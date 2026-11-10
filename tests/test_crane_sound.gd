extends SceneTree
## The crane's sounds (Mike, 2026-11-09): its hydraulics (crane_move.wav) play
## while the turret turns or the boom slides, and fade out over the last
## moments of each move, so by the time it stops they're gone (no sudden cut);
## its winch (winch.wav) plays while the line takes the crate up or lets it
## down, a little lower going down, fading out the same way. A crate's lifted
## onto the bed, start to finish. Prints, per step of the job, how loud each
## got and how it ended. Run with --fixed-fps 60.
const PX := 1024.0 / 12.0

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
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates") + get_nodes_in_group("vehicles") + get_nodes_in_group("trees"):
		node.queue_free()
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	truck.position = Vector2(22.0, 13.3) * PX
	main.add_child(truck)
	main.get_node("Player").global_position = Vector2(22.0, 25.0) * PX
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = truck.to_global(Vector2(0.5, 2.6) * PX)
	for f in 4: await physics_frame
	mate.order_ride(truck, 1)
	var t := 0.0
	while truck.passenger != mate and t < 15.0:
		await physics_frame
		t += 1.0 / 60.0
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = truck.to_global(Vector2(-1.8, 1.3) * PX)
	for f in 3: await physics_frame
	truck.vehicle_order("crane")
	t = 0.0
	var stab_max := 0.0
	var stab_drop := 0.0
	var stab_last := 0.0
	# The sequence (Mike, 2026-11-09): out, at the controls, half a second, the
	# switch, the motor on at once, a second of it, then the stabilisers drop.
	var at_controls := -1.0
	var switched := -1.0
	var motor_full := -1.0
	var stab_moved := -1.0
	var switches := 0
	while truck._cphase != truck.CranePhase.WORKING and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
		if at_controls < 0.0 and truck._cphase == truck.CranePhase.SETTLING:
			at_controls = t
		if truck._switch_snd.playing:   # (stopped once counted: see the start click below)
			switches += 1
			if switched < 0.0:
				switched = t
			truck._switch_snd.stop()
		if motor_full < 0.0 and truck._motor_level >= 0.99:
			motor_full = t
		if stab_moved < 0.0 and truck._stab > 0.0:
			stab_moved = t
		stab_max = maxf(stab_max, truck._stab_level)
		stab_drop = maxf(stab_drop, stab_last - truck._stab_level)
		stab_last = truck._stab_level
	print("    at the controls %.2f s, switch %.2f, motor full %.2f, stabilisers moving %.2f" % [at_controls, switched, motor_full, stab_moved])
	check("at the controls, half a second, then the switch (%.2f s after)" % (switched - at_controls),
			at_controls > 0.0 and absf(switched - at_controls - 0.5) < 0.1 and switches == 1)
	check("the motor on at once (full %.2f s after the switch), playing" % (motor_full - switched),
			motor_full >= switched and motor_full - switched < 0.3 and truck._motor_snd.playing)
	check("a second of motor before the stabilisers drop (%.2f s)" % (stab_moved - switched), absf(stab_moved - switched - 1.0) < 0.1)
	await physics_frame
	await physics_frame
	check("the stabilisers coming down: their sound, full (%.2f), %.2f as they're down, then off; no sudden cut (%.3f a tick at most)" % [stab_max, stab_last, stab_drop],
			stab_max > 0.9 and stab_last < 0.05 and stab_drop < 0.1 and not truck._stab_snd.playing)
	check("volumes: boom -8 dB, winch -6 dB (20% lower), stabilisers -6 dB", truck.crane_volume_db == -8.0
			and truck.winch_volume_db == -6.0 and truck.stabilizer_volume_db == -6.0)
	check("the crane's deployed, both sounds quiet", truck._cphase == truck.CranePhase.WORKING and not truck._crane_snd.playing
			and not truck._winch_snd.playing)
	check("the crate's taken", truck.crane_click(crate.global_position) == "ok")
	# Watch it, tick by tick, through the job.
	var names := ["REACH", "LIFT", "SWING", "LOWER"]
	var stats := {}   # step -> {crane_max, winch_max, crane_end, winch_end, worst_drop, pitch}
	var last_step := -1
	var worst_drop := 0.0
	var last_crane := 0.0
	var last_winch := 0.0
	var crane_when_still := 0.0   # the crane's level while neither turret nor boom moved
	var prev := Vector2(truck._slew, truck._boom_ext)
	t = 0.0
	while (truck._job != null or truck._bed[0] == null) and t < 120.0:
		await physics_frame
		t += 1.0 / 60.0
		var job = truck._job
		var step: int = job.step if job != null else -1
		if step != last_step and last_step >= 0:
			stats[names[last_step]].crane_end = last_crane
			stats[names[last_step]].winch_end = last_winch
		if step >= 0 and not stats.has(names[step]):
			stats[names[step]] = {crane_max = 0.0, winch_max = 0.0, crane_end = 0.0, winch_end = 0.0, pitch = 1.0, clicks = 0}
		last_step = step
		# (Stopped once counted: headless audio plays in real time, slower than
		# this fixed-fps run, so the swing's click could find the reach's still
		# "playing" and restart it unseen.)
		if truck._crane_start_snd.playing:
			if step >= 0:
				stats[names[step]].clicks += 1
			truck._crane_start_snd.stop()
		var c: float = truck._crane_level
		var w: float = truck._winch_level
		worst_drop = maxf(worst_drop, maxf(last_crane - c, last_winch - w))
		var now := Vector2(truck._slew, truck._boom_ext)
		if now.is_equal_approx(prev):
			crane_when_still = maxf(crane_when_still, c * (1.0 if not truck._crane_snd.playing else 1.0))
		prev = now
		if step >= 0:
			var s: Dictionary = stats[names[step]]
			s.crane_max = maxf(s.crane_max, c)
			s.winch_max = maxf(s.winch_max, w)
			if w > 0.5:
				s.pitch = truck._winch_snd.pitch_scale
		last_crane = c
		last_winch = w
	for k in names:
		if stats.has(k):
			var s: Dictionary = stats[k]
			print("    %s: crane up to %.2f, ended at %.2f; winch up to %.2f (pitch %.2f), ended at %.2f; start clicks %d" % [k, s.crane_max, s.crane_end, s.winch_max, s.pitch, s.winch_end, s.clicks])
	check("the crate's on the bed", truck._bed[0] == crate)
	check("REACH and SWING (the boom moving): the crane's sound, full, gone by the time each stops; no winch",
			stats.REACH.crane_max > 0.9 and stats.SWING.crane_max > 0.9 and stats.REACH.crane_end < 0.05
			and stats.SWING.crane_end < 0.05 and stats.REACH.winch_max == 0.0 and stats.SWING.winch_max == 0.0)
	check("LIFT and LOWER (the line moving): the winch, full, gone by the end; lower going down (%.2f)" % stats.LOWER.pitch,
			stats.LIFT.winch_max > 0.9 and stats.LOWER.winch_max > 0.9 and stats.LIFT.winch_end < 0.05
			and stats.LOWER.winch_end < 0.05 and stats.LOWER.pitch < 1.0 and is_equal_approx(stats.LIFT.pitch, 1.0))
	check("the start click: once as the boom starts each move (REACH, SWING), never for the line (LIFT, LOWER)",
			stats.REACH.clicks == 1 and stats.SWING.clicks == 1 and stats.LIFT.clicks == 0 and stats.LOWER.clicks == 0)
	check("never a sudden cut: the most either dropped in a tick was %.3f (a fade over 0.4 s drops about 0.04)" % worst_drop, worst_drop < 0.1)
	check("the crane's quiet while the boom isn't moving (%.2f at most, its fade's tail aside)" % crane_when_still, crane_when_still < 0.2)
	for f in 30: await physics_frame
	check("both stopped after the job", not truck._crane_snd.playing and not truck._winch_snd.playing)
	check("the motor ran through the job (%.2f)" % truck._motor_level, truck._motor_level >= 0.99 and truck._motor_snd.playing)
	# Put away: the stabilisers go up, with their sound; then the switch, and the motor runs down.
	# (The tick they're up it's switched off, so its last reading here is already running down: 0.97.)
	truck.vehicle_order("crane")
	stab_max = 0.0
	t = 0.0
	var motor_while_stowing := 1.0
	while truck._stab > 0.0 and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
		stab_max = maxf(stab_max, truck._stab_level)
		stab_last = truck._stab_level
		motor_while_stowing = minf(motor_while_stowing, truck._motor_level)
	var off_switch := false
	for f in 60:
		await physics_frame
		off_switch = off_switch or truck._switch_snd.playing
	check("the stabilisers going up: their sound, full (%.2f), %.2f as they're up, then off" % [stab_max, stab_last],
			stab_max > 0.9 and stab_last < 0.05 and not truck._stab_snd.playing)
	check("put away: the motor ran till the stabilisers were up (%.2f), then the switch, and it's off" % motor_while_stowing,
			motor_while_stowing >= 0.9 and off_switch and truck._motor_level == 0.0 and not truck._motor_snd.playing)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
