extends SceneTree
## Squadmates building a 10-tile sandbag wall (the 2026-11-01 battle log's
## setup): how long each carrier spends climbing on built bags, and how long
## the whole wall takes.

const PX := 1024.0 / 12.0


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.position = m(9.87, 15.99)
	level.add_child(player)
	var crate: Node2D = load("res://scenes/crate_sandbags.tscn").instantiate()
	crate.position = m(15.6, 19.3)
	level.add_child(crate)
	var starts := [m(16.69, 19.17), m(16.71, 18.25), m(16.91, 20.37), m(16.54, 15.15), m(16.66, 17.02), m(16.51, 16.08)]
	var mates: Array[Node2D] = []
	for p: Vector2 in starts:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.position = p
		level.add_child(mate)
		mates.append(mate)
	await process_frame
	await physics_frame
	await physics_frame
	var walls: Array[Node2D] = []
	for i in 10:
		var wall: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		wall.position = m(19.5, 19.6) - Vector2(0, 68.0 * i)
		wall.rotation = PI / 2.0
		level.add_child(wall)
		walls.append(wall)
	await physics_frame
	for wall in walls:
		wall.start_site(crate)
	for mate in mates:
		mate.order_build()

	var dt := 1.0 / 60.0
	var climbing := []
	var worst := []
	var retargets := []
	var last_site := []
	for i in mates.size():
		climbing.append(0.0)
		worst.append(0.0)
		retargets.append(0)
		last_site.append(null)
	var t := 0.0
	var done_at := -1.0
	while t < 40.0:
		await physics_frame
		t += dt
		for i in mates.size():
			var mate := mates[i]
			var c := 0.0
			for wall in walls:
				c = maxf(c, wall.climb_at(mate.global_position))
			worst[i] = maxf(worst[i], c)
			var s: Node2D = mate._build_site
			if s != null and last_site[i] != null and s != last_site[i] and mate.carrying != "":
				retargets[i] += 1
			last_site[i] = s if mate.carrying != "" else null
			if c > 0.05:
				climbing[i] += dt
		if walls.all(func(w: Node2D) -> bool: return w.built):
			done_at = t
			break
	print("wall done at: %s" % ("%.2f s" % done_at if done_at >= 0.0 else "NOT DONE after 40 s"))
	for i in mates.size():
		print("  mate %d: on bags %.2f s, highest climb %.2f, retargets %d" % [i + 1, climbing[i], worst[i], retargets[i]])
	quit()
