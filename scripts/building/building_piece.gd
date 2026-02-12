extends StaticBody3D
class_name BuildingPiece

## Individual building piece that can be placed, damaged, and destroyed
## Supports health system, snap points, and visual damage feedback

signal piece_destroyed(piece: BuildingPiece)
signal piece_damaged(piece: BuildingPiece, current_health: float, max_health: float)
signal door_interacted(piece: BuildingPiece, is_open: bool)

@export var piece_id: String = "wooden_wall"
@export var is_ghost: bool = false  # Preview mode
@export var can_place: bool = true  # Valid placement location

var piece_data: BuildingPiecesData.BuildingPieceData
var current_health: float
var is_damaged: bool = false
var damage_threshold_1: float = 0.75  # First damage visual at 75%
var damage_threshold_2: float = 0.50  # Second damage visual at 50%
var damage_threshold_3: float = 0.25  # Heavy damage visual at 25%

# Door specific
var is_door_open: bool = false

# Snap points (world coordinates)
var snap_point_nodes: Array[Node3D] = []

# Visual components
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var ghost_material: StandardMaterial3D

# Placement validation
var overlap_bodies: Array = []

func _ready() -> void:
	if not is_ghost:
		_initialize_piece()
		_create_snap_points()
		_setup_collision()
	else:
		_setup_ghost_preview()

	# Add to building group
	add_to_group("building_pieces")
	if piece_data and piece_data.is_interactive:
		add_to_group("interactable")

func _initialize_piece() -> void:
	piece_data = BuildingPiecesData.get_instance().get_piece_data(piece_id)
	if piece_data == null:
		push_error("Failed to load piece data for: %s" % piece_id)
		return

	current_health = piece_data.max_health
	_create_mesh()

func _create_mesh() -> void:
	# Create a placeholder mesh (cube/appropriate shape)
	# In production, this would load from piece_data.mesh_path
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	var mesh: Mesh
	var material = StandardMaterial3D.new()

	# Create appropriate mesh based on piece type
	match piece_data.piece_type:
		BuildingPiecesData.PieceType.ROOF:
			# Angled roof mesh
			var prism = BoxMesh.new()
			prism.size = piece_data.size
			mesh = prism

			# Rotate for roof angle
			if piece_id == "wooden_roof_26":
				mesh_instance.rotation_degrees.x = 26
			elif piece_id == "wooden_roof_45":
				mesh_instance.rotation_degrees.x = 45

		BuildingPiecesData.PieceType.STAIRS:
			# Stairs mesh (sloped box)
			var stairs_mesh = BoxMesh.new()
			stairs_mesh.size = piece_data.size
			mesh = stairs_mesh
			mesh_instance.rotation_degrees.x = 30  # Slope

		_:
			# Default box mesh for walls, floors, doors, beams
			var box_mesh = BoxMesh.new()
			box_mesh.size = piece_data.size
			mesh = box_mesh

	mesh_instance.mesh = mesh

	# Material based on material type
	if piece_data.material_type == BuildingPiecesData.MaterialType.WOOD:
		material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown
	else:  # Stone
		material.albedo_color = Color(0.5, 0.5, 0.5)  # Gray

	# Tint based on piece type
	match piece_data.piece_type:
		BuildingPiecesData.PieceType.DOOR:
			material.albedo_color = material.albedo_color.darkened(0.2)
		BuildingPiecesData.PieceType.ROOF:
			material.albedo_color = material.albedo_color.darkened(0.3)

	mesh_instance.material_override = material

func _setup_collision() -> void:
	# Create collision shape
	collision_shape = CollisionShape3D.new()
	add_child(collision_shape)

	var box_shape = BoxShape3D.new()
	box_shape.size = piece_data.size
	collision_shape.shape = box_shape

	# Set collision layers
	collision_layer = 4  # Building layer
	collision_mask = 0   # Buildings don't detect collisions actively

func _create_snap_points() -> void:
	# Create marker nodes at each snap point for visualization
	for snap_offset in piece_data.snap_points:
		var snap_marker = Node3D.new()
		snap_marker.name = "SnapPoint"
		add_child(snap_marker)
		snap_marker.position = snap_offset
		snap_point_nodes.append(snap_marker)

func _setup_ghost_preview() -> void:
	# Ghost preview for placement mode
	_initialize_piece()

	# Make semi-transparent
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.5, 1.0, 0.5, 0.5)  # Green tint

	if mesh_instance:
		mesh_instance.material_override = ghost_material

	# Disable collision for ghost
	collision_layer = 0
	collision_mask = 0

	# Add Area3D for overlap detection
	var area = Area3D.new()
	add_child(area)
	area.name = "OverlapDetector"
	area.collision_layer = 0
	area.collision_mask = 4  # Detect other buildings

	var area_shape = CollisionShape3D.new()
	area.add_child(area_shape)
	var box = BoxShape3D.new()
	box.size = piece_data.size
	area_shape.shape = box

	area.body_entered.connect(_on_overlap_entered)
	area.body_exited.connect(_on_overlap_exited)

func _on_overlap_entered(body: Node3D) -> void:
	if body is BuildingPiece and body != self:
		overlap_bodies.append(body)
		update_placement_validity()

func _on_overlap_exited(body: Node3D) -> void:
	if body in overlap_bodies:
		overlap_bodies.erase(body)
		update_placement_validity()

func update_placement_validity() -> void:
	# Check if placement is valid
	can_place = overlap_bodies.size() == 0

	# Update ghost material color
	if ghost_material:
		if can_place:
			ghost_material.albedo_color = Color(0.5, 1.0, 0.5, 0.5)  # Green = good
		else:
			ghost_material.albedo_color = Color(1.0, 0.3, 0.3, 0.5)  # Red = invalid

func take_damage(damage: float, attacker: Node = null) -> void:
	if is_ghost:
		return

	current_health -= damage
	current_health = max(0, current_health)

	var health_percent = current_health / piece_data.max_health
	_update_damage_visuals(health_percent)

	piece_damaged.emit(self, current_health, piece_data.max_health)

	if current_health <= 0:
		_destroy()

func _update_damage_visuals(health_percent: float) -> void:
	# Update material to show damage
	if not mesh_instance or not mesh_instance.material_override:
		return

	var material = mesh_instance.material_override as StandardMaterial3D
	if material == null:
		return

	# Store original color if not damaged yet
	var base_color = material.albedo_color
	if piece_data.material_type == BuildingPiecesData.MaterialType.WOOD:
		base_color = Color(0.6, 0.4, 0.2)
	else:
		base_color = Color(0.5, 0.5, 0.5)

	# Darken and redden as damage increases
	if health_percent <= damage_threshold_3:
		# Heavy damage - very dark, lots of red
		material.albedo_color = base_color.lerp(Color(0.3, 0.1, 0.1), 0.6)
		is_damaged = true
	elif health_percent <= damage_threshold_2:
		# Moderate damage
		material.albedo_color = base_color.lerp(Color(0.4, 0.2, 0.2), 0.4)
		is_damaged = true
	elif health_percent <= damage_threshold_1:
		# Light damage
		material.albedo_color = base_color.lerp(Color(0.5, 0.3, 0.3), 0.2)
		is_damaged = true
	else:
		# No visible damage
		material.albedo_color = base_color
		is_damaged = false

func repair(amount: float) -> void:
	if is_ghost:
		return

	current_health += amount
	current_health = min(current_health, piece_data.max_health)

	var health_percent = current_health / piece_data.max_health
	_update_damage_visuals(health_percent)

	piece_damaged.emit(self, current_health, piece_data.max_health)

func _destroy() -> void:
	piece_destroyed.emit(self)

	# TODO: Drop some resources (50% of cost)
	# TODO: Create destruction particles/effects

	print("[BuildingPiece] %s destroyed!" % piece_data.display_name)
	queue_free()

func interact(player: Node) -> bool:
	if not piece_data.is_interactive:
		return false

	if piece_data.piece_type == BuildingPiecesData.PieceType.DOOR:
		toggle_door()
		return true

	return false

func toggle_door() -> void:
	is_door_open = !is_door_open

	# Animate door opening/closing
	if mesh_instance:
		var tween = create_tween()
		if is_door_open:
			# Open door (rotate 90 degrees)
			tween.tween_property(mesh_instance, "rotation_degrees:y", 90.0, 0.3)
			# Disable collision when open
			if collision_shape:
				collision_shape.disabled = true
		else:
			# Close door
			tween.tween_property(mesh_instance, "rotation_degrees:y", 0.0, 0.3)
			# Re-enable collision
			if collision_shape:
				collision_shape.disabled = false

	door_interacted.emit(self, is_door_open)

func get_snap_points_world() -> Array[Vector3]:
	var world_points: Array[Vector3] = []
	for snap_node in snap_point_nodes:
		world_points.append(snap_node.global_position)
	return world_points

func get_closest_snap_point(to_position: Vector3) -> Vector3:
	var snap_points = get_snap_points_world()
	if snap_points.is_empty():
		return global_position

	var closest_point = snap_points[0]
	var closest_distance = to_position.distance_to(closest_point)

	for point in snap_points:
		var distance = to_position.distance_to(point)
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point

	return closest_point

func is_valid_placement_on_ground() -> bool:
	# Raycast down to check for ground contact
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * 3.0
	)
	query.collision_mask = 1  # Ground layer

	var result = space_state.intersect_ray(query)
	return !result.is_empty()

func get_health_percentage() -> float:
	if piece_data == null:
		return 0.0
	return current_health / piece_data.max_health

func get_display_name() -> String:
	return piece_data.display_name if piece_data else "Unknown"

func get_piece_type() -> BuildingPiecesData.PieceType:
	return piece_data.piece_type if piece_data else BuildingPiecesData.PieceType.WALL
