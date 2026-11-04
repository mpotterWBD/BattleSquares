extends SceneTree
## Squadmates take a watch tower's stairs: sent up onto the deck, into the
## cabin, back down; and following the player up there.

const PX := 1024.0 / 12.0

var tower: Node2D

func _m(u) -> Vector2:
	return tower.to_local(u.global_position) / PX

func _go(mate, spot_m: Vector2, label: String, max_s := 30) -> void:
	mate.order_move(tower.to_global(spot_m * PX))
	var t := 0.0
	var peak := 0.0
	while t < max_s:
		for f in 30: await physics_frame
		t += 0.5
		peak = maxf(peak, mate.elevation_m)
		if mate.state != mate.State.MOVE:
			break
	var c = mate.get_last_slide_collision()
	print("   last hit: %s / %s, velocity %s, via %s" % [c.get_collider().name if c else "-", c.get_collider().get_parent().name if c else "-", mate.velocity, _m_pt(mate._tower_way(mate.destination))])
	print("%-26s -> (%5.2f, %5.2f): at (%5.2f, %5.2f) after %4.1f s, state %s, on tower %s, height %.2f (peak %.2f)" % [label, spot_m.x, spot_m.y,
			_m(mate).x, _m(mate).y, t, mate.State.keys()[mate.state], mate.tower != null, mate.elevation_m, peak])

func _m_pt(p: Vector2) -> Vector2:
	return tower.to_local(p) / PX

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(36, 8) * PX
	main.add_child(tower)
	for f in 3: await physics_frame
	var mate: Node2D = main.get_node("Squadmate")
	mate.global_position = tower.to_global(Vector2(-4, 3) * PX)
	for f in 3: await physics_frame
	await _go(mate, Vector2(1.05, 1.05), "up to the deck's SE corner")
	await _go(mate, Vector2(-0.4, -0.3), "into the cabin")
	await _go(mate, Vector2(1.05, 1.05), "out to the SE corner")
	await _go(mate, Vector2(2.0, -1.1), "onto the top landing")
	await _go(mate, Vector2(-4.0, 3.0), "down to the ground")
	var player: Node2D = main.get_node("Player")
	player.global_position = tower.to_global(Vector2(1.05, 0.2) * PX)
	player._set_tower(tower)
	var mates := get_nodes_in_group("squad").slice(0, 4)
	for i in mates.size():
		var m = mates[i]
		m.global_position = tower.to_global(Vector2(-3 - randf() * 2, 2 + randf() * 2) * PX)
		m.order_follow("follow")
		m.follow_slot = i
		m.follow_count = mates.size()
	for s in 40:
		for f in 60: await physics_frame
	print("player up on the deck, %d told to Follow me, after 40 s:" % mates.size())
	for m in mates:
		print("   %s at (%5.2f, %5.2f) on tower %s state %s slot (%5.2f, %5.2f) slot on tower %s via (%5.2f, %5.2f)" % [m.name, _m(m).x, _m(m).y, m.tower != null, m.State.keys()[m.state], _m_pt(m._slot_position()).x, _m_pt(m._slot_position()).y, tower.on_surface(m._slot_position()), _m_pt(m._tower_way(m._slot_position())).x, _m_pt(m._tower_way(m._slot_position())).y])
	quit()
