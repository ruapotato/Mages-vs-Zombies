@tool
extends EditorScript

## Quick utility script to create a placeholder sprite for the player
## Run this in Godot Editor: File -> Run Script
## Creates a simple mage sprite texture at res://assets/player/mage_placeholder.png

func _run() -> void:
	var width = 64
	var height = 64

	# Create image
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Fill with transparent
	image.fill(Color(0, 0, 0, 0))

	# Draw a simple mage character
	# Body (purple robe)
	for y in range(32, 60):
		for x in range(20, 44):
			var distance_from_center = abs(x - 32)
			var width_at_y = 12 + (y - 32) * 0.3
			if distance_from_center < width_at_y:
				image.set_pixel(x, y, Color(0.5, 0.3, 0.8, 1.0))

	# Head (skin tone)
	for y in range(16, 32):
		for x in range(24, 40):
			var dx = x - 32
			var dy = y - 24
			if dx * dx + dy * dy < 64:
				image.set_pixel(x, y, Color(1.0, 0.85, 0.7, 1.0))

	# Hat (dark purple)
	for y in range(8, 20):
		for x in range(22, 42):
			var dx = x - 32
			var dy = y - 16
			if dx * dx + dy * dy < 100 and y < 18:
				image.set_pixel(x, y, Color(0.3, 0.1, 0.5, 1.0))

	# Hat tip
	for y in range(4, 12):
		for x in range(28, 36):
			if y < 10:
				image.set_pixel(x, y, Color(0.3, 0.1, 0.5, 1.0))

	# Eyes
	image.set_pixel(27, 24, Color(0, 0, 0, 1))
	image.set_pixel(36, 24, Color(0, 0, 0, 1))

	# Simple staff (brown)
	for y in range(20, 55):
		image.set_pixel(44, y, Color(0.4, 0.25, 0.1, 1.0))
		image.set_pixel(45, y, Color(0.4, 0.25, 0.1, 1.0))

	# Staff orb (cyan magic)
	for y in range(16, 22):
		for x in range(42, 48):
			var dx = x - 45
			var dy = y - 19
			if dx * dx + dy * dy < 9:
				image.set_pixel(x, y, Color(0.3, 0.8, 1.0, 1.0))

	# Add outline for better visibility
	var outlined = _add_outline(image)

	# Save texture
	var dir_path = "res://assets/player"
	if !DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var texture_path = dir_path + "/mage_placeholder.png"
	outlined.save_png(texture_path)

	print("Created placeholder mage sprite at: ", texture_path)
	print("Assign this to the Sprite3D texture in the player scene!")


func _add_outline(image: Image) -> Image:
	var width = image.get_width()
	var height = image.get_height()
	var outlined = Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Copy original
	outlined.blit_rect(image, Rect2i(0, 0, width, height), Vector2i(0, 0))

	# Add black outline
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var pixel = image.get_pixel(x, y)
			if pixel.a < 0.5:  # Transparent pixel
				# Check neighbors
				var has_opaque_neighbor = false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if image.get_pixel(x + dx, y + dy).a > 0.5:
							has_opaque_neighbor = true
							break
					if has_opaque_neighbor:
						break

				if has_opaque_neighbor:
					outlined.set_pixel(x, y, Color(0, 0, 0, 1))

	return outlined
