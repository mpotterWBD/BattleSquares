extends SceneTree
## A watch tower built from its crate, part by part, by the player.

const PX := 1024.0 / 12.0

func _f(player) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	player._unhandled_input(ev)

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var crate: Node2D = load("res://scenes/crate_tower.tscn").instantiate()
	crate.position = Vector2(40, 8) * PX
	main.add_child(crate)
	crate.strapped = false
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(46, 8) * PX
	main.add_child(tower)
	for f in 3: await physics_frame
	print("command lists it: %s, crate can set up: %s" % [main.get_node("Command")._supply_count("watch_tower"), crate.can_set_up()])
	tower.start_site(crate)
	print("site: built %s, in build_sites %s, legs solid %s, base modulate %s" % [tower.built, tower.is_in_group("build_sites"),
			not tower.get_node("LegsBody/LegNE").disabled, tower.get_node("Base").modulate])
	for i in 5:
		player.global_position = crate.global_position + Vector2(0, 0.6) * PX
		for f in 3: await physics_frame
		_f(player)
		var part: String = player.carrying
		player.global_position = tower.global_position + Vector2(-0.3, 0.2) * PX   # under the deck
		for f in 3: await physics_frame
		await process_frame
		var key_shown: bool = tower._deliver_key.visible
		_f(player)
		for f in 3: await physics_frame
		print("  took %-15s crate taken %d, texture %s | installed %s, F shown %s" % [part, crate.taken,
				crate.get_node("Body").texture.resource_path.get_file() if crate.get_node("Body").visible else "(empty)", tower.installed, key_shown])
	for f in 10: await process_frame
	print("built %s, in build_sites %s, legs solid %s, stair solid %s, all white %s, crate collision off %s" % [tower.built,
			tower.is_in_group("build_sites"), not tower.get_node("LegsBody/LegNE").disabled,
			not tower.get_node("StairsBody/LowerFlight").disabled,
			["Base", "Stairs", "Platform", "Roof", "Details"].all(func(n): return tower.get_node(n).modulate == Color.WHITE),
			crate.get_node("Collision").disabled])
	print("player under deck: upper alpha %.2f" % tower.get_node("Roof").self_modulate.a)
	player.global_position = tower.global_position + Vector2(-4, 0) * PX
	for f in 30: await process_frame
	print("player away: upper alpha %.2f" % tower.get_node("Roof").self_modulate.a)
	quit()
