extends SceneTree
## A watch tower's Radio > Has Station: it starts with a radio station fitted.

const PX := 1024.0 / 12.0

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	var a: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	a.position = Vector2(10, 12) * PX
	a.radio_has_station = true
	main.add_child(a)
	var b: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	b.position = Vector2(25, 12) * PX
	b.radio_has_station = true
	b.radio_built = false
	main.add_child(b)
	var c: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	c.position = Vector2(30, 20) * PX
	main.add_child(c)
	root.add_child(main)
	current_scene = main
	for f in 5: await physics_frame
	for t in [a, b, c]:
		var st = t.station
		if st == null:
			print("%s: no station" % t.name)
			continue
		print("%s: station %s, mounted %s, built %s, site %s, from crate %s, desk at %s m" % [t.name, st.name, st.mount == t, st.built,
				st.is_in_group("build_sites"), st.site_crate.name if st.site_crate else "-", (t.to_local(st.get_node("DeskBody/Desk").global_position) / PX).snapped(Vector2(0.01, 0.01))])
	quit()
