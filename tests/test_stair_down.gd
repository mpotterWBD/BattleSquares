extends SceneTree
## Walking down the stair hugging either side (pressed into it), or down the
## middle: never caught on the way off.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(30, 8) * PX
	main.add_child(tower)
	for f in 3: await physics_frame
	for c in [["hugging the inside (west)", 1.82, "move_left"], ["hugging the outside (east)", 2.18, "move_right"], ["down the middle", 2.0, ""]]:
		player.global_position = tower.to_global(Vector2(c[1], 1.5) * PX)
		player._set_tower(tower)
		for f in 3: await physics_frame
		Input.action_press("move_down")
		if c[2] != "":
			Input.action_press(c[2], 0.3)
		var slowest := INF
		var last_y := 1.5
		var off_at := -1.0
		var t := 0
		for f in 400:
			await physics_frame
			var m: Vector2 = tower.to_local(player.global_position) / PX
			if f % 10 == 9:
				if (m.y - last_y) * 6.0 < 0.1:
					var col = player.get_last_slide_collision()
					print("   stalled at (%.2f, %.2f), against %s shape %d" % [m.x, m.y, col.get_collider().name if col else "-", col.get_collider_shape_index() if col else -1])
				slowest = minf(slowest, (m.y - last_y) * 6.0)   # m/s over the last 10 frames
				last_y = m.y
			if player.tower == null and off_at < 0.0:
				off_at = m.y
				t = f
				break
		Input.action_release("move_down")
		if c[2] != "":
			Input.action_release(c[2])
		for f in 10: await physics_frame
		print("%-27s off the tower at y %.2f after %.1f s; slowest pace on the way %.2f m/s" % [c[0], off_at, t / 60.0, slowest])
	quit()
