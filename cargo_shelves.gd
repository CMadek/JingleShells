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
			# Fitted shelf art now comes from Blender; keep the same physical shelf.
			world._hull_box(hull,Vector3(.9,.09,2.8),Vector3(x,y,8.65))
			for z in [7.75,8.65,9.55]:
				var point := Vector3(x,y+.045+Cargo.HALF_SIZE,z)
				var item: Node3D = (Cargo.BOMB_MODEL if side == 1 else Cargo.PRESENT_MODEL).instantiate()
				rack.add_child(item)
				item.position = point
				targets.append({"kind":kind,"point":point})
	return targets
