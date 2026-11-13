extends Node
## Reproducible in-engine art review, using the actual gameplay scene and assets.
const OUT := "res://art/aircraft/mk2/previews/cozy/"
var w: Node3D
func snap(title: String) -> void:
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+title+".png")
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main = load("res://main.gd").new()
	add_child(main)
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	w = main.get_node("World")
	w.set_physics_process(false)
	w.stations.set_physics_process(false)
	w.queues.set_physics_process(false)
	w.hud_info.get_parent().hide()
	w.stations.ui.hide()
	w.stations.reticle.hide()
	w.players[1].set_physics_process(false)
	w.players[1].global_position = w.Airfield.SPAWN
	w.players[1].presentation.set_process(false)
	w.players[1].presentation.model.hide()
	w.players[1].presentation.hands.hide()
	for node in w.find_children("*","Label3D",true,false):node.hide()
	w.bomber.position = Vector3(0,35,790)
	w.bomber.rotation = Vector3.ZERO
	w.grounded = false
	w.access.set_state("door",false,0)
	for rack in 2:
		w.queues.queues[rack] = [{"id":rack*10+1,"kind":1},{"id":rack*10+2,"kind":2},{"id":rack*10+3,"kind":1}]
	w.queues.reconcile()
	var camera := Camera3D.new()
	w.bomber.add_child(camera)
	camera.make_current()
	for view in [
		["exterior",Vector3(26,12,-30),Vector3(0,1,0),48.0],
		["cockpit",Vector3(0,3.15,-5.9),Vector3(0,2.85,-9),69.0],
		["cabin",Vector3(.1,1.9,6.4),Vector3(0,1.65,-4),76.0],
		["stairs",Vector3(-.75,1.8,-.3),Vector3(.65,1.95,-6.3),72.0],
		["stores",Vector3(.0,1.9,7.3),Vector3(0,1.0,10.0),80.0],
		["turret",Vector3(5.4,-3.4,-10.4),Vector3(1.75,-1.5,-7.3),54.0]
	]:
		camera.position=view[1];camera.fov=view[3]
		camera.look_at(w.bomber.to_global(view[2]))
		await snap(view[0])
	for id in [1,2,3]:
		if id>1:w.add_player(id)
		var elf = w.players[id]
		elf.set_physics_process(false)
		elf.presentation.set_process(false)
		elf.presentation.model.show()
		elf.global_position = w.bomber.to_global(Vector3((id-2)*1.12,.03,1.2))
		elf.rotation=Vector3.ZERO
		elf.presentation.animation.play("idle")
		elf.presentation.animation.advance(.1)
	camera.position=Vector3(0,1.3,-3.9)
	camera.fov=48
	camera.look_at(w.bomber.to_global(Vector3(0,1.1,1.2)))
	await snap("crew")
	# An actual remote socket and carry animation, plus distinct peer palette.
	w.set_held(2,1)
	w.players[2].presentation.animation.play("carry_idle")
	w.players[2].presentation.animation.advance(.2)
	camera.position=Vector3(1.4,1.25,-1.3)
	camera.fov=42
	camera.look_at(w.players[2].global_position+Vector3(0,1,0))
	await snap("crew-carry")
	# Capture the first-person mesh after the UI is stable, with HUD hidden.
	w.set_held(1,1)
	var elf=w.players[1]
	elf.global_position=w.bomber.to_global(Vector3(0,.03,0))
	elf.presentation.set_process(true)
	elf.cam.make_current()
	await get_tree().create_timer(.6).timeout
	await snap("hands")
	if "--visual-only" in OS.get_cmdline_user_args():
		print("POLISH VISUAL PREVIEWS: COMPLETE")
		main.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit()
		return
	# Measure steady rendering separately from synchronous PNG encoding.
	for id in range(4,9):
		w.add_player(id)
		var crew=w.players[id]
		crew.set_physics_process(false)
		crew.global_position=w.bomber.to_global(Vector3((id%3-1)*1.1,.03,2.5+(id/3)*1.2))
		crew.net_pos=crew.global_position
	camera.position=Vector3(0,1.8,-2)
	camera.look_at(w.bomber.to_global(Vector3(0,1.3,5)))
	camera.make_current()
	for i in 100:await get_tree().process_frame
	var elapsed:=0.0
	for i in 180:
		await get_tree().process_frame
		elapsed+=get_process_delta_time()
	print("POLISH PREVIEWS: COMPLETE")
	print("BODY MESHES: ",elf.presentation.model.find_children("*","MeshInstance3D",true,false).size())
	print("DRAW CALLS: ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("FRAME SECONDS: ",Performance.get_monitor(Performance.TIME_PROCESS))
	print("EIGHT CREW AVERAGE FPS: ",180.0/elapsed)
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
