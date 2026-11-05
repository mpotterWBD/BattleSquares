extends SceneTree
## Screenshots of the supply truck driving itself (vehicle_ai.gd) into a bay off the
## road (it backs in): selected in command mode with its planned path drawn, part way
## through the reverse, and parked. Saves truck_ai_1.png .. _3.png. Opens a window.
const PX := 1024.0 / 12.0


func shot(name: String) -> void:
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://truck_ai_%s.png" % name)
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
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	main.add_child(truck)
	var player: CharacterBody2D = main.get_node("Player")
	var command: Node = main.get_node("Command")
	for f in 4: await physics_frame
	for c in main.get_children():
		if c is StaticBody2D:
			c.queue_free()
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	await physics_frame
	truck.global_position = Vector2(22.0, 13.0) * PX
	player.global_position = Vector2(27.0, 16.5) * PX
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = Vector2(23.5, 16.0) * PX
	for f in 4: await physics_frame
	mate.order_ride(truck, -1)
	while truck.driver == null:
		await physics_frame
	main.get_node("Camera")._target_zoom = 0.85
	Input.action_press("command")
	for f in 30: await physics_frame
	command._select_truck(truck)
	command._click(Vector2(27.0, 19.8) * PX, false)
	for f in 20: await physics_frame
	await shot("1")
	var got := false
	var t := 0.0
	while truck.ai_status() == "driving" and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
		if not got and truck.speed < -1.0 and truck.global_position.y > 15.5 * PX:
			got = true
			await shot("2")
	for f in 60: await physics_frame
	await shot("3")
	Input.action_release("command")
	quit()
