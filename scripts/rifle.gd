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

@export var shoulder_right_m := 0.13   ## shoulder offset to the square's right
@export var shoulder_forward_m := 0.0  ## shoulder offset toward the front face
@export var sweep_right_deg := 40.0    ## how far it can swing out to the right
@export var sweep_left_deg := 30.0     ## how far it can swing across the body
@export var aim_speed_dps := 720.0     ## how fast it swings toward the mouse
@export var fire_interval_s := 0.12    ## fastest you can fire
@export var bullet_speed_mps := 120.0
@export var recoil_m := 0.04           ## kick back per shot
@export var shadow_path: NodePath = ^"../Shadows/RifleShadow"

## Where the rifle points, in radians (0 = right, -PI/2 = up).
var aim := -PI / 2

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


## Fires one shot if the rifle is ready. Bullets are added to the player's
## parent, so they fly on their own instead of following the player.
func fire() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = fire_interval_s
	_recoil_m = recoil_m
	_flash_left = FLASH_TIME_S
	_flash.visible = true
	_flash.rotation = randf_range(-0.15, 0.15)
	var muzzle := global_position + Vector2.from_angle(aim) * LENGTH_M * World.PX_PER_M * scale.x
	var bullet := Bullet.new()
	bullet.setup(muzzle, aim, bullet_speed_mps)
	owner.get_parent().add_child(bullet)
	fired.emit()
