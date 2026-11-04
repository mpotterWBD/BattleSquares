extends SceneTree

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = player.global_position + Vector2(-1.0, -0.5) * PX
	main.add_child(tower)
	for u in get_nodes_in_group("squad"):
		u.global_position += Vector2(900, 0)
		u.speed_mps = 0.0
	for f in 3: await physics_frame
	var mates := get_nodes_in_group("squad")
	var spots := [[Vector2(-0.5, -0.4), true], [Vector2(2.0, 1.5), true], [Vector2(-0.8, 0.3), false], [Vector2(2.0, 3.0), true]]
	for i in spots.size():
		mates[i].global_position = tower.to_global(spots[i][0] * PX)
		if spots[i][1]:
			mates[i]._set_tower(tower)
	player.global_position = tower.to_global(Vector2(1.05, 0.3) * PX)
	player._set_tower(tower)
	for f in 60: await process_frame
	root.get_texture().get_image().save_png("res://tower_shot2.png")
	quit()
