extends Node
## Game Controller - Wires together all game systems
## Connects player to terrain, manages zombie spawning based on day/night

@onready var terrain_world: Node3D = $"../TerrainWorld"
@onready var zombie_horde: Node3D = $"../ZombieHorde"
@onready var player: Node3D = $"../Player"

var game_manager: Node
var day_night_cycle: Node
var weather_manager: Node

# Track if player has been placed on terrain
var player_placed: bool = false

func _ready() -> void:
	# Get autoload references
	game_manager = get_node_or_null("/root/GameManager")
	day_night_cycle = get_node_or_null("/root/DayNightCycle")
	weather_manager = get_node_or_null("/root/WeatherManager")

	# Wait a frame for all nodes to be ready
	await get_tree().process_frame

	_setup_terrain()
	_setup_zombies()
	_setup_game_state()
	_connect_signals()

	print("[GameController] All systems initialized!")


func _setup_terrain() -> void:
	if terrain_world and player:
		# Disable player physics until terrain is ready
		player.set_physics_process(false)
		if "velocity" in player:
			player.velocity = Vector3.ZERO

		# Register player with terrain for chunk loading
		if terrain_world.has_method("add_tracked_player"):
			terrain_world.add_tracked_player(player)
			print("[GameController] Player registered with terrain system")

		# Connect to terrain_ready signal
		if terrain_world.has_signal("terrain_ready"):
			terrain_world.terrain_ready.connect(_on_terrain_ready)

		print("[GameController] Waiting for terrain to generate...")


func _setup_zombies() -> void:
	if zombie_horde and player:
		# Set player as target for zombies
		if zombie_horde.has_method("set_player_target"):
			zombie_horde.set_player_target(player)
		elif "player_target" in zombie_horde:
			zombie_horde.player_target = player

		# Set spawn enabled based on game state
		if "spawn_enabled" in zombie_horde:
			zombie_horde.spawn_enabled = true

		print("[GameController] Zombie horde targeting player")


func _setup_game_state() -> void:
	if game_manager:
		game_manager.player = player
		game_manager.terrain_world = terrain_world
		game_manager.zombie_horde = zombie_horde
		game_manager.start_game()


func _connect_signals() -> void:
	# Connect day/night cycle to zombie horde
	if day_night_cycle:
		if day_night_cycle.has_signal("night_began"):
			day_night_cycle.night_began.connect(_on_night_began)
		if day_night_cycle.has_signal("day_began"):
			day_night_cycle.day_began.connect(_on_day_began)

	# Connect game manager signals
	if game_manager:
		if game_manager.has_signal("player_died"):
			game_manager.player_died.connect(_on_player_died)
		if game_manager.has_signal("game_over"):
			game_manager.game_over.connect(_on_game_over)


func _on_terrain_ready() -> void:
	print("[GameController] Terrain ready signal received!")
	_place_player_on_terrain()


func _on_night_began() -> void:
	print("[GameController] NIGHT - Zombies become dangerous!")

	# Increase zombie spawn rate at night
	if zombie_horde and "spawn_rate_multiplier" in zombie_horde:
		zombie_horde.spawn_rate_multiplier = game_manager.get_zombie_spawn_multiplier() if game_manager else 3.0

	# Enable aggressive zombie behavior
	if zombie_horde and "aggressive_mode" in zombie_horde:
		zombie_horde.aggressive_mode = true


func _on_day_began() -> void:
	print("[GameController] DAY - Zombies weakened")

	# Reset zombie spawn rate
	if zombie_horde and "spawn_rate_multiplier" in zombie_horde:
		zombie_horde.spawn_rate_multiplier = 1.0

	# Disable aggressive mode
	if zombie_horde and "aggressive_mode" in zombie_horde:
		zombie_horde.aggressive_mode = false


func _on_player_died() -> void:
	print("[GameController] Player has died!")
	# Disable zombie spawning
	if zombie_horde and "spawn_enabled" in zombie_horde:
		zombie_horde.spawn_enabled = false


func _on_game_over(survived_days: int) -> void:
	print("[GameController] Game Over - Survived %d days" % survived_days)
	# Could show game over UI here


## Place player on terrain after chunks are loaded
func _place_player_on_terrain() -> void:
	if not terrain_world or not player:
		return

	if player_placed:
		return

	# Get terrain height at player's position using raycast
	var player_pos := player.global_position
	var terrain_height := _get_ground_height(Vector3(player_pos.x, 200.0, player_pos.z))

	if terrain_height < -100.0:
		# Fallback if raycast failed - use biome generator height
		var player_pos_2d := Vector2(player_pos.x, player_pos.z)
		if terrain_world.has_method("get_terrain_height"):
			terrain_height = terrain_world.get_terrain_height(player_pos_2d)
		else:
			terrain_height = 10.0

	# Place player above terrain
	var spawn_height := terrain_height + 2.0  # 2 units above terrain
	player.global_position.y = spawn_height
	if "velocity" in player:
		player.velocity = Vector3.ZERO

	# Re-enable player physics
	player.set_physics_process(true)
	player_placed = true

	print("[GameController] Player placed at height %.1f (ground: %.1f)" % [spawn_height, terrain_height])


## Get ground height using raycast
func _get_ground_height(from_pos: Vector3) -> float:
	var space_state := get_tree().root.get_world_3d().direct_space_state
	if not space_state:
		return -999.0

	var ray_origin := from_pos
	var ray_end := from_pos + Vector3.DOWN * 500.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1  # World layer

	var result := space_state.intersect_ray(query)
	if result:
		return result.position.y

	return -999.0


## Called every frame to check if player fell through world
func _process(delta: float) -> void:
	# If terrain is ready but player not yet placed, try to place them
	if not player_placed and terrain_world and terrain_world.has_method("is_terrain_ready"):
		if terrain_world.is_terrain_ready():
			_place_player_on_terrain()

	# Check if player fell through world
	if player_placed and player and player.global_position.y < -50.0:
		print("[GameController] Player fell below world, respawning...")
		_respawn_player()


## Respawn player at a safe location
func _respawn_player() -> void:
	if not player:
		return

	# Disable physics while repositioning
	player.set_physics_process(false)

	# Get terrain height at origin
	var spawn_pos := Vector2(0, 0)
	var terrain_height: float = 10.0

	if terrain_world and terrain_world.has_method("get_terrain_height"):
		terrain_height = terrain_world.get_terrain_height(spawn_pos)

	# Place player safely above terrain
	player.global_position = Vector3(spawn_pos.x, terrain_height + 2.0, spawn_pos.y)
	if "velocity" in player:
		player.velocity = Vector3.ZERO

	# Re-enable physics
	player.set_physics_process(true)

	print("[GameController] Player respawned at (0, %.1f, 0)" % (terrain_height + 2.0))
