extends Node
## Flies its parent helicopter (scenes/helicopter.tscn) in to a landing zone,
## sets down, unloads troops who move out and disperse on both sides, then
## lifts off, flies away and is removed. Started by a radio terminal's troop
## request (scripts/radio_terminal.gd) via start(), and at the start of the
## game to drop the player off (scripts/arrival.gd).
##
## Besides new troopers it can carry `passengers`: squares already in the
## scene (the player), hidden and switched off until their turn comes. They
## step out first, onto their door spot, and are not sent anywhere.
##
## It comes in from the west, nose east, at CRUISE_ALT_M, slowing and
## descending over the last APPROACH_M. The hull only blocks squares while
## it's on the ground.

const World = preload("res://scripts/world.gd")
const Helicopter = preload("res://scripts/helicopter.gd")
const SQUADMATE := preload("res://scenes/squadmate.tscn")

const CRUISE_ALT_M := 25.0
const CRUISE_MPS := 30.0
const ENTRY_M := 70.0          ## starts this far west of the LZ (well off screen)
const APPROACH_M := 45.0       ## descends over this last stretch
const SETTLE_S := 0.8          ## on the ground before the doors open
const UNLOAD_EVERY_S := 0.35   ## one trooper out every this long, alternating sides
## Cabin door positions along the fuselage (nose = +x), on the real
## helicopter; times Helicopter.SCALE.
const DOOR_X_M := [2.6 * Helicopter.SCALE, 1.2 * Helicopter.SCALE]
const DOOR_OUT_M := 1.8 * Helicopter.SCALE   ## a square just outside the fuselage's side
## Where they move to once out: a short step clear of the door (DOOR_OUT_M
## is about 1 m), so they end up close to where they were dropped off.
const DISPERSE_OUT_M := 2.0    ## out from the fuselage's centreline
const DISPERSE_SPREAD_M := 3.0 ## each side's troopers spread evenly along this much of the fuselage, centred between the doors
const LEAVE_AFTER_S := 2.5     ## after the last trooper is out
const CLIMB_S := 4.0
const EXIT_M := 80.0           ## removed once this far east of the LZ

enum Phase { INBOUND, SETTLING, UNLOADING, WAITING, CLIMBING, OUTBOUND }

## A passenger (from `passengers`) has stepped out and is back in play.
signal passenger_out(unit: Node2D)

var phase := Phase.INBOUND
var lz := Vector2.ZERO
var troops := 0
var units: Array = []   ## unit type per trooper, in unloading order ("infantry", "radio")
var passengers: Array = []   ## squares already in the scene, unloaded before `units`

var _heli: Node2D
var _timer := 0.0
var _out := 0
var _speed := 0.0


## Begins the run: `heli` is the helicopter this node is a child of;
## `unit_types` has one unit type id per trooper (radio_terminal.gd UNIT_TYPES);
## `riders` are squares already in the scene to carry (see `passengers`).
func start(heli: Node2D, landing_zone: Vector2, unit_types: Array, riders: Array = []) -> void:
	_heli = heli
	lz = landing_zone
	units = unit_types
	passengers = riders
	troops = passengers.size() + units.size()
	for rider: Node2D in passengers:
		rider.visible = false
		rider.process_mode = Node.PROCESS_MODE_DISABLED   # also takes it out of physics
	_heli.rotation = 0.0   # nose east
	_heli.position = lz + Vector2(-ENTRY_M * World.PX_PER_M, 0)
	_heli.altitude_m = CRUISE_ALT_M
	_heli.rotor_spin = 1.0
	_speed = CRUISE_MPS
	_set_hull(false)


func _physics_process(delta: float) -> void:
	if _heli == null:
		return
	var px := World.PX_PER_M
	match phase:
		Phase.INBOUND:
			var left_m := (lz.x - _heli.position.x) / px
			_speed = clampf(left_m * 0.9, 1.2, CRUISE_MPS)   # ease off near the LZ
			var step := minf(_speed * delta, left_m)
			_heli.position.x += step * px
			_heli.altitude_m = CRUISE_ALT_M * clampf((left_m - 0.5) / APPROACH_M, 0.0, 1.0)
			if left_m - step <= 0.02:
				_heli.position = lz
				_heli.altitude_m = 0.0
				_set_hull(true)
				phase = Phase.SETTLING
				_timer = SETTLE_S
		Phase.SETTLING:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.UNLOADING
				_timer = 0.0
		Phase.UNLOADING:
			_timer -= delta
			if _timer <= 0.0:
				_unload_one()
				_timer = UNLOAD_EVERY_S
				if _out >= troops:
					phase = Phase.WAITING
					_timer = LEAVE_AFTER_S
		Phase.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.CLIMBING
				_timer = 0.0
				_speed = 0.0
				_set_hull(false)
		Phase.CLIMBING:
			_timer += delta
			var t := clampf(_timer / CLIMB_S, 0.0, 1.0)
			_heli.altitude_m = CRUISE_ALT_M * t * t
			_speed = 8.0 * t
			_heli.position.x += _speed * delta * px
			if t >= 1.0:
				phase = Phase.OUTBOUND
		Phase.OUTBOUND:
			_speed = move_toward(_speed, CRUISE_MPS, 10.0 * delta)
			_heli.position.x += _speed * delta * px
			if (_heli.position.x - lz.x) / px > EXIT_M:
				_heli.queue_free()


## One trooper steps out of a door (alternating sides) and moves out to a
## spot beside the helicopter, clear of the fuselage.
func _unload_one() -> void:
	var px := World.PX_PER_M
	var side := 1.0 if _out % 2 == 0 else -1.0          # +1 = starboard (screen down when facing east)
	var per_side := ceili(troops / 2.0)
	var index := _out / 2                               # which trooper on this side
	var door_x: float = DOOR_X_M[index % DOOR_X_M.size()]
	var spread := 0.0 if per_side <= 1 else lerpf(-DISPERSE_SPREAD_M / 2, DISPERSE_SPREAD_M / 2,
			float(index) / (per_side - 1))
	var door := _heli.to_global(Vector2(door_x, side * DOOR_OUT_M) * px)
	var facing := _heli.rotation + side * PI / 2         # facing out of the door
	if _out < passengers.size():
		var rider: Node2D = passengers[_out]
		rider.position = door
		rider.facing = facing
		rider.visible = true
		rider.process_mode = Node.PROCESS_MODE_INHERIT
		_out += 1
		passenger_out.emit(rider)
		return
	var trooper: Node2D = SQUADMATE.instantiate()
	if units[_out - passengers.size()] == "radio":
		trooper.kit = "radio"
	trooper.position = door
	trooper.facing = facing
	_heli.get_parent().add_child(trooper)
	# Spots are spaced evenly around the middle of the two doors, not each
	# trooper's own door, so neighbours never get sent to the same spot.
	var middle: float = (DOOR_X_M[0] + DOOR_X_M[1]) / 2.0
	trooper.order_move(_heli.to_global(Vector2(middle + spread, side * DISPERSE_OUT_M) * px))
	_out += 1


## Where the first square out stands, relative to the landing zone (pixels),
## for a helicopter landing nose east: just outside the front starboard door.
static func first_out_offset() -> Vector2:
	return Vector2(DOOR_X_M[0], DOOR_OUT_M) * World.PX_PER_M


func _set_hull(solid: bool) -> void:
	_heli.get_node("Hull/Outline").set_deferred("disabled", not solid)
