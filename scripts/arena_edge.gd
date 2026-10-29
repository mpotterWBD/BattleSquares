extends Node2D
## The barrier round the play area (World.ARENA): a light boundary line
## with small posts every POST_EVERY_M, and the ground beyond it dimmed so
## it's clear where the field ends. Squares can't cross it (soldier.gd and
## squadmate.gd keep inside the arena); this just shows where it is.

const World = preload("res://scripts/world.gd")

const LINE_COLOR := Color(0.92, 0.9, 0.82, 0.85)
const LINE_WIDTH_PX := 3.0
const SHADOW_COLOR := Color(0, 0, 0, 0.35)   ## a thin dark line under it, so it reads on light grass
const POST_EVERY_M := 4.0
const POST_RADIUS_PX := 5.0
const POST_COLOR := Color(0.22, 0.2, 0.17)
const OUTSIDE_COLOR := Color(0, 0, 0, 0.3)
const OUTSIDE_PX := 4000.0   ## how far the dimming reaches beyond the edge


func _ready() -> void:
	z_index = -50   # over the grass and ground props, under the squares


func _draw() -> void:
	var a := World.ARENA
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
