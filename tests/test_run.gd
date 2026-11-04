extends SceneTree
## Shift runs at run_speed_mps; not while carrying, nor in command mode.

const World = preload("res://scripts/world.gd")


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func speed_over(player: Node2D, actions: Array) -> float:
	for a in actions:
		Input.action_press(a)
	await ticks(30)   # get up to speed
	var from := player.global_position
	await ticks(60)
	var moved := from.distance_to(player.global_position) / World.PX_PER_M
	for a in actions:
		Input.action_release(a)
	await ticks(60)   # stop
	return moved


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = Vector2(600, 600)
	player.global_position = Vector2(600, 600)
	print("walk: %.2f m/s" % await speed_over(player, ["move_right"]))
	player.global_position = Vector2(600, 600)
	print("run (Shift): %.2f m/s (run_speed_mps %.1f)" % [await speed_over(player, ["move_right", "run"]), player.run_speed_mps])
	player.run_speed_mps = 5.0
	player.global_position = Vector2(600, 600)
	print("run at 5.0: %.2f m/s" % await speed_over(player, ["move_right", "run"]))
	player.carrying = "sandbags"
	player.global_position = Vector2(600, 600)
	print("run carrying: %.2f m/s" % await speed_over(player, ["move_right", "run"]))
	player.carrying = ""
	player.global_position = Vector2(600, 600)
	print("run in command mode: %.2f m/s" % await speed_over(player, ["move_right", "run", "command"]))
	quit()
