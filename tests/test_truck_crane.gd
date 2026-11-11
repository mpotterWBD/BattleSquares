extends SceneTree
## The supply truck's crane (2026-11-04), and S starting the engine. A squadmate
## rides as passenger, the player drives. Selecting Crane deploys it at once: the
## passenger gets out (once stopped), walks to the controls, stands half a second,
## the stabilisers come down; they stay down (also with the driver out) until Crane
## is deselected or W/S is pressed, when the crane is put away and the operator
## back in before the truck moves. Crates clicked in the circle load furthest back
## first (a crate in the squares beside the bed); Crane held gives 1 or 2 boxes and a ghost on the side the mouse is on, unloading nearest first; the exit box blocked refuses Crane.
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


var min_gap := INF   ## the closest a visible rider's middle got to the open right door's panel (m)


## Notes how close `rider` is to the passenger's door panel while it's open or swinging: a square is
## 0.4 m (0.2 to its side), so under that and the door's cutting through it.
func note_door_gap(truck: Node2D, rider: Node2D) -> void:
	if truck._door_open[1] <= 0.05 or not rider.visible:
		return
	var door: Node2D = truck._doors[1]
	var a: Vector2 = door.position / PX
	var b: Vector2 = a + Vector2(-0.62, 0.0).rotated(door.rotation)
	var p: Vector2 = truck.to_local(rider.global_position) / PX
	min_gap = minf(min_gap, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))


## Waits (physics ticks) until `cond` is true or `limit_s` passes; the time it took.
func wait_for(cond: Callable, limit_s: float) -> float:
	var t := 0.0
	while not cond.call() and t < limit_s:
		await physics_frame
		t += 1.0 / 60.0
	return t


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
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = truck.to_global(Vector2(0.5, 2.6) * PX)
	for f in 4: await physics_frame

	# The squadmate rides, the player drives.
	mate.selected = true
	command._click(truck.to_global(Vector2(-1.2, 0.0) * PX), false)
	mate.selected = false
	var t := 0.0
	while truck.passenger == null and t < 15.0:
		await physics_frame
		t += 1.0 / 60.0
		note_door_gap(truck, mate)
	check("the squadmate's riding as the passenger", truck.passenger == mate)
	print("    getting in: closest to the door panel %.2f m" % min_gap)
	check("getting in, the open door never cuts through the square (always 0.2 m or more off its middle)", min_gap >= 0.2)
	min_gap = INF
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	for f in 3: await physics_frame
	await press_f()
	t = 0.0
	while truck.driver == null and t < 4.0:
		await physics_frame
		t += 1.0 / 60.0
	check("the player's driving", truck.driver == player)

	# S starts the engine (as W does).
	check("engine off before", truck._engine == truck.EngineState.OFF)
	Input.action_press("move_down")
	for f in 4: await physics_frame
	Input.action_release("move_down")
	check("S starts the engine", truck._engine != truck.EngineState.OFF)
	t = 0.0
	while truck._engine != truck.EngineState.RUNNING and t < 6.0:
		await physics_frame
		t += 1.0 / 60.0
	check("...and it's running", truck._engine == truck.EngineState.RUNNING)


	# Selecting Crane is when it deploys (nothing before).
	check("not armed, nothing deployed before the order", not truck.crane_armed() and truck._cphase == truck.CranePhase.IDLE)
	check("the boom reaches the far corners of both squares beside the bed (%.1f m)" % truck.crane_reach_m, truck.crane_reach_m >= 3.4)
	check("slow: 22 deg/s turret, 0.4 m/s boom, 2.5 s lifts, 4 s stabilisers",
			truck.crane_slew_dps <= 25.0 and truck.boom_mps <= 0.5 and truck.lift_s >= 2.0
			and truck.stabilizer_down_s >= 3.5 and truck.stabilizer_up_s >= 3.5)
	check("driving: the squad-order Crane button isn't up (Hatch/Crane are)", not command._crane_button.visible)
	# A truck click (command mode): the HUD says how many units are in it; the seat's taken, so the rider's selected.
	command._click(truck.to_global(Vector2(-1.5, 0.3) * PX), false)   # the far end of the bed: not the door
	check("a click on the bed: a HUD, 'Units inside: 1'", command._truck_hud.visible and command._truck_hud_text.text.begins_with("Units inside: 1"))
	check("...and the truck isn't selected (it can't be: its driver's ordered with Park)", not command.has_method("selected_truck") and not mate.selected)
	command._clear_selection()
	# A square in the passenger's exit box: Crane's refused, nothing deploys.
	var blocker: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(blocker)
	blocker.global_position = truck.to_global(truck.EXIT_BOX_M * PX)
	for f in 3: await physics_frame
	command._give_vehicle_order("crane")
	check("something in the exit box: Crane's refused, nothing deploys", not truck.crane_armed() and truck._cphase == truck.CranePhase.IDLE)
	blocker.queue_free()
	for f in 3: await physics_frame
	check("...and the box is clear again once it's gone", truck._operator_can_get_out())

	# Two crates in the circle (and one beyond it), on the passenger's side.
	var crates := []
	for spot in [Vector2(-0.6, 1.3), Vector2(-1.8, 1.3), Vector2(-0.6, 3.0)]:   # (the third is outside the squares)
		var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
		main.add_child(crate)
		crate.global_position = truck.to_global(spot * PX)
		crate.rotation = 0.4
		crates.append(crate)
	for f in 3: await physics_frame

	# Crane selected, no crate clicked: it deploys, phase by phase.
	command._give_vehicle_order("crane")
	check("Crane selected: armed, and the passenger's getting out already", truck.crane_armed() and truck._cphase == truck.CranePhase.WAIT_STOP)
	var phases := []
	var settle_s := 0.0
	var stab_at_settle_end := -1.0
	var station_ok := false
	var rifle_out := false
	var prev := -1
	t = 0.0
	while truck._cphase != truck.CranePhase.WORKING and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
		if truck._cphase != prev:
			prev = truck._cphase
			phases.append(prev)
			print("    t=%.1f  phase %d  stab %.2f" % [t, prev, truck._stab])
		note_door_gap(truck, mate)
		if truck._cphase == truck.CranePhase.SETTLING:
			settle_s += 1.0 / 60.0
			station_ok = mate.global_position.distance_to(truck._station_world()) < 0.2 * PX
			if truck._stab > 0.0:
				stab_at_settle_end = truck._stab
		if truck._cphase >= truck.CranePhase.WALKING and truck._operator != null:
			if not mate.weapon_away or mate.get_node("Rifle").visible:
				rifle_out = true
	print("    deployed at t=%.1f; phases %s" % [t, phases])
	check("phases in order: waiting, walking, settling, deploying, working",
			phases == [truck.CranePhase.WAIT_STOP, truck.CranePhase.WALKING, truck.CranePhase.SETTLING,
			truck.CranePhase.DEPLOYING, truck.CranePhase.WORKING])
	check("the operator stood at the controls (STATION_M) for the half second before the stabilisers",
			station_ok and settle_s >= truck.station_hold_s - 0.05 and settle_s < truck.station_hold_s + 0.2 and stab_at_settle_end < 0.0)
	check("the operator had no rifle out from the door on", not rifle_out and mate.weapon_away)
	check("deployed with no crate clicked: stabilisers down, no job, still armed", truck._stab == 1.0 and truck._job == null
			and truck._jobs.is_empty() and truck.crane_armed())
	print("    getting in and out: closest to the door panel %.2f m" % min_gap)
	check("getting in and out, the door never cuts through the square (0.2 m or more off its middle)", min_gap >= 0.2)

	# Clicks while it's deployed.
	check("a crate outside the squares: refused", truck.crane_click(crates[2].global_position) == "no" and truck._jobs.is_empty())
	check("empty ground: not the crane's click", truck.crane_click(truck.to_global(Vector2(0.5, 3.4) * PX)) == "")
	command._click(crates[0].global_position, false)
	command._click(crates[1].global_position, false)
	command._click(crates[0].global_position, false)
	check("two crates queued (the same one twice: once)", truck._jobs.size() + (1 if truck._job != null else 0) == 2)
	# The driver gets out meanwhile.
	var got_out: bool = truck.get_out()
	check("the driver gets out during the work", got_out)
	var seen_boom := 0.0
	t = 0.0
	while (truck._bed[0] == null or truck._bed[1] == null or truck._job != null) and t < 200.0:
		await physics_frame
		t += 1.0 / 60.0
		seen_boom = maxf(seen_boom, truck._boom_ext)
		note_door_gap(truck, mate)
	print("    both loaded at t=%.1f" % t)
	check("the boom slid out past the arm to reach a crate (%.2f m)" % seen_boom, seen_boom > 0.8)
	check("both crates are on the bed: the first in the furthest back spot, the second in the nearer",
			truck._bed[0] == crates[0] and truck._bed[1] == crates[1]
			and truck.to_local(crates[0].global_position).distance_to(Vector2(truck.SLOT_X_M[0], 0.0) * PX) < 2.0
			and truck.to_local(crates[1].global_position).distance_to(Vector2(truck.SLOT_X_M[1], 0.0) * PX) < 2.0)
	check("loaded crates ride the truck (children of it), not solid, not looked up as crates",
			crates[0].get_parent() == truck and crates[0].mounted and not crates[0].is_in_group("crates")
			and crates[0].get_node("Collision").disabled)
	# It stays deployed: nothing puts it away by itself.
	for f in 600: await physics_frame
	check("ten seconds after the last job it's still deployed: stabilisers down, operator out, Crane still selected",
			truck._stab == 1.0 and truck._cphase == truck.CranePhase.WORKING and truck._operator == mate and truck.crane_armed())
	check("the driver's out and the truck hasn't moved", player.vehicle == null and truck.speed == 0.0)
	command._place_menus()
	check("the player's outside and a passenger belongs to the truck: Crane is among the normal orders",
			command._crane_button.visible and not command._vehicle_buttons[0].visible)

	# The driver gets back in, and unloads (the opposite order) while still deployed.
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	for f in 3: await physics_frame
	await press_f()
	t = await wait_for(func(): return truck.driver != null, 5.0)
	check("the driver's back in, the crane still deployed", truck.driver == player and truck._stab == 1.0)
	# Setting them down: hold Crane, 1 or 2 boxes, a ghost on the side the mouse is on, a click.
	check("two crates loaded: the drop-off counts them", truck.loaded_count() == 2)
	check("a click on the bed or on empty ground isn't the crane's (the squad's own click then)",
			truck.crane_click(truck.to_global(Vector2(-1.0, 0.0) * PX)) == "" and truck.crane_click(truck.to_global(Vector2(0.4, 6.5) * PX)) == "")
	var one: PackedVector2Array = truck.crane_drop_spots(1, 1)
	var two: PackedVector2Array = truck.crane_drop_spots(2, -1)
	check("1 box on the right: one spot, 1.3 m out from the nearer crate's bed spot",
			one.size() == 1 and truck.to_local(one[0]).distance_to(Vector2(truck.SLOT_X_M[1], truck.DROP_Y_M) * PX) < 1.0)
	check("2 boxes on the left: two spots, at both bed spots, 1.3 m out that side",
			two.size() == 2 and truck.to_local(two[0]).distance_to(Vector2(truck.SLOT_X_M[1], -truck.DROP_Y_M) * PX) < 1.0
			and truck.to_local(two[1]).distance_to(Vector2(truck.SLOT_X_M[0], -truck.DROP_Y_M) * PX) < 1.0)
	check("3 boxes: refused (only two on it)", not truck.crane_drop(3, 1) and truck.crane_drop_spots(3, 1).size() == 2)
	var blocker2: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(blocker2)
	blocker2.global_position = one[0]
	for f in 3: await physics_frame
	check("something on the spot: it can't be set down there", not truck.crane_drop_clear(1, 1) and not truck.crane_drop(1, 1))
	blocker2.queue_free()
	await physics_frame
	await physics_frame
	# The command mode flow.
	command._open_crane_popout(command._vehicle_buttons[1], true)
	check("holding Crane opens the 1 / 2 boxes pop-out for the truck", command._crane_menu_truck == truck)
	command._start_crane_drop(1)
	command._mouse_world = truck.to_global(Vector2(0.0, -3.0) * PX)
	check("1 box chosen, the mouse on the left of the truck: the ghost's on the left", command._crane_drop_truck == truck and command._crane_drop_side() == -1)
	command._mouse_world = truck.to_global(Vector2(0.0, 3.0) * PX)
	check("...and on the right with the mouse there", command._crane_drop_side() == 1)
	command._confirm_crane_drop()   # (the mouse is on the right)
	check("a click sets it down: one unload queued, the mode over",
			truck._jobs.size() + (1 if truck._job != null else 0) == 1 and command._crane_drop_truck == null)
	t = await wait_for(func(): return truck._bed[1] == null and truck._job == null and truck._jobs.is_empty(), 200.0)
	check("the nearer crate (the second) came off first, down on the right, solid, in the crates group",
			not crates[1].mounted and crates[0].mounted and crates[1].is_in_group("crates") and crates[1].get_parent() == main
			and truck.to_local(crates[1].global_position).distance_to(Vector2(truck.SLOT_X_M[1], truck.DROP_Y_M) * PX) < 1.0)
	command._open_crane_popout(command._vehicle_buttons[1], true)
	command._start_crane_drop(1)
	command._mouse_world = truck.to_global(Vector2(0.0, -3.0) * PX)
	command._confirm_crane_drop()
	t = await wait_for(func(): return truck._bed[0] == null and truck._job == null and truck._jobs.is_empty(), 200.0)
	check("the other, with the mouse on the left, down on the left side; the bed's empty",
			not crates[0].mounted and truck._bed == [null, null]
			and truck.to_local(crates[0].global_position).distance_to(Vector2(truck.SLOT_X_M[0], -truck.DROP_Y_M) * PX) < 1.0)
	check("nothing loaded: holding Crane has no pop-out to open (the old one stays)", truck.loaded_count() == 0)

	# Driving off: the stabilisers come up and the operator gets in first; only then does it move.
	var order := []
	var moved_early := false
	Input.action_press("move_up")
	prev = -1
	t = 0.0
	while truck._cphase != truck.CranePhase.IDLE or t < 1.0:
		await physics_frame
		t += 1.0 / 60.0
		if truck._cphase != prev:
			prev = truck._cphase
			order.append(prev)
		if truck._cphase != truck.CranePhase.IDLE and absf(truck.speed) > 0.01:
			moved_early = true
		if t > 120.0:
			break
	print("    put away for driving off at t=%.1f; phases %s" % [t, order])
	check("W: stowing, then the operator walks back in, and only then idle", order.has(truck.CranePhase.STOWING)
			and order.find(truck.CranePhase.RETURNING) > order.find(truck.CranePhase.STOWING) and order.back() == truck.CranePhase.IDLE)
	check("it didn't move until the stabilisers were up and the operator in", not moved_early and truck._stab == 0.0
			and truck.passenger == mate and not mate.visible and not mate.weapon_away)
	check("Crane's deselected by driving off", not truck.crane_armed())
	t = await wait_for(func(): return truck.speed > 1.0, 12.0)
	check("then it drives off (%.1f s later), as normal" % t, truck.speed > 1.0)
	Input.action_release("move_up")
	for f in 400: await physics_frame
	check("...and rolls to a stop", truck.speed == 0.0)

	# Deselecting Crane puts it away too.
	command._give_vehicle_order("crane")
	t = await wait_for(func(): return truck._cphase == truck.CranePhase.WORKING, 60.0)
	check("Crane selected again: deployed", truck._cphase == truck.CranePhase.WORKING and truck._stab == 1.0)
	command._give_vehicle_order("crane")
	check("pressed again: deselected", not truck.crane_armed())
	t = await wait_for(func(): return truck._cphase == truck.CranePhase.IDLE, 60.0)
	check("...and put away: stabilisers up, boom in, operator back in the seat", truck._stab == 0.0 and truck._boom_ext == 0.0
			and absf(truck._slew) < 0.01 and truck.passenger == mate and truck._operator == null and mate.riding == truck)

	# The operator given another order mid-deploy is let go and it stows itself.
	command._give_vehicle_order("crane")
	t = await wait_for(func(): return truck._cphase == truck.CranePhase.DEPLOYING, 30.0)
	check("selected again: deploying", truck._cphase == truck.CranePhase.DEPLOYING)
	mate.selected = true
	command._order_move(mate.global_position + Vector2(3, 3) * PX, command._selected())
	mate.selected = false
	t = await wait_for(func(): return truck._cphase == truck.CranePhase.IDLE, 90.0)
	check("the operator was let go: the crane stowed itself, the operator's its own again, not riding, rifle back",
			truck._cphase == truck.CranePhase.IDLE and truck._stab == 0.0 and mate.riding == null and truck.passenger == null
			and not mate.weapon_away and not truck.crane_armed())
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
