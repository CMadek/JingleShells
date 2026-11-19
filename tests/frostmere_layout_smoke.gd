extends Node

# Project the complete modeled lot (roof overhang through the end of the
# shoveled walk) into the street grid. The two street facings differ by 180°.
func footprint(site: Dictionary, bearing: float) -> Rect2:
	var frame := Basis(Vector3.UP,-bearing)
	var facing := Basis(Vector3.UP,site.yaw)
	var area := Rect2()
	for x in [-4.65,4.65]:
		for z in [-4.04,10.8]:
			var corner: Vector3 = frame*(site.base+facing*Vector3(x,0,z))
			var point := Vector2(corner.x,corner.z)
			if x == -4.65 and z == -4.04: area = Rect2(point,Vector2.ZERO)
			else: area = area.expand(point)
	return area.grow(.5)

func _ready() -> void:
	var failures := 0
	var checked_lots := 0
	for seed_value in 512:
		var d := preload("res://delivery_district.gd").new()
		d.generate(seed_value)
		var lots: Array[Rect2] = []
		for site in d.sites:
			var bounds := footprint(site,d.bearing)
			if lots.any(func(other: Rect2): return other.intersects(bounds)):
				push_error("Overlapping house lots in Frostmere seed %d" % seed_value)
				failures += 1
				break
			lots.append(bounds)
		checked_lots += lots.size()
		var addresses := {}
		for index in d.stops: addresses[index] = true
		if addresses.size() != 6 or addresses.has(-1):
			push_error("Incomplete manifest in seed %d" % seed_value)
			failures += 1
		var halfway := Vector2(0,d.Airfield.PARK.z).lerp(Vector2(d.landmarks["Bell Square"].x,d.landmarks["Bell Square"].z),.5)
		if not Geometry2D.is_point_in_polygon(halfway,d.woodland.shore) or d.woodland.woods.size() != 2:
			push_error("Missing halfway lake or woodland in seed %d" % seed_value)
			failures += 1
		for wood in d.woodland.woods:
			for point in wood:
				if point.y >= -300:
					push_error("Approach forest extends onto the runway in seed %d" % seed_value)
					failures += 1
					break
		for point in d.valley.rail:
			if d.bounds.has_point(point) or Rect2(-80,-320,160,1250).has_point(point) or Geometry2D.is_point_in_polygon(point,d.woodland.shore):
				push_error("Freight line crosses the airfield, lake or delivery district in seed %d" % seed_value)
				failures += 1
				break
		var crossing: Vector3 = d.valley.survey["Trestle Crossing"]
		if not is_equal_approx(crossing.x,d.valley.river_x(crossing.z)):
			push_error("Trestle misses the river in seed %d" % seed_value)
			failures += 1
		d.free()
		if failures: break
	print("FROSTMERE LAYOUT: ",checked_lots," lots, ",failures," failures")
	get_tree().quit(failures)
