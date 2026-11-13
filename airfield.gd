extends Node3D
## Depot and runway. All coordinates use the world frame.
const PARK := Vector3(0, 2.92, 840)
const SPAWN := Vector3(-31, .2, 845)
const SUPPLIES := {1: Vector3(-32, .55, 837), 2: Vector3(-25, .55, 837)}
const LENGTH := 1200.0
const WIDTH := 52.0
var world: Node3D
var solid: StaticBody3D

func build(w: Node3D) -> void:
	world = w
	solid = StaticBody3D.new()
	solid.collision_layer = 16 | 8
	add_child(solid)
	box(Vector3(WIDTH,.1,LENGTH), Vector3(0,-.01,300), Color("25343c"))
	box(Vector3(35,.1,30),Vector3(-29,.01,840),Color("3b4750"))
	for z in range(-290,900,20):
		box(Vector3(.22,.02,8),Vector3(0,.05,z),Color("e9dfbc"),false)
		for x in [-26,26]:
			box(Vector3(.35,.18,.35),Vector3(x,.14,z),Color("87d2e8"),false,true)
	for z in [-275,875]:
		for x in [-20,-16,-12,-8,8,12,16,20]:
			box(Vector3(2,.02,14),Vector3(x,.05,z),Color("ded9bf"),false)
	# Boarding stairs belong to the airfield and stay behind when the plane departs.
	var boarding := Node3D.new()
	boarding.name = "BoardingSteps"
	add_child(boarding)
	for i in 12:
		var height := PARK.y*(i+1)/12.0
		world._box(boarding,Vector3(4.7/12,height,1.8),Vector3(-9+(i+.5)*4.7/12,height/2,PARK.z-4.8),Color("425c52"),false)
		world._box(boarding,Vector3(.035,.025,1.78),Vector3(-8.98+i*4.7/12,height+.012,PARK.z-4.8),Color("c2a157"),false)
	world._walkway_wedge(solid,1.8,Vector3(-9,0,PARK.z-4.8),Vector3(-4.3,PARK.y,PARK.z-4.8))
	# Shop room has an east-facing exit onto the flight line.
	var timber := Color("382c30")
	box(Vector3(16,.18,18),Vector3(-28,-.02,841),Color("68503a"))
	box(Vector3(.3,4.5,18),Vector3(-36,2.25,841),timber)
	for z in [832,850]:
		box(Vector3(16,4.5,.3),Vector3(-28,2.25,z),timber)
	box(Vector3(.3,4.5,2),Vector3(-20,2.25,833),timber)
	box(Vector3(.3,4.5,12),Vector3(-20,2.25,844),timber)
	box(Vector3(.3,1.3,4),Vector3(-20,3.85,836),timber)
	box(Vector3(17,.3,19),Vector3(-28,4.6,841),Color("d9e3e7"))
	for x in range(-35,-19,2):
		box(Vector3(.10,4.3,.14),Vector3(x,2.2,832.2),Color("9a7956"),false)
		box(Vector3(.14,.14,.14),Vector3(x,4.05,849.7),Color("f8c474"),false,true)
	for z in [836,841,846]:
		box(Vector3(15.7,.25,.25),Vector3(-28,4.15,z),Color("79583a"),false)
	box(Vector3(11,1.1,1.2),Vector3(-28,.55,834.4),Color("542e33"))
	box(Vector3(11.4,.12,1.5),Vector3(-28,1.16,834.4),Color("bb965a"))
	world._label3d(self,"THE NAUGHTY LIST\nQUARTERMASTER",Vector3(-28,3.6,832.5))
	world._label3d(self,"SHOP COMING SOON\nSupplies are aboard the North Star",Vector3(-33,2.6,833.2))
	world._label3d(self,"01  BOARD\n02  COLLECT SUPPLIES\n03  TAKE FLIGHT",Vector3(-35.7,2.4,844))
	world._label3d(self,"FLIGHT LINE  →",Vector3(-20,3.5,836))
	world._label3d(self,"NORTH STAR AIRFIELD",Vector3(-19.7,4.45,841))
	shopkeeper(Vector3(-28,.45,833.4))
	for x in range(-18,-8,2):
		box(Vector3(1.2,.02,.25),Vector3(x,.075,835.2),Color("e2b54e"),false)
	for pos in [Vector3(-28,3.8,835),Vector3(-26,3.8,843),Vector3(-18,4,836)]:
		lamp(pos, Color("ffc382"), 2.0, 13)
	for x in [-47,40]:
		for z in range(760,901,35):
			box(Vector3(.25,7,.25),Vector3(x,3.5,z),Color("364650"))
			box(Vector3(.8,.15,.4),Vector3(x,7,z),Color("c8e8ff"),false,true)
			lamp(Vector3(x,6.8,z),Color("9dc3df"),1.1,28)
	for i in range(24):
		var mesh := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0
		cone.bottom_radius = 2.3
		cone.height = 7
		mesh.mesh = cone
		mesh.material_override = world._mat(Color("254d42"))
		mesh.position = Vector3(-65-(i%3)*7,3.5,760+i*8)
		add_child(mesh)

func box(size: Vector3, pos: Vector3, color: Color, collision := true, glow := false) -> void:
	world._box(solid,size,pos,color,glow,solid if collision else null)

func lamp(pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)

func orb(pos: Vector3, size: Vector3, color: Color, glow := false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.position = pos
	mesh.scale = size
	mesh.material_override = world._mat(color,glow)
	add_child(mesh)

func shopkeeper(pos: Vector3) -> void:
	var skin := Color("91a776")
	orb(pos+Vector3(0,.85,0),Vector3(1.2,.9,.7),Color("18392d"))
	orb(pos+Vector3(0,1.45,0),Vector3(.35,.35,.35),skin)
	orb(pos+Vector3(0,1.7,0),Vector3(.85,.55,.7),skin)
	for side in [-1,1]:
		orb(pos+Vector3(side*.55,1,.3),Vector3(.35,.45,.55),Color("18392d"))
		orb(pos+Vector3(side*.65,1.1,.65),Vector3(.35,.17,.35),skin)
		orb(pos+Vector3(side*.48,1.75,0),Vector3(.5,.13,.18),skin)
		orb(pos+Vector3(side*.18,1.8,.33),Vector3(.18,.08,.08),Color("fc6037"),true)
		var brow: MeshInstance3D = world._box(self,Vector3(.26,.065,.08),pos+Vector3(side*.18,1.9,.32),Color("203227"))
		brow.rotation.z = side*.3
	box(Vector3(.33,.04,.08),pos+Vector3(0,1.5,.35),Color("203227"),false)
	var hat := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = .43
	cone.height = .85
	hat.mesh = cone
	hat.position = pos+Vector3(.12,2.38,0)
	hat.rotation.z = -.3
	hat.material_override = world._mat(Color("852c3b"))
	add_child(hat)
	orb(pos+Vector3(.25,2.8,0),Vector3(.2,.13,.2),Color("d6b965"))
