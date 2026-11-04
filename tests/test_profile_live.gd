extends SceneTree
## Live tuning: a profile file saved while the game runs is picked up.

const PATH := "res://assets/height_profiles/watch_tower_lower_stairs.tres"


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var towers := []
	for i in 2:
		var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
		tower.position = Vector2(1000 + i * 1200, 1000)
		level.add_child(tower)
		towers.append(tower)
	for f in 90: await process_frame
	print("before: lower stairs pass through %s, height class %s" % [towers.map(func(t): return t.part_pass("lower_stairs")), towers.map(func(t): return t.part_height_class("lower_stairs"))])
	var original := FileAccess.get_file_as_string(PATH)
	await create_timer(1.2).timeout   # (file times are to the second)
	var changed := original.replace("pass_through = 80", "pass_through = 5")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(changed)
	f.close()
	await create_timer(1.5).timeout
	print("after saving 5%%: lower stairs pass through %s, stair body height class %s" % [towers.map(func(t): return t.part_pass("lower_stairs")),
		towers.map(func(t): return t.get_node("StairsBody").height_class)])
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(original)
	f.close()
	quit()
