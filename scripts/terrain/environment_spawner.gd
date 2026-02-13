extends Node3D
class_name EnvironmentSpawner

## EnvironmentSpawner - Places billboard trees, rocks, and foliage on terrain
## Paper Mario style 2D objects in 3D world

signal environment_ready()

# Configuration
@export_group("Spawning")
@export var spawn_radius: float = 200.0  # How far to spawn objects (very far for 2D billboards)
@export var update_radius: float = 80.0  # How far before re-centering
@export var tree_density: float = 0.025  # Trees per square unit (more dense)
@export var rock_density: float = 0.015  # Rocks per square unit
@export var grass_density: float = 0.06  # Grass clumps per square unit (more dense)

@export_group("Object Limits")
@export var max_trees: int = 600
@export var max_rocks: int = 250
@export var max_grass: int = 800

# Internal state
var terrain_world: Node = null
var player: Node3D = null
var last_spawn_center: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Object pools - trees are now StaticBody3D with sprites
var tree_pool: Array[StaticBody3D] = []
var rock_pool: Array[Sprite3D] = []
var grass_pool: Array[Sprite3D] = []

# Tree health tracking
var tree_health: Dictionary = {}  # tree_instance_id -> health
const TREE_MAX_HEALTH: float = 100.0
const TREE_COLLISION_LAYER: int = 1  # World layer

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

# Tree types by biome - each biome has different vegetation
const BIOME_TREES: Dictionary = {
	"valley": ["oak", "oak", "pine", "magic"],  # Serene meadows with occasional magic trees
	"dark_forest": ["dark_oak", "dark_oak", "swamp", "dead"],  # Very dark, twisted trees
	"swamp": ["swamp", "swamp", "dead", "swamp"],  # Mostly swamp trees with some dead
	"mountain": ["frost_pine", "frost_pine", "pine", "dead"],  # Snowy pines
	"desert": ["cactus", "cactus", "palm", "dead"],  # Cacti and palm trees
	"wizardland": ["crystal_tree", "crystal_tree", "magic", "crystal_tree"],  # Magical crystal trees
	"hell": ["ember_tree", "ember_tree", "dead", "ember_tree"],  # Burning ember trees
}

# Tree density multiplier by biome (some biomes have more/less vegetation)
const BIOME_TREE_DENSITY: Dictionary = {
	"valley": 1.2,
	"dark_forest": 1.5,  # Dense forest
	"swamp": 0.8,
	"mountain": 0.4,  # Sparse at high altitude
	"desert": 0.15,  # Very sparse
	"wizardland": 0.6,
	"hell": 0.3,  # Barren wasteland
}

# Grass spawning by biome
const BIOME_HAS_GRASS: Dictionary = {
	"valley": true,
	"dark_forest": true,
	"swamp": true,
	"mountain": false,  # Snow, no grass
	"desert": false,  # Sand, no grass
	"wizardland": true,
	"hell": false,  # Fire, no grass
}


func _ready() -> void:
	add_to_group("environment_spawner")
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
		# Pre-generate all tree textures including biome-specific ones
		var all_tree_types := ["oak", "pine", "dead", "magic", "swamp",
							   "cactus", "palm", "frost_pine", "crystal_tree",
							   "ember_tree", "dark_oak"]
		for tree_type in all_tree_types:
			tree_textures[tree_type] = tex_gen.generate_tree_texture(tree_type)
		print("[EnvironmentSpawner] Generated %d tree textures" % all_tree_types.size())
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
	# Create tree pool - each tree is a StaticBody3D with collision
	for _i in range(max_trees):
		var tree = _create_tree_body()
		tree.visible = false
		add_child(tree)
		tree_pool.append(tree)

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


func _create_tree_body() -> StaticBody3D:
	# Create a StaticBody3D for tree collision
	var body = StaticBody3D.new()
	body.collision_layer = TREE_COLLISION_LAYER
	body.collision_mask = 0  # Trees don't need to detect other things

	# Add collision shape (cylinder for trunk)
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 3.0
	collision.shape = capsule
	collision.position = Vector3(0, 1.5, 0)  # Center the capsule
	body.add_child(collision)

	# Add sprite
	var sprite = _create_billboard_sprite()
	body.add_child(sprite)

	# Add to destructible group
	body.add_to_group("destructible_trees")

	# Initialize health
	tree_health[body.get_instance_id()] = TREE_MAX_HEALTH

	return body


func _create_billboard_sprite() -> Sprite3D:
	var sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y  # Stay upright when looking up/down
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

	var tree_idx = 0
	var rock_idx = 0
	var grass_idx = 0

	# Collect all valid grid cells with their distances
	var grid_radius = int(spawn_radius / GRID_SIZE)
	var cells: Array = []

	for gx in range(-grid_radius, grid_radius + 1):
		for gz in range(-grid_radius, grid_radius + 1):
			var grid_x = int(center.x / GRID_SIZE) + gx
			var grid_z = int(center.z / GRID_SIZE) + gz

			var cell_center = Vector3(grid_x * GRID_SIZE + GRID_SIZE * 0.5, 0, grid_z * GRID_SIZE + GRID_SIZE * 0.5)
			var dist = Vector2(cell_center.x - center.x, cell_center.z - center.z).length()
			if dist > spawn_radius:
				continue

			cells.append({"x": grid_x, "z": grid_z, "dist": dist})

	# Sort cells by distance (closest first) - ensures nearby objects get priority
	cells.sort_custom(func(a, b): return a.dist < b.dist)

	var cell_area = GRID_SIZE * GRID_SIZE

	# Spawn objects in distance-sorted order
	for cell in cells:
		var grid_x: int = cell.x
		var grid_z: int = cell.z
		var dist: float = cell.dist
		var grid_key = "%d,%d" % [grid_x, grid_z]

		# Seed RNG for this cell (consistent spawning)
		rng.seed = grid_x * 73856093 ^ grid_z * 19349663

		# Get biome for this cell (use cell center)
		var cell_world_x = grid_x * GRID_SIZE + GRID_SIZE * 0.5
		var cell_world_z = grid_z * GRID_SIZE + GRID_SIZE * 0.5
		var biome = _get_biome_at(cell_world_x, cell_world_z)
		var biome_density_mult = _get_tree_density_for_biome(biome)

		# Spawn trees in this cell based on biome
		var num_trees = int(cell_area * tree_density * biome_density_mult * (0.5 + rng.randf()))
		for _t in range(num_trees):
			if tree_idx >= max_trees:
				break

			var local_x = rng.randf() * GRID_SIZE
			var local_z = rng.randf() * GRID_SIZE
			var world_x = grid_x * GRID_SIZE + local_x
			var world_z = grid_z * GRID_SIZE + local_z

			var height = _get_terrain_height(world_x, world_z)
			if height < -10 or height > 80:  # Skip water/extreme heights
				continue

			var pos = Vector3(world_x, height, world_z)
			var tree_type = _get_tree_type_for_biome(biome)

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
				_place_rock(rock_pool[rock_idx], pos, biome)
				active_rocks[grid_key + "_r" + str(_r)] = rock_pool[rock_idx]
				rock_idx += 1

		# Spawn grass in this cell (only close to player and in biomes with grass)
		if dist < spawn_radius * 0.5 and _biome_has_grass(biome):
			var num_grass = int(cell_area * grass_density * (0.5 + rng.randf()))
			for _g in range(num_grass):
				if grass_idx >= max_grass:
					break

				var local_x = rng.randf() * GRID_SIZE
				var local_z = rng.randf() * GRID_SIZE
				var world_x = grid_x * GRID_SIZE + local_x
				var world_z = grid_z * GRID_SIZE + local_z

				var height = _get_terrain_height(world_x, world_z)
				if height < 0 or height > 50:
					continue

				var pos = Vector3(world_x, height, world_z)

				if grass_pool[grass_idx]:
					_place_grass(grass_pool[grass_idx], pos, biome)
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


func _get_biome_at(x: float, z: float) -> String:
	if terrain_world and terrain_world.has_method("get_biome_at"):
		return terrain_world.get_biome_at(Vector2(x, z))
	return "valley"


func _get_tree_type_for_biome(biome: String) -> String:
	var tree_types: Array = BIOME_TREES.get(biome, BIOME_TREES["valley"])
	return tree_types[rng.randi() % tree_types.size()]


func _get_tree_density_for_biome(biome: String) -> float:
	return BIOME_TREE_DENSITY.get(biome, 1.0)


func _biome_has_grass(biome: String) -> bool:
	return BIOME_HAS_GRASS.get(biome, true)


func _place_tree(tree_body: StaticBody3D, pos: Vector3, tree_type: String) -> void:
	var sprite: Sprite3D = tree_body.get_child(1) as Sprite3D  # Child 0 is collision, child 1 is sprite
	if not sprite:
		return

	sprite.texture = tree_textures.get(tree_type, tree_textures["oak"])
	sprite.pixel_size = 0.04 + rng.randf() * 0.02  # Bigger trees

	# Offset Y so tree base is at ground level (texture is 128 tall, centered)
	var tex_height = sprite.texture.get_height() if sprite.texture else 128
	var world_height = tex_height * sprite.pixel_size

	# Scale variation makes some trees bigger
	var scale_var = 0.9 + rng.randf() * 0.6  # Range 0.9 to 1.5
	sprite.scale = Vector3.ONE * scale_var

	# Position sprite relative to body
	sprite.position = Vector3(0, world_height * 0.48 * scale_var, 0)

	# Position the tree body at ground level
	tree_body.position = pos

	# Random rotation (rotate the body, not the sprite, since sprite is billboard)
	tree_body.rotation.y = rng.randf() * TAU

	# Reset health
	tree_health[tree_body.get_instance_id()] = TREE_MAX_HEALTH

	# Update collision shape based on scale
	var collision: CollisionShape3D = tree_body.get_child(0) as CollisionShape3D
	if collision and collision.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision.shape
		capsule.radius = 0.4 * scale_var
		capsule.height = 3.0 * scale_var
		collision.position = Vector3(0, 1.5 * scale_var, 0)

	tree_body.visible = true


# Biome rock colors
const BIOME_ROCK_COLORS: Dictionary = {
	"valley": Color(0.6, 0.58, 0.55),
	"dark_forest": Color(0.3, 0.35, 0.3),
	"swamp": Color(0.4, 0.38, 0.32),
	"mountain": Color(0.75, 0.78, 0.82),  # Light grey/white
	"desert": Color(0.85, 0.75, 0.55),  # Sandy
	"wizardland": Color(0.6, 0.4, 0.7),  # Purple tinted
	"hell": Color(0.4, 0.2, 0.15),  # Dark red/black
}

# Biome grass colors
const BIOME_GRASS_COLORS: Dictionary = {
	"valley": Color(0.3, 0.6, 0.3),
	"dark_forest": Color(0.1, 0.25, 0.15),
	"swamp": Color(0.4, 0.5, 0.25),
	"wizardland": Color(0.6, 0.3, 0.7),
}


func _place_rock(sprite: Sprite3D, pos: Vector3, biome: String = "valley") -> void:
	# Bigger rocks
	sprite.pixel_size = 0.04
	var scale_var = 0.6 + rng.randf() * 1.2  # Range 0.6 to 1.8
	sprite.scale = Vector3.ONE * scale_var

	# Tint rock based on biome
	var rock_color: Color = BIOME_ROCK_COLORS.get(biome, BIOME_ROCK_COLORS["valley"])
	sprite.modulate = rock_color.lightened(rng.randf() * 0.2 - 0.1)

	# Rock sits on ground
	var rock_height = 48 * sprite.pixel_size * scale_var
	sprite.position = pos + Vector3(0, rock_height * 0.25, 0)

	sprite.rotation.y = rng.randf() * TAU
	sprite.visible = true


## Damage a tree - call this when tree is hit by spell/attack
func damage_tree(tree_body: StaticBody3D, damage: float) -> void:
	var tree_id = tree_body.get_instance_id()
	if tree_id not in tree_health:
		tree_health[tree_id] = TREE_MAX_HEALTH

	tree_health[tree_id] -= damage

	# Visual feedback - flash white
	var sprite: Sprite3D = tree_body.get_child(1) as Sprite3D
	if sprite:
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color(1.0, 1.0, 1.0)

	# Check if tree is destroyed
	if tree_health[tree_id] <= 0:
		_destroy_tree(tree_body)


## Destroy a tree with falling animation
func _destroy_tree(tree_body: StaticBody3D) -> void:
	if not is_instance_valid(tree_body):
		return

	# Disable collision immediately
	tree_body.collision_layer = 0

	var sprite: Sprite3D = tree_body.get_child(1) as Sprite3D
	if sprite:
		# Fall over animation
		var fall_direction = randf() * TAU  # Random fall direction
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "rotation:x", -PI/2, 0.5).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "position:y", 0.2, 0.5)
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0).set_delay(0.5)
		tween.chain().tween_callback(func():
			if is_instance_valid(tree_body):
				tree_body.visible = false
				# Return to pool (reset for reuse)
				tree_health[tree_body.get_instance_id()] = TREE_MAX_HEALTH
				tree_body.collision_layer = TREE_COLLISION_LAYER
		)
	else:
		tree_body.visible = false


## Static method to find and damage a tree by its body
static func find_tree_spawner() -> EnvironmentSpawner:
	var spawners = Engine.get_main_loop().root.get_tree().get_nodes_in_group("environment_spawner")
	if spawners.size() > 0:
		return spawners[0] as EnvironmentSpawner
	return null


func _place_grass(sprite: Sprite3D, pos: Vector3, biome: String = "valley") -> void:
	sprite.pixel_size = 0.02
	var scale_var = 0.7 + rng.randf() * 0.9  # Range 0.7 to 1.6
	sprite.scale = Vector3.ONE * scale_var

	# Tint grass based on biome
	var grass_color: Color = BIOME_GRASS_COLORS.get(biome, BIOME_GRASS_COLORS["valley"])
	sprite.modulate = grass_color.lightened(rng.randf() * 0.3 - 0.15)

	var grass_height = 48 * sprite.pixel_size * scale_var
	sprite.position = pos + Vector3(0, grass_height * 0.35, 0)

	sprite.rotation.y = rng.randf() * TAU
	sprite.visible = true
