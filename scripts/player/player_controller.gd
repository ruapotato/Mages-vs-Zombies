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
@onready var first_person_arms: Node3D = $CameraMount/Camera3D/FirstPersonArms

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

# ADS (Aim Down Sights) zoom
const DEFAULT_FOV := 75.0
const ADS_FOV := 45.0
const ADS_ZOOM_SPEED := 12.0
const ADS_SENSITIVITY_MULTIPLIER := 0.5  # Half sensitivity when aiming

# Combat parameters
@export_group("Combat")
@export var max_health := 100.0
@export var max_mana := 100.0
@export var mana_regen_rate := 10.0  # Mana per second

# Spell slots (1=fireball, 2=frost nova AOE, 3=lightning, 4=heal, 5=flame wave AOE)
@export_group("Spells")
@export var spell_slots: Array[String] = ["fireball", "frost_nova", "lightning", "heal", "flame_wave"]
@export var spell_cooldowns: Array[float] = [0.5, 2.5, 2.0, 8.0, 3.0]
@export var spell_mana_costs: Array[int] = [15, 25, 25, 35, 30]

# State
var current_health: float
var current_mana: float
var is_sprinting := false
var is_aiming := false
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
		var arms_script = load("res://scripts/player/first_person_arms.gd")
		if arms_script:
			first_person_arms = Node3D.new()
			first_person_arms.set_script(arms_script)
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
		# Reduce sensitivity when aiming
		var sensitivity := mouse_sensitivity
		if is_aiming:
			sensitivity *= ADS_SENSITIVITY_MULTIPLIER

		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity
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

	# Mana regeneration only (no health regen)
	_handle_regeneration(delta)

	# Handle ADS FOV zoom
	if camera:
		var target_fov := ADS_FOV if is_aiming else DEFAULT_FOV
		camera.fov = lerpf(camera.fov, target_fov, ADS_ZOOM_SPEED * delta)

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

	# Number keys to SELECT spell (1-5)
	for i in range(5):
		if Input.is_action_just_pressed("spell_" + str(i + 1)):
			current_spell_slot = i
			_update_arm_spell_color()
			print("Selected spell: %s" % spell_slots[i])

	# Left click casts the currently selected spell
	if Input.is_action_just_pressed("cast_spell"):
		_cast_spell(current_spell_slot)

	# Build mode toggle
	if Input.is_action_just_pressed("build_mode"):
		build_mode = not build_mode
		print("Build mode: ", "ON" if build_mode else "OFF")

	# Aiming (ADS) - right mouse button
	is_aiming = Input.is_action_pressed("aim") and not is_sprinting


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
	# Mana regeneration only - no automatic health regen
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

	match spell_name:
		"fireball", "lightning":
			# Projectile spells
			_spawn_projectile(spawn_position, camera_forward, spell_name)

		"frost_nova":
			# AOE centered on player - freeze/slow nearby enemies
			_cast_frost_nova()

		"flame_wave":
			# AOE centered on player - fire damage
			_cast_flame_wave()

		"heal":
			# Self heal
			heal(40.0)
			_create_heal_effect()


func _spawn_projectile(spawn_pos: Vector3, direction: Vector3, spell_name: String) -> void:
	var scene_path := "res://scripts/projectiles/fireball.tscn"

	if ResourceLoader.exists(scene_path):
		var spell_scene = load(scene_path)
		var spell_instance = spell_scene.instantiate()
		get_tree().current_scene.add_child(spell_instance)
		spell_instance.global_position = spawn_pos

		# Modify based on spell type
		if spell_name == "lightning":
			if "damage" in spell_instance:
				spell_instance.damage = 35.0
			if "speed" in spell_instance:
				spell_instance.speed = 50.0

		# Raycast from camera center to find where crosshair actually hits
		var aim_direction := direction
		if camera:
			var space_state := get_world_3d().direct_space_state
			var from := camera.global_position
			var to := from + direction * 200.0
			var query := PhysicsRayQueryParameters3D.create(from, to)
			query.collision_mask = 0b1111  # World, player, enemy, interactable
			query.exclude = [self]
			var result := space_state.intersect_ray(query)
			if result:
				# Aim from spawn point toward the hit point
				aim_direction = (result.position - spawn_pos).normalized()

		if spell_instance.has_method("setup_simple"):
			spell_instance.setup_simple(aim_direction, self)
		elif "velocity" in spell_instance:
			spell_instance.velocity = aim_direction * 25.0


func _cast_frost_nova() -> void:
	# AOE damage and slow around player
	var aoe_radius := 8.0
	var damage := 30.0

	# Find enemies in range
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= aoe_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, self)
			# Could add slow effect here

	# Visual effect
	_create_aoe_effect(Color(0.4, 0.8, 1.0, 0.8), aoe_radius)


func _cast_flame_wave() -> void:
	# AOE fire damage around player
	var aoe_radius := 6.0
	var damage := 45.0

	# Find enemies in range
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= aoe_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, self)

	# Visual effect
	_create_aoe_effect(Color(1.0, 0.4, 0.1, 0.8), aoe_radius)


func _create_aoe_effect(color: Color, radius: float) -> void:
	# Create expanding ring effect
	var effect := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.3
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 16
	effect.mesh = torus

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect.material_override = material

	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector3(0, 0.1, 0)
	effect.rotation.x = PI / 2.0

	# Animate expansion and fade
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 1.5, 0.3)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(effect.queue_free)

	# Add light flash
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius * 1.5
	effect.add_child(light)

	var light_tween := create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 0.3)


func _create_heal_effect() -> void:
	# Green healing particles around player
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	effect.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 1.0, 0.3, 0.5)
	material.emission_enabled = true
	material.emission = Color(0.3, 1.0, 0.4)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect.material_override = material

	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector3(0, 1.0, 0)

	# Animate rise and fade
	var tween := create_tween()
	tween.tween_property(effect, "global_position:y", global_position.y + 2.5, 0.5)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(effect.queue_free)


## Take damage from zombie
func take_damage(amount: float, _attacker: Node = null) -> void:
	current_health -= amount
	current_health = max(current_health, 0)

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
