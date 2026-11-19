extends Node3D
## All district geometry is built from this manifest; the navigator reads the same positions.
var route_seed: int
var sites: Array[Dictionary] = []
var roads: Array[PackedVector3Array] = []
var landmarks := {}
var groves := PackedVector3Array()
var woodland := preload("res://frostmere_woodland.gd").new()
var valley := preload("res://frostmere_valley.gd").new()
var garden_firs := PackedVector3Array()
var bounds := Rect2()
var town: String
var stops := PackedInt32Array()
var placards: Array[Label3D] = []
const Contract := preload("res://frostmere.gd")
const Cargo := preload("res://cargo.gd")
const Airfield := preload("res://airfield.gd")
# Northbound distance from the parked aircraft to the center of town, in metres.
const OUTBOUND_METRES := Vector2(4600, 5000)
var bearing: float
const WALLS := [Color("ccad89"), Color("a96958"), Color("819ca7"), Color("d6c5ae")]

func generate(value: int) -> void:
	route_seed = value
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var origin := Vector3(rng.randf_range(-300, 300), 0, Airfield.PARK.z - rng.randf_range(OUTBOUND_METRES.x, OUTBOUND_METRES.y))
	bearing = rng.randf_range(-.48, .48)
	var blocks := rng.randi_range(4, 6)
	var depth := rng.randi_range(6, 9)
	var spacing := rng.randf_range(39, 47)
	town = "Frostmere"
	bounds = Rect2(Vector2(origin.x, origin.z), Vector2.ZERO)
	var lots: Array[Rect2] = []
	for col in range(-blocks, blocks + 1):
		var street := PackedVector3Array()
		var bend := rng.randf_range(-10, 10)
		for row in range(-depth, depth + 1):
			var local := Vector3(col * spacing + bend * cos(row * .38), 0, row * 25)
			var junction := origin + local.rotated(Vector3.UP, bearing)
			street.append(junction)
			if row in [-depth+1,0,depth-1]: continue
			for side in [-1, 1]:
				if rng.randf() < .45:
					var yard := junction + Vector3(side*11,0,2.0*sin(col+row)).rotated(Vector3.UP,bearing)
					garden_firs.append(yard)
					continue
				var base := junction + Vector3(side * rng.randf_range(10, 14), 0, rng.randf_range(-3, 3)).rotated(Vector3.UP, bearing)
				var style := 0 if col < -blocks*.33 else (2 if col > blocks*.33 else 1)
				var candidate := {"base":base, "style":style, "variant":rng.randi_range(0,1), "yaw":bearing-side*PI*.5, "color":WALLS[rng.randi_range(0, WALLS.size()-1)], "nice":rng.randf() < .7}
				# All houses face across their street. Reserve the entire lot in
				# street coordinates, including eaves, porch, path and lamp.
				var local_base := (base-origin).rotated(Vector3.UP,-bearing)
				var lot := Rect2(local_base.x - (11.0 if side == 1 else 4.2),local_base.z-4.8,15.2,9.6).grow(1.0)
				if lots.any(func(occupied: Rect2): return occupied.intersects(lot)): continue
				lots.append(lot)
				sites.append(candidate)
				bounds = bounds.expand(Vector2(base.x, base.z))
		roads.append(street)
	var gardens := PackedVector3Array()
	for tree in garden_firs:
		var local_tree := (tree-origin).rotated(Vector3.UP,-bearing)
		if not lots.any(func(lot: Rect2): return lot.grow(3.8).has_point(Vector2(local_tree.x,local_tree.z))):
			gardens.append(tree)
	garden_firs = gardens
	woodland.generate(value, Airfield.PARK, origin)
	for row in [-depth + 1, 0, depth - 1]:
		var cross_street := PackedVector3Array()
		for col in range(blocks * 2 + 1):
			cross_street.append(roads[col][row + depth])
		roads.append(cross_street)
	landmarks["Relay light"] = origin + Vector3(blocks * spacing + 40, 0, depth * 25 + 32).rotated(Vector3.UP, bearing)
	landmarks["Lantern Quay"] = origin + Vector3(-blocks * spacing - 70, 0, 0).rotated(Vector3.UP, bearing)
	landmarks["Bell Square"] = roads[blocks][depth] + Vector3(8,0,8).rotated(Vector3.UP,bearing)
	landmarks["Saw Works"] = origin + Vector3(blocks*spacing+42,0,-depth*9).rotated(Vector3.UP,bearing)
	# Sample distinct existing roofs in three neighbourhoods, in the chart's frame.
	for offset in [Vector2(-.96,.75),Vector2(-.92,-.25),Vector2(-.20,.38),Vector2(.12,-.35),Vector2(.88,.28),Vector2(.90,-.72)]:
		var target: Vector3 = origin + Vector3(offset.x*blocks*spacing,0,offset.y*depth*25).rotated(Vector3.UP,bearing)
		var nearest := -1
		var distance := INF
		for i in sites.size():
			var d: float = sites[i].base.distance_squared_to(target)
			if d < distance and not stops.has(i):
				nearest = i
				distance = d
		stops.append(nearest)
		sites[nearest].nice = Contract.ORDERS[stops.size()-1] == Cargo.Kind.PRESENT
	for point: Vector3 in landmarks.values():
		bounds = bounds.expand(Vector2(point.x, point.z))
	bounds = bounds.grow(40)
	valley.generate(value, Airfield.PARK, origin, bounds, woodland.shore)
	# Sight references beside the approach, clear of the runway, depot and district.
	for z in range(725,ceili(bounds.end.y)+55,-73):
		var side := 1 if ((725-z)/73) % 2 == 0 else -1
		var grove := Vector3(side * rng.randf_range(52,110),0,z + rng.randf_range(-12,12))
		if not woodland.in_route_scenery(grove): groves.append(grove)
	# Windbreaks outside the last streets frame the neighborhoods from the air.
	for col in range(-blocks,blocks+1):
		for side in [-1,1]:
			groves.append(origin + Vector3(col*spacing,0,side*(depth*25+43)).rotated(Vector3.UP,bearing))

func build(w: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = route_seed
	var tree_bases := PackedVector3Array()
	for grove in groves:
		for tree in rng.randi_range(6,11):
			var p := grove + Vector3(rng.randf_range(-15,15),0,rng.randf_range(-22,22))
			if not woodland.in_route_scenery(p): tree_bases.append(p)
	tree_bases.append_array(garden_firs)
	valley.build_ground(self)
	valley.build_river(self)
	valley.build_rail(self)
	preload("res://frostmere_outposts.gd").new().build(self,valley.survey)
	woodland.build(self,tree_bases,valley,bounds)
	# Merge road ribbons into one surface, just above the existing level snow.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for street in roads:
		for i in range(1, street.size()):
			var a := street[i-1] + Vector3.UP * .022
			var b := street[i] + Vector3.UP * .022
			var edge := (b-a).normalized().cross(Vector3.UP) * 2.3
			for vertex: Vector3 in [a-edge, b-edge, a+edge, a+edge, b-edge, b+edge]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(vertex)
	var strips := MeshInstance3D.new()
	strips.mesh = surface.commit()
	var road_material: StandardMaterial3D = w._mat(Color("81929c")).duplicate()
	road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	strips.material_override = road_material
	add_child(strips)
	var pond := MeshInstance3D.new()
	var ice := CylinderMesh.new()
	ice.height = .08
	ice.top_radius = 32
	ice.bottom_radius = 32
	pond.mesh = ice
	pond.scale.z = .65
	pond.position = landmarks["Lantern Quay"]
	pond.rotation.y = bearing
	pond.material_override = w._mat(Color("729ca8"))
	add_child(pond)
	var beacon: Vector3 = landmarks["Relay light"]
	for side in [-1, 1]:
		var leg: MeshInstance3D = w._box(self, Vector3(.65, 18, .65), beacon+Vector3(side*1.9, 9, 0), Color("71544d"))
		leg.rotation.z = side * .12
	for h in [3, 8, 13, 17]:
		w._box(self, Vector3(5.4-h*.2,.25,.6), beacon+Vector3.UP*h, Color("51585a"))
	w._box(self,Vector3(1.2,1.3,1.2),beacon+Vector3.UP*18.5,Color("ffc58b"),true)
	preload("res://frostmere_landmarks.gd").build(w,self)
	var kits := []
	for style in 3:
		for variant in 2:
			kits.append(preload("res://frostmere_houses.gd").new().build(style,variant))
	for i in sites.size():
		var site := sites[i]
		w._make_house(site, kits[site.style*2+site.variant], stops.has(i))
	for i in stops.size():
		var root: Node3D = w.recipients.houses[stops[i]].root
		var sign := Label3D.new()
		sign.text = "%02d   %s" % [i+1, w.contract.ADDRESSES[i]]
		sign.position = Vector3(0,11,0)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.font_size = 48
		sign.pixel_size = .021
		sign.modulate = Color("ffe5a4")
		root.add_child(sign)
		placards.append(sign)
		dress_address(w,root,i)
	w.contract.refresh()

func dress_address(w: Node3D, house: Node3D, index: int) -> void:
	var timber := Color("865639")
	var spruce := Color("31574c")
	var ivory := Color("eee0bd")
	match index:
		0: # Waterside landing with a pair of mooring posts.
			for plank in 7:
				w._box(house,Vector3(3.1,.18,.51),Vector3(-1,.4,4.0+plank*.54),timber)
			for x in [-2.6,.6]: w._box(house,Vector3(.29,1.4,.29),Vector3(x,.7,7.3),timber)
		1: # Nets drying on a bright frame beside the cottage.
			for x in [-2.5,2.5]: w._box(house,Vector3(.24,3,.24),Vector3(x,1.5,5.3),spruce)
			for strand in 11: w._box(house,Vector3(.055,1.9,.055),Vector3(-2.5+strand*.5,1.95,5.3),ivory)
			for row in 5: w._box(house,Vector3(5,.055,.055),Vector3(0,1.1+row*.44,5.3),ivory)
		2:
			w._box(house,Vector3(2.5,2.5,.25),Vector3(0,3.4,3.6),ivory)
			w._box(house,Vector3(.12,.85,.12),Vector3(0,3.8,3.78),spruce)
			w._box(house,Vector3(.75,.13,.12),Vector3(.33,3.4,3.78),spruce)
		3:
			for stripe in 9:
				var awning: MeshInstance3D = w._box(house,Vector3(.8,.2,2.2),Vector3((stripe-4)*.8,3,4.3),ivory if stripe%2 else Color("ae3c3f"))
				awning.rotation.x = .22
		4:
			for log_index in 5:
				var log_mesh := CylinderMesh.new()
				log_mesh.top_radius = .48
				log_mesh.bottom_radius = .48
				log_mesh.height = 5
				var log_piece := MeshInstance3D.new()
				log_piece.mesh = log_mesh
				log_piece.material_override = w._mat(timber)
				log_piece.rotation.z = PI*.5
				log_piece.position = Vector3(0,.48 if log_index<3 else 1.3,4.2+log_index%3+.5*floori(log_index/3.0))
				house.add_child(log_piece)
		5:
			for x in [-3,-1,1,3]:
				w._box(house,Vector3(1.3,1.05,.09),Vector3(x,3.8,3.6),Color("ffc678"),true)
				w._box(house,Vector3(.09,1.05,.15),Vector3(x,3.8,3.65),spruce)
