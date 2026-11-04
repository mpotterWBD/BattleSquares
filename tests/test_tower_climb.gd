extends SceneTree
## The player walks up a watch tower's stairs, round the deck, into the
## cabin, and back down.

const PX := 1024.0 / 12.0

var tower: Node2D
var player: Node2D

func _m() -> Vector2:
	return tower.to_local(player.global_position) / PX

func _walk(action: String, frames: int, stop := Callable()) -> void:
	Input.action_press(action)
	for f in frames:
		await physics_frame
		if stop.is_valid() and stop.call():
			break
	Input.action_release(action)
	for f in 20: await physics_frame

func _report(what: String) -> void:
	await process_frame
	print("%-34s at (%5.2f, %5.2f) m  on tower %-5s  height %.2f  z %d  body scale %.2f | roof alpha %.2f deck alpha %.2f" % [what, _m().x, _m().y,
			player.tower != null, player.elevation_m, player.z_index, player.get_node("Body").scale.x / (1.0 + player._height_m),
			tower.get_node("Roof").self_modulate.a, tower.get_node("Platform").self_modulate.a])

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(40, 10) * PX
	main.add_child(tower)
	for u in get_nodes_in_group("squad"):
		u.global_position += Vector2(0, 300)   # out of the way
	for f in 3: await physics_frame
	player.global_position = tower.to_global(Vector2(2.0, 5.5) * PX)
	for f in 5: await physics_frame
	await _report("start, south of the stair")
	await _walk("move_up", 60, func(): return _m().y < 3.0)
	await _report("up into the foot")
	await _walk("move_up", 400, func(): return _m().y < 1.5)
	await _report("on the mid landing")
	await _walk("move_up", 400, func(): return _m().y < -1.0)
	await _report("top landing")
	await _walk("move_left", 300)
	await _report("west along the north walkway?")
	player.global_position = tower.to_global(Vector2(1.05, 0.0) * PX)   # east walkway
	for f in 5: await physics_frame
	await _walk("move_right", 120)
	await _report("pushed east into the railing")
	await _walk("move_down", 200)
	await _report("pushed south (walkway corner)")
	player.global_position = tower.to_global(Vector2(1.05, -0.75) * PX)
	for f in 5: await physics_frame
	await _walk("move_left", 120)
	for f in 20: await process_frame
	await _report("in at the door")
	await _walk("move_right", 120)
	for f in 20: await process_frame
	await _report("back out of the door")
	player.global_position = tower.to_global(Vector2(2.0, -1.0) * PX)
	for f in 5: await physics_frame
	await _walk("move_down", 900, func(): return player.tower == null)
	await _report("walked down and off")
	await _walk("move_left", 200)
	await _report("on the ground west")
	player.global_position = tower.to_global(Vector2(0.0, 2.5) * PX)
	for f in 5: await physics_frame
	await _walk("move_up", 200)
	for f in 20: await process_frame
	await _report("ground: walked north under the deck")
	Input.action_press("move_up")
	for f in 5: await physics_frame
	var c = player.get_last_slide_collision()
	print("  blocked by %s (%s) layer %s" % [c.get_collider().name if c else "nothing", c.get_collider().get_parent().name if c else "", c.get_collider().collision_layer if c else 0])
	quit()
