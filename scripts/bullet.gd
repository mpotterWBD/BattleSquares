extends Node2D
## A rifle tracer: a bright streak flying straight until it hits something
## solid, leaves the arena or runs out of time.
##
## Each tick it checks the whole stretch it's about to fly with a ray, so
## at 2 m a tick it can't skip through a 0.4 m square. It ignores whoever
## fired it. Anything solid stops it (squares, a landed helicopter's hull, a
## radio station); a square also takes the hit (soldier.gd take_hit()).
## Bullets in flight are in the "bullets" group, so enemies can notice shots
## (scripts/enemy.gd): `origin` is where it was fired from.

const World = preload("res://scripts/world.gd")
const LIFETIME_S := 1.0
const COLOR := Color(1.0, 0.95, 0.7, 0.9)

var velocity := Vector2.ZERO
var shooter: CollisionObject2D   ## never hit by its own shot
var damage := 0.0                ## health it takes off a square it hits
var origin := Vector2.ZERO       ## where it was fired from

var _age := 0.0
var _travelled := 0.0


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
	var query := PhysicsRayQueryParameters2D.create(position, position + step)
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		if hit.collider.has_method("take_hit"):
			hit.collider.take_hit(hit.position, velocity.normalized(), damage,
					shooter if is_instance_valid(shooter) else null)
		queue_free()
		return
	position += step
	_travelled += step.length()
	_age += delta
	if _age > LIFETIME_S or not World.ARENA.grow(200).has_point(position):
		queue_free()
	queue_redraw()


func _draw() -> void:
	# The streak covers the distance flown in one tick, so it reads as a
	# continuous tracer however fast it goes. It never reaches behind the muzzle.
	var length := minf(velocity.length() / Engine.physics_ticks_per_second, _travelled)
	draw_line(Vector2(-length, 0), Vector2.ZERO, COLOR, 2.0)
