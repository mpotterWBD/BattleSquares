extends SceneTree
## Debug panels: each part of the watch tower, and other objects, in the same format.

const PX := 1024.0 / 12.0

var overlay: Node

func _click(world: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = root.get_canvas_transform() * world
	overlay._unhandled_input(ev)

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(8, 6) * PX
	main.add_child(tower)
	for f in 5: await physics_frame
	for n in main.find_children("*", "", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("debug_overlay.gd"):
			overlay = n
	var q := InputEventAction.new()
	q.action = "debug"
	q.pressed = true
	overlay._unhandled_input(q)
	var mate: Node2D = main.get_node("Squadmate")
	mate.global_position = tower.to_global(Vector2(-0.4, -0.3) * PX)
	mate._set_tower(tower)
	for f in 3: await physics_frame
	var targets := [["tower base (a leg)", tower.to_global(Vector2(1.6, 1.6) * PX)], ["tower upper stairs", tower.to_global(Vector2(2.0, 0.5) * PX)], ["tower lower stairs", tower.to_global(Vector2(2.0, 3.0) * PX)],
			["tower top", tower.to_global(Vector2(1.05, 0.5) * PX)], ["tower shelter", tower.to_global(Vector2(0.0, 0.0) * PX)],
			["sandbags", main.get_node("Sandbags").global_position], ["desk", main.get_node("RadioStation/DeskBody/Desk").global_position],
			["ammo crate", main.get_node("AmmoCrate").global_position]]
	for t in targets:
		_click(t[1])
		for f in 2: await process_frame
		var lines := []
		for l in [overlay._name_label, overlay._body_label]:
			if l.visible and l.text != "":
				lines.append(l.text.replace("\n", " | "))
		print("%s:\n    %s" % [t[0], "  //  ".join(lines)])
	_click(mate.global_position)
	for f in 2: await process_frame
	print("squadmate in the shelter:\n    %s" % overlay._body_label.text.replace("\n", " | "))
	quit()
