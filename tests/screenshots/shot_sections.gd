extends SceneTree

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = player.global_position + Vector2(-1.0, -2.5) * PX
	main.add_child(tower)
	for f in 3: await physics_frame
	var overlay: Node
	for n in main.find_children("*", "", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("debug_overlay.gd"):
			overlay = n
	var q := InputEventAction.new()
	q.action = "debug"
	q.pressed = true
	overlay._unhandled_input(q)
	for f in 5: await process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = root.get_canvas_transform() * tower.to_global(Vector2(1.0, 1.0) * PX)
	overlay._unhandled_input(ev)
	for f in 20: await process_frame
	root.get_texture().get_image().save_png("res://sections_shot.png")
	quit()
