extends Node3D
## Generate road topology before assigning any frontage, decoration or delivery rules.
const HOUSES := [preload("res://assets/neighborhood/peppermint.glb"), preload("res://assets/neighborhood/lantern.glb"), preload("res://assets/neighborhood/gingersnap.glb"), preload("res://assets/neighborhood/bluebird.glb")]
const CARS := [preload("res://assets/neighborhood/pip.glb"), preload("res://assets/neighborhood/courier.glb"), preload("res://assets/neighborhood/sledwagon.glb")]
const DIRS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const CELL := 20.0
const STRIDE := 3
const DRIVE_X := 5.6
const DRIVE_HALF := 1.48
const ROAD := Color("#4a5260")
const CURB := Color("#a4b1b7")
const WALK := Color("#c3c7c7")
const LAWN := Color.TRANSPARENT # The continuous grass surface shows through here.
const DRIVE := Color("#89939c")
const PAINT := Color("#e1cea1")

var roads := {}
var border_neighbors := {}
var district := Vector2i.ZERO
var district_seed := 0
var car_limit := 0
var parcels := {}
var entrances := {}
var lot_queue: Array = []
var road_queue: Array = []
var ready_for_play := false
var lots: Array[Dictionary] = []
var highest_chimney := 0.0
var car_count := 0
var generation_ms := 0.0
var map_origin := Vector3.ZERO
var paint_cache := {}
var chunks := {}
var tree_groups := {}
var ground_material := StandardMaterial3D.new()
var beam_mesh := CylinderMesh.new()
var beam_materials := {}


func stream(map_seed: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map_seed, salt])
	return rng


func layout(map_seed: int, width: int, depth: int) -> void:
	var rng := stream(map_seed, 1)
	var seen := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	roads[Vector2i.ZERO] = true
	while not stack.is_empty():
		var cell := stack.back() as Vector2i
		var choices: Array[Vector2i] = []
		for step: Vector2i in DIRS:
			var next := cell + step
			if Rect2i(0, 0, width, depth).has_point(next) and not seen.has(next):
				choices.append(step)
		if choices.is_empty():
			stack.pop_back()
			continue
		var dir := choices[rng.randi_range(0, choices.size()-1)]
		connect_blocks(cell, dir)
		seen[cell + dir] = true
		stack.append(cell + dir)
	# Add loops to the spanning tree to create through routes and four-way junctions.
	for x in width:
		for z in depth:
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var cell := Vector2i(x,z)
				if seen.has(cell+dir) and rng.randf() < 0.42:
					connect_blocks(cell, dir)


func connect_blocks(cell: Vector2i, dir: Vector2i) -> void:
	for i in range(STRIDE+1):
		roads[cell*STRIDE + dir*i] = true


func center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL) + map_origin


func classify(map_seed: int, lot_id: String) -> bool:
	# Replace this temporary per-address rule when level design supplies a list.
	return stream(map_seed, lot_id.hash()).randf() < 0.7


static func span(width: int, depth: int) -> Vector2:
	# Two outer street tiles on each side plus the junction tile itself.
	return Vector2((width-1)*STRIDE+5, (depth-1)*STRIDE+5)*CELL


func add_gateway(start: Vector2i, direction: Vector2i) -> void:
	for i in range(1, 3):
		roads[start + direction*i] = true
	border_neighbors[start + direction*3] = true


func begin_build(map_seed: int, width: int, depth: int, max_houses: int, max_cars: int, coord: Vector2i) -> void:
	var start := Time.get_ticks_usec()
	district = coord
	district_seed = map_seed if coord == Vector2i.ZERO else hash([map_seed, coord])
	car_limit = max_cars
	var offset := Vector2(coord)*span(width, depth)
	position = Vector3(offset.x, 0, offset.y)
	map_origin = -Vector3(width-1,0,depth-1)*STRIDE*CELL/2
	layout(district_seed,width,depth)
	# Both sides of a border sample its west/north district's address.
	var last := Vector2i(width-1, depth-1)*STRIDE
	add_gateway(Vector2i(last.x, (hash([map_seed,coord,0]) % depth)*STRIDE), Vector2i.RIGHT)
	add_gateway(Vector2i(0, (hash([map_seed,coord+Vector2i.LEFT,0]) % depth)*STRIDE), Vector2i.LEFT)
	add_gateway(Vector2i((hash([map_seed,coord,1]) % width)*STRIDE, last.y), Vector2i.DOWN)
	add_gateway(Vector2i((hash([map_seed,coord+Vector2i.UP,1]) % width)*STRIDE, 0), Vector2i.UP)
	beam_mesh.top_radius = 0.45
	beam_mesh.bottom_radius = 0.45
	beam_mesh.height = 8
	beam_mesh.radial_segments = 8
	ground_material.vertex_color_use_as_albedo = true
	ground_material.vertex_color_is_srgb = true
	var bounds := Rect2i(-2, -2, last.x+5, last.y+5)
	for road: Vector2i in roads:
		for outward: Vector2i in DIRS:
			var side := Vector2i(-outward.y,outward.x)
			var cell := road + outward
			# Place drives only along straight, uninterrupted frontage.
			if not bounds.has_point(cell) or roads.has(cell) or parcels.has(cell) or not (roads.has(road+side) and roads.has(road-side)):
				continue
			parcels[cell] = outward
	var order := parcels.keys()
	var placement := stream(district_seed, 2)
	for i in range(order.size()-1,0,-1):
		var j := placement.randi_range(0,i)
		var first = order[i]
		order[i] = order[j]
		order[j] = first
	lot_queue = order.slice(0, mini(max_houses, order.size()))
	lot_queue.reverse()
	road_queue = roads.keys()
	generation_ms = (Time.get_ticks_usec()-start)/1000.0


func build_step(budget_usec := 0) -> void:
	var start := Time.get_ticks_usec()
	while not lot_queue.is_empty():
		var cell: Vector2i = lot_queue.pop_back()
		var outward: Vector2i = parcels[cell]
		var road := cell - outward
		if not entrances.has(road):
			entrances[road] = []
		entrances[road].append(outward)
		build_lot(cell,outward,district_seed,car_limit)
		if budget_usec > 0 and Time.get_ticks_usec()-start >= budget_usec:
			generation_ms += (Time.get_ticks_usec()-start)/1000.0
			return
	while not road_queue.is_empty():
		var road: Vector2i = road_queue.pop_back()
		pave(road,entrances.get(road,[]))
		if budget_usec > 0 and Time.get_ticks_usec()-start >= budget_usec:
			generation_ms += (Time.get_ticks_usec()-start)/1000.0
			return
	for builder: SurfaceTool in chunks.values():
		var patch := MeshInstance3D.new()
		patch.mesh = builder.commit()
		patch.material_override = ground_material
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)
	chunks.clear()
	plant_trees()
	entrances.clear()
	parcels.clear()
	ready_for_play = true
	show()
	generation_ms += (Time.get_ticks_usec()-start)/1000.0


func build_lot(cell: Vector2i, outward: Vector2i, map_seed: int, max_cars: int) -> void:
	var lot_id := "%d_%d/%d_%d" % [district.x,district.y,cell.x,cell.y]
	var rng := stream(map_seed, hash([3,cell]))
	var variant := rng.randi_range(0,HOUSES.size()-1)
	var home: Node3D = HOUSES[variant].instantiate()
	add_child(home)
	home.position = center(cell)
	home.rotation.y = atan2(-outward.x,-outward.y)
	tint(home,"Painted clapboard",rng)
	var top: Vector3 = home.find_child("Delivery",true,false).global_position
	highest_chimney = maxf(highest_chimney, top.y)
	var nice := classify(map_seed,lot_id)
	lots.append({"id":lot_id,"cell":cell,"variant":variant,"position":home.global_position,"yaw":home.rotation.y,"top":top,"nice":nice})
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	if not beam_materials.has(nice):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.2,1,0.4,0.25) if nice else Color(1,0.2,0.2,0.25)
		beam_materials[nice] = m
	beam.material_override = beam_materials[nice]
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position = top + Vector3.UP*4
	var roadward := -Vector2(outward)
	var right := Vector2(roadward.y,-roadward.x)
	var drive_center := right*DRIVE_X + roadward*4.5
	rectangle(cell,drive_center,right.abs()*DRIVE_HALF*2 + roadward.abs()*11,0.033,DRIVE)
	# Front steps join the driveway. Leave its street end clear for access.
	rectangle(cell, right*DRIVE_X/2 + roadward*5.1, right.abs()*DRIVE_X + roadward.abs()*0.95,0.036,WALK)
	rectangle(cell, roadward*4.5, right.abs()*0.95 + roadward.abs()*1.25,0.036,WALK)
	var garden := stream(map_seed,hash([4,cell]))
	var group := Vector2i(floori(cell.x/4.0),floori(cell.y/4.0))
	if not tree_groups.has(group):
		tree_groups[group] = []
	for local_z in [-6.4,6.7]:
		if garden.randf() < 0.8:
			var size := garden.randf_range(0.72,1.2)
			var location := home.transform * Vector3(-6.7+garden.randf_range(-0.55,0.55),0.04,local_z)
			tree_groups[group].append(Transform3D(Basis(Vector3.UP,garden.randf_range(0,TAU)).scaled(Vector3.ONE*size),location))
	if car_count < max_cars and rng.randf() < 0.63:
		var car: Node3D = CARS[rng.randi_range(0,CARS.size()-1)].instantiate()
		add_child(car)
		car.transform = home.transform.translated_local(Vector3(DRIVE_X,0.035,rng.randf_range(2.4,5.0)))
		tint(car,"Body paint",rng)
		car_count += 1


func plant_trees() -> void:
	# One shared mesh, one instance batch per group of neighboring lots.
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in 3:
		var radius := 1.38-tier*0.29
		var base := 0.28+tier*0.93
		var height := 2.0-tier*0.18
		for i in 7:
			var a := TAU*i/7 + tier*0.32
			var b := a+TAU/7
			var left := Vector3(cos(a)*radius,base,sin(a)*radius)
			var right := Vector3(cos(b)*radius,base,sin(b)*radius)
			var peak := Vector3(0,base+height,0)
			var lip_l := left.lerp(peak,0.22+0.08*sin(a))
			var lip_r := right.lerp(peak,0.22+0.08*sin(b))
			builder.set_normal((right-left).cross(peak-left).normalized()*-1)
			for p in [left,right,lip_r,left,lip_r,lip_l,lip_l,lip_r,peak]:
				builder.set_color(Color("#345d51") if p == left or p == right else Color("#e1eeee"))
				builder.add_vertex(p)
	var mesh := builder.commit()
	mesh.surface_set_material(0,ground_material)
	for transforms: Array in tree_groups.values():
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = mesh
		batch.instance_count = transforms.size()
		for i in transforms.size():
			batch.set_instance_transform(i,transforms[i])
		var grove := MultiMeshInstance3D.new()
		grove.multimesh = batch
		add_child(grove)
	tree_groups.clear()


func tint(model: Node3D, material_name: String, rng: RandomNumberGenerator) -> void:
	var exterior := model.find_child("Exterior",true,false) as MeshInstance3D
	var palette := [Color.WHITE,Color("#d8eaff"),Color("#ffd9b7")]
	var swatch := rng.randi_range(0,palette.size()-1)
	if swatch == 0 or not exterior:
		return
	for i in exterior.mesh.get_surface_count():
		var base := exterior.mesh.surface_get_material(i) as StandardMaterial3D
		if base and base.resource_name == material_name:
			var key := "%s_%s" % [base.get_instance_id(),swatch]
			if not paint_cache.has(key):
				var paint := base.duplicate() as StandardMaterial3D
				paint.albedo_color *= palette[swatch]
				paint_cache[key] = paint
			exterior.set_surface_override_material(i,paint_cache[key])


func pave(cell: Vector2i, entrances: Array) -> void:
	# Partition one tile into disjoint rectangles. Every road arm meets its
	# neighbor at the tile edge, including the curb and sidewalk corners.
	var cuts := [-10.0,-7.08,-5.45,-4.12,-3.85,-3.6,3.6,3.85,4.12,5.45,7.08,10.0]
	for ix in cuts.size()-1:
		var run_start := float(cuts[0])
		var run_color := Color.TRANSPARENT
		for iz in cuts.size()-1:
			var low := Vector2(cuts[ix],cuts[iz])
			var high := Vector2(cuts[ix+1],cuts[iz+1])
			var p := (low+high)*0.5
			var distance := maxf(absf(p.x),absf(p.y))
			var apron := false
			for side: Vector2i in DIRS:
				var along := p.dot(Vector2(side))
				var across := p.dot(Vector2(-side.y,side.x))
				if along > 0 and (roads.has(cell+side) or border_neighbors.has(cell+side)):
					distance = minf(distance,absf(across))
				if entrances.has(side) and along >= 3.6 and absf(across-DRIVE_X) < DRIVE_HALF:
					apron = true
			var color := LAWN
			if distance < 3.6: color = ROAD
			elif apron: color = DRIVE
			elif distance < 3.85: color = CURB
			elif distance < 5.45: color = WALK
			if iz > 0 and color != run_color:
				var size := Vector2(high.x-low.x,low.y-run_start)
				rectangle(cell,Vector2(p.x,run_start+size.y/2),size,paving_height(run_color),run_color)
				run_start = low.y
			run_color = color
			if iz == cuts.size()-2:
				var size := Vector2(high.x-low.x,high.y-run_start)
				rectangle(cell,Vector2(p.x,run_start+size.y/2),size,paving_height(color),color)
	# Painted dashes stop before junctions.
	for dir: Vector2i in DIRS:
		if roads.has(cell+dir) or border_neighbors.has(cell+dir):
			var axis := Vector2(dir).abs()
			rectangle(cell,Vector2(dir)*7.1,axis*2.3+(Vector2.ONE-axis)*0.15,0.045,PAINT)


func paving_height(color: Color) -> float:
	return 0.105 if color == WALK or color == CURB else 0.033


func rectangle(cell: Vector2i, offset: Vector2, size: Vector2, y: float, color: Color) -> void:
	if color == LAWN:
		return
	var chunk := Vector2i(floori(cell.x/4.0),floori(cell.y/4.0))
	if not chunks.has(chunk):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		chunks[chunk] = builder
	var builder: SurfaceTool = chunks[chunk]
	var middle := center(cell)+Vector3(offset.x,y,offset.y)
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
		builder.set_color(color)
		builder.set_normal(Vector3.UP)
		builder.add_vertex(middle+Vector3(corner.x*size.x,0,corner.y*size.y)*0.5)
