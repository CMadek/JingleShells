extends SceneTree
## Reproducible aircraft inspection and regression scene; replaces the removed dorsal demo.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.add_child(load("res://tests/mk2_smoke.tscn").instantiate())
