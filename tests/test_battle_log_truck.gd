extends SceneTree
## Battle log format 2: the supply truck (2026-11-09). With the log on, a
## squadmate gets in to drive and another to ride as passenger; the truck is
## sent along the road; Crane is selected, a crate lifted onto the bed; the
## truck is slung for a moment (as under a helicopter); Disperse gets them out.
## Then the file is read back and checked for: the truck's M line (once, not
## rewritten as it moves), V lines with its speed, its ~ lines (driver,
## passenger, door steps, engine, ai, crane phase, operator, job, bed, slung),
## its O lines (ride, drive, crane, lift, dismount), and each square's
## vehicle= key (boarding, in its seat, crane, leaving, then -). Prints the
## truck's lines.
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
	player.global_position = Vector2(5, 3) * PX
	var home := Vector2(22.0, 13.0)
	truck.global_position = home * PX
	var driver: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(driver)
	driver.global_position = (home + Vector2(1.5, -3.0)) * PX
	var rider: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(rider)
	rider.global_position = (home + Vector2(1.5, 3.0)) * PX
	for f in 4: await physics_frame
	var log_node: Node = null
	for child in command.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("battle_log.gd"):
			log_node = child
	log_node.start()
	await physics_frame
	var BattleLog = log_node.get_script()
	var dn: int = BattleLog.number_of(driver)
	var rn: int = BattleLog.number_of(rider)

	driver.order_ride(truck, -1)
	rider.order_ride(truck, 1)
	await wait_for(func(): return truck.driver == driver and truck.passenger == rider, 15.0)
	check("both in", truck.driver == driver and truck.passenger == rider)
	for f in 20: await physics_frame
	check("driving to a point on the road", truck.order_drive_to(Vector2(30.0, 12.9) * PX))
	await wait_for(func(): return truck.ai_status() != "driving", 60.0)
	check("arrived", truck.ai_status() == "arrived")
	for f in 90: await physics_frame

	# The crane: a crate beside the bed, lifted on.
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = truck.to_global(Vector2(-1.2, 1.3) * PX)
	for f in 3: await physics_frame
	check("Crane on", truck.vehicle_order("crane"))
	await wait_for(func(): return truck._cphase == truck.CranePhase.WORKING, 60.0)
	check("lift ordered", truck.crane_click(crate.global_position) == "ok")
	await wait_for(func(): return truck._bed[0] == crate and truck._job == null, 120.0)
	check("crate on the bed", truck._bed[0] == crate)
	truck.vehicle_order("crane")   # put away
	await wait_for(func(): return truck._cphase == truck.CranePhase.IDLE, 90.0)

	# Slung a moment: it isn't "gone" from the map.
	truck.set_airborne(true)
	for f in 80: await physics_frame
	truck.set_airborne(false)
	for f in 80: await physics_frame

	truck.dismount_all()
	await wait_for(func(): return truck.driver == null and truck.passenger == null and not truck.busy(), 30.0)
	for f in 30: await physics_frame
	log_node.stop()

	# ---- read it back
	var text := FileAccess.get_file_as_string(log_node._path)
	var tid := ""
	var m_lines := 0
	var v_speed := 0.0
	var v_lines := 0
	var gone := false
	var vkeys := {}      ## key -> [values in order]
	var seats := {}      ## unit number -> [vehicle= values in order]
	var orders := []
	print("---- truck lines")
	for line in text.split("\n"):
		if line.begins_with("#") or line == "":
			continue
		var f := line.split("\t")
		if f[1] == "M" and f[3] == "supply_truck":
			tid = f[2]
			m_lines += 1
			print("  | " + line)
		elif tid != "" and f[1] == "G" and f[2] == tid:
			gone = true
		elif tid != "" and f[1] == "V" and f[2] == tid:
			v_lines += 1
			v_speed = maxf(v_speed, float(f[6]))
		elif f[1] == "~":
			for kv in f.slice(3):
				var k := kv.get_slice("=", 0)
				var v := kv.get_slice("=", 1)
				if f[2] == tid:
					if not vkeys.has(k):
						vkeys[k] = []
					vkeys[k].append(v)
				elif k == "vehicle":
					if not seats.has(f[2]):
						seats[f[2]] = []
					seats[f[2]].append(v)
			if f[2] == tid:
				print("  | " + line)
		elif f[1] == "O":
			if f[2] == tid or f[3] == "ride":
				orders.append(" ".join(f.slice(3)) if f[2] == tid else "ride " + f[2] + " " + " ".join(f.slice(4)))
				print("  | " + line)
	print("---- %d V lines; the driver %d's vehicle=: %s; the passenger %d's: %s" % [v_lines, dn, seats.get(str(dn)), rn, seats.get(str(rn))])
	print("---- orders: %s" % [orders])
	check("the header says format 2", text.contains("format 2"))
	check("the truck's one M line (%d), never written as gone while slung" % m_lines, m_lines == 1 and not gone)
	check("V lines as it drove, up to %.1f m/s" % v_speed, v_lines > 10 and v_speed > 3.0)
	check("~ driver and passenger seats filled by %d and %d, then emptied" % [dn, rn],
			vkeys.get("driver", []) == ["-", str(dn), "-"] and vkeys.get("passenger", []).has(str(rn))
			and vkeys.get("passenger", []).back() == "-")
	var dd: Array = vkeys.get("driver_door", [])
	check("driver_door steps: TO_DOOR,%d ... CLOSING ... CLOSING_OUT" % dn, dd.has("TO_DOOR,%d" % dn)
			and dd.has("CLOSING,%d" % dn) and dd.has("STEP_OUT,%d" % dn) and dd.back() == "-")
	check("engine RUNNING then OFF", vkeys.get("engine", []).has("RUNNING") and vkeys.get("engine", []).back() == "OFF")
	check("ai driving with a destination, then arrived", vkeys.get("ai", []).has("driving") and vkeys.get("ai", []).has("arrived")
			and vkeys.get("ai_to", []).has("30.00,12.90"))
	check("crane phases through to WORKING and back to IDLE, operator %d" % rn, vkeys.get("crane", []).has("WORKING")
			and vkeys.get("crane", []).back() == "IDLE" and vkeys.get("operator", []).has(str(rn)))
	var jobs: Array = vkeys.get("job", [])
	check("job lines: load,<crate>,REACH ... LOWER", jobs.any(func(j): return j.begins_with("load,o") and j.ends_with("REACH"))
			and jobs.any(func(j): return j.ends_with("LOWER")))
	check("bed: the crate in the back spot", vkeys.get("bed", []).any(func(b): return b.begins_with("o") and b.ends_with(",-")))
	check("slung 1 then 0", vkeys.get("slung", []) == ["0", "1", "0"])
	var ds: Array = seats.get(str(dn), [])
	check("the driver's vehicle=: boarding_driver, driver, leaving_driver, -",
			ds == ["%s:boarding_driver" % tid, "%s:driver" % tid, "%s:leaving_driver" % tid, "-"])
	var ps: Array = seats.get(str(rn), [])
	check("the passenger's vehicle=: ... passenger, crane, boarding_passenger (going back), ... -",
			ps.has("%s:passenger" % tid) and ps.has("%s:crane" % tid) and ps.count("%s:boarding_passenger" % tid) == 2
			and ps.back() == "-")
	check("orders: ride x2, drive ok, crane on ok, lift ok, crane off, dismount",
			orders.size() == 7 and orders[2].begins_with("drive 30.00,12.90 - %d ok" % dn) and orders[3] == "crane on ok"
			and orders[4].begins_with("lift ") and orders[4].ends_with(" ok") and orders[5] == "crane off ok" and orders[6] == "dismount")
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
