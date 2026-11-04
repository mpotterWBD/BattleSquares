extends SceneTree
## The player's Unlimited Ammo: endless spares from the start, reloads keep
## coming; off mid-game, back to its own magazines; on again.
func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	var player: Node2D = main.get_node("Player")
	player.unlimited_ammo = true
	root.add_child(main)
	current_scene = main
	for f in 5: await physics_frame
	var rifle: Node2D = player.get_node("Rifle")
	print("start (on): spare_mags %d, spare count %d, rounds %d" % [rifle.spare_mags, rifle.spare_count(), rifle.rounds])
	for r in 3:   # empty the magazine and reload, three times
		while rifle.rounds > 0:
			rifle._cooldown = 0.0
			rifle.fire()
		print("  emptied; reload starts %s" % rifle.start_reload())
		while rifle.reloading:
			await physics_frame
		print("  reloaded: rounds %d" % rifle.rounds)
	player.unlimited_ammo = false
	print("off: spare_mags %d, spare count %d (rounds in them %d)" % [rifle.spare_mags, rifle.spare_count(), rifle.spare_rounds()])
	player.unlimited_ammo = true
	print("on again: spare_mags %d" % rifle.spare_mags)
	quit()
