extends Control
## Pause Menu - Shows when player presses Escape during gameplay

@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

var is_paused := false


func _ready() -> void:
	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Start hidden
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if is_paused:
			_unpause()
		else:
			_pause()


func _pause() -> void:
	is_paused = true
	get_tree().paused = true
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unpause() -> void:
	is_paused = false
	get_tree().paused = false
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	_unpause()


func _on_main_menu_pressed() -> void:
	# Disconnect from network if connected
	if NetworkManager and NetworkManager.is_connected_to_server():
		NetworkManager.disconnect_from_game()

	_unpause()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
