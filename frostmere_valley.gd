extends RefCounted
## The survey, scenery and flight floor use the same seeded valley.
const GRID := 80
const CORNER := Vector2i(-6080, -9040)
const GRID_SIZE := Vector2i(153, 190)
const Ground := preload("res://assets/materials/snow.gdshader")
var heights := PackedFloat32Array()
var river := PackedVector2Array()
var rail := PackedVector2Array()
var survey := {}
var seed_value: int
var phase: float
var west_offset: float
var town_z: float

func generate(value: int, start: Vector3, town: Vector3, town_bounds: Rect2, shoreline: PackedVector2Array) -> void:
	seed_value = value
	# Even the easternmost river bend (-815+139+78) must leave room for the rail line.
	west_offset = minf(0,town_bounds.position.x-275-(-598))
	town_z = town.z
	var rng := RandomNumberGenerator.new()
	rng.seed = value ^ 0x79ab
	phase = rng.randf_range(0, TAU)
	for z in range(-5520, 2161, 60):
		river.append(Vector2(river_x(z), z))
	var crossing := roundf(start.lerp(town, .31).z / 60) * 60
	survey["Trestle Crossing"] = Vector3(river_x(crossing), 0, crossing)
	survey["East Fold Farm"] = Vector3(rng.randf_range(350, 470), 0, start.lerp(town, .085).z)
	survey["North Tank"] = Vector3(town.x + 665, 0, town.z + 335)
	var bridge := Vector2(river_x(crossing),crossing)
	# Westbound track climbs into the pass. On the east bank it runs north
	# parallel to the water, ending in a siding outside the delivery district.
	for offset in [Vector2(-1140,460),Vector2(-830,402),Vector2(-610,238),Vector2(-448,91),Vector2(-310,19),Vector2(-172,0),Vector2(172,0),Vector2(246,-16),Vector2(303,-67),Vector2(338,-158)]:
		rail.append(bridge+offset)
	var lake := Rect2(shoreline[0],Vector2.ZERO)
	for p in shoreline: lake = lake.expand(p)
	for z in range(int(crossing)-300,int(town.z)-131,-85):
		var x := river_x(z)+217
		var distance_to_lake := maxf(lake.position.y-z,z-lake.end.y)
		x = lerpf(minf(x,lake.position.x-22),x,smoothstep(85,240,distance_to_lake))
		rail.append(Vector2(x,z))

func track_clearance(p: Vector2) -> float:
	var closest := INF
	for i in range(1,rail.size()):
		if p.y < minf(rail[i-1].y,rail[i].y)-10 or p.y > maxf(rail[i-1].y,rail[i].y)+10: continue
		closest = minf(closest,p.distance_to(Geometry2D.get_closest_point_to_segment(p,rail[i-1],rail[i])))
	return closest

func river_x(z: float) -> float:
	var bend := -815 + 139 * sin(z * .0027 + phase) + 78 * sin(z * .0061 - phase)
	return bend + west_offset * (1.0-smoothstep(410,950,absf(z-town_z)))

func bank_width(z: float) -> float:
	return 28 + 8 * sin(z * .004 + phase)

func build_ground(parent: Node3D) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = .00095
	noise.fractal_octaves = 4
	heights.resize(GRID_SIZE.x * GRID_SIZE.y)
	for row in GRID_SIZE.y:
		for col in GRID_SIZE.x:
			var x := float(CORNER.x + col * GRID)
			var z := float(CORNER.y + row * GRID)
			# Flat valley floor preserves the runway, lake, streets and drop heights.
			var side := absf(x) - 1120
			if x < 0: side += west_offset * (1.0-smoothstep(410,950,absf(z-town_z)))
			var end := maxf(z - 1210, -4830 - z)
			var rise := maxf(side, end)
			var foothills := smoothstep(0, 850, rise)
			var ridge := exp(-pow((rise - 1130 - 185 * sin((z+x) * .0021 + phase)) / 580, 2))
			var relief := noise.get_noise_2d(x, z)
			heights[row * GRID_SIZE.x + col] = foothills * maxf(0,185 + 315 * ridge + 265 * relief + 120 * absf(noise.get_noise_2d(z*1.8, x*1.8)))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := ShaderMaterial.new()
	material.shader = Ground
	surface.set_material(material)
	var raised_faces := PackedVector3Array()
	for row in GRID_SIZE.y:
		for col in GRID_SIZE.x:
			var i := row * GRID_SIZE.x + col
			var east := heights[i+1] if col+1 < GRID_SIZE.x else heights[i]
			var west := heights[i-1] if col > 0 else heights[i]
			var south := heights[i+GRID_SIZE.x] if row+1 < GRID_SIZE.y else heights[i]
			var north := heights[i-GRID_SIZE.x] if row > 0 else heights[i]
			surface.set_normal(Vector3(west-east, 2.0*GRID, north-south).normalized())
			surface.add_vertex(grid_vertex(i))
			if col+1 == GRID_SIZE.x or row+1 == GRID_SIZE.y: continue
			var corner := grid_vertex(i)
			var solid := absf(corner.x)<3200 and corner.z > -6200 and corner.z < 3200 and maxf(maxf(heights[i],east),maxf(south,heights[i+GRID_SIZE.x+1])) > 0
			for index in [i, i+1, i+GRID_SIZE.x, i+1, i+GRID_SIZE.x+1, i+GRID_SIZE.x]:
				surface.add_index(index)
				if solid:
					raised_faces.append(grid_vertex(index))
	var ground := MeshInstance3D.new()
	ground.name = "ValleyFloor"
	ground.mesh = surface.commit()
	parent.add_child(ground)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(raised_faces)
	collision.shape = shape
	body.add_child(collision)
	ground.add_child(body)

func grid_vertex(i: int) -> Vector3:
	return Vector3(CORNER.x + (i % GRID_SIZE.x)*GRID, heights[i], CORNER.y + floori(float(i)/GRID_SIZE.x)*GRID)

func elevation(x: float, z: float) -> float:
	if heights.is_empty(): return 0
	var uv := (Vector2(x,z) - Vector2(CORNER)) / GRID
	var cell := Vector2i(uv.floor())
	if cell.x < 0 or cell.y < 0 or cell.x+1 >= GRID_SIZE.x or cell.y+1 >= GRID_SIZE.y: return 0
	var i := cell.y * GRID_SIZE.x + cell.x
	var tx := uv.x - cell.x
	var tz := uv.y - cell.y
	var b := heights[i+1]
	var c := heights[i+GRID_SIZE.x]
	if tx + tz <= 1:
		return heights[i]*(1-tx-tz) + b*tx + c*tz
	return b*(1-tz) + c*(1-tx) + heights[i+GRID_SIZE.x+1]*(tx+tz-1)

func build_river(parent: Node3D) -> void:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ice := ShaderMaterial.new()
	ice.shader = preload("res://assets/materials/frozen_lake.gdshader")
	s.set_material(ice)
	for i in river.size():
		var p := river[i]
		for side in [-1, 0, 1]:
			s.set_uv(Vector2(absf(side), 0))
			s.add_vertex(Vector3(p.x + side * bank_width(p.y), .10, p.y))
		if i+1 < river.size():
			for col in 2:
				var k := i*3+col
				for index in [k,k+1,k+3,k+1,k+4,k+3]: s.add_index(index)
	var channel := MeshInstance3D.new()
	channel.name = "WestFork"
	channel.mesh = s.commit()
	channel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(channel)

func build_rail(parent: Node3D) -> void:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	s.set_material(mat)
	var crossing: Vector3 = survey["Trestle Crossing"]
	for i in range(1,rail.size()):
		var a := rail[i-1]
		var b := rail[i]
		if a.y == crossing.z and b.y == crossing.z:
			# The raised track and railcars belong to the trestle mesh.
			for sign_x in [-1,1]:
				var end := Vector2(crossing.x+sign_x*150,crossing.z)
				track_segment(s,end,Vector2(crossing.x+sign_x*172,crossing.z))
			continue
		var steps := ceili(a.distance_to(b)/20)
		for j in steps:
			track_segment(s,a.lerp(b,float(j)/steps),a.lerp(b,float(j+1)/steps))
	var bed := MeshInstance3D.new()
	bed.name = "FreightLine"
	bed.mesh = s.commit()
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bed)

func track_segment(s: SurfaceTool,a: Vector2,b: Vector2) -> void:
	var side := (b-a).normalized().orthogonal()
	for strip in [Vector2(-4,4),Vector2(-2.25,-1.95),Vector2(1.95,2.25)]:
		var outer: bool = strip.x == -4
		var color := Color("#828c91") if outer else Color("#475259")
		for p in [a+side*strip.x,b+side*strip.x,a+side*strip.y,a+side*strip.y,b+side*strip.x,b+side*strip.y]:
			s.set_color(color.srgb_to_linear())
			s.set_normal(Vector3.UP)
			s.add_vertex(Vector3(p.x,elevation(p.x,p.y)+(.16 if outer else .25),p.y))

func plant_outlying_groves(woodland: RefCounted, chunks: Dictionary, town: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x53fc
	var protected_town := town.grow(52)
	for z in range(-5620, 2750, 370):
		for side in [-1,1]:
			for band in [385, 825, 1400, 2020, 2670]:
				var center := Vector2(side*(band+rng.randf_range(-140,140)), z+rng.randf_range(-136,136))
				var spread := Vector2(rng.randf_range(29,85), rng.randf_range(52,132))
				var angle := rng.randf_range(-.8,.8)
				for j in rng.randi_range(18,44):
					var p := center + (Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*spread).rotated(angle)
					if protected_town.has_point(p) or absf(p.x-river_x(p.y)) < bank_width(p.y)+14 or (p.x<0 and track_clearance(p)<10): continue
					# Buildings, fields and the trestle approach need open ground.
					var reserved := false
					for site: Vector3 in survey.values():
						if absf(p.x-site.x)<176 and absf(p.y-site.z)<157:
							reserved = true
							break
					if reserved: continue
					var base := Vector3(p.x,elevation(p.x,p.y),p.y)
					if absf(p.x)<540 and woodland.in_route_scenery(base): continue
					woodland.plant(chunks,base,rng.randf_range(10,24),rng)
