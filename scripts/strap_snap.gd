extends Node2D
## A crate's straps snapping (crate.gd _break_straps()): each black strap
## (as crates.py build_straps() lays them: two along y at a third in from
## the sides, one along x through the middle) parts at a point near its
## middle, and the two ends whip back toward the load's edges, curling and
## flicking out past them as they fade, over SNAP_S. A child of the crate,
## so it turns with it; it removes itself when done.

const World = preload("res://scripts/world.gd")

const SNAP_S := 0.4            ## the whole snap, start to gone
const WIDTH_M := 0.035         ## crates.py STRAP_W
const WHIP_M := 0.22           ## the ends fly out this far past the load's edge
const CURL_M := 0.06           ## and kink sideways this much as they go
const COLOR := Color(0.05, 0.05, 0.05)

var _halves: Array = []        ## [{cut, end, side}] in metres, the crate's frame
var _t := 0.0


## `load_m`: the load's footprint (crate.gd), the straps run over it.
func setup(load_m: Vector2) -> void:
	var straps := [
		[Vector2(-load_m.x * 0.3, -load_m.y / 2.0), Vector2(-load_m.x * 0.3, load_m.y / 2.0)],
		[Vector2(load_m.x * 0.3, -load_m.y / 2.0), Vector2(load_m.x * 0.3, load_m.y / 2.0)],
		[Vector2(-load_m.x / 2.0, 0.0), Vector2(load_m.x / 2.0, 0.0)],
	]
	for strap in straps:
		var cut: Vector2 = strap[0].lerp(strap[1], randf_range(0.35, 0.65))
		for end in strap:
			_halves.append({cut = cut, end = end, side = -1.0 if randf() < 0.5 else 1.0})


func _ready() -> void:
	z_index = 1   # over the load


func _process(delta: float) -> void:
	_t += delta
	if _t >= SNAP_S:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var px := World.PX_PER_M
	var k := clampf(_t / SNAP_S, 0.0, 1.0)
	var recoil := 1.0 - pow(1.0 - k, 3.0)          # fast at first, like a cut strap
	var alpha := 1.0 - k * k
	for half in _halves:
		var cut: Vector2 = half.cut
		var end: Vector2 = half.end
		var along := (end - cut).normalized()
		var across: Vector2 = along.orthogonal() * half.side
		var outer := end + along * WHIP_M * recoil
		var inner := cut.lerp(outer, recoil * 0.85)
		var mid := inner.lerp(outer, 0.5) + across * CURL_M * sin(k * PI) * 1.5
		var tip := inner + across * CURL_M * recoil   # the cut end curls over
		var line := PackedVector2Array([tip * px, inner * px, mid * px, outer * px])
		draw_polyline(line, Color(COLOR, alpha), maxf(WIDTH_M * px, 2.0), true)
