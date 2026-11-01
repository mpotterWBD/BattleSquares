extends Node2D
## A crate coming down under a parachute (released by scripts/supply_drop.gd).
##
## It drops from the helicopter, falls free for FREEFALL_S, then the canopy
## (assets/vehicles/parachute.png, blender/scripts/parachute.py) blossoms
## open over OPEN_S and slows it to DESCENT_MPS, swaying gently as it comes
## down. It steers in from where it was let go to the exact spot it was
## called to (`target`), touching down there turned as asked. While it's in
## the air it looks bigger the higher it is (like the helicopter), its
## shadow and the canopy's fall away from the sun by their heights, and it's
## not solid. It's drawn over the squares but under helicopters (their body
## is at z 5, the rotor 19-20): just let go, it's below the one that dropped
## it (CRATE_Z, CANOPY_Z). On touchdown: a thump and a burst of dust, and the
## crate is a normal solid crate from then on (its own shadows back on).
##
## Sound: the canopy flapping (assets/sfx/parachuteFlapping.mp3, looped,
## from a random point in it so drops don't sound alike) fades in as it
## opens, and out as it spills air after touchdown; the crate hitting the
## ground is assets/sfx/HittingGround.mp3.
##
## Then the canopy comes down on its own, straight down onto the crate, with
## a little physics (_settle_canopy()): with the load gone it's all drag and
## no weight, so it nearly stops and floats; it spills air (`_inflation`
## falls toward DEFLATED over DEFLATE_S), and with less canopy to hold it up
## it sinks faster (drag ~ inflation x speed squared: CANOPY_SINK_MPS fully
## open). It flutters and wanders a little as it comes, its shadow closing
## in on it. Going slack it spreads, so it looks a little bigger, never
## smaller, and once it's down on the load it drapes over it, spreading a
## little more, and fades away.

const World = preload("res://scripts/world.gd")
const HitDust = preload("res://scripts/hit_dust.gd")

const CANOPY_TEX := preload("res://assets/vehicles/parachute.png")
const CANOPY_SCALE := 0.5          ## parachute.png is rendered at 2x
const GRAVITY := 9.8
const FREEFALL_S := 0.9            ## falling free before the canopy opens
const OPEN_S := 0.7                ## the canopy blossoming open
const DESCENT_MPS := 5.0           ## steady descent under the canopy
const BRAKE := 2.5                 ## how quickly the canopy slows it to that (per second)
const LINES_M := 4.0               ## the canopy rides this far above the crate
const GROW_PER_M := 0.01           ## looks 1% bigger per metre up (helicopter.gd CLIMB_SCALE_PER_M)
const SWAY_DEG := 4.0              ## the crate swings this far either way...
const SWAY_HZ := 0.3               ## ...this often
const CANOPY_SHADOW_ALPHA := 0.3
const CRATE_SHADOW_ALPHA := 0.6
## The canopy settling, once its crate is down.
const CANOPY_SINK_MPS := 1.5       ## its falling speed on its own, fully open (drag = its weight)
const DEFLATED := 0.4              ## how open it ends up as it spills air...
const DEFLATE_S := 1.0             ## ...falling toward that over about this long
const SLACK_LOOK := 1.12           ## going slack it spreads: drawn this big (of open) by DEFLATED
const FLUTTER_HZ := 1.6            ## the fabric rippling...
const FLUTTER := 0.06              ## ...this much (of its size), while it's still open
const WANDER_M := 0.12             ## wandering about over the crate as it comes down
const DRAPE_S := 1.6               ## lying over the load, spreading out and fading
const DRAPE_SPREAD := 0.06         ## spreads this much more as it drapes
const LAND_DUST_M := 0.45
const CRATE_Z := 3                 ## in the air: over the squares (0), under a helicopter's body (5)
const CANOPY_Z := 4                ## the canopy over its crate, still under the helicopter
const FLAP_SOUND := preload("res://assets/sfx/parachuteFlapping.mp3")
const LAND_SOUND := preload("res://assets/sfx/HittingGround.mp3")
const FLAP_DB := -2.0              ## the flapping, fully open
const FLAP_FADE_S := 0.8           ## fading out after touchdown
const LAND_DB := 4.0               ## the landing (the recording's quiet)
const SOUND_HEARING_M := 40.0

var crate: Node2D                  ## the crate on its way down (then on the ground)
var _target := Vector2.ZERO
var _turn := 0.0
var _from := Vector2.ZERO
var _alt := 0.0
var _alt0 := 1.0
var _fall := 0.0                   ## falling speed, m/s
var _t := 0.0
var _landed := false
var _canopy_h := 0.0               ## once down: the canopy's height above the ground (m)...
var _canopy_v := 0.0               ## ...its falling speed (m/s)...
var _inflation := 1.0              ## ...how open it still is (1 open .. DEFLATED)...
var _settle_t := 0.0               ## ...time since the crate landed...
var _drape := -1.0                 ## ...and 0..1 through draping over the load (-1: not yet)
var _canopy_size := 0.0            ## the biggest it's been drawn since then: it never looks smaller
var _shadow: Node2D
var _flap: AudioStreamPlayer2D


## `scene` is the crate's scene (crate.gd); it lands at world `target`,
## turned `turn`, having been let go at world `from`, `altitude_m` up.
func setup(scene: PackedScene, target: Vector2, turn: float, from: Vector2, altitude_m: float) -> void:
	_target = target
	_turn = turn
	_from = from
	_alt = altitude_m
	_alt0 = maxf(altitude_m, 0.1)
	crate = scene.instantiate()
	crate.position = from
	crate.rotation = turn
	crate.z_index = CRATE_Z
	crate.get_node("Collision").disabled = true
	for part in ["Shadow", "PalletShadow"]:
		if crate.has_node(part):
			crate.get_node(part).visible = false


func _ready() -> void:
	z_index = CANOPY_Z
	_shadow = Node2D.new()
	_shadow.z_as_relative = false
	_shadow.z_index = -9   # on the ground
	_shadow.draw.connect(_draw_shadows)
	add_child(_shadow)
	get_parent().add_child.call_deferred(crate)
	var looped := FLAP_SOUND.duplicate() as AudioStreamMP3
	looped.loop = true
	_flap = AudioStreamPlayer2D.new()
	_flap.stream = looped
	_flap.volume_db = -80.0
	_flap.max_distance = SOUND_HEARING_M * World.PX_PER_M
	add_child(_flap)
	_flap.play(randf() * FLAP_SOUND.get_length() * 0.8)   # (the end has one loud snap)


func _physics_process(delta: float) -> void:
	_t += delta
	_flap.global_position = _canopy_at()
	if _landed:
		var left := clampf(1.0 - _settle_t / FLAP_FADE_S, 0.0, 1.0)
		_flap.volume_db = FLAP_DB + linear_to_db(maxf(left, 0.0001))
		if left <= 0.0 and _flap.playing:
			_flap.stop()
		_settle_canopy(delta)
		queue_redraw()
		_shadow.queue_redraw()
		return
	if _t < FREEFALL_S:
		_fall += GRAVITY * delta
	else:
		_fall = lerpf(_fall, DESCENT_MPS, 1.0 - exp(-BRAKE * delta))
	_alt -= _fall * delta
	if _alt <= 0.0:
		_land()
		return
	if crate.is_inside_tree():
		var down := 1.0 - _alt / _alt0   # 0 let go .. 1 down
		crate.global_position = _from.lerp(_target, smoothstep(0.0, 1.0, down))
		crate.rotation = _turn + deg_to_rad(SWAY_DEG) * sin(TAU * SWAY_HZ * _t) * _opened()
		crate.scale = Vector2.ONE * (1.0 + _alt * GROW_PER_M)
	_flap.volume_db = FLAP_DB + linear_to_db(maxf(minf(_opened(), 1.0), 0.0001))   # in as it opens
	queue_redraw()
	_shadow.queue_redraw()


## The canopy on its own after the crate lands: drag (proportional to how
## open it is, and to speed squared) against its weight, so it hangs then
## sinks faster as it spills air, until it's down on the load; then it
## drapes and fades.
func _settle_canopy(delta: float) -> void:
	_settle_t += delta
	if _drape >= 0.0:
		_drape = minf(_drape + delta / DRAPE_S, 1.0)
		if _drape >= 1.0:
			queue_free()
		return
	_inflation = DEFLATED + (1.0 - DEFLATED) * exp(-_settle_t / DEFLATE_S)
	var drag := GRAVITY / (CANOPY_SINK_MPS * CANOPY_SINK_MPS) * _inflation
	_canopy_v += (GRAVITY - drag * _canopy_v * absf(_canopy_v)) * delta
	_canopy_h -= _canopy_v * delta
	var top: float = crate.load_height_m if "load_height_m" in crate else 0.7
	if _canopy_h <= top:
		_canopy_h = top
		_drape = 0.0


## How far the canopy has opened (0 packed .. 1 open, with a little overshoot).
func _opened() -> float:
	var k := clampf((_t - FREEFALL_S) / OPEN_S, 0.0, 1.0)
	return k + 0.12 * sin(k * PI)


## Down: exactly on its spot, solid, its own shadows on; a thump and dust.
func _land() -> void:
	_landed = true
	_alt = 0.0
	crate.global_position = _target
	crate.rotation = _turn
	crate.scale = Vector2.ONE
	crate.z_index = 0
	crate.get_node("Collision").set_deferred("disabled", false)
	for part in ["Shadow", "PalletShadow"]:
		if crate.has_node(part):
			crate.get_node(part).visible = true
			crate.get_node(part + "/Shape").queue_redraw()
	_canopy_h = LINES_M + (crate.load_height_m if "load_height_m" in crate else 0.7)
	_canopy_v = _fall   # it was coming down with the crate
	var level := get_parent()
	for k in 6:
		var out := Vector2.from_angle(TAU * k / 6.0 + randf_range(-0.3, 0.3))
		var dust := HitDust.new()
		dust.setup(_target + out * LAND_DUST_M * World.PX_PER_M, -out, HitDust.GROUND_STRENGTH, true)
		level.add_child(dust)
	var thud := AudioStreamPlayer2D.new()
	thud.stream = LAND_SOUND
	thud.position = _target
	thud.volume_db = LAND_DB
	thud.pitch_scale = randf_range(0.94, 1.06)
	thud.max_distance = SOUND_HEARING_M * World.PX_PER_M
	thud.finished.connect(thud.queue_free)
	level.add_child(thud)
	thud.play()


## Where the canopy is (world): over its crate in the air; once the crate's
## down, over it still, wandering a little as it comes down.
func _canopy_at() -> Vector2:
	if _landed:
		var still := 0.0 if _drape >= 0.0 else clampf(_canopy_h / LINES_M, 0.0, 1.0)
		var wander := Vector2(sin(_settle_t * 1.3), cos(_settle_t * 1.1 + 0.4)) * WANDER_M * still
		return _target + wander * World.PX_PER_M
	var sway := Vector2.from_angle(_turn) * sin(TAU * SWAY_HZ * _t + 0.6) * 0.15 * World.PX_PER_M
	return (crate.global_position if crate.is_inside_tree() else _from) + sway


## The canopy's height above the ground (m).
func _canopy_height() -> float:
	return _canopy_h if _landed else _alt + LINES_M


## How the canopy is drawn: its size on screen (with height, opening,
## fluttering, and once its crate is down, going slack and draping), its
## size on the ground (for its shadow, without the height), and how solid it
## looks. Once its crate is down it spreads as it goes slack (SLACK_LOOK)
## and drapes (DRAPE_SPREAD), and never looks smaller than it has (though
## it's coming down, nearer the ground looks smaller).
func _canopy_look() -> Array:
	var near := 1.0 + _canopy_height() * GROW_PER_M
	var size := _opened() * near
	var ripple := 0.0
	var alpha := 1.0
	if _landed:
		var slack := 1.0 - (_inflation - DEFLATED) / (1.0 - DEFLATED)   # 0 open .. 1 slack
		size = lerpf(1.0, SLACK_LOOK, slack) * near
		ripple = FLUTTER * (1.0 - slack) * sin(TAU * FLUTTER_HZ * _settle_t)
		if _drape >= 0.0:
			var d := smoothstep(0.0, 1.0, _drape)
			size *= 1.0 + DRAPE_SPREAD * d
			alpha = 1.0 - d
		_canopy_size = maxf(_canopy_size, size)
		size = _canopy_size
	var squash := Vector2(size * (1.0 + ripple), size * (1.0 - 0.8 * ripple))
	return [squash, squash / near, alpha]


func _draw() -> void:
	if _opened() <= 0.0:
		return
	var size := CANOPY_TEX.get_size() * CANOPY_SCALE
	var look := _canopy_look()
	draw_set_transform(to_local(_canopy_at()), 0.0, look[0])
	draw_texture_rect(CANOPY_TEX, Rect2(-size / 2.0, size), false, Color(1, 1, 1, look[2]))
	draw_set_transform(Vector2.ZERO)


## On the ground: the crate's shadow while it's up (a dark footprint, away
## from the sun by its height) and the canopy's (its shape, darkened).
func _draw_shadows() -> void:
	var px := World.PX_PER_M
	var sun := World.SUN_DIR * tan(deg_to_rad(World.SUN_TILT_DEG)) * px
	if not _landed and crate.is_inside_tree():
		var foot := Vector2(0.8, 0.8) * px
		_shadow.draw_set_transform(_shadow.to_local(crate.global_position + sun * (_alt + 0.4)), crate.rotation)
		_shadow.draw_rect(Rect2(-foot / 2.0, foot), Color(0, 0, 0, CRATE_SHADOW_ALPHA))
	if _opened() > 0.0:
		var size := CANOPY_TEX.get_size() * CANOPY_SCALE
		var look := _canopy_look()
		_shadow.draw_set_transform(_shadow.to_local(_canopy_at() + sun * _canopy_height()), 0.0, look[1])
		_shadow.draw_texture_rect(CANOPY_TEX, Rect2(-size / 2.0, size), false, Color(0, 0, 0, CANOPY_SHADOW_ALPHA * look[2]))
	_shadow.draw_set_transform(Vector2.ZERO)
