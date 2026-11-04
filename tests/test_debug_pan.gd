extends SceneTree
## Debug mode: wheel-button drag pans the camera; off, it's ignored; Q off eases back.

const PX := 1024.0 / 12.0
const World = preload("res://scripts/world.gd")

func key_q() -> void:
	var e := InputEventAction.new()
	e.action = "debug"
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = InputEventAction.new()
	e.action = "debug"
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame

func drag(by: Vector2) -> void:
	var cam: Camera2D = current_scene.get_node("Camera")
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_MIDDLE
	b.pressed = true
	cam._unhandled_input(b)
	for i in 4:
		var m := InputEventMouseMotion.new()
		m.relative = by / 4.0
		cam._unhandled_input(m)
		await process_frame
	b = InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_MIDDLE
	b.pressed = false
	cam._unhandled_input(b)
	for i in 5:
		await process_frame

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 10:
		await process_frame
	var cam: Camera2D = main.get_node("Camera")
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = Vector2(22, 12) * PX
	for i in 60:
		await process_frame
	print("start: cam %s m, zoom %.2f" % [(cam.position / PX).snapped(Vector2(0.01, 0.01)), cam.zoom.x])
	await drag(Vector2(-300, 0))
	print("drag, not debug: cam %s m" % (cam.position / PX).snapped(Vector2(0.01, 0.01)))
	await key_q()
	print("debug on: ", World.debug)
	await drag(Vector2(-300, 120))
	print("drag 300 px left, 120 up in debug: cam %s m" % (cam.position / PX).snapped(Vector2(0.01, 0.01)))
	await drag(Vector2(-100000, 0))
	print("huge drag: cam %s m (stops at the edge)" % (cam.position / PX).snapped(Vector2(0.01, 0.01)))
	await drag(Vector2(500, 0))
	print("back 500 px: cam %s m (moves straight away)" % (cam.position / PX).snapped(Vector2(0.01, 0.01)))
	await key_q()
	for i in 90:
		await process_frame
	print("debug off, 1.5 s later: cam %s m, player %s m" % [(cam.position / PX).snapped(Vector2(0.01, 0.01)), (player.position / PX).snapped(Vector2(0.01, 0.01))])
	quit()
