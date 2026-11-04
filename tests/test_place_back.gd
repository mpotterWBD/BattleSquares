extends SceneTree
## Placing: X backs out to the command menu (held open), X again closes it.

const World = preload("res://scripts/world.gd")

func _x() -> InputEventKey:
	var x := InputEventKey.new()
	x.keycode = KEY_X
	x.physical_keycode = KEY_X
	x.pressed = true
	return x

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var cmd: Node = main.get_node("Command")
	for f in 5: await physics_frame
	cmd._start_placing("sandbags")
	for f in 3: await process_frame
	print("placing: %s, commanding %s, banner: %s" % [cmd._placing, World.commanding(), cmd._banner.text])
	root.push_input(_x())
	for f in 3: await process_frame
	print("X: placing '%s', commanding %s, menu held %s, menus shown %s, banner: %s" % [cmd._placing, World.commanding(), World.menu_held, cmd._menu.visible and cmd._hud.visible, cmd._banner.text])
	root.push_input(_x())
	for f in 3: await process_frame
	print("X again: commanding %s, menu held %s" % [World.commanding(), World.menu_held])
	cmd._start_placing("sandbags")
	root.push_input(_x())
	for f in 3: await process_frame
	cmd._give_order("follow")
	for f in 3: await process_frame
	print("back out, then an order: commanding %s, menu held %s" % [World.commanding(), World.menu_held])
	quit()
