extends SceneTree
## A row of sandbags along a watch tower's stair: the dig-in squares under the
## stair are gone; the rest are separate squares.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = player.global_position + Vector2(-3.0, -3.5) * PX
	main.add_child(tower)
	var walls := []
	for i in 9:
		var w: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		w.position = tower.to_global(Vector2(2.75, -1.4 + i * 0.797) * PX)
		w.rotation = PI / 2
		main.add_child(w)
		walls.append(w)
	for f in 5: await physics_frame
	var open := []
	for w in walls:
		open.append("%s%s" % ["W" if w.side_open(-1) or w.side_open(1) else "-", ""])
	var sides := walls.map(func(w): return "%s|%s" % ["open" if w.side_open(1) else "X", "open" if w.side_open(-1) else "X"])
	print("walls along the stair (stair side | far side): ", sides)
	var cmd: Node = main.get_node("Command")
	cmd.process_mode = Node.PROCESS_MODE_DISABLED
	World_set_commanding()
	for f in 20: await process_frame
	root.get_texture().get_image().save_png("res://digin_shot.png")
	quit()

func World_set_commanding() -> void:
	var World = load("res://scripts/world.gd")
	World.placing = true
