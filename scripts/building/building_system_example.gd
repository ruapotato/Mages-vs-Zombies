extends Node3D

## Example script showing how to integrate the Valheim-style building system
## Add this to your main game scene or player controller

@onready var build_mode: BuildMode = BuildMode.new()
@onready var player: CharacterBody3D = $Player  # Adjust path to your player
@onready var camera: Camera3D = $Player/Camera3D  # Adjust path to your camera
@onready var world: Node3D = self  # The world/level node

func _ready() -> void:
	# Initialize the building system
	add_child(build_mode)
	build_mode.initialize(player, camera, world)

	# Connect signals
	build_mode.build_piece_placed.connect(_on_build_piece_placed)
	build_mode.build_mode_toggled.connect(_on_build_mode_toggled)

	print("[BuildingSystem] Building system initialized")
	print("  Press B to toggle build mode")
	print("  Press R to rotate pieces")
	print("  Left-click to place, Right-click/ESC to cancel")

func _input(event: InputEvent) -> void:
	# Toggle build mode with B key
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_B:
			build_mode.toggle()

		# Number keys to select building pieces (1-9)
		if event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			_select_piece_by_index(index)

func _select_piece_by_index(index: int) -> void:
	var pieces = build_mode.get_available_pieces()
	if index < pieces.size():
		var piece_data = pieces[index]
		build_mode.set_current_piece(piece_data.id)
		print("[BuildingSystem] Selected: %s" % piece_data.display_name)

func _on_build_piece_placed(piece_id: String, position: Vector3, rotation: float) -> void:
	print("[BuildingSystem] Piece placed: %s at %s" % [piece_id, position])

	# You can add additional logic here:
	# - Network synchronization
	# - Saving to database
	# - Achievement tracking
	# - etc.

func _on_build_mode_toggled(active: bool) -> void:
	if active:
		print("[BuildingSystem] Build mode ACTIVATED")
		# Optional: Show building UI, disable combat, etc.
	else:
		print("[BuildingSystem] Build mode DEACTIVATED")
		# Optional: Hide building UI, re-enable combat, etc.

# Example: Spawn a workbench at a specific location
func spawn_workbench(position: Vector3) -> void:
	var workbench = CraftingStation.new()
	world.add_child(workbench)
	workbench.global_position = position
	print("[BuildingSystem] Workbench spawned at %s" % position)

# Example: Get all building pieces within a radius
func get_buildings_in_radius(center: Vector3, radius: float) -> Array:
	var buildings = []
	var all_pieces = get_tree().get_nodes_in_group("building_pieces")

	for piece in all_pieces:
		if piece is BuildingPiece:
			if piece.global_position.distance_to(center) <= radius:
				buildings.append(piece)

	return buildings

# Example: Repair all damaged buildings in range
func repair_buildings_in_radius(center: Vector3, radius: float, repair_amount: float) -> void:
	var buildings = get_buildings_in_radius(center, radius)

	for building in buildings:
		if building.is_damaged:
			building.repair(repair_amount)
			print("[BuildingSystem] Repaired %s (+%.1f HP)" % [building.get_display_name(), repair_amount])

# Example: Check if position is inside a shelter
func is_inside_shelter(position: Vector3) -> bool:
	# Simple check: if there are walls/roof nearby, consider it shelter
	var nearby_pieces = get_buildings_in_radius(position, 5.0)

	var has_walls = false
	var has_roof = false

	for piece in nearby_pieces:
		if piece is BuildingPiece:
			match piece.get_piece_type():
				BuildingPiecesData.PieceType.WALL, BuildingPiecesData.PieceType.DOOR:
					has_walls = true
				BuildingPiecesData.PieceType.ROOF:
					has_roof = true

	return has_walls and has_roof
