extends SceneTree
## Running on dirt plays the looped SprintOnDirt footfalls; walking, stopping
## or running on the road's asphalt doesn't.

const World = preload("res://scripts/world.gd")


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
	var steps: AudioStreamPlayer2D = player._run_steps
	print("loaded: %s, loops=%s, length %.2f s" % [steps != null, steps.stream.loop, steps.stream.get_length()])
	player.global_position = Vector2(600, 600)
	Input.action_press("move_right")
	await ticks(40)
	print("walking: playing=%s" % steps.playing)
	Input.action_press("run")
	await ticks(40)
	print("running on dirt: playing=%s at %.2f s, %.1f dB" % [steps.playing, steps.get_playback_position(), steps.volume_db])
	Input.action_release("run")
	await ticks(3)
	print("let go of Shift, 3 ticks: playing=%s %.1f dB" % [steps.playing, steps.volume_db])
	await ticks(30)
	print("0.5 s later: playing=%s" % steps.playing)
	Input.action_release("move_right")
	# Onto the road.
	var road: Node2D = get_first_node_in_group("roads")
	var on_road := Vector2.INF
	if road:
		for i in 200:
			var p: Vector2 = road.to_global(road.curve.sample_baked(road.curve.get_baked_length() * i / 200.0))
			if road.covers(p) and road.covers(p + Vector2(150, 0)) and World.ARENA.grow(-200).has_point(p):
				on_road = p
				break
	if on_road == Vector2.INF:
		print("no road in reach to test")
	else:
		player.global_position = on_road
		Input.action_press("move_right")
		Input.action_press("run")
		await ticks(20)
		print("running on the road (%s): playing=%s" % [road.covers(player.global_position), steps.playing])
		Input.action_release("run")
		Input.action_release("move_right")
	quit()
