extends SceneTree
## Two squadmates under a Build order put a watch tower up from its crate.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var crate: Node2D = load("res://scenes/crate_tower.tscn").instantiate()
	crate.position = Vector2(30, 20) * PX
	main.add_child(crate)
	crate.strapped = false
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(36, 20) * PX
	main.add_child(tower)
	for f in 3: await physics_frame
	tower.start_site(crate)
	var crew := [main.get_node("Squadmate"), main.get_node("Squadmate2")]
	for i in crew.size():
		crew[i].global_position = crate.global_position + Vector2(-1.5, i * 0.8) * PX
		crew[i].order_build()
	for s in 90:
		for f in 60: await physics_frame
		if s % 10 == 9 or tower.built:
			print("%3d s: installed %d/5 %s | crew %s carrying [%s, %s]" % [s + 1, tower.installed.size(), tower.installed.back() if not tower.installed.is_empty() else "",
					[crew[0].State.keys()[crew[0].state], crew[1].State.keys()[crew[1].state]], crew[0].carrying, crew[1].carrying])
		if tower.built:
			break
	quit()
