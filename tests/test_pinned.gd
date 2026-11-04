extends SceneTree
## Pinned: a squadmate shooting at an enemy behind heavy cover while the
## enemies outnumber the squad stops firing and gets down. Enemies are held
## still (no AI) so the setup stays put. Scenario (-- <name>):
##   wall     dug in behind sandbags, 2 enemies behind crates 15 m off:
##            pinned; then one enemy dies: unpinned, back to DEFEND, firing
##   even     the same with only 1 enemy: never pinned (1 v 1)
##   exposed  2 enemies, its target in the open: never pinned
##   fire     pinned, then a Fire order on its target: shoots anyway
##   open     standing in the open, a crate 3 m behind it: pinned, it goes
##            behind the crate and doesn't shoot

const PX := 1024.0 / 12.0


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func add(level: Node, path: String, at: Vector2) -> Node2D:
	var node: Node2D = load(path).instantiate()
	node.position = at
	level.add_child(node)
	return node


var shots := 0
var mate: Node2D


func count_shots() -> void:
	for b: Node2D in get_nodes_in_group("bullets"):
		if b.shooter == mate and not b.has_meta("counted"):
			b.set_meta("counted", true)
			shots += 1


func run(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame
		count_shots()


func state_name() -> String:
	return ["IDLE", "SHUFFLE", "MOVE", "FOLLOW", "ATTENTION", "DEFEND", "BUILD", "SURPRISED", "PINNED"][mate.state]


func _init() -> void:
	var scenario: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "wall"
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var home := Vector2(1500, 1500)
	var enemies: Array[Node2D] = []
	var count := 1 if scenario == "even" else 2
	for i in count:
		var spot := home + Vector2((i - 0.5) * 3 * PX, -15 * PX)
		var e: Node2D = load("res://scenes/enemy.tscn").instantiate()
		e.max_health = 1000.0
		e.position = spot
		level.add_child(e)
		enemies.append(e)
		if not (scenario == "exposed" and i == 0):
			add(level, "res://scenes/crate_ammo.tscn", spot + Vector2(0, 0.75 * PX))   # between it and the squad
	if scenario == "open":
		mate = add(level, "res://scenes/squadmate.tscn", home)
		add(level, "res://scenes/crate_ammo.tscn", home + Vector2(0, 3 * PX))
	else:
		add(level, "res://scenes/sandbags.tscn", home)
		mate = add(level, "res://scenes/squadmate.tscn", home + Vector2(0, 0.42 * PX))
	mate.max_health = 1000.0
	await process_frame
	await ticks(2)
	for e in enemies:
		e.set_physics_process(false)   # held still
		e.alerted = true
	mate._rifle.spare_mags = -1
	mate._rifle.rounds = 30
	if scenario != "open":
		mate.order_move(mate.global_position, true)
		await ticks(30)
	var start: Vector2 = mate.global_position
	mate.order_attack(enemies[0], false)   # as if shooting back
	await run(0.9)
	var before := shots
	await run(2.5)
	print("%s: %d enemies, state after 3.4 s %s, shots in first 0.9 s %d, in the next 2.5 s %d" % [
			scenario, count, state_name(), before, shots - before])
	match scenario:
		"wall":
			enemies[1].take_hit(enemies[1].global_position, Vector2.UP, 5000.0, null)
			var at_kill := shots
			await run(2.5)
			print("   one enemy dead: state %s, shots in the next 2.5 s %d" % [state_name(), shots - at_kill])
		"fire":
			mate.order_attack(enemies[0])   # the player's Fire order
			var at_order := shots
			await run(2.5)
			print("   Fire order: state %s, shots in the next 2.5 s %d" % [state_name(), shots - at_order])
		"open":
			var cover_ok: bool = mate._hide_cover != null and mate._hide_covers(mate.global_position, mate._hide_cover, enemies[0].global_position)
			print("   moved %.2f m, cover between it and its target now: %s" % [
					mate.global_position.distance_to(start) / PX, cover_ok])
	quit()
