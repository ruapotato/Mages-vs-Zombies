extends CharacterBody3D
class_name PlayerController

## First-person mage controller
## Based on Zombies-vs-Humans FPS controls

# Node references
@onready var camera: Camera3D = $CameraMount/Camera3D
@onready var camera_mount: Node3D = $CameraMount
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mage_sprite: Sprite3D = $MageSprite
@onready var staff_sprite: Sprite3D = $StaffSprite
@onready var spell_spawn_point: Marker3D = $CameraMount/SpellSpawnPoint
@onready var first_person_arms: FirstPersonArms = $CameraMount/Camera3D/FirstPersonArms

# Movement parameters
@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var acceleration := 15.0
@export var friction := 10.0
@export var air_control := 0.3
@export var jump_velocity := 6.0
@export var double_jump_velocity := 5.0
@export var double_jump_enabled := true
@export var gravity := 20.0

# Camera parameters
@export_group("Camera")
@export var mouse_sensitivity := 0.002
@export var vertical_look_limit := 89.0  # degrees

# Combat parameters
@export_group("Combat")
@export var max_health := 100.0
@export var health_regen_rate := 50.0  # HP per second
@export var health_regen_delay := 2.0  # Seconds after damage before regen
@export var max_mana := 100.0
@export var mana_regen_rate := 10.0  # Mana per second

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
var pitch := 0.0
var yaw := 0.0

# Spell state
var spell_cooldown_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var current_spell_slot := 0

# Input
var input_dir := Vector2.ZERO


func _ready() -> void:
	# Add to player group for zombie targeting
	add_to_group("player")
	add_to_group("local_player")

	# Initialize stats
	current_health = max_health
	current_mana = max_mana

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Setup mage sprite (Paper Mario style - visible to others, not to self in first person)
	_setup_mage_sprite()

	print("[Player] First-person mage ready")


func _setup_mage_sprite() -> void:
	# Generate mage texture
	if mage_sprite and TextureGenerator:
		mage_sprite.texture = TextureGenerator.generate_mage_texture("blue", 0)
		mage_sprite.visible = true  # Visible to other players/shadows

	# Generate staff texture
	if staff_sprite and TextureGenerator:
		staff_sprite.texture = TextureGenerator.generate_staff_texture()
		staff_sprite.visible = true

	# Setup first-person arms (visible when looking down)
	_setup_first_person_arms()


func _setup_first_person_arms() -> void:
	# Create first-person arms if not already present
	if not first_person_arms and camera:
		first_person_arms = FirstPersonArms.new()
		first_person_arms.name = "FirstPersonArms"
		camera.add_child(first_person_arms)

	# Set spell color based on current slot
	if first_person_arms:
		_update_arm_spell_color()


func _update_arm_spell_color() -> void:
	if not first_person_arms:
		return

	# Color based on selected spell
	var colors := {
		"fireball": Color(1, 0.5, 0.2),
		"ice_spike": Color(0.3, 0.7, 1.0),
		"lightning": Color(1, 1, 0.3),
		"heal": Color(0.3, 1, 0.4),
		"shield": Color(0.5, 0.5, 1.0),
	}

	if current_spell_slot < spell_slots.size():
		var spell_name = spell_slots[current_spell_slot]
		var color = colors.get(spell_name, Color(0.6, 0.3, 0.9))
		first_person_arms.set_spell_color(color)


func _input(event: InputEvent) -> void:
	# Mouse look - first person style
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-vertical_look_limit), deg_to_rad(vertical_look_limit))

		# Apply rotation immediately
		rotation.y = yaw
		if camera_mount:
			camera_mount.rotation.x = pitch

	# Recapture mouse if clicking during gameplay
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

	# Regeneration
	_handle_regeneration(delta)

	# Move
	move_and_slide()


func _handle_input(_delta: float) -> void:
	# Movement input
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Sprint
	is_sprinting = Input.is_action_pressed("sprint")

	# Jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
		elif double_jump_enabled and not has_double_jumped:
			velocity.y = double_jump_velocity
			has_double_jumped = true

	# Spell casting - left click for primary spell
	if Input.is_action_just_pressed("cast_spell") or Input.is_action_just_pressed("spell_1"):
		_cast_spell(0)

	# Number keys for other spells
	for i in range(1, 5):
		if Input.is_action_just_pressed("spell_" + str(i + 1)):
			_cast_spell(i)

	# Build mode toggle
	if Input.is_action_just_pressed("build_mode"):
		build_mode = not build_mode
		print("Build mode: ", "ON" if build_mode else "OFF")


func _handle_movement(delta: float) -> void:
	# Get movement direction based on where player is facing
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed := sprint_speed if is_sprinting else walk_speed
	var accel := acceleration if is_on_floor() else acceleration * air_control

	if direction.length() > 0:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
	else:
		# Apply friction
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)


func _handle_regeneration(delta: float) -> void:
	# Health regeneration (CoD style - fast regen after delay)
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
		return

	# Check mana
	var mana_cost = spell_mana_costs[slot_index] if slot_index < spell_mana_costs.size() else 0
	if current_mana < mana_cost:
		return

	# Cast spell
	current_mana -= mana_cost
	spell_cooldown_timers[slot_index] = spell_cooldowns[slot_index] if slot_index < spell_cooldowns.size() else 1.0
	current_spell_slot = slot_index

	# Play arm cast animation
	if first_person_arms:
		first_person_arms.play_cast_animation()
		_update_arm_spell_color()

	var spell_name = spell_slots[slot_index] if slot_index < spell_slots.size() else "unknown"
	_spawn_spell_effect(spell_name)


func _spawn_spell_effect(spell_name: String) -> void:
	# Get camera forward direction for spell aiming
	var camera_forward := -camera.global_transform.basis.z if camera else -global_transform.basis.z
	var spawn_position := global_position + Vector3(0, 1.5, 0) + camera_forward * 1.0

	# Map spell names to scene paths
	var spell_scenes := {
		"fireball": "res://scripts/projectiles/fireball.tscn",
		"ice_spike": "res://scripts/projectiles/fireball.tscn",
		"lightning": "res://scripts/projectiles/fireball.tscn",
		"heal": "",
		"shield": "",
	}

	var scene_path: String = spell_scenes.get(spell_name, "")
	if scene_path == "":
		# Self-cast spells
		if spell_name == "heal":
			heal(25.0)
		return

	# Load and instantiate projectile
	if ResourceLoader.exists(scene_path):
		var spell_scene = load(scene_path)
		var spell_instance = spell_scene.instantiate()
		get_tree().current_scene.add_child(spell_instance)
		spell_instance.global_position = spawn_position

		if spell_instance.has_method("setup_simple"):
			spell_instance.setup_simple(camera_forward, self)
		elif "velocity" in spell_instance:
			spell_instance.velocity = camera_forward * 25.0


## Take damage from zombie
func take_damage(amount: float, _attacker: Node = null) -> void:
	current_health -= amount
	current_health = max(current_health, 0)
	time_since_damage = 0.0

	# Flash HUD red
	var huds = get_tree().get_nodes_in_group("game_hud")
	if huds.size() == 0:
		# Find HUD by type
		for node in get_tree().get_nodes_in_group(""):
			if node.has_method("flash_damage"):
				node.flash_damage(0.5)
				break

	# Camera shake effect
	_apply_damage_shake()

	print("Player took ", amount, " damage. Health: ", current_health, "/", max_health)

	if current_health <= 0:
		_die()


func _apply_damage_shake() -> void:
	if not camera_mount:
		return

	# Quick camera shake
	var original_rotation = camera_mount.rotation
	var shake_tween = create_tween()
	shake_tween.tween_property(camera_mount, "rotation:z", original_rotation.z + 0.05, 0.03)
	shake_tween.tween_property(camera_mount, "rotation:z", original_rotation.z - 0.03, 0.03)
	shake_tween.tween_property(camera_mount, "rotation:z", original_rotation.z, 0.04)


## Heal player
func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)


## Player death
func _die() -> void:
	print("Player died!")


## Check if player can be targeted
func is_valid_target() -> bool:
	return current_health > 0


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
