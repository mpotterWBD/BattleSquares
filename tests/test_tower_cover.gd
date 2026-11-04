extends SceneTree
## A watch tower covers whoever's in or under it: shots from elsewhere get
## through 75% under the deck, 80% on the stair, 50% on the deck, 30% in the cabin.

const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")
const Cover = preload("res://scripts/cover.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(8, 6) * PX
	main.add_child(tower)
	var target: Node2D = main.get_node("Squadmate")
	var shooter: Node2D = load("res://scenes/enemy.tscn").instantiate()
	main.add_child(shooter)
	shooter.global_position = tower.to_global(Vector2(-8, 0) * PX)
	shooter.speed_mps = 0.0
	target.speed_mps = 0.0
	for f in 3: await physics_frame
	for spot in [["under", Vector2(-0.5, 1.0), false], ["upper stairs", Vector2(2.0, 1.5), true], ["lower stairs", Vector2(2.0, 3.0), true], ["platform", Vector2(1.05, 0.5), true],
			["cabin", Vector2(-0.4, -0.3), true], ["open ground", Vector2(-4.0, 0.0), false]]:
		target.global_position = tower.to_global(spot[1] * PX)
		target._set_tower(tower if spot[2] else null)
		for f in 2: await physics_frame
		var through := 0
		for i in 2000:
			if Cover.tower_blocks(target, shooter) == null:
				through += 1
		print("%-11s part '%s': %4.1f%% get through; enemy counts it shielded: %s" % [spot[0], tower.part_of(target), through / 20.0, shooter._shielded(target)])
	# Same place: on the deck shooting someone else on the deck.
	var other: Node2D = main.get_node("Squadmate2")
	other.global_position = tower.to_global(Vector2(1.05, -1.0) * PX)
	other._set_tower(tower)
	target.global_position = tower.to_global(Vector2(1.05, 0.9) * PX)
	target._set_tower(tower)
	print("deck to deck: %.0f%% through" % (Cover.tower_pass(target, other) * 100.0))
	# A real bullet into the cabin: some stop in the tower (it takes no hit).
	target.global_position = tower.to_global(Vector2(-0.4, -0.3) * PX)
	var health_before: float = target.health
	target.max_health = 100000.0
	target.health = 100000.0
	var hits := 0
	for i in 200:
		var b := Bullet.new()
		b.setup(shooter.global_position, (target.global_position - shooter.global_position).angle(), 300.0, shooter, 1.0)
		main.add_child(b)
		for f in 4: await physics_frame
	print("200 real shots into the cabin: target took %d hits (expected about 60)" % roundi(100000.0 - target.health))
	quit()
