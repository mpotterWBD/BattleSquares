extends SceneTree
## A screenshot of getting into the supply truck (supply_truck.gd): the
## driver's door swung open and the player's square stepping up into the cab.
## Saves truck_door_shot.png. Opens a window (run without --headless).
const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var truck: Node2D = load("res://scenes/supply_truck.tscn").instantiate()
	truck.position = player.position + Vector2(-1.5, 1.6) * PX
	main.add_child(truck)
	main.get_node("Camera")._target_zoom = 2.6
	for f in 30: await process_frame
	player.global_position = truck.to_global(Vector2(1.4, -1.25) * PX)
	for f in 30: await process_frame
	truck.get_in(player)
	while truck._step != truck.Step.STEP_IN:
		await physics_frame
	for f in 9: await physics_frame
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://truck_door_shot.png")
	quit()
