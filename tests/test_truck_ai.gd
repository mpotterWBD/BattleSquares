extends SceneTree
## A squadmate driving the supply truck by itself (vehicle_ai.gd), Mike 2026-11-04:
## told where to go it stays on the road (the right-hand lane), stops at a point on
## the road, turns round if it has to, drives forward into a spot near the road and
## backs into one farther off it (nose out toward the road). Prints OK / FAIL.
const PX := 1024.0 / 12.0

var fails := 0
var plan_ms_max := 0   ## the longest a drive_to() planning took (ms)


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## The road's centre line, nearest point to world `p` (metres).
func centre_dist(road: Path2D, p: Vector2) -> float:
	var local := road.to_local(p * PX)
	return local.distance_to(road.curve.get_closest_point(local)) / PX


## Sends the truck to `dest` (metres) and waits for it to finish; returns what it did.
func run_to(truck: Node2D, road: Path2D, dest: Vector2, limit_s := 120.0) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var ok: bool = truck.order_drive_to(dest * PX)
	var plan_ms := Time.get_ticks_msec() - t0
	plan_ms_max = maxi(plan_ms_max, plan_ms)
	var t := 0.0
	var max_lat := 0.0
	var min_speed := 0.0
	var max_speed := 0.0
	var gears := 0
	var prev_sign := 0
	while truck.ai_status() == "driving" and t < limit_s:
		await physics_frame
		t += 1.0 / 60.0
		max_lat = maxf(max_lat, centre_dist(road, truck.global_position / PX))
		min_speed = minf(min_speed, truck.speed)
		max_speed = maxf(max_speed, truck.speed)
		var s := int(signf(truck.speed)) if absf(truck.speed) > 0.3 else prev_sign
		if s != 0 and s != prev_sign:
			gears += 1
			prev_sign = s
	for f in 90: await physics_frame
	var heading := Vector2.from_angle(truck.global_rotation)
	return {ok = ok, t = t, status = truck.ai_status(), end = truck.global_position / PX, heading = heading,
			max_lat = max_lat, min_speed = min_speed, max_speed = max_speed, gears = gears, plan_ms = plan_ms}


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
	var road: Path2D = main.get_node("Road")
	var player: CharacterBody2D = main.get_node("Player")
	var command: Node = main.get_node("Command")
	for f in 4: await physics_frame
	for c in main.get_children():   # (the sandbag walls build their pieces after the scene is up)
		if c is StaticBody2D:
			c.queue_free()
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	await physics_frame
	player.global_position = Vector2(5, 3) * PX
	var home := Vector2(22.0, 13.0)
	truck.global_position = home * PX
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = (home + Vector2(1.5, 3.0)) * PX
	for f in 4: await physics_frame

	# Nobody driving: an order to drive goes nowhere.
	check("no driver: it can't be sent anywhere", not truck.order_drive_to((home + Vector2(5, 0)) * PX))
	mate.order_ride(truck, -1)
	var t := 0.0
	while truck.driver == null and t < 12.0:
		await physics_frame
		t += 1.0 / 60.0
	check("the squadmate's in the driver's seat", truck.driver == mate and truck.ai_driver == mate and not truck.player_driving)

	# A: along the road, east, to a point on the asphalt.
	var r := await run_to(truck, road, Vector2(30.0, 12.9))
	print("    A: %s" % r)
	check("A: ordered, arrived (%s in %.1f s)" % [r.status, r.t], r.ok and r.status == "arrived")
	check("A: the middle's within 1.5 m of the point (%.2f m off)" % r.end.distance_to(Vector2(30.0, 12.9)),
			r.end.distance_to(Vector2(30.0, 12.9)) < 1.5)
	check("A: nose east, and never off the road (%.2f m from the centre line at most)" % r.max_lat,
			r.heading.dot(Vector2.RIGHT) > 0.95 and r.max_lat < 2.2)
	check("A: it went at a good clip (%.1f m/s) and never reversed" % r.max_speed, r.max_speed > 3.0 and r.min_speed > -0.3)

	# B: west, behind it: it has to turn round.
	r = await run_to(truck, road, Vector2(12.0, 11.0))
	print("    B: %s" % r)
	check("B: turned round and arrived (%s in %.1f s, %d changes of gear)" % [r.status, r.t, r.gears], r.ok and r.status == "arrived")
	check("B: the middle's within 1.5 m of the point (%.2f m off), nose west" % r.end.distance_to(Vector2(12.0, 11.0)),
			r.end.distance_to(Vector2(12.0, 11.0)) < 1.5 and r.heading.dot(Vector2.LEFT) > 0.9)
	check("B: it reversed to turn (K-turn) and stayed within 6 m of the road", r.min_speed < -0.5 and r.max_lat < 6.0)

	# C: a spot 4 m off the road: forward in, nose to the spot (south).
	truck.global_position = home * PX
	truck.rotation = 0.0
	truck.speed = 0.0
	for f in 10: await physics_frame
	var spot := Vector2(27.0, 16.2)
	r = await run_to(truck, road, spot)
	print("    C: %s" % r)
	check("C: forward into a spot near the road: arrived (%s in %.1f s)" % [r.status, r.t], r.ok and r.status == "arrived")
	check("C: the middle's within 1.2 m of it (%.2f), nose to the spot (south), never reversing" % r.end.distance_to(spot),
			r.end.distance_to(spot) < 1.2 and r.heading.dot(Vector2.DOWN) > 0.6 and r.min_speed > -0.3)

	# D: a spot farther off: backs in, nose out toward the road (north).
	truck.global_position = home * PX
	truck.rotation = 0.0
	truck.speed = 0.0
	for f in 10: await physics_frame
	spot = Vector2(27.0, 19.8)
	r = await run_to(truck, road, spot)
	print("    D: %s" % r)
	check("D: backed into a spot off the road: arrived (%s in %.1f s)" % [r.status, r.t], r.ok and r.status == "arrived")
	check("D: it reversed in (%.1f m/s back), the middle's within 1.2 m of it (%.2f), nose out toward the road (north)" % [-r.min_speed, r.end.distance_to(spot)],
			r.min_speed < -0.5 and r.end.distance_to(spot) < 1.2 and r.heading.dot(Vector2.UP) > 0.85)

	# The way out of the spot: back on the road, east, forward.
	r = await run_to(truck, road, Vector2(33.0, 12.9))
	print("    E: %s" % r)
	check("E: out of the bay and along the road: arrived (%s in %.1f s)" % [r.status, r.t], r.ok and r.status == "arrived"
			and r.end.distance_to(Vector2(33.0, 12.9)) < 1.5)
	# F: a crate across the lane ahead: it stops short of it, never hitting it.
	truck.global_position = home * PX
	truck.rotation = 0.0
	truck.speed = 0.0
	for f in 10: await physics_frame
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = Vector2(28.0, 13.1) * PX
	for f in 6: await physics_frame
	r = await run_to(truck, road, Vector2(33.0, 12.9))
	print("    F: %s" % r)
	var gap: float = (crate.global_position.x - truck.global_position.x) / PX - truck.LENGTH_M / 2.0 - 0.4
	check("F: a crate in the way: it stopped short of it (%.1f m of clear road left in front), didn't hit it and didn't give up (%s)" % [gap, r.status],
			r.status == "arrived" and gap > 0.2 and gap < 6.0 and truck.global_position.x < crate.global_position.x)
	check("planning took %d ms or less (the longest was D's)" % maxi(plan_ms_max, 1), plan_ms_max < 2500)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
