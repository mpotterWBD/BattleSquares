extends SceneTree
## Screenshots of the supply truck's crane (supply_truck.gd): the reach circle
## in command mode with crates round it, the crane mid-job (stabilisers down,
## boom out, a crate on the hook), and the loaded bed once it's stowed.
## Saves truck_crane_1.png .. _4.png. Opens a window (run without --headless).
const PX := 1024.0 / 12.0


func shot(name: String) -> void:
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://truck_crane_%s.png" % name)
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
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	await physics_frame
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = truck.to_global(Vector2(0.5, 2.6) * PX)
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	for f in 4: await physics_frame
	mate.selected = true
	command._click(truck.to_global(Vector2(-1.2, 0.0) * PX), false)
	mate.selected = false
	while truck.passenger == null:
		await physics_frame
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	truck.get_in(player)
	while truck.driver == null:
		await physics_frame
	main.get_node("Camera")._target_zoom = 2.4
	var crates := []
	for spec in [["crate_ammo", Vector2(0.5, 1.9)], ["crate_comms", Vector2(-0.8, 2.0)], ["crate_sandbags", Vector2(2.6, 3.0)]]:
		var crate: Node2D = load("res://scenes/%s.tscn" % spec[0]).instantiate()
		main.add_child(crate)
		crate.global_position = truck.to_global(spec[1] * PX)
		crates.append(crate)
	command._give_vehicle_order("crane")
	Input.action_press("command")
	for f in 40: await physics_frame
	await shot("1")
	command._click(crates[0].global_position, false)
	command._click(crates[1].global_position, false)
	Input.action_release("command")
	var got := {}
	var t := 0.0
	while truck._cphase != truck.CranePhase.IDLE or t < 2.0:
		await physics_frame
		t += 1.0 / 60.0
		if not got.has("2") and truck._cphase == truck.CranePhase.DEPLOYING and truck._stab > 0.45:
			got["2"] = true
			await shot("2")
		if not got.has("3") and truck._job != null and truck._job.step == truck.JobStep.SWING and absf(truck._slew) > 1.4:
			got["3"] = true
			await shot("3")
		if not got.has("4") and truck._cphase == truck.CranePhase.WORKING and truck._job == null and truck._bed[1] != null:
			got["4"] = true
			await shot("4")
		if t > 80.0:
			break
	# The loaded bed with the truck turned, the crates' shadows on it and past its back (as Mike's picture).
	for f in 120: await physics_frame
	truck.rotation = -0.5
	var marker := Node2D.new()   # (the camera looks at the bed)
	main.add_child(marker)
	marker.global_position = truck.to_global(Vector2(-1.2, 0.0) * PX)
	main.get_node("Camera")._target = marker
	main.get_node("Camera")._target_zoom = 3.0
	for f in 20: await physics_frame
	await shot("5")
	print("shots: ", got.keys())
	quit()
