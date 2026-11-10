extends SceneTree
## The RADIO menu stays open (Mike, 2026-11-09): sending troops, equipment or a
## vehicle by helicopter, and locking the dish's heading in (a click, or F),
## all come back to the RADIO menu (Deploy, Command, Dish, Exit) instead of
## closing it; the player stays busy (no firing) while it's open. Esc or X on
## a request steps back to the menu; X at the menu closes it; Exit closes it.

const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var station: Node2D = load("res://scenes/radio_station.tscn").instantiate()
	station.position = Vector2(30.0, 19.0) * PX
	main.add_child(station)
	var player: Node2D = main.get_node("Player")
	var term = station.get_node("Terminal")
	for f in 4: await physics_frame
	player.global_position = station.get_node("OperatorZone").global_position
	for f in 6: await physics_frame
	check("the station's built and the player's at the desk", station.built and term._player_on_box())
	var menu = term.Screen.MENU

	# Troops: fill a slot, wait for it, send, click an LZ.
	term.open_menu()
	term._on_kind_chosen("troops", Vector2.ZERO)
	term._type_for_slot = 0
	term._on_type_chosen("infantry", Vector2.ZERO)
	for f in 90: await physics_frame
	check("a troop's ready", term.troops_ready())
	term._on_send()
	term._send_helicopter(Vector2(20.0, 8.0) * PX)
	await physics_frame
	check("troops sent: back at the RADIO menu, the player still busy", term.screen == menu and term._layer.visible and player.busy)

	# Equipment: one crate, send, drop.
	term._on_kind_chosen("equipment", Vector2.ZERO)
	term._equip_for_slot = 0
	term._on_equip_chosen("ammo", Vector2.ZERO)
	for f in 90: await physics_frame
	term._on_equip_send()
	term._send_drop(Vector2(20.0, 20.0) * PX)
	await physics_frame
	check("equipment sent: back at the RADIO menu, the drop ghost gone", term.screen == menu and term._dz_ghost == null and player.busy)

	# A vehicle.
	term._on_kind_chosen("vehicles", Vector2.ZERO)
	term._on_vehicle_chosen("supply_truck", Vector2.ZERO)
	for f in 90: await physics_frame
	term._on_vehicle_send()
	term._send_vehicle(Vector2(12.0, 20.0) * PX)
	await physics_frame
	check("a vehicle sent: back at the RADIO menu, the ghost gone", term.screen == menu and term._vehicle_ghost == null and player.busy)

	# The dish: a click locks it in.
	var before: float = station.target_heading
	term._on_dish()
	for f in 3: await process_frame
	check("Dish: the wheel's up, the menu's hidden", station.tuning and not term._layer.visible)
	station._pick = before + 1.0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_final_transform() * (root.get_canvas_transform() * (station.to_global(station.dish_at) + Vector2(80, 0)))
	station._unhandled_input(click)
	await process_frame
	check("a click locks the heading in and it's back at the RADIO menu, the player busy",
			not station.tuning and station.turning and term.screen == menu and term._layer.visible and player.busy)
	var up := click.duplicate()
	up.pressed = false
	station._unhandled_input(up)
	for f in 5: await process_frame
	check("...and still there (and busy) once the button's up", term.screen == menu and player.busy)
	# The dish again: F locks it in.
	term._on_dish()
	for f in 3: await process_frame
	var f_key := InputEventAction.new()
	f_key.action = "interact"
	f_key.pressed = true
	Input.parse_input_event(f_key)
	for f in 3: await process_frame
	var f_up := f_key.duplicate()
	f_up.pressed = false
	Input.parse_input_event(f_up)
	for f in 3: await process_frame
	check("F locks it in and it's back at the RADIO menu (not closed, not reopened twice)",
			not station.tuning and term.screen == menu and term._layer.visible)

	# Esc / X on a request: back to the menu; X at the menu: closed.
	term._on_kind_chosen("troops", Vector2.ZERO)
	key(KEY_ESCAPE)
	for f in 3: await process_frame
	check("Esc on the troop request: back at the menu", term.screen == menu)
	term._on_kind_chosen("equipment", Vector2.ZERO)
	key(KEY_X)
	for f in 3: await process_frame
	check("X on the equipment request: back at the menu", term.screen == menu)
	key(KEY_X)
	for f in 3: await process_frame
	check("X at the menu: closed, the player free", term.screen == term.Screen.CLOSED and not player.busy)
	# Exit still closes.
	term.open_menu()
	term.close()
	check("Exit closes it", term.screen == term.Screen.CLOSED)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
