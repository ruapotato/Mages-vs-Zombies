extends Node
class_name BuildMode

## Valheim-style building mode controller
## Toggle with B key, place buildings with left-click, rotate with R

signal build_piece_placed(piece_id: String, position: Vector3, rotation: float)
signal build_mode_toggled(active: bool)

# Building mode state
var is_active: bool = false
var current_piece_id: String = "wooden_wall"
var current_rotation: float = 0.0  # In radians

# Ghost preview
var ghost_piece: BuildingPiece = null
var ghost_position: Vector3 = Vector3.ZERO
var is_valid_placement: bool = false

# Grid snapping
@export var grid_size: float = 2.0  # 2x2 unit grid
@export var snap_to_grid: bool = true
@export var placement_distance: float = 10.0  # Max distance for placement

# References
var player: Node3D = null
var camera: Camera3D = null
var world: Node3D = null

# Workbench requirement
@export var requires_workbench: bool = true
@export var workbench_range: float = 20.0
var nearest_workbench: CraftingStation = null

# Input handling
var rotation_step: float = deg_to_rad(45.0)  # 45-degree rotation steps

func _ready() -> void:
	set_process(false)  # Only process when active

func initialize(p_player: Node3D, p_camera: Camera3D, p_world: Node3D) -> void:
	player = p_player
	camera = p_camera
	world = p_world

func _process(delta: float) -> void:
	if not is_active:
		return

	_update_ghost_position()
	_handle_input()

func _handle_input() -> void:
	# Toggle build mode with B key
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		deactivate()
		return

	# Rotate with R key
	if Input.is_action_just_pressed("ui_page_up") or Input.is_key_pressed(KEY_R):
		rotate_preview(1)

	# Cancel placement with right-click
	if Input.is_action_just_pressed("ui_cancel"):
		deactivate()

	# Place with left-click
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if is_valid_placement:
			place_current_piece()

func activate() -> void:
	if is_active:
		return

	is_active = true
	set_process(true)
	_create_ghost_preview()
	build_mode_toggled.emit(true)
	print("[BuildMode] Activated - Press B to toggle, R to rotate, Left-click to place, ESC/Right-click to cancel")

func deactivate() -> void:
	if not is_active:
		return

	is_active = false
	set_process(false)
	_destroy_ghost_preview()
	build_mode_toggled.emit(false)
	print("[BuildMode] Deactivated")

func toggle() -> void:
	if is_active:
		deactivate()
	else:
		activate()

func set_current_piece(piece_id: String) -> void:
	if current_piece_id == piece_id:
		return

	current_piece_id = piece_id
	current_rotation = 0.0

	if is_active:
		_destroy_ghost_preview()
		_create_ghost_preview()

func _create_ghost_preview() -> void:
	if ghost_piece != null:
		_destroy_ghost_preview()

	# Create ghost building piece
	ghost_piece = BuildingPiece.new()
	ghost_piece.piece_id = current_piece_id
	ghost_piece.is_ghost = true
	world.add_child(ghost_piece)

	print("[BuildMode] Created ghost preview for: %s" % current_piece_id)

func _destroy_ghost_preview() -> void:
	if ghost_piece != null:
		ghost_piece.queue_free()
		ghost_piece = null

func _update_ghost_position() -> void:
	if ghost_piece == null or camera == null:
		return

	# Raycast from camera to find placement position
	var from = camera.global_position
	var forward = -camera.global_transform.basis.z
	var to = from + forward * placement_distance

	var space_state = world.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer only

	var result = space_state.intersect_ray(query)

	if result:
		var hit_point = result.position
		var hit_normal = result.normal

		# Snap to grid if enabled
		if snap_to_grid:
			hit_point.x = round(hit_point.x / grid_size) * grid_size
			hit_point.z = round(hit_point.z / grid_size) * grid_size

		# Try to snap to nearby building pieces
		var snap_point = _find_nearest_snap_point(hit_point)
		if snap_point != Vector3.ZERO:
			ghost_position = snap_point
		else:
			ghost_position = hit_point

		# Update ghost piece transform
		ghost_piece.global_position = ghost_position
		ghost_piece.rotation.y = current_rotation

		# Validate placement
		_validate_placement()
	else:
		# No ground hit - place in front of camera at default distance
		ghost_position = from + forward * 5.0
		ghost_piece.global_position = ghost_position
		ghost_piece.rotation.y = current_rotation
		is_valid_placement = false
		ghost_piece.update_placement_validity()

func _find_nearest_snap_point(from_position: Vector3) -> Vector3:
	var nearest_point = Vector3.ZERO
	var nearest_distance = grid_size * 0.75  # Snap within 75% of grid size

	# Find all building pieces in range
	var building_pieces = get_tree().get_nodes_in_group("building_pieces")

	for piece in building_pieces:
		if piece == ghost_piece or piece is not BuildingPiece:
			continue

		# Check if piece has snap points
		var snap_points = piece.get_snap_points_world()
		for snap_point in snap_points:
			var distance = from_position.distance_to(snap_point)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_point = snap_point

	return nearest_point

func _validate_placement() -> bool:
	if ghost_piece == null:
		is_valid_placement = false
		return false

	# Check ground contact
	if not ghost_piece.is_valid_placement_on_ground():
		is_valid_placement = false
		ghost_piece.update_placement_validity()
		return false

	# Check for overlaps (handled by ghost_piece's Area3D)
	if not ghost_piece.can_place:
		is_valid_placement = false
		ghost_piece.update_placement_validity()
		return false

	# Check workbench requirement
	if requires_workbench and current_piece_id != "workbench":
		if not _is_near_workbench():
			is_valid_placement = false
			ghost_piece.update_placement_validity()
			return false

	# Check resources (if player has inventory)
	if player and player.has_method("has_resources"):
		var piece_data = BuildingPiecesData.get_instance().get_piece_data(current_piece_id)
		if piece_data != null:
			if not player.has_resources(piece_data.cost):
				is_valid_placement = false
				ghost_piece.update_placement_validity()
				return false

	# All checks passed
	is_valid_placement = true
	ghost_piece.update_placement_validity()
	return true

func _is_near_workbench() -> bool:
	if player == null:
		return false

	var workbenches = get_tree().get_nodes_in_group("workbenches")
	for workbench in workbenches:
		if workbench is CraftingStation:
			if workbench.is_player_in_range(player.global_position):
				nearest_workbench = workbench
				return true

	nearest_workbench = null
	return false

func rotate_preview(direction: int) -> void:
	if ghost_piece == null:
		return

	current_rotation += rotation_step * direction
	current_rotation = wrapf(current_rotation, 0, TAU)  # Keep between 0 and 2*PI

	ghost_piece.rotation.y = current_rotation
	print("[BuildMode] Rotated to: %.1f degrees" % rad_to_deg(current_rotation))

func place_current_piece() -> void:
	if not is_valid_placement or ghost_piece == null:
		print("[BuildMode] Cannot place - invalid placement")
		return

	# Get piece data
	var piece_data = BuildingPiecesData.get_instance().get_piece_data(current_piece_id)
	if piece_data == null:
		print("[BuildMode] ERROR: Piece data not found for: %s" % current_piece_id)
		return

	# Check and consume resources
	if player and player.has_method("consume_resources"):
		if not player.consume_resources(piece_data.cost):
			print("[BuildMode] Cannot afford to build %s" % piece_data.display_name)
			return

	# Emit signal for actual placement
	build_piece_placed.emit(current_piece_id, ghost_position, current_rotation)

	# Create the actual building piece
	var new_piece = BuildingPiece.new()
	new_piece.piece_id = current_piece_id
	new_piece.is_ghost = false
	world.add_child(new_piece)
	new_piece.global_position = ghost_position
	new_piece.rotation.y = current_rotation

	print("[BuildMode] Placed %s at %s (rotation: %.1f°)" % [
		piece_data.display_name,
		ghost_position,
		rad_to_deg(current_rotation)
	])

	# Play placement sound
	_play_placement_sound()

func _play_placement_sound() -> void:
	# TODO: Add placement sound effect
	pass

# Utility function to get building piece data
func get_current_piece_data() -> BuildingPiecesData.BuildingPieceData:
	return BuildingPiecesData.get_instance().get_piece_data(current_piece_id)

# Get list of all available building pieces
func get_available_pieces() -> Array:
	return BuildingPiecesData.get_instance().get_all_pieces()
