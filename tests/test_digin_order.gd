extends SceneTree
const PX := 1024.0 / 12.0
func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(12, 8) * PX
	main.add_child(tower)
	var walls := []
	for i in 9:
		var w: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		w.position = tower.to_global(Vector2(2.75, -1.4 + i * 0.797) * PX)
		w.rotation = PI / 2
		main.add_child(w)
		walls.append(w)
	for f in 5: await physics_frame
	var cmd: Node = main.get_node("Command")
	var mates := get_nodes_in_group("squad").slice(0, 3)
	for side in [["stair side (west)", -0.4], ["far side (east)", 0.4]]:
		cmd._man_sandbags(walls[3].global_position + Vector2(side[1], 0) * PX, mates)
		var where := mates.map(func(m): return (tower.to_local(m.destination) / PX).snapped(Vector2(0.01, 0.01)))
		print("%s: sent to %s" % [side[0], where])
	quit()
