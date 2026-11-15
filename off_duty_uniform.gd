extends RefCounted

static func dress(actor: Node3D, clip: String, color: Color, expression: String) -> Array[Dictionary]:
	var blink_targets: Array[Dictionary] = []
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_blend_shape_count():
			node.set_blend_shape_value(index, 0.0)
			var shape: String = node.mesh.get_blend_shape_name(index)
			if shape == expression:
				node.set_blend_shape_value(index, 1.0)
			elif shape == expression + "Blink":
				blink_targets.append({"mesh":node,"index":index})
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material is StandardMaterial3D and material.resource_name == "Skin":
				var skin: StandardMaterial3D = material.duplicate()
				skin.vertex_color_use_as_albedo = true
				skin.vertex_color_is_srgb = false
				node.set_surface_override_material(surface, skin)
			elif material and material.resource_name == "Coat":
				var coat := ShaderMaterial.new()
				coat.shader = preload("res://assets/elf/coat_palette.gdshader")
				coat.set_shader_parameter("surface_color", material.albedo_texture)
				coat.set_shader_parameter("coat_mask", preload("res://assets/elf/textures/crew_coat_tint.png"))
				coat.set_shader_parameter("coat_color", color)
				# Matte wool: the nearby lantern otherwise washes sleeve folds cream.
				coat.set_shader_parameter("cloth_specular", 0.0)
				node.set_surface_override_material(surface, coat)
			elif clip != "menu_sit" and material and material.resource_name.begins_with("Candy cane"):
				node.hide()
			elif clip != "menu_cocoa" and material and material.resource_name.begins_with("Cocoa"):
				node.hide()
			elif clip != "menu_lean" and material and material.resource_name.begins_with("Watch"):
				node.hide()
	return blink_targets
