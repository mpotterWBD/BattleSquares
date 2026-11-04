extends SceneTree
## On the ground, hugging the outside of the stair's lower flight (pressed
## into it) up and down, on both sides (Mike, 2026-11-02: a bump out where
## the flight meets the foot). Prints how far it was pushed out sideways
## along the way and its slowest pace.

const PX := 1024.0 / 12.0

var player: Node2D
var tower: Node2D


func _m() -> Vector2:
	return tower.to_local(player.global_position) / PX


func _release() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for e in main.get_children():
		if e.get_script() and e.get_script().resource_path.ends_with("enemy.gd"):
			e.queue_free()
	player = main.get_node("Player")
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(30, 8) * PX
	main.add_child(tower)
	for f in 3: await physics_frame
	for c in [["west, walking south", 1.3, 2.3, "move_down", "move_right"], ["west, walking north", 1.3, 4.0, "move_up", "move_right"],
			["east, walking south", 2.7, 2.3, "move_down", "move_left"], ["east, walking north", 2.7, 4.0, "move_up", "move_left"]]:
		player._set_tower(null)
		player.global_position = tower.to_global(Vector2(c[1], c[2]) * PX)
		for f in 3: await physics_frame
		Input.action_press(c[4])
		Input.action_press(c[3])
		var xmin := INF
		var xmax := -INF
		var slowest := INF
		var slow_at := Vector2.ZERO
		var last := _m()
		for f in 240:
			await physics_frame
			var m := _m()
			if f >= 20 and m.y > 2.4 and m.y < 4.05:   # (after it's settled against the side)
				xmin = minf(xmin, m.x)
				xmax = maxf(xmax, m.x)
			if f % 10 == 9:
				if f >= 20 and absf(m.y - last.y) * 6.0 < slowest and ((c[3] == "move_down" and m.y < 4.25) or (c[3] == "move_up" and m.y > 2.4)):
					slowest = absf(m.y - last.y) * 6.0
					slow_at = m
				last = m
			if (c[3] == "move_down" and m.y > 4.3) or (c[3] == "move_up" and m.y < 2.3):
				break
		_release()
		print("%-22s x %.3f..%.3f along the flight and foot (side-to-side %.1f cm); slowest %.2f m/s at (%.2f, %.2f); on tower %s" % [
			c[0], xmin, xmax, (xmax - xmin) * 100.0, slowest, slow_at.x, slow_at.y, player.tower != null])
		for f in 5: await physics_frame
	quit()
