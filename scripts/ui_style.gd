extends RefCounted
## The shared look of the in-game menus: see-through dark buttons and panels
## with green borders and text (World.COMMAND_COLOR). Used by command mode
## (scripts/command.gd), the radio terminal (scripts/radio_terminal.gd) and
## the hold-to-choose pop-outs (scripts/hold_popout.gd). Load with:
##     const UiStyle = preload("res://scripts/ui_style.gd")

const World = preload("res://scripts/world.gd")
const COLOR := World.COMMAND_COLOR


static func menu_button(text: String, min_size := Vector2(170, 42)) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE   # keyboard keys (Space!) don't press it
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(COLOR, 0.35))
	var fills := {
		"normal": Color(0, 0, 0, 0.35),
		"hover": Color(0.1, 0.35, 0.1, 0.55),
		"pressed": Color(0.2, 0.55, 0.2, 0.7),
		"disabled": Color(0, 0, 0, 0.2),
	}
	for style: String in fills:
		button.add_theme_stylebox_override(style, box(fills[style], 0.25 if style == "disabled" else 0.7))
	return button


## A column of menu buttons under a small title.
static func menu_column(title_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	column.add_child(title(title_text))
	return column


static func title(text: String, size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(COLOR, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 4)
	return label


static func caption(text: String, size := 22) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 4)
	return label


## A rounded panel style: `fill` behind, a green border at `edge_alpha`.
static func box(fill: Color, edge_alpha := 0.7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(COLOR, edge_alpha)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style


## A see-through panel to hold other menu controls.
static func panel() -> PanelContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.45)))
	return container


## The big white bold "F" centred on an interaction pad (a station's green
## box) while the player stands on it: F is the interact key. Add it as a
## child of the pad, centred on the pad's origin, and toggle `visible`.
## It draws over the squares so the player doesn't hide it.
static func pad_key(text := "F") -> Label:
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.2
	var settings := LabelSettings.new()
	settings.font = bold
	settings.font_size = 64
	settings.font_color = Color.WHITE
	settings.outline_size = 10
	settings.outline_color = Color(0, 0, 0, 0.6)
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(100, 100)
	label.position = -label.size / 2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 30
	label.visible = false
	return label
