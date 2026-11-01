extends RefCounted
## How a part being carried to something under construction looks, from
## above, held in front of whoever's carrying it (player.gd, squadmate.gd):
##   desk          the desk folded into a grey bundle, legs strapped on
##   electronics   a black rugged case
##   legs          the dish's legs in an olive case
##   dish          the dish in a tan case
##   wiring        the cable reel
##   sandbags      a filled burlap sandbag (a wall's worth, sandbags.gd)
## Load with:
##     const CarryArt = preload("res://scripts/carry_art.gd")

const World = preload("res://scripts/world.gd")

const AHEAD_M := 0.36            ## held this far in front of the carrier's middle
const OUTLINE := Color(0, 0, 0, 0.6)


## Draws `part` on `canvas`, held in front of something at its origin facing `facing`.
static func draw(canvas: CanvasItem, part: String, facing: float) -> void:
	var px := World.PX_PER_M
	canvas.draw_set_transform(Vector2.from_angle(facing) * AHEAD_M * px, facing + PI / 2)
	match part:
		"desk":
			var r := Rect2(Vector2(-0.36, -0.12) * px, Vector2(0.72, 0.24) * px)
			canvas.draw_rect(r, Color(0.3, 0.32, 0.27))
			for k in 4:
				canvas.draw_line(Vector2(-0.33, -0.07 + k * 0.045) * px, Vector2(0.33, -0.07 + k * 0.045) * px,
						Color(0.05, 0.05, 0.05), 2.0)
			canvas.draw_rect(r, OUTLINE, false, 1.0)
		"electronics", "legs", "dish":
			var colour: Color = {"electronics": Color(0.08, 0.08, 0.08), "legs": Color(0.33, 0.35, 0.22),
					"dish": Color(0.80, 0.72, 0.58)}[part]
			var r := Rect2(Vector2(-0.175, -0.11) * px, Vector2(0.35, 0.22) * px)
			canvas.draw_rect(r, colour)
			canvas.draw_line(Vector2(-0.06, 0) * px, Vector2(0.06, 0) * px, Color(0.2, 0.2, 0.2), 3.0)
			canvas.draw_rect(r, OUTLINE, false, 1.0)
		"wiring":
			canvas.draw_circle(Vector2.ZERO, 0.11 * px, Color(0.33, 0.35, 0.22))
			canvas.draw_circle(Vector2.ZERO, 0.09 * px, Color(0.04, 0.04, 0.04))
			canvas.draw_circle(Vector2.ZERO, 0.025 * px, Color(0.33, 0.35, 0.22))
		"sandbags":
			var r := Rect2(Vector2(-0.185, -0.12) * px, Vector2(0.37, 0.24) * px)
			canvas.draw_rect(r, Color(0.74, 0.65, 0.48))
			canvas.draw_line(Vector2(-0.14, -0.1) * px, Vector2(-0.14, 0.1) * px, Color(0.5, 0.42, 0.28), 2.0)
			canvas.draw_line(Vector2(0.14, -0.1) * px, Vector2(0.14, 0.1) * px, Color(0.5, 0.42, 0.28), 2.0)
			canvas.draw_rect(r, OUTLINE, false, 1.0)
	canvas.draw_set_transform(Vector2.ZERO)
