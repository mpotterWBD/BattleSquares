extends SceneTree
## The truck in command mode (Mike, 2026-11-09). Clicking the truck with nobody
## selected sends whoever's in the command circle: one alone (to the side clicked,
## else the other seat), two a seat each, more the two nearest its doors. The
## truck isn't selectable any more: Park shows only while a truck with a
## squadmate at the wheel is in the circle; it brings up a ghost (turned by the
## wheel) and a click sends the driver to park exactly there, that way round
## (vehicle_ai.gd `_finish_pose()`). Parks: ahead on the road; behind it facing
## the other way; off the road nose out, nose in (backed), at 45 degrees; just
## behind where it is. A spot with a crate in it is refused (the ghost stays).
## Disperse with nobody selected gets them out. Prints each park's error.
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait_for(cond: Callable, limit_s: float) -> float:
	var t := 0.0
	while not cond.call() and t < limit_s:
		await physics_frame
		t += 1.0 / 60.0
	return t


func mate_at(main: Node, at: Vector2) -> Node2D:
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = at * PX
	return mate


## Parks the truck at `at` (m), nose along `deg`, through the command code; waits; {ok, status, t, off, turn, back, plan_ms}.
func park(command: Node, truck: Node2D, at: Vector2, deg: float) -> Dictionary:
	command._give_park_order()
	if command._park_truck != truck:
		return {ok = false, status = "no Park"}
	command._mouse_world = at * PX
	command._park_heading = deg_to_rad(deg)
	var t0 := Time.get_ticks_msec()
	command._confirm_park()
	var plan_ms := Time.get_ticks_msec() - t0
	var ok: bool = command._park_truck == null and truck.ai_status() == "driving"
	var shape := []
	if ok:
		for run in truck._ai.runs:
			shape.append("%s%.1fm" % ["R" if run.reverse else "F", run.cum[run.cum.size() - 1]])
	var was_short: bool = ok and truck._ai.short
	command._park_truck = null
	var back := 0.0
	var t := 0.0
	while truck.ai_status() == "driving" and t < 150.0:
		await physics_frame
		t += 1.0 / 60.0
		back = minf(back, truck.speed)
	for f in 60: await physics_frame
	return {ok = ok, status = truck.ai_status(), t = t, plan_ms = plan_ms,
			off = (truck.global_position / PX).distance_to(at),
			turn = absf(rad_to_deg(angle_difference(truck.global_rotation, deg_to_rad(deg)))), back = back, runs = shape, short = was_short}


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
	var command: Node = main.get_node("Command")
	for f in 4: await physics_frame
	for c in main.get_children():
		if c is StaticBody2D:
			c.queue_free()
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates") + get_nodes_in_group("vehicles"):
		if node != truck:
			node.queue_free()
	await physics_frame
	var home := Vector2(22.0, 13.2)
	truck.global_position = home * PX
	player.global_position = (home + Vector2(0.0, 4.5)) * PX
	for f in 4: await physics_frame

	# ---- getting in from the circle, nobody selected
	var a := mate_at(main, home + Vector2(-1.0, 3.0))
	for f in 4: await physics_frame
	command._place_menus()
	check("no driver: no Park", not command._park_button.visible and command._park_candidate() == null)
	command._click(truck.to_global(Vector2(1.0, -0.4) * PX), false)   # the left of the cab: the driver's side
	check("one in the circle, nobody selected, a click on the driver's side: it goes to drive", a.riding == truck
			and truck.seat_free(1) and not truck.seat_free(-1))
	await wait_for(func(): return truck.driver == a, 15.0)
	check("...and it's in the driver's seat", truck.driver == a)
	var b := mate_at(main, home + Vector2(0.5, 3.0))
	for f in 4: await physics_frame
	command._click(truck.to_global(Vector2(1.0, -0.4) * PX), false)   # the driver's side again: taken
	check("one more, clicked on the (taken) driver's side: it takes the passenger's seat", b.riding == truck and not truck.seat_free(1))
	await wait_for(func(): return truck.passenger == b, 15.0)
	truck.dismount_all()
	await wait_for(func(): return truck.driver == null and truck.passenger == null and not truck.busy(), 20.0)
	for f in 30: await physics_frame
	var c := mate_at(main, home + Vector2(4.5, 3.6))   # farther from the doors than a and b
	for f in 4: await physics_frame
	for u in [a, b, c]:
		u.global_position = Vector2(u.global_position.x, (home.y + 3.0) * PX)
	a.global_position.x = (home.x + 0.5) * PX
	b.global_position.x = (home.x + 1.5) * PX
	c.global_position.x = (home.x + 6.0) * PX
	for f in 4: await physics_frame
	command._click(truck.to_global(Vector2(-1.5, 0.0) * PX), false)   # the bed
	check("three in the circle, nobody selected: the two nearest the doors get in, the third stays",
			a.riding == truck and b.riding == truck and c.riding == null)
	await wait_for(func(): return truck.driver != null and truck.passenger != null, 20.0)
	check("...one in each seat", truck.driver != null and truck.passenger != null)
	var drv: Node2D = truck.driver
	c.queue_free()   # (out of the way of the parking)
	player.collision_layer = 0   # (the player's moved beside the truck for each park, to keep it in the circle: not to be in the way)

	# ---- Park
	command._place_menus()
	check("a squadmate driving, the truck in the circle: Park shows", command._park_button.visible and command._park_candidate() == truck)
	check("the truck can't be selected any more (no selected_truck)", not command.has_method("selected_truck"))
	command._give_park_order()
	check("Park: the ghost's up, at the truck's own heading until the wheel turns it",
			command._park_truck == truck and absf(command._park_heading_now() - truck.global_rotation) < 0.001)
	var turned: float = command._turned_attention(command._park_heading_now(), 1)
	check("one wheel notch turns it 15 degrees", absf(rad_to_deg(turned - truck.global_rotation) - 15.0) < 0.5)
	command._park_truck = null

	var cases := [
		["A ahead on the road, east", Vector2(31.0, 13.3), 0.0],
		["B behind it, facing west (turn round)", Vector2(15.0, 10.8), 180.0],
		["C off the road, nose out (south)", Vector2(27.0, 16.6), 90.0],
		["D off the road, nose to the road (backed in)", Vector2(33.0, 18.0), -90.0],
		["E off the road at 45 degrees", Vector2(24.0, 17.5), 45.0],
		["F on the road, a little behind, east", Vector2(19.0, 13.3), 0.0],
		["G across the road, north", Vector2(30.0, 12.0), -90.0],
	]
	var worst_ms := 0
	for k in cases:
		player.global_position = truck.global_position + Vector2(0.0, 3.0) * PX   # (the truck's always in the circle)
		await physics_frame
		var r := await park(command, truck, k[1], k[2])
		worst_ms = maxi(worst_ms, r.get("plan_ms", 0))
		print("    %s: %s" % [k[0], r])
		check("%s: arrived, within 0.5 m (%.2f) and 5 degrees (%.1f)" % [k[0], r.get("off", -1.0), r.get("turn", -1.0)],
				r.ok and r.status == "arrived" and r.off < 0.5 and r.turn < 5.0)
	check("planning took %d ms at most" % worst_ms, worst_ms < 1500)

	# A spot with a crate in it: refused, the ghost stays.
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = Vector2(36.0, 17.0) * PX
	player.global_position = truck.global_position + Vector2(0.0, 3.0) * PX
	for f in 4: await physics_frame
	command._give_park_order()
	command._mouse_world = Vector2(36.0, 17.0) * PX
	check("the ghost's red over the crate", not command._park_clear(truck, command._mouse_world, 0.0))
	command._park_heading = 0.0
	command._confirm_park()
	check("a click there: refused, the truck stays, the ghost's still up", command._park_truck == truck and truck.ai_status() != "driving")
	command._park_truck = null

	# Disperse with nobody selected: they get out.
	command._clear_selection()
	command._give_order("disperse")
	await wait_for(func(): return truck.driver == null and truck.passenger == null and not truck.busy(), 20.0)
	check("Disperse, nobody selected: everyone in the truck gets out (%s was driving)" % drv.name,
			truck.driver == null and truck.passenger == null and a.riding == null and b.riding == null and a.visible and b.visible)
	command._place_menus()
	check("...and Park's gone", not command._park_button.visible)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
