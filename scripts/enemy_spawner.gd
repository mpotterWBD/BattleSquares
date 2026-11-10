extends Node2D
## A testing aid: drops enemies by helicopter wherever you click (Mike,
## 2026-11-09; it used to send patrols in from the right of the old field).
##
## A small HUD panel in the top right corner: How many (1 to MAX_COUNT), then
## Drop by helicopter. A ghost of the helicopter (enemy blue) follows the mouse
## over the field; a left click anywhere in the play area sends an enemy
## helicopter to land there and let them out (scripts/insertion.gd with
## `enemy` on: it comes in from the west, as ours do), and each walks a step
## clear of the door and stands there calm, fighting anyone it spots
## (enemy.gd). Right click or Esc cancels; red where it can't land (off the
## field).
##
## While the mouse is over the panel, or a drop is being placed, the player is
## `busy`, so clicking doesn't fire the rifle.

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Insertion = preload("res://scripts/insertion.gd")
const HELICOPTER := preload("res://scenes/helicopter.tscn")

const MAX_COUNT := 10
const ENEMY_TINT := Color(0.62, 0.72, 1.0)     ## the enemy helicopter, against ours (enemy blue)
const GHOST_OK := Color(0.62, 0.72, 1.0, 0.55)
const GHOST_BAD := Color(1.0, 0.45, 0.45, 0.5)

## Dropped enemies' health (the Inspector; main.tscn's spawner has 4 for testing).
@export var enemy_health := 2.0

var _count: SpinBox
var _status: Label
var _panel: PanelContainer
var _made_busy := false
var _ghost: Node2D = null   ## placing a drop: the helicopter following the mouse
var _mouse_world := Vector2.ZERO


func _ready() -> void:
	_build_hud()


func _process(_delta: float) -> void:
	if _ghost != null:
		_mouse_world = get_global_mouse_position()
		_ghost.global_position = _mouse_world
		_ghost.modulate = GHOST_OK if can_land(_mouse_world) else GHOST_BAD
		if World.commanding():
			_stop_placing()   # (command mode takes the clicks)
	_keep_clicks_off_the_rifle()


func _unhandled_input(event: InputEvent) -> void:
	if _ghost == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("back"):
		_stop_placing()
		_status.text = "Cancelled"
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		var at := get_global_mouse_position()
		if can_land(at):
			_stop_placing()
			drop(int(_count.value), at)
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		_stop_placing()
		_status.text = "Cancelled"
	get_viewport().set_input_as_handled()


## Whether a helicopter can set down at `at` (world px): inside the play area,
## clear of its edge.
func can_land(at: Vector2) -> bool:
	return World.ARENA.grow(-6.0 * World.PX_PER_M).has_point(at)


## Sends an enemy helicopter to land at `at` (world px) and let `count` enemies out.
func drop(count: int, at: Vector2) -> void:
	count = clampi(count, 1, MAX_COUNT)
	var heli: Node2D = HELICOPTER.instantiate()
	heli.modulate = ENEMY_TINT
	var run := Insertion.new()
	run.enemy = true
	run.enemy_health = enemy_health
	heli.add_child(run)
	get_parent().add_child(heli)
	var types: Array = []
	for i in count:
		types.append("enemy")
	run.start(heli, at, types)
	_status.text = "%d on the way to (%d, %d) m" % [count, roundi(at.x / World.PX_PER_M), roundi(at.y / World.PX_PER_M)]


func _start_placing() -> void:
	if _ghost != null:
		return
	_count.get_line_edit().release_focus()
	_ghost = HELICOPTER.instantiate()
	# Just a picture: nothing running, no collisions, no shadows.
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_ghost.get_node("Hull/Outline").disabled = true
	_ghost.get_node("Shadows").visible = false
	_ghost.z_index = 45
	get_parent().add_child(_ghost)
	_ghost.global_position = get_global_mouse_position()
	_status.text = "Click where it lands   [right click] cancel"


func _stop_placing() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null


# --------------------------------------------------------------------- HUD --

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_panel = UiStyle.panel()
	layer.add_child(_panel)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	var column := UiStyle.menu_column("ENEMY DROP (testing)")
	_panel.add_child(column)

	var count_row := HBoxContainer.new()
	count_row.add_child(UiStyle.title("How many", 16))
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = MAX_COUNT
	_count.value = 4
	_count.custom_minimum_size.x = 90
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Typing a number: let go of the keyboard afterwards, so WASD walks again.
	_count.get_line_edit().text_submitted.connect(func(_t): _count.get_line_edit().release_focus())
	count_row.add_child(_count)
	column.add_child(count_row)

	var button := UiStyle.menu_button("Drop by helicopter", Vector2(220, 36))
	button.pressed.connect(_start_placing)
	column.add_child(button)
	_status = UiStyle.title("", 14)
	column.add_child(_status)


## The rifle fires on a left click wherever it lands, so while the mouse is
## over the panel, or a drop's being placed, the player is made `busy`.
func _keep_clicks_off_the_rifle() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var over := _ghost != null or _panel.get_global_rect().has_point(_panel.get_global_mouse_position())
	if over and not _made_busy and not player.busy:
		player.busy = true
		_made_busy = true
	elif not over and _made_busy:
		# (the click that dropped them is still down: let go of it first, or it'd fire)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		player.busy = false
		_made_busy = false
