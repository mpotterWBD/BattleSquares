extends SceneTree
## Windowed: squadmates each carrying one item, a frame of them.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 10:
		await physics_frame
	var player: Node2D = get_first_node_in_group("player")
	var squad := get_nodes_in_group("squad")
	var parts := ["desk", "electronics", "legs", "dish", "wiring", "sandbags"]
	for i in squad.size():
		var u: Node2D = squad[i]
		u.global_position = player.global_position + Vector2(1.5 + (i % 3) * 1.6, -1.0 + (i / 3) * 1.8) * PX
		u.order_attention(u.global_position, -PI / 2)
		u.carrying = parts[i]
	player.carrying = "ammo_can"
	main.get_node("Camera")._target_zoom = 3.0
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (player.global_position + Vector2(2.5, 0) * PX))
	var r := Rect2i(Vector2i(c) - Vector2i(700, 380), Vector2i(1400, 760)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png("carry_shot.png")
	print("ok")
	quit()
