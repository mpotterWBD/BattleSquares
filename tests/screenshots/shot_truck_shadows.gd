extends SceneTree
## Close-ups of the supply truck's shadows (Mike, 2026-11-11: the crates on the
## bed and their shadows didn't meet; the boom cast none): the crane is posed
## directly (turned and reached out, crates set on the bed or hung on the hook),
## not run through a job. Saves truck_shadow_<name>.png. Opens a window (run
## without --headless).
const PX := 1024.0 / 12.0


func shot(name: String) -> void:
	for f in 3: await process_frame
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://truck_shadow_%s.png" % name)
	paused = false


func crate_at(main: Node, truck: Node2D, kind: String) -> Node2D:
	var crate: Node2D = load("res://scenes/%s.tscn" % kind).instantiate()
	main.add_child(crate)
	crate.mount()
	crate.reparent(truck, true)
	return crate


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for child in main.get_children():
		if (child is CollisionObject2D and child.name != "Player") or child.is_in_group("watch_towers") \
				or child.name.begins_with("Sandbag") or child.name.begins_with("Crate"):
			child.queue_free()
	var player: CharacterBody2D = main.get_node("Player")
	var truck: CharacterBody2D = load("res://scenes/supply_truck.tscn").instantiate()
	truck.position = Vector2(22.0, 12.6) * PX
	main.add_child(truck)
	for f in 4: await physics_frame
	for node in get_nodes_in_group("squad") + get_nodes_in_group("crates"):
		node.queue_free()
	player.global_position = truck.to_global(Vector2(0.2, -6.0) * PX)
	# The camera looks at the bed (a marker: the camera asks its target if it's dead).
	var looks := GDScript.new()
	looks.source_code = "extends Node2D\nvar dead := false\n"
	looks.reload()
	var marker := Node2D.new()
	marker.set_script(looks)
	main.add_child(marker)
	marker.global_position = truck.to_global(Vector2(-0.6, 0.6) * PX)
	main.get_node("Camera")._target = marker
	main.get_node("Camera")._target_zoom = 2.6
	for f in 60: await physics_frame
	# Two crates on the bed, the arm turned back over them (Mike's first two pictures).
	var bed := [crate_at(main, truck, "crate_ammo"), crate_at(main, truck, "crate_comms")]
	for i in 2:
		bed[i].position = Vector2(truck.SLOT_X_M[i], 0.0) * PX
		bed[i].height_m = truck.BED_Z_M
		truck._bed[i] = bed[i]
	truck._slew = PI
	truck._reach_m = truck.ARM_M
	await shot("bed")
	# The nearer crate on the hook, the boom out over the ground (his third).
	truck._bed[1] = null
	truck._slew = 2.2
	truck._reach_m = 2.3
	bed[1].height_m = truck.CARRY_M
	bed[1].position = truck._hook_m() * PX
	await shot("hook")
	# Folded, the hook close in at the side.
	truck._slew = PI / 2
	truck._reach_m = 0.8
	bed[1].position = truck._hook_m() * PX
	await shot("folded")
	# A real job: a squadmate runs the crane and loads a crate from the square beside the bed.
	for i in 2:
		bed[i].queue_free()
	truck._bed = [null, null]
	truck._slew = 0.0
	truck._reach_m = truck.ARM_M
	var command: Node = main.get_node("Command")
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	mate.global_position = truck.to_global(Vector2(0.5, 2.6) * PX)
	for f in 4: await physics_frame
	mate.selected = true
	command._click(truck.to_global(Vector2(-1.2, 0.0) * PX), false)
	mate.selected = false
	while truck.passenger == null:
		await physics_frame
	player.global_position = truck.to_global(Vector2(1.5, -1.3) * PX)
	truck.get_in(player)
	while truck.driver == null:
		await physics_frame
	var crate: Node2D = load("res://scenes/crate_comms.tscn").instantiate()
	main.add_child(crate)
	crate.global_position = truck.to_global(Vector2(-1.4, -1.5) * PX)
	command._give_vehicle_order("crane")
	var t := 0.0
	while truck._cphase != truck.CranePhase.WORKING and t < 30.0:
		await physics_frame
		t += 1.0 / 60.0
	print("crane: ", truck.crane_click(crate.global_position))
	t = 0.0
	while (truck._bed[0] == null or truck._job != null) and t < 90.0:
		await physics_frame
		t += 1.0 / 60.0
	print("loaded: ", truck._bed, " after ", t, " s")
	await shot("loaded")
	quit()
