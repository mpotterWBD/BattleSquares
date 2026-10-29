extends Node2D
## A UH-60-style transport helicopter, shrunk to SCALE of real size so the
## two pilot squares seen through its cockpit glass are 0.44 m, 10% bigger
## than the player (they're higher up, closer to the camera): about 8.4 m
## long with a 9 m main rotor. Rotate this node to set its heading (nose points along +x).
##
## Sizes below are the real helicopter's, times SCALE.
##
## The body and rotor are separate top-down sprites lit from straight
## overhead (blender/scripts/helicopter.py), so they look right at any
## heading. The two pilots are their own sprites, drawn over the body's
## cockpit and under the glass image, so they can move a little: a slow
## sway, and now and then a glance to one side and back. The rotor turns at `rotor_spin` (0 = stopped, 1 = flight speed);
## as it speeds up the blades fade into a translucent blur disc.
##
## Shadows are drawn here, merged in one group. Each part that sits at its
## own height (fuselage, tail plane, fin, tail rotor) has its own outline,
## swept by shaders/shadow_sweep.gdshader across the heights it spans, which
## is the shadow a solid casts under the 40-degree sun. The rotor adds its
## own. Raising `altitude_m` slides them all away in the sun's direction and
## makes the helicopter look a little bigger, as it's closer to the camera.
##
## Radio terminals send them in to drop troops (scripts/insertion.gd).

const World = preload("res://scripts/world.gd")

const SCALE := 0.55                 ## of real size; matches SCALE in helicopter.py
const MAST_M := Vector2(1.5, 0.0) * SCALE   ## main rotor mast, ahead of the body centre; matches MAST_X_M in helicopter.py
const ROTOR_RADIUS_M := 8.18 * SCALE
const ROTOR_HEIGHT_M := 3.6 * SCALE
const SHADOW_SWEEP := preload("res://shaders/shadow_sweep.gdshader")
## Each part's shadow outline (blender/scripts/helicopter.py SHADOW_PARTS)
## and the lowest and highest points of that part above the ground (m).
const SHADOW_PARTS := [
	{texture = preload("res://assets/vehicles/helicopter_shadow_body.png"), low_m = 0.1 * SCALE, high_m = 3.25 * SCALE},
	{texture = preload("res://assets/vehicles/helicopter_shadow_stabilator.png"), low_m = 1.95 * SCALE, high_m = 2.05 * SCALE},
	{texture = preload("res://assets/vehicles/helicopter_shadow_fin.png"), low_m = 1.9 * SCALE, high_m = 4.3 * SCALE},
	{texture = preload("res://assets/vehicles/helicopter_shadow_tailrotor.png"), low_m = 1.85 * SCALE, high_m = 5.15 * SCALE},
]
const SHADOW_TEXEL_PX := 2.0        ## outlines are rendered at half the game's pixel density
const SHADOW_ALPHA := 0.71          ## same darkness as the squares' shadows
const CLIMB_SCALE_PER_M := 0.01     ## looks 1% bigger per metre of altitude
const PILOT_TEXTURE := preload("res://assets/vehicles/helicopter_pilot.png")
const GLASS_TEXTURE := preload("res://assets/vehicles/helicopter_glass.png")
## Where the pilots sit (port one; the other is mirrored), game metres.
## Matches PILOT_X_M / PILOT_Y_M in helicopter.py, which are laid out for a
## helicopter at scale 0.5 (COCKPIT_AT_SCALE).
const PILOT_M := Vector2(2.84, -0.245) * SCALE / 0.5
const PILOT_SWAY_DEG := 3.0          ## slow idle turning either way
const PILOT_SHIFT_M := 0.015         ## and shifting in the seat
const PILOT_GLANCE_DEG := Vector2(10.0, 28.0)   ## a glance turns this far
const PILOT_GLANCE_S := Vector2(0.6, 1.8)       ## and holds this long
const PILOT_GLANCE_EVERY_S := Vector2(2.5, 7.0) ## between glances
const PILOT_TURN_RATE := 6.0         ## how quickly a glance turns (per second)
## Top-down outline of the real fuselage (metres, nose at +x; times SCALE
## in _ready), for collisions.
const HULL_M := [
	Vector2(7.6, 0.0), Vector2(7.2, -0.7), Vector2(6.6, -1.1), Vector2(5.5, -1.2),
	Vector2(-0.5, -1.2), Vector2(-1.5, -1.0), Vector2(-2.5, -0.6), Vector2(-7.6, -0.3),
	Vector2(-7.6, 0.3), Vector2(-2.5, 0.6), Vector2(-1.5, 1.0), Vector2(-0.5, 1.2),
	Vector2(5.5, 1.2), Vector2(6.6, 1.1), Vector2(7.2, 0.7),
]

@export var altitude_m := 0.0
@export_range(0.0, 1.0) var rotor_spin := 0.35   ## 0 = stopped, 1 = flight speed
## Shown blade speed at full spin. The real rotor turns ~4.3 times a second,
## which strobes at 60 frames a second, so the blades are shown slower and
## the blur disc carries the rest.
@export var full_spin_rev_per_s := 1.6

var _rotor_angle := 0.0
var _part_shadows: Array[Sprite2D] = []   ## one per SHADOW_PARTS entry
var _rotor_shadow: Sprite2D
var _disc_shadow: Node2D
var _pilots: Array[Sprite2D] = []
var _pilot_moods: Array[Dictionary] = []   ## per pilot: phases, glance state
var _pilot_time := 0.0
var _rng := RandomNumberGenerator.new()

@onready var _shadows: CanvasGroup = $Shadows
@onready var _body: Sprite2D = $Body
@onready var _rotor: Sprite2D = $Rotor
@onready var _disc: Node2D = $RotorDisc


func _ready() -> void:
	_add_cockpit()
	for part in SHADOW_PARTS:
		var shadow := Sprite2D.new()
		shadow.texture = part.texture
		shadow.scale = Vector2.ONE * SHADOW_TEXEL_PX
		var sweep := ShaderMaterial.new()
		sweep.shader = SHADOW_SWEEP
		shadow.material = sweep
		_shadows.add_child(shadow)
		_part_shadows.append(shadow)
	_disc_shadow = Node2D.new()
	_disc_shadow.draw.connect(_draw_disc_shadow)
	_shadows.add_child(_disc_shadow)
	_rotor_shadow = Sprite2D.new()
	_rotor_shadow.texture = _rotor.texture
	_rotor_shadow.modulate = Color.BLACK
	_shadows.add_child(_rotor_shadow)
	_disc.draw.connect(_draw_disc)

	var hull := PackedVector2Array()
	for point: Vector2 in HULL_M:
		hull.append(point * SCALE * World.PX_PER_M)
	$Hull/Outline.polygon = hull


func _process(delta: float) -> void:
	_move_pilots(delta)
	_rotor_angle = wrapf(_rotor_angle + rotor_spin * full_spin_rev_per_s * TAU * delta, 0.0, TAU)
	var px := World.PX_PER_M
	var grow := 1.0 + altitude_m * CLIMB_SCALE_PER_M
	var mast := MAST_M * px * grow

	_body.scale = Vector2.ONE * grow
	_rotor.position = mast
	_rotor.rotation = _rotor_angle
	_rotor.scale = Vector2.ONE * grow
	_rotor.modulate.a = 1.0 - 0.55 * rotor_spin   # blades blur out as they speed up
	_disc.position = mast
	_disc.scale = Vector2.ONE * grow
	_disc.queue_redraw()

	# Shadows: the sun's direction is fixed on screen, so undo this node's
	# rotation to get it in local coordinates.
	var sun := World.SUN_DIR.rotated(-global_rotation) * tan(deg_to_rad(World.SUN_TILT_DEG)) * px
	_shadows.self_modulate.a = SHADOW_ALPHA
	for i in SHADOW_PARTS.size():
		var part: Dictionary = SHADOW_PARTS[i]
		var shadow := _part_shadows[i]
		shadow.position = sun * (altitude_m + part.low_m)
		# How far the shadow moves from the part's lowest to highest point,
		# in the outline's own texture pixels.
		var sweep: Vector2 = sun * (part.high_m - part.low_m) / SHADOW_TEXEL_PX
		(shadow.material as ShaderMaterial).set_shader_parameter("sweep", sweep)
	var rotor_shadow_at := MAST_M * px + sun * (altitude_m + ROTOR_HEIGHT_M)
	_rotor_shadow.position = rotor_shadow_at
	_rotor_shadow.rotation = _rotor_angle
	_rotor_shadow.modulate.a = 1.0 - 0.6 * rotor_spin
	_disc_shadow.position = rotor_shadow_at
	_disc_shadow.queue_redraw()


## The pilots, then the glass over them, as children of the body so they
## turn and grow with it.
func _add_cockpit() -> void:
	_rng.randomize()
	for side in [1.0, -1.0]:
		var pilot := Sprite2D.new()
		pilot.texture = PILOT_TEXTURE
		pilot.position = Vector2(PILOT_M.x, PILOT_M.y * side) * World.PX_PER_M
		_body.add_child(pilot)
		_pilots.append(pilot)
		_pilot_moods.append({
			phases = [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU],
			glance = 0.0,          # current extra turn (radians)
			glance_to = 0.0,       # where the glance is heading
			timer = _rng.randf_range(PILOT_GLANCE_EVERY_S.x, PILOT_GLANCE_EVERY_S.y),
		})
	var glass := Sprite2D.new()
	glass.texture = GLASS_TEXTURE
	_body.add_child(glass)


## A slow sway and shift in the seat, plus now and then a glance to one side
## (each pilot on its own timer), so the crew looks alive.
func _move_pilots(delta: float) -> void:
	_pilot_time += delta
	var t := _pilot_time
	for i in _pilots.size():
		var mood: Dictionary = _pilot_moods[i]
		mood.timer -= delta
		if mood.timer <= 0.0:
			if mood.glance_to == 0.0:
				var turn := deg_to_rad(_rng.randf_range(PILOT_GLANCE_DEG.x, PILOT_GLANCE_DEG.y))
				mood.glance_to = turn if _rng.randf() < 0.5 else -turn
				mood.timer = _rng.randf_range(PILOT_GLANCE_S.x, PILOT_GLANCE_S.y)
			else:
				mood.glance_to = 0.0
				mood.timer = _rng.randf_range(PILOT_GLANCE_EVERY_S.x, PILOT_GLANCE_EVERY_S.y)
		mood.glance = lerpf(mood.glance, mood.glance_to, 1.0 - exp(-PILOT_TURN_RATE * delta))
		var ph: Array = mood.phases
		var sway := deg_to_rad(PILOT_SWAY_DEG) * (0.7 * sin(t * 0.6 + ph[0]) + 0.3 * sin(t * 1.7 + ph[1]))
		var shift := Vector2(sin(t * 0.45 + ph[2]), sin(t * 0.8 + ph[1])) * PILOT_SHIFT_M
		var pilot := _pilots[i]
		pilot.rotation = sway + mood.glance
		pilot.position = (Vector2(PILOT_M.x, PILOT_M.y * (1.0 if i == 0 else -1.0)) + shift) * World.PX_PER_M


## The spinning rotor's blur: a faint dark disc with a yellow ring where the
## blade tips' caution bands sweep round.
func _draw_disc() -> void:
	if rotor_spin <= 0.0:
		return
	var px := World.PX_PER_M
	_disc.draw_circle(Vector2.ZERO, ROTOR_RADIUS_M * px, Color(0.05, 0.05, 0.05, 0.22 * rotor_spin))
	_disc.draw_arc(Vector2.ZERO, ROTOR_RADIUS_M * px - 0.72 * SCALE * px, 0.0, TAU, 96,
			Color(0.9, 0.75, 0.15, 0.14 * rotor_spin), 0.25 * SCALE * px, true)


func _draw_disc_shadow() -> void:
	if rotor_spin <= 0.0:
		return
	_disc_shadow.draw_circle(Vector2.ZERO, ROTOR_RADIUS_M * World.PX_PER_M, Color(0, 0, 0, 0.3 * rotor_spin))
