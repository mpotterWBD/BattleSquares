extends SceneTree
## drop_off_animation off: player starts on the ground, early crates still drop.

const World = preload("res://scripts/world.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var c1: Node2D = main.get_node("AmmoCrate")
	c1.early_deploy = true
	var player: Node2D = main.get_node("Player")
	player.drop_off_animation = false
	root.add_child(main)
	current_scene = main
	var helis := 0
	var seen := []
	for f in 60 * 20:
		await physics_frame
		for n in main.get_children():
			if n.has_node("Hull") and not n in seen:
				seen.append(n)
				print("%5.1f s  helicopter appears" % (f / 60.0))
		if f == 5:
			print("  start: player visible %s, aboard %s, processing %s, crate in tree %s" % [player.visible, World.player_aboard, player.process_mode != Node.PROCESS_MODE_DISABLED, c1.is_inside_tree()])
	print("  20 s: helicopters %d, crate in tree %s, player visible %s aboard %s" % [seen.size(), c1.is_inside_tree(), player.visible, World.player_aboard])
	quit()
