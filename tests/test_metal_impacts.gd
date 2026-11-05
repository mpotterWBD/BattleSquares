extends SceneTree
## Bullets into metal (2026-11-03: Mike's BulletImpactMetal.mp3, cut into
## assets/sfx/bullet_metal/): real bullets into the supply truck, an ammo
## crate and a lone ammo can each play one of the new clips ("metal"), the
## truck with sparks; a body hitting steel ("clang", death_fall.gd) still
## plays the old ones. Prints OK / FAIL.
const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")
const HitSparks = preload("res://scripts/hit_sparks.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## The sound players and sparks added to `level` since `before`.
func added(level: Node, before: Array) -> Array:
	return level.get_children().filter(func(c): return not before.has(c))


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var shooter: Node2D = load("res://scenes/enemy.tscn").instantiate()
	level.add_child(shooter)
	shooter.global_position = Vector2(10, 12) * PX
	var targets := {
		"supply truck": "res://scenes/supply_truck.tscn",
		"ammo crate": "res://scenes/crate_ammo.tscn",
		"ammo can": "res://scenes/ammo_can.tscn",
	}
	var k := 0
	for name: String in targets:
		var thing: Node2D = load(targets[name]).instantiate()
		level.add_child(thing)
		thing.global_position = Vector2(16, 6 + k * 6) * PX
		k += 1
		for f in 3: await physics_frame
		shooter.set_physics_process(false)
		var before := level.get_children()
		var b: Node2D = Bullet.new()
		b.setup(shooter.global_position, (thing.global_position - shooter.global_position).angle(), 60.0, shooter, 1.0)
		level.add_child(b)
		for f in 20:
			await physics_frame
			if not is_instance_valid(b):
				break
		var new := added(level, before)
		var heard := new.filter(func(c): return c is AudioStreamPlayer2D and c.stream and c.stream.resource_path.contains("bullet_metal"))
		var sparked := new.any(func(c): return c.get_script() == HitSparks)
		check("a bullet into the %s: one of the new metal clips (%s)%s" % [name,
				heard[0].stream.resource_path.get_file() if heard else "none", ", sparks" if sparked else ""],
				not heard.is_empty() and (sparked or name != "supply truck"))
		thing.queue_free()
	var before := level.get_children()
	ImpactSound.play(level, Vector2.ZERO, "clang")
	var clang := added(level, before).filter(func(c): return c is AudioStreamPlayer2D)
	check("a body hitting steel (clang): the old clips (%s)" % [clang[0].stream.resource_path.get_file() if clang else "none"],
			not clang.is_empty() and clang[0].stream.resource_path.contains("metal_impact"))
	print("DONE, %d failed" % fails)
	quit()
