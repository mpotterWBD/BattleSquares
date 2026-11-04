extends SceneTree
## Main level: an ammo can site laid near the player; one squadmate selected,
## a click on the near AmmoCrate sends it to fetch and deliver.

const PX := 1024.0 / 12.0


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func click(world: Vector2) -> void:
	var screen := root.get_final_transform() * (root.get_canvas_transform() * world)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		await process_frame
	await ticks(3)


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await ticks(5)
	var crate: Node2D = main.get_node("AmmoCrate")
	print("AmmoCrate builds '%s', parts %d, strapped %s" % [crate.builds, crate.parts.size(), crate.strapped])
	var cmd: Node = main.get_node("Command")
	var squad := get_nodes_in_group("squad")
	for u in squad:
		u.get_node("Rifle")._spares = [30, 30] as Array[int]   # keep them off ammo runs
	var can: Node2D = load("res://scenes/ammo_supply.tscn").instantiate()
	can.position = crate.global_position + Vector2(3.0, 2.0) * PX
	main.add_child(can)
	var supplies: Array = cmd._supply_crates("ammo_can", can.position)
	can.start_site(supplies[0])
	print("site's crate: ", supplies[0].name)
	Input.action_press("command")
	await ticks(5)
	var mate: Node2D = squad[0]
	await click(mate.global_position)
	await click(crate.global_position)
	print("after crate click: mate state %s, from %s" % [mate.State.keys()[mate.state], mate._build_from.name if mate._build_from else "-"])
	Input.action_release("command")
	var t := 0
	var carried := false
	while not can.built and t < 1500:
		await physics_frame
		t += 1
		if mate.carrying == "ammo_can" and not carried:
			carried = true
			print("   picked up a can at %.1f s (crate strapped %s, taken %d)" % [t / 60.0, crate.strapped, crate.taken])
	print("can built %s at %.1f s; mate %s" % [can.built, t / 60.0, mate.State.keys()[mate.state]])
	quit()
