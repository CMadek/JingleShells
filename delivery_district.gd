extends Node3D
## All district geometry is built from this manifest; the navigator reads the same positions.
var route_seed: int
var sites: Array[Dictionary] = []
var roads: Array[PackedVector3Array] = []
var landmarks := {}
var groves := PackedVector3Array()
var bounds := Rect2()
var town: String
const WALLS := [Color("ccad89"), Color("a96958"), Color("819ca7"), Color("d6c5ae")]

func generate(value: int) -> void:
	route_seed = value
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var origin := Vector3(rng.randf_range(-300, 300), 0, rng.randf_range(-1060, -800))
	var bearing := rng.randf_range(-.48, .48)
	var blocks := rng.randi_range(4, 6)
	var depth := rng.randi_range(6, 9)
	var spacing := rng.randf_range(39, 47)
	town = ["Bramblewick","Bellweather","Starling Hollow","Tallowmere","Winterfold"][rng.randi_range(0,4)]
	bounds = Rect2(Vector2(origin.x, origin.z), Vector2.ZERO)
	for col in range(-blocks, blocks + 1):
		var street := PackedVector3Array()
		var bend := rng.randf_range(-10, 10)
		for row in range(-depth, depth + 1):
			var local := Vector3(col * spacing + bend * cos(row * .38), 0, row * 25)
			var junction := origin + local.rotated(Vector3.UP, bearing)
			street.append(junction)
			if row in [-depth+1,0,depth-1]: continue
			for side in [-1, 1]:
				if rng.randf() < .45: continue
				var base := junction + Vector3(side * rng.randf_range(10, 14), 0, rng.randf_range(-3, 3)).rotated(Vector3.UP, bearing)
				sites.append({"base":base, "color":WALLS[rng.randi_range(0, WALLS.size()-1)], "nice":rng.randf() < .7})
				bounds = bounds.expand(Vector2(base.x, base.z))
		roads.append(street)
	for row in [-depth + 1, 0, depth - 1]:
		var cross_street := PackedVector3Array()
		for col in range(blocks * 2 + 1):
			cross_street.append(roads[col][row + depth])
		roads.append(cross_street)
	landmarks["Relay light"] = origin + Vector3(blocks * spacing + 40, 0, depth * 25 + 32).rotated(Vector3.UP, bearing)
	landmarks["Frostmere"] = origin + Vector3(-blocks * spacing - 70, 0, 0).rotated(Vector3.UP, bearing)
	for point: Vector3 in landmarks.values():
		bounds = bounds.expand(Vector2(point.x, point.z))
	bounds = bounds.grow(40)
	# Sight references beside the approach, clear of the runway, depot and district.
	for z in range(725,ceili(bounds.end.y)+55,-73):
		var side := 1 if groves.size() % 2 == 0 else -1
		groves.append(Vector3(side * rng.randf_range(52,110),0,z + rng.randf_range(-12,12)))

func _build_groves(w: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = route_seed
	var leaves: Array[Transform3D] = []
	var snow: Array[Transform3D] = []
	var body := StaticBody3D.new()
	add_child(body)
	var crown := ConvexPolygonShape3D.new()
	var points := PackedVector3Array([Vector3.UP])
	for j in 8:
		points.append(Vector3(.25*cos(TAU*j/8),0,.25*sin(TAU*j/8)))
	crown.points = points
	for grove in groves:
		for tree in rng.randi_range(6,11):
			var base := grove + Vector3(rng.randf_range(-15,15),0,rng.randf_range(-22,22))
			var height := rng.randf_range(6,13)
			for tier in 3:
				var radius := height * (.26 - tier*.05)
				var basis := Basis.IDENTITY.scaled(Vector3(radius,height*.52,radius))
				var center := base + Vector3.UP * height * (.27 + tier*.22)
				leaves.append(Transform3D(basis,center))
				snow.append(Transform3D(basis.scaled(Vector3.ONE*.79),center+Vector3.UP*height*.08))
			var trunk := CollisionShape3D.new()
			trunk.shape = crown
			trunk.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*height),base)
			body.add_child(trunk)
	preload("res://assets/materials/fir_batch.gd").add_tiers(self,leaves,w._mat(Color("284f49")))
	preload("res://assets/materials/fir_batch.gd").add_tiers(self,snow,w._mat(Color("aec4cb")))

func build(w: Node3D) -> void:
	_build_groves(w)
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
	pond.position = landmarks["Frostmere"]
	pond.material_override = w._mat(Color("729ca8"))
	add_child(pond)
	var beacon: Vector3 = landmarks["Relay light"]
	for side in [-1, 1]:
		var leg: MeshInstance3D = w._box(self, Vector3(.65, 18, .65), beacon+Vector3(side*1.9, 9, 0), Color("71544d"))
		leg.rotation.z = side * .12
	for h in [3, 8, 13, 17]:
		w._box(self, Vector3(5.4-h*.2,.25,.6), beacon+Vector3.UP*h, Color("51585a"))
	w._box(self,Vector3(1.2,1.3,1.2),beacon+Vector3.UP*18.5,Color("ffc58b"),true)
	for site in sites:
		w._make_house(site.base, site.color, site.nice)
