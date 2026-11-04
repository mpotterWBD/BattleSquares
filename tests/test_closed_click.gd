extends SceneTree
## A click on a dig-in square under a watch tower's stair is a plain move (onto the stair).

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(16.85, 15.64) * PX
	main.add_child(tower)
	for i in 10:
		var w: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		w.position = Vector2(19.5, 14.6 + i * 0.797) * PX
		w.rotation = PI / 2
		main.add_child(w)
	root.add_child(main)
	current_scene = main
	var cmd: Node = main.get_node("Command")
	var mate: Node2D = main.get_node("Squadmate")
	for f in 3: await physics_frame
	for c in [["upper stair, beside the wall", Vector2(2.25, 0.3)], ["lower stair, beside the wall", Vector2(2.25, 3.0)], ["open side of the wall (east)", Vector2(3.05, 3.0)]]:
		var p: Vector2 = tower.to_global(c[1] * PX)
		mate.global_position = tower.to_global(Vector2(-3, 6) * PX)
		mate._set_tower(null)
		mate.state = mate.State.IDLE
		for f in 3: await physics_frame
		cmd._order_move(p, [mate])
		for f in 3: await physics_frame
		var t := 0.0
		while t < 30.0 and mate.state == mate.State.MOVE:
			for f in 30: await physics_frame
			t += 0.5
		print("%-30s wall there %s -> %s after %.1f s, on tower %s, cover %s" % [c[0], cmd._sandbags_at(p) != null, mate.State.keys()[mate.state], t, mate.tower != null, mate._cover != null])
	quit()
