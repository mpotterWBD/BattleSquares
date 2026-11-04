extends SceneTree
## Two F targets in reach: only the closest takes F (and shows its green F).

const PX := 1024.0 / 12.0
const World = preload("res://scripts/world.gd")

var main: Node
var player: Node2D
var station: Node2D
var crate: Node2D
var term: Node

func _press_f() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F
	ev.physical_keycode = KEY_F
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)

func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")
	station = load("res://scenes/radio_station.tscn").instantiate()
	station.position = Vector2(18, 10) * PX
	main.add_child(station)
	term = station.get_node("Terminal")
	crate = main.get_node("AmmoCrate2")
	crate.strapped = true
	var zone: Node2D = station.get_node("OperatorZone")
	var pad: Node2D = station.get_node("StandBox")
	for f in 3: await physics_frame
	# Player in the desk's zone; crate placed so the player is 1.0 m from it.
	var stand: Vector2 = zone.global_position
	for case in ["crate closer", "desk closer"]:
		player.global_position = stand
		var pad_d: float = stand.distance_to(pad.global_position) / PX
		var crate_d := 0.8 if case == "crate closer" else 1.2
		crate.global_position = stand + Vector2(-crate_d * PX, 0)
		crate.unstrap_progress = 0.0
		for f in 5:
			await physics_frame
		for f in 3: await process_frame
		print("   key %s unstrapper %s take %s unstrap %s pm %s" % [crate._key, crate._unstrapper, crate.can_take(player), crate.can_unstrap(player), crate.process_mode])
		var t = player.interact_target()
		print("%s: pad %.2f m, crate %.2f m -> target %s; desk F shown %s, crate F shown %s" % [case, pad_d, crate_d,
				t.name if t else "none", term._pad_prompt.visible, crate._key.visible])
		_press_f()
		Input.action_press("interact")
		for f in 10: await physics_frame
		Input.action_release("interact")
		print("   after F: terminal screen %s, crate unstrap progress %.2f" % [term.screen, crate.unstrap_progress])
		if term.screen != 0:
			term.close()
		player.busy = false
		for f in 3: await physics_frame
	quit()
