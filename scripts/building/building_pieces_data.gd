extends Node
class_name BuildingPiecesData

## Database of all available building pieces with their properties

enum PieceType {
	WALL,
	FLOOR,
	DOOR,
	ROOF,
	STAIRS,
	BEAM
}

enum MaterialType {
	WOOD,
	STONE
}

class BuildingPieceData:
	var id: String
	var display_name: String
	var piece_type: PieceType
	var material_type: MaterialType
	var max_health: float
	var cost: Dictionary  # Resource name -> amount
	var mesh_path: String
	var snap_points: Array[Vector3]  # Relative positions for snapping
	var size: Vector3  # Bounding box size
	var rotation_step: float = 90.0  # Degrees
	var is_interactive: bool = false
	var description: String = ""

	func _init(
		p_id: String,
		p_name: String,
		p_type: PieceType,
		p_material: MaterialType,
		p_health: float,
		p_cost: Dictionary,
		p_size: Vector3,
		p_snap_points: Array[Vector3] = [],
		p_interactive: bool = false,
		p_desc: String = ""
	):
		id = p_id
		display_name = p_name
		piece_type = p_type
		material_type = p_material
		max_health = p_health
		cost = p_cost
		size = p_size
		snap_points = p_snap_points
		is_interactive = p_interactive
		description = p_desc

		# Generate placeholder mesh path
		mesh_path = "res://models/building/%s.tscn" % id

# Singleton instance
static var instance: BuildingPiecesData = null

var pieces_database: Dictionary = {}

func _init():
	if instance == null:
		instance = self
	_initialize_database()

static func get_instance() -> BuildingPiecesData:
	if instance == null:
		instance = BuildingPiecesData.new()
	return instance

func _initialize_database() -> void:
	# Define snap points for different piece types
	var wall_snaps: Array[Vector3] = [
		Vector3(-1, 0, 0),   # Left
		Vector3(1, 0, 0),    # Right
		Vector3(0, 0, -1),   # Bottom
		Vector3(0, 0, 1),    # Top
	]

	var floor_snaps: Array[Vector3] = [
		Vector3(-1, 0, 0),   # Left
		Vector3(1, 0, 0),    # Right
		Vector3(0, -1, 0),   # Front
		Vector3(0, 1, 0),    # Back
	]

	var beam_snaps: Array[Vector3] = [
		Vector3(0, -1, 0),   # Bottom
		Vector3(0, 1, 0),    # Top
	]

	# WOODEN PIECES
	_add_piece(BuildingPieceData.new(
		"wooden_wall",
		"Wooden Wall",
		PieceType.WALL,
		MaterialType.WOOD,
		100.0,
		{"wood": 4, "stone": 2},
		Vector3(2, 2, 0.2),
		wall_snaps,
		false,
		"Basic wooden wall for shelter construction"
	))

	_add_piece(BuildingPieceData.new(
		"wooden_floor",
		"Wooden Floor",
		PieceType.FLOOR,
		MaterialType.WOOD,
		80.0,
		{"wood": 3},
		Vector3(2, 2, 0.2),
		floor_snaps,
		false,
		"Wooden floor tile for building platforms"
	))

	_add_piece(BuildingPieceData.new(
		"wooden_door",
		"Wooden Door",
		PieceType.DOOR,
		MaterialType.WOOD,
		60.0,
		{"wood": 4, "iron": 1},
		Vector3(1, 2, 0.2),
		wall_snaps,
		true,
		"Wooden door that can be opened and closed"
	))

	_add_piece(BuildingPieceData.new(
		"wooden_roof_26",
		"Wooden Roof 26°",
		PieceType.ROOF,
		MaterialType.WOOD,
		80.0,
		{"wood": 3, "stone": 1},
		Vector3(2, 2, 0.2),
		floor_snaps,
		false,
		"Wooden roof piece with 26 degree angle"
	))

	_add_piece(BuildingPieceData.new(
		"wooden_roof_45",
		"Wooden Roof 45°",
		PieceType.ROOF,
		MaterialType.WOOD,
		80.0,
		{"wood": 3, "stone": 1},
		Vector3(2, 2, 0.2),
		floor_snaps,
		false,
		"Wooden roof piece with 45 degree angle"
	))

	_add_piece(BuildingPieceData.new(
		"wooden_stairs",
		"Wooden Stairs",
		PieceType.STAIRS,
		MaterialType.WOOD,
		70.0,
		{"wood": 5},
		Vector3(2, 2, 2),
		floor_snaps,
		false,
		"Wooden stairs for vertical movement"
	))

	_add_piece(BuildingPieceData.new(
		"wooden_beam",
		"Wooden Beam",
		PieceType.BEAM,
		MaterialType.WOOD,
		90.0,
		{"wood": 2},
		Vector3(0.2, 2, 0.2),
		beam_snaps,
		false,
		"Vertical wooden support beam"
	))

	# STONE PIECES
	_add_piece(BuildingPieceData.new(
		"stone_wall",
		"Stone Wall",
		PieceType.WALL,
		MaterialType.STONE,
		300.0,
		{"stone": 6, "wood": 1},
		Vector3(2, 2, 0.3),
		wall_snaps,
		false,
		"Strong stone wall with high durability"
	))

	_add_piece(BuildingPieceData.new(
		"stone_floor",
		"Stone Floor",
		PieceType.FLOOR,
		MaterialType.STONE,
		250.0,
		{"stone": 4},
		Vector3(2, 2, 0.2),
		floor_snaps,
		false,
		"Durable stone floor tile"
	))

	_add_piece(BuildingPieceData.new(
		"reinforced_door",
		"Reinforced Door",
		PieceType.DOOR,
		MaterialType.STONE,
		200.0,
		{"wood": 4, "iron": 4, "stone": 2},
		Vector3(1, 2, 0.3),
		wall_snaps,
		true,
		"Heavily reinforced door with metal banding"
	))

func _add_piece(piece_data: BuildingPieceData) -> void:
	pieces_database[piece_data.id] = piece_data

func get_piece_data(piece_id: String) -> BuildingPieceData:
	if pieces_database.has(piece_id):
		return pieces_database[piece_id]
	push_error("Building piece not found: %s" % piece_id)
	return null

func get_all_pieces() -> Array:
	return pieces_database.values()

func get_pieces_by_type(type: PieceType) -> Array:
	var result: Array = []
	for piece in pieces_database.values():
		if piece.piece_type == type:
			result.append(piece)
	return result

func get_pieces_by_material(material: MaterialType) -> Array:
	var result: Array = []
	for piece in pieces_database.values():
		if piece.material_type == material:
			result.append(piece)
	return result

func can_afford(piece_id: String, inventory: Dictionary) -> bool:
	var piece_data = get_piece_data(piece_id)
	if piece_data == null:
		return false

	for resource in piece_data.cost:
		var required_amount = piece_data.cost[resource]
		var available_amount = inventory.get(resource, 0)
		if available_amount < required_amount:
			return false

	return true

func consume_resources(piece_id: String, inventory: Dictionary) -> bool:
	if not can_afford(piece_id, inventory):
		return false

	var piece_data = get_piece_data(piece_id)
	for resource in piece_data.cost:
		var required_amount = piece_data.cost[resource]
		inventory[resource] -= required_amount

	return true
