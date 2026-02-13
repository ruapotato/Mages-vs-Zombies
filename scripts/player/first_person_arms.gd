extends Node3D
class_name FirstPersonArms

## First-person arms and wand/staff visible from player's perspective
## Rendered on a separate viewport layer so they don't clip through walls

@onready var arm_left: MeshInstance3D
@onready var arm_right: MeshInstance3D
@onready var wand: MeshInstance3D
@onready var wand_tip: MeshInstance3D

# Animation state
var idle_time: float = 0.0
var cast_animation_time: float = 0.0
var is_casting: bool = false

# Wand tip glow color based on selected spell
var current_spell_color: Color = Color(1, 0.5, 0.2)  # Fireball orange

# Skin tone (matches player mage)
var skin_color: Color = Color(0.96, 0.80, 0.69)
var robe_color: Color = Color(0.2, 0.3, 0.7)


func _ready() -> void:
	_create_arms()
	_create_wand()


func _process(delta: float) -> void:
	idle_time += delta

	# Idle bob animation
	if not is_casting:
		_animate_idle(delta)
	else:
		_animate_cast(delta)


func _create_arms() -> void:
	# Left arm (less visible, off to the side)
	arm_left = MeshInstance3D.new()
	var left_mesh = CylinderMesh.new()
	left_mesh.top_radius = 0.03
	left_mesh.bottom_radius = 0.04
	left_mesh.height = 0.35
	arm_left.mesh = left_mesh

	var left_mat = StandardMaterial3D.new()
	left_mat.albedo_color = skin_color
	arm_left.material_override = left_mat

	arm_left.position = Vector3(-0.25, -0.3, -0.35)
	arm_left.rotation_degrees = Vector3(-60, 0, 20)
	add_child(arm_left)

	# Left sleeve
	var sleeve_left = MeshInstance3D.new()
	var sleeve_mesh_l = CylinderMesh.new()
	sleeve_mesh_l.top_radius = 0.045
	sleeve_mesh_l.bottom_radius = 0.05
	sleeve_mesh_l.height = 0.15
	sleeve_left.mesh = sleeve_mesh_l

	var sleeve_mat = StandardMaterial3D.new()
	sleeve_mat.albedo_color = robe_color
	sleeve_left.material_override = sleeve_mat
	sleeve_left.position = Vector3(0, 0.15, 0)
	arm_left.add_child(sleeve_left)

	# Right arm (holding wand, more prominent)
	arm_right = MeshInstance3D.new()
	var right_mesh = CylinderMesh.new()
	right_mesh.top_radius = 0.03
	right_mesh.bottom_radius = 0.04
	right_mesh.height = 0.4
	arm_right.mesh = right_mesh

	var right_mat = StandardMaterial3D.new()
	right_mat.albedo_color = skin_color
	arm_right.material_override = right_mat

	arm_right.position = Vector3(0.2, -0.25, -0.4)
	arm_right.rotation_degrees = Vector3(-45, -15, -10)
	add_child(arm_right)

	# Right sleeve
	var sleeve_right = MeshInstance3D.new()
	var sleeve_mesh_r = CylinderMesh.new()
	sleeve_mesh_r.top_radius = 0.045
	sleeve_mesh_r.bottom_radius = 0.05
	sleeve_mesh_r.height = 0.15
	sleeve_right.mesh = sleeve_mesh_r
	sleeve_right.material_override = sleeve_mat
	sleeve_right.position = Vector3(0, 0.18, 0)
	arm_right.add_child(sleeve_right)

	# Right hand (gripping wand)
	var hand_right = MeshInstance3D.new()
	var hand_mesh = SphereMesh.new()
	hand_mesh.radius = 0.04
	hand_mesh.height = 0.06
	hand_right.mesh = hand_mesh
	hand_right.material_override = left_mat  # Same skin material
	hand_right.position = Vector3(0, -0.22, 0)
	arm_right.add_child(hand_right)


func _create_wand() -> void:
	# Wand/staff attached to right hand
	wand = MeshInstance3D.new()
	var wand_mesh = CylinderMesh.new()
	wand_mesh.top_radius = 0.015
	wand_mesh.bottom_radius = 0.02
	wand_mesh.height = 0.5
	wand.mesh = wand_mesh

	var wand_mat = StandardMaterial3D.new()
	wand_mat.albedo_color = Color(0.4, 0.25, 0.15)  # Wood color
	wand.material_override = wand_mat

	wand.position = Vector3(0.22, -0.35, -0.55)
	wand.rotation_degrees = Vector3(-30, -10, 5)
	add_child(wand)

	# Crystal/gem at tip of wand
	wand_tip = MeshInstance3D.new()
	var tip_mesh = SphereMesh.new()
	tip_mesh.radius = 0.035
	tip_mesh.height = 0.05
	wand_tip.mesh = tip_mesh

	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = current_spell_color
	tip_mat.emission_enabled = true
	tip_mat.emission = current_spell_color
	tip_mat.emission_energy_multiplier = 2.0
	wand_tip.material_override = tip_mat

	wand_tip.position = Vector3(0, 0.27, 0)
	wand.add_child(wand_tip)

	# Add a small light at wand tip
	var tip_light = OmniLight3D.new()
	tip_light.light_color = current_spell_color
	tip_light.light_energy = 0.5
	tip_light.omni_range = 1.0
	tip_light.omni_attenuation = 2.0
	wand_tip.add_child(tip_light)


func _animate_idle(delta: float) -> void:
	# Gentle breathing/swaying animation
	var bob = sin(idle_time * 1.5) * 0.01
	var sway = sin(idle_time * 0.8) * 0.5

	position.y = bob
	rotation_degrees.z = sway

	# Subtle wand tip glow pulse
	if wand_tip:
		var mat = wand_tip.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 1.5 + sin(idle_time * 3.0) * 0.5


func _animate_cast(delta: float) -> void:
	cast_animation_time += delta

	# Quick forward thrust then return
	var progress = cast_animation_time / 0.3  # 0.3 second animation

	if progress < 0.5:
		# Thrust forward
		var thrust = progress * 2.0  # 0 to 1 in first half
		arm_right.rotation_degrees.x = -45 - thrust * 30
		wand.position.z = -0.55 - thrust * 0.15

		# Brighten wand tip
		if wand_tip:
			var mat = wand_tip.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 2.0 + thrust * 6.0
	else:
		# Return
		var ret = (progress - 0.5) * 2.0  # 0 to 1 in second half
		arm_right.rotation_degrees.x = -75 + ret * 30
		wand.position.z = -0.7 + ret * 0.15

		if wand_tip:
			var mat = wand_tip.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 8.0 - ret * 6.0

	if progress >= 1.0:
		is_casting = false
		cast_animation_time = 0.0
		arm_right.rotation_degrees.x = -45
		wand.position.z = -0.55


func play_cast_animation() -> void:
	is_casting = true
	cast_animation_time = 0.0


func set_spell_color(color: Color) -> void:
	current_spell_color = color

	if wand_tip:
		var mat = wand_tip.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = color
			mat.emission = color

		# Update light color
		for child in wand_tip.get_children():
			if child is OmniLight3D:
				child.light_color = color


func set_skin_tone(skin: Color) -> void:
	skin_color = skin

	if arm_left:
		var mat = arm_left.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = skin

	if arm_right:
		var mat = arm_right.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = skin


func set_robe_color(robe: Color) -> void:
	robe_color = robe

	# Update sleeve colors
	for arm in [arm_left, arm_right]:
		if arm:
			for child in arm.get_children():
				if child is MeshInstance3D:
					var mat = child.material_override as StandardMaterial3D
					if mat and mat.albedo_color != skin_color:
						mat.albedo_color = robe
