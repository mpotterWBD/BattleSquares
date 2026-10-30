extends Node2D
## A rifle tracer: a bright streak flying straight until it hits something
## solid, leaves the arena or runs out of time.
##
## Each tick it checks the whole stretch it's about to fly with a ray, so
## at 2 m a tick it can't skip through a 0.4 m square. It ignores whoever
## fired it. Anything solid stops it (squares, a landed helicopter's hull, a
## radio station, sandbags); a square also takes the hit (soldier.gd
## take_hit()), and cover with a bullet_hit() shows it (sandbags.gd).
## Cover with a lets_bullet_through() is asked once whether this shot goes
## over it (sandbags: always from inside its proximity box, sometimes from
## outside); if so the bullet flies on and never asks that one again.
## Bullets in flight are in the "bullets" group, so enemies can notice shots
## (scripts/enemy.gd): `origin` is where it was fired from.
##
## A shot that isn't the player's own, passing within the player's flyby
## circle (player.gd `flyby_radius_m`), whizzes past: a flyby sound
## (scripts/impact_sound.gd) at its closest point to the player, once.
##
## A badly aimed shot (rifle.gd ground_hit_chance_at()) is given a
## `ground_at_m`: if nothing stops it first, it goes into the ground that far
## from the muzzle and kicks up a small puff of dust (scripts/hit_dust.gd),
## with the thud of a round into the ground (scripts/impact_sound.gd):
## concrete on a road's asphalt (road.gd covers()), dirt anywhere else.

const World = preload("res://scripts/world.gd")
const HitDust = preload("res://scripts/hit_dust.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")
const LIFETIME_S := 1.0
const COLOR := Color(1.0, 0.95, 0.7, 0.9)

var velocity := Vector2.ZERO
var shooter: CollisionObject2D   ## never hit by its own shot
var damage := 0.0                ## health it takes off a square it hits
var origin := Vector2.ZERO       ## where it was fired from
var ground_at_m := INF           ## goes into the ground this far from the muzzle

var _age := 0.0
var _travelled := 0.0
var _passed: Array[RID] = []   ## cover this shot has gone over
var _whizzed := false          ## has played its flyby


func setup(from: Vector2, angle: float, speed_mps: float, shot_by: CollisionObject2D = null,
		hit_damage := 0.0) -> void:
	position = from
	origin = from
	rotation = angle
	add_to_group("bullets")
	velocity = Vector2.from_angle(angle) * speed_mps * World.PX_PER_M
	shooter = shot_by
	damage = hit_damage


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	var to_ground := ground_at_m * World.PX_PER_M - _travelled
	var lands := step.length() >= to_ground
	if lands:
		step = velocity.normalized() * maxf(to_ground, 0.0)
	var query := PhysicsRayQueryParameters2D.create(position, position + step)
	var hit := {}
	for i in 4:   # past up to a few walls it goes over this tick
		query.exclude = _passed + ([shooter.get_rid()] if is_instance_valid(shooter) else [])
		hit = get_world_2d().direct_space_state.intersect_ray(query)
		if hit and hit.collider.has_method("lets_bullet_through") and hit.collider.lets_bullet_through(self):
			_passed.append(hit.rid)
			hit = {}
			continue
		break
	if hit:
		if hit.collider.has_method("take_hit"):
			hit.collider.take_hit(hit.position, velocity.normalized(), damage,
					shooter if is_instance_valid(shooter) else null)
		elif hit.collider.has_method("bullet_hit"):   # cover that shows the hit (sandbags.gd)
			hit.collider.bullet_hit(hit.position, velocity.normalized())
		queue_free()
		return
	_check_flyby(step)
	position += step
	if lands:
		_hit_ground()
		return
	_travelled += step.length()
	_age += delta
	if _age > LIFETIME_S or not World.ARENA.grow(200).has_point(position):
		queue_free()
	queue_redraw()


## Passing within the player's flyby circle this tick (along `step`): the
## whizz, from the closest point of its path to the player.
func _check_flyby(step: Vector2) -> void:
	if _whizzed:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player == shooter:
		return
	var near := Geometry2D.get_closest_point_to_segment(player.global_position, position, position + step)
	if near.distance_to(player.global_position) <= player.flyby_radius_m * World.PX_PER_M:
		_whizzed = true
		ImpactSound.play(get_parent(), near, "flyby")


## Into the ground here: a puff of dust and a thud, and the bullet's gone.
func _hit_ground() -> void:
	var dust := HitDust.new()
	dust.setup(position, velocity.normalized(), HitDust.GROUND_STRENGTH, true)
	get_parent().add_child(dust)
	var on_road := get_tree().get_nodes_in_group("roads").any(func(road): return road.covers(position))
	ImpactSound.play(get_parent(), position, "concrete" if on_road else "dirt")
	queue_free()


func _draw() -> void:
	# The streak covers the distance flown in one tick, so it reads as a
	# continuous tracer however fast it goes. It never reaches behind the muzzle.
	var length := minf(velocity.length() / Engine.physics_ticks_per_second, _travelled)
	draw_line(Vector2(-length, 0), Vector2.ZERO, COLOR, 2.0)
