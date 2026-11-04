extends SceneTree
## Every frame of walking up the stair's foot and back down: never on the
## ground (drawn under the stair) while any of the square is over the stair.

const PX := 1024.0 / 12.0
const STAIR := Rect2(1.6, -0.6, 0.8, 4.7)   # the stair's art, flights and landings (m)

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
	for start_x in [2.0, 1.8, 2.2, 1.5, 2.5]:
		player.global_position = tower.to_global(Vector2(start_x, 6.0) * PX)
		for f in 5: await physics_frame
		var bad := 0
		var on_at := -1.0
		Input.action_press("move_up")
		for f in 240:
			await physics_frame
			var m: Vector2 = tower.to_local(player.global_position) / PX
			var body := Rect2(m - Vector2(0.2, 0.2), Vector2(0.4, 0.4))
			if player.tower == null and body.intersects(STAIR):
				bad += 1
			if player.tower != null and on_at < 0.0:
				on_at = m.y
		Input.action_release("move_up")
		var top_y: float = (tower.to_local(player.global_position) / PX).y
		Input.action_press("move_down")
		var off_at := -1.0
		for f in 400:
			await physics_frame
			var m: Vector2 = tower.to_local(player.global_position) / PX
			var body := Rect2(m - Vector2(0.2, 0.2), Vector2(0.4, 0.4))
			if player.tower == null and body.intersects(STAIR):
				bad += 1
			if player.tower == null and off_at < 0.0:
				off_at = m.y
		Input.action_release("move_down")
		for f in 10: await physics_frame
		print("x %.1f: on the tower at y %.2f (the stair ends at 4.10), up to y %.2f, off at y %.2f; frames under the stair: %d" % [start_x, on_at, top_y, off_at, bad])
	# From the side: can't walk in under the foot.
	player.global_position = tower.to_global(Vector2(0.9, 3.8) * PX)
	for f in 5: await physics_frame
	Input.action_press("move_right")
	for f in 120: await physics_frame
	Input.action_release("move_right")
	print("from the west at y 3.8: stopped at x %.2f (stringer at 1.60), on tower %s" % [(tower.to_local(player.global_position) / PX).x, player.tower != null])
	quit()
