extends RefCounted
## The driver's brain for a truck (supply_truck.gd), for when a squadmate's at
## the wheel and the truck's been told where to go (Mike, 2026-11-04: "as if it
## was an individual unit"; there'll be a lot of automated driving, so the
## decisions are always to stay on roads, and to back into or drive forward
## into spots reasonably).
##
## drive_to(point) plans, tick(delta) follows. Everything is worked out in
## metres, as the truck's REAR AXLE's path (the point a bicycle model turns
## about), and is a list of runs: a run is one gear's worth of path (forward,
## or reverse), with a speed limit at each point.
##
## The plan:
##  1. Roads (group "roads", road.gd) are a graph: their curves sampled every
##     NET_STEP_M, ends and crossings within JOIN_M joined. The route's the
##     shortest way along them, on the right-hand lane (LANE_M off the centre
##     line, as one drives on the right).
##  2. The truck joins the lane ahead of itself by the shortest smooth curve
##     (a Hermite spline) it can actually drive: its tightest bend no sharper
##     than the truck's turning circle (R_USE_M). If it faces the wrong way, or
##     is in a spot it can't get out of directly, `_reposition()` tries
##     short reversing and forward moves (a K-turn) until a join works.
##  3. At the far end: a click on the asphalt means stopping along the lane,
##     centre on the click. A click off the road is a spot beside it: close
##     (< BACK_IN_OVER_M off the road) it drives forward in (the lane, then a
##     curve into the spot, nose to the spot); farther, it backs in (past the
##     spot, stops, then reverses in along a curve, nose out toward the road,
##     the way a truck backs into a bay). If the chosen way can't be driven,
##     the other is tried.
##  4. Following: pure pursuit (steer to a point a lookahead ahead on the
##     path; the same formula steers a reverse), speed limited by the bends
##     ahead (lateral acceleration A_LAT_MPS2), by braking distance to the end
##     of each run (DECEL_MPS2) and by ROAD_MPS / OFFROAD_MPS / REVERSE_MPS;
##     a pause at each change of gear. Stuck (blocked BLOCK_S): it backs off
##     a little and plans again, up to MAX_ATTEMPTS, then gives up.

const World = preload("res://scripts/world.gd")

const WHEELBASE_M := 2.6
const REAR_X_M := -1.26             ## the rear axle, from the truck's middle (supply_truck.gd REAR_AXLE_X_M)
const LANE_M := 1.3                 ## right-hand lane: this far right of a road's centre line
const NET_STEP_M := 1.5
const JOIN_M := 3.0
const STEP_M := 0.5                 ## path points are this far apart
const ROADSIDE_M := 2.0             ## a click this near a road's centre line is on the road
const BACK_IN_OVER_M := 5.0
const TAIL_M := 18.0                ## the lane carried straight on past the route's end (room to pull past a spot)
const STEER_USE := 0.85             ## of the truck's lock the plans use (the rest is for the follower to correct with)
const A_LAT_MPS2 := 2.0
const DECEL_MPS2 := 2.0
const ROAD_MPS := 5.0
const OFFROAD_MPS := 3.0
const REVERSE_MPS := 1.5
const MIN_MPS := 0.5
const END_EPS_M := 0.3
const GEAR_PAUSE_S := 0.6
const BLOCK_S := 2.0
const MAX_ATTEMPTS := 3
const JOIN_STEP := 4                ## join points tried every this many path points
const JOIN_REACH_M := 40.0
const ROAD_KEEP_M := 3.4            ## a path joining a road from on it stays this near a centre line (a K-turn rather than a loop across the verge)

var truck: Node2D
var status := "idle"                ## idle, driving, arrived, failed
var runs: Array = []
var run_i := 0
var idx := 0
var goal := Vector2.ZERO            ## world px
var _pause := 0.0
var _blocked := 0.0
var _attempts := 0
var _astar: AStar2D
var _roads: Array = []              ## the road centre lines, metres: PackedVector2Array each
var short := false                  ## the path was cut short at something solid in the way: it stops before it
var _cut := false
var _nudge := false                 ## the run in hand's a back-off after being blocked: plan again after it
var _r_use := 4.6
var _space: PhysicsDirectSpaceState2D
var _query: PhysicsShapeQueryParameters2D
var _keep_road := false             ## the truck starts on a road: joining it must keep to it


func _init(truck_: Node2D) -> void:
	truck = truck_
	_r_use = WHEELBASE_M / tan(deg_to_rad(truck.max_steer_deg * STEER_USE)) * 1.05


func active() -> bool:
	return status == "driving"


func stop() -> void:
	runs.clear()
	status = "idle"


## The whole planned path in world px (to draw it in command mode).
func path_px() -> PackedVector2Array:
	var out := PackedVector2Array()
	var px := World.PX_PER_M
	for run in runs:
		for p: Vector2 in run.pts:
			out.append(p * px)
	return out


# ---------------------------------------------------------------- planning --

## Plans a drive to world point `dest_px` (where the truck's middle should end
## up) from where the truck is now. False if there's no way.
func drive_to(dest_px: Vector2, fresh := true) -> bool:
	goal = dest_px
	if fresh:
		_attempts = 0
	var px := World.PX_PER_M
	var h0 := Vector2.from_angle(truck.global_rotation)
	var r0 := truck.global_position / px + h0 * REAR_X_M
	_cut = false
	var plan := _plan(r0, h0, dest_px / px)
	_blocked = 0.0
	_pause = 0.0
	_nudge = false
	short = _cut
	if plan.is_empty():
		runs.clear()
		status = "failed"
		return false
	runs = plan
	run_i = 0
	idx = 0
	status = "driving"
	return true


func _plan(r0: Vector2, h0: Vector2, dest: Vector2) -> Array:
	_build_net()
	_begin_checks()
	var near := _nearest_road(dest)
	var start_near := _nearest_road(r0)
	if _roads.is_empty() or near.is_empty() or start_near.is_empty():
		return _plan_offroad(r0, h0, dest)
	# The route along the lane from the road nearest the truck to the one nearest the goal.
	var a_id := _astar.get_closest_point(r0)
	var b_id := _astar.get_closest_point(near.point)
	var ids := _astar.get_id_path(a_id, b_id)
	if ids.size() < 2:   # (the same node: the road's own way on, whichever way the truck faces)
		var other := -1
		var best_dot := -INF
		for n in _astar.get_point_connections(b_id):
			var dot := h0.dot((_astar.get_point_position(n) - _astar.get_point_position(b_id)).normalized())
			if dot > best_dot:
				best_dot = dot
				other = n
		if other < 0:
			return _plan_offroad(r0, h0, dest)
		ids = PackedInt64Array([b_id, other])
	_keep_road = start_near.dist <= ROADSIDE_M + LANE_M + 0.5
	var lane := _lane(ids)
	var free_until := _lane_free_until(lane)
	var access := _closest_index(lane.pts, near.point)
	# Getting onto the lane from here: the shortest drivable join, or a K-turn first.
	var join := _best_join(r0, h0, lane, 0, JOIN_REACH_M)
	var lead: Array = []
	var sp := r0   # (where the join starts from: the truck, or where the K-turn leaves it)
	var sh := h0
	if join.is_empty():
		var re := _reposition(r0, h0, lane)
		if re.is_empty():
			return []
		lead = re.runs
		join = re.join
		sp = re.p
		sh = re.h
	var j: int = join.j
	var join_len := _length(join.pts)
	# Where it goes from the lane: stopping on the road, or the way off it.
	var on_road: bool = near.dist <= ROADSIDE_M
	var finish: Array = []   # runs after the lane's part
	var lane_end: int = lane.pts.size() - 1
	var direct := false      # (a spot it can go straight into from where it is: no lane at all)
	if on_road:
		# Stop in the lane, the truck's middle nearest the click.
		var best := j
		var best_d := INF
		for i in range(j, lane.pts.size()):
			var mid: Vector2 = lane.pts[i] - lane.dirs[i] * REAR_X_M
			var d := mid.distance_to(dest)
			if d < best_d:
				best_d = d
				best = i
		lane_end = best
	else:
		var n: Vector2 = (dest - near.point).normalized()
		var order := ["forward", "back"] if near.dist <= BACK_IN_OVER_M else ["back", "forward"]
		var parked := false
		for style: String in order:
			var park := _park(lane, access, n, dest, style, near, free_until, j, join_len, sp, sh)
			if not park.is_empty():
				direct = park.direct
				lane_end = park.lane_end
				finish = park.runs
				parked = true
				break
		if not parked:
			lane_end = clampi(access, j, lane.pts.size() - 1)   # (no way into it that the truck can drive: as near as the road gets)
			finish = _plan_offroad_from(lane.pts[lane_end], lane.dirs[lane_end], dest)
	var out: Array = lead.duplicate()
	var first := _new_run(false)
	if not lead.is_empty() and not lead.back().reverse:
		first = lead.pop_back()   # (carry on forward: no stop)
		out = lead
	if not direct:
		_extend(first, join.pts, ROAD_MPS if start_near.dist <= ROADSIDE_M + LANE_M else OFFROAD_MPS)
		for i in range(j + 1, lane_end + 1):
			_push(first, lane.pts[i], ROAD_MPS)
	out.append(first)
	if not finish.is_empty():
		# The finish starts where the lane's followed to (or the truck's pose): forward-in just carries on the same run.
		var f0: Dictionary = finish[0]
		if not f0.reverse:
			for i in range(0 if direct else 1, f0.pts.size()):
				_push(first, f0.pts[i], f0.spd[i])
			finish = finish.slice(1)
		out.append_array(finish)
	return _validated(_prepared(out))


## No roads (or none usable): the truck's own way to `dest`, forward if it can, else after a K-turn.
func _plan_offroad(r0: Vector2, h0: Vector2, dest: Vector2) -> Array:
	var h := (dest - r0).normalized() if dest.distance_to(r0) > 0.1 else h0
	var target := dest + h * REAR_X_M   # (its rear axle: REAR_X_M behind the middle)
	var pts := _fit(r0, h0, target, h)
	var out: Array = []
	if pts.is_empty():
		var lane := {pts = PackedVector2Array([target]), dirs = PackedVector2Array([h])}
		var re := _reposition(r0, h0, lane)
		if re.is_empty():
			return []
		out = re.runs
		var run := _new_run(false)
		if not out.is_empty() and not out.back().reverse:
			run = out.pop_back()
		_extend(run, re.join.pts, OFFROAD_MPS)
		out.append(run)
	else:
		var run := _new_run(false)
		_extend(run, pts, OFFROAD_MPS)
		out.append(run)
	return _validated(_prepared(out))


func _plan_offroad_from(p: Vector2, d: Vector2, dest: Vector2) -> Array:
	var h := (dest - p).normalized()
	var target := dest + h * REAR_X_M
	var pts := _fit(p, d, target, h)
	if pts.is_empty():
		pts = _hermite(p, d, target, h, 1.0, 24)   # (as near as it can: bends sharper than the truck's, but never stops)
	var run := _new_run(false)
	_extend(run, pts, OFFROAD_MPS)
	return [run]


## Pulls off the lane into a spot: "forward" (the lane, then a curve in, nose to
## the spot) or "back" (past the spot, stop, reverse in, nose out toward the road).
## Several entry angles are tried, straight in first, shallower after (a tight
## spot beside the road can't be turned into square-on: no truck can, so it
## angles in, as a driver does), and several places to leave the lane, and the
## cheapest drivable one's taken: the path's length, a little for each degree off
## square, and it must stay in the corridor from the far side of the road to just
## past the spot (never a loop across the field). {} if none can be driven, else
## {lane_end: where the lane's followed to, runs}.
func _park(lane: Dictionary, access: int, n: Vector2, dest: Vector2, style: String, near: Dictionary, free_until: int,
		j: int, join_len: float, sp: Vector2, sh: Vector2) -> Dictionary:
	var last: int = lane.pts.size() - 1
	var road_way: Vector2 = lane.dirs[access]
	var best := {}
	var best_cost := INF
	for phi in [0.0, 20.0, 40.0, 60.0, 75.0]:
		var s := sin(deg_to_rad(phi))
		var c := cos(deg_to_rad(phi))
		if style == "forward":
			var into := (n * c + road_way * s).normalized()   # nose along this, toward the way the lane goes
			var spot_rear := dest + into * REAR_X_M
			# Straight in from where the truck is (it's on the road, aligned, and the spot's ahead).
			var pts := _fit(sp, sh, spot_rear, into)
			if not pts.is_empty() and _in_corridor(pts, near, n) and _run_free(pts, false):
				var cost: float = _length(pts) + 0.3 * phi
				if cost < best_cost:
					best_cost = cost
					var run := _new_run(false)
					_extend(run, pts, OFFROAD_MPS)
					best = {lane_end = j, runs = [run], direct = true}
			# Or along the lane first, leaving it where that's cheapest.
			for e in range(access, maxi(j, access - int(18.0 / STEP_M)) - 1, -JOIN_STEP):
				pts = _fit(lane.pts[e], lane.dirs[e], spot_rear, into)
				if pts.is_empty() or not _in_corridor(pts, near, n) or not _run_free(pts, false):
					continue
				var cost: float = join_len + float(maxi(e - j, 0)) * STEP_M + _length(pts) + 0.3 * phi
				if cost < best_cost:
					best_cost = cost
					var run := _new_run(false)
					_extend(run, pts, OFFROAD_MPS)
					best = {lane_end = e, runs = [run], direct = false}
		else:
			var into := (n * c - road_way * s).normalized()   # the way the rear axle travels going in (toward where it came from)
			var spot_rear := dest - into * REAR_X_M
			for f in range(maxi(mini(access + int(4.0 / STEP_M), last), j), mini(access + int(TAIL_M / STEP_M), last) + 1, JOIN_STEP):
				if f > free_until:
					break   # (the lane's blocked past here)
				var pts := _fit(lane.pts[f], -lane.dirs[f], spot_rear, into)
				if pts.is_empty() or not _in_corridor(pts, near, n) or not _run_free(pts, true):
					continue
				var cost: float = join_len + float(f - j) * STEP_M + _length(pts) + 0.3 * phi
				if cost < best_cost:
					best_cost = cost
					var run := _new_run(true)
					_extend(run, pts, REVERSE_MPS)
					best = {lane_end = f, runs = [run], direct = false}
	return best


## Whether `pts` stays between the far side of the road (ROAD_KEEP_M past its centre line)
## and 2.5 m past the spot, measured along `n` (the way from the road to the spot).
func _in_corridor(pts: PackedVector2Array, near: Dictionary, n: Vector2) -> bool:
	var depth: float = near.dist
	for i in range(0, pts.size(), 2):
		var lat: float = (pts[i] - near.point).dot(n)
		if lat < -ROAD_KEEP_M or lat > depth + 2.5:
			return false
	return true


## The first point on `lane` (from index `from`) that `pose` can smoothly reach: {j, pts} or {}.
func _best_join(p: Vector2, h: Vector2, lane: Dictionary, from: int, reach_m: float) -> Dictionary:
	var last := mini(lane.pts.size() - 1, from + int(reach_m / STEP_M))
	var j := from
	while j <= last:
		var pts := _fit(p, h, lane.pts[j], lane.dirs[j], _keep_road)
		if not pts.is_empty():
			return {j = j, pts = pts}
		j += JOIN_STEP
	return {}


## Short moves (forward or reversing, hard over one way or the other, then
## again the other gear) until the truck's somewhere it can join the lane from:
## a K-turn. The cheapest found. {runs, join} or {}.
func _reposition(r0: Vector2, h0: Vector2, lane: Dictionary) -> Dictionary:
	var best := {}
	var best_cost := INF
	for g1 in [1, -1]:
		for s1 in [-1.0, 1.0]:
			for d1 in [3.0, 5.0, 7.0]:
				var m1 := _sim(r0, h0, g1, s1, d1)
				if m1.is_empty():
					continue
				var join := _best_join(m1.p, m1.h, lane, 0, JOIN_REACH_M)
				if not join.is_empty():
					var cost: float = d1 + _length(join.pts) + (4.0 if g1 < 0 else 0.0)
					if cost < best_cost:
						best_cost = cost
						best = {runs = [_run_of(m1.pts, g1 < 0)], join = join, p = m1.p, h = m1.h}
				for s2 in [-1.0, 1.0]:
					for d2 in [3.0, 5.0, 7.0]:
						var m2 := _sim(m1.p, m1.h, -g1, s2, d2)
						if m2.is_empty():
							continue
						var join2 := _best_join(m2.p, m2.h, lane, 0, JOIN_REACH_M)
						if not join2.is_empty():
							var cost2: float = d1 + d2 + _length(join2.pts) + 8.0
							if cost2 < best_cost:
								best_cost = cost2
								best = {runs = [_run_of(m1.pts, g1 < 0), _run_of(m2.pts, g1 > 0)], join = join2, p = m2.p, h = m2.h}
	return best


## Simulates `dist` metres in gear `g` (1 forward, -1 reverse) with the wheels
## turned `steer` (-1 full left .. 1 full right) of the lock the plans use,
## from the rear axle at `p`, nose along `h`: {pts, p, h}, or {} if it leaves the field.
func _sim(p: Vector2, h: Vector2, g: int, steer: float, dist: float) -> Dictionary:
	var delta := deg_to_rad(truck.max_steer_deg * STEER_USE) * steer
	var pts := PackedVector2Array([p])
	var theta := h.angle()
	var ds := 0.25
	var field := Rect2(World.ARENA.position / World.PX_PER_M, World.ARENA.size / World.PX_PER_M)
	var travelled := 0.0
	while travelled < dist:
		p += Vector2.from_angle(theta) * ds * g
		theta += ds * g * tan(delta) / WHEELBASE_M
		travelled += ds
		if not field.grow(-1.5).has_point(p):
			return {}
		pts.append(p)
	return {pts = pts, p = p, h = Vector2.from_angle(theta)}


# ------------------------------------------------------------------ curves --

## A smooth forward path from `p0` (nose along `d0`) to `p1` (nose along `d1`),
## no bend sharper than the truck's turning circle: sample points, or empty.
## A gentle one (the target's ahead) is a Hermite spline; otherwise the shortest
## Dubins path (an arc, a straight, an arc: it swings out the other way first if
## it must). With `keep_road`, a path that strays more than ROAD_KEEP_M from a
## road's centre line is turned down.
func _fit(p0: Vector2, d0: Vector2, p1: Vector2, d1: Vector2, keep_road := false) -> PackedVector2Array:
	var chord := p0.distance_to(p1)
	if chord < 0.2:
		return PackedVector2Array([p0, p1])
	if (p1 - p0).dot(d0) >= -0.1 * chord:
		for scale in [1.0, 0.7, 1.4, 0.5, 2.0]:
			var pts := _hermite(p0, d0, p1, d1, scale, maxi(int(chord * 1.4 / STEP_M), 8))
			if _max_curvature(pts) * _r_use <= 1.0 and (not keep_road or _near_roads(pts)):
				return pts
	var dub := _dubins(p0, d0, p1, d1)
	if not dub.is_empty() and (not keep_road or _near_roads(dub)):
		return dub
	return PackedVector2Array()


## Whether every point of `pts` is within ROAD_KEEP_M of a road's centre line.
func _near_roads(pts: PackedVector2Array) -> bool:
	for i in range(0, pts.size(), 2):
		var r := _nearest_road(pts[i])
		if r.is_empty() or r.dist > ROAD_KEEP_M:
			return false
	return true


## The shortest path of an arc, a straight and an arc (none sharper than R_USE_M)
## from pose (`p0`, `d0`) to (`p1`, `d1`), sampled: empty if none (the poses are
## too close for these shapes). The standard Dubins construction, worked in a
## y-up frame (the screen's is y-down) with turns left (+1) or right (-1).
func _dubins(p0: Vector2, d0: Vector2, p1: Vector2, d1: Vector2) -> PackedVector2Array:
	var r := _r_use
	var a := Vector2(p0.x, -p0.y)
	var b := Vector2(p1.x, -p1.y)
	var th0 := atan2(-d0.y, d0.x)
	var th1 := atan2(-d1.y, d1.x)
	var dist := a.distance_to(b)
	var d := dist / r
	var theta := atan2(b.y - a.y, b.x - a.x)
	var alpha := fposmod(th0 - theta, TAU)
	var beta := fposmod(th1 - theta, TAU)
	var sa := sin(alpha)
	var ca := cos(alpha)
	var sb := sin(beta)
	var cb := cos(beta)
	var cab := cos(alpha - beta)
	var best_len := INF
	var best: Array = []   # [turn of the 1st arc, of the middle (0 a straight), of the last, t, p, q] (arc lengths in radii)
	var cands: Array = []
	var p_sq := 2.0 + d * d - 2.0 * cab + 2.0 * d * (sa - sb)   # LSL
	if p_sq >= 0.0:
		var tmp := atan2(cb - ca, d + sa - sb)
		cands.append([1, 0, 1, fposmod(tmp - alpha, TAU), sqrt(p_sq), fposmod(beta - tmp, TAU)])
	p_sq = 2.0 + d * d - 2.0 * cab + 2.0 * d * (sb - sa)   # RSR
	if p_sq >= 0.0:
		var tmp := atan2(ca - cb, d - sa + sb)
		cands.append([-1, 0, -1, fposmod(alpha - tmp, TAU), sqrt(p_sq), fposmod(tmp - beta, TAU)])
	p_sq = -2.0 + d * d + 2.0 * cab + 2.0 * d * (sa + sb)   # LSR
	if p_sq >= 0.0:
		var p := sqrt(p_sq)
		var tmp := atan2(-ca - cb, d + sa + sb) - atan2(-2.0, p)
		cands.append([1, 0, -1, fposmod(tmp - alpha, TAU), p, fposmod(tmp - fposmod(beta, TAU), TAU)])
	p_sq = -2.0 + d * d + 2.0 * cab - 2.0 * d * (sa + sb)   # RSL
	if p_sq >= 0.0:
		var p := sqrt(p_sq)
		var tmp := atan2(ca + cb, d - sa - sb) - atan2(2.0, p)
		cands.append([-1, 0, 1, fposmod(alpha - tmp, TAU), p, fposmod(beta - tmp, TAU)])
	var ccc := (6.0 - d * d + 2.0 * cab + 2.0 * d * (sa - sb)) / 8.0   # RLR (poses close together)
	if absf(ccc) <= 1.0:
		var p := fposmod(TAU - acos(ccc), TAU)
		var t := fposmod(alpha - atan2(ca - cb, d - sa + sb) + fposmod(p / 2.0, TAU), TAU)
		cands.append([-1, 1, -1, t, p, fposmod(alpha - beta - t + fposmod(p, TAU), TAU)])
	ccc = (6.0 - d * d + 2.0 * cab + 2.0 * d * (sb - sa)) / 8.0   # LRL
	if absf(ccc) <= 1.0:
		var p := fposmod(TAU - acos(ccc), TAU)
		var t := fposmod(-alpha - atan2(ca - cb, d + sa - sb) + p / 2.0, TAU)
		cands.append([1, -1, 1, t, p, fposmod(fposmod(beta, TAU) - alpha - t + fposmod(p, TAU), TAU)])
	for c in cands:
		var total: float = c[3] + c[4] + c[5]
		if total < best_len:
			best_len = total
			best = c
	if best.is_empty() or best_len * r > 70.0:
		return PackedVector2Array()
	var pts := PackedVector2Array([p0])
	var pos := a
	var th := th0
	var segs := [[best[0], best[3]], [best[1], best[4]], [best[2], best[5]]]
	for seg in segs:
		var left: float = seg[1] * r
		while left > 0.0001:
			var ds := minf(0.25, left)
			if seg[0] == 0:
				pos += Vector2.from_angle(th) * ds
			else:
				var dth: float = seg[0] * ds / r
				pos += Vector2.from_angle(th + dth / 2.0) * ds
				th += dth
			left -= ds
			pts.append(Vector2(pos.x, -pos.y))
	return _resampled(pts)


func _hermite(p0: Vector2, d0: Vector2, p1: Vector2, d1: Vector2, scale: float, n: int) -> PackedVector2Array:
	var chord := p0.distance_to(p1)
	var m0 := d0 * chord * scale
	var m1 := d1 * chord * scale
	var pts := PackedVector2Array()
	for i in n + 1:
		var s := float(i) / n
		var s2 := s * s
		var s3 := s2 * s
		pts.append((2.0 * s3 - 3.0 * s2 + 1.0) * p0 + (s3 - 2.0 * s2 + s) * m0
				+ (-2.0 * s3 + 3.0 * s2) * p1 + (s3 - s2) * m1)
	return _resampled(pts)


## The sharpest bend (1/m) along `pts`.
func _max_curvature(pts: PackedVector2Array) -> float:
	var worst := 0.0
	for i in range(1, pts.size() - 1):
		var a := pts[i] - pts[i - 1]
		var b := pts[i + 1] - pts[i]
		var len := (a.length() + b.length()) / 2.0
		if len > 0.01:
			worst = maxf(worst, absf(a.angle_to(b)) / len)
	return worst


## `pts` as points STEP_M apart along it.
func _resampled(pts: PackedVector2Array, step := STEP_M) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		if seg < 0.0001:
			continue
		var at := step - carry
		while at <= seg:
			out.append(a.lerp(b, at / seg))
			at += step
		carry = seg - (at - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.05:
		out.append(pts[pts.size() - 1])
	return out


func _length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	return total


# ------------------------------------------------------------------- roads --

func _build_net() -> void:
	_astar = AStar2D.new()
	_roads.clear()
	var px := World.PX_PER_M
	var road_of := {}
	var next_id := 0
	for road in truck.get_tree().get_nodes_in_group("roads"):
		if road.curve == null or road.curve.point_count < 2:
			continue
		var baked: PackedVector2Array = road.curve.get_baked_points()
		var world := PackedVector2Array()
		for p in baked:
			world.append(road.to_global(p) / px)
		var pts := _resampled(world, NET_STEP_M)
		_roads.append(pts)
		var prev := -1
		for p in pts:
			_astar.add_point(next_id, p)
			road_of[next_id] = _roads.size() - 1
			if prev >= 0:
				_astar.connect_points(prev, next_id)
			prev = next_id
			next_id += 1
	# Roads that meet or cross: nodes of different roads close together are joined.
	var ids := _astar.get_point_ids()
	for i in ids.size():
		for k in range(i + 1, ids.size()):
			if road_of[ids[i]] != road_of[ids[k]] \
					and _astar.get_point_position(ids[i]).distance_to(_astar.get_point_position(ids[k])) <= JOIN_M:
				_astar.connect_points(ids[i], ids[k])


## The point on a road nearest `p` (metres): {point, dist}, or {} with no roads.
func _nearest_road(p: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for pts: PackedVector2Array in _roads:
		for i in range(1, pts.size()):
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])
			var d := p.distance_to(q)
			if d < best_d:
				best_d = d
				best = {point = q, dist = d}
	return best


## The right-hand lane along the node path `ids`, resampled, with a direction at each point and a straight tail on past the end.
func _lane(ids: PackedInt64Array) -> Dictionary:
	var centre := PackedVector2Array()
	for id in ids:
		centre.append(_astar.get_point_position(id))
	var pts := PackedVector2Array()
	for i in centre.size():
		var a := centre[maxi(i - 1, 0)]
		var b := centre[mini(i + 1, centre.size() - 1)]
		var d := (b - a).normalized()
		pts.append(centre[i] + Vector2(-d.y, d.x) * LANE_M)
	pts = _resampled(pts)
	var tail_d := (pts[pts.size() - 1] - pts[maxi(pts.size() - 4, 0)]).normalized()
	for k in range(1, int(TAIL_M / STEP_M) + 1):
		pts.append(pts[pts.size() - 1] + tail_d * STEP_M)
	var dirs := PackedVector2Array()
	for i in pts.size():
		dirs.append((pts[mini(i + 2, pts.size() - 1)] - pts[maxi(i - 2, 0)]).normalized())
	return {pts = pts, dirs = dirs}


func _closest_index(pts: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in pts.size():
		var d := pts[i].distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


# -------------------------------------------------------------------- runs --

func _new_run(reverse: bool) -> Dictionary:
	return {pts = PackedVector2Array(), spd = PackedFloat32Array(), reverse = reverse}


func _run_of(pts: PackedVector2Array, reverse: bool) -> Dictionary:
	var run := _new_run(reverse)
	_extend(run, pts, REVERSE_MPS if reverse else OFFROAD_MPS)
	return run


func _push(run: Dictionary, p: Vector2, speed: float) -> void:
	var pts: PackedVector2Array = run.pts
	if pts.size() > 0 and pts[pts.size() - 1].distance_to(p) < 0.05:
		return
	run.pts.append(p)
	run.spd.append(speed)


func _extend(run: Dictionary, pts: PackedVector2Array, speed: float) -> void:
	for p in pts:
		_push(run, p, speed)


## Gets ready to ask whether the truck's body would be clear at a pose (_body_free()).
func _begin_checks() -> void:
	_space = truck.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(truck.LENGTH_M, truck.WIDTH_M + 0.1) * World.PX_PER_M
	_query = PhysicsShapeQueryParameters2D.new()
	_query.shape = shape
	_query.collision_mask = truck.collision_mask
	_query.exclude = [truck.get_rid()]


## Whether nothing solid is where the truck's body would be with its rear axle at `rear` (metres), nose along `nose`.
func _body_free(rear: Vector2, nose: Vector2) -> bool:
	_query.transform = Transform2D(nose.angle(), (rear + nose * -REAR_X_M) * World.PX_PER_M)
	return _space.intersect_shape(_query, 1).is_empty()


## Whether the truck could drive all of `pts` (a run, in gear `reverse`) without meeting anything solid.
func _run_free(pts: PackedVector2Array, reverse: bool) -> bool:
	for i in range(3, pts.size(), 2):
		var travel := (pts[i] - pts[i - 1]).normalized()
		if not _body_free(pts[i], -travel if reverse else travel):
			return false
	return true


## The last lane index (stepping by 2) the truck could be at, nose along the lane, before meeting something solid (a few points short of it).
func _lane_free_until(lane: Dictionary) -> int:
	for i in range(2, lane.pts.size(), 2):
		if not _body_free(lane.pts[i], lane.dirs[i]):
			return maxi(i - 3, 0)
	return lane.pts.size() - 1


## Cuts the plan short where the truck (its whole body, every point of the way) would meet something solid
## (the layers it collides with: squares, crates, sandbags, tower legs): a couple of metres before it, so it
## stops short and `short` is set; the runs after are dropped. Spots it starts on top of are ignored.
func _validated(plan: Array) -> Array:
	for ri in plan.size():
		var run: Dictionary = plan[ri]
		var pts: PackedVector2Array = run.pts
		for i in range(3, pts.size(), 2):
			var travel := (pts[i] - pts[i - 1]).normalized()
			if _body_free(pts[i], -travel if run.reverse else travel):
				continue
			_cut = true
			var keep := maxi(i - int(2.0 / STEP_M), 0)
			if keep < 3 and ri == 0:
				return []   # (blocked from the start)
			var cut := _new_run(run.reverse)
			for k in keep + 1:
				_push(cut, pts[k], run.spd[k])
			var out: Array = plan.slice(0, ri)
			if cut.pts.size() >= 2:
				out.append(_prepared([cut])[0])
			return out
	return plan


## Each run resampled evenly, with its cumulative length and the bend at each point.
func _prepared(out: Array) -> Array:
	var good: Array = []
	for run: Dictionary in out:
		if run.pts.size() < 2:
			continue
		var pts := _resampled(run.pts)
		# (speeds follow their points: the nearest original's)
		var spd := PackedFloat32Array()
		for p in pts:
			spd.append(run.spd[_closest_index(run.pts, p)])
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var kappa := PackedFloat32Array()
		kappa.resize(pts.size())
		for i in pts.size():
			var worst := 0.0
			for k in range(maxi(i - 2, 1), mini(i + 3, pts.size() - 1)):
				var a := pts[k] - pts[k - 1]
				var b := pts[k + 1] - pts[k]
				worst = maxf(worst, absf(a.angle_to(b)) / maxf((a.length() + b.length()) / 2.0, 0.01))
			kappa[i] = worst
		good.append({pts = pts, spd = spd, cum = cum, kappa = kappa, reverse = run.reverse})
	return good


# --------------------------------------------------------------- following --

## One tick: {speed: where its speed should be going (m/s, negative reversing),
## steer: the front wheels' angle (radians, positive right)}.
func tick(delta: float) -> Dictionary:
	var out := {speed = 0.0, steer = 0.0}
	if status != "driving":
		return out
	if _pause > 0.0:
		_pause -= delta
		return out
	var run: Dictionary = runs[run_i]
	var pts: PackedVector2Array = run.pts
	var px := World.PX_PER_M
	var h := Vector2.from_angle(truck.global_rotation)
	var rear := truck.global_position / px + h * REAR_X_M
	var reverse: bool = run.reverse
	# Progress: the nearest point just ahead of where it was.
	var best_d := INF
	for i in range(idx, mini(idx + 40, pts.size())):
		var d := rear.distance_to(pts[i])
		if d < best_d:
			best_d = d
			idx = i
	var remaining: float = run.cum[pts.size() - 1] - run.cum[idx]
	var travel := -h if reverse else h
	var end_gone := idx >= pts.size() - 1 and (pts[pts.size() - 1] - rear).dot(travel) <= 0.0
	if remaining <= END_EPS_M or end_gone:
		_run_done()
		return out
	# Steering: pure pursuit on a point a lookahead along the path.
	var look := clampf(1.6 + 0.7 * absf(float(truck.speed)), 2.0, 6.0) if not reverse else 2.2
	var gi := idx
	while gi < pts.size() - 1 and run.cum[gi] - run.cum[idx] < look:
		gi += 1
	var goal_p := pts[gi]
	var rel := (goal_p - rear).rotated(-h.angle())
	var ld := maxf(rel.length(), 0.5)
	var max_steer := deg_to_rad(truck.max_steer_deg) * 0.95
	out.steer = clampf(atan(2.0 * WHEELBASE_M * rel.y / (ld * ld)), -max_steer, max_steer)
	# Speed: the run's limit, the bends ahead, braking to the end, and how far off the path it is.
	var v: float = run.spd[idx]
	var kmax := 0.0
	var ahead := idx
	while ahead < pts.size() - 1 and run.cum[ahead] - run.cum[idx] < 8.0:
		kmax = maxf(kmax, run.kappa[ahead])
		ahead += 1
	if kmax > 0.001:
		v = minf(v, sqrt(A_LAT_MPS2 / kmax))
	v = minf(v, sqrt(2.0 * DECEL_MPS2 * maxf(remaining - 0.15, 0.0)))
	v = minf(v, lerpf(float(truck.top_speed_mps), 1.0, clampf(best_d / 3.0, 0.0, 1.0)))
	v = maxf(v, MIN_MPS) if remaining > 1.0 else maxf(v, 0.3)
	out.speed = -minf(v, REVERSE_MPS) if reverse else v
	# Blocked: it should be moving and isn't.
	if absf(float(truck.speed)) < 0.05 and v > 0.4:
		_blocked += delta
		if _blocked >= BLOCK_S:
			_unstick(reverse)
	else:
		_blocked = 0.0
	return out


## The run's done: the next one after a pause (changing gear), or it's arrived.
func _run_done() -> void:
	var was_nudge := _nudge
	run_i += 1
	idx = 0
	_pause = GEAR_PAUSE_S
	if run_i >= runs.size():
		if was_nudge:
			drive_to(goal, false)   # (backed off: plan it again from here)
		else:
			status = "arrived"


## Stuck against something: back off a little the other way and plan again; give up after a few goes.
func _unstick(reverse: bool) -> void:
	_attempts += 1
	_blocked = 0.0
	if _attempts > MAX_ATTEMPTS:
		runs.clear()
		status = "failed"
		return
	var px := World.PX_PER_M
	var h := Vector2.from_angle(truck.global_rotation)
	var rear := truck.global_position / px + h * REAR_X_M
	var dir := h if reverse else -h   # the other way from the one it was going
	var pts := PackedVector2Array()
	for i in int(3.0 / STEP_M) + 1:
		pts.append(rear + dir * STEP_M * i)
	var run := _new_run(not reverse)
	_extend(run, pts, REVERSE_MPS if not reverse else OFFROAD_MPS)
	runs = _prepared([run])
	run_i = 0
	idx = 0
	_nudge = true
	_pause = 0.3
