extends CharacterBody3D
class_name PlayerController

## First-person mage controller
## Based on Zombies-vs-Humans FPS controls

# Preloaded resources
const LightningMaterial = preload("res://resources/materials/lightning_material.tres")

# Node references
@onready var camera: Camera3D = $CameraMount/Camera3D
@onready var camera_mount: Node3D = $CameraMount
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mage_sprite: Sprite3D = $MageSprite
@onready var staff_sprite: Sprite3D = $StaffSprite
@onready var spell_spawn_point: Marker3D = $CameraMount/SpellSpawnPoint
@onready var first_person_arms: Node3D = $CameraMount/Camera3D/FirstPersonArms
@onready var aim_raycast: RayCast3D = $CameraMount/Camera3D/AimRaycast

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
var is_dead := false

# Camera state
var pitch := 0.0
var yaw := 0.0

# Spell state
var spell_cooldown_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var current_spell_slot := 0

# Input
var input_dir := Vector2.ZERO


## AUTO-TEST: Disabled
var _auto_test_lightning: bool = false
var _auto_test_timer: float = 0.0
var _auto_test_count: int = 0

func _ready() -> void:
	# Add to player group for zombie targeting
	add_to_group("player")
	add_to_group("local_player")

	# Initialize stats
	current_health = max_health
	current_mana = max_mana

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Enable aim raycast
	if aim_raycast:
		aim_raycast.enabled = true

	# Setup mage sprite (Paper Mario style - visible to others, not to self in first person)
	_setup_mage_sprite()

	print("[Player] First-person mage ready")

	# Pre-warm all spell effects to buffer graphics and catch errors
	_prewarm_spell_effects()

	if _auto_test_lightning:
		print("[AUTO-TEST] Lightning auto-fire ENABLED - will fire every 0.5s")


func _prewarm_spell_effects() -> void:
	print("[Player] Pre-warming spell effects...")

	# Test position far below ground so effects aren't visible
	var test_pos := Vector3(0, -1000, 0)

	# Test lightning bolt visual
	print("[Player] Testing lightning bolt...")
	_test_lightning_visual(test_pos)

	# Test ground ring (frost nova / flame wave)
	print("[Player] Testing ground ring (frost)...")
	_test_ground_ring(Color(0.4, 0.8, 1.0), 8.0, test_pos)

	print("[Player] Testing ground ring (fire)...")
	_test_ground_ring(Color(1.0, 0.4, 0.1), 6.0, test_pos)

	# Test heal effect
	print("[Player] Testing heal effect...")
	_test_heal_effect(test_pos)

	print("[Player] Spell effects pre-warmed successfully!")


func _test_lightning_visual(pos: Vector3) -> void:
	# Create and immediately destroy to test code path
	var bolt := MeshInstance3D.new()
	bolt.name = "TestLightningBolt"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.15
	cylinder.bottom_radius = 0.15
	cylinder.height = 30.0
	bolt.mesh = cylinder

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.7, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 0.5)
	material.emission_energy_multiplier = 5.0
	bolt.material_override = material

	var flash := OmniLight3D.new()
	flash.light_color = Color(0.8, 0.8, 1.0)
	flash.light_energy = 10.0
	flash.omni_range = 15.0
	bolt.add_child(flash)

	add_child(bolt)
	bolt.global_position = pos

	# Immediately free
	bolt.queue_free()
	print("[Player] Lightning visual test passed")


func _test_ground_ring(color: Color, radius: float, pos: Vector3) -> void:
	var effect := MeshInstance3D.new()
	effect.name = "TestGroundRing"

	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.1
	effect.mesh = disc

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.6)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	effect.material_override = material

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius * 1.5
	effect.add_child(light)

	add_child(effect)
	effect.global_position = pos

	effect.queue_free()
	print("[Player] Ground ring test passed")


func _test_heal_effect(pos: Vector3) -> void:
	var effect := MeshInstance3D.new()
	effect.name = "TestHealEffect"
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

	add_child(effect)
	effect.global_position = pos

	effect.queue_free()
	print("[Player] Heal effect test passed")


## Get the point where the crosshair is aiming (for spell targeting)
func get_aim_target() -> Dictionary:
	if aim_raycast and aim_raycast.is_colliding():
		return {
			"position": aim_raycast.get_collision_point(),
			"normal": aim_raycast.get_collision_normal(),
			"collider": aim_raycast.get_collider()
		}
	# No hit - return a point far in front of camera
	if camera:
		return {
			"position": camera.global_position - camera.global_transform.basis.z * 200.0,
			"normal": Vector3.UP,
			"collider": null
		}
	return {}


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


# Track temporary effects for manual cleanup
var _temp_effects: Array[Dictionary] = []

func _physics_process(delta: float) -> void:
	# AUTO-TEST: Fire lightning automatically (disabled)
	if _auto_test_lightning:
		_auto_test_timer += delta
		if _auto_test_timer >= 0.5:
			_auto_test_timer = 0.0
			_auto_test_count += 1
			current_mana = max_mana
			spell_cooldown_timers[2] = 0.0
			_cast_lightning_bolt()

	# Clean up expired temporary effects
	_cleanup_temp_effects(delta)

	# Don't process if dead
	if is_dead:
		# Still apply gravity so corpse falls
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		# Continue death camera animation
		_update_death_animation(delta)
		return

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

	# Handle damage shake (no tweens)
	_update_damage_shake(delta)

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
		"fireball":
			# Projectile spell
			_spawn_projectile(spawn_position, camera_forward, spell_name)

		"lightning":
			# Instant raycast spell with bolt from sky
			_cast_lightning_bolt()

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

		# Use the aim raycast to find where crosshair actually hits
		var aim_direction := direction
		if aim_raycast and aim_raycast.is_colliding():
			var hit_point := aim_raycast.get_collision_point()
			aim_direction = (hit_point - spawn_pos).normalized()

		if spell_instance.has_method("setup_simple"):
			spell_instance.setup_simple(aim_direction, self)
		elif "velocity" in spell_instance:
			spell_instance.velocity = aim_direction * 25.0


func _cast_frost_nova() -> void:
	# Simple AOE centered on player - damages nearby enemies
	var aoe_radius := 8.0
	var damage := 30.0
	var player_pos: Vector3 = global_position

	# Find and damage enemies in range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if player_pos.distance_to(enemy.global_position) <= aoe_radius:
			if enemy.has_method("take_damage"):
				var hit_pos: Vector3 = enemy.global_position + Vector3(0, 0.9, 0)
				enemy.take_damage(damage, self, hit_pos)

	# Create simple ground ring effect centered on player
	_create_ground_ring(Color(0.4, 0.8, 1.0), aoe_radius)


func _cast_flame_wave() -> void:
	# Simple AOE centered on player - damages nearby enemies with fire
	var aoe_radius := 6.0
	var damage := 45.0
	var player_pos: Vector3 = global_position

	# Find and damage enemies in range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if player_pos.distance_to(enemy.global_position) <= aoe_radius:
			if enemy.has_method("take_damage"):
				var hit_pos: Vector3 = enemy.global_position + Vector3(0, 0.9, 0)
				enemy.take_damage(damage, self, hit_pos)

	# Create simple ground ring effect centered on player
	_create_ground_ring(Color(1.0, 0.4, 0.1), aoe_radius)


func _cast_lightning_bolt() -> void:
	# Lightning bolt - always strikes ground at aimed XZ position, AOE damage
	var damage := 35.0
	var aoe_radius := 5.0

	# Raycast to find where player is aiming
	var space_state = get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var to: Vector3 = from + forward * 100.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]

	var result = space_state.intersect_ray(query)

	# Get the XZ position from where we're aiming
	var aim_pos: Vector3
	if result:
		aim_pos = result.position
	else:
		aim_pos = to

	# Now cast straight down from high above to find ground at that XZ
	var sky_pos := Vector3(aim_pos.x, aim_pos.y + 50.0, aim_pos.z)
	var ground_query = PhysicsRayQueryParameters3D.create(sky_pos, sky_pos + Vector3(0, -200, 0))
	ground_query.collision_mask = 1  # Only terrain layer

	var ground_result = space_state.intersect_ray(ground_query)

	var strike_pos: Vector3
	if ground_result:
		strike_pos = ground_result.position
	else:
		# Fallback to terrain height lookup
		var terrain = get_tree().get_first_node_in_group("terrain_world")
		if terrain and terrain.has_method("get_terrain_height"):
			strike_pos = Vector3(aim_pos.x, terrain.get_terrain_height(Vector2(aim_pos.x, aim_pos.z)), aim_pos.z)
		else:
			strike_pos = Vector3(aim_pos.x, 0, aim_pos.z)

	# Damage enemies in AOE (simple distance check)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = enemy.global_position.distance_to(strike_pos)
		if dist <= aoe_radius and enemy.has_method("take_damage"):
			var head_pos: Vector3 = enemy.global_position + Vector3(0, 1.8, 0)
			enemy.take_damage(damage, self, head_pos)

	# Spawn visual effect at ground
	_create_lightning_visual(strike_pos)


func _cleanup_temp_effects(delta: float) -> void:
	var i := 0
	while i < _temp_effects.size():
		var effect_data := _temp_effects[i]
		effect_data.time_left -= delta
		if effect_data.time_left <= 0:
			if is_instance_valid(effect_data.node):
				effect_data.node.queue_free()
			_temp_effects.remove_at(i)
		else:
			i += 1


func _create_lightning_visual(strike_pos: Vector3) -> void:
	# Use preloaded material to avoid runtime emission crash
	var bolt := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 25.0
	bolt.mesh = cyl
	bolt.material_override = LightningMaterial

	add_child(bolt)
	bolt.global_position = strike_pos + Vector3(0, 12.5, 0)

	_temp_effects.append({"node": bolt, "time_left": 0.15})


func _create_ground_ring(color: Color, radius: float) -> void:
	# Simple flat disc/ring on ground centered at player position
	var effect := MeshInstance3D.new()
	effect.name = "GroundRing"

	# Use a flat cylinder (disc) for ground effect
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.1  # Very thin - essentially flat
	effect.mesh = disc

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.6)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	effect.material_override = material

	get_tree().current_scene.add_child(effect)
	# Position at player's feet level
	effect.global_position = Vector3(global_position.x, global_position.y + 0.1, global_position.z)

	# Add glow light at ground level (not from above)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius * 1.5
	light.position = Vector3.ZERO  # At effect center
	effect.add_child(light)

	# Track for manual cleanup - no tweens, no timers
	_temp_effects.append({"node": effect, "time_left": 0.5})


func _create_heal_effect() -> void:
	# Green healing particles around player
	var effect := MeshInstance3D.new()
	effect.name = "HealEffect"
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

	# Track for manual cleanup - no tweens
	_temp_effects.append({"node": effect, "time_left": 0.6})


## Take damage from zombie
func take_damage(amount: float, _attacker: Node = null) -> void:
	if is_dead:
		return

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


var _damage_shake_timer: float = 0.0
var _damage_shake_phase: int = 0
var _original_cam_z_rotation: float = 0.0

func _update_damage_shake(delta: float) -> void:
	if _damage_shake_timer <= 0:
		return

	if not camera_mount:
		_damage_shake_timer = 0.0
		return

	_damage_shake_timer -= delta

	# Simple shake oscillation
	var shake_amount := sin(_damage_shake_timer * 60.0) * 0.04 * (_damage_shake_timer / 0.1)
	camera_mount.rotation.z = _original_cam_z_rotation + shake_amount

	if _damage_shake_timer <= 0:
		camera_mount.rotation.z = _original_cam_z_rotation

func _apply_damage_shake() -> void:
	if not camera_mount:
		return

	# Start manual shake (no tweens)
	_original_cam_z_rotation = camera_mount.rotation.z
	_damage_shake_timer = 0.1


## Heal player
func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)


## Player death
var _death_anim_timer: float = 0.0
var _death_cam_start_x: float = 0.0
var _death_cam_start_y: float = 0.0

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	print("Player died!")

	# Disable controls
	set_process_input(false)

	# Release mouse so player can interact with death screen
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Disable collision so zombies stop attacking
	collision_layer = 0
	collision_mask = 0

	# Start death animation (no tweens)
	if camera_mount:
		_death_cam_start_x = camera_mount.rotation.x
		_death_cam_start_y = camera_mount.position.y
		_death_anim_timer = 0.5

	# Notify GameManager
	if GameManager and GameManager.has_method("on_player_died"):
		GameManager.on_player_died()


func _update_death_animation(delta: float) -> void:
	if _death_anim_timer <= 0:
		return

	if not camera_mount:
		_death_anim_timer = 0.0
		return

	_death_anim_timer -= delta
	var progress := 1.0 - (_death_anim_timer / 0.5)
	progress = clampf(progress, 0.0, 1.0)

	# Animate camera falling
	camera_mount.rotation.x = lerpf(_death_cam_start_x, deg_to_rad(-80), progress)
	camera_mount.position.y = lerpf(_death_cam_start_y, 0.3, progress)


## Check if player can be targeted
func is_valid_target() -> bool:
	return not is_dead and current_health > 0


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
