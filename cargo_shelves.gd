extends RefCounted
## Individual supply cubbies in the original POC's two side cargo bays.
const Cargo = preload("res://cargo.gd")
const LEVELS := [.30, 1.10, 1.90]
const COLUMNS := [-1.0, 0.0, 1.0]

static func build(world: Node3D, hull: StaticBody3D) -> Array:
	var targets: Array = []
	for side in [-1, 1]:
		var kind: int = Cargo.Kind.PRESENT if side == -1 else Cargo.Kind.BOMB
		var rack := Node3D.new()
		rack.name = "PresentShelves" if side == -1 else "BombShelves"
		world.bomber.add_child(rack)
		var x: float = side * 2.42
		# Each item has a separate shelf cubby, with an open face toward the aisle.
		for y in [.30, 1.10, 1.90, 2.68]:
			part(world, hull, rack, Vector3(.96,.09,3.12), Vector3(x,y,0), Color("795238"))
			world._box(rack,Vector3(.035,.045,3.12),Vector3(side*1.925,y+.025,0),Color("c2a157"))
		for z in [-1.55,-.50,.50,1.55]:
			part(world,hull,rack,Vector3(.96,2.68,.065),Vector3(x,1.34,z),Color("254e42"))
		part(world,hull,rack,Vector3(.065,2.68,3.12),Vector3(side*2.90,1.34,0),Color("254e42"))
		for row in LEVELS.size():
			for column in COLUMNS.size():
				var point := Vector3(x,LEVELS[row]+.045+Cargo.HALF_SIZE,COLUMNS[column])
				# Stored bombs are unlit; fuse effects belong to the carried/loose prop.
				var item: Node3D = (Cargo.PRESENT_MODEL if kind == Cargo.Kind.PRESENT else Cargo.BOMB_MODEL).instantiate()
				item.name = "Supply_%d_%d" % [row,column]
				item.position = point
				item.rotation.y = side*PI/2 + .12*(column-1)
				rack.add_child(item)
				targets.append({"kind":kind,"point":point})
				# Low retaining lip and brass fasteners frame each individual slot.
				world._box(rack,Vector3(.035,.07,.90),Vector3(side*1.925,LEVELS[row]+.08,COLUMNS[column]),Color("c2a157"))
		var title := "PRESENTS" if kind == Cargo.Kind.PRESENT else "BOMBS"
		# Fixed plaques sit on the cabinet instead of floating into the curved roof.
		for end in [-1,1]:
			world._box(rack,Vector3(.84,.34,.025),Vector3(x,1.75,end*1.60),Color("795238"))
			var sign := Label3D.new()
			sign.text = title
			sign.font_size = 36
			sign.pixel_size = .0038
			sign.modulate = Color("f3d9a3")
			sign.position = Vector3(x,1.75,end*1.62)
			sign.rotation.y = PI if end == -1 else 0.0
			rack.add_child(sign)
	return targets

static func part(world: Node3D, hull: StaticBody3D, rack: Node3D, size: Vector3, point: Vector3, color: Color) -> void:
	world._box(rack,size,point,color)
	# Duplicated into the moving cargo hull by World after construction.
	world._hull_box(hull,size,point)
