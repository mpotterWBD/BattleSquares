extends SceneTree
func _init() -> void:
	print("editor hint: %s" % Engine.is_editor_hint())
	var p: HeightProfile = ResourceLoader.load("res://assets/height_profiles/watch_tower_top.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	print("names: %s" % [p.shots_away.map(func(s): return s.resource_name)])
	quit()
