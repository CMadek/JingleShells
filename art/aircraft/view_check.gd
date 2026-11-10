extends SceneTree
func _initialize():
	call_deferred("run")
func snap(label):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/aircraft/"+label+".png")
func run():
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main._start_world()
	var w=main.get_node("World")
	var p=w.players[1]
	for i in range(12): await physics_frame
	p.position=Vector3(0,.03,.9)
	Input.action_press("move_forward")
	for i in range(20):await physics_frame
	Input.action_release("move_forward")
	assert(p.position.z<.2 and p.position.y>-.2,"Walk aisle in flight")
	var e=InputEventAction.new()
	e.action="interact"
	e.pressed=true
	p.position=Vector3(1.14,.02,-1.16)
	p._input(e)
	assert(p.at_ladder() and p.position.y>2)
	for i in range(5):await physics_frame
	p._input(e)
	assert(p.position.y<.1)
	p.position=Vector3(0,.02,2)
	p.rotation.y=PI
	p.pitch=-.77
	p.carry(1)
	w.cargo_action("drop")
	var cargo=w.loose.values()[0]
	for i in range(42): await physics_frame
	assert(w.bomber.to_local(cargo.global_position).y < 0)
	print("DROP local height ",w.bomber.to_local(cargo.global_position).y)
	p.position=Vector3(1.4,.01,4.65)
	p.rotation.y=.18
	p.pitch=0
	p.head.rotation.x=0
	await snap("cabin")
	p.position=w.HELM_POS
	w.request_helm()
	await snap("cockpit")
	w.toggle_pilot_view()
	for i in range(10): await physics_frame
	await snap("chase")
	var helm_pose: Transform3D = p.transform
	var head_pose: Transform3D = p.head.transform
	var old_offset: Vector3 = w.bomber.to_local(p.chase.global_position)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = true
	p._input(button)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(240, -36)
	p._input(motion)
	button.pressed = false
	p._input(button)
	for i in range(24): await physics_frame
	assert(old_offset.distance_to(w.bomber.to_local(p.chase.global_position)) > 8)
	assert(p.transform.is_equal_approx(helm_pose) and p.head.transform.is_equal_approx(head_pose))
	var panel = w.instruments
	var old_speed: float = panel.speed.rotation.z
	var old_height: float = panel.altitude.rotation.z
	for action in ["move_forward", "move_right", "jump"]: Input.action_press(action)
	for i in range(48): await physics_frame
	for action in ["move_forward", "move_right", "jump"]: Input.action_release(action)
	assert(absf(panel.speed.rotation.z-old_speed) > .001)
	assert(absf(panel.altitude.rotation.z-old_height) > .0001)
	assert(absf(panel.wheel.rotation.z) > .05 and absf(panel.climb.rotation.z) > .02)
	print("PASS independent camera orbit, wheel and live flight instruments")
	p.chase.global_position=w.bomber.to_global(Vector3(21,10,-19))
	p.chase.look_at(w.bomber.to_global(Vector3(0,1,0)))
	p.set_physics_process(false)
	await snap("north_star")
	w.request_helm()
	assert(not w.view_button.visible and p.cam.current)
	print("PASS moving deck, ladder, cargo release, pilot view and exit")
	quit()
