@tool   # (in the editor too: it tidies and names its sections as they're added, _tidy_sections())
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
## Adding one (_tidy_sections()) fills the Inspector's empty slot with a copy of
## the section before it, and gives the old last one a radius past the one inside it.

## How far past the section inside it a section that had no radius of its
## own (the old last one, once another's added) is put.
const RADIUS_STEP_M := 5.0

## How high it is (cover.gd height classes). Shots Away only counts cover this
## high or lower, so its sections grey out the classes above it.
@export_range(1, 3, 1) var height_class := 3:
	set(value):
		height_class = value
		_share_height()
## Of the shots at someone here from anywhere else, this share gets through
## the place itself (the rest stop in it). Shots Into's sections, if any, say
## it by the shooter's distance instead.
@export_range(0, 100, 1, "suffix:%") var pass_through := 50

@export_group("Shots Away")
## Firing from here, nearest first.
@export var shots_away: Array[ShotSection] = []:
	set(value):
		shots_away = value
		_tidy_sections(shots_away, "Section", ShotSection)
		_share_height()

@export_group("Shots Into")
## Shot at here, by the shooter's distance, nearest first.
@export var shots_into: Array[ShotIntoSection] = []:
	set(value):
		shots_into = value
		_tidy_sections(shots_into, "Into Section", ShotIntoSection)


## Tells each Shots Away section this place's height class, so the Inspector
## greys out its pass-throughs for cover higher than that: cover.gd away_pass()
## treats that as just cover, so they'd do nothing (Mike, 2026-11-03).
func _share_height() -> void:
	for section in shots_away:
		if section != null:
			section.set("height_class", height_class)   # (not a method call: see shot_section.gd)


## Run whenever a list changes (added to, taken from, reordered, loaded):
##   - An empty slot (the Inspector's Add Element) gets a section, a copy of
##     the one before it (`kind` if it's the first), so adding one adds a
##     ring out past the rest with the old last one's settings (Mike, 2026-11-03).
##   - A section that isn't the last but reaches no further than the one
##     inside it (the old last one's radius never counted, so it's often 0)
##     covers nothing: it's put RADIUS_STEP_M past that one, to adjust from.
##   - Each is named by its place, counting from 1 like the circles ("Section
##     1" is the nearest): the Inspector shows the name on the element instead
##     of "ShotSection", where Godot's own list numbers start at 0 (Mike, 2026-11-02).
## Editing a section's radius by hand doesn't come through here, so it's never undone.
static func _tidy_sections(sections: Array, word: String, kind: Script) -> void:
	for i in sections.size():
		if sections[i] == null:
			sections[i] = sections[i - 1].duplicate() if i > 0 and sections[i - 1] != null else kind.new()
	var inner := 0.0
	for i in sections.size():
		if i < sections.size() - 1 and sections[i].radius_m <= inner:
			sections[i].radius_m = inner + RADIUS_STEP_M
		inner = sections[i].radius_m
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
