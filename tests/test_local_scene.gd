extends SceneTree
## What Local to Scene on a height profile does to two towers in a scene, and
## to its sections.
func _init() -> void:
	var p: HeightProfile = load("res://assets/height_profiles/watch_tower_top.tres").duplicate(true)
	p.resource_local_to_scene = true
	ResourceSaver.save(p, "res://local_test_profile.tres")
	var saved: HeightProfile = load("res://local_test_profile.tres")
	# A scene with two towers, the profile set on each in the Inspector.
	var root2 := Node2D.new()
	for i in 2:
		var t: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
		t.name = "Tower%d" % i
		t.top = saved
		root2.add_child(t)
		t.owner = root2
	var packed := PackedScene.new()
	packed.pack(root2)
	ResourceSaver.save(packed, "res://local_test_scene.tscn")
	var level: Node = load("res://local_test_scene.tscn").instantiate()
	root.add_child(level)
	var a: HeightProfile = level.get_node("Tower0").top
	var b: HeightProfile = level.get_node("Tower1").top
	print("set in the scene, Local to Scene on: towers share the profile %s; profile is the file's %s; share section 1 %s; section 1 is the file's %s" % [
		a == b, a == saved, a.shots_away[0] == b.shots_away[0], a.shots_away[0] == saved.shots_away[0]])
	# The default (not set in the scene): the script's preload.
	var top_file: HeightProfile = load("res://assets/height_profiles/watch_tower_top.tres")
	top_file.resource_local_to_scene = true
	var t1: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	var t2: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	print("left at the default, Local to Scene on: towers share it %s" % (t1.top == t2.top))
	t1.free()
	t2.free()
	quit()
