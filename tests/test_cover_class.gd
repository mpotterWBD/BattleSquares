extends SceneTree
const Cover = preload("res://scripts/cover.gd")
func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var things := {}
	var x := 300
	for path in ["crate_ammo", "crate_comms", "crate_sandbags", "ammo_can", "sandbags", "radio_station", "helicopter", "squadmate"]:
		var n: Node2D = load("res://scenes/%s.tscn" % path).instantiate()
		n.position = Vector2(x, 1000)
		x += 400
		level.add_child(n)
		things[path] = n
	for i in 3:
		await physics_frame
	var st: Node2D = things.radio_station
	for k in things:
		if k == "radio_station" or k == "helicopter":
			continue
		print("%-15s stops %3.0f%%  class %d" % [k, Cover.stop_chance(things[k]) * 100, Cover.class_of(things[k])])
	for body in ["DeskBody", "DishBody"]:
		var b = st.get_node(body)
		print("%-15s stops %3.0f%%  class %d (cover_class() %d)" % [body, Cover.stop_chance(b) * 100, Cover.class_of(b), b.cover_class()])
	var hull = things.helicopter.get_node("Hull")
	print("%-15s stops %3.0f%%  class %d" % ["helicopter Hull", Cover.stop_chance(hull) * 100, Cover.class_of(hull)])
	var wall: Node2D = things.sandbags
	for i in 30:
		wall.bullet_hit(wall.global_position, Vector2.DOWN, 2.0)
	print("sandbags shot down: collapsed=%s class %d" % [wall.is_collapsed(), wall.cover_class()])
	print("boundaries: 0.4 -> %d, 0.41 -> %d, 0.6 -> %d, 0.61 -> %d" % [Cover.class_for(0.4), Cover.class_for(0.41), Cover.class_for(0.6), Cover.class_for(0.61)])
	quit()
