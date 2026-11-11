extends RefCounted
## Per-player capsule; clearance tested in the actor's current world orientation.
const STANDING := 1.8
const DUCKED := 1.15
static func can_stand(actor: CharacterBody3D, shape_node: CollisionShape3D) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = .38
	shape.height = STANDING - .04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = actor.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, STANDING / 2.0 + .025, 0))
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

static func update(actor: CharacterBody3D, shape_node: CollisionShape3D, requested: bool) -> void:
	if requested:
		actor.crouched = true
	elif actor.crouched and can_stand(actor, shape_node):
		actor.crouched = false
	var height := DUCKED if actor.crouched else STANDING
	shape_node.shape.height = height
	shape_node.position.y = height / 2.0
