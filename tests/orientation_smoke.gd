extends Node
## Exercises actual crew carrying, remote interpolation and station transforms.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func upright(elf: Node3D) -> bool:
	return elf.global_basis.y.dot(Vector3.UP) > .99999 and elf.presentation.model.global_basis.y.dot(Vector3.UP) > .99999

func _ready() -> void:
	var main = load("res://main.gd").new()
	add_child(main)
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	var w = main.get_node("World")
	w.add_player(2)
	w.set_physics_process(false)
	w.stations.set_physics_process(false)
	for elf in w.players.values(): elf.set_physics_process(false)
	await get_tree().physics_frame
	var local = w.players[1]
	var remote = w.players[2]
	w.bomber.position = Vector3(0,80,0)
	w.bomber.rotation = Vector3.ZERO
	local.global_position = w.bomber.to_global(Vector3(-.6,.05,1))
	remote.global_position = w.bomber.to_global(Vector3(.6,.05,1))
	remote.net_pos = remote.global_position
	local.global_rotation = Vector3(0,.25,0)
	remote.global_rotation = Vector3(0,-.25,0)
	remote.net_yaw = -.25
	# Banks in both directions, climb/descent and repeated heading wraparounds.
	for step in 360:
		var old: Transform3D = w.bomber.global_transform
		var local_offset: Vector3 = old.affine_inverse()*local.global_position
		var remote_offset: Vector3 = old.affine_inverse()*remote.global_position
		var net_offset: Vector3 = old.affine_inverse()*remote.net_pos
		var heading := step*.025
		w.bomber.rotation = Vector3(sin(step*.06)*.5,heading,sin(step*.04)*.65)
		w.bomber.position += Vector3(.03,cos(step*.06)*.05,-.1)
		w.carry_crew(old)
		check(upright(local) and upright(remote),"Bank/climb/descent keeps both crew roots and visual models upright")
		check(local.global_position.distance_to(w.bomber.to_global(local_offset)) < .0001,"Local crew travels with the tilted deck")
		check(remote.global_position.distance_to(w.bomber.to_global(remote_offset)) < .0001,"Remote crew travels with the tilted deck")
		check(remote.net_pos.distance_to(w.bomber.to_global(net_offset)) < .0001,"Remote target travels in the same frame")
		check(absf(angle_difference(local.rotation.y,.25+heading))<.0001,"Crew heading follows the aircraft's yaw without roll drift")
		remote._physics_process(1.0/60)
		check(upright(remote),"Remote interpolation cannot reintroduce leaning")
	# Repair a residual tilt from old code, even while standing outside the plane.
	for elf in [local,remote]:
		elf.global_position = w.Airfield.SPAWN
		elf.net_pos = elf.global_position
		elf.rotation = Vector3(.4,.3,-.5)
		elf._physics_process(0)
		check(upright(elf),"Walking tick repairs residual pitch/roll outside the aircraft")
	# An animated crouch remains intentional; only the actor root is constrained.
	local.crouched = true
	local.presentation.animation.play("crouch_idle")
	local.presentation.animation.advance(.2)
	var skeleton: Skeleton3D = local.presentation.model.find_children("*","Skeleton3D",true,false)[0]
	var spine := skeleton.find_bone("Spine")
	check(skeleton.get_bone_pose_rotation(spine).angle_to(Quaternion.IDENTITY)>.1,"Crouch animation retains its spine pose")
	local.keep_upright()
	check(skeleton.get_bone_pose_rotation(spine).angle_to(Quaternion.IDENTITY)>.1,"Upright correction never cancels animation bones")
	local.crouched = false
	w.heading = .4
	w.bomber.rotation = Vector3(.3,.4,-.5)
	w.stations.yaw = .8
	w.stations.pitch = -.6
	w.stations.desired_yaw = .8
	w.stations.desired_pitch = -.6
	for id in [1,2]:
		var elf = w.players[id]
		w.stations.occupancy({"delivery":0,"turret":id})
		w.stations._physics_process(.1)
		var seat_basis: Basis = w.stations.turret_pitch.global_basis
		elf._physics_process(1.0/60)
		check(elf.global_basis.is_equal_approx(seat_basis),"Local and remote turret operators keep the gimbal orientation")
		w.stations.occupancy({"delivery":0,"turret":0})
		elf._physics_process(0)
		check(upright(elf),"Leaving the turret restores upright walking")
		check(elf.global_position.distance_to(w.bomber.to_global(w.stations.SEATS.turret)) < .1,"Turret exit stays beside the stairs")
	w.set_pilot(1)
	local._physics_process(0)
	check(upright(local),"Helm crew stays upright during bank")
	w.set_pilot(0)
	w.stations.occupancy({"delivery":1,"turret":0})
	w.stations._physics_process(.1)
	local._physics_process(0)
	check(upright(local),"Delivery console preserves world-up")
	w.stations.occupancy({"delivery":0,"turret":0})
	w.begin_level()
	for elf in [local,remote]:check(upright(elf),"Level reset/landing clears any seat orientation")
	print("ORIENTATION CHECKS: ","PASS" if failures==0 else "FAIL (%d)"%failures)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)
