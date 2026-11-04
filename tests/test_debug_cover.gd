extends SceneTree
## Debug mode: enemy rings only in debug; clicking a solid thing shows its cover class.

const World = preload("res://scripts/world.gd")

var main: Node
var overlay: Node

func _click(world: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = root.get_canvas_transform() * world
	overlay._unhandled_input(ev)

func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	enemy.position = Vector2(2000, 300)
	main.add_child(enemy)
	for f in 5: await physics_frame
	for n in main.find_children("*", "", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("debug_overlay.gd"):
			overlay = n
	var ring: Node2D = enemy.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("enemy_ring.gd"))[0]
	await process_frame
	print("normal play: enemy ring visible %s" % ring.visible)
	var q := InputEventAction.new()
	q.action = "debug"
	q.pressed = true
	overlay._unhandled_input(q)
	for f in 2: await process_frame
	print("debug on: enemy ring visible %s" % ring.visible)
	var station: Node2D = main.get_node("RadioStation")
	var targets := {
		"sandbag wall": main.get_node("Sandbags").global_position,
		"desk": station.get_node("DeskBody/Desk").global_position,
		"dish": station.get_node("DishBody/Dish").global_position,
		"ammo crate": main.get_node("AmmoCrate").global_position,
	}
	for what in targets:
		_click(targets[what])
		for f in 2: await process_frame
		var lines := []
		for l in [overlay._name_label, overlay._body_label]:
			if l.visible and l.text != "":
				lines.append(l.text.replace("\n", " | "))
		print("%s: picked %s, panel shown %s: %s" % [what, overlay._picked.name if overlay._picked else "none", overlay._panel.visible, "  //  ".join(lines)])
	_click(Vector2(5, 5))
	for f in 2: await process_frame
	print("open ground: picked %s" % overlay._picked)
	overlay._unhandled_input(q)
	for f in 2: await process_frame
	print("debug off: enemy ring visible %s" % ring.visible)
	quit()
