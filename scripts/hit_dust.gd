extends Node2D
## The puff of dust knocked off a square where a bullet hits it
## (soldier.gd take_hit()): a quick bright pop at the hit point, soft dust
## clouds that burst back out toward the shooter, spread and fade, and a few
## fast flecks of grit. It removes itself once everything has faded.
##
## Sizes and speeds are in metres; the clouds slow down quickly, like dust
## in air.

const World = preload("res://scripts/world.gd")

const DUST_COLOR := Color(0.80, 0.74, 0.62)
const GRIT_COLOR := Color(0.42, 0.37, 0.30)
const POP_S := 0.07               ## the bright pop at the moment of impact
const POP_RADIUS_M := 0.07
const PUFFS := 8
const PUFF_SPREAD_DEG := 65.0     ## either side of straight back at the shooter
const PUFF_SPEED_MPS := Vector2(1.2, 3.6)
const PUFF_RADIUS_M := Vector2(0.03, 0.07)   ## starting size; they swell as they go
const PUFF_GROW := 2.6            ## times their starting size by the time they fade
const PUFF_LIFE_S := Vector2(0.4, 0.8)
const PUFF_ALPHA := 0.75
const PUFF_DRAG := 7.0            ## how quickly they slow (per second)
const GRITS := 7
const GRIT_SPREAD_DEG := 80.0
const GRIT_SPEED_MPS := Vector2(4.0, 8.0)
const GRIT_LIFE_S := Vector2(0.15, 0.3)
const GRIT_DRAG := 4.0

var _age := 0.0
var _life := 0.0   ## when the last particle fades
var _puffs: Array[Dictionary] = []
var _grits: Array[Dictionary] = []
var _strength := 1.0


## `point` is where the bullet struck (world); `direction` the way it was
## travelling (unit vector), so the dust comes back out the way it came in.
## A `strength` under 1 is a lighter scuff (fewer, slower puffs and no pop),
## e.g. a body skidding (scripts/death_fall.gd).
func setup(point: Vector2, direction: Vector2, strength := 1.0) -> void:
	position = point
	_strength = strength
	z_index = 15   # over the squares
	var back := (-direction).angle()
	for i in maxi(1, roundi(PUFFS * strength)):
		var life := randf_range(PUFF_LIFE_S.x, PUFF_LIFE_S.y)
		_puffs.append({
			pos = Vector2.ZERO,
			vel = Vector2.from_angle(back + deg_to_rad(randf_range(-PUFF_SPREAD_DEG, PUFF_SPREAD_DEG)))
					* randf_range(PUFF_SPEED_MPS.x, PUFF_SPEED_MPS.y) * strength,
			radius = randf_range(PUFF_RADIUS_M.x, PUFF_RADIUS_M.y),
			life = life,
		})
		_life = maxf(_life, life)
	for i in roundi(GRITS * strength):
		var life := randf_range(GRIT_LIFE_S.x, GRIT_LIFE_S.y)
		_grits.append({
			pos = Vector2.ZERO,
			vel = Vector2.from_angle(back + deg_to_rad(randf_range(-GRIT_SPREAD_DEG, GRIT_SPREAD_DEG)))
					* randf_range(GRIT_SPEED_MPS.x, GRIT_SPEED_MPS.y),
			life = life,
		})
		_life = maxf(_life, life)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	for puff in _puffs:
		puff.vel *= exp(-PUFF_DRAG * delta)
		puff.pos += puff.vel * delta
	for grit in _grits:
		grit.vel *= exp(-GRIT_DRAG * delta)
		grit.pos += grit.vel * delta
	queue_redraw()


func _draw() -> void:
	var px := World.PX_PER_M
	for puff in _puffs:
		var t: float = _age / puff.life
		if t >= 1.0:
			continue
		var radius: float = puff.radius * lerpf(1.0, PUFF_GROW, 1.0 - pow(1.0 - t, 2.0))
		var fade := PUFF_ALPHA * (1.0 - t) * (1.0 - t)
		draw_circle(puff.pos * px, radius * px, Color(DUST_COLOR, fade), true, -1.0, true)
	for grit in _grits:
		var t: float = _age / grit.life
		if t >= 1.0:
			continue
		var tail: Vector2 = grit.vel * 0.012   # a short streak along its path
		draw_line((grit.pos - tail) * px, grit.pos * px, Color(GRIT_COLOR, 1.0 - t), 1.5, true)
	if _age < POP_S and _strength >= 1.0:
		var t := _age / POP_S
		draw_circle(Vector2.ZERO, POP_RADIUS_M * px * (0.6 + 0.8 * t),
				Color(1.0, 0.97, 0.88, 0.9 * (1.0 - t)), true, -1.0, true)
