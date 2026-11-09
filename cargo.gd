extends RefCounted
## Original cargo props shared by the supply piles, carried models, and loose bodies.

enum Kind { EMPTY, PRESENT, BOMB }

const HALF_SIZE := 0.24

static func shape(kind: int) -> Shape3D:
	if kind == Kind.BOMB:
		var sphere := SphereShape3D.new()
		sphere.radius = HALF_SIZE
		return sphere
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * HALF_SIZE * 2.0
	return box


static func model(kind: int) -> Node3D:
	var root := Node3D.new()
	if kind == Kind.PRESENT:
		_box(root, Vector3.ONE * 0.48, Vector3.ZERO, Color.FIREBRICK)
		_box(root, Vector3(0.49, 0.49, 0.08), Vector3.ZERO, Color.GOLD)
		_box(root, Vector3(0.08, 0.49, 0.49), Vector3.ZERO, Color.GOLD)
	else:
		var ball := SphereMesh.new()
		ball.radius = HALF_SIZE
		ball.height = HALF_SIZE * 2.0
		_part(root, ball, Vector3.ZERO, Color.DARK_SLATE_GRAY)
		_box(root, Vector3(0.07, 0.12, 0.07), Vector3(0, 0.27, 0), Color.TAN)
	return root


static func _box(root: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(root, mesh, pos, color)


static func _part(root: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	part.material_override = material
	part.mesh = mesh
	part.position = pos
	root.add_child(part)
