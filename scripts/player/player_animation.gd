extends Node
class_name PlayerAnimation

## Handles procedural 2D animation for the billboard player sprite
## Provides walk cycles, idle breathing, cast animations, and jump animations

signal animation_finished(animation_name: String)

@export var sprite: Sprite3D
@export var base_scale := Vector2(1.0, 1.0)

# Animation parameters
var animation_time := 0.0
var current_animation := "idle"
var is_moving := false
var movement_direction := Vector2.ZERO  # 2D direction for animation
var velocity_3d := Vector3.ZERO

# Animation state
var is_casting := false
var is_jumping := false
var is_grounded := true

# Idle animation parameters
const IDLE_BREATH_SPEED := 1.5
const IDLE_BREATH_AMOUNT := 0.03
const IDLE_SWAY_SPEED := 0.8
const IDLE_SWAY_AMOUNT := 0.02

# Walk animation parameters
const WALK_BOB_SPEED := 10.0
const WALK_BOB_AMOUNT := 0.15
const WALK_SQUASH_AMOUNT := 0.1
const WALK_TILT_AMOUNT := 5.0  # degrees
const ARM_SWING_SPEED := 8.0
const ARM_SWING_AMOUNT := 10.0  # degrees

# Jump animation parameters
const JUMP_SQUASH := Vector2(1.1, 0.85)  # Squash before jump
const JUMP_STRETCH := Vector2(0.85, 1.15)  # Stretch during jump
const JUMP_TUCK := Vector2(0.95, 1.05)  # Slight tuck at apex

# Cast animation parameters
const CAST_DURATION := 0.5
const CAST_RAISE_HEIGHT := 0.3
const CAST_WINDUP := 0.15
var cast_time := 0.0

# Sprite offset from body
var sprite_offset := Vector3.ZERO
var sprite_rotation := 0.0
var sprite_scale := Vector2(1.0, 1.0)


func _ready() -> void:
	if sprite:
		sprite_scale = base_scale


func _process(delta: float) -> void:
	animation_time += delta

	if is_casting:
		_animate_cast(delta)
	elif !is_grounded:
		_animate_jump(delta)
	elif is_moving:
		_animate_walk(delta)
	else:
		_animate_idle(delta)

	# Apply transformations to sprite
	if sprite:
		sprite.position.y = sprite_offset.y
		sprite.position.x = sprite_offset.x
		sprite.position.z = sprite_offset.z
		sprite.scale = Vector3(sprite_scale.x * base_scale.x, sprite_scale.y * base_scale.y, 1.0)
		sprite.rotation_degrees.z = sprite_rotation


## Update movement state for animation
func update_movement(velocity: Vector3, grounded: bool) -> void:
	velocity_3d = velocity
	is_grounded = grounded

	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	is_moving = horizontal_velocity.length() > 0.1

	if is_moving:
		movement_direction = horizontal_velocity.normalized()


## Play casting animation
func play_cast() -> void:
	is_casting = true
	cast_time = 0.0


## Idle animation - subtle breathing and swaying
func _animate_idle(delta: float) -> void:
	# Breathing effect (vertical scale)
	var breath = sin(animation_time * IDLE_BREATH_SPEED) * IDLE_BREATH_AMOUNT
	sprite_scale.y = 1.0 + breath
	sprite_scale.x = 1.0 - breath * 0.5  # Inverse for volume conservation

	# Subtle sway
	var sway = sin(animation_time * IDLE_SWAY_SPEED) * IDLE_SWAY_AMOUNT
	sprite_offset.x = sway
	sprite_rotation = sway * 2.0

	sprite_offset.y = 0.0
	sprite_offset.z = 0.0


## Walk animation - bob, squash/stretch, tilt
func _animate_walk(delta: float) -> void:
	var speed_factor = velocity_3d.length() / 5.0  # Normalize to walk speed
	speed_factor = clamp(speed_factor, 0.5, 2.0)  # Sprint makes it faster

	# Bobbing motion
	var bob_phase = animation_time * WALK_BOB_SPEED * speed_factor
	var bob = abs(sin(bob_phase)) * WALK_BOB_AMOUNT
	sprite_offset.y = bob

	# Squash and stretch
	var squash_phase = sin(bob_phase * 2.0)  # Double frequency
	sprite_scale.y = 1.0 + squash_phase * WALK_SQUASH_AMOUNT
	sprite_scale.x = 1.0 - squash_phase * WALK_SQUASH_AMOUNT * 0.5

	# Tilt based on movement
	var tilt = sin(bob_phase) * WALK_TILT_AMOUNT * speed_factor
	sprite_rotation = tilt

	# Slight side-to-side motion (arm swing simulation)
	var side_swing = sin(bob_phase) * 0.05
	sprite_offset.x = side_swing
	sprite_offset.z = 0.0


## Jump animation - squash on landing, stretch in air
func _animate_jump(delta: float) -> void:
	# Determine jump phase based on vertical velocity
	if velocity_3d.y > 3.0:
		# Rising - stretch
		sprite_scale = JUMP_STRETCH
		sprite_rotation = 0.0
	elif velocity_3d.y > -1.0:
		# Apex - tuck
		sprite_scale = JUMP_TUCK
		sprite_rotation = 0.0
	else:
		# Falling - slight stretch
		sprite_scale = Vector2(0.9, 1.1)
		sprite_rotation = 0.0

	sprite_offset.x = 0.0
	sprite_offset.y = 0.0
	sprite_offset.z = 0.0


## Cast animation - raise arm with wand
func _animate_cast(delta: float) -> void:
	cast_time += delta

	if cast_time < CAST_WINDUP:
		# Windup - slight squash
		var progress = cast_time / CAST_WINDUP
		sprite_scale = Vector2(1.0 + progress * 0.1, 1.0 - progress * 0.1)
		sprite_offset.y = -progress * 0.1
		sprite_rotation = -progress * 10.0

	elif cast_time < CAST_DURATION:
		# Cast - raise and stretch
		var progress = (cast_time - CAST_WINDUP) / (CAST_DURATION - CAST_WINDUP)
		sprite_scale = Vector2(0.95, 1.1)
		sprite_offset.y = CAST_RAISE_HEIGHT * progress
		sprite_rotation = 10.0 * progress

	else:
		# End cast
		is_casting = false
		cast_time = 0.0
		sprite_scale = Vector2(1.0, 1.0)
		sprite_offset = Vector3.ZERO
		sprite_rotation = 0.0
		animation_finished.emit("cast")


## Get the current animation state as a string
func get_current_state() -> String:
	if is_casting:
		return "casting"
	elif !is_grounded:
		return "jumping"
	elif is_moving:
		return "walking"
	else:
		return "idle"


## Reset animation state
func reset() -> void:
	animation_time = 0.0
	is_casting = false
	is_jumping = false
	sprite_offset = Vector3.ZERO
	sprite_rotation = 0.0
	sprite_scale = Vector2(1.0, 1.0)
