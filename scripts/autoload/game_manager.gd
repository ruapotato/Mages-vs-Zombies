extends Node
## Game Manager - Central game state and coordination
## Handles game flow, player stats, zombie spawning, and night danger mechanics

signal game_started
signal game_over(survived_days: int)
signal day_changed(day_number: int)
signal night_danger_level_changed(level: float)
signal zombie_killed(zombie_type: String, position: Vector3)
signal player_died
signal shelter_entered
signal shelter_exited

# Game state
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.MENU
var current_day: int = 1
var zombies_killed: int = 0
var total_play_time: float = 0.0

# Night danger system - zombies are MUCH more dangerous at night
var is_night: bool = false
var night_danger_multiplier: float = 1.0
const NIGHT_DAMAGE_MULT: float = 2.0  # Zombies deal 2x damage at night
const NIGHT_SPEED_MULT: float = 1.5   # Zombies move 1.5x faster at night
const NIGHT_HEALTH_MULT: float = 1.5  # Zombies have 50% more health at night
const NIGHT_SPAWN_MULT: float = 3.0   # 3x more zombies spawn at night

# Player stats
var player_health: float = 100.0
var player_max_health: float = 100.0
var player_mana: float = 100.0
var player_max_mana: float = 100.0
var mana_regen_rate: float = 5.0  # Per second

# Shelter system
var player_in_shelter: bool = false
var shelter_protection: float = 0.0  # 0-1, reduces zombie aggro and spawns

# References
var player: Node = null
var terrain_world: Node = null
var zombie_horde: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect to day/night cycle when available
	if has_node("/root/DayNightCycle"):
		var dnc = get_node("/root/DayNightCycle")
		if dnc.has_signal("night_began"):
			dnc.night_began.connect(_on_night_began)
		if dnc.has_signal("day_began"):
			dnc.day_began.connect(_on_day_began)
		if dnc.has_signal("new_day"):
			dnc.new_day.connect(_on_new_day)

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		total_play_time += delta

		# Regenerate mana
		if player_mana < player_max_mana:
			player_mana = min(player_mana + mana_regen_rate * delta, player_max_mana)

func start_game() -> void:
	current_state = GameState.PLAYING
	current_day = 1
	zombies_killed = 0
	total_play_time = 0.0
	player_health = player_max_health
	player_mana = player_max_mana
	is_night = false
	night_danger_multiplier = 1.0
	game_started.emit()
	print("[GameManager] Game started!")

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false

func end_game() -> void:
	current_state = GameState.GAME_OVER
	game_over.emit(current_day)
	print("[GameManager] Game Over! Survived %d days, killed %d zombies" % [current_day, zombies_killed])

# Night danger system
func _on_night_began() -> void:
	is_night = true
	night_danger_multiplier = 1.0
	_update_night_danger()
	print("[GameManager] NIGHT HAS FALLEN - Zombies are now DANGEROUS!")

func _on_day_began() -> void:
	is_night = false
	night_danger_multiplier = 1.0
	night_danger_level_changed.emit(1.0)
	print("[GameManager] Day has broken - zombies weakened")

func _on_new_day(day_num: int) -> void:
	current_day = day_num
	day_changed.emit(day_num)
	print("[GameManager] Day %d" % day_num)

func _update_night_danger() -> void:
	if is_night:
		# Base night danger
		night_danger_multiplier = 1.0

		# Reduce danger if in shelter
		if player_in_shelter:
			night_danger_multiplier *= (1.0 - shelter_protection * 0.8)

		night_danger_level_changed.emit(night_danger_multiplier)

# Get current zombie stat multipliers
func get_zombie_damage_multiplier() -> float:
	if is_night:
		return NIGHT_DAMAGE_MULT * night_danger_multiplier
	return 1.0

func get_zombie_speed_multiplier() -> float:
	if is_night:
		return NIGHT_SPEED_MULT * night_danger_multiplier
	return 1.0

func get_zombie_health_multiplier() -> float:
	if is_night:
		return NIGHT_HEALTH_MULT * night_danger_multiplier
	return 1.0

func get_zombie_spawn_multiplier() -> float:
	if is_night:
		return NIGHT_SPAWN_MULT * night_danger_multiplier
	return 1.0

# Shelter system
func enter_shelter(protection_level: float = 1.0) -> void:
	player_in_shelter = true
	shelter_protection = clamp(protection_level, 0.0, 1.0)
	shelter_entered.emit()
	_update_night_danger()
	print("[GameManager] Entered shelter (protection: %.0f%%)" % (shelter_protection * 100))

func exit_shelter() -> void:
	player_in_shelter = false
	shelter_protection = 0.0
	shelter_exited.emit()
	_update_night_danger()
	print("[GameManager] Left shelter - EXPOSED!")

# Combat
func on_zombie_killed(zombie_type: String, position: Vector3) -> void:
	zombies_killed += 1
	zombie_killed.emit(zombie_type, position)

func damage_player(amount: float) -> void:
	player_health -= amount
	if player_health <= 0:
		player_health = 0
		player_died.emit()
		end_game()

func heal_player(amount: float) -> void:
	player_health = min(player_health + amount, player_max_health)

func use_mana(amount: float) -> bool:
	if player_mana >= amount:
		player_mana -= amount
		return true
	return false

func restore_mana(amount: float) -> void:
	player_mana = min(player_mana + amount, player_max_mana)

# Utility
func get_difficulty_scale() -> float:
	# Difficulty increases each day
	return 1.0 + (current_day - 1) * 0.15

func is_playing() -> bool:
	return current_state == GameState.PLAYING

# Player registration (for multiplayer)
var registered_players: Dictionary = {}  # peer_id -> player_node

func register_player(peer_id: int, player_node: Node) -> void:
	registered_players[peer_id] = player_node
	print("[GameManager] Registered player %d" % peer_id)

func unregister_player(peer_id: int) -> void:
	if peer_id in registered_players:
		registered_players.erase(peer_id)
		print("[GameManager] Unregistered player %d" % peer_id)
