extends Node3D

const QuartermasterDialogue := preload("res://quartermaster_dialogue.gd")
const CHIMNEY := Vector3(-22.2,1.80,842.5)
const TABLE := Vector3(-33.05,.68,840.65)
const HOME := [TABLE,Vector3(-22.2,.56,845),Vector3(-21.8,.45,845.25),Vector3(-22.5,.45,845.35),Vector3(-33,.80,841.5),Vector3(-33,.80,839.8),Vector3(-34.6,.82,841.95)]
const NAMES := ["Flight chart","Practice parcel","Practice parcel","Practice parcel","Tin mug","Tin mug","Couch cushion"]
const SEATS := [Vector3(-34.55,.10,839.2),Vector3(-34.55,.10,840.65),Vector3(-34.55,.10,842.1)]
const COUNTER := [Vector3(-29.76,1.48,834.65),Vector3(-26.66,1.48,834.65)]
const CLERK := Vector3(-28.4,.18,833.49)
const CLERK_FACE := CLERK + Vector3(0,1.73,.24)
const Cargo := preload("res://cargo.gd")
# The first two entries also have physical samples on the counter.
const STOCK := [
	{"id":"mitt", "name":"Throwing mitt", "cost":8, "upgrade":1, "detail":"Crew upgrade · 35% more throw speed", "reply":"issued_mitt"},
	{"id":"sling", "name":"Quick sling", "cost":10, "upgrade":2, "detail":"Crew upgrade · 35% less charge time", "reply":"issued_sling"},
	{"id":"present", "name":"Wrapped present", "cost":2, "upgrade":0, "detail":"Gift cargo · Carry, load or deliver", "reply":"issued_present"},
]
var world: Node3D
var props: Array[RigidBody3D] = []
var holders := PackedInt64Array()
var seats := {}
var charges := {}
var thrown_from := {}
var presenting := false
var map_out := false
var waypoint := Vector3.INF
var vouchers := 12
var upgrades := 0
var baskets := 0
var record := 0.0
var net_clock := 0.0
var subscribers: Array[int] = []
var last_sent: Array[Transform3D] = []
var carrier: Node3D
var carrier_phase := 0.0
var stamp: Node3D
var bell: AudioStreamPlayer3D
var placard: Label3D
var chart: Control
var sheet: TextureRect
var dialogue: QuartermasterDialogue
var graphics: Node3D
var base_throw: float
var base_charge: float

func build(w: Node3D, depot: Node3D) -> void:
	world = w
	base_throw = w.max_throw_speed
	base_charge = w.charge_seconds
	graphics = preload("res://mess_fittings.gd").new()
	add_child(graphics)
	graphics.build(self,depot)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,600)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	chart = preload("res://flight_chart.gd").new()
	chart.world = w
	chart.mess = self
	chart.size = viewport.size
	viewport.add_child(chart)
	var overlay := CanvasLayer.new()
	overlay.layer = 4
	add_child(overlay)
	dialogue = preload("res://quartermaster_dialogue.tscn").instantiate()
	overlay.add_child(dialogue)
	dialogue.setup(self,graphics.quartermaster,CLERK_FACE)
	sheet = TextureRect.new()
	overlay.add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.anchor_left = .07
	sheet.anchor_right = .93
	sheet.anchor_top = .08
	sheet.anchor_bottom = .91
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sheet.texture = viewport.get_texture()
	sheet.hide()
	for i in HOME.size():
		var body := RigidBody3D.new()
		body.name = "Prop%d" % i
		body.collision_layer = 32
		body.collision_mask = 1 | 4 | 16 | 32
		body.freeze = not multiplayer.is_server()
		body.continuous_cd = true
		add_child(body)
		body.position = HOME[i]
		var shape := BoxShape3D.new()
		shape.size = Vector3(.82,.032,.52) if i == 0 else (Vector3(.56,.19,.48) if i == 6 else (Vector3(.21,.23,.21) if i >= 4 else Vector3.ONE*.36))
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		graphics.dress_prop(body,i,viewport.get_texture(),shape.size)
		props.append(body)
		holders.append(0)

func held(id: int) -> int:
	return holders.find(id)

func in_room(p: Vector3) -> bool:
	return AABB(Vector3(-36,-1,832),Vector3(16,6,18)).has_point(p)

func target(id: int) -> String:
	var elf = world.players.get(id)
	if not elf: return ""
	var view: Transform3D = elf.head.global_transform
	var best := INF
	var found := ""
	var options := {}
	for i in props.size():
		if holders[i] == 0 or (i == 0 and map_out and holders[i] != id):
			options["prop%d" % i] = [props[i].position,.48]
	if in_room(view.origin):
		options["talk"] = [CLERK_FACE,.52]
		for i in SEATS.size():
			if not seats.has(id) and not i in seats.values():
				options["seat%d" % i] = [SEATS[i]+Vector3.UP*.71,.72]
		for i in COUNTER.size(): options["buy%d" % i] = [COUNTER[i],.64]
	for key: String in options:
		var point: Vector3 = options[key][0]
		var offset := point-view.origin
		var distance := offset.dot(-view.basis.z)
		# The clerk stands one arm's length behind the samples on the counter.
		if distance <= 0 or offset.length() > (3.8 if key == "talk" else 3.1): continue
		var miss := (offset+view.basis.z*distance).length()
		if miss > float(options[key][1]): continue
		var rank := miss / distance + distance * .007
		if rank >= best: continue
		var ray := PhysicsRayQueryParameters3D.create(view.origin,point,1|16)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = rank
		found = key
	return found

func hint(id: int) -> String:
	var elf = world.players[id]
	var item := held(id)
	if not in_room(elf.position) and item < 0: return ""
	var key := target(id)
	var line := "THE LAST STOP    /    Crew fund: %d vouchers" % vouchers if in_room(elf.position) else "NORTH STAR   /   Navigation"
	if dialogue.choosing(): return line
	if key == "talk" and (not dialogue.visible or dialogue.page == QuartermasterDialogue.Page.RECEIPT): line += "\n{interact}   Talk to the quartermaster"
	elif key.begins_with("seat") and not seats.has(id): line += "\n{interact}   Sit on the couch"
	elif key.begins_with("buy"):
		var idx := int(key.right(1))
		var good: Dictionary = STOCK[idx]
		line += "\n%s   •   %s" % [good.name,"Issued" if upgrades & good.upgrade else "{interact}   Buy for %d vouchers" % good.cost]
		line += "   /   " + good.detail
	elif key.begins_with("prop") and item < 0:
		line += "\n{interact}   Pick up " + NAMES[int(key.right(1))]
	if seats.has(id): line += "\n{jump}   Get up"
	if item == 0: line += "\n{crew_primary}   Read chart     {show_chart}   Offer / take back     {drop_cargo}   Set down"
	elif item > 0: line += "\nHold {crew_primary} to throw %s     {drop_cargo}   Set down" % NAMES[item]
	elif key == "" and not seats.has(id): line += "\nChart & lounge   •   Quartermaster   •   Chimney toss"
	return line

func handle_input(id: int, e: InputEvent) -> bool:
	if dialogue.choosing():
		dialogue.handle_choice_input(e)
		return true
	var item := held(id)
	if item == 0 and e.is_action_pressed("show_chart"):
		request("offer")
		return true
	if e.is_action_pressed("jump") and seats.has(id):
		request("stand")
		return true
	if e.is_action_pressed("interact"):
		var key := target(id)
		if not presenting and (key == "talk" or (key == "" and dialogue.visible and dialogue.page == QuartermasterDialogue.Page.CHAT)):
			dialogue.converse(world.players[id])
			return true
		if key.begins_with("seat") or key.begins_with("buy") or (item < 0 and key != ""):
			request(key)
			return true
		if item >= 0 and world.access.aimed(world.players[id].head.global_transform) == "": return true
	if item < 0: return false
	if item == 0 and presenting and e.is_action_pressed("mark_chart"):
		var fit := minf(sheet.size.x/960.0,sheet.size.y/600.0)
		var px := (sheet.get_local_mouse_position()-sheet.size*.5)/fit+Vector2(480,300)
		var point: Vector3 = chart.position_on_chart(px)
		if point.is_finite():
			if multiplayer.is_server(): pencil(id,point)
			else: pencil_remote.rpc_id(1,point)
		return true
	if e.is_action_pressed("drop_cargo"):
		request("drop")
		return true
	if e.is_action_pressed("crew_primary"):
		if item == 0: read_sheet(not presenting)
		else: request("charge")
		return true
	if e.is_action_released("crew_primary"):
		if item > 0: request("throw")
		return true
	return false

func read_sheet(open: bool) -> void:
	if open: dialogue.close()
	presenting = open
	world.hud_info.get_parent().visible = not open
	if not Game.menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

@rpc("any_peer","reliable")
func pencil_remote(point: Vector3) -> void:
	if multiplayer.is_server(): pencil(multiplayer.get_remote_sender_id(),point)

func pencil(id: int, point: Vector3) -> void:
	if held(id) != 0 or not point.is_finite() or absf(point.x)>4000 or absf(point.z)>4000: return
	var next := Vector3(point.x,0,point.z)
	if waypoint.is_finite() and waypoint.distance_to(next)<12: next = Vector3.INF
	set_mark.rpc(next)

@rpc("authority","call_local","reliable")
func set_mark(point: Vector3) -> void:
	waypoint = point
	chart.queue_redraw()
	chart.get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE

func request(action: String) -> void:
	if multiplayer.is_server(): perform(1,action)
	else: remote_request.rpc_id(1,action)

@rpc("any_peer","reliable")
func remote_request(action: String) -> void:
	if multiplayer.is_server(): perform(multiplayer.get_remote_sender_id(),action)

func within_counter_reach(elf: Node3D) -> bool:
	var origin: Vector3 = elf.head.global_position
	if not in_room(elf.position) or origin.distance_to(CLERK_FACE) > QuartermasterDialogue.HEARING_RANGE: return false
	var ray := PhysicsRayQueryParameters3D.create(origin,CLERK_FACE,1|16)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func perform(id: int, action: String) -> void:
	var elf = world.players.get(id)
	var ordering := action.begins_with("order/")
	if not elf or world.pilot_id == id or world.stations.station_for(id) != "":
		if elf and ordering: clerk_reply.rpc_id(id,"",true)
		return
	if ordering:
		if within_counter_reach(elf):
			for good: Dictionary in STOCK:
				if action == "order/" + str(good.id):
					sell(id,good,true)
					return
		clerk_reply.rpc_id(id,"",true)
		return
	var item := held(id)
	if action == "cancel":
		charges.erase(id)
		return
	if action == "stand" and seats.has(id):
		seats.erase(id)
		publish()
		return
	if action == "offer" and item == 0:
		map_out = not map_out
		publish()
		return
	if action == "charge" and item > 0:
		if not charges.has(id): charges[id] = Time.get_ticks_msec()
		return
	if (action == "drop" or action == "throw") and item >= 0:
		if action == "throw" and (item == 0 or not charges.has(id)): return
		var view: Transform3D = elf.head.global_transform
		var pos := view.origin - view.basis.z * .83
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(view.origin,pos-view.basis.z*.28,1|16|4)).is_empty():
			charges.erase(id)
			return
		var impulse := 0.0
		if action == "throw":
			var strength := clampf((Time.get_ticks_msec()-int(charges[id]))/(world.charge_seconds*1000.0),0,1)
			impulse = lerpf(3,world.max_throw_speed,strength)
			thrown_from[item] = elf.position
		charges.erase(id)
		if item == 0: map_out = false
		holders[item] = 0
		set_body(item,Transform3D(Basis.IDENTITY,pos),-view.basis.z*impulse)
		publish()
		return
	if action.is_empty() or action != target(id): return
	var idx := int(action.right(1))
	if action.begins_with("seat"):
		if idx in seats.values(): return
		seats[id] = idx
	elif action.begins_with("prop"):
		if item >= 0 or elf.held_kind != 0: return
		if holders[idx] != 0 and (idx != 0 or not map_out): return
		holders[idx] = id
		if idx == 0: map_out = false
		thrown_from.erase(idx)
		set_body(idx,props[idx].transform,Vector3.ZERO)
	elif action.begins_with("buy"):
		sell(id,STOCK[idx],false)
		return
	else:
		return
	publish()

func unavailable(id: int, good: Dictionary) -> String:
	if upgrades & good.upgrade: return "owned"
	if good.upgrade == 0 and (held(id) >= 0 or world.players[id].held_kind != Cargo.Kind.EMPTY): return "hands_full"
	if vouchers < good.cost: return "short"
	return ""

func sell(id: int, good: Dictionary, from_catalog: bool) -> void:
	var reason := unavailable(id,good)
	if reason != "":
		if reason == "short": world.access.notice.rpc_id(id,"The crew needs %d more vouchers." % (good.cost-vouchers))
		clerk_reply.rpc_id(id,reason,from_catalog)
		return
	vouchers -= good.cost
	if good.upgrade:
		upgrades |= good.upgrade
	else:
		world.set_held.rpc(id,Cargo.Kind.PRESENT)
	dispatch.rpc()
	publish()
	clerk_reply.rpc_id(id,good.reply,from_catalog)

@rpc("authority","call_local","reliable")
func clerk_reply(line_id: String, from_catalog: bool) -> void:
	if not presenting:
		dialogue.reply(world.players.get(multiplayer.get_unique_id()),line_id,from_catalog)

func set_body(i: int, pose: Transform3D, speed: Vector3) -> void:
	var body := props[i]
	body.freeze = holders[i] != 0 or not multiplayer.is_server()
	body.collision_layer = 32 if holders[i] == 0 else 0
	body.collision_mask = 53 if holders[i] == 0 else 0
	body.transform = pose
	body.linear_velocity = speed
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false

func poses() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for body in props: result.append(body.transform)
	return result

func publish() -> void:
	refresh()
	var transforms := poses()
	for id in subscribers:
		state.rpc_id(id,holders,seats,map_out,vouchers,upgrades,baskets,record,transforms)

func snapshot(id: int) -> void:
	if not subscribers.has(id): subscribers.append(id)
	set_mark.rpc_id(id,waypoint)
	state.rpc_id(id,holders,seats,map_out,vouchers,upgrades,baskets,record,poses())

@rpc("authority","reliable")
func state(owners: PackedInt64Array, occupied: Dictionary, offer: bool, money: int, gear: int, count: int, best: float, transforms: Array[Transform3D]) -> void:
	holders = owners
	seats = occupied
	map_out = offer
	vouchers = money
	upgrades = gear
	baskets = count
	record = best
	for i in props.size(): set_body(i,transforms[i],Vector3.ZERO)
	refresh()

func refresh() -> void:
	dialogue.refresh_stock()
	world.max_throw_speed = base_throw * (1.35 if upgrades & 1 else 1.0)
	world.charge_seconds = base_charge * (.65 if upgrades & 2 else 1.0)
	if presenting and holders[0] != multiplayer.get_unique_id(): read_sheet(false)
	placard.text = "CHIMNEY LEAGUE\n%02d   /   BEST %.1f m" % [baskets,record]

func earn(amount: int) -> void:
	vouchers += amount
	publish()

func depart(id: int) -> void:
	subscribers.erase(id)
	var i := held(id)
	if i >= 0:
		holders[i] = 0
		set_body(i,Transform3D(Basis.IDENTITY,HOME[i]),Vector3.ZERO)
		if i == 0: map_out = false
	seats.erase(id)
	charges.erase(id)
	publish()

func reset_room() -> void:
	seats.clear()
	charges.clear()
	thrown_from.clear()
	holders.fill(0)
	map_out = false
	if presenting: read_sheet(false)
	for i in props.size(): set_body(i,Transform3D(Basis.IDENTITY,HOME[i]),Vector3.ZERO)
	publish()

@rpc("authority","call_local","reliable")
func dispatch() -> void:
	bell.play()
	var tween := stamp.create_tween()
	tween.tween_property(stamp,"position:y",1.40,.10)
	tween.tween_property(stamp,"position:y",1.59,.22)

@rpc("authority","call_local","reliable")
func ring() -> void:
	bell.play()

@rpc("authority","call_remote","unreliable_ordered",2)
func motion(transforms: Array[Transform3D]) -> void:
	for i in props.size():
		if holders[i] == 0: props[i].transform = transforms[i]

func _physics_process(delta: float) -> void:
	if props.is_empty(): return
	for i in props.size():
		var body := props[i]
		var actor = world.players.get(holders[i])
		if actor:
			var view: Transform3D = actor.head.global_transform
			body.transform = view.translated_local(Vector3(.07,-.32,-.77))
			if i == 0:
				body.rotate_object_local(Vector3.RIGHT, .63 if not map_out else -1.55)
			continue
		if not multiplayer.is_server(): continue
		if i in [1,2,3] and thrown_from.has(i) and body.position.y < CHIMNEY.y and body.position.y > 1.05 and Vector2(body.position.x-CHIMNEY.x,body.position.z-CHIMNEY.z).length() < .53:
			var start: Vector3 = thrown_from[i]
			record = maxf(record,Vector2(start.x,start.z).distance_to(Vector2(CHIMNEY.x,CHIMNEY.z)))
			baskets += 1
			thrown_from.erase(i)
			set_body(i,Transform3D(Basis.IDENTITY,CHIMNEY+Vector3(0,-1.18,1.02)),Vector3(0,0,2.6))
			ring.rpc()
			publish()
		if body.position.y < -5 or Vector2(body.position.x,body.position.z).length() > 3000 or (i != 0 and body.position.distance_to(HOME[i]) > 35):
			set_body(i,Transform3D(Basis.IDENTITY,HOME[i]),Vector3.ZERO)
			thrown_from.erase(i)
	net_clock += delta
	if net_clock >= .10:
		net_clock = 0
		if multiplayer.is_server() and not subscribers.is_empty():
			var transforms := poses()
			var changed := last_sent.is_empty()
			for i in props.size():
				if changed: break
				if holders[i] == 0 and not transforms[i].is_equal_approx(last_sent[i]): changed = true
			if changed:
				for id in subscribers: motion.rpc_id(id,transforms)
				last_sent = transforms
		var reader = world.players.get(multiplayer.get_unique_id())
		if reader and reader.position.distance_squared_to(props[0].position) < 400:
			chart.queue_redraw()
			chart.get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE
	sheet.visible = presenting and not Game.menu_open and held(multiplayer.get_unique_id()) == 0
	props[0].visible = not sheet.visible
	carrier_phase = fmod(carrier_phase+delta*.05,1.0)
	carrier.position = Vector3(-31.7+4.9*(1-cos(TAU*carrier_phase)),3.65,835.9)
