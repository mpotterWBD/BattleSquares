extends SceneTree
## Command mode clicks: nobody selected, a left click on the ground sends
## everyone in the circle there, and at a sandbag wall they dig in; a right
## click needs a selection; clicking a squadmate still selects it; with one
## selected, only it goes.

const PX := 1024.0 / 12.0


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func click(world: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var screen := root.get_final_transform() * (root.get_canvas_transform() * world)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		await process_frame
	await ticks(3)


func states(squad: Array) -> String:
	return ", ".join(squad.map(func(u): return "%s=%s" % [u.name.trim_prefix("Squadmate"), u.State.keys()[u.state]]))


func reset(squad: Array) -> void:
	for i in squad.size():
		squad[i].order_attention(m(19.0 + i * 0.6, 12.0), 0.0)
		squad[i].global_position = m(19.0 + i * 0.6, 12.0)
		squad[i].selected = false
	squad[5].global_position = m(5.0, 20.0)   # well outside the 8 m circle
	await ticks(10)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = m(20.0, 10.0)
	for i in 6:
		var wall: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		wall.position = m(24.0, 8.0) + Vector2(0, 68.0 * i)
		wall.rotation = PI / 2.0
		main.add_child(wall)
	var squad := get_nodes_in_group("squad")
	Input.action_press("command")
	await reset(squad)

	await click(m(21.0, 3.0))
	print("nobody selected, left click open ground: %s" % states(squad))
	print("   sent to: %s" % ", ".join(squad.slice(0, 5).map(func(u): return str((u.destination / PX).snapped(Vector2(0.1, 0.1))))))
	await reset(squad)
	await click(m(23.6, 9.5))
	print("nobody selected, left click at the wall: %s" % states(squad))
	await ticks(300)
	print("   5 s later: %s" % states(squad))
	await reset(squad)
	await click(m(21.0, 3.0), MOUSE_BUTTON_RIGHT)
	await click(m(23.6, 9.5), MOUSE_BUTTON_RIGHT)
	print("nobody selected, right click ground and wall: %s" % states(squad))
	await click(squad[2].global_position)
	print("left click on 3: selected %s, %s" % [squad.filter(func(u): return u.selected).map(func(u): return u.name), states(squad)])
	await click(m(23.6, 9.5))
	print("3 selected, left click at the wall: %s" % states(squad))
	Input.action_release("command")
	quit()
