extends Area3D
class_name Fireball

## Fireball - Arcing projectile with gravity, proper visuals and damage
## Paper Mario style with 3D mesh and particle effects

# Projectile settings
@export var speed: float = 20.0
@export var gravity_force: float = 8.0
@export var damage: float = 25.0
@export var explosion_radius: float = 2.0
@export var lifetime: float = 10.0

# State
var velocity: Vector3 = Vector3.ZERO
var has_hit: bool = false
var owner_node: Node = null
var time_alive: float = 0.0

# Visual components
var mesh_instance: MeshInstance3D
var light: OmniLight3D
var particles: GPUParticles3D
var trail_particles: GPUParticles3D


func _ready() -> void:
	add_to_group("player_spells")
	add_to_group("player_projectiles")

	# Setup collision
	collision_layer = 8  # Projectile layer
	collision_mask = 1 | 4  # World and Enemy layers

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Create visual components
	_create_visuals()

	# Create collision shape
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.25
	collision.shape = sphere
	add_child(collision)


func _create_visuals() -> void:
	# Fireball mesh (glowing sphere)
	mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	sphere_mesh.radial_segments = 12
	sphere_mesh.rings = 6
	mesh_instance.mesh = sphere_mesh

	# Fireball material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.0)
	material.emission_energy_multiplier = 4.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	add_child(mesh_instance)

	# Point light for glow
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 3.0
	light.omni_range = 5.0
	light.omni_attenuation = 1.5
	add_child(light)

	# Fire particles
	particles = GPUParticles3D.new()
	particles.amount = 32
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.local_coords = false

	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.15
	particle_material.direction = Vector3(0, 0, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 0.5
	particle_material.initial_velocity_max = 2.0
	particle_material.gravity = Vector3(0, 1, 0)
	particle_material.scale_min = 0.1
	particle_material.scale_max = 0.3
	particle_material.color = Color(1, 0.6, 0.1)

	var color_ramp = GradientTexture1D.new()
	var gradient = Gradient.new()
	gradient.colors = [Color(1, 0.8, 0.2, 1), Color(1, 0.3, 0.0, 0.5), Color(0.2, 0.0, 0.0, 0)]
	color_ramp.gradient = gradient
	particle_material.color_ramp = color_ramp

	particles.process_material = particle_material

	# Particle mesh (small sphere)
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	particles.draw_pass_1 = particle_mesh

	add_child(particles)

	# Trail particles (behind the fireball)
	trail_particles = GPUParticles3D.new()
	trail_particles.amount = 24
	trail_particles.lifetime = 0.6
	trail_particles.explosiveness = 0.0
	trail_particles.randomness = 0.3
	trail_particles.local_coords = false

	var trail_material = ParticleProcessMaterial.new()
	trail_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	trail_material.direction = Vector3(0, 0, 1)  # Emit backwards
	trail_material.spread = 20.0
	trail_material.initial_velocity_min = 1.0
	trail_material.initial_velocity_max = 3.0
	trail_material.gravity = Vector3(0, -2, 0)
	trail_material.scale_min = 0.05
	trail_material.scale_max = 0.15
	trail_material.color = Color(1, 0.4, 0.1)
	trail_material.color_ramp = color_ramp

	trail_particles.process_material = trail_material
	trail_particles.draw_pass_1 = particle_mesh

	add_child(trail_particles)


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	time_alive += delta
	if time_alive > lifetime:
		queue_free()
		return

	# Apply gravity (creates the arc)
	velocity.y -= gravity_force * delta

	# Move the projectile
	global_position += velocity * delta

	# Rotate to face direction of travel
	if velocity.length() > 0.5:
		var look_dir = velocity.normalized()
		if look_dir.length() > 0.01:
			look_at(global_position + look_dir, Vector3.UP)

	# Animate the fireball (pulsing)
	var pulse = 1.0 + sin(time_alive * 15.0) * 0.15
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * pulse

	# Light flicker
	if light:
		light.light_energy = 2.5 + sin(time_alive * 20.0) * 0.5


func setup(direction: Vector3, caster: Node = null) -> void:
	velocity = direction.normalized() * speed
	owner_node = caster

	# Initial look direction
	if velocity.length() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)


func setup_simple(direction: Vector3, caster: Node) -> void:
	setup(direction, caster)


func get_damage() -> float:
	return damage


func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return

	# Don't hit the caster
	if body == owner_node:
		return

	_hit(body)


func _on_area_entered(area: Area3D) -> void:
	if has_hit:
		return

	# Check if area's parent is an enemy
	var parent = area.get_parent()
	if parent and parent != owner_node:
		if parent.is_in_group("enemies") or parent.is_in_group("zombies"):
			_hit(parent)


func _hit(hit_target: Node = null) -> void:
	has_hit = true
	velocity = Vector3.ZERO

	# Deal damage to hit target
	if hit_target and hit_target.has_method("take_damage"):
		hit_target.take_damage(damage, owner_node)

	# AOE damage
	_deal_explosion_damage()

	# Explosion effect
	_spawn_explosion()

	# Disable collision
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Cleanup after explosion animation
	await get_tree().create_timer(0.5).timeout
	queue_free()


func _deal_explosion_damage() -> void:
	# Find all enemies in explosion radius
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 4  # Enemy layer

	var results = space_state.intersect_shape(query, 16)
	for result in results:
		var collider = result.collider
		if collider and collider.has_method("take_damage") and collider != owner_node:
			# Reduced damage based on distance
			var distance = global_position.distance_to(collider.global_position)
			var damage_falloff = 1.0 - (distance / explosion_radius)
			var aoe_damage = damage * 0.5 * damage_falloff  # 50% of main damage for AOE
			collider.take_damage(aoe_damage, owner_node)


func _spawn_explosion() -> void:
	# Stop normal particles
	if particles:
		particles.emitting = false
	if trail_particles:
		trail_particles.emitting = false

	# Scale up mesh quickly then fade
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3.ONE * 3.0, 0.1)
		tween.parallel().tween_property(mesh_instance, "transparency", 1.0, 0.3)

	# Bright flash
	if light:
		light.light_energy = 8.0
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.3)
		tween.tween_property(light, "omni_range", 8.0, 0.1)

	# Create explosion particles
	var explosion = GPUParticles3D.new()
	explosion.amount = 50
	explosion.lifetime = 0.5
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.emitting = true

	var exp_material = ParticleProcessMaterial.new()
	exp_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	exp_material.emission_sphere_radius = 0.3
	exp_material.direction = Vector3(0, 1, 0)
	exp_material.spread = 180.0
	exp_material.initial_velocity_min = 3.0
	exp_material.initial_velocity_max = 8.0
	exp_material.gravity = Vector3(0, -5, 0)
	exp_material.scale_min = 0.1
	exp_material.scale_max = 0.4
	exp_material.color = Color(1, 0.5, 0.1)

	var gradient = Gradient.new()
	gradient.colors = [Color(1, 0.9, 0.3, 1), Color(1, 0.4, 0.0, 0.8), Color(0.3, 0.1, 0.0, 0)]
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	exp_material.color_ramp = color_ramp

	explosion.process_material = exp_material

	var exp_mesh = SphereMesh.new()
	exp_mesh.radius = 0.08
	exp_mesh.height = 0.16
	explosion.draw_pass_1 = exp_mesh

	add_child(explosion)
