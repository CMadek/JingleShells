extends Node3D
## The quartermaster's hand-folded decorations. All movement is local to the room.
const CHART_PAPER := preload("res://assets/depot/chart_scraps.svg")
const SCARF := preload("res://assets/depot/door_scarf.gdshader")
var stars: Array[Node3D] = []
var dark: StandardMaterial3D
var brass: StandardMaterial3D
var elapsed := 0.0

func finish(tint: Color, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = metal
	mat.roughness = .42 if metal else .79
	return mat

func mesh_node(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	parent.add_child(visual)
	return visual

func cylinder(a: float, b: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = a
	m.bottom_radius = b
	m.height = h
	m.radial_segments = 12
	m.rings = 0
	return m

func rod(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var line := mesh_node(parent,cylinder(r,r,a.distance_to(b)),(a+b)*.5,mat)
	line.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func batch(mesh: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in transforms.size(): instances.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = mat
	add_child(node)

func build() -> void:
	dark = finish(Color("42392d"))
	brass = finish(Color("aa8551"),.54)
	var paper := finish(Color.WHITE)
	paper.albedo_texture = CHART_PAPER
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	var star_mesh := folded_star()
	var caps: Array[Transform3D] = []
	var wire: Array[Transform3D] = []
	var bulbs: Array = [[],[],[],[]]
	var globe := SphereMesh.new()
	globe.radial_segments = 12
	globe.rings = 6
	globe.radius = .048
	globe.height = .143
	for span in [[Vector3(-35.6,4.13,844.3),Vector3(-20.45,4.05,837.8),.71,17],
			[Vector3(-35.6,4.05,836.3),Vector3(-20.45,4.1,833.5),.32,14]]:
		var a: Vector3 = span[0]
		var b: Vector3 = span[1]
		var previous := a
		for i in range(1,int(span[3])+1):
			var t := float(i)/float(span[3])
			var p := a.lerp(b,t)-Vector3.UP*float(span[2])*4*t*(1-t)
			wire.append(Transform3D(Basis(Quaternion(Vector3.UP,(p-previous).normalized())).scaled_local(Vector3(1,p.distance_to(previous),1)),(p+previous)*.5))
			previous = p
			if i == span[3]: continue
			caps.append(Transform3D(Basis.IDENTITY,p-Vector3.UP*.042))
			bulbs[(i*3+floori(i/3.0))%4].append(Transform3D(Basis.IDENTITY,p-Vector3.UP*.142))
			if i % 4 == 1:
				var pivot := Node3D.new()
				add_child(pivot)
				pivot.position = p
				var length := .31+.10*(i%3)
				rod(pivot,Vector3.ZERO,Vector3.DOWN*length,.006,dark)
				var ornament := mesh_node(pivot,star_mesh,Vector3.DOWN*(length+.18),paper)
				ornament.scale = Vector3.ONE*(.32+.045*(i%3))
				stars.append(pivot)
	batch(cylinder(.010,.010,1.0),wire,dark)
	batch(cylinder(.03,.033,.083),caps,brass)
	var palette := [Color("ffc076"),Color("e06749"),Color("85c393"),Color("ffe0a3")]
	for i in bulbs.size():
		var glass := finish(palette[i])
		glass.emission_enabled = true
		glass.emission = palette[i]
		glass.emission_energy_multiplier = 1.8
		var transforms: Array[Transform3D] = []
		transforms.assign(bulbs[i])
		batch(globe,transforms,glass)
	door_curtain()
	counter_swags()

func folded_star() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var p := Vector3.UP.rotated(Vector3.BACK,-TAU*i/10.0) * (1.0 if i%2==0 else .43)
		var q := Vector3.UP.rotated(Vector3.BACK,-TAU*(i+1)/10.0) * (1.0 if i%2==1 else .43)
		for side in [-1,1]:
			var peak := Vector3(0,0,.29*side)
			var tri := [peak,p,q] if side == 1 else [peak,q,p]
			var normal: Vector3 = (tri[2]-peak).cross(tri[1]-peak).normalized()
			for v: Vector3 in tri:
				st.set_normal(normal)
				st.set_uv(Vector2(.5+.48*v.x,.5-.48*v.y))
				st.add_vertex(v)
	return st.commit()

func door_curtain() -> void:
	# A salvaged striped mail sack tied back at the north jamb of the apron door.
	var cloth := ShaderMaterial.new()
	cloth.shader = SCARF
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 22
	var rows := 18
	for j in range(rows+1):
		var v := float(j)/rows
		var gather := exp(-pow((v-.65)/.18,2))
		for i in range(cols+1):
			var u := float(i)/cols
			var fold := sin(u*PI*9+.6*v)
			var z := 834.19 + u*(1.55-.96*v-.34*gather) + .12*sin(PI*v)
			var x := -20.28-.12*fold*(1-.50*gather)-.15*v
			var y := 3.12-v*(1.86+.23*u)-.04*v*fold
			st.set_uv(Vector2(u,v))
			st.add_vertex(Vector3(x,y,z))
	for j in range(rows):
		for i in range(cols):
			var k := j*(cols+1)+i
			for index in [k,k+cols+1,k+1,k+1,k+cols+1,k+cols+2]: st.add_index(index)
	st.generate_normals()
	mesh_node(self,st.commit(),Vector3.ZERO,cloth)
	rod(self,Vector3(-20.29,3.17,834.08),Vector3(-20.29,3.17,835.86),.026,brass)

func counter_swags() -> void:
	# Interleaved fir sprays with berries, in one mesh for both counter screens.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1947
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var berries: Array[Transform3D] = []
	for x0: float in [-32.15,-26.75]:
		for i in 78:
			var t := i/77.0
			var p := Vector3(x0+1.91*t,2.93-.26*sin(t*PI),834.12)
			var side := -1.0 if i%2 else 1.0
			var axis := Vector3(side*.10,-rng.randf_range(.10,.20),rng.randf_range(.04,.15))
			var color := Color("336547").darkened(rng.randf_range(0,.34))
			for j in 6:
				var b := p+axis*j/7.0
				for hand in [-1,1]:
					var tip := b+axis*.39+Vector3(hand*.062,-.024,.023)
					for vertex in [b-Vector3.RIGHT*.017,b+Vector3.RIGHT*.017,tip]:
						leaves.set_color(color)
						leaves.set_normal(Vector3(.1,.5,.86))
						leaves.add_vertex(vertex)
			if i%8 < 2: berries.append(Transform3D(Basis.IDENTITY,p+axis*.65+Vector3.BACK*.075))
	var needles := finish(Color.WHITE)
	needles.vertex_color_use_as_albedo = true
	needles.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node(self,leaves.commit(),Vector3.ZERO,needles)
	var berry := SphereMesh.new()
	berry.radius = .036
	berry.height = .072
	berry.radial_segments = 8
	berry.rings = 4
	batch(berry,berries,finish(Color("b44d40")))

func _process(delta: float) -> void:
	elapsed += delta
	var draft := sin(elapsed*.64)
	for i in stars.size():
		var p := stars[i]
		# The free end near the open door stirs more than the sheltered end.
		var exposure := clampf((p.position.x+36)/16,.15,1)
		p.rotation.z = .022*sin(elapsed*1.26+i*1.9)+.052*exposure*draft
		p.rotation.y = .42*sin(elapsed*.68+i*1.32)+i*.3
