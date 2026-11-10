extends SceneTree
## Debug mode: Q toggles it; every square has a number (player 0), stable for
## the level; a log started later uses the same numbers; a square that
## arrives later gets the next number.

const World = preload("res://scripts/world.gd")
const BattleLog = preload("res://scripts/battle_log.gd")


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


func numbers() -> String:
	var out := []
	for u in get_nodes_in_group("units"):
		out.append("%s=%d" % [u.name, BattleLog.number_of(u)])
	return ", ".join(out)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	for i in 3:
		await physics_frame
	print("before Q: debug=%s" % World.debug)
	await key(KEY_Q)
	var overlay: Node = null
	for c in main.get_node("Command").get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("debug_overlay.gd"):
			overlay = c
	print("after Q: debug=%s, overlay layer visible=%s" % [World.debug, overlay._layer.visible])
	print("numbers: ", numbers())
	# (the spawner drops enemies by helicopter now: placed straight in instead)
	for i in 3:
		var foe: Node2D = load("res://scenes/enemy.tscn").instantiate()
		foe.position = Vector2(40.0, 6.0 + 2.0 * i) * 1024.0 / 12.0
		main.add_child(foe)
	for i in 3:
		await physics_frame
	print("after 3 enemies arrive: ", numbers())
	# Kill squadmate 1, then start a log: its numbers must match.
	var squad := get_nodes_in_group("squad")
	squad[0].take_hit(squad[0].global_position, Vector2.UP, 1000.0, null)
	await physics_frame
	await key(KEY_F9)
	for i in 10:
		await physics_frame
	await key(KEY_F9)
	var log_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://logs/battle_log.txt"))
	var ok := true
	var us := []
	for line in log_text.split("\n"):
		var f := line.split("\t")
		if f.size() > 3 and f[1] == "U":
			us.append("%s=%s" % [f[4], f[2]])
			var node := main.find_child(f[4], true, false)
			if node and str(BattleLog.number_of(node)) != f[2]:
				ok = false
	print("log U lines: ", ", ".join(us))
	print("log numbers match overlay numbers: ", ok)
	await key(KEY_Q)
	print("after second Q: debug=%s, overlay layer visible=%s" % [World.debug, overlay._layer.visible])
	# Draw once with debug on, to be sure drawing doesn't error.
	await key(KEY_Q)
	for i in 3:
		await process_frame
	print("drew with debug on without errors")
	quit()
