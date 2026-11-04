extends SceneTree
## Command mode (Mike, 2026-11-02):
##   - the triangle left of the player shows while commanding and folds the
##     ORDERS and DEPLOY menus away and back; it stays as left next time;
##   - clicking a strapped crate with nothing to build sends only the
##     nearest selected squadmate to undo the straps; one owing parts to a
##     site still gets everyone.

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
	player.global_position = m(20.0, 10.0)
	var command: Node = main.get_node("Command")
	var mates: Array = []
	for i in 3:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.position = m(19.0 + i * 0.8, 11.5)
		main.add_child(mate)
		mates.append(mate)
	await ticks(5)

	# The triangle.
	Input.action_press("command")
	await ticks(3)
	var toggle: Button = command._menu_toggle
	var screen: Vector2 = root.get_canvas_transform() * player.global_position
	var view_scale: float = root.get_canvas_transform().get_scale().x
	var half_sq := 0.2 * PX * view_scale
	var t_rect := Rect2(toggle.position, toggle.size)
	print("commanding: hud %s, triangle visible %s, size %s; its right edge %.1f px left of the square's left edge, centred %.1f px off; ORDERS shown %s, DEPLOY shown %s" % [
		command._hud.visible, toggle.is_visible_in_tree(), toggle.size, (screen.x - half_sq) - t_rect.end.x,
		t_rect.get_center().y - screen.y, command._menu.visible, command._deploy_menu.visible])
	print("   ORDERS' right edge %.1f px left of the triangle (no overlap: %s)" % [t_rect.position.x - (command._menu.position.x + command._menu.size.x),
		command._menu.position.x + command._menu.size.x <= t_rect.position.x])
	toggle.pressed.emit()
	await ticks(2)
	print("after one click: ORDERS shown %s, DEPLOY shown %s, triangle visible %s" % [command._menu.visible, command._deploy_menu.visible, toggle.is_visible_in_tree()])
	Input.action_release("command")
	await ticks(3)
	print("out of command mode: hud %s" % command._hud.visible)
	Input.action_press("command")
	await ticks(3)
	print("back in: ORDERS shown %s (stays folded)" % command._menu.visible)
	toggle.pressed.emit()
	await ticks(2)
	print("after another click: ORDERS shown %s, DEPLOY shown %s" % [command._menu.visible, command._deploy_menu.visible])

	# A strapped crate with nothing owed: only the nearest of the selected goes.
	var crate: Node2D = load("res://scenes/crate_sandbags.tscn").instantiate()
	crate.position = m(23.0, 11.5)
	main.add_child(crate)
	await ticks(3)
	for u in mates:
		u.selected = true
	print("crate strapped %s, wanted %s" % [crate.strapped, crate.wanted()])
	command._click(crate.global_position, false)
	await ticks(3)
	for u in mates:
		print("   %s at %.1f m from the crate: state %s" % [u.name, u.global_position.distance_to(crate.global_position) / PX, u.State.keys()[u.state]])
	var t := 0
	while crate.strapped and t < 900:
		await physics_frame
		t += 1
	print("straps off %s after %.1f s" % [not crate.strapped, t / 60.0])
	Input.action_release("command")
	quit()
