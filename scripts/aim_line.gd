extends Node2D
## The player's aiming line (added by scripts/player.gd), shown while the
## aim button (right mouse) is held. It shows how accurate the weapon in
## hand is, from its own settings (rifle.gd `aim_*`, spread_at()), so each
## weapon gets its own line.
##
## From the muzzle along the barrel:
##   - a solid line as long as the weapon's accurate range, ending in a tick:
##     click anywhere within it and the shot goes exactly there
##   - past it, out to the mouse, a wedge as wide as a shot at each distance
##     could stray, shading from white to red as it opens up, with an arc
##     across it at the mouse marking how far either side the shot may land
## Drawn in the world (top_level), over the squares.

const World = preload("res://scripts/world.gd")

const SOLID_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const WILD_COLOR := Color(1.0, 0.3, 0.2, 0.9)     ## the wedge at its widest spread
const WEDGE_FILL_ALPHA := 0.18
const TICK_M := 0.15          ## half-length of the tick at the end of the accurate range
const WEDGE_STEPS := 24

## The weapon whose accuracy to show (rifle.gd) and the world point being
## aimed at. Set by the player.
var weapon: Node2D
var target := Vector2.ZERO


func _ready() -> void:
	top_level = true
	z_index = 40


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if weapon == null:
		return
	var px := World.PX_PER_M
	var muzzle: Vector2 = weapon.muzzle_position()
	var dir := Vector2.from_angle(weapon.aim)
	var side := dir.orthogonal()
	var accurate: float = weapon.aim_accurate_m
	var reach := muzzle.distance_to(target) / px
	var edge := muzzle + dir * accurate * px

	# Past the accurate range, out to the mouse: the spread wedge.
	if reach > accurate:
		var worst: float = weapon.aim_max_spread_deg
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var colors := PackedColorArray()
		for i in WEDGE_STEPS + 1:
			var d := lerpf(accurate, reach, float(i) / WEDGE_STEPS)
			var spread: float = weapon.spread_at(d)
			var half := tan(deg_to_rad(spread)) * d * px
			var at := muzzle + dir * d * px
			left.append(at + side * half)
			right.append(at - side * half)
			colors.append(_wild(spread / worst if worst > 0.0 else 0.0))
		var outline := left.duplicate()
		var fill_colors := PackedColorArray()
		for c in colors:
			fill_colors.append(Color(c, WEDGE_FILL_ALPHA))
		for i in range(WEDGE_STEPS, -1, -1):
			outline.append(right[i])
			fill_colors.append(Color(colors[i], WEDGE_FILL_ALPHA))
		draw_polygon(outline, fill_colors)
		for i in WEDGE_STEPS:
			draw_line(left[i], left[i + 1], colors[i + 1], 1.5, true)
			draw_line(right[i], right[i + 1], colors[i + 1], 1.5, true)
		var far_spread: float = weapon.spread_at(reach)
		var far_color := _wild(far_spread / worst if worst > 0.0 else 0.0)
		draw_dashed_line(edge, muzzle + dir * reach * px, Color(far_color, 0.5), 1.5, 6.0, true, true)
		if far_spread > 0.0:
			draw_arc(muzzle, reach * px, weapon.aim - deg_to_rad(far_spread),
					weapon.aim + deg_to_rad(far_spread), 16, far_color, 2.5, true)

	# The accurate range: solid, with a tick across its end.
	draw_line(muzzle, edge, SOLID_COLOR, 2.0, true)
	draw_line(edge + side * TICK_M * px, edge - side * TICK_M * px, SOLID_COLOR, 2.0, true)


## The colour for a shot that may stray `t` (0..1) of the weapon's worst.
func _wild(t: float) -> Color:
	return SOLID_COLOR.lerp(WILD_COLOR, clampf(t, 0.0, 1.0))
