extends RefCounted
## Low, open wall racks in the separate aft room. Centre aisle stays clear.
const Cargo = preload("res://cargo.gd")
static func build(world: Node3D, hull: StaticBody3D) -> Array:
	var targets: Array = []
	for side in [-1,1]:
		var kind: int = Cargo.Kind.BOMB if side == 1 else Cargo.Kind.PRESENT
		var rack := Node3D.new()
		rack.name = "BombRack" if side == 1 else "PresentRack"
		world.bomber.add_child(rack)
		var x: float = side*2.42
		for y in [.25,.95]:
			world._box(rack,Vector3(.9,.09,2.8),Vector3(x,y,8.65),Color("795238"))
			world._hull_box(hull,Vector3(.9,.09,2.8),Vector3(x,y,8.65))
			for z in [7.75,8.65,9.55]:
				var point := Vector3(x,y+.045+Cargo.HALF_SIZE,z)
				var item: Node3D = (Cargo.BOMB_MODEL if side == 1 else Cargo.PRESENT_MODEL).instantiate()
				rack.add_child(item)
				item.position = point
				targets.append({"kind":kind,"point":point})
			world._box(rack,Vector3(.04,.07,2.8),Vector3(side*1.97,y+.08,8.65),Color("c2a157"))
		for z in [7.25,10.05]:
			for xx in [side*2.02,side*2.82]:
				world._box(rack,Vector3(.08,1.05,.08),Vector3(xx,.525,z),Color("254e42"))
		var sign := Label3D.new()
		sign.text = "BOMBS" if side == 1 else "PRESENTS"
		sign.font_size = 32
		sign.pixel_size = .004
		sign.position = Vector3(side*1.94,.78,8.65)
		sign.rotation.y = -side*PI/2
		rack.add_child(sign)
	return targets
