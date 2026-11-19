extends Control
## Live ink on the physical chart. Each panel uses a single metres-to-paper scale.
var world: Node3D
var mess: Node3D
const INK := Color("263c41")
const FAINT := Color("b8ae88")
const RED := Color("963d39")
const TEAL := Color("27675b")
const BLUE := Color("22568a")
const PAPER := Color("e5dab5")
const ROUTE := Rect2(29,91,340,344)
const VILLAGE := Rect2(390,91,544,344)
var font: Font = ThemeDB.fallback_font
var route_bounds := Rect2()

func position_on_chart(pixel: Vector2) -> Vector3:
	if not world.district: return Vector3.INF
	for pair in [[route_bounds,ROUTE],[world.district.bounds,VILLAGE]]:
		var area: Rect2 = pair[0]
		var panel: Rect2 = pair[1]
		if not panel.has_point(pixel) or not area.has_area(): continue
		var metres := area.get_center() + (pixel-panel.get_center()) / minf(panel.size.x/area.size.x,panel.size.y/area.size.y)
		return Vector3(metres.x,0,metres.y)
	return Vector3.INF

func lettering(p: Vector2, value: String, px := 15, color := INK) -> void:
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func plot(point: Vector3, bounds: Rect2, panel: Rect2) -> Vector2:
	var scale_factor := minf(panel.size.x / bounds.size.x, panel.size.y / bounds.size.y)
	return panel.get_center() + (Vector2(point.x,point.z) - bounds.get_center()) * scale_factor

func draw_chart_area(outline: PackedVector2Array, area: Rect2, panel: Rect2, color: Color) -> void:
	var ink := PackedVector2Array()
	for point in outline: ink.append(plot(Vector3(point.x,0,point.y),area,panel))
	draw_colored_polygon(ink,color)

func frame(panel: Rect2) -> void:
	draw_rect(panel,Color("dfd4b2"))
	for index in range(1,8):
		var offset := panel.size*index/8.0
		draw_line(panel.position+Vector2(offset.x,0),panel.position+Vector2(offset.x,panel.size.y),FAINT,.8)
		draw_line(panel.position+Vector2(0,offset.y),panel.position+Vector2(panel.size.x,offset.y),FAINT,.8)
	draw_rect(panel,INK,false,1.4)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),PAPER)
	draw_rect(Rect2(10,10,940,580),INK,false,2)
	lettering(Vector2(28,41),"NORTH STAR   /   FLIGHT SURVEY",26)
	if not world or not world.district: return
	var district = world.district
	lettering(Vector2(726,40),"CHART   %08X" % district.route_seed,16)
	lettering(ROUTE.position-Vector2(0,10),"01    FLIGHT LINE   •   N ↑",16)
	lettering(VILLAGE.position-Vector2(0,10),"02    " + String(district.town).to_upper() + "    /    DELIVERY DISTRICT",16)
	frame(ROUTE)
	frame(VILLAGE)
	var bounds: Rect2 = district.bounds.expand(Vector2(0,900)).grow(80)
	if mess.waypoint.is_finite(): bounds = bounds.expand(Vector2(mess.waypoint.x,mess.waypoint.z))
	for elf in world.players.values():
		bounds = bounds.expand(Vector2(elf.position.x,elf.position.z)).grow(.1)
	bounds = bounds.expand(Vector2(world.bomber.position.x,world.bomber.position.z)).grow(24)
	route_bounds = bounds
	for pair in [[bounds,ROUTE],[district.bounds,VILLAGE]]:
		var area: Rect2 = pair[0]
		var panel: Rect2 = pair[1]
		if panel == ROUTE:
			var watercourse := PackedVector2Array()
			for bank in district.valley.river:
				var point := plot(Vector3(bank.x,0,bank.y),area,panel)
				if panel.grow(-2).has_point(point): watercourse.append(point)
			if watercourse.size() >= 2: draw_polyline(watercourse, Color("8fb3c0"), 3, true)
			for i in range(1,district.valley.rail.size()):
				var a: Vector2 = district.valley.rail[i-1]
				var b: Vector2 = district.valley.rail[i]
				var p := plot(Vector3(a.x,0,a.y),area,panel)
				var q := plot(Vector3(b.x,0,b.y),area,panel)
				if panel.has_point(p) and panel.has_point(q): draw_line(p,q,FAINT,1.2,true)
			for wood in district.woodland.woods:
				draw_chart_area(wood,area,panel,Color("8fa98e"))
			draw_chart_area(district.woodland.shore,area,panel,Color("8fb3c0"))
			var lake: Vector2 = district.woodland.lake_center
			var mid := plot(Vector3(lake.x,0,lake.y),area,panel)
			lettering(mid+Vector2(21,4),"Stillwater Lake",12,BLUE)
			for grove in district.groves:
				var center := plot(grove,area,panel)
				if panel.has_point(center):
					draw_colored_polygon(PackedVector2Array([center+Vector2(0,-2.5),center+Vector2(2,2),center+Vector2(-2,2)]), TEAL)
			draw_line(plot(Vector3(0,0,-300),area,panel),plot(Vector3(0,0,900),area,panel),INK,3)
			var base := plot(world.Airfield.SPAWN,area,panel)
			draw_rect(Rect2(base-Vector2(3,3),Vector2(6,6)),RED)
			lettering(base+Vector2(8,0),"LAST STOP",12)
			for title: String in district.valley.survey:
				var pin := plot(district.valley.survey[title],area,panel)
				draw_rect(Rect2(pin-Vector2(2,2),Vector2(4,4)),INK)
				var left := title == "Trestle Crossing"
				var offset := -font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x-5 if left else 5.0
				lettering(pin+Vector2(offset,4),title,11)
		else:
			for road in district.roads:
				var line := PackedVector2Array()
				for point in road: line.append(plot(point,area,panel))
				draw_polyline(line,FAINT,2)
		for i in world.recipients.houses.size():
			var house: Dictionary = world.recipients.houses[i]
			if panel == ROUTE and not district.stops.has(i): continue
			var p := plot(world.chimneys[i].top,area,panel)
			if house.destroyed:
				draw_line(p-Vector2(2,2),p+Vector2(2,2),INK,1)
				draw_line(p-Vector2(-2,2),p+Vector2(-2,2),INK,1)
			elif house.delivered: draw_arc(p,3.2,0,TAU,10,TEAL,1.3)
			elif house.nice: draw_circle(p,2.8 if panel == VILLAGE else 1.1,TEAL)
			else: draw_rect(Rect2(p-Vector2.ONE*2,Vector2.ONE*4),RED)
		for title in district.landmarks:
			var p := plot(district.landmarks[title],area,panel)
			if title == "Lantern Quay":
				var shore := PackedVector2Array()
				for j in 32:
					var edge := Vector3(cos(TAU*j/32)*32,0,sin(TAU*j/32)*20.8)
					shore.append(plot(district.landmarks[title]+edge.rotated(Vector3.UP,district.bearing),area,panel))
				draw_colored_polygon(shore,Color("97b7ba"))
			draw_circle(p,3,BLUE)
			if panel == VILLAGE: lettering(Vector2(clampf(p.x-(70 if title == "Lantern Quay" else 25),panel.position.x+2,panel.end.x-83),p.y-7),title,12)
		if panel == VILLAGE:
			for i in district.stops.size():
				var anchor := plot(world.chimneys[district.stops[i]].top,area,panel)
				var ink := TEAL if district.sites[district.stops[i]].nice else RED
				if world.contract.delivered[i] == world.contract.REQUIRED[i]: ink = INK
				draw_circle(anchor,10,ink)
				lettering(anchor+Vector2(-4,5),str(i+1),14,PAPER)
		for cargo in world.loose.values():
			var p := plot(cargo.global_position,area,panel)
			if panel.has_point(p): draw_circle(p,2,Color("ae7526"))
		for id in world.players:
			var p := plot(world.players[id].position,area,panel)
			if panel.has_point(p):
				draw_arc(p,4,0,TAU,12,BLUE,1.6)
		var plane := plot(world.bomber.position,area,panel)
		if panel.has_point(plane):
			var dir := Vector2(-sin(world.heading),-cos(world.heading))
			draw_colored_polygon(PackedVector2Array([plane+dir*9,plane-dir*6+dir.orthogonal()*5,plane-dir*4,plane-dir*6-dir.orthogonal()*5]),INK)
		if mess.waypoint.is_finite():
			var mark := plot(mess.waypoint,area,panel)
			if panel.has_point(mark):
				if panel.has_point(plane) and plane.distance_to(mark)>12: draw_dashed_line(plane,mark,RED,1.5,5,true)
				draw_arc(mark,8,-.2,TAU,30,RED,2.5,true)
	lettering(Vector2(29,455),"POSTMASTER'S LIST",16)
	for i in district.stops.size():
		var x: int = 29 + (i % 3)*303
		var y := 477 if i < 3 else 522
		var coal: bool = not district.sites[district.stops[i]].nice
		var done: bool = world.contract.delivered[i] == world.contract.REQUIRED[i]
		var ink := INK if done else (RED if coal else TEAL)
		draw_rect(Rect2(x,y-14,4,33),ink)
		lettering(Vector2(x+10,y),"%02d  %s  /  %s" % [i+1, world.contract.CHILDREN[i], "SIGNED" if done else ("NAUGHTY" if coal else "NICE")],16,ink)
		lettering(Vector2(x+10,y+18),"%s   ·   %s %d/%d" % [world.contract.ADDRESSES[i], "Coal" if coal else "Gifts", world.contract.delivered[i], world.contract.REQUIRED[i]],14)
	lettering(Vector2(29,562),"▲ Aircraft    ◎ Crew    ● Nice    ○ Delivered    ■ Naughty    × Ruin",14)
	var balance: int = mess.vouchers
	lettering(Vector2(760,557),"%d  VOUCHERS" % balance,16,RED)
	if mess.presenting:
		lettering(Vector2(29,580),"{mark_chart}   Mark / erase     •     {crew_primary}   Fold chart".format(Game.bindings.labels),13)
