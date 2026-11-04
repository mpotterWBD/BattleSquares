extends SceneTree
## Two sides each dug in behind sandbags, facing each other across 15 m,
## nobody firing first: do they see each other and fight?

const PX := 1024.0 / 12.0


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var gap := float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 15.0
	var ours: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	ours.position = Vector2(1200, 1500)
	level.add_child(ours)
	var theirs: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	theirs.position = Vector2(1200, 1500 - gap * PX)
	level.add_child(theirs)
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	mate.position = Vector2(1200, 1500 + 0.42 * PX)
	level.add_child(mate)
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	enemy.position = theirs.position - Vector2(0, 0.42 * PX)
	enemy.start_facing_deg = 90.0
	level.add_child(enemy)
	await process_frame
	await ticks(2)
	mate.order_move(mate.global_position, true)
	await ticks(120)
	print("gap %.0f m. squadmate defending=%s; enemy in cover=%s calm=%s" % [gap, mate.is_defending(), enemy.cover_wall != null, enemy.is_calm()])
	var shots := 0
	var first := -1.0
	for t in 60 * 8:
		await physics_frame
		var n := get_nodes_in_group("bullets").size()
		if n > 0 and first < 0:
			first = t / 60.0
		shots = maxi(shots, n)
	print("after 8 s: enemy alerted=%s mode=%s attacking=%s; squadmate attacking=%s; first bullet at %s s; mate hp %.0f enemy hp %.0f, mate dead=%s enemy dead=%s"
			% [enemy.alerted, enemy.mode, enemy.is_attacking(), mate.is_attacking(), first, mate.health, enemy.health, mate.dead, enemy.dead])
	quit()
