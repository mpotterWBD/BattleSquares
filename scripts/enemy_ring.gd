extends Node2D
## An enemy's detection circle (added by scripts/enemy.gd), painted on the
## ground under the squares while its `show_detection` is on: a faint blue
## ring while it's calm, dashed and brighter once it's alerted. Hidden when
## it dies.

const World = preload("res://scripts/world.gd")
const CALM_COLOR := Color(0.35, 0.6, 1.0)
const ALERT_COLOR := Color(1.0, 0.45, 0.35)

var enemy: Node2D   ## enemy.gd


func _ready() -> void:
	z_index = -1   # on the ground, like the sight triangle


func _process(_delta: float) -> void:
	visible = enemy.show_detection and not enemy.dead
	if visible:
		queue_redraw()


func _draw() -> void:
	# Centred on the enemy, so it moves with it.
	var radius: float = enemy.detection_radius_m * World.PX_PER_M
	if enemy.alerted:
		var points := 72
		for i in points:
			if i % 2 == 0:
				var a := TAU * i / points
				var b := TAU * (i + 1) / points
				draw_arc(Vector2.ZERO, radius, a, b, 4, Color(ALERT_COLOR, 0.75), 3.0, true)
	else:
		draw_circle(Vector2.ZERO, radius, Color(CALM_COLOR, 0.04))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(CALM_COLOR, 0.3), 1.5, true)
