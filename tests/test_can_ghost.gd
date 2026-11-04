extends SceneTree
## Placing an ammo can from DEPLOY: the ghost's there and drawn; then
## clicking the ammo crate with one selected sends it to fetch.

const PX := 1024.0 / 12.0


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 5:
		await physics_frame
	for c in ["AmmoCrate", "AmmoCrate2"]:
		var crate: Node = main.get_node(c)
		print("%s builds='%s' parts=%d strapped=%s" % [c, crate.builds, crate.parts.size(), crate.strapped])
	Input.action_press("command")
	for i in 5:
		await process_frame
	var cmd: Node = main.get_node("Command")
	print("carried ammo_can: ", cmd._carried("ammo_can"))
	cmd._start_placing("ammo_can")
	cmd._mouse_world = Vector2(16, 17) * PX
	for i in 5:
		await process_frame
	print("placing '%s', ghosts %d" % [cmd._placing, cmd._ghosts.size()])
	for g in cmd._ghosts:
		var body: Sprite2D = g.get_node("Body")
		print("  ghost at %s m, visible %s, in tree %s, modulate %s, z %d (rel %s), body tex %s size %s, global z %d" % [
			g.global_position / PX, g.is_visible_in_tree(), g.is_inside_tree(), g.modulate, g.z_index, g.z_as_relative,
			body.texture.resource_path.get_file(), body.texture.get_size(), 0])
	for g in cmd._ghosts:
		print("  sandbags ghost compare:")
	cmd._stop_placing()
	cmd._start_placing("sandbags")
	for i in 3:
		await process_frame
	for g in cmd._ghosts:
		print("  sandbags ghost visible %s modulate %s z %d rel %s" % [g.is_visible_in_tree(), g.modulate, g.z_index, g.z_as_relative])
	cmd._stop_placing()
	Input.action_release("command")
	quit()
