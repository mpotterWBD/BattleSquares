extends StaticBody2D
## Something solid to walk into that only sometimes stops a bullet: the
## radio station's desk and dish (scenes/radio_station.tscn). `hit_chance` of
## the shots that reach it strike it; the rest go past it, `over_chance` of
## those over the top (drawn over it, bullet.gd go_over()) and the others
## under or through (drawn under it): the desk 30% hit, the rest half over,
## half under; the dish 60% hit, the rest over.
##
## Like the sandbags (sandbags.gd), a bullet asks it once, on reaching it,
## whether it goes through (lets_bullet_through(), bullet.gd); one that
## doesn't stops in it (bullet_hit()) with the `impact` sound
## (scripts/impact_sound.gd) and, for "metal", sparks (scripts/hit_sparks.gd),
## or else a puff of dust. With `see_through` (the desk), sight lines see
## past it, so it doesn't hide anyone (sees_through(), ai_soldier.gd
## _clear_view()); without it (the dish), it hides whoever's behind it.

const HitDust = preload("res://scripts/hit_dust.gd")
const HitSparks = preload("res://scripts/hit_sparks.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")
const Cover = preload("res://scripts/cover.gd")

## The chance a bullet reaching it hits it (0.3 = 30%); the rest go through.
@export_range(0.0, 1.0, 0.01) var hit_chance := 0.3
## Of the shots that get past it, the share that go over the top (drawn over
## it); the rest go under or through it (drawn under it).
@export_range(0.0, 1.0, 0.01) var over_chance := 0.5
## What a hit sounds like (an impact_sound.gd kind); "metal" also throws sparks.
@export var impact := "metal"
## Whether sight lines see past it (a desk: yes).
@export var see_through := true


## Asked by a bullet (bullet.gd) once, when it reaches this: whether it goes
## past; if so, over the top (`over_chance`) or under.
func lets_bullet_through(bullet: Node2D) -> bool:
	if randf() < hit_chance:
		return false
	if randf() < over_chance:
		if bullet.has_method("go_over"):
			bullet.go_over()
	elif bullet.has_method("go_under"):
		bullet.go_under()
	return true


## A bullet stopped in it (bullet.gd): sparks (or dust) and the impact sound.
func bullet_hit(point: Vector2, direction: Vector2, _damage := 0.0) -> void:
	var level: Node = get_tree().current_scene
	if level == null:
		level = get_parent()
	if impact == "metal":
		var sparks := HitSparks.new()
		sparks.setup(point, direction)
		level.add_child(sparks)
	else:
		var dust := HitDust.new()
		dust.setup(point, direction)
		level.add_child(dust)
	if impact != "":
		ImpactSound.play(level, point, impact)


## Whether sight lines see past it (`see_through`).
func sees_through() -> bool:
	return see_through


## The share of shots reaching it that it stops (`hit_chance`), for its
## cover class (scripts/cover.gd): the desk 30%, class 1; the dish 60%, class 2.
func cover_stop_chance() -> float:
	return hit_chance


func cover_class() -> int:
	return Cover.class_of(self)
