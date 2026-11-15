extends Node

const MAX_ELVES := 8
const PROTOCOL := "jingle-bells-16"
var ui: CanvasLayer
var menu_music: AudioStreamPlayer
var lobby_id := 0
var target_lobby := 0
var operation := ""
var pending_create := false
var pending_join := 0
var deadline := 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	if Game.steam_ready:
		Game.steam.lobby_created.connect(_on_lobby_created)
		Game.steam.lobby_joined.connect(_on_lobby_joined)
		Game.steam.join_requested.connect(_on_join_requested)
	multiplayer.connected_to_server.connect(_start_world)
	multiplayer.connection_failed.connect(func(): _return_to_menu("Connection failed. Check Steam and try again."))
	multiplayer.server_disconnected.connect(func(): _return_to_menu("The host left the game."))
	menu_music = preload("res://menu_music.gd").new()
	add_child(menu_music)
	ui = preload("res://menu.gd").new()
	add_child(ui)

func _process(_delta: float) -> void:
	if operation != "" and Time.get_ticks_msec() > deadline:
		_return_to_menu("Connection timed out. You can try again once Steam finishes the pending request.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui):
		ui.confirm_exit()

func busy() -> bool:
	return operation != "" or pending_create or pending_join != 0

func host_game() -> void:
	if not Game.steam_ready or busy() or get_node_or_null("World"):
		return
	operation = "host"
	pending_create = true
	deadline = Time.get_ticks_msec() + 20000
	ui.show_page("connecting", "Creating Steam lobby…")
	Game.steam.createLobby(1, MAX_ELVES) # Friends only.

func join_game(id: int) -> void:
	if not Game.steam_ready or busy() or get_node_or_null("World"):
		return
	target_lobby = id
	pending_join = id
	operation = "join"
	deadline = Time.get_ticks_msec() + 20000
	ui.show_page("connecting", "Joining Steam lobby…")
	Game.steam.joinLobby(id)

func _on_join_requested(id: int, _friend: int) -> void:
	if get_node_or_null("World") or busy():
		ui.show_notice("Leave the current session or finish the pending request before accepting an invite.")
		return
	join_game(id)

func _on_lobby_created(result: int, id: int) -> void:
	pending_create = false
	if operation != "host":
		if result == 1:
			Game.steam.leaveLobby(id)
		return
	if result != 1:
		_return_to_menu("Couldn't create lobby (Steam response %d)." % result)
		return
	lobby_id = id
	Game.steam.setLobbyData(id, "protocol", PROTOCOL)
	Game.steam.setLobbyData(id, "name", "Jingle Shells")
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.create_host(0)
	if error != OK:
		_return_to_menu("Couldn't start host: %s." % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	_start_world()

func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	# Steam also sends this for our own newly created lobby.
	if id == lobby_id and lobby_id != 0:
		return
	if pending_create and operation == "host":
		return
	if id != pending_join:
		if response == 1:
			Game.steam.leaveLobby(id)
		return
	pending_join = 0
	if operation != "join" or target_lobby != id:
		if response == 1:
			Game.steam.leaveLobby(id)
		return
	if response != 1:
		var reason: String = {2: "Lobby unavailable.", 3: "You don't have permission to join.", 4: "Lobby is full.", 6: "You are banned from this lobby."}.get(response, "Couldn't join lobby (Steam response %d)." % response)
		_return_to_menu(reason)
		return
	lobby_id = id
	if Game.steam.getLobbyData(id, "protocol") != PROTOCOL:
		_return_to_menu("This lobby is running an incompatible game version.")
		return
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.create_client(Game.steam.getLobbyOwner(id), 0)
	if error != OK:
		_return_to_menu("Couldn't connect: %s." % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	ui.show_page("connecting", "Connecting to the host…")

func _start_world() -> void:
	if operation == "" or get_node_or_null("World"):
		return
	operation = ""
	ui.release_backdrop()
	var world: Node3D = preload("res://world.gd").new()
	world.name = "World"
	add_child(world)
	menu_music.set_active(false)
	ui.resume_game()

func _return_to_menu(message: String = "") -> void:
	operation = ""
	target_lobby = 0
	var world := get_node_or_null("World")
	if world and multiplayer.is_server() and lobby_id != 0 and Game.steam_ready:
		Game.steam.setLobbyJoinable(lobby_id, false)
	if world:
		remove_child(world)
		world.queue_free()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	if lobby_id != 0 and Game.steam_ready:
		Game.steam.leaveLobby(lobby_id)
	lobby_id = 0
	menu_music.set_active(true)
	ui.show_page("main", message)

func quit_game() -> void:
	_return_to_menu()
	get_tree().quit()

@rpc("any_peer", "unreliable_ordered")
func sync_elf(pos: Vector3, yaw: float, pitch: float, ducked: bool, grounded: bool) -> void:
	var world := get_node_or_null("World")
	if not world:
		return
	var elf = world.players.get(multiplayer.get_remote_sender_id())
	if elf:
		elf.net_pos = pos
		elf.net_yaw = yaw
		elf.net_pitch = pitch
		elf.crouched = ducked
		elf.net_grounded = grounded
