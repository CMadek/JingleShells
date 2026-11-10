extends Node
## Lobby: host a game or join one by IP, then spawn the World.

const PORT := 7777
const MAX_ELVES := 8

var menu: CanvasLayer
var addr: LineEdit
var status: Label


func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	_build_menu()



func _build_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "ELF BOMBER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Deliver presents. Mind the naughty list."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	addr = LineEdit.new()
	addr.text = "127.0.0.1"
	addr.placeholder_text = "Host IP address"
	box.add_child(addr)

	var host_btn := Button.new()
	host_btn.text = "Host a game"
	host_btn.pressed.connect(_on_host)
	box.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Join game"
	join_btn.pressed.connect(_on_join)
	box.add_child(join_btn)

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != 1:
		status.text = "Couldn't create lobby."
		return
	var peer := SteamMultiplayerPeer.new()
	peer.create_host(0)
	multiplayer.multiplayer_peer = peer
	status.text = "Lobby ID: %d" % lobby_id   # share this, or use Steam's invite overlay
	_start_world()
	
func _on_lobby_joined(lobby_id: int, _perm: int, _locked: bool, response: int) -> void:
	if multiplayer.is_server():
		return   # the host also gets this signal for its own lobby
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		status.text = "Couldn't join lobby."
		return
	var peer := SteamMultiplayerPeer.new()
	peer.create_client(Steam.getLobbyOwner(lobby_id), 0)
	multiplayer.multiplayer_peer = peer
	

func _on_host() -> void:
	status.text = "Creating lobby..."
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_ELVES)


func _on_join() -> void:
	status.text = "Joining..."
	Steam.joinLobby(addr.text.strip_edges().to_int())


func _start_world() -> void:
	menu.hide()
	var w: Node3D = preload("res://world.gd").new()
	w.name = "World"
	add_child(w)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	status.text = "Connection failed."


func _on_server_gone() -> void:
	_return_to_menu("The host left the game.")


func _return_to_menu(msg: String) -> void:
	var w := get_node_or_null("World")
	if w:
		remove_child(w)
		w.queue_free()
	multiplayer.multiplayer_peer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status.text = msg
	menu.show()


# The lobby exists before player nodes do. Early motion packets can safely
# arrive while a joining peer is still receiving the reliable player list.
@rpc("any_peer", "unreliable_ordered")
func sync_elf(pos: Vector3, yaw: float, pitch: float) -> void:
	var world := get_node_or_null("World")
	if not world:
		return
	var elf = world.players.get(multiplayer.get_remote_sender_id())
	if elf:
		elf.net_pos = pos
		elf.net_yaw = yaw
		elf.net_pitch = pitch
