extends SceneTree
## Windowed: placing an ammo can (and a sandbag wall for comparison),
## screenshots of the ghost near the player.

const PX := 1024.0 / 12.0


func shot(main: Node, cmd: Node, id: String, file: String) -> void:
	cmd._start_placing(id)
	var player: Node2D = get_first_node_in_group("player")
	var world: Vector2 = player.global_position + Vector2(1.5, 0) * PX
	var screen: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * world)
	Input.warp_mouse(screen)
	for i in 10:
		await process_frame
	print("%s: placing '%s', ghosts %d at %s, mouse_world %s" % [id, cmd._placing, cmd._ghosts.size(),
			cmd._ghosts.map(func(g): return g.global_position / PX), cmd._mouse_world / PX])
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var c := screen.round()
	var r := Rect2i(Vector2i(c) - Vector2i(220, 160), Vector2i(440, 320)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(file)
	cmd._stop_placing()


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 10:
		await physics_frame
	Input.action_press("command")
	for i in 5:
		await process_frame
	var cmd: Node = main.get_node("Command")
	await shot(main, cmd, "ammo_can", "ghost_can.png")
	await shot(main, cmd, "sandbags", "ghost_bags.png")
	Input.action_release("command")
	quit()
