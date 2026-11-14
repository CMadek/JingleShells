extends Node
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	var saved := Game.values.duplicate()
	Game.values.menu_motion = true
	var main = load("res://main.gd").new()
	add_child(main)
	for i in 8: await get_tree().process_frame
	var ui = main.ui
	var background = ui.backdrop
	check(background.viewport.own_world_3d, "Menu must have an isolated World3D")
	check(background.viewport.gui_disable_input, "Background must not receive menu input")
	check(main.get_node_or_null("World") == null, "Menu must not start gameplay")
	check(background.stage.actors.size() == 3, "Three crew members are staged")
	for i in background.stage.actors.size():
		var props := {"Candy cane":0, "Cocoa":0}
		for mesh in background.stage.actors[i].find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				check(not material.resource_name.begins_with("Cigarette"), "Cigarettes must be removed from the exported crew")
				if mesh.visible:
					for prefix in props:
						if material.resource_name.begins_with(prefix): props[prefix] += 1
		check((props["Cocoa"] > 0) == (i == 0), "Only the right elf carries the cocoa mug")
		check((props["Candy cane"] > 0) == (i == 1), "Only the seated elf has a candy cane")
	var steam = background.find_children("CocoaSteam", "CPUParticles3D", true, false)
	check(steam.size() == 1, "Only the mug emits steam")
	if steam.size() == 1:
		check(steam[0].get_parent().bone_name == "MugSteam", "Steam must follow the mug instead of the mouth")
	check(background.stage.faces.size() == 3, "Each crew member has a distinct expression")
	for face in background.stage.faces:
		check(not face.targets.is_empty(), "Corrective blink shapes must survive Blender export: " + face.expression)
		for target in face.targets:
			var expression_index: int = target.mesh.find_blend_shape_by_name(face.expression)
			check(expression_index >= 0 and is_equal_approx(target.mesh.get_blend_shape_value(expression_index),1.0), "Chosen facial expression stays applied while animating")
			for index in target.mesh.mesh.get_blend_shape_count():
				var shape: String = target.mesh.mesh.get_blend_shape_name(index)
				if shape not in [face.expression, face.expression+"Blink"]:
					check(is_zero_approx(target.mesh.get_blend_shape_value(index)), "Inactive face shapes must stay neutral")
	check(background.stage.find_children("*", "Label3D", true, false).is_empty(), "Menu crates have no lettering")
	check(background.find_children("*", "AudioStreamPlayer", true, false).is_empty(), "Background must not add audio players")
	check(background.find_children("*", "PhysicsBody3D", true, false).is_empty(), "Background must not simulate physics")
	var total_particles := 0
	for particles in background.find_children("*", "CPUParticles3D", true, false):
		total_particles += particles.amount
	check(total_particles <= 500, "Particle budget must stay bounded")
	# The exported acting has matching poses and no abrupt velocity change at wrap.
	for animation_player in background.stage.animations:
		var skeleton: Skeleton3D = animation_player.get_parent().find_children("*", "Skeleton3D", true, false)[0]
		var clip: String = animation_player.current_animation
		var length: float = animation_player.get_animation(clip).length
		check(absf(length - 24.0) < .05, "Menu action must span 24 seconds")
		animation_player.pause()
		animation_player.seek(.001, true)
		var start: Array[Transform3D] = []
		for bone in skeleton.get_bone_count(): start.append(skeleton.get_bone_pose(bone))
		animation_player.seek(length-.001, true)
		for bone in skeleton.get_bone_count():
			var end := skeleton.get_bone_pose(bone)
			check(start[bone].origin.distance_to(end.origin) < .002, "No position jump in " + clip + "/" + skeleton.get_bone_name(bone))
			check(start[bone].basis.get_rotation_quaternion().angle_to(end.basis.get_rotation_quaternion()) < .01, "No rotation jump in " + clip + "/" + skeleton.get_bone_name(bone))
		animation_player.seek(length-.0333, true)
		var before: Array[Transform3D] = []
		for bone in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(bone))
		animation_player.seek(.0333, true)
		for bone in skeleton.get_bone_count():
			var after := skeleton.get_bone_pose(bone)
			var inverse_rotation := start[bone].basis.get_rotation_quaternion().inverse()
			var incoming := (inverse_rotation * before[bone].basis.get_rotation_quaternion()).get_euler()
			var outgoing := (inverse_rotation * after.basis.get_rotation_quaternion()).get_euler()
			check((incoming+outgoing).length() < .004, "Smooth angular motion across " + clip + "/" + skeleton.get_bone_name(bone))
		animation_player.play(clip)
	# Demand visible acting, so the menu cannot regress to barely moving idles.
	for spec in [[1,"ShinL",1.0,3.0,.7], [0,"Mug",0.0,3.0,.20]]:
		var animation_player: AnimationPlayer = background.stage.animations[spec[0]]
		var skeleton: Skeleton3D = animation_player.get_parent().find_children("*", "Skeleton3D", true, false)[0]
		var bone := skeleton.find_bone(spec[1])
		animation_player.seek(spec[2],true)
		var first := skeleton.get_bone_pose_rotation(bone)
		animation_player.seek(spec[3],true)
		check(first.angle_to(skeleton.get_bone_pose_rotation(bone)) > spec[4], "Visible movement survives export: " + spec[1])
	# Measure what the viewer sees: the watch rises towards the face. Its height
	# depends on both the shoulder and the elbow, not the local elbow angle alone.
	var watch_player: AnimationPlayer = background.stage.animations[2]
	var watch_rig: Skeleton3D = watch_player.get_parent().find_children("*", "Skeleton3D", true, false)[0]
	var wrist := watch_rig.find_bone("ForearmL")
	var bezel := watch_rig.get_bone_global_rest(wrist).affine_inverse() * Vector3(-.44,.805,.14)
	watch_player.seek(1.0,true)
	var lowered := watch_rig.get_bone_global_pose(wrist) * bezel
	watch_player.seek(5.0,true)
	var raised := watch_rig.get_bone_global_pose(wrist) * bezel
	check(raised.y - lowered.y > .18 and raised.distance_to(lowered) > .30, "Watch rises visibly towards the face")
	for face in background.stage.faces:
		face.player.pause()
		face.player.seek(fposmod(2.3-face.offset,24),true)
	background.stage._process(0)
	for face in background.stage.faces:
		for target in face.targets:
			check(target.mesh.get_blend_shape_value(target.index) > .99, "Eyes close at the authored blink beat")
	# Page changes must keep the same scene, phases and music player.
	for page in ["options", "help", "credits", "play", "join", "connecting", "main"]:
		ui.show_page(page)
		await get_tree().process_frame
		check(ui.backdrop == background, "Navigation must not recreate the animated backdrop")
	# Real viewport input must reach Controls through the decorative layers.
	var settings: Button
	for child in ui.box.get_children():
		if child is Button and child.text == "Settings": settings = child
	await get_tree().process_frame
	var previous_focus := get_viewport().gui_get_focus_owner()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab, true)
	check(get_viewport().gui_get_focus_owner() != previous_focus, "Keyboard can move focus through menu Controls")
	check(is_instance_valid(settings), "Main menu exposes Settings")
	if settings:
		var motion := InputEventMouseMotion.new()
		motion.position = settings.get_global_rect().get_center()
		get_viewport().push_input(motion, true)
		for pressed in [true,false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = motion.position
			get_viewport().push_input(click, true)
		check(ui.page == "options", "Mouse can open Settings through the backdrop")
		check(settings.get_theme_color("font_color") == Color("a6ca94"), "Menu uses evergreen text")
		check(settings.get_theme_color("font_hover_color") == Color("f18d81"), "Hover uses Christmas red")
		check(settings.get_theme_color("font_focus_color") == Color("f18d81"), "Keyboard focus also uses Christmas red")
	# Disable animation through the real settings Apply flow; no live 3D remains.
	ui.draft.menu_motion = false
	ui.apply_options()
	await get_tree().process_frame
	check(not is_instance_valid(background), "Disabling animation frees the stage")
	check(ui.backdrop.viewport == null, "Still background has no active render viewport")
	check(ResourceLoader.exists(ui.backdrop.STILL), "Still fallback is shipped")
	ui.show_page("options")
	ui.draft.menu_motion = true
	ui.apply_options()
	await get_tree().process_frame
	# Repeat departures/disconnects to catch camera leaks and duplicate scenes.
	for cycle in 2:
		background = ui.backdrop
		main.operation = "host"
		main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		main._start_world()
		await get_tree().process_frame
		check(not is_instance_valid(background) and ui.backdrop == null, "Gameplay frees the menu stage")
		check(get_viewport().get_camera_3d() != null, "Gameplay owns its camera")
		ui.show_page("pause")
		check(ui.backdrop == null, "Pause must not create a background")
		main._return_to_menu()
		await get_tree().process_frame
		check(ui.find_children("MenuBackdrop", "Control", false, false).size() == 1, "Return creates exactly one backdrop")
		check(ui.backdrop.viewport.world_3d != get_viewport().world_3d, "Return preserves world isolation")
	Game.values = saved
	Game.apply_settings()
	Game.save_settings()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("MENU BACKGROUND CHECKS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(failures)
