extends Node2D
## A rifle tracer: a bright streak flying straight until it leaves the arena
## or runs out of time. There's nothing for it to hit yet.

const World = preload("res://scripts/world.gd")
const LIFETIME_S := 1.0
const COLOR := Color(1.0, 0.95, 0.7, 0.9)

var velocity := Vector2.ZERO

var _age := 0.0
var _travelled := 0.0


func setup(from: Vector2, angle: float, speed_mps: float) -> void:
	position = from
	rotation = angle
	velocity = Vector2.from_angle(angle) * speed_mps * World.PX_PER_M


func _physics_process(delta: float) -> void:
	var step := velocity * delta
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
