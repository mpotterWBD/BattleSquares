extends Node
## The radio terminal at a station's desk (a child of scenes/radio_station.tscn).
## Stand in the platform's green box (the station's OperatorZone) and press F
## for the RADIO menu, beside the player like the command-mode menus:
##
##   Command  radio command mode (World.radio_commanding): command mode over
##            this station's radio net. Radio operators in its dish beam,
##            and anyone in their command circle, hear you, as well as
##            anyone in earshot of your voice (player.gd can_hear()). F
##            again, or stepping off the box, hangs up.
##   Deploy   hold for Troops / Vehicles (vehicles to come). Let go on Troops:
##              1. MAX_TROOPS slots, in rows of PER_ROW. Press a slot for
##                 the unit-type pop-out (Infantry or Radio operator; a
##                 quick click fills it with Infantry). Fill as many as you
##                 want.
##              2. filled slots are readied one after another,
##                 `seconds_per_troop` each
##              3. once they're all ready, Send helicopter: a ghost
##                 helicopter follows the mouse to mark the LZ (inside the
##                 play area; right click goes back), and a click sends a
##                 helicopter to fly them in (scripts/insertion.gd)
##
## The request and its countdown live here, so they carry on while the
## player is away; reopening the menu shows where they're at, and while the
## menu is closed a timer above the platform's box shows the total time
## left (or that the troops are ready). While the menu
## is open the player doesn't aim or fire (player.gd `busy`). F or Esc closes
## it.

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const HoldPopout = preload("res://scripts/hold_popout.gd")
const Insertion = preload("res://scripts/insertion.gd")
const HELICOPTER := preload("res://scenes/helicopter.tscn")

const COLOR := World.COMMAND_COLOR
const MAX_TROOPS := 10
const PER_ROW := 5
const MENU_GAP_PX := 36.0
const KINDS := [
	{id = "troops", text = "Troops"},
	{id = "vehicles", text = "Vehicles"},
]
## Unit types a troop slot can hold.
const UNIT_TYPES := [
	{id = "infantry", text = "Infantry"},
	{id = "radio", text = "Radio"},   ## infantry with a radio pack (soldier.gd kit)
]
const INFANTRY_RED := Color(0.85, 0.15, 0.12)
const PACK_BROWN := Color(0.42, 0.29, 0.16)
const LZ_OK := Color(0.7, 1.0, 0.7, 0.55)
const LZ_BAD := Color(1.0, 0.45, 0.45, 0.5)

@export var seconds_per_troop := 1.0   # 1 s for testing; was 30
@export var zone_path: NodePath = ^"../OperatorZone"
@export var pad_path: NodePath = ^"../StandBox"   ## the green box the "[F] Interact" prompt shows under

enum Screen { CLOSED, MENU, SLOTS, LZ }
var screen := Screen.CLOSED

## The troop request: one entry per slot, "" while empty or a unit type id.
var slots: Array[String] = []
var _pad_prompt: Label
var _pad_timer: Label
var _progress: Array[float] = []   ## seconds of readying done, per slot
var _queue: Array[int] = []        ## filled slots, in the order they were filled

var _owns_radio := false            ## this terminal switched radio command on
var _free_player_on_release := false
var _mouse_world := Vector2.ZERO
var _ghost: Node2D
var _type_for_slot := -1

var _layer: CanvasLayer
var _menu: VBoxContainer
var _deploy_button: Button
var _command_button: Button
var _kinds_popout: HoldPopout
var _types_popout: HoldPopout
var _slots_panel: PanelContainer
var _slots_grid: GridContainer
var _slot_buttons: Array[Button] = []
var _status_label: Label
var _send_button: Button

@onready var _zone: Area2D = get_node(zone_path)


func _ready() -> void:
	World.register_controls()
	_build_ui()
	_pad_prompt = _make_pad_prompt()
	get_node(pad_path).add_child(_pad_prompt)
	_pad_timer = _make_pad_timer()
	get_node(pad_path).add_child(_pad_timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if _owns_radio:
			hang_up()
			get_viewport().set_input_as_handled()
		elif screen != Screen.CLOSED:
			close()
			get_viewport().set_input_as_handled()
		elif _player_on_box() and not World.commanding():
			open_menu()
			get_viewport().set_input_as_handled()
		return
	if screen == Screen.CLOSED:
		return
	if event.is_action_pressed("ui_cancel"):
		if screen == Screen.LZ:
			_stop_lz(true)
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if screen != Screen.LZ:
		return
	# Marking the LZ: the ghost follows the mouse; left click sends, right
	# click goes back to the request.
	var mouse := event as InputEventMouse
	if mouse:
		_mouse_world = _to_world(mouse.position)
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT and _lz_ok(_mouse_world):
			_send_helicopter(_mouse_world)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_stop_lz(true)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_tick_readying(delta)
	var on_box := _player_on_box()
	_pad_prompt.visible = on_box and screen == Screen.CLOSED and not _owns_radio
	_update_pad_timer()
	if _owns_radio and not on_box:
		hang_up()
	if screen != Screen.CLOSED and (not on_box or (World.commanding() and not World.radio_commanding)):
		close()
	if _free_player_on_release and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_free_player_on_release = false
		if screen == Screen.CLOSED and _player():
			_player().busy = false
	match screen:
		Screen.MENU, Screen.SLOTS:
			_place_ui()
			_refresh_slots()
		Screen.LZ:
			_ghost.global_position = _mouse_world
			_ghost.modulate = LZ_OK if _lz_ok(_mouse_world) else LZ_BAD


# ----------------------------------------------------------------- opening --

func _player():
	return get_tree().get_first_node_in_group("player")


func _player_on_box() -> bool:
	var player = _player()
	return player != null and _zone.overlaps_body(player)


func open_menu() -> void:
	_show(Screen.MENU)
	_player().busy = true


func close() -> void:
	if screen == Screen.LZ:
		_stop_lz(false)
	_show(Screen.CLOSED)
	_release_player()


func hang_up() -> void:
	World.radio_commanding = false
	World.radio_station = null
	_owns_radio = false


## Frees the player to aim and fire again, but not while the left button is
## still down from the click that closed the menu (it would fire).
func _release_player() -> void:
	var player = _player()
	if player == null:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_free_player_on_release = true
	else:
		player.busy = false


func _show(which: Screen) -> void:
	screen = which
	_layer.visible = which in [Screen.MENU, Screen.SLOTS]
	_slots_panel.visible = which == Screen.SLOTS
	_kinds_popout.close()
	_types_popout.close()
	if which in [Screen.MENU, Screen.SLOTS]:
		_place_ui()


func _on_command() -> void:
	close()
	World.radio_commanding = true
	World.radio_station = get_parent()   # this station's dish carries the link
	_owns_radio = true


func _on_deploy_down() -> void:
	_kinds_popout.set_option("vehicles", "Vehicles (soon)", true)
	_kinds_popout.open(_deploy_button)


func _on_kind_chosen(kind: String, _at: Vector2) -> void:
	if kind != "troops":
		return
	if slots.is_empty():
		_new_request()
	_show(Screen.SLOTS)   # otherwise a request is already under way


# ------------------------------------------------------------- the request --

## MAX_TROOPS empty slots; fill as many as you want sent.
func _new_request() -> void:
	slots.clear()
	_progress.clear()
	_queue.clear()
	for i in MAX_TROOPS:
		slots.append("")
		_progress.append(0.0)


func _on_slot_down(index: int) -> void:
	if slots[index] != "":
		return   # already filled
	_type_for_slot = index
	_types_popout.open(_slot_buttons[index], "infantry", _slots_panel)   # left of the whole panel


func _on_type_chosen(unit_type: String, _at: Vector2) -> void:
	if _type_for_slot < 0 or slots[_type_for_slot] != "":
		return
	slots[_type_for_slot] = unit_type
	_queue.append(_type_for_slot)
	_type_for_slot = -1


func _on_clear() -> void:
	_new_request()


## Readies filled slots one at a time, in the order they were filled.
func _tick_readying(delta: float) -> void:
	for index in _queue:
		if _progress[index] < seconds_per_troop:
			_progress[index] = minf(_progress[index] + delta, seconds_per_troop)
			return


func _slot_ready(index: int) -> bool:
	return slots[index] != "" and _progress[index] >= seconds_per_troop


## Every filled slot is ready (and at least one is filled).
func troops_ready() -> bool:
	return not _queue.is_empty() and _queue.all(_slot_ready)


func _seconds_left() -> float:
	var left := 0.0
	for index in _queue:
		left += seconds_per_troop - _progress[index]
	return left


# -------------------------------------------------------------- the LZ --

func _on_send() -> void:
	if not troops_ready():
		return
	_show(Screen.LZ)
	_ghost = HELICOPTER.instantiate()
	# Just a picture: nothing running, no collisions, no shadows.
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_ghost.get_node("Hull/Outline").disabled = true
	_ghost.get_node("Shadows").visible = false
	_ghost.z_index = 45
	get_parent().get_parent().add_child(_ghost)
	_ghost.global_position = _mouse_world


func _stop_lz(back_to_request: bool) -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if back_to_request:
		_show(Screen.SLOTS)


## The LZ just has to be inside the play area.
func _lz_ok(point: Vector2) -> bool:
	return World.ARENA.has_point(point)


func _send_helicopter(lz: Vector2) -> void:
	var units := _queue.map(func(index: int) -> String: return slots[index])
	var heli: Node2D = HELICOPTER.instantiate()
	var run := Insertion.new()
	heli.add_child(run)
	get_parent().get_parent().add_child(heli)
	run.start(heli, lz, units)
	slots.clear()
	_progress.clear()
	_queue.clear()
	close()


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


# ---------------------------------------------------------------- the UI --

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.visible = false
	add_child(_layer)

	# RADIO, left of the player.
	_menu = UiStyle.menu_column("RADIO")
	_deploy_button = UiStyle.menu_button("Deploy")
	_deploy_button.button_down.connect(_on_deploy_down)
	_command_button = UiStyle.menu_button("Command")
	_command_button.pressed.connect(_on_command)
	_menu.add_child(_deploy_button)
	_menu.add_child(_command_button)
	_layer.add_child(_menu)

	_kinds_popout = HoldPopout.new()
	_kinds_popout.setup(KINDS, _draw_kind_icon, -1.0)
	_kinds_popout.chosen.connect(_on_kind_chosen)
	_types_popout = HoldPopout.new()
	_types_popout.setup(UNIT_TYPES, _draw_unit_icon, -1.0)
	_types_popout.chosen.connect(_on_type_chosen)

	# The request: slots, status and Send.
	_slots_panel = UiStyle.panel()
	var slots_box := VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	slots_box.add_child(UiStyle.title("TROOP REQUEST"))
	_slots_grid = GridContainer.new()
	_slots_grid.columns = PER_ROW
	_slots_grid.add_theme_constant_override("h_separation", 6)
	_slots_grid.add_theme_constant_override("v_separation", 6)
	slots_box.add_child(_slots_grid)
	_status_label = UiStyle.caption("", 18)
	slots_box.add_child(_status_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_send_button = UiStyle.menu_button("Send helicopter", Vector2(200, 42))
	_send_button.pressed.connect(_on_send)
	var clear := UiStyle.menu_button("Clear", Vector2(100, 42))
	clear.pressed.connect(_on_clear)
	row.add_child(_send_button)
	row.add_child(clear)
	slots_box.add_child(row)
	_slots_panel.add_child(slots_box)
	_slots_panel.visible = false
	_layer.add_child(_slots_panel)

	_layer.add_child(_kinds_popout)
	_layer.add_child(_types_popout)
	_build_slot_buttons()


func _build_slot_buttons() -> void:
	for i in MAX_TROOPS:
		var button := UiStyle.menu_button("", Vector2(56, 56))
		button.button_down.connect(_on_slot_down.bind(i))
		button.draw.connect(_draw_slot.bind(button, i))
		_slots_grid.add_child(button)
		_slot_buttons.append(button)


## RADIO just left of the player's square on screen; the slot panel just
## left of RADIO.
func _place_ui() -> void:
	var player = _player()
	if player == null:
		return
	var view := get_viewport().get_visible_rect()
	var canvas := get_viewport().get_canvas_transform()
	var at: Vector2 = canvas * player.global_position
	var half_square: float = 0.2 * World.PX_PER_M * canvas.get_scale().x
	_menu.reset_size()
	var menu_pos := Vector2(at.x - half_square - MENU_GAP_PX - _menu.size.x, at.y - _menu.size.y / 2.0)
	_menu.position = menu_pos.clamp(view.position, view.end - _menu.size)
	if _slots_panel.visible:
		_slots_panel.reset_size()
		var pos := Vector2(_menu.position.x - 12.0 - _slots_panel.size.x, at.y - _slots_panel.size.y / 2.0)
		_slots_panel.position = pos.clamp(view.position, view.end - _slots_panel.size)


func _refresh_slots() -> void:
	if screen != Screen.SLOTS:
		return
	for button in _slot_buttons:
		button.queue_redraw()
	var filled := _queue.size()
	_send_button.disabled = not troops_ready()
	if filled == 0:
		_status_label.text = "Press a slot to choose its unit"
	elif troops_ready():
		_status_label.text = "%d ready - send the helicopter" % filled
	else:
		_status_label.text = "%d of %d filled - ready in %s" % [filled, slots.size(), _clock(_seconds_left())]


func _clock(seconds: float) -> String:
	var left := ceili(seconds)
	return "%d:%02d" % [left / 60, left % 60]


## "[F] Interact" just under the platform's box while the player stands in
## it, styled like the station's "[F] Tune dish".
func _make_pad_prompt() -> Label:
	var settings := LabelSettings.new()
	settings.font_size = 16
	settings.font_color = Color(0.75, 1.0, 0.75)
	settings.outline_size = 5
	settings.outline_color = Color(0, 0, 0, 0.8)
	var label := Label.new()
	label.text = "[F] Interact"
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(140, 24)
	# Centred just under the box (145 px tall, centred on the pad).
	label.position = Vector2(-label.size.x / 2, 72.5 + 3.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 30
	label.visible = false
	return label


## The timer above the platform's box: how many troopers and the total time
## left, or that they're ready. Only while the menu is closed (the menu
## shows it otherwise).
func _make_pad_timer() -> Label:
	var settings := LabelSettings.new()
	settings.font_size = 26
	settings.font_color = COLOR
	settings.outline_size = 6
	settings.outline_color = Color(0, 0, 0, 0.8)
	var label := Label.new()
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(260, 36)
	# Centred just above the box (145 px tall, centred on the pad).
	label.position = Vector2(-label.size.x / 2, -72.5 - 6.0 - label.size.y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 30
	label.visible = false
	return label


func _update_pad_timer() -> void:
	_pad_timer.visible = screen == Screen.CLOSED and not _queue.is_empty()
	if not _pad_timer.visible:
		return
	var troops := _queue.size()
	var noun := "trooper" if troops == 1 else "troopers"
	if troops_ready():
		_pad_timer.text = "%d %s READY" % [troops, noun]
	else:
		_pad_timer.text = "%d %s  %s" % [troops, noun, _clock(_seconds_left())]


## A slot: "+" while empty; the unit's icon once filled, with a green fill
## rising as it's readied, and a bright border when ready.
func _draw_slot(button: Button, index: int) -> void:
	if index >= slots.size():
		return
	var rect := Rect2(Vector2.ZERO, button.size)
	var c := rect.get_center()
	if slots[index] == "":
		button.draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), Color(COLOR, 0.6), 2.0)
		button.draw_line(c + Vector2(0, -9), c + Vector2(0, 9), Color(COLOR, 0.6), 2.0)
		return
	var done: float = _progress[index] / seconds_per_troop
	var inner := rect.grow(-4)
	if done < 1.0:
		var fill_h := inner.size.y * done
		button.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - fill_h), Vector2(inner.size.x, fill_h)),
				Color(COLOR, 0.3))
	_draw_unit(button, slots[index], c, 1.0 if done >= 1.0 else 0.6)
	if done >= 1.0:
		button.draw_rect(inner, COLOR, false, 2.0)


## A unit's icon, facing up: a red square with a rifle poking out; a radio
## operator also has a brown pack on its back with an antenna.
func _draw_unit(canvas: CanvasItem, unit: String, center: Vector2, alpha: float) -> void:
	if unit == "radio":
		center.y -= 4.0   # room below for the pack
		var pack := Rect2(center + Vector2(-7, 8), Vector2(14, 6))
		canvas.draw_rect(pack, Color(PACK_BROWN, alpha))
		canvas.draw_rect(pack, Color(0, 0, 0, 0.6 * alpha), false, 1.0)
		canvas.draw_line(center + Vector2(-4, 13), center + Vector2(-9, 19), Color(0.05, 0.05, 0.05, alpha), 1.5)
	canvas.draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color(INFANTRY_RED, alpha))
	canvas.draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color(0, 0, 0, 0.6 * alpha), false, 1.0)
	canvas.draw_line(center + Vector2(5, -4), center + Vector2(5, -16), Color(0.25, 0.26, 0.27, alpha), 3.0)


func _draw_unit_icon(icon: Control, unit: Dictionary) -> void:
	_draw_unit(icon, unit.id, icon.size / 2.0, 1.0)


## Troops: three little squares; vehicles: a helicopter-ish cross.
func _draw_kind_icon(icon: Control, kind: Dictionary) -> void:
	var c := icon.size / 2.0
	if kind.id == "troops":
		for dx in [-12.0, 0.0, 12.0]:
			var square := Rect2(c + Vector2(dx - 4, -4), Vector2(8, 8))
			icon.draw_rect(square, INFANTRY_RED)
			icon.draw_rect(square, Color(0, 0, 0, 0.6), false, 1.0)
	else:
		icon.draw_line(c + Vector2(-14, 0), c + Vector2(10, 0), COLOR, 4.0)
		icon.draw_line(c + Vector2(4, -11), c + Vector2(4, 11), COLOR, 1.5)
		icon.draw_line(c + Vector2(-7, -11), c + Vector2(15, 11), COLOR, 1.5)
