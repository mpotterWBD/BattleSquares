extends Node
## A square's death, as a ragdoll (added by soldier.gd _die()). Nothing is
## scripted: the killing shot shoves it, and physics does the rest.
##
##   skid    it's knocked off along the shot, `SHOVE_MPS` give or take, and
##           skids to a stop (slower on its feet, faster lying flat),
##           bouncing off anything solid in the way
##   spin    a hit off-centre spins it round as it goes, like a shove on a
##           corner; the spin dies away, quickest once it's flat
##   topple  it goes limp and tips over the edge of whichever face the shot
##           pushed it toward: front (shot from behind), back (from the
##           front) or a side. Gravity pulls it over faster and faster; it
##           slams down, bounces back up a little, maybe twice, and settles,
##           throwing dust each time it hits
##   rifle   let go, it flies free under gravity: dropped out to the side
##           when it falls on its front or side, flung out to the side and
##           spinning when it goes over backwards. It bounces and skids too.
##
## Then it lies there, darkening, and finally fades away and is removed.
## An anchored square (the dummy) only topples and spins: it doesn't skid.
##
## The toppling block is pre-rendered (blender/scripts/fall_square.py): one
## sheet row per fall direction (FALL_DIRS, all the way round, since the
## fixed sun lights each direction differently) and one column per tip step
## (FALL_FRAMES, standing to flat). Spinning just moves it along the rows, so
## the lighting stays right as it turns. The frames are centred where the
## square stood, so the block topples away from the centre.

const World = preload("res://scripts/world.gd")
const Rifle = preload("res://scripts/rifle.gd")
const HitDust = preload("res://scripts/hit_dust.gd")

const FALL_DIRS := 30          ## matches DIRS in fall_square.py
const FALL_FRAMES := 12        ## matches TIPS in fall_square.py
const SHADOW_SHEET := preload("res://assets/characters/square_fall_shadow_sheet.png")
const SHADOW_ALPHA := 0.71     ## as soldier.gd
const SIZE_M := 0.4            ## as soldier.gd

## The shove: how fast the killing shot sends it skidding (give or take
## SHOVE_SPREAD of that), and how quickly it slows.
const SHOVE_MPS := 2.2
const SHOVE_SPREAD := 0.25
const SKID_UPRIGHT_MPS2 := 4.0  ## still on its feet, going over
const SKID_FLAT_MPS2 := 10.0    ## lying flat, scraping along
const BUMP_KEEP := 0.4          ## keeps this much speed bouncing off something solid

## The spin: from a hit right at a corner (none for dead-centre), plus a
## little at random, dying away this fast (per second; twice as fast flat).
const SPIN_DPS := 360.0
const SPIN_RANDOM_DPS := 60.0
const SPIN_DAMP := 3.0

## The topple, as a block pivoting on its bottom edge.
const TIP_GRAVITY := 33.0       ## g over the pivot distance (rad/s²): how hard it's pulled over
const TIP_LEAN_DEG := 20.0      ## limp: falls as though already leaning this far over
const TIP_KICK_DPS := 70.0      ## the shot starts it tipping this fast (scaled with the shove)
const TIP_BOUNCE := 0.35        ## keeps this much of its speed bouncing back off the ground
const TIP_REST_DPS := 45.0      ## hitting the ground slower than this, it just settles
const THUMP_DUST_DPS := 150.0   ## a bounce harder than this throws dust too
const LAND_DUST_M := 0.2        ## dust bursts out from the edges it lands on
const SKID_DUST_MPS := 0.5      ## skidding flat faster than this kicks up dust...
const SKID_DUST_S := 0.09       ## ...a puff this often

const DARKEN_TO := Color(0.55, 0.55, 0.55)
const DARKEN_S := 1.5
const LIE_S := 5.0             ## after landing, before it fades
const FADE_S := 1.0

## The rifle, flying free. Speeds in metres per second.
const GUN_HELD_M := 0.22       ## its height when it's let go (rifle.gd HOLD_HEIGHT_M)
const GUN_DROP_MPS := 0.8      ## front or side: let go, out to the side
const GUN_DROP_SPIN_DPS := 90.0
const GUN_FLING_MPS := 1.3     ## backwards: flung out to the side...
const GUN_FLING_UP_MPS := 1.4  ## ...and up...
const GUN_FLING_SPIN_DPS := 540.0   ## ...spinning
const GUN_CARRY := 0.5         ## and it keeps this much of the body's skid
const GUN_GRAVITY := 9.8
const GUN_BOUNCE := 0.3        ## keeps this much of its fall speed bouncing up
const GUN_REST_MPS := 0.5      ## landing slower than this, it stays down
const GUN_SKID_MPS2 := 6.0
const GUN_SPIN_DAMP := 6.0     ## spin dies away this fast on the ground

var _square: CharacterBody2D
var _body: Sprite2D
var _shadow: Sprite2D
var _rifle: Node2D
var _rifle_shadow: Sprite2D
var _t := 0.0

var _fall_angle := 0.0         ## which way it topples (radians), turning with the spin
var _vel := Vector2.ZERO       ## skid (px per second)
var _spin := 0.0               ## radians per second, clockwise
var _tip := 0.0                ## 0 standing .. PI/2 flat
var _tip_vel := 0.0
var _landed := false
var _settled := false
var _skid_dust_in := 0.0

var _gun_pos := Vector2.ZERO   ## world px
var _gun_vel := Vector2.ZERO   ## m/s along the ground
var _gun_h := 0.0              ## height, m
var _gun_vh := 0.0             ## m/s, up
var _gun_turn := 0.0
var _gun_spin := 0.0
var _gun_down := false


## Called once, as the square dies, killed by a shot that struck `point`
## travelling along `direction`. `body_sheet` is its toppling sheet.
func setup(square: CharacterBody2D, body_sheet: Texture2D, point: Vector2, direction: Vector2) -> void:
	_square = square
	_body = square.get_node("Body")
	_shadow = square.get_node("Shadows/Shadow")
	_rifle = square.get_node("Rifle")
	_rifle_shadow = square.get_node("Shadows/RifleShadow")
	var px := World.PX_PER_M
	var facing: float = square.facing
	var ahead := Vector2.from_angle(facing)
	var right := ahead.rotated(PI / 2)

	# A block tips over an edge: toward whichever face the shot pushes
	# (0 front, 1 right, 2 back, 3 left).
	var face := posmod(roundi(angle_difference(facing, direction.angle()) / (PI / 2)), 4)
	_fall_angle = facing + face * PI / 2
	var shove := randf_range(1.0 - SHOVE_SPREAD, 1.0 + SHOVE_SPREAD)
	if not square.anchored:
		_vel = direction * SHOVE_MPS * shove * px
	var lever := clampf((point - square.global_position).cross(direction) / (SIZE_M / 2 * px), -1.0, 1.0)
	_spin = deg_to_rad(lever * SPIN_DPS + randf_range(-SPIN_RANDOM_DPS, SPIN_RANDOM_DPS))
	_tip_vel = deg_to_rad(TIP_KICK_DPS) * shove

	for sprite in [_body, _shadow]:
		sprite.hframes = FALL_FRAMES
		sprite.vframes = FALL_DIRS
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
	_body.texture = body_sheet
	_shadow.texture = SHADOW_SHEET
	(square.get_node("Shadows") as CanvasGroup).self_modulate.a = SHADOW_ALPHA
	_set_frame()

	# The rifle leaves the shoulder from wherever it was, away from the side
	# it falls on.
	_rifle.get_node("Gun").position = Vector2.ZERO   # no recoil left in it
	_rifle.get_node("Flash").visible = false
	_gun_pos = _rifle.global_position
	_gun_turn = _rifle.rotation
	_gun_h = GUN_HELD_M
	var side := -right if face == 1 else right
	if face == 2:
		_gun_vel = side * GUN_FLING_MPS * randf_range(0.8, 1.2)
		_gun_vh = GUN_FLING_UP_MPS * randf_range(0.8, 1.2)
		_gun_spin = deg_to_rad(GUN_FLING_SPIN_DPS) * randf_range(0.75, 1.25) * (1.0 if randf() < 0.5 else -1.0)
	else:
		_gun_vel = side * GUN_DROP_MPS * randf_range(0.7, 1.3)
		_gun_spin = deg_to_rad(randf_range(-GUN_DROP_SPIN_DPS, GUN_DROP_SPIN_DPS))
	_gun_vel += _vel / px * GUN_CARRY


func _physics_process(delta: float) -> void:
	_t += delta
	_topple(delta)
	_skid(delta)
	_set_frame()
	_update_gun(delta)


## Gravity pulls it over its edge; it bounces off the ground until it's
## hitting too softly to come back up.
func _topple(delta: float) -> void:
	if _settled:
		return
	_tip_vel += TIP_GRAVITY * sin(_tip + deg_to_rad(TIP_LEAN_DEG)) * delta
	_tip += _tip_vel * delta
	if _tip < PI / 2:
		return
	_tip = PI / 2
	var impact := _tip_vel
	if impact < deg_to_rad(TIP_REST_DPS):
		_settled = true
		_tip_vel = 0.0
		return
	_tip_vel = -impact * TIP_BOUNCE
	if not _landed:
		_landed = true
		_land()
	elif impact > deg_to_rad(THUMP_DUST_DPS):
		_dust(_lying_centre() + _fall_dir() * LAND_DUST_M * World.PX_PER_M, -_fall_dir(), 0.5)


## Slides (bouncing off anything solid) and spins, both slowing, faster flat.
func _skid(delta: float) -> void:
	var px := World.PX_PER_M
	var flat := _tip / (PI / 2)
	_vel = _vel.move_toward(Vector2.ZERO, lerpf(SKID_UPRIGHT_MPS2, SKID_FLAT_MPS2, flat) * px * delta)
	if _vel != Vector2.ZERO:
		var hit := _square.move_and_collide(_vel * delta)
		if hit:
			_vel = _vel.bounce(hit.get_normal()) * BUMP_KEEP
	_spin *= exp(-SPIN_DAMP * (1.0 + flat) * delta)
	_fall_angle += _spin * delta
	# Scraping along flat kicks up dust behind it.
	_skid_dust_in -= delta
	if _landed and _vel.length() > SKID_DUST_MPS * px and _skid_dust_in <= 0.0:
		_skid_dust_in = SKID_DUST_S
		var along := _vel.normalized()
		_dust(_lying_centre() - along * SIZE_M / 2 * px, along, 0.4)


func _fall_dir() -> Vector2:
	return Vector2.from_angle(_fall_angle)


## Where the block's middle is once it's down: half a square over.
func _lying_centre() -> Vector2:
	return _square.global_position + _fall_dir() * (_tip / (PI / 2)) * SIZE_M * World.PX_PER_M


func _set_frame() -> void:
	var row := posmod(roundi(_fall_angle / TAU * FALL_DIRS), FALL_DIRS)
	var column := roundi(clampf(_tip / (PI / 2), 0.0, 1.0) * (FALL_FRAMES - 1))
	_body.frame = row * FALL_FRAMES + column
	_shadow.frame = _body.frame


## Thump: dust bursts out from under the edges it lands on, then it darkens,
## lies there, fades and is removed.
func _land() -> void:
	var px := World.PX_PER_M
	var centre := _lying_centre()
	var side := _fall_dir().orthogonal()
	# HitDust sprays back against the direction it's given.
	for out in [_fall_dir(), side, -side]:
		_dust(centre + out * LAND_DUST_M * px, -out, 1.0)
	var after := create_tween()
	after.tween_property(_body, "modulate", DARKEN_TO, DARKEN_S)
	after.tween_interval(LIE_S - DARKEN_S)
	after.tween_property(_square, "modulate:a", 0.0, FADE_S)
	after.tween_callback(_square.queue_free)


## Into the level, not the square, so the dust stays where it was thrown up.
func _dust(point: Vector2, direction: Vector2, strength: float) -> void:
	var dust := HitDust.new()
	dust.setup(point, direction, strength)
	var level := get_tree().current_scene
	(level if level else _square.get_parent()).add_child(dust)


## The rifle flies under gravity, bounces, then skids and stops spinning.
## It's placed in the world, so it doesn't ride along with the body's skid.
func _update_gun(delta: float) -> void:
	var px := World.PX_PER_M
	if not _gun_down:
		_gun_vh -= GUN_GRAVITY * delta
		_gun_h += _gun_vh * delta
		if _gun_h <= 0.0:
			_gun_h = 0.0
			if -_gun_vh > GUN_REST_MPS:
				_gun_vh = -_gun_vh * GUN_BOUNCE
				_gun_vel *= 0.6
				_gun_spin *= 0.5
			else:
				_gun_vh = 0.0
				_gun_down = true
	else:
		_gun_vel = _gun_vel.move_toward(Vector2.ZERO, GUN_SKID_MPS2 * delta)
		_gun_spin *= exp(-GUN_SPIN_DAMP * delta)
	_gun_pos += _gun_vel * px * delta
	var half := 0.3 * px
	var area := World.ARENA.grow(-half)
	_gun_pos = _gun_pos.clamp(area.position, area.end)
	_gun_turn += _gun_spin * delta
	_rifle.global_position = _gun_pos
	_rifle.rotation = _gun_turn
	_rifle.scale = Vector2.ONE * (1.0 + _gun_h)
	_rifle_shadow.global_position = _gun_pos + World.SUN_DIR * _gun_h * tan(deg_to_rad(World.SUN_TILT_DEG)) * px
	_rifle_shadow.rotation = _gun_turn
	_rifle_shadow.scale = _rifle.scale * Rifle.SPRITE_SCALE
