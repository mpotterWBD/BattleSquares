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
##
## It holds `mag_size` rounds. Empty, it reloads by itself if `auto_reload`
## (squadmates, enemies); otherwise (the player) the trigger just clicks
## (DRY_FIRE_SOUNDS) until the holder start_reload()s (R). It can't fire
## while reloading. It carries `spare_mags` magazines (-1: as many as it
## needs). A reload swaps in the fullest spare; the magazine coming out is
## kept as a spare if it still has rounds in it, and only an empty one is
## dropped on the ground. With no spare left that has rounds, it can't reload.
##
## A reload plays one of RELOAD_TAKES at random (never the same twice
## running): five takes cut from assets/sfx/RifleReload.mp3, each with the
## moments of its sounds measured. The reload lasts as long as its take
## (about 1.9-2.0 s), and the animation (_reload_pose()) lands on its sounds:
##   start..out   the rifle tips out to the right (RELOAD_TILT_DEG), pulled
##                back and lowered
##   out          the magazine release: the empty magazine drops out (the gun
##                shows rifle_no_mag.png) and falls to the ground (DroppedMag:
##                under gravity, its shadow closing in, bounces, lies there,
##                fades)
##   in - 0.35 s  a fresh magazine comes from the body to the well...
##   in           ...and seats with the clack (rifle.png again), a jolt
##   charge       the charging handle: pulled back and let go
##   charge..end  back up to the aim
## Its sound is heard from the rifle, panned on screen, but as loud as the
## distance from the player says: full at the player's own rifle, fading
## to nothing at `reload_hearing_m`.
## Art: blender/scripts/rifle.py renders rifle_no_mag.png and magazine.png.

signal fired
signal reload_started
signal reload_finished

const World = preload("res://scripts/world.gd")
const Bullet = preload("res://scripts/bullet.gd")

const LENGTH_M := 0.48        ## shoulder (pivot) to muzzle; matches LENGTH_M in blender/scripts/rifle.py
## rifle.png is rendered at 4x the game's pixel density (RENDER_SCALE in
## rifle.py) so its small parts stay sharp when zoomed in; shrink it back.
const SPRITE_SCALE := 1.0 / 4.0
const HOLD_HEIGHT_M := 0.22   ## how high it's held, for the shadow offset
const FLASH_TIME_S := 0.05
const RIFLE_TEX := preload("res://assets/characters/rifle.png")
const NO_MAG_TEX := preload("res://assets/characters/rifle_no_mag.png")
const MAG_TEX := preload("res://assets/characters/magazine.png")
## Where the magazine sits in the rifle's frame (metres; pivot at 0, muzzle
## along +x): it pokes out to the gun's right (rifle.py, canted 30 degrees).
const MAG_SEAT_M := Vector2(0.33, 0.045)
const RELOAD_TILT_DEG := 25.0     ## tipped out to the right, clear of the body, magazine well in view
const RELOAD_PULL_M := 0.03       ## pulled back toward the shoulder
const RELOAD_LOWER_M := 0.06      ## lowered (its shadow comes in)
const CHARGE_PULL_M := 0.035      ## the charging handle's pull
const SEAT_JOLT_M := 0.015
const LOAD_S := 0.35              ## the fresh magazine's trip from the body to the well
## Dry fire: the click of the trigger on an empty magazine (cut from
## assets/sfx/GunOutofAmmo.mp3; see DEVLOG).
const DRY_FIRE_SOUNDS := [
	preload("res://assets/sfx/dry_fire/dry_fire_0.wav"),
	preload("res://assets/sfx/dry_fire/dry_fire_1.wav"),
	preload("res://assets/sfx/dry_fire/dry_fire_2.wav"),
	preload("res://assets/sfx/dry_fire/dry_fire_3.wav"),
	preload("res://assets/sfx/dry_fire/dry_fire_4.wav"),
]
## Reload takes (assets/sfx/rifle_reload/, cut from RifleReload.mp3; see
## DEVLOG): each with its length and the moments (seconds in) of the magazine
## release, the magazine seating, and the charging handle's pull and release.
const RELOAD_TAKES := [
	{sound = preload("res://assets/sfx/rifle_reload/rifle_reload_0.wav"), length = 1.940, out = 0.06, seat = 0.69, charge = 1.42, charged = 1.72},
	{sound = preload("res://assets/sfx/rifle_reload/rifle_reload_1.wav"), length = 1.990, out = 0.06, seat = 0.81, charge = 1.48, charged = 1.77},
	{sound = preload("res://assets/sfx/rifle_reload/rifle_reload_2.wav"), length = 1.920, out = 0.06, seat = 0.65, charge = 1.40, charged = 1.70},
	{sound = preload("res://assets/sfx/rifle_reload/rifle_reload_3.wav"), length = 1.970, out = 0.06, seat = 0.76, charge = 1.44, charged = 1.75},
	{sound = preload("res://assets/sfx/rifle_reload/rifle_reload_4.wav"), length = 1.922, out = 0.06, seat = 0.87, charge = 1.46, charged = 1.79},
]
static var _last_take := -1

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

@export_group("Magazine")
## Rounds in a full magazine. (A reload lasts as long as its sound.)
@export_range(1, 200, 1) var mag_size := 30
## Spare magazines carried, full, besides the one in the rifle (-1 = as many as it needs).
@export_range(-1, 50, 1) var spare_mags := -1
## Reloads by itself when the magazine runs dry. Off (the player), an empty
## rifle just clicks until it's told to reload.
@export var auto_reload := true
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var reload_volume_db := -2.0
## A reload can be heard out to this far from the player (fading with distance).
@export_range(1.0, 100.0, 0.5, "suffix:m") var reload_hearing_m := 25.0

@export_group("Sound")
## Played at the muzzle on every shot, by every rifle (players, squadmates,
## enemies): one of these at random, never the same one twice running (cut
## from assets/sfx/Rifle.mp3, each with its echo tail; see DEVLOG).
## Positional: quieter and panned with distance from the camera.
@export var shot_sounds: Array[AudioStream] = [
	preload("res://assets/sfx/rifle_shot/rifle_shot_0.wav"),
	preload("res://assets/sfx/rifle_shot/rifle_shot_1.wav"),
	preload("res://assets/sfx/rifle_shot/rifle_shot_2.wav"),
]
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var shot_volume_db := 0.0
## Each shot's pitch varies up to this much either way (0.05 = 5%), so a
## string of shots doesn't sound like one sample repeated.
@export_range(0.0, 0.3, 0.01) var shot_pitch_jitter := 0.05
## Beyond this far from the camera a shot can't be heard; it fades out over that distance.
@export_range(1.0, 100.0, 1.0, "suffix:m") var shot_hearing_m := 45.0

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
var _shot: AudioStreamPlayer2D

## Rounds left in the magazine, and whether it's reloading (and how far in).
var rounds := 0
var reloading := false
var reload_progress := 0.0     ## 0..1 through the reload
var _hand_mag: Sprite2D        ## the fresh magazine on its way in
var _dropped := false          ## this reload's empty magazine is out
var _seated := false
var _take: Dictionary = {}     ## the reload take playing
var _reload_t := 0.0           ## seconds into it
var _reload_sound: AudioStreamPlayer2D
var _dry_sound: AudioStreamPlayer2D
var _spares: Array[int] = []   ## rounds in each spare magazine (when they're counted)
var _old_rounds := 0           ## what the magazine coming out still had

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
	_shot = AudioStreamPlayer2D.new()
	var pick := AudioStreamRandomizer.new()
	pick.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	pick.random_pitch = 1.0   # pitch varies in fire() instead (shot_pitch_jitter)
	for sound in shot_sounds:
		pick.add_stream(-1, sound)
	_shot.stream = pick
	_shot.volume_db = shot_volume_db
	_shot.max_distance = shot_hearing_m * World.PX_PER_M
	_shot.max_polyphony = 6   # quick shots' echoes ring over each other instead of cutting off
	_shot.position = Vector2(muzzle, 0)
	add_child(_shot)
	rounds = mag_size
	_hand_mag = Sprite2D.new()
	_hand_mag.texture = MAG_TEX
	_hand_mag.scale = Vector2.ONE * SPRITE_SCALE
	_hand_mag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hand_mag.visible = false
	add_child(_hand_mag)
	_reload_sound = AudioStreamPlayer2D.new()
	_reload_sound.attenuation = 0.0          # loudness is set from the distance to the player instead
	_reload_sound.max_distance = 100000.0
	_reload_sound.position = MAG_SEAT_M * World.PX_PER_M
	add_child(_reload_sound)
	var clicks := AudioStreamRandomizer.new()
	clicks.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	for sound in DRY_FIRE_SOUNDS:
		clicks.add_stream(-1, sound)
	_dry_sound = AudioStreamPlayer2D.new()
	_dry_sound.stream = clicks
	_dry_sound.max_distance = 15.0 * World.PX_PER_M
	add_child(_dry_sound)
	for i in maxi(spare_mags, 0):
		_spares.append(mag_size)


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

	var pose := _reload_pose(delta)   # (tilt radians, pulled back m, lowered m)
	var back := _recoil_m + pose.y
	rotation = aim + pose.x
	var kick := Vector2.from_angle(rotation) * -back * px
	scale = Vector2.ONE * (1.0 + lift_m)
	_gun.position.x = -back * px
	var height := HOLD_HEIGHT_M + lift_m - pose.z
	_shadow.position = (position + kick
			+ World.SUN_DIR * height * tan(deg_to_rad(World.SUN_TILT_DEG)) * px)
	_shadow.rotation = rotation
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
	if _cooldown > 0.0 or reloading:
		return
	if rounds <= 0:
		if auto_reload:
			start_reload()
		else:
			_cooldown = fire_interval_s
			_dry_sound.pitch_scale = 1.0 + randf_range(-0.04, 0.04)
			_dry_sound.play()   # click
		return
	rounds -= 1
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
	_shot.pitch_scale = 1.0 + randf_range(-shot_pitch_jitter, shot_pitch_jitter)
	_shot.play()
	fired.emit()
	if rounds <= 0 and auto_reload:
		start_reload()   # empty: straight into a reload


## Spare magazines left (-1: as many as it needs).
func spare_count() -> int:
	return -1 if spare_mags < 0 else _spares.size()


## Rounds in the spare magazines (-1: as many as it needs).
func spare_rounds() -> int:
	if spare_mags < 0:
		return -1
	var total := 0
	for n in _spares:
		total += n
	return total


## Starts a reload, unless it's already reloading or full: picks a take and
## plays its sound. Returns whether it did.
func start_reload() -> bool:
	if reloading or rounds >= mag_size:
		return false
	if spare_mags >= 0 and (_spares.is_empty() or _spares.max() <= rounds):
		return false   # nothing better to put in
	_old_rounds = rounds
	var pick := randi() % (RELOAD_TAKES.size() - 1)
	if _last_take >= 0 and pick >= _last_take:
		pick += 1   # skip the one played last
	_last_take = pick
	_take = RELOAD_TAKES[pick]
	reloading = true
	reload_progress = 0.0
	_reload_t = 0.0
	_dropped = false
	_seated = false
	_reload_sound.stream = _take.sound
	_set_reload_volume()
	_reload_sound.play()
	reload_started.emit()
	return true


## Stops a reload where it is (its holder died): no magazine left in hand,
## and the sound cut.
func abandon_reload() -> void:
	reloading = false
	_hand_mag.visible = false
	_reload_sound.stop()


## Loudness by distance from the player (from the camera if there's no player).
func _set_reload_volume() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var ears: Vector2
	if player:
		ears = player.global_position
	elif get_viewport().get_camera_2d():
		ears = get_viewport().get_camera_2d().get_screen_center_position()
	else:
		ears = global_position
	var level := clampf(1.0 - global_position.distance_to(ears) / (reload_hearing_m * World.PX_PER_M), 0.0, 1.0)
	_reload_sound.volume_db = reload_volume_db + linear_to_db(maxf(level * level, 0.0001))


## Steps the reload on by `delta` and returns the pose for this moment:
## (tilt in radians, pulled back in metres, lowered in metres). Drops the
## empty magazine and seats the fresh one on their sounds. Zero when not
## reloading.
func _reload_pose(delta: float) -> Vector3:
	if not reloading:
		return Vector3.ZERO
	_reload_t += delta
	var t := _reload_t
	var length: float = _take.length
	reload_progress = minf(t / length, 1.0)
	_set_reload_volume()
	# How far into the tipped-out pose: out as the release clicks, back up
	# once the charging handle's done.
	var tipped := smoothstep(0.0, _take.out + 0.12, t) * (1.0 - smoothstep(_take.charged, length, t))
	var pull := RELOAD_PULL_M * tipped
	if t >= _take.charge and t < _take.charged:   # the charging handle
		pull += CHARGE_PULL_M * sin((t - _take.charge) / (_take.charged - _take.charge) * PI)
	if t >= _take.seat and t < _take.seat + 0.06:   # the fresh magazine seats
		pull += SEAT_JOLT_M * sin((t - _take.seat) / 0.06 * PI)
	# The empty magazine drops out on the release.
	if t >= _take.out and not _dropped:
		_dropped = true
		_gun.texture = NO_MAG_TEX
		if _old_rounds <= 0:
			_drop_magazine()   # (one with rounds left goes in a pouch instead)
	# The fresh one comes from the body to the well, and seats on the clack.
	var seat := MAG_SEAT_M * World.PX_PER_M
	if t >= _take.seat - LOAD_S and t < _take.seat:
		var body := (to_local(owner.global_position) if owner else Vector2.ZERO) + Vector2(0, 0.06 * World.PX_PER_M)
		var k := smoothstep(_take.seat - LOAD_S, _take.seat, t)
		_hand_mag.visible = true
		_hand_mag.position = body.lerp(seat, k)
		_hand_mag.rotation = lerpf(0.0, PI / 2, k)          # from carried flat to upright in the well
		_hand_mag.scale = Vector2(SPRITE_SCALE * lerpf(1.0, 0.5, k), SPRITE_SCALE)   # foreshortens as it stands up
	elif t >= _take.seat and not _seated:
		_seated = true
		_hand_mag.visible = false
		_gun.texture = RIFLE_TEX
	if t >= length:
		reloading = false
		if spare_mags < 0:
			rounds = mag_size
		else:
			if _old_rounds > 0:
				_spares.append(_old_rounds)   # kept, with what's left in it
			var best := _spares.find(_spares.max())
			rounds = _spares[best]
			_spares.remove_at(best)
		reload_finished.emit()
	return Vector3(deg_to_rad(RELOAD_TILT_DEG) * tipped, pull, RELOAD_LOWER_M * tipped)


## The empty magazine falls from the well to the ground, into the level.
func _drop_magazine() -> void:
	var level := owner.get_parent() if owner else get_parent()
	var mag := DroppedMag.new()
	mag.setup(to_global(MAG_SEAT_M * World.PX_PER_M), global_rotation + PI / 2,
			Vector2.from_angle(global_rotation + PI / 2), HOLD_HEIGHT_M)
	level.add_child(mag)


## An empty magazine dropped in a reload: it falls under gravity from the
## rifle's height, drifting out to the gun's right and turning, its shadow
## closing in as it comes down; bounces once, lies there LIE_S, fades, and
## is gone.
class DroppedMag extends Node2D:
	const World = preload("res://scripts/world.gd")
	const GRAVITY := 9.8
	const DRIFT_MPS := 0.5
	const SPIN_DPS := 300.0
	const BOUNCE := 0.25
	const LIE_S := 5.0
	const FADE_S := 1.0
	const SHADOW_ALPHA := 0.55
	var _height := 0.0
	var _fall := 0.0
	var _drift := Vector2.ZERO
	var _spin := 0.0
	var _down := false
	var _sprite: Sprite2D
	var _shadow: Sprite2D

	func setup(at: Vector2, turn: float, out: Vector2, height_m: float) -> void:
		position = at
		rotation = turn
		_height = height_m
		_drift = out * DRIFT_MPS * randf_range(0.6, 1.2)
		_spin = deg_to_rad(SPIN_DPS) * randf_range(-1.0, 1.0)
		z_index = -4   # on the ground, under the squares
		_shadow = Sprite2D.new()
		_shadow.texture = MAG_TEX
		_shadow.scale = Vector2.ONE * SPRITE_SCALE
		_shadow.modulate = Color(0, 0, 0, SHADOW_ALPHA)
		add_child(_shadow)
		_sprite = Sprite2D.new()
		_sprite.texture = MAG_TEX
		_sprite.scale = Vector2.ONE * SPRITE_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(_sprite)
		_place_shadow()

	func _physics_process(delta: float) -> void:
		if _down:
			return
		var px := World.PX_PER_M
		_fall += GRAVITY * delta
		_height -= _fall * delta
		position += _drift * px * delta
		rotation += _spin * delta
		if _height <= 0.0:
			_height = 0.0
			if _fall > 1.0:
				_fall = -_fall * BOUNCE   # one small bounce
				_drift *= 0.4
				_spin *= 0.4
			else:
				_down = true
				var fade := create_tween()
				fade.tween_interval(LIE_S)
				fade.tween_property(self, "modulate:a", 0.0, FADE_S)
				fade.tween_callback(queue_free)
		_place_shadow()

	## The shadow sits away from the sun by the height it's at; up off the
	## ground it's drawn a touch bigger.
	func _place_shadow() -> void:
		var px := World.PX_PER_M
		var away: Vector2 = World.SUN_DIR * _height * tan(deg_to_rad(World.SUN_TILT_DEG)) * px
		_shadow.position = away.rotated(-rotation)
		_sprite.scale = Vector2.ONE * SPRITE_SCALE * (1.0 + _height)
