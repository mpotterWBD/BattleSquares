extends SceneTree
## Mike's log 08:15: a squadmate sent to dig in at the sandbag wall right in
## front of the tower's stair foot.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(16.85, 15.64) * PX
	tower.radio_has_station = true
	main.add_child(tower)
	for i in 10:
		var w: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		w.position = Vector2(19.5, 14.6 + i * 0.797) * PX
		w.rotation = PI / 2
		main.add_child(w)
	root.add_child(main)
	current_scene = main
	var mate: Node2D = main.get_node("Squadmate")
	for f in 3: await physics_frame
	for start in [Vector2(11.57, 23.11), Vector2(22.0, 22.0), Vector2(14.0, 15.0)]:
		mate.global_position = start * PX
		mate.state = mate.State.IDLE
		for f in 3: await physics_frame
		mate.order_move(Vector2(19.04, 20.14) * PX, true)
		var t := 0.0
		while t < 30.0:
			for f in 30: await physics_frame
			t += 0.5
			if mate.state != mate.State.MOVE:
				break
		print("from %s: %s after %.1f s at %s (spot 19.04, 20.14)" % [start, mate.State.keys()[mate.state], t, (mate.global_position / PX).snapped(Vector2(0.01, 0.01))])
	quit()
