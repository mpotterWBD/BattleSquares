extends SceneTree
## The straps coming off a crate play BandBreak.mp3.

func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var crate: Node2D = load("res://scenes/crate_sandbags.tscn").instantiate()
	crate.position = Vector2(500, 500)
	level.add_child(crate)
	await process_frame
	print("sound file loads: %s" % ResourceLoader.exists(crate.UNSTRAP_SOUND))
	crate._break_straps()
	for node in level.get_children():
		if node is AudioStreamPlayer2D:
			print("playing=%s stream=%s length=%.2f s at=%s" % [node.playing, node.stream.resource_path.get_file(),
					node.stream.get_length(), node.position])
	quit()
