extends SceneTree
## Six squadmates short of ammo near a can: only one at it at a time.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 5:
		await physics_frame
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = Vector2(5, 5) * PX
	var squad := get_nodes_in_group("squad")
	var can: Node2D = load("res://scenes/ammo_supply.tscn").instantiate()
	can.position = Vector2(22, 12) * PX
	can.rounds = 400
	main.add_child(can)
	for i in squad.size():
		squad[i].order_attention(Vector2(19.0 + i * 0.7, 15.0) * PX, 0.0)
		squad[i].global_position = Vector2(19.0 + i * 0.7, 15.0) * PX
	var most := 0
	var walking_most := 0
	var order := []
	for f in 60 * 60:
		await physics_frame
		var near := 0
		var heading := 0
		for u in squad:
			if u.global_position.distance_to(can.global_position) < 1.0 * PX:
				near += 1
			if u._ammo == can:
				heading += 1
			if u.get_node("Rifle").spare_room() == 0 and not u.name in order:
				order.append(u.name)
				print("%5.1f s  %s done (%s)" % [f / 60.0, u.name, str(u.get_node("Rifle")._spares)])
		most = maxi(most, near)
		walking_most = maxi(walking_most, heading)
		if order.size() == squad.size():
			break
	print("most within 1 m of the can at once: %d; most going for it at once: %d; can left %d" % [most, walking_most, can.rounds])
	quit()
