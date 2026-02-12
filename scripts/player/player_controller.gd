extends CharacterBody3D
class_name PlayerController

## Main player controller for 2D billboard character in 3D world
## Paper Mario style - 2D sprite that always faces camera, mouse look controls

# Node references
@onready var sprite: Sprite3D = $Sprite3D
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var animation_controller = $AnimationController  # PlayerAnimation

# Movement parameters
@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var acceleration := 10.0
@export var friction := 15.0
@export var air_acceleration := 5.0
@export var jump_velocity := 7.0
@export var double_jump_enabled := true
@export var gravity := 20.0

# Camera parameters
@export_group("Camera")
@export var mouse_sensitivity := 0.002
@export var camera_distance := 5.0
@export var camera_height := 2.0
@export var vertical_look_limit := 80.0  # degrees
@export var camera_smoothness := 10.0

# Combat parameters
@export_group("Combat")
@export var max_health := 100.0
@export var health_regen_rate := 2.0  # HP per second
@export var health_regen_delay := 5.0  # Seconds after damage before regen
@export var max_mana := 100.0
@export var mana_regen_rate := 5.0  # Mana per second

# Spell slots
@export_group("Spells")
@export var spell_slots: Array[String] = ["fireball", "ice_spike", "lightning", "heal", "shield"]
@export var spell_cooldowns: Array[float] = [1.0, 1.5, 2.0, 10.0, 8.0]
@export var spell_mana_costs: Array[int] = [15, 20, 25, 30, 20]

# State
var current_health: float
var current_mana: float
var time_since_damage := 0.0
var is_sprinting := false
var has_double_jumped := false
var build_mode := false

# Camera state
var camera_rotation := Vector2.ZERO  # x = pitch, y = yaw
var camera_velocity := Vector2.ZERO

# Spell state
var spell_cooldown_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var current_spell_slot := 0

# Input
var input_dir := Vector2.ZERO


func _ready() -> void:
	# Initialize stats
	current_health = max_health
	current_mana = max_mana

	# Setup camera
	if camera_pivot:
		camera_pivot.position = Vector3(0, camera_height, 0)
	if camera:
		camera.position = Vector3(0, 0, camera_distance)

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Setup sprite billboard
	if sprite:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Sprite should be a placeholder until you add actual textures
		sprite.modulate = Color.WHITE

	# Setup animation controller
	if animation_controller and sprite:
		animation_controller.sprite = sprite


func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, -deg_to_rad(vertical_look_limit), deg_to_rad(vertical_look_limit))

	# Note: Escape/pause is now handled by PauseMenu
	# Only recapture mouse if clicking during gameplay
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Update timers
	time_since_damage += delta
	_update_cooldowns(delta)

	# Handle input
	_handle_input(delta)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		has_double_jumped = false

	# Movement
	_handle_movement(delta)

	# Camera update
	_update_camera(delta)

	# Regeneration
	_handle_regeneration(delta)

	# Update animation
	if animation_controller:
		animation_controller.update_movement(velocity, is_on_floor())

	# Move
	move_and_slide()


func _handle_input(delta: float) -> void:
	# Movement input
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Sprint
	is_sprinting = Input.is_action_pressed("sprint")

	# Jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
		elif double_jump_enabled and not has_double_jumped:
			velocity.y = jump_velocity
			has_double_jumped = true

	# Spell casting
	for i in range(5):
		if Input.is_action_just_pressed("spell_" + str(i + 1)):
			_cast_spell(i)

	# Build mode toggle
	if Input.is_action_just_pressed("build_mode"):
		build_mode = not build_mode
		print("Build mode: ", "ON" if build_mode else "OFF")


func _handle_movement(delta: float) -> void:
	# Get camera forward and right vectors
	var camera_basis := camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward := -camera_basis.z
	var right := camera_basis.x

	# Flatten to horizontal plane
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	# Calculate desired velocity
	var desired_velocity := (forward * input_dir.y + right * input_dir.x)
	var speed := sprint_speed if is_sprinting else walk_speed

	# Apply acceleration/friction
	var accel := acceleration if is_on_floor() else air_acceleration

	if desired_velocity.length() > 0:
		desired_velocity = desired_velocity.normalized() * speed
		velocity.x = move_toward(velocity.x, desired_velocity.x, accel * delta)
		velocity.z = move_toward(velocity.z, desired_velocity.z, accel * delta)
	else:
		# Apply friction
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)


func _update_camera(delta: float) -> void:
	if not camera_pivot:
		return

	# Smooth camera rotation
	var target_rotation := Vector3(camera_rotation.x, camera_rotation.y, 0)
	camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, target_rotation.x, camera_smoothness * delta)
	camera_pivot.rotation.y = lerp(camera_pivot.rotation.y, target_rotation.y, camera_smoothness * delta)


func _handle_regeneration(delta: float) -> void:
	# Health regeneration
	if time_since_damage >= health_regen_delay and current_health < max_health:
		current_health = min(current_health + health_regen_rate * delta, max_health)

	# Mana regeneration
	if current_mana < max_mana:
		current_mana = min(current_mana + mana_regen_rate * delta, max_mana)


func _update_cooldowns(delta: float) -> void:
	for i in range(spell_cooldown_timers.size()):
		if spell_cooldown_timers[i] > 0:
			spell_cooldown_timers[i] -= delta


func _cast_spell(slot_index: int) -> void:
	# Validate slot
	if slot_index < 0 or slot_index >= spell_slots.size():
		return

	# Check cooldown
	if spell_cooldown_timers[slot_index] > 0:
		print("Spell on cooldown: ", spell_cooldown_timers[slot_index], "s remaining")
		return

	# Check mana
	var mana_cost = spell_mana_costs[slot_index] if slot_index < spell_mana_costs.size() else 0
	if current_mana < mana_cost:
		print("Not enough mana! Need: ", mana_cost, " Have: ", current_mana)
		return

	# Cast spell
	current_mana -= mana_cost
	spell_cooldown_timers[slot_index] = spell_cooldowns[slot_index] if slot_index < spell_cooldowns.size() else 1.0
	current_spell_slot = slot_index

	# Play cast animation
	if animation_controller:
		animation_controller.play_cast()

	# Emit spell cast signal or instantiate spell
	var spell_name = spell_slots[slot_index] if slot_index < spell_slots.size() else "unknown"
	print("Cast spell: ", spell_name, " (Slot ", slot_index + 1, ")")

	# TODO: Instantiate actual spell projectile/effect
	_spawn_spell_effect(spell_name)


func _spawn_spell_effect(spell_name: String) -> void:
	# Get camera forward direction for spell aiming
	var camera_forward := -camera.global_transform.basis.z if camera else -global_transform.basis.z
	var spawn_position := global_position + Vector3(0, 1.5, 0) + camera_forward * 1.5

	# TODO: Replace with actual spell instantiation
	print("Spawning ", spell_name, " at ", spawn_position, " direction: ", camera_forward)

	# This is where you'd instantiate your spell scenes:
	# var spell_scene = preload("res://scenes/spells/" + spell_name + ".tscn")
	# var spell_instance = spell_scene.instantiate()
	# get_tree().current_scene.add_child(spell_instance)
	# spell_instance.global_position = spawn_position
	# spell_instance.setup(camera_forward, self)


## Take damage
func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = max(current_health, 0)
	time_since_damage = 0.0

	print("Player took ", amount, " damage. Health: ", current_health, "/", max_health)

	if current_health <= 0:
		_die()


## Heal player
func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	print("Player healed ", amount, ". Health: ", current_health, "/", max_health)


## Player death
func _die() -> void:
	print("Player died!")
	# TODO: Implement death logic (respawn, game over, etc.)


## Get current health percentage
func get_health_percent() -> float:
	return current_health / max_health


## Get current mana percentage
func get_mana_percent() -> float:
	return current_mana / max_mana


## Get spell info for UI
func get_spell_info(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= spell_slots.size():
		return {}

	return {
		"name": spell_slots[slot_index],
		"cooldown": spell_cooldown_timers[slot_index],
		"max_cooldown": spell_cooldowns[slot_index] if slot_index < spell_cooldowns.size() else 0.0,
		"mana_cost": spell_mana_costs[slot_index] if slot_index < spell_mana_costs.size() else 0,
		"available": spell_cooldown_timers[slot_index] <= 0 and current_mana >= (spell_mana_costs[slot_index] if slot_index < spell_mana_costs.size() else 0)
	}
