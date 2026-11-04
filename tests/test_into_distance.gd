extends SceneTree
## Shots Into by the shooter's distance (Mike, 2026-11-02): someone on the
## top shot at from close, middling and far (nothing in between) gets hit by
## the section's Pass Through; low cover hides them only where Seen is off;
## Shots Away unchanged. The debug panel lists both.

const PX := 1024.0 / 12.0
const Cover = preload("res://scripts/cover.gd")
const Bullet = preload("res://scripts/bullet.gd")
const DebugOverlay = preload("res://scripts/debug_overlay.gd")

var tower: Node2D


func t(x: float, y: float) -> Vector2:
	return tower.to_global(Vector2(x, y) * PX)


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(25, 12) * PX
	level.add_child(tower)
	var up: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	up.position = t(-0.5, 1.05)   # the south walkway (top)
	level.add_child(up)
	var ground: Node2D = load("res://scenes/enemy.tscn").instantiate()
	level.add_child(ground)
	for f in 3: await physics_frame
	up._set_tower(tower)
	for f in 3: await physics_frame
	for u in [up, ground]:
		u.process_mode = Node.PROCESS_MODE_DISABLED
	var middle: Vector2 = tower.part_middle("top")
	for d in [3.0, 8.0, 15.0]:
		ground.global_position = middle + Vector2(-d, 0.0) * PX + Vector2(0, 1.05) * PX
		var dist := ground.global_position.distance_to(middle) / PX
		# (count by rolls through the tower's own check, as the bullet does)
		var through := 0
		for i in 4000:
			if Cover.tower_blocks(up, ground) == null:
				through += 1
		print("shooter %4.1f m from the deck's middle: section %d, through the tower %d%% (setting %d%%)" % [dist,
			HeightProfile.section_number(tower.top.shots_into, dist), roundi(100.0 * through / 4000),
			tower.top.into_section(dist).pass_through])

	# Seen: sandbags between, looked at from 8 m (Seen) and 15 m (not).
	var bags: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	bags.rotation = PI / 2.0
	level.add_child(bags)
	for d in [8.0, 15.0]:
		ground.global_position = middle + Vector2(-d, 1.05) * PX
		bags.global_position = ground.global_position + Vector2(2.0, 0) * PX
		for f in 3: await physics_frame
		print("looking from %4.1f m over sandbags 2 m in front: sees them %s (no profile rule: %s)" % [d,
			ground._clear_view(ground.global_position, up.global_position, false, false, up),
			ground._clear_view(ground.global_position, up.global_position, false, false, null)])
	# Shots Away unchanged: from the top past those sandbags 4.5 m out.
	bags.global_position = middle + Vector2(-4.5, 1.05) * PX
	for f in 3: await physics_frame
	print("firing from the top past sandbags 4.5 m out: %d%% through (section 1 class 1: 78%%)" % roundi(100.0 * (1.0 - Cover.stop_chance(bags) * (1.0 - Cover.height_extra(bags, bags.global_position, up)))))

	var overlay: Node = DebugOverlay.new()
	level.add_child(overlay)
	await process_frame
	overlay._picked = tower
	overlay._picked_part = "top"
	overlay._picked_at = up.global_position
	overlay._update_tower_panel(tower)
	print(overlay._body_label.text.split("OBJECT SPECIFIC INFO:")[1])
	quit()
