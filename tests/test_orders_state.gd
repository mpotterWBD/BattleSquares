extends SceneTree
## Squadmates under orders: no surprise, no ammo runs, no shuffling; Disperse frees them.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var cmd: Node = main.get_node("Command")
	var mate: Node2D = main.get_node("Squadmate")
	var far: Node2D = main.get_node("Squadmate6")
	mate.global_position = player.global_position + Vector2(2, 0) * PX
	far.global_position = player.global_position + Vector2(20, 5) * PX
	for f in 10: await physics_frame
	print("near the player: orders %s, far one: orders %s" % [mate.under_orders, far.under_orders])
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	main.add_child(enemy)
	enemy.global_position = mate.global_position + Vector2(10, 0) * PX
	enemy.speed_mps = 0.0
	for f in 3: await physics_frame
	for who in [mate, far]:
		who._surprise(enemy, enemy.global_position)
		print("%s fired at: state %s, shooting back %s" % [who.name, who.State.keys()[who.state], who.attack_target == enemy])
	# Out of ammo: no run under orders.
	mate.attack_target = null
	mate.state = mate.State.IDLE
	var rifle = mate.get_node("Rifle")
	rifle.rounds = 0
	var pickup: Node2D = load("res://scenes/ammo_supply.tscn").instantiate()
	pickup.position = mate.global_position + Vector2(-3, 0) * PX
	main.add_child(pickup)
	var start: Vector2 = mate.global_position
	for f in 180: await physics_frame
	print("out of ammo under orders: out %s, moved %.2f m, going for ammo %s" % [mate.is_out_of_ammo(), mate.global_position.distance_to(start) / PX, mate._ammo != null])
	# Disperse: on its own.
	cmd._give_order("disperse") if false else mate.order_disperse(mate.global_position + Vector2(0, 1) * PX)
	for f in 120: await physics_frame
	mate.selected = true
	for f in 10: await physics_frame
	print("dispersed (and selected): orders %s, own %s" % [mate.under_orders, mate.on_own])
	start = mate.global_position
	for f in 240: await physics_frame
	print("   out of ammo on its own: going for ammo %s, moved %.2f m" % [mate._ammo != null, mate.global_position.distance_to(start) / PX])
	mate.order_follow("follow")
	print("given Follow me: orders %s, own %s" % [mate.under_orders, mate.on_own])
	quit()
