extends Node2D
## A deployed comms station (scenes/radio_station.tscn), compact: the
## operator platform with its desk, and just south of it, no wider than the
## platform, the antenna: a small satellite dish you aim by hand. (Until
## 2026-10-29 it also had a 7 m guyed mast.) The node's origin is the
## middle of the whole thing, so the deploy ghost centres on the mouse.
##
## Stand in the green box beside the dish (west of it) and press F (the "interact" control)
## to tune it. A wheel opens around the dish with a white line that follows
## the mouse: that only picks the heading, the dish stays put. Left click or
## F again locks the pick in (`target_heading`) and the dish then turns to
## it slowly (TURN_DEG_PER_S, easing in and out). A very big translucent cone
## comes out of the dish to show where it actually points, in the same
## green and see-through as the command circles; it shows while tuning and in
## command mode (holding Space), not while the dish turns on its own. Stepping out of the box or pressing Space closes
## the wheel without changing the pick. Where the dish points is kept in
## `dish_heading`, and `dish_tuned` is announced once it gets there, for the
## long-range comms to come. While tuning, the player doesn't aim or fire
## (player.gd `busy`).
##
## The platform's green box (OperatorZone) is where the operator stands to
## work the radio: see the Terminal node (scripts/radio_terminal.gd).
##
## The dish is its own sprite, lit from straight overhead so it can turn to
## any heading; its shadow is its outline swept across the dish's height
## range (shaders/shadow_sweep.gdshader).

signal dish_tuned(heading: float)

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

const DISH_AT := Vector2(0, 93.9)         ## the dish's post; matches DISH_AT in blender/scripts/radio_station.py
const DISH_LOW_M := 0.78                  ## the turning parts' lowest and highest points (head to top of the rim), for their shadow
const DISH_HIGH_M := 1.72
const DISH_TEXEL_PX := 0.5                ## the dish image is rendered at 2x the game's pixel density
const BEAM_LENGTH_M := 60.0
const BEAM_HALF_DEG := 18.0
const BEAM_COLOR := World.COMMAND_COLOR    ## same green as the command circles and menus
const WHEEL_RADIUS_PX := 150.0
const WHEEL_COLOR := World.COMMAND_COLOR
const TURN_DEG_PER_S := 12.0    ## the dish's top turning speed: half a turn takes ~15 s
const TURN_ACCEL_DEG := 10.0    ## per second per second, winding up to that speed
const TURN_EASE_PER_S := 1.2    ## slows down over the last stretch: speed <= this x degrees left

## Where the dish points, in radians (0 = right, PI/2 = down). It's built
## facing south (down).
@export var dish_heading := PI / 2

## Where the dish has been told to point; it turns toward this.
var target_heading := 0.0
var tuning := false
var turning := false

## The heading being picked on the wheel (follows the mouse while tuning).
var _pick := 0.0
var _turn_speed := 0.0   ## degrees per second

## After a click locks the heading in, the player stays busy until the
## mouse button comes up. Freeing it straight away would let that same
## click count as a fresh trigger pull and fire the rifle.
var _free_player_on_release := false
var _wheel_layer: CanvasLayer
var _wheel: Control
var _pad_key: Label

@onready var _dish: Sprite2D = $Dish
@onready var _dish_shadow: Sprite2D = $DishShadow
@onready var _zone: Area2D = $DishZone
@onready var _prompt: Label = $DishPrompt
@onready var _beam: Node2D = $Beam


func _ready() -> void:
	World.register_controls()
	_beam.draw.connect(_draw_beam)
	_pad_key = UiStyle.pad_key()
	$DishStandBox.add_child(_pad_key)
	_wheel_layer = CanvasLayer.new()
	_wheel_layer.visible = false
	add_child(_wheel_layer)
	_wheel = Control.new()
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.draw.connect(_draw_wheel)
	_wheel_layer.add_child(_wheel)
	target_heading = dish_heading
	_update_dish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if tuning:
			_stop_tuning(true)
			get_viewport().set_input_as_handled()
		elif _player_at_dish() and not World.commanding():
			_start_tuning()
			get_viewport().set_input_as_handled()
		return
	if not tuning:
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	_pick_at(get_canvas_transform().affine_inverse() * mouse.position)
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_stop_tuning(true, true)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _free_player_on_release and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_free_player_on_release = false
		var player = _player()
		if player and not tuning:
			player.busy = false
	var at_dish := _player_at_dish()
	_prompt.visible = at_dish and not tuning
	_pad_key.visible = _prompt.visible
	if tuning and (not at_dish or World.commanding()):
		_stop_tuning()
	if turning:
		_turn(delta)
	if tuning:
		_wheel.position = get_canvas_transform() * to_global(DISH_AT)
		_wheel.queue_redraw()
	# The beam shows while tuning, and in command mode so you can see where
	# each dish is pointed while giving orders.
	_beam.visible = tuning or World.commanding()
	if _beam.visible:
		_beam.queue_redraw()


func _player():
	return get_tree().get_first_node_in_group("player")


## Whether a world point is inside the dish's beam: the radio link reaches
## radio operators there (player.gd radio_reaches()).
func beam_covers(point: Vector2) -> bool:
	var to := point - to_global(DISH_AT)
	if to.length() > BEAM_LENGTH_M * World.PX_PER_M:
		return false
	return absf(angle_difference(dish_heading + global_rotation, to.angle())) <= deg_to_rad(BEAM_HALF_DEG)


func _player_at_dish() -> bool:
	var player = _player()
	return player != null and _zone.overlaps_body(player)


func _start_tuning() -> void:
	tuning = true
	_pick = target_heading
	_wheel_layer.visible = true
	_player().busy = true


## `lock`: the pick becomes the dish's new target and it starts turning
## (left click or F); otherwise the wheel just closes (walked off, Space).
## `by_click`: closed with the left mouse button, which is still down, so
## the player is only freed once it's released (see _free_player_on_release).
func _stop_tuning(lock := false, by_click := false) -> void:
	tuning = false
	_wheel_layer.visible = false
	var player = _player()
	if by_click:
		_free_player_on_release = true
	elif player:
		player.busy = false
	if lock:
		target_heading = _pick
		turning = true


## Picks the heading toward a world point (the mouse, while tuning). The
## dish doesn't move until the pick is locked in.
func _pick_at(point: Vector2) -> void:
	var from := to_global(DISH_AT)
	if from.distance_to(point) < 4.0:
		return   # mouse on the hub: no clear direction
	_pick = (point - from).angle()


## Turns the dish a step toward target_heading, the short way round:
## winds up to TURN_DEG_PER_S, then eases off as it closes in.
func _turn(delta: float) -> void:
	var left := absf(rad_to_deg(angle_difference(dish_heading, target_heading)))
	_turn_speed = minf(_turn_speed + TURN_ACCEL_DEG * delta, TURN_DEG_PER_S)
	var speed := minf(_turn_speed, maxf(left * TURN_EASE_PER_S, 1.0))
	if left <= speed * delta:
		dish_heading = target_heading
		turning = false
		_turn_speed = 0.0
		dish_tuned.emit(dish_heading)
	else:
		dish_heading = rotate_toward(dish_heading, target_heading, deg_to_rad(speed * delta))
	_update_dish()


func _update_dish() -> void:
	# The image shows the dish facing down (PI/2).
	_dish.rotation = dish_heading - PI / 2
	_dish_shadow.rotation = _dish.rotation
	var sun := World.SUN_DIR * tan(deg_to_rad(World.SUN_TILT_DEG)) * World.PX_PER_M
	_dish_shadow.position = DISH_AT + sun * DISH_LOW_M
	# How far the shadow stretches from the dish's lowest to highest point,
	# in the dish image's own (rotated, half-size) pixels.
	var sweep: Vector2 = (sun * (DISH_HIGH_M - DISH_LOW_M)).rotated(-_dish_shadow.rotation) / DISH_TEXEL_PX
	(_dish_shadow.material as ShaderMaterial).set_shader_parameter("sweep", sweep)


## The beam: a very big cone out of the dish along its heading, drawn with
## the shared command alphas (world.gd CONE_*): a fading fill and a faint
## outline, same green and see-through.
func _draw_beam() -> void:
	var reach := BEAM_LENGTH_M * World.PX_PER_M
	var half := deg_to_rad(BEAM_HALF_DEG)
	var near := Color(BEAM_COLOR, World.CONE_NEAR_ALPHA)
	var far := Color(BEAM_COLOR, World.CONE_FAR_ALPHA)
	var rim := PackedVector2Array()
	for i in 25:
		rim.append(DISH_AT + Vector2.from_angle(dish_heading - half + 2.0 * half * i / 24.0) * reach)
	for i in rim.size() - 1:
		_beam.draw_polygon(PackedVector2Array([DISH_AT, rim[i], rim[i + 1]]),
				PackedColorArray([near, far, far]))
	var edge := Color(BEAM_COLOR, World.CONE_EDGE_ALPHA)
	_beam.draw_line(DISH_AT, rim[0], edge, 1.5, true)
	_beam.draw_line(DISH_AT, rim[rim.size() - 1], edge, 1.5, true)
	_beam.draw_polyline(rim, edge, 1.5, true)


## The tuning wheel, drawn around the dish on screen: a ring with compass
## ticks and N/E/S/W, a green line where the dish points now, and the white
## line being picked with the mouse.
func _draw_wheel() -> void:
	var r := WHEEL_RADIUS_PX
	_wheel.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.25))
	_wheel.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(WHEEL_COLOR, 0.85), 3.0, true)
	for deg in range(0, 360, 15):
		var a := deg_to_rad(deg)
		var length := 16.0 if deg % 90 == 0 else (10.0 if deg % 45 == 0 else 6.0)
		var dir := Vector2.from_angle(a)
		_wheel.draw_line(dir * (r - length), dir * r, Color(WHEEL_COLOR, 0.85), 2.0, true)
	var font := ThemeDB.fallback_font
	for mark in [["N", -PI / 2], ["E", 0.0], ["S", PI / 2], ["W", PI]]:
		var at: Vector2 = Vector2.from_angle(mark[1]) * (r + 18.0)
		_wheel.draw_string_outline(font, at + Vector2(-6, 7), mark[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color.BLACK)
		_wheel.draw_string(font, at + Vector2(-6, 7), mark[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, WHEEL_COLOR)
	_wheel.draw_line(Vector2.ZERO, Vector2.from_angle(dish_heading) * (r * 0.6), Color(WHEEL_COLOR, 0.9), 4.0, true)
	var tip := Vector2.from_angle(_pick) * (r - 4.0)
	_wheel.draw_line(Vector2.ZERO, tip, Color.WHITE, 3.0, true)
	_wheel.draw_circle(tip, 6.0, Color.WHITE)
	_wheel.draw_circle(Vector2.ZERO, 5.0, Color(WHEEL_COLOR, 0.9))
	var bearing := fposmod(rad_to_deg(_pick) + 90.0, 360.0)   # compass: 0 = north, clockwise
	var text := "AZ %03d" % roundi(bearing)
	var at := Vector2(-34, -r + 52)   # inside the ring, under the N mark
	_wheel.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color.BLACK)
	_wheel.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
