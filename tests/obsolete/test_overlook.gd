extends SceneTree
## The overlook box: from inside it, someone up high on the tower is seen and
## shot past sandbags; the shelter is heavy cover until they fire out of it.

const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")
const Cover = preload("res://scripts/cover.gd")

var tower: Node2D

func _at(m: Vector2) -> Vector2:
	return tower.to_global(m * PX)

func _hits(main, shooter, target, n := 300) -> int:
	target.max_health = 1e9
	target.health = 1e9
	for i in n:
		var b := Bullet.new()
		b.setup(shooter.global_position, (target.global_position - shooter.global_position).angle(), 300.0, shooter, 1.0)
		main.add_child(b)
		if i % 10 == 9:
			for f in 3: await physics_frame
	for f in 30: await physics_frame
	return roundi(1e9 - target.health)

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(10, 12) * PX
	main.add_child(tower)
	var wall: Node = load("res://scenes/sandbags.tscn").instantiate()
	wall.position = _at(Vector2(4.0, 0.5))
	wall.rotation = PI / 2
	main.add_child(wall)
	var mate: Node2D = main.get_node("Squadmate")
	mate.speed_mps = 0.0
	mate.hold_fire = true
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	main.add_child(enemy)
	enemy.speed_mps = 0.0
	for f in 5: await physics_frame
	var ghost: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	main.add_child(ghost)
	print("placing ghost in watch_towers: %s (real tower: %s)" % [ghost.is_in_group("watch_towers"), tower.is_in_group("watch_towers")])
	ghost.queue_free()
	for case in [["top", Vector2(1.05, 0.5), true, Vector2(6.5, 0.5)], ["top", Vector2(1.05, 0.5), true, Vector2(10.5, 0.5)],
			["ground behind the wall", Vector2(3.4, 0.5), false, Vector2(6.5, 0.5)]]:
		wall.queue_free()
		wall = load("res://scenes/sandbags.tscn").instantiate()
		wall.position = _at(Vector2(4.0, 0.5))
		wall.rotation = PI / 2
		main.add_child(wall)
		wall.max_health = 1e9
		wall.health = 1e9
		mate.global_position = _at(case[1])
		mate._set_tower(tower if case[2] else null)
		mate.elevation_m = 3.0 if case[2] else 0.0
		enemy.global_position = _at(case[3])
		for f in 3: await physics_frame
		var in_box: bool = tower.overlooks(enemy.global_position)
		var rq := PhysicsRayQueryParameters2D.create(enemy.global_position, mate.global_position)
		rq.exclude = [enemy.get_rid()]
		var first := root.get_world_2d().direct_space_state.intersect_ray(rq)
		print("   ray hits %s (layer %s) at %s m; wall at %s m, built %s, stop %s" % [first.collider.name if first else "-", first.collider.collision_layer if first else 0, tower.to_local(first.position) / PX if first else Vector2.ZERO, tower.to_local(wall.global_position) / PX, wall.built, wall.cover_stop_chance()])
		var spots: bool = enemy._clear_view(enemy.global_position, mate.global_position, false, true, Cover.in_full_view(mate, enemy.global_position))
		var hit := await _hits(main, enemy, mate)
		print("mate on %-22s enemy %s the box: spots it %s, shielded %s, %d of 300 shots hit" % [case[0], "in" if in_box else "outside", spots, enemy._shielded(mate), hit])
	# The shelter: heavy until it fires out of it.
	mate.global_position = _at(Vector2(0.2, 0.0))
	mate._set_tower(tower)
	enemy.global_position = _at(Vector2(6.5, 0.0))
	for f in 3: await physics_frame
	mate.exposed_s = 0.0
	print("shelter, quiet: spots %s, shielded %s, pass %.0f%%" % [enemy._clear_view(enemy.global_position, mate.global_position, false, true, Cover.in_full_view(mate, enemy.global_position)),
			enemy._shielded(mate), Cover.tower_pass(mate, enemy) * 100.0])
	mate.exposed_s = 0.8
	print("shelter, just fired: shielded %s, pass %.0f%%" % [enemy._shielded(mate), Cover.tower_pass(mate, enemy) * 100.0])
	quit()
