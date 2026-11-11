extends SceneTree
## Screenshots of the supply truck's stabilisers (Mike, 2026-11-11: a Blender
## animation, supply_truck_stabilizer_sheet.png) at four points of coming down,
## _stab 0, 0.3, 0.6 and 1, close up, the truck turned a little so the
## mirrored right one and the shadows show. Saves truck_stabs_0.png .. _3.png.
## Also checks the frames picked and the shadows' sweeps (numbers: background
## windows often stop drawing). Opens a window (run without --headless).
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func shot(name: String) -> void:
	paused = true
	for f in 3:   # (a few draws, with a limit: a background window may not draw at all)
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://truck_stabs_%s.png" % name)
	paused = false


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for child in main.get_children():
		if (child is CollisionObject2D and child.name != "Player") or child.is_in_group("watch_towers") \
				or child.name.begins_with("Sandbag") or child.name.begins_with("Crate"):
			child.queue_free()
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates") + get_nodes_in_group("vehicles") + get_nodes_in_group("trees"):
		node.queue_free()
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	truck.position = Vector2(22.0, 13.0) * PX
	truck.rotation = 0.35
	main.add_child(truck)
	# (The camera follows the player: parked just ahead of the truck, out of the way.)
	main.get_node("Player").global_position = truck.to_global(Vector2(0.23, -2.0) * PX)
	main.get_node("Camera")._target_zoom = 3.0
	for f in 60: await physics_frame
	var frames := []
	for k in 4:
		var s: float = [0.0, 0.3, 0.6, 1.0][k]
		truck._stab = s
		truck._stab_was = s
		for f in 3: await physics_frame
		await process_frame
		await process_frame
		print("    _stab %.2f (cphase %d), frame %d" % [truck._stab, truck._cphase, truck._stabs[0].frame])
		frames.append(truck._stabs[0].frame)
		check("_stab %.1f: both stabilisers on frame %d of %d" % [s, truck._stabs[0].frame, truck.STAB_FRAMES],
				truck._stabs[0].frame == roundi(s * (truck.STAB_FRAMES - 1)) and truck._stabs[1].frame == truck._stabs[0].frame
				and truck._stab_shadows[0].frame == truck._stabs[0].frame and truck._stab_shadows[1].frame == truck._stabs[0].frame)
		var a: Vector2 = truck._stab_shadows[0].material.get_shader_parameter("sweep")
		var b: Vector2 = truck._stab_shadows[1].material.get_shader_parameter("sweep")
		check("  the right one's shadow sweep is the left's mirrored (%s, %s)" % [a, b], a.is_equal_approx(Vector2(b.x, -b.y)))
		await shot(str(k))
	var left: Sprite2D = truck._stabs[0]
	check("the left one at -y (%s), the right mirrored at +y" % left.position, left.position.y < 0.0
			and truck._stabs[1].position.is_equal_approx(Vector2(left.position.x, -left.position.y)) and truck._stabs[1].flip_v)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
