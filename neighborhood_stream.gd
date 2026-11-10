extends Node3D
## Each district can be reconstructed from its address and the host's map settings.
const District := preload("res://neighborhood.gd")
const LOAD_DISTANCE := 220.0
const KEEP_DISTANCE := 265.0
const BUILD_BUDGET_USEC := 2000

var districts := {}
var map_seed: int
var settings: Vector4i
var district_size: Vector2


func configure(chosen_seed: int, chosen_settings: Vector4i, start: Vector3) -> void:
	map_seed = chosen_seed
	settings = chosen_settings
	district_size = District.span(settings.x, settings.y)
	var first := start_district(address(start))
	first.build_step()
	print("Neighborhood seed %d, starting district %s: %d homes, %d cars in %.1f ms" % [
		map_seed, first.district, first.lots.size(), first.car_count, first.generation_ms])


func address(pos: Vector3) -> Vector2i:
	return Vector2i((Vector2(pos.x, pos.z)/district_size + Vector2(0.5, 0.5)).floor())


func start_district(coord: Vector2i) -> District:
	var district := District.new()
	district.hide()
	add_child(district)
	district.begin_build(map_seed, settings.x, settings.y, settings.z, settings.w, coord)
	districts[coord] = district
	return district


func distance_to_edge(point: Vector2, coord: Vector2i) -> float:
	var gap := (point - Vector2(coord)*district_size).abs() - district_size*0.5
	return gap.max(Vector2.ZERO).length()


func advance(pos: Vector3, cargo: Dictionary) -> void:
	var point := Vector2(pos.x, pos.z)
	var margin := Vector3(LOAD_DISTANCE, 0, LOAD_DISTANCE)
	var low := address(pos-margin)
	var high := address(pos+margin)
	var closest := INF
	var next := Vector2i.ZERO
	for z in range(low.y, high.y+1):
		for x in range(low.x, high.x+1):
			var coord := Vector2i(x, z)
			var district: District = districts.get(coord)
			if district and district.ready_for_play:
				continue
			var distance := distance_to_edge(point, coord)
			if distance <= LOAD_DISTANCE and distance < closest:
				closest = distance
				next = coord

	# Keep the ground under falling cargo live even when the crew flies away.
	var pinned := {}
	for body: Node3D in cargo.values():
		var coord := address(body.global_position)
		pinned[coord] = true
		var district: District = districts.get(coord)
		if not district or not district.ready_for_play:
			next = coord
			closest = 0
	for coord: Vector2i in districts.keys():
		if not pinned.has(coord) and distance_to_edge(point, coord) > KEEP_DISTANCE:
			var old: District = districts[coord]
			remove_child(old)
			old.queue_free()
			districts.erase(coord)
	if closest != INF:
		var district: District = districts.get(next)
		if not district:
			district = start_district(next)
		district.build_step(BUILD_BUDGET_USEC)
