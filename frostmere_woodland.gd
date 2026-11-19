extends RefCounted
## World X/Z outlines feed both the chart and the scenery. Tree instances are
## grouped by location so a view of the first wood does not draw the second.
const CELL := 224.0
const TREE_SPACING := 15
const DETAIL_RANGE := 360.0
var woods: Array[PackedVector2Array] = []
var shore := PackedVector2Array()
var lake_center := Vector2.ZERO
var seed_value: int

func generate(value: int, origin: Vector3, town: Vector3) -> void:
	seed_value = value
	var start := Vector2(origin.x, origin.z)
	var end := Vector2(town.x, town.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = value ^ 0x1ce
	lake_center = start.lerp(end,.50) + Vector2(rng.randf_range(-36,36),0)
	shore = outline(lake_center,Vector2(280,245),rng)
	woods = [outline(start.lerp(end,.365),Vector2(330,405),rng),
			outline(start.lerp(end,.695),Vector2(355,685),rng)]

func outline(center: Vector2, radii: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var phase := rng.randf_range(0,TAU)
	for i in 64:
		var a := TAU*i/64
		var r := 1.0 + .13*sin(3*a+phase) + .065*sin(5*a-phase) + .035*cos(8*a+phase)
		points.append(center + Vector2.from_angle(a)*radii*r)
	return points

func in_route_scenery(p: Vector3) -> bool:
	var xz := Vector2(p.x,p.z)
	if Geometry2D.is_point_in_polygon(xz,shore): return true
	for wood in woods:
		if Geometry2D.is_point_in_polygon(xz,wood): return true
	return false

func build(parent: Node3D, collidable_bases: PackedVector3Array, valley: RefCounted, town: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0xf17
	var chunks := {}
	var body := StaticBody3D.new()
	parent.add_child(body)
	var crown := ConvexPolygonShape3D.new()
	var points := PackedVector3Array([Vector3.UP])
	for i in 8:
		points.append(Vector3(.25*cos(TAU*i/8),0,.25*sin(TAU*i/8)))
	crown.points = points
	for base in collidable_bases:
		var size := rng.randf_range(6,13)
		plant(chunks,base,size,rng)
		var collision := CollisionShape3D.new()
		collision.shape = crown
		collision.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),base)
		body.add_child(collision)
	for wood in woods:
		var area := Rect2(wood[0],Vector2.ZERO)
		for point in wood: area = area.expand(point)
		for z in range(floori(area.position.y),ceili(area.end.y),TREE_SPACING):
			for x in range(floori(area.position.x),ceili(area.end.x),TREE_SPACING):
				var p := Vector2(x+rng.randf_range(-5,5),z+rng.randf_range(-5,5))
				if not Geometry2D.is_point_in_polygon(p,wood) or Geometry2D.is_point_in_polygon(p,shore): continue
				if p.x < -200 and valley.track_clearance(p) < 10: continue
				# Small clearings break up the canopy when seen from the cockpit.
				if sin(p.x*.022)+cos(p.y*.027)+.5*sin((p.x+p.y)*.051) > 1.50: continue
				plant(chunks,Vector3(p.x,0,p.y),rng.randf_range(10,21),rng)
	valley.plant_outlying_groves(self,chunks,town)
	var detailed := fir_mesh(7,3)
	var distant := fir_mesh(4,2)
	for key: Vector2i in chunks:
		var origin := Vector3(key.x*CELL,0,key.y*CELL)
		make_patch(parent,chunks[key],origin,detailed,false)
		make_patch(parent,chunks[key],origin,distant,true)
	build_ice(parent)

func make_patch(parent: Node3D, transforms: Array, origin: Vector3, mesh: Mesh, distant: bool) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in transforms.size(): batch.set_instance_transform(i,transforms[i])
	var patch := MultiMeshInstance3D.new()
	patch.multimesh = batch
	patch.position = origin
	if distant:
		patch.visibility_range_begin = DETAIL_RANGE
		patch.visibility_range_end = 1900
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		patch.visibility_range_end = DETAIL_RANGE
	parent.add_child(patch)

func plant(chunks: Dictionary, base: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var key := Vector2i(floori(base.x/CELL),floori(base.z/CELL))
	if not chunks.has(key): chunks[key] = []
	var width := height*rng.randf_range(.86,1.16)
	var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled_local(Vector3(width,height,width))
	chunks[key].append(Transform3D(basis,base-Vector3(key.x*CELL,0,key.y*CELL)))

func fir_mesh(sides: int, tiers: int) -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	s.set_material(mat)
	var green := Color("254e46").srgb_to_linear()
	var snow := Color("dae7e8").srgb_to_linear()
	for tier in tiers:
		var fraction := float(tier)/(tiers-1)
		var bottom := .055+.47*fraction
		var radius := .31-.14*fraction
		var peak := Vector3.UP*(bottom+.475)
		for i in sides:
			var a := TAU*i/sides+tier*.31
			var b := a+TAU/sides
			var left := Vector3(cos(a)*radius,bottom,sin(a)*radius)
			var right := Vector3(cos(b)*radius,bottom,sin(b)*radius)
			var normal := (peak-left).cross(right-left).normalized()
			for p in [left,right,peak]:
				s.set_normal(normal)
				s.set_color(snow if p == peak else green)
				s.add_vertex(p)
	s.index()
	return s.commit()

func build_ice(parent: Node3D) -> void:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/materials/frozen_lake.gdshader")
	s.set_material(mat)
	for i in shore.size():
		# UV.x measures distance from the center to the irregular shore.
		for vertex: Vector2 in [lake_center,shore[i],shore[(i+1)%shore.size()]]:
			s.set_uv(Vector2(0 if vertex == lake_center else 1,0))
			s.add_vertex(Vector3(vertex.x-lake_center.x,0,vertex.y-lake_center.y))
	var ice := MeshInstance3D.new()
	ice.mesh = s.commit()
	ice.position = Vector3(lake_center.x,.12,lake_center.y)
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ice)
