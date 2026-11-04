extends SceneTree
## Aiming the dish: X goes back to the RADIO menu without changing the heading.

const World = preload("res://scripts/world.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var station: Node2D = main.get_node("RadioStation")
	var term = station.get_node("Terminal")
	player.global_position = station.get_node("OperatorZone").global_position
	for f in 10: await physics_frame
	var before: float = station.target_heading
	term.open_menu()
	term._on_dish()
	for f in 3: await process_frame
	station._pick = before + 1.0
	print("aiming: tuning %s, menu screen %s" % [station.tuning, term.screen])
	var x := InputEventKey.new()
	x.keycode = KEY_X
	x.physical_keycode = KEY_X
	x.pressed = true
	root.push_input(x)
	for f in 3: await process_frame
	print("X pressed: tuning %s, RADIO menu open %s, heading unchanged %s, player busy %s" % [station.tuning,
			term.screen == term.Screen.MENU, is_equal_approx(station.target_heading, before), player.busy])
	quit()
