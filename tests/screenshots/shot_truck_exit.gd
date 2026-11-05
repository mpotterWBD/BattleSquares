extends SceneTree
## Frames of the passenger getting out of the supply truck to run the crane
## (supply_truck.gd), zoomed in on the cab's passenger side: truck_exit_00.png ...
## one every FRAMES_PER_SHOT physics ticks from the door starting to open until
## it's standing at the controls. Opens a window (run without --headless).
const PX := 1024.0 / 12.0
const FRAMES_PER_SHOT := 14


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
	main.get_node("Camera")._target_zoom = 4.2
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = truck.to_global(Vector2(0.5, 2.0) * PX)
	command._give_vehicle_order("crane")
	for f in 30: await physics_frame
	command._click(crate.global_position, false)
	var seat = truck._seats[1]
	while seat.step == truck.Step.NONE:
		await physics_frame
	var n := 0
	var f := 0
	while truck._cphase != truck.CranePhase.DEPLOYING and n < 40:
		await physics_frame
		f += 1
		if f % FRAMES_PER_SHOT == 0:
			paused = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://truck_exit_%02d.png" % n)
			paused = false
			print("shot %02d  phase %d  step %d  mate at %s" % [n, truck._cphase, seat.step, truck.to_local(mate.global_position) / PX])
			n += 1
	quit()
