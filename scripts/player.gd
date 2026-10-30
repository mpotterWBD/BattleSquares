extends "res://scripts/soldier.gd"
## The square you control (see scripts/soldier.gd for how every square
## moves, turns and carries its rifle).
##
## WASD or the arrow keys walk, the mouse aims, left click fires. A shot
## goes exactly where you click within the rifle's accurate range, and
## strays more the further past it you click (rifle.gd `aim_*`); hold right
## mouse to see that as the aiming line (scripts/aim_line.gd). Holding Space
## enters command mode (scripts/command.gd): the mouse then gives squad
## orders, so this square keeps looking where it last aimed and won't fire.
## It's in the "player" group so squadmates and the command overlay can
## find it.
##
## Its voice carries all round it within its command circle
## (`aura_radius_m`), whichever way it faces. In command mode only
## squadmates inside the circle hear it: they turn to listen and can be
## selected and given orders, which can send them anywhere.
##
## Over the radio (radio command mode at a station's terminal) orders also
## go through the radio net: radio operators (soldier `kit` "radio") inside
## that station's dish beam are linked, and they pass orders on to anyone
## within their own command circle (`radio_circle_radius_m`).
## Communications decide who can be commanded.

const AimLine = preload("res://scripts/aim_line.gd")

## The command circle: how far its voice carries, all round. (Until
## 2026-10-29 this was 2.475 m plus an 8 m voice cone out of its front face.)
@export var aura_radius_m := 8.0
## A radio operator's command circle radius. Its own setting: it used to be
## twice the player's old 2.475 m circle.
@export var radio_circle_radius_m := 4.95
## How far away equipment can be put down from command mode's DEPLOY menu.
@export var deploy_reach_m := 2.475
## Equipment carried, to deploy from command mode: deployable id -> count.
## Ids match DEPLOYABLES in scripts/command.gd.
@export var deployables := {"radio_station": 1}
## How fast the squad's formation swings round to match the way this square
## faces, so sweeping the aim doesn't send followers running in circles.
@export var formation_turn_dps := 90.0

## The direction squadmates on Follow me / Lead line up along (radians):
## `facing`, smoothed.
var formation_heading := -PI / 2
## Set while something else has the mouse (e.g. a station's tuning wheel):
## this square then keeps looking where it last aimed and won't fire.
var busy := false

var _last_aim := Vector2.ZERO
var _aim_line: Node2D


func _ready() -> void:
	super()
	add_to_group("player")
	World.register_controls()
	_last_aim = global_position + Vector2.from_angle(facing) * 10.0 * World.PX_PER_M
	formation_heading = facing
	_aim_line = AimLine.new()
	_aim_line.weapon = _rifle
	_aim_line.visible = false
	add_child(_aim_line)


func _physics_process(delta: float) -> void:
	super(delta)
	formation_heading = wrapf(rotate_toward(formation_heading, facing,
			deg_to_rad(formation_turn_dps) * delta), -PI, PI)
	_aim_line.visible = Input.is_action_pressed("aim") and not World.commanding() and not busy
	_aim_line.target = _last_aim


## The player can't die yet (there's no game over to go to): it still
## takes hits, but its health just tops back up.
func _die(_point: Vector2, _direction: Vector2) -> void:
	health = max_health


func _move_intent() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Where to aim: the mouse, except in command mode, when the mouse is busy
## giving orders. A gamepad stick or an AI could supply this instead.
func _aim_point() -> Vector2:
	if not World.commanding() and not busy:
		_last_aim = get_global_mouse_position()
	return _last_aim


## Holds still while commanding: the mouse is giving orders, so the body
## doesn't drift round as it settles toward its last aim.
func _turn_toward(target: Vector2, delta: float) -> void:
	if not World.commanding():
		super(target, delta)


## How far the shot may stray: none within the rifle's accurate range of
## the point clicked, more the further past it.
func _shot_spread_deg() -> float:
	return _rifle.spread_at(_rifle.muzzle_position().distance_to(_last_aim) / World.PX_PER_M)


func _wants_to_fire() -> bool:
	return Input.is_action_just_pressed("shoot") and not World.commanding() and not busy


## Whether a squadmate at `point` can be commanded: it hears the player's
## voice, or (in radio command mode) the radio net reaches it.
func can_hear(point: Vector2) -> bool:
	return hears_voice(point) or (World.radio_commanding and radio_reaches(point))


## A radio operator's command circle radius, in metres.
func radio_circle_m() -> float:
	return radio_circle_radius_m


## Radio operators the station in use links to: those inside its dish beam.
func linked_radio_operators() -> Array[Node]:
	var station = World.radio_station
	if station == null or not is_instance_valid(station):
		return []
	return get_tree().get_nodes_in_group("squad").filter(
			func(unit): return unit.kit == "radio" and station.beam_covers(unit.global_position))


## Whether the radio net reaches `point`: within the command circle of a
## linked radio operator (which includes the operator itself).
func radio_reaches(point: Vector2) -> bool:
	var reach := radio_circle_m() * World.PX_PER_M
	for operator in linked_radio_operators():
		if operator.global_position.distance_to(point) <= reach:
			return true
	return false


## Whether a point is within earshot of the player's voice: inside its
## command circle.
func hears_voice(point: Vector2) -> bool:
	return global_position.distance_to(point) <= aura_radius_m * World.PX_PER_M
