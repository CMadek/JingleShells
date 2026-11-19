extends RefCounted
## A fixed supply display shared by every peer. Only collected cargo becomes a game item.
const Cargo := preload("res://cargo.gd")
const PALLET_TOP := .21
const PAPERS := [Color("#bd304b"), Color("#28725c"), Color("#437994"), Color("#a96537")]

static func build(world: Node3D, hull: StaticBody3D) -> void:
	var stores := Node3D.new()
	stores.name = "DeliveryStores"
	world.bomber.add_child(stores)
	world._hull_box(hull, Vector3(4.85, .034, 4.85), Vector3(0, .014, 9.495))
	for side in [-1, 1]:
		world._hull_box(hull, Vector3(1.24, PALLET_TOP, 3.22), Vector3(side * 1.77, PALLET_TOP / 2, 9.50))
	var parcel_mesh := _stock_mesh(Cargo.PRESENT_MODEL)
	var batches := [[], [], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1224
	for row in 2:
		var heights := [1, 2, 2, 2, 2, 1] if row == 0 else [2, 3, 4, 4, 3, 2]
		for column in heights.size():
			var top := PALLET_TOP
			for layer in heights[column]:
				var scale := Vector3(rng.randf_range(.94, 1.07), rng.randf_range(.72, 1.19), rng.randf_range(.94, 1.04))
				var yaw := rng.randf_range(-.075, .075)
				var center := Vector3(-1.48 - row * .55, top + Cargo.HALF_SIZE * scale.y, 8.20 + column * .52)
				batches[rng.randi_range(0, PAPERS.size() - 1)].append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale), center))
				var box: CollisionShape3D = world._hull_box(hull, scale * Cargo.HALF_SIZE * 2, center)
				box.rotation.y = yaw
				box.set_meta("stock_kind", Cargo.Kind.PRESENT)
				top += Cargo.HALF_SIZE * 2 * scale.y
	for i in PAPERS.size():
		var mesh := parcel_mesh.duplicate() as Mesh
		for index in mesh.get_surface_count():
			var mat := mesh.surface_get_material(index) as StandardMaterial3D
			if mat and (mat.resource_name.begins_with("Paper ") or mat.resource_name.begins_with("Lid ")):
				var paper := mat.duplicate() as StandardMaterial3D
				paper.albedo_color = PAPERS[i].lightened(.13) if mat.resource_name.begins_with("Lid ") else PAPERS[i]
				mesh.surface_set_material(index, paper)
		_display(stores, mesh, batches[i])

	# The upper row sits in the pockets between four neighboring lower shells.
	var bombs := []
	var radius := .28
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	for layer in 2:
		for row in 2 - layer:
			for column in 6 - layer:
				var center := Vector3(1.48 + (row + .5 * layer) * 2 * radius,
					PALLET_TOP + radius + layer * sqrt(2.0) * radius, 8.10 + (column + .5 * layer) * 2 * radius)
				var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)).rotated(Vector3.RIGHT, rng.randf_range(-.25, .25))
				bombs.append(Transform3D(basis.scaled(Vector3.ONE * radius / Cargo.HALF_SIZE), center))
				var collision := CollisionShape3D.new()
				collision.shape = sphere
				collision.position = center
				collision.set_meta("stock_kind", Cargo.Kind.BOMB)
				hull.add_child(collision)
	_display(stores, _stock_mesh(Cargo.BOMB_MODEL), bombs)

static func _stock_mesh(scene: PackedScene) -> Mesh:
	# The cargo exporter joins the prop into one mesh and bakes its transform.
	var root := scene.instantiate()
	var geometry := root as MeshInstance3D
	if not geometry: geometry = root.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := geometry.mesh
	root.free()
	return mesh

static func _display(parent: Node3D, mesh: Mesh, poses: Array) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = poses.size()
	for i in poses.size():
		batch.set_instance_transform(i, poses[i])
	var display := MultiMeshInstance3D.new()
	display.multimesh = batch
	parent.add_child(display)
