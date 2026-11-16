extends RefCounted
## Snow and foliage share one cone mesh per batch regardless of the number of firs.
static func add_tiers(parent: Node3D, transforms: Array[Transform3D], material: Material) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 1
	cone.height = 1
	cone.radial_segments = 9
	cone.rings = 0
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = cone
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
	var trees := MultiMeshInstance3D.new()
	trees.multimesh = batch
	trees.material_override = material
	parent.add_child(trees)
