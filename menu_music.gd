extends AudioStreamPlayer
## A single persistent front-end track; pause menus do not restart it.
const MENU_GAIN_DB := -12.0
const FADE_SECONDS := .8
var active := false
var fade: Tween

func _ready() -> void:
	name = "MenuMusic"
	bus = "Master"
	var track := preload("res://assets/audio/snowbound_dispatch.wav").duplicate() as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = roundi(track.get_length() * track.mix_rate)
	stream = track
	volume_db = -60
	set_active(true)

func set_active(enabled: bool) -> void:
	if enabled == active:
		return
	active = enabled
	if fade and fade.is_valid():
		fade.kill()
	if enabled and not playing:
		volume_db = -60
		play()
	fade = create_tween()
	fade.tween_property(self, "volume_db", MENU_GAIN_DB if enabled else -60.0, FADE_SECONDS)
	if not enabled:
		fade.tween_callback(stop)

func _exit_tree() -> void:
	stop()
