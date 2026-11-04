extends SceneTree

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = player.global_position + Vector2(-2.0, -2.0) * PX
	main.add_child(tower)
	var cmd: Node = main.get_node("Command")
	for f in 3: await physics_frame
	cmd._start_placing("radio_station")
	cmd.process_mode = Node.PROCESS_MODE_DISABLED   # (it would read the real mouse)
	cmd._mouse_world = tower.global_position
	cmd._update_ghosts()
	for f in 10: await process_frame
	print("placing [%s] carried %d can mount %s part %s ghosts %d layout %s" % [cmd._placing, cmd._carried("radio_station"), tower.can_mount_station(), tower.part_at(cmd._mouse_world), cmd._ghosts.size(), cmd._layout()])
	root.get_texture().get_image().save_png("res://tower_radio_ghost.png")
	cmd._place(cmd._layout())
	cmd._stop_placing()
	var st: Node2D = tower.station
	st.install("desk")
	st.install("legs")
	for f in 10: await process_frame
	root.get_texture().get_image().save_png("res://tower_radio_site.png")
	for p in ["electronics", "dish", "wiring"]:
		st.install(p)
	var mate: Node2D = main.get_node("Squadmate")
	mate.global_position = st.get_node("OperatorZone").global_position
	mate._set_tower(tower)
	player.global_position = tower.to_global(Vector2(1.05, 0.9) * PX)
	player._set_tower(tower)
	for f in 40: await process_frame
	root.get_texture().get_image().save_png("res://tower_radio_built.png")
	quit()
