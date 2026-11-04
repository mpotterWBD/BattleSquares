extends SceneTree
## The player hops higher and waddles more than a squadmate while walking.

func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	var mate: Node2D = get_nodes_in_group("squad")[0]
	print("player hop %.2f m waddle %.1f deg; squadmate hop %.2f m waddle %.1f deg" % [player.hop_height_m, player.waddle_deg, mate.hop_height_m, mate.waddle_deg])
	player.global_position = Vector2(600, 600)
	Input.action_press("move_right")
	var top := 0.0
	var sway := 0.0
	for i in 120:
		await physics_frame
		top = maxf(top, player._height_m)
		sway = maxf(sway, absf(rad_to_deg(deg_to_rad(player.waddle_deg) * sin(player._hop_phase) * signf(player._height_m))))
	Input.action_release("move_right")
	print("walking 2 s: highest hop %.3f m, widest sway %.1f deg" % [top, sway])
	quit()
