extends CanvasLayer
## The menu that comes up once the player has died and come to rest
## (player.gd): a small panel low on the screen, below the body, in the command
## menus' style (ui_style.gd), with Restart (the level again, from the
## start) and Quit. The game carries on behind it.

const UiStyle = preload("res://scripts/ui_style.gd")

const DIM := Color(0, 0, 0, 0.35)   ## darkens the screen behind the panel
const FADE_S := 0.4


func _ready() -> void:
	layer = 100
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	add_child(root)
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# In the lower part of the screen, clear of the body the camera's on.
	var centre := CenterContainer.new()
	centre.anchor_right = 1.0
	centre.anchor_top = 0.6
	centre.anchor_bottom = 0.9
	root.add_child(centre)
	var panel := UiStyle.panel()
	centre.add_child(panel)
	var column := UiStyle.menu_column("")
	column.get_child(0).queue_free()   # a caption instead of the small title
	var caption := UiStyle.caption("KILLED IN ACTION", 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var restart := UiStyle.menu_button("Restart")
	restart.pressed.connect(_restart)
	column.add_child(restart)
	var quit := UiStyle.menu_button("Quit")
	quit.pressed.connect(get_tree().quit)
	column.add_child(quit)
	panel.add_child(column)
	create_tween().tween_property(root, "modulate:a", 1.0, FADE_S)


func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
