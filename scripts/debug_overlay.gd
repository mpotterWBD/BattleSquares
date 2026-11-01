extends Node2D
## Debug mode (Q toggles World.debug): each live square's battle-log number
## (battle_log.gd number_of(): the player 0, the rest 1, 2...) shown just
## above its top-right corner, green for our side, red for enemies, so Mike
## can ask about "number 4" and it matches the log. Drawn on the screen
## (a CanvasLayer) so the numbers stay readable at any zoom. Made by
## command.gd; one per level.
##
## While it's on the player takes no controls (player.gd _hands_off()) and
## command mode stays shut (World.commanding()). A left click on a square
## picks it: a ring round it and a panel beside it with its number, name,
## the rounds in its magazine and its spare magazines (rifle.gd), kept up to
## date. A click on open ground, its death, or Q again drops it.

const World = preload("res://scripts/world.gd")
const BattleLog = preload("res://scripts/battle_log.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

const FONT_SIZE := 20
const OUTLINE := 5
const OFFSET_M := Vector2(0.2, -0.3)   ## from the square's centre, just past its top-right corner
const ENEMY_COLOR := Color(1.0, 0.4, 0.35)
const PICK_M := 0.4                    ## a click this close to a square's centre picks it
const RING_M := 0.4                    ## the picked square's ring
const PANEL_OFFSET := Vector2(48, 24)  ## the panel, from the picked square on screen (as player.gd's ammo panel)

var _layer: CanvasLayer
var _view: Node2D
var _picked: Node2D = null
var _panel: PanelContainer
var _name_label: Label
var _ammo_label: Label
var _mags_label: Label


func _ready() -> void:
	World.debug = false
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_view = Node2D.new()
	_view.draw.connect(_draw_numbers)
	_layer.add_child(_view)
	_panel = UiStyle.panel()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_name_label = UiStyle.title("", 15)
	_ammo_label = UiStyle.caption("", 20)
	_mags_label = UiStyle.title("", 15)
	column.add_child(_name_label)
	column.add_child(_ammo_label)
	column.add_child(_mags_label)
	_panel.add_child(column)
	_layer.add_child(_panel)
	_layer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug") and not event.is_echo():
		World.debug = not World.debug
		_layer.visible = World.debug
		_picked = null
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if World.debug and button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_picked = _square_at(get_viewport().get_canvas_transform().affine_inverse() * button.position)
		get_viewport().set_input_as_handled()


## The live, numbered square nearest world `point`, within PICK_M (null if none).
func _square_at(point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := PICK_M * World.PX_PER_M
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if unit.dead or not unit.is_visible_in_tree() or BattleLog.number_of(unit) < 0:
			continue
		var d := unit.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = unit
	return best


func _process(_delta: float) -> void:
	if not World.debug:
		return
	if _picked != null and (not is_instance_valid(_picked) or _picked.dead):
		_picked = null
	_update_panel()
	_view.queue_redraw()


## The picked square's details, beside it.
func _update_panel() -> void:
	_panel.visible = _picked != null
	if _picked == null:
		return
	var side := "enemy" if _picked.is_in_group("enemies") else ("player" if _picked.is_in_group("player") else "squad")
	var shown := "" if _picked.name.begins_with("@") else "  " + _picked.name   # spawned: no name of its own
	_name_label.text = "#%d%s  (%s)" % [BattleLog.number_of(_picked), shown, side]
	var rifle = _picked.get_node_or_null("Rifle")
	if rifle == null:
		_ammo_label.text = "no rifle"
		_mags_label.text = ""
	else:
		_ammo_label.text = "RELOADING" if rifle.reloading else "AMMO  %d / %d" % [rifle.rounds, rifle.mag_size]
		_ammo_label.add_theme_color_override("font_color",
				ENEMY_COLOR if rifle.rounds <= 0 and not rifle.reloading else UiStyle.COLOR)
		var spares: int = rifle.spare_count()
		_mags_label.text = "MAGS  unlimited" if spares < 0 else "MAGS  %d  (%d rounds)" % [spares, rifle.spare_rounds()]
	_panel.reset_size()
	_panel.position = get_viewport().get_canvas_transform() * _picked.global_position + PANEL_OFFSET


func _draw_numbers() -> void:
	var font := ThemeDB.fallback_font
	var to_screen := get_viewport().get_canvas_transform()
	var zoom := to_screen.get_scale().x
	_view.draw_string(font, Vector2(16, get_viewport().get_visible_rect().size.y - 16), "DEBUG (Q)  click a square for its details",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(World.COMMAND_COLOR, 0.8))
	if _picked != null:
		_view.draw_arc(to_screen * _picked.global_position, RING_M * World.PX_PER_M * zoom, 0.0, TAU, 40,
				Color(1.0, 0.85, 0.3, 0.9), 2.0, true)
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		var n := BattleLog.number_of(unit)
		if n < 0 or unit.dead or not unit.is_visible_in_tree():
			continue
		var at := to_screen * unit.global_position + OFFSET_M * World.PX_PER_M * zoom
		var color := ENEMY_COLOR if unit.is_in_group("enemies") else World.COMMAND_COLOR
		_view.draw_string_outline(font, at, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE, Color(0, 0, 0, 0.8))
		_view.draw_string(font, at, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
