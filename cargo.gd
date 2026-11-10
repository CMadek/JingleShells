extends RefCounted
## Original cargo props shared by the supply piles, carried models, and loose bodies.

enum Kind { EMPTY, PRESENT, BOMB, COAL }

const HALF_SIZE := 0.24

static func shape(kind: int) -> Shape3D:
	if kind == Kind.COAL:
		var lump := BoxShape3D.new()
		lump.size = Vector3(0.28, 0.19, 0.24)
		return lump
	if kind == Kind.BOMB:
		var sphere := SphereShape3D.new()
		sphere.radius = HALF_SIZE
		return sphere
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * HALF_SIZE * 2.0
	return box


const PRESENT_MODEL := preload("res://assets/cargo/present.glb")
const BOMB_MODEL := preload("res://assets/cargo/bomb.glb")
const PRESENT_PILE := preload("res://assets/cargo/present_pile.glb")
const BURNING_FUSE := preload("res://assets/cargo/burning_fuse.tscn")
const BOMB_PILE := preload("res://assets/cargo/bomb_pile.glb")
const COAL_MODEL := preload("res://assets/cargo/anthracite.glb")


static func model(kind: int) -> Node3D:
	if kind == Kind.COAL:
		return COAL_MODEL.instantiate()
	if kind == Kind.PRESENT:
		return PRESENT_MODEL.instantiate()
	var bomb := BOMB_MODEL.instantiate() as Node3D
	var fuse := BURNING_FUSE.instantiate() as Node3D
	# Blender wick tip (X, Y, Z) = (0.075, 0, 0.34), imported Y-up.
	fuse.position = Vector3(0.075, 0.34, 0)
	bomb.add_child(fuse)
	return bomb


static func pile(kind: int) -> Node3D:
	return (PRESENT_PILE if kind == Kind.PRESENT else BOMB_PILE).instantiate()
