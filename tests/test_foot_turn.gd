extends SceneTree
## Coming down the stair and turning off it at the foot (Mike's screenshot,
## 2026-11-02: an invisible curve): walking down, then down-left / down-right
## from the bottom step. Prints the path's sideways drift per metre down past
## the foot (a free diagonal is 1.0) and where it got off the tower. Then
## going up from in front of the foot (middle and either edge) still gets on
## and up to the deck, and turning straight back up after stepping off works.

const PX := 1024.0 / 12.0

var main: Node
var player: Node2D
var tower: Node2D


func _m() -> Vector2:
	return tower.to_local(player.global_position) / PX


func _release() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
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

	for side in ["move_left", "move_right", ""]:
		player.global_position = tower.to_global(Vector2(2.0, 3.0) * PX)
		player._set_tower(tower)
		for f in 3: await physics_frame
		Input.action_press("move_down")
		while _m().y < 3.9:
			await physics_frame
		if side != "":
			Input.action_press(side)
		var start := _m()
		var off_y := -1.0
		var xs := {}
		for f in 240:
			await physics_frame
			var m := _m()
			if player.tower == null and off_y < 0.0:
				off_y = m.y
			for y in [4.3, 4.6, 5.0]:
				if not xs.has(y) and m.y >= y:
					xs[y] = m.x
			if m.y > 5.4:
				break
		_release()
		var end := _m()
		var drift := absf(end.x - start.x) / maxf(end.y - start.y, 0.01)
		print("%-12s from (%.2f, %.2f): x at y 4.3 %.2f, 4.6 %.2f, 5.0 %.2f; drift %.2f per m down; off the tower at y %.2f" % [
			side if side != "" else "straight", start.x, start.y, xs.get(4.3, NAN), xs.get(4.6, NAN), xs.get(5.0, NAN), drift, off_y])
		for f in 10: await physics_frame

	for x in [2.0, 1.6, 2.4]:
		player._set_tower(null)
		player.global_position = tower.to_global(Vector2(x, 5.6) * PX)
		for f in 3: await physics_frame
		Input.action_press("move_up")
		var on_at := -1.0
		var reached := false
		for f in 600:
			await physics_frame
			var m := _m()
			if player.tower == tower and on_at < 0.0:
				on_at = m.y
			if player.tower == null and on_at >= 0.0 and m.y < 4.0:
				print("   fell off at (%.2f, %.2f)" % [m.x, m.y])
				break
			if m.y < -0.9:
				reached = true
				break
		_release()
		print("up from x %.1f: on at y %.2f, reached the top landing %s (at %.2f, %.2f)" % [x, on_at, reached, _m().x, _m().y])
		for f in 10: await physics_frame

	# Off and straight back up.
	player.global_position = tower.to_global(Vector2(2.0, 3.0) * PX)
	player._set_tower(tower)
	for f in 3: await physics_frame
	Input.action_press("move_down")
	while player.tower != null:
		await physics_frame
	var off := _m()
	_release()
	Input.action_press("move_up")
	var back := false
	for f in 300:
		await physics_frame
		if _m().y < 2.5:
			back = player.tower == tower
			break
	_release()
	print("off at y %.2f, then straight back up: on the stair again %s (at y %.2f, elevation %.2f)" % [off.y, back, _m().y, player.elevation_m])
	quit()
