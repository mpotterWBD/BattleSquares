extends SceneTree
const PX := 1024.0 / 12.0
const DebugOverlay = preload("res://scripts/debug_overlay.gd")
func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for i in 10:
		await physics_frame
	var crate: Node2D = main.get_node("AmmoCrate")
	var overlay: Node = null
	for n in main.find_children("*", "", true, false):
		if n.get_script() == DebugOverlay:
			overlay = n
	load("res://scripts/world.gd").debug = true
	overlay._layer.visible = true
	overlay._picked = crate
	main.get_node("Camera")._target_zoom = 0.75
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("crate_debug.png")
	print(overlay._name_label.text, " | ", overlay._ammo_label.text, " | ", overlay._mags_label.text, " | ", overlay._state_label.text)
	quit()
