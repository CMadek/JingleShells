extends SceneTree
## Validate the imported character contract, including the complexion regression.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var body = load("res://assets/elf/flight_elf.glb").instantiate()
	var arms = load("res://assets/elf/first_person_arms.glb").instantiate()
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	check(skeleton.get_bone_count() == 13, "Gameplay skeleton retains its bones plus one scarf bone")
	check(skeleton.find_bone("CargoSocket") >= 0, "Remote carrying socket is present")
	check(skeleton.find_bone("Scarf") >= 0, "Third-person scarf has its own anchored bone")
	check(arms.find_children("*", "Skeleton3D", true, false).is_empty(), "First-person arms must not contain the scarf rig")
	var animation: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
	for clip in ["idle", "walk", "jump", "land", "crouch_idle", "crouch_walk", "crouch_carry_idle", "crouch_carry_walk", "pickup", "carry_idle", "carry_walk", "charge", "throw", "drop", "helm"]:
		check(animation.has_animation(clip), "Missing gameplay clip: " + clip)
	var complexion_found := false
	var coat_found := false
	var blended_vertices := 0
	var triangles := 0
	for node in body.find_children("*", "MeshInstance3D", true, false):
		for i in node.mesh.get_surface_count():
			var arrays = node.mesh.surface_get_arrays(i)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var material = node.get_active_material(i)
			check(material.resource_name not in ["Rosy cheeks", "Flax stitching"], "Blush and decorative lines belong to surfaces, not separate mesh layers")
			if material.resource_name in ["Coat", "Cranberry", "Wool", "Leather", "Brass"]:
				check(material.albedo_texture != null, "Costume detail must be baked into an albedo atlas: " + material.resource_name)
			if material.resource_name == "Skin":
				complexion_found = true
				check(material.vertex_color_use_as_albedo, "Imported Skin must use its complexion colors")
				check(not material.vertex_color_is_srgb, "GLB complexion colors are already linear")
				check(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(), "Every skin vertex needs a complexion color")
			if material.resource_name == "Coat":
				coat_found = true
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var stride: int = weights.size() / arrays[Mesh.ARRAY_VERTEX].size()
				for vertex in arrays[Mesh.ARRAY_VERTEX].size():
					var total := 0.0
					var influences := 0
					for j in stride:
						var weight := weights[vertex * stride + j]
						total += weight
						if weight > .001: influences += 1
					check(absf(total - 1.0) < .005, "Clothing bone weights remain normalized after import")
					if influences > 1: blended_vertices += 1
	check(complexion_found and coat_found, "Skin and customizable Coat material contracts are present")
	check(blended_vertices > 100, "Continuous sleeves need blended shoulder and elbow weights")
	root.add_child(body)
	animation.play("walk")
	animation.advance(.05)
	var scarf := skeleton.find_bone("Scarf")
	var scarf_start := skeleton.get_bone_pose_rotation(scarf)
	animation.advance(.22)
	check(scarf_start.angle_to(skeleton.get_bone_pose_rotation(scarf)) > .02, "Walking visibly jostles the scarf")
	var arms_coat := false
	for node in arms.find_children("*", "MeshInstance3D", true, false):
		for i in node.mesh.get_surface_count():
			if node.get_active_material(i).resource_name == "Coat": arms_coat = true
	check(arms_coat, "First-person sleeves retain coat customization")
	print("ELF ASSET CHECK: ", "PASS" if failures == 0 else "FAIL", " | triangles=", triangles, " | blended coat vertices=", blended_vertices)
	body.free()
	arms.free()
	quit(1 if failures else 0)
