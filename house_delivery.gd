extends Node
## Recipient identity and visual destruction; all gameplay decisions are made by World.
var world: Node3D
var houses: Array[Dictionary] = []
var effects: Array[Node3D] = []

func register(root: StaticBody3D, nice: bool, chimney: StaticBody3D) -> void:
	var id := houses.size()
	root.set_meta("house_id", id)
	chimney.set_meta("chimney", true)
	houses.append({"root": root, "nice": nice, "destroyed": false, "base": root.position})

func identify(collider: Object) -> Dictionary:
	var node := collider as Node
	var precision := false
	while node and node != world:
		precision = precision or node.has_meta("chimney")
		if node.has_meta("house_id"):
			return {"id": int(node.get_meta("house_id")), "precision": precision}
		node = node.get_parent()
	return {}

func disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children(): disable_collisions(child)

func destroy(id: int, impact: Vector3, animate: bool) -> void:
	if id < 0 or id >= houses.size() or houses[id].destroyed: return
	var house: Dictionary = houses[id]
	house.destroyed = true
	var root: Node3D = house.root
	root.hide()
	disable_collisions(root)
	var ruins := StaticBody3D.new()
	world.add_child(ruins)
	ruins.position = house.base
	world._box(ruins, Vector3(7.8,.45,6.8), Vector3(0,.225,0), Color("494348"), false, ruins)
	for i in 5:
		world._box(ruins, Vector3(1.1,.6,1.5), Vector3(-3+i*1.4,.55,sin(i*2.1)*2), Color("655355"), false, ruins)
	if animate:
		world.landing_burst(impact, world.Cargo.Kind.BOMB)
		var burst := Node3D.new()
		world.add_child(burst)
		burst.position = house.base + Vector3(0,3,0)
		track_effect(burst)
		var tween := burst.create_tween().set_parallel(true)
		for i in 20:
			var piece := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(.45,.18,.65)
			piece.mesh = mesh
			piece.material_override = world._mat(Color("654c46") if i < 12 else Color("514f55"))
			burst.add_child(piece)
			var angle := i * 2.4
			var end := Vector3(cos(angle)*5, -2.5, sin(angle)*5)
			piece.position = Vector3(0, i%3, 0)
			if i >= 12:
				piece.mesh = SphereMesh.new()
				end.y = 7
				tween.tween_property(piece,"scale",Vector3.ONE*3,1.5)
			tween.tween_property(piece,"position",end,1.5).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(piece,"rotation",Vector3(i,2*i,i),1.5)
			tween.tween_property(piece,"scale",Vector3.ONE*.01,.5).set_delay(1.5)
		tween.chain().tween_callback(burst.queue_free)

func track_effect(node: Node3D) -> void:
	effects = effects.filter(func(item): return is_instance_valid(item))
	if effects.size() >= 24:
		var oldest = effects.pop_front()
		oldest.queue_free()
	effects.append(node)

func popup(position: Vector3, message: String) -> void:
	var label := Label3D.new()
	label.text = message
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.pixel_size = .012
	world.add_child(label)
	label.position = position + Vector3.UP
	track_effect(label)
	var tween := label.create_tween()
	tween.tween_property(label,"position",label.position+Vector3.UP*2,1.4)
	tween.tween_callback(label.queue_free)
