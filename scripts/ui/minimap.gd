extends Control

## MiniMap - Terrain-based minimap with enemy dots and zoom support
## Based on Hamberg minimap system with procedural terrain rendering

# Map settings
const MINIMAP_SIZE := 150  # Pixels on screen
const DEFAULT_WORLD_RADIUS := 100.0  # Default world units visible
const ZOOMED_WORLD_RADIUS := 50.0  # Zoomed in world units visible
const BUFFER_SIZE := 256  # Texture buffer size
const BUFFER_WORLD_SIZE := 400.0  # World units covered by buffer

# Biome colors matching terrain shader
const BIOME_COLORS := {
	"valley": Color(0.25, 0.55, 0.25),      # Green meadow
	"dark_forest": Color(0.15, 0.35, 0.15), # Dark green forest
	"swamp": Color(0.3, 0.35, 0.2),         # Murky green-brown
	"mountain": Color(0.6, 0.6, 0.65),      # Gray rock
	"desert": Color(0.75, 0.65, 0.35),      # Sandy yellow
	"wizardland": Color(0.5, 0.3, 0.6),     # Purple magic
	"hell": Color(0.5, 0.15, 0.1)           # Dark red
}

# Colors
const COLOR_PLAYER := Color(0.2, 0.8, 1.0)  # Cyan
const COLOR_ENEMY := Color(1.0, 0.2, 0.2)  # Red
const COLOR_ENEMY_MAGE := Color(0.7, 0.2, 1.0)  # Purple for mage zombies
const COLOR_BACKGROUND := Color(0.1, 0.15, 0.1, 0.8)
const COLOR_BORDER := Color(0.3, 0.4, 0.3)

# References
var local_player: Node3D = null
var biome_generator = null  # TerrainBiomeGenerator

# Map texture buffer
var map_texture: ImageTexture = null
var atlas_texture: AtlasTexture = null
var buffer_center: Vector2 = Vector2.ZERO
var last_player_pos: Vector2 = Vector2.ZERO

# Zoom state
var is_zoomed: bool = false
var current_world_radius: float = DEFAULT_WORLD_RADIUS

# Update throttling
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # 10 fps updates
var buffer_regen_timer: float = 0.0
const BUFFER_REGEN_INTERVAL: float = 1.0  # Regenerate buffer every second if needed


func _ready() -> void:
	# Set size
	custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)

	# Find player and biome generator
	await get_tree().process_frame
	_find_player()
	_find_biome_generator()

	# Generate initial map buffer
	if biome_generator and local_player:
		_regenerate_buffer(Vector2(local_player.global_position.x, local_player.global_position.z))


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		local_player = players[0]


func _find_biome_generator() -> void:
	# Find terrain world to get biome generator
	var terrain_worlds = get_tree().get_nodes_in_group("terrain_world")
	if terrain_worlds.size() > 0:
		var terrain_world = terrain_worlds[0]
		if "biome_generator" in terrain_world:
			biome_generator = terrain_world.biome_generator
			print("[MiniMap] Found biome generator")


func _input(event: InputEvent) -> void:
	# M key to toggle minimap zoom
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_zoom()
			get_viewport().set_input_as_handled()

	# Mouse wheel over minimap to zoom (when mouse is visible)
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var local_pos = get_local_mouse_position()
		if Rect2(Vector2.ZERO, size).has_point(local_pos):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				if not is_zoomed:
					_toggle_zoom()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				if is_zoomed:
					_toggle_zoom()
				get_viewport().set_input_as_handled()


func _toggle_zoom() -> void:
	is_zoomed = not is_zoomed
	current_world_radius = ZOOMED_WORLD_RADIUS if is_zoomed else DEFAULT_WORLD_RADIUS
	queue_redraw()


func _process(delta: float) -> void:
	update_timer += delta
	buffer_regen_timer += delta

	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0

		# Check if player moved far enough to regenerate buffer
		if local_player and is_instance_valid(local_player):
			var player_pos = Vector2(local_player.global_position.x, local_player.global_position.z)

			# Regenerate buffer if player moved too far from center
			if buffer_regen_timer >= BUFFER_REGEN_INTERVAL:
				buffer_regen_timer = 0.0
				var dist_from_center = player_pos.distance_to(buffer_center)
				if dist_from_center > BUFFER_WORLD_SIZE * 0.25:
					_regenerate_buffer(player_pos)

			last_player_pos = player_pos

		queue_redraw()


func _regenerate_buffer(center: Vector2) -> void:
	if not biome_generator:
		_find_biome_generator()
		if not biome_generator:
			return

	buffer_center = center

	# Generate terrain texture
	var img := Image.create(BUFFER_SIZE, BUFFER_SIZE, false, Image.FORMAT_RGB8)
	var units_per_pixel := BUFFER_WORLD_SIZE / float(BUFFER_SIZE)
	var start_x := center.x - (BUFFER_WORLD_SIZE * 0.5)
	var start_z := center.y - (BUFFER_WORLD_SIZE * 0.5)

	for py in BUFFER_SIZE:
		for px in BUFFER_SIZE:
			var world_x := start_x + (px * units_per_pixel)
			var world_z := start_z + (py * units_per_pixel)
			var world_pos := Vector2(world_x, world_z)

			# Get biome at this position
			var biome: String = biome_generator.get_biome_at_position(world_pos)
			var base_color: Color = BIOME_COLORS.get(biome, Color.GRAY)

			# Get height for shading
			var height: float = biome_generator.get_height_at_position(world_pos)
			var height_normalized: float = clampf((height + 20.0) / 100.0, 0.0, 1.0)
			var height_modifier: float = lerpf(0.6, 1.2, height_normalized)

			var final_color := base_color * height_modifier
			img.set_pixel(px, py, final_color)

	map_texture = ImageTexture.create_from_image(img)


func _draw() -> void:
	var center := size / 2.0
	var half_size := size.x / 2.0 - 4.0

	# Draw square background and border
	var border_rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var inner_rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(border_rect, COLOR_BORDER)
	draw_rect(inner_rect, COLOR_BACKGROUND)

	# Draw terrain texture if available
	if map_texture and local_player and is_instance_valid(local_player):
		_draw_terrain(center, half_size)

	# Draw compass directions
	_draw_compass(center, half_size)

	if not local_player or not is_instance_valid(local_player):
		_find_player()
		return

	var player_pos := local_player.global_position

	# Draw enemies
	_draw_enemies(center, half_size, player_pos)

	# Draw player (center, with direction indicator)
	_draw_player_marker(center)

	# Draw zoom indicator
	if is_zoomed:
		_draw_zoom_indicator(center, half_size)


func _draw_terrain(center: Vector2, half_size: float) -> void:
	if not map_texture or not local_player:
		return

	var player_pos := Vector2(local_player.global_position.x, local_player.global_position.z)

	# Calculate which part of the buffer to show
	var world_to_buffer := float(BUFFER_SIZE) / BUFFER_WORLD_SIZE
	var relative_pos := player_pos - buffer_center

	# Buffer pixel position of player
	var buffer_x := (BUFFER_SIZE * 0.5) + (relative_pos.x * world_to_buffer)
	var buffer_y := (BUFFER_SIZE * 0.5) + (relative_pos.y * world_to_buffer)

	# Size of visible area in buffer pixels
	var visible_buffer_pixels := current_world_radius * 2.0 * world_to_buffer

	# Region to show
	var region_x := buffer_x - (visible_buffer_pixels * 0.5)
	var region_y := buffer_y - (visible_buffer_pixels * 0.5)

	# Clamp to buffer bounds
	region_x = clampf(region_x, 0, BUFFER_SIZE - visible_buffer_pixels)
	region_y = clampf(region_y, 0, BUFFER_SIZE - visible_buffer_pixels)

	# Create atlas texture for the visible portion
	if not atlas_texture:
		atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = map_texture
	atlas_texture.region = Rect2(region_x, region_y, visible_buffer_pixels, visible_buffer_pixels)

	# Draw terrain texture as square
	var draw_size := half_size * 2.0 - 4.0
	var draw_pos := center - Vector2(half_size - 2, half_size - 2)
	draw_texture_rect(atlas_texture, Rect2(draw_pos, Vector2(draw_size, draw_size)), false)


func _draw_compass(center: Vector2, half_size: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 10

	var directions := [
		{"label": "N", "offset": Vector2(0, -half_size + 8)},
		{"label": "S", "offset": Vector2(0, half_size - 2)},
		{"label": "E", "offset": Vector2(half_size - 6, 4)},
		{"label": "W", "offset": Vector2(-half_size + 2, 4)}
	]

	for dir in directions:
		var pos: Vector2 = center + dir.offset
		# Outline
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(font, pos + off, dir.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)
		# Text
		draw_string(font, pos, dir.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


func _draw_enemies(center: Vector2, half_size: float, player_pos: Vector3) -> void:
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
		var map_pos := relative / current_world_radius * half_size

		# Clamp to square bounds
		map_pos.x = clampf(map_pos.x, -half_size + 4, half_size - 4)
		map_pos.y = clampf(map_pos.y, -half_size + 4, half_size - 4)

		var screen_pos := center + map_pos

		# Determine color based on zombie type
		var dot_color := COLOR_ENEMY
		if "zombie_type" in enemy:
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


func _draw_zoom_indicator(center: Vector2, half_size: float) -> void:
	# Draw a small indicator that we're zoomed in
	var font := ThemeDB.fallback_font
	var font_size := 8
	var text := "ZOOM"
	var pos := center + Vector2(-half_size + 5, half_size - 5)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 0, 0.7))


func set_player(player: Node3D) -> void:
	local_player = player
