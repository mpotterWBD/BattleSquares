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
##           Once it's down it lies on the ground (GUN_DOWN_Z), drawn under
##           the squares walking over it.
##
## Then it lies there, darkening, and stays on the field, on the ground
## (BODY_DOWN_Z). Living squares walk over it and never push it: from the
## moment it dies it ignores every square (it only bounces off solid
## things as it skids), and once it's at rest it collides with nothing.
## Stepping over it lifts a square a little and slows it (soldier.gd, the
## "bodies" group, under_at()), like a low sandbag. `came_to_rest`
## fires once the body and rifle have both stopped moving; then, if the
## rifle still has rounds in its magazine (and it isn't the player's), a
## little circle round it marks it as ammo to pick up (ammo_pickup.gd).
## Off for the player (`drops_ammo`).
## An anchored square (the dummy) only topples and spins: it doesn't skid.
##
## Up a watch tower (Mike, 2026-11-03) it lies where it falls, on the deck or
## the stairs: as high as they are (drawn as big, its shadow on them) and over
## them, under the squares still up there. Toppling or skidding into a railing
## (watch_tower.gd wall_near()) it hits it with a clang; going outward faster
## than OVER_RAIL_MPS it goes over (_roll_over(): tipping over the top rail),
## drops under gravity (_drop(): smaller as it falls, its shadow out on the
## ground below), and lands with a thump and a bounce on the ground, or on
## the stair if that's what's under it. Slower, or at the cabin's wall, or
## where what's past the rail is higher (the deck, from the stairs), it's
## stopped there and slumps down against it. Its rifle comes down on whatever
## is under it too, and can slide off the deck's edge.
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
const AmmoPickup = preload("res://scripts/ammo_pickup.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")
const WatchTower = preload("res://scripts/watch_tower.gd")

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
const BODY_DOWN_Z := -3        ## once down, on the ground: under every living square, over its gun (GUN_DOWN_Z)
const BODY_REACH_M := 0.22     ## a square's centre this close to the body's middle is right on it...
const BODY_EDGE_M := 0.14      ## ...easing off to nothing this much further out

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
const GUN_DOWN_Z := -4         ## once down it's on the ground, under every square (as a dropped magazine, rifle.gd)
const GUN_HALF_M := 0.05       ## landing on a stair, kept this far in from its side rails

## Up a watch tower.
const GROW_PER_M := 0.08       ## as soldier.gd: drawn this much bigger a metre up
const OVER_RAIL_MPS := 0.9     ## meeting a railing going outward faster than this, it goes over
const CLANG_MPS := 0.3         ## meeting a railing or wall faster than this, it clangs
const OVER_S := 0.18           ## going over the rail takes this long...
const OVER_LIFT_M := 0.25      ## ...rising this much over the top...
const OVER_CLEAR_M := 0.3      ## ...its middle ending this far out past the rail
const OVER_OUT_MPS := 0.7      ## then it drops, drifting on outward this fast...
const FALL_GRAVITY := 29.4     ## three times real gravity (Mike, 2026-11-03: the fall faster, twice): 3 m in 0.45 s
const FALL_SPIN_DPS := 120.0   ## ...turning a little, up to this fast
const LAND_KEEP := 0.25        ## landing, it keeps this much of the drift as a skid
const LAND_BOUNCE_DPS := 120.0 ## and rocks back up off the ground, at most this fast
const LAND_BOUNCE_PER_MPS := 30.0   ## (this many degrees a second for each m/s it landed at)
const LAND_STEP_M := 0.15      ## coming down, it lands on the stair rising under it by up to this much a tick
const SHADOW_FADE_PER_M := 0.15     ## its shadow fades this much a metre it's above it...
const SHADOW_FADE_MIN := 0.3        ## ...to no fainter than this

## Fired once, when the body has settled and stopped skidding and the rifle is down.
signal came_to_rest

## Whether its rifle's magazine is left as ammo to pick up (not the player's own).
var drops_ammo := true

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
var _gun_floor := 0.0          ## the height of what's under the rifle (m)
var _gun_from := 0.0           ## the height it last left or landed on, for its lift (m)
var _at_rest := false

var _shadows: CanvasGroup
var _died_on: Node2D = null    ## the watch tower it died on (null: on the ground)
var _tower: Node2D = null      ## the one it's lying on now (null once it's gone over the side)
var _h := 0.0                  ## its height (m): the deck or stair it's on, or as it falls
var _floor := 0.0              ## the height of what's under it (m)
var _vh := 0.0                 ## m/s, up
var _phase := ""               ## "" toppling and lying; "over" a railing; "falling" off it
var _met_wall := false         ## it's met a railing or wall once (and gone over or not)
var _over_t := 0.0
var _over_from := Vector2.ZERO
var _over_to := Vector2.ZERO
var _over_tip := 0.0
var _over_angle := 0.0
var _over_out := Vector2.ZERO


## Called once, as the square dies, killed by a shot that struck `point`
## travelling along `direction`. `body_sheet` is its toppling sheet.
func setup(square: CharacterBody2D, body_sheet: Texture2D, point: Vector2, direction: Vector2) -> void:
	_square = square
	_body = square.get_node("Body")
	_shadow = square.get_node("Shadows/Shadow")
	_rifle = square.get_node("Rifle")
	if _rifle.has_method("abandon_reload"):
		_rifle.abandon_reload()
	_rifle_shadow = square.get_node("Shadows/RifleShadow")
	_shadows = square.get_node("Shadows")
	if is_instance_valid(square.tower):
		_died_on = square.tower
		_tower = square.tower
		_h = square.elevation_m
		_floor = _h
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
	# Squares walk over it: none of them pushes it, or is pushed by it.
	for unit in square.get_tree().get_nodes_in_group("units"):
		if unit is PhysicsBody2D and unit != square:
			square.add_collision_exception_with(unit)

	for sprite in [_body, _shadow]:
		sprite.hframes = FALL_FRAMES
		sprite.vframes = FALL_DIRS
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
	_body.texture = body_sheet
	_shadow.texture = SHADOW_SHEET
	_shadows.self_modulate.a = SHADOW_ALPHA
	_set_frame()
	_place_view()

	# The rifle leaves the shoulder from wherever it was, away from the side
	# it falls on.
	_rifle.get_node("Gun").position = Vector2.ZERO   # no recoil left in it
	_rifle.get_node("Flash").visible = false
	_gun_pos = _rifle.global_position
	_gun_turn = _rifle.rotation
	_gun_h = _h + GUN_HELD_M
	_gun_floor = _h
	_gun_from = _h
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
	if _phase == "over":
		_roll_over(delta)
	elif _phase == "falling":
		_drop(delta)
	else:
		_topple(delta)
		if _tower:
			_meet_walls()
		_skid(delta)
		if _tower and _phase == "":   # lying on the stair: as high as it is under its middle
			var under: float = _landing(_lying_centre(), _h, SIZE_M / 2)[1]
			if under > 0.0:   # (its railings keep it up here)
				_floor = under
				_h = under
	_set_frame()
	_place_view()
	_update_gun(delta)
	if not _at_rest and _phase == "" and _settled and _gun_down and _vel == Vector2.ZERO:
		_at_rest = true
		_square.collision_mask = 0   # lying there: nothing moves it now
		came_to_rest.emit()
		_offer_ammo()


## The magazine left in its rifle, for the player to pick up.
func _offer_ammo() -> void:
	if not drops_ammo or not _rifle.visible or _rifle.rounds <= 0:
		return
	var pickup := AmmoPickup.new()
	pickup.setup(_rifle, _died_on if _gun_floor > 0.0 else null)
	var level := get_tree().current_scene
	(level if level else _square.get_parent()).add_child(pickup)


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
		if not _landed:   # went over gently enough to settle on first touch
			_landed = true
			_land()
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
			# Up a tower, into a railing: maybe over it.
			var touch: Dictionary = _tower.wall_near(hit.get_position(), 0.1, _square.global_position) if _tower else {}
			if not touch.is_empty() and _meet(touch, -_vel.dot(hit.get_normal()) / px):
				return
			_vel = _vel.bounce(hit.get_normal()) * BUMP_KEEP
	_spin *= exp(-SPIN_DAMP * (1.0 + flat) * delta)
	_fall_angle += _spin * delta
	# Scraping along flat kicks up dust behind it.
	_skid_dust_in -= delta
	if _landed and _vel.length() > SKID_DUST_MPS * px and _skid_dust_in <= 0.0:
		_skid_dust_in = SKID_DUST_S
		var along := _vel.normalized()
		_dust(_lying_centre() - along * SIZE_M / 2 * px, along, 0.4)


## Up a tower: the body meeting a railing or the cabin's wall as it topples or
## skids toward it (watch_tower.gd wall_near()). Over it (_meet()), or stopped
## by it: kept clear of it, it slides down against it and stays up here.
func _meet_walls() -> void:
	var px := World.PX_PER_M
	var touch: Dictionary = _tower.wall_near(_lying_centre(), SIZE_M / 2, _square.global_position)
	if touch.is_empty():
		return
	var out: Vector2 = touch.out
	var tipping := _tip_vel * SIZE_M / (PI / 2) * _fall_dir().dot(out) if _tip < PI / 2 else 0.0
	var toward := _vel.dot(out) / px + tipping
	if toward <= 0.0 or _meet(touch, toward):
		return
	_square.global_position -= out * maxf(SIZE_M / 2 - touch.distance_m, 0.0) * px
	_vel -= out * maxf(_vel.dot(out), 0.0)


## The first railing or wall it meets, going `toward` m/s outward: a clang,
## and over it if that's a railing, it's going fast enough, and what's past
## it isn't higher (from the stairs toward the deck). True if it goes over.
func _meet(touch: Dictionary, toward: float) -> bool:
	if _met_wall:
		return false
	_met_wall = true
	if toward > CLANG_MPS:
		ImpactSound.play(_level(), touch.point, "clang")
	if not touch.rail or toward < OVER_RAIL_MPS:
		return false
	var beyond: Array = _tower.landing(touch.point + touch.out * OVER_CLEAR_M * World.PX_PER_M)
	if not beyond.is_empty() and beyond[1] > _h + 0.05:
		return false
	_phase = "over"
	_over_t = 0.0
	_over_from = _square.global_position
	# Flat, its middle lies a square past where it stands: that ends OVER_CLEAR_M past the rail.
	_over_to = touch.point + touch.out * (OVER_CLEAR_M - SIZE_M) * World.PX_PER_M
	_over_tip = _tip
	_over_angle = _fall_angle
	_over_out = touch.out
	_vel = Vector2.ZERO
	_tip_vel = 0.0
	_square.collision_mask = 0   # over the rail and down, through nothing
	return true


## Going over the railing: it tips on over the top rail, turning to go over
## it square on, then drops (_drop()).
func _roll_over(delta: float) -> void:
	_over_t += delta
	var k := minf(_over_t / OVER_S, 1.0)
	var eased := smoothstep(0.0, 1.0, k)
	_square.global_position = _over_from.lerp(_over_to, eased)
	_tip = lerpf(_over_tip, PI / 2, eased)
	_fall_angle = lerp_angle(_over_angle, _over_out.angle(), eased)
	_h = _floor + OVER_LIFT_M * sin(PI * k)
	if k < 1.0:
		return
	_phase = "falling"
	_vh = 0.0
	_vel = _over_out * OVER_OUT_MPS * World.PX_PER_M
	_spin = deg_to_rad(randf_range(-FALL_SPIN_DPS, FALL_SPIN_DPS))


## Dropping off the tower under gravity, until it lands on what's under it:
## the ground, or a lower part of the tower (the stair, over the deck's
## railing), where it's pulled in between the stair's rails. It lands with a
## thump and dust, rocks back up a little, and skids a short way.
func _drop(delta: float) -> void:
	var was := _h   # (what's under it is judged from where it was: it may be past the stair's slope by now)
	_vh -= FALL_GRAVITY * delta
	_h += _vh * delta
	_square.global_position += _vel * delta
	_fall_angle += _spin * delta
	var below := _landing(_lying_centre(), was, SIZE_M / 2)
	_floor = below[1]
	if _h > _floor:
		return
	_h = _floor
	_square.global_position += below[0] - _lying_centre()
	var impact := -_vh
	_vh = 0.0
	_phase = ""
	_vel *= LAND_KEEP
	_tip = PI / 2
	_tip_vel = -deg_to_rad(minf(LAND_BOUNCE_DPS, impact * LAND_BOUNCE_PER_MPS))
	_settled = false
	if _floor > 0.0:
		# On the stair, wedged between its rails: no rocking back up, which would
		# swing it back over the deck's railing it came over.
		_tip_vel = 0.0
		_settled = true
		_square.collision_mask = WatchTower.WALL_LAYER
	else:
		_tower = null
		_square.tower = null
		_square.collision_mask = _square._ground_mask
	_landed = true
	_land()
	ImpactSound.play(_level(), _lying_centre(), "clang" if _tower else "dirt")


## What something coming down at world `at` from `from_m` up lands on:
## [world point, height (m)]: the tower it died on where it's over a part no
## higher, or only LAND_STEP_M higher (the stair rising under it), pulled
## `half_m` in from a stair's side rails; else the ground (under the deck too).
func _landing(at: Vector2, from_m: float, half_m: float) -> Array:
	if is_instance_valid(_died_on):
		var on: Array = _died_on.landing(at, half_m)
		if not on.is_empty() and on[1] <= from_m + LAND_STEP_M:
			return on
	return [at, 0.0]


## Drawn bigger the higher it is (as soldier.gd view_scale()), its shadow on
## whatever's under it: further off the higher it is above it (out on the
## ground below as it drops), and fainter.
func _place_view() -> void:
	var above := _h - _floor
	_body.scale = Vector2.ONE * (1.0 + _h * GROW_PER_M)
	_shadow.scale = Vector2.ONE * (1.0 + _floor * GROW_PER_M)
	_shadow.position = World.SUN_DIR * above * tan(deg_to_rad(World.SUN_TILT_DEG)) * World.PX_PER_M
	_shadows.self_modulate.a = SHADOW_ALPHA * clampf(1.0 - above * SHADOW_FADE_PER_M, SHADOW_FADE_MIN, 1.0)


func _level() -> Node:
	var level := get_tree().current_scene
	return level if level else _square.get_parent()


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


## Thump: dust bursts out from under the edges it lands on, then it darkens
## and lies there, on the ground under the living. Up a tower it lies over the
## deck and stairs with the squares up there (UNIT_Z), moved first in the
## level so they're all drawn over it.
func _land() -> void:
	if _tower:
		_square.z_index = WatchTower.UNIT_Z
		_square.get_parent().move_child(_square, 0)
	else:
		_square.z_index = BODY_DOWN_Z
	add_to_group("bodies")
	var px := World.PX_PER_M
	var centre := _lying_centre()
	var side := _fall_dir().orthogonal()
	# HitDust sprays back against the direction it's given.
	for out in [_fall_dir(), side, -side]:
		_dust(centre + out * LAND_DUST_M * px, -out, 1.0)
	create_tween().tween_property(_body, "modulate", DARKEN_TO, DARKEN_S)


## How much a square at `point` (world) is on top of the body: 1 right on
## it, easing to 0 off its edge.
func under_at(point: Vector2) -> float:
	if _floor > 0.0:   # up a tower: nobody on the ground steps over it
		return 0.0
	var px := World.PX_PER_M
	var d := point.distance_to(_lying_centre()) / px
	return 1.0 - smoothstep(BODY_REACH_M, BODY_REACH_M + BODY_EDGE_M, d)


## Into the level, not the square, so the dust stays where it was thrown up.
func _dust(point: Vector2, direction: Vector2, strength: float) -> void:
	var dust := HitDust.new()
	dust.setup(point, direction, strength)
	var level := get_tree().current_scene
	(level if level else _square.get_parent()).add_child(dust)


## The rifle flies under gravity, bounces, then skids and stops spinning.
## It's placed in the world, so it doesn't ride along with the body's skid.
## Up a tower it comes down on the deck or stair under it, or past their edge
## to the ground (the railings don't stop it); skidding off the deck's edge,
## it falls again.
func _update_gun(delta: float) -> void:
	var px := World.PX_PER_M
	var below := _landing(_gun_pos, _gun_h, GUN_HALF_M)
	_gun_floor = below[1]
	if _gun_down and _gun_h > _gun_floor + LAND_STEP_M:   # slid off the edge
		_gun_down = false
		_rifle.z_as_relative = true
		_rifle.z_index = 0
		_rifle_shadow.visible = true
	elif _gun_down:   # (on a stair, up or down its slope)
		_gun_h = _gun_floor
	if not _gun_down:
		_gun_vh -= GUN_GRAVITY * delta
		_gun_h += _gun_vh * delta
		if _gun_h <= _gun_floor:
			_gun_h = _gun_floor
			_gun_from = _gun_floor
			if -_gun_vh > GUN_REST_MPS:
				_gun_vh = -_gun_vh * GUN_BOUNCE
				_gun_vel *= 0.6
				_gun_spin *= 0.5
			else:
				_gun_vh = 0.0
				_gun_down = true
				_gun_pos = below[0]   # (between a stair's side rails)
				# Lying on the ground: under the squares, and flat, so no shadow
				# of its own (it would be drawn over it). Up a tower, over its
				# deck and stairs with the squares up there, under its body.
				_rifle.z_as_relative = false
				_rifle.z_index = WatchTower.UNIT_Z if _gun_floor > 0.0 else GUN_DOWN_Z
				_rifle_shadow.visible = false
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
	# Lifted toward the camera a little above where it left or last landed
	# (dropping off the tower that's nothing), and bigger the higher it is.
	_rifle.scale = Vector2.ONE * (1.0 + maxf(_gun_h - _gun_from, 0.0)) * (1.0 + _gun_h * GROW_PER_M)
	_rifle_shadow.global_position = _gun_pos + World.SUN_DIR * (_gun_h - _gun_floor) * tan(deg_to_rad(World.SUN_TILT_DEG)) * px
	_rifle_shadow.rotation = _gun_turn
	_rifle_shadow.scale = _rifle.scale * Rifle.SPRITE_SCALE
