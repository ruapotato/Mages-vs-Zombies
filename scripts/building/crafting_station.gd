extends StaticBody3D
class_name CraftingStation

## Workbench - required for building in a 20m radius
## Provides access to crafting menu for building pieces

signal crafting_menu_opened(station: CraftingStation)
signal crafting_menu_closed(station: CraftingStation)

@export var station_name: String = "Workbench"
@export var build_radius: float = 20.0
@export var health: float = 200.0

var current_health: float
var is_active: bool = false
var players_in_range: Array = []

# Visual feedback
var range_indicator: MeshInstance3D = null
var show_range: bool = false

func _ready() -> void:
	current_health = health
	add_to_group("workbenches")
	add_to_group("building_pieces")
	add_to_group("interactable")

	_setup_collision()
	_create_mesh()
	_create_range_indicator()

func _setup_collision() -> void:
	# Create collision shape for the workbench
	var collision = CollisionShape3D.new()
	add_child(collision)

	var box = BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = box

	# Set collision layers
	collision_layer = 5  # Building + Interactable
	collision_mask = 0

func _create_mesh() -> void:
	# Create simple workbench visualization
	var mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	# Table top
	var table_mesh = BoxMesh.new()
	table_mesh.size = Vector3(1.5, 0.1, 1.0)
	mesh_instance.mesh = table_mesh
	mesh_instance.position = Vector3(0, 0.5, 0)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.35, 0.2)  # Wood color
	mesh_instance.material_override = material

	# Legs
	for x in [-0.6, 0.6]:
		for z in [-0.4, 0.4]:
			var leg = MeshInstance3D.new()
			add_child(leg)
			var leg_mesh = BoxMesh.new()
			leg_mesh.size = Vector3(0.1, 0.5, 0.1)
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.25, z)
			leg.material_override = material

func _create_range_indicator() -> void:
	# Create semi-transparent sphere to show build radius
	range_indicator = MeshInstance3D.new()
	add_child(range_indicator)

	var sphere = SphereMesh.new()
	sphere.radius = build_radius
	sphere.height = build_radius * 2
	sphere.radial_segments = 32
	sphere.rings = 16
	range_indicator.mesh = sphere

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3, 0.6, 1.0, 0.1)  # Light blue, very transparent
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	range_indicator.material_override = material

	range_indicator.visible = false

func interact(player: Node) -> bool:
	# Open crafting menu for player
	print("[CraftingStation] %s interacted with by player" % station_name)
	open_crafting_menu(player)
	return true

func open_crafting_menu(player: Node) -> void:
	is_active = true
	crafting_menu_opened.emit(self)

	# TODO: Show crafting UI
	print("[CraftingStation] Opening crafting menu...")
	print("  Available recipes: Building pieces")

func close_crafting_menu() -> void:
	is_active = false
	crafting_menu_closed.emit(self)

func is_player_in_range(player_position: Vector3) -> bool:
	return global_position.distance_to(player_position) <= build_radius

func show_build_radius(show: bool) -> void:
	show_range = show
	if range_indicator:
		range_indicator.visible = show

func take_damage(damage: float) -> void:
	current_health -= damage
	current_health = max(0, current_health)

	if current_health <= 0:
		_destroy()

func _destroy() -> void:
	print("[CraftingStation] %s destroyed!" % station_name)
	queue_free()

func get_health_percentage() -> float:
	return current_health / health
