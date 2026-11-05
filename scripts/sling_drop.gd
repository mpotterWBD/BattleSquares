extends Node
## Flies its parent helicopter (scenes/helicopter.tscn) in with a vehicle
## slung under it on cables, sets the vehicle down at the landing zone, lets
## go, and flies away (Mike, 2026-11-03: the supply truck deployable by
## helicopter, like troops; it's too big for the cabin). Started by a radio
## terminal's vehicle request (scripts/radio_terminal.gd) via start().
##
## As a troop insertion (insertion.gd): in from the west, nose east, at
## CRUISE_ALT_M, slowing and coming down over APPROACH_M, until the vehicle,
## SLING_M under it, is HOVER_M off the ground over the landing zone. It
## lowers it the rest of the way over LOWER_S, lets go (the cables gone, the
## vehicle solid and on the ground: `set_down`), hovers RELEASE_S, climbs
## and flies away east, and is removed. Meanwhile the vehicle has no
## collisions, can't be got into, and is drawn bigger by its height, its
## shadow out on the ground (supply_truck.gd `altitude_m`).

const World = preload("res://scripts/world.gd")
const Insertion = preload("res://scripts/insertion.gd")

const SLING_M := 7.0          ## the vehicle hangs this far under the helicopter
const HOVER_M := 1.0          ## coming in, it stops with the vehicle this high...
const LOWER_S := 2.0          ## ...and lowers it the rest of the way over this long
const RELEASE_S := 1.2        ## hovering after letting go
## The cables: from the helicopter's hook (under its middle) to the vehicle's
## lifting points (its corners, a little in).
const LIFT_POINTS_M := [Vector2(1.9, 0.5), Vector2(1.9, -0.5), Vector2(-1.9, 0.5), Vector2(-1.9, -0.5)]
const CABLE_COLOR := Color(0.07, 0.07, 0.07, 0.85)
const CABLE_PX := 2.0
const CABLE_Z := 4            ## over the vehicle's body (3), under the helicopter's (5)

enum Phase { INBOUND, LOWERING, RELEASED, CLIMBING, OUTBOUND }

## The vehicle's on the ground and let go.
signal set_down(vehicle: Node2D)

var phase := Phase.INBOUND
var lz := Vector2.ZERO
var vehicle: Node2D

var _heli: Node2D
var _timer := 0.0
var _speed := 0.0
var _cables: Node2D


## Begins the run: `heli` is the helicopter this node is a child of;
## `slung` the vehicle (already in the level) it carries to `landing_zone`.
func start(heli: Node2D, landing_zone: Vector2, slung: Node2D) -> void:
	_heli = heli
	lz = landing_zone
	vehicle = slung
	_heli.rotation = 0.0   # nose east
	_heli.position = lz + Vector2(-Insertion.ENTRY_M * World.PX_PER_M, 0)
	_heli.altitude_m = Insertion.CRUISE_ALT_M
	_heli.rotor_spin = 1.0
	_heli.get_node("Hull/Outline").set_deferred("disabled", true)   # it never lands
	_speed = Insertion.CRUISE_MPS
	vehicle.rotation = 0.0
	vehicle.set_airborne(true)
	_cables = Node2D.new()
	_cables.z_index = CABLE_Z
	_cables.draw.connect(_draw_cables)
	_heli.get_parent().add_child(_cables)
	_carry()


func _physics_process(delta: float) -> void:
	if _heli == null:
		return
	var px := World.PX_PER_M
	var hover := SLING_M + HOVER_M
	match phase:
		Phase.INBOUND:
			var left_m := (lz.x - _heli.position.x) / px
			_speed = clampf(left_m * 0.9, 1.2, Insertion.CRUISE_MPS)   # ease off near the LZ
			var step := minf(_speed * delta, left_m)
			_heli.position.x += step * px
			_heli.altitude_m = lerpf(hover, Insertion.CRUISE_ALT_M, clampf((left_m - 0.5) / Insertion.APPROACH_M, 0.0, 1.0))
			if left_m - step <= 0.02:
				_heli.position = lz
				_heli.altitude_m = hover
				phase = Phase.LOWERING
				_timer = 0.0
		Phase.LOWERING:
			_timer += delta
			var t := smoothstep(0.0, 1.0, _timer / LOWER_S)
			_heli.altitude_m = lerpf(hover, SLING_M, t)
			if _timer >= LOWER_S:
				_heli.altitude_m = SLING_M
				_let_go()
				phase = Phase.RELEASED
				_timer = RELEASE_S
		Phase.RELEASED:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.CLIMBING
				_timer = 0.0
				_speed = 0.0
		Phase.CLIMBING:
			_timer += delta
			var t := clampf(_timer / Insertion.CLIMB_S, 0.0, 1.0)
			_heli.altitude_m = lerpf(SLING_M, Insertion.CRUISE_ALT_M, t * t)
			_speed = 8.0 * t
			_heli.position.x += _speed * delta * px
			if t >= 1.0:
				phase = Phase.OUTBOUND
		Phase.OUTBOUND:
			_speed = move_toward(_speed, Insertion.CRUISE_MPS, 10.0 * delta)
			_heli.position.x += _speed * delta * px
			if (_heli.position.x - lz.x) / px > Insertion.EXIT_M:
				_heli.queue_free()
				return
	if phase in [Phase.INBOUND, Phase.LOWERING]:
		_carry()


## The vehicle under the helicopter, SLING_M down, and the cables to it.
func _carry() -> void:
	vehicle.global_position = _heli.global_position
	vehicle.altitude_m = maxf(_heli.altitude_m - SLING_M, 0.0)
	_cables.queue_redraw()


## Down: the cables go and the vehicle's on the ground, solid.
func _let_go() -> void:
	vehicle.altitude_m = 0.0
	vehicle.set_airborne(false)
	_cables.queue_free()
	_cables = null
	set_down.emit(vehicle)


## From the hook to each lifting point, in the world (the helicopter's
## grown by its height, the vehicle by its own).
func _draw_cables() -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	var hook := _heli.global_position
	for point: Vector2 in LIFT_POINTS_M:
		_cables.draw_line(hook, vehicle.to_global(point * World.PX_PER_M), CABLE_COLOR, CABLE_PX, true)
