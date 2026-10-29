extends CharacterBody2D
## A square soldier: the body every square shares, whoever controls it.
##
## It walks in whatever direction it's told, independent of where it faces,
## so it can strafe and back up. The body turns toward the point it's aiming
## at, but loosely, like a person: it only swings quickly once the aim is
## more than `comfort_deg` off its nose, and otherwise eases round to face
## the target squarely. Its front face is its line of sight, marked by the
## see-through "Sight" triangle just in front of it.
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
## Subclasses decide what it does by overriding:
##   _move_intent()    which way to walk (length 0..1 = fraction of full speed)
##   _aim_point()      the world point to look and aim at
##   _wants_to_fire()  whether to pull the trigger this tick
## scripts/player.gd reads the keyboard and mouse; scripts/squadmate.gd is AI.
##
## Sizes and speeds are in metres, so they stay right if the zoom changes.

const World = preload("res://scripts/world.gd")
const RadioPack = preload("res://scripts/radio_pack.gd")

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

## Which way the front face points, in radians: 0 = right, -PI/2 = up.
var facing := -PI / 2

## Multiplies walking speed; subclasses raise it to jog (e.g. catching up).
var _speed_scale := 1.0

var _hop_phase := 0.0
var _height_m := 0.0

@onready var _body: Sprite2D = $Body
@onready var _shadows: CanvasGroup = $Shadows
@onready var _shadow: Sprite2D = $Shadows/Shadow
@onready var _sight: Polygon2D = $Sight
@onready var _rifle = $Rifle
var _radio_pack: Node2D


func _ready() -> void:
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
	var intent := _move_intent().limit_length(1.0)
	var px := World.PX_PER_M
	if intent != Vector2.ZERO:
		velocity = velocity.move_toward(intent * speed_mps * _speed_scale * px,
				acceleration_mps2 * px * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction_mps2 * px * delta)
	move_and_slide()
	_stay_in_arena()
	var target := _aim_point()
	_turn_toward(target, delta)
	_update_hop(delta)
	_update_visuals()
	_rifle.update_aim(facing, _height_m, target, delta)
	if _wants_to_fire():
		_rifle.fire()


## Which way to walk this tick. Length 0..1 is the fraction of full speed.
func _move_intent() -> Vector2:
	return Vector2.ZERO


## The world point to look and aim at. By default, straight ahead.
func _aim_point() -> Vector2:
	return global_position + Vector2.from_angle(facing) * 10.0 * World.PX_PER_M


## Whether to fire this tick.
func _wants_to_fire() -> bool:
	return false


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
	var frame := _turn_frame(facing + waddle)
	_body.frame = frame
	_shadow.frame = frame
	_sight.rotation = facing
	if _radio_pack:
		_radio_pack.update_pose(facing + waddle, _height_m)


## The sheet frame showing the square turned by `angle` (clockwise radians).
static func _turn_frame(angle: float) -> int:
	var quarter := PI / 2
	return roundi(fposmod(angle, quarter) / quarter * TURN_FRAMES) % TURN_FRAMES


func _stay_in_arena() -> void:
	var half := SIZE_M / 2 * World.PX_PER_M
	var area := World.ARENA.grow(-half)
	position = position.clamp(area.position, area.end)
