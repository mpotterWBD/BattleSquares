extends RefCounted
## Cover classes: how much protection something on the field gives, by the
## share of the shots reaching it that it stops (Mike, 2026-10-31), for the
## AI to weigh cover by later:
##   0 NONE    not cover: a square, a wall shot down to a puddle, an emptied
##             crate (just its pallet)
##   1 LIGHT   stops LIGHT_MAX (40%) or less: the station's desk (30%)
##   2 MEDIUM  stops more than that, up to MEDIUM_MAX (60%): the dish (60%)
##   3 HEAVY   stops more than 60%: a sandbag wall (90%), a crate, the lone
##             ammo can, a helicopter's hull (100%)
## Firing over cover drops it: a square that's just fired (soldier.gd
## `exposed_s`) right behind a sandbag wall is covered by it only
## EXPOSED_STOP (40%, class 1) of the time (stop_chance_for()).
## Height (Mike, 2026-11-02): someone standing somewhere with a height profile
## (height_profile.gd: a watch tower's parts) fires past cover as high as
## where they stand or lower by its Shots Away (away_pass(), height_extra());
## shot at there, its Shots Into says by the shooter's distance how much gets
## through the part (watch_tower.gd cover_pass()) and whether low cover hides
## them (seen_past()).
## A watch tower covers whoever's in or under it: only so much of the shots
## at them get through its steel (tower_pass(), tower_blocks()).
## Something with cover_stop_chance() says what it stops (crate.gd,
## sandbags.gd, partial_cover.gd); any other solid body stops every shot.
## Load with:
##     const Cover = preload("res://scripts/cover.gd")

const World = preload("res://scripts/world.gd")

const NONE := 0
const LIGHT := 1
const MEDIUM := 2
const HEAVY := 3
const LIGHT_MAX := 0.4
const MEDIUM_MAX := 0.6


## The class for cover that stops `stops` (0..1) of the shots reaching it.
static func class_for(stops: float) -> int:
	if stops <= 0.0:
		return NONE
	if stops <= LIGHT_MAX:
		return LIGHT
	if stops <= MEDIUM_MAX:
		return MEDIUM
	return HEAVY


## The share of the shots reaching `node` that it stops (squares: none, they're not cover).
static func stop_chance(node: Node) -> float:
	if node == null or not is_instance_valid(node) or node.has_method("take_hit"):
		return 0.0
	if node.has_method("cover_stop_chance"):
		return node.cover_stop_chance()
	return 1.0 if node is CollisionObject2D else 0.0


## `node`'s cover class (NONE, LIGHT, MEDIUM or HEAVY).
static func class_of(node: Node) -> int:
	return class_for(stop_chance(node))



## The share of shots reaching `node` at world `point` (where the line of
## fire meets it) that it stops on the way to `unit`: less than
## stop_chance() if `unit` is exposed behind it (cover_stop_chance_for(),
## sandbags.gd).
static func stop_chance_for(node: Node, point: Vector2, unit: Node2D) -> float:
	if unit != null and is_instance_valid(node) and node.has_method("cover_stop_chance_for"):
		return node.cover_stop_chance_for(point, unit)
	return stop_chance(node)


## The cover class `node` gives `unit` on the line of fire meeting it at `point`.
static func class_for_unit(node: Node, point: Vector2, unit: Node2D) -> int:
	return class_for(stop_chance_for(node, point, unit))


## Height classes (Mike, 2026-11-01): how tall something is, for firing down
## on it from up high. 1 low (sandbags, the radio station's desk and dish),
## 2 middling (crates), 3 tall (a watch tower, and anything else solid that
## doesn't say: a helicopter). Things say with `height_class`.
static func height_class_of(node: Node) -> int:
	if node != null and is_instance_valid(node) and "height_class" in node:
		return node.height_class
	return 3


## The height profile of where `unit` stands (height_profile.gd: up a watch
## tower, its part's), or null on the ground.
static func profile_of(unit: Node) -> HeightProfile:
	if unit == null or not is_instance_valid(unit):
		return null
	var tower = unit.get("tower")
	if tower == null or not is_instance_valid(tower):
		return null
	return tower.profile_of(unit)


## The middle its sections are measured from: the middle of the part of the
## tower `unit` stands on (watch_tower.gd part_middle()).
static func _profile_middle(unit: Node) -> Vector2:
	var tower = unit.get("tower")
	return tower.part_middle(tower.part_of(unit))


## Of `shooter`'s shots meeting cover of height class `cls` at world `point`,
## letting `normal` (0..1) through anyway, the share that get through: more
## by the Shots Away of where it stands if the cover's lower (never less).
static func away_pass(shooter: Node, cls: int, point: Vector2, normal: float) -> float:
	var profile := profile_of(shooter)
	if profile == null or cls > profile.height_class:   # (as high or lower: Mike, 2026-11-02)
		return normal
	var section := profile.away_section(_profile_middle(shooter).distance_to(point) / World.PX_PER_M)
	return maxf(normal, section.pass_for(cls)) if section else normal


## Of the shots `node` would stop where they meet it at world `point`, the
## share (0..1) that get through anyway by the shooter's height (away_pass()),
## for a roll after the cover's own (bullet.gd). `stops`: what it stops
## otherwise (its stop_chance() if not given). None for squares, or fired from
## the ground.
static func height_extra(node: Node, point: Vector2, shooter: Node, stops := -1.0) -> float:
	if node == null or not is_instance_valid(node) or node.has_method("take_hit"):
		return 0.0
	if stops < 0.0:
		stops = stop_chance(node)
	if stops <= 0.0:
		return 0.0
	var through := away_pass(shooter, height_class_of(node), point, 1.0 - stops)
	return clampf(1.0 - (1.0 - through) / stops, 0.0, 1.0)


## Whether `node` (cover met looking from world `from` at `target`) leaves
## `target` in view: it's low (height class 1 or 2, and no higher than where
## `target` stands), and `target`'s Shots Into section for that distance says
## Seen.
static func seen_past(node: Node, target: Node, from: Vector2) -> bool:
	var profile := profile_of(target)
	if profile == null or node == null or node.has_method("take_hit"):
		return false
	if height_class_of(node) > mini(profile.height_class, 2):
		return false
	var section := profile.into_section(_profile_middle(target).distance_to(from) / World.PX_PER_M)
	return section != null and section.seen


## The share (0..1) of `shooter`'s shots that get through a watch tower's
## steel to `target` in or under it (watch_tower.gd cover_pass(): under the
## deck, on the stair, on the deck, in the cabin); 1 if it's in none of them.
static func tower_pass(target: Node, shooter: Node) -> float:
	var through := 1.0
	if target == null or not is_instance_valid(target):
		return through
	for tower in target.get_tree().get_nodes_in_group("watch_towers"):
		through = minf(through, tower.cover_pass(target, shooter))
	return through


## A shot at `target` by `shooter` reaching it in or under a watch tower: the
## tower's body the shot stops in instead (a roll on tower_pass()), or null
## if it gets through.
static func tower_blocks(target: Node, shooter: Node) -> Node:
	if target == null or not is_instance_valid(target):
		return null
	for tower in target.get_tree().get_nodes_in_group("watch_towers"):
		if randf() >= tower.cover_pass(target, shooter):
			return tower.get_node("LegsBody")
	return null
