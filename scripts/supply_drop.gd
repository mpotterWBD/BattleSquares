extends Node
## Flies its parent helicopter (scenes/helicopter.tscn) over a drop zone and
## drops supplies by parachute (scripts/air_drop.gd), then flies away and is
## removed. Started by a radio terminal's equipment request
## (scripts/radio_terminal.gd) via start().
##
## It comes in from the west, nose east, at CRUISE_ALT_M, along the line
## through the middle of the drops, letting down to DROP_ALT_M and slowing
## to DROP_MPS over the drop zone. Each crate is let go as the helicopter
## passes over its spot (in order from west to east), and steers down onto
## that exact spot under its canopy. After the last it speeds up and climbs
## away east. The hull is never solid (it never lands).

const World = preload("res://scripts/world.gd")
const AirDrop = preload("res://scripts/air_drop.gd")

const CRUISE_ALT_M := 25.0
const DROP_ALT_M := 20.0
const CRUISE_MPS := 30.0
const DROP_MPS := 8.0
const ENTRY_M := 70.0          ## starts this far west of the first drop (well off screen)
const SLOW_FROM_M := 30.0      ## starts slowing and letting down this far before the first drop
const EXIT_M := 80.0           ## removed once this far east of the last drop
const ACCEL_MPS2 := 6.0

var _heli: Node2D
var _drops: Array = []         ## [{scene, pos, turn}], west to east, still to go
var _first_x := 0.0
var _last_x := 0.0
var _speed := CRUISE_MPS


## Begins the run: `heli` is the helicopter this node is a child of; `drops`
## are {scene: PackedScene, pos: Vector2 (world), turn: float (radians)}.
func start(heli: Node2D, drops: Array) -> void:
	_heli = heli
	_drops = drops.duplicate()
	_drops.sort_custom(func(a, b): return a.pos.x < b.pos.x)
	_first_x = _drops[0].pos.x
	_last_x = _drops[-1].pos.x
	var line_y := 0.0
	for drop in _drops:
		line_y += drop.pos.y
	line_y /= _drops.size()
	_heli.rotation = 0.0   # nose east
	_heli.position = Vector2(_first_x - ENTRY_M * World.PX_PER_M, line_y)
	_heli.altitude_m = CRUISE_ALT_M
	_heli.rotor_spin = 1.0
	_heli.get_node("Hull/Outline").set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if _heli == null:
		return
	var px := World.PX_PER_M
	var x := _heli.position.x
	if not _drops.is_empty():
		# Coming in: slow down and let down over the last SLOW_FROM_M.
		var to_first := (_first_x - x) / px
		var k := clampf(1.0 - to_first / SLOW_FROM_M, 0.0, 1.0)
		var wanted := lerpf(CRUISE_MPS, DROP_MPS, smoothstep(0.0, 1.0, k))
		_speed = move_toward(_speed, wanted, ACCEL_MPS2 * 2.0 * delta) if wanted < _speed else wanted
		_heli.altitude_m = lerpf(CRUISE_ALT_M, DROP_ALT_M, smoothstep(0.0, 1.0, k))
		while not _drops.is_empty() and x >= _drops[0].pos.x:
			_release(_drops.pop_front())
	else:
		# Away: speed up and climb back to cruise.
		_speed = move_toward(_speed, CRUISE_MPS, ACCEL_MPS2 * delta)
		_heli.altitude_m = move_toward(_heli.altitude_m, CRUISE_ALT_M, 2.0 * delta)
		if (x - _last_x) / px > EXIT_M:
			_heli.queue_free()
			return
	_heli.position.x += _speed * delta * px


## Lets a crate go from under the helicopter; it comes down on its spot.
func _release(drop: Dictionary) -> void:
	var fall := AirDrop.new()
	fall.setup(drop.scene, drop.pos, drop.turn, _heli.global_position, _heli.altitude_m)
	_heli.get_parent().add_child(fall)
