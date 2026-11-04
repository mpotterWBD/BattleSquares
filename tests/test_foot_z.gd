extends SceneTree
## A square on the ground by the stair's foot is drawn over the stairs (z 5,
## the stairs are 4); beside the higher part of the lower flight, under the
## deck or away from the tower it's at 0; up on the tower 6 (Mike,
## 2026-11-02: a rail end drawn on top of him).

const PX := 1024.0 / 12.0


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for e in main.get_children():
		if e.get_script() and e.get_script().resource_path.ends_with("enemy.gd"):
			e.queue_free()
	var player: Node2D = main.get_node("Player")
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(40, 8) * PX
	main.add_child(tower)
	for f in 3: await physics_frame
	print("stairs drawn at z %d" % tower.get_node("Stairs").z_index)
	for c in [["beside the foot, west (Mike's spot)", Vector2(1.35, 3.7)], ["beside the foot, east", Vector2(2.65, 3.7)],
			["in front of the foot", Vector2(2.0, 4.6)], ["beside the flight higher up, west", Vector2(1.35, 2.5)],
			["under the deck", Vector2(0.0, 0.0)], ["out in the open", Vector2(5.0, 5.0)]]:
		player._set_tower(null)
		player.global_position = tower.to_global(c[1] * PX)
		for f in 3: await physics_frame
		print("%-36s at %s: z %d" % [c[0], c[1], player.z_index])
	player.global_position = tower.to_global(Vector2(2.0, 3.0) * PX)
	player._set_tower(tower)
	for f in 3: await physics_frame
	print("%-36s at %s: z %d" % ["up on the stair", Vector2(2.0, 3.0), player.z_index])
	# Walking away from the foot drops it back under.
	player._set_tower(null)
	player.global_position = tower.to_global(Vector2(1.35, 3.7) * PX)
	for f in 3: await physics_frame
	Input.action_press("move_up")
	for f in 60: await physics_frame
	Input.action_release("move_up")
	print("walked north beside the flight to y %.2f: z %d" % [(tower.to_local(player.global_position) / PX).y, player.z_index])
	quit()
