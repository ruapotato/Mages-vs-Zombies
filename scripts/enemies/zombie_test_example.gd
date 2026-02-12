extends Node3D

## Example script showing how to use the Zombie System
## Attach this to a test scene to spawn and manage zombies

@onready var zombie_horde: ZombieHorde = $ZombieHorde

func _ready() -> void:
	# Connect signals
	if zombie_horde:
		zombie_horde.wave_started.connect(_on_wave_started)
		zombie_horde.wave_completed.connect(_on_wave_completed)
		zombie_horde.zombie_spawned.connect(_on_zombie_spawned)
		zombie_horde.zombie_died.connect(_on_zombie_died)
		zombie_horde.all_zombies_defeated.connect(_on_all_zombies_defeated)

		print("[ZombieTest] Zombie horde system initialized!")
		print("[ZombieTest] Press 1-5 to spawn specific zombie types")
		print("[ZombieTest] Press SPACE to spawn a wave manually")
		print("[ZombieTest] Press C to clear all zombies")

func _input(event: InputEvent) -> void:
	if not zombie_horde:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# Spawn walker
				print("[ZombieTest] Spawning Walker zombie")
				zombie_horde.spawn_zombies(1, "walker")

			KEY_2:
				# Spawn runner
				print("[ZombieTest] Spawning Runner zombie")
				zombie_horde.spawn_zombies(1, "runner")

			KEY_3:
				# Spawn brute
				print("[ZombieTest] Spawning Brute zombie")
				zombie_horde.spawn_zombies(1, "brute")

			KEY_4:
				# Spawn mage
				print("[ZombieTest] Spawning Mage zombie")
				zombie_horde.spawn_zombies(1, "mage")

			KEY_5:
				# Spawn exploder
				print("[ZombieTest] Spawning Exploder zombie")
				zombie_horde.spawn_zombies(1, "exploder")

			KEY_SPACE:
				# Spawn random wave
				print("[ZombieTest] Spawning random wave of 10 zombies")
				zombie_horde.spawn_zombies(10)

			KEY_C:
				# Clear all zombies
				print("[ZombieTest] Clearing all zombies")
				zombie_horde.clear_all_zombies()

			KEY_T:
				# Toggle time to test night mechanics
				if DayNightCycle:
					if DayNightCycle.is_night():
						DayNightCycle.set_time(12.0)  # Set to noon
						print("[ZombieTest] Set time to DAY (12:00)")
					else:
						DayNightCycle.set_time(0.0)  # Set to midnight
						print("[ZombieTest] Set time to NIGHT (00:00)")

			KEY_S:
				# Print stats
				_print_stats()

func _print_stats() -> void:
	if not zombie_horde:
		return

	var stats = zombie_horde.get_stats()
	print("\n=== ZOMBIE HORDE STATS ===")
	print("Active Zombies: %d" % stats.active_zombies)
	print("Queued Spawns: %d" % stats.queued_spawns)
	print("Current Wave: %d" % stats.current_wave)
	print("Wave Active: %s" % stats.is_wave_active)
	print("Total Spawned: %d" % stats.total_spawned)
	print("Total Killed: %d" % stats.total_killed)
	print("Difficulty Multiplier: %.2f" % stats.difficulty_multiplier)
	print("Current Day: %d" % stats.current_day)
	print("Is Night: %s" % stats.is_night)

	if stats.is_night:
		print("\n*** NIGHT MODE ACTIVE ***")
		print("- Zombies deal 2x damage!")
		print("- Zombies move 1.5x faster!")
		print("- Zombies have 50% more health!")
		print("- Waves spawn 2x more zombies!")

	print("========================\n")

func _on_wave_started(wave_number: int, zombie_count: int) -> void:
	var is_night = DayNightCycle.is_night() if DayNightCycle else false
	print("\n[WAVE %d STARTED] Spawning %d zombies%s\n" % [
		wave_number,
		zombie_count,
		" - NIGHT WAVE!" if is_night else ""
	])

func _on_wave_completed(wave_number: int) -> void:
	print("\n[WAVE %d COMPLETED] All zombies defeated!\n" % wave_number)

func _on_zombie_spawned(zombie: ZombieBase) -> void:
	# Optional: customize zombie on spawn
	pass

func _on_zombie_died(zombie: Node3D, killer_id: int, is_headshot: bool) -> void:
	# Optional: handle zombie death (drop loot, XP, etc.)
	pass

func _on_all_zombies_defeated() -> void:
	print("\n=== ALL ZOMBIES DEFEATED ===")
	print("Victory! All zombie waves have been cleared!")
	print("============================\n")

## Example: Custom spawn pattern
func spawn_boss_wave() -> void:
	if not zombie_horde:
		return

	print("[ZombieTest] Spawning BOSS WAVE!")

	# Spawn 1 boss-like formation
	zombie_horde.spawn_zombies(1, "brute")  # Tank in front
	zombie_horde.spawn_zombies(2, "mage")   # Ranged support
	zombie_horde.spawn_zombies(5, "walker") # Fodder
	zombie_horde.spawn_zombies(3, "runner") # Fast flankers
	zombie_horde.spawn_zombies(1, "exploder") # Surprise

## Example: Night survival mode
func start_night_survival() -> void:
	if not zombie_horde or not DayNightCycle:
		return

	print("[ZombieTest] Starting NIGHT SURVIVAL MODE!")

	# Set to night
	DayNightCycle.set_time(0.0)

	# Spawn continuous waves
	zombie_horde.enable_waves = true
	zombie_horde.wave_interval = 60.0  # Every minute
	zombie_horde.base_zombies_per_wave = 10
	zombie_horde.zombies_per_wave_increase = 5

	print("- Waves every 60 seconds")
	print("- Starting with 10 zombies per wave")
	print("- Increasing by 5 each wave")
	print("- All zombies have night bonuses!")
	print("SURVIVE AS LONG AS YOU CAN!")
