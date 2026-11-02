extends StaticBody2D
## A watch tower's railings and cabin walls (made by watch_tower.gd), on its
## own collision layer (watch_tower.gd WALL_LAYER): they keep the squares up
## on the tower from walking off the deck or through the cabin, and nothing
## on the ground touches them. Bullets pass: they don't know how high they
## fly, so one fired under the deck mustn't stop in a railing 3 m up.


func lets_bullet_through(_bullet: Node2D) -> bool:
	return true


## Nor do they hide anyone from sight (ai_soldier.gd _clear_view()).
func sees_through() -> bool:
	return true
