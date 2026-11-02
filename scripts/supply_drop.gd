extends Node
## Flies its parent helicopter (scenes/helicopter.tscn) over a drop zone and
## drops supplies by parachute (scripts/air_drop.gd), then flies away and is
## removed. Started by a radio terminal's equipment request
## (scripts/radio_terminal.gd) via start().
##
## The drops lie in a line, and it flies in along that line (`heading`: 0 is
## from the west, nose east) at CRUISE_ALT_M, letting down to DROP_ALT_M and
## slowing to DROP_MPS over the drop zone. Each crate is let go as the
## helicopter passes over its spot (in order along the line), and steers
## down onto that exact spot under its canopy. After the last it speeds up
## and climbs away the way it was going. The hull is never solid (it never
## lands).

const World = preload("res://scripts/world.gd")
const AirDrop = preload("res://scripts/air_drop.gd")

const CRUISE_ALT_M := 25.0
const DROP_ALT_M := 20.0
const CRUISE_MPS := 30.0
const DROP_MPS := 8.0
const ENTRY_M := 70.0          ## starts this far before the first drop (well off screen)
const SLOW_FROM_M := 30.0      ## starts slowing and letting down this far before the first drop
const EXIT_M := 80.0           ## removed once this far past the last drop
const ACCEL_MPS2 := 6.0

var _heli: Node2D
var _drops: Array = []         ## [{scene, pos, turn}], in order along the run, still to go
var _dir := Vector2.RIGHT      ## the way it's flying
var _first_s := 0.0            ## the first and last drops, as distances along _dir (px)
var _last_s := 0.0
var _speed := CRUISE_MPS


## A crate's been let go (its air_drop.gd, coming down).
signal released(fall: Node2D)


## Begins the run: `heli` is the helicopter this node is a child of; `drops`
## are {scene: PackedScene (or a crate out of the tree, air_drop.gd setup()),
## pos: Vector2 (world), turn: float (radians)};
## it flies along `heading` (radians, 0 = east).
func start(heli: Node2D, drops: Array, heading := 0.0) -> void:
	_heli = heli
	_dir = Vector2.from_angle(heading)
	_drops = drops.duplicate()
	_drops.sort_custom(func(a, b): return a.pos.dot(_dir) < b.pos.dot(_dir))
	_first_s = _drops[0].pos.dot(_dir)
	_last_s = _drops[-1].pos.dot(_dir)
	var middle := Vector2.ZERO
	for drop in _drops:
		middle += drop.pos
	middle /= _drops.size()
	_heli.rotation = heading
	_heli.position = middle + _dir * (_first_s - middle.dot(_dir) - ENTRY_M * World.PX_PER_M)
	_heli.altitude_m = CRUISE_ALT_M
	_heli.rotor_spin = 1.0
	_heli.get_node("Hull/Outline").set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if _heli == null:
		return
	var px := World.PX_PER_M
	var s := _heli.position.dot(_dir)
	if not _drops.is_empty():
		# Coming in: slow down and let down over the last SLOW_FROM_M.
		var to_first := (_first_s - s) / px
		var k := clampf(1.0 - to_first / SLOW_FROM_M, 0.0, 1.0)
		var wanted := lerpf(CRUISE_MPS, DROP_MPS, smoothstep(0.0, 1.0, k))
		_speed = move_toward(_speed, wanted, ACCEL_MPS2 * 2.0 * delta) if wanted < _speed else wanted
		_heli.altitude_m = lerpf(CRUISE_ALT_M, DROP_ALT_M, smoothstep(0.0, 1.0, k))
		while not _drops.is_empty() and s >= _drops[0].pos.dot(_dir):
			_release(_drops.pop_front())
	else:
		# Away: speed up and climb back to cruise.
		_speed = move_toward(_speed, CRUISE_MPS, ACCEL_MPS2 * delta)
		_heli.altitude_m = move_toward(_heli.altitude_m, CRUISE_ALT_M, 2.0 * delta)
		if (s - _last_s) / px > EXIT_M:
			_heli.queue_free()
			return
	_heli.position += _dir * _speed * delta * px


## Lets a crate go from under the helicopter; it comes down on its spot.
func _release(drop: Dictionary) -> void:
	var fall := AirDrop.new()
	fall.setup(drop.scene, drop.pos, drop.turn, _heli.global_position, _heli.altitude_m)
	_heli.get_parent().add_child(fall)
	released.emit(fall)
