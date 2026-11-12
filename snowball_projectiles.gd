extends Node3D
## Modular cosmetic snowballs: the host sweeps a sphere and decides first contact.
var world: Node3D
var balls := {}
var serial := 1
func launch(pos: Vector3, velocity: Vector3) -> void:
	if not multiplayer.is_server() or balls.size() >= 32: return
	spawn.rpc(serial,pos,velocity)
	serial += 1
@rpc("authority","call_local","reliable")
func spawn(id: int, pos: Vector3, velocity: Vector3) -> void:
	if balls.has(id): return
	var model := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = .12
	mesh.height = .24
	mesh.radial_segments = 12
	mesh.rings = 6
	model.mesh = mesh
	model.material_override = world._mat(Color("e5f6ff"))
	world.add_child(model)
	model.global_position = pos
	balls[id] = {"model":model,"velocity":velocity,"age":0.0}
@rpc("authority","call_local","reliable")
func finish(id: int, point: Vector3, impact: bool) -> void:
	if not balls.has(id): return
	balls[id].model.queue_free()
	balls.erase(id)
	if impact:
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = .2
		mesh.height = .4
		puff.mesh = mesh
		puff.material_override = world._mat(Color.WHITE)
		world.add_child(puff)
		world.recipients.track_effect(puff)
		puff.global_position = point
		var tween := puff.create_tween()
		tween.tween_property(puff,"scale",Vector3.ONE*2,.1)
		tween.tween_property(puff,"scale",Vector3.ZERO,.2)
		tween.tween_callback(puff.queue_free)
@rpc("authority","call_local","reliable")
func clear_all() -> void:
	for ball in balls.values(): ball.model.queue_free()
	balls.clear()
func _physics_process(delta: float) -> void:
	for id in balls.keys():
		var ball: Dictionary = balls[id]
		var pos: Vector3 = ball.model.global_position
		var motion: Vector3 = ball.velocity*delta+Vector3.DOWN*4.9*delta*delta
		if multiplayer.is_server():
			var shape := SphereShape3D.new()
			shape.radius = .12
			var hit: Dictionary = world.Trajectory.sweep(get_world_3d().direct_space_state,shape,Transform3D(Basis.IDENTITY,pos),motion,1|16)
			if not hit.is_empty():
				finish.rpc(id,hit.point,true)
				continue
		ball.model.global_position += motion
		ball.velocity += Vector3.DOWN*9.8*delta
		ball.age += delta
		if ball.age > 5:
			if multiplayer.is_server(): finish.rpc(id,ball.model.global_position,false)
func _exit_tree() -> void:
	for ball in balls.values():
		if is_instance_valid(ball.model): ball.model.queue_free()
