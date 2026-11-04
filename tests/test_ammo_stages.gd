extends SceneTree
## The ammo crate steps through its stage pictures as cans are taken.

func _init() -> void:
	var crate: Node = load("res://scenes/crate_ammo.tscn").instantiate()
	root.add_child(crate)
	await physics_frame
	crate._break_straps()
	var shown := ""
	for i in 25:
		var body: Sprite2D = crate.get_node("Body")
		var now := "%s h%.3f" % [body.texture.resource_path.get_file() if body.visible else "(pallet only)", crate.load_height_m]
		if now != shown:
			print("taken %2d: %s" % [crate.taken, now])
			shown = now
		crate.reserved = 24
		crate.take_part()
	quit()
