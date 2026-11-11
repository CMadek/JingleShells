extends Control
## Lightweight decorative snowfall, independent of gameplay and mouse input.
var flakes: Array[Vector4] = []
var drift := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	for i in range(100):
		flakes.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 2.2), rng.randf_range(0.015, 0.055)))

func _process(delta: float) -> void:
	drift += delta
	for i in flakes.size():
		flakes[i].y = fposmod(flakes[i].y + delta * flakes[i].w, 1.0)
		flakes[i].x = fposmod(flakes[i].x + delta * 0.007, 1.0)
	queue_redraw()

func _draw() -> void:
	for flake in flakes:
		var position := Vector2(flake.x * size.x + sin(drift * 0.5 + flake.y * 20.0) * 9, flake.y * size.y)
		draw_circle(position, flake.z, Color(0.93, 0.95, 1.0, 0.18 + flake.z * 0.12))
