extends SceneTree
## Radio command: the camera frames everyone once, then stays put as they move;
## the wheel zooms; Back returns to the RADIO menu; Exit closes it.

const PX := 1024.0 / 12.0
const World = preload("res://scripts/world.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var cam: Camera2D = main.get_node("Camera")
	var cmd: Node = main.get_node("Command")
	var player: Node2D = main.get_node("Player")
	var station: Node2D = main.get_node("RadioStation")
	var term = station.get_node("Terminal")
	player.global_position = station.get_node("OperatorZone").global_position
	for f in 10: await physics_frame
	term.open_menu()
	term._on_command()
	for f in 120: await process_frame
	var framed: Vector2 = cam.position
	var zoom_framed: float = cam.zoom.x
	for u in get_nodes_in_group("squad"):
		u.global_position += Vector2(8, 4) * PX
	for f in 60: await process_frame
	print("radio command: framed at %s zoom %.2f; after the squad moved 9 m: camera moved %.1f px, zoom %.2f" % [framed.round(), zoom_framed, cam.position.distance_to(framed), cam.zoom.x])
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	cam._unhandled_input(wheel)
	cam._unhandled_input(wheel)
	for f in 60: await process_frame
	print("two notches in: zoom %.2f (was %.2f)" % [cam.zoom.x, zoom_framed])
	print("Back shown %s, Deploy shown %s, deploy button enabled %s" % [cmd._back_button.is_visible_in_tree(), cmd._deploy_menu.visible, not cmd._deploy_button.disabled])
	cmd._start_placing("sandbags")
	print("placing sandbags over the radio: %s" % (cmd._placing == "sandbags"))
	cmd._stop_placing()
	cmd._back_to_radio()
	for f in 5: await process_frame
	print("after Back: radio commanding %s, RADIO menu open %s" % [World.radio_commanding, term.screen == term.Screen.MENU])
	term.close()
	term.open_menu()
	var exit_button: Button = null
	for b in term._menu.find_children("*", "Button", true, false):
		if b.text == "Exit":
			exit_button = b
	exit_button.pressed.emit()
	for f in 5: await process_frame
	print("Exit pressed: menu closed %s, player busy %s" % [term.screen == term.Screen.CLOSED, player.busy])
	quit()
