extends SceneTree
## Firing over sandbags exposes a square: the wall covers it 40%, and an
## enemy held up in a standoff fires on it.

const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var wall: Node2D = main.get_node("Sandbags")
	var across: Vector2 = wall.global_transform.y.normalized()
	var mate: Node2D = main.get_node("Squadmate")
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	main.add_child(enemy)
	for f in 3: await physics_frame
	# Everyone else well away.
	for u in get_nodes_in_group("units"):
		if u != mate and u != enemy:
			u.global_position = Vector2(100, 100) * PX + Vector2(randf(), randf()) * 300
			u.speed_mps = 0.0
	mate.global_position = wall.global_position + across * 0.5 * PX
	mate.speed_mps = 0.0
	enemy.global_position = wall.global_position - across * 10.0 * PX
	enemy.speed_mps = 0.0
	for f in 3: await physics_frame

	# Bullets from the enemy's side at the wall, toward the mate.
	for exposed in [false, true]:
		var through := 0
		for i in 2000:
			mate.exposed_s = 0.8 if exposed else 0.0
			var b := Bullet.new()
			var at: Vector2 = wall.global_position - across * 0.1 * PX
			b.setup(enemy.global_position, across.angle(), 300.0)
			b.global_position = at
			if wall.lets_bullet_through(b):
				through += 1
			b.free()
		print("mate exposed %s: %.1f%% of shots get over the wall (cover %.0f%%)" % [exposed, through / 20.0, 100.0 - through / 20.0])

	mate.exposed_s = 0.0

	# The enemy in a fight with the mate.
	enemy.alert(mate)
	enemy.attack_target = mate
	var shots := [0]
	enemy.get_node("Rifle").fired.connect(func(): shots[0] += 1)
	for phase in ["mate holding fire", "mate firing over the wall"]:
		shots[0] = 0
		var standoff_ticks := 0
		for f in 60 * 4:
			if phase == "mate firing over the wall" and f % 30 == 0:
				mate.get_node("Rifle").fired.emit()   # a shot (without the bullet)
			await physics_frame
			enemy.attack_target = mate
			if f % 30 == 0:
				var r = enemy.get_node("Rifle")
				print("   enemy dead %s health %.1f pm %s inside %s mate state %s" % [enemy.dead, enemy.health, enemy.process_mode, enemy.is_inside_tree(), mate.State.keys()[mate.state]])
				print("   f%d standoff %s shielded %s hold %s ready %s surprised %s rounds %d reload %s aimdiff %.2f next %.2f exposed %.2f" % [f, enemy._standoff, enemy._shielded(mate), enemy.holding_fire, enemy._ready_to_fire(), enemy._is_surprised(), r.rounds, r.reloading, absf(angle_difference(r.aim, (mate.global_position - r.global_position).angle())), enemy._next_shot_s, mate.exposed_s])
			if enemy._standoff:
				standoff_ticks += 1
		print("%s, 4 s: enemy mode %s, standoff %d%% of the time, enemy shots %d" % [phase, enemy.Mode.keys()[enemy.mode], standoff_ticks * 100 / 240, shots[0]])
	quit()
