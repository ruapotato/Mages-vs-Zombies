extends Area3D
class_name Fireball

## Fireball - Arcing projectile with gravity that deals damage on impact
## Self-contained projectile without base class dependency

@export var gravity_strength: float = 9.8
@export var speed_multiplier: float = 1.0
@export var damage: float = 20.0
@export var lifetime: float = 10.0

var velocity: Vector3 = Vector3.ZERO
var initial_direction: Vector3 = Vector3.ZERO
var has_hit: bool = false
var owner_id: int = 0
var time_alive: float = 0.0

# Visual
@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Setup collision
	collision_layer = 8  # Projectile layer (bit 4)
	collision_mask = 1 | 4  # World (1) and Enemy (4)

	# Connect signals
	body_entered.connect(_on_body_entered)

	# Create sprite if not exists
	if not sprite:
		sprite = Sprite3D.new()
		add_child(sprite)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = 0.02
		_create_fireball_texture()

	# Create collision shape if not exists
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 0.3
		collision_shape.shape = sphere
		add_child(collision_shape)


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	time_alive += delta
	if time_alive > lifetime:
		queue_free()
		return

	# Apply gravity to velocity
	velocity.y -= gravity_strength * delta

	# Move projectile
	position += velocity * delta

	# Rotate to face direction of travel
	if velocity.length() > 0.1:
		var look_target = position + velocity.normalized()
		if position.distance_to(look_target) > 0.01:
			look_at(look_target, Vector3.UP)

	# Animate sprite (pulse/flicker)
	if sprite:
		var pulse = 1.0 + sin(time_alive * 15.0) * 0.15
		sprite.scale = Vector3.ONE * pulse
		sprite.modulate = Color(1.0, 0.6 + sin(time_alive * 20.0) * 0.2, 0.2)


## Simple setup that takes direction and caster
func setup_simple(direction: Vector3, caster: Node) -> void:
	velocity = direction.normalized() * 25.0 * speed_multiplier
	initial_direction = direction.normalized()
	damage = 20.0
	owner_id = caster.get_instance_id() if caster else 0

	# Initial rotation
	if velocity.length() > 0.01:
		var target = position + velocity.normalized()
		if position.distance_to(target) > 0.01:
			look_at(target, Vector3.UP)


## Full setup with all parameters
func setup(start_pos: Vector3, direction: Vector3, speed: float, dmg: float, shooter_id: int) -> void:
	position = start_pos
	velocity = direction.normalized() * speed * speed_multiplier
	initial_direction = direction.normalized()
	damage = dmg
	owner_id = shooter_id

	if velocity.length() > 0.01:
		var target = position + velocity.normalized()
		if position.distance_to(target) > 0.01:
			look_at(target, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return

	# Don't hit the owner
	if body.get_instance_id() == owner_id:
		return

	# Deal damage to enemies
	if body.is_in_group("enemies") or body.is_in_group("zombies"):
		if body.has_method("take_damage"):
			body.take_damage(damage, self)

	_hit()


func _hit() -> void:
	has_hit = true
	velocity = Vector3.ZERO

	# Disable collision
	if collision_shape:
		collision_shape.disabled = true

	# Explosion visual
	if sprite:
		# Quick expansion then fade
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector3.ONE * 3.0, 0.15)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.15)

	# Destroy after brief delay
	await get_tree().create_timer(0.2).timeout
	queue_free()


func _create_fireball_texture() -> void:
	# Create a simple fireball texture procedurally
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center = Vector2(16, 16)

	for y in range(32):
		for x in range(32):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)

			if dist < 14:
				var t = 1.0 - (dist / 14.0)
				var r = 1.0
				var g = 0.4 + t * 0.5
				var b = 0.1 * t
				var a = t * t
				img.set_pixel(x, y, Color(r, g, b, a))

	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
