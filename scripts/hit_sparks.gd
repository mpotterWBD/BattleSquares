extends Node2D
## Sparks off a bullet striking metal (crate.gd bullet_hit() with `impact`
## "metal", e.g. the ammo cans): a bright flash at the hit point and a spray
## of short, fast streaks glancing back out the way the round came, fanned
## either side, slowing and fading in a fraction of a second, then gone.
## Sizes and speeds in metres.

const World = preload("res://scripts/world.gd")

const FLASH_S := 0.06
const FLASH_RADIUS_M := 0.05
const SPARKS := 9
const SPREAD_DEG := 70.0          ## either side of straight back at the shooter
const SPEED_MPS := Vector2(3.0, 7.0)
const LIFE_S := Vector2(0.08, 0.22)
const DRAG := 6.0                 ## how quickly they slow (per second)
const TRAIL_S := 0.025            ## each streak is as long as this much of its flight
const HOT := Color(1.0, 0.95, 0.75)
const COOL := Color(1.0, 0.55, 0.15)

var _t := 0.0
var _sparks: Array = []           ## [position, velocity, life] per spark (px, px/s, s)


## `point` is where the bullet struck (world); `direction` the way it was
## going (unit vector), so the sparks glance back out toward the shooter.
func setup(point: Vector2, direction: Vector2) -> void:
	position = point
	z_index = 5   # over the load it struck
	var px := World.PX_PER_M
	for i in SPARKS:
		var angle := (-direction).angle() + deg_to_rad(randf_range(-SPREAD_DEG, SPREAD_DEG))
		var speed := randf_range(SPEED_MPS.x, SPEED_MPS.y) * px
		_sparks.append([Vector2.ZERO, Vector2.from_angle(angle) * speed, randf_range(LIFE_S.x, LIFE_S.y)])


func _process(delta: float) -> void:
	_t += delta
	var alive := false
	for spark in _sparks:
		spark[1] *= exp(-DRAG * delta)
		spark[0] += spark[1] * delta
		alive = alive or _t < spark[2]
	if not alive:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var px := World.PX_PER_M
	if _t < FLASH_S:
		var k := 1.0 - _t / FLASH_S
		draw_circle(Vector2.ZERO, FLASH_RADIUS_M * px * (0.6 + 0.4 * k), Color(HOT, 0.9 * k))
	for spark in _sparks:
		var life: float = spark[2]
		if _t >= life:
			continue
		var k := _t / life
		var head: Vector2 = spark[0]
		var tail: Vector2 = head - spark[1] * TRAIL_S
		draw_line(tail, head, Color(HOT.lerp(COOL, k), 1.0 - k), 1.5, true)
