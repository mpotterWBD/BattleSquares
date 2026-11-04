extends SceneTree
## The 01:19 battle log's fight: the player 5.7 m behind the squad's
## sandbag wall, the squad dug in at it, four enemies arriving at their wall
## in the north-east. Records a battle log (F9) for the summary script.

const PX := 1024.0 / 12.0


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var seconds := float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 25.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = m(13.36, 16.74)
	for i in 10:
		var wall: Node2D = load("res://scenes/sandbags.tscn").instantiate()
		wall.position = m(19.1, 13.4) + Vector2(0, 68.0 * i)
		wall.rotation = PI / 2.0
		main.add_child(wall)
	var squad := get_nodes_in_group("squad")
	var ys := [16.54, 18.98, 15.73, 17.35, 18.20, 19.77]
	for i in squad.size():
		squad[i].global_position = m(18.0, ys[i])
	await ticks(2)
	for i in squad.size():
		squad[i].order_move(m(18.64, ys[i]), true)
	await ticks(120)
	await key(KEY_F9)
	await ticks(60)
	var enemies: Array[Node2D] = []
	for x in [39.4, 41.0, 42.6, 44.2]:
		var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
		enemy.position = m(x, 4.16)
		main.add_child(enemy)
		enemies.append(enemy)
	await ticks(1)
	for enemy in enemies:
		enemy.alert(player, player.global_position)
	await ticks(int(seconds * 60))
	await key(KEY_F9)
	for enemy in enemies:
		print("enemy %s: rounds left %d, target %s" % [enemy.name, enemy.get_node("Rifle").rounds,
				enemy.attack_target.name if enemy.attack_target else "-"])
	quit()
