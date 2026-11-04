extends SceneTree
## The shelter: 100% protection, and nobody fires out of it.

const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")
const Cover = preload("res://scripts/cover.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(10, 12) * PX
	main.add_child(tower)
	var mate: Node2D = main.get_node("Squadmate")
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	main.add_child(enemy)
	enemy.speed_mps = 0.0
	mate.speed_mps = 0.0
	for f in 3: await physics_frame
	enemy.global_position = tower.to_global(Vector2(6.0, 0.0) * PX)
	enemy.max_health = 1e9
	enemy.health = 1e9
	for spot in [["shelter", Vector2(0.0, 0.0)], ["top", Vector2(1.05, 0.5)]]:
		mate.global_position = tower.to_global(spot[1] * PX)
		mate._set_tower(tower)
		for f in 3: await physics_frame
		var shots := [0]
		var cb := func(): shots[0] += 1
		mate.get_node("Rifle").fired.connect(cb)
		mate.order_attack(enemy)
		for f in 240: await physics_frame
		mate.get_node("Rifle").fired.disconnect(cb)
		print("mate in the %-8s: pass through to it %3.0f%%, its shots at the enemy in 4 s: %d" % [spot[0], Cover.tower_pass(mate, enemy) * 100.0, shots[0]])
	quit()
