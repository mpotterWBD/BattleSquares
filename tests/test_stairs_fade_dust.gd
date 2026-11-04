extends SceneTree
const PX := 1024.0 / 12.0
func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(16.85, 15.64) * PX
	main.add_child(tower)
	var wall: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	wall.position = tower.to_global(Vector2(2.65, 0.5) * PX)
	wall.rotation = PI / 2
	main.add_child(wall)
	for f in 3: await physics_frame
	for spot in [["under the upper flight", Vector2(2.0, 0.5)], ["under the top landing", Vector2(1.9, -1.5)], ["beside the lower flight", Vector2(1.2, 3.0)], ["out in the open", Vector2(-4, 0)]]:
		player.global_position = tower.to_global(spot[1] * PX)
		for f in 40: await process_frame
		print("player %-24s stairs alpha %.2f" % [spot[0], tower.get_node("Stairs").self_modulate.a])
	var before := main.get_child_count()
	wall.bullet_hit(wall.global_position + Vector2(-0.15, 0) * PX, Vector2.RIGHT, 0.0)
	var dusts := main.get_children().filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("hit_dust.gd"))
	var dust: Node = dusts.back()
	print("dust off the wall beside the stair: z %d (stairs 4, deck 5)" % dust.z_index)
	var far: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	far.position = tower.to_global(Vector2(-6, 6) * PX)
	main.add_child(far)
	for f in 3: await physics_frame
	far.bullet_hit(far.global_position, Vector2.RIGHT, 0.0)
	print("dust off a wall in the open: z %d" % main.get_children().filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("hit_dust.gd")).back().z_index)
	quit()
