extends SceneTree
## Driving the supply truck (supply_truck.gd, 2026-11-03): the level with a
## truck of its own in the open; the player walks to its door (the green F's
## the interact target), F gets in (hidden, off the layers, riding at its
## middle), W drives it forward, D steers it right (clockwise, turning about
## its rear axles), let go it coasts to a stop, S reverses; it stops against
## a crate and at the edge of the play area, never overlapping; F gets out by
## the door. Also a bullet at it stops in it. Prints OK / FAIL.
const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")
const World = preload("res://scripts/world.gd")

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


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	for f in roundi(seconds * 60): await physics_frame
	Input.action_release(action)


func overlapping(body: CharacterBody2D) -> bool:
	return body.test_move(body.global_transform, Vector2.ZERO)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	# A clear stretch: everything solid but the player and the field moved out of the way.
	for child in main.get_children():
		if child is CollisionObject2D and child.name != "Player":
			child.queue_free()
		elif child.is_in_group("watch_towers") or child.name.begins_with("Sandbag") or child.name.begins_with("Crate"):
			child.queue_free()
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	truck.position = Vector2(22.0, 12.6) * PX
	main.add_child(truck)
	var player: CharacterBody2D = main.get_node("Player")
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	for f in 2: await physics_frame
	check("the truck starts clear of everything", not overlapping(truck))

	# To the driver's door and in.
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	for f in 3: await physics_frame
	var prompt: Control = truck._prompt_at.get_child(0)
	await process_frame
	check("at the door: the truck is what F works on, its F shown", player.interact_target() == truck and prompt.visible)
	await press_f()
	# Getting in plays out: to the door, the door opens, in under the roof, the door shuts.
	var reached_door := INF
	var door_max := 0.0
	var hidden_at := INF
	var t := 0.0
	var door_spot: Vector2 = truck.to_global(truck.DOOR_M * PX)
	while truck.driver == null and t < 4.0:
		await physics_frame
		t += 1.0 / 60.0
		if reached_door == INF and player.global_position.distance_to(door_spot) < 0.08 * PX:
			reached_door = t
		door_max = maxf(door_max, absf(truck._doors[0].rotation))
		if hidden_at == INF and not player.visible:
			hidden_at = t
	print("    getting in: at the door %.2f s, hidden in the cab %.2f s, driving %.2f s; door opened to %.0f deg, shut again %s" % [
			reached_door, hidden_at, t, rad_to_deg(door_max), not truck._doors[0].visible])
	check("F: walks to the door, the door swings open, in, the door shuts", reached_door < hidden_at and hidden_at < t
			and door_max > deg_to_rad(70.0) and not truck._doors[0].visible and t < 4.0)
	check("in: driving, hidden, off the layers, switched off, in the seat", truck.driver == player and not player.visible
			and player.collision_layer == 0 and player.process_mode == Node.PROCESS_MODE_DISABLED
			and player.global_position.distance_to(truck.to_global(truck.SEAT_M * PX)) < 0.1 * PX)

	# In, the engine stays off (silent) until W turns the ignition (Mike); held,
	# it moves once it's started and booted (its start sound, then boot_pause_s).
	for f in 120: await physics_frame
	check("in, 2 s later with nothing pressed: the engine still off, silent", truck._engine == truck.EngineState.OFF
			and not truck._start.playing and not truck._idle.playing)
	Input.action_press("move_up")
	await physics_frame
	await physics_frame
	check("W: the ignition, its start sound playing", truck._engine == truck.EngineState.STARTING and truck._start.playing)
	var waited := 0.0
	var parked := truck.global_position
	var idle_heard := false
	while truck.global_position.distance_to(parked) < 1.0 and waited < 8.0:
		await physics_frame
		waited += 1.0 / 60.0
		idle_heard = idle_heard or truck._idle.playing
	Input.action_release("move_up")
	var expect: float = truck.SOUND_START.get_length() + truck.boot_pause_s
	print("    W held from the ignition: it set off after %.2f s (start sound %.2f s + boot %.2f s); idle heard %s" % [waited,
			truck.SOUND_START.get_length(), truck.boot_pause_s, idle_heard])
	check("W does nothing until the engine's started and booted", waited > expect - 0.1 and waited < expect + 1.0 and idle_heard)
	check("running: the engine loop heard, pitched up with speed, the start sound done", truck._engine == truck.EngineState.RUNNING
			and truck._idle.playing and truck._idle.pitch_scale > 1.05 and not truck._start.playing)
	for f in 180: await physics_frame
	truck.global_position = parked
	for f in 2: await physics_frame

	# Forward.
	var start := truck.global_position
	await hold("move_up", 2.0)
	var moved: float = (truck.global_position - start).length() / PX
	print("    after 2 s of W: %.2f m at %.2f m/s, heading %.1f deg, player in the seat %s" % [moved, truck.speed,
			rad_to_deg(truck.rotation), player.global_position.distance_to(truck.to_global(truck.SEAT_M * PX)) < 1.0])
	if truck._run:
		print("    at %.1f m/s: running loop at %.1f dB, driving loop at %.1f dB (pitch %.2f)" % [truck.speed, truck._idle.volume_db,
				truck._run.volume_db, truck._run.pitch_scale])
		check("with a driving loop: it's playing at speed, louder than the running one", truck._run.playing
				and truck._run.volume_db > truck._idle.volume_db)
	check("W drives it forward along its heading", moved > 3.0 and absf(truck.rotation) < 0.01
			and (truck.global_position - start).normalized().dot(Vector2.RIGHT) > 0.99
			and player.global_position.distance_to(truck.to_global(truck.SEAT_M * PX)) < 1.0)

	# Steering right while rolling: clockwise.
	Input.action_press("move_up")
	var before := truck.rotation
	await hold("move_right", 1.0)
	Input.action_release("move_up")
	print("    after 1 s of W+D: heading %.1f deg (was %.1f), steer %.1f deg" % [rad_to_deg(truck.rotation), rad_to_deg(before), rad_to_deg(truck.steer)])
	check("D turns it right (clockwise) while rolling", truck.rotation - before > deg_to_rad(20.0))
	var t1: float = truck._tyres[0].rotation
	var t2: float = truck._tyres[2].rotation
	print("    front tyres turned %.1f and %.1f deg, rear %.1f" % [rad_to_deg(t1), rad_to_deg(t2), rad_to_deg(truck._tyres[4].rotation)])
	check("the front two axles' tyres turn with it (the front more), the rear don't",
			t1 > t2 and t2 > deg_to_rad(10.0) and truck._tyres[4].rotation == 0.0)
	for f in 240: await physics_frame
	check("let go: it rolls to a stop and the wheels straighten", truck.speed == 0.0 and truck.steer == 0.0)

	# Standing still, steering doesn't turn it.
	var still := truck.rotation
	await hold("move_left", 0.5)
	check("standing still, A turns the wheels but not the truck", is_equal_approx(truck.rotation, still))
	for f in 30: await physics_frame

	# Reverse.
	var at := truck.global_position
	await hold("move_down", 1.5)
	var back := (truck.global_position - at).dot(Vector2.from_angle(truck.rotation)) / PX
	print("    after 1.5 s of S: %.2f m along its heading, speed %.2f" % [back, truck.speed])
	check("S reverses it", back < -0.5 and truck.speed < 0.0)
	for f in 120: await physics_frame

	# Into a crate: stops, not overlapping.
	truck.rotation = 0.0
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = truck.global_position + Vector2(5.0, 0.0) * PX
	for f in 3: await physics_frame
	await hold("move_up", 3.0)
	var gap := (crate.global_position.x - truck.global_position.x) / PX
	print("    into a crate 5 m ahead: stopped %.2f m short of its middle, speed %.2f" % [gap, truck.speed])
	check("stops dead against a crate, no overlap", gap > 2.4 and gap < 2.8 and not overlapping(truck))
	crate.queue_free()
	for f in 3: await physics_frame

	# The edge of the play area.
	truck.rotation = -PI / 2   # north
	await hold("move_up", 6.0)
	var top := truck.global_position.y / PX
	print("    driving north to the edge: stopped with its middle %.2f m from it" % top)
	check("stops at the edge of the play area", truck._inside_arena() and top < 2.5 and truck.speed < 1.0)
	truck.global_position = Vector2(22.0, 12.6) * PX
	truck.rotation = 0.0
	for f in 3: await physics_frame

	# F while moving: nothing.
	Input.action_press("move_up")
	for f in 30: await physics_frame
	await press_f()
	Input.action_release("move_up")
	check("F while it's moving: stays in", truck.driver == player)
	for f in 240: await physics_frame

	# Out: the door opens, the square steps out beside it, the door shuts.
	await press_f()
	check("F to get out: the engine off, its stop sound playing, the door's opening sound",
			truck._engine == truck.EngineState.OFF and truck._stop.playing and truck._door_sound.playing
			and truck._door_sound.stream == truck.SOUND_DOOR_OPEN)
	var door := truck.to_global(truck.DOOR_M * PX)
	var out_door := 0.0
	t = 0.0
	while (truck.busy()) and t < 4.0:
		await physics_frame
		t += 1.0 / 60.0
		out_door = maxf(out_door, absf(truck._doors[0].rotation))
	print("    getting out: %.2f s, door opened to %.0f deg; at %.2f m from the door spot" % [t, rad_to_deg(out_door),
			player.global_position.distance_to(door) / PX])
	check("F: out by the driver's door, the door opening and shutting (shown, solid, back in hand)", truck.driver == null
			and player.visible and player.collision_layer != 0 and player.collision_mask != 0 and not player.busy
			and player.walk_to == null and player.process_mode == Node.PROCESS_MODE_INHERIT and out_door > deg_to_rad(70.0)
			and not truck._doors[0].visible and player.global_position.distance_to(truck.to_global(truck.CLEAR_M * PX)) < 0.5 * PX and not overlapping(player))   # (out of the door's swing: it shuts after)
	for f in 3: await physics_frame
	check("out, the F shows again at the door", player.interact_target() == truck)

	# The driver's door blocked: in, then out by the other door.
	await press_f()
	for f in 240: await physics_frame
	var block: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(block)
	block.global_position = door
	for f in 3: await physics_frame
	await press_f()
	t = 0.0
	var right_door := 0.0
	while truck.busy() and t < 4.0:
		await physics_frame
		t += 1.0 / 60.0
		right_door = maxf(right_door, absf(truck._doors[1].rotation))
	var other := truck.to_global(Vector2(truck.CLEAR_M.x, -truck.CLEAR_M.y) * PX)
	check("driver's door blocked: out by the other door, which opens (%.0f deg)" % rad_to_deg(right_door),
			truck.driver == null and player.global_position.distance_to(other) < 0.5 * PX and right_door > deg_to_rad(70.0)
			and not overlapping(player))
	block.queue_free()
	for f in 3: await physics_frame

	# A bullet stops in it.
	var shooter: Node2D = load("res://scenes/enemy.tscn").instantiate()
	main.add_child(shooter)
	shooter.global_position = truck.global_position + Vector2(0.0, 6.0) * PX
	for f in 2: await physics_frame
	shooter.set_physics_process(false)
	var b: Node2D = Bullet.new()
	b.setup(shooter.global_position, -PI / 2, 60.0, shooter, 1.0)
	main.add_child(b)
	var last := b.global_position
	for f in 20:
		await physics_frame
		if not is_instance_valid(b):
			break
		last = b.global_position
	check("a bullet at it stops in it (at %.2f m from its middle)" % [(last - truck.global_position).length() / PX],
			not is_instance_valid(b) and (last - truck.global_position).length() / PX < 1.5)
	print("DONE, %d failed" % fails)
	quit()
