extends SceneTree
## Ammo cans: 2 empty spares to start; a squadmate builds a can from a
## (strapped) ammo crate; the player loads from it by standing there; a
## squadmate out of ammo goes and loads; dead-gun magazine swap.

const PX := 1024.0 / 12.0
const AmmoSupply = preload("res://scripts/ammo_supply.gd")
const AmmoPickup = preload("res://scripts/ammo_pickup.gd")


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func mags(u: Node) -> String:
	var r: Node = u.get_node("Rifle")
	return "rifle %d, spares %s (count %d)" % [r.rounds, str(r._spares), r.spare_count()]


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = m(20.0, 10.0)
	var squad := get_nodes_in_group("squad")
	for i in squad.size():
		squad[i].order_attention(m(19.0 + i * 0.6, 14.0), 0.0)
		squad[i].global_position = m(19.0 + i * 0.6, 14.0)
	await ticks(5)
	print("start: player ", mags(player), "; mate ", mags(squad[0]))
	for u in squad:   # not short, so only the ones the test means go to the can
		u.get_node("Rifle")._spares = [30, 30] as Array[int]

	# Reload with empty spares: refused. Fire to 10, then can't reload.
	var rifle: Node = player.get_node("Rifle")
	print("reload with empty spares: ", rifle.start_reload())

	# Build a can from an ammo crate (strapped) by a squadmate.
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	crate.position = m(24.0, 14.0)
	main.add_child(crate)
	await ticks(2)
	var can: Node2D = load("res://scenes/ammo_supply.tscn").instantiate()
	can.position = m(22.0, 10.0)
	main.add_child(can)
	can.start_site(crate)
	print("crate parts %d, available %d, can built %s" % [crate.parts.size(), crate.available(), can.built])
	squad[0].order_build()
	var t := 0
	while not can.built and t < 1200:
		await physics_frame
		t += 1
	print("can built after %.1f s (crate taken %d, mate %s)" % [t / 60.0, crate.taken, squad[0].State.keys()[squad[0].state]])

	# Player stands at it.
	player.global_position = can.global_position + Vector2(0.3 * PX, 0)
	var start_rounds: int = can.rounds
	t = 0
	while rifle.spare_room() > 0 and t < 1200:
		await physics_frame
		t += 1
	print("player loaded %d rounds in %.2f s: %s; can left %d" % [start_rounds - can.rounds, t / 60.0, mags(player), can.rounds])
	await ticks(5)
	print("still at it with full spares, can left %d" % can.rounds)
	rifle.rounds = 0
	print("reload now: ", rifle.start_reload())
	await ticks(150)
	print("after reload: ", mags(player))
	player.global_position = m(16.0, 10.0)
	await ticks(3)

	# A squadmate out of ammo goes for the can.
	var mate: Node = squad[1]
	mate.get_node("Rifle").rounds = 0
	mate.get_node("Rifle")._spares = [0, 0] as Array[int]
	print("mate 2 out? ", mate.is_out_of_ammo(), " ", mags(mate))
	t = 0
	while mate.get_node("Rifle").spare_room() > 0 and t < 1800:
		await physics_frame
		t += 1
	print("mate 2 loaded after %.1f s, at can %.2f m: %s; can left %d" % [t / 60.0,
			mate.global_position.distance_to(can.global_position) / PX, mags(mate), can.rounds])
	await ticks(200)
	print("   then: ", mags(mate), " state ", mate.State.keys()[mate.state])

	# Dead-gun magazine swap.
	var dead_rifle: Node = squad[2].get_node("Rifle")
	var pickup := AmmoPickup.new()
	dead_rifle.rounds = 20
	pickup.setup(dead_rifle)
	main.add_child(pickup)
	var r3: Node = squad[3].get_node("Rifle")
	r3._spares = [0, 12] as Array[int]
	print("useful to 4 (spares [0,12]) with 20: ", pickup.useful_to(squad[3]))
	pickup.give_to(squad[3])
	print("after swap: 4 spares %s, dead rifle %d, pickup alive %s" % [str(r3._spares), dead_rifle.rounds, is_instance_valid(pickup) and not pickup.is_queued_for_deletion()])
	var r4: Node = squad[4].get_node("Rifle")
	r4._spares = [25, 30] as Array[int]
	dead_rifle.rounds = 20
	print("useful to 5 (spares [25,30]) with 20: ", pickup.useful_to(squad[4]))
	quit()
