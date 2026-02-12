extends Node3D
class_name EnvironmentSpawner

## EnvironmentSpawner - Places billboard trees, rocks, and foliage on terrain
## Paper Mario style 2D objects in 3D world

signal environment_ready()

# Configuration
@export_group("Spawning")
@export var spawn_radius: float = 80.0  # How far to spawn objects
@export var update_radius: float = 100.0  # How far before re-centering
@export var tree_density: float = 0.015  # Trees per square unit
@export var rock_density: float = 0.05  # Rocks per square unit
@export var grass_density: float = 0.04  # Grass clumps per square unit

@export_group("Object Limits")
@export var max_trees: int = 200
@export var max_rocks: int = 100
@export var max_grass: int = 300

# Internal state
var terrain_world: Node = null
var player: Node3D = null
var last_spawn_center: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Object pools
var tree_pool: Array[Sprite3D] = []
var rock_pool: Array[Sprite3D] = []
var grass_pool: Array[Sprite3D] = []

# Active objects tracking
var active_trees: Dictionary = {}  # key -> Sprite3D
var active_rocks: Dictionary = {}
var active_grass: Dictionary = {}

# Texture references
var tree_textures: Dictionary = {}
var rock_texture: ImageTexture = null
var grass_texture: ImageTexture = null

# Grid-based spawning
const GRID_SIZE: float = 8.0  # Size of spawn grid cells

# Tree type weights by biome height
const TREE_TYPES_BY_HEIGHT: Array = [
	{"type": "swamp", "min_height": -5, "max_height": 5, "weight": 1.0},
	{"type": "oak", "min_height": 5, "max_height": 25, "weight": 1.5},
	{"type": "pine", "min_height": 20, "max_height": 50, "weight": 1.2},
	{"type": "dead", "min_height": -10, "max_height": 60, "weight": 0.3},
	{"type": "magic", "min_height": 15, "max_height": 45, "weight": 0.15},
]


func _ready() -> void:
	print("[EnvironmentSpawner] Initializing...")

	# Wait a frame for other nodes to be ready
	await get_tree().process_frame

	# Find terrain world
	var terrain_nodes = get_tree().get_nodes_in_group("terrain_world")
	if terrain_nodes.size() > 0:
		terrain_world = terrain_nodes[0]
		print("[EnvironmentSpawner] Found terrain world")

	# Generate textures
	_generate_textures()

	# Create object pools
	_create_object_pools()

	print("[EnvironmentSpawner] Ready")
	emit_signal("environment_ready")


func _process(_delta: float) -> void:
	# Find player if not set
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			last_spawn_center = player.global_position
			_spawn_environment_around(player.global_position)
			return
		return

	# Check if player moved far enough to respawn
	var dist_from_center = player.global_position.distance_to(last_spawn_center)
	if dist_from_center > update_radius * 0.5:
		_update_environment(player.global_position)


func _generate_textures() -> void:
	var tex_gen = get_node_or_null("/root/TextureGenerator")

	if tex_gen:
		# Pre-generate tree textures
		for tree_type in ["oak", "pine", "dead", "magic", "swamp"]:
			tree_textures[tree_type] = tex_gen.generate_tree_texture(tree_type)
		print("[EnvironmentSpawner] Generated tree textures")
	else:
		# Fallback textures
		_generate_fallback_textures()

	# Generate rock texture (procedural)
	_generate_rock_texture()

	# Generate grass texture (procedural)
	_generate_grass_texture()


func _generate_fallback_textures() -> void:
	# Simple green tree fallback
	var img = Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Trunk
	for y in range(90, 124):
		for x in range(28, 36):
			img.set_pixel(x, y, Color(0.4, 0.3, 0.2))

	# Canopy
	for y in range(10, 95):
		for x in range(10, 54):
			var dx = x - 32
			var dy = y - 50
			if dx * dx + dy * dy < 900:
				img.set_pixel(x, y, Color(0.2 + randf() * 0.1, 0.5 + randf() * 0.2, 0.2))

	var tex = ImageTexture.create_from_image(img)
	tree_textures["oak"] = tex
	tree_textures["pine"] = tex
	tree_textures["dead"] = tex
	tree_textures["magic"] = tex
	tree_textures["swamp"] = tex


func _generate_rock_texture() -> void:
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var cx = 24
	var cy = 30

	# Irregular rock shape
	for y in range(48):
		for x in range(48):
			var dx = x - cx
			var dy = (y - cy) * 1.3  # Flatten vertically
			var noise_offset = sin(x * 0.5) * 3 + cos(y * 0.7) * 2
			var dist = sqrt(dx * dx + dy * dy) + noise_offset

			if dist < 20:
				var shade = 0.4 + (1.0 - dist / 20.0) * 0.3 + randf() * 0.1
				var color = Color(shade * 0.6, shade * 0.58, shade * 0.55)
				img.set_pixel(x, y, color)

	rock_texture = ImageTexture.create_from_image(img)


func _generate_grass_texture() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Draw several grass blades
	for blade in range(5):
		var bx = 6 + blade * 5 + randi() % 3
		var sway = randf() * 6 - 3

		for y in range(48):
			var progress = y / 48.0
			var x_offset = int(sway * (1.0 - progress))
			var blade_width = max(1, int(2 * (1.0 - progress)))

			for w in range(-blade_width, blade_width + 1):
				var px = bx + x_offset + w
				var py = 47 - y
				if px >= 0 and px < 32 and py >= 0 and py < 48:
					var shade = 0.3 + progress * 0.4 + randf() * 0.1
					img.set_pixel(px, py, Color(shade * 0.5, shade, shade * 0.4))

	grass_texture = ImageTexture.create_from_image(img)


func _create_object_pools() -> void:
	# Create tree pool
	for _i in range(max_trees):
		var sprite = _create_billboard_sprite()
		sprite.visible = false
		add_child(sprite)
		tree_pool.append(sprite)

	# Create rock pool
	for _i in range(max_rocks):
		var sprite = _create_billboard_sprite()
		sprite.texture = rock_texture
		sprite.pixel_size = 0.03
		sprite.visible = false
		add_child(sprite)
		rock_pool.append(sprite)

	# Create grass pool
	for _i in range(max_grass):
		var sprite = _create_billboard_sprite()
		sprite.texture = grass_texture
		sprite.pixel_size = 0.015
		sprite.visible = false
		add_child(sprite)
		grass_pool.append(sprite)

	print("[EnvironmentSpawner] Created object pools: %d trees, %d rocks, %d grass" % [max_trees, max_rocks, max_grass])


func _create_billboard_sprite() -> Sprite3D:
	var sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.render_priority = 0
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


func _spawn_environment_around(center: Vector3) -> void:
	last_spawn_center = center

	# Clear existing placements
	active_trees.clear()
	active_rocks.clear()
	active_grass.clear()

	# Hide all pooled objects
	for sprite in tree_pool:
		sprite.visible = false
	for sprite in rock_pool:
		sprite.visible = false
	for sprite in grass_pool:
		sprite.visible = false

	# Seed RNG based on world position for consistency
	rng.seed = int(center.x / GRID_SIZE) * 73856093 ^ int(center.z / GRID_SIZE) * 19349663

	var tree_idx = 0
	var rock_idx = 0
	var grass_idx = 0

	# Spawn in grid cells around center
	var grid_radius = int(spawn_radius / GRID_SIZE)

	for gx in range(-grid_radius, grid_radius + 1):
		for gz in range(-grid_radius, grid_radius + 1):
			var grid_x = int(center.x / GRID_SIZE) + gx
			var grid_z = int(center.z / GRID_SIZE) + gz
			var grid_key = "%d,%d" % [grid_x, grid_z]

			# Check distance
			var cell_center = Vector3(grid_x * GRID_SIZE + GRID_SIZE * 0.5, 0, grid_z * GRID_SIZE + GRID_SIZE * 0.5)
			var dist = Vector2(cell_center.x - center.x, cell_center.z - center.z).length()
			if dist > spawn_radius:
				continue

			# Seed RNG for this cell (consistent spawning)
			rng.seed = grid_x * 73856093 ^ grid_z * 19349663

			var cell_area = GRID_SIZE * GRID_SIZE

			# Spawn trees in this cell
			var num_trees = int(cell_area * tree_density * (0.5 + rng.randf()))
			for _t in range(num_trees):
				if tree_idx >= max_trees:
					break

				var local_x = rng.randf() * GRID_SIZE
				var local_z = rng.randf() * GRID_SIZE
				var world_x = grid_x * GRID_SIZE + local_x
				var world_z = grid_z * GRID_SIZE + local_z

				var height = _get_terrain_height(world_x, world_z)
				if height < -10 or height > 60:  # Skip water/extreme heights
					continue

				var pos = Vector3(world_x, height, world_z)
				var tree_type = _get_tree_type_for_height(height)

				if tree_pool[tree_idx]:
					_place_tree(tree_pool[tree_idx], pos, tree_type)
					active_trees[grid_key + "_t" + str(_t)] = tree_pool[tree_idx]
					tree_idx += 1

			# Spawn rocks in this cell
			var num_rocks = int(cell_area * rock_density * (0.5 + rng.randf()))
			for _r in range(num_rocks):
				if rock_idx >= max_rocks:
					break

				var local_x = rng.randf() * GRID_SIZE
				var local_z = rng.randf() * GRID_SIZE
				var world_x = grid_x * GRID_SIZE + local_x
				var world_z = grid_z * GRID_SIZE + local_z

				var height = _get_terrain_height(world_x, world_z)
				# Rocks spawn almost everywhere
				if height < -100:  # Only skip if way under water
					continue

				var pos = Vector3(world_x, height, world_z)

				if rock_pool[rock_idx]:
					_place_rock(rock_pool[rock_idx], pos)
					active_rocks[grid_key + "_r" + str(_r)] = rock_pool[rock_idx]
					rock_idx += 1

			# Spawn grass in this cell (only close to player)
			if dist < spawn_radius * 0.5:
				var num_grass = int(cell_area * grass_density * (0.5 + rng.randf()))
				for _g in range(num_grass):
					if grass_idx >= max_grass:
						break

					var local_x = rng.randf() * GRID_SIZE
					var local_z = rng.randf() * GRID_SIZE
					var world_x = grid_x * GRID_SIZE + local_x
					var world_z = grid_z * GRID_SIZE + local_z

					var height = _get_terrain_height(world_x, world_z)
					if height < 0 or height > 40:
						continue

					var pos = Vector3(world_x, height, world_z)

					if grass_pool[grass_idx]:
						_place_grass(grass_pool[grass_idx], pos)
						active_grass[grid_key + "_g" + str(_g)] = grass_pool[grass_idx]
						grass_idx += 1

	print("[EnvironmentSpawner] Spawned %d trees, %d rocks, %d grass around (%.0f, %.0f)" % [
		tree_idx, rock_idx, grass_idx, center.x, center.z
	])


func _update_environment(new_center: Vector3) -> void:
	# For now, just respawn everything
	_spawn_environment_around(new_center)


func _get_terrain_height(x: float, z: float) -> float:
	if terrain_world and terrain_world.has_method("get_terrain_height"):
		return terrain_world.get_terrain_height(Vector2(x, z))
	return 0.0


func _get_tree_type_for_height(height: float) -> String:
	var candidates: Array = []
	var total_weight: float = 0.0

	for tree_info in TREE_TYPES_BY_HEIGHT:
		if height >= tree_info["min_height"] and height <= tree_info["max_height"]:
			candidates.append(tree_info)
			total_weight += tree_info["weight"]

	if candidates.size() == 0:
		return "oak"

	var roll = rng.randf() * total_weight
	var cumulative: float = 0.0

	for tree_info in candidates:
		cumulative += tree_info["weight"]
		if roll <= cumulative:
			return tree_info["type"]

	return candidates[0]["type"]


func _place_tree(sprite: Sprite3D, pos: Vector3, tree_type: String) -> void:
	sprite.texture = tree_textures.get(tree_type, tree_textures["oak"])
	sprite.pixel_size = 0.04 + rng.randf() * 0.02  # Bigger trees (was 0.025)

	# Offset Y so tree base is at ground level (texture is 128 tall, centered)
	var tex_height = sprite.texture.get_height() if sprite.texture else 128
	var world_height = tex_height * sprite.pixel_size

	# Scale variation makes some trees bigger
	var scale_var = 0.9 + rng.randf() * 0.6  # Range 0.9 to 1.5
	sprite.scale = Vector3.ONE * scale_var

	# Position tree so base is at ground
	sprite.position = pos + Vector3(0, world_height * 0.48 * scale_var, 0)

	# Random rotation
	sprite.rotation.y = rng.randf() * TAU
	sprite.visible = true


func _place_rock(sprite: Sprite3D, pos: Vector3) -> void:
	# Bigger rocks
	sprite.pixel_size = 0.04  # Was 0.03 in pool
	var scale_var = 0.6 + rng.randf() * 1.2  # Range 0.6 to 1.8
	sprite.scale = Vector3.ONE * scale_var

	# Rock sits on ground
	var rock_height = 48 * sprite.pixel_size * scale_var
	sprite.position = pos + Vector3(0, rock_height * 0.25, 0)

	sprite.rotation.y = rng.randf() * TAU
	sprite.visible = true


func _place_grass(sprite: Sprite3D, pos: Vector3) -> void:
	sprite.pixel_size = 0.02  # Was 0.015 in pool
	var scale_var = 0.7 + rng.randf() * 0.9  # Range 0.7 to 1.6
	sprite.scale = Vector3.ONE * scale_var

	var grass_height = 48 * sprite.pixel_size * scale_var
	sprite.position = pos + Vector3(0, grass_height * 0.35, 0)

	sprite.rotation.y = rng.randf() * TAU
	sprite.visible = true
