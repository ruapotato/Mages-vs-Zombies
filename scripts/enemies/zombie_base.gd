extends CharacterBody3D
class_name ZombieBase

## ZombieBase - Paper Mario style 2D billboard zombie in 3D world
## Base class for all zombie types with procedural animation and night scaling

signal died(zombie: ZombieBase)
signal hit_player(zombie: ZombieBase, damage: float)

# Zombie states
enum State {
	SPAWNING,
	IDLE,
	CHASING,
	ATTACKING,
	DYING,
	DEAD
}

# Zombie type (determines texture and behavior)
@export var zombie_type: String = "walker"

# Basic stats (scaled by difficulty and time)
@export_group("Base Stats")
@export var base_health: float = 50.0
@export var base_speed: float = 3.0
@export var base_damage: float = 10.0
@export var detection_range: float = 20.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5

# Night scaling - CRITICAL: Much stronger at night!
@export_group("Night Scaling")
@export var night_damage_multiplier: float = 2.0  # 2x damage at night!
@export var night_speed_multiplier: float = 1.5  # 50% faster at night
@export var night_health_multiplier: float = 1.5  # 50% more health at night

# Procedural animation settings
@export_group("Animation")
@export var walk_bob_speed: float = 8.0
@export var walk_bob_height: float = 0.15
@export var walk_lean_amount: float = 5.0  # degrees
@export var attack_swing_speed: float = 10.0
@export var attack_swing_angle: float = 30.0  # degrees
@export var death_fall_duration: float = 0.8

# Internal state
var current_state: State = State.SPAWNING
var current_health: float
var max_health: float
var current_speed: float
var current_damage: float
var is_night_time: bool = false

# Combat
var attack_timer: float = 0.0
var can_attack: bool = true
var target_player: Node3D = null

# Animation state
var animation_time: float = 0.0
var death_timer: float = 0.0
var spawn_timer: float = 0.0
const SPAWN_DURATION: float = 0.5

# LOD (Level of Detail) - set by zombie horde manager
var lod_level: int = 0  # 0 = full detail, 1 = simplified, 2 = minimal
var lod_distance: float = 0.0

# References
@onready var sprite: Sprite3D = $Sprite3D
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_bar: Node3D = $HealthBar
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var attack_area: Area3D = $AttackArea
@onready var detection_area: Area3D = $DetectionArea

# Collision
var player_in_attack_range: bool = false
var gravity: float = 9.8

func _ready() -> void:
	add_to_group("zombies")
	add_to_group("enemies")

	# Set up collision layers
	collision_layer = 4  # Enemy layer (bit 3)
	collision_mask = 1 | 2  # World (bit 1) and Player (bit 2)

	# Initialize based on time of day
	_update_time_scaling()

	# Initialize health
	max_health = base_health * (night_health_multiplier if is_night_time else 1.0)
	current_health = max_health
	current_speed = base_speed * (night_speed_multiplier if is_night_time else 1.0)
	current_damage = base_damage * (night_damage_multiplier if is_night_time else 1.0)

	# Setup navigation
	if navigation_agent:
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = 0.5
		navigation_agent.radius = 0.5
		navigation_agent.height = 2.0
		navigation_agent.max_speed = current_speed

	# Setup sprite billboard with procedural texture
	if sprite:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Pixel art style
		sprite.pixel_size = 0.025  # Match ZvH size
		sprite.no_depth_test = false
		sprite.modulate = Color(0.6, 0.8, 0.6, 1.0)  # Visible immediately, greenish tint

		# Generate zombie texture using ZvH-style generator
		sprite.texture = ZombieTextureGenerator.get_zombie_texture(zombie_type)
		print("[Zombie] Generated texture for type: %s" % zombie_type)

		# Tank/brute type is bigger
		if zombie_type == "brute" or zombie_type == "tank":
			sprite.pixel_size = 0.03

	# Setup areas
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	# Setup health bar
	if health_bar:
		_update_health_bar()

	# Start spawning
	current_state = State.SPAWNING

func _physics_process(delta: float) -> void:
	# Update time-based scaling
	_update_time_scaling()

	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	# State machine
	match current_state:
		State.SPAWNING:
			_process_spawning(delta)
		State.IDLE:
			_process_idle(delta)
		State.CHASING:
			_process_chasing(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.DYING:
			_process_dying(delta)
		State.DEAD:
			pass  # Do nothing when dead

	# Apply gravity when not on floor
	if not is_on_floor() and current_state != State.DEAD:
		velocity.y -= gravity * delta

	# Move
	if current_state != State.DEAD and current_state != State.DYING:
		move_and_slide()

	# Update animation
	_update_animation(delta)

	# Update health bar rotation (always face camera)
	if health_bar and is_instance_valid(health_bar):
		var camera = get_viewport().get_camera_3d()
		if camera:
			health_bar.look_at(camera.global_position, Vector3.UP)

func _process_spawning(delta: float) -> void:
	spawn_timer += delta
	var spawn_progress = min(spawn_timer / SPAWN_DURATION, 1.0)

	# Scale up from ground (sprite already visible)
	scale = Vector3.ONE * (0.5 + spawn_progress * 0.5)  # Start at 50% scale

	if spawn_progress >= 1.0:
		scale = Vector3.ONE
		current_state = State.IDLE
		print("[Zombie] Spawn complete, now IDLE at %v" % global_position)

func _process_idle(delta: float) -> void:
	# Simplified AI for distant zombies (LOD)
	if lod_level >= 2:
		return

	# Look for player
	if target_player and is_instance_valid(target_player):
		var distance = global_position.distance_to(target_player.global_position)
		if distance <= detection_range:
			current_state = State.CHASING

	# Slight idle bob
	animation_time += delta * 2.0

func _process_chasing(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		current_state = State.IDLE
		return

	var distance = global_position.distance_to(target_player.global_position)

	# Check if out of range
	if distance > detection_range * 1.5:  # Add hysteresis
		current_state = State.IDLE
		target_player = null
		return

	# Check if in attack range
	if distance <= attack_range and can_attack:
		current_state = State.ATTACKING
		return

	# LOD: Skip pathfinding for very distant zombies
	if lod_level >= 2:
		# Simple direct movement for distant zombies
		var direction = (target_player.global_position - global_position).normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Full pathfinding for close zombies
		navigation_agent.target_position = target_player.global_position

		if navigation_agent.is_navigation_finished():
			velocity.x = 0
			velocity.z = 0
		else:
			var next_position = navigation_agent.get_next_path_position()
			var direction = (next_position - global_position).normalized()
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed

	# Rotate to face movement direction
	if velocity.length() > 0.1:
		var look_direction = Vector2(velocity.z, velocity.x)
		rotation.y = look_direction.angle()

	animation_time += delta * walk_bob_speed

func _process_attacking(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		current_state = State.IDLE
		return

	var distance = global_position.distance_to(target_player.global_position)

	# If player moved out of range, chase again
	if distance > attack_range * 1.2:
		current_state = State.CHASING
		return

	# Face player
	var direction_to_player = target_player.global_position - global_position
	var angle = atan2(direction_to_player.x, direction_to_player.z)
	rotation.y = angle

	# Stop moving
	velocity.x = 0
	velocity.z = 0

	# Attack animation
	animation_time += delta * attack_swing_speed

	# Deal damage at peak of swing
	if can_attack and animation_time > PI * 0.5 and animation_time < PI * 0.6:
		_deal_damage_to_player()
		can_attack = false
		attack_timer = attack_cooldown

	# Return to chasing after attack animation completes
	if animation_time >= PI:
		animation_time = 0.0
		current_state = State.CHASING

func _process_dying(delta: float) -> void:
	death_timer += delta

	# Stop movement
	velocity = Vector3.ZERO

	# Falling animation
	var death_progress = death_timer / death_fall_duration

	if sprite:
		# Rotate sprite as falling
		sprite.rotation_degrees.z = -90.0 * death_progress
		# Fade out
		sprite.modulate.a = 1.0 - death_progress

	# Sink into ground
	position.y -= delta * 1.5

	if death_timer >= death_fall_duration:
		current_state = State.DEAD
		queue_free()

func _update_animation(delta: float) -> void:
	if not sprite:
		return

	match current_state:
		State.SPAWNING:
			# Handled in _process_spawning
			pass
		State.IDLE:
			# Gentle idle bob
			sprite.position.y = sin(animation_time) * walk_bob_height * 0.3
		State.CHASING:
			# Walking bob animation
			var bob = sin(animation_time) * walk_bob_height
			sprite.position.y = abs(bob)  # Absolute value for bouncing effect
			# Slight lean forward when walking
			sprite.rotation_degrees.x = walk_lean_amount
		State.ATTACKING:
			# Attack swing
			var swing = sin(animation_time) * attack_swing_angle
			sprite.rotation_degrees.z = swing
			# Scale slightly during attack
			var attack_scale = 1.0 + sin(animation_time) * 0.1
			sprite.scale = Vector3.ONE * attack_scale
		State.DYING:
			# Handled in _process_dying
			pass

func _update_health_bar() -> void:
	if not health_bar:
		return

	# Update health bar fill
	var fill = health_bar.get_node_or_null("Fill")
	if fill and fill is MeshInstance3D:
		var health_percent = current_health / max_health
		fill.scale.x = health_percent

		# Color based on health
		var mat = fill.get_active_material(0) as StandardMaterial3D
		if mat:
			if health_percent > 0.5:
				mat.albedo_color = Color.GREEN
			elif health_percent > 0.25:
				mat.albedo_color = Color.YELLOW
			else:
				mat.albedo_color = Color.RED

	# Hide health bar when at full health
	if current_health >= max_health:
		health_bar.visible = false
	else:
		health_bar.visible = true

func _update_time_scaling() -> void:
	# Check if it's night using the DayNightCycle autoload
	if DayNightCycle:
		var was_night = is_night_time
		is_night_time = DayNightCycle.is_night()

		# Update stats if day/night changed
		if was_night != is_night_time:
			current_speed = base_speed * (night_speed_multiplier if is_night_time else 1.0)
			current_damage = base_damage * (night_damage_multiplier if is_night_time else 1.0)

			# Update navigation speed
			if navigation_agent:
				navigation_agent.max_speed = current_speed

			# Change sprite tint at night (more menacing)
			if sprite and is_night_time:
				sprite.modulate = Color(0.8, 0.5, 0.5)  # Reddish tint at night
			elif sprite:
				sprite.modulate = Color(0.6, 0.8, 0.6)  # Greenish during day

func take_damage(amount: float, attacker: Node3D = null) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_health -= amount
	current_health = max(0, current_health)

	# Spawn hit effect
	_spawn_hit_effect(amount)

	# Flash sprite white
	if sprite:
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and sprite:
			sprite.modulate = Color(0.8, 0.5, 0.5) if is_night_time else Color(0.6, 0.8, 0.6)

	_update_health_bar()

	# Die if health depleted
	if current_health <= 0:
		die()


func _spawn_hit_effect(damage_amount: float) -> void:
	# Create hit effect at zombie position
	var effect = Node3D.new()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector3(0, 1.2, 0)

	# Mesh flash
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	var hit_color = Color(1, 0.5, 0.2) if damage_amount < 50 else Color(1, 0.2, 0.1)
	mat.albedo_color = hit_color
	mat.emission_enabled = true
	mat.emission = hit_color
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	effect.add_child(mesh)

	# Light
	var light = OmniLight3D.new()
	light.light_color = hit_color
	light.light_energy = 2.0
	light.omni_range = 2.0
	effect.add_child(light)

	# Animate and cleanup
	var tween = effect.create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * 2.0, 0.1)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.15)
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(effect.queue_free)

func die() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_state = State.DYING
	death_timer = 0.0

	# Disable collision
	if collision_shape:
		collision_shape.disabled = true

	# Disable areas
	if attack_area:
		attack_area.monitoring = false
	if detection_area:
		detection_area.monitoring = false

	# Emit signal
	died.emit(self)

func _deal_damage_to_player() -> void:
	if not target_player or not is_instance_valid(target_player):
		return

	# Check if player is still in range
	if global_position.distance_to(target_player.global_position) > attack_range * 1.2:
		return

	# Deal damage (pass self as attacker)
	if target_player.has_method("take_damage"):
		target_player.take_damage(current_damage, self)

	hit_player.emit(self, current_damage)

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("local_player"):
		target_player = body
		if current_state == State.IDLE:
			current_state = State.CHASING

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body == target_player:
		# Don't immediately lose target, check distance in state processing
		pass

func _on_attack_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("local_player"):
		player_in_attack_range = true

func _on_attack_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("local_player"):
		player_in_attack_range = false

## Set LOD level (called by horde manager)
func set_lod_level(level: int, distance: float) -> void:
	lod_level = level
	lod_distance = distance

	# Disable complex features at high LOD levels
	if lod_level >= 2:
		# Minimal detail - disable health bar, simplify sprite
		if health_bar:
			health_bar.visible = false
	elif lod_level >= 1:
		# Medium detail - simplify some effects
		if health_bar:
			health_bar.visible = current_health < max_health

## Get current stats (for debugging/UI)
func get_stats() -> Dictionary:
	return {
		"health": current_health,
		"max_health": max_health,
		"speed": current_speed,
		"damage": current_damage,
		"is_night": is_night_time,
		"state": State.keys()[current_state],
		"lod_level": lod_level
	}
