extends Node
var world: Node3D
var next_id := 10000
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		get_tree().quit(1)
		assert(value, message)
func impact(kind: int, start: Vector3, finish: Vector3) -> int:
	var id := next_id
	next_id += 1
	world.show_loose(id,kind,Transform3D(Basis.IDENTITY,start))
	world.loose[id].freeze = true
	world.loose[id].position = finish
	world._step_cargo(1.0/60)
	check(not world.loose.has(id),"Swept impact should consume cargo")
	return id

func compare_trajectory(origin: Vector3, velocity: Vector3, bank: float) -> void:
	var pose := Transform3D(Basis(Vector3.FORWARD, bank), origin)
	var predicted: Dictionary = world.preview.predict({"pose": pose, "velocity": velocity})
	check(not predicted.is_empty(), "Ballistic estimate must find first impact")
	var id := next_id
	next_id += 1
	world.show_loose(id,1,pose)
	world.loose[id].linear_velocity = velocity
	var last := origin
	for frame in 360:
		await get_tree().physics_frame
		if not world.loose.has(id): break
		last = world.loose[id].position
		world._step_cargo(1.0/60)
	check(not world.loose.has(id), "Moving present must resolve")
	check(last.distance_to(predicted.point) < 1.5, "Moving/banked prediction stays within timestep tolerance")
func _ready() -> void:
	var main = load("res://main.gd").new()
	add_child(main)
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	world = main.get_node("World")
	world.set_physics_process(false)
	for i in 3: await get_tree().physics_frame
	var good := -1
	var bad := -1
	for i in world.recipients.houses.size():
		if world.recipients.houses[i].nice: good = i
		else: bad = i
	var base: Vector3 = world.recipients.houses[good].base
	var bad_base: Vector3 = world.recipients.houses[bad].base
	var id := impact(1,base+Vector3(0,20,0),base+Vector3(0,2,0))
	check(world.score == 10,"Roof gives +10")
	world._resolve_impact(id,world.recipients.houses[good].root,base)
	check(world.score == 10,"Duplicate impact must not score")
	impact(1,base+Vector3(2.2,20,1),base+Vector3(2.2,0,1))
	check(world.score == 25,"Chimney gives +15")
	impact(1,base+Vector3(-12,3,0),base+Vector3(1,3,0))
	check(world.score == 35,"Wall gives +10")
	impact(1,bad_base+Vector3(2.2,20,1),bad_base+Vector3(2.2,0,1))
	check(world.score == 30,"Naughty chimney remains -5")
	impact(1,base+Vector3(11,10,0),base+Vector3(11,-1,0))
	check(world.score == 30,"Ground miss gives no points")
	var predicted: Dictionary = world.preview.predict({"pose":Transform3D(Basis.IDENTITY,base+Vector3(0,15,0)),"velocity":Vector3.ZERO})
	check(not predicted.is_empty(),"Prediction hits roof")
	check(world.recipients.identify(predicted.collider).id == good,"Prediction identifies same recipient")
	# Let the actual rigid body fall and compare its first contact with the prediction.
	var physical_id := next_id
	next_id += 1
	world.show_loose(physical_id,1,Transform3D(Basis.IDENTITY,base+Vector3(0,15,0)))
	var last_point := Vector3.ZERO
	for frame in 180:
		await get_tree().physics_frame
		if not world.loose.has(physical_id): break
		last_point = world.loose[physical_id].position
		world._step_cargo(1.0/60)
	check(not world.loose.has(physical_id),"Physical fall resolves")
	check(last_point.distance_to(predicted.point) < 1.0,"Preview agrees with physical impact within cargo size/timestep tolerance")
	check(world.score == 40,"Physical roof delivery scores once")
	impact(2,base+Vector3(-12,3,0),base+Vector3(1,3,0))
	check(world.recipients.houses[good].destroyed,"Bomb destroys hit house")
	check(world.score == 40,"Bomb adds no points")
	check(not world.recipients.houses[bad].destroyed,"No area destruction")
	check(world.recipients.houses[good].root.collision_layer == 0,"Destroyed wall collision disabled")
	check(not world.recipients.houses[good].root.visible,"House and beacon hidden")
	var child_count := world.get_child_count()
	world.destroy_house(good,base,false)
	check(world.get_child_count() == child_count,"Repeated destruction is idempotent")
	for i in 2: await get_tree().physics_frame
	impact(1,base+Vector3(0,20,0),base+Vector3(0,-1,0))
	impact(2,base+Vector3(0,20,0),base+Vector3(0,-1,0))
	check(world.score == 40,"Destroyed recipients reject subsequent presents and bombs")
	world.destroy_house(bad,bad_base,false)
	check(world.recipients.houses[bad].destroyed,"Snapshot destruction applies silently")
	await compare_trajectory(base+Vector3(0,25,0), Vector3(15,0,0), .25)
	await compare_trajectory(base+Vector3(0,45,0), Vector3(30,5,2), -.45)
	await compare_trajectory(base+Vector3(0,15,0), Vector3(-8,0,8), 0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = base + Vector3(14,12,18)
	camera.look_at(base+Vector3(0,2,0))
	camera.current = true
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://delivery-destruction.png")
	print("PASS roof/wall/chimney/ground scoring, fast sweeps, duplicate protection, physical prediction, bomb destruction and snapshot replay")
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	get_tree().quit()
