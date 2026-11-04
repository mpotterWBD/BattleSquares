extends SceneTree
## A sandbag wall going up (bags delivered) plays a sand thud at it.

func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var crate: Node2D = load("res://scenes/crate_sandbags.tscn").instantiate()
	crate.position = Vector2(300, 300)
	level.add_child(crate)
	var wall: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	wall.position = Vector2(600, 300)
	level.add_child(wall)
	await process_frame
	wall.start_site(crate)
	var before := level.get_children().filter(func(n): return n is AudioStreamPlayer2D).size()
	print("site: built=%s, sounds %d" % [wall.built, before])
	wall.install("sandbags")
	for node in level.get_children():
		if node is AudioStreamPlayer2D:
			print("installed: built=%s, playing=%s %s at %s" % [wall.built, node.playing, node.stream.resource_path.get_file(), node.position])
	quit()
