extends Node
class_name ManaManager
## Manages player's mana pool and regeneration

signal mana_changed(current: int, maximum: int)
signal mana_depleted
signal mana_full

@export var max_mana: int = 100
@export var base_mana_regen_per_sec: float = 5.0
@export var regen_delay_after_cast: float = 1.0  # Delay before regen starts after casting

var current_mana: int = 100
var mana_regen_per_sec: float = 5.0
var is_regenerating: bool = true

# Timers
var regen_timer: Timer = null
var regen_delay_timer: Timer = null


func _ready() -> void:
	_setup_timers()
	current_mana = max_mana
	mana_regen_per_sec = base_mana_regen_per_sec
	_start_regeneration()


func _setup_timers() -> void:
	# Regen tick timer
	regen_timer = Timer.new()
	regen_timer.name = "RegenTimer"
	regen_timer.wait_time = 0.1  # Tick every 100ms
	regen_timer.autostart = false
	add_child(regen_timer)
	regen_timer.timeout.connect(_on_regen_tick)

	# Delay timer
	regen_delay_timer = Timer.new()
	regen_delay_timer.name = "RegenDelayTimer"
	regen_delay_timer.one_shot = true
	regen_delay_timer.autostart = false
	add_child(regen_delay_timer)
	regen_delay_timer.timeout.connect(_on_regen_delay_finished)


func _start_regeneration() -> void:
	is_regenerating = true
	regen_timer.start()


func _stop_regeneration() -> void:
	is_regenerating = false
	regen_timer.stop()


func consume_mana(amount: int) -> bool:
	if current_mana < amount:
		return false

	current_mana -= amount
	current_mana = max(0, current_mana)
	mana_changed.emit(current_mana, max_mana)

	if current_mana == 0:
		mana_depleted.emit()

	# Reset regen delay
	_stop_regeneration()
	regen_delay_timer.wait_time = regen_delay_after_cast
	regen_delay_timer.start()

	return true


func add_mana(amount: int) -> void:
	var old_mana := current_mana
	current_mana = min(current_mana + amount, max_mana)

	if current_mana != old_mana:
		mana_changed.emit(current_mana, max_mana)

	if current_mana == max_mana and old_mana < max_mana:
		mana_full.emit()


func set_max_mana(new_max: int) -> void:
	max_mana = new_max
	current_mana = min(current_mana, max_mana)
	mana_changed.emit(current_mana, max_mana)


func set_mana_regen(new_regen: float) -> void:
	base_mana_regen_per_sec = new_regen
	mana_regen_per_sec = new_regen


func add_mana_regen_bonus(bonus: float) -> void:
	mana_regen_per_sec = base_mana_regen_per_sec + bonus


func reset_mana_regen() -> void:
	mana_regen_per_sec = base_mana_regen_per_sec


func refill_mana() -> void:
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)
	mana_full.emit()


func get_mana_percent() -> float:
	if max_mana == 0:
		return 0.0
	return float(current_mana) / float(max_mana)


func has_enough_mana(amount: int) -> bool:
	return current_mana >= amount


func _on_regen_tick() -> void:
	if not is_regenerating:
		return

	if current_mana >= max_mana:
		return

	# Regenerate mana
	var regen_amount := mana_regen_per_sec * regen_timer.wait_time
	add_mana(int(regen_amount))


func _on_regen_delay_finished() -> void:
	_start_regeneration()


# Save/Load support
func get_save_data() -> Dictionary:
	return {
		"current_mana": current_mana,
		"max_mana": max_mana,
		"mana_regen_per_sec": mana_regen_per_sec
	}


func load_save_data(data: Dictionary) -> void:
	current_mana = data.get("current_mana", max_mana)
	max_mana = data.get("max_mana", 100)
	mana_regen_per_sec = data.get("mana_regen_per_sec", base_mana_regen_per_sec)
	mana_changed.emit(current_mana, max_mana)
