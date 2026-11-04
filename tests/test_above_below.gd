extends SceneTree
## Shots Into Above %: someone on the top is only hit by shots flying high,
## someone on the ground under the deck only by shots flying low (then the
## tower's steel as before).
const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")
func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(25, 12) * PX
	level.add_child(tower)
	var p: HeightProfile = tower.top.duplicate(true)
	for s in p.shots_into:
		s.above = 80
	tower.top = p
	var up: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	up.position = tower.to_global(Vector2(-0.5, 1.05) * PX)
	level.add_child(up)
	var under: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	under.position = tower.to_global(Vector2(1.05, -0.9) * PX)   # under the deck, beside the cabin
	level.add_child(under)
	var shooter: Node2D = load("res://scenes/enemy.tscn").instantiate()
	shooter.position = tower.to_global(Vector2(-8.0, 0.4) * PX)
	level.add_child(shooter)
	for f in 3: await physics_frame
	up._set_tower(tower)
	for f in 3: await physics_frame
	for u in [up, under, shooter]:
		u.set_physics_process(false)
		u.set_process(false)
		u.max_health = 1000000.0
		u.health = 1000000.0
	print("up on: %s; under: %s (part above it: %s)" % [tower.part_of(up), tower.part_of(under), tower.part_above(under.global_position)])
	for who in [up, under]:
		var before: float = who.health
		var shots := 300
		shooter.global_position = tower.to_global(Vector2(-8.0, 1.05 if who == up else -0.9) * PX)
		for i in shots:
			var b: Node2D = Bullet.new()
			var from: Vector2 = shooter.global_position
			b.setup(from, (who.global_position - from).angle(), 60.0, shooter, 1.0)
			b.ground_at_m = 40.0
			level.add_child(b)
			var last: Vector2 = b.global_position
			for f in 12:
				await physics_frame
				if not is_instance_valid(b):
					break
				last = b.global_position
			if is_instance_valid(b):
				b.queue_free()
		var hits := roundi(before - who.health)
		var share: float = tower.above_share(tower.part_of(who) if who == up else tower.part_above(who.global_position), shooter.global_position)
		print("%-6s shot 300 times from %.1f m: hit %d%% (above %d%%; steel lets %d%% through)" % [
			"up" if who == up else "under", tower.part_middle("top").distance_to(shooter.global_position) / PX, roundi(100.0 * hits / shots),
			roundi(share * 100), roundi(100.0 * tower.part_pass_from(tower.part_of(who), shooter))])
	quit()
