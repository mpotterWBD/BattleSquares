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
## Something with cover_stop_chance() says what it stops (crate.gd,
## sandbags.gd, partial_cover.gd); any other solid body stops every shot.
## Load with:
##     const Cover = preload("res://scripts/cover.gd")

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
