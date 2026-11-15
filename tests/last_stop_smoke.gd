extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func aim(elf: Node3D, point: Vector3, from: Vector3) -> void:
	elf.position = from
	var direction: Vector3 = (point-elf.head.global_position).normalized()
	elf.rotation.y = atan2(-direction.x,-direction.z)
	elf.pitch = asin(direction.y)
	elf.head.rotation.x = elf.pitch

func press(elf: Node3D, action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	elf._unhandled_input(e)

func click(button: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = motion.position
		event.pressed = down
		get_viewport().push_input(event,true)

func _ready() -> void:
	var main = preload("res://main.gd").new()
	add_child(main)
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	var w = main.get_node("World")
	var elf = w.players[1]
	var room = w.mess
	for i in 5: await get_tree().physics_frame
	var trim = room.graphics.get_node("HolidayTrim")
	var star: Node3D = trim.stars[0]
	var start_angle := star.rotation
	for i in 4: await get_tree().process_frame
	check(not star.rotation.is_equal_approx(start_angle),"Suspended chart stars respond to the draft")
	var copy := preload("res://delivery_district.gd").new()
	copy.generate(w.district.route_seed)
	check(copy.sites == w.district.sites and copy.roads == w.district.roads,"Identical seed reproduces house and road positions")
	var other := preload("res://delivery_district.gd").new()
	other.generate(w.district.route_seed+1)
	check(other.sites != copy.sites,"Another seed produces a different district")
	copy.free()
	other.free()
	for i in w.recipients.houses.size():
		var house: Dictionary = w.recipients.houses[i]
		check(house.root.position == w.district.sites[i].base and house.nice == w.district.sites[i].nice,"Chart source matches spawned delivery target")
	var capture := "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		w.hud_info.get_parent().hide()
		aim(elf,Vector3(-28.1,1.50,836),Vector3(-29.4,.10,848.5))
		await screenshot("last-stop-room")
		aim(elf,Vector3(-34.25,1.08,840.33),Vector3(-31.86,.10,843.79))
		await screenshot("last-stop-lounge")
		aim(elf,Vector3(-29.08,1.84,833.84),Vector3(-27.09,.10,839.0))
		await screenshot("last-stop-counter")
		aim(elf,Vector3(-28.65,1.96,834.7),Vector3(-32.01,.12,843.68))
		await screenshot("last-stop-night-shift")
		if "--capture-motion" in OS.get_cmdline_user_args():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-data/room-motion"))
			for i in 56:
				await RenderingServer.frame_post_draw
				var frame := get_viewport().get_texture().get_image()
				frame.resize(800,450,Image.INTERPOLATE_LANCZOS)
				frame.save_png("res://.test-data/room-motion/frame-%03d.png" % i)
		w.hud_info.get_parent().show()
	aim(elf,room.props[0].position,Vector3(-32.1,.12,841))
	check(room.target(1) == "prop0","Chart is reachable on table")
	press(elf,"interact")
	check(room.held(1) == 0,"Interact picks up physical chart")
	press(elf,"crew_primary")
	for i in 8: await get_tree().physics_frame
	check(room.sheet.visible,"Reading unfolds the chart")
	var house: Vector3 = w.chimneys[0].top
	var px: Vector2 = room.chart.plot(house,w.district.bounds,room.chart.VILLAGE)
	var pin: Vector3 = room.chart.position_on_chart(px)
	check(Vector2(pin.x,pin.z).distance_to(Vector2(house.x,house.z)) < .01,"Ink on the village inset maps back to the chimney in world metres")
	room.pencil(1,pin)
	check(room.waypoint == pin,"Map holder can mark the route")
	if capture: await screenshot("last-stop-chart")
	press(elf,"show_chart")
	check(room.map_out,"Offering the chart replicates outward-facing paper")
	press(elf,"drop_cargo")
	check(room.held(1) == -1,"Chart can be set down")
	aim(elf,room.SEATS[0]+Vector3.UP*.71,Vector3(-33.85,.10,838.2))
	press(elf,"interact")
	check(room.seats.has(1),"Couch is usable")
	await get_tree().physics_frame
	await get_tree().physics_frame
	press(elf,"jump")
	check(not room.seats.has(1),"Player can stand up")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var counter_front := Vector3(-28.4,.1,836.6)
	aim(elf,room.CLERK_FACE,counter_front+Vector3.BACK*2.5)
	check(room.target(1) != "talk","Clerk is out of earshot across the room")
	aim(elf,room.CLERK_FACE,counter_front)
	check(room.target(1) == "talk" and room.hint(1).contains("Talk"),"Clerk's face offers conversation over the counter")
	press(elf,"interact")
	var chat = room.dialogue
	check(chat.choosing() and chat.line_id == "offer" and chat.get_node("%Browse").is_visible_in_tree(),"Clerk offers a voiced choice of chat or stock")
	if capture:
		await get_tree().create_timer(2.6).timeout
		await screenshot("quartermaster-choice")
	chat.get_node("%Chat").pressed.emit()
	check(chat.visible and chat.line_id == "welcome" and chat.voice.playing,"Interact starts the clerk's voiced greeting")
	var spoke := false
	for i in 24:
		await get_tree().physics_frame
		if chat.mouth.visible and chat.mouth.scale.y > .025:
			spoke = true
	check(spoke and chat.mouth.global_position.distance_to(room.CLERK_FACE)<.14,"Speaking mouth tracks the clerk's head and opens on syllables")
	check(chat.subtitle.visible_characters > 0 and chat.subtitle.visible_characters < chat.subtitle.text.length(),"Subtitles appear over time")
	press(elf,"interact")
	check(chat.subtitle.visible_characters == chat.subtitle.text.length() and not chat.voice.playing,"Interact reveals the line and cuts its audio")
	if capture: await screenshot("quartermaster-talk")
	press(elf,"interact")
	check(chat.line_id == "outfitter" and chat.voice.playing,"Second line has its own voice")
	if capture:
		for i in 160:
			await RenderingServer.frame_post_draw
			if chat.subtitle.visible_characters > 18 and chat.mouth.visible and chat.mouth.scale.y > .032:
				get_viewport().get_texture().get_image().save_png("res://.test-data/quartermaster-speaking.png")
				break
	press(elf,"interact")
	press(elf,"interact")
	check(chat.choosing() and room.vouchers == 12,"Chat returns to the counter without spending vouchers")
	chat.get_node("%Chat").pressed.emit()
	check(chat.line_id == "chart","A return visit has a different story")
	elf.position = counter_front+Vector3.BACK*4
	await get_tree().process_frame
	await get_tree().process_frame
	check(not chat.visible and not chat.voice.playing,"Walking away closes the conversation and stops speech")
	room.perform(1,"order/present")
	check(room.vouchers == 12 and elf.held_kind == w.Cargo.Kind.EMPTY,"Walking away also closes access to purchases")
	aim(elf,room.CLERK_FACE,counter_front)
	room.perform(1,"order/unknown")
	check(room.vouchers == 12 and not chat.visible,"Unknown stock cannot debit the crew or open a dialogue")
	press(elf,"interact")
	if capture:
		await get_tree().process_frame
		click(chat.get_node("%Browse"))
	else:
		chat.get_node("%Browse").pressed.emit()
	check(chat.get_node("%Catalog").is_visible_in_tree() and chat.buy_buttons.size() == room.STOCK.size(),"Catalog lists all goods at the clerk")
	if capture:
		await get_tree().create_timer(2.5).timeout
		await screenshot("quartermaster-stock")
	chat.buy_buttons[2].grab_focus()
	press(elf,"interact")
	check(room.vouchers == 10 and elf.held_kind == w.Cargo.Kind.PRESENT,"Direct item purchase hands real gift cargo to the customer")
	check(chat.line_id == "issued_present" and chat.buy_buttons[2].disabled and chat.buy_buttons[2].text == "Hands full","Catalog stays open with a spoken receipt and occupied hands")
	room.perform(1,"order/present")
	check(room.vouchers == 10 and chat.line_id == "hands_full","Another present cannot overwrite held cargo")
	if capture:
		click(chat.buy_buttons[0])
	else:
		chat.buy_buttons[0].pressed.emit()
	check(room.vouchers == 2 and w.max_throw_speed > room.base_throw and chat.line_id == "issued_mitt","Direct upgrade applies to the crew immediately")
	check(chat.buy_buttons[0].text == "Issued" and chat.buy_buttons[1].text == "8 short","Catalog refreshes ownership and affordability")
	chat.get_node("%Back").pressed.emit()
	chat.get_node("%Goodbye").pressed.emit()
	check(not chat.visible,"Goodbye dismisses the catalog and restores gameplay")
	press(elf,"interact")
	var leave := InputEventAction.new()
	leave.action = "flight_menu"
	leave.pressed = true
	main.ui._input(leave)
	check(not chat.visible and not Game.menu_open,"Menu shortcut leaves the counter before opening the flight menu")
	press(elf,"drop_cargo")
	check(elf.held_kind == w.Cargo.Kind.EMPTY,"Purchased present can be dropped as ordinary cargo")
	aim(elf,room.COUNTER[0],Vector3(-29.76,.1,836.1))
	press(elf,"interact")
	check(room.vouchers == 2,"Counter sample shares catalog ownership and cannot charge twice")
	check(chat.line_id == "owned","Clerk recognizes previously issued gear")
	aim(elf,room.COUNTER[1],Vector3(-26.66,.1,836.1))
	press(elf,"interact")
	check(chat.line_id == "short" and room.vouchers == 2,"Short-funds line preserves the balance")
	aim(elf,room.props[1].position,room.props[1].position+Vector3(0,-.1,1.1))
	press(elf,"interact")
	check(room.held(1) == 1,"Practice parcel can be picked up")
	room.perform(1,"charge")
	room.perform(1,"throw")
	check(room.held(1) == -1 and room.props[1].linear_velocity.length() > 2,"Practice parcel launches")
	room.set_body(1,Transform3D(Basis.IDENTITY,room.CHIMNEY+Vector3.UP*.40),Vector3.DOWN*2.0)
	for i in 35: await get_tree().physics_frame
	check(room.baskets == 1 and room.record > 0,"Physics crossing rings up a single basket")
	w.begin_level()
	check(room.baskets == 1 and room.upgrades == 1 and room.held(1) == -1,"Round reset restores objects and retains session purchases and record")
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	print("LAST STOP: ","PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)

func screenshot(label: String) -> void:
	for i in 4: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.test-data/%s.png" % label)
