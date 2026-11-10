extends SceneTree
## Start On Top (soldier.gd `start_on_top`, Mike 2026-11-09): a squadmate and
## an enemy placed over a watch tower's deck start up on it (its tower set,
## standing high, drawn over the deck), one placed over the deck's middle is
## put on the nearest place to stand, and one with it on but off any tower stays
## on the ground. The enemy, alerted to a squadmate on the ground, fights from
## up there without walking off (enemy.gd); the squadmate up there, ordered to
## a spot on the ground, comes down the stair. Run with --fixed-fps 60.
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad") + get_nodes_in_group("watch_towers"):
		node.queue_free()
	await physics_frame
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(20.0, 40.0) * PX
	main.add_child(tower)
	await physics_frame
	# Two places to stand on the open deck (the "top": not the shelter, where nobody can fire out).
	var spots: Array[Vector2] = []
	for gx in range(-8, 9):
		for gy in range(-8, 9):
			var p: Vector2 = tower.to_global(Vector2(gx, gy) * 0.5 * PX)
			if spots.size() < 2 and tower.can_stay(p) and tower.part_at(p) == "top" \
					and spots.all(func(s): return s.distance_to(p) > 1.0 * PX):
				spots.append(p)
	check("found two places to stand on the open deck", spots.size() == 2)

	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	mate.start_on_top = true
	mate.position = spots[0]
	var foe: Node2D = load("res://scenes/enemy.tscn").instantiate()
	foe.start_on_top = true
	foe.position = spots[1]
	var grounded: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	grounded.start_on_top = true
	grounded.position = Vector2(40.0, 40.0) * PX
	var plain: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	plain.position = tower.global_position   # (over the deck, setting off: on the ground under it)
	for u in [mate, foe, grounded, plain]:
		main.add_child(u)
	for f in 3: await physics_frame
	check("a squadmate placed on the deck starts up there (%.1f m high)" % mate.elevation_m,
			mate.tower == tower and mate.elevation_m > 2.0 and mate.global_position.distance_to(spots[0]) < 2.0)
	check("an enemy placed on the deck too (%.1f m high), its post up there" % foe.elevation_m,
			foe.tower == tower and foe.elevation_m > 2.0 and foe._post.distance_to(foe.global_position) < 1.0)
	check("one with it on but off any tower stays on the ground", grounded.tower == null and grounded.elevation_m == 0.0)
	check("one over the deck with it off is on the ground under it", plain.tower == null)

	# The enemy fights from up there without walking off.
	var shots := [0]
	foe.get_node("Rifle").fired.connect(func(): shots[0] += 1)
	var target: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	target.position = tower.global_position + Vector2(0.0, 9.0) * PX
	target.invincible = true
	target.hold_fire = true   # (it doesn't shoot back: a hit would knock the enemy about, and the check is that it doesn't walk)
	mate.hold_fire = true     # (nor does the one up beside it; and it lives, to come down after)
	mate.invincible = true
	main.add_child(target)
	await physics_frame
	foe.alert(target)
	# (it may be hit and knocked about, or killed, by squadmates firing back: that's
	# not walking, so the check is its walking speed, not where it ends up)
	var fastest := 0.0
	for f in 600:
		await physics_frame
		if is_instance_valid(foe) and not foe.dead:
			fastest = maxf(fastest, foe.velocity.length() / PX)
	check("the enemy, alerted, fired from up there (%d shots) and never walked (its fastest %.2f m/s), still up" % [shots[0], fastest],
			shots[0] > 0 and fastest < 0.05 and foe.tower == tower)

	# The squadmate comes down when ordered, from places along the south walkway
	# (the west end too) and the east one.
	target.queue_free()
	foe.queue_free()
	await physics_frame
	var down := tower.global_position + Vector2(-6.0, 10.0) * PX
	var all_down := true
	var worst := 0.0
	for start in [Vector2(-1.15, 1.05), Vector2(-0.5, 1.05), Vector2(0.3, 1.05), Vector2(1.05, -0.3)]:
		mate.order_move(mate.global_position)   # (stand still)
		mate.global_position = tower.to_global(start * PX)
		mate._place_on_top()
		await physics_frame
		var placed: bool = mate.tower == tower
		mate.order_move(down)
		var t := 0.0
		while (mate.tower != null or mate.global_position.distance_to(down) > 0.5 * PX) and t < 40.0:
			await physics_frame
			t += 1.0 / 60.0
		var ok: bool = placed and mate.tower == null and mate.global_position.distance_to(down) < 0.5 * PX
		print("    from %s on the deck: %s in %.1f s" % [start, "down" if ok else "NOT down (at %s, tower-local)" % (tower.to_local(mate.global_position) / PX), t])
		all_down = all_down and ok
		worst = maxf(worst, t)
	check("the squadmate, ordered to the ground from four places on the deck, comes down the stair each time (%.1f s at most)" % worst, all_down)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
