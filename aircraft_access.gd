extends Node
## Host-authorized exterior boarding door, with fixed player/cargo collision gates.
const POINTS := {"door": Vector3(-4.62,1.14,-4.8), "hatch": Vector3(0,0,3)}
const DOOR_HINGE := Vector3(-4.70,1.14,-5.6)
const SWITCHES := [Vector3(-4.57,1.45,-3.75),Vector3(-4.82,1.45,-3.75)]
var world: Node3D
var opened := {"door": true, "hatch": false}
var amount := {"door": 1.0, "hatch": 0.0}
var panels := {}
var gates := {}
var door_visual: Node3D
var cargo_shapes := {}
var hatch_leaves: Array[Node3D] = []

func build(w: Node3D) -> void:
	world = w
	door_visual = world.instruments.get_node("BoardingDoor_rig")
	for key in POINTS:
		var body := StaticBody3D.new()
		body.collision_layer = 16
		world.bomber.add_child(body)
		var gate: CollisionShape3D
		if key == "door":
			gate = CollisionShape3D.new()
			gate.shape = preload("res://assets/aircraft/boarding_door_collision.tres")
			body.add_child(gate)
		else:
			world._box(body,Vector3(2,.18,2),Vector3.ZERO,Color("8d7140"),false,body)
			gate = body.get_child(1)
		gates[key] = gate
		panels[key] = body
		if multiplayer.is_server():
			var shape: CollisionShape3D = gate.duplicate()
			world.moving_hull.add_child(shape)
			cargo_shapes[key] = shape
		if key == "hatch":
			# A stationary collision gate supports the deck while the two leaves
			# rotate down from their outer hinges, separating along the centre seam.
			body.get_child(0).visible = false
			for side in [-1, 1]:
				var hinge := Node3D.new()
				hinge.visible = false
				world.bomber.add_child(hinge)
				hinge.position = Vector3(side, -.09, 3)
				world._box(hinge,Vector3(.99,.18,2),Vector3(-side*.5,0,0),Color("715b39"))
				for z in [-.75,.75]:
					world._box(hinge,Vector3(.94,.03,.07),Vector3(-side*.5,.105,z),Color("b5a66b"))
				hatch_leaves.append(hinge)
	# Fixed handles stay reachable from inside and outside while the leaf swings.
	for i in SWITCHES.size():
		world._box(world.bomber,Vector3(.06,.32,.24),SWITCHES[i],Color("c2a157"))
		var sign := Label3D.new()
		sign.text = "BOARDING\nE • OPEN / CLOSE"
		sign.position = SWITCHES[i]+Vector3(.04 if i == 0 else -.04,.48,.10)
		sign.rotation.y = PI/2 if i == 0 else -PI/2
		sign.font_size = 28
		sign.pixel_size = .0025
		sign.double_sided = false
		world.bomber.add_child(sign)
	step(0)

func aimed(view: Transform3D) -> String:
	for key in POINTS:
		if key == "hatch": continue
		var targets: Array[Vector3] = [POINTS[key]]
		if key == "door":
			targets.append_array(SWITCHES)
			targets.append(world.bomber.to_local(door_visual.to_global(Vector3(.05,.06,1.4))))
		for point in targets:
			var target: Vector3 = world.bomber.to_global(point)
			var offset := target-view.origin
			var along := offset.dot(-view.basis.z)
			if offset.length() > 3.5 or along <= 0 or (offset+view.basis.z*along).length() > .65:
				continue
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(view.origin,target,1|16))
			if hit.is_empty() or hit.collider == panels[key] or hit.position.distance_to(target) < .25:
				return key
	return ""

func request(key: String) -> void:
	if multiplayer.is_server():
		handle(1,key)
	else:
		request_remote.rpc_id(1,key)

@rpc("any_peer", "reliable")
func request_remote(key: String) -> void:
	if multiplayer.is_server():
		handle(multiplayer.get_remote_sender_id(),key)

func handle(id: int, key: String) -> void:
	if key == "hatch": return
	if not opened.has(key) or not world.players.has(id) or world.pilot_id == id:
		return
	if aimed(world.players[id].head.global_transform) != key:
		return
	if key != "door" and absf(float(amount[key])-(1.0 if opened[key] else 0.0)) > .01:
		return
	if opened[key] and blocked(key):
		notice.rpc_id(id,"Step clear of the " + ("boarding doorway" if key == "door" else "bomb bay") + " to close it")
		return
	set_state.rpc(key,not opened[key],amount[key])

func blocked(key: String) -> bool:
	var area := AABB(Vector3(-5.15,-.4,-5.95),Vector3(1.10,3.1,2.3)) if key == "door" else AABB(Vector3(-1.25,-1.3,1.75),Vector3(2.5,3.3,2.5))
	for elf in world.players.values():
		if area.has_point(world.bomber.to_local(elf.global_position)):
			return true
	for item in world.loose.values():
		if area.has_point(world.bomber.to_local(item.global_position)):
			return true
	return false

@rpc("authority", "call_local", "reliable")
func notice(message: String) -> void:
	world.hud_msg.text = message
	world.msg_timer = 3.0

@rpc("authority", "call_local", "reliable")
func set_state(key: String, is_open: bool, fraction: float) -> void:
	opened[key] = is_open
	amount[key] = fraction

func snapshot(id: int) -> void:
	for key in opened:
		set_state.rpc_id(id,key,opened[key],amount[key])

func step(delta: float) -> void:
	for key in opened:
		if multiplayer.is_server() and not opened[key] and amount[key] > 0 and blocked(key):
			set_state.rpc(key,true,amount[key])
		amount[key] = move_toward(amount[key],1.0 if opened[key] else 0.0,delta/1.1)
		var closed := DOOR_HINGE if key == "door" else Vector3(0,-.09,3)
		var panel: StaticBody3D = panels[key]
		panel.position = closed
		# Keep the collision gate fixed so the animated leaf cannot shove the crew.
		var disabled: bool = amount[key] > .999 if opened[key] else amount[key] > .001
		gates[key].disabled = disabled
		if cargo_shapes.has(key):
			cargo_shapes[key].position = closed
			cargo_shapes[key].disabled = disabled
	var t: float = amount.door
	door_visual.rotation.y = -2.35*t*t*(3.0-2.0*t)
	for i in hatch_leaves.size():
		hatch_leaves[i].rotation.z = (-1 if i == 0 else 1) * float(amount.hatch) * PI / 2.0
