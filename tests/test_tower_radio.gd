extends SceneTree
## A radio station placed over a watch tower goes on it, and is built from up there.

const PX := 1024.0 / 12.0

var tower: Node2D

func _m(p: Vector2) -> Vector2:
	return tower.to_local(p) / PX

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
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(10, 12) * PX
	main.add_child(tower)
	var crate: Node2D = main.get_node("CommsCrate")
	crate.strapped = false
	var cmd: Node = main.get_node("Command")
	var player: Node2D = main.get_node("Player")
	for f in 3: await physics_frame
	cmd._placing = "radio_station"
	cmd._mouse_world = tower.to_global(Vector2(0.0, 0.0) * PX)
	var spots: Array = cmd._layout()
	print("layout over the tower: mount %s, at %s m, turn %.2f" % [spots[0].get("mount") != null, _m(spots[0].pos), spots[0].turn])
	cmd._update_ghosts()
	print("ghost mounted: %s" % (cmd._ghosts[0].get("mount") != null))
	cmd._mouse_world = tower.to_global(Vector2(-6.0, 6.0) * PX)
	print("off the tower: mount %s" % (cmd._layout()[0].get("mount") != null))
	cmd._mouse_world = tower.to_global(Vector2(0.0, 0.0) * PX)
	cmd._place(cmd._layout())
	for f in 3: await physics_frame
	var st: Node2D = tower.station
	print("placed: station %s, mounted %s, built %s, site %s" % [st != null, st.mount == tower, st.built, st.is_in_group("build_sites")])
	print("   desk box %s..%s m, deliver spot %s m (on the tower %s)" % [_m(st.get_node("DeskBody/Desk").global_position) - Vector2(0.7, 0.3).rotated(0), _m(st.get_node("DeskBody/Desk").global_position) + Vector2(0.7, 0.3), _m(st.deliver_spot(Vector2.ZERO)), tower.on_surface(st.deliver_spot(Vector2.ZERO))])
	print("   desk at %s m, operator spot at %s m, dish at %s m (roof %s)" % [_m(st.get_node("DeskBody/Desk").global_position), _m(st.get_node("OperatorZone").global_position),
			_m(st.to_global(st.dish_at)), tower.on_surface(st.to_global(st.dish_at))])
	print("   can mount another: %s" % tower.can_mount_station())
	# From the ground under the deck: can't deliver.
	player.global_position = crate.global_position + Vector2(0, 0.6) * PX
	for f in 3: await physics_frame
	_f(player)
	var part: String = player.carrying
	player.global_position = st.global_position
	player._set_tower(null)
	for f in 3: await physics_frame
	print("carrying %s, under the deck by the station: can deliver %s" % [part, st.can_deliver_at(player.global_position, player)])
	for i in 5:
		if player.carrying == "":
			player._set_tower(null)
			player.global_position = crate.global_position + Vector2(0, 0.6) * PX
			for f in 3: await physics_frame
			_f(player)
		player.global_position = tower.to_global(Vector2(1.05, -0.3) * PX)
		player._set_tower(tower)
		for f in 3: await physics_frame
		_f(player)
		for f in 3: await physics_frame
	print("up on the tower, delivered: installed %s, built %s" % [st.installed, st.built])
	# The radio: in the shelter, at the desk.
	player.global_position = st.get_node("OperatorZone").global_position
	for f in 5: await physics_frame
	await process_frame
	var term = st.get_node("Terminal")
	print("in the shelter at the desk: on box %s, F target %s" % [term._player_on_box(), player.interact_target().name if player.interact_target() else "-"])
	term.open_menu()
	term._on_dish()
	for f in 3: await process_frame
	print("radio menu Dish: tuning %s, menu screen %s, player busy %s" % [st.tuning, term.screen, player.busy])
	var want := 0.3
	st._pick = want
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	st._unhandled_input(ev)
	for f in 3: await process_frame
	print("F locks it: tuning %s, target heading %.2f, player busy %s" % [st.tuning, st.target_heading, player.busy])
	term.open_menu()
	term._on_dish()
	player.global_position = tower.to_global(Vector2(1.05, 0.9) * PX)
	for f in 5: await physics_frame
	await process_frame
	print("walked away from the desk: tuning %s; F target out there %s" % [st.tuning, player.interact_target().name if player.interact_target() else "-"])
	player._set_tower(null)
	player.global_position = tower.to_global(Vector2(-0.3, 0.0) * PX)
	for f in 5: await physics_frame
	print("on the ground under it: on box %s" % term._player_on_box())
	quit()
