extends Node
## Capture the actual menu, including its separate render world.
func _ready() -> void:
	var main = load("res://main.gd").new()
	add_child(main)
	main.menu_music.stop()
	var args := OS.get_cmdline_user_args()
	if "--seated" in args:
		main.ui.root.hide()
		var stage = main.ui.backdrop.stage
		stage.camera.position = Vector3(9.8, 1.55, -10.4)
		stage.camera.fov = 40
		stage.camera.look_at(Vector3(7.9,.95,-7.3))
	if "--4-3" in args:
		DisplayServer.window_set_size(Vector2i(1024,768))
	elif "--ultrawide" in args:
		DisplayServer.window_set_size(Vector2i(1920,820))
	elif "--1080" in args:
		DisplayServer.window_set_size(Vector2i(1920,1080))
	for i in 60:
		await get_tree().process_frame
	if "--movie" in args:
		for i in 24 * 30:
			await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		var suffix := "4-3" if "--4-3" in args else ("wide" if "--ultrawide" in args else ("1080" if "--1080" in args else "720"))
		if "--static-menu" in args: suffix += "-static"
		get_viewport().get_texture().get_image().save_png("res://.test-data/menu-"+("seated-" if "--seated" in args else "background-")+suffix+".png")
		if "--still" in args:
			main.ui.backdrop.viewport.get_texture().get_image().save_jpg("res://assets/menu/airfield_still.jpg", .92)
		if "--poses" in args:
			var stage = main.ui.backdrop.stage
			for time in [0.0, 1.0, 3.0, 5.0, 7.0, 9.0, 12.0, 18.0, 23.99]:
				for animation in stage.animations:
					animation.pause()
					animation.seek(time, true)
				for i in 3: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://.test-data/menu-pose-%02d.png"%int(time))
			for face in stage.faces:
				face.player.pause()
				face.player.seek(fposmod(2.3-face.offset, 24), true)
			for i in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.test-data/menu-blink.png")
	print("MENU PREVIEW COMPLETE")
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
