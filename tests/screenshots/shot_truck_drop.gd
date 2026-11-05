extends SceneTree
## Screenshots of the supply truck's crane squares and drop-off ghost (supply_truck.gd,
## command.gd): the squares beside the bed with crates in them (command mode, Crane
## selected), then with both crates loaded and 2 boxes chosen, the green ghost on the
## side of the truck the mouse is on. Saves truck_drop_1.png .. _3.png. Opens a window.
const PX := 1024.0 / 12.0


func shot(name: String) -> void:
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://truck_drop_%s.png" % name)
	paused = false


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for child in main.get_children():
		if (child is CollisionObject2D and child.name != "Player") or child.is_in_group("watch_towers") \
				or child.name.begins_with("Sandbag") or child.name.begins_with("Crate"):
			child.queue_free()
	var player: CharacterBody2D = main.get_node("Player")
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	truck.position = Vector2(22.0, 12.6) * PX
	main.add_child(truck)
	var command: Node = main.get_node("Command")
	for f in 4: await physics_frame
	for c in main.get_children():
		if c is StaticBody2D:
			c.queue_free()
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	await physics_frame
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = truck.to_global(Vector2(0.5, 3.6) * PX)
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	for f in 4: await physics_frame
	mate.selected = true
	command._click(truck.to_global(Vector2(-1.2, 0.3) * PX), false)
	mate.selected = false
	while truck.passenger == null:
		await physics_frame
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	truck.get_in(player)
	while truck.driver == null:
		await physics_frame
	main.get_node("Camera")._target_zoom = 2.0
	var crates := []
	for spec in [["crate_ammo", Vector2(-0.6, 1.3)], ["crate_comms", Vector2(-1.8, -1.3)]]:
		var crate: Node2D = load("res://scenes/%s.tscn" % spec[0]).instantiate()
		main.add_child(crate)
		crate.global_position = truck.to_global(spec[1] * PX)
		crates.append(crate)
	command._give_vehicle_order("crane")
	Input.action_press("command")
	t_wait(self)
	for f in 40: await physics_frame
	await shot("1")
	for c in crates:
		command._click(c.global_position, false)
	var t := 0.0
	while (truck._bed[0] == null or truck._bed[1] == null) and t < 150.0:
		await physics_frame
		t += 1.0 / 60.0
	for f in 60: await physics_frame
	command._open_crane_popout(command._vehicle_buttons[1], true)
	command._start_crane_drop(2)
	var left := command.get_viewport().get_canvas_transform() * truck.to_global(Vector2(-1.0, -2.5) * PX)
	root.warp_mouse(left)
	for f in 10: await physics_frame
	await shot("2")
	var right := command.get_viewport().get_canvas_transform() * truck.to_global(Vector2(-1.0, 2.5) * PX)
	root.warp_mouse(right)
	for f in 10: await physics_frame
	await shot("3")
	Input.action_release("command")
	quit()


func t_wait(_n) -> void:
	pass
