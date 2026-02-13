extends Control
## Main Menu - Host/Join multiplayer or play single player

@onready var player_name_edit: LineEdit = %PlayerNameEdit
@onready var ip_edit: LineEdit = %IPEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var single_player_button: Button = %SinglePlayerButton
@onready var quit_button: Button = %QuitButton
@onready var status_label: Label = %StatusLabel

const DEFAULT_PORT := 7777


## AUTO-TEST: Disabled
var _auto_start: bool = false

func _ready() -> void:
	# Connect buttons
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	single_player_button.pressed.connect(_on_single_player_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Connect network signals
	if NetworkManager:
		NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
		NetworkManager.connection_failed.connect(_on_connection_failed)

	# Load saved player name
	var saved_name := _load_player_name()
	if saved_name != "":
		player_name_edit.text = saved_name
	else:
		player_name_edit.text = "Mage_%d" % randi_range(100, 999)

	# Clear status
	status_label.text = ""

	# Show mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# AUTO-TEST: Automatically start single player game
	if _auto_start:
		print("[AUTO-TEST] Auto-starting single player game...")
		call_deferred("_on_single_player_pressed")


func _on_host_pressed() -> void:
	var player_name := player_name_edit.text.strip_edges()
	if player_name == "":
		player_name = "Host"

	_save_player_name(player_name)
	_set_buttons_enabled(false)
	status_label.text = "Starting server..."

	var error := NetworkManager.host_game(DEFAULT_PORT, player_name)
	if error != OK:
		status_label.text = "Failed to start server: %s" % error_string(error)
		_set_buttons_enabled(true)
		return

	# Server started, load game
	status_label.text = "Server started! Loading game..."
	await get_tree().create_timer(0.5).timeout
	_load_game()


func _on_join_pressed() -> void:
	var player_name := player_name_edit.text.strip_edges()
	if player_name == "":
		player_name = "Player"

	var ip := ip_edit.text.strip_edges()
	if ip == "":
		status_label.text = "Please enter a server IP address"
		return

	_save_player_name(player_name)
	_set_buttons_enabled(false)
	status_label.text = "Connecting to %s..." % ip

	var error := NetworkManager.join_game(ip, DEFAULT_PORT, player_name)
	if error != OK:
		status_label.text = "Failed to connect: %s" % error_string(error)
		_set_buttons_enabled(true)


func _on_single_player_pressed() -> void:
	var player_name := player_name_edit.text.strip_edges()
	if player_name == "":
		player_name = "Mage"

	_save_player_name(player_name)
	status_label.text = "Loading single player..."

	# Don't use networking for single player
	await get_tree().create_timer(0.3).timeout
	_load_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_connection_succeeded() -> void:
	status_label.text = "Connected! Loading game..."
	await get_tree().create_timer(0.5).timeout
	_load_game()


func _on_connection_failed() -> void:
	status_label.text = "Connection failed! Server may not be running."
	_set_buttons_enabled(true)


func _load_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _set_buttons_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	join_button.disabled = not enabled
	single_player_button.disabled = not enabled
	player_name_edit.editable = enabled
	ip_edit.editable = enabled


func _save_player_name(player_name: String) -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.save("user://settings.cfg")


func _load_player_name() -> String:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("player", "name", "")
	return ""
