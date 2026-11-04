extends SceneTree
## Mike, 2026-11-02:
##   - the menu triangle's size is the Command node's Menu Toggle Px, live;
##   - two squadmates sent to an ammo can (a click on it) load one after the
##     other, the second waiting off to the side, then stand down;
##   - out of ammo, they get the no-ammo sign while commanding (draws, no errors);
##   - a radio station on a watch tower casts no stand (legs) shadow.

const PX := 1024.0 / 12.0


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func ticks(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for e in main.get_children():
		if e.get_script() and e.get_script().resource_path.ends_with("enemy.gd"):
			e.queue_free()
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = m(26.0, 9.0)
	var command: Node = main.get_node("Command")
	var mates: Array = []
	for i in 2:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.name = "Mate%d" % (i + 1)
		mate.position = m(25.0 + i * 1.0, 10.5)
		main.add_child(mate)
		mates.append(mate)
	var can: Node2D = load("res://scenes/ammo_supply.tscn").instantiate()
	can.position = m(28.0, 12.0)
	main.add_child(can)
	await ticks(5)
	# Both out: nothing in the rifle, empty spares.
	for u in mates:
		var r: Node2D = u.get_node("Rifle")
		r.rounds = 0
		r._spares = [0, 0] as Array[int]
	Input.action_press("command")
	await ticks(3)
	print("menu triangle at the default: %s" % command._menu_toggle.size)
	command.menu_toggle_px = 40.0
	await ticks(2)
	var screen: Vector2 = root.get_canvas_transform() * player.global_position
	var t_rect := Rect2(command._menu_toggle.position, command._menu_toggle.size)
	print("set to 40: %s; ORDERS' right edge %.1f px left of it (no overlap %s)" % [command._menu_toggle.size,
		t_rect.position.x - (command._menu.position.x + command._menu.size.x), command._menu.position.x + command._menu.size.x <= t_rect.position.x])
	print("out of ammo: %s (the sign draws over them while commanding)" % [mates.map(func(u): return u.is_out_of_ammo())])

	# Select both and click the can.
	for u in mates:
		u.selected = true
	command._click(can.global_position, false)
	await ticks(2)
	print("after the click: %s; can claimed by %s" % [mates.map(func(u): return "%s %s" % [u.name, u.State.keys()[u.state]]),
		can.claimed_by.name if can.claimed_by else "-"])
	var t := 0
	var log := {}
	while t < 1800:
		await physics_frame
		t += 1
		for u in mates:
			var spares: Array = u.get_node("Rifle")._spares
			var d: float = u.global_position.distance_to(can.global_position) / PX
			var key := "%s %s" % [u.name, u.State.keys()[u.state]]
			if not log.has(key):
				log[key] = true
				print("  %.1f s: %s, %.2f m from the can, spares %s" % [t / 60.0, key, d, spares])
		if t % 300 == 0:
			print("  %.1f s: %s; claimed by %s; rounds left %d" % [t / 60.0, mates.map(func(u): return "%s %.2f m spares %s %s" % [u.name, u.global_position.distance_to(can.global_position) / PX, u.get_node("Rifle")._spares, u.State.keys()[u.state]]), can.claimed_by.name if can.claimed_by else "-", can.rounds])
		if mates.all(func(u): return u.state == u.State.IDLE and u._sent_ammo == null):
			break
	print("done after %.1f s: %s; can rounds left %d" % [t / 60.0, mates.map(func(u): return "%s spares %s rifle %d" % [u.name, u.get_node("Rifle")._spares, u.get_node("Rifle").rounds]), can.rounds])
	command._click(can.global_position, false)
	await ticks(2)
	print("click again with full spares: red ping %s; states %s" % [command._pings.any(func(p): return p.get("color", command.COLOR) == command.REFUSE_COLOR), mates.map(func(u): return u.State.keys()[u.state])])
	Input.action_release("command")

	# A radio station on the level's watch tower.
	var tower: Node2D = main.get_node("WatchTower")
	var radio: Node2D = load("res://scenes/radio_station.tscn").instantiate()
	radio.mount_on(tower)
	var spot: Dictionary = tower.station_spot()
	radio.position = spot.pos
	radio.rotation = spot.turn
	main.add_child(radio)
	await ticks(3)
	radio.fade_dish(1.0)
	print("mounted station: stand shadow visible %s, dish shadow visible %s" % [radio.get_node("ShadowStand").visible, radio.get_node("DishShadow").visible])
	var ground: Node2D = load("res://scenes/radio_station.tscn").instantiate()
	ground.position = m(30.0, 4.0)
	main.add_child(ground)
	await ticks(3)
	print("station on the ground: stand shadow visible %s" % ground.get_node("ShadowStand").visible)
	quit()
