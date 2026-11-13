extends Control
## Delayed-release impact sight for the selected cargo launcher.
var stations: Node3D
func _process(_delta: float) -> void:
	visible = stations.active_local == "delivery" and not Game.menu_open
	queue_redraw()
func _draw() -> void:
	if not visible: return
	var camera: Camera3D = stations.console_camera
	var font := ThemeDB.fallback_font
	var hit: Dictionary = stations.predictions[stations.selected]
	var color := Color(.20,1.0,.42)
	var title := ("LEFT" if stations.selected == 0 else "RIGHT")+" LAUNCHER  /  SPACE TO RELEASE"
	var viewport_size := get_viewport_rect().size
	var title_at := Vector2(viewport_size.x*.5-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x*.5,42)
	draw_string_outline(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,22,5,Color.BLACK)
	draw_string(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,22,color)
	if hit.is_empty():
		var hint := "LOAD THIS RACK TO DISPLAY ITS LANDING TARGET" if stations.world.queues.queues[stations.selected].is_empty() else "RELEASE PATH BLOCKED"
		if stations.world.queues.remaining[stations.selected]>0 and stations.world.queues.reserved[stations.selected]==0: hint = "CHUTE RESETTING"
		draw_string(font,Vector2(28,80),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		return
	if camera.is_position_behind(hit.point): return
	var screen := camera.unproject_position(hit.point)
	var distance := camera.global_position.distance_to(hit.point)
	var radius := clampf(110*pow(40/maxf(distance,1),.4),55,155)
	draw_arc(screen,radius,0,TAU,128,Color(0,0,0,.65),5,true)
	draw_arc(screen,radius,0,TAU,128,color,2.5,true)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(screen+direction*(radius-8),screen+direction*(radius+8),color,2,true)
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		draw_line(screen-axis*13,screen+axis*13,Color.BLACK,5,true)
		draw_line(screen-axis*13,screen+axis*13,color,2.5,true)
