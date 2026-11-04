extends SceneTree
## Clicking strapped crates one after another with the whole squad in the
## circle (nobody selected) sends one squadmate to each: the nearest that
## isn't already off undoing another crate's straps (Mike, 2026-11-02). A
## crate someone's already going to gets nobody new; with everyone busy, a
## red ping and nobody.

const PX := 1024.0 / 12.0


func m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * PX


func ticks(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for e in main.get_children():
		if e.get_script() and e.get_script().resource_path.ends_with("enemy.gd"):
			e.queue_free()
	await ticks(3)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = m(24.0, 9.0)
	var command: Node = main.get_node("Command")
	var mates: Array = []
	for i in 4:
		var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
		mate.name = "Mate%d" % (i + 1)
		mate.position = m(23.0 + i * 0.8, 10.5)
		main.add_child(mate)
		mates.append(mate)
	var crates: Array = []
	for i in 5:
		var crate: Node2D = load("res://scenes/crate_sandbags.tscn").instantiate()
		crate.name = "Crate%d" % (i + 1)
		crate.position = m(22.0 + i * 1.6, 13.0)   # (clear of the level's watch tower, at (16.85, 15.64))
		main.add_child(crate)
		crates.append(crate)
	await ticks(5)
	Input.action_press("command")
	await ticks(3)

	var report := func(label: String) -> void:
		var who := []
		for u in mates:
			var c = u.unstrapping()
			who.append("%s->%s" % [u.name, c.name if c else "-"])
		var red: int = command._pings.filter(func(p): return p.get("color", command.COLOR) == command.REFUSE_COLOR).size()
		print("%-34s %s   red pings %d" % [label, ", ".join(who), red])

	for step in [["click Crate1", 0], ["click Crate2", 1], ["click Crate1 again", 0], ["click Crate3", 2], ["click Crate4", 3], ["click Crate5 (all busy)", 4]]:
		command._click(crates[step[1]].global_position, false)
		await ticks(2)
		report.call(step[0])

	var t := 0
	while crates.slice(0, 4).any(func(c): return c.strapped) and t < 1800:
		await physics_frame
		t += 1
	print("straps off crates 1-4: %s after %.1f s; crate 5 still strapped %s" % [crates.slice(0, 4).map(func(c): return not c.strapped), t / 60.0, crates[4].strapped])
	await ticks(10)
	command._click(crates[4].global_position, false)
	await ticks(2)
	report.call("click Crate5 once they're free")
	Input.action_release("command")
	quit()
