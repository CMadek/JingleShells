@tool
extends EditorScenePostImport
## Godot's importer leaves the GLB complexion attribute disabled on Skin.
## Enable its linear vertex colors on the imported material, including reimports.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_surface_count():
			var material = node.get_active_material(index)
			if material is StandardMaterial3D and material.resource_name == "Skin":
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
	return scene
