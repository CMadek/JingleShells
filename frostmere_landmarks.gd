extends RefCounted

const TIMBER := Color("#77523f")
const STEEL := Color("#42585c")
const RED := Color("#99483d")
const SNOW := Color("#deeaed")
const HONEY := Color("#ffcb83")

static func build(w: Node3D, district: Node3D) -> void:
	var quay := anchor(district, "Lantern Quay")
	for i in 3:
		var x := -10.0+i*10
		w._box(quay,Vector3(2.6,.55,14),Vector3(x,.49,13),TIMBER,false,quay)
		for side in [-1,1]:
			w._box(quay,Vector3(.35,1.8,.35),Vector3(x+side*1.35,.9,6.4),STEEL)
		var boat := Node3D.new()
		quay.add_child(boat)
		boat.position = Vector3(x+3.4,0,10+i*.9)
		boat.rotation.y = .10*(i-1)
		var hull: MeshInstance3D = w._box(boat,Vector3(2.6,1.25,6.6),Vector3(0,.7,0),RED)
		w._box(boat,Vector3(2.75,.18,6.8),Vector3(0,1.36,0),SNOW)
		w._box(boat,Vector3(1.86,1.60,2.34),Vector3(0,2.19,.8),STEEL)
		w._box(boat,Vector3(1.52,.61,.08),Vector3(0,2.35,2.0),HONEY,true)
		w._box(boat,Vector3(2.18,.22,2.62),Vector3(0,3.07,.8),SNOW)
		w._box(boat,Vector3(.16,5.6,.16),Vector3(0,3.6,-1.4),TIMBER)
		hull.create_convex_collision()
	w._box(quay,Vector3(34,.65,3.2),Vector3(0,.49,20.2),TIMBER,false,quay)

	var tower := anchor(district, "Bell Square")
	w._box(tower,Vector3(9,.35,9),Vector3(0,.18,0),SNOW,false,tower)
	w._box(tower,Vector3(4.4,13,4.4),Vector3(0,6.5,0),RED,false,tower)
	w._box(tower,Vector3(5.1,3.6,5.1),Vector3(0,14.8,0),STEEL,false,tower)
	for i in 4:
		var face := Node3D.new()
		tower.add_child(face)
		face.rotation.y = i*PI*.5
		var dial := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.38
		disc.bottom_radius = 1.38
		disc.height = .12
		dial.mesh = disc
		dial.material_override = w._mat(HONEY,true)
		dial.rotation.x = PI*.5
		dial.position = Vector3(0,14.8,2.57)
		face.add_child(dial)
		w._box(face,Vector3(.14,.91,.10),Vector3(0,15.2,2.69),STEEL)
		w._box(face,Vector3(.68,.14,.10),Vector3(.32,14.81,2.69),STEEL)
	var spire := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.radial_segments = 4
	cone.top_radius = .05
	cone.bottom_radius = 4.25
	cone.height = 7
	spire.mesh = cone
	spire.material_override = w._mat(SNOW)
	spire.position.y = 20.1
	spire.rotation.y = PI*.25
	tower.add_child(spire)
	spire.create_convex_collision()

	var mill := anchor(district,"Saw Works")
	w._box(mill,Vector3(13,6,17),Vector3(0,3,0),RED,false,mill)
	for i in 3:
		var roof: MeshInstance3D = w._box(mill,Vector3(4.75,.38,18),Vector3((i-1)*4.38,6.70,0),SNOW)
		roof.rotation.z = .24
		w._box(mill,Vector3(.18,.95,16.7),Vector3((i-1)*4.38+2.12,6.52,0),HONEY,true)
	for i in 7:
		w._box(mill,Vector3(3.16,3.2,3.16),Vector3(8.6,1.6+i*3.2,-4),RED if i%2 == 0 else SNOW,false,mill)

	var rng := RandomNumberGenerator.new()
	rng.seed = district.route_seed
	var ridge: Vector3 = district.landmarks["Saw Works"]
	for i in 13:
		var peak := MeshInstance3D.new()
		peak.mesh = fell(rng)
		peak.position = ridge + Vector3((i-9)*105, -3, -440-rng.randf_range(0,100))
		district.add_child(peak)
		peak.create_convex_collision()

# Broken cirques and exposed faces give the north ridge a navigable silhouette.
static func fell(rng: RandomNumberGenerator) -> ArrayMesh:
	var foot := PackedVector3Array()
	var shelf := PackedVector3Array()
	var snowline := PackedVector3Array()
	var top := Vector3(rng.randf_range(-28,28),rng.randf_range(64,150),rng.randf_range(-20,20))
	for i in 11:
		var angle := TAU*i/11
		var radius := rng.randf_range(72,110)
		var p := Vector3(cos(angle)*radius,0,sin(angle)*radius*.84)
		foot.append(p)
		shelf.append(p.lerp(top,rng.randf_range(.25,.42))+Vector3.UP*rng.randf_range(-5,6))
		snowline.append(p.lerp(top,rng.randf_range(.52,.80))+Vector3.UP*rng.randf_range(0,8))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(mat)
	for i in foot.size():
		var j := (i+1)%foot.size()
		var stone := Color("7d8c9d") if i%3 else Color("a0b3bf")
		for tri in [[foot[i],foot[j],shelf[j],SNOW],[foot[i],shelf[j],shelf[i],SNOW],
					[shelf[i],shelf[j],snowline[j],stone],[shelf[i],snowline[j],snowline[i],stone],
					[snowline[i],snowline[j],top,SNOW]]:
			var normal: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
			for k in 3:
				surface.set_normal(normal)
				surface.set_color(tri[3].srgb_to_linear())
				surface.add_vertex(tri[k])
	return surface.commit()

static func anchor(district: Node3D, title: String) -> StaticBody3D:
	var node := StaticBody3D.new()
	district.add_child(node)
	node.position = district.landmarks[title]
	node.rotation.y = district.bearing
	return node
