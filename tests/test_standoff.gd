extends SceneTree
## Standoff: with every foe dug in behind class 3 cover it holds fire until
## it sees a window. Scenario (-- <name>):
##   walls   both sides dug in behind sandbags 15 m apart, live AI: nobody fires
##   peek    squadmate dug in, 1 enemy (held still) behind a crate: no shots;
##           the enemy steps out from the crate: it fires
##   window  2 enemies held still, one behind a crate, one in the open 3 m to
##           the side; it starts on the dug-in one: switches to the open one
##   order   as peek, but a Fire order: shoots at the crate anyway

const PX := 1024.0 / 12.0

var counts := {}


func add(level: Node, path: String, at: Vector2) -> Node2D:
	var node: Node2D = load(path).instantiate()
	node.position = at
	level.add_child(node)
	return node


func run(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame
		for b: Node2D in get_nodes_in_group("bullets"):
			if not b.has_meta("counted"):
				b.set_meta("counted", true)
				var who: String = "mate" if b.shooter != null and b.shooter.is_in_group("squad") else "enemy"
				counts[who] = counts.get(who, 0) + 1


func shots(who: String) -> int:
	return counts.get(who, 0)


func _init() -> void:
	var scenario: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "walls"
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var home := Vector2(1500, 1500)
	add(level, "res://scenes/sandbags.tscn", home)
	var mate: Node2D = add(level, "res://scenes/squadmate.tscn", home + Vector2(0, 0.42 * PX))
	mate.max_health = 1000.0
	var far := home + Vector2(0, -15 * PX)
	if scenario == "walls":
		add(level, "res://scenes/sandbags.tscn", far)
		var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
		enemy.position = far - Vector2(0, 0.42 * PX)
		enemy.start_facing_deg = 90.0
		enemy.max_health = 1000.0
		level.add_child(enemy)
		await process_frame
		await run(0.05)
		mate.order_move(mate.global_position, true)
		await run(2.0)
		enemy.alert(mate)
		await run(8.0)
		print("walls: enemy attacking=%s mode=%s, mate attacking=%s; shots in 8 s: mate %d, enemy %d" % [
				enemy.is_attacking(), enemy.mode, mate.is_attacking(), shots("mate"), shots("enemy")])
		quit()
		return
	var enemies: Array[Node2D] = []
	var count := 2 if scenario == "window" else 1
	for i in count:
		var spot := far + Vector2(i * 3 * PX, 0)
		var e: Node2D = add(level, "res://scenes/enemy.tscn", spot)
		e.max_health = 1000.0
		enemies.append(e)
		if i == 0:
			add(level, "res://scenes/crate_ammo.tscn", spot + Vector2(0, 0.75 * PX))
	await process_frame
	await run(0.05)
	for e in enemies:
		e.set_physics_process(false)
		e.alerted = true
	mate._rifle.spare_mags = -1
	mate.order_move(mate.global_position, true)
	await run(0.5)
	mate.order_attack(enemies[0], scenario == "order")
	for e in enemies:
		print("  dug_in=%s view=%s alerted=%s state=%s" % [mate._dug_in(e), mate._clear_view(mate.global_position, e.global_position, true), e.alerted, mate.state])
	print("  foes ", mate._foes().size())
	await run(3.0)
	print("%s: target %s, shots in 3 s: %d" % [scenario, "dug-in enemy" if mate.attack_target == enemies[0] else
			("open enemy" if mate.attack_target != null else "none"), shots("mate")])
	if scenario == "peek":
		var before := shots("mate")
		enemies[0].global_position += Vector2(1.5 * PX, 0)   # steps out from behind the crate
		await run(2.5)
		print("   stepped out: shots in the next 2.5 s %d" % (shots("mate") - before))
		before = shots("mate")
		enemies[0].global_position -= Vector2(1.5 * PX, 0)   # back in
		await run(0.5)
		print("  back: dug_in=%s target=%s pinned=%s standoff=%s" % [mate._dug_in(enemies[0]), mate.attack_target, mate.state, mate._standoff])
		before = shots("mate")
		await run(2.5)
		print("   back behind the crate: shots in the next 2.5 s %d" % (shots("mate") - before))
	quit()
