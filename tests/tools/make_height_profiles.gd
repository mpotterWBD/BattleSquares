extends SceneTree
## The watch tower's default profiles, Shots Into by the shooter's distance.
const DIR := "res://assets/height_profiles/"

func away(radius: float, c1: int, c2: int, c3: int) -> ShotSection:
	var s := ShotSection.new()
	s.radius_m = radius
	s.class_1_pass_through = c1
	s.class_2_pass_through = c2
	s.class_3_pass_through = c3
	return s

func into(radius: float, through: int, seen: bool) -> ShotIntoSection:
	var s := ShotIntoSection.new()
	s.radius_m = radius
	s.pass_through = through
	s.seen = seen
	return s

func save(name: String, height: int, through: int, shots_away: Array, shots_into: Array) -> void:
	var p := HeightProfile.new()
	p.height_class = height
	p.pass_through = through
	var a: Array[ShotSection] = []
	a.assign(shots_away)
	var b: Array[ShotIntoSection] = []
	b.assign(shots_into)
	p.shots_away = a
	p.shots_into = b
	print("%s: %s" % [name, error_string(ResourceSaver.save(p, DIR + name + ".tres"))])

func _init() -> void:
	save("watch_tower_top", 3, 50, [away(5.0, 78, 50, 0), away(10.0, 55, 25, 0), away(0.0, 33, 10, 0)],
		[into(5.0, 70, true), into(10.0, 50, true), into(0.0, 35, false)])
	save("watch_tower_shelter", 3, 0, [], [into(5.0, 0, true), into(10.0, 0, true), into(0.0, 0, false)])
	save("watch_tower_upper_stairs", 2, 80, [away(5.0, 60, 0, 0), away(10.0, 45, 0, 0), away(0.0, 30, 0, 0)],
		[into(5.0, 90, true), into(10.0, 75, true), into(0.0, 55, false)])
	quit()
