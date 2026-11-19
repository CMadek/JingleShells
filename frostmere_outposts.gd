extends RefCounted
## Each landmark is a single colored mesh, including its approach tracks.
const RED := Color("#963e38")
const PAINT := Color("#f0dfb0")
const STEEL := Color("#425965")
const WOOD := Color("#72533e")
const SNOW := Color("#e4edf1")
var block := BoxMesh.new()
var gable := PrismMesh.new()
var drum := CylinderMesh.new()
var surface := SurfaceTool.new()

func build(parent: Node3D, survey: Dictionary) -> void:
	drum.radial_segments = 12
	drum.height = 1
	drum.rings = 0
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	for title in survey:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(mat)
		match title:
			"East Fold Farm": farm()
			"Trestle Crossing": trestle()
			"North Tank": water_tank()
		surface.index()
		var landmark := MeshInstance3D.new()
		landmark.name = title
		landmark.mesh = surface.commit()
		landmark.position = survey[title]
		parent.add_child(landmark)
		landmark.create_trimesh_collision()
		surface.clear()

func part(size: Vector3, center: Vector3, color: Color, primitive: PrimitiveMesh = null, basis := Basis.IDENTITY) -> void:
	var pose := Transform3D(basis.scaled_local(size), center)
	var normal := pose.basis.inverse().transposed()
	var source := primitive if primitive else block
	var arrays := source.get_mesh_arrays()
	for i in arrays[Mesh.ARRAY_INDEX]:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal((normal * arrays[Mesh.ARRAY_NORMAL][i]).normalized())
		surface.add_vertex(pose * arrays[Mesh.ARRAY_VERTEX][i])

func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var span := b-a
	part(Vector3(width,span.length(),width),(a+b)*.5,color,null,Basis(Quaternion(Vector3.UP,span.normalized())))

func shed(p: Vector3, w: float, h: float, d: float, color: Color) -> void:
	part(Vector3(w,h,d), p+Vector3.UP*(h*.5),color)
	part(Vector3(w+1.6,h*.62,d+1.8),p+Vector3.UP*(h*1.31),SNOW,gable)
	part(Vector3(w*.48,h*.78,.25),p+Vector3(0,h*.39,d*.5),WOOD)
	for side in [-1,1]:
		beam(p+Vector3(-side*w*.21,h*.1,d*.51),p+Vector3(side*w*.21,h*.69,d*.51),.24,PAINT)
		part(Vector3(.23,h*.78,.32),p+Vector3(side*w*.24,h*.39,d*.51),PAINT)
		part(Vector3(.3,h*.32,d*.18),p+Vector3(side*w*.50,h*.62,d*.2),PAINT)

func farm() -> void:
	shed(Vector3.ZERO,20,10,36,RED)
	shed(Vector3(40,0,26),14,6,21,Color("#536d60"))
	for x in [-25,-39]:
		part(Vector3(9,16,9),Vector3(x,8,-7),STEEL,drum)
		part(Vector3(9.4,1.8,9.4),Vector3(x,16.8,-7),SNOW,drum)
		for y in [3,9,14]:
			part(Vector3(9.2,.42,9.2),Vector3(x,y,-7),PAINT,drum)
	# Stubble emerges through the snow in alternating strips around a farm lane.
	for x in [-96,108]:
		for z in [-67,65]:
			part(Vector3(79,.08,100),Vector3(x,.04,z),Color("#b8bfad"))
			for i in 13:
				part(Vector3(1.7,.20,94),Vector3(x+(i-6)*5.6,.10,z),Color("#9d9981"))
	part(Vector3(291,.12,5),Vector3(6,.07,0),Color("#a2a9a8"))

func trestle() -> void:
	var bed := Color("#838a88")
	for side in [-1,1]:
		part(Vector3(94,.22,8),Vector3(side*103,.11,0),bed)
		# Snow-covered rail embankments climb gradually to the timber deck.
		var slope: float = -side * atan2(9.0,57.0)
		part(Vector3(58,1.1,6),Vector3(side*77,4.55,0),WOOD,null,Basis(Vector3.BACK,slope))
		for z in [-2.1,2.1]:
			part(Vector3(58,.26,.28),Vector3(side*77,5.2,z),STEEL,null,Basis(Vector3.BACK,slope))
			part(Vector3(44,.25,.28),Vector3(side*128,.31,z),STEEL)
	part(Vector3(100,1.5,7),Vector3(0,9.2,0),WOOD)
	for z in [-2.1,2.1]:
		part(Vector3(102,.30,.32),Vector3(0,10.12,z),STEEL)
		for x in range(-54,55,18):
			beam(Vector3(x,0,z*1.6),Vector3(x,9,z),1.35,WOOD)
			if x<54:
				beam(Vector3(x,1.5,z*1.5),Vector3(x+18,8,z),.88,WOOD)
				beam(Vector3(x+18,1.5,z*1.5),Vector3(x,8,z),.88,WOOD)
	shed(Vector3(121,0,-16),13,5,22,RED)
	for i in 3:
		var x := 112.0+i*14
		part(Vector3(12,3.1,4),Vector3(x,2.3,0),RED if i%2 else STEEL)
		part(Vector3(12.4,.4,4.3),Vector3(x,4.0,0),SNOW)

func water_tank() -> void:
	for x in [-5.5,5.5]:
		for z in [-5.5,5.5]:
			beam(Vector3(x*1.5,0,z*1.5),Vector3(x,23,z),1.25,STEEL)
			beam(Vector3(x*1.4,4,z*1.4),Vector3(-x,19,z),.65,STEEL)
			beam(Vector3(x*1.4,4,z*1.4),Vector3(x,19,-z),.65,STEEL)
	part(Vector3(18,12,18),Vector3(0,28,0),RED,drum)
	part(Vector3(18.2,2.8,18.2),Vector3(0,29,0),PAINT,drum)
	var cap := CylinderMesh.new()
	cap.radial_segments = 12
	cap.height = 1
	cap.rings = 0
	cap.top_radius = .035
	part(Vector3(20,5,20),Vector3(0,36.4,0),SNOW,cap)
	shed(Vector3(26,0,12),12,5,19,Color("#536d60"))
