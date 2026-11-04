extends SceneTree
## Smoke: the real level with its enemies, three squadmates up the watch
## tower and two on the ground near the enemies, fighting for 25 s. Any script
## error shows in the output; prints shots fired and hits.

const PX := 1024.0 / 12.0


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for f in 3: await physics_frame
	var tower: Node2D = main.get_node("WatchTower")
	var player: Node2D = main.get_node("Player")
	var mates: Array = []
	for spot in [Vector2(-0.5, 1.05), Vector2(1.05, -0.8), Vector2(2.0, 1.5)]:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.position = tower.to_global(spot * PX)
		main.add_child(mate)
		mate._set_tower(tower)
		mates.append(mate)
	var enemies: Array = []
	for i in 4:
		var e: Node2D = load("res://scenes/enemy.tscn").instantiate()
		e.position = tower.to_global(Vector2(-14.0, -3.0 + i * 2.0) * PX)
		main.add_child(e)
		enemies.append(e)
	for f in 3: await physics_frame
	for i in 2:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.position = enemies[0].global_position + Vector2(-6.0, i * 1.5) * PX
		main.add_child(mate)
		mates.append(mate)
	var shots := 0
	for f in 25 * 60:
		await physics_frame
		shots = maxi(shots, get_nodes_in_group("bullets").size())
	print("after 25 s: squadmates %s; enemies alive %d of %d" % [mates.map(func(u): return "%s%s" % ["dead" if u.dead else "alive", " up (%s)" % tower.part_of(u) if u.tower else ""]),
		enemies.filter(func(e): return is_instance_valid(e) and not e.dead).size(), enemies.size()])
	quit()
