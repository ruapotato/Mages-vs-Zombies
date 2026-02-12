extends Node3D

## Test script for the building system
## Create a test scene with this script to verify everything works

@onready var build_mode: BuildMode = BuildMode.new()
@onready var camera: Camera3D = Camera3D.new()
@onready var test_player: Node3D = Node3D.new()

# Test inventory
var test_inventory: Dictionary = {
	"wood": 1000,
	"stone": 1000,
	"iron": 1000
}

var camera_distance: float = 10.0
var camera_angle: float = 45.0
var camera_height: float = 5.0

func _ready() -> void:
	# Set up test scene
	_setup_test_scene()
	_setup_camera()
	_setup_build_mode()

	print("\n" + "=".repeat(60))
	print("BUILDING SYSTEM TEST")
	print("=".repeat(60))
	print("\nControls:")
	print("  B - Toggle build mode")
	print("  R - Rotate piece")
	print("  1-9 - Select piece")
	print("  Left-click - Place piece")
	print("  Right-click/ESC - Cancel")
	print("  WASD - Move camera")
	print("  Q/E - Rotate camera")
	print("\nTest Functions:")
	print("  F1 - Spawn workbench at origin")
	print("  F2 - Test damage on nearest building")
	print("  F3 - Repair all buildings")
	print("  F4 - List all placed buildings")
	print("  F5 - Clear all buildings")
	print("\n" + "=".repeat(60) + "\n")

func _setup_test_scene() -> void:
	# Create ground plane
	var ground = StaticBody3D.new()
	add_child(ground)

	var ground_mesh = MeshInstance3D.new()
	ground.add_child(ground_mesh)

	var plane = PlaneMesh.new()
	plane.size = Vector2(100, 100)
	ground_mesh.mesh = plane

	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.6, 0.3)  # Green grass
	ground_mesh.material_override = ground_material

	var ground_collision = CollisionShape3D.new()
	ground.add_child(ground_collision)
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(100, 0.1, 100)
	ground_collision.shape = ground_shape

	ground.collision_layer = 1  # Ground layer

	# Create test player marker
	test_player.name = "TestPlayer"
	add_child(test_player)
	test_player.global_position = Vector3(0, 0, 0)

	var player_mesh = MeshInstance3D.new()
	test_player.add_child(player_mesh)
	var cylinder = CylinderMesh.new()
	cylinder.height = 2.0
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	player_mesh.mesh = cylinder
	player_mesh.position.y = 1.0

	var player_material = StandardMaterial3D.new()
	player_material.albedo_color = Color(0.3, 0.3, 1.0)  # Blue
	player_mesh.material_override = player_material

func _setup_camera() -> void:
	camera.name = "TestCamera"
	test_player.add_child(camera)
	_update_camera_position()

func _update_camera_position() -> void:
	var angle_rad = deg_to_rad(camera_angle)
	camera.position = Vector3(
		cos(angle_rad) * camera_distance,
		camera_height,
		sin(angle_rad) * camera_distance
	)
	camera.look_at(test_player.global_position + Vector3.UP, Vector3.UP)

func _setup_build_mode() -> void:
	add_child(build_mode)
	build_mode.initialize(test_player, camera, self)

	# Add test resource methods to test_player
	test_player.set_script(load("res://scripts/building/test_player_resources.gd"))
	test_player.inventory = test_inventory

	# Connect signals
	build_mode.build_piece_placed.connect(_on_piece_placed)
	build_mode.build_mode_toggled.connect(_on_build_mode_toggled)

	# Spawn initial workbench
	_spawn_test_workbench()

func _spawn_test_workbench() -> void:
	var workbench = CraftingStation.new()
	add_child(workbench)
	workbench.global_position = Vector3(0, 0, 5)
	print("[Test] Workbench spawned at ", workbench.global_position)

func _process(delta: float) -> void:
	_handle_camera_movement(delta)

func _handle_camera_movement(delta: float) -> void:
	var move_speed = 5.0
	var rotate_speed = 90.0

	# Move player
	var movement = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		movement.z -= 1
	if Input.is_key_pressed(KEY_S):
		movement.z += 1
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1
	if Input.is_key_pressed(KEY_D):
		movement.x += 1

	if movement != Vector3.ZERO:
		test_player.global_position += movement.normalized() * move_speed * delta

	# Rotate camera
	if Input.is_key_pressed(KEY_Q):
		camera_angle -= rotate_speed * delta
	if Input.is_key_pressed(KEY_E):
		camera_angle += rotate_speed * delta

	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E):
		_update_camera_position()

func _input(event: InputEvent) -> void:
	# Building controls
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_B:
				build_mode.toggle()

			# Piece selection
			KEY_1:
				build_mode.set_current_piece("wooden_wall")
				print("[Test] Selected: Wooden Wall")
			KEY_2:
				build_mode.set_current_piece("wooden_floor")
				print("[Test] Selected: Wooden Floor")
			KEY_3:
				build_mode.set_current_piece("wooden_door")
				print("[Test] Selected: Wooden Door")
			KEY_4:
				build_mode.set_current_piece("wooden_stairs")
				print("[Test] Selected: Wooden Stairs")
			KEY_5:
				build_mode.set_current_piece("wooden_beam")
				print("[Test] Selected: Wooden Beam")
			KEY_6:
				build_mode.set_current_piece("wooden_roof_26")
				print("[Test] Selected: Wooden Roof 26°")
			KEY_7:
				build_mode.set_current_piece("wooden_roof_45")
				print("[Test] Selected: Wooden Roof 45°")
			KEY_8:
				build_mode.set_current_piece("stone_wall")
				print("[Test] Selected: Stone Wall")
			KEY_9:
				build_mode.set_current_piece("stone_floor")
				print("[Test] Selected: Stone Floor")

			# Test functions
			KEY_F1:
				_spawn_test_workbench()
			KEY_F2:
				_test_damage()
			KEY_F3:
				_test_repair_all()
			KEY_F4:
				_list_buildings()
			KEY_F5:
				_clear_all_buildings()

func _on_piece_placed(piece_id: String, position: Vector3, rotation: float) -> void:
	print("[Test] Piece placed: %s at %s (rot: %.1f°)" % [piece_id, position, rad_to_deg(rotation)])

func _on_build_mode_toggled(active: bool) -> void:
	if active:
		print("[Test] Build mode ACTIVATED")
	else:
		print("[Test] Build mode DEACTIVATED")

func _test_damage() -> void:
	var pieces = get_tree().get_nodes_in_group("building_pieces")
	if pieces.is_empty():
		print("[Test] No buildings to damage")
		return

	# Find nearest building to player
	var nearest: BuildingPiece = null
	var nearest_dist = INF

	for piece in pieces:
		if piece is BuildingPiece and piece != build_mode.ghost_piece:
			var dist = piece.global_position.distance_to(test_player.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = piece

	if nearest:
		nearest.take_damage(25.0)
		print("[Test] Damaged %s - Health: %.1f/%.1f (%.1f%%)" % [
			nearest.get_display_name(),
			nearest.current_health,
			nearest.piece_data.max_health,
			nearest.get_health_percentage() * 100
		])

func _test_repair_all() -> void:
	var count = 0
	for piece in get_tree().get_nodes_in_group("building_pieces"):
		if piece is BuildingPiece and piece != build_mode.ghost_piece:
			piece.repair(1000.0)  # Full repair
			count += 1

	print("[Test] Repaired %d buildings" % count)

func _list_buildings() -> void:
	var pieces = get_tree().get_nodes_in_group("building_pieces")
	var count = 0

	print("\n" + "-".repeat(60))
	print("PLACED BUILDINGS:")
	print("-".repeat(60))

	for piece in pieces:
		if piece is BuildingPiece and piece != build_mode.ghost_piece:
			count += 1
			print("%d. %s - Pos: %s - HP: %.1f/%.1f (%.0f%%)" % [
				count,
				piece.get_display_name(),
				piece.global_position,
				piece.current_health,
				piece.piece_data.max_health,
				piece.get_health_percentage() * 100
			])

	print("-".repeat(60))
	print("Total: %d buildings\n" % count)

func _clear_all_buildings() -> void:
	var count = 0
	for piece in get_tree().get_nodes_in_group("building_pieces"):
		if piece is BuildingPiece and piece != build_mode.ghost_piece:
			piece.queue_free()
			count += 1

	print("[Test] Cleared %d buildings" % count)
