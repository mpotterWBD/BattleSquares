extends SceneTree
## Command mode, nobody selected: a right click at a sandbag wall sends
## everyone in the command circle to man it; a right click on open ground
## sends nobody. With someone selected, only they go.

const PX := 1024.0 / 12.0


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func right_click(world: Vector2) -> void:
	var screen := root.get_final_transform() * (root.get_canvas_transform() * world)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		await process_frame


func states(squad: Array) -> String:
	var out := []
	for u in squad:
		out.append("%s=%s" % [u.name, u.State.keys()[u.state]])
	return ", ".join(out)


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
	for i in squad.size():
		squad[i].global_position = m(19.0 + i * 0.6, 12.0)
	squad[5].global_position = m(5.0, 20.0)   # well outside the 8 m circle
	await ticks(10)
	print("in the circle: %s" % ", ".join(squad.map(func(u): return "%s=%s" % [u.name, player.can_hear(u.global_position)])))
	Input.action_press("command")
	await ticks(3)

	await right_click(m(21.0, 3.0))   # open ground
	await ticks(5)
	print("nobody selected, open ground: %s" % states(squad))

	await right_click(m(23.6, 9.5))   # just in front of the wall (its box)
	await ticks(5)
	print("nobody selected, at the wall: %s" % states(squad))
	await ticks(240)
	print("4 s later: %s" % states(squad))
	for k in 8:
		print("  t+%.1f Squadmate at %s goal %s state %s" % [4 + k * 0.5, (squad[0].global_position / PX).snapped(Vector2(0.01, 0.01)), (squad[0].destination / PX).snapped(Vector2(0.01, 0.01)) if true else "?", squad[0].State.keys()[squad[0].state]])
		await ticks(30)

	for u in squad:
		u.order_follow("follow")
	await ticks(120)
	squad[2].selected = true
	await right_click(m(23.6, 9.5))
	await ticks(5)
	print("one selected (%s), at the wall: %s" % [squad[2].name, states(squad)])
	Input.action_release("command")
	quit()
