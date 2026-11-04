extends SceneTree
## Adding a section to a height profile (height_profile.gd _tidy_sections(),
## 2026-11-03): does what the Inspector's Add Element does (an empty slot on
## the end, the list set back) to the watch tower top's Shots Away and Shots
## Into, then checks the empty slot became a section copying the one before
## it, the old last section (radius 0) got a radius past the one inside it,
## and distances land in the right sections. Also: as loaded nothing changes,
## and editing a radius by hand isn't undone. Prints OK / FAIL lines.

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func radii(sections: Array) -> Array:
	return sections.map(func(s): return s.radius_m)


func _init() -> void:
	var profile: HeightProfile = load("res://assets/height_profiles/watch_tower_top.tres").duplicate(true)
	print("loaded away radii ", radii(profile.shots_away), "  into radii ", radii(profile.shots_into))
	check("as loaded, the last section's radius is left alone",
			radii(profile.shots_away) == [5.0, 10.0, 0.0] and radii(profile.shots_into) == [5.0, 10.0, 0.0])

	var away := profile.shots_away.duplicate()
	away.append(null)
	profile.shots_away = away
	var s: Array = profile.shots_away
	print("after Add Element, away radii ", radii(s), "  names ", s.map(func(x): return x.resource_name))
	check("4 sections, none empty", s.size() == 4 and not s.has(null))
	check("section 3 pushed out to 15 m", is_equal_approx(s[2].radius_m, 15.0))
	check("section 4 copies section 3's pass-through (33/10)", s[3].class_1_pass_through == 33 and s[3].class_2_pass_through == 10)
	check("section 4 is its own copy", s[3] != s[2])
	check("named Section 1-4", s.map(func(x): return x.resource_name) == ["Section 1", "Section 2", "Section 3", "Section 4"])
	check("12 m is in section 3, 20 m in section 4",
			HeightProfile.section_number(s, 12.0) == 3 and HeightProfile.section_number(s, 20.0) == 4)

	s[2].radius_m = 25.0   # by hand, in the section's own Inspector
	check("a radius set by hand stays", is_equal_approx(profile.shots_away[2].radius_m, 25.0))
	away = profile.shots_away.duplicate()
	away.append(null)
	profile.shots_away = away
	print("after a 5th, away radii ", radii(profile.shots_away))
	check("a 5th: 25 kept, section 4 to 30 m", radii(profile.shots_away).slice(0, 4) == [5.0, 10.0, 25.0, 30.0])

	var into := profile.shots_into.duplicate()
	into.append(null)
	profile.shots_into = into
	var t: Array = profile.shots_into
	print("into after Add Element, radii ", radii(t))
	check("into: section 3 to 15 m, section 4 copies 35% / hidden",
			t.size() == 4 and is_equal_approx(t[2].radius_m, 15.0) and t[3].pass_through == 35 and not t[3].seen
			and t[3].resource_name == "Into Section 4")

	var fresh := HeightProfile.new()
	fresh.shots_away = [null] as Array[ShotSection]
	check("a first section in an empty list is a new ShotSection",
			fresh.shots_away.size() == 1 and fresh.shots_away[0] is ShotSection)

	print("DONE, %d failed" % fails)
	quit()
