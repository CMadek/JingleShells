extends Node
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var main = load("res://main.gd").new()
	add_child(main)
	var music = main.menu_music
	check(music.playing and music.active, "Music starts in main menu")
	check(music.bus == "Master", "Music follows master volume")
	check(music.stream.stereo and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Stereo music loops")
	check(absf(music.stream.get_length() - 51.42857) < .01, "Complete track imported")
	check(music.stream.loop_end == roundi(music.stream.get_length() * music.stream.mix_rate), "Loop covers whole track")
	await get_tree().create_timer(1).timeout
	check(is_equal_approx(music.volume_db, music.MENU_GAIN_DB), "Menu fades in to intended mix")
	music.seek(12)
	for page in ["options", "help", "credits", "play", "connecting", "main"]:
		main.ui.show_page(page)
		check(main.menu_music == music and music.playing, "Navigation preserves single music player")
	check(music.get_playback_position() >= 11.9, "Navigation does not restart track")
	var saved: float = Game.values.volume
	Game.values.volume = 0.0
	Game.apply_settings()
	check(AudioServer.is_bus_mute(0), "Master zero mutes music")
	Game.values.volume = saved
	Game.apply_settings()
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	check(not music.active, "Starting game fades menu music out")
	await get_tree().create_timer(1).timeout
	check(not music.playing, "Music stops after departure fade")
	main.ui.show_page("pause")
	main.ui.show_page("options")
	check(not music.active and not music.playing, "In-game menus leave front-end music stopped")
	main._return_to_menu()
	check(music.active and music.playing, "Disconnect returns menu music")
	# An interrupted departure fade must never stop a newly resumed menu track.
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	await get_tree().create_timer(.15).timeout
	main._return_to_menu()
	await get_tree().create_timer(1).timeout
	check(music.playing and is_equal_approx(music.volume_db,music.MENU_GAIN_DB), "Rapid disconnect cancels stale fade-out callback")
	# Cross the actual audio loop boundary without a finished/restarted player.
	music.seek(music.stream.get_length() - .12)
	await get_tree().create_timer(.4).timeout
	check(music.playing and music.get_playback_position() < 1, "Playback crosses loop boundary continuously")
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(music), "Closing main frees the music player")
	await get_tree().create_timer(.2).timeout
	print("MENU MUSIC CHECKS: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)
