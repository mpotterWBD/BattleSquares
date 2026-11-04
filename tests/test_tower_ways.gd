extends SceneTree
## Squadmates in and out of a watch tower (radio fitted) from all over it.

const PX := 1024.0 / 12.0

var tower: Node2D

func _m(p: Vector2) -> Vector2:
	return (tower.to_local(p) / PX).snapped(Vector2(0.01, 0.01))

func _go(mate, start: Vector2, on: bool, goal: Vector2) -> String:
	mate.global_position = tower.to_global(start * PX)
	mate._set_tower(tower if on else null)
	mate.state = mate.State.IDLE
	for f in 3: await physics_frame
	mate.order_move(tower.to_global(goal * PX))
	var t := 0.0
	while t < 40.0:
		for f in 30: await physics_frame
		t += 0.5
		if mate.state != mate.State.MOVE:
			break
	var at := _m(mate.global_position)
	var ok: bool = at.distance_to(goal) < 0.45
	return "%s %5.1f s  at %s%s" % ["OK   " if ok else "STUCK", t, at, "" if ok else "  (on tower %s)" % (mate.tower != null)]

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(16.85, 15.64) * PX
	tower.radio_has_station = true
	main.add_child(tower)
	root.add_child(main)
	current_scene = main
	var mate: Node2D = main.get_node("Squadmate")
	for u in get_nodes_in_group("squad"):
		if u != mate:
			u.global_position = Vector2(2, 2) * PX + Vector2(randf(), randf()) * 100
	for f in 5: await physics_frame
	var starts := [["shelter (log's spot)", Vector2(-0.2, -0.36)], ["shelter by the desk, south", Vector2(-0.2, 0.45)],
			["deck SE corner", Vector2(1.05, 1.05)], ["deck east walkway", Vector2(1.05, 0.3)],
			["top landing NW", Vector2(1.6, -1.6)], ["top landing NE", Vector2(2.2, -1.6)], ["upper flight", Vector2(2.0, 0.5)]]
	var goals := [["ground SE (log's goal)", Vector2(2.17, 5.32)], ["ground west", Vector2(-4.0, 0.0)], ["ground north", Vector2(0.0, -4.5)]]
	var ups := [["ground north", Vector2(0.0, -4.5)], ["ground under the deck", Vector2(0.5, 0.5)], ["ground east of stair", Vector2(3.5, 0.0)], ["ground west", Vector2(-4.0, 0.0)]]
	for u in ups:
		print("%-27s -> %-22s %s" % [u[0], "deck SE corner", await _go(mate, u[1], false, Vector2(1.05, 1.05))])
	for s in starts:
		for g in goals:
			print("%-27s -> %-22s %s" % [s[0], g[0], await _go(mate, s[1], true, g[1])])
	print("%-27s -> %-22s %s" % ["ground west", "into the shelter", await _go(mate, Vector2(-4.0, 0.0), false, Vector2(0.0, -0.2))])
	print("%-27s -> %-22s %s" % ["ground north", "deck SE corner", await _go(mate, Vector2(0.0, -4.5), false, Vector2(1.05, 1.05))])
	quit()
