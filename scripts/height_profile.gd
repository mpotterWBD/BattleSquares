@tool   # (in the editor too: it names its sections as they're added, _name_sections())
extends Resource
class_name HeightProfile
## How high a place you can stand on is, for shooting (Mike, 2026-11-02): a
## watch tower's parts each have one (watch_tower.gd `lower_stairs` ...
## `shelter`), and anything else you'll stand on can. Saved as its own file
## (assets/height_profiles/), so things of a kind can share one; "Make
## Unique" in the Inspector to give one thing its own.
##
##   - Height Class: how high it is (1 low, 2 middling, 3 tall: cover.gd).
##   - Pass Through: of the shots at someone here from anywhere else, the
##     share that gets through the place itself (its steel, its walls); with
##     Shots Into sections, only for a shot with no shooter to measure from.
##   - Shots Away: firing from here, sections out from its middle (by the
##     cover's distance from it): how much of the shots get through cover
##     as high as this or lower, by that cover's height class. Cover higher
##     than where you stand is just cover.
##   - Shots Into: shot at here, sections out from its middle by how far the
##     SHOOTER is: the Pass Through for shots from that far (easier to hit
##     from close up), and whether low cover hides them from there (Seen).
## The sections go nearest first; the last reaches as far as a bullet goes.

## How high it is (cover.gd height classes).
@export_range(1, 3, 1) var height_class := 3
## Of the shots at someone here from anywhere else, this share gets through
## the place itself (the rest stop in it). Shots Into's sections, if any, say
## it by the shooter's distance instead.
@export_range(0, 100, 1, "suffix:%") var pass_through := 50

@export_group("Shots Away")
## Firing from here, nearest first.
@export var shots_away: Array[ShotSection] = []:
	set(value):
		shots_away = value
		_name_sections(shots_away, "Section")

@export_group("Shots Into")
## Shot at here, by the shooter's distance, nearest first.
@export var shots_into: Array[ShotIntoSection] = []:
	set(value):
		shots_into = value
		_name_sections(shots_into, "Into Section")


## Names each section by its place, counting from 1 like the circles ("Section
## 1" is the nearest): the Inspector shows the name on the element instead of
## "ShotSection", where Godot's own list numbers start at 0 (Mike, 2026-11-02).
static func _name_sections(sections: Array, word: String) -> void:
	for i in sections.size():
		if sections[i] != null:
			sections[i].resource_name = "%s %d" % [word, i + 1]


## The Shots Away section `distance_m` from the middle (null: none).
func away_section(distance_m: float) -> ShotSection:
	return _section_at(shots_away, distance_m)


## The Shots Into section `distance_m` from the middle (null: none).
func into_section(distance_m: float) -> ShotIntoSection:
	return _section_at(shots_into, distance_m)


## Which section (1..) `distance_m` from the middle is in `sections` (0: none).
static func section_number(sections: Array, distance_m: float) -> int:
	for i in sections.size():
		if sections[i] != null and (i == sections.size() - 1 or distance_m <= sections[i].radius_m):
			return i + 1
	return 0


static func _section_at(sections: Array, distance_m: float) -> Variant:
	var n := section_number(sections, distance_m)
	return sections[n - 1] if n > 0 else null
