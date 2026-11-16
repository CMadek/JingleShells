extends "res://main.gd"
## Playable solo flight trial using the same helm, crew and host simulation as a lobby.
func _ready() -> void:
	super()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	operation = "host"
	_start_world()
	var world := get_node("World")
	world.players[1].position = world.bomber.to_global(world.HELM_POS)
	world.mess.holders[0] = world.mess.PINNED
	world.mess.set_body(0,world.mess.board.global_transform,Vector3.ZERO)
	world.mess.publish()
	world.request_helm()
	for rack in 2:
		world.queues.queues[rack] = [{"id":world.queues.serial, "kind":world.Cargo.Kind.PRESENT}]
		world.queues.serial += 1
	world.queues.publish()
