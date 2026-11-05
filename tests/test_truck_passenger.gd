extends SceneTree
## A squadmate riding in the supply truck (2026-11-03): three selected, a
## command-mode click on the truck sends only the one nearest its passenger
## door, which walks round to the right side and gets in by that door (it
## opens and shuts), and rides in the passenger seat, hidden. The player gets
## in and drives: command mode's ORDERS are Hatch and Crane (no DEPLOY), the
## passenger rides along. An order while moving: it stays in until the truck
## stops, then gets out by its door and carries the order out. Orders with
## nobody selected don't reach it. Prints OK / FAIL.
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func press_f() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	var up := InputEventAction.new()
	up.action = "interact"
	up.pressed = false
	Input.parse_input_event(up)
	for f in 2: await physics_frame


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
	truck.position = Vector2(22.0, 12.6) * PX
	main.add_child(truck)
	var player: CharacterBody2D = main.get_node("Player")
	var command: Node = main.get_node("Command")
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	await physics_frame
	player.global_position = truck.to_global(Vector2(-1.0, -3.0) * PX)
	# Three on the left (the far side from the passenger door), one a little nearer the front.
	var mates := []
	for spot in [Vector2(-1.5, -2.2), Vector2(0.5, -2.2), Vector2(1.5, -2.4)]:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		main.add_child(mate)
		mate.global_position = truck.to_global(spot * PX)
		mates.append(mate)
	for f in 4: await physics_frame
	for mate in mates:
		mate.selected = true
	var door: Vector2 = truck.to_global(Vector2(truck.DOOR_M.x, -truck.DOOR_M.y) * PX)
	var nearest: Node2D = mates.duplicate()[0]
	for mate in mates:
		if mate.global_position.distance_to(door) < nearest.global_position.distance_to(door):
			nearest = mate
	command._click(truck.to_global(Vector2(-1.2, 0.0) * PX), false)   # on the bed
	var riders := mates.filter(func(m): return m.riding == truck)
	check("three selected, a click on the truck: two go (a seat each), the nearest to the passenger door gets that seat",
			riders.size() == 2 and riders.has(nearest) and truck._seats[1].rider == nearest)
	var t := 0.0
	var door_max := 0.0
	var min_y := INF
	while (truck.passenger == null or truck.driver == null) and t < 25.0:
		await physics_frame
		t += 1.0 / 60.0
		door_max = maxf(door_max, absf(truck._doors[1].rotation))
		min_y = minf(min_y, truck.to_local(nearest.global_position).y / PX)
	print("    in after %.1f s; the passenger door opened to %.0f deg" % [t, rad_to_deg(door_max)])
	check("it walks round and gets in by the passenger door (it opens and shuts), hidden, in the passenger seat",
			truck.passenger == nearest and not nearest.visible and door_max > deg_to_rad(70.0) and not truck._doors[1].visible
			and nearest.global_position.distance_to(truck.to_global(Vector2(truck.SEAT_M.x, -truck.SEAT_M.y) * PX)) < 0.1 * PX)
	check("...and the other's in the driver's seat, hidden", truck.driver != null and truck.driver != nearest and not truck.driver.visible)
	command._click(truck.to_global(Vector2(-1.2, 0.0) * PX), false)
	check("a second click on the truck: nobody else goes (both seats are taken)", mates.filter(func(m): return m.riding == truck).size() == 2)
	for mate in mates:
		mate.selected = false
	# The driver's sent off again (the player's to drive in a moment).
	var squad_driver = truck.driver
	truck.unload(squad_driver)
	t = 0.0
	while (truck.driver != null or truck.busy()) and t < 10.0:
		await physics_frame
		t += 1.0 / 60.0
	check("an order sends the squadmate driver out again", truck.driver == null and squad_driver.riding == null and squad_driver.visible)
	squad_driver.global_position = truck.to_global(Vector2(-1.0, -4.0) * PX)

	# The player gets in and drives.
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	for f in 3: await physics_frame
	await press_f()
	t = 0.0
	while truck.driver == null and t < 4.0:
		await physics_frame
		t += 1.0 / 60.0
	command._place_menus()
	check("driving: the player's in the truck, command mode's orders are Hatch and Crane, no DEPLOY",
			player.vehicle == truck and command._vehicle_buttons.all(func(b): return b.visible)
			and command._order_buttons.all(func(b): return not b.visible) and not command._deploy_menu.visible)
	command._give_vehicle_order("hatch")   # (not done yet: just mustn't break)
	command._order_move(truck.global_position + Vector2(0, 6) * PX, command._order_targets())
	check("an order with nobody selected doesn't reach the passenger", truck.passenger == nearest)
	Input.action_press("move_up")
	for f in 240: await physics_frame
	check("it drives off with the passenger riding along in its seat", truck.speed > 1.0 and truck.passenger == nearest
			and nearest.global_position.distance_to(truck.to_global(Vector2(truck.SEAT_M.x, -truck.SEAT_M.y) * PX)) < 0.1 * PX)
	# Selected and sent somewhere while moving: stays in until it stops.
	var goal: Vector2 = truck.global_position + Vector2(0, 5) * PX
	nearest.selected = true
	command._order_move(goal, command._selected())
	nearest.selected = false
	for f in 30: await physics_frame
	check("ordered out while moving: it stays in", truck.passenger == nearest and not nearest.visible)
	Input.action_release("move_up")
	t = 0.0
	var out_door := 0.0
	while (truck.passenger != null or truck.busy()) and t < 8.0:
		await physics_frame
		t += 1.0 / 60.0
		out_door = maxf(out_door, absf(truck._doors[1].rotation))
	for f in 480: await physics_frame   # (the truck drove on past where it was sent: a walk back)
	print("    out once stopped; the passenger door opened to %.0f deg; it's %.2f m from where it was sent" % [rad_to_deg(out_door),
			nearest.global_position.distance_to(goal) / PX])
	check("stopped: it gets out by its door and walks to where it was sent", truck.passenger == null and nearest.visible
			and nearest.riding == null and out_door > deg_to_rad(70.0) and nearest.global_position.distance_to(goal) < 1.0 * PX
			and nearest.collision_mask != 0 and nearest.collision_layer != 0)
	command._place_menus()
	check("the driver's still in: Hatch and Crane still shown", command._vehicle_buttons.all(func(b): return b.visible))
	print("DONE, %d failed" % fails)
	quit()
