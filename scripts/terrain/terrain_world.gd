extends Node3D
class_name TerrainWorld

## TerrainWorld - Marching Cubes terrain system for Mages-vs-Zombies
## Adapted from Hamberg's custom terrain system

const ChunkDataClass = preload("res://scripts/terrain/chunk_data.gd")
const ChunkMeshGeneratorClass = preload("res://scripts/terrain/chunk_mesh_generator.gd")

# Signals
signal chunk_loaded(chunk_x: int, chunk_z: int)
signal chunk_unloaded(chunk_x: int, chunk_z: int)
signal terrain_ready()  # Emitted when initial chunks around player are ready

# Terrain generation
var biome_generator  # TerrainBiomeGenerator instance
var mesh_generator  # ChunkMeshGenerator instance

# Chunk storage
var chunks: Dictionary = {}  # Key: "x,z" -> ChunkData
var chunk_meshes: Dictionary = {}  # Key: "x,z" -> MeshInstance3D
var chunk_colliders: Dictionary = {}  # Key: "x,z" -> StaticBody3D
var chunk_lod_levels: Dictionary = {}  # Key: "x,z" -> current LOD level

# Configuration
@export var view_distance: int = 12  # Increased view distance
@export var world_seed: int = 12345

# LOD distances (in chunks from player)
const LOD_DISTANCES: Array = [4, 8, 12]  # Increased LOD distances

# State
var is_initialized: bool = false
var initial_terrain_ready: bool = false

# Player tracking
var tracked_players: Array[Node3D] = []
var player_chunk_positions: Dictionary = {}

# Material for terrain rendering
var terrain_material: Material

# Threading for mesh generation
var pending_mesh_updates: Array = []
var mesh_updates_in_progress: Dictionary = {}
var completed_mesh_results: Array = []
var mesh_result_mutex: Mutex = Mutex.new()
const MAX_CONCURRENT_MESH_TASKS: int = 4

# Chunk loading queue
var pending_chunk_loads: Array = []
var chunk_load_timer: float = 0.0
const CHUNK_LOAD_INTERVAL: float = 0.016
const CHUNKS_PER_FRAME: int = 8


func _ready() -> void:
	print("[TerrainWorld] Initializing terrain system...")

	add_to_group("terrain_world")

	# Create mesh generator
	mesh_generator = ChunkMeshGeneratorClass.new()

	# Setup biome generator
	var BiomeGen = preload("res://scripts/terrain/terrain_biome_generator.gd")
	biome_generator = BiomeGen.new(world_seed)

	# Setup terrain material
	_setup_terrain_material()

	is_initialized = true
	print("[TerrainWorld] Terrain system ready (seed: %d)" % world_seed)


func _setup_terrain_material() -> void:
	# Load terrain shader with biome colors and slope detection
	var shader_path = "res://shaders/terrain_material.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader = load(shader_path)
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("world_seed", world_seed)
		terrain_material = mat
		print("[TerrainWorld] Using terrain shader material (seed: %d)" % world_seed)
	else:
		# Fallback to simple material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.55, 0.25)
		mat.roughness = 0.9
		terrain_material = mat
		print("[TerrainWorld] Using fallback terrain material")


func _process(delta: float) -> void:
	if not is_initialized:
		return

	# Process pending chunk loads (rate limited)
	chunk_load_timer += delta
	if chunk_load_timer >= CHUNK_LOAD_INTERVAL and pending_chunk_loads.size() > 0:
		chunk_load_timer = 0.0
		for _i in range(min(CHUNKS_PER_FRAME, pending_chunk_loads.size())):
			if pending_chunk_loads.size() == 0:
				break
			var coords = pending_chunk_loads.pop_front()
			_load_chunk_immediate(coords[0], coords[1])

	# Start new mesh generation tasks (threaded)
	_start_threaded_mesh_updates()

	# Apply completed mesh results on main thread
	_apply_completed_meshes()

	# Update chunks around players
	for player in tracked_players:
		if is_instance_valid(player):
			_update_chunks_around_position(player.global_position)


## Add a player to track for chunk loading
func add_tracked_player(player: Node3D) -> void:
	if player not in tracked_players:
		tracked_players.append(player)
		player_chunk_positions[player] = Vector2i(-999999, -999999)
		print("[TerrainWorld] Tracking player: %s" % player.name)

		# Immediately load chunks around player
		_update_chunks_around_position(player.global_position)


## Remove a tracked player
func remove_tracked_player(player: Node3D) -> void:
	tracked_players.erase(player)
	player_chunk_positions.erase(player)


## Update chunks around a world position
func _update_chunks_around_position(world_pos: Vector3) -> void:
	var center_chunk := ChunkDataClass.world_to_chunk_coords(world_pos)

	# Collect chunks to load with their distances
	var chunks_to_queue: Array = []

	for dx in range(-view_distance, view_distance + 1):
		for dz in range(-view_distance, view_distance + 1):
			var cx := center_chunk.x + dx
			var cz := center_chunk.y + dz

			# Skip if too far (circular check)
			var dist_sq := dx * dx + dz * dz
			if dist_sq > view_distance * view_distance:
				continue

			var key := ChunkDataClass.make_key(cx, cz)
			if not chunks.has(key):
				var already_queued := false
				for pending in pending_chunk_loads:
					if pending[0] == cx and pending[1] == cz:
						already_queued = true
						break
				if not already_queued:
					chunks_to_queue.append([cx, cz, dist_sq])

	# Sort by distance (closest first)
	chunks_to_queue.sort_custom(func(a, b): return a[2] < b[2])

	# Load the closest chunks immediately with mesh (under player's feet)
	var immediate_load_count := 0
	const MAX_IMMEDIATE_LOADS := 9  # 3x3 area under player
	for chunk_info in chunks_to_queue:
		if immediate_load_count >= MAX_IMMEDIATE_LOADS:
			break
		if chunk_info[2] <= 2:  # Distance squared <= 2 means adjacent or same chunk
			_load_chunk_immediate(chunk_info[0], chunk_info[1], true)
			immediate_load_count += 1

	# Check if initial terrain is ready
	if not initial_terrain_ready and immediate_load_count > 0:
		# Check if we have collision for the chunk player is in
		var player_chunk_key := ChunkDataClass.make_key(center_chunk.x, center_chunk.y)
		if chunk_colliders.has(player_chunk_key):
			initial_terrain_ready = true
			emit_signal("terrain_ready")
			print("[TerrainWorld] Initial terrain ready!")

	# Queue the rest
	for chunk_info in chunks_to_queue:
		if chunk_info[2] > 2:
			_load_chunk(chunk_info[0], chunk_info[1])

	# Unload chunks too far away AND update LOD for existing chunks
	var chunks_to_unload: Array = []
	for chunk_key in chunks:
		var chunk = chunks[chunk_key]
		var dist_x: int = chunk.chunk_x - center_chunk.x
		var dist_z: int = chunk.chunk_z - center_chunk.y
		var dist_sq: int = dist_x * dist_x + dist_z * dist_z

		if dist_sq > (view_distance + 2) * (view_distance + 2):
			chunks_to_unload.append(chunk_key)
		else:
			# Check if LOD level needs updating
			var current_lod: int = chunk_lod_levels.get(chunk_key, -1)
			var new_lod: int = _get_chunk_lod_level(chunk.chunk_x, chunk.chunk_z)

			# Re-generate mesh if LOD changed OR if close chunk is missing collision
			var needs_collision: bool = new_lod <= 1 and not chunk_colliders.has(chunk_key)
			if current_lod != new_lod or needs_collision:
				if not pending_mesh_updates.has(chunk_key) and not mesh_updates_in_progress.has(chunk_key):
					chunk.is_dirty = true
					pending_mesh_updates.append(chunk_key)

	for key in chunks_to_unload:
		_unload_chunk(key)


## Queue a chunk for loading
func _load_chunk(cx: int, cz: int) -> void:
	var key := ChunkDataClass.make_key(cx, cz)
	if chunks.has(key):
		return

	var coords := [cx, cz]
	for pending in pending_chunk_loads:
		if pending[0] == cx and pending[1] == cz:
			return

	pending_chunk_loads.append(coords)


## Load a chunk immediately
func _load_chunk_immediate(cx: int, cz: int, generate_mesh_now: bool = false) -> void:
	var key := ChunkDataClass.make_key(cx, cz)
	if chunks.has(key):
		if generate_mesh_now and chunks[key].is_dirty:
			_update_chunk_mesh(chunks[key])
		return

	# Generate new chunk
	var chunk = _generate_chunk(cx, cz)
	chunks[key] = chunk

	if generate_mesh_now:
		_update_chunk_mesh(chunk)
	else:
		if not pending_mesh_updates.has(key):
			pending_mesh_updates.append(key)

	# Mark neighbor chunks as needing mesh update
	_queue_neighbor_mesh_updates(cx, cz)

	emit_signal("chunk_loaded", cx, cz)


## Queue mesh updates for neighboring chunks
func _queue_neighbor_mesh_updates(cx: int, cz: int) -> void:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var nkey := ChunkDataClass.make_key(cx + dx, cz + dz)
			if chunks.has(nkey) and not pending_mesh_updates.has(nkey):
				chunks[nkey].is_dirty = true
				pending_mesh_updates.append(nkey)


## Generate a new chunk procedurally
func _generate_chunk(cx: int, cz: int):
	var chunk := ChunkDataClass.new(cx, cz)
	chunk.biome_generator = biome_generator

	# Generate heightmap
	var heights := PackedFloat32Array()
	heights.resize(ChunkDataClass.CHUNK_SIZE_XZ * ChunkDataClass.CHUNK_SIZE_XZ)

	for lz in ChunkDataClass.CHUNK_SIZE_XZ:
		for lx in ChunkDataClass.CHUNK_SIZE_XZ:
			var world_x := cx * ChunkDataClass.CHUNK_SIZE_XZ + lx
			var world_z := cz * ChunkDataClass.CHUNK_SIZE_XZ + lz
			var world_pos := Vector2(world_x, world_z)

			var terrain_height: float = biome_generator.get_height_at_position(world_pos)
			heights[lx + lz * ChunkDataClass.CHUNK_SIZE_XZ] = terrain_height

	chunk.fill_from_heights(heights)
	return chunk


## Get LOD level for a chunk based on distance from players
func _get_chunk_lod_level(cx: int, cz: int) -> int:
	var min_dist_sq: float = INF

	for player in tracked_players:
		if is_instance_valid(player):
			var player_chunk := ChunkDataClass.world_to_chunk_coords(player.global_position)
			var dx: int = cx - player_chunk.x
			var dz: int = cz - player_chunk.y
			var dist_sq: float = dx * dx + dz * dz
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq

	var dist: float = sqrt(min_dist_sq)

	for i in LOD_DISTANCES.size():
		if dist <= LOD_DISTANCES[i]:
			return i
	return LOD_DISTANCES.size()


## Start threaded mesh generation for pending chunks
func _start_threaded_mesh_updates() -> void:
	while mesh_updates_in_progress.size() < MAX_CONCURRENT_MESH_TASKS and pending_mesh_updates.size() > 0:
		var chunk_key = pending_mesh_updates.pop_front()

		if mesh_updates_in_progress.has(chunk_key) or not chunks.has(chunk_key):
			continue

		var chunk = chunks[chunk_key]
		if not chunk.is_dirty:
			continue

		var lod_level: int = _get_chunk_lod_level(chunk.chunk_x, chunk.chunk_z)

		# Gather neighbor data
		var neighbors := {}
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nkey := ChunkDataClass.make_key(chunk.chunk_x + dx, chunk.chunk_z + dz)
				if chunks.has(nkey):
					neighbors[nkey] = chunks[nkey]

		var task_id = WorkerThreadPool.add_task(
			_generate_mesh_threaded.bind(chunk_key, chunk, neighbors, lod_level)
		)
		mesh_updates_in_progress[chunk_key] = task_id


## Threaded mesh generation
func _generate_mesh_threaded(chunk_key: String, chunk, neighbors: Dictionary, lod_level: int = 0) -> void:
	# Safety check - mesh_generator and mutex must exist
	if not mesh_generator or not mesh_result_mutex:
		return

	var mesh: ArrayMesh = mesh_generator.generate_mesh(chunk, neighbors, lod_level)
	var collision_shape: ConcavePolygonShape3D = null

	# Only generate collision for high detail chunks (LOD 0 and 1)
	if mesh and lod_level <= 1 and mesh_generator:
		collision_shape = mesh_generator.generate_collision_shape(mesh)

	if not mesh_result_mutex:
		return

	mesh_result_mutex.lock()
	completed_mesh_results.append({
		"chunk_key": chunk_key,
		"mesh": mesh,
		"collision_shape": collision_shape,
		"lod_level": lod_level
	})
	mesh_result_mutex.unlock()


## Apply completed mesh results on main thread
func _apply_completed_meshes() -> void:
	mesh_result_mutex.lock()
	var results_to_apply = completed_mesh_results.duplicate()
	completed_mesh_results.clear()
	mesh_result_mutex.unlock()

	for result in results_to_apply:
		var chunk_key: String = result["chunk_key"]
		var lod_level: int = result.get("lod_level", 0)

		mesh_updates_in_progress.erase(chunk_key)

		if not chunks.has(chunk_key):
			continue

		var chunk = chunks[chunk_key]
		var mesh: ArrayMesh = result["mesh"]
		var collision_shape: ConcavePolygonShape3D = result["collision_shape"]

		if mesh == null or mesh.get_surface_count() == 0:
			_remove_chunk_visuals(chunk_key)
			chunk.is_dirty = false
			chunk_lod_levels.erase(chunk_key)
			continue

		chunk_lod_levels[chunk_key] = lod_level

		# Create or update MeshInstance3D
		var mesh_instance: MeshInstance3D
		if chunk_meshes.has(chunk_key):
			mesh_instance = chunk_meshes[chunk_key]
		else:
			mesh_instance = MeshInstance3D.new()
			mesh_instance.name = "ChunkMesh_%s" % chunk_key
			add_child(mesh_instance)
			chunk_meshes[chunk_key] = mesh_instance

		mesh_instance.mesh = mesh
		mesh_instance.material_override = terrain_material

		# Create or update collision shape
		if collision_shape:
			var static_body: StaticBody3D
			if chunk_colliders.has(chunk_key):
				static_body = chunk_colliders[chunk_key]
				for child in static_body.get_children():
					child.queue_free()
			else:
				static_body = StaticBody3D.new()
				static_body.name = "ChunkCollider_%s" % chunk_key
				static_body.collision_layer = 1
				static_body.collision_mask = 0
				add_child(static_body)
				chunk_colliders[chunk_key] = static_body

			var shape_node := CollisionShape3D.new()
			shape_node.shape = collision_shape
			static_body.add_child(shape_node)

		chunk.is_dirty = false

		# Check if initial terrain is now ready
		if not initial_terrain_ready:
			for player in tracked_players:
				if is_instance_valid(player):
					var player_chunk := ChunkDataClass.world_to_chunk_coords(player.global_position)
					var player_chunk_key := ChunkDataClass.make_key(player_chunk.x, player_chunk.y)
					if chunk_colliders.has(player_chunk_key):
						initial_terrain_ready = true
						emit_signal("terrain_ready")
						print("[TerrainWorld] Initial terrain ready!")
						break


## Update mesh for a chunk (synchronous)
func _update_chunk_mesh(chunk) -> void:
	if not chunk.is_dirty:
		return

	var key: String = chunk.get_key()

	var neighbors := {}
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var nkey := ChunkDataClass.make_key(chunk.chunk_x + dx, chunk.chunk_z + dz)
			if chunks.has(nkey):
				neighbors[nkey] = chunks[nkey]

	var mesh: ArrayMesh = mesh_generator.generate_mesh(chunk, neighbors)

	if mesh == null:
		_remove_chunk_visuals(key)
		chunk.is_dirty = false
		return

	# Create or update MeshInstance3D
	var mesh_instance: MeshInstance3D
	if chunk_meshes.has(key):
		mesh_instance = chunk_meshes[key]
	else:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "ChunkMesh_%s" % key
		add_child(mesh_instance)
		chunk_meshes[key] = mesh_instance

	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material

	# Create or update collision shape
	var collision_shape: ConcavePolygonShape3D = mesh_generator.generate_collision_shape(mesh)
	if collision_shape:
		var static_body: StaticBody3D
		if chunk_colliders.has(key):
			static_body = chunk_colliders[key]
			for child in static_body.get_children():
				child.queue_free()
		else:
			static_body = StaticBody3D.new()
			static_body.name = "ChunkCollider_%s" % key
			static_body.collision_layer = 1
			static_body.collision_mask = 0
			add_child(static_body)
			chunk_colliders[key] = static_body

		var shape_node := CollisionShape3D.new()
		shape_node.shape = collision_shape
		static_body.add_child(shape_node)

	chunk.is_dirty = false


## Remove visual elements for a chunk
func _remove_chunk_visuals(key: String) -> void:
	if chunk_meshes.has(key):
		chunk_meshes[key].queue_free()
		chunk_meshes.erase(key)

	if chunk_colliders.has(key):
		chunk_colliders[key].queue_free()
		chunk_colliders.erase(key)


## Unload a chunk
func _unload_chunk(key: String) -> void:
	if not chunks.has(key):
		return

	var chunk = chunks[key]
	_remove_chunk_visuals(key)
	chunks.erase(key)
	pending_mesh_updates.erase(key)

	emit_signal("chunk_unloaded", chunk.chunk_x, chunk.chunk_z)


## Get terrain height at XZ position
func get_terrain_height(xz_pos: Vector2) -> float:
	if biome_generator:
		return biome_generator.get_height_at_position(xz_pos)
	return 0.0


## Get biome at position
func get_biome_at(xz_pos: Vector2) -> String:
	if biome_generator:
		return biome_generator.get_biome_at_position(xz_pos)
	return "valley"


## Get biome index for shader
func _get_biome_index(biome_name: String) -> int:
	match biome_name:
		"valley": return 0
		"dark_forest": return 1
		"swamp": return 2
		"mountain": return 3
		"desert": return 4
		"wizardland": return 5
		"hell": return 6
		_: return 0


## Check if collision is ready at position
func has_collision_at_position(world_pos: Vector3) -> bool:
	var chunk_coords := ChunkDataClass.world_to_chunk_coords(world_pos)
	var key := ChunkDataClass.make_key(chunk_coords.x, chunk_coords.y)
	return chunk_colliders.has(key)


## Check if terrain is ready for player spawning
func is_terrain_ready() -> bool:
	return initial_terrain_ready
