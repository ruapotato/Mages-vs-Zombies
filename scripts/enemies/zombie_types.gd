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
# MAGE ZOMBIE - Ranged magic attacks with slow homing purple orbs
# ============================================================================
class ZombieMage extends ZombieBase:

	var mage_orb_scene: PackedScene = null
	var ranged_attack_range: float = 18.0
	var orb_damage: float = 20.0
	var magic_cooldown: float = 3.0  # Slower cooldown for powerful orbs
	var magic_timer: float = 0.0
	var casting: bool = false
	var cast_time: float = 0.0
	const CAST_DURATION: float = 0.8  # Time to charge before firing

	func _init() -> void:
		# Ranged attacker
		base_health = 40.0
		base_speed = 2.5
		base_damage = 5.0  # Melee damage is low
		detection_range = 30.0  # Detects from farther
		attack_range = 18.0  # Keeps distance
		attack_cooldown = 3.0

	func _ready() -> void:
		super._ready()

		if sprite:
			sprite.modulate = Color(0.6, 0.5, 0.9)  # Purple for mage
			sprite.scale = Vector3.ONE * 0.95

		# Load homing orb projectile scene
		if ResourceLoader.exists("res://scenes/effects/mage_orb_projectile.tscn"):
			mage_orb_scene = load("res://scenes/effects/mage_orb_projectile.tscn")

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)

		# Update magic cooldown
		if magic_timer > 0:
			magic_timer -= delta

	func _process_attacking(delta: float) -> void:
		if not target_player or not is_instance_valid(target_player):
			current_state = State.IDLE
			casting = false
			return

		var distance = global_position.distance_to(target_player.global_position)

		# Mage keeps distance and casts spells
		if distance < 5.0 and not casting:
			# Too close! Back away
			current_state = State.CHASING
			return

		if distance > ranged_attack_range * 1.3 and not casting:
			current_state = State.CHASING
			return

		# Face player
		var direction_to_player = target_player.global_position - global_position
		var angle = atan2(direction_to_player.x, direction_to_player.z)
		rotation.y = angle

		# Stop moving while casting
		velocity.x = 0
		velocity.z = 0

		# Casting logic
		if casting:
			cast_time += delta
			# Charging animation - raise arms and glow
			if sprite:
				var charge_progress = cast_time / CAST_DURATION
				sprite.modulate = Color(0.6, 0.5, 0.9).lerp(Color(1.0, 0.7, 1.0), charge_progress)
				sprite.position.y = base_sprite_y + charge_progress * 0.15
				sprite.scale = Vector3.ONE * (0.95 + charge_progress * 0.1)

			if cast_time >= CAST_DURATION:
				_fire_orb()
				casting = false
				cast_time = 0.0
				magic_timer = magic_cooldown
				if sprite:
					sprite.modulate = Color(0.6, 0.5, 0.9)
		elif magic_timer <= 0:
			# Start casting
			casting = true
			cast_time = 0.0
		else:
			# Idle animation while waiting for cooldown
			anim_time += delta * 3.0
			if sprite:
				sprite.position.y = base_sprite_y + sin(anim_time) * 0.03
				sprite.scale = Vector3.ONE * 0.95

	func _fire_orb() -> void:
		if not target_player or not is_instance_valid(target_player):
			return

		var orb: Node3D = null

		if mage_orb_scene:
			orb = mage_orb_scene.instantiate()
		else:
			# Fallback: use the orb script directly
			orb = Area3D.new()
			var orb_script = load("res://scripts/enemies/mage_orb_projectile.gd")
			if orb_script:
				orb.set_script(orb_script)
			else:
				orb.queue_free()
				return

		# Position orb in front of mage at head height
		get_tree().root.add_child(orb)
		orb.global_position = global_position + Vector3.UP * 1.6

		# Calculate initial direction toward player
		var direction = (target_player.global_position + Vector3.UP - global_position).normalized()

		# Initialize orb
		if orb.has_method("initialize"):
			orb.initialize(direction, self, orb_damage)

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

		# Handle explosion countdown with scale animation (no tweens)
		if is_exploding:
			explosion_timer -= delta
			# Scale up during countdown
			var progress := 1.0 - (explosion_timer / explosion_delay)
			scale = Vector3.ONE * lerpf(1.0, 1.3, progress)
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

		# Scale up animation will happen in _physics_process

	func _explode() -> void:
		# Prevent multiple explosions
		if current_state == State.DEAD:
			return
		current_state = State.DEAD

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
					var hit_pos = body.global_position + Vector3(0, 0.9, 0)
					body.take_damage(damage, self, hit_pos)

		# Create explosion visual effect
		if explosion_scene:
			var explosion = explosion_scene.instantiate()
			get_tree().root.add_child(explosion)
			explosion.global_position = global_position
		else:
			# Fallback: create simple explosion effect
			_create_simple_explosion()

		# Emit died signal with proper arguments (zombie, was_headshot, hit_position)
		emit_signal("died", self, last_hit_was_headshot, last_hit_position)

		# Remove self
		queue_free()

	func _create_simple_explosion() -> void:
		# Simple visual explosion using light - no tweens
		var explosion = Node3D.new()
		explosion.name = "SimpleExplosion"
		get_tree().root.add_child(explosion)
		explosion.global_position = global_position

		# Add omni light for flash
		var light = OmniLight3D.new()
		light.light_color = Color.ORANGE
		light.light_energy = 5.0
		light.omni_range = explosion_radius * 2
		explosion.add_child(light)

		# Simple delayed cleanup using SceneTreeTimer (no tweens)
		get_tree().create_timer(0.5).timeout.connect(explosion.queue_free)

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
