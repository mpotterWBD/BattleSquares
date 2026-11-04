extends SceneTree
const PX := 1024.0 / 12.0
const Cover = preload("res://scripts/cover.gd")
func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(20, 12) * PX
	level.add_child(tower)
	for f in 3: await physics_frame
	for part in ["lower_stairs", "upper_stairs", "top", "shelter", "base"]:
		print("%-13s middle %s m from the tower's" % [part, (tower.to_local(tower.part_middle(part)) / PX).snapped(Vector2(0.01, 0.01))])
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	mate.position = tower.to_global(Vector2(2.0, 3.0) * PX)
	level.add_child(mate)
	mate._set_tower(tower)
	await physics_frame
	var bags: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	bags.position = tower.to_global(Vector2(2.0, 7.5) * PX)   # 4.45 m from the lower flight's middle, 7.8 from the tower's
	level.add_child(bags)
	await physics_frame
	print("on the %s: sandbags 4.45 m from its middle -> Shots Away section %d" % [tower.part_of(mate),
		HeightProfile.section_number(tower.lower_stairs.shots_away, Cover._profile_middle(mate).distance_to(bags.global_position) / PX)])
	quit()
