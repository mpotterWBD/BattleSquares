extends SceneTree
## Windowed: debug mode with states showing, one squadmate picked.

const PX := 1024.0 / 12.0
const DebugOverlay = preload("res://scripts/debug_overlay.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 10:
		await physics_frame
	var player: Node2D = get_first_node_in_group("player")
	var squad := get_nodes_in_group("squad")
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	enemy.position = player.global_position + Vector2(6, -1) * PX
	main.add_child(enemy)
	for i in squad.size():
		squad[i].global_position = player.global_position + Vector2(1.2 + (i % 3) * 1.4, -1.2 + (i / 3) * 1.6) * PX
		squad[i].order_attention(squad[i].global_position, 0.0)
	await physics_frame
	squad[0].attack_target = enemy
	squad[1].state = squad[1].State.DEFEND
	squad[2].state = squad[2].State.PINNED
	squad[3].holding_fire = true
	squad[3].attack_target = enemy
	squad[4].state = squad[4].State.SURPRISED
	enemy.mode = enemy.Mode.ENGAGE
	enemy.attack_target = squad[0]
	var overlay: Node = null
	for n in main.find_children("*", "", true, false):
		if n.get_script() == DebugOverlay:
			overlay = n
	World_debug(overlay)
	overlay._picked = squad[0]
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (player.global_position + Vector2(3, 0) * PX))
	var r := Rect2i(Vector2i(c) - Vector2i(380, 200), Vector2i(760, 400)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png("debug_states.png")
	print("picked panel: ", overlay._state_label.text, " | ", overlay._detail_label.text.replace("\n", "; "))
	for u in [enemy] + squad:
		var s: Dictionary = overlay._status(u)
		print("%s: %s %s" % [u.name, s.word, s.tags])
	quit()

func World_debug(overlay: Node) -> void:
	var World = load("res://scripts/world.gd")
	World.debug = true
	overlay._layer.visible = true
