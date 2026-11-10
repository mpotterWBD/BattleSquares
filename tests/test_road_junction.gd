extends SceneTree
## Road junctions (Mike, 2026-11-09): a T and a crossroads (road_junction.gd),
## all 8 textures (2 kinds x 4 conditions) 12 m square; arms 6 m out; a
## road's end dragged near an arm snaps onto it with its handle carrying
## straight on out of the arm (road.gd _snap_ends(), as in the editor), also
## for a junction turned 90 degrees; covers() for bullets and footsteps; and
## a squadmate driving the truck from a road, through a crossroads, down the
## road off its south arm (vehicle_ai.gd's road map runs through junctions).
## Run with --fixed-fps 60.
const World = preload("res://scripts/world.gd")
const Junction = preload("res://scripts/road_junction.gd")
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func road_from(main: Node, pts: Array) -> Path2D:
	var road: Path2D = Path2D.new()
	road.set_script(load("res://scripts/road.gd"))
	var c := Curve2D.new()
	for p: Vector2 in pts:
		c.add_point(p * PX)
	road.curve = c
	main.add_child(road)
	return road


func _init() -> void:
	var all_ok := true
	for kind in Junction.TEXTURES:
		for cond in Junction.TEXTURES[kind]:
			var tex: Texture2D = Junction.TEXTURES[kind][cond]
			all_ok = all_ok and tex != null and tex.get_width() == 1024 and tex.get_height() == 1024
	check("all 8 junction textures load, 1024 px (12 m) square", all_ok)

	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for f in 4: await physics_frame
	# A clear field: no walls, crates, squad or the level's own road.
	for c in main.get_children():
		if c is StaticBody2D or c.is_in_group("roads") or c.is_in_group("watch_towers"):
			c.queue_free()
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates") + get_nodes_in_group("vehicles"):
		node.queue_free()
	await physics_frame

	# A T, turned 90 degrees: its stem points west.
	var t: Node2D = load("res://scenes/road_junction.tscn").instantiate()
	t.kind = Junction.Kind.T
	t.position = Vector2(60.0, 60.0) * PX
	t.rotation = PI / 2
	main.add_child(t)
	await process_frame
	var stem: Vector2 = t.end_position(2) / PX
	check("the T turned 90: its stem's end 6 m west of the middle (%s)" % stem, stem.distance_to(Vector2(54.0, 60.0)) < 0.01
			and t.end_outward(2).distance_to(Vector2.LEFT) < 0.001)
	check("covers: the middle and its arms' asphalt, not the grass between them",
			t.covers(Vector2(60, 60) * PX) and t.covers(Vector2(55, 61) * PX) and t.covers(Vector2(61, 65) * PX)
			and not t.covers(Vector2(56, 56) * PX) and not t.covers(Vector2(65, 60) * PX))
	# A road ending 0.6 m off the stem's end, at an angle: it snaps on.
	var r: Path2D = road_from(main, [Vector2(40.0, 66.0), Vector2(53.5, 60.5)])
	await process_frame
	r._snap_ends()
	var end: Vector2 = r.end_position(1) / PX
	var handle_dir: Vector2 = r.global_transform.basis_xform(r.curve.get_point_in(1)).normalized()
	check("a road's end 0.6 m off the stem clicks onto it (%s)" % end, end.distance_to(stem) < 0.01)
	check("...its handle turned so it carries straight on out of the arm (west)", handle_dir.distance_to(Vector2.LEFT) < 0.01)
	var far: Path2D = road_from(main, [Vector2(40.0, 80.0), Vector2(52.0, 80.0)])
	await process_frame
	far._snap_ends()
	check("one 20 m off isn't pulled in", (far.end_position(1) / PX).distance_to(Vector2(52.0, 80.0)) < 0.01)

	# A crossroads, a road to its west arm, one off its south arm; the truck goes through.
	var x: Node2D = load("res://scenes/road_junction.tscn").instantiate()
	x.kind = Junction.Kind.CROSS
	x.position = Vector2(30.0, 30.0) * PX
	main.add_child(x)
	await process_frame
	var west: Path2D = road_from(main, [Vector2(-10.0, 30.0), Vector2(24.0, 30.0)])
	var south: Path2D = road_from(main, [Vector2(30.0, 36.0), Vector2(30.0, 70.0)])
	await process_frame
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	main.add_child(truck)
	truck.global_position = Vector2(0.0, 31.3) * PX
	var player: Node2D = main.get_node("Player")
	player.global_position = Vector2(0.0, 45.0) * PX
	player.collision_layer = 0
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = Vector2(1.0, 28.0) * PX
	for f in 4: await physics_frame
	mate.order_ride(truck, -1)
	var tt := 0.0
	while truck.driver != mate and tt < 15.0:
		await physics_frame
		tt += 1.0 / 60.0
	var dest := Vector2(28.7, 60.0)   # (the south road's lane, southbound: on its right, the west side)
	check("sent down the south road", truck.order_drive_to(dest * PX))
	var path: PackedVector2Array = truck.ai_path_px()
	var through := false
	var off_grass := true
	for p in path:
		var m := p / PX
		if m.distance_to(Vector2(30, 30)) < 4.0:
			through = true
		# (the route keeps to the roads: on asphalt or within a metre of it)
		var on := false
		for road in get_nodes_in_group("roads"):
			for d in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				if road.covers(p + d * PX):
					on = true
		off_grass = off_grass and on
	check("its route goes through the crossroads and keeps to the roads", through and off_grass)
	tt = 0.0
	while truck.ai_status() == "driving" and tt < 60.0:
		await physics_frame
		tt += 1.0 / 60.0
	var at: Vector2 = truck.global_position / PX
	check("it got there (%s, %.1f m off, in %.1f s)" % [truck.ai_status(), at.distance_to(dest), tt], truck.ai_status() == "arrived" and at.distance_to(dest) < 2.0)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
