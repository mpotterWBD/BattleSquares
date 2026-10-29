extends VBoxContainer
## A list that pops out beside a held menu button: press and hold the
## button, slide onto an option, let go to choose it. A quick click on the
## button itself picks `open()`'s default (if any); letting go anywhere else
## cancels. Disabled options can't be chosen.
##
## Each option is a panel with an icon (drawn by the `draw_icon` callable
## given to setup(), called with (icon Control, option)) and a caption.
##
## Its controls ignore the mouse: while a button is held the GUI keeps
## sending events to that button, so hovering and the release are worked
## out here, from event positions, in _input.
##
## Used by command mode (formation shapes, equipment) and the radio terminal
## (troops/vehicles, unit types).

## Emitted when an option is chosen. `at` is where the mouse button was let
## go, in viewport coordinates.
signal chosen(id: String, at: Vector2)

const UiStyle = preload("res://scripts/ui_style.gd")

## -1: opens to the left of the button; 1: to its right.
var side := -1.0

var _panels := {}      ## option id -> PanelContainer
var _captions := {}    ## option id -> Label
var _disabled := {}    ## option id -> true while it can't be chosen
var _source: Button
var _default := ""
var _hover := ""


## Builds one panel per option ({id, text, ...}). Call once.
func setup(options: Array, draw_icon: Callable, opens_to := -1.0) -> void:
	side = opens_to
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	visible = false
	for option in options:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(150, 46)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(44, 30)
		icon.draw.connect(draw_icon.bind(icon, option))
		var label := UiStyle.caption(option.text)
		row.add_child(icon)
		row.add_child(label)
		panel.add_child(row)
		add_child(panel)
		_panels[option.id] = panel
		_captions[option.id] = label
	_restyle()


## Changes an option's caption and whether it can be chosen.
func set_option(id: String, text: String, disabled := false) -> void:
	_captions[id].text = text
	_disabled[id] = disabled
	_restyle()


## Opens beside `source` (a button being held down), centred on it. With
## `beside` (e.g. the panel the button sits in), opens beside that instead,
## top-aligned with it, so the list doesn't cover the panel. A quick click
## on the button itself chooses `default_choice` ("" = nothing).
func open(source: Button, default_choice := "", beside: Control = null) -> void:
	_source = source
	_default = default_choice
	reset_size()
	var rect := (beside if beside else source).get_global_rect()
	var x := rect.position.x - 10.0 - size.x if side < 0.0 else rect.end.x + 10.0
	var y := rect.position.y if beside else rect.get_center().y - size.y / 2.0
	var pos := Vector2(x, y)
	var view := get_viewport().get_visible_rect()
	position = pos.clamp(view.position, view.end - size)
	_hover = ""
	visible = true
	_restyle()


func close() -> void:
	visible = false
	_source = null
	_hover = ""


func is_open() -> bool:
	return visible


## The option under `screen` (viewport coordinates), or "".
func option_at(screen: Vector2) -> String:
	for id in _panels:
		if not _disabled.get(id, false) and _panels[id].get_global_rect().has_point(screen):
			return id
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	var hover := option_at(mouse.position)
	if hover != _hover:
		_hover = hover
		_restyle()
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		var choice := _hover
		if choice == "" and _source and _source.get_global_rect().has_point(button.position):
			choice = _default   # a quick click on the button itself
		close()
		if choice != "":
			chosen.emit(choice, button.position)


func _restyle() -> void:
	for id in _panels:
		var hot: bool = id == _hover
		var off: bool = _disabled.get(id, false)
		var fill := Color(0.2, 0.55, 0.2, 0.7) if hot else Color(0, 0, 0, 0.25 if off else 0.45)
		_panels[id].add_theme_stylebox_override("panel", UiStyle.box(fill, 1.0 if hot else (0.25 if off else 0.7)))
		_captions[id].modulate.a = 0.4 if off else 1.0
