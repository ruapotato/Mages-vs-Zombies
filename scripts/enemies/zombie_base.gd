extends CharacterBody3D
class_name ZombieBase

## ZombieBase - Paper Mario style 2D billboard zombie in 3D world
## Based on Zombies-vs-Humans BillboardZombie implementation

signal died(zombie: ZombieBase, was_headshot: bool, hit_position: Vector3)
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

# Headshot tracking - matching ZvH logic
var last_hit_was_headshot: bool = false
var last_hit_position: Vector3 = Vector3.ZERO
@export var head_position_y: float = 1.5  # Y height where head is (from base)
const HEAD_THRESHOLD: float = 0.3  # Hits within this distance below head_position_y count as headshot

# Animation state (matching ZvH)
var anim_time: float = 0.0
var base_sprite_y: float = 0.9  # Base Y position for sprite
var is_attacking_anim: bool = false
var attack_anim_time: float = 0.0
var death_anim_started: bool = false  # Prevent multiple death tweens
var _hit_flash_timer: float = 0.0  # For damage flash without tweens

# Health bar (matching ZvH)
var health_bar_sprite: Sprite3D = null
var health_bar_image: Image = null
var health_bar_texture: ImageTexture = null
const HEALTH_BAR_WIDTH := 32
const HEALTH_BAR_HEIGHT := 4

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
		if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
			attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Randomize animation offset so zombies don't sync
	anim_time = randf() * TAU

	# Create health bar (hidden until damaged)
	_create_health_bar()

	# Start spawning sequence - use manual timer (no tweens)
	current_state = State.SPAWNING
	_spawn_timer = 0.3


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


func _create_health_bar() -> void:
	health_bar_sprite = Sprite3D.new()
	health_bar_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_sprite.pixel_size = 0.02
	health_bar_sprite.position = Vector3(0, 1.8, 0)  # Above zombie head
	health_bar_sprite.no_depth_test = true
	health_bar_sprite.render_priority = 10
	health_bar_sprite.visible = false
	add_child(health_bar_sprite)

	health_bar_image = Image.create(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT, false, Image.FORMAT_RGBA8)
	health_bar_texture = ImageTexture.create_from_image(health_bar_image)
	health_bar_sprite.texture = health_bar_texture


func _update_health_bar() -> void:
	if not health_bar_sprite or max_health <= 0:
		return

	var ratio := clampf(current_health / max_health, 0.0, 1.0)
	var filled := int(ratio * HEALTH_BAR_WIDTH)

	# Draw: black background, colored fill, dark red remainder
	health_bar_image.fill(Color(0, 0, 0, 0.7))
	for x in range(1, HEALTH_BAR_WIDTH - 1):
		for y in range(1, HEALTH_BAR_HEIGHT - 1):
			if x < filled:
				# Green -> yellow -> red gradient based on health
				var bar_color: Color
				if ratio > 0.5:
					bar_color = Color(0.1, 0.9, 0.1)
				elif ratio > 0.25:
					bar_color = Color(0.9, 0.9, 0.1)
				else:
					bar_color = Color(0.9, 0.1, 0.1)
				health_bar_image.set_pixel(x, y, bar_color)
			else:
				health_bar_image.set_pixel(x, y, Color(0.2, 0.0, 0.0, 0.5))

	health_bar_texture.update(health_bar_image)
	health_bar_sprite.visible = true


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

	# Process hit flash timer (no tweens)
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0 and sprite:
			sprite.modulate = Color(0.8, 0.5, 0.5) if is_night_time else Color(1.0, 1.0, 1.0)

	# State machine
	match current_state:
		State.SPAWNING:
			# Manual spawn timer (no tweens)
			if _spawn_timer > 0:
				_spawn_timer -= delta
				if _spawn_timer <= 0:
					current_state = State.CHASING
					_find_target_player()
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


var _death_timer: float = 0.0
var _death_duration: float = 0.3
var _spawn_timer: float = 0.0  # For spawn delay without tweens

func _process_dying(delta: float) -> void:
	velocity = Vector3.ZERO

	# Start death animation
	if not death_anim_started:
		death_anim_started = true
		_death_timer = 0.0

	# Animate death manually (no tweens)
	_death_timer += delta
	var progress := clampf(_death_timer / _death_duration, 0.0, 1.0)

	if sprite:
		sprite.rotation.x = lerpf(0.0, -PI/2, progress)
		sprite.position.y = lerpf(base_sprite_y, 0.1, progress)
		sprite.modulate.a = lerpf(1.0, 0.5, progress)

	# Finish when done
	if _death_timer >= _death_duration:
		_finish_death()
		return

	# Fallback if no sprite
	if not sprite:
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


func take_damage(amount: float, attacker: Node3D = null, hit_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_health -= amount
	current_health = max(0, current_health)

	# Determine if headshot based on hit height - matching ZvH logic exactly
	last_hit_position = hit_position if hit_position != Vector3.ZERO else global_position + Vector3(0, 1.0, 0)
	var hit_height: float = last_hit_position.y - global_position.y
	# Headshot if hit is at or above (head_position_y - HEAD_THRESHOLD)
	var this_hit_is_headshot: bool = hit_height >= (head_position_y - HEAD_THRESHOLD)
	if this_hit_is_headshot:
		last_hit_was_headshot = true

	# Update health bar
	_update_health_bar()

	# Flash white on hit
	if sprite:
		sprite.modulate = Color.WHITE
		_hit_flash_timer = 0.05

	if current_health <= 0:
		die()


func die() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_state = State.DYING

	# Disable collision
	collision_layer = 0
	collision_mask = 0

	# Notify GameManager with headshot info for points
	if GameManager:
		GameManager.on_zombie_killed(zombie_type, global_position, last_hit_was_headshot, last_hit_position)

	died.emit(self, last_hit_was_headshot, last_hit_position)


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
