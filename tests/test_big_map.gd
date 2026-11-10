extends SceneTree
## The 2-square-mile field and the enemy drop (Mike, 2026-11-09). The arena is
## 2276 m square, centred on the first level's middle (22.5, 12.65 m), so the
## old field sits in its middle. The player can walk out past the old edge.
## The enemy spawner drops 6 enemies by helicopter at a spot 60 m out; they
## land there, each walks a step clear of the door, and they stand calm. The
## drop's ghost: placing makes the player busy, cancelling frees it. A Park
## 120 m away (by road first, then the search) and one beside the old field
## (a window, not the whole 2 km). Run with --fixed-fps 60.
const World = preload("res://scripts/world.gd")
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var side_m := World.ARENA.size.x / PX
	var mid := World.ARENA.get_center() / PX
	check("the arena: %.0f x %.0f m (2 square miles: 2276 m a side), centred on (%.2f, %.2f) m" % [side_m, World.ARENA.size.y / PX, mid.x, mid.y],
			absf(side_m - 2276.0) < 1.0 and is_equal_approx(World.ARENA.size.x, World.ARENA.size.y)
			and mid.distance_to(Vector2(22.5, 12.66)) < 0.05)
	check("the old field (0..45 x 0..25.3 m) is well inside it", World.ARENA.grow(-1000.0 * PX).encloses(Rect2(0, 0, 3840, 2160)))

	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for f in 4: await physics_frame
	var player: CharacterBody2D = main.get_node("Player")
	# Walk east past the old edge (45 m).
	player.global_position = Vector2(44.0, 12.0) * PX
	Input.action_press("move_right")
	for f in 180: await physics_frame
	Input.action_release("move_right")
	check("the player walks out past the old field's edge (now at %.1f m)" % (player.global_position.x / PX), player.global_position.x / PX > 46.0)

	# The enemy drop.
	var spawner: Node = main.get_node("EnemySpawner")
	var before := get_nodes_in_group("enemies").size()
	spawner._start_placing()
	for f in 3: await process_frame
	check("placing a drop: the ghost's up and the player can't fire", spawner._ghost != null and player.busy)
	spawner._stop_placing()
	for f in 3: await process_frame
	check("cancelled: the ghost's gone, the player free", spawner._ghost == null and not player.busy)
	var at := Vector2(80.0, 50.0) * PX
	check("it can land out on the new ground, not off the field", spawner.can_land(at) and not spawner.can_land(World.ARENA.end + Vector2(10, 10)))
	spawner.drop(6, at)
	var t := 0.0
	while get_nodes_in_group("enemies").size() < before + 6 and t < 30.0:
		await physics_frame
		t += 1.0 / 60.0
	check("6 enemies out of the helicopter after %.1f s" % t, get_nodes_in_group("enemies").size() == before + 6)
	for f in 300: await physics_frame
	var foes := get_nodes_in_group("enemies").slice(before)
	var near := foes.all(func(e): return e.global_position.distance_to(at) < 4.0 * PX)
	var calm := foes.all(func(e): return e.is_calm())
	var health := foes.all(func(e): return is_equal_approx(e.max_health, spawner.enemy_health))
	check("they're within 4 m of where it landed, calm, with the spawner's health (%s)" % spawner.enemy_health, near and calm and health)
	var spread := 0.0
	for e: Node2D in foes:
		for o: Node2D in foes:
			if e != o:
				spread = maxf(spread, e.global_position.distance_to(o.global_position) / PX)
	check("...spread out round it, not stacked (%.1f m across)" % spread, spread > 1.5)

	# Parks: one 120 m away (by road, then the search), one near.
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()
	for node in get_nodes_in_group("squad"):
		node.queue_free()
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	main.add_child(truck)
	truck.global_position = Vector2(20.0, 13.3) * PX
	player.global_position = Vector2(20.0, 30.0) * PX
	player.collision_layer = 0
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = Vector2(21.0, 10.0) * PX
	for f in 4: await physics_frame
	mate.order_ride(truck, -1)
	t = 0.0
	while truck.driver != mate and t < 15.0:
		await physics_frame
		t += 1.0 / 60.0
	for c in [[Vector2(28.0, 18.0), 90.0, "near, off the road"], [Vector2(140.0, 20.0), 0.0, "120 m away, off the old field"]]:
		var f0 := Time.get_ticks_msec()
		var ok: bool = truck.order_drive_to(c[0] * PX, deg_to_rad(c[1]))
		var order_ms := Time.get_ticks_msec() - f0
		t = 0.0
		var worst_frame := 0
		while ok and truck.ai_status() == "driving" and t < 150.0:
			var fs := Time.get_ticks_msec()
			await physics_frame
			worst_frame = maxi(worst_frame, Time.get_ticks_msec() - fs)
			t += 1.0 / 60.0
		var off: float = (truck.global_position / PX).distance_to(c[0])
		var turn := absf(rad_to_deg(angle_difference(truck.global_rotation, deg_to_rad(c[1]))))
		print("    %s: %s in %.1f s, %.2f m / %.1f deg off; the order took %d ms, the longest frame %d ms; %s" % [c[2], truck.ai_status(), t, off, turn, order_ms, worst_frame, truck._ai.plan_note])
		check("Park %s: arrived (%.2f m, %.1f deg), no frame over 40 ms" % [c[2], off, turn],
				ok and truck.ai_status() == "arrived" and off < 0.45 and turn < 4.5 and worst_frame <= 40 and order_ms < 200)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
