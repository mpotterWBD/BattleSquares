extends SceneTree
## Battle log: the main level, F9 starts a log, the squad is sent to fight
## the enemies for a while, the log is stopped; prints how many of each
## line there are and the file's start. Run twice to check a new log wipes
## the old one (the line count doesn't grow).

const PX := 1024.0 / 12.0


func f9() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F9
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await physics_frame
	var log_node: Node = null
	for child in main.get_node("Command").get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("battle_log.gd"):
			log_node = child
	await f9()
	for i in 5:
		await process_frame
	print("logging after F9: ", log_node._file != null, "  path ", log_node._path)
	var spawner: Node = main.get_node("EnemySpawner")
	spawner.spawn(4, spawner.FORMATIONS[0])
	for i in 3:
		await physics_frame
	var enemies := get_nodes_in_group("enemies")
	var squad := get_nodes_in_group("squad")
	print("enemies %d, squad %d" % [enemies.size(), squad.size()])
	# Squad: half sent toward the enemies, half told to fire at the first one.
	for i in squad.size():
		if i % 2 == 0:
			squad[i].order_move(enemies[0].global_position + Vector2(-6 * PX, (i - 2) * 0.8 * PX))
		else:
			squad[i].order_attack(enemies[0])
	for e in enemies:
		e.alert(squad[0])
	for i in 60 * 15:
		await physics_frame
	log_node.toggle()
	print("logging after stop: ", log_node._file != null, "  note: ", log_node._note.text)
	var text := FileAccess.get_file_as_string(log_node._path)
	var counts := {}
	for line in text.split("\n"):
		if line.begins_with("#") or line == "":
			continue
		var code := line.get_slice("\t", 1)
		counts[code] = counts.get(code, 0) + 1
	print("lines by code: ", counts, "   bytes ", text.length())
	var shown := 0
	for line in text.split("\n"):
		if not line.begins_with("#"):
			print("  | ", line)
			shown += 1
			if shown > 45:
				break
	quit()
