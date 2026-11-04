extends SceneTree
## Command mode: one squadmate selected, a left click on a strapped crate
## with nothing to build sends it to undo the straps; they snap (StrapSnap
## child shows, then goes) and it stops building. Also a strapped ammo crate.

const PX := 1024.0 / 12.0
const StrapSnap = preload("res://scripts/strap_snap.gd")


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func click(world: Vector2) -> void:
	var screen := root.get_final_transform() * (root.get_canvas_transform() * world)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		await process_frame
	await ticks(3)


func snaps(crate: Node) -> int:
	return crate.get_children().filter(func(c): return c is StrapSnap).size()


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = m(20.0, 10.0)
	var squad := get_nodes_in_group("squad")
	for i in squad.size():
		squad[i].order_attention(m(19.0 + i * 0.6, 12.0), 0.0)
		squad[i].global_position = m(19.0 + i * 0.6, 12.0)
	for kind in ["sandbags", "ammo"]:
		var crate: Node2D = load("res://scenes/crate_%s.tscn" % kind).instantiate()
		crate.position = m(23.0, 7.0)
		crate.rotation = 0.3
		main.add_child(crate)
		await ticks(5)
		Input.action_press("command")
		await ticks(5)
		await click(squad[1].global_position)
		await click(crate.global_position)
		var mate: Node = squad[1]
		print("%s crate: strapped=%s wanted=%s, mate state %s" % [kind, crate.strapped, crate.wanted(), mate.State.keys()[mate.state]])
		Input.action_release("command")
		var seen := false
		for f in 600:
			await physics_frame
			if snaps(crate) > 0 and not seen:
				seen = true
				print("   straps snapped at %.2f s (strapped=%s, texture %s)" % [f / 60.0, crate.strapped, crate.get_node("Body").texture.resource_path.get_file()])
			if seen and snaps(crate) == 0:
				print("   snap animation gone after %.2f s; mate state %s, others %s" % [f / 60.0, mate.State.keys()[mate.state],
						squad.filter(func(u): return u != mate).map(func(u): return u.State.keys()[u.state])])
				break
		crate.queue_free()
		await ticks(3)
	quit()
