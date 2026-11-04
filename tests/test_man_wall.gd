extends SceneTree
## Six squadmates sent to man a sandbag wall (the 2026-11-01 00:52 battle
## log's setup): how long each takes to dig in, and how long it spends on
## top of the bags getting there.

const PX := 1024.0 / 12.0


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.position = m(14.17, 16.13)
	level.add_child(player)
	var walls: Array[Node2D] = []
	for i in 10:
		var wall: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		wall.position = m(19.2, 13.5) + Vector2(0, 68.0 * i)
		wall.rotation = PI / 2.0
		level.add_child(wall)
		walls.append(wall)
	var starts := [m(17.87, 15.49), m(17.65, 16.16), m(17.70, 14.80), m(17.97, 17.03), m(17.13, 18.16), m(17.88, 14.24)]
	var spots := [m(18.75, 19.11), m(18.75, 16.72), m(18.75, 15.93), m(18.75, 17.52), m(18.75, 18.32), m(18.75, 19.91)]
	var mates: Array[Node2D] = []
	for p: Vector2 in starts:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.position = p
		level.add_child(mate)
		mates.append(mate)
	await process_frame
	await physics_frame
	await physics_frame
	for i in [3, 4, 1, 0, 2, 5]:   # the log's order
		mates[i].order_move(spots[i], true)

	var dt := 1.0 / 60.0
	var climbing := []
	var dug_at := []
	for i in mates.size():
		climbing.append(0.0)
		dug_at.append(-1.0)
	var t := 0.0
	while t < 25.0:
		await physics_frame
		t += dt
		for i in mates.size():
			var mate := mates[i]
			var c := 0.0
			for wall in walls:
				c = maxf(c, wall.climb_at(mate.global_position))
			if c > 0.05:
				climbing[i] += dt
			if dug_at[i] < 0.0 and mate.state == mate.State.DEFEND:
				dug_at[i] = t
		if dug_at.all(func(d: float) -> bool: return d >= 0.0):
			break
	for i in mates.size():
		var at: Vector2 = mates[i].global_position / PX
		print("  mate %d: dug in at %s, on bags %.2f s, now at (%.2f, %.2f)" % [i + 1,
				"%.2f s" % dug_at[i] if dug_at[i] >= 0.0 else "NEVER", climbing[i], at.x, at.y])
	quit()
