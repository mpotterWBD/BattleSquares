extends SceneTree
## Squadmates sent up the level's watch tower (Mike, 2026-11-02): to a place
## to stand (top landing, east walkway by the door, south walkway, mid
## landing, shelter) they stop there; to the flights or the walkway between
## the door and the shelter's corner, they go to the nearest place to stand.
## Three sent together line up along it. And dust off sandbags is drawn under
## the stairs wherever the wall is.

const PX := 1024.0 / 12.0

var tower: Node2D


func _m(p: Vector2) -> Vector2:
	return (tower.to_local(p) / PX).snapped(Vector2(0.01, 0.01))


func _settle(units: Array) -> float:
	var t := 0.0
	while t < 40.0:
		for f in 30: await physics_frame
		t += 0.5
		if units.all(func(u): return not u.is_moving()):
			break
	return t


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for e in main.get_children():
		if e.get_script() and e.get_script().resource_path.ends_with("enemy.gd"):
			e.queue_free()
	for f in 3: await physics_frame
	tower = main.get_node("WatchTower")
	var command: Node = main.get_node("Command")
	var player: Node2D = main.get_node("Player")
	player.global_position = tower.to_global(Vector2(-4, 6) * PX)
	var mates: Array = []
	for i in 3:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.position = tower.to_global(Vector2(-3.0 + i * 0.7, 5.0) * PX)
		main.add_child(mate)
		mates.append(mate)
	for f in 5: await physics_frame
	var mate: Node2D = mates[0]
	for c in [["lower flight, near the foot (yellow)", Vector2(2.0, 3.6)], ["lower flight, middle (yellow)", Vector2(2.0, 2.8)],
			["mid landing (blue)", Vector2(2.0, 1.5)], ["upper flight (yellow)", Vector2(2.0, 0.3)],
			["upper flight, near the top (yellow)", Vector2(2.0, -0.4)], ["top landing (blue)", Vector2(2.0, -1.2)],
			["east walkway by the door (blue)", Vector2(1.05, -0.8)], ["east walkway, south of door (yellow)", Vector2(1.05, 0.2)],
			["south walkway (blue)", Vector2(-0.6, 1.05)], ["in the shelter", Vector2(-0.4, -0.4)]]:
		command._order_move(tower.to_global(c[1] * PX), [mate])
		var t := await _settle([mate])
		print("%-38s sent to %s: stopped at %s on tower %s, part %s (%.1f s)" % [c[0], c[1], _m(mate.global_position), mate.tower != null, tower.part_of(mate), t])

	for c in [["3 to the south walkway", Vector2(0.0, 1.05)], ["3 to the lower flight", Vector2(2.0, 3.0)], ["3 to the top landing", Vector2(2.0, -1.2)]]:
		command._order_move(tower.to_global(c[1] * PX), mates)
		var t := await _settle(mates)
		print("%-24s %s: %s (%.1f s)" % [c[0], c[1], ", ".join(mates.map(func(u): return "%s %s" % [_m(u.global_position), tower.part_of(u)])), t])

	# Dust off a sandbag wall 1.2 m east of the stair (out of the old 0.4 m reach).
	var bags: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	bags.position = tower.to_global(Vector2(3.6, 3.0) * PX)
	main.add_child(bags)
	for f in 3: await physics_frame
	var before := main.get_children().size()
	bags.bullet_hit(bags.global_position, Vector2.LEFT, 0.0)
	for f in 2: await physics_frame
	var dust: Array = main.get_children().slice(before).filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("hit_dust.gd"))
	print("dust off a wall 1.2 m from the stair: %s (stairs at z %d)" % [dust.map(func(d): return "z %d" % d.z_index), tower.get_node("Stairs").z_index])
	quit()
