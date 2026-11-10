extends SceneTree
## Parking next to a crate (Mike, 2026-11-09: it got hung up on the box when it
## had to end right next to it; the way there should be as fast and efficient as
## possible). A crate where Mike's was (10, 16.4); the truck parked beside it,
## nose to it, tail to it and on its far side, each from four starting places
## (on the road both ways, south of it, west of it), and Mike's last order (from
## beside the crate to the road at 30.4, 13.2, east: it drove a little and
## stopped). Each must arrive (0.45 m, 4 degrees), never touch the crate, never
## get stuck, and not wander: 25 s at most (planning and all), and no more than
## twice the straight-line distance plus 32 m (a U-turn's loop round is about as
## quick as a three-point turn, and allowed). Driven distance and time are printed against the
## straight-line distance. Run with --fixed-fps 60 (no waiting on the clock).
const PX := 1024.0 / 12.0
const CRATE := Vector2(10.0, 16.4)

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for child in main.get_children():
		if (child is CollisionObject2D and child.name != "Player") or child.is_in_group("watch_towers") \
				or child.name.begins_with("Sandbag") or child.name.begins_with("Crate"):
			child.queue_free()
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	main.add_child(truck)
	var player: CharacterBody2D = main.get_node("Player")
	for f in 4: await physics_frame
	for c in main.get_children():
		if c is StaticBody2D:
			c.queue_free()
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates") + get_nodes_in_group("vehicles"):
		if node != truck:
			node.queue_free()
	await physics_frame
	player.global_position = Vector2(40.0, 3.0) * PX
	truck.global_position = Vector2(20.0, 13.3) * PX
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = Vector2(21.0, 10.0) * PX
	for f in 4: await physics_frame
	mate.order_ride(truck, -1)
	var t := 0.0
	while truck.driver != mate and t < 15.0:
		await physics_frame
		t += 1.0 / 60.0
	check("a squadmate's driving", truck.driver == mate)
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = CRATE * PX
	for f in 4: await physics_frame

	var goals := [
		["beside it (Mike's), west", Vector2(9.87, 17.98), 180.0],
		["nose to it, west", Vector2(13.0, 16.4), 180.0],
		["tail to it, west", Vector2(7.0, 16.4), 180.0],
		["its road side, east", Vector2(10.1, 14.85), 0.0],
	]
	var starts := [
		["on the road east", Vector2(17.3, 13.3), 0.0],
		["on the road west", Vector2(25.0, 10.8), 180.0],
		["south of it, north", Vector2(14.0, 21.5), -90.0],
		["west of it, east", Vector2(3.5, 19.5), 0.0],
	]
	var cases := []
	for g in goals:
		for s in starts:
			cases.append([s[0] + " -> " + g[0], s[1], s[2], g[1], g[2]])
	cases.append(["Mike's last: beside the crate -> the road east", Vector2(10.0, 17.99), 180.0, Vector2(30.4, 13.19), 0.0])
	var worst_ms := 0
	var worst_frame := 0
	var total_t := 0.0
	for c in cases:
		truck.global_position = c[1] * PX
		truck.rotation = deg_to_rad(c[2])
		truck.speed = 0.0
		truck.steer = 0.0
		crate.global_position = CRATE * PX
		for f in 3: await physics_frame
		var ok: bool = truck.order_drive_to(c[3] * PX, deg_to_rad(c[4]))
		var ai = truck._ai
		t = 0.0
		var hitch := 0   # (the longest a frame took while it was planning: the search is on a thread)
		while ai.planning and t < 10.0:
			var f0 := Time.get_ticks_msec()
			await physics_frame
			hitch = maxi(hitch, Time.get_ticks_msec() - f0)
			t += 1.0 / 60.0
		worst_ms = maxi(worst_ms, ai.plan_ms)
		worst_frame = maxi(worst_frame, hitch)
		var shape := []
		for run in ai.runs:
			shape.append("%s%.1f" % ["R" if run.reverse else "F", run.cum[run.cum.size() - 1]])
		var travelled := 0.0
		var last: Vector2 = truck.global_position
		var touched := false
		while ok and truck.ai_status() == "driving" and t < 90.0:
			await physics_frame
			t += 1.0 / 60.0
			travelled += truck.global_position.distance_to(last) / PX
			last = truck.global_position
			if crate.global_position.distance_to(CRATE * PX) > 0.02 * PX:
				touched = true
		for f in 30: await physics_frame
		var off: float = (truck.global_position / PX).distance_to(c[3])
		var turn := absf(rad_to_deg(angle_difference(truck.global_rotation, deg_to_rad(c[4]))))
		var straight: float = (c[1] as Vector2).distance_to(c[3])
		total_t += t
		print("    %s: %s in %.1f s, drove %.1f m (straight line %.1f), runs %s, plan %d ms (%s, frame %d ms), stuck %d, off %.2f m %.1f deg" % [
				c[0], truck.ai_status() if ok else "REFUSED", t, travelled, straight, shape, ai.plan_ms, ai.plan_note, hitch, ai.unsticks, off, turn])
		check("%s: arrived, never stuck, crate untouched, %.2f m / %.1f deg off, %.1f s (25 at most), drove %.1f m for %.1f" % [c[0], off, turn, t, travelled, straight],
				ok and truck.ai_status() == "arrived" and ai.unsticks == 0 and not touched and off < 0.45 and turn < 4.5
				and t <= 25.0 and travelled <= straight * 2.0 + 32.0)
	print("    total driving %.0f s; planning at most %d ms" % [total_t, worst_ms])
	check("planning never held a frame up: the longest frame while it planned took %d ms (the search: %d ms at most, a slice a tick)" % [worst_frame, worst_ms],
			worst_frame <= 20)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
