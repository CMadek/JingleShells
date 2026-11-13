extends Node3D
## Host-owned one-shot exit. Detached panel is cosmetic and never obstructs crew.
const POINT := Vector3(3.08,1.14,11)
var world: Node3D
var gone := false
var door: StaticBody3D
var cargo_gate: CollisionShape3D
var debris: Node3D
var motion: Tween
var sound: AudioStreamPlayer3D

func build(w: Node3D) -> void:
	world = w
	door = StaticBody3D.new()
	door.collision_layer = 16
	world.bomber.add_child(door)
	door.position = POINT
	world._box(door,Vector3(.16,2.28,1.6),Vector3.ZERO,Color("712936"),false,door)
	for z in [-.72,.72]:
		world._box(door,Vector3(.19,2.12,.05),Vector3(0,0,z),Color("c2a157"))
	world._box(door,Vector3(.22,.07,.45),Vector3(-.12,0,0),Color("c2a157"))
	for z in [10.16,11.84]:
		world._box(world.bomber,Vector3(.2,2.4,.07),Vector3(3.08,1.16,z),Color("c2a157"))
	world._box(world.bomber,Vector3(.2,.07,1.75),Vector3(3.08,2.35,11),Color("c2a157"))
	var sign := Label3D.new()
	sign.text = "EMERGENCY EXIT\nE — RELEASE"
	sign.font_size = 30
	sign.pixel_size = .004
	sign.position = Vector3(2.96,1.9,11)
	sign.rotation.y = -PI/2
	world.bomber.add_child(sign)
	if multiplayer.is_server():
		cargo_gate = door.get_child(1).duplicate()
		cargo_gate.position = POINT
		world.moving_hull.add_child(cargo_gate)
	sound = AudioStreamPlayer3D.new()
	sound.stream = preload("res://assets/audio/latch.wav")
	sound.bus = "Master"
	sound.volume_db = -4
	sound.pitch_scale = .55
	door.add_child(sound)

func aimed(view: Transform3D) -> bool:
	if gone: return false
	var target: Vector3 = world.bomber.to_global(POINT)
	var offset := target-view.origin
	var along := offset.dot(-view.basis.z)
	if offset.length() > 3 or along <= 0 or (offset+view.basis.z*along).length() > .7: return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(view.origin,target,1|16))
	return hit.is_empty() or hit.collider == door

func request() -> void:
	if multiplayer.is_server(): handle(1)
	else: request_remote.rpc_id(1)

@rpc("any_peer","reliable")
func request_remote() -> void:
	if multiplayer.is_server(): handle(multiplayer.get_remote_sender_id())

func handle(id: int) -> void:
	if gone or not world.players.has(id) or world.pilot_id == id: return
	if not aimed(world.players[id].head.global_transform): return
	set_gone.rpc(true,true)

@rpc("authority","call_local","reliable")
func set_gone(value: bool, animate: bool) -> void:
	var was_gone := gone
	gone = value
	door.visible = not gone
	door.get_child(1).set_deferred("disabled",gone)
	if cargo_gate: cargo_gate.set_deferred("disabled",gone)
	if motion and motion.is_valid(): motion.kill()
	if is_instance_valid(debris): debris.queue_free()
	if not gone or was_gone or not animate: return
	debris = Node3D.new()
	world.add_child(debris)
	debris.global_transform = door.global_transform
	for child in door.get_children():
		if child is MeshInstance3D: debris.add_child(child.duplicate())
	sound.play()
	var start := debris.global_position
	var outward: Vector3 = world.bomber.global_basis * Vector3(7,1,3)
	var aft: Vector3 = world.bomber.global_basis * Vector3(12,-4,18)
	motion = create_tween()
	motion.set_parallel(true)
	motion.tween_property(debris,"global_position",start+outward,.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(debris,"rotation",debris.rotation+Vector3(1.7,2.5,1),.6)
	motion.chain().tween_property(debris,"global_position",start+aft,1.3)
	motion.chain().tween_callback(debris.queue_free)

func _exit_tree() -> void:
	if is_instance_valid(debris): debris.queue_free()
