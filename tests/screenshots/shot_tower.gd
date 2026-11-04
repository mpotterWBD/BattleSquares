extends SceneTree

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var at: Vector2 = player.global_position
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = at + Vector2(3.5, -1.5) * PX
	main.add_child(tower)
	var site: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	site.position = at + Vector2(-6.5, -1.5) * PX
	main.add_child(site)
	var crate: Node2D = load("res://scenes/crate_tower.tscn").instantiate()
	crate.position = at + Vector2(-2.5, 3.0) * PX
	main.add_child(crate)
	for f in 3: await physics_frame
	site.start_site(crate)
	site.install("tower_base")
	site.install("tower_platform")
	for f in 40: await process_frame
	root.get_texture().get_image().save_png("res://tower_shot.png")
	quit()
