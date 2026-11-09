extends CharacterBody3D
## One elf. Child of the Bomber node, so it rides along with the ship.
## Each peer controls its own elf and streams its state to everyone else.

const Cargo := preload("res://cargo.gd")
var held_kind := Cargo.Kind.EMPTY
var held_model: Node3D
var charging_since := -1

const WALK_SPEED := 5.0
const JUMP_SPEED := 5.0
const GRAVITY := 18.0
const MOUSE_SENS := 0.0022

var peer_id := 1
var world: Node3D
var head: Node3D
var cam: Camera3D
var body_mesh: Node3D
var pitch := 0.0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 17
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)

	var col := Color.from_hsv((peer_id % 360) / 360.0, 0.6, 0.9)
	body_mesh = Node3D.new()
	add_child(body_mesh)

	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.5
	torso.mesh = cm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = col
	torso.material_override = tm
	torso.position.y = 0.8
	body_mesh.add_child(torso)

	var hat := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.3
	cone.height = 0.7
	hat.mesh = cone
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.8, 0.1, 0.1)
	hat.material_override = hm
	hat.position.y = 1.9
	body_mesh.add_child(hat)

	var tag := Label3D.new()
	tag.text = "Elf %d" % (peer_id % 1000)
	tag.position.y = 2.5
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.005
	tag.font_size = 48
	body_mesh.add_child(tag)

	net_pos = position
	if is_multiplayer_authority():
		cam = Camera3D.new()
		cam.current = true
		cam.far = 2000.0
		head.add_child(cam)
		body_mesh.visible = false


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and held_kind != Cargo.Kind.EMPTY and world.pilot_id != peer_id:
			if event.pressed and charging_since < 0:
				charging_since = Time.get_ticks_msec()
				world.cargo_action("charge")
			elif not event.pressed and charging_since >= 0:
				charging_since = -1
				world.cargo_action("throw")
	elif event.is_action_pressed("ui_cancel"):
		charging_since = -1
		world.cargo_action("cancel")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact"):
		var item_id: int = world.aimed_loose(head.global_transform) if held_kind == Cargo.Kind.EMPTY else 0
		if world.pilot_id != peer_id and item_id != 0:
			world.cargo_action("pickup", item_id)
		elif world.pilot_id == peer_id or position.distance_to(world.HELM_POS) < 2.5:
			world.request_helm()
		else:
			world.cargo_action("pickup")
	elif event.is_action_pressed("drop_cargo"):
		charging_since = -1
		world.cargo_action("drop")


func carry(kind: int) -> void:
	charging_since = -1
	held_kind = kind
	if held_model:
		held_model.queue_free()
		held_model = null
	if kind != Cargo.Kind.EMPTY:
		held_model = Cargo.model(kind)
		head.add_child(held_model)
		held_model.position = Vector3(0.29, -0.27, -0.65)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		position = position.lerp(net_pos, 0.35)
		rotation.y = lerp_angle(rotation.y, net_yaw, 0.35)
		head.rotation.x = net_pitch
		return

	if world.pilot_id == peer_id:
		velocity = Vector3.ZERO
		position = world.HELM_POS
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		world.send_pilot_input(v.x, -v.y, Input.get_axis("descend", "jump"))
	else:
		if is_on_floor():
			velocity.y = JUMP_SPEED if Input.is_action_just_pressed("jump") else 0.0
		else:
			velocity.y -= GRAVITY * delta
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := global_transform.basis * Vector3(input.x, 0, input.y)
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
		move_and_slide()

	# Safety net: if you somehow fall out of the ship, hop back in.
	if global_position.y < world.bomber.global_position.y - 6.0:
		position = Vector3(0, 0.3, 1)
		velocity = Vector3.ZERO

	world.get_parent().sync_elf.rpc(position, rotation.y, head.rotation.x)
