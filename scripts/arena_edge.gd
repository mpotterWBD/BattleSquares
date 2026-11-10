@tool
extends Node2D
## The barrier round the play area (World.ARENA): a light boundary line
## with small posts every POST_EVERY_M, and the ground beyond it dimmed so
## it's clear where the field ends. Squares can't cross it (soldier.gd keeps
## them inside, so anything placed outside is moved in when the game
## starts); this just shows where it is. It's a @tool script, so the same
## boundary shows in the editor while placing things in main.tscn.
##
## In the editor only (Mike, 2026-11-09: the 2D editor still showed the old
## 45 m field): the field is 2.28 km across now, but main.tscn's grass sprite
## only covers the old field there (field.gd tiles it in the game, not in the
## editor), so grass is drawn over the whole arena under everything else
## (`_editor_grass`), and the edge is also drawn as a line one screen pixel
## wide at any zoom (at the zoom that fits 2 km on screen, the game's 3 px line
## is far thinner than a pixel). It redraws if the arena changes (a script reload).

const World = preload("res://scripts/world.gd")
const GRASS := preload("res://assets/textures/field_grass_tile.png")
const EDITOR_EDGE_COLOR := Color(1.0, 0.85, 0.3)   ## the editor's 1-pixel edge line: bright, to find it zoomed right out

const LINE_COLOR := Color(0.92, 0.9, 0.82, 0.85)
const LINE_WIDTH_PX := 3.0
const SHADOW_COLOR := Color(0, 0, 0, 0.35)   ## a thin dark line under it, so it reads on light grass
const POST_EVERY_M := 4.0
const POST_RADIUS_PX := 5.0
const POST_COLOR := Color(0.22, 0.2, 0.17)
const OUTSIDE_COLOR := Color(0, 0, 0, 0.3)
const OUTSIDE_PX := 4000.0   ## how far the dimming reaches beyond the edge


var _editor_grass: Node2D = null
var _drawn := Rect2()   ## the arena as last drawn (the editor: redrawn if it changes)


func _ready() -> void:
	z_index = -50   # over the grass and ground props, under the squares
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_make_editor_grass()


func _process(_delta: float) -> void:
	# (the editor only: after world.gd changes, the arena's a new size)
	if _drawn != World.ARENA:
		queue_redraw()
		if _editor_grass:
			_editor_grass.queue_redraw()


## The editor's grass over the whole arena, under main.tscn's Field (z -100), not saved with the scene.
func _make_editor_grass() -> void:
	for child in get_children(true):   # one left over from before a script reload
		if child.has_meta("editor_grass"):
			child.queue_free()
	_editor_grass = Node2D.new()
	_editor_grass.set_meta("editor_grass", true)
	_editor_grass.z_as_relative = false
	_editor_grass.z_index = -101
	_editor_grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_editor_grass.draw.connect(func(): _editor_grass.draw_texture_rect(GRASS, World.ARENA, true))
	add_child(_editor_grass, false, Node.INTERNAL_MODE_FRONT)


func _draw() -> void:
	var a := World.ARENA
	_drawn = a
	# Dim everything outside: four bands round the edge.
	var o := OUTSIDE_PX
	draw_rect(Rect2(a.position.x - o, a.position.y - o, a.size.x + 2 * o, o), OUTSIDE_COLOR)
	draw_rect(Rect2(a.position.x - o, a.end.y, a.size.x + 2 * o, o), OUTSIDE_COLOR)
	draw_rect(Rect2(a.position.x - o, a.position.y, o, a.size.y), OUTSIDE_COLOR)
	draw_rect(Rect2(a.end.x, a.position.y, o, a.size.y), OUTSIDE_COLOR)
	var corners := PackedVector2Array([a.position, Vector2(a.end.x, a.position.y), a.end,
			Vector2(a.position.x, a.end.y), a.position])
	draw_polyline(corners, SHADOW_COLOR, LINE_WIDTH_PX + 3.0, true)
	draw_polyline(corners, LINE_COLOR, LINE_WIDTH_PX, true)
	# Posts along each side, one at every corner.
	var step := POST_EVERY_M * World.PX_PER_M
	for i in 4:
		var from := corners[i]
		var to := corners[i + 1]
		var count := maxi(1, roundi(from.distance_to(to) / step))
		for k in count:
			var at := from.lerp(to, float(k) / count)
			draw_circle(at, POST_RADIUS_PX + 1.5, SHADOW_COLOR)
			draw_circle(at, POST_RADIUS_PX, POST_COLOR)
	if Engine.is_editor_hint():
		# (a width of -1: always one screen pixel, however far out the editor's zoomed)
		draw_polyline(corners, EDITOR_EDGE_COLOR, -1.0)
