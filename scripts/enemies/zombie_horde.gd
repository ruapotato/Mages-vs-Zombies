extends Node3D
class_name ZombieHorde

## ZombieHorde - Centralized zombie manager for performance and wave spawning
## Handles batch processing, LOD system, wave difficulty scaling, and night mechanics
## CRITICAL: Zombies are MUCH stronger and more numerous at night!

signal wave_started(wave_number: int, zombie_count: int)
signal wave_completed(wave_number: int)
signal zombie_spawned(zombie: Node3D)
signal zombie_died(zombie: Node3D, killer_id: int, is_headshot: bool)
signal all_zombies_defeated()

# Wave configuration
@export_group("Wave Settings")
@export var enable_waves: bool = true
@export var wave_interval: float = 30.0  # 30 seconds between waves
@export var first_wave_delay: float = 5.0  # Start first wave after 5 seconds
@export var base_zombies_per_wave: int = 5
@export var zombies_per_wave_increase: int = 2
@export var max_active_zombies: int = 50

# Spawn configuration
@export_group("Spawn Settings")
@export var spawn_radius_min: float = 20.0
@export var spawn_radius_max: float = 40.0
@export var night_spawn_multiplier: float = 2.0  # 2x more zombies at night!
@export var night_spawn_rate_multiplier: float = 1.5  # Spawn 50% faster at night
@export var spawn_height_offset: float = 1.0

# LOD (Level of Detail) settings - from original implementation
@export_group("LOD Settings")
@export var lod_distance_medium: float = 30.0  # Simplified AI
@export var lod_distance_far: float = 60.0  # Minimal AI
@export var lod_update_interval: float = 0.5  # Update LOD every 0.5 seconds
const LOD_PHYSICS_DIST := 20.0  # Use physics within this range
const LOD_FAR_DIST := 50.0  # Direct teleport beyond this
const MAX_PHYSICS_ZOMBIES := 100  # Only do physics for this many
const MAX_ANIMATED_ZOMBIES := 400  # Billboard animation is very cheap

# Difficulty scaling
@export_group("Difficulty Scaling")
@export var enable_difficulty_scaling: bool = true
@export var difficulty_scale_per_day: float = 0.1  # 10% stronger per game day
@export var max_difficulty_multiplier: float = 3.0

# Zombie type probabilities (must add to 1.0)
@export_group("Zombie Types")
@export var walker_probability: float = 0.5  # 50%
@export var runner_probability: float = 0.25  # 25%
@export var brute_probability: float = 0.15  # 15%
@export var mage_probability: float = 0.07  # 7%
@export var exploder_probability: float = 0.03  # 3%

# Internal state
var all_zombies: Array[Node3D] = []
var zombie_data: Dictionary = {}  # zombie -> {target, path_timer, sync_timer, etc}
var current_wave: int = 0
var wave_timer: float = 0.0
var is_wave_active: bool = false
var zombies_to_spawn: int = 0
var spawn_cooldown: float = 0.0
const SPAWN_INTERVAL: float = 1.0  # Spawn one zombie per second

# Batch processing state
var path_batch_index: int = 0
var sync_batch_index: int = 0
const PATH_UPDATE_BATCH := 20  # How many path updates per frame
const TARGET_UPDATE_INTERVAL := 0.5  # How often to recalculate targets
const SYNC_BATCH_SIZE := 25  # How many zombies to sync per frame
var target_update_timer: float = 0.0

var lod_update_timer: float = 0.0
var current_day: int = 0
var difficulty_multiplier: float = 1.0

# Cached player data (updated once per frame)
var cached_players: Array[Node3D] = []
var cached_player_positions: Array[Vector3] = []
var cached_player_forward: Vector3 = Vector3.FORWARD  # Camera direction for culling
var cached_camera: Camera3D = null
var player: Node3D = null

# Performance counters
var physics_this_frame: int = 0  # Counter for physics limit
var animated_this_frame: int = 0  # Counter for animation limit

# Zombie type scenes (preloaded)
var zombie_types: Dictionary = {}

# Performance metrics
var total_zombies_spawned: int = 0
var total_zombies_killed: int = 0

# References
var zombies_container: Node3D
var game_controller: Node3D

func _ready() -> void:
	add_to_group("zombie_horde")

	# Only server runs horde AI in multiplayer
	if multiplayer and not multiplayer.is_server():
		set_physics_process(false)
		return

	# Find player
	call_deferred("_find_player")

	# Load zombie type scenes
	_load_zombie_types()

	# Start wave timer (use first_wave_delay for the first wave)
	if enable_waves:
		wave_timer = first_wave_delay
		print("[ZombieHorde] First wave in %.1f seconds" % first_wave_delay)

	# Connect to day/night cycle for difficulty updates
	if DayNightCycle:
		DayNightCycle.period_changed.connect(_on_period_changed)

func initialize(container: Node3D, controller: Node3D) -> void:
	zombies_container = container
	game_controller = controller

	# Connect to container child signals
	if zombies_container:
		zombies_container.child_entered_tree.connect(_on_zombie_added)
		zombies_container.child_exiting_tree.connect(_on_zombie_removed)

		# Register existing zombies
		for child in zombies_container.get_children():
			_on_zombie_added(child)

func _on_zombie_added(node: Node) -> void:
	if not node is CharacterBody3D:
		return

	var zombie := node as Node3D
	all_zombies.append(zombie)

	# Assign initial target immediately if we have players
	var initial_target: Node3D = null
	if cached_players.size() > 0:
		initial_target = cached_players[randi() % cached_players.size()]
	elif player:
		initial_target = player

	# Initialize zombie data with staggered timers
	zombie_data[zombie] = {
		"target": initial_target,
		"path_timer": randf() * 0.5,  # Staggered path updates
		"sync_timer": randf() * 0.15,  # Staggered network sync
		"stuck_timer": 0.0,
		"last_pos": zombie.global_position,
	}

	# Disable the zombie's own physics processing - horde controls it now
	if zombie.has_method("set_horde_controlled"):
		zombie.set_horde_controlled(true)

	# Set to chasing state immediately if it has a target
	if initial_target and "state" in zombie:
		zombie.set("state", 2)  # CHASING

	# Connect died signal
	if zombie.has_signal("died"):
		zombie.died.connect(_on_zombie_died.bind(zombie))

func _on_zombie_removed(node: Node) -> void:
	if node in all_zombies:
		all_zombies.erase(node)
		zombie_data.erase(node)

func _physics_process(delta: float) -> void:
	# Wave spawning
	if enable_waves:
		_process_wave_spawning(delta)

	# Spawn queued zombies
	if zombies_to_spawn > 0:
		spawn_cooldown -= delta
		if spawn_cooldown <= 0:
			var spawn_interval = SPAWN_INTERVAL
			if DayNightCycle and DayNightCycle.is_night():
				spawn_interval /= night_spawn_rate_multiplier

			spawn_cooldown = spawn_interval
			_spawn_random_zombie()
			zombies_to_spawn -= 1

	# Clean up dead/invalid zombies from tracking
	_cleanup_dead_zombies()

	# === Batch processing for active zombies ===
	if all_zombies.is_empty():
		return

	# Cache player data once per frame
	_update_player_cache()

	# Update targets periodically (not every frame)
	target_update_timer -= delta
	if target_update_timer <= 0:
		target_update_timer = TARGET_UPDATE_INTERVAL
		_update_all_targets()

	# Update LOD for all zombies periodically
	lod_update_timer += delta
	if lod_update_timer >= lod_update_interval:
		lod_update_timer = 0.0
		_update_all_zombie_lod()

	# Process zombies in batches for pathfinding
	_process_path_batch(delta)

	# Process ALL zombies for movement (this is fast)
	_process_all_movement(delta)

	# Batch sync to clients (if multiplayer)
	if multiplayer:
		_process_sync_batch()

func _process_wave_spawning(delta: float) -> void:
	if is_wave_active:
		# Wait for all zombies to be defeated
		if all_zombies.size() == 0 and zombies_to_spawn == 0:
			_complete_wave()
	else:
		# Count down to next wave
		wave_timer -= delta
		if wave_timer <= 0:
			_start_wave()

func _start_wave() -> void:
	current_wave += 1
	is_wave_active = true

	# Calculate zombies for this wave
	var base_count = base_zombies_per_wave + (current_wave - 1) * zombies_per_wave_increase

	# Apply night multiplier if it's night - MAKE NIGHT SCARY!
	if DayNightCycle and DayNightCycle.is_night():
		base_count = int(base_count * night_spawn_multiplier)

	# Cap at max active zombies
	zombies_to_spawn = min(base_count, max_active_zombies)

	print("[ZombieHorde] Wave %d started! Spawning %d zombies%s" % [
		current_wave,
		zombies_to_spawn,
		" (NIGHT WAVE - 2X ZOMBIES!)" if (DayNightCycle and DayNightCycle.is_night()) else ""
	])
	emit_signal("wave_started", current_wave, zombies_to_spawn)

func _complete_wave() -> void:
	is_wave_active = false
	wave_timer = wave_interval

	print("[ZombieHorde] Wave %d completed!" % current_wave)
	emit_signal("wave_completed", current_wave)

	# Check if all zombies ever spawned are defeated
	if total_zombies_killed == total_zombies_spawned:
		emit_signal("all_zombies_defeated")

func _spawn_random_zombie():  # -> ZombieBase
	if not player or not is_instance_valid(player):
		_find_player()
		if not player:
			return null

	# Find spawn position FIRST before creating zombie
	var spawn_pos = _get_random_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return null

	# Determine zombie type based on probabilities
	var zombie_type = _roll_zombie_type()
	var zombie = _create_zombie(zombie_type)

	if not zombie:
		return null

	# Add to scene FIRST (before setting position to avoid !is_inside_tree error)
	if zombies_container:
		zombies_container.add_child(zombie)
	else:
		add_child(zombie)

	# Now set position (zombie is in tree)
	zombie.global_position = spawn_pos

	# Apply difficulty scaling
	if enable_difficulty_scaling:
		_apply_difficulty_scaling(zombie)

	# Track zombie (will be done by _on_zombie_added if using container)
	if not zombies_container:
		all_zombies.append(zombie)
		total_zombies_spawned += 1
		zombie.died.connect(_on_zombie_died.bind(zombie))

	emit_signal("zombie_spawned", zombie)

	return zombie

func _create_zombie(zombie_type: String):  # -> ZombieBase
	if not zombie_types.has(zombie_type):
		return null

	var zombie_scene = zombie_types[zombie_type]
	if not zombie_scene:
		return null

	var zombie = zombie_scene.instantiate()
	return zombie

func _roll_zombie_type() -> String:
	var roll = randf()
	var cumulative = 0.0

	# Check each type in order
	cumulative += walker_probability
	if roll < cumulative:
		return "walker"

	cumulative += runner_probability
	if roll < cumulative:
		return "runner"

	cumulative += brute_probability
	if roll < cumulative:
		return "brute"

	cumulative += mage_probability
	if roll < cumulative:
		return "mage"

	cumulative += exploder_probability
	if roll < cumulative:
		return "exploder"

	# Fallback to walker
	return "walker"

func _get_random_spawn_position() -> Vector3:
	if not player:
		return Vector3.ZERO

	var attempts = 0
	var max_attempts = 20

	while attempts < max_attempts:
		# Random angle
		var angle = randf() * TAU
		# Random distance
		var distance = randf_range(spawn_radius_min, spawn_radius_max)

		# Calculate position
		var offset = Vector3(
			cos(angle) * distance,
			spawn_height_offset,
			sin(angle) * distance
		)

		var spawn_pos = player.global_position + offset

		# Check if position is valid (raycast to find ground)
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			spawn_pos + Vector3.UP * 10,
			spawn_pos + Vector3.DOWN * 20
		)
		query.collision_mask = 1  # World layer

		var result = space_state.intersect_ray(query)
		if result:
			# Found ground, spawn slightly above it
			return result.position + Vector3.UP * spawn_height_offset

		attempts += 1

	# If no valid position found, spawn at a fallback position
	return player.global_position + Vector3.FORWARD * spawn_radius_min + Vector3.UP * spawn_height_offset

func _apply_difficulty_scaling(zombie) -> void:  # ZombieBase
	# Calculate difficulty based on current day
	if DayNightCycle:
		# Estimate current day from game time
		current_day = int(DayNightCycle.current_hour / 24.0)

	difficulty_multiplier = 1.0 + (current_day * difficulty_scale_per_day)
	difficulty_multiplier = min(difficulty_multiplier, max_difficulty_multiplier)

	# Scale zombie stats
	zombie.base_health *= difficulty_multiplier
	zombie.base_damage *= difficulty_multiplier
	# Don't scale speed too much, just a bit
	zombie.base_speed *= (1.0 + (difficulty_multiplier - 1.0) * 0.3)

	# Reinitialize zombie with new stats
	zombie.max_health = zombie.base_health * (zombie.night_health_multiplier if zombie.is_night_time else 1.0)
	zombie.current_health = zombie.max_health
	zombie.current_speed = zombie.base_speed * (zombie.night_speed_multiplier if zombie.is_night_time else 1.0)
	zombie.current_damage = zombie.base_damage * (zombie.night_damage_multiplier if zombie.is_night_time else 1.0)

func _update_player_cache() -> void:
	cached_players.clear()
	cached_player_positions.clear()

	# Get camera for frustum culling
	cached_camera = get_viewport().get_camera_3d()
	if cached_camera:
		cached_player_forward = -cached_camera.global_transform.basis.z

	if game_controller:
		var players_node := game_controller.get_node_or_null("Players")
		if players_node:
			for p in players_node.get_children():
				cached_players.append(p)
				cached_player_positions.append(p.global_position)
			if cached_players.size() > 0 and not player:
				player = cached_players[0]
			return

	# Fallback: find players in tree
	if not player:
		_find_player()

	if player:
		cached_players.append(player)
		cached_player_positions.append(player.global_position)

func _update_all_targets() -> void:
	if cached_players.is_empty():
		return

	for zombie in all_zombies:
		if not is_instance_valid(zombie):
			continue

		var data: Dictionary = zombie_data.get(zombie, {})
		if data.is_empty():
			continue

		# Find nearest player
		var zombie_pos := zombie.global_position
		var nearest_player: Node3D = null
		var nearest_dist := INF

		for i in cached_players.size():
			var dist := zombie_pos.distance_squared_to(cached_player_positions[i])
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_player = cached_players[i]

		data["target"] = nearest_player

		# Update zombie's target_player if it has that property
		if "target_player" in zombie and nearest_player:
			zombie.target_player = nearest_player

func _update_all_zombie_lod() -> void:
	if cached_players.is_empty():
		return

	var player_pos = cached_player_positions[0] if cached_player_positions.size() > 0 else Vector3.ZERO

	for zombie in all_zombies:
		if not is_instance_valid(zombie):
			continue

		var distance = player_pos.distance_to(zombie.global_position)

		if zombie.has_method("set_lod_level"):
			if distance > lod_distance_far:
				zombie.set_lod_level(2, distance)  # Minimal detail
			elif distance > lod_distance_medium:
				zombie.set_lod_level(1, distance)  # Medium detail
			else:
				zombie.set_lod_level(0, distance)  # Full detail

func _process_path_batch(delta: float) -> void:
	if all_zombies.is_empty():
		return

	# Process a batch of zombies for path updates
	var batch_end := mini(path_batch_index + PATH_UPDATE_BATCH, all_zombies.size())
	var processed := 0

	for i in range(path_batch_index, batch_end):
		var zombie := all_zombies[i]
		if not is_instance_valid(zombie):
			continue

		var data: Dictionary = zombie_data.get(zombie, {})
		if data.is_empty():
			continue

		var target: Node3D = data.get("target")
		if not target or not is_instance_valid(target):
			continue

		# Skip path updates for far zombies - they use direct movement anyway
		var dist_sq := zombie.global_position.distance_squared_to(target.global_position)
		if dist_sq > LOD_PHYSICS_DIST * LOD_PHYSICS_DIST:
			continue

		# Update path timer
		data["path_timer"] -= delta * PATH_UPDATE_BATCH

		if data["path_timer"] <= 0:
			data["path_timer"] = 0.4 + randf() * 0.3  # 0.4-0.7 second updates

			var nav_agent: NavigationAgent3D = zombie.get_node_or_null("NavigationAgent3D")
			if nav_agent:
				nav_agent.target_position = target.global_position
				processed += 1

				# Limit actual nav updates per frame
				if processed >= 10:
					break

	# Advance batch index
	path_batch_index = batch_end
	if path_batch_index >= all_zombies.size():
		path_batch_index = 0

func _process_all_movement(delta: float) -> void:
	physics_this_frame = 0
	animated_this_frame = 0

	# Ensure all zombies have data entries
	for zombie in all_zombies:
		if not is_instance_valid(zombie):
			continue

		if zombie not in zombie_data:
			zombie_data[zombie] = {
				"target": player if player else null,
				"path_timer": randf() * 0.5,
				"sync_timer": randf() * 0.15,
				"stuck_timer": 0.0,
				"last_pos": zombie.global_position,
			}

		var data: Dictionary = zombie_data[zombie]
		if cached_players.size() > 0:
			if not data.get("target") or not is_instance_valid(data.get("target")):
				data["target"] = cached_players[0]

	for zombie in all_zombies:
		if not is_instance_valid(zombie):
			continue

		# Skip dead/dying zombies
		var state: int = zombie.get("current_state") if "current_state" in zombie else 0
		if state >= 4:  # DYING=4 or DEAD=5
			continue

		var data: Dictionary = zombie_data.get(zombie, {})
		if data.is_empty():
			continue

		var target: Node3D = data.get("target")
		if not target or not is_instance_valid(target):
			if cached_players.size() > 0:
				target = cached_players[0]
				data["target"] = target
			else:
				continue

		# Let the zombie handle its own movement if it's not horde-controlled
		if not zombie.has_method("set_horde_controlled"):
			continue

		# Calculate distance to target for LOD
		var dist_sq := zombie.global_position.distance_squared_to(target.global_position)
		var direction := target.global_position - zombie.global_position
		direction.y = 0
		if direction.length_squared() > 0.01:
			direction = direction.normalized()
		else:
			continue

		var speed: float = zombie.get("current_speed") if "current_speed" in zombie else 3.0

		# Check visibility
		var is_visible := _is_zombie_visible(zombie)

		# If not visible, teleport for performance
		if not is_visible and dist_sq > 400.0:  # > 20 units away
			var new_pos := zombie.global_position + direction * speed * delta
			new_pos.y = target.global_position.y
			zombie.global_position = new_pos
			_set_zombie_visible(zombie, false)
			continue

		_set_zombie_visible(zombie, true)

		# Determine processing level
		var use_physics := dist_sq < LOD_PHYSICS_DIST * LOD_PHYSICS_DIST and physics_this_frame < MAX_PHYSICS_ZOMBIES

		if dist_sq > LOD_FAR_DIST * LOD_FAR_DIST:
			# Very far: teleport faster
			var new_pos := zombie.global_position + direction * speed * delta * 1.3
			new_pos.y = target.global_position.y
			zombie.global_position = new_pos
		elif use_physics and zombie.has_method("move_and_slide"):
			# Close: use proper physics
			zombie.velocity.x = direction.x * speed
			zombie.velocity.z = direction.z * speed
			if not zombie.is_on_floor():
				zombie.velocity.y -= 20.0 * delta
			zombie.move_and_slide()
			physics_this_frame += 1
		else:
			# Medium: simple teleport
			var new_pos := zombie.global_position + direction * speed * delta
			zombie.global_position = new_pos

		# Update animation if under limit
		if animated_this_frame < MAX_ANIMATED_ZOMBIES:
			if zombie.has_method("update_animation_from_velocity"):
				zombie.update_animation_from_velocity()
			animated_this_frame += 1

func _set_zombie_visible(zombie: Node3D, vis: bool) -> void:
	var sprite: Sprite3D = zombie.get_node_or_null("Sprite3D")
	if sprite and sprite.visible != vis:
		sprite.visible = vis

func _is_zombie_visible(zombie: Node3D) -> bool:
	if not cached_camera or cached_player_positions.is_empty():
		return true

	var cam_pos := cached_camera.global_position
	var to_zombie := zombie.global_position - cam_pos

	# Always visible if close
	if to_zombie.length_squared() < 100.0:
		return true

	var dot := to_zombie.normalized().dot(cached_player_forward)
	return dot > -0.5  # Hide if more than 120 degrees behind camera

func _process_sync_batch() -> void:
	if all_zombies.is_empty():
		return

	var batch_end := mini(sync_batch_index + SYNC_BATCH_SIZE, all_zombies.size())

	for i in range(sync_batch_index, batch_end):
		var zombie := all_zombies[i]
		if not is_instance_valid(zombie):
			continue

		# Call the zombie's sync RPC (skip dead/dying zombies)
		if zombie.has_method("_sync_state"):
			var state = zombie.get("current_state") if "current_state" in zombie else 0
			if int(state) < 4:
				zombie.rpc("_sync_state", zombie.global_position, zombie.rotation.y, zombie.velocity, int(state))

	sync_batch_index = batch_end
	if sync_batch_index >= all_zombies.size():
		sync_batch_index = 0

func _cleanup_dead_zombies() -> void:
	var valid_zombies: Array[Node3D] = []
	for zombie in all_zombies:
		if is_instance_valid(zombie):
			var state = zombie.get("current_state") if "current_state" in zombie else 0
			if state != 5:  # Not DEAD
				valid_zombies.append(zombie)

	all_zombies = valid_zombies

func _on_zombie_died(zombie) -> void:  # ZombieBase
	total_zombies_killed += 1

	# Emit signal with default values if not multiplayer
	zombie_died.emit(zombie, 0, false)

	# Remove from active tracking
	var idx = all_zombies.find(zombie)
	if idx >= 0:
		all_zombies.remove_at(idx)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("local_player")
	if players.size() == 0:
		players = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player = players[0]
		print("[ZombieHorde] Found player: %s" % player.name)

func _load_zombie_types() -> void:
	var walker_path = "res://scenes/enemies/zombie_walker.tscn"
	var runner_path = "res://scenes/enemies/zombie_runner.tscn"
	var brute_path = "res://scenes/enemies/zombie_brute.tscn"
	var mage_path = "res://scenes/enemies/zombie_mage.tscn"
	var exploder_path = "res://scenes/enemies/zombie_exploder.tscn"
	var base_path = "res://scenes/enemies/zombie.tscn"

	# Try to load each type, fallback to base
	zombie_types["walker"] = _try_load_scene(walker_path, base_path)
	zombie_types["runner"] = _try_load_scene(runner_path, base_path)
	zombie_types["brute"] = _try_load_scene(brute_path, base_path)
	zombie_types["mage"] = _try_load_scene(mage_path, base_path)
	zombie_types["exploder"] = _try_load_scene(exploder_path, base_path)

	print("[ZombieHorde] Loaded %d zombie type scenes" % zombie_types.size())

func _try_load_scene(primary_path: String, fallback_path: String) -> PackedScene:
	if ResourceLoader.exists(primary_path):
		return load(primary_path)
	elif ResourceLoader.exists(fallback_path):
		return load(fallback_path)
	return null

func _on_period_changed(period: String) -> void:
	if period == "night":
		print("[ZombieHorde] NIGHT HAS FALLEN! Zombies are now 2X stronger, 1.5X faster, with 50% more health!")
		print("[ZombieHorde] Waves will spawn 2X MORE zombies! SEEK SHELTER!")
	elif period == "day":
		print("[ZombieHorde] Daybreak! Zombies return to normal strength.")

## Manual spawn function (for testing or special events)
func spawn_zombies(count: int, zombie_type: String = "") -> void:
	for i in range(count):
		if zombie_type == "":
			zombies_to_spawn += 1
		else:
			var zombie = _create_zombie(zombie_type)
			if zombie:
				var spawn_pos = _get_random_spawn_position()
				zombie.global_position = spawn_pos
				if zombies_container:
					zombies_container.add_child(zombie)
				else:
					add_child(zombie)
				if not zombies_container:
					all_zombies.append(zombie)
					zombie.died.connect(_on_zombie_died.bind(zombie))
					total_zombies_spawned += 1

## Clear all zombies (for testing or game reset)
func clear_all_zombies() -> void:
	for zombie in all_zombies:
		if is_instance_valid(zombie):
			zombie.queue_free()

	all_zombies.clear()
	zombie_data.clear()
	zombies_to_spawn = 0
	is_wave_active = false

## Get statistics
func get_stats() -> Dictionary:
	return {
		"active_zombies": all_zombies.size(),
		"queued_spawns": zombies_to_spawn,
		"current_wave": current_wave,
		"is_wave_active": is_wave_active,
		"total_spawned": total_zombies_spawned,
		"total_killed": total_zombies_killed,
		"difficulty_multiplier": difficulty_multiplier,
		"current_day": current_day,
		"is_night": DayNightCycle.is_night() if DayNightCycle else false
	}

func get_zombie_count() -> int:
	return all_zombies.size()
