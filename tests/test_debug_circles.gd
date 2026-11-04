extends SceneTree
## Debug mode (Q): clicking each part of the watch tower, does the panel show
## and the sections draw (no errors)?

const PX := 1024.0 / 12.0
const DebugOverlay = preload("res://scripts/debug_overlay.gd")


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for f in 10: await process_frame
	var tower: Node2D = main.get_node("WatchTower")
	var overlay: Node = main.get_node("Command").get_children().filter(func(c): return c.get_script() == DebugOverlay)[0]
	var key := InputEventAction.new()
	key.action = "debug"
	key.pressed = true
	Input.parse_input_event(key)
	for f in 3: await process_frame
	var drawn := [0]
	overlay._view.draw.connect(func(): drawn[0] += 1)
	for c in [["lower stairs", Vector2(2.0, 3.0)], ["upper stairs", Vector2(2.0, 0.3)], ["top", Vector2(-0.5, 1.05)], ["shelter", Vector2(-0.3, -0.3)]]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = root.get_final_transform() * (root.get_canvas_transform() * tower.to_global(c[1] * PX))
		click.global_position = click.position
		Input.parse_input_event(click)
		var before: int = drawn[0]
		for f in 5: await process_frame
		var picked: String = "%s / %s" % [overlay._picked.name if overlay._picked else "-", overlay._picked_part]
		var profile = tower.profile_for(overlay._picked_part) if overlay._picked == tower else null
		print("%-13s picked %s; profile %s; view redrawn %d times; panel shown %s" % [c[0], picked, profile.resource_path.get_file() if profile else "-",
			drawn[0] - before, overlay._panel.visible])
	quit()
