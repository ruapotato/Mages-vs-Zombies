extends SceneTree
## Command-line network test script
## Usage:
##   godot --headless --script test_network.gd host
##   godot --headless --script test_network.gd join 127.0.0.1

var is_host := false
var server_address := "127.0.0.1"
var port := 7777
var test_duration := 15.0  # seconds

func _init() -> void:
	# Parse command line args - Godot passes script args after --script scriptname
	var args := OS.get_cmdline_user_args()
	print("[TestNetwork] User args: %s" % str(args))

	# Also check regular args as fallback
	var all_args := OS.get_cmdline_args()
	print("[TestNetwork] All args: %s" % str(all_args))

	# Check both arg lists
	var check_args := args if args.size() > 0 else all_args

	for i in check_args.size():
		var arg := check_args[i]
		if arg == "host" or arg == "--host":
			is_host = true
		elif (arg == "join" or arg == "--join") and i + 1 < check_args.size():
			server_address = check_args[i + 1]
		elif (arg == "port" or arg == "--port") and i + 1 < check_args.size():
			port = int(check_args[i + 1])

	print("[TestNetwork] Mode: %s" % ("HOST" if is_host else "CLIENT"))
	if not is_host:
		print("[TestNetwork] Server: %s:%d" % [server_address, port])


func _initialize() -> void:
	print("\n========== MAGES VS ZOMBIES NETWORK TEST ==========")
	print("[TestNetwork] Starting test...")

	# Wait for autoloads
	await process_frame
	await process_frame

	var nm = root.get_node_or_null("/root/NetworkManager")
	if not nm:
		print("[TestNetwork] ERROR: NetworkManager autoload not found!")
		quit(1)
		return

	print("[TestNetwork] NetworkManager found, setting up...")

	# Connect signals
	nm.connection_succeeded.connect(_on_connected)
	nm.connection_failed.connect(_on_connection_failed)
	nm.player_connected.connect(_on_player_connected)
	nm.player_disconnected.connect(_on_player_disconnected)
	nm.lobby_updated.connect(_on_lobby_updated)

	if is_host:
		print("[TestNetwork] Starting server on port %d..." % port)
		var err = nm.host_game(port, "TestHost")
		if err != OK:
			print("[TestNetwork] ERROR: Failed to host: %s" % error_string(err))
			quit(1)
			return
		print("[TestNetwork] Server started! Waiting for connections...")
	else:
		print("[TestNetwork] Connecting to %s:%d..." % [server_address, port])
		var err = nm.join_game(server_address, port, "TestClient_%d" % randi_range(1, 999))
		if err != OK:
			print("[TestNetwork] ERROR: Failed to join: %s" % error_string(err))
			quit(1)
			return

	# Run test for specified duration
	var start_time := Time.get_ticks_msec()
	while true:
		var elapsed := (Time.get_ticks_msec() - start_time) / 1000.0
		if elapsed >= test_duration:
			break

		# Print status every 3 seconds
		if int(elapsed) % 3 == 0 and fmod(elapsed, 3.0) < 0.1:
			_print_status(nm)

		await process_frame

	print("\n[TestNetwork] Test complete!")
	_print_status(nm)
	nm.disconnect_from_game()
	quit(0)


func _print_status(nm) -> void:
	print("--- Network Status ---")
	print("  Is Server: %s" % nm.is_server())
	print("  Is Connected: %s" % nm.is_connected_to_server())
	print("  Local Peer ID: %d" % nm.get_local_peer_id())
	print("  Connected Players: %s" % str(nm.connected_players))
	print("----------------------")


func _on_connected() -> void:
	print("[TestNetwork] CONNECTED to server!")


func _on_connection_failed() -> void:
	print("[TestNetwork] CONNECTION FAILED!")


func _on_player_connected(peer_id: int, info: Dictionary) -> void:
	print("[TestNetwork] Player connected: peer=%d, name='%s'" % [peer_id, info.get("name", "?")])


func _on_player_disconnected(peer_id: int) -> void:
	print("[TestNetwork] Player disconnected: peer=%d" % peer_id)


func _on_lobby_updated(players: Dictionary) -> void:
	print("[TestNetwork] Lobby updated: %d players - %s" % [players.size(), str(players.keys())])
