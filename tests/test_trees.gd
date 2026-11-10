extends SceneTree
## Trees (Mike, 2026-11-09): every type (pine, spruce, oak, maple, cottonwood)
## at every growth (sapling, young, mature) has its measurements, picture and
## shadow; a mature one is bigger than a young one, a young one than a
## sapling; its shadow falls to the bottom right (the sun's top left), the
## farther the taller it is; Size scales it all, trunk too; its crown fades
## while a square's under it and comes back after; its trunk is solid: a
## square walking into it stops, and it's heavy cover (cover.gd class 3).
## Prints each one's sizes.
const PX := 1024.0 / 12.0
const Cover = preload("res://scripts/cover.gd")
const TreeScript = preload("res://scripts/tree.gd")

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad"):
		node.queue_free()

	var all_ok := true
	var grows := true
	for t in 5:
		var heights := []
		for g in 3:
			var d: Dictionary = TreeScript.info(t, g)
			var name := "%s %s" % [TreeScript.TYPE_NAMES[t], TreeScript.GROWTH_NAMES[g]]
			if d.is_empty():
				all_ok = false
				print("    %s: no measurements" % name)
				continue
			var tree: Node2D = load("res://scenes/tree.tscn").instantiate()
			tree.type = t
			tree.growth = g
			tree.position = Vector2(60.0 + 30.0 * t, 40.0 + 30.0 * g) * PX
			main.add_child(tree)
			await process_frame
			var ok: bool = tree._canopy.texture != null and tree._shadow.texture != null
			var off: Vector2 = tree._shadow.position / PX
			ok = ok and off.x > 0.0 and off.y > 0.0   # bottom right
			print("    %s: %.1f m tall, crown %.1f m across, trunk %.2f m across, shadow centred at %s m%s" % [
					name, d.height_m, d.canopy_radius_m * 2.0, d.trunk_radius_m * 2.0, off, "" if ok else "  <-- FAILED (textures %s %s)" % [tree._canopy.texture != null, tree._shadow.texture != null]])
			all_ok = all_ok and ok
			heights.append(float(d.height_m))
		if heights.size() == 3:
			grows = grows and heights[0] < heights[1] and heights[1] < heights[2]
	check("all 15 (5 types x 3 growths): measurements, picture and shadow, the shadow to the bottom right", all_ok)
	check("each type: a sapling shorter than a young tree, a young one than a mature one", grows)

	# Size: everything scales.
	var big: Node2D = load("res://scenes/tree.tscn").instantiate()
	big.type = TreeScript.Type.MAPLE
	big.position = Vector2(30.0, 60.0) * PX
	main.add_child(big)
	await process_frame
	var r1: float = big._trunk_shape.radius
	var s1: Vector2 = big._shadow.position
	big.size = 1.5
	check("Size 150%: crown, trunk and shadow's offset all 1.5x", is_equal_approx(big._canopy.scale.x, 1.5)
			and absf(big._trunk_shape.radius / r1 - 1.5) < 0.01 and big._shadow.position.distance_to(s1 * 1.5) < 0.5)

	# The crown fades over a square, and comes back.
	var oak: Node2D = load("res://scenes/tree.tscn").instantiate()
	oak.type = TreeScript.Type.OAK
	oak.position = Vector2(30.0, 100.0) * PX
	main.add_child(oak)
	var player: Node2D = main.get_node("Player")
	player.global_position = oak.global_position + Vector2(3.0, 2.0) * PX
	for f in 60: await process_frame
	var faded: float = oak._canopy.modulate.a
	player.global_position = oak.global_position + Vector2(20.0, 0.0) * PX
	for f in 60: await process_frame
	check("a square under the oak's crown: it fades (%.2f); out from under, it's back (%.2f)" % [faded, oak._canopy.modulate.a],
			faded < 0.5 and oak._canopy.modulate.a > 0.99)

	# The trunk: solid, heavy cover.
	check("its trunk is heavy cover (class %d)" % Cover.class_of(oak._trunk), Cover.class_of(oak._trunk) == Cover.HEAVY)
	player.global_position = oak.global_position + Vector2(-3.0, 0.0) * PX
	await physics_frame
	Input.action_press("move_right")
	for f in 150: await physics_frame
	Input.action_release("move_right")
	var gap: float = (oak.global_position.x - player.global_position.x) / PX
	check("the player walking into its trunk stops at it (%.2f m from its middle)" % gap, gap > 0.3 and gap < 1.0)
	print("%s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
