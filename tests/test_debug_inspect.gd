extends SceneTree
## Debug mode: Q locks the player's controls and keeps command mode shut;
## a click on a square shows its ammo and magazines; Q again gives control back.

const World = preload("res://scripts/world.gd")


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


func click_at(world: Vector2) -> void:
	var screen := root.get_final_transform() * (root.get_canvas_transform() * world)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		await process_frame


func ticks(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	var overlay: Node = null
	for c in main.get_node("Command").get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("debug_overlay.gd"):
			overlay = c
	var rifle = player.get_node("Rifle")

	await key(KEY_Q)
	print("Q: debug=%s" % World.debug)
	var start := player.global_position
	var rounds_before: int = rifle.rounds
	Input.action_press("move_right")
	Input.action_press("shoot")
	await ticks(30)
	Input.action_release("shoot")
	Input.action_press("command")
	await ticks(2)
	print("in debug: moved %.2f m, rounds %d -> %d, commanding=%s" % [
			player.global_position.distance_to(start) / World.PX_PER_M, rounds_before, rifle.rounds, World.commanding()])
	Input.action_release("command")
	Input.action_release("move_right")

	var mate: Node2D = get_nodes_in_group("squad")[2]
	mate.get_node("Rifle").rounds = 7
	await click_at(mate.global_position + Vector2(10, 5))
	await ticks(1)
	print("clicked %s: picked=%s panel=%s" % [mate.name, overlay._picked.name if overlay._picked else "none", overlay._panel.visible])
	print("   panel: %s | %s | %s" % [overlay._name_label.text, overlay._ammo_label.text, overlay._mags_label.text])
	mate.get_node("Rifle").rounds = 3
	await ticks(1)
	print("   after it fired 4: %s" % overlay._ammo_label.text)
	print("   player rounds after the click: %d (no shot)" % rifle.rounds)
	await click_at(player.global_position)
	await ticks(1)
	print("clicked the player: %s | %s | %s" % [overlay._name_label.text, overlay._ammo_label.text, overlay._mags_label.text])
	await click_at(player.global_position + Vector2(400, 0))
	await ticks(1)
	print("clicked open ground: picked=%s panel=%s" % [overlay._picked, overlay._panel.visible])

	await click_at(mate.global_position)
	await key(KEY_Q)
	await ticks(1)
	print("Q again: debug=%s picked=%s layer=%s" % [World.debug, overlay._picked, overlay._layer.visible])
	start = player.global_position
	Input.action_press("move_right")
	await ticks(30)
	Input.action_release("move_right")
	print("after Q: moved %.2f m" % (player.global_position.distance_to(start) / World.PX_PER_M))
	quit()
