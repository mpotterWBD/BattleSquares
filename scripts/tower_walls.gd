extends StaticBody2D
## A watch tower's railings and cabin walls (made by watch_tower.gd), on its
## own collision layer (watch_tower.gd WALL_LAYER): they keep the squares up
## on the tower from walking off the deck or through the cabin, and nothing
## on the ground touches them. Bullets pass: they don't know how high they
## fly, so one fired under the deck mustn't stop in a railing 3 m up. But a
## shot fired from up on the tower, at the cabin's height, stops in the
## cabin's walls (Mike, 2026-11-03: shooting through the shelter from the
## top): stops_bullet(). Its shapes are the tower's WALLS in order, the
## railings (RAILS) first.

## How many of its shapes are railings, the rest the cabin's walls (set by watch_tower.gd).
var rail_count := 0


func lets_bullet_through(_bullet: Node2D) -> bool:
	return true


## Whether a bullet reaching shape `shape` (its index) stops there: a cabin
## wall, fired by someone up on the tower at the cabin's height (bullet.gd).
func stops_bullet(bullet: Node2D, shape: int) -> bool:
	return _cabin_high(bullet.get("shooter"), shape)


## Nor do they hide anyone from sight (ai_soldier.gd _clear_view())...
func sees_through() -> bool:
	return true


## ...but the cabin's walls do from up on the tower at its height (`viewer`).
func blocks_sight(viewer: Node, shape: int) -> bool:
	return _cabin_high(viewer, shape)


## A shot stopped in the cabin's wall: sparks and a clang, as off the legs.
func bullet_hit(point: Vector2, direction: Vector2, damage := 0.0) -> void:
	get_parent().get_node("LegsBody").bullet_hit(point, direction, damage)


func _cabin_high(who: Node, shape: int) -> bool:
	return shape >= rail_count and get_parent().up_high(who)
