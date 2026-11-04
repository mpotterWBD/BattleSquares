extends SceneTree
## The surprised state: an idle square shot at runs for cover, then fights
## from it. Scenario from the command line (-- <name>):
##   away     enemy; a crate 2 m behind it (away from the shooter) and one
##            1.5 m in front: it should take the one behind and peek out
##   toward2  enemy; only a crate 1.8 m toward the shooter: takes it
##   toward4  enemy; only a crate 4 m toward the shooter: no cover, ENGAGE
##   wall     enemy; a sandbag wall 2 m behind it: fires over it, no peeking
##   squad    squadmate shot at by an enemy; a crate 2 m behind it

const PX := 1024.0 / 12.0


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func add(level: Node, path: String, at: Vector2) -> Node2D:
	var node: Node2D = load(path).instantiate()
	node.position = at
	level.add_child(node)
	return node


func _init() -> void:
	var scenario: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "away"
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var at := Vector2(1500, 900)
	var foe_at := at + Vector2(0, 12 * PX)   # the shooter, 12 m south
	var victim: Node2D
	var shooter: Node2D
	var covers := {}
	if scenario == "squad":
		victim = load("res://scenes/squadmate.tscn").instantiate()
		victim.max_health = 1000.0
		victim.position = at
		level.add_child(victim)
		shooter = load("res://scenes/enemy.tscn").instantiate()
		shooter.max_health = 1000.0
		shooter.position = foe_at
		shooter.start_facing_deg = -90.0
		level.add_child(shooter)
		covers.behind = add(level, "res://scenes/crate_ammo.tscn", at - Vector2(0, 2 * PX))
	else:
		victim = load("res://scenes/enemy.tscn").instantiate()
		victim.max_health = 1000.0
		victim.position = at
		victim.start_facing_deg = -90.0   # facing away, north
		victim.sight_m = 5.0              # doesn't spot the shooter by sight first
		level.add_child(victim)
		shooter = load("res://scenes/squadmate.tscn").instantiate()
		shooter.max_health = 1000.0
		shooter.position = foe_at
		level.add_child(shooter)
		match scenario:
			"away":
				covers.behind = add(level, "res://scenes/crate_ammo.tscn", at - Vector2(0, 2 * PX))
				covers.front = add(level, "res://scenes/crate_ammo.tscn", at + Vector2(0, 1.5 * PX))
			"toward2":
				covers.front = add(level, "res://scenes/crate_ammo.tscn", at + Vector2(0, 1.8 * PX))
			"toward4":
				covers.front = add(level, "res://scenes/crate_ammo.tscn", at + Vector2(0, 4 * PX))
			"wall":
				covers.behind = add(level, "res://scenes/sandbags.tscn", at - Vector2(0, 2 * PX))
	await process_frame
	await ticks(2)
	shooter._rifle.start_rounds = -1
	shooter._rifle.rounds = 30
	shooter._rifle.spare_mags = -1
	victim._rifle.rounds = 30
	victim._rifle.spare_mags = -1
	if scenario == "squad":
		shooter.alert(victim)
	else:
		shooter.order_attack(victim)
	var start: Vector2 = victim.global_position
	var t := 0
	var surprised_at := -1
	var in_cover_at := -1
	var peeks := 0
	var last_phase := -1
	var victim_shots := {}
	var shots_from := {}
	var hits_hiding := 0
	var hp: float = victim.health
	var max_mode := ""
	while t < 60 * 12 and not victim.dead:
		await physics_frame
		t += 1
		if surprised_at < 0 and victim._is_surprised():
			surprised_at = t
		if victim._is_surprised():
			if in_cover_at < 0 and victim._hide_phase != 0:
				in_cover_at = t
			if victim._hide_phase == 2 and last_phase != 2:
				peeks += 1
			last_phase = victim._hide_phase
		for b: Node2D in get_nodes_in_group("bullets"):
			if b.shooter == victim and not victim_shots.has(b.get_instance_id()):
				victim_shots[b.get_instance_id()] = true
				var where := "peek" if victim._is_surprised() and victim._hide_phase == 2 else (
						"hide" if victim._is_surprised() else "other")
				shots_from[where] = shots_from.get(where, 0) + 1
		if victim.health < hp:
			if victim._is_surprised() and victim._hide_phase == 1:
				hits_hiding += 1
			hp = victim.health
	var cover_name := "none"
	for k in covers:
		if victim._hide_cover == covers[k]:
			cover_name = k
	var mode_text := ""
	if scenario == "squad":
		mode_text = "state=%d (SURPRISED=7)" % victim.state
	else:
		mode_text = "mode=%d (ENGAGE=1, SURPRISED=4)" % victim.mode
	print("%s: surprised at %.2f s, in cover at %.2f s, cover=%s low=%s, moved %.2f m, %s" % [scenario,
			surprised_at / 60.0, in_cover_at / 60.0, cover_name, victim._hide_low,
			victim.global_position.distance_to(start) / PX, mode_text])
	if victim._hide_cover:
		var foe: Vector2 = shooter.global_position
		print("   cover between spot and shooter: %s; spot %.2f m from cover centre" % [
				victim._hide_covers(victim._hide_spot, victim._hide_cover, foe),
				victim._hide_spot.distance_to(victim._hide_cover.global_position) / PX])
	print("   peeks %d, victim shots by phase %s, hits while tucked in %d, health %.0f/1000, shooter health %.0f/1000" % [
			peeks, shots_from, hits_hiding, victim.health, shooter.health])
	quit()
