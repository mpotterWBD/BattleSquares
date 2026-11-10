extends CharacterBody2D
## The supply truck (scenes/supply_truck.tscn; art by
## blender/scripts/supply_truck.py, after Mike's reference photos): an 8x8
## truck, 4.3 m long, with a loader crane between the cab and a flatbed
## that takes two pallets. The crane and the bed don't do anything yet
## (2026-11-03: driving first). Rotate this node to set its heading (the
## nose points along +x).
##
## Driving (Mike, 2026-11-03), car style: walk up to the driver's door (on
## its left, DOOR_M) and a green F shows; F gets in. Getting in plays out
## (Mike: it has to feel immersive): the player's square walks itself to the
## door (player.gd `walk_to`), the door swings open (about its hinge at its
## front edge, DOOR_OPEN_DEG in DOOR_S), the square steps up into the cab (out
## of sight under the roof, to the driver's seat, SEAT_M), and the door shuts;
## then W starts it (below). The square is hidden and switched off in there, riding in
## the seat (so the camera and command mode follow the truck), and nothing
## hits it. Then:
##   W  forward: speeds up to `top_speed_mps` (`accel_mps2`)
##   S  brakes, then reverses, up to `reverse_speed_mps`
##   A / D  steer the front wheels, up to `max_steer_deg`, `steer_dps`
##          to turn them; they straighten again let go. It turns like a
##          truck, about its rear axles (REAR_AXLE_X_M, WHEELBASE_M): only
##          while rolling, and tighter the more they're turned.
## Let go of W and S and it rolls to a stop (`coast_mps2`). It stops dead
## against anything solid (squares, crates, sandbags, the tower's legs) and at
## the edge of the play area, and won't turn into something. F again, once
## it's stopped, gets out the same way backwards: the door opens, the square
## steps down out of the cab to beside it, the door shuts. If something's
## there, by the other door (the same door, mirrored); if both are blocked,
## out the back at once. A squadmate takes either seat (squadmate.gd order_ride(); command.gd: the side
## of the cab clicked, two selected fill both). With one at the wheel it drives itself where it's sent:
## select the truck (a click on it with nobody selected) and click the ground (vehicle_ai.gd: by road,
## on the right-hand lane, forward or backing into spots); the player always drives by hand.
##
## Sound (Mike's recordings, assets/sfx/supply_truck/): the door opens with a
## click and slams shut. In, the engine's off until the first press of W
## (Mike: the ignition doesn't start until you press W); then it starts (the
## starter, it catching, settling to idle), and only `boot_pause_s` after
## that will it move (Mike: it needs time to boot up after ignition).
## Running, one engine loop (a long seamless one: Mike, the short ones sounded
## periodic) climbs in pitch and volume with speed (`speed_pitch`,
## `speed_gain_db`); getting out, it's switched off (its stop sound, the
## loop fading).
##
## The tyres are drawn under the squares and the body (TYRE_Z), so the square
## getting in goes over them and under the cab; the front two axles' turn
## with the steering.
##
## Solid like the other big things (layer 1): squares go round it, bullets
## stop in it (cover.gd: it stops every shot) with sparks and the clang of a
## round into steel (bullet_hit()), and sandbags (layer 4) stop it.
##
## Its sprites are lit from straight overhead so it can face any way; the
## shadows are drawn here, as the helicopter's (helicopter.gd): an outline
## per group of parts at its own heights (SHADOW_PARTS), each swept by
## shaders/shadow_sweep.gdshader across those heights, toward the sun. The
## crane's and the doors' turn with them.

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const HitSparks = preload("res://scripts/hit_sparks.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")
const SHADOW_SWEEP := preload("res://shaders/shadow_sweep.gdshader")
const VehicleAI = preload("res://scripts/vehicle_ai.gd")
const BattleLog = preload("res://scripts/battle_log.gd")

## Each body part group's shadow outline (supply_truck.py SHADOW_GROUPS) and
## its lowest and highest points above the ground (m).
const SHADOW_PARTS := [
	{texture = preload("res://assets/vehicles/supply_truck_shadow_low.png"), low_m = 0.0, high_m = 0.95},
	{texture = preload("res://assets/vehicles/supply_truck_shadow_headboard.png"), low_m = 0.8, high_m = 1.22},
	{texture = preload("res://assets/vehicles/supply_truck_shadow_cab.png"), low_m = 0.3, high_m = 1.88},
]
## The crane turret's, round its slewing axis (it turns with the turret).
const CRANE_SHADOW := {texture = preload("res://assets/vehicles/supply_truck_shadow_crane.png"), low_m = 0.86, high_m = 2.08}
## A door's, round its middle (it swings with the door).
const DOOR_SHADOW := {texture = preload("res://assets/vehicles/supply_truck_shadow_door.png"), low_m = 0.76, high_m = 1.64}
const DOOR_TEXTURE := preload("res://assets/vehicles/supply_truck_door.png")
## The tyres are their own sprite (the left front one, supply_truck.py), drawn
## TYRE_Z, under the squares (0) and the body (3): one getting in goes over
## them and under the cab (Mike, 2026-11-03). The front two axles' turn as it
## steers. Axles along the truck (AXLES_X), and the tyres' middles out either side.
const TYRE_TEXTURE := preload("res://assets/vehicles/supply_truck_tyre.png")
const AXLES_X_M := [1.70, 0.98, -0.90, -1.62]
const STEERED_AXLES := 2
const TYRE_Y_M := 0.6
const TYRE_Z := -1

## Sounds, cut from Mike's recordings (blender/scripts/cut_truck_sounds.py, from
## the sections in `sound_cuts`, whose Cut Sounds button re-cuts them):
## the door opening and slamming, and the engine: starting (the starter, the
## engine catching, settling to idle), running (one ~7 s loop of its idle,
## joined where the waveforms line up, so it doesn't repeat audibly), and stopping.
const SOUND_DOOR_OPEN := preload("res://assets/sfx/supply_truck/door_open.wav")
const SOUND_DOOR_SLAM := preload("res://assets/sfx/supply_truck/door_slam.wav")
const SOUND_START := preload("res://assets/sfx/supply_truck/truck_start.wav")
const SOUND_IDLE := preload("res://assets/sfx/supply_truck/truck_idle.wav")
const SOUND_STOP := preload("res://assets/sfx/supply_truck/truck_stop.wav")
const ENGINE_AT_M := Vector2(0.8, 0.0)   ## the engine module, where its sound comes from
const START_BLEND_S := 0.3          ## the start's last stretch cross-fades into the idle loop
## The driving loop (truck_run.wav: only if the sound cuts made one) blends in
## over this much of the way to top speed, from the first to the second.
const SOUND_RUN_PATH := "res://assets/sfx/supply_truck/truck_run.wav"
const RUN_BLEND := Vector2(0.15, 0.6)
const LOOP_FADE_S := 0.25           ## the loop fades out this fast when it stops
const IDLE_WANDER := 0.015         ## the idle loop's pitch wanders this much either way, slowly
const HEARING_M := 45.0             ## heard out to this far

## The engine (`_engine`): off; starting (the start sound playing, then
## `boot_pause_s` before it can drive); running.
enum EngineState { OFF, STARTING, RUNNING }
const SHADOW_TEXEL_PX := 2.0        ## outlines are rendered at half the game's pixel density
const SHADOW_ALPHA := 0.71          ## the squares' shadows' darkness
const CLIMB_SCALE_PER_M := 0.01     ## slung up in the air, drawn this much bigger a metre (as helicopter.gd)

## Its size (metres, over the tyres) and layout, from supply_truck.py.
const LENGTH_M := 4.3
const WIDTH_M := 1.37
const CRANE_X_M := 0.23             ## the crane's slewing axis, ahead of the middle (CRANE_X_M)
const REAR_AXLE_X_M := -1.26        ## the rear axles' middle (AXLES_X): it turns about here
const WHEELBASE_M := 2.6            ## from there to the front axles' middle
## The doors (supply_truck.py DOOR_X, DOOR_T): the left (driver's) door's
## hinge, at its front edge in the middle of its thickness (the right's is
## mirrored), and its middle, back from there.
const DOOR_HINGE_M := Vector2(1.89, -0.575)
const DOOR_MIDDLE_M := Vector2(-0.31, 0.0)
const DOOR_OPEN_DEG := 75.0         ## swung open this far
const DOOR_S := 0.45                ## taking this long to open or shut
## Outside the driver's door (behind it once it's open), where the player
## gets in and out, and the driver's seat, under the roof (the right side's
## are mirrored).
const DOOR_M := Vector2(1.5, -0.95)
const SEAT_M := Vector2(1.55, -0.28)
const DOOR_REACH_M := 0.9           ## the player this close to the door can get in
## Outside the open door's swing (the left side's; the right's is its mirror): a rider
## waits here for the door to open and walks off here before it shuts, so the door
## never sweeps through them (Mike, 2026-11-04: nothing clips). SWEEP_CLEAR_M: at
## least this far from the hinge is out of it (the door's 0.62 m, a square's corner 0.28 m).
const CLEAR_M := Vector2(1.15, -1.3)
const SWEEP_CLEAR_M := 0.95
const LEG_M := 0.15                 ## on the way, this close to a stop is through it (no slowing to a halt at each)
const ARRIVE_M := 0.06             ## walking itself in or out, this close is there
const WALK_GIVE_UP_S := 3.0         ## walking to the door and not there by then (blocked): it gives up
const STOPPED_MPS := 0.2            ## it has to be this slow to get out
const SQUAD_WALK_GIVE_UP := 4.0    ## a squadmate walking round to the door gets this many times WALK_GIVE_UP_S
const ROUND_M := 0.6               ## walking round the truck to a door, this far off its corners
const CORNER_M := 0.3              ## ...a corner this close is passed
const PROMPT_ALPHA := 0.55          ## the green F, see-through as at the radio desk

## The crane (Mike, 2026-11-04), with the order Crane in command mode: it
## picks up crates from two squares beside the bed, one each side (PICKUP_*; drawn in
## command mode, the red boxes). Selecting
## Crane is when it deploys: the passenger gets out (once it's stopped), walks
## to the crane's controls (STATION_M, on the passenger's side), and after
## station_hold_s standing there the stabilisers come down. They stay down
## until Crane's deselected or the driver tries to drive off, when the boom
## goes in, the stabilisers come up and the operator gets back in, and only then
## can it move. Clicking a crate in a square while it's deployed: the turret
## turns to it and a boom slides out of the arm (ARM_M long stowed), it's
## lifted, swung round to the bed and set down on the furthest back free spot
## (SLOT_X_M) first. Holding Crane in command mode gives 1 or 2 boxes and a ghost on the
## side of the truck the mouse is on: a click sets the nearest crates down there (crane_drop()). The truck can't move meanwhile.
const CRANE_AXIS_M := Vector2(CRANE_X_M, 0.0)
const ARM_M := 1.0                  ## the stowed arm's tip, ahead of the axis: the boom slides out from here
## The two squares beside the bed (either side, Mike's blue boxes, 2026-11-04): a crate has to be
## in one (its middle) for the crane to take it. Along the truck from PICKUP_X_M.x to .y, out from
## its middle PICKUP_Y_M.x to .y. Crates go down again on the ground at DROP_Y_M out, at the bed
## spot they came from along the truck (the ghost, command.gd).
const PICKUP_X_M := Vector2(-2.54, 0.32)
const PICKUP_Y_M := Vector2(0.6, 1.95)
const DROP_Y_M := 1.3
const STATION_M := Vector2(0.75, 1.12)  ## where the operator stands: beside the crane's controls on the passenger's side (Mike's blue box, 2026-11-04), clear of the stabiliser's foot
const SLOT_X_M := [-1.53, -0.61]    ## the bed's two pallet spots along the truck (supply_truck.py), furthest back first
const BED_Z_M := 0.80               ## the deck's height: a crate on it is held this high
const CARRY_M := 1.9                ## a crate on the hook is held this high
const STAB_OUT_M := 0.86            ## the stabilisers' feet, out either side of the middle
const STATION_GIVE_UP_S := 8.0      ## the operator walking to the controls and not there by then: it gives up
const STATION_REACH_M := 0.15       ## this close to the spot is there
## What must be clear beside the passenger's door for the operator to get out
## (Mike's blue box, 2026-11-04): this box, its middle and size in metres, on the
## passenger's side. Something solid in it (or at the controls) and the job's
## cancelled; he doesn't go round the back instead.
const EXIT_BOX_M := Vector2(1.54, 0.945)
const EXIT_BOX_SIZE_M := Vector2(1.24, 0.51)
## The flatbed's deck (supply_truck.py BED_*): where the crates' shadows fall on it.
const BED_BACK_X_M := -2.05
const BED_FRONT_X_M := -0.05
const BED_W_M := 1.2
const CRATE_PICK_PX := 8.0          ## a click this far off a crate's pallet still picks it
const REACH_RING := Color(0.95, 0.27, 0.22)
const BEAM_A := Color("#56653a")    ## the boom: the arm's own colour, then the sliding steel
const BEAM_B := Color("#8b9197")
const BEAM_EDGE := Color("#232a1b")
const STAB_BEAM := Color("#5a6b3c")
const STAB_PAD := Color("#2f3236")
const STAB_PAD_EDGE := Color("#70767c")

## Getting in and out, step by step (each Seat's `step`).
enum Step { NONE, TO_DOOR, OPENING, STEP_IN, CLOSING, OPENING_OUT, STEP_OUT, CLOSING_OUT }
## The crane's operation: the passenger waiting for the truck to stop, walking
## to the controls, standing there a moment, the stabilisers coming down,
## working through the jobs, stowing, and the operator walking back in.
enum CranePhase { IDLE, WAIT_STOP, WALKING, SETTLING, DEPLOYING, WORKING, STOWING, RETURNING }
## One job's steps: the boom out to the load, the lift, the swing round, setting it down.
enum JobStep { REACH, LIFT, SWING, LOWER }

@export_group("Driving")
## Flat out, forward (metres per second; the player runs at 3.2).
@export_range(1.0, 15.0, 0.1, "suffix:m/s") var top_speed_mps := 6.0
@export_range(0.5, 8.0, 0.1, "suffix:m/s") var reverse_speed_mps := 2.5
## Speeding up, with W (or S, reversing).
@export_range(0.5, 10.0, 0.1, "suffix:m/s²") var accel_mps2 := 2.5
## Braking, with the other one.
@export_range(1.0, 20.0, 0.1, "suffix:m/s²") var brake_mps2 := 7.0
## Rolling to a stop with neither.
@export_range(0.1, 10.0, 0.1, "suffix:m/s²") var coast_mps2 := 1.5
## How far the front wheels turn, and how fast.
@export_range(5.0, 45.0, 1.0, "suffix:°") var max_steer_deg := 32.0
@export_range(10.0, 360.0, 5.0, "suffix:°/s") var steer_dps := 110.0
## After the engine's start sound, this long before it'll move (Mike: it
## needs time to boot up after ignition).
@export_range(0.0, 5.0, 0.1, "suffix:s") var boot_pause_s := 0.6

@export_group("Sound")
@export_range(-30.0, 12.0, 0.5, "suffix:dB") var engine_volume_db := 0.0
@export_range(-30.0, 12.0, 0.5, "suffix:dB") var door_volume_db := 0.0
## The engine's pitch climbs this much at top speed (and a little with the
## throttle down), so it sounds like it's working harder...
@export_range(0.0, 1.0, 0.05) var speed_pitch := 0.3
## ...and it gets this much louder.
@export_range(0.0, 12.0, 0.5, "suffix:dB") var speed_gain_db := 4.0
## The driving loop's volume, against the running one (when there is one: Sound Cuts > Engine Driving).
@export_range(-24.0, 12.0, 0.5, "suffix:dB") var driving_volume_db := -4.0
## Which sections of the recordings the sounds are cut from (times in
## seconds), with a Cut Sounds button that re-cuts them (truck_sound_cuts.gd).
## Shared by every truck: it's its own file. Only the editor uses it.
@export var sound_cuts: TruckSoundCuts = preload("res://assets/sfx/supply_truck/truck_sound_cuts.tres")

@export_group("Crane")
## How far from its axis the boom can reach (the squares beside the bed are inside it).
@export_range(1.0, 6.0, 0.1, "suffix:m") var crane_reach_m := 3.6:
	set(value):
		crane_reach_m = value
		if _reach:
			_reach.queue_redraw()
## The turret turning, the boom sliding out and in (Mike, 2026-11-04: a lot slower, like a real one).
@export_range(5.0, 360.0, 1.0, "suffix:°/s") var crane_slew_dps := 22.0
@export_range(0.1, 5.0, 0.05, "suffix:m/s") var boom_mps := 0.4
## Lifting a crate, and setting it down.
@export_range(0.2, 8.0, 0.1, "suffix:s") var lift_s := 2.5
## The operator standing at the controls this long before the stabilisers come down.
@export_range(0.0, 3.0, 0.1, "suffix:s") var station_hold_s := 0.5
## The stabilisers coming down (or up).
@export_range(0.2, 10.0, 0.1, "suffix:s") var stabilizer_s := 4.0

## A seat in the cab and whoever's in it or getting in or out of it: the
## driver's (side -1, the left) or the passenger's (1, the right).
class Seat:
	var side := -1
	var occupant = null   ## sitting in it, the door shut behind them
	var rider = null      ## getting in or out of it
	var door := 0         ## the door they're using: 0 the left, 1 the right
	var step := 0         ## (a Step)
	var leg := 0          ## stepping in or out: 0 through the door's gap, 1 the rest of the way
	var operate := false  ## getting out to run the crane (the passenger's): it's not freed to its own AI, the truck keeps it
	var step_s := 0.0     ## time into this step
	var layer := 1        ## the rider's collision layer and mask, while they're off
	var mask := 1
	var want_out := false ## the passenger's been told to get out: once it's stopped
	var route := []       ## getting in: the way to the door still to go (local metres, the door last)
	func _init(s: int) -> void:
		side = s
		door = 0 if s < 0 else 1

## Who's driving (the player), or null. Set once the door's shut behind them.
var driver:
	get:
		return _seats[0].occupant
## Whether the player's at the wheel, or a squadmate (`ai_driver`: it drives by vehicle_ai.gd).
var player_driving: bool:
	get:
		return driver != null and driver.is_in_group("player")
var ai_driver:
	get:
		var d = driver
		return d if d != null and not d.is_in_group("player") else null
## Who's riding as the passenger (a squadmate), or null.
var passenger:
	get:
		return _seats[1].occupant
## Its speed along its heading (m/s; backwards is negative).
var speed := 0.0
## The front wheels' angle (radians; positive is to the right).
var steer := 0.0
## Slung under a helicopter (sling_drop.gd): off every collision layer, not
## to be got into, drawn bigger by its height and its shadow out below.
var airborne := false
## Its height above the ground while slung (m).
var altitude_m := 0.0:
	set(value):
		altitude_m = value
		scale = Vector2.ONE * (1.0 + altitude_m * CLIMB_SCALE_PER_M)

var _seats: Array[Seat] = [Seat.new(-1), Seat.new(1)]
var _door_open := [0.0, 0.0]        ## each door (left, right): 0 shut .. 1 open
var _doors: Array[Node2D] = []      ## their hinges (the sprite under each)
var _door_shadows: Array[Sprite2D] = []
var _part_shadows: Array[Sprite2D] = []
var _crane_shadow: Sprite2D
var _prompt_at: Node2D              ## the green F's spot by the door, kept upright
var _tyres: Array[Sprite2D] = []    ## axle by axle, left then right
var _engine := EngineState.OFF
var _engine_s := 0.0                ## time since the engine was started
var _start: AudioStreamPlayer2D
var _idle: AudioStreamPlayer2D
var _run: AudioStreamPlayer2D = null   ## the driving loop (null: none)
var _stop: AudioStreamPlayer2D
var _door_sound: AudioStreamPlayer2D
var _loop_level := 0.0              ## the engine loop's volume, 0..1 (fading in from the start, out when it stops)

## The crane. `_armed`: the Crane order's been given and a click on a crate (or on
## ground) in the circle is a job. `_jobs` are those still to do, `_job` the one
## in hand ({kind "load" / "unload", crate, from, to (local metres), slot, step,
## t, h0, h1}); `_bed` the crate on each of the bed's two spots (SLOT_X_M).
var _armed := false
var _ai: RefCounted = null          ## the driver's brain (vehicle_ai.gd), made when a squadmate's first told where to go
var _cphase := CranePhase.IDLE
var _operator = null                 ## the squadmate running it (out of the cab, or being fetched back in)
var _jobs: Array = []
var _job = null
var _bed: Array = [null, null]
var _stab := 0.0                     ## the stabilisers: 0 up .. 1 down
var _slew := 0.0                     ## the turret's turn from the truck's heading (radians)
var _boom_ext := 0.0                 ## how far the boom's out past the stowed arm (m)
var _crane_t := 0.0                  ## time in the current phase
var _want_stow := false              ## to be put away as soon as nothing's on the hook
var _rig: Node2D                     ## the turret (the sprite) and the boom, turning about the axis
var _boom: Node2D
var _boom_shadow: Node2D
var _stabs: Node2D
var _bed_shadow: CanvasGroup         ## the crates' shadows on the deck
var _bed_shadow_shape: Node2D
var _reach: Node2D                   ## the circle
var _sun := Vector2.ZERO             ## the sun's way, px per metre of height, in this node's frame (_process)

@onready var _shadows: CanvasGroup = $Shadows
@onready var _crane: Sprite2D = $Crane


func _ready() -> void:
	World.register_controls()
	add_to_group("interactables")   # F at the driver's door (player.gd interact_target())
	add_to_group("vehicles")
	for part in SHADOW_PARTS:
		_part_shadows.append(_add_shadow(part.texture))
	_crane_shadow = _add_shadow(CRANE_SHADOW.texture)
	for side in [-1, 1]:
		var hinge := Node2D.new()
		hinge.position = _side_m(DOOR_HINGE_M, side) * World.PX_PER_M
		var door := Sprite2D.new()
		door.texture = DOOR_TEXTURE
		door.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		door.scale = Vector2.ONE * 0.5   # rendered at 2x
		door.position = DOOR_MIDDLE_M * World.PX_PER_M
		door.flip_v = side > 0           # the right door is the left one mirrored
		hinge.add_child(door)
		hinge.z_index = 3                # with the body, after it: over the cab's side
		hinge.visible = false
		add_child(hinge)
		_doors.append(hinge)
		var shadow := _add_shadow(DOOR_SHADOW.texture)
		shadow.flip_v = side > 0
		shadow.visible = false
		_door_shadows.append(shadow)
	_prompt_at = Node2D.new()
	_prompt_at.position = DOOR_M * World.PX_PER_M
	add_child(_prompt_at)
	_prompt_at.add_child(UiStyle.pad_key("F", Color(World.COMMAND_COLOR, PROMPT_ALPHA)))
	for x: float in AXLES_X_M:
		for side in [-1, 1]:
			var tyre := Sprite2D.new()
			tyre.texture = TYRE_TEXTURE
			tyre.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tyre.scale = Vector2.ONE * 0.5   # rendered at 2x
			tyre.position = Vector2(x, side * TYRE_Y_M) * World.PX_PER_M
			tyre.flip_v = side > 0           # the hub outside on both sides
			tyre.z_index = TYRE_Z
			add_child(tyre)
			_tyres.append(tyre)
	_start = _add_sound(SOUND_START, false)
	_idle = _add_sound(SOUND_IDLE, true)
	if ResourceLoader.exists(SOUND_RUN_PATH):
		_run = _add_sound(load(SOUND_RUN_PATH), true)
	_stop = _add_sound(SOUND_STOP, false)
	_door_sound = _add_sound(SOUND_DOOR_OPEN, false)
	_build_crane()


## The crane's parts: the turret's sprite under a node that turns about the
## slewing axis (z 4: over the body and the crates on the bed), the boom that
## slides out of its arm (under the arm's sprite), the stabilisers on the
## ground beside the pedestal, the boom's shadow, and the circle of its reach.
func _build_crane() -> void:
	_rig = Node2D.new()
	_rig.position = _crane.position
	_rig.z_index = 4
	add_child(_rig)
	_boom = Node2D.new()
	_boom.draw.connect(_draw_boom)
	_rig.add_child(_boom)
	_crane.reparent(_rig, true)   # (its place and z are now the rig's)
	_crane.z_index = 0
	_stabs = Node2D.new()
	_stabs.z_index = 3
	_stabs.draw.connect(_draw_stabs)
	add_child(_stabs)
	# The crates' shadows on the deck: over the body, under the crates themselves (they're
	# added to the truck after this, at the same level), one group so overlaps aren't doubly dark.
	_bed_shadow = CanvasGroup.new()
	_bed_shadow.z_index = 3
	_bed_shadow.self_modulate = Color(1, 1, 1, SHADOW_ALPHA)
	_bed_shadow_shape = Node2D.new()
	_bed_shadow_shape.draw.connect(_draw_bed_shadow)
	_bed_shadow.add_child(_bed_shadow_shape)
	add_child(_bed_shadow)
	_boom_shadow = Node2D.new()
	_boom_shadow.draw.connect(_draw_boom_shadow)
	_shadows.add_child(_boom_shadow)
	_reach = Node2D.new()
	_reach.z_as_relative = false
	_reach.z_index = 20
	_reach.visible = false
	_reach.draw.connect(_draw_reach)
	add_child(_reach)


## A sound player at the engine (`loop`: the stream set to loop, as
## helicopter.gd's), not playing yet.
func _add_sound(stream: AudioStreamWAV, loop: bool) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	if loop:
		var looped := stream.duplicate() as AudioStreamWAV
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		looped.loop_end = int(stream.get_length() * stream.mix_rate)
		stream = looped
	player.stream = stream
	player.max_distance = HEARING_M * World.PX_PER_M
	player.position = ENGINE_AT_M * World.PX_PER_M
	add_child(player)
	return player


## `m` (the left side's, metres) for side -1 (left) or 1 (the right: mirrored).
static func _side_m(m: Vector2, side: int) -> Vector2:
	return Vector2(m.x, m.y * -side)


func _add_shadow(texture: Texture2D) -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.texture = texture
	shadow.scale = Vector2.ONE * SHADOW_TEXEL_PX
	var sweep := ShaderMaterial.new()
	sweep.shader = SHADOW_SWEEP
	shadow.material = sweep
	_shadows.add_child(shadow)
	return shadow


func _physics_process(delta: float) -> void:
	if _ai != null:
		_ai.think()   # (a parking search: another slice of it, and its way taken up once it's done)
	var throttle := 0.0
	var turn := 0.0
	# With the crane's operator out (and the stabilisers coming down or down) it's going nowhere.
	var locked := _cphase != CranePhase.IDLE and _cphase != CranePhase.WAIT_STOP
	var ai_speed := NAN   # (set when a squadmate's driving it: where its speed should be going)
	if ai_driver != null and _ai != null and _ai.active():
		if _engine == EngineState.OFF:
			_start_engine()
		if _engine == EngineState.RUNNING and not locked:
			var cmd: Dictionary = _ai.tick(delta)
			ai_speed = cmd.speed
			turn = clampf(cmd.steer / deg_to_rad(max_steer_deg), -1.0, 1.0)
		else:
			ai_speed = 0.0
	elif ai_driver != null:
		ai_speed = 0.0   # (nothing to do: it stays put)
	if player_driving and not World.debug:
		if _engine == EngineState.OFF and (Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")):
			_start_engine()   # W or S turns the ignition (Mike, 2026-11-04)
		if _engine == EngineState.RUNNING and not locked:   # (not while it's starting up)
			throttle = Input.get_axis("move_down", "move_up")
		if not locked:
			turn = Input.get_axis("move_left", "move_right")
		elif _cphase != CranePhase.STOWING and _cphase != CranePhase.RETURNING \
				and (Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")):
			# Driving off: the crane's put away first (the stabilisers up, the operator back
			# in), and only then does it move (Mike, 2026-11-04).
			_armed = false
			_end_crane()
	if is_nan(ai_speed):
		_update_speed(throttle, delta)
	else:   # the AI's: speeds up or brakes to the speed it wants
		var braking := absf(ai_speed) < absf(speed) or ai_speed * speed < 0.0
		speed = move_toward(speed, ai_speed, (brake_mps2 if braking else accel_mps2) * delta)
	if locked:
		speed = 0.0
	var max_steer := deg_to_rad(max_steer_deg)
	var steer_rate := deg_to_rad(steer_dps) * (1.0 if turn != 0.0 else 1.5)   # (straightens a little quicker)
	steer = move_toward(steer, turn * max_steer, steer_rate * delta)
	if speed != 0.0:
		_drive(delta)
	for seat in _seats:
		if seat.occupant:   # riding in it
			seat.occupant.global_position = to_global(_side_m(SEAT_M, seat.side) * World.PX_PER_M)
			if seat.want_out and seat.step == Step.NONE and absf(speed) <= STOPPED_MPS:
				_get_out(seat)
		if seat.step != Step.NONE:
			_tick_getting_in_or_out(seat, delta)
	_tick_crane(delta)
	_tick_engine(delta, throttle)
	_turn_tyres()


## The front two axles' tyres turned with the steering, each as much as it
## needs to roll round the same middle (the nearer the rear axles, the less).
func _turn_tyres() -> void:
	for a in STEERED_AXLES:
		var lever: float = AXLES_X_M[a] - REAR_AXLE_X_M
		var angle := atan(lever * tan(steer) / WHEELBASE_M)
		_tyres[a * 2].rotation = angle
		_tyres[a * 2 + 1].rotation = angle


# ------------------------------------------------------------------ engine --

## The ignition: the first press of W with the driver in (Mike: the start sound,
## then a pause to boot up before it moves; held, it rolls off once it has).
func _start_engine() -> void:
	_engine = EngineState.STARTING
	_engine_s = 0.0
	_stop.stop()
	_start.volume_db = engine_volume_db
	_start.play()


## Stopped as the driver gets out: the stop sound, the loops fading out.
func _stop_engine() -> void:
	if _engine == EngineState.OFF:
		return
	_engine = EngineState.OFF
	if _start.playing:
		_start.stop()
	_stop.volume_db = engine_volume_db
	_stop.play()


## Starting: the start sound plays; over its last START_BLEND_S the idle loop
## fades in under it; `boot_pause_s` after it ends, it can drive. Running:
## the loop's pitch and volume climbing with speed (and a little with the
## throttle down). Off: the loop fades out.
func _tick_engine(delta: float, throttle: float) -> void:
	_engine_s += delta
	var start_len := SOUND_START.get_length()
	match _engine:
		EngineState.STARTING:
			var blend := clampf((_engine_s - (start_len - START_BLEND_S)) / START_BLEND_S, 0.0, 1.0)
			_loop_level = blend
			_start.volume_db = engine_volume_db + linear_to_db(maxf(1.0 - blend, 0.0001))
			if _engine_s >= start_len + boot_pause_s:
				_engine = EngineState.RUNNING
		EngineState.RUNNING:
			_loop_level = 1.0
		EngineState.OFF:
			_loop_level = move_toward(_loop_level, 0.0, delta / LOOP_FADE_S)
	var work := clampf(absf(speed) / top_speed_mps + 0.25 * absf(throttle), 0.0, 1.0)
	# With a driving loop, it blends in with speed (constant power), its pitch
	# climbing from below its own; without, the running loop alone, pitched up.
	var drive := smoothstep(RUN_BLEND.x, RUN_BLEND.y, work) if _run else 0.0
	# A slow, slight wander in the pitch (two out-of-step swells), so a short
	# loop of a steady idle doesn't sound the same each time round.
	var wander := 1.0 + IDLE_WANDER * (0.6 * sin(_engine_s * 2.7) + 0.4 * sin(_engine_s * 1.13 + 1.0))
	_mix_loop(_idle, _loop_level * cos(drive * PI / 2), engine_volume_db + speed_gain_db * work, (1.0 + speed_pitch * work) * wander)
	if _run:
		_mix_loop(_run, _loop_level * sin(drive * PI / 2), engine_volume_db + driving_volume_db + speed_gain_db * work,
				1.0 - speed_pitch * (1.0 - work))


## The loop at `level` (0..1) of `base_db`, at `pitch`, started when it's heard, stopped when not.
func _mix_loop(player: AudioStreamPlayer2D, level: float, base_db: float, pitch: float) -> void:
	if level <= 0.001:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play(randf() * player.stream.get_length())
	player.volume_db = base_db + linear_to_db(level)
	player.pitch_scale = pitch


## The door opening or slamming, from door `i`.
func _door_noise(sound: AudioStream, i: int) -> void:
	_door_sound.stream = sound
	_door_sound.volume_db = door_volume_db
	_door_sound.position = _doors[i].position
	_door_sound.play()


## W speeds it up forward (braking first if it's going backwards), S the
## other way; neither and it rolls to a stop.
func _update_speed(throttle: float, delta: float) -> void:
	if throttle > 0.0:
		speed = move_toward(speed, top_speed_mps, (brake_mps2 if speed < 0.0 else accel_mps2) * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -reverse_speed_mps, (brake_mps2 if speed > 0.0 else accel_mps2) * delta)
	else:
		speed = move_toward(speed, 0.0, coast_mps2 * delta)


## One tick of driving: the rear axles roll along its heading and it turns
## about them by the front wheels' angle (a bicycle model). Turning into
## something, it doesn't turn; running into something, or out of the play
## area, it stops.
func _drive(delta: float) -> void:
	var px := World.PX_PER_M
	var old_transform := global_transform
	var rear := global_position + Vector2.from_angle(rotation) * REAR_AXLE_X_M * px
	var turn := speed * tan(steer) / WHEELBASE_M * delta
	rotation += turn
	if test_move(global_transform, Vector2.ZERO):
		rotation -= turn
	var heading := Vector2.from_angle(rotation)
	var to := rear + heading * speed * px * delta - heading * REAR_AXLE_X_M * px
	var hit := move_and_collide(to - global_position)
	if hit or not _inside_arena():
		if not hit:
			global_transform = old_transform
		speed = 0.0


## Whether all four of its corners are inside the play area.
func _inside_arena() -> bool:
	var half := Vector2(LENGTH_M, WIDTH_M) / 2.0 * World.PX_PER_M
	for corner in [Vector2(half.x, half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), -half]:
		if not World.ARENA.has_point(global_transform * corner):
			return false
	return true


func _process(_delta: float) -> void:
	# Shadows: the sun's direction is fixed on screen, so undo this node's
	# rotation to get it in local coordinates (as helicopter.gd).
	var sun := World.SUN_DIR.rotated(-global_rotation) * tan(deg_to_rad(World.SUN_TILT_DEG)) * World.PX_PER_M
	_shadows.self_modulate.a = SHADOW_ALPHA
	for i in SHADOW_PARTS.size():
		_place_shadow(_part_shadows[i], SHADOW_PARTS[i], sun, Vector2.ZERO, 0.0)
	_sun = sun
	_rig.rotation = _slew
	_place_shadow(_crane_shadow, CRANE_SHADOW, sun, _rig.position, _rig.rotation)
	_boom.queue_redraw()
	_boom_shadow.queue_redraw()
	_stabs.queue_redraw()
	_bed_shadow_shape.queue_redraw()
	# The reach circle: in command mode, once the Crane order's been given.
	_reach.visible = World.commanding() and (_armed or _cphase != CranePhase.IDLE)
	if altitude_m > 0.0:   # slung under a helicopter: the shadows out on the ground below (sling_drop.gd)
		for shadow in _part_shadows + [_crane_shadow]:
			shadow.position += sun * altitude_m
	for i in 2:
		var door := _doors[i]
		_door_shadows[i].visible = door.visible
		if door.visible:
			_place_shadow(_door_shadows[i], DOOR_SHADOW, sun,
					door.position + (DOOR_MIDDLE_M * World.PX_PER_M).rotated(door.rotation), door.rotation)
	_prompt_at.global_rotation = 0.0   # the F upright whichever way it faces
	var player = _player()
	_prompt_at.get_child(0).visible = (driver == null and _seats[0].step == Step.NONE and player != null and not player.dead
			and player.interact_target() == self)


## A part's shadow with its middle at `at` (local), turned `turn` with it:
## shifted toward the sun by its lowest point's height, and swept (in its
## texture's own pixels) across to its highest.
func _place_shadow(shadow: Sprite2D, part: Dictionary, sun: Vector2, at: Vector2, turn: float) -> void:
	shadow.position = at + sun * part.low_m
	shadow.rotation = turn
	var sweep: Vector2 = sun.rotated(-turn) * (part.high_m - part.low_m) / SHADOW_TEXEL_PX
	(shadow.material as ShaderMaterial).set_shader_parameter("sweep", sweep)
	# A copy every texture pixel along it: the cab's sweep is ~60 px, and the
	# shader's 24 left thin parts (the mirrors' arms) as dotted streaks.
	(shadow.material as ShaderMaterial).set_shader_parameter("steps", clampi(ceili(sweep.length()), 8, 128))


func _player():
	return get_tree().get_first_node_in_group("player")


## For the player's interact_target(): the driver's door, while nobody's
## driving or getting in and the player's within DOOR_REACH_M of it.
func interact_point() -> Variant:
	var player = _player()
	var door := to_global(DOOR_M * World.PX_PER_M)
	if (driver == null and _seats[0].step == Step.NONE and player != null and not airborne
			and player.global_position.distance_to(door) <= DOOR_REACH_M * World.PX_PER_M):
		return door
	return null


## F: in at the driver's door, or (stopped) out again.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo() or World.debug or _seats[0].step != Step.NONE:
		return
	var player = _player()
	if player == null or player.dead:
		return
	if driver == player:
		if absf(speed) <= STOPPED_MPS and get_out():
			get_viewport().set_input_as_handled()
	elif driver == null and not World.commanding() and player.interact_target() == self:
		get_in(player)
		get_viewport().set_input_as_handled()


## A truck order from command mode while the player's driving (command.gd
## VEHICLE_ORDERS: "hatch", "crane"). "crane" gets the crane ready for a click
## on a crate in its circle (_order_crane()); pressed again it's put away;
## false if there's no one in the passenger's seat to run it. The hatch isn't
## worked out yet (Mike, 2026-11-03: the buttons first).
func vehicle_order(id: String) -> bool:
	if id == "crane":
		var done := _order_crane()
		BattleLog.order(self, "crane", ["on" if _armed else "off", _ok(done)])
		return done
	BattleLog.order(self, id, ["unbuilt"])
	print("Truck: %s (not done yet)" % id)
	return true


# ------------------------------------------------------------------- crane --

## The Crane order: ready for a click on a crate (or on ground) in the circle;
## pressed again, put away. False if nobody's there to run it.
func _order_crane() -> bool:
	if _armed:   # deselected: the crane's put away (the job on the hook finishes first)
		_armed = false
		_end_crane()
		return true
	if _cphase == CranePhase.RETURNING:
		return false   # (the operator's still getting back in)
	if _cphase == CranePhase.STOWING and _operator_ok():
		_armed = true   # (changed its mind: the stabilisers go back down)
		_want_stow = false
		_cphase = CranePhase.DEPLOYING
		return true
	if _cphase != CranePhase.IDLE or passenger == null or not _operator_can_get_out():
		return false   # (no one to run it, it's still putting away, or the passenger's side is blocked)
	# Selecting Crane is when it deploys (Mike, 2026-11-04): the operator gets out once it's stopped,
	# and the stabilisers come down. They stay down until Crane's deselected or it's driven off.
	_armed = true
	_want_stow = false
	_cphase = CranePhase.WAIT_STOP
	_crane_t = 0.0
	return true


## The crane's to be put away (Crane deselected, or the driver wants to drive off): the jobs
## still waiting are dropped, the one on the hook is finished, then it stows.
func _end_crane() -> void:
	_jobs.clear()
	if _cphase == CranePhase.WAIT_STOP:
		_crane_cancel()
	elif _cphase in [CranePhase.WALKING, CranePhase.SETTLING, CranePhase.DEPLOYING, CranePhase.WORKING]:
		_want_stow = true


## Whether the Crane order's been given (command.gd _click() sends the clicks here).
func crane_armed() -> bool:
	return _armed


## Whether the crane could be run: someone's riding in the passenger's seat (or
## is out at the controls). The Crane order's only offered then (command.gd).
func crane_available() -> bool:
	return not airborne and (passenger != null or _operator != null)


## How many squadmates are in the truck, driver's seat or passenger's (for the HUD a click on it brings up).
func units_inside() -> int:
	return _seats.filter(func(s): return s.occupant != null and not s.occupant.is_in_group("player")).size()


## Told where to go (command.gd, with the truck selected): a squadmate at the
## wheel drives it there, by road (vehicle_ai.gd). The crane's put away first
## (it won't move until it is). False if nobody but the player's driving it, or
## there's no way to the point.
## With a `heading` (radians: the Park order, command.gd) it ends exactly at
## `point` with its nose that way; NAN, it chooses (nose to a spot by the road,
## or backed in nose out).
func order_drive_to(point: Vector2, heading := NAN) -> bool:
	var done := _drive_to(point, heading)
	BattleLog.order(self, "drive", [point, "-" if is_nan(heading) else "%d" % roundi(rad_to_deg(heading)), ai_driver, _ok(done)])
	return done


func _drive_to(point: Vector2, heading: float) -> bool:
	if ai_driver == null or airborne:
		return false
	if _ai == null:
		_ai = VehicleAI.new(self)
	_armed = false
	_end_crane()
	return _ai.drive_to(point, true, heading)


## Where it's been told to park and which way (world px, radians; heading NAN if it chooses), while it's
## driving there: {at, heading}, or {} (command mode draws a faint ghost there).
func ai_goal() -> Dictionary:
	if _ai == null or not _ai.active():
		return {}
	return {at = _ai.goal, heading = _ai.goal_heading}


## Everyone but the player in it gets out (once it's stopped): the Disperse order with the truck selected.
func dismount_all() -> void:
	BattleLog.order(self, "dismount")
	for seat in _seats:
		if seat.occupant != null and not seat.occupant.is_in_group("player"):
			unload(seat.occupant)


## Stops driving itself (it brakes to a halt where it is).
func ai_stop() -> void:
	if _ai != null:
		_ai.stop()


## "idle", "driving", "arrived" or "failed" (the AI's, for the HUD and tests).
func ai_status() -> String:
	return _ai.status if _ai != null else "idle"


## The AI's planned path in world px (command mode draws it while the truck's selected).
func ai_path_px() -> PackedVector2Array:
	return _ai.path_px() if _ai != null and _ai.active() else PackedVector2Array()


## Whether a squadmate's at the wheel, so the truck can be sent places.
func has_ai_driver() -> bool:
	return ai_driver != null


## Whether the crane's operator is out of the cab at the crane right now (the HUD).
func operator_out() -> bool:
	return _operator != null and _cphase != CranePhase.RETURNING


## A left click in command mode while the crane's ready (command.gd _click()).
## "" if it isn't (or the click's not on a crate: the squad's own click then);
## "ok" a job's taken: the crate under the click, with its middle in one of the
## two squares beside the bed, is lifted onto it (the furthest back spot first);
## "no" if it's refused (not in a square, the bed's full).
func crane_click(point: Vector2) -> String:
	var result := _crane_click(point)
	if result != "":
		BattleLog.order(self, "lift", [point, "ok" if result == "ok" else "refused"])
	return result


func _crane_click(point: Vector2) -> String:
	if not _armed or airborne:
		return ""
	var crate := _crate_to_lift(point)
	if crate == null:
		return ""
	if _cphase == CranePhase.RETURNING or (_cphase == CranePhase.STOWING and not _operator_ok()):
		return "no"   # (it's putting away: the next go's after)
	if _cphase == CranePhase.IDLE and not _operator_can_get_out():
		return "no"   # (the passenger's side is blocked: he'd not get out, so it's cancelled at once)
	if _projected() >= _bed.size() or not in_pickup(crate.global_position):
		return "no"
	_jobs.append({kind = "load", crate = crate})
	_wake_crane()
	return "ok"


## Whether world `point` is inside one of the squares beside the bed.
func in_pickup(point: Vector2) -> bool:
	var local := to_local(point) / World.PX_PER_M
	return (local.x >= PICKUP_X_M.x and local.x <= PICKUP_X_M.y
			and absf(local.y) >= PICKUP_Y_M.x and absf(local.y) <= PICKUP_Y_M.y)


## A job's been added: start the operation, or take it up again if it was stowing.
func _wake_crane() -> void:
	if _cphase == CranePhase.IDLE:
		_cphase = CranePhase.WAIT_STOP   # the operator gets out once it's stopped
		_crane_t = 0.0
	elif _cphase == CranePhase.STOWING:
		_cphase = CranePhase.DEPLOYING   # (changed its mind: the stabilisers go back down)


## The bed spots (indexes, nearest the crane first) the next `count` crates set down would come
## from: the ones loaded, less those already spoken for by unloads waiting.
func _unload_slots(count: int) -> Array:
	var occupied: Array = []
	for i in range(_bed.size() - 1, -1, -1):
		if _bed[i] != null:
			occupied.append(i)
	var waiting := _jobs.filter(func(j): return j.kind == "unload").size()
	return occupied.slice(waiting).slice(0, count)


## How many crates (up to 2) could be set down now.
func loaded_count() -> int:
	return _unload_slots(_bed.size()).size()


## Where `count` crates would be set down on `side` (1 the passenger's, -1 the driver's), world px: out
## from the truck at the bed spot each comes from. Fewer if fewer are loaded.
func crane_drop_spots(count: int, side: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for slot: int in _unload_slots(count):
		out.append(to_global(Vector2(SLOT_X_M[slot], side * DROP_Y_M) * World.PX_PER_M))
	return out


## Whether every one of those spots is clear ground.
func crane_drop_clear(count: int, side: int) -> bool:
	var spots := crane_drop_spots(count, side)
	if spots.size() < count:
		return false
	return spots.size() > 0 and Array(spots).all(func(p): return _spot_clear(p))


## Sets `count` crates down on `side` (command.gd: hold Crane, 1 or 2 boxes, then where): the crane
## deploys if it isn't, and the unloads wait their turn. False if there aren't that many loaded, the
## ground's taken, or it can't deploy.
func crane_drop(count: int, side: int) -> bool:
	var done := _crane_drop(count, side)
	BattleLog.order(self, "drop", [count, "driver" if side < 0 else "passenger", _ok(done)])
	return done


func _crane_drop(count: int, side: int) -> bool:
	if airborne or not crane_drop_clear(count, side):
		return false
	var slots := _unload_slots(count)
	if not _armed:
		if not _order_crane():
			return false
	elif _cphase == CranePhase.RETURNING or (_cphase == CranePhase.STOWING and not _operator_ok()):
		return false
	for slot: int in slots:
		_jobs.append({kind = "unload", to = Vector2(SLOT_X_M[slot], side * DROP_Y_M)})
	_wake_crane()
	return true


## The crate (on the ground, with a pallet, not already a job) whose pallet is under `point`.
func _crate_to_lift(point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for crate: Node2D in get_tree().get_nodes_in_group("crates"):
		if crate.get("mounted") == null or crate.mounted or crate.pallet_m == Vector2.ZERO or _is_job(crate):
			continue
		var local: Vector2 = crate.to_local(point)
		var half: Vector2 = crate.pallet_m * World.PX_PER_M / 2.0 + Vector2.ONE * CRATE_PICK_PX
		if absf(local.x) <= half.x and absf(local.y) <= half.y and crate.global_position.distance_to(point) < best_d:
			best = crate
			best_d = crate.global_position.distance_to(point)
	return best


func _is_job(crate: Node2D) -> bool:
	return (_job != null and _job.crate == crate) or _jobs.any(func(j): return j.get("crate") == crate)


## How many crates will be on the bed once every job's done.
func _projected() -> int:
	var n := _bed.filter(func(c): return c != null).size()
	if _job != null and _job.kind == "load":
		n += 1
	for job in _jobs:
		n += 1 if job.kind == "load" else -1
	return n


## Whether a crate could be set down with its middle at world `at`: inside the
## play area, nothing solid under it (the truck, a square, another crate).
func _spot_clear(at: Vector2) -> bool:
	var px := World.PX_PER_M
	if not World.ARENA.grow(-0.5 * px).has_point(at):
		return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(0.84, 0.84) * px
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(global_rotation, at)
	query.collision_mask = 5
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Whether `box_m` (a middle and a size, local metres) has nothing solid in it
## (layers 1 and 4: the squares, crates, sandbags, the tower's legs, as the
## truck itself would hit), the truck and whoever's in `except` aside.
func _box_clear(box_m: Array, except: Array = []) -> bool:
	var px := World.PX_PER_M
	var shape := RectangleShape2D.new()
	shape.size = box_m[1] * px
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(global_rotation, to_global(box_m[0] * px))
	query.collision_mask = 5
	var skip: Array[RID] = [get_rid()]
	for body: CollisionObject2D in except:
		skip.append(body.get_rid())
	query.exclude = skip
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Whether the passenger could get out and stand at the controls: the exit box
## beside its door (EXIT_BOX_M) and the spot at the crane (STATION_M) are clear.
func _operator_can_get_out() -> bool:
	var who: Array = [passenger] if passenger != null else ([_operator] if _operator != null else [])
	return (_box_clear([EXIT_BOX_M, EXIT_BOX_SIZE_M], who)
			and _box_clear([Vector2(CLEAR_M.x, -CLEAR_M.y), Vector2.ONE * 0.45], who)
			and _box_clear([STATION_M, Vector2.ONE * 0.45], who))


## Tells command mode a red ping at `at` (the crane's job was cancelled).
func _refuse_ping(at: Vector2) -> void:
	get_tree().call_group("command", "refuse_ping", at)


func _drop_operator() -> void:
	if _operator != null and is_instance_valid(_operator):
		_operator.weapon_away = false
	_operator = null


func _operator_ok() -> bool:
	return _operator != null and is_instance_valid(_operator) and not _operator.dead


func _station_world() -> Vector2:
	return to_global(STATION_M * World.PX_PER_M)


## The passenger's out of the cab (step_out): the truck keeps hold of it, it
## walks to the controls.
func _operator_out(seat: Seat, square) -> void:
	seat.operate = false
	_operator = square
	square.weapon_away = true   # (no rifle in its hands while it runs the crane, Mike, 2026-11-04)
	square.riding = self   # (given another order, it comes back through unload())
	_cphase = CranePhase.WALKING
	_crane_t = 0.0


## Keeps the operator at the controls, facing the hook.
func _hold_operator() -> void:
	_operator.walk_to = _station_world()
	_operator.facing = (to_global(_hook_m() * World.PX_PER_M) - _operator.global_position).angle()


## The hook's place (local metres): the end of the boom.
func _hook_m() -> Vector2:
	return CRANE_AXIS_M + Vector2.from_angle(_slew) * (ARM_M + _boom_ext)


func _tick_crane(delta: float) -> void:
	if _cphase == CranePhase.IDLE:
		return
	_crane_t += delta
	var seat := _seats[1]
	match _cphase:
		CranePhase.WAIT_STOP:
			if seat.step != Step.NONE:
				return
			if passenger == null:   # (nobody's left to run it)
				_crane_cancel()
			elif absf(speed) <= STOPPED_MPS:
				seat.operate = true
				if not _operator_can_get_out() or not _get_out(seat):   # (its side's blocked: it's off)
					seat.operate = false
					_refuse_ping(to_global(EXIT_BOX_M * World.PX_PER_M))
					_crane_cancel()
		CranePhase.WALKING:
			if not _operator_ok():
				_crane_abort()
				return
			_operator.walk_to = _station_world()
			if _operator.global_position.distance_to(_station_world()) <= STATION_REACH_M * World.PX_PER_M:
				_cphase = CranePhase.SETTLING
				_crane_t = 0.0
			elif _crane_t > STATION_GIVE_UP_S:
				_crane_abort()   # (something's in the way)
		CranePhase.SETTLING:
			if not _operator_ok():
				_crane_abort()
				return
			_hold_operator()
			if _crane_t >= station_hold_s:   # standing there a moment, then the stabilisers
				_cphase = CranePhase.DEPLOYING
				_crane_t = 0.0
		CranePhase.DEPLOYING:
			if not _operator_ok():
				_crane_abort()
				return
			_hold_operator()
			_stab = move_toward(_stab, 1.0, delta / stabilizer_s)
			if _stab >= 1.0:
				_cphase = CranePhase.WORKING
				_crane_t = 0.0
		CranePhase.WORKING:
			if not _operator_ok():
				_crane_abort()
				return
			_hold_operator()
			_tick_working(delta)
		CranePhase.STOWING:
			# The boom in and the turret back over the cab, then the stabilisers up.
			var stowed := _aim_at(CRANE_AXIS_M + Vector2(ARM_M, 0.0), delta)
			if _operator_ok():
				_hold_operator()
			if stowed:
				_stab = move_toward(_stab, 0.0, delta / stabilizer_s)
				if _stab <= 0.0:
					_finish_stow()
		CranePhase.RETURNING:
			# The operator walking back in by its door (the same steps as getting in).
			if seat.step == Step.NONE:
				_drop_operator()   # (in, or it gave up on the way: it's its own again)
				_cphase = CranePhase.IDLE


## Working: the next job when there is one; otherwise it waits, deployed, for the next click (until it's to be put away).
func _tick_working(delta: float) -> void:
	if _job != null:
		_tick_job(delta)
		_crane_t = 0.0
	elif not _jobs.is_empty():
		_start_job(_jobs.pop_front())
		_crane_t = 0.0
	elif _want_stow:   # (it stays deployed otherwise, ready for the next click)
		_want_stow = false
		_cphase = CranePhase.STOWING


## Starts a job (null `_job` if it can't be done now: the crate's gone, the bed's full, the spot's taken).
func _start_job(spec: Dictionary) -> void:
	var px := World.PX_PER_M
	var axis := to_global(CRANE_AXIS_M * px)
	if spec.kind == "load":
		var crate = spec.crate
		if not is_instance_valid(crate) or crate.mounted or not in_pickup(crate.global_position):
			return
		var slot := _bed.find(null)   # the furthest back free spot first
		if slot < 0:
			return
		_job = {kind = "load", crate = crate, slot = slot, from = to_local(crate.global_position) / px,
				to = Vector2(SLOT_X_M[slot], 0.0), h0 = 0.0, h1 = BED_Z_M}
	else:
		var slot := -1
		for i in range(_bed.size() - 1, -1, -1):   # the nearest one first: the opposite
			if _bed[i] != null:
				slot = i
				break
		if slot < 0 or not _spot_clear(to_global(spec.to * px)):
			return
		_job = {kind = "unload", crate = _bed[slot], slot = slot, from = Vector2(SLOT_X_M[slot], 0.0),
				to = spec.to, h0 = BED_Z_M, h1 = 0.0}
		_bed[slot] = null
	_job.step = JobStep.REACH
	_job.t = 0.0


## One tick of the job in hand: the boom out to the load, lift it, swing it to
## where it goes, set it down.
func _tick_job(delta: float) -> void:
	var px := World.PX_PER_M
	var job: Dictionary = _job
	var crate: Node2D = job.crate
	if not is_instance_valid(crate):
		_job = null
		return
	match job.step:
		JobStep.REACH:
			if _aim_at(job.from, delta):
				# Hooked on: it comes off the ground (or the bed) and rides the hook.
				if job.kind == "load":
					crate.mount()
					crate.reparent(self, true)
				job.p0 = crate.position
				job.r0 = crate.rotation
				job.step = JobStep.LIFT
				job.t = 0.0
		JobStep.LIFT:
			job.t = minf(job.t + delta / lift_s, 1.0)
			var e := smoothstep(0.0, 1.0, job.t)
			crate.height_m = lerpf(job.h0, CARRY_M, e)
			crate.position = job.p0.lerp(_hook_m() * px, e)
			crate.rotation = lerp_angle(job.r0, 0.0, e)
			if job.t >= 1.0:
				job.step = JobStep.SWING
		JobStep.SWING:
			var there := _aim_at(job.to, delta)
			crate.position = _hook_m() * px
			if there:
				job.p0 = crate.position
				job.step = JobStep.LOWER
				job.t = 0.0
		JobStep.LOWER:
			job.t = minf(job.t + delta / lift_s, 1.0)
			var e := smoothstep(0.0, 1.0, job.t)
			crate.height_m = lerpf(CARRY_M, job.h1, e)
			crate.position = job.p0.lerp(job.to * px, e)
			if job.t >= 1.0:
				if job.kind == "load":
					crate.position = job.to * px
					crate.height_m = BED_Z_M
					_bed[job.slot] = crate
				else:
					_to_ground(crate)
				_job = null


## Turns the turret toward `target` (local metres) and slides the boom out
## (never in past the arm) to reach it. True once it's there.
func _aim_at(target: Vector2, delta: float) -> bool:
	var off := target - CRANE_AXIS_M
	var want := off.angle() if off.length() > 0.05 else _slew
	var want_ext := clampf(off.length() - ARM_M, 0.0, crane_reach_m - ARM_M)
	var diff := angle_difference(_slew, want)
	var step := deg_to_rad(crane_slew_dps) * delta
	_slew = wrapf(_slew + clampf(diff, -step, step), -PI, PI)
	_boom_ext = move_toward(_boom_ext, want_ext, boom_mps * delta)
	return absf(diff) <= step and is_equal_approx(_boom_ext, want_ext)


## A carried crate down on the ground where it is.
func _to_ground(crate: Node2D) -> void:
	crate.rotation = 0.0
	crate.reparent(get_parent(), true)
	crate.unmount()


## It couldn't go on: whatever's on the hook is put down (back in its spot on
## the bed, or on the ground if the hook's out past the truck), the jobs
## dropped, the crane stowed; the operator walks back in if it's still its own.
func _crane_abort() -> void:
	var job = _job
	if job != null and is_instance_valid(job.crate):
		var crate: Node2D = job.crate
		var px := World.PX_PER_M
		if job.kind == "unload" and job.step == JobStep.REACH:
			_bed[job.slot] = crate   # (never left its spot)
		elif job.step != JobStep.REACH:   # (a load not yet hooked is still on the ground)
			var hook := _hook_m()
			if absf(hook.x) <= LENGTH_M / 2.0 and absf(hook.y) <= WIDTH_M / 2.0:
				var slot: int = job.slot   # over the bed: it goes in the spot it was bound for
				crate.position = Vector2(SLOT_X_M[slot], 0.0) * px
				crate.rotation = 0.0
				crate.height_m = BED_Z_M
				_bed[slot] = crate
			else:
				crate.position = hook * px
				_to_ground(crate)
	_job = null
	_jobs.clear()
	_armed = false   # (no operator: Crane has to be selected again)
	_want_stow = false
	_cphase = CranePhase.STOWING
	_crane_t = 0.0


## Nothing got started (the operator couldn't get out): it's as it was.
func _crane_cancel() -> void:
	_jobs.clear()
	_job = null
	_armed = false
	_want_stow = false
	_cphase = CranePhase.IDLE


## Stowed and the stabilisers up: the operator walks back to its door and gets in.
func _finish_stow() -> void:
	if _operator_ok() and passenger_free():
		_cphase = CranePhase.RETURNING
		_board(_seats[1], _operator)
	else:
		_drop_operator()
		_cphase = CranePhase.IDLE


## The two squares beside the bed a crate has to be in (command mode, once Crane's selected).
func _draw_reach() -> void:
	var px := World.PX_PER_M
	for side in [-1.0, 1.0]:
		var y0 := PICKUP_Y_M.x if side > 0.0 else -PICKUP_Y_M.y
		var box := Rect2(Vector2(PICKUP_X_M.x, y0) * px, Vector2(PICKUP_X_M.y - PICKUP_X_M.x, PICKUP_Y_M.y - PICKUP_Y_M.x) * px)
		_reach.draw_rect(box, Color(REACH_RING, 0.08))
		_reach.draw_rect(box, Color(REACH_RING, 0.9), false, 2.5)


## The boom: two sections sliding out of the arm's end (drawn under the arm's
## own picture, so what's inside it is hidden), a hook block at the tip.
func _draw_boom() -> void:
	if _boom_ext <= 0.005:
		return
	var px := World.PX_PER_M
	var a := Rect2(Vector2(ARM_M - 0.5, -0.06) * px, Vector2(0.5 + _boom_ext * 0.55, 0.12) * px)
	var b := Rect2(Vector2(ARM_M - 0.3, -0.04) * px, Vector2(0.3 + _boom_ext, 0.08) * px)
	_boom.draw_rect(a, BEAM_A)
	_boom.draw_rect(a, BEAM_EDGE, false, 1.0)
	_boom.draw_rect(b, BEAM_B)
	_boom.draw_rect(b, BEAM_EDGE, false, 1.0)
	_boom.draw_rect(Rect2(Vector2(ARM_M + _boom_ext - 0.05, -0.07) * px, Vector2(0.1, 0.14) * px), BEAM_EDGE)


## The boom's shadow: the section sticking out past the arm, swept up from
## where it's low to where it's high (the arm's own is in the turret's picture).
func _draw_boom_shadow() -> void:
	if _boom_ext <= 0.005:
		return
	var px := World.PX_PER_M
	var dir := Vector2.from_angle(_slew)
	var side := dir.orthogonal() * 0.05 * px
	var a := (CRANE_AXIS_M + dir * (ARM_M - 0.3)) * px
	var b := (CRANE_AXIS_M + dir * (ARM_M + _boom_ext)) * px
	var points := PackedVector2Array()
	for h in [1.7, 2.1]:
		for corner in [a + side, a - side, b + side, b - side]:
			points.append(corner + _sun * h)
	_boom_shadow.draw_colored_polygon(Geometry2D.convex_hull(points), Color.BLACK)


## The crates' shadows on the deck (Mike, 2026-11-04: a crate on the bed
## shadows the bed, and out past its back): each pallet's and load's footprint
## swept up along the sun from the deck, cut to the deck. (Past the deck's
## edge, the crate's own shadow on the ground shows, pushed out by its height.)
func _draw_bed_shadow() -> void:
	var px := World.PX_PER_M
	var deck := PackedVector2Array([Vector2(BED_BACK_X_M, -BED_W_M / 2.0) * px, Vector2(BED_FRONT_X_M, -BED_W_M / 2.0) * px,
			Vector2(BED_FRONT_X_M, BED_W_M / 2.0) * px, Vector2(BED_BACK_X_M, BED_W_M / 2.0) * px])
	for crate in _bed:
		if crate == null or not is_instance_valid(crate):
			continue
		var points := PackedVector2Array()
		for part in [[crate.pallet_m, crate.pallet_height_m], [crate.load_m, crate.load_height_m]]:
			if part[0] == Vector2.ZERO:
				continue
			var half: Vector2 = part[0] * px / 2.0
			for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
				points.append(crate.position + corner)
				points.append(crate.position + corner + _sun * part[1])
		for piece in Geometry2D.intersect_polygons(Geometry2D.convex_hull(points), deck):
			_bed_shadow_shape.draw_colored_polygon(piece, Color.BLACK)


## The stabilisers: beams run out either side of the pedestal, then the jacks
## push their pads down (the pads widen as they take the weight).
func _draw_stabs() -> void:
	if _stab <= 0.0:
		return
	var px := World.PX_PER_M
	var out := smoothstep(0.0, 0.55, _stab)
	var down := smoothstep(0.45, 1.0, _stab)
	for side in [-1.0, 1.0]:
		var y1 := lerpf(0.6, STAB_OUT_M, out)
		var beam := Rect2(Vector2(CRANE_X_M - 0.08, minf(side * 0.6, side * y1)) * px, Vector2(0.16, absf(y1 - 0.6)) * px)
		_stabs.draw_rect(beam, STAB_BEAM)
		_stabs.draw_rect(beam, BEAM_EDGE, false, 1.0)
		var c := Vector2(CRANE_X_M, side * y1) * px
		var r := (0.1 + 0.05 * down) * px
		_stabs.draw_circle(c + Vector2(1.5, 1.5) * down, r, Color(0, 0, 0, 0.25 * down))   # (where it's pressing)
		_stabs.draw_circle(c, r, STAB_PAD)
		_stabs.draw_arc(c, r, 0.0, TAU, 24, STAB_PAD_EDGE, 1.5, true)
		_stabs.draw_circle(c, 0.035 * px, STAB_PAD_EDGE)


# ------------------------------------------------------- getting in and out --

## `square` (the player) gets in by the driver's door: it walks itself there,
## the door opens, it steps up into the cab, the door shuts (_tick_getting_in_or_out()).
func get_in(square) -> void:
	_board(_seats[0], square)


## Whether the passenger's seat is free for a squadmate (nobody in it or
## on the way).
## Up in the air (`airborne`, slung: sling_drop.gd) or back down: off every
## collision layer up there, back on them down here.
func set_airborne(on: bool) -> void:
	airborne = on
	collision_layer = 0 if on else 1
	collision_mask = 0 if on else 5   # (as the scene: squares and crates 1, sandbags 4)


func passenger_free() -> bool:
	return seat_free(1)


## Whether the seat on `side` (-1 the driver's, 1 the passenger's) is free: nobody in it or on the way.
func seat_free(side: int) -> bool:
	var seat := _seats[0 if side < 0 else 1]
	return seat.occupant == null and seat.step == Step.NONE and not airborne


## `square` (a squadmate, squadmate.gd order_ride()) gets in by the door on
## `side` (1 the passenger's, -1 the driver's), the same way. False if the seat's taken.
func board(square, side := 1) -> bool:
	if not seat_free(side):
		return false
	_board(_seats[0 if side < 0 else 1], square)
	return true


## `square` (the passenger, given another order: squadmate.gd _take_orders())
## gets out by its door once the truck's stopped; on the way to the door, it
## stops where it is. False if it isn't in or getting in.
func unload(square) -> bool:
	if square == _operator and _cphase in [CranePhase.WALKING, CranePhase.SETTLING, CranePhase.DEPLOYING,
			CranePhase.WORKING, CranePhase.STOWING]:
		# The crane's operator given another order: it's let go, and the crane stows itself.
		square.riding = null
		square.walk_to = null
		_drop_operator()
		_crane_abort()
		return true
	for seat in _seats:
		if seat.occupant == square:
			seat.want_out = true
			if seat.side < 0:
				ai_stop()   # (the driver's to get out: it stops first)
			return true
		if seat.rider == square and seat.step == Step.TO_DOOR:
			_abandon(seat)
			return true
	return false


func _board(seat: Seat, square) -> void:
	seat.rider = square
	seat.door = 0 if seat.side < 0 else 1
	if square.is_in_group("player"):
		square.busy = true
	seat.route = _route_to_door(to_local(square.global_position) / World.PX_PER_M, seat.side)
	square.walk_to = to_global(seat.route[0] * World.PX_PER_M)
	_begin(seat, Step.TO_DOOR)


## The way from local `from` (metres) to the door on `side`: straight there,
## or if the truck's in the way (a squadmate on the far side: it walked into
## its side), round its front or its back, whichever's shorter, by the
## corners ROUND_M off it. Local points, the door last.
func _route_to_door(from: Vector2, side: int) -> Array:
	var door := _side_m(CLEAR_M, side)   # (waits outside the door's swing while it opens)
	var keep_off := Rect2(-LENGTH_M / 2 - 0.25, -WIDTH_M / 2 - 0.25, LENGTH_M + 0.5, WIDTH_M + 0.5)
	if not _crosses(from, door, keep_off):
		return [door]
	var y_out := WIDTH_M / 2 + ROUND_M
	var here := signf(from.y) if absf(from.y) > 0.01 else float(-side)
	var best := []
	var best_len := INF
	for end_x in [LENGTH_M / 2 + ROUND_M, -LENGTH_M / 2 - ROUND_M]:
		var route := [Vector2(end_x, here * y_out), Vector2(end_x, side * y_out), door]
		var length: float = from.distance_to(route[0]) + route[0].distance_to(route[1]) + route[1].distance_to(door)
		if length < best_len:
			best_len = length
			best = route
	return best


## Whether the line from `a` to `b` (local metres) passes through `box`.
static func _crosses(a: Vector2, b: Vector2, box: Rect2) -> bool:
	for k in 21:
		if box.has_point(a.lerp(b, k / 20.0)):
			return true
	return false


## The driver gets out (it must have stopped): see _get_out(). False if
## every way out's blocked (it stays in).
func get_out() -> bool:
	return _get_out(_seats[0])


## Whoever's in `seat` gets out: by their own door if there's room beside it,
## else the other door if nobody's using that seat, played out as getting in
## backwards; with both blocked, at once out the back. False if all three
## are blocked.
func _get_out(seat: Seat) -> bool:
	var square = seat.occupant
	if square == null:
		return false
	var other := _seats[1 if seat.side < 0 else 0]
	# (the crane's operator always by its own door: the controls are on that side)
	var doors := [seat.side, -seat.side] if other.step == Step.NONE and other.occupant == null and not seat.operate \
			else [seat.side]
	for side: int in doors:
		var at := to_global(_side_m(DOOR_M, side) * World.PX_PER_M)
		var clear := to_global(_side_m(CLEAR_M, side) * World.PX_PER_M)   # (and beyond it, out of the door's swing)
		if _clear_for(square, at, seat) and _in_play(at) and _clear_for(square, clear, seat) and _in_play(clear):
			_vacate(seat)
			seat.rider = square
			seat.door = 0 if side < 0 else 1
			square.global_position = to_global(_side_m(SEAT_M, side) * World.PX_PER_M)   # (under the roof: out of sight)
			_unhide(seat, square)
			if square.is_in_group("player"):
				square.busy = true
			_begin(seat, Step.OPENING_OUT)
			return true
	if seat.operate:
		return false   # (the crane's operator doesn't go out the back: the job's cancelled)
	var back := to_global(Vector2(-LENGTH_M / 2 - 0.5, 0.0) * World.PX_PER_M)
	if _clear_for(square, back, seat) and _in_play(back):
		_vacate(seat)
		square.global_position = back
		square.facing = (back - global_position).angle()   # facing away from the truck
		_unhide(seat, square)
		_free(seat, square)
		if seat.operate:
			_operator_out(seat, square)
		return true
	return false


## Nobody in `seat` now: the driver leaving switches the engine off and
## takes the player out of the truck (command.gd's orders go back to normal).
func _vacate(seat: Seat) -> void:
	var square = seat.occupant
	seat.occupant = null
	seat.want_out = false
	if seat.side < 0:
		_stop_engine()
		ai_stop()
	if square.is_in_group("player"):
		square.vehicle = null


func _begin(seat: Seat, step: Step) -> void:
	seat.step = step
	seat.step_s = 0.0


## One tick of getting in or out of `seat`: walking to the door, the door
## opening, stepping in under the roof (or out), the door shutting.
func _tick_getting_in_or_out(seat: Seat, delta: float) -> void:
	seat.step_s += delta
	var rider = seat.rider
	if seat.step != Step.CLOSING_OUT and (rider == null or not is_instance_valid(rider) or rider.dead):
		_abandon(seat)   # (the door shuts on its own: CLOSING_OUT needs no rider)
		return
	match seat.step:
		Step.TO_DOOR:
			# Round the truck first if it's in the way (_route_to_door()).
			if seat.route.size() > 1 and rider.global_position.distance_to(to_global(seat.route[0] * World.PX_PER_M)) <= CORNER_M * World.PX_PER_M:
				seat.route.pop_front()
			rider.walk_to = to_global(seat.route[0] * World.PX_PER_M)
			if seat.route.size() == 1 and _arrived(rider):
				# Through the cab's side from here: off everything solid (and
				# drawn under the truck, so the roof hides it as it goes in).
				seat.mask = rider.collision_mask
				rider.collision_mask = 0
				add_collision_exception_with(rider)
				_begin(seat, Step.OPENING)
			elif seat.step_s > WALK_GIVE_UP_S * (1.0 if rider.is_in_group("player") else SQUAD_WALK_GIVE_UP):
				_abandon(seat)   # something in the way
		Step.OPENING:
			if _door_free(seat) and _swing(seat.door, 1.0, delta):
				# In through the door's gap, square on, then up into the seat.
				rider.walk_to = to_global(_side_m(DOOR_M, seat.side) * World.PX_PER_M)
				seat.leg = 0
				_begin(seat, Step.STEP_IN)
		Step.STEP_IN:
			if seat.leg == 0:
				if rider.global_position.distance_to(rider.walk_to) <= LEG_M * World.PX_PER_M:
					seat.leg = 1
					rider.walk_to = to_global(_side_m(SEAT_M, seat.side) * World.PX_PER_M)
			elif _arrived(rider):
				_hide(seat, rider)
				_begin(seat, Step.CLOSING)
		Step.CLOSING:
			if _swing(seat.door, 0.0, delta):
				seat.occupant = rider
				seat.rider = null
				if rider.is_in_group("player"):
					rider.vehicle = self
				_begin(seat, Step.NONE)
		Step.OPENING_OUT:
			if _door_free(seat) and _swing(seat.door, 1.0, delta):
				rider.walk_to = to_global(_side_m(DOOR_M, -1 if seat.door == 0 else 1) * World.PX_PER_M)
				seat.leg = 0
				_begin(seat, Step.STEP_OUT)
		Step.STEP_OUT:
			# Out through the gap square on, then on out of the door's swing; only then does it shut.
			if seat.leg == 0:
				if rider.global_position.distance_to(rider.walk_to) <= LEG_M * World.PX_PER_M or seat.step_s > WALK_GIVE_UP_S:
					seat.leg = 1
					rider.walk_to = to_global(_side_m(CLEAR_M, -1 if seat.door == 0 else 1) * World.PX_PER_M)
			elif (rider.global_position.distance_to(to_global(_doors[seat.door].position)) >= SWEEP_CLEAR_M * World.PX_PER_M
					or seat.step_s > WALK_GIVE_UP_S * 2.0):
				_free(seat, rider)
				if seat.operate:
					_operator_out(seat, rider)   # (not its own AI's: the crane's)
				_begin(seat, Step.CLOSING_OUT)
		Step.CLOSING_OUT:
			if _swing(seat.door, 0.0, delta):
				seat.rider = null
				_begin(seat, Step.NONE)


## Whether `seat`'s door isn't being used by the other seat's rider right
## now (the driver getting out by the passenger's door, say).
func _door_free(seat: Seat) -> bool:
	var other := _seats[1 if seat.side < 0 else 0]
	return other.step == Step.NONE or other.door != seat.door


## Swings door `i` toward `to` (0 shut, 1 open), easing in and out over
## DOOR_S, with its sound as it starts to open and as it slams shut. True
## once it's there.
func _swing(i: int, to: float, delta: float) -> bool:
	var was: float = _door_open[i]
	_door_open[i] = move_toward(_door_open[i], to, delta / DOOR_S)
	if to > 0.0 and was == 0.0:
		_door_noise(SOUND_DOOR_OPEN, i)
	elif to == 0.0 and was > 0.0 and _door_open[i] == 0.0:
		_door_noise(SOUND_DOOR_SLAM, i)
	var side := -1 if i == 0 else 1
	var door := _doors[i]
	door.visible = _door_open[i] > 0.0
	door.rotation = -side * deg_to_rad(DOOR_OPEN_DEG) * smoothstep(0.0, 1.0, _door_open[i])   # (outward: the left door's back edge swings to -y)
	return _door_open[i] == to


func _arrived(square) -> bool:
	return square.walk_to == null or square.global_position.distance_to(square.walk_to) <= ARRIVE_M * World.PX_PER_M


## Whether anyone's getting in or out (tests).
func busy() -> bool:
	return _seats.any(func(s): return s.step != Step.NONE)


## In the cab: hidden and switched off, off the collision layers (nothing
## hits it in here).
func _hide(seat: Seat, square) -> void:
	square.walk_to = null
	seat.layer = square.collision_layer
	square.collision_layer = 0
	square.visible = false
	square.process_mode = Node.PROCESS_MODE_DISABLED


## Out of the cab (still walking itself, off everything solid, until it's
## clear of the truck: _free()).
func _unhide(seat: Seat, square) -> void:
	square.collision_layer = seat.layer
	seat.mask = square.collision_mask if square.collision_mask != 0 else seat.mask
	square.collision_mask = 0
	add_collision_exception_with(square)
	square.visible = true
	square.process_mode = Node.PROCESS_MODE_INHERIT


## Back in its own hands (the player's, or a squadmate's AI), solid again.
func _free(seat: Seat, square) -> void:
	square.walk_to = null
	if square.is_in_group("player"):
		square.busy = false
	else:
		square.riding = null
	square.collision_mask = seat.mask
	remove_collision_exception_with(square)


## Getting in stopped part way (the way to the door blocked, the rider
## killed, a passenger given another order): back in its own hands, the door
## left to shut.
func _abandon(seat: Seat) -> void:
	var rider = seat.rider
	if rider != null and is_instance_valid(rider):
		if seat.step != Step.TO_DOOR:
			_free(seat, rider)
		else:
			rider.walk_to = null
			if rider.is_in_group("player"):
				rider.busy = false
			else:
				rider.riding = null
	seat.rider = null
	if _door_open[seat.door] > 0.0:
		_begin(seat, Step.CLOSING_OUT)
	else:
		_begin(seat, Step.NONE)


func _in_play(at: Vector2) -> bool:
	return World.ARENA.grow(-0.2 * World.PX_PER_M).has_point(at)


## Whether `square` would fit at world `at` without overlapping anything solid.
func _clear_for(square, at: Vector2, seat: Seat = null) -> bool:
	var shape_node: CollisionShape2D = square.get_node("CollisionShape2D")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = Transform2D(0.0, at)
	query.collision_mask = (seat.mask if seat else 1) if square.collision_mask == 0 else square.collision_mask
	query.exclude = [square.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## A bullet stopped in it (bullet.gd): sparks and the clang of a round into
## steel (impact_sound.gd "metal", as the crates and the tower's legs).
func bullet_hit(point: Vector2, direction: Vector2, _damage := 0.0) -> void:
	var level: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	var sparks := HitSparks.new()
	sparks.setup(point, direction)
	level.add_child(sparks)
	ImpactSound.play(level, point, "metal")


# -------------------------------------------------------------- battle log --

static func _ok(done: bool) -> String:
	return "ok" if done else "refused"


## What it's doing, for the battle log's ~ lines (battle_log.gd): key -> value,
## with squares and crates as nodes and points in world px (the log numbers
## and converts them; null is none). Who's in each seat, who's getting in or
## out by its door and how far they've got, the engine, the AI driver and
## the crane.
func log_status() -> Dictionary:
	var s := {engine = EngineState.keys()[_engine], slung = airborne}
	for seat in _seats:
		var seat_name := "driver" if seat.side < 0 else "passenger"
		s[seat_name] = seat.occupant
		s[seat_name + "_door"] = [Step.keys()[seat.step], seat.rider] if seat.step != Step.NONE else null
		s[seat_name + "_wants_out"] = seat.want_out
	s.ai = "planning" if _ai != null and _ai.planning else ai_status()
	s.ai_stuck = _ai.unsticks if _ai != null else 0
	s.ai_to = _ai.goal if _ai != null and _ai.active() else null
	s.ai_heading = "%d" % roundi(rad_to_deg(_ai.goal_heading)) if _ai != null and _ai.active() and not is_nan(_ai.goal_heading) else null
	s.crane = CranePhase.keys()[_cphase]
	s.armed = _armed
	s.operator = _operator if _operator_ok() else null
	s.job = [_job.kind, _job.crate, JobStep.keys()[_job.step]] if _job != null else null
	s.jobs = _jobs.size()
	s.bed = _bed
	return s


## Where `square` is in or by the truck, for the battle log (a square's
## vehicle= key): "driver" or "passenger" (sitting in that seat),
## "boarding_<seat>" or "leaving_<seat>" (on its way in or out by a door),
## "crane" (out running the crane), or "" (nothing to do with it).
func seat_of(square) -> String:
	for seat in _seats:
		var seat_name := "driver" if seat.side < 0 else "passenger"
		if seat.occupant == square:
			return seat_name
		if seat.rider == square and seat.step != Step.CLOSING_OUT:   # (once out, it's its own while the door shuts)
			return ("leaving_" if seat.step >= Step.OPENING_OUT else "boarding_") + seat_name
	if square == _operator:
		return "crane"
	return ""
