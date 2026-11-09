extends Node
## Lobby: host a game or join one by IP, then spawn the World.

const PORT := 7777
const MAX_ELVES := 8

var menu: CanvasLayer
var addr: LineEdit
var status: Label


func _ready() -> void:
	multiplayer.connected_to_server.connect(_start_world)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
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


func _on_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_ELVES)
	if err != OK:
		status.text = "Couldn't host (is the port already in use?)"
		return
	multiplayer.multiplayer_peer = peer
	_start_world()


func _on_join() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr.text.strip_edges(), PORT)
	if err != OK:
		status.text = "Couldn't start connecting."
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Connecting..."


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
