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
##     Given a heading too (the Park order: command.gd, Mike 2026-11-09: a ghost
##     of where the truck ends up and which way it faces), it must end exactly
##     there, nose that way, by the quickest way it can find: `_hybrid()`, a
##     search over the whole field (see "Parking" below), in place of 1-3.
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
const MAX_REVERSE_M := 15.0         ## parking: no reversing farther than this in one go (no driver backs 40 m)
const ARRIVE_OFF_M := 0.45          ## parked at a heading: finished this far off the spot, or...
const ARRIVE_TURN_DEG := 4.0        ## ...this far off the heading, it shuffles again (`_run_done()`)
const SETTLE_M := 2.5              ## parking at a heading: the last this much of the way is straight, so it ends square
# Parking's search (_hybrid()):
const HA_CELL := 0.5                ## its grid: one state per half-metre square and heading...
const HA_BINS := 72                 ## ...headings every 5 degrees (counted from the truck's own, so it starts on one)
const HA_TURN_BINS := 3             ## a move at the plans' full lock turns this many (15 degrees); its length follows (_ha_tables())
const CLEAR_CELL := 0.1             ## the clearance map's grid (m)
const DISC_N := 8                   ## the truck's body, for the search: this many discs along it...
const DISC_R := 0.74                ## ...this big (together they cover its 4.3 x 1.37 m)
const SOFT_M := 0.3                 ## nearer than this to anything (past the discs) costs extra: it keeps clear when it can
const CLEAR_CAP := 1.2              ## the clearance map stops counting here
const COST_GEAR_S := 1.8            ## a change of gear, in seconds: braking to a stop, the pause, getting going again
const COST_SOFT_S := 0.4            ## a metre that close to something (seconds)
const COST_STEER_S := 0.03          ## a notch's change of steering (fewer wiggles)
const COST_PER_M := 0.15            ## and each metre driven, on top of its time: of two ways nearly as quick, the shorter (no loops round the field)
const SHORT_SETTLE_M := 1.0         ## the last straight in, where SETTLE_M won't fit
const HA_WEIGHT := 1.3              ## how much it trusts its estimate of the time left: a little over 1 is far quicker, and nearly as good
const HA_MAX := 30000               ## moves looked at before it gives up
const HA_MORE := 600                ## once it's found a way, this many more looked at for a quicker one
const SHOT_M := 14.0                ## within this of the spot, it tries driving straight in (_ha_shot())
const HA_WINDOW_M := 25.0           ## the search looks this far round the truck and the spot (and no further)
const HA_FAR_M := 150.0             ## a Park farther than this: by road first (the ordinary planner, which keeps to the road: it stops short of anything across it), the search once it's near
const HOLO_STEPS := [Vector3i(1, 0, 10), Vector3i(-1, 0, 10), Vector3i(0, 1, 10), Vector3i(0, -1, 10),
		Vector3i(1, 1, 14), Vector3i(1, -1, 14), Vector3i(-1, 1, 14), Vector3i(-1, -1, 14)]   ## the estimate's neighbours: x, y, length in tenths of a square
const HA_SLICE_MS := 5              ## the search runs this long a tick (think()), so a hard one never freezes the game
const CLEAR_MARGIN := 0.12          ## the search keeps this much more room (it doesn't follow its line perfectly), but on the last straight in
const PARK_TIGHT_K := 0.12          ## parking, following: a bend sharper than this (1/m) ahead...
const PARK_TIGHT_MPS := 2.5         ## ...is taken no faster than this
const PARK_CRAWL_MPS := 0.7         ## the last run's end: this slow at the very end...
const PARK_EASE := 0.45             ## ...and this much faster a metre before it
const PARK_END_M := 0.08            ## a park's runs end this near their ends (driving's: END_EPS_M)

var truck: Node2D
var status := "idle"                ## idle, driving, arrived, failed
var runs: Array = []
var run_i := 0
var idx := 0
var goal := Vector2.ZERO            ## world px
var goal_heading := NAN             ## the way its nose is to end up (radians), or NAN: its own choice
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
var unsticks := 0                   ## times it's been stuck against something and backed off (since the last order: the log, tests)
var plan_ms := 0                    ## how long the last plan took
var plan_note := ""                 ## parking: why the last plan found no way (or how many moves it looked at)
# Parking's search: the field as the search sees it (_ha_setup()).
var _ox := 0.0                      ## the search's window (m, world): its top left...
var _oy := 0.0
var _aw := 0.0                      ## ...and size
var _ah := 0.0
var _clear := PackedFloat32Array()  ## clearance: the distance from each CLEAR_CELL square to the nearest thing solid
var _cw := 0
var _ch := 0
var _road := PackedByteArray()      ## HA_CELL squares on a road (driven at ROAD_MPS)
var _gw := 0
var _gh := 0
var _ha_s := 1.4                    ## a move's length (m)
var _th0 := 0.0                     ## heading bin 0 (the truck's heading)
var _prim_g := PackedInt32Array()   ## each move: its gear (1, -1)...
var _prim_db := PackedInt32Array()  ## ...and how many heading bins it turns, forward (-3, -1, 0, 1, 3)
var _pe := PackedVector2Array()     ## [bin * moves + move]: where it ends, from where it starts
var _pm := PackedVector2Array()     ## ...where its middle is
var _pmd := PackedVector2Array()    ## [(bin * moves + move) * DISC_N + disc]: the discs at its middle
var _bd := PackedVector2Array()     ## [bin * DISC_N + disc]: the discs for a heading, from the rear axle
var _disc_off := PackedFloat32Array()   ## each disc's distance ahead of the rear axle
var planning := false               ## parking's search is running (a slice a tick, think()): it waits, engine starting
# The search's state between slices (_hybrid_begin()):
var _s_r0 := Vector2.ZERO
var _s_goal := Vector2.ZERO
var _s_nose := Vector2.RIGHT
var _s_holo := PackedFloat32Array()
var _s_turn := PackedFloat32Array()
var _s_nx := PackedFloat32Array()
var _s_ny := PackedFloat32Array()
var _s_nk := PackedInt32Array()
var _s_ng := PackedFloat32Array()
var _s_gear := PackedInt32Array()
var _s_db := PackedInt32Array()
var _s_par := PackedInt32Array()
var _s_prim := PackedInt32Array()
var _s_best := {}
var _s_hf: Array = []
var _s_hi: Array = []
var _s_stuck := false
var _s_found := {}
var _s_cost := INF
var _s_expanded := 0
var _s_after := 0
var _s_us := 0                      ## its time so far (microseconds)
var _s_holo_done := false           ## the estimate's worked out (_holo_step())
var _h_hf: Array = []               ## ...its heap meanwhile
var _h_hi: Array = []
var _reshuffle := false             ## the plan under way is a shuffle to straighten up: none found is fine


func _init(truck_: Node2D) -> void:
	truck = truck_
	_r_use = WHEELBASE_M / tan(deg_to_rad(truck.max_steer_deg * STEER_USE)) * 1.05


func active() -> bool:
	return status == "driving"


func stop() -> void:
	_cancel_search()
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
## up) from where the truck is now, its nose ending along `heading` (radians;
## NAN: whichever way suits the spot). False if there's no way.
func drive_to(dest_px: Vector2, fresh := true, heading := NAN) -> bool:
	goal = dest_px
	if fresh:
		_attempts = 0
		unsticks = 0
		goal_heading = heading
	var px := World.PX_PER_M
	var h0 := Vector2.from_angle(truck.global_rotation)
	var r0 := truck.global_position / px + h0 * REAR_X_M
	if fresh:
		_reshuffle = false
	if not is_nan(goal_heading) and r0.distance_to(dest_px / px) <= HA_FAR_M:
		# Parking at a heading (Park): a search for the quickest way there, a slice
		# a tick (_hybrid_begin()); it waits, its engine starting, till think() has the way.
		# (Farther off, the ordinary planner below takes it there by road, and once
		# it's arrived, _run_done()'s shuffle parks it with the search.)
		_build_net()
		_begin_checks()
		var nose := Vector2.from_angle(goal_heading)
		runs.clear()
		run_i = 0
		idx = 0
		_blocked = 0.0
		_pause = 0.0
		_nudge = false
		short = false
		if not _hybrid_begin(r0, h0, dest_px / px + nose * REAR_X_M, nose):
			status = "failed"
			return false
		status = "driving"
		return true
	_cancel_search()
	_cut = false
	var t0 := Time.get_ticks_msec()
	var plan := _plan(r0, h0, dest_px / px)
	plan_ms = Time.get_ticks_msec() - t0
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
	var h :=(dest - r0).normalized() if dest.distance_to(r0) > 0.1 else h0
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


# ----------------------------------------------------------------- parking --
#
# Parking at a heading (the Park order) is a search, hybrid A* (as self-parking
# cars use; Mike, 2026-11-09: "as fast and efficient as possible", after the
# old way looped 60 m round the field for a 9 m move and stopped short of
# another). The truck's moves are short arcs, forward or reversing, straight,
# gently or hard either way. The search grows the quickest sequence of them
# from where the truck is, by the TIME they'd take (5 m/s on a road, 3 off it,
# 1.5 reversing, COST_GEAR_S a change of gear), led by an estimate of the time
# left (_holo_begin(), _holo_step()). Every move's checked against a clearance map of
# everything solid (_ha_setup()), the truck as a row of discs; close to things
# costs a little extra, so it keeps clear when it can and squeezes in when it
# must. Near the spot it keeps trying to drive (or back) straight in along a
# smooth curve ending on SETTLE_M straight (_ha_shot()); the first that's clear
# is kept, and a few hundred more moves are looked at for a quicker one.

## Starts parking's search. It runs a slice at a time, HA_SLICE_MS a tick
## (think()), while the engine starts: a hard spot can take a second or two of
## searching, and all at once that would freeze the game. (Not on a worker
## thread: script there ran fifty times slower.) False if the spot's taken.
func _hybrid_begin(r0: Vector2, h0: Vector2, goal_rear: Vector2, nose: Vector2) -> bool:
	_cancel_search()
	if not _body_free(goal_rear, nose):
		plan_note = "the spot's taken or off the field"
		return false   # (something's in the spot, or it's off the field)
	var t0 := Time.get_ticks_usec()
	_ha_setup(h0.angle(), Rect2(r0, Vector2.ZERO).expand(goal_rear).grow(HA_WINDOW_M))
	_s_r0 = r0
	_s_goal = goal_rear
	_s_nose = nose
	_holo_begin(goal_rear)   # (the estimate: worked out a slice at a time, think(), before the search)
	_s_holo_done = false
	# The other half of the estimate: it has to turn to face the way it's to end up, and
	# it turns at most a radian every _r_use metres, taken at PARK_TIGHT_MPS.
	_s_turn.resize(HA_BINS)
	for kb in HA_BINS:
		_s_turn[kb] = _r_use * absf(angle_difference(_th0 + kb * TAU / HA_BINS, nose.angle())) * (1.0 / PARK_TIGHT_MPS + COST_PER_M)
	# The nodes: where each is, its heading bin, the time to it, its gear and
	# turn, the node it came from and the move that brought it.
	_s_nx = PackedFloat32Array([r0.x])
	_s_ny = PackedFloat32Array([r0.y])
	_s_nk = PackedInt32Array([0])
	_s_ng = PackedFloat32Array([0.0])
	_s_gear = PackedInt32Array([0])
	_s_db = PackedInt32Array([0])
	_s_par = PackedInt32Array([-1])
	_s_prim = PackedInt32Array([-1])
	_s_best = {_ha_key(r0.x, r0.y, 0): 0.0}   # (state -> the least time found to it)
	_s_hf = []
	_s_hi = []
	_hpush(_s_hf, _s_hi, 0.0, 0)
	_s_stuck = _ha_check(r0.x, r0.y, _bd, 0, DISC_R + CLEAR_MARGIN) < 0   # (close to something already: its first move may be too)
	_s_found = {}
	_s_cost = INF
	_s_expanded = 0
	_s_after = 0
	_s_us = Time.get_ticks_usec() - t0
	planning = true
	return true


## Called every tick (supply_truck.gd): another slice of the search; done, its
## way's taken up (or, none found, it's failed, with a red ping at the spot).
func think() -> void:
	if not planning:
		return
	var t0 := Time.get_ticks_usec()
	var deadline := t0 + HA_SLICE_MS * 1000
	if not _s_holo_done:
		_s_holo_done = _holo_step(deadline)
		if not _s_holo_done:
			_s_us += Time.get_ticks_usec() - t0
			return
	var done := _hybrid_step(deadline)
	_s_us += Time.get_ticks_usec() - t0
	if not done:
		return
	planning = false
	plan_ms = int(_s_us / 1000)
	_cut = false
	var raw := _hybrid_build()
	var plan: Array = _validated(_prepared(raw)) if not raw.is_empty() else []
	short = _cut
	if plan.is_empty():
		runs.clear()
		if _reshuffle:
			status = "arrived"   # (a shuffle to put it straighter, and none to be had: it's as near as it gets)
		else:
			status = "failed"
			truck.get_tree().call_group("command", "refuse_ping", goal)
		return
	runs = plan
	run_i = 0
	idx = 0


## Drops a search still going (a new order, or Stop).
func _cancel_search() -> void:
	planning = false


## The search, until `deadline_us` (Time.get_ticks_usec()): true once it's
## done (a way found and nothing left that could be quicker, or none at all).
func _hybrid_step(deadline_us: int) -> bool:
	var n_prims := _prim_g.size()
	var c_road := 1.0 / ROAD_MPS
	var c_off := 1.0 / OFFROAD_MPS
	var c_rev := 1.0 / REVERSE_MPS
	var c_tight := 1.0 / PARK_TIGHT_MPS   # (turning: the follower takes it no faster, near a hard bend)
	var goal_rear := _s_goal
	var nose := _s_nose
	var slice := 0
	while not _s_hf.is_empty() and _s_expanded < HA_MAX:
		slice += 1
		if slice % 32 == 0 and Time.get_ticks_usec() > deadline_us:
			return false   # (more next tick)
		var f: float = _s_hf[0]
		var i := _hpop(_s_hf, _s_hi)
		var g: float = _s_ng[i]
		# Found a way: done once nothing left could be quicker (by the unweighted estimate), or after HA_MORE more.
		if not _s_found.is_empty() and (g + (f - g) / HA_WEIGHT >= _s_cost or _s_after > HA_MORE):
			return true
		var x: float = _s_nx[i]
		var y: float = _s_ny[i]
		var k: int = _s_nk[i]
		if _s_best.get(_ha_key(x, y, k), INF) < g - 0.0001:
			continue   # (a quicker way here was found since)
		_s_expanded += 1
		if not _s_found.is_empty():
			_s_after += 1
		var gear: int = _s_gear[i]
		# Straight in from here?
		var to_goal := Vector2(x, y).distance_to(goal_rear)
		if to_goal <= SHOT_M and (_s_expanded % 4 == 1 or to_goal < 5.0):
			var shot := _ha_shot(Vector2(x, y), _th0 + k * TAU / HA_BINS, gear, goal_rear, nose)
			if not shot.is_empty() and g + shot.cost < _s_cost:
				_s_cost = g + shot.cost
				_s_found = {node = i, shot = shot}
		var hard := DISC_R + CLEAR_MARGIN - (0.3 if _s_stuck and i == 0 else 0.0)
		for p in n_prims:
			var pg: int = _prim_g[p]
			var pdb: int = _prim_db[p]
			var tp := k * n_prims + p
			var e: Vector2 = _pe[tp]
			var ex := x + e.x
			var ey := y + e.y
			var ek := posmod(k + pg * pdb, HA_BINS)
			var m: Vector2 = _pm[tp]
			var t1 := _ha_check(x + m.x, y + m.y, _pmd, tp * DISC_N, hard)
			if t1 < 0:
				continue
			var t2 := _ha_check(ex, ey, _bd, ek * DISC_N, hard)
			if t2 < 0:
				continue
			var cell := _ha_cell(ex, ey)
			if cell < 0:
				continue
			var h: float = _s_holo[cell]
			if h == INF:
				continue
			h = maxf(h, _s_turn[ek])
			var cost := _ha_s * (COST_PER_M + (c_rev if pg < 0 else (c_tight if pdb != 0 else (c_road if _road[cell] else c_off))))
			if gear != 0 and pg != gear:
				cost += COST_GEAR_S
			elif gear != 0:
				cost += absi(pdb - _s_db[i]) * COST_STEER_S
			if t1 > 0 or t2 > 0:
				cost += _ha_s * COST_SOFT_S
			var g2 := g + cost
			var key2 := _ha_key(ex, ey, ek)
			if _s_best.get(key2, INF) <= g2:
				continue
			_s_best[key2] = g2
			_s_nx.append(ex)
			_s_ny.append(ey)
			_s_nk.append(ek)
			_s_ng.append(g2)
			_s_gear.append(pg)
			_s_db.append(pdb)
			_s_par.append(i)
			_s_prim.append(p)
			_hpush(_s_hf, _s_hi, g2 + HA_WEIGHT * h, _s_nx.size() - 1)
	return true


## The search's result as runs (one per gear; not yet checked against the
## physics: think() does that): the moves from the truck to the node the shot
## left from, then the shot. [] if it found no way.
func _hybrid_build() -> Array:
	var r0 := _s_r0
	var start_cell := _ha_cell(r0.x, r0.y)
	plan_note = "%d moves looked at, %d states, %.1f s%s%s" % [_s_expanded, _s_nx.size(), _s_cost,
			"" if start_cell >= 0 and _s_holo[start_cell] != INF else ", no way from where it is (as the crow flies)",
			", it started touching something" if _s_stuck else ""]
	if _s_found.is_empty():
		return []
	var chain: Array = []
	var n: int = _s_found.node
	while n > 0:
		chain.push_front(n)
		n = _s_par[n]
	var out: Array = []
	var run := _new_run(false)
	var run_gear := 0
	var at := r0
	for c: int in chain:
		var pg: int = _s_gear[c]
		var par: int = _s_par[c]
		var pts := _ha_points(Vector2(_s_nx[par], _s_ny[par]), _s_nk[par], _s_prim[c])
		if pg != run_gear:
			if run.pts.size() >= 2:
				out.append(run)
			run = _new_run(pg < 0)
			_push(run, at, _ha_speed(at, pg < 0))
			run_gear = pg
		for q in pts:
			_push(run, q, _ha_speed(q, pg < 0))
		at = pts[pts.size() - 1]
	var shot: Dictionary = _s_found.shot
	var sg := -1 if shot.reverse else 1
	if sg != run_gear:
		if run.pts.size() >= 2:
			out.append(run)
		run = _new_run(shot.reverse)
		_push(run, at, _ha_speed(at, shot.reverse))
	for q: Vector2 in shot.pts:
		_push(run, q, _ha_speed(q, shot.reverse))
	out.append(run)
	return out


## Driving (or backing) straight into the spot (rear axle `goal_rear`, nose
## along `nose`) from the pose (rear axle `p`, nose along `th`, in `gear`): a
## smooth curve to the start of the last straight, then the straight
## (SETTLE_M; where that won't fit, as by the field's edge, SHORT_SETTLE_M).
## {pts, reverse, cost (s)} for the quickest that's clear, or {}.
func _ha_shot(p: Vector2, th: float, gear: int, goal_rear: Vector2, nose: Vector2) -> Dictionary:
	var h := Vector2.from_angle(th)
	var out := {}
	for settle: float in [SETTLE_M, SHORT_SETTLE_M]:
		for reverse in [false, true]:
			var to: Vector2 = goal_rear + nose * settle * (1.0 if reverse else -1.0)
			var d0 := -h if reverse else h
			var d1 := -nose if reverse else nose
			var pts := _fit(p, d0, to, d1)
			if pts.is_empty() or (pts.size() == 2 and absf(d0.angle_to(d1)) > deg_to_rad(3.0)):
				continue   # (no curve: or "already there" pointing the wrong way)
			var tail := _straight(to, goal_rear)
			pts.append_array(tail)
			var length := _length(pts)
			if length > p.distance_to(to) * 2.5 + 6.0 or (reverse and length > MAX_REVERSE_M):
				continue   # (a loop round: the search will find better)
			if not _drivable(pts, d0):
				continue   # (a bend sharper than it can turn: a short curve can pass _fit()'s check)
			var cost := (_ha_time(pts, reverse) + length * COST_PER_M
					+ (COST_GEAR_S if gear != 0 and gear != (-1 if reverse else 1) else 0.0))
			if (out.is_empty() or cost < out.cost) and _ha_path_ok(pts, reverse, pts.size() - tail.size()):
				out = {pts = pts, reverse = reverse, cost = cost}
		if not out.is_empty():
			return out   # (the short straight only if the long one won't do)
	return out


## Whether every bit of `pts` (driven from heading `d0`) bends no sharper than
## the truck can take (the plans' turning circle, with a little to spare). Point
## to point: a curve over a short distance can hide a kink between samples.
func _drivable(pts: PackedVector2Array, d0: Vector2) -> bool:
	var prev := d0
	var kmax := 1.1 / _r_use
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		var length := seg.length()
		if length < 0.01:
			continue
		var dir := seg / length
		if absf(prev.angle_to(dir)) > length * kmax + 0.03:
			return false
		prev = dir
	return true


## Whether the truck can drive `pts` (in reverse or not) clear of everything,
## with CLEAR_MARGIN to spare up to point `tail`. From there (the last straight
## in, which may be tight) its exact outline is checked instead (_body_free()):
## the discs bulge nearly half a metre past its bumpers along its middle, so a
## spot with a crate 0.5 m off its nose or tail would never pass by them.
func _ha_path_ok(pts: PackedVector2Array, reverse: bool, tail: int) -> bool:
	var discs := PackedVector2Array()
	discs.resize(DISC_N)
	for i in range(1, pts.size()):
		var d := pts[i] - pts[i - 1]
		if d.length_squared() < 0.0001:
			continue
		var dir := d.normalized() * (-1.0 if reverse else 1.0)
		if i >= tail:
			if not _body_free(pts[i], dir):
				return false
			continue
		for j in DISC_N:
			discs[j] = dir * _disc_off[j]
		if _ha_check(pts[i].x, pts[i].y, discs, 0, DISC_R + CLEAR_MARGIN) < 0:
			return false
	return true


## The time to drive `pts` as the follower will: reversing, a sharp bend (PARK_TIGHT_K), on a road, off it.
func _ha_time(pts: PackedVector2Array, reverse: bool) -> float:
	var t := 0.0
	var prev := Vector2.ZERO
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		var length := seg.length()
		if length < 0.0001:
			continue
		var dir := seg / length
		var sharp := prev != Vector2.ZERO and absf(prev.angle_to(dir)) / length > PARK_TIGHT_K
		prev = dir
		if reverse:
			t += length / REVERSE_MPS
		elif sharp:
			t += length / PARK_TIGHT_MPS
		else:
			var cell := _ha_cell(pts[i].x, pts[i].y)
			t += length / (ROAD_MPS if cell >= 0 and _road[cell] else OFFROAD_MPS)
	return t


## How fast to go at `q`: as the search reckoned it.
func _ha_speed(q: Vector2, reverse: bool) -> float:
	if reverse:
		return REVERSE_MPS
	var cell := _ha_cell(q.x, q.y)
	return ROAD_MPS if cell >= 0 and _road[cell] else OFFROAD_MPS


## Whether the truck, its discs at `discs[base..]` from (`x`, `y`), is clear:
## -1 not (inside the discs' `hard` of something, or of the field's edge), 1
## clear but close (within SOFT_M more), 0 clear.
func _ha_check(x: float, y: float, discs: PackedVector2Array, base: int, hard: float) -> int:
	var tight := 0
	for j in DISC_N:
		var d: Vector2 = discs[base + j]
		var px := x + d.x - _ox   # (in the window)
		var py := y + d.y - _oy
		if px < hard or py < hard or px > _aw - hard or py > _ah - hard:
			return -1
		var c: float = _clear[int(py / CLEAR_CELL) * _cw + int(px / CLEAR_CELL)]
		if c < hard:
			return -1
		if c < hard + SOFT_M:
			tight = 1
	return tight


## The search grid square under world (`x`, `y`) (metres), or -1 outside the window.
func _ha_cell(x: float, y: float) -> int:
	x -= _ox
	y -= _oy
	if x < 0.0 or y < 0.0 or x >= _aw or y >= _ah:
		return -1
	return int(y / HA_CELL) * _gw + int(x / HA_CELL)


func _ha_key(x: float, y: float, k: int) -> int:
	return (k * _gh + int((y - _oy) / HA_CELL)) * _gw + int((x - _ox) / HA_CELL)


## The points (every quarter of it) along move `prim` from rear axle `p` at heading bin `k`.
func _ha_points(p: Vector2, k: int, prim: int) -> PackedVector2Array:
	var th := _th0 + k * TAU / HA_BINS
	var kappa := _prim_db[prim] * TAU / HA_BINS / _ha_s
	var out := PackedVector2Array()
	for i in range(1, 5):
		out.append(p + _arc(th, _prim_g[prim], kappa, _ha_s * i / 4.0))
	return out


## Where the rear axle gets to (from where it starts) going `s` metres in gear
## `g` from heading `th`, turning `kappa` (1/m; positive: to the right) as it goes forward.
static func _arc(th: float, g: int, kappa: float, s: float) -> Vector2:
	if absf(kappa) < 0.000001:
		return Vector2.from_angle(th) * g * s
	var d := g * s * kappa
	return Vector2((sin(th + d) - sin(th)) / kappa, (cos(th) - cos(th + d)) / kappa)


## The field as the search sees it, in `window` (metres: the part of the play
## area round the truck and the spot, HA_WINDOW_M to spare; on a 2 km field
## the whole of it would be far too big): the clearance map (everything solid
## the truck runs into, as it is now), the road squares, and the moves. The
## window's edge is a wall to the search.
func _ha_setup(th0: float, window: Rect2) -> void:
	var arena := Rect2(World.ARENA.position / World.PX_PER_M, World.ARENA.size / World.PX_PER_M)
	window = window.intersection(arena)
	_ox = window.position.x
	_oy = window.position.y
	_aw = window.size.x
	_ah = window.size.y
	_cw = ceili(_aw / CLEAR_CELL)
	_ch = ceili(_ah / CLEAR_CELL)
	_clear.resize(_cw * _ch)
	_clear.fill(CLEAR_CAP)
	for ob: Dictionary in _ha_obstacles(window):
		_ha_stamp(ob)
	_gw = ceili(_aw / HA_CELL)
	_gh = ceili(_ah / HA_CELL)
	_road.resize(_gw * _gh)
	_road.fill(0)
	var origin := Vector2(_ox, _oy)
	for pts: PackedVector2Array in _roads:
		for i in range(1, pts.size()):
			var box := Rect2(pts[i - 1] - origin, Vector2.ZERO).expand(pts[i] - origin).grow(ROADSIDE_M)
			for cy in range(maxi(int(box.position.y / HA_CELL), 0), mini(int(box.end.y / HA_CELL), _gh - 1) + 1):
				for cx in range(maxi(int(box.position.x / HA_CELL), 0), mini(int(box.end.x / HA_CELL), _gw - 1) + 1):
					var c := origin + Vector2(cx + 0.5, cy + 0.5) * HA_CELL
					if c.distance_to(Geometry2D.get_closest_point_to_segment(c, pts[i - 1], pts[i])) <= ROADSIDE_M:
						_road[cy * _gw + cx] = 1
	_ha_tables(th0)


## Everything solid the truck runs into (its collision mask), but itself: {kind
## rect (inv: the world-px to shape transform, half), circle (c, r), capsule
## (a, b, r) or poly (pts)}, metres, each with its bounding box.
func _ha_obstacles(window: Rect2) -> Array:
	var px := World.PX_PER_M
	var all := RectangleShape2D.new()
	all.size = (window.size + Vector2.ONE * 2.0 * CLEAR_CAP) * px
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = all
	q.transform = Transform2D(0.0, window.get_center() * px)
	q.collision_mask = truck.collision_mask
	q.exclude = [truck.get_rid()]
	var out: Array = []
	var seen := {}
	for hit: Dictionary in _space.intersect_shape(q, 2048):
		var body = hit.collider
		if not body is CollisionObject2D:
			continue
		var node = body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
		if node == null or seen.has(node.get_instance_id()):
			continue
		seen[node.get_instance_id()] = true
		var xf: Transform2D = node.global_transform
		if node is CollisionPolygon2D:
			if node.disabled or node.polygon.size() < 3:
				continue
			var pts := PackedVector2Array()
			for v: Vector2 in node.polygon:
				pts.append(xf * v / px)
			out.append({kind = "poly", pts = pts, box = _bounds(pts)})
			continue
		if not node is CollisionShape2D or node.disabled or node.shape == null:
			continue
		var sh: Shape2D = node.shape
		if sh is CircleShape2D:
			var r: float = sh.radius * xf.get_scale().x / px
			out.append({kind = "circle", c = xf.origin / px, r = r, box = Rect2(xf.origin / px, Vector2.ZERO).grow(r)})
		elif sh is CapsuleShape2D:
			var hs := maxf(sh.height / 2.0 - sh.radius, 0.0)
			var a := xf * Vector2(0.0, -hs) / px
			var b := xf * Vector2(0.0, hs) / px
			var r: float = sh.radius * xf.get_scale().x / px
			out.append({kind = "capsule", a = a, b = b, r = r, box = Rect2(a, Vector2.ZERO).expand(b).grow(r)})
		else:   # a rectangle (anything else: its bounding rectangle)
			var rect: Rect2 = sh.get_rect()
			var at := xf * Transform2D(0.0, rect.get_center())
			var half := rect.size / 2.0
			var corners := PackedVector2Array()
			for c in [half, Vector2(half.x, -half.y), -half, Vector2(-half.x, half.y)]:
				corners.append(at * c / px)
			out.append({kind = "rect", inv = at.affine_inverse(), half = half, box = _bounds(corners)})
	return out


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	return box


## Marks an obstacle on the clearance map: each square near it gets the
## distance to it (from the square's middle, less a little for the square's size).
func _ha_stamp(ob: Dictionary) -> void:
	var px := World.PX_PER_M
	var origin := Vector2(_ox, _oy)
	var box: Rect2 = ob.box.grow(CLEAR_CAP)
	box.position -= origin   # (in the window)
	var x0 := maxi(int(box.position.x / CLEAR_CELL), 0)
	var x1 := mini(int(box.end.x / CLEAR_CELL), _cw - 1)
	var y0 := maxi(int(box.position.y / CLEAR_CELL), 0)
	var y1 := mini(int(box.end.y / CLEAR_CELL), _ch - 1)
	var kind: String = ob.kind
	var slack := CLEAR_CELL * 0.71
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var p := origin + Vector2(cx + 0.5, cy + 0.5) * CLEAR_CELL   # (world metres)
			var d := 0.0
			if kind == "rect":
				var local: Vector2 = ob.inv * (p * px)
				var qx: float = absf(local.x) - ob.half.x
				var qy: float = absf(local.y) - ob.half.y
				d = Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() / px
			elif kind == "circle":
				d = maxf(p.distance_to(ob.c) - ob.r, 0.0)
			elif kind == "capsule":
				d = maxf(p.distance_to(Geometry2D.get_closest_point_to_segment(p, ob.a, ob.b)) - ob.r, 0.0)
			else:
				var pts: PackedVector2Array = ob.pts
				if not Geometry2D.is_point_in_polygon(p, pts):
					d = INF
					for i in pts.size():
						var a := pts[i]
						var b := pts[(i + 1) % pts.size()]
						d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
			d = maxf(d - slack, 0.0)
			var idx := cy * _cw + cx
			if d < _clear[idx]:
				_clear[idx] = d


## The moves, and where each takes the truck (and its discs) from each heading.
## Ten: forward and reversing, straight, a little either way, and at the plans'
## full lock either way; the length is what turns HA_TURN_BINS at full lock.
func _ha_tables(th0: float) -> void:
	_th0 = th0
	var bin := TAU / HA_BINS
	_ha_s = _r_use * HA_TURN_BINS * bin
	_prim_g = PackedInt32Array()
	_prim_db = PackedInt32Array()
	for g in [1, -1]:
		for db in [-HA_TURN_BINS, -1, 0, 1, HA_TURN_BINS]:
			_prim_g.append(g)
			_prim_db.append(db)
	var n := _prim_g.size()
	var length: float = truck.LENGTH_M
	_disc_off.resize(DISC_N)
	for j in DISC_N:
		_disc_off[j] = -REAR_X_M - length / 2.0 + (j + 0.5) * length / DISC_N
	_bd.resize(HA_BINS * DISC_N)
	_pe.resize(HA_BINS * n)
	_pm.resize(HA_BINS * n)
	_pmd.resize(HA_BINS * n * DISC_N)
	for k in HA_BINS:
		var th := th0 + k * bin
		var dir := Vector2.from_angle(th)
		for j in DISC_N:
			_bd[k * DISC_N + j] = dir * _disc_off[j]
		for p in n:
			var g: int = _prim_g[p]
			var kappa: float = _prim_db[p] * bin / _ha_s
			_pe[k * n + p] = _arc(th, g, kappa, _ha_s)
			_pm[k * n + p] = _arc(th, g, kappa, _ha_s / 2.0)
			var mid_dir := Vector2.from_angle(th + g * _ha_s / 2.0 * kappa)
			for j in DISC_N:
				_pmd[(k * n + p) * DISC_N + j] = mid_dir * _disc_off[j]


## The estimate of the time left from each square to the spot, for something
## that could turn on the spot (going round what's in the way, faster on roads):
## a Dijkstra out from the spot over the squares the truck's width fits in. INF: no way.
## Starts it (into _s_holo; _holo_step() a slice at a time: on a long trip's
## window it takes a while).
func _holo_begin(goal_rear: Vector2) -> void:
	_s_holo.resize(_gw * _gh)
	_s_holo.fill(INF)
	_h_hf = []
	_h_hi = []
	var start := _ha_cell(goal_rear.x, goal_rear.y)
	if start >= 0:
		_s_holo[start] = 0.0
		_hpush(_h_hf, _h_hi, 0.0, start)


## More of it, until `deadline_us`: true once it's done. Each metre costs its
## time (on a road or off it) and COST_PER_M, as in the search, so the estimate
## is as near the search's own costs as it can be without going over them.
func _holo_step(deadline_us: int) -> bool:
	var half_w: float = truck.WIDTH_M / 2.0
	var c_road := 1.0 / ROAD_MPS + COST_PER_M
	var c_off := 1.0 / OFFROAD_MPS + COST_PER_M
	var n := 0
	while not _h_hf.is_empty():
		n += 1
		if n % 64 == 0 and Time.get_ticks_usec() > deadline_us:
			return false
		var f: float = _h_hf[0]
		var c := _hpop(_h_hf, _h_hi)
		if f > _s_holo[c] + 0.0001:
			continue   # (stale; the slack: `_s_holo` holds 32-bit floats, `f` is 64-bit)
		var cx := c % _gw
		var cy := c / _gw
		for s: Vector3i in HOLO_STEPS:
			var nx := cx + s.x
			var ny := cy + s.y
			if nx < 0 or ny < 0 or nx >= _gw or ny >= _gh:
				continue
			var nc := ny * _gw + nx
			# (somewhere the truck's width fits: its middle's this far from anything)
			var ci := mini(int((ny + 0.5) * HA_CELL / CLEAR_CELL), _ch - 1) * _cw + mini(int((nx + 0.5) * HA_CELL / CLEAR_CELL), _cw - 1)
			if _clear[ci] < half_w:
				continue
			var nf := f + HA_CELL * s.z / 10.0 * (c_road if _road[nc] else c_off)
			if nf < _s_holo[nc] - 0.0001:   # (the slack again: without it, a value rounded up into 32 bits came back round for ever)
				_s_holo[nc] = nf
				_hpush(_h_hf, _h_hi, nf, nc)
	return true


## A binary heap in two arrays (the keys, and what they're for): add one...
static func _hpush(hf: Array, hi: Array, f: float, i: int) -> void:
	hf.append(f)
	hi.append(i)
	var c := hf.size() - 1
	while c > 0:
		var p := (c - 1) >> 1
		if hf[p] <= f:
			break
		hf[c] = hf[p]
		hi[c] = hi[p]
		c = p
	hf[c] = f
	hi[c] = i


## ...and take the least off (what it's for).
static func _hpop(hf: Array, hi: Array) -> int:
	var top: int = hi[0]
	var lf: float = hf.pop_back()
	var li: int = hi.pop_back()
	var n := hf.size()
	if n > 0:
		var c := 0
		while true:
			var l := 2 * c + 1
			if l >= n:
				break
			var r := l + 1
			var m := l if r >= n or hf[l] <= hf[r] else r
			if hf[m] >= lf:
				break
			hf[c] = hf[m]
			hi[c] = hi[m]
			c = m
		hf[c] = lf
		hi[c] = li
	return top


## Whether the truck's middle is within ARRIVE_OFF_M of where it was to park and its nose within
## ARRIVE_TURN_DEG of the heading (a heading goal only).
func _parked() -> bool:
	var off: float = (truck.global_position - goal).length() / World.PX_PER_M
	return off <= ARRIVE_OFF_M and absf(angle_difference(truck.global_rotation, goal_heading)) <= deg_to_rad(ARRIVE_TURN_DEG)


## Points STEP_M apart from `a` to `b`, `a` left out.
func _straight(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(ceili(a.distance_to(b) / STEP_M), 1)
	for i in range(1, n + 1):
		out.append(a.lerp(b, float(i) / n))
	return out


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
	var lines: Array[PackedVector2Array] = []   # every road's centre line, world metres
	for road in truck.get_tree().get_nodes_in_group("roads"):
		if road.has_method("centre_lines"):
			lines.append_array(road.centre_lines())   # a junction (road_junction.gd): through it, and each arm
			continue
		if road.curve == null or road.curve.point_count < 2:
			continue
		var baked: PackedVector2Array = road.curve.get_baked_points()
		var world := PackedVector2Array()
		for p in baked:
			world.append(road.to_global(p) / px)
		lines.append(world)
	for world in lines:
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


## Whether nothing solid is where the truck's body would be with its rear axle at `rear` (metres), nose along
## `nose`, and all of it's inside the play area (supply_truck.gd stops dead at its edge).
func _body_free(rear: Vector2, nose: Vector2) -> bool:
	var xform := Transform2D(nose.angle(), (rear + nose * -REAR_X_M) * World.PX_PER_M)
	var half: Vector2 = Vector2(truck.LENGTH_M, truck.WIDTH_M) * World.PX_PER_M / 2.0
	for corner in [half, Vector2(half.x, -half.y), -half, Vector2(-half.x, half.y)]:
		if not World.ARENA.has_point(xform * corner):
			return false
	_query.transform = xform
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
	if status != "driving" or planning or runs.is_empty():
		return out   # (or still working out the way)
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
	# (a park's runs are followed right to their ends: the last is the spot itself, and one before a
	# short last run must leave it lined up)
	var end_eps := PARK_END_M if not is_nan(goal_heading) else END_EPS_M
	if remaining <= end_eps or end_gone:
		_run_done()
		return out
	# Steering: pure pursuit on a point a lookahead along the path. Parking (tight
	# moves near things), a shorter one: it holds the line closer.
	var parking := not is_nan(goal_heading)
	var look := clampf(1.6 + 0.7 * absf(float(truck.speed)), 2.0, 6.0) if not reverse else 2.2
	if parking:
		look = clampf(1.1 + 0.5 * absf(float(truck.speed)), 1.6, 6.0) if not reverse else 1.8
	var gi := idx
	while gi < pts.size() - 1 and run.cum[gi] - run.cum[idx] < look:
		gi += 1
	var goal_p := pts[gi]
	var along: float = run.cum[gi] - run.cum[idx]
	if gi == pts.size() - 1 and along < look and gi > 0:
		# Near the end the point runs on past it, along the way the path ends: aimed at the end point
		# itself, it'd finish pointing at it rather than lined up (a parked heading would be off).
		goal_p += (pts[gi] - pts[gi - 1]).normalized() * (look - along)
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
	if parking:
		# Tight bends slower (the wheel can only turn so fast: at speed it runs wide), and
		# the last few metres into the spot at a crawl, so it ends square.
		if kmax > PARK_TIGHT_K:
			v = minf(v, PARK_TIGHT_MPS)
		if run_i == runs.size() - 1:
			v = minf(v, PARK_CRAWL_MPS + PARK_EASE * remaining)
		v = minf(v, lerpf(v, 0.8, clampf((best_d - 0.25) / 0.5, 0.0, 1.0)))   # (well off the line: slow, to get back on it)
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
			_reshuffle = false
			drive_to(goal, false)   # (backed off: plan it again from here)
		elif not is_nan(goal_heading) and not _parked() and _attempts < MAX_ATTEMPTS:
			# Parked off the spot or askew: plan again from here, a shuffle to put it right.
			_attempts += 1
			_reshuffle = true
			if not drive_to(goal, false):
				status = "arrived"   # (no way to do better: it's as near as it gets)
		else:
			status = "arrived"


## Stuck against something: back off a little the other way and plan again; give up after a few goes.
func _unstick(reverse: bool) -> void:
	_attempts += 1
	unsticks += 1
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
