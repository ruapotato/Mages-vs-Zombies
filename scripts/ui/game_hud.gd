extends CanvasLayer
class_name GameHUD

## GameHUD - Combat HUD with crosshair, health/mana bars, spell slots
## Based on Zombies-vs-Humans HUD style

# References to UI elements
var crosshair_dot: ColorRect
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var health_label: Label
var mana_bar_bg: ColorRect
var mana_bar_fill: ColorRect
var mana_label: Label
var spell_container: HBoxContainer
var damage_overlay: ColorRect
var wave_label: Label
var zombie_count_label: Label
var minimap: Control

# Spell slot UI elements
var spell_slots: Array[Control] = []

# Player reference
var player: Node = null

# Damage overlay state
var damage_intensity: float = 0.0
const DAMAGE_FADE_SPEED: float = 1.5


func _ready() -> void:
	layer = 10  # Above game
	_create_ui()

	# Find player
	await get_tree().process_frame
	_find_player()


func _process(delta: float) -> void:
	_update_player_stats()
	_update_damage_overlay(delta)
	_update_wave_info()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("local_player")
	if players.size() == 0:
		players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func _create_ui() -> void:
	# Root control
	var root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# === CROSSHAIR (center of screen) ===
	_create_crosshair(root)

	# === HEALTH BAR (bottom left) ===
	_create_health_bar(root)

	# === MANA BAR (below health) ===
	_create_mana_bar(root)

	# === SPELL SLOTS (bottom center) ===
	_create_spell_slots(root)

	# === DAMAGE OVERLAY (full screen red vignette) ===
	_create_damage_overlay(root)

	# === WAVE INFO (top left) ===
	_create_wave_info(root)

	# === MINIMAP (top right) ===
	_create_minimap(root)


func _create_crosshair(parent: Control) -> void:
	# Center container
	var center = Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)

	# Crosshair dot (simple white dot like ZvH)
	crosshair_dot = ColorRect.new()
	crosshair_dot.custom_minimum_size = Vector2(4, 4)
	crosshair_dot.size = Vector2(4, 4)
	crosshair_dot.position = Vector2(-2, -2)  # Center it
	crosshair_dot.color = Color(1, 1, 1, 0.9)
	crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(crosshair_dot)

	# Optional: Add crosshair lines for better visibility
	var line_length = 8
	var line_thickness = 2
	var gap = 4

	# Top line
	var top_line = ColorRect.new()
	top_line.size = Vector2(line_thickness, line_length)
	top_line.position = Vector2(-line_thickness/2, -gap - line_length)
	top_line.color = Color(1, 1, 1, 0.7)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(top_line)

	# Bottom line
	var bottom_line = ColorRect.new()
	bottom_line.size = Vector2(line_thickness, line_length)
	bottom_line.position = Vector2(-line_thickness/2, gap)
	bottom_line.color = Color(1, 1, 1, 0.7)
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(bottom_line)

	# Left line
	var left_line = ColorRect.new()
	left_line.size = Vector2(line_length, line_thickness)
	left_line.position = Vector2(-gap - line_length, -line_thickness/2)
	left_line.color = Color(1, 1, 1, 0.7)
	left_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(left_line)

	# Right line
	var right_line = ColorRect.new()
	right_line.size = Vector2(line_length, line_thickness)
	right_line.position = Vector2(gap, -line_thickness/2)
	right_line.color = Color(1, 1, 1, 0.7)
	right_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(right_line)


func _create_health_bar(parent: Control) -> void:
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(20, -80)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	# Health icon/label
	var health_icon = Label.new()
	health_icon.text = "HP"
	health_icon.position = Vector2(0, 0)
	health_icon.add_theme_font_size_override("font_size", 16)
	health_icon.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	container.add_child(health_icon)

	# Background
	health_bar_bg = ColorRect.new()
	health_bar_bg.size = Vector2(200, 20)
	health_bar_bg.position = Vector2(30, 0)
	health_bar_bg.color = Color(0.2, 0.1, 0.1, 0.8)
	container.add_child(health_bar_bg)

	# Fill
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(196, 16)
	health_bar_fill.position = Vector2(32, 2)
	health_bar_fill.color = Color(0.8, 0.2, 0.2, 1.0)
	container.add_child(health_bar_fill)

	# Value label
	health_label = Label.new()
	health_label.text = "100 / 100"
	health_label.position = Vector2(240, 0)
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.add_theme_color_override("font_color", Color(1, 1, 1))
	container.add_child(health_label)


func _create_mana_bar(parent: Control) -> void:
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(20, -50)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	# Mana icon/label
	var mana_icon = Label.new()
	mana_icon.text = "MP"
	mana_icon.position = Vector2(0, 0)
	mana_icon.add_theme_font_size_override("font_size", 16)
	mana_icon.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
	container.add_child(mana_icon)

	# Background
	mana_bar_bg = ColorRect.new()
	mana_bar_bg.size = Vector2(200, 20)
	mana_bar_bg.position = Vector2(30, 0)
	mana_bar_bg.color = Color(0.1, 0.1, 0.2, 0.8)
	container.add_child(mana_bar_bg)

	# Fill
	mana_bar_fill = ColorRect.new()
	mana_bar_fill.size = Vector2(196, 16)
	mana_bar_fill.position = Vector2(32, 2)
	mana_bar_fill.color = Color(0.2, 0.4, 1.0, 1.0)
	container.add_child(mana_bar_fill)

	# Value label
	mana_label = Label.new()
	mana_label.text = "100 / 100"
	mana_label.position = Vector2(240, 0)
	mana_label.add_theme_font_size_override("font_size", 16)
	mana_label.add_theme_color_override("font_color", Color(1, 1, 1))
	container.add_child(mana_label)


func _create_spell_slots(parent: Control) -> void:
	spell_container = HBoxContainer.new()
	spell_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spell_container.position = Vector2(-150, -100)
	spell_container.add_theme_constant_override("separation", 10)
	spell_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spell_container)

	# Create 5 spell slots
	var spell_names = ["Fire", "Frost", "Bolt", "Heal", "Wave"]
	var spell_colors = [
		Color(1.0, 0.4, 0.1),  # Fire - orange
		Color(0.3, 0.7, 1.0),  # Frost Nova - blue
		Color(1.0, 1.0, 0.3),  # Lightning - yellow
		Color(0.3, 1.0, 0.4),  # Heal - green
		Color(1.0, 0.5, 0.2),  # Flame Wave - orange-red
	]

	for i in range(5):
		var slot = _create_spell_slot(i + 1, spell_names[i], spell_colors[i])
		spell_container.add_child(slot)
		spell_slots.append(slot)


func _create_spell_slot(key: int, spell_name: String, color: Color) -> Control:
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(60, 85)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(56, 56)
	bg.position = Vector2(2, 14)
	bg.color = Color(0.1, 0.1, 0.15, 0.8)
	slot.add_child(bg)

	# Icon/color indicator
	var icon = ColorRect.new()
	icon.name = "Icon"
	icon.size = Vector2(48, 48)
	icon.position = Vector2(6, 18)
	icon.color = color
	slot.add_child(icon)

	# Key number
	var key_label = Label.new()
	key_label.text = str(key)
	key_label.position = Vector2(24, 0)
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	slot.add_child(key_label)

	# Spell name label
	var name_label = Label.new()
	name_label.text = spell_name
	name_label.position = Vector2(6, 72)
	name_label.size = Vector2(48, 14)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(name_label)

	# Cooldown overlay
	var cooldown = ColorRect.new()
	cooldown.name = "Cooldown"
	cooldown.size = Vector2(48, 0)  # Height changes based on cooldown
	cooldown.position = Vector2(6, 18)
	cooldown.color = Color(0, 0, 0, 0.7)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cooldown)

	return slot


func _create_damage_overlay(parent: Control) -> void:
	damage_overlay = ColorRect.new()
	damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.5, 0, 0, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(damage_overlay)


func _create_wave_info(parent: Control) -> void:
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.position = Vector2(20, 20)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	wave_label = Label.new()
	wave_label.text = "Wave 1"
	wave_label.position = Vector2(0, 0)
	wave_label.add_theme_font_size_override("font_size", 32)
	wave_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	container.add_child(wave_label)

	zombie_count_label = Label.new()
	zombie_count_label.text = "Zombies: 0"
	zombie_count_label.position = Vector2(0, 40)
	zombie_count_label.add_theme_font_size_override("font_size", 18)
	zombie_count_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(zombie_count_label)


func _update_player_stats() -> void:
	if not player:
		_find_player()
		return

	# Update health bar
	if "current_health" in player and "max_health" in player:
		var health_percent = player.current_health / player.max_health
		health_bar_fill.size.x = 196 * health_percent
		health_bar_fill.color = _get_health_color(health_percent)
		health_label.text = "%d / %d" % [int(player.current_health), int(player.max_health)]

		# Update damage overlay based on health
		if health_percent < 0.3:
			damage_intensity = maxf(damage_intensity, (0.3 - health_percent) * 2.0)

	# Update mana bar
	if "current_mana" in player and "max_mana" in player:
		var mana_percent = player.current_mana / player.max_mana
		mana_bar_fill.size.x = 196 * mana_percent
		mana_label.text = "%d / %d" % [int(player.current_mana), int(player.max_mana)]

	# Update spell cooldowns
	if player.has_method("get_spell_info"):
		for i in range(mini(5, spell_slots.size())):
			var info = player.get_spell_info(i)
			if info.is_empty():
				continue

			var cooldown_rect = spell_slots[i].get_node_or_null("Cooldown")
			if cooldown_rect and info.has("cooldown") and info.has("max_cooldown"):
				if info.max_cooldown > 0:
					var cooldown_percent = info.cooldown / info.max_cooldown
					cooldown_rect.size.y = 48 * cooldown_percent
				else:
					cooldown_rect.size.y = 0


func _get_health_color(percent: float) -> Color:
	if percent > 0.6:
		return Color(0.2, 0.8, 0.2)  # Green
	elif percent > 0.3:
		return Color(0.9, 0.7, 0.1)  # Yellow
	else:
		return Color(0.9, 0.2, 0.2)  # Red


func _update_damage_overlay(delta: float) -> void:
	# Fade out damage overlay
	if damage_intensity > 0:
		damage_intensity = maxf(0, damage_intensity - delta * DAMAGE_FADE_SPEED)
		damage_overlay.color.a = damage_intensity * 0.5


func _update_wave_info() -> void:
	var hordes = get_tree().get_nodes_in_group("zombie_horde")
	if hordes.size() > 0:
		var horde = hordes[0]
		if horde.has_method("get_stats"):
			var stats = horde.get_stats()
			wave_label.text = "Wave %d" % stats.current_wave
			zombie_count_label.text = "Zombies: %d" % stats.active_zombies
		elif "current_wave" in horde:
			wave_label.text = "Wave %d" % horde.current_wave
			zombie_count_label.text = "Zombies: %d" % horde.all_zombies.size()


func _create_minimap(parent: Control) -> void:
	# Load and instantiate minimap
	var MiniMapScript = load("res://scripts/ui/minimap.gd")
	minimap = Control.new()
	minimap.set_script(MiniMapScript)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-170, 20)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(minimap)


## Call this when player takes damage to flash red
func flash_damage(intensity: float = 0.5) -> void:
	damage_intensity = minf(1.0, damage_intensity + intensity)
