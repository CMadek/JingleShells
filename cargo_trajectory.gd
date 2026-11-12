extends RefCounted
## Shared shape sweep used by impact detection and the trajectory estimate.
static func sweep(space: PhysicsDirectSpaceState3D, shape: Shape3D, pose: Transform3D, motion: Vector3, mask: int, excluded: Array[RID] = []) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.collision_mask = mask
	query.exclude = excluded
	var overlap := space.get_rest_info(query)
	if not overlap.is_empty():
		overlap["collider"] = instance_from_id(overlap.collider_id)
		return overlap
	query.motion = motion
	var fractions := space.cast_motion(query)
	if fractions[0] >= 1.0: return {}
	query.transform.origin += motion * minf(1, fractions[1] + .001)
	query.motion = Vector3.ZERO
	var hit := space.get_rest_info(query)
	if hit.is_empty():
		var ray := PhysicsRayQueryParameters3D.create(pose.origin, pose.origin+motion,mask,excluded)
		hit = space.intersect_ray(ray)
	if hit.has("collider_id"): hit["collider"] = instance_from_id(hit.collider_id)
	if hit.has("position"): hit["point"] = hit.position
	return hit
