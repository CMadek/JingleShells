extends Node
## Host-authorized sliding panels, with matching player/cargo collision gates.
const POINTS := {"door": Vector3(-3,1,-4.8), "hatch": Vector3(0,0,3)}
var world: Node3D
var opened := {"door": true, "hatch": false}
var amount := {"door": 1.0, "hatch": 0.0}
var panels := {}
var cargo_shapes := {}
var hatch_leaves: Array[Node3D] = []

func build(w: Node3D) -> void:
	world = w
	for key in POINTS:
		var body := StaticBody3D.new()
		body.collision_layer = 16
		world.bomber.add_child(body)
		var size := Vector3(.16,2.28,1.6) if key == "door" else Vector3(2,.18,2)
		world._box(body,size,Vector3.ZERO,Color("712936") if key == "door" else Color("8d7140"),false,body)
		panels[key] = body
		if multiplayer.is_server():
			var shape: CollisionShape3D = body.get_child(1).duplicate()
			world.moving_hull.add_child(shape)
			cargo_shapes[key] = shape
		if key == "door":
			for z in [-5.63,-3.97]:
				world._box(world.bomber,Vector3(.12,2.4,.07),Vector3(-3.14,1.15,z),Color("c2a157"))
			world._box(world.bomber,Vector3(.12,.07,1.72),Vector3(-3.14,2.32,-4.8),Color("c2a157"))
		else:
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
	# Switches remain visible when the door is parked out of the opening.
	for x in [-2.84,-3.22]:
		world._box(world.bomber,Vector3(.06,.32,.24),Vector3(x,1.45,-3.75),Color("c2a157"))
	var sign := Label3D.new()
	sign.text = "BOARDING\nE • OPEN / CLOSE"
	sign.position = Vector3(-2.80,1.95,-3.55)
	sign.rotation.y = PI/2
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
			targets.append_array([Vector3(-2.84,1.45,-3.75),Vector3(-3.22,1.45,-3.75),panels.door.position])
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
	var area := AABB(Vector3(-3.55,-.4,-5.9),Vector3(1,3.1,2.2)) if key == "door" else AABB(Vector3(-1.25,-1.3,1.75),Vector3(2.5,3.3,2.5))
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
		var closed := Vector3(-3.08,1.14,-4.8) if key == "door" else Vector3(0,-.09,3)
		var pos := closed + Vector3(0,0,-1.7)*float(amount[key]) if key == "door" else closed
		var panel: StaticBody3D = panels[key]
		panel.position = pos
		# The collision gate stays stationary during the slide to avoid shoving cargo.
		panel.get_child(1).position = closed-pos
		var disabled: bool = amount[key] > .999 if opened[key] else amount[key] > .001
		panel.get_child(1).disabled = disabled
		if cargo_shapes.has(key):
			cargo_shapes[key].position = closed
			cargo_shapes[key].disabled = disabled
	for i in hatch_leaves.size():
		hatch_leaves[i].rotation.z = (-1 if i == 0 else 1) * float(amount.hatch) * PI / 2.0
