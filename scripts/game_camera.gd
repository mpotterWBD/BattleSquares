extends Camera2D
## Scroll wheel zooms in and out.
##
## The camera follows the target (the player) but keeps the view inside the
## arena, plus EDGE_VIEW_M beyond it so the edge barrier (arena_edge.gd)
## stays in sight, whenever that fits. Zoomed all the way out the whole
## arena and its barrier fit on screen; otherwise it follows the player up
## to the edges.
##
## In radio command mode (World.radio_commanding, from a station's terminal)
## it switches to an RTS-style overview: it eases out and over to fit the
## player and every squadmate with OVERVIEW_MARGIN_M to spare, and keeps
## them all in view as they move. It never zooms in closer than you had it,
## and the wheel does nothing meanwhile. Hanging up eases it back to your
## zoom, following the player again.

const World = preload("res://scripts/world.gd")
const EDGE_VIEW_M := 2.0   ## how much ground past the arena edge the view can show
const OVERVIEW_MARGIN_M := 4.0   ## room round the units in the radio command overview

@export var target_path: NodePath = ^"../Player"
@export var min_zoom := 0.43    ## below 1 = see more of the field (0.43: the whole arena)
@export var max_zoom := 3.0     ## above 1 = close-up
@export var zoom_step := 1.15   ## change per wheel notch
@export var zoom_ease := 12.0   ## how quickly the zoom catches up
@export var move_ease := 5.0    ## how quickly it pans to and from the overview

var _target_zoom := 1.0
var _overview := false
var _user_zoom := 1.0       ## the zoom to go back to after the overview
var _easing_move := false   ## panning smoothly (into, during or out of the overview)

@onready var _target: Node2D = get_node(target_path)


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or _overview:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_zoom *= zoom_step
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_zoom /= zoom_step
	else:
		return
	_target_zoom = clampf(_target_zoom, min_zoom, max_zoom)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if World.radio_commanding != _overview:
		_overview = World.radio_commanding
		if _overview:
			_user_zoom = _target_zoom
		else:
			_target_zoom = _user_zoom
		_easing_move = true
	var focus := _target.position
	if _overview:
		var box := _units_box()
		focus = box.get_center()
		var view := get_viewport_rect().size
		_target_zoom = clampf(minf(view.x / box.size.x, view.y / box.size.y), min_zoom, _user_zoom)

	var z := lerpf(zoom.x, _target_zoom, 1.0 - exp(-zoom_ease * delta))
	if absf(z - _target_zoom) < 0.0005:
		z = _target_zoom
	zoom = Vector2(z, z)
	var wanted := _view_center_for(focus)
	if _easing_move:
		position = position.lerp(wanted, 1.0 - exp(-move_ease * delta))
		# Back on the player: follow it exactly again.
		if not _overview and position.distance_to(wanted) < 1.0:
			_easing_move = false
	else:
		position = wanted


## The player and every squadmate, with OVERVIEW_MARGIN_M round them.
func _units_box() -> Rect2:
	var box := Rect2(_target.position, Vector2.ZERO)
	for unit in get_tree().get_nodes_in_group("squad"):
		box = box.expand(unit.global_position)
	return box.grow(OVERVIEW_MARGIN_M * World.PX_PER_M)


## Centre the view on `point`, but slide it back so it stays inside the
## arena. On an axis where the view is wider than the arena, centre it.
func _view_center_for(point: Vector2) -> Vector2:
	var half := get_viewport_rect().size / zoom / 2.0
	var arena := World.ARENA.grow(EDGE_VIEW_M * World.PX_PER_M)
	var center := point
	for axis in 2:
		var lo := arena.position[axis] + half[axis]
		var hi := arena.end[axis] - half[axis]
		center[axis] = clampf(point[axis], lo, hi) if lo <= hi else arena.get_center()[axis]
	return center
