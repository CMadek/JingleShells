extends RefCounted
## Reuse each streetscape kit across its neighborhood. Each kit is two surfaces:
## painted joinery and illuminated windows. Both disappear with the house.
const SNOW := Color("#e5eff3")
const CREAM := Color("#ead8b4")
const WOOD := Color("#62443c")
const SPRUCE := Color("#34564f")
const BRICK := Color("#874e48")
const GLASS := Color("#ffcc80")
var box := BoxMesh.new()
var gable := PrismMesh.new()
var paint := SurfaceTool.new()
var light := SurfaceTool.new()

func part(size: Vector3, pos: Vector3, color: Color, roll := 0.0, shape: PrimitiveMesh = null, pitch := 0.0) -> void:
	var transform := Transform3D((Basis(Vector3.BACK,roll)*Basis(Vector3.RIGHT,pitch)).scaled_local(size),pos)
	var surface := light if color == GLASS else paint
	var source := shape if shape else box
	var arrays := source.get_mesh_arrays()
	for i in arrays[Mesh.ARRAY_INDEX]:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal((transform.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
		surface.add_vertex(transform*arrays[Mesh.ARRAY_VERTEX][i])

func window(x: float, y: float, width: float, z: float = 3.56) -> void:
	var outward := signf(z)
	part(Vector3(width+.23,1.57,.13),Vector3(x,y,z),CREAM)
	part(Vector3(width,1.31,.15),Vector3(x,y,z+outward*.044),GLASS)
	part(Vector3(.09,1.35,.06),Vector3(x,y,z+outward*.14),WOOD)
	part(Vector3(width,.09,.06),Vector3(x,y,z+outward*.14),WOOD)
	part(Vector3(width+.38,.15,.30),Vector3(x,y-.78,z+outward*.04),SNOW)

func build(style: int, variant: int) -> ArrayMesh:
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	light.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	paint.set_material(mat)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	light.set_material(glow)
	var trim: Color = [SPRUCE,BRICK,WOOD][style]
	for side in [-1,1]:
		part(Vector3(5.22,.20,8.03),Vector3(side*2.24,6.39,0),SNOW,-side*atan2(2.5,4.5))
		part(Vector3(.21,.34,8.05),Vector3(side*4.48,4.99,0),trim)
		part(Vector3(.22,4.96,.22),Vector3(side*3.95,2.50,3.52),CREAM)
		window(side*2.48,2.56,1.45 if style != 1 else 2.04)
		window(side*2.18,2.66,1.42,-3.56)
		var sx: float = side*4.04
		for z in [-1.68,1.68]:
			part(Vector3(.08,1.45,1.18),Vector3(sx,2.80,z),GLASS)
			part(Vector3(.14,1.48,.10),Vector3(sx,2.80,z),trim)
	part(Vector3(1.22,2.42,.14),Vector3(0,1.23,3.55),trim)
	part(Vector3(.63,.62,.09),Vector3(0,1.75,3.66),GLASS)
	part(Vector3(2.0,.28,.84),Vector3(0,.14,3.90),CREAM)
	part(Vector3(1.48,.28,1.48),Vector3(2.2,7.38,1.0),BRICK)
	part(Vector3(.90,.04,.90),Vector3(2.2,7.53,1.0),WOOD)
	match style:
		0: # Harbor cottages have deep covered porches and painted shutters.
			part(Vector3(7.65,.23,2.18),Vector3(0,2.99,4.36),SNOW,0,null,.13)
			for x in [-3.45,3.45]:
				part(Vector3(.20,2.82,.20),Vector3(x,1.41,5.2),SPRUCE)
			for x in [-3.52,-1.45,1.45,3.52]:
				part(Vector3(.39,1.50,.15),Vector3(x,2.54,3.60),SPRUCE)
		1: # Market street has striped canopies and high stepped shop gables.
			for i in 11:
				part(Vector3(.68,.18,1.50),Vector3((i-5)*.68,3.63,4.14),CREAM if i%2 else trim,0,null,.22)
			for i in 3:
				part(Vector3(6.6-i*1.85,.74,.34),Vector3(0,5.13+i*.64,3.75),trim)
				part(Vector3(6.72-i*1.85,.11,.46),Vector3(0,5.54+i*.64,3.75),SNOW)
		2: # Mill terraces share exposed timber bays and an attic dormer.
			for x in [-3.9,-1.13,1.13,3.9]:
				part(Vector3(.21,5.0,.23),Vector3(x,2.5,3.55),WOOD)
			part(Vector3(8.15,.21,.24),Vector3(0,3.78,3.57),WOOD)
			part(Vector3(2.45,1.80,1.80),Vector3(0,5.80,3.32),CREAM)
			part(Vector3(2.95,1.08,2.1),Vector3(0,7.18,3.32),SNOW,0,gable)
			window(0,5.86,1.15,4.23)
	# A shoveled walk connects each front step to the street. A post lamp
	# and low garden fence mark the property even on a snowy approach.
	part(Vector3(1.72,.075,7.4),Vector3(0,.035,7.1),Color("#abb3b4"))
	if variant or style == 1:
		part(Vector3(.19,3.75,.19),Vector3(2.20,1.88,8.45),SPRUCE)
		part(Vector3(.64,.74,.64),Vector3(2.20,4.03,8.45),GLASS)
		part(Vector3(.86,.28,.86),Vector3(2.20,4.51,8.45),SPRUCE,0,gable)
	if variant:
		for side in [-1,1]:
			part(Vector3(2.1,.16,.20),Vector3(side*2.85,.95,5.30),trim)
			for i in 4:
				part(Vector3(.13,1.10,.14),Vector3(side*(1.94+i*.58),.55,5.30),CREAM)
	paint.index()
	light.index()
	return light.commit(paint.commit())
