extends CharacterBody2D
## A square soldier: the body every square shares, whoever controls it.
##
## It walks in whatever direction it's told, independent of where it faces,
## so it can strafe and back up. The body turns toward the point it's aiming
## at, but loosely, like a person: it only swings quickly once the aim is
## more than `comfort_deg` off its nose, and otherwise eases round to face
## the target squarely. Its front face is its line of sight, marked by the
## see-through "Sight" triangle just in front of it, painted on the ground
## (z_index -1 in scenes/soldier.tscn): under the shadows, the rifle and
## every square, so the rifle reads as held over it.
##
## While walking it hops. Lifting off the ground moves it toward the overhead
## camera, so it grows slightly, and its shadow slides away in the direction
## the sunlight travels and fades a little.
##
## It carries a rifle (scripts/rifle.gd) on its right shoulder that follows
## the aim point within a sweep either side of the front, covering the gap
## while the body catches up.
##
## `kit` adds gear: "radio" puts a radio pack with a whip antenna on its back
## (scripts/radio_pack.gd), for radio operators.
##
## A bullet that hits it (scripts/bullet.gd) calls take_hit(): it's shoved
## back hard along the shot, `hit_knockback_m` in `hit_knockback_s`, twists
## up to `hit_twist_deg` if the hit lands off-centre, and dust bursts off
## the spot it was hit (scripts/hit_dust.gd). An `anchored` square (the
## crash test dummy) stays put instead: the shove and twist play out as a
## springy wobble of its sprites that settles back where it stands.
##
## Each hit takes the bullet's damage off `health` (out of `max_health`).
## At 0 it dies: it stops blocking bullets and squares and leaves every
## group (so it's out of the squad and can't be targeted), then goes down as
## a ragdoll (scripts/death_fall.gd, using `fall_sheet`): the killing shot
## sends it skidding and spinning, it topples over whichever face was
## pushed, bounces and settles, and its rifle flies free. It lies there and
## fades away. Every square is in the "units"
## group while alive, which is what Fire orders pick targets from.
##
## Subclasses decide what it does by overriding:
##   _move_intent()     which way to walk (length 0..1 = fraction of full speed)
##   _aim_point()       the world point to look and aim at
##   _wants_to_fire()   whether to pull the trigger this tick
##   _shot_spread_deg() how far a shot may stray either side of the aim
## scripts/player.gd reads the keyboard and mouse; scripts/squadmate.gd is AI.
##
## Sizes and speeds are in metres, so they stay right if the zoom changes.

const World = preload("res://scripts/world.gd")
const RadioPack = preload("res://scripts/radio_pack.gd")
const HitDust = preload("res://scripts/hit_dust.gd")
const DeathFall = preload("res://scripts/death_fall.gd")

signal died

const SIZE_M := 0.4   ## matches SIZE_M in blender/scripts/character_square.py
## The body and shadow sheets hold this many angles across 90 degrees (the
## square looks the same every quarter turn). Matches FRAMES in
## character_square.py. Frames are pre-lit, so the sprites themselves
## never rotate: turning just picks a frame.
const TURN_FRAMES := 30
## Darkness of a shadow on open ground (printed by character_square.py). The
## body and rifle shadows are drawn fully dark inside the "Shadows" group and
## the group as a whole is faded to this, so where they overlap the ground
## isn't darkened twice.
const SHADOW_ALPHA := 0.71
const SIGHT_GAP_M := 0.05      ## space between the front face and the triangle
const SIGHT_DEPTH_M := 0.16    ## how far the triangle points out

@export var speed_mps := 1.6          ## walking speed, metres per second
@export var acceleration_mps2 := 10.0
@export var friction_mps2 := 9.0
@export var hop_height_m := 0.06
@export var hop_length_m := 0.45      ## ground covered per hop
@export var turn_speed_dps := 540.0   ## how fast it swings once the aim leaves the comfort zone
@export var comfort_deg := 15.0       ## aim can be this far off the nose before it swings
@export var settle_speed_dps := 60.0  ## how fast it eases round to face the aim squarely
## Extra gear: "" (none) or "radio" (radio pack). Set before it enters the tree.
@export var kit := ""
## How far a bullet hit shoves it back, and how quickly: a short, sharp
## jolt rather than a slide.
@export var hit_knockback_m := 0.3
@export var hit_knockback_s := 0.12
## Most it twists when hit right at a corner (none for a dead-centre hit).
@export var hit_twist_deg := 20.0
## Stays where it stands when hit: it only rocks (see `jostle_m`) and turns
## back to its own facing. For fixed things like the crash test dummy.
@export var anchored := false
## When anchored: how far a hit rocks it, how many rocks a second, and how
## quickly they die out (0 = never, 1 = no bounce at all).
@export var jostle_m := 0.1
@export var jostle_hz := 7.0
@export_range(0.0, 1.0) var jostle_damping := 0.3
@export var max_health := 2.0   ## 2 for testing (a 25-damage rifle hit kills outright); was 100
## Takes hits (shove, dust) but never loses health, so it can't die.
@export var invincible := false
## The block toppling over when it dies, in every direction
## (blender/scripts/fall_square.py). The dummy has its own.
@export var fall_sheet: Texture2D = preload("res://assets/characters/red_square_fall_sheet.png")

## Which way the front face points, in radians: 0 = right, -PI/2 = up.
var facing := -PI / 2
var health := 0.0      ## set to max_health on entering the tree
var dead := false
## Whoever fired the last bullet that hit it (null if unknown).
var last_hit_by: Node2D = null

## Multiplies walking speed; subclasses raise it to jog (e.g. catching up).
var _speed_scale := 1.0

var _hop_phase := 0.0
var _height_m := 0.0
var _knock := Vector2.ZERO        ## knockback still to play out (px per second)
var _knock_decel := 0.0           ## how fast it dies away (px per second squared)
var _jostle := Vector2.ZERO       ## anchored: the sprites' offset from home (px)
var _jostle_vel := Vector2.ZERO
var _jostle_turn := 0.0           ## anchored: extra turn shown (radians)
var _jostle_turn_vel := 0.0

@onready var _body: Sprite2D = $Body
@onready var _shadows: CanvasGroup = $Shadows
@onready var _shadow: Sprite2D = $Shadows/Shadow
@onready var _sight: Polygon2D = $Sight
@onready var _rifle = $Rifle
var _radio_pack: Node2D


func _ready() -> void:
	health = max_health
	add_to_group("units")
	var px := World.PX_PER_M
	($CollisionShape2D.shape as RectangleShape2D).size = Vector2.ONE * SIZE_M * px
	# Triangle drawn facing right (rotation 0): its base runs the full width
	# of the front face, just in front of it, and its tip points forward.
	var base_x := (SIZE_M / 2 + SIGHT_GAP_M) * px
	var half_w := SIZE_M / 2 * px
	_sight.polygon = PackedVector2Array([
		Vector2(base_x, -half_w),
		Vector2(base_x + SIGHT_DEPTH_M * px, 0),
		Vector2(base_x, half_w),
	])
	if kit == "radio":
		_radio_pack = RadioPack.new()
		add_child(_radio_pack)   # after Body, so it's drawn over it
		_radio_pack.setup(_shadows)


func _physics_process(delta: float) -> void:
	var intent := Vector2.ZERO if dead else _move_intent().limit_length(1.0)
	var px := World.PX_PER_M
	if intent != Vector2.ZERO:
		velocity = velocity.move_toward(intent * speed_mps * _speed_scale * px,
				acceleration_mps2 * px * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction_mps2 * px * delta)
	move_and_slide()
	# Knockback moves it on top of walking, but isn't walking: no hops.
	if _knock != Vector2.ZERO:
		var was := _knock
		_knock = _knock.move_toward(Vector2.ZERO, _knock_decel * delta)
		move_and_collide((was + _knock) / 2.0 * delta)   # average speed over the tick: exact distance
	_stay_in_arena()
	_update_jostle(delta)
	if dead:   # no more looking round or shooting; death_fall.gd draws it now
		return
	var target := _aim_point()
	_turn_toward(target, delta)
	_update_hop(delta)
	_update_visuals()
	_rifle.update_aim(facing, _height_m, target, delta)
	if _wants_to_fire():
		_rifle.fire(_shot_spread_deg())


## Which way to walk this tick. Length 0..1 is the fraction of full speed.
func _move_intent() -> Vector2:
	return Vector2.ZERO


## The world point to look and aim at. By default, straight ahead.
func _aim_point() -> Vector2:
	return global_position + Vector2.from_angle(facing) * 10.0 * World.PX_PER_M


## Whether to fire this tick.
func _wants_to_fire() -> bool:
	return false


## How far either side of the aim a shot may stray. The player's are dead on.
func _shot_spread_deg() -> float:
	return 0.0


## Hit by a bullet at world `point` (on this square's edge), travelling
## along `direction` (a unit vector), taking `damage` off its health.
## `by` is whoever fired it, if known (kept in `last_hit_by`).
func take_hit(point: Vector2, direction: Vector2, damage := 0.0, by: Node2D = null) -> void:
	if dead:
		return
	if by != null:
		last_hit_by = by
	var px := World.PX_PER_M
	# A hit off to one side spins it that way, like a shove on a corner:
	# the turning effect (cross product) of the push about its centre, from
	# -1 to 1 across its width. Positive is clockwise on screen.
	var lever := (point - global_position).cross(direction) / (SIZE_M / 2 * px)
	var twist := clampf(lever, -1.0, 1.0) * deg_to_rad(hit_twist_deg)
	if anchored:
		# Kick the spring hard enough that, from rest, its first swing
		# reaches jostle_m (and the full twist) before it rocks back.
		var kick := 1.0 / _spring_first_peak()
		_jostle_vel += direction * jostle_m * kick * px
		_jostle_turn_vel += twist * kick
	else:
		# Slows evenly to a stop: covers hit_knockback_m in hit_knockback_s.
		var speed := 2.0 * hit_knockback_m / hit_knockback_s * px
		_knock = direction * speed
		_knock_decel = speed / hit_knockback_s
		facing = wrapf(facing + twist, -PI, PI)
	# Into the level, not this square, so the dust stays where it was knocked off.
	var dust := HitDust.new()
	dust.setup(point, direction)
	var level := get_tree().current_scene
	(level if level else get_parent()).add_child(dust)
	if invincible:
		return
	health -= damage
	if health <= 0.0:
		_die(point, direction)


## Out of health, killed by a shot that struck `point` travelling along
## `direction`. Leaves every group at once so nothing orders, follows or
## targets it, and goes off the collision layers so bullets and squares pass
## over it (it still bumps into solid things as it skids). Then death_fall.gd
## takes over as a ragdoll, shoved by the shot, so the hit's own knockback
## is dropped.
func _die(point: Vector2, direction: Vector2) -> void:
	dead = true
	died.emit()
	for group in get_groups():
		remove_from_group(group)
	set_deferred("collision_layer", 0)
	velocity = Vector2.ZERO
	_knock = Vector2.ZERO
	_sight.visible = false
	if _radio_pack:
		_radio_pack.drop()
	var fall := DeathFall.new()
	add_child(fall)
	fall.setup(self, fall_sheet, point, direction)


## Anchored squares: a damped spring pulls the sprites' offset and extra
## turn back to nothing, overshooting a little so it rocks before settling.
## Stepped with the spring's exact solution, so it swings as far as asked
## at any frame rate (simple stepping loses most of the swing this stiff).
func _update_jostle(delta: float) -> void:
	if _jostle == Vector2.ZERO and _jostle_vel == Vector2.ZERO and _jostle_turn_vel == 0.0 and _jostle_turn == 0.0:
		return
	var step := _spring_step(delta)   # [x from x, x from v, v from x, v from v]
	var x := _jostle
	_jostle = x * step[0] + _jostle_vel * step[1]
	_jostle_vel = x * step[2] + _jostle_vel * step[3]
	var turn := _jostle_turn
	_jostle_turn = turn * step[0] + _jostle_turn_vel * step[1]
	_jostle_turn_vel = turn * step[2] + _jostle_turn_vel * step[3]
	if _jostle.length() < 0.05 and _jostle_vel.length() < 1.0 and absf(_jostle_turn) < 0.001 and absf(_jostle_turn_vel) < 0.01:
		_jostle = Vector2.ZERO   # settled
		_jostle_vel = Vector2.ZERO
		_jostle_turn = 0.0
		_jostle_turn_vel = 0.0


## How the jostle spring's offset x and speed v change over `dt`, as
## [x from x, x from v, v from x, v from v] (an underdamped spring).
func _spring_step(dt: float) -> Array[float]:
	var omega := TAU * jostle_hz
	var zeta := clampf(jostle_damping, 0.0, 0.99)
	var wd := omega * sqrt(1.0 - zeta * zeta)   # how fast it actually rocks
	var decay := exp(-zeta * omega * dt)
	var c := cos(wd * dt)
	var s := sin(wd * dt) / wd
	return [decay * (c + zeta * omega * s), decay * s,
			-decay * omega * omega * s, decay * (c - zeta * omega * s)]


## How far the spring's first swing reaches when kicked from rest at a
## speed of 1, so a kick can be sized to swing a set distance.
func _spring_first_peak() -> float:
	var omega := TAU * jostle_hz
	var zeta := clampf(jostle_damping, 0.0, 0.99)
	var wd := omega * sqrt(1.0 - zeta * zeta)
	var t := atan2(wd, zeta * omega) / wd   # when it stops and turns back
	return exp(-zeta * omega * t) * sin(wd * t) / wd


## Turn the body toward `target` like a person tracking with a rifle: a
## quick swing to bring the aim back within `comfort_deg` of the nose, then
## a slow settle to face it squarely.
func _turn_toward(target: Vector2, delta: float) -> void:
	var to_target := target - global_position
	if to_target.length() < SIZE_M * World.PX_PER_M:
		return   # target on top of the square: no clear direction
	var wanted := to_target.angle()
	var off := angle_difference(facing, wanted)
	var comfort := deg_to_rad(comfort_deg)
	if absf(off) > comfort:
		var edge := wanted - signf(off) * comfort
		facing = rotate_toward(facing, edge, deg_to_rad(turn_speed_dps) * delta)
	# Always settle too, so it can't hover right on the comfort edge.
	facing = rotate_toward(facing, wanted, deg_to_rad(settle_speed_dps) * delta)
	facing = wrapf(facing, -PI, PI)


func _update_hop(delta: float) -> void:
	var moved_m := velocity.length() * delta / World.PX_PER_M
	if moved_m > 0.0003:
		# One hop per hop_length_m travelled, so the feet never "skate".
		_hop_phase += moved_m / hop_length_m * PI
		_height_m = hop_height_m * absf(sin(_hop_phase))
	else:
		_height_m = move_toward(_height_m, 0.0, delta * 0.6)
		if is_zero_approx(_height_m):
			_hop_phase = 0.0


func _update_visuals() -> void:
	_body.scale = Vector2.ONE * (1.0 + _height_m)
	_shadow.position = (World.SUN_DIR * _height_m * tan(deg_to_rad(World.SUN_TILT_DEG))
			* World.PX_PER_M)
	_shadows.self_modulate.a = SHADOW_ALPHA * (1.0 - _height_m * 2.5)
	# A slight side-to-side waddle, one sway every two hops.
	var waddle := deg_to_rad(3.0) * sin(_hop_phase) * signf(_height_m)
	var turn := facing + waddle + _jostle_turn
	var frame := _turn_frame(turn)
	_body.frame = frame
	_shadow.frame = frame
	_sight.rotation = facing + _jostle_turn
	# An anchored square's rocking moves only what's drawn, not the square.
	_body.position = _jostle
	_shadows.position = _jostle
	_sight.position = _jostle
	if _radio_pack:
		_radio_pack.position = _jostle
		_radio_pack.update_pose(turn, _height_m)


## The sheet frame showing the square turned by `angle` (clockwise radians).
static func _turn_frame(angle: float) -> int:
	var quarter := PI / 2
	return roundi(fposmod(angle, quarter) / quarter * TURN_FRAMES) % TURN_FRAMES


func _stay_in_arena() -> void:
	var half := SIZE_M / 2 * World.PX_PER_M
	var area := World.ARENA.grow(-half)
	position = position.clamp(area.position, area.end)
