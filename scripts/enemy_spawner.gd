extends Node2D
## A testing aid: summons patrols of enemies from the right of the field.
##
## A small HUD panel in the top right corner picks how many (1 to MAX_COUNT)
## and their formation, and its Spawn button sends them in from one of three
## regions along the field's right edge (top, middle, bottom thirds), chosen
## at random. The regions are drawn faintly on the ground, and the one they
## came from flashes. Each spawn is a patrol (scripts/patrol.gd) walking
## right to left; its enemies (scenes/enemy.tscn) fight anyone they spot,
## then rejoin it and walk on (enemy.gd).
##
## Formations, facing the way they walk, `gap_m` apart:
##   Column  single file
##   Line    side by side
##   Wedge   an arrowhead: a leader, then pairs further back each side
##
## While the mouse is over the panel (or its formation list is open) the
## player is `busy`, so clicking it doesn't fire the rifle.

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Patrol = preload("res://scripts/patrol.gd")
const ENEMY := preload("res://scenes/enemy.tscn")

const FORMATIONS := ["Column", "Line", "Wedge"]
const REGION_NAMES := ["top", "middle", "bottom"]
const MAX_COUNT := 12
const REGION_W_M := 3.0           ## how far in from the right edge the regions reach
const SPAWN_MARGIN_M := 0.8       ## the rearmost enemy starts this far in from the edge
const REGION_COLOR := Color(0.35, 0.55, 1.0)   ## enemy blue
const FLASH_S := 2.0

## Space between enemies in a formation.
@export_range(0.8, 5.0, 0.1, "suffix:m") var gap_m := 1.6
## Spawned enemies' health (the placed ones in main.tscn have 2 for testing).
@export var enemy_health := 2.0

var _count: SpinBox
var _formation: OptionButton
var _status: Label
var _panel: PanelContainer
var _flash_region := -1
var _flash_left := 0.0
var _made_busy := false


func _ready() -> void:
	z_index = -20   # on the ground, under the squares
	_build_hud()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()
	_keep_clicks_off_the_rifle()


## Sends `count` enemies in `formation` from a random region on the right.
func spawn(count: int, formation: String) -> void:
	var px := World.PX_PER_M
	var region := randi() % REGION_NAMES.size()
	var offsets := _formation_offsets(count, formation)   # metres: x ahead, y to the side
	var depth := 0.0
	var side_lo := 0.0
	var side_hi := 0.0
	for o: Vector2 in offsets:
		depth = maxf(depth, -o.x)
		side_lo = minf(side_lo, o.y)
		side_hi = maxf(side_hi, o.y)
	var band := World.ARENA.size.y / REGION_NAMES.size()
	var y := World.ARENA.position.y + band * (region + 0.5) + randf_range(-0.25, 0.25) * band
	var edge := 0.5 * px
	y = clampf(y, World.ARENA.position.y + edge - side_lo * px, World.ARENA.end.y - edge - side_hi * px)
	var patrol := Patrol.new()
	patrol.heading = Vector2.LEFT
	patrol.anchor = Vector2(World.ARENA.end.x - (SPAWN_MARGIN_M + depth) * px, y)
	get_parent().add_child(patrol)
	var area := World.ARENA.grow(-edge)
	for o: Vector2 in offsets:
		var enemy: Node2D = ENEMY.instantiate()
		var offset := Vector2(-o.x, o.y) * px   # walking left: ahead is -x
		enemy.position = (patrol.anchor + offset).clamp(area.position, area.end)
		enemy.max_health = enemy_health
		patrol.add(enemy, offset)
		get_parent().add_child(enemy)
	_flash_region = region
	_flash_left = FLASH_S
	_status.text = "%d in a %s from the %s" % [count, formation.to_lower(), REGION_NAMES[region]]
	queue_redraw()


## Each enemy's place in the formation, in metres: x ahead of the leader
## (0 or less), y to the side.
func _formation_offsets(count: int, formation: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in count:
		match formation:
			"Line":
				out.append(Vector2(0.0, (i - (count - 1) / 2.0) * gap_m))
			"Wedge":
				var row := (i + 1) / 2
				var side := 0.0 if i == 0 else (-1.0 if i % 2 == 1 else 1.0)
				out.append(Vector2(-row * gap_m * 0.8, side * row * gap_m * 0.8))
			_:   # Column
				out.append(Vector2(-i * gap_m, 0.0))
	return out


func _draw() -> void:
	var px := World.PX_PER_M
	var band := World.ARENA.size.y / REGION_NAMES.size()
	for i in REGION_NAMES.size():
		var rect := Rect2(World.ARENA.end.x - REGION_W_M * px, World.ARENA.position.y + band * i,
				REGION_W_M * px, band).grow(-4.0)
		var lit := clampf(_flash_left / FLASH_S, 0.0, 1.0) if i == _flash_region else 0.0
		draw_rect(rect, Color(REGION_COLOR, 0.05 + 0.25 * lit))
		draw_rect(rect, Color(REGION_COLOR, 0.3 + 0.6 * lit), false, 2.0)


# --------------------------------------------------------------------- HUD --

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_panel = UiStyle.panel()
	layer.add_child(_panel)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	var column := UiStyle.menu_column("ENEMY SPAWN (testing)")
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

	var formation_row := HBoxContainer.new()
	formation_row.add_child(UiStyle.title("Formation", 16))
	_formation = OptionButton.new()
	_formation.focus_mode = Control.FOCUS_NONE
	for f in FORMATIONS:
		_formation.add_item(f)
	_formation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation_row.add_child(_formation)
	column.add_child(formation_row)

	var button := UiStyle.menu_button("Spawn", Vector2(200, 36))
	button.pressed.connect(func():
		_count.get_line_edit().release_focus()
		spawn(int(_count.value), FORMATIONS[_formation.selected]))
	column.add_child(button)
	_status = UiStyle.title("", 14)
	column.add_child(_status)


## The rifle fires on a left click wherever it lands, so while the mouse is
## over the panel (or its list is open) the player is made `busy`.
func _keep_clicks_off_the_rifle() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var over := (_panel.get_global_rect().has_point(_panel.get_global_mouse_position())
			or _formation.get_popup().visible)
	if over and not _made_busy and not player.busy:
		player.busy = true
		_made_busy = true
	elif not over and _made_busy:
		player.busy = false
		_made_busy = false
