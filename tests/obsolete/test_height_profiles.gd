extends SceneTree
## Height profiles (Mike, 2026-11-02): the watch tower's parts' Shots Away and
## Shots Into, by the numbers, by real bullets, by what an enemy sees, and in
## the debug panel.

const PX := 1024.0 / 12.0
const Cover = preload("res://scripts/cover.gd")
const Bullet = preload("res://scripts/bullet.gd")
const DebugOverlay = preload("res://scripts/debug_overlay.gd")

var level: Node2D
var tower: Node2D


func t(x: float, y: float) -> Vector2:
	return tower.to_global(Vector2(x, y) * PX)


func _init() -> void:
	level = Node2D.new()
	root.add_child(level)
	current_scene = level
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(30, 12) * PX
	level.add_child(tower)
	var up: Node2D = load("res://scenes/squadmate.tscn").instantiate()   # up on the south walkway
	up.position = t(-1.0, 1.05)
	level.add_child(up)
	var ground: Node2D = load("res://scenes/enemy.tscn").instantiate()   # 20 m south, on the ground
	ground.position = t(-21.0, 1.05)
	level.add_child(ground)
	for f in 3: await physics_frame
	up._set_tower(tower)
	for f in 3: await physics_frame
	for u in [up, ground]:   # (they stay put: shot at, they'd run for cover)
		u.process_mode = Node.PROCESS_MODE_DISABLED
	for part in ["lower_stairs", "upper_stairs", "top", "shelter"]:
		var p: HeightProfile = tower.profile_for(part)
		print("%-13s %s: height %d, pass through %d%%, %d shots away, %d shots into" % [part, p.resource_path.get_file(), p.height_class, p.pass_through, p.shots_away.size(), p.shots_into.size()])
	print("up on: %s (profile %s); on the ground: profile %s" % [tower.part_of(up), Cover.profile_of(up).resource_path.get_file(), Cover.profile_of(ground)])

	for c in [["sandbags 4.5 m from the tower (section 1)", "res://scenes/sandbags.tscn", 4.5], ["sandbags 12 m out (section 3)", "res://scenes/sandbags.tscn", 12.0],
			["crate 12 m out (section 3)", "res://scenes/crate_sandbags.tscn", 12.0], ["crate 7 m out (section 2)", "res://scenes/crate_sandbags.tscn", 7.0]]:
		var cover: Node2D = load(c[1]).instantiate()
		cover.position = t(-c[2], 1.05)
		cover.rotation = PI / 2.0   # across the line of fire
		if cover.get("strapped") != null:
			cover.strapped = false
		level.add_child(cover)
		for f in 3: await physics_frame
		var at: Vector2 = cover.global_position
		var normal := 1.0 - Cover.stop_chance(cover)
		var into := Cover.height_pass(cover, at, ground, up, normal)
		var away := Cover.height_pass(cover, at, up, ground, normal)
		var seen: bool = ground._clear_view(ground.global_position, up.global_position, false, true, up)
		var seen_before: bool = ground._clear_view(ground.global_position, up.global_position, false, true, null)
		# Real bullets at the one up there, fired by the one on the ground from
		# 1 m in front of the cover (so only this cover's in the way).
		var through := 0
		var shots := 400
		var dir: Vector2 = (up.global_position - ground.global_position).normalized()
		for i in shots:
			var b: Node2D = Bullet.new()
			b.setup(at - dir * 1.0 * PX, dir.angle(), 30.0, ground, 0.0)
			b.ground_at_m = 40.0
			level.add_child(b)
			for f in 12:
				await physics_frame
				if not is_instance_valid(b):
					break
				if (b.global_position - at).dot(dir) > 0.6 * PX:
					through += 1
					b.queue_free()
					break
		print("%-42s class %d, normal %d%%: shot into %d%%, fired away from up there %d%%; bullets past it %d%%; seen %s (no profile: %s)" % [
			c[0], Cover.height_class_of(cover), roundi(normal * 100), roundi(into * 100), roundi(away * 100), roundi(100.0 * through / shots), seen, seen_before])
		cover.queue_free()
		for f in 3: await physics_frame

	# The debug panel for the top.
	var overlay: Node = DebugOverlay.new()
	level.add_child(overlay)
	await process_frame
	overlay._picked = tower
	overlay._picked_part = "top"
	overlay._picked_at = t(-1.0, 1.0)
	overlay._update_tower_panel(tower)
	print("debug panel:\n%s\n%s" % [overlay._name_label.text, overlay._body_label.text])
	quit()
