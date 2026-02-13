extends Node
## Procedural Texture Generator - Creates all 2D pixel art textures
## Generates epic mage, zombie, tree, and spell textures

# Texture cache
var texture_cache: Dictionary = {}

# Color palettes
const MAGE_ROBES := {
	"blue": [Color(0.2, 0.3, 0.7), Color(0.3, 0.4, 0.8), Color(0.15, 0.2, 0.5)],
	"red": [Color(0.7, 0.2, 0.2), Color(0.8, 0.3, 0.3), Color(0.5, 0.15, 0.15)],
	"purple": [Color(0.5, 0.2, 0.6), Color(0.6, 0.3, 0.7), Color(0.35, 0.1, 0.4)],
	"green": [Color(0.2, 0.5, 0.3), Color(0.3, 0.6, 0.4), Color(0.1, 0.35, 0.2)],
	"white": [Color(0.85, 0.85, 0.9), Color(0.95, 0.95, 1.0), Color(0.7, 0.7, 0.75)],
}

const SKIN_TONES := [
	Color(0.96, 0.80, 0.69),  # Light
	Color(0.87, 0.72, 0.53),  # Medium
	Color(0.76, 0.57, 0.42),  # Tan
	Color(0.55, 0.38, 0.26),  # Brown
	Color(0.36, 0.25, 0.18),  # Dark
]

const ZOMBIE_COLORS := {
	"walker": [Color(0.4, 0.5, 0.35), Color(0.5, 0.6, 0.4), Color(0.3, 0.4, 0.25)],
	"runner": [Color(0.5, 0.35, 0.3), Color(0.6, 0.4, 0.35), Color(0.4, 0.25, 0.2)],
	"brute": [Color(0.45, 0.4, 0.35), Color(0.55, 0.5, 0.45), Color(0.35, 0.3, 0.25)],
	"mage_zombie": [Color(0.35, 0.3, 0.5), Color(0.45, 0.4, 0.6), Color(0.25, 0.2, 0.4)],
	"exploder": [Color(0.6, 0.4, 0.3), Color(0.7, 0.5, 0.35), Color(0.5, 0.3, 0.2)],
}

const TREE_COLORS := {
	"oak": {"trunk": Color(0.4, 0.3, 0.2), "leaves": Color(0.2, 0.5, 0.2)},
	"pine": {"trunk": Color(0.35, 0.25, 0.15), "leaves": Color(0.1, 0.4, 0.2)},
	"dead": {"trunk": Color(0.3, 0.25, 0.2), "leaves": Color(0.4, 0.35, 0.3)},
	"magic": {"trunk": Color(0.3, 0.2, 0.4), "leaves": Color(0.5, 0.3, 0.7)},
	"swamp": {"trunk": Color(0.25, 0.3, 0.2), "leaves": Color(0.3, 0.4, 0.25)},
}

func _ready() -> void:
	print("[TextureGenerator] Ready - generating textures on demand")

# ============================================
# MAGE PLAYER TEXTURES (64x96 pixels)
# ============================================
func generate_mage_texture(robe_color: String = "blue", skin_idx: int = 0) -> ImageTexture:
	var cache_key := "mage_%s_%d" % [robe_color, skin_idx]
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]

	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	var robe: Array = MAGE_ROBES.get(robe_color, MAGE_ROBES["blue"])
	var skin: Color = SKIN_TONES[clamp(skin_idx, 0, SKIN_TONES.size() - 1)]

	# Fill transparent
	img.fill(Color(0, 0, 0, 0))

	# Draw mage (centered, from bottom up)
	var cx := 32  # Center x
	var by := 90  # Bottom y

	# Robe base (flowing robes)
	_draw_robe(img, cx, by, robe)

	# Body/torso
	_draw_torso(img, cx, by - 45, robe)

	# Head
	_draw_head(img, cx, by - 70, skin)

	# Wizard hat
	_draw_wizard_hat(img, cx, by - 82, robe)

	# Arms (will be animated separately in some cases)
	_draw_arms(img, cx, by - 50, skin, robe)

	# Staff/wand holder position marker (subtle)
	img.set_pixel(cx + 18, by - 45, Color(1, 1, 0, 0.5))

	var tex := ImageTexture.create_from_image(img)
	texture_cache[cache_key] = tex
	return tex

func _draw_robe(img: Image, cx: int, by: int, colors: Array) -> void:
	# Flowing robe bottom
	for y in range(by - 40, by):
		var width: int = int(12 + (y - (by - 40)) * 0.4)
		var wave: int = int(sin(y * 0.3) * 2)
		for x in range(cx - width + wave, cx + width + wave):
			if x >= 0 and x < 64:
				var shade: float = 0.9 + randf() * 0.1
				img.set_pixel(x, y, colors[0] * shade)

	# Robe edges/trim
	for y in range(by - 40, by):
		var width: int = int(12 + (y - (by - 40)) * 0.4)
		if y >= 0 and y < 96:
			if cx - width >= 0:
				img.set_pixel(cx - width, y, colors[2])
			if cx + width - 1 < 64:
				img.set_pixel(cx + width - 1, y, colors[2])

func _draw_torso(img: Image, cx: int, y: int, colors: Array) -> void:
	# Upper body
	for dy in range(-5, 15):
		var width: int = 10 - abs(dy) / 3
		for dx in range(-width, width):
			var px := cx + dx
			var py := y + dy
			if px >= 0 and px < 64 and py >= 0 and py < 96:
				img.set_pixel(px, py, colors[0])

	# Belt
	for dx in range(-8, 8):
		var px := cx + dx
		if px >= 0 and px < 64 and y + 10 < 96:
			img.set_pixel(px, y + 10, colors[2] * 0.8)

func _draw_head(img: Image, cx: int, y: int, skin: Color) -> void:
	# Circular head
	for dy in range(-8, 8):
		for dx in range(-6, 6):
			if dx * dx + dy * dy < 45:
				var px := cx + dx
				var py := y + dy
				if px >= 0 and px < 64 and py >= 0 and py < 96:
					var shade: float = 0.95 + randf() * 0.05
					img.set_pixel(px, py, skin * shade)

	# Eyes
	img.set_pixel(cx - 2, y - 1, Color(0.1, 0.1, 0.2))
	img.set_pixel(cx + 2, y - 1, Color(0.1, 0.1, 0.2))
	# Eye shine
	img.set_pixel(cx - 2, y - 2, Color(0.8, 0.8, 1.0))
	img.set_pixel(cx + 2, y - 2, Color(0.8, 0.8, 1.0))

	# Beard (wizard-style)
	for dy in range(3, 12):
		var beard_width: int = 4 - dy / 3
		for dx in range(-beard_width, beard_width + 1):
			var px := cx + dx
			var py := y + dy
			if px >= 0 and px < 64 and py >= 0 and py < 96:
				img.set_pixel(px, py, Color(0.7, 0.7, 0.75))

func _draw_wizard_hat(img: Image, cx: int, y: int, colors: Array) -> void:
	# Hat brim
	for dx in range(-10, 11):
		var px := cx + dx
		if px >= 0 and px < 64 and y + 5 >= 0 and y + 5 < 96:
			img.set_pixel(px, y + 5, colors[2])
			img.set_pixel(px, y + 6, colors[2])

	# Hat cone
	for dy in range(-25, 6):
		var width: int = int(8 - abs(dy + 10) * 0.35)
		if width > 0:
			for dx in range(-width, width):
				var px := cx + dx
				var py := y + dy
				if px >= 0 and px < 64 and py >= 0 and py < 96:
					var shade: float = 0.9 + (dx + width) / float(width * 2) * 0.2
					img.set_pixel(px, py, colors[1] * shade)

	# Hat tip (slight bend)
	for i in range(5):
		var px := cx + 3 + i
		var py := y - 25 + i
		if px >= 0 and px < 64 and py >= 0 and py < 96:
			img.set_pixel(px, py, colors[1])

	# Star on hat
	_draw_star(img, cx, y - 8, Color(1, 0.9, 0.3))

func _draw_star(img: Image, cx: int, cy: int, color: Color) -> void:
	# Simple 5-point star
	var points := [
		Vector2i(0, -3), Vector2i(1, -1), Vector2i(3, 0),
		Vector2i(1, 1), Vector2i(2, 3), Vector2i(0, 2),
		Vector2i(-2, 3), Vector2i(-1, 1), Vector2i(-3, 0),
		Vector2i(-1, -1)
	]
	for p in points:
		var px := cx + p.x
		var py := cy + p.y
		if px >= 0 and px < 64 and py >= 0 and py < 96:
			img.set_pixel(px, py, color)

func _draw_arms(img: Image, cx: int, y: int, skin: Color, robe: Array) -> void:
	# Left arm (down)
	for i in range(15):
		var px := cx - 12
		var py := y + i
		if px >= 0 and px < 64 and py >= 0 and py < 96:
			# Sleeve
			img.set_pixel(px, py, robe[0])
			img.set_pixel(px + 1, py, robe[0])
			img.set_pixel(px + 2, py, robe[0])

	# Left hand
	for dx in range(-1, 3):
		var px := cx - 12 + dx
		var py := y + 15
		if px >= 0 and px < 64 and py >= 0 and py < 96:
			img.set_pixel(px, py, skin)

	# Right arm (holding staff, angled up)
	for i in range(12):
		var px := cx + 10 + i / 2
		var py := y + 5 - i / 3
		if px >= 0 and px < 64 and py >= 0 and py < 96:
			img.set_pixel(px, py, robe[0])
			img.set_pixel(px, py + 1, robe[0])

# ============================================
# ZOMBIE TEXTURES (64x96 pixels)
# ============================================
func generate_zombie_texture(zombie_type: String = "walker") -> ImageTexture:
	var cache_key := "zombie_%s" % zombie_type
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]

	var size := Vector2i(64, 96)
	if zombie_type == "brute":
		size = Vector2i(80, 112)

	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var colors: Array = ZOMBIE_COLORS.get(zombie_type, ZOMBIE_COLORS["walker"])

	img.fill(Color(0, 0, 0, 0))

	var cx := size.x / 2
	var by := size.y - 6

	match zombie_type:
		"walker":
			_draw_walker_zombie(img, cx, by, colors)
		"runner":
			_draw_runner_zombie(img, cx, by, colors)
		"brute":
			_draw_brute_zombie(img, cx, by, colors)
		"mage_zombie":
			_draw_mage_zombie(img, cx, by, colors)
		"exploder":
			_draw_exploder_zombie(img, cx, by, colors)
		_:
			_draw_walker_zombie(img, cx, by, colors)

	var tex := ImageTexture.create_from_image(img)
	texture_cache[cache_key] = tex
	return tex

func _draw_walker_zombie(img: Image, cx: int, by: int, colors: Array) -> void:
	# Tattered clothes body
	for y in range(by - 50, by - 10):
		var width: int = 8 + int((y - (by - 50)) * 0.15)
		for x in range(cx - width, cx + width):
			if x >= 0 and x < img.get_width() and randf() > 0.1:
				var shade: float = 0.8 + randf() * 0.2
				img.set_pixel(x, y, colors[0] * shade)

	# Legs (shambling pose)
	_draw_zombie_legs(img, cx, by, colors)

	# Arms (reaching forward)
	_draw_zombie_arms(img, cx, by - 35, colors, false)

	# Head
	_draw_zombie_head(img, cx, by - 60, colors, false)

func _draw_runner_zombie(img: Image, cx: int, by: int, colors: Array) -> void:
	# Leaner body
	for y in range(by - 45, by - 10):
		var lean: int = int((y - (by - 45)) * 0.1)
		var width: int = 6 + int((y - (by - 45)) * 0.1)
		for x in range(cx - width + lean, cx + width + lean):
			if x >= 0 and x < img.get_width() and randf() > 0.05:
				img.set_pixel(x, y, colors[0] * (0.85 + randf() * 0.15))

	_draw_zombie_legs(img, cx, by, colors)
	_draw_zombie_arms(img, cx + 5, by - 32, colors, true)
	_draw_zombie_head(img, cx + 3, by - 55, colors, true)

func _draw_brute_zombie(img: Image, cx: int, by: int, colors: Array) -> void:
	# Massive body
	for y in range(by - 70, by - 15):
		var width: int = 18 + int((y - (by - 70)) * 0.2)
		for x in range(cx - width, cx + width):
			if x >= 0 and x < img.get_width():
				var shade: float = 0.75 + randf() * 0.25
				img.set_pixel(x, y, colors[0] * shade)

	# Thick legs
	for leg_offset in [-10, 10]:
		for y in range(by - 15, by):
			for dx in range(-6, 6):
				var px := cx + leg_offset + dx
				if px >= 0 and px < img.get_width():
					img.set_pixel(px, y, colors[2])

	# Huge arms
	for arm_side in [-1, 1]:
		for i in range(25):
			var px := cx + arm_side * (20 + i / 4)
			var py := by - 55 + i
			for dx in range(-4, 5):
				var ppx := px + dx
				if ppx >= 0 and ppx < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(ppx, py, colors[1])

	# Big head
	for dy in range(-15, 10):
		for dx in range(-12, 13):
			if dx * dx / 2 + dy * dy < 120:
				var px := cx + dx
				var py := by - 80 + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, colors[1])

	# Angry eyes
	img.set_pixel(cx - 5, by - 82, Color(1, 0.2, 0.1))
	img.set_pixel(cx + 5, by - 82, Color(1, 0.2, 0.1))

func _draw_mage_zombie(img: Image, cx: int, by: int, colors: Array) -> void:
	# Robed undead mage
	for y in range(by - 55, by - 5):
		var width: int = 10 + int((y - (by - 55)) * 0.25)
		var wave: int = int(sin(y * 0.2) * 2)
		for x in range(cx - width + wave, cx + width + wave):
			if x >= 0 and x < img.get_width():
				img.set_pixel(x, y, colors[0] * (0.8 + randf() * 0.2))

	# Ghostly lower half
	for y in range(by - 5, by):
		var alpha: float = 1.0 - (y - (by - 5)) / 5.0
		var width: int = 12
		for x in range(cx - width, cx + width):
			if x >= 0 and x < img.get_width():
				var c := colors[0]
				c.a = alpha * 0.7
				img.set_pixel(x, y, c)

	# Skull head
	for dy in range(-12, 8):
		for dx in range(-8, 9):
			if dx * dx + dy * dy < 70:
				var px := cx + dx
				var py := by - 68 + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, Color(0.8, 0.75, 0.7))

	# Glowing eyes
	img.set_pixel(cx - 3, by - 70, Color(0.3, 1.0, 0.4))
	img.set_pixel(cx + 3, by - 70, Color(0.3, 1.0, 0.4))
	img.set_pixel(cx - 3, by - 69, Color(0.2, 0.8, 0.3))
	img.set_pixel(cx + 3, by - 69, Color(0.2, 0.8, 0.3))

	# Magic orb in hands
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			if dx * dx + dy * dy < 18:
				var px := cx + dx
				var py := by - 35 + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					var dist: float = sqrt(dx * dx + dy * dy)
					var glow: Color = Color(0.5, 0.2, 0.8).lerp(Color(0.8, 0.4, 1.0), 1.0 - dist / 4.0)
					img.set_pixel(px, py, glow)

func _draw_exploder_zombie(img: Image, cx: int, by: int, colors: Array) -> void:
	# Bloated body
	for y in range(by - 50, by - 10):
		var bloat: float = sin((y - (by - 50)) / 40.0 * PI)
		var width: int = int(8 + bloat * 12)
		for x in range(cx - width, cx + width):
			if x >= 0 and x < img.get_width():
				# Pustules
				var is_pustule: bool = randf() < 0.08
				var color: Color = colors[0] if not is_pustule else Color(0.7, 0.5, 0.2)
				img.set_pixel(x, y, color * (0.8 + randf() * 0.2))

	_draw_zombie_legs(img, cx, by, colors)

	# Short stubby arms
	for arm_side in [-1, 1]:
		for i in range(8):
			var px := cx + arm_side * (12 + i / 3)
			var py := by - 35 + i
			for dx in range(-2, 3):
				var ppx := px + dx
				if ppx >= 0 and ppx < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(ppx, py, colors[1])

	# Bloated head
	for dy in range(-10, 6):
		for dx in range(-8, 9):
			if dx * dx + dy * dy < 60:
				var px := cx + dx
				var py := by - 58 + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, colors[1])

	# Veiny angry eyes
	img.set_pixel(cx - 3, by - 60, Color(1, 0.3, 0.1))
	img.set_pixel(cx + 3, by - 60, Color(1, 0.3, 0.1))

	# Warning glow (about to explode look)
	for y in range(by - 45, by - 20):
		for x in range(cx - 8, cx + 9):
			if x >= 0 and x < img.get_width() and randf() < 0.3:
				var existing: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, existing.lerp(Color(1, 0.5, 0.1), 0.3))

func _draw_zombie_legs(img: Image, cx: int, by: int, colors: Array) -> void:
	# Shambling legs
	for leg_offset in [-5, 5]:
		var leg_forward: int = 2 if leg_offset < 0 else -2
		for y in range(by - 10, by):
			for dx in range(-3, 3):
				var px := cx + leg_offset + dx + leg_forward * (y - (by - 10)) / 10
				if px >= 0 and px < img.get_width():
					img.set_pixel(px, y, colors[2])

func _draw_zombie_arms(img: Image, cx: int, y: int, colors: Array, reaching: bool) -> void:
	for arm_side in [-1, 1]:
		var reach_ext: int = 8 if reaching else 0
		for i in range(15 + reach_ext):
			var px := cx + arm_side * (10 + i / 2)
			var py := y + i / 3 - reach_ext / 4
			for dx in range(-2, 3):
				var ppx := px + dx
				if ppx >= 0 and ppx < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(ppx, py, colors[1])

func _draw_zombie_head(img: Image, cx: int, y: int, colors: Array, tilted: bool) -> void:
	var tilt: int = 3 if tilted else 0
	for dy in range(-10, 8):
		for dx in range(-7, 8):
			if dx * dx + dy * dy < 55:
				var px := cx + dx + (dy * tilt / 10)
				var py := y + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, colors[1])

	# Dead eyes
	img.set_pixel(cx - 3 + tilt, y - 2, Color(0.8, 0.2, 0.1))
	img.set_pixel(cx + 3 + tilt, y - 2, Color(0.8, 0.2, 0.1))

	# Mouth/jaw
	for dx in range(-4, 5):
		var px := cx + dx + tilt / 2
		if px >= 0 and px < img.get_width() and y + 4 < img.get_height():
			img.set_pixel(px, y + 4, colors[2] * 0.5)

# ============================================
# TREE TEXTURES (Billboard 2D trees)
# ============================================
func generate_tree_texture(tree_type: String = "oak") -> ImageTexture:
	var cache_key := "tree_%s" % tree_type
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]

	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	var tree_data: Dictionary = TREE_COLORS.get(tree_type, TREE_COLORS["oak"])
	var trunk_color: Color = tree_data["trunk"]
	var leaves_color: Color = tree_data["leaves"]

	img.fill(Color(0, 0, 0, 0))

	var cx := 32
	var by := 124

	match tree_type:
		"oak":
			_draw_oak_tree(img, cx, by, trunk_color, leaves_color)
		"pine":
			_draw_pine_tree(img, cx, by, trunk_color, leaves_color)
		"dead":
			_draw_dead_tree(img, cx, by, trunk_color)
		"magic":
			_draw_magic_tree(img, cx, by, trunk_color, leaves_color)
		"swamp":
			_draw_swamp_tree(img, cx, by, trunk_color, leaves_color)
		_:
			_draw_oak_tree(img, cx, by, trunk_color, leaves_color)

	var tex := ImageTexture.create_from_image(img)
	texture_cache[cache_key] = tex
	return tex

func _draw_oak_tree(img: Image, cx: int, by: int, trunk: Color, leaves: Color) -> void:
	# Trunk
	for y in range(by - 50, by):
		var width: int = 4 + int((by - y) * 0.03)
		for dx in range(-width, width + 1):
			var px := cx + dx
			if px >= 0 and px < 64:
				var shade: float = 0.8 + randf() * 0.2
				img.set_pixel(px, y, trunk * shade)

	# Leafy canopy (multiple clusters)
	var centers := [Vector2i(cx, by - 70), Vector2i(cx - 12, by - 60), Vector2i(cx + 12, by - 60)]
	for center in centers:
		for dy in range(-25, 20):
			for dx in range(-20, 21):
				if dx * dx + dy * dy < 350 + randf() * 100:
					var px := center.x + dx
					var py := center.y + dy
					if px >= 0 and px < 64 and py >= 0 and py < 128:
						var shade: float = 0.7 + randf() * 0.3
						var existing: Color = img.get_pixel(px, py)
						if existing.a < 0.5:
							img.set_pixel(px, py, leaves * shade)

func _draw_pine_tree(img: Image, cx: int, by: int, trunk: Color, leaves: Color) -> void:
	# Trunk
	for y in range(by - 35, by):
		for dx in range(-3, 4):
			var px := cx + dx
			if px >= 0 and px < 64:
				img.set_pixel(px, y, trunk * (0.85 + randf() * 0.15))

	# Triangular pine layers
	for layer in range(4):
		var layer_y: int = by - 45 - layer * 22
		var layer_width: int = 25 - layer * 4
		for y in range(layer_y, layer_y + 25):
			var progress: float = (y - layer_y) / 25.0
			var width: int = int(layer_width * (1.0 - progress))
			for dx in range(-width, width + 1):
				var px := cx + dx
				if px >= 0 and px < 64 and y >= 0 and y < 128:
					var shade: float = 0.75 + randf() * 0.25
					img.set_pixel(px, y, leaves * shade)

func _draw_dead_tree(img: Image, cx: int, by: int, trunk: Color) -> void:
	# Gnarled trunk
	for y in range(by - 80, by):
		var twist: int = int(sin(y * 0.1) * 3)
		var width: int = 3 + int((by - y) * 0.02)
		for dx in range(-width, width + 1):
			var px := cx + dx + twist
			if px >= 0 and px < 64:
				img.set_pixel(px, y, trunk * (0.7 + randf() * 0.3))

	# Dead branches
	var branches := [
		{"start": Vector2i(cx, by - 60), "dir": Vector2i(15, -20)},
		{"start": Vector2i(cx, by - 50), "dir": Vector2i(-18, -15)},
		{"start": Vector2i(cx, by - 40), "dir": Vector2i(12, -25)},
		{"start": Vector2i(cx, by - 70), "dir": Vector2i(-10, -18)},
	]
	for branch in branches:
		_draw_branch(img, branch["start"], branch["dir"], trunk, 8)

func _draw_branch(img: Image, start: Vector2i, dir: Vector2i, color: Color, length: int) -> void:
	for i in range(length):
		var t: float = i / float(length)
		var px: int = start.x + int(dir.x * t)
		var py: int = start.y + int(dir.y * t)
		var width: int = max(1, 3 - i / 3)
		for dx in range(-width, width + 1):
			var ppx := px + dx
			if ppx >= 0 and ppx < 64 and py >= 0 and py < 128:
				img.set_pixel(ppx, py, color * (0.8 + randf() * 0.2))

func _draw_magic_tree(img: Image, cx: int, by: int, trunk: Color, leaves: Color) -> void:
	# Glowing trunk
	for y in range(by - 60, by):
		var width: int = 4 + int((by - y) * 0.025)
		for dx in range(-width, width + 1):
			var px := cx + dx
			if px >= 0 and px < 64:
				var glow: Color = trunk.lerp(Color(0.6, 0.3, 0.8), randf() * 0.3)
				img.set_pixel(px, y, glow)

	# Mystical canopy with sparkles
	for dy in range(-55, 10):
		for dx in range(-22, 23):
			if dx * dx + dy * dy < 400 + randf() * 150:
				var px := cx + dx
				var py := by - 75 + dy
				if px >= 0 and px < 64 and py >= 0 and py < 128:
					var is_sparkle: bool = randf() < 0.05
					var color: Color = leaves if not is_sparkle else Color(1, 0.9, 1.0)
					img.set_pixel(px, py, color * (0.7 + randf() * 0.3))

func _draw_swamp_tree(img: Image, cx: int, by: int, trunk: Color, leaves: Color) -> void:
	# Twisted trunk with roots
	for y in range(by - 55, by):
		var twist: int = int(sin(y * 0.15) * 4)
		var width: int = 3 + int((by - y) * 0.02) + (2 if y > by - 10 else 0)
		for dx in range(-width, width + 1):
			var px := cx + dx + twist
			if px >= 0 and px < 64:
				img.set_pixel(px, y, trunk * (0.7 + randf() * 0.2))

	# Scraggly moss-covered canopy
	for dy in range(-40, 15):
		for dx in range(-18, 19):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 25 + randf() * 10:
				var px := cx + dx
				var py := by - 70 + dy
				if px >= 0 and px < 64 and py >= 0 and py < 128 and randf() > 0.15:
					# Moss-like variation
					var moss: Color = leaves.lerp(Color(0.4, 0.45, 0.3), randf() * 0.4)
					img.set_pixel(px, py, moss)

	# Hanging moss
	for x in range(cx - 15, cx + 16, 3):
		if randf() > 0.4:
			var hang_length: int = randi_range(8, 20)
			for y in range(by - 55, by - 55 + hang_length):
				if x >= 0 and x < 64 and y >= 0 and y < 128:
					img.set_pixel(x, y, Color(0.35, 0.4, 0.3, 0.8))

# ============================================
# SPELL EFFECT TEXTURES
# ============================================
func generate_spell_texture(spell_type: String) -> ImageTexture:
	var cache_key := "spell_%s" % spell_type
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]

	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match spell_type:
		"fireball":
			_draw_fireball_texture(img)
		"ice_shard":
			_draw_ice_shard_texture(img)
		"lightning":
			_draw_lightning_texture(img)
		"arcane":
			_draw_arcane_texture(img)
		"nature":
			_draw_nature_texture(img)
		"dark":
			_draw_dark_texture(img)
		"holy":
			_draw_holy_texture(img)
		_:
			_draw_arcane_texture(img)

	var tex := ImageTexture.create_from_image(img)
	texture_cache[cache_key] = tex
	return tex

func _draw_fireball_texture(img: Image) -> void:
	var cx := 16
	var cy := 16
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 12:
				var px := cx + dx
				var py := cy + dy
				var t: float = dist / 12.0
				var color: Color = Color(1, 0.9, 0.3).lerp(Color(1, 0.3, 0.1), t)
				color.a = 1.0 - t * 0.5
				img.set_pixel(px, py, color)

func _draw_ice_shard_texture(img: Image) -> void:
	var cx := 16
	var cy := 16
	# Crystal shape
	var points := [Vector2i(0, -12), Vector2i(6, 0), Vector2i(0, 12), Vector2i(-6, 0)]
	for i in range(points.size()):
		var p1: Vector2i = points[i]
		var p2: Vector2i = points[(i + 1) % points.size()]
		for t in range(20):
			var tt: float = t / 20.0
			var px: int = cx + int(p1.x + (p2.x - p1.x) * tt)
			var py: int = cy + int(p1.y + (p2.y - p1.y) * tt)
			if px >= 0 and px < 32 and py >= 0 and py < 32:
				img.set_pixel(px, py, Color(0.7, 0.9, 1.0))
	# Fill with gradient
	for dy in range(-10, 11):
		for dx in range(-5, 6):
			var px := cx + dx
			var py := cy + dy
			if px >= 0 and px < 32 and py >= 0 and py < 32:
				var existing: Color = img.get_pixel(px, py)
				if existing.a < 0.5:
					var t: float = abs(dy) / 10.0
					img.set_pixel(px, py, Color(0.5, 0.8, 1.0, 0.8 - t * 0.5))

func _draw_lightning_texture(img: Image) -> void:
	var cx := 16
	# Lightning bolt shape
	var y := 2
	var x := cx
	while y < 30:
		var next_x: int = x + randi_range(-3, 3)
		var next_y: int = y + randi_range(2, 5)
		for yy in range(y, min(next_y, 30)):
			var xx: int = x + int((next_x - x) * (yy - y) / float(next_y - y))
			if xx >= 0 and xx < 32:
				img.set_pixel(xx, yy, Color(1, 1, 0.5))
				if xx > 0:
					img.set_pixel(xx - 1, yy, Color(0.8, 0.8, 1.0, 0.6))
				if xx < 31:
					img.set_pixel(xx + 1, yy, Color(0.8, 0.8, 1.0, 0.6))
		x = next_x
		y = next_y

func _draw_arcane_texture(img: Image) -> void:
	var cx := 16
	var cy := 16
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 10 and dist > 4:
				var angle: float = atan2(dy, dx)
				var pulse: float = sin(angle * 6) * 0.3 + 0.7
				var px := cx + dx
				var py := cy + dy
				img.set_pixel(px, py, Color(0.6, 0.3, 0.9, pulse))
	# Center orb
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			if dx * dx + dy * dy < 16:
				img.set_pixel(cx + dx, cy + dy, Color(0.8, 0.5, 1.0))

func _draw_nature_texture(img: Image) -> void:
	var cx := 16
	var cy := 16
	# Leaf-like shape
	for dy in range(-12, 13):
		for dx in range(-8, 9):
			var leaf_shape: float = abs(dx) * 1.5 + abs(dy) * 0.8
			if leaf_shape < 12:
				var px := cx + dx
				var py := cy + dy
				var shade: float = 0.7 + randf() * 0.3
				img.set_pixel(px, py, Color(0.3, 0.7, 0.3) * shade)

func _draw_dark_texture(img: Image) -> void:
	var cx := 16
	var cy := 16
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 11:
				var px := cx + dx
				var py := cy + dy
				var t: float = dist / 11.0
				var alpha: float = 0.9 - t * 0.6
				var color: Color = Color(0.2, 0.1, 0.3).lerp(Color(0.4, 0.1, 0.5), t)
				color.a = alpha
				img.set_pixel(px, py, color)

func _draw_holy_texture(img: Image) -> void:
	var cx := 16
	var cy := 16
	# Glowing cross/star shape
	for i in range(-10, 11):
		if cx + i >= 0 and cx + i < 32:
			img.set_pixel(cx + i, cy, Color(1, 1, 0.8))
		if cy + i >= 0 and cy + i < 32:
			img.set_pixel(cx, cy + i, Color(1, 1, 0.8))
	# Glow around
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 7 and dist > 1:
				var px := cx + dx
				var py := cy + dy
				var existing: Color = img.get_pixel(px, py)
				if existing.a < 0.5:
					img.set_pixel(px, py, Color(1, 0.95, 0.7, 0.5 - dist * 0.05))

# ============================================
# WAND/STAFF TEXTURES
# ============================================
func generate_wand_texture(wand_type: String = "basic") -> ImageTexture:
	var cache_key := "wand_%s" % wand_type
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]

	var img := Image.create(16, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var cx := 8
	var by := 44

	match wand_type:
		"basic":
			_draw_basic_wand(img, cx, by)
		"fire":
			_draw_fire_wand(img, cx, by)
		"ice":
			_draw_ice_wand(img, cx, by)
		"lightning":
			_draw_lightning_wand(img, cx, by)
		"staff":
			_draw_staff(img, cx, by)
		_:
			_draw_basic_wand(img, cx, by)

	var tex := ImageTexture.create_from_image(img)
	texture_cache[cache_key] = tex
	return tex

func _draw_basic_wand(img: Image, cx: int, by: int) -> void:
	# Wooden wand
	for y in range(by - 35, by):
		for dx in range(-2, 3):
			var px := cx + dx
			if px >= 0 and px < 16:
				img.set_pixel(px, y, Color(0.5, 0.35, 0.2) * (0.9 + randf() * 0.1))
	# Crystal tip
	for dy in range(-8, 0):
		for dx in range(-2, 3):
			if abs(dx) + abs(dy) / 2 < 4:
				var px := cx + dx
				var py := by - 35 + dy
				if py >= 0 and px >= 0 and px < 16:
					img.set_pixel(px, py, Color(0.6, 0.7, 0.9))

func _draw_fire_wand(img: Image, cx: int, by: int) -> void:
	# Dark wood
	for y in range(by - 32, by):
		for dx in range(-2, 3):
			var px := cx + dx
			if px >= 0 and px < 16:
				img.set_pixel(px, y, Color(0.3, 0.15, 0.1) * (0.9 + randf() * 0.1))
	# Flame orb tip
	for dy in range(-10, 2):
		for dx in range(-4, 5):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 5:
				var px := cx + dx
				var py := by - 35 + dy
				if py >= 0 and px >= 0 and px < 16:
					var t: float = dist / 5.0
					img.set_pixel(px, py, Color(1, 0.6, 0.2).lerp(Color(1, 0.2, 0.1), t))

func _draw_ice_wand(img: Image, cx: int, by: int) -> void:
	# Crystal shaft
	for y in range(by - 32, by):
		for dx in range(-2, 3):
			var px := cx + dx
			if px >= 0 and px < 16:
				img.set_pixel(px, y, Color(0.7, 0.85, 0.95) * (0.9 + randf() * 0.1))
	# Ice crystal tip
	for dy in range(-12, 0):
		var width: int = max(1, 4 - abs(dy + 6) / 2)
		for dx in range(-width, width + 1):
			var px := cx + dx
			var py := by - 35 + dy
			if py >= 0 and px >= 0 and px < 16:
				img.set_pixel(px, py, Color(0.5, 0.8, 1.0))

func _draw_lightning_wand(img: Image, cx: int, by: int) -> void:
	# Metal shaft
	for y in range(by - 30, by):
		for dx in range(-2, 3):
			var px := cx + dx
			if px >= 0 and px < 16:
				img.set_pixel(px, y, Color(0.6, 0.6, 0.65) * (0.85 + randf() * 0.15))
	# Crackling orb
	for dy in range(-10, 2):
		for dx in range(-4, 5):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 5:
				var px := cx + dx
				var py := by - 33 + dy
				if py >= 0 and px >= 0 and px < 16:
					var is_spark: bool = randf() < 0.2
					var color: Color = Color(0.9, 0.9, 1.0) if not is_spark else Color(1, 1, 0.5)
					img.set_pixel(px, py, color)

func _draw_staff(img: Image, cx: int, by: int) -> void:
	# Long wooden staff
	for y in range(4, by):
		for dx in range(-2, 3):
			var px := cx + dx
			if px >= 0 and px < 16:
				img.set_pixel(px, y, Color(0.45, 0.3, 0.15) * (0.85 + randf() * 0.15))
	# Crystal head
	for dy in range(-8, 4):
		for dx in range(-4, 5):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 5:
				var px := cx + dx
				var py := 6 + dy
				if py >= 0 and px >= 0 and px < 16:
					img.set_pixel(px, py, Color(0.7, 0.4, 0.9) * (0.8 + randf() * 0.2))

# ============================================
# STAFF/WAND TEXTURE (16x64 pixels)
# ============================================
func generate_staff_texture(staff_type: String = "arcane") -> ImageTexture:
	var cache_key := "staff_%s" % staff_type
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]

	var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var cx := 8
	var by := 60

	# Staff shaft (wood)
	for y in range(15, by):
		for dx in range(-1, 2):
			var px := cx + dx
			if px >= 0 and px < 16:
				var shade := 0.85 + randf() * 0.15
				img.set_pixel(px, y, Color(0.45, 0.3, 0.15) * shade)

	# Crystal/gem head based on type
	var gem_color: Color
	match staff_type:
		"fire":
			gem_color = Color(1.0, 0.3, 0.1)
		"ice":
			gem_color = Color(0.3, 0.7, 1.0)
		"lightning":
			gem_color = Color(1.0, 1.0, 0.3)
		"arcane", _:
			gem_color = Color(0.6, 0.3, 0.9)

	# Crystal shape
	for dy in range(-10, 5):
		for dx in range(-4, 5):
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 5:
				var px := cx + dx
				var py := 12 + dy
				if py >= 0 and px >= 0 and px < 16:
					var brightness := 0.7 + (1.0 - dist / 5.0) * 0.3 + randf() * 0.1
					img.set_pixel(px, py, gem_color * brightness)

	# Crystal glow/shine
	img.set_pixel(cx - 1, 8, Color(1, 1, 1, 0.8))
	img.set_pixel(cx, 7, Color(1, 1, 1, 0.9))

	var tex := ImageTexture.create_from_image(img)
	texture_cache[cache_key] = tex
	return tex


# Clear cache if needed
func clear_cache() -> void:
	texture_cache.clear()
