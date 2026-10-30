extends Node2D
## The player's rifle, shouldered like a right-handed person would hold it.
## The stock sits at the right shoulder (`shoulder_*_m`, in the body's own
## frame, so it turns with the square) and the gun pivots there, pointing
## from the shoulder at the mouse. It can swing `sweep_right_deg` out to the
## right but only `sweep_left_deg` across the body; to aim further round the
## square has to turn. Left click fires a tracer.
##
## The rifle sprite is lit from straight overhead, so it can rotate freely.
## Its shadow is the same shape, darkened and offset away from the sun by the
## rifle's height above the ground.

signal fired

const World = preload("res://scripts/world.gd")
const Bullet = preload("res://scripts/bullet.gd")

const LENGTH_M := 0.48        ## shoulder (pivot) to muzzle; matches LENGTH_M in blender/scripts/rifle.py
## rifle.png is rendered at 4x the game's pixel density (RENDER_SCALE in
## rifle.py) so its small parts stay sharp when zoomed in; shrink it back.
const SPRITE_SCALE := 1.0 / 4.0
const HOLD_HEIGHT_M := 0.22   ## how high it's held, for the shadow offset
const FLASH_TIME_S := 0.05

# The "##" comment above each setting is its tooltip in Godot's Inspector
# (hover over the setting's name).

@export_group("Holding")
## How far the shoulder the rifle pivots on sits to the right of the
## square's centre, in metres.
@export_range(0.0, 0.5, 0.01, "suffix:m") var shoulder_right_m := 0.13
## How far the shoulder sits toward the square's front face, in metres
## (negative = toward the back).
@export_range(-0.3, 0.3, 0.01, "suffix:m") var shoulder_forward_m := 0.0
## How far the rifle can swing out to the right of where the square faces
## before the square has to turn.
@export_range(0.0, 180.0, 1.0, "suffix:°") var sweep_right_deg := 40.0
## How far the rifle can swing across the body, to the left of where the
## square faces, before the square has to turn.
@export_range(0.0, 180.0, 1.0, "suffix:°") var sweep_left_deg := 30.0
## How fast the rifle swings round toward the mouse, in degrees per second.
@export_range(0.0, 3600.0, 10.0, "suffix:°/s") var aim_speed_dps := 720.0

@export_group("Firing")
## The shortest time between shots: clicks faster than this are ignored.
@export_range(0.0, 5.0, 0.01, "suffix:s") var fire_interval_s := 0.12
## How fast the bullet flies, in metres per second.
@export_range(1.0, 1000.0, 1.0, "suffix:m/s") var bullet_speed_mps := 120.0
## Health a hit takes off a square (a full square has max_health in
## soldier.gd, normally 100).
@export_range(0.0, 500.0, 0.5) var damage := 25.0
## How far the rifle kicks back toward the shoulder with each shot, in
## metres. Just for looks: it doesn't change where shots go.
@export_range(0.0, 0.2, 0.005, "suffix:m") var recoil_m := 0.04

@export_group("Aim")
## The length of the solid part of the aiming line (right mouse): click
## anywhere within this distance of the muzzle and the shot goes exactly
## there. Past it, shots start to stray.
@export_range(0.0, 50.0, 0.5, "suffix:m") var aim_accurate_m := 6.0
## How far past the solid line the spread takes to grow to its worst
## (Aim Max Spread Deg). Clicks further out than that are no worse.
@export_range(0.1, 50.0, 0.5, "suffix:m") var aim_falloff_m := 12.0
## The worst a shot can stray, either side of where you aimed, once you're
## Aim Falloff M past the solid line. Each shot lands at random within it.
@export_range(0.0, 45.0, 0.5, "suffix:°") var aim_max_spread_deg := 8.0
## How the spread grows between the end of the solid line and its worst:
## 1 = steadily; above 1 = barely at first, then quickly near the end;
## below 1 = quickly at first, then levelling off.
@export_range(0.1, 4.0, 0.1) var aim_spread_curve := 1.0
## The chance, once you're Aim Falloff M past the solid line, that a shot
## goes into the ground short of where you aimed (kicking up a puff of dust)
## instead of carrying on. None within the solid line; it grows past it
## like the spread does.
@export_range(0.0, 100.0, 1.0, "suffix:%") var aim_max_ground_hit_pct := 40.0
## How the ground-hit chance grows between the end of the solid line and its
## worst: 1 = steadily; above 1 = barely at first, then quickly near the end;
## below 1 = quickly at first, then levelling off.
@export_range(0.1, 4.0, 0.1) var aim_ground_hit_curve := 1.0
## Standing still steadies the aim: the solid line and the falloff both
## grow to this many times their length (2 = 200%, twice as long). Moving
## puts them straight back to normal.
@export_range(1.0, 5.0, 0.05, "suffix:x") var aim_still_multiplier := 2.0
## How long after stopping the aim takes to steady fully (the line grows
## smoothly over this time).
@export_range(0.0, 3.0, 0.05, "suffix:s") var aim_steady_s := 0.5
## Moving slower than this still counts as standing still (so a nudge or a
## hit doesn't spoil the aim), in metres per second.
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var aim_still_below_mps := 0.3

@export_group("")
## The rifle's shadow sprite, darkened and offset by the sun. Leave as is
## unless the scene's node layout changes.
@export var shadow_path: NodePath = ^"../Shadows/RifleShadow"

## Where the rifle points, in radians (0 = right, -PI/2 = up).
var aim := -PI / 2

## How steady the aim is: 0 moving, rising to 1 after standing still for
## `aim_steady_s` (update_steadiness()).
var steady := 0.0

var _cooldown := 0.0
var _recoil_m := 0.0
var _flash_left := 0.0

@onready var _gun: Sprite2D = $Gun
@onready var _flash: Polygon2D = $Flash
@onready var _shadow: Sprite2D = get_node(shadow_path)


func _ready() -> void:
	var muzzle := LENGTH_M * World.PX_PER_M
	_flash.polygon = PackedVector2Array([
		Vector2(muzzle, 0), Vector2(muzzle + 6, -4),
		Vector2(muzzle + 15, 0), Vector2(muzzle + 6, 4),
	])
	_flash.visible = false
	_gun.scale = Vector2.ONE * SPRITE_SCALE
	# Mipmaps keep the shrunk-down sprite smooth instead of shimmering as it turns.
	_gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Called by the player every physics tick, after it has turned and hopped.
## `target` is the world point to aim at (usually the mouse).
func update_aim(facing: float, lift_m: float, target: Vector2, delta: float) -> void:
	var px := World.PX_PER_M
	# Put the pivot on the right shoulder. Rotating the facing direction by
	# +90 degrees gives the square's right (Godot's y axis points down).
	var ahead := Vector2.from_angle(facing)
	position = ((ahead * shoulder_forward_m + ahead.rotated(PI / 2) * shoulder_right_m)
			* px * (1.0 + lift_m))

	# Positive angles are clockwise on screen, i.e. to the square's right.
	var left := -deg_to_rad(sweep_left_deg)
	var right := deg_to_rad(sweep_right_deg)
	var to_target := (target - global_position).angle()
	var wanted := facing + clampf(angle_difference(facing, to_target), left, right)
	aim = rotate_toward(aim, wanted, deg_to_rad(aim_speed_dps) * delta)
	# Keep inside the sweep even while the body turns underneath.
	aim = wrapf(facing + clampf(angle_difference(facing, aim), left, right), -PI, PI)

	_cooldown = maxf(_cooldown - delta, 0.0)
	_recoil_m = move_toward(_recoil_m, 0.0, delta * 0.4)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_flash.visible = _flash_left > 0.0

	var kick := Vector2.from_angle(aim) * -_recoil_m * px
	rotation = aim
	scale = Vector2.ONE * (1.0 + lift_m)
	_gun.position.x = -_recoil_m * px
	var height := HOLD_HEIGHT_M + lift_m
	_shadow.position = (position + kick
			+ World.SUN_DIR * height * tan(deg_to_rad(World.SUN_TILT_DEG)) * px)
	_shadow.rotation = aim
	_shadow.scale = scale * SPRITE_SCALE


## Where shots leave the barrel, in world coordinates.
func muzzle_position() -> Vector2:
	return global_position + Vector2.from_angle(aim) * LENGTH_M * World.PX_PER_M * scale.x


## Called every tick with how fast the holder is moving (px/s): standing
## still steadies the aim over `aim_steady_s`; moving loses it at once.
func update_steadiness(speed: float, delta: float) -> void:
	if speed > aim_still_below_mps * World.PX_PER_M:
		steady = 0.0
	elif aim_steady_s <= 0.0:
		steady = 1.0
	else:
		steady = minf(steady + delta / aim_steady_s, 1.0)


## The solid line's length right now, in metres: `aim_accurate_m`, longer
## while standing still (`aim_still_multiplier`).
func accurate_m() -> float:
	return aim_accurate_m * _steady_scale()


## How far past the solid line the spread takes to reach its worst right
## now, in metres (`aim_falloff_m`, longer while standing still).
func falloff_m() -> float:
	return aim_falloff_m * _steady_scale()


func _steady_scale() -> float:
	return lerpf(1.0, aim_still_multiplier, smoothstep(0.0, 1.0, steady))


## How far either side of the aim (degrees) a shot at a point `distance_m`
## from the muzzle may stray. See `aim_accurate_m`.
func spread_at(distance_m: float) -> float:
	return aim_max_spread_deg * pow(_past_solid(distance_m), aim_spread_curve)


## The chance (0..1) that a shot at a point `distance_m` from the muzzle
## goes into the ground short of it. See `aim_max_ground_hit_pct`.
func ground_hit_chance_at(distance_m: float) -> float:
	return aim_max_ground_hit_pct / 100.0 * pow(_past_solid(distance_m), aim_ground_hit_curve)


## How far past the solid line `distance_m` is, as a fraction (0..1) of
## the falloff, both as they are right now (accurate_m(), falloff_m()).
func _past_solid(distance_m: float) -> float:
	var past := distance_m - accurate_m()
	if past <= 0.0:
		return 0.0
	return clampf(past / maxf(falloff_m(), 0.001), 0.0, 1.0)


## Fires one shot if the rifle is ready. Bullets are added to the player's
## parent, so they fly on their own instead of following the player.
## `spread_deg` throws the shot up to that far either side of the aim.
## `distance_m` is how far from the muzzle the shooter is aiming: past the
## solid line, the shot may go into the ground (ground_hit_chance_at()),
## landing somewhere between the end of the solid line and that point.
func fire(spread_deg := 0.0, distance_m := 0.0) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = fire_interval_s
	_recoil_m = recoil_m
	_flash_left = FLASH_TIME_S
	_flash.visible = true
	_flash.rotation = randf_range(-0.15, 0.15)
	var muzzle := muzzle_position()
	var bullet := Bullet.new()
	var angle := aim + deg_to_rad(randf_range(-spread_deg, spread_deg))
	bullet.setup(muzzle, angle, bullet_speed_mps, owner, damage)
	if randf() < ground_hit_chance_at(distance_m):
		bullet.ground_at_m = randf_range(minf(accurate_m(), distance_m), distance_m)
	owner.get_parent().add_child(bullet)
	fired.emit()
