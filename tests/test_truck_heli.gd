extends SceneTree
## The supply truck deployed by helicopter (radio_terminal.gd's Vehicles,
## sling_drop.gd, 2026-11-03): at a radio station's terminal, Deploy >
## Vehicles, the slot filled with a Supply truck, readied, Send helicopter:
## the LZ ghost is OK in the open and red on a crate and off the field; sent,
## a helicopter flies in with the truck slung under it (up in the air, off
## every collision layer, drawn bigger), lowers it, lets go at the LZ (on the
## ground, solid, nose east) and flies away; then the player drives it.
## Prints OK / FAIL.
const World = preload("res://scripts/world.gd")
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
	var station: Node2D = load("res://scenes/radio_station.tscn").instantiate()
	station.position = Vector2(8.0, 5.0) * PX
	main.add_child(station)
	var player: CharacterBody2D = main.get_node("Player")
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	await physics_frame
	var terminal: Node = station.get_node("Terminal")
	player.global_position = station.get_node("StandBox").global_position
	for f in 3: await physics_frame
	terminal.open_menu()
	terminal._on_kind_chosen("vehicles", Vector2.ZERO)
	for f in 2: await process_frame
	check("Deploy > Vehicles: the vehicle request shows", terminal.screen == terminal.Screen.VEHICLES and terminal._vehicle_panel.visible)
	terminal._on_vehicle_chosen("supply_truck", Vector2.ZERO)
	check("the slot filled with a Supply truck, readying", terminal.vehicle_slot == "supply_truck" and not terminal.vehicle_ready())
	for f in roundi((terminal.seconds_per_vehicle + 0.2) * 60): await physics_frame
	await process_frame
	check("ready: Send helicopter on (%s)" % terminal._vehicle_status.text, terminal.vehicle_ready() and not terminal._vehicle_send.disabled)
	terminal._on_vehicle_send()
	var lz := Vector2(24.0, 13.0) * PX
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = Vector2(24.0, 18.0) * PX
	for f in 3: await physics_frame
	check("marking the LZ: OK in the open, red on a crate and off the field", terminal.screen == terminal.Screen.VLZ
			and terminal._vlz_ok(lz) and not terminal._vlz_ok(crate.global_position)
			and not terminal._vlz_ok(World.ARENA.position + Vector2(0.5, 13.0) * PX))   # (off the 2 km field's west edge)
	crate.queue_free()
	terminal._send_vehicle(lz)
	await physics_frame
	var truck: Node2D = null
	var heli: Node2D = null
	for node in main.get_children():
		if node.is_in_group("vehicles") and node.get("airborne"):
			truck = node
		elif node.get_script() and node.get_script().resource_path.ends_with("helicopter.gd"):
			heli = node
	check("sent: the request's done, a helicopter and the truck on their way", terminal.vehicle_slot == "" and truck != null and heli != null)
	if truck == null or heli == null:
		quit()
		return
	var run: Node = heli.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("sling_drop.gd"))[0]
	var down := [false]
	run.set_down.connect(func(_v): down[0] = true)
	var max_alt := 0.0
	var under := true
	var t := 0.0
	var off_layers := true
	while not down[0] and t < 15.0:
		await physics_frame
		t += 1.0 / 60.0
		max_alt = maxf(max_alt, truck.altitude_m)
		under = under and truck.global_position.distance_to(heli.global_position) < 1.0
		off_layers = off_layers and (down[0] or truck.collision_layer == 0)   # (until the tick it's set down)
	print("    set down after %.1f s, up to %.1f m in the air (scale %.2f at the top)" % [t, max_alt, 1.0 + max_alt * truck.CLIMB_SCALE_PER_M])
	check("slung under the helicopter all the way in, up in the air, off every collision layer",
			under and max_alt > 10.0 and off_layers)
	check("set down at the LZ: on the ground, solid, nose east, not airborne", down[0]
			and truck.global_position.distance_to(lz) < 0.1 * PX and truck.altitude_m == 0.0 and not truck.airborne
			and truck.collision_layer == 1 and truck.collision_mask == 5 and absf(truck.rotation) < 0.01
			and is_equal_approx(truck.scale.x, 1.0))
	t = 0.0
	while is_instance_valid(heli) and t < 15.0:
		await physics_frame
		t += 1.0 / 60.0
	check("the helicopter flies away and is gone (%.1f s)" % t, not is_instance_valid(heli))
	# The player gets in and drives it.
	terminal.close()
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	for f in 3: await physics_frame
	check("the player can get in (it's the interact target)", player.interact_target() == truck)
	truck.get_in(player)
	t = 0.0
	while truck.driver == null and t < 4.0:
		await physics_frame
		t += 1.0 / 60.0
	check("in, driving it", truck.driver == player)
	print("DONE, %d failed" % fails)
	quit()
