extends SceneTree
## Enemies and ammo crates: a calm enemy near a strapped crate undoes it;
## five held up in a standoff by a crate get two ammo cans set up behind them.

const PX := 1024.0 / 12.0
const Enemy := preload("res://scenes/enemy.tscn")

func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await ticks(5)
	for u in get_nodes_in_group("squad"):
		u.queue_free()
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = m(2, 23)
	await ticks(2)

	# 1. Calm enemy by a strapped crate.
	var crate1: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	crate1.position = m(41, 3)
	main.add_child(crate1)
	var e0: Node2D = Enemy.instantiate()
	e0.position = m(36, 3)
	main.add_child(e0)
	await ticks(2)
	var t := 0
	while crate1.strapped and t < 900:
		await physics_frame
		t += 1
	print("1. calm enemy 5 m off a strapped crate: straps off %s at %.1f s; its task now '%s', mode %s" % [
			not crate1.strapped, t / 60.0, e0.crate_task, e0.Mode.keys()[e0.mode]])
	e0.queue_free()

	# 2. Standoff: player boxed in by sandbags, five enemies by an open crate.
	player.global_position = m(24, 18)
	for side in 4:
		for k in 5:
			var wall: Node2D = load("res://scenes/sandbags.tscn").instantiate()
			var along := (k - 2) * 68.0
			match side:
				0: wall.position = player.global_position + Vector2(along, -2.0 * 68.0 - 20)
				1: wall.position = player.global_position + Vector2(along, 2.0 * 68.0 + 20)
				2:
					wall.position = player.global_position + Vector2(-2.0 * 68.0 - 20, along)
					wall.rotation = PI / 2
				3:
					wall.position = player.global_position + Vector2(2.0 * 68.0 + 20, along)
					wall.rotation = PI / 2
			main.add_child(wall)
	var crate2: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	crate2.position = m(37, 18)
	crate2.strapped = false
	main.add_child(crate2)
	var enemies := []
	for k in 5:
		var e: Node2D = Enemy.instantiate()
		e.position = m(34.5, 15.5 + k * 1.3)
		e.cover_seek_m = 0.0
		e.min_range_m = 9.0
		e.max_range_m = 12.0
		main.add_child(e)
		enemies.append(e)
	await ticks(3)
	for e in enemies:
		e.alert(player)
	var placed_at := []
	var seen_tasks := {}
	var shots := 0
	for f in 60 * 40:
		await physics_frame
		for e in enemies:   # held where they are, but the one on a crate job
			e.speed_mps = 1.6 if e.crate_task != "" else 0.0
		if false:
			for e in enemies:
				if e.crate_task != "":
					print("      w %.1f s %s task=%s carry=%s at %s crate %.2f m in_reach=%s held=%s wanted=%d avail=%d spot %s vel %.2f" % [f / 60.0, e.name.right(3), e.crate_task, e.carrying, str((e.global_position / PX).snapped(Vector2(0.1,0.1))), e.global_position.distance_to(e._crate.global_position) / PX if e._crate else -1.0, e._crate.in_reach(e) if e._crate else false, e._held_up(), e._cans_wanted(crate2), crate2.available(), str((e._can_spot / PX).snapped(Vector2(0.1,0.1))), e.velocity.length() / PX])
		if f % 300 == 150:
			print("   %.1f s: %s" % [f / 60.0, " | ".join(enemies.map(func(e): return "%s %s tgt=%s so=%s %s m" % [e.name.right(2), e.Mode.keys()[e.mode], e.attack_target.name if e.attack_target else "-", e._standoff, str((e.global_position / PX).snapped(Vector2(0.1,0.1)))]))])
		for e in enemies:
			if is_instance_valid(e) and e.crate_task != "" and not seen_tasks.has(e.name + e.crate_task):
				seen_tasks[e.name + e.crate_task] = true
				print("   %.1f s  %s takes on '%s' (held up: %d near the crate)" % [f / 60.0, e.name, e.crate_task, e._held_up_near(crate2).size()])
		for c in get_nodes_in_group("enemy_ammo_cans"):
			if is_instance_valid(c) and not c in placed_at:
				placed_at.append(c)
				var mid := Vector2.ZERO
				for e in enemies:
					mid += e.global_position
				mid /= enemies.size()
				print("   %.1f s  can set down at %s m: %.1f m from the group's middle, %.1f m from the player (group %.1f m)" % [f / 60.0,
						(c.global_position / PX).snapped(Vector2(0.1, 0.1)), c.global_position.distance_to(mid) / PX,
						c.global_position.distance_to(player.global_position) / PX, mid.distance_to(player.global_position) / PX])
	var held := enemies.filter(func(e): return e._held_up()).size()
	print("2. after 40 s: held up %d of 5, cans set up %d (wanted ceil(5/3) = 2), crate taken %d reserved %d; tasks now %s" % [
			held, placed_at.size(), crate2.taken, crate2.reserved, enemies.map(func(e): return e.crate_task)])
	print("   enemy ammo: %s" % str(enemies.map(func(e): return "%d+%d" % [e._rifle.rounds, e._rifle.spare_rounds()])))
	print("   cans left: %s" % str(placed_at.map(func(c): return c.rounds if is_instance_valid(c) else -1)))
	quit()
