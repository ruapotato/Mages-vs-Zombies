extends CharacterBody3D
class_name ZombieBase

## ZombieBase - Paper Mario style 2D billboard zombie in 3D world
## Based on Zombies-vs-Humans BillboardZombie implementation

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
@export var detection_range: float = 25.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0

# Night scaling
@export_group("Night Scaling")
@export var night_damage_multiplier: float = 2.0
@export var night_speed_multiplier: float = 1.5
@export var night_health_multiplier: float = 1.5

# Internal state
var current_state: State = State.SPAWNING
var current_health: float
var max_health: float
var current_speed: float
var current_damage: float
var is_night_time: bool = false

# Combat
var can_attack: bool = true
var target_player: Node3D = null
var players_in_attack_range: Array[Node3D] = []

# Animation state (matching ZvH)
var anim_time: float = 0.0
var base_sprite_y: float = 0.9  # Base Y position for sprite
var is_attacking_anim: bool = false
var attack_anim_time: float = 0.0

# LOD
var lod_level: int = 0
var lod_distance: float = 0.0

# References
@onready var sprite: Sprite3D = $Sprite3D
@onready var attack_sprite: Sprite3D = $AttackSprite
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var attack_area: Area3D = $AttackArea
@onready var detection_area: Area3D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer

# Gravity
var gravity: float = 20.0

# Attack swipe texture (cached static)
static var swipe_texture: ImageTexture = null


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("enemies")

	# Set up collision layers
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World and Player

	# Initialize based on time of day
	_update_time_scaling()

	# Initialize health
	max_health = base_health * (night_health_multiplier if is_night_time else 1.0)
	current_health = max_health
	current_speed = base_speed * (night_speed_multiplier if is_night_time else 1.0)
	current_damage = base_damage * (night_damage_multiplier if is_night_time else 1.0)

	# Setup sprite with procedural texture
	if sprite:
		sprite.texture = ZombieTextureGenerator.get_zombie_texture(zombie_type)
		# Tank/brute is bigger
		if zombie_type == "brute" or zombie_type == "tank":
			sprite.pixel_size = 0.03
		# Store base Y position
		base_sprite_y = sprite.position.y
		print("[Zombie] Generated texture for type: %s" % zombie_type)

	# Setup attack sprite with swipe texture
	if attack_sprite:
		if not swipe_texture:
			swipe_texture = _generate_swipe_texture()
		attack_sprite.texture = swipe_texture
		attack_sprite.visible = false

	# Setup attack timer
	if attack_timer:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Randomize animation offset so zombies don't sync
	anim_time = randf() * TAU

	# Start spawning sequence
	current_state = State.SPAWNING
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		current_state = State.CHASING
		# Find player immediately
		_find_target_player()


func _generate_swipe_texture() -> ImageTexture:
	var img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var claw_color := Color(0.3, 0.25, 0.2)
	var slash_color := Color(1.0, 0.3, 0.2, 0.8)

	# Draw slashing claws
	for i in range(3):
		var x_start: int = 8 + i * 12
		var y_start: int = 4 + i * 3
		# Claw
		for j in range(20):
			var x: int = x_start + j
			var y: int = y_start + int(j * 0.8)
			for dy in range(-2, 3):
				if x < 48 and y + dy < 32 and y + dy >= 0:
					img.set_pixel(x, y + dy, claw_color if abs(dy) < 2 else slash_color)

		# Slash trail
		for j in range(15):
			var x: int = x_start + j + 5
			var y: int = y_start + int(j * 0.8) + 2
			if x < 48 and y < 32:
				img.set_pixel(x, y, Color(slash_color.r, slash_color.g, slash_color.b, 0.5 - j * 0.03))

	return ImageTexture.create_from_image(img)


func _find_target_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var closest_dist := INF
		for p in players:
			var dist := global_position.distance_to(p.global_position)
			if dist < closest_dist:
				closest_dist = dist
				target_player = p


func _physics_process(delta: float) -> void:
	# Update time scaling
	_update_time_scaling()

	# State machine
	match current_state:
		State.SPAWNING:
			pass  # Handled in _ready
		State.IDLE:
			_process_idle(delta)
		State.CHASING:
			_process_chasing(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.DYING:
			_process_dying(delta)
		State.DEAD:
			return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# Move
	if current_state != State.DEAD and current_state != State.DYING:
		move_and_slide()

	# Update animation
	_update_animation(delta)


func _process_idle(delta: float) -> void:
	# Find target if we don't have one
	if not target_player or not is_instance_valid(target_player):
		_find_target_player()

	# Start chasing if we have a target
	if target_player and is_instance_valid(target_player):
		var distance = global_position.distance_to(target_player.global_position)
		if distance <= detection_range:
			current_state = State.CHASING


func _process_chasing(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_find_target_player()
		if not target_player:
			current_state = State.IDLE
			return

	var distance = global_position.distance_to(target_player.global_position)

	# Check if out of range
	if distance > detection_range * 1.5:
		current_state = State.IDLE
		target_player = null
		return

	# Check if in attack range
	if distance <= attack_range and can_attack:
		current_state = State.ATTACKING
		return

	# Move toward player
	var direction = (target_player.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		# Face movement direction
		rotation.y = atan2(direction.x, direction.z)
	else:
		velocity.x = 0
		velocity.z = 0


func _process_attacking(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		current_state = State.CHASING
		return

	var distance = global_position.distance_to(target_player.global_position)

	# If player moved away, chase
	if distance > attack_range * 1.5:
		current_state = State.CHASING
		return

	# Stop moving
	velocity.x = 0
	velocity.z = 0

	# Face player
	var direction = target_player.global_position - global_position
	rotation.y = atan2(direction.x, direction.z)

	# Attack
	if can_attack:
		_perform_attack()


func _perform_attack() -> void:
	can_attack = false
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.start()

	# Start swipe animation
	is_attacking_anim = true
	attack_anim_time = 0.0
	if attack_sprite:
		attack_sprite.visible = true
		attack_sprite.modulate.a = 1.0

	# Deal damage
	if target_player and is_instance_valid(target_player):
		if target_player.has_method("take_damage"):
			target_player.take_damage(current_damage, self)
			hit_player.emit(self, current_damage)


func _process_dying(delta: float) -> void:
	velocity = Vector3.ZERO

	# Death animation - fall flat
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "rotation:x", -PI/2, 0.3)
		tween.parallel().tween_property(sprite, "position:y", 0.1, 0.3)
		tween.parallel().tween_property(sprite, "modulate:a", 0.5, 0.3)
		tween.tween_callback(_finish_death)
		current_state = State.DEAD  # Prevent re-triggering
	else:
		_finish_death()


func _finish_death() -> void:
	queue_free()


func _update_animation(delta: float) -> void:
	# Update attack swipe animation
	if is_attacking_anim:
		attack_anim_time += delta
		if attack_anim_time > 0.35:
			is_attacking_anim = false
			if attack_sprite:
				attack_sprite.visible = false

	var dominated_velocity := absf(velocity.x) + absf(velocity.z)

	if current_state == State.ATTACKING:
		_animate_attack(delta)
	elif dominated_velocity > 0.5:
		_animate_walk(delta)
	else:
		_animate_idle(delta)


func _animate_walk(delta: float) -> void:
	anim_time += delta * current_speed * 3.0

	if sprite:
		# Bounce up and down
		sprite.position.y = base_sprite_y + abs(sin(anim_time)) * 0.08
		# Slight squash and stretch
		var squash := 1.0 + sin(anim_time * 2.0) * 0.05
		sprite.scale.x = 1.0 / squash
		sprite.scale.y = squash
		# Tilt side to side like walking
		sprite.rotation.z = sin(anim_time) * 0.1


func _animate_idle(delta: float) -> void:
	anim_time += delta * 2.0

	if sprite:
		# Gentle sway
		sprite.position.y = base_sprite_y + sin(anim_time * 0.8) * 0.02
		sprite.rotation.z = sin(anim_time * 0.5) * 0.05
		sprite.scale.x = 1.0
		sprite.scale.y = 1.0


func _animate_attack(delta: float) -> void:
	anim_time += delta * 6.0

	if sprite:
		# Lunge forward
		var lunge := sin(anim_time * 4.0)
		sprite.position.z = 0.2 * max(0, lunge)
		sprite.scale.x = 1.0 + max(0, lunge) * 0.2
		sprite.rotation.z = lunge * 0.15

	# Animate swipe effect
	if attack_sprite and is_attacking_anim:
		attack_sprite.visible = true
		var swipe_progress := attack_anim_time * 5.0
		attack_sprite.position.x = sin(swipe_progress) * 0.4
		attack_sprite.position.z = 0.3 + cos(swipe_progress) * 0.2
		attack_sprite.rotation.z = swipe_progress * 2.0
		attack_sprite.modulate.a = 1.0 - (attack_anim_time * 2.5)


func _update_time_scaling() -> void:
	if DayNightCycle:
		var was_night = is_night_time
		is_night_time = DayNightCycle.is_night()

		if was_night != is_night_time:
			current_speed = base_speed * (night_speed_multiplier if is_night_time else 1.0)
			current_damage = base_damage * (night_damage_multiplier if is_night_time else 1.0)

			if sprite and is_night_time:
				sprite.modulate = Color(0.8, 0.5, 0.5)
			elif sprite:
				sprite.modulate = Color(1.0, 1.0, 1.0)


func take_damage(amount: float, attacker: Node3D = null) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_health -= amount
	current_health = max(0, current_health)

	# Flash white on hit
	if sprite:
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(self) and sprite:
			sprite.modulate = Color(0.8, 0.5, 0.5) if is_night_time else Color(1.0, 1.0, 1.0)

	if current_health <= 0:
		die()


func die() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_state = State.DYING

	# Disable collision
	collision_layer = 0
	collision_mask = 0

	died.emit(self)


func _on_attack_timer_timeout() -> void:
	can_attack = true


func _on_attack_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("local_player"):
		if body not in players_in_attack_range:
			players_in_attack_range.append(body)


func _on_attack_area_body_exited(body: Node3D) -> void:
	if body in players_in_attack_range:
		players_in_attack_range.erase(body)


func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("local_player"):
		target_player = body
		if current_state == State.IDLE:
			current_state = State.CHASING


func _on_detection_area_body_exited(body: Node3D) -> void:
	pass  # Don't lose target immediately


func set_lod_level(level: int, distance: float) -> void:
	lod_level = level
	lod_distance = distance


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
