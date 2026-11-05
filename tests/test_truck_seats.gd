extends SceneTree
## Clicking the supply truck in command mode (Mike, 2026-11-04): one unit selected
## goes to the seat on the side of the cab clicked (right the passenger's, left the
## driver's); two or more selected fill both seats; with a squadmate at the wheel and
## nothing selected the click selects the truck, which is then sent where a click
## (or right click) on the ground says, stopped with Stop, and emptied with Disperse.
## A rider hidden in the cab isn't a click target of its own. Prints OK / FAIL.
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
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	await physics_frame
	var home := Vector2(22.0, 13.0)
	truck.global_position = home * PX
	player.global_position = (home + Vector2(-3.0, 4.0)) * PX
	var mates := []
	for spot in [Vector2(0.0, -3.5), Vector2(1.5, -3.5), Vector2(3.0, -3.5)]:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		main.add_child(mate)
		mate.global_position = truck.to_global(spot * PX + Vector2(0, -2.0) * PX)
		mates.append(mate)
	for f in 6: await physics_frame
	command._clear_selection()
	var right := truck.to_global(Vector2(1.5, 0.5) * PX)   # the passenger's side of the cab
	var left := truck.to_global(Vector2(1.5, -0.5) * PX)

	# One unit, the right side of the cab: the passenger's seat.
	mates[0].selected = true
	command._click(right, false)
	check("one unit selected, the right of the cab clicked: it's sent to the passenger's seat",
			truck._seats[1].rider == mates[0] and truck._seats[0].rider == null and mates[0].riding == truck)
	await wait_for(func(): return truck.passenger != null, 25.0)
	check("...and it's in the passenger's seat", truck.passenger == mates[0] and truck.driver == null)
	# Out again, then one unit, the left side: the driver's seat.
	command._clear_selection()
	command._click(truck.global_position, false)
	check("nothing selected, the truck clicked: the truck's selected (the rider hidden in the cab isn't picked)",
			command.selected_truck() == truck and not mates[0].selected)
	command._give_order("disperse")
	await wait_for(func(): return truck.passenger == null and not truck.busy(), 12.0)
	check("Disperse with the truck selected: everyone in it gets out", truck.passenger == null and mates[0].riding == null)
	command._clear_selection()
	mates[1].selected = true
	command._click(left, false)
	check("one unit selected, the left of the cab clicked: it's sent to the driver's seat",
			truck._seats[0].rider == mates[1] and truck._seats[1].rider == null)
	await wait_for(func(): return truck.driver != null, 25.0)
	check("...and it's in the driver's seat", truck.driver == mates[1] and truck.ai_driver == mates[1])
	# A second unit to the seat that's taken: refused; to the free one: goes.
	command._clear_selection()
	mates[0].selected = true
	command._click(left, false)
	check("a unit sent to the seat that's taken: refused", mates[0].riding == null)
	command._click(right, false)
	check("...and to the other side's free seat: goes", truck._seats[1].rider == mates[0])
	await wait_for(func(): return truck.passenger != null, 25.0)
	check("both seats full", truck.passenger == mates[0] and truck.driver == mates[1] and truck.units_inside() == 2)
	command._clear_selection()

	# The truck, selected, is sent places like a unit.
	command._click(left, false)
	check("nothing selected, the truck clicked (a squadmate driving): the truck's selected, a HUD says 2 units",
			command.selected_truck() == truck and command._truck_hud.visible and command._truck_hud_text.text.begins_with("Units inside: 2"))
	var there := Vector2(30.0, 12.9)
	command._click(there * PX, false)
	check("a click on the ground: it's driving there", truck.ai_status() == "driving")
	await wait_for(func(): return truck.ai_status() != "driving", 60.0)
	check("it got there (%s), %.1f m off" % [truck.ai_status(), truck.global_position.distance_to(there * PX) / PX],
			truck.ai_status() == "arrived" and truck.global_position.distance_to(there * PX) < 1.5 * PX)
	command._order_move(Vector2(16.0, 11.5) * PX)   # (a right click)
	check("a right click on the ground sends it too", truck.ai_status() == "driving")
	await wait_for(func(): return truck.speed > 2.0 or truck.ai_status() != "driving", 20.0)
	command._give_order("stop")
	await wait_for(func(): return absf(truck.speed) < 0.1, 10.0)
	check("Stop halts it", truck.ai_status() == "idle" and absf(truck.speed) < 0.1)
	# Units selected: clicking the ground moves them, not the truck.
	command._clear_selection()
	mates[2].selected = true
	var before := truck.global_position
	command._click(Vector2(35.0, 20.0) * PX, false)
	for f in 30: await physics_frame
	check("a unit selected: a click on the ground sends the unit, the truck stays", truck.global_position.distance_to(before) < 0.1 * PX
			and truck.ai_status() == "idle" and mates[2].is_moving())
	# Two or more selected: both seats at once (after emptying it).
	command._clear_selection()
	command._click(truck.to_global(Vector2(1.5, -0.5) * PX), false)   # (the truck has driven off: where its cab is now)
	command._give_order("disperse")
	await wait_for(func(): return truck.driver == null and truck.passenger == null and not truck.busy(), 20.0)
	check("emptied again", truck.driver == null and truck.passenger == null)
	command._clear_selection()
	for m in mates:
		m.selected = true
	command._click(truck.to_global(Vector2(-1.0, -0.3) * PX), false)   # the bed, on the left
	var in_seats := [truck._seats[0].rider, truck._seats[1].rider]
	check("three units selected, the truck clicked: two go, one to each seat",
			in_seats[0] != null and in_seats[1] != null and in_seats[0] != in_seats[1])
	await wait_for(func(): return truck.driver != null and truck.passenger != null, 30.0)
	check("...and they're in", truck.driver != null and truck.passenger != null and truck.units_inside() == 2)
	check("...the third stayed out", mates.filter(func(m): return m.riding == truck).size() == 2)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
