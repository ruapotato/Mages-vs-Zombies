extends Control

## MiniMap - Simple minimap showing player, enemies, and terrain
## Shows nearby area with enemy dots

# Map settings
const MINIMAP_SIZE := 150  # Pixels on screen
const MINIMAP_WORLD_RADIUS := 50.0  # World units visible

# Colors
const COLOR_PLAYER := Color(0.2, 0.8, 1.0)  # Cyan
const COLOR_ENEMY := Color(1.0, 0.2, 0.2)  # Red
const COLOR_ENEMY_MAGE := Color(0.7, 0.2, 1.0)  # Purple for mage zombies
const COLOR_BACKGROUND := Color(0.1, 0.15, 0.1, 0.8)
const COLOR_BORDER := Color(0.3, 0.4, 0.3)

# References
var local_player: Node3D = null

# Update throttling
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # 10 fps updates


func _ready() -> void:
	# Set size
	custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)

	# Find player
	await get_tree().process_frame
	_find_player()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		local_player = players[0]


func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := size.x / 2.0 - 5.0

	# Draw background circle
	draw_circle(center, radius + 3, COLOR_BORDER)
	draw_circle(center, radius, COLOR_BACKGROUND)

	# Draw compass directions
	_draw_compass(center, radius)

	if not local_player or not is_instance_valid(local_player):
		_find_player()
		return

	var player_pos := local_player.global_position

	# Draw enemies
	_draw_enemies(center, radius, player_pos)

	# Draw player (center, with direction indicator)
	_draw_player_marker(center)


func _draw_compass(center: Vector2, radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 10

	var directions := [
		{"label": "N", "offset": Vector2(0, -radius + 8)},
		{"label": "S", "offset": Vector2(0, radius - 2)},
		{"label": "E", "offset": Vector2(radius - 6, 4)},
		{"label": "W", "offset": Vector2(-radius + 2, 4)}
	]

	for dir in directions:
		var pos: Vector2 = center + dir.offset
		# Outline
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(font, pos + off, dir.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)
		# Text
		draw_string(font, pos, dir.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


func _draw_enemies(center: Vector2, radius: float, player_pos: Vector3) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Get relative position
		var enemy_pos: Vector3 = enemy.global_position
		var relative := Vector2(
			enemy_pos.x - player_pos.x,
			enemy_pos.z - player_pos.z
		)

		# Scale to minimap
		var map_pos := relative / MINIMAP_WORLD_RADIUS * radius

		# Clamp to circle
		if map_pos.length() > radius - 4:
			map_pos = map_pos.normalized() * (radius - 4)

		var screen_pos := center + map_pos

		# Determine color based on zombie type
		var dot_color := COLOR_ENEMY
		if enemy.has_method("get") and "zombie_type" in enemy:
			if enemy.zombie_type == "mage_zombie" or enemy.zombie_type == "mage":
				dot_color = COLOR_ENEMY_MAGE

		# Draw enemy dot
		draw_circle(screen_pos, 3, dot_color)
		draw_circle(screen_pos, 3, Color.BLACK, false, 1.0)


func _draw_player_marker(center: Vector2) -> void:
	if not local_player:
		return

	# Get player rotation for direction indicator
	var player_rot := 0.0
	var camera_mount = local_player.get_node_or_null("CameraMount")
	if camera_mount:
		# Use the player's Y rotation (body rotation)
		player_rot = local_player.rotation.y

	# Draw direction triangle
	var arrow_size := 8.0
	var angle := -player_rot - PI / 2.0  # Adjust for map orientation

	var tip := center + Vector2(cos(angle), sin(angle)) * arrow_size
	var left := center + Vector2(cos(angle + 2.5), sin(angle + 2.5)) * (arrow_size * 0.6)
	var right := center + Vector2(cos(angle - 2.5), sin(angle - 2.5)) * (arrow_size * 0.6)

	# Draw arrow
	var points := PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, COLOR_PLAYER)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.WHITE, 1.5)

	# Center dot
	draw_circle(center, 3, COLOR_PLAYER)


func set_player(player: Node3D) -> void:
	local_player = player
