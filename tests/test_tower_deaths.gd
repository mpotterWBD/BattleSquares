extends SceneTree
## Deaths up a watch tower (death_fall.gd, 2026-11-03): a squadmate stood on a
## part of a tower (its own, clear of the level's), killed by a shot pushing
## it a set way, 4 times each. Checks where the body ends up: over the railing
## to the ground, over the deck's railing onto the stair, or staying up there
## (stopped by a railing it can't go over, the cabin's wall, or falling
## inward), its height, draw order, and its rifle's. Prints a line per run and
## OK / FAIL per case.

const PX := 1024.0 / 12.0
const RUNS := 4

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(34, 18) * PX
	main.add_child(tower)
	for f in 3: await physics_frame

	# [name, where (tower metres), push (tower frame), expect: "ground" / "stair" / "stay"]
	var cases := [
		["south walkway, pushed south", Vector2(0.0, 1.1), Vector2(0, 1), "ground"],
		["south walkway, pushed north (cabin wall)", Vector2(0.0, 1.1), Vector2(0, -1), "stay"],
		["south walkway, pushed west (along it)", Vector2(0.3, 1.05), Vector2(-1, 0), "stay"],
		["west of deck, pushed west", Vector2(-1.15, 1.0), Vector2(-1, 0), "ground"],
		["upper flight, pushed east", Vector2(2.0, 0.3), Vector2(1, 0), "ground"],
		["upper flight, pushed west (deck past it)", Vector2(2.0, 0.3), Vector2(-1, 0), "stay"],
		["upper flight, pushed down it", Vector2(2.0, 0.0), Vector2(0, 1), "stay"],
		["east walkway, pushed east (onto the stair)", Vector2(1.15, 0.6), Vector2(1, 0), "stair"],
		["top landing, pushed north", Vector2(2.0, -1.55), Vector2(0, -1), "ground"],
		["lower flight, pushed west", Vector2(2.0, 3.0), Vector2(-1, 0), "ground"],
		["mid landing, pushed east", Vector2(2.0, 1.5), Vector2(1, 0), "ground"],
		["in the shelter, pushed west", Vector2(-0.9, 0.0), Vector2(-1, 0), "stay"],
		["on the ground, open field", Vector2(-5.0, 0.0), Vector2(-1, 0), "ground_start"],
	]
	for c in cases:
		var got := []
		for run in RUNS:
			got.append(await _die_at(main, tower, c[1], c[2]))
		var expect: String = c[3]
		var ok := true
		for g in got:
			print("    %-44s end %-6s h %.2f  at (%.2f, %.2f)  z %d  went over %s  max h %.2f  rifle h %.2f z %d  pickup on tower %s  rest %s" % [
					c[0], g.end, g.h, g.at.x, g.at.y, g.z, g.over, g.max_h, g.gun_h, g.gun_z, g.pickup_tower, g.rest])
			match expect:
				"ground", "ground_start":
					ok = ok and g.end == "ground" and is_zero_approx(g.h) and g.z == -3 and (expect == "ground_start" or g.over)
				"stair":
					ok = ok and g.end == "tower" and g.h > 1.4 and g.h < 3.0 and g.at.x > 1.7 and g.at.x < 2.3 and g.z == 6 and g.over
				"stay":
					ok = ok and g.end == "tower" and g.h > 0.5 and not g.over and g.z == 6
			ok = ok and g.rest
		check("%s: %s" % [c[0], expect], ok)
	print("DONE, %d failed" % fails)
	quit()


## Kills a fresh squadmate standing at tower metres `m` (up on the tower if
## that's on it) with a shot pushing it along `push`; waits for it to come to
## rest. Returns where it ended up.
func _die_at(main: Node, tower: Node2D, m: Vector2, push: Vector2) -> Dictionary:
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	main.add_child(mate)
	for f in 2: await physics_frame
	mate.set_physics_process(false)
	mate.set_process(false)
	var at: Vector2 = tower.to_global(m * PX)
	mate.global_position = at
	if tower.on_surface(at):
		mate._set_tower(tower)
		mate.elevation_m = tower.height_at(at)
	var dir := push.rotated(tower.global_rotation)
	mate.facing = dir.angle()
	mate.take_hit(at, dir, 999.0)
	var fall: Node = mate._fall
	var rest := [false]
	fall.came_to_rest.connect(func(): rest[0] = true)
	var over := false
	var max_h := 0.0
	for f in 60 * 6:
		await physics_frame
		over = over or fall._phase == "over"
		max_h = maxf(max_h, fall._h)
		if rest[0]:
			break
	var pickup_tower := false
	for p in get_nodes_in_group("ammo_pickups"):
		if p._rifle == mate.get_node("Rifle"):
			pickup_tower = p.tower != null
	return {
		"end": "tower" if fall._tower else "ground", "h": fall._h,
		"at": tower.to_local(fall._lying_centre()) / PX, "z": mate.z_index, "over": over, "max_h": max_h,
		"gun_h": fall._gun_h, "gun_z": mate.get_node("Rifle").z_index, "pickup_tower": pickup_tower, "rest": rest[0],
	}
