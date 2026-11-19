extends Node3D
## Reliable host-owned queues. Visual interpolation never changes inventory.
const Cargo = preload("res://cargo.gd")
const Sweep = preload("res://cargo_trajectory.gd")
const CAPACITY := 5
const CYCLE_TIME := .8
const CLOSE_TIME := .35
const RELEASE_DELAY := CYCLE_TIME-CLOSE_TIME
const MOUTH_HALF := Vector2(.65, .56)
var world: Node3D
var queues: Array = [[],[]]
var reserved := [0,0]
var jammed := -1
var jam_at_stops := -1
const JAM_BANK := deg_to_rad(22.0)
var remaining := [0.0,0.0]
var serial := 1
var models := {}
var moves := {}
var shutters: Array[Node3D] = []
var highlight: MeshInstance3D
var hopper_signs: Array[Label3D] = []
var selected_id := 0
var revision := 0
var sound: AudioStreamPlayer3D

var slots: Array[PackedVector3Array] = []
var loaders := PackedVector3Array()
var outlets := PackedVector3Array()
var closed_gates := PackedVector3Array()

func slot(rack: int, index: int) -> Vector3:
	return slots[rack][index]
func loader(rack: int) -> Vector3:
	return loaders[rack]
func outlet(rack: int) -> Vector3:
	return outlets[rack]

# Aft-facing hoppers share their lip coordinates with the swept catch test.
func mouth(rack: int) -> Vector3:
	return Vector3(signf(slot(rack,0).x) * 1.92, 2.06, 5.36)

func build_hopper(rack: int) -> void:
	var lip := mouth(rack)
	var ochre := Color("e1a84e")
	var enamel := Color("4c665b")
	var side_sign := signf(lip.x)
	for side in [-1, 1]:
		var rail := lip + Vector3(side * (MOUTH_HALF.x+.04), 0, -.28)
		if side == side_sign:
			hopper_panel(rail+Vector3.UP*.37, Vector3(.08,.46,.60), enamel)
		else:
			hopper_panel(rail, Vector3(.08, 1.20, .60), enamel)
		world._box(world.bomber, Vector3(.095, 1.21, .06), rail + Vector3(0,0,.30), ochre)
	for side in [-1, 1]:
		hopper_panel(lip + Vector3(0,side*(MOUTH_HALF.y+.04),0), Vector3(1.46,.08,.09), ochre)
	hopper_panel(lip + Vector3(0,-.60,-.29), Vector3(1.46,.09,.64), enamel)
	hopper_panel(lip + Vector3(0,-.02,-.62), Vector3(1.46,1.25,.08), enamel)
	# A sloped bed and roller ribs lead through the side opening onto the track.
	var incline := -side_sign*.38
	var bed: MeshInstance3D = world._box(world.bomber,Vector3(1.83,.09,.54),lip+Vector3(side_sign*.29,-.42,-.30),Color("596267"))
	bed.rotation.z = incline
	for i in 7:
		var offset := (i-3)*.25
		var rib: MeshInstance3D = world._box(world.bomber,Vector3(.065,.055,.49),bed.position+Vector3(offset,.072,0).rotated(Vector3.BACK,incline),ochre)
		rib.rotation.z = incline
	for side in [-1,1]:
		var foot := Vector3(lip.x+side*.48,0,lip.z-.45)
		var base_y := .78 if absf(foot.x) >= 2.34 else 0.0
		var height := lip.y-.64-base_y
		hopper_panel(foot+Vector3.UP*(base_y+height*.5),Vector3(.10,height,.10),enamel)
		world._box(world.bomber,Vector3(.26,.06,.26),foot+Vector3.UP*(base_y+.03),enamel)
	world._box(world.bomber,Vector3(1.45,.28,.08),lip+Vector3(0,.74,0),enamel)
	var stencil := Label3D.new()
	stencil.font_size = 42
	stencil.pixel_size = .0030
	stencil.outline_size = 2
	stencil.position = lip + Vector3(0,.74,.05)
	world.bomber.add_child(stencil)
	hopper_signs.append(stencil)
	update_sign(rack)

func update_sign(rack: int) -> void:
	var state_text := "TOSS"
	if jammed == rack: state_text = "JAM"
	elif remaining[rack] > 0: state_text = "BUSY"
	elif queues[rack].size() == CAPACITY: state_text = "FULL"
	hopper_signs[rack].text = "%s   %s   %d/5" % ["L" if rack == 0 else "R",state_text,queues[rack].size()]
	hopper_signs[rack].modulate = Color("ffe3a0") if state_text == "TOSS" else Color("ff9982")


func hopper_panel(center: Vector3, size: Vector3, color: Color) -> void:
	world._box(world.bomber, size, center, color)
	for hull in [world.bomber.get_node("Hull"), world.moving_hull]:
		if hull: world._hull_box(hull, size, center)

func catch_throw(id: int, start: Vector3, end: Vector3) -> bool:
	for rack in 2:
		var lip := mouth(rack)
		if start.z <= lip.z or end.z > lip.z: continue
		var crossing := start.lerp(end, (start.z-lip.z)/(start.z-end.z)) - lip
		if absf(crossing.x) > MOUTH_HALF.x or absf(crossing.y) > MOUTH_HALF.y: continue
		if remaining[rack] > 0 or jammed == rack or queues[rack].size() >= CAPACITY: continue
		append_stock(rack, world.loose[id].get_meta("kind"))
		world.remove_loose.rpc(id)
		release_sound.rpc(rack)
		publish()
		return true
	return false

func append_stock(rack: int, kind: int) -> void:
	queues[rack].append({"id":serial,"kind":kind})
	serial += 1

func build(w: Node3D) -> void:
	world = w
	for rack in 2:
		var positions := PackedVector3Array()
		for i in CAPACITY:
			positions.append(world.instruments.get_node("Rack%dSlot%d_rig" % [rack,i+1]).position)
		slots.append(positions)
		loaders.append(world.instruments.get_node("Rack%dLoadingPoint_rig" % rack).position)
		outlets.append(world.instruments.get_node("ChuteOutlet%d_rig" % rack).position)
		build_hopper(rack)
		var x := slot(rack,0).x
		for hull in [world.bomber.get_node("Hull"), world.moving_hull]:
			if hull:
				world._hull_box(hull,Vector3(1.16,.78,4.86),Vector3(x,.39,3.72))
				world._hull_box(hull,Vector3(1.16,1.56,.94),Vector3(x,.78,outlet(rack).z))
				world._hull_box(hull,Vector3(.96,.12,.93),Vector3(signf(x)*2.54,.88,1.53))
		for i in 5:
			var tag := Label3D.new()
			tag.text = "1 • NEXT" if i == 0 else str(i+1)
			tag.font_size = 32
			tag.pixel_size = .003
			tag.position = slot(rack,i)+Vector3(.60 if rack == 0 else -.60,-.17,0)
			tag.rotation.y = PI/2 if rack == 0 else -PI/2
			world.bomber.add_child(tag)
		var label := Label3D.new()
		label.text = ("LEFT" if rack == 0 else "RIGHT") + " • LOAD"
		label.rotation.y = PI/2 if rack == 0 else -PI/2
		label.position = loader(rack)+Vector3(.24 if rack == 0 else -.24,-.14,0)
		label.font_size = 30
		label.pixel_size = .0025
		label.double_sided = false
		world.bomber.add_child(label)
		var gate: Node3D = world.instruments.get_node("ChuteShutter%d_rig" % rack)
		shutters.append(gate)
		closed_gates.append(gate.position)
	sound = AudioStreamPlayer3D.new()
	sound.stream = preload("res://assets/audio/latch.wav")
	sound.bus = "Master"
	sound.volume_db = -12
	add_child(sound)
	highlight = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = .29
	mesh.height = .58
	highlight.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1,.85,.2,.23)
	highlight.material_override = material
	world.bomber.add_child(highlight)
	highlight.hide()

func sees(id: int, point: Vector3, radius: float = .45) -> bool:
	if not world.players.has(id): return false
	var view: Transform3D = world.players[id].head.global_transform
	var target: Vector3 = world.bomber.to_global(point)
	var offset := target-view.origin
	var along := offset.dot(-view.basis.z)
	if offset.length() > 2.8 or along <= 0 or (offset+view.basis.z*along).length() > radius: return false
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(view.origin,target,1|16)).is_empty()

func aimed(id: int) -> Dictionary:
	for rack in 2:
		if world.players.has(id) and world.players[id].held_kind != 0 and sees(id,loader(rack),.60): return {"rack":rack,"id":0}
		for i in queues[rack].size():
			if sees(id,slot(rack,i),.32): return {"rack":rack,"id":queues[rack][i].id,"index":i,"kind":queues[rack][i].kind}
		if sees(id,loader(rack),.60): return {"rack":rack,"id":0}
	return {}

func prompt(id: int) -> String:
	var a := aimed(id)
	if a.is_empty(): return ""
	if a.rack == jammed and a.id == 0: return "%s — Free stuck parcel" % Game.bindings.labels.interact
	if remaining[a.rack] > 0: return "Chute cycling — please wait"
	if a.id != 0:
		if a.rack == jammed and a.index == 0: return "Parcel stuck • Free it at the loading end"
		return "Empty your hands to retrieve" if world.players[id].held_kind != 0 else "%s — Retrieve %s • position %d" % [Game.bindings.labels.interact, "present" if a.kind == 1 else "bomb",a.index+1]
	if queues[a.rack].size() == 5: return "Rack full • 5/5"
	return ("%s — Load held cargo" % Game.bindings.labels.interact if world.players[id].held_kind else "Toss cargo into the marked hopper or carry it here")+" • %d/5" % queues[a.rack].size()

func interact(id: int) -> bool:
	var a := aimed(id)
	if a.is_empty(): return false
	var action := "retrieve" if a.id else "load"
	if jammed == a.rack and a.id == 0: action = "clear"
	request(action,a.rack,a.id)
	return true

func request(action: String, rack: int, item_id: int = 0) -> void:
	if multiplayer.is_server(): handle(1,action,rack,item_id)
	else: command.rpc_id(1,action,rack,item_id)

@rpc("any_peer","reliable")
func command(action: String, rack: int, item_id: int) -> void:
	if multiplayer.is_server(): handle(multiplayer.get_remote_sender_id(),action,rack,item_id)

func handle(id: int, action: String, rack: int, item_id: int = 0) -> bool:
	if rack < 0 or rack > 1 or not world.players.has(id) or remaining[rack] > 0: return false
	var elf = world.players[id]
	if action == "release":
		if world.stations.occupants.delivery != id or queues[rack].is_empty(): return false
		if jammed == rack: return false
		if jam_risk():
			jammed = rack
			jam_at_stops = world.contract.completed()
			release_sound.rpc(rack)
			publish()
			return false
		reserved[rack] = queues[rack][0].id
		remaining[rack] = CYCLE_TIME
	elif world.pilot_id == id or world.stations.station_for(id) != "" or world.mess.held(id) >= 0: return false
	elif action == "clear":
		if jammed != rack or not sees(id,loader(rack),.60): return false
		jammed = -1
		release_sound.rpc(rack)
	elif action == "load":
		if elf.held_kind == 0 or queues[rack].size() == CAPACITY or not sees(id,loader(rack),.60): return false
		append_stock(rack, elf.held_kind)
		world.set_held.rpc(id,0)
	elif action == "retrieve":
		if elf.held_kind != 0: return false
		var index := -1
		for i in queues[rack].size():
			if queues[rack][i].id == item_id: index = i
		if index < 0 or not sees(id,slot(rack,index),.32): return false
		if rack == jammed and index == 0: return false
		var kind: int = queues[rack][index].kind
		queues[rack].remove_at(index)
		world.set_held.rpc(id,kind)
	else: return false
	publish()
	return true

func release_state(rack: int, kind: int) -> Dictionary:
	return release_at(rack,kind,world.bomber.transform,world.previous_plane,world.physics_delta)

func prediction_state(rack: int, kind: int) -> Dictionary:
	if jammed == rack: return {}
	# A reserved head uses only its remaining opening time; closing is unavailable.
	if remaining[rack]>0 and reserved[rack]==0: return {}
	var delay: float = maxf(0,remaining[rack]-CLOSE_TIME) if reserved[rack] else RELEASE_DELAY
	var future: Dictionary = world.forecast_flight(delay)
	if future.is_empty(): return {}
	var excluded: Array[RID] = []
	# The current aircraft is not at its future release pose. Ignore that stale proxy.
	for body in world.bomber.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
	if world.moving_hull: excluded.append(world.moving_hull.get_rid())
	return release_at(rack,kind,future.pose,future.previous,future.delta,excluded)

func release_at(rack: int, kind: int, plane: Transform3D, previous: Transform3D, delta: float, excluded: Array[RID] = []) -> Dictionary:
	var end: Vector3 = plane*outlet(rack)
	var start: Vector3 = plane*(outlet(rack)+Vector3(0,.95,0))
	var pose := Transform3D(plane.basis,start)
	var space := get_world_3d().direct_space_state
	if not Sweep.sweep(space,Cargo.shape(kind),pose,end-start,1|4,excluded).is_empty(): return {}
	pose.origin = end
	if not Sweep.sweep(space,Cargo.shape(kind),pose,Vector3.ZERO,1|4|16,excluded).is_empty(): return {}
	var velocity: Vector3 = (end-previous*outlet(rack))/maxf(delta,.001)
	return {"pose":pose,"velocity":velocity+plane.basis*Vector3.DOWN,"excluded":excluded}

func commit(rack: int) -> bool:
	if queues[rack].is_empty() or queues[rack][0].id != reserved[rack]: return false
	var item: Dictionary = queues[rack][0]
	var state := release_state(rack,item.kind)
	if state.is_empty(): return false
	if world.loose.size() >= world.max_loose_items: return false
	var id: int = world.next_item
	world.show_loose.rpc(id,item.kind,state.pose)
	if not world.loose.has(id): return false
	world.next_item += 1
	world.loose[id].linear_velocity = state.velocity
	queues[rack].pop_front()
	reserved[rack] = 0
	return true

func jam_risk() -> bool:
	var stops: int = world.contract.completed()
	return jammed < 0 and world.contract.active and stops > 0 and stops < 6 and stops != jam_at_stops and absf(world.roll) >= JAM_BANK

func publish() -> void:
	revision += 1
	state.rpc(queues,reserved,remaining,revision,jammed,jam_at_stops)

@rpc("authority","call_local","reliable")
func state(q: Array, r: Array, times: Array, rev: int, blocked: int, last_jam: int) -> void:
	if rev < revision: return
	revision = rev
	jammed = blocked
	jam_at_stops = last_jam
	queues = q.duplicate(true)
	reserved = r.duplicate()
	remaining = times.duplicate()
	reconcile()

func snapshot(id: int) -> void:
	state.rpc_id(id,queues,reserved,remaining,revision,jammed,jam_at_stops)

func reconcile() -> void:
	var alive := {}
	for rack in 2:
		update_sign(rack)
		for i in queues[rack].size():
			var item: Dictionary = queues[rack][i]
			alive[item.id] = true
			if not models.has(item.id):
				var model: Node3D = (Cargo.PRESENT_MODEL if item.kind == 1 else Cargo.BOMB_MODEL).instantiate()
				world.bomber.add_child(model)
				model.position = loader(rack)
				models[item.id] = model
			if moves.has(item.id) and moves[item.id].is_valid(): moves[item.id].kill()
			var target := slot(rack,i)
			models[item.id].rotation.z = .36 if rack == jammed and i == 0 else 0.0
			if reserved[rack] == item.id: target += Vector3(0,-.6,outlet(rack).z-target.z)
			moves[item.id] = create_tween()
			moves[item.id].tween_property(models[item.id],"position",target,.28).set_trans(Tween.TRANS_SINE)
	for id in models.keys():
		if not alive.has(id):
			if moves.has(id) and moves[id].is_valid(): moves[id].kill()
			models[id].queue_free()
			models.erase(id)
			moves.erase(id)

func reset() -> void:
	jammed = -1
	jam_at_stops = -1
	queues = [[],[]]
	reserved = [0,0]
	remaining = [0.0,0.0]
	publish()

func _physics_process(delta: float) -> void:
	if not world: return
	for rack in 2:
		if remaining[rack] > 0:
			remaining[rack] = maxf(0,remaining[rack]-delta)
			if multiplayer.is_server():
				if reserved[rack] and remaining[rack] <= CLOSE_TIME+0.000001:
					var success := commit(rack)
					reserved[rack] = 0
					if not success:
						remaining[rack] = 0
						if world.stations.occupants.delivery: world.access.notice.rpc_id(world.stations.occupants.delivery,"Outlet blocked or cargo limit reached — item retained")
					else: release_sound.rpc(rack)
					publish()
				elif remaining[rack] == 0: publish()
		var open_fraction := clampf((CYCLE_TIME-remaining[rack])/RELEASE_DELAY,0,1) if reserved[rack] else clampf(remaining[rack]/CLOSE_TIME,0,1)
		shutters[rack].position = closed_gates[rack] + Vector3.FORWARD * 1.04 * smoothstep(0,1,open_fraction)
	var a := aimed(multiplayer.get_unique_id()) if not Game.menu_open else {}
	highlight.visible = not a.is_empty() and a.id != 0
	if highlight.visible: highlight.position = slot(a.rack,a.index)

@rpc("authority","call_local","reliable")
func release_sound(rack: int) -> void:
	sound.global_position = world.bomber.to_global(outlet(rack))
	sound.play()
