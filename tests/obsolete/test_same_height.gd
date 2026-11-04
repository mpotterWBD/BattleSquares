extends SceneTree
## Sections now count cover as high as where you stand too: from the lower
## stairs (height 2), a crate (height 2) 5 m off goes by its Class 2 value.
const PX := 1024.0 / 12.0
const Cover = preload("res://scripts/cover.gd")
const DebugOverlay = preload("res://scripts/debug_overlay.gd")
func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(20, 12) * PX
	var p := HeightProfile.new()
	p.height_class = 2
	p.pass_through = 80
	var s := ShotSection.new()
	s.radius_m = 8.5
	s.class_2_pass_through = 100
	var into := ShotIntoSection.new()
	into.radius_m = 8.5
	into.class_2_pass_through = 60
	into.class_2_seen = true
	p.shots_away = [s] as Array[ShotSection]
	p.shots_into = [into] as Array[ShotIntoSection]
	tower.lower_stairs = p
	level.add_child(tower)
	var up: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	up.position = tower.to_global(Vector2(2.0, 3.0) * PX)
	level.add_child(up)
	up._set_tower(tower)
	var ground: Node2D = load("res://scenes/enemy.tscn").instantiate()
	ground.position = tower.to_global(Vector2(-14.0, 3.0) * PX)
	level.add_child(ground)
	for f in 3: await physics_frame
	for c in [["crate 5 m west (class 2)", "res://scenes/crate_sandbags.tscn"], ["sandbags 5 m west (class 1)", "res://scenes/sandbags.tscn"]]:
		var cover: Node2D = load(c[1]).instantiate()
		cover.position = tower.to_global(Vector2(-3.0, 3.0) * PX)
		level.add_child(cover)
		await physics_frame
		var normal := 1.0 - Cover.stop_chance(cover)
		print("%-28s normal %3d%%: fired from the lower stairs %3d%%; shot at the lower stairs %3d%%, seen %s" % [c[0], roundi(normal * 100),
			roundi(Cover.height_pass(cover, cover.global_position, up, ground, normal) * 100),
			roundi(Cover.height_pass(cover, cover.global_position, ground, up, normal) * 100), Cover.seen_past(cover, cover.global_position, up)])
		cover.free()
	var overlay: Node = DebugOverlay.new()
	level.add_child(overlay)
	await process_frame
	overlay._picked = tower
	overlay._picked_part = "lower_stairs"
	overlay._picked_at = up.global_position
	overlay._update_tower_panel(tower)
	print(overlay._body_label.text.split("OBJECT SPECIFIC INFO:")[1])
	quit()
