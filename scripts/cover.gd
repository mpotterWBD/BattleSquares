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
## Fired down on from up a watch tower, more gets through lower cover
## (fired_down_extra(), by its height class: height_class_of()).
## A watch tower covers whoever's in or under it: only so much of the shots
## at them get through its steel (tower_pass(), tower_blocks()).
## From inside its overlook box, someone up high on it has only the tower to
## protect them: class 1 and 2 cover in between doesn't count (in_full_view(),
## overlook_past()).
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
const OVERLOOK_LINE_M := 0.5   ## a shot passing this close to someone up a watch tower is at them (overlook_past())


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


## Of `shooter`'s shots that `node` would stop where they meet it at world
## `point`, the share (0..1) that get through anyway: firing down on it from
## up a watch tower, so that in all the tower's new pass-through for its
## height class and section gets through (watch_tower.gd fired_down_pass()).
## `stops`: what it stops otherwise (its stop_chance() if not given). None on
## the ground.
static func fired_down_extra(node: Node, point: Vector2, shooter: Node, stops := -1.0) -> float:
	if shooter == null or not is_instance_valid(shooter) or node == null or node.has_method("take_hit"):
		return 0.0
	var tower = shooter.get("tower")
	if tower == null or not is_instance_valid(tower):
		return 0.0
	if stops < 0.0:
		stops = stop_chance(node)
	if stops <= 0.0:
		return 0.0
	var through: float = tower.fired_down_pass(height_class_of(node), point, 1.0 - stops, shooter.elevation_m,
			tower.height_class_of_unit(shooter))
	return clampf(1.0 - (1.0 - through) / stops, 0.0, 1.0)


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


## Whether height class 1 and 2 cover between world `from` and `target`
## doesn't count, for seeing it or shooting it: it's up high on a watch tower
## and `from` is in that tower's overlook box (watch_tower.gd in_full_view()).
static func in_full_view(target: Node, from: Vector2) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	for tower in target.get_tree().get_nodes_in_group("watch_towers"):
		if tower.in_full_view(target, from):
			return true
	return false


## For a bullet that's reached `node`: whether it flies on over it, being
## height class 1 or 2 cover on the way to someone up high on a watch tower
## that it was fired at from inside that tower's overlook box (passing
## within OVERLOOK_LINE_M of them, beyond it).
static func overlook_past(node: Node, bullet: Node2D) -> bool:
	if node == null or node.has_method("take_hit") or height_class_of(node) > 2:
		return false
	var ahead: Vector2 = bullet.velocity.normalized()
	for tower in node.get_tree().get_nodes_in_group("watch_towers"):
		if not tower.overlooks(bullet.origin):
			continue
		for unit: Node2D in node.get_tree().get_nodes_in_group("units"):
			if unit.dead or not tower.is_up_high(unit):
				continue
			var to: Vector2 = unit.global_position - bullet.global_position
			if to.dot(ahead) > 0.0 and absf(to.cross(ahead)) <= OVERLOOK_LINE_M * World.PX_PER_M:
				return true
	return false
