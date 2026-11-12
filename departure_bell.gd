extends Node3D
## Transient, host-authorized bell pulls. Late joiners do not replay old rings.
const LOCATION := Vector3(2.5, 2.65, 5.25)
const HANDLE := Vector3(0, -1.25, 0)
const COOLDOWN_MS := 1200
const CHIME := preload("res://assets/audio/departure_bell.wav")
var world: Node3D
var bell: Node3D
var clapper: Node3D
var rope: Node3D
var cord: MeshInstance3D
var sound: AudioStreamPlayer3D
var elapsed := 10.0
var last_pull_ms := -COOLDOWN_MS
var ring_count := 0

func build(w: Node3D) -> void:
	world = w
	position = LOCATION
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("c79743")
	brass.metallic = .75
	brass.roughness = .28
	brass.cull_mode = BaseMaterial3D.CULL_DISABLED
	world._box(self,Vector3(.12,.45,.38),Vector3(.4,-.02,0),Color("294d40"))
	world._box(self,Vector3(.52,.08,.12),Vector3(.15,.15,0),Color("c79743"))
	bell = Node3D.new()
	add_child(bell)
	# Revolved inner and outer shell, open at the mouth.
	var profile := [Vector2(.055,.07),Vector2(.11,0),Vector2(.13,-.12),Vector2(.17,-.27),Vector2(.27,-.36),Vector2(.27,-.40),Vector2(.23,-.40),Vector2(.20,-.30),Vector2(.10,-.12),Vector2(.075,-.025),Vector2(.025,.025)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for segment in range(48):
			var points: Array[Vector3] = []
			for pair in [Vector2i(row,segment),Vector2i(row,segment+1),Vector2i(row+1,segment+1),Vector2i(row+1,segment)]:
				var radius: float = profile[pair.x].x
				var angle: float = pair.y*TAU/48
				points.append(Vector3(cos(angle)*radius,profile[pair.x].y,sin(angle)*radius))
			for index in [0,1,2,0,2,3]: surface.add_vertex(points[index])
	surface.generate_normals()
	var shell := MeshInstance3D.new()
	shell.mesh = surface.commit()
	shell.material_override = brass
	bell.add_child(shell)
	clapper = Node3D.new()
	bell.add_child(clapper)
	world._box(clapper,Vector3(.035,.3,.035),Vector3(0,-.18,0),Color("403529"))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .065
	sphere.height = .13
	ball.mesh = sphere
	ball.material_override = brass
	ball.position.y = -.33
	clapper.add_child(ball)
	rope = Node3D.new()
	add_child(rope)
	cord = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .014
	cylinder.bottom_radius = .014
	cylinder.height = .86
	cord.mesh = cylinder
	cord.position.y = -.81
	cord.material_override = world._mat(Color("d8c39a"))
	rope.add_child(cord)
	var grip := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = .065
	ring_mesh.outer_radius = .105
	grip.mesh = ring_mesh
	grip.material_override = brass
	grip.position = HANDLE
	grip.rotation.z = PI/2
	rope.add_child(grip)
	world._label3d(self,"DEPARTURE BELL\nE • PULL",Vector3(0,-.45,.55))
	var label := get_child(-1) as Label3D
	label.font_size = 28
	label.pixel_size = .003
	sound = AudioStreamPlayer3D.new()
	sound.stream = CHIME
	sound.bus = "Master"
	sound.unit_size = 8
	sound.max_distance = 65
	sound.volume_db = -5
	sound.max_polyphony = 2
	add_child(sound)

func aimed(view: Transform3D) -> bool:
	var target := to_global(HANDLE + Vector3(0,rope.position.y,0))
	var offset := target-view.origin
	var along := offset.dot(-view.basis.z)
	if offset.length() > 2.8 or along <= 0 or (offset+view.basis.z*along).length() > .32:
		return false
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(view.origin,target,1|16)).is_empty()

func request_pull() -> void:
	if multiplayer.is_server():
		handle_pull(1)
	else:
		pull_remote.rpc_id(1)

@rpc("any_peer", "reliable")
func pull_remote() -> void:
	if multiplayer.is_server(): handle_pull(multiplayer.get_remote_sender_id())

func handle_pull(id: int) -> void:
	if not multiplayer.is_server() or not world.players.has(id) or world.pilot_id == id:
		return
	if Time.get_ticks_msec()-last_pull_ms < COOLDOWN_MS or not aimed(world.players[id].head.global_transform):
		return
	last_pull_ms = Time.get_ticks_msec()
	ring.rpc()

@rpc("authority", "call_local", "reliable")
func ring() -> void:
	elapsed = 0
	ring_count += 1
	sound.play()

func _process(delta: float) -> void:
	if not bell: return
	elapsed += delta
	var pull := sin(clampf(elapsed/.45,0,1)*PI)*.22
	rope.position.y = -pull
	cord.mesh.height = .86 + pull
	cord.position.y = -.81 + pull/2
	var swing := sin(elapsed*13)*exp(-elapsed*1.65)*.42 if elapsed < 4 else 0.0
	bell.rotation.z = swing
	clapper.rotation.z = -swing*1.4
	rope.rotation.z = swing*.08

func _exit_tree() -> void:
	if is_instance_valid(sound): sound.stop()
