extends CanvasLayer

## Debug UI overlay for player stats
## Add this as a child of the Player node to see real-time stats

@export var player: PlayerController

var label: Label


func _ready() -> void:
	# Create label
	label = Label.new()
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)

	# Auto-find player if not set
	if not player:
		player = get_parent() as PlayerController


func _process(_delta: float) -> void:
	if not player:
		return

	var text = ""
	text += "=== PLAYER DEBUG ===\n"
	text += "Position: %.1f, %.1f, %.1f\n" % [player.global_position.x, player.global_position.y, player.global_position.z]
	text += "Velocity: %.1f, %.1f, %.1f\n" % [player.velocity.x, player.velocity.y, player.velocity.z]
	text += "Grounded: %s\n" % player.is_on_floor()
	text += "\n"

	text += "Health: %.0f / %.0f (%.0f%%)\n" % [player.current_health, player.max_health, player.get_health_percent() * 100]
	text += "Mana: %.0f / %.0f (%.0f%%)\n" % [player.current_mana, player.max_mana, player.get_mana_percent() * 100]
	text += "\n"

	text += "Sprint: %s\n" % ("ON" if player.is_sprinting else "OFF")
	text += "Build Mode: %s\n" % ("ON" if player.build_mode else "OFF")
	text += "\n"

	text += "=== SPELLS ===\n"
	for i in range(5):
		var spell = player.get_spell_info(i)
		var status = "READY" if spell.available else ("CD: %.1fs" % spell.cooldown if spell.cooldown > 0 else "NO MANA")
		text += "%d. %s [%d mana] - %s\n" % [i + 1, spell.name.capitalize(), spell.mana_cost, status]

	text += "\n"
	if player.animation_controller:
		text += "Animation: %s\n" % player.animation_controller.get_current_state()

	label.text = text
