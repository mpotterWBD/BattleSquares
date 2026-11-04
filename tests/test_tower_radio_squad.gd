extends SceneTree
## Squadmates build a radio station on a watch tower, carrying the parts up.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(10, 12) * PX
	main.add_child(tower)
	var crate: Node2D = main.get_node("CommsCrate")
	crate.strapped = false
	var cmd: Node = main.get_node("Command")
	for f in 3: await physics_frame
	cmd._placing = "radio_station"
	cmd._mouse_world = tower.global_position
	cmd._update_ghosts()
	cmd._place(cmd._layout())
	var st: Node2D = tower.station
	var crew := [main.get_node("Squadmate"), main.get_node("Squadmate2")]
	for m in crew:
		m.order_build()
	var peak := 0.0
	for s in 120:
		for f in 60: await physics_frame
		for m in crew:
			peak = maxf(peak, m.elevation_m)
		if st.built:
			print("built after %d s (squadmates peaked at %.1f m up)" % [s + 1, peak])
			break
		if s % 20 == 19:
			print("%3d s: installed %s, crew %s" % [s + 1, st.installed, crew.map(func(m): return "%s %s up %.1f at %s via %s" % [m.State.keys()[m.state], m.carrying, m.elevation_m, (tower.to_local(m.global_position) / PX).snapped(Vector2(0.01, 0.01)), (tower.to_local(m._tower_way(m._build_site.deliver_spot(m.global_position) if m._build_site else m.global_position)) / PX).snapped(Vector2(0.01,0.01))])])
	print("final: built %s, installed %s" % [st.built, st.installed])
	quit()
