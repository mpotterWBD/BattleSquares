extends SceneTree
## The watch tower's shelter stops every shot at whoever's in it, from
## anywhere (Mike, 2026-11-03: 0% through regardless of where it's shot
## from; only shots going under it, below the deck, pass). Real bullets, 200
## from each place, at a square in the shelter: from the ground close, middling
## and far, from the deck beside the cabin, from the top landing, from the
## upper and lower flights. Every one should be 0 hits. Also a square on the
## ground under the deck is still hit by low shots (Above). Uses the profiles
## as saved (assets/height_profiles/). Prints hits per place and OK / FAIL.
const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(25, 12) * PX
	level.add_child(tower)
	var target: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	level.add_child(target)
	var shooter: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	level.add_child(shooter)
	for f in 3: await physics_frame
	for u in [target, shooter]:
		u.set_physics_process(false)
		u.set_process(false)
		u.max_health = 1000000.0
		u.health = 1000000.0
	var inside := Vector2(-0.3, -0.3)
	# [where from (tower metres), up on the tower]
	for from in [[Vector2(-3.0, -0.3), false], [Vector2(-7.0, -0.3), false], [Vector2(-15.0, 2.0), false],
			[Vector2(1.05, 0.2), true], [Vector2(-0.3, 1.05), true], [Vector2(1.9, -1.3), true],
			[Vector2(2.0, 0.3), true], [Vector2(2.0, 3.0), true]]:
		var hits := await _hits(level, tower, shooter, from[0], from[1], target, inside, true)
		check("into the shelter from (%.1f, %.1f)%s: %d of 200 hit" % [from[0].x, from[0].y, " up on the tower" if from[1] else "", hits], hits == 0)
	# Leaky settings: the shelter's Pass Through and Shots Into at 100%, the
	# top's Shots Away class 3 at 100%. Still nothing gets in.
	var shelter: HeightProfile = tower.shelter.duplicate(true)
	shelter.pass_through = 100
	for s in shelter.shots_into:
		s.pass_through = 100
	tower.shelter = shelter
	var top: HeightProfile = tower.top.duplicate(true)
	for s in top.shots_away:
		s.class_3_pass_through = 100
	tower.top = top
	for from in [[Vector2(-3.0, -0.3), false], [Vector2(1.05, 0.2), true], [Vector2(-0.3, 1.05), true]]:
		var hits := await _hits(level, tower, shooter, from[0], from[1], target, inside, true)
		check("leaky profiles, into the shelter from (%.1f, %.1f)%s: %d of 200 hit" % [from[0].x, from[0].y, " up on the tower" if from[1] else "", hits], hits == 0)
	var under := await _hits(level, tower, shooter, Vector2(-7.0, -0.3), false, target, inside, false)
	check("someone on the ground under the shelter, from the ground 7 m off: %d of 200 hit (low shots still get them)" % under, under > 0)

	# Through the cabin (Mike: shooting through the shelter from the top). From
	# up on the tower its walls stop the shot; from the ground it goes under.
	var through := await _hits(level, tower, shooter, Vector2(0.0, 1.05), true, target, Vector2(0.0, -6.0), false)
	check("from the south walkway, through the cabin at someone on the ground north: %d of 200 hit" % through, through == 0)
	through = await _hits(level, tower, shooter, Vector2(1.05, -0.9), true, target, Vector2(-6.0, -0.4), false)
	check("from the east walkway, through the cabin at someone on the ground west: %d of 200 hit" % through, through == 0)
	var open := await _hits(level, tower, shooter, Vector2(0.0, 1.05), true, target, Vector2(0.0, 6.0), false)
	check("from the south walkway at someone on the ground south (open): %d of 200 hit" % open, open > 150)
	var below := await _hits(level, tower, shooter, Vector2(-7.0, -0.3), false, target, Vector2(6.0, -0.3), false)
	check("ground to ground under the cabin: %d of 200 hit" % below, below > 150)
	# The AI up there doesn't see through it either.
	shooter.global_position = tower.to_global(Vector2(0.0, 1.05) * PX)
	shooter._set_tower(tower)
	var north: Vector2 = tower.to_global(Vector2(0.0, -6.0) * PX)
	var south: Vector2 = tower.to_global(Vector2(0.0, 6.0) * PX)
	for f in 2: await physics_frame
	check("the AI on the south walkway can't see through the cabin, can see south",
			not shooter._clear_view(shooter.global_position, north) and shooter._clear_view(shooter.global_position, south))
	shooter.global_position = tower.to_global(Vector2(-7.0, -0.3) * PX)
	shooter._set_tower(null)
	for f in 2: await physics_frame
	check("from the ground it sees under it", shooter._clear_view(shooter.global_position, tower.to_global(Vector2(6.0, -0.3) * PX)))
	# Tracers: drawn over the deck fired from up there, at ground level from the ground.
	var zs := []
	for spot in [[Vector2(0.0, 1.05), true], [Vector2(2.0, 0.3), true], [Vector2(2.0, 3.0), true], [Vector2(-7.0, -0.3), false]]:
		shooter.global_position = tower.to_global(spot[0] * PX)
		shooter._set_tower(tower if spot[1] else null)
		var b: Node2D = Bullet.new()
		b.setup(shooter.global_position, 0.0, 60.0, shooter, 1.0)
		zs.append(b.z_index)
		b.free()
	check("tracer z from the top, upper flight, lower flight, ground: %s (expect [6, 6, 0, 0])" % [zs], zs == [6, 6, 0, 0])
	print("DONE, %d failed" % fails)
	quit()


## How many of 200 shots by `shooter` at tower metres `from_m` (up on the
## tower if `up`) hit `target` at `to_m` (up on it if `target_up`).
func _hits(level: Node, tower: Node2D, shooter: Node2D, from_m: Vector2, up: bool,
		target: Node2D, to_m: Vector2, target_up: bool) -> int:
	shooter.global_position = tower.to_global(from_m * PX)
	shooter._set_tower(tower if up else null)
	target.global_position = tower.to_global(to_m * PX)
	target._set_tower(tower if target_up else null)
	for f in 2: await physics_frame
	var before: float = target.health
	for i in 200:
		var b: Node2D = Bullet.new()
		var at: Vector2 = shooter.global_position
		b.setup(at, (target.global_position - at).angle(), 60.0, shooter, 1.0)
		b.ground_at_m = 40.0
		level.add_child(b)
		for f in 12:
			await physics_frame
			if not is_instance_valid(b):
				break
		if is_instance_valid(b):
			b.queue_free()
	return roundi(before - target.health)
