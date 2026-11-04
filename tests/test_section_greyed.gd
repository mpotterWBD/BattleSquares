extends SceneTree
## Shots Away sections grey out the classes their profile doesn't count
## (shot_section.gd _validate_property(), height_profile.gd _share_height(),
## 2026-11-03): reads each section's property list, as the Inspector does, for
## the watch tower's upper stairs (height class 2) and top (3), then changes a
## profile's height class and adds a section. Read-only = greyed out. Also
## checks the greyed values are still saved. Prints OK / FAIL lines.

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## Which of a section's class pass-throughs are greyed out, e.g. [3].
func greyed(section: Resource) -> Array:
	var out := []
	for p in section.get_property_list():
		for cls in range(1, 4):
			if p.name == "class_%d_pass_through" % cls and p.usage & PROPERTY_USAGE_READ_ONLY:
				out.append(cls)
	return out


func all_greyed(profile: HeightProfile) -> Array:
	return profile.shots_away.map(greyed)


func _init() -> void:
	var stairs: HeightProfile = load("res://assets/height_profiles/watch_tower_upper_stairs.tres").duplicate(true)
	var top: HeightProfile = load("res://assets/height_profiles/watch_tower_top.tres").duplicate(true)
	print("upper stairs (class %d): %s   top (class %d): %s" % [stairs.height_class, all_greyed(stairs), top.height_class, all_greyed(top)])
	check("upper stairs, height 2: class 3 greyed in every section", all_greyed(stairs).all(func(g): return g == [3]))
	check("top, height 3: nothing greyed", all_greyed(top).all(func(g): return g.is_empty()))

	top.height_class = 1
	print("top set to 1: ", all_greyed(top))
	check("top set to 1: classes 2 and 3 greyed", all_greyed(top).all(func(g): return g == [2, 3]))

	var away := top.shots_away.duplicate()
	away.append(null)
	top.shots_away = away
	check("a section added at height 1 is greyed the same", greyed(top.shots_away[-1]) == [2, 3])

	top.height_class = 3
	check("back to 3: nothing greyed", all_greyed(top).all(func(g): return g.is_empty()))

	var path := "user://greyed_test.tres"
	top.height_class = 1
	top.shots_away[0].class_2_pass_through = 42
	ResourceSaver.save(top, path)
	var back: HeightProfile = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check("greyed values are still saved (class 2 = 42 at height 1)", back.shots_away[0].class_2_pass_through == 42)
	check("and greyed again after loading", greyed(back.shots_away[0]) == [2, 3])

	print("DONE, %d failed" % fails)
	quit()
