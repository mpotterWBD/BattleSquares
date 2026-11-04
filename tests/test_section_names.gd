extends SceneTree
func _init() -> void:
	var p: HeightProfile = load("res://assets/height_profiles/watch_tower_top.tres")
	print("loaded: away %s; into %s" % [p.shots_away.map(func(s): return s.resource_name), p.shots_into.map(func(s): return s.resource_name)])
	var list := p.shots_away.duplicate()
	list.push_front(ShotSection.new())   # a new nearest one
	list.append(null)                    # an empty slot
	p.shots_away = list
	print("a new one first, an empty slot last: %s" % [p.shots_away.map(func(s): return s.resource_name if s else "<empty>")])
	list = p.shots_away.duplicate()
	list.reverse()
	p.shots_away = list
	print("reversed: %s" % [p.shots_away.map(func(s): return s.resource_name if s else "<empty>")])
	quit()
