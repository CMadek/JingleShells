extends Node3D
## Reliable host-owned queues. Visual interpolation never changes inventory.
const Cargo = preload("res://cargo.gd")
const Sweep = preload("res://cargo_trajectory.gd")
const CAPACITY := 5
const CYCLE_TIME := .8
const CLOSE_TIME := .35
const RELEASE_DELAY := CYCLE_TIME-CLOSE_TIME
var world: Node3D
var queues: Array = [[],[]]
var reserved := [0,0]
var remaining := [0.0,0.0]
var serial := 1
var models := {}
var moves := {}
var shutters: Array[Node3D] = []
var highlight: MeshInstance3D
var selected_id := 0
var revision := 0
var sound: AudioStreamPlayer3D

static func slot(rack: int, index: int) -> Vector3:
	return Vector3(-2.22 if rack == 0 else 2.22,1.02,1.4+index*.8)
static func loader(rack: int) -> Vector3:
	return Vector3(-1.6 if rack == 0 else 1.6,1.0,5.65)
static func outlet(rack: int) -> Vector3:
	return Vector3(-1.32 if rack == 0 else 1.32,-1.60,1.4)

func build(w: Node3D) -> void:
	world = w
	for rack in 2:
		var x := slot(rack,0).x
		world._hull_box(world.bomber.get_node("Hull"),Vector3(1.05,.85,4.5),Vector3(x,.425,3.1))
		# Cargo hull already exists; match its guarded rack volume.
		if world.moving_hull: world._hull_box(world.moving_hull,Vector3(1.05,.85,4.5),Vector3(x,.425,3.1))
		for i in 5:
			var tag := Label3D.new()
			tag.text = "1 • NEXT" if i == 0 else str(i+1)
			tag.font_size = 32
			tag.pixel_size = .003
			tag.position = slot(rack,i)+Vector3(.57 if rack == 0 else -.57,-.17,0)
			tag.rotation.y = PI/2 if rack == 0 else -PI/2
			world.bomber.add_child(tag)
		var label := Label3D.new()
		label.text = ("LEFT" if rack == 0 else "RIGHT") + " • LOAD"
		label.position = loader(rack)+Vector3(0,.20,.165)
		label.font_size = 30
		label.pixel_size = .0025
		label.double_sided = false
		world.bomber.add_child(label)
		var gate: Node3D = world.instruments.get_node("ChuteShutter%d_rig" % rack)
		shutters.append(gate)
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
	if remaining[a.rack] > 0: return "Chute cycling — please wait"
	if a.id != 0:
		return "Empty your hands to retrieve" if world.players[id].held_kind != 0 else "E — Retrieve %s • position %d" % ["present" if a.kind == 1 else "bomb",a.index+1]
	if queues[a.rack].size() == 5: return "Rack full • 5/5"
	return ("E — Load held cargo" if world.players[id].held_kind else "Carry cargo here to load")+" • %d/5" % queues[a.rack].size()

func interact(id: int) -> bool:
	var a := aimed(id)
	if a.is_empty(): return false
	request("retrieve" if a.id else "load",a.rack,a.id)
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
		reserved[rack] = queues[rack][0].id
		remaining[rack] = CYCLE_TIME
	elif world.pilot_id == id or world.stations.station_for(id) != "": return false
	elif action == "load":
		if elf.held_kind == 0 or queues[rack].size() == CAPACITY or not sees(id,loader(rack),.60): return false
		queues[rack].append({"id":serial,"kind":elf.held_kind})
		serial += 1
		world.set_held.rpc(id,0)
	elif action == "retrieve":
		if elf.held_kind != 0: return false
		var index := -1
		for i in queues[rack].size():
			if queues[rack][i].id == item_id: index = i
		if index < 0 or not sees(id,slot(rack,index),.32): return false
		var kind: int = queues[rack][index].kind
		queues[rack].remove_at(index)
		world.set_held.rpc(id,kind)
	else: return false
	publish()
	return true

func release_state(rack: int, kind: int) -> Dictionary:
	return release_at(rack,kind,world.bomber.transform,world.previous_plane,world.physics_delta)

func prediction_state(rack: int, kind: int) -> Dictionary:
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

func publish() -> void:
	revision += 1
	state.rpc(queues,reserved,remaining,revision)

@rpc("authority","call_local","reliable")
func state(q: Array, r: Array, times: Array, rev: int) -> void:
	if rev < revision: return
	revision = rev
	queues = q.duplicate(true)
	reserved = r.duplicate()
	remaining = times.duplicate()
	reconcile()

func snapshot(id: int) -> void:
	state.rpc_id(id,queues,reserved,remaining,revision)

func reconcile() -> void:
	var alive := {}
	for rack in 2:
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
			if reserved[rack] == item.id: target += Vector3(0,-.6,-.2)
			moves[item.id] = create_tween()
			moves[item.id].tween_property(models[item.id],"position",target,.28).set_trans(Tween.TRANS_SINE)
	for id in models.keys():
		if not alive.has(id):
			if moves.has(id) and moves[id].is_valid(): moves[id].kill()
			models[id].queue_free()
			models.erase(id)
			moves.erase(id)

func reset() -> void:
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
		shutters[rack].position.x = lerpf(shutters[rack].position.x,(-1.32 if rack == 0 else 1.32)+(.65 if remaining[rack]>0 else 0),minf(1,delta*10))
	var a := aimed(multiplayer.get_unique_id()) if not Game.menu_open else {}
	highlight.visible = not a.is_empty() and a.id != 0
	if highlight.visible: highlight.position = slot(a.rack,a.index)

@rpc("authority","call_local","reliable")
func release_sound(rack: int) -> void:
	sound.global_position = world.bomber.to_global(outlet(rack))
	sound.play()
