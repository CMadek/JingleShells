extends RefCounted
## Runtime companions to the Blender palette; no per-frame material allocation.

static func apply(plane: Node3D, airframe: Node3D) -> void:
	polish_glass(airframe)
	# Downward spots use one shadow view each, rather than six for an omni.
	# Small fills keep stairs, cargo labels and the gunner readable.
	lamp(plane, "CockpitWarmKey", Vector3(0,4.3,-7.4), 2.0, 6.8, true)
	lamp(plane, "CabinWarmKey", Vector3(0,3.6,1.0), 2.2, 9.0, true)
	lamp(plane, "StoresWarmKey", Vector3(0,3.2,9.2), 1.8, 6.2, true)
	lamp(plane, "StairFill", Vector3(-.6,2.8,-3.7), .7, 4.8)
	lamp(plane, "LoadingFill", Vector3(0,2.4,5.6), .55, 4.0)
	lamp(plane, "GunnerFill", Vector3(1.75,-.8,-7.3), .3, 2.3)
	# Moving reflection probes recapture even in UPDATE_ONCE mode. Soft fills
	# provide the cabin bounce without six additional views while flying.
	lamp(plane, "CabinBounce", Vector3(0,2.8,.4), .65, 13)
	lamp(plane, "CockpitBounce", Vector3(0,3.6,-7.6), .45, 6)

static func lamp(parent: Node3D, title: String, pos: Vector3, energy: float, reach: float, shadows: bool = false) -> void:
	var light: Light3D
	if shadows:
		var spot := SpotLight3D.new()
		spot.spot_range = reach
		spot.spot_angle = 82
		spot.spot_angle_attenuation = .35
		spot.spot_attenuation = 1.1
		spot.rotation.x = -PI/2
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = reach
		omni.omni_attenuation = 1.3
		light = omni
	light.name = title
	light.position = pos
	light.light_color = Color(1.0,.83,.61)
	light.light_energy = energy
	light.light_size = .25
	light.shadow_enabled = shadows
	light.shadow_bias = .035
	light.shadow_normal_bias = .5
	parent.add_child(light)

static func polish_glass(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.get_active_material(surface)
			if source is StandardMaterial3D and ("wool" in source.resource_name.to_lower() or "headliner" in source.resource_name.to_lower()):
				# Cloth must not reflect a bright lamp as a polished ceiling hotspot.
				var cloth: StandardMaterial3D = source.duplicate()
				cloth.metallic = 0
				cloth.metallic_specular = .08
				node.set_surface_override_material(surface,cloth)
			if source is StandardMaterial3D and source.resource_name in ["Turret crystal glass", "Pale glacier glazing"]:
				var glass: StandardMaterial3D = source.duplicate()
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				glass.albedo_color = Color(.68,.85,.88,.10 if source.resource_name == "Turret crystal glass" else .075)
				glass.metallic = .08
				glass.metallic_specular = .3
				glass.roughness = .19
				glass.refraction_enabled = false
				node.set_surface_override_material(surface, glass)
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		polish_glass(child)
