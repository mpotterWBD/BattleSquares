extends SceneTree
## Command mode: ORDERS and DEPLOY stacked left of the player, a gap between.

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 5:
		await physics_frame
	Input.action_press("command")
	for i in 10:
		await process_frame
	var cmd: Node = null
	for n in main.find_children("*", "", true, false):
		if n.get("_deploy_menu") != null:
			cmd = n
			break
	var player: Node2D = get_first_node_in_group("player")
	var screen: Vector2 = root.get_canvas_transform() * player.global_position
	print("player on screen ", screen)
	print("ORDERS ", cmd._menu.get_global_rect(), " visible ", cmd._menu.visible)
	print("DEPLOY ", cmd._deploy_menu.get_global_rect(), " visible ", cmd._deploy_menu.visible, " button '", cmd._deploy_button.text, "'")
	print("gap ", cmd._deploy_menu.get_global_rect().position.y - cmd._menu.get_global_rect().end.y)
	Input.action_release("command")
	quit()
