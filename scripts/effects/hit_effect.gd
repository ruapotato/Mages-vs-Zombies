extends Node3D
class_name HitEffect

## HitEffect - Visual feedback when damage is dealt
## Spawns particles and a brief flash at hit location

@export var effect_color: Color = Color(1, 0.5, 0.2)
@export var is_critical: bool = false

var mesh: MeshInstance3D
var light: OmniLight3D
var particles: GPUParticles3D


func _ready() -> void:
	_create_effect()

	# Auto-destroy after effect completes
	await get_tree().create_timer(0.5).timeout
	queue_free()


func _create_effect() -> void:
	# Flash mesh
	mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.1 if not is_critical else 0.15
	sphere.height = 0.2 if not is_critical else 0.3
	mesh.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = effect_color
	material.emission_enabled = true
	material.emission = effect_color
	material.emission_energy_multiplier = 5.0 if is_critical else 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	add_child(mesh)

	# Light flash
	light = OmniLight3D.new()
	light.light_color = effect_color
	light.light_energy = 3.0 if is_critical else 2.0
	light.omni_range = 3.0 if is_critical else 2.0
	light.omni_attenuation = 2.0
	add_child(light)

	# Particles
	particles = GPUParticles3D.new()
	particles.amount = 20 if is_critical else 12
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.1
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 5.0
	particle_mat.gravity = Vector3(0, -8, 0)
	particle_mat.scale_min = 0.03
	particle_mat.scale_max = 0.08
	particle_mat.color = effect_color

	var gradient = Gradient.new()
	gradient.colors = [effect_color, effect_color * 0.5, Color(0, 0, 0, 0)]
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	particle_mat.color_ramp = ramp

	particles.process_material = particle_mat

	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.03
	particle_mesh.height = 0.06
	particles.draw_pass_1 = particle_mesh
	add_child(particles)

	# Animate
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * 1.5, 0.1)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.2)
	tween.tween_property(mesh, "scale", Vector3.ONE * 0.1, 0.2)


## Static helper to spawn a hit effect at a position
static func spawn_at(parent: Node, pos: Vector3, color: Color = Color(1, 0.5, 0.2), critical: bool = false) -> void:
	var effect = HitEffect.new()
	effect.effect_color = color
	effect.is_critical = critical
	parent.add_child(effect)
	effect.global_position = pos
