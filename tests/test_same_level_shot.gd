extends SceneTree
## Shooting someone up on the watch tower from up there too (2026-11-03: Mike's
## shots at someone on the top beside him went through them). Real bullets,
## 300 each:
##   - from the top's south walkway at someone 1.4 m along it: all should hit
##     (same part: no steel between, and no high / low roll);
##   - from the top at someone on the upper flight: hit as often as the steel
##     lets through from that far (Shots Into), not halved again by Above;
##   - from the ground 8 m off at someone on the top: as before, Above x the
##     steel (high shots only).
## Prints each hit share and OK / FAIL.
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

	var top_from := await _hits(level, tower, shooter, Vector2(-0.8, 1.05), true, target, Vector2(0.6, 1.05), true)
	check("top to top (same walkway, 1.4 m): %d%% hit, expect 100%%" % roundi(top_from * 100), top_from > 0.99)

	var to_stair := await _hits(level, tower, shooter, Vector2(0.9, 1.05), true, target, Vector2(2.0, 0.3), true)
	# (the stairs' steel from there, or more if the top's Shots Away lets class 2 past)
	var through: float = tower.cover_pass(target, shooter)
	check("top to upper flight: %d%% hit, expect about the steel's %d%%" % [roundi(to_stair * 100), roundi(through * 100)],
			absf(to_stair - through) < 0.08)

	var ground := await _hits(level, tower, shooter, Vector2(-8.0, 1.05), false, target, Vector2(-0.5, 1.05), true)
	var share: float = tower.above_share("top", shooter.global_position)
	var steel: float = tower.part_pass_from("top", shooter)
	check("ground (8 m) to top: %d%% hit, expect about above %d%% x steel %d%% = %d%%" % [roundi(ground * 100), roundi(share * 100),
			roundi(steel * 100), roundi(share * steel * 100)], absf(ground - share * steel) < 0.08)
	print("DONE, %d failed" % fails)
	quit()


## The share of 300 shots by `shooter` at tower metres `from_m` (up on it if
## `shooter_up`) that hit `target` at `to_m` (up on it if `target_up`).
func _hits(level: Node, tower: Node2D, shooter: Node2D, from_m: Vector2, shooter_up: bool,
		target: Node2D, to_m: Vector2, target_up: bool) -> float:
	shooter.global_position = tower.to_global(from_m * PX)
	shooter._set_tower(tower if shooter_up else null)
	target.global_position = tower.to_global(to_m * PX)
	target._set_tower(tower if target_up else null)
	for f in 2: await physics_frame
	var before: float = target.health
	var shots := 300
	for i in shots:
		var b: Node2D = Bullet.new()
		var from: Vector2 = shooter.global_position
		b.setup(from, (target.global_position - from).angle(), 60.0, shooter, 1.0)
		b.ground_at_m = 40.0
		level.add_child(b)
		for f in 12:
			await physics_frame
			if not is_instance_valid(b):
				break
		if is_instance_valid(b):
			b.queue_free()
	return (before - target.health) / shots
