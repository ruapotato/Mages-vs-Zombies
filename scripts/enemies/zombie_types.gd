## ZombieTypes - Different zombie variants extending ZombieBase
## Walker, Runner, Brute, Mage Zombie, and Exploder types

# ============================================================================
# WALKER - Basic slow zombie
# ============================================================================
class_name ZombieWalker
extends ZombieBase

func _init() -> void:
	# Basic stats
	base_health = 50.0
	base_speed = 3.0
	base_damage = 10.0
	detection_range = 20.0
	attack_range = 2.0
	attack_cooldown = 1.5

	# Appearance
	# Greenish tint for basic walker

func _ready() -> void:
	super._ready()

	if sprite:
		sprite.modulate = Color(0.6, 0.8, 0.6)  # Greenish

# ============================================================================
# RUNNER - Fast zombie with less health
# ============================================================================
class ZombieRunner extends ZombieBase:

	func _init() -> void:
		# Fast but fragile
		base_health = 30.0
		base_speed = 6.0  # 2x faster!
		base_damage = 8.0
		detection_range = 25.0
		attack_range = 2.0
		attack_cooldown = 1.0  # Attacks faster too

		# Faster animation
		walk_bob_speed = 12.0
		walk_lean_amount = 10.0  # Leans more when running

	func _ready() -> void:
		super._ready()

		if sprite:
			sprite.modulate = Color(0.9, 0.9, 0.6)  # Yellowish for runner
			sprite.scale = Vector3.ONE * 0.9  # Slightly smaller

# ============================================================================
# BRUTE - Slow, high health, high damage tank zombie
# ============================================================================
class ZombieBrute extends ZombieBase:

	func _init() -> void:
		# Tank stats
		base_health = 150.0  # 3x health!
		base_speed = 1.5  # Half speed
		base_damage = 25.0  # 2.5x damage!
		detection_range = 25.0
		attack_range = 2.5
		attack_cooldown = 2.5  # Slow attacks

		# Heavier animation
		walk_bob_speed = 5.0
		walk_bob_height = 0.1
		attack_swing_angle = 45.0

	func _ready() -> void:
		super._ready()

		if sprite:
			sprite.modulate = Color(0.8, 0.5, 0.5)  # Reddish for brute
			sprite.scale = Vector3.ONE * 1.3  # Bigger!

		# Bigger collision
		if collision_shape and collision_shape.shape:
			var shape = collision_shape.shape
			if shape is CapsuleShape3D:
				shape.radius *= 1.2
				shape.height *= 1.2

# ============================================================================
# MAGE ZOMBIE - Ranged magic attacks
# ============================================================================
class ZombieMage extends ZombieBase:

	var magic_projectile_scene: PackedScene = null
	var ranged_attack_range: float = 15.0
	var projectile_speed: float = 10.0
	var projectile_damage: float = 15.0
	var magic_cooldown: float = 2.0
	var magic_timer: float = 0.0

	func _init() -> void:
		# Ranged attacker
		base_health = 40.0
		base_speed = 2.5
		base_damage = 5.0  # Melee damage is low
		detection_range = 30.0  # Detects from farther
		attack_range = 15.0  # Keeps distance
		attack_cooldown = 2.0

		# Different animation style
		walk_bob_speed = 6.0

	func _ready() -> void:
		super._ready()

		if sprite:
			sprite.modulate = Color(0.6, 0.5, 0.9)  # Purple for mage
			sprite.scale = Vector3.ONE * 0.95

		# Try to load projectile scene
		if ResourceLoader.exists("res://scenes/effects/zombie_magic_projectile.tscn"):
			magic_projectile_scene = load("res://scenes/effects/zombie_magic_projectile.tscn")

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)

		# Update magic cooldown
		if magic_timer > 0:
			magic_timer -= delta

	func _process_attacking(delta: float) -> void:
		if not target_player or not is_instance_valid(target_player):
			current_state = State.IDLE
			return

		var distance = global_position.distance_to(target_player.global_position)

		# Mage keeps distance and casts spells
		if distance < 5.0:
			# Too close! Back away and return to chasing
			current_state = State.CHASING
			return

		if distance > ranged_attack_range * 1.2:
			current_state = State.CHASING
			return

		# Face player
		var direction_to_player = target_player.global_position - global_position
		var angle = atan2(direction_to_player.x, direction_to_player.z)
		rotation.y = angle

		# Stop moving
		velocity.x = 0
		velocity.z = 0

		# Cast spell
		if magic_timer <= 0:
			_cast_magic_projectile()
			magic_timer = magic_cooldown

		# Visual casting animation
		animation_time += delta * 3.0
		if sprite:
			sprite.position.y = abs(sin(animation_time) * 0.2)
			sprite.scale = Vector3.ONE * (0.95 + sin(animation_time) * 0.05)

	func _cast_magic_projectile() -> void:
		if not target_player or not is_instance_valid(target_player):
			return

		# Create projectile
		var projectile: Node3D = null

		if magic_projectile_scene:
			projectile = magic_projectile_scene.instantiate()
		else:
			# Fallback: create simple projectile
			projectile = _create_simple_projectile()

		if not projectile:
			return

		# Position projectile
		get_tree().root.add_child(projectile)
		projectile.global_position = global_position + Vector3.UP * 1.5

		# Set projectile direction and damage
		var direction = (target_player.global_position - global_position).normalized()

		if projectile.has_method("initialize"):
			projectile.initialize(direction, projectile_speed, projectile_damage, self)
		elif "direction" in projectile:
			projectile.direction = direction
			projectile.speed = projectile_speed
			projectile.damage = projectile_damage

	func _create_simple_projectile() -> Node3D:
		# Simple magic projectile fallback
		var projectile = Node3D.new()
		projectile.set_script(preload("res://scripts/enemies/zombie_types.gd").SimpleMagicProjectile)
		return projectile

# ============================================================================
# EXPLODER - Explodes on death, dealing area damage
# ============================================================================
class ZombieExploder extends ZombieBase:

	var explosion_radius: float = 5.0
	var explosion_damage: float = 30.0
	var explosion_scene: PackedScene = null
	var is_exploding: bool = false
	var explosion_timer: float = 0.0
	var explosion_delay: float = 0.5  # Time before explosion after death

	func _init() -> void:
		# Kamikaze stats
		base_health = 35.0
		base_speed = 4.0
		base_damage = 15.0
		detection_range = 25.0
		attack_range = 2.0
		attack_cooldown = 1.5

		# Pulsing animation
		walk_bob_speed = 10.0

	func _ready() -> void:
		super._ready()

		if sprite:
			sprite.modulate = Color(1.0, 0.6, 0.3)  # Orange for exploder

		# Try to load explosion effect
		if ResourceLoader.exists("res://scenes/effects/explosion.tscn"):
			explosion_scene = load("res://scenes/effects/explosion.tscn")

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)

		# Pulsing effect when alive
		if current_state != State.DYING and current_state != State.DEAD and sprite:
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.1
			sprite.modulate = Color(1.0, 0.6, 0.3) * pulse

		# Handle explosion countdown
		if is_exploding:
			explosion_timer -= delta
			if explosion_timer <= 0:
				_explode()

	func die() -> void:
		if current_state == State.DYING or current_state == State.DEAD:
			return

		# Don't use normal death - trigger explosion instead
		current_state = State.DYING
		is_exploding = true
		explosion_timer = explosion_delay

		# Flash red
		if sprite:
			sprite.modulate = Color.RED

		# Disable collision immediately
		if collision_shape:
			collision_shape.disabled = true

		# Disable areas
		if attack_area:
			attack_area.monitoring = false
		if detection_area:
			detection_area.monitoring = false

		# Scale up slightly before explosion
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3.ONE * 1.3, explosion_delay)

	func _explode() -> void:
		# Deal area damage
		var space_state = get_world_3d().direct_space_state

		# Find all bodies in explosion radius
		var query = PhysicsShapeQueryParameters3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = explosion_radius
		query.shape = sphere
		query.transform = Transform3D(Basis(), global_position)
		query.collision_mask = 2 | 4  # Player and Enemy layers

		var results = space_state.intersect_shape(query)

		for result in results:
			var body = result.collider
			if body and body != self:
				# Deal damage to players
				if (body.is_in_group("player") or body.is_in_group("local_player")) and body.has_method("take_damage"):
					var distance = global_position.distance_to(body.global_position)
					var damage_falloff = 1.0 - (distance / explosion_radius)
					var damage = explosion_damage * damage_falloff

					# Apply night multiplier to explosion damage too!
					if is_night_time:
						damage *= night_damage_multiplier

					body.take_damage(damage, self)

				# Also damage other zombies (chain reactions!)
				elif body.is_in_group("zombies") and body.has_method("take_damage"):
					var distance = global_position.distance_to(body.global_position)
					var damage_falloff = 1.0 - (distance / explosion_radius)
					var damage = explosion_damage * 0.5 * damage_falloff  # Half damage to zombies
					body.take_damage(damage, self)

		# Create explosion visual effect
		if explosion_scene:
			var explosion = explosion_scene.instantiate()
			get_tree().root.add_child(explosion)
			explosion.global_position = global_position
		else:
			# Fallback: create simple explosion effect
			_create_simple_explosion()

		# Emit died signal
		emit_signal("died", self)

		# Remove self
		current_state = State.DEAD
		queue_free()

	func _create_simple_explosion() -> void:
		# Simple visual explosion using particles or light
		var explosion = Node3D.new()
		get_tree().root.add_child(explosion)
		explosion.global_position = global_position

		# Add omni light for flash
		var light = OmniLight3D.new()
		light.light_color = Color.ORANGE
		light.light_energy = 5.0
		light.omni_range = explosion_radius * 2
		explosion.add_child(light)

		# Fade out and remove
		var tween = explosion.create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.5)
		tween.tween_callback(explosion.queue_free)

# ============================================================================
# SIMPLE MAGIC PROJECTILE - Fallback for mage zombie
# ============================================================================
class SimpleMagicProjectile extends Node3D:

	var direction: Vector3 = Vector3.FORWARD
	var speed: float = 10.0
	var damage: float = 15.0
	var lifetime: float = 5.0
	var caster: Node3D = null

	var sprite: Sprite3D
	var area: Area3D

	func _ready() -> void:
		# Create sprite
		sprite = Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = 0.02
		sprite.modulate = Color(0.8, 0.3, 1.0)  # Purple magic
		add_child(sprite)

		# Create collision area
		area = Area3D.new()
		var collision = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 0.3
		collision.shape = shape
		area.add_child(collision)
		add_child(area)

		area.collision_layer = 4  # Enemy layer
		area.collision_mask = 2  # Player layer
		area.body_entered.connect(_on_body_entered)

		# Set up timer for lifetime
		var timer = Timer.new()
		timer.wait_time = lifetime
		timer.one_shot = true
		timer.timeout.connect(queue_free)
		add_child(timer)
		timer.start()

	func _physics_process(delta: float) -> void:
		# Move forward
		global_position += direction * speed * delta

		# Pulse animation
		if sprite:
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.2
			sprite.scale = Vector3.ONE * pulse

	func initialize(dir: Vector3, spd: float, dmg: float, src: Node3D) -> void:
		direction = dir
		speed = spd
		damage = dmg
		caster = src

	func _on_body_entered(body: Node3D) -> void:
		if body == caster:
			return

		if body.is_in_group("player") or body.is_in_group("local_player"):
			if body.has_method("take_damage"):
				body.take_damage(damage, caster)

			# Create small impact effect
			if sprite:
				sprite.modulate = Color.WHITE

			queue_free()
