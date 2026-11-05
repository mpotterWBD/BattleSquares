extends SceneTree
## A screenshot of the supply truck in the level (supply_truck.gd): two
## trucks, one facing east and one turned 35 degrees, beside the player, with
## their swept shadows. Saves truck_shot.png. Opens a window (run without --headless).
const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	for spot in [[Vector2(-1.0, -2.2), 0.0], [Vector2(1.5, 2.6), deg_to_rad(35.0)]]:
		var truck: Node2D = load("res://scenes/supply_truck.tscn").instantiate()
		truck.position = player.position + spot[0] * PX
		truck.rotation = spot[1]
		main.add_child(truck)
	main.get_node("Camera")._target_zoom = 1.6
	for f in 90: await process_frame
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://truck_shot.png")
	quit()
