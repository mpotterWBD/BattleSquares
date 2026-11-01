extends "res://scripts/soldier.gd"
## The shared AI body for computer-run squares (scripts/squadmate.gd for the
## player's squad, scripts/enemy.gd for the blue enemies): walking to a spot
## round other squares, noticing when it's stuck, and shooting at
## `attack_target` with fire discipline. What to walk to and what to shoot
## is up to the subclass.
##
## Walking (_walk_to): heads for a point, easing off over the last stretch,
## bending round any square in the way (_steer). It looks ahead for solid
## things too (a desk, a crate, a helicopter: _avoid_obstacles()), and goes
## round them before it gets there rather than walking into them and
## sliding along. If it stops getting closer it tries passing on the other
## side, and after STUCK_TIME_S gives up and calls _arrive() as if it had
## got there.
##
## Out of ammo (rifle empty and no spare with rounds in it), it goes for
## the nearest ammo on the field (a dead square's magazine, ammo_pickup.gd)
## within AMMO_SEARCH_M that nobody else is going for: it claims it, jogs
## there round anything in the way, takes it, reloads, and goes back to
## what it was doing (_ammo_run(), checked first by the subclasses each
## tick). Short of ammo (less than a full magazine all told) it doesn't
## wait to run dry: it picks up any within AMMO_TOPUP_M, if it's free to
## (_may_top_up(): a squadmate not on its way somewhere it was sent). With
## none about it carries on as it was.
##
## Shooting (_wants_to_fire): while it has a live `attack_target`, a shot
## every SHOT_GAP_S once the rifle points at the target. It holds fire
## (`holding_fire`) while any other square stands in the line of fire,
## close enough to be hit allowing for its spread, and shoots as soon as the
## line clears. Friendly fire is still on: this only stops it shooting
## through someone on purpose.
##
## Standoff (_in_standoff()): with class 3 cover (scripts/cover.gd) anywhere
## on its line of fire to its target, other than a wall it's at itself
## (_shielded()), and no foe in the fight (_foes(), within STANDOFF_FOE_M) clear of such cover
## where it can see it, shooting only wastes ammo: it holds fire until it
## sees a window, a foe out of cover in sight, and switches to that one
## (_take_window()). Looked at every STANDOFF_CHECK_S. A squadmate's Fire
## order is carried out regardless (_fire_on_order()).
##
## Surprised (the subclasses decide when: an idle square that's attacked,
## hit or with a hostile round passing or landing within NEAR_MISS_M,
## _near_miss()), it runs for cover before it fights (_find_hide(),
## _tick_hide()): anything solid within HIDE_SEARCH_M that's at least a
## square wide (sandbags, crates, the dish, a landed helicopter; not the
## see-through desk), standing just off its far side from the attacker,
## somewhere nobody else is or is heading. The nearest that isn't toward
## the attacker; only if there's none, one toward it no more than
## HIDE_TOWARD_M away. Behind sandbags it fights over the top from there.
## Behind anything taller it hides, and every HIDE_S steps out sideways
## just far enough for a clear shot (PEEK_MAX_M), fires PEEK_SHOTS, and
## steps back in (and stays in to reload). Flanked (the cover no longer
## between it and the attacker for HIDE_FLANK_S) it looks for other cover.

const ARRIVE_M := 0.08           ## close enough to count as arrived
const SLOW_DOWN_M := 0.3         ## eases off over the last stretch
const STUCK_TIME_S := 2.0        ## gives up on a spot it gets no closer to for this long
const PROGRESS_M := 0.05         ## getting this much closer counts as progress
const DETOUR_SWAP_S := 0.7       ## no progress for this long: try going round the other side
const AVOID_M := 0.8             ## steers around squares closer than this that are in the way
const LOOK_DISTANCE_M := 10.0
## Seeing solid things ahead in time to go round them (_avoid_obstacles()).
const LOOK_AHEAD_M := 3.0        ## looks this far along its way for something solid
const SKIRT_M := 1.2             ## a way round must be clear at least this far
const CLEAR_RADIUS_M := 0.3      ## the room it needs: its half-diagonal (0.28) and a little
const SWERVE_DEG := [15.0, 30.0, 45.0, 60.0, 75.0, 90.0, 110.0, 130.0, 150.0]
const AVOID_EVERY_S := 0.1       ## looks again this often
const DETOUR_LIMIT_S := 8.0      ## going round something without getting closer: gives up after this long
const OBSTACLE_MASK := 1         ## crates, the station's desk and dish, helicopters (sandbags are climbed)

## Getting ammo when it's out.
const AMMO_SEARCH_M := 40.0      ## out of ammo: goes for some up to this far away
const AMMO_TOPUP_M := 12.0       ## short of ammo: picks up any this close
const AMMO_RUN_SPEED := 1.35     ## jogs there (of walking speed)
const AMMO_LOOK_S := 0.5         ## looks for some this often while out

## Firing on a target.
const SHOT_GAP_S := Vector2(0.35, 0.6)   ## between shots, picked at random each time
const LINED_UP_DEG := 4.0                ## the rifle must point this close to the target to fire
## A square whose centre is closer than this to the line of fire is in the
## way: half a square's diagonal (0.28 m, a corner turned toward the line)
## plus a margin. The spread's widening is added with distance.
const LINE_CLEAR_M := 0.35

## Standoff: holding fire at foes all dug in.
const Cover = preload("res://scripts/cover.gd")
const DUG_IN_M := 1.5            ## class 3 cover this close to a foe, between it and us, has it dug in
const STANDOFF_FOE_M := 35.0     ## foes this close count as in the fight
const STANDOFF_CHECK_S := 0.25   ## looks for a window this often

## Surprised: getting into cover and fighting from it.
enum HidePhase { GOING, HIDING, PEEKING }
const NEAR_MISS_M := 2.5         ## a hostile round passing or landing this close is an attack
const HIDE_SEARCH_M := 8.0       ## looks this far for something to get behind
const HIDE_TOWARD_M := 2.5       ## cover toward the attacker only if there's no other, and this close
const HIDE_MIN_WIDTH_M := 0.4    ## narrower than a square, it hides nobody (a lone ammo can)
const HIDE_GAP_M := 0.32         ## its middle stands this far off the cover's far side
const HIDE_ROOM_M := 0.2         ## a spot needs this much room clear of anything solid
const HIDE_COVERED_M := 1.5      ## the cover must stand this close in front of the spot
const HIDE_MASK := 1 | 4         ## solid things, and sandbags
const WALL_SPOT_M := 0.42        ## behind a sandbag wall's middle (as command.gd, enemy.gd)
const HIDE_RUN_SPEED := 1.4      ## runs for cover (of walking speed)
const HIDE_FLANK_S := 0.8        ## the cover not between it and the attacker this long: flanked
const HIDE_S := Vector2(1.0, 2.0)   ## in cover between peeks
const PEEK_STEP_M := 0.125
const PEEK_MAX_M := 1.5          ## steps out up to this far for a clear shot
const PEEK_RIFLE_M := 0.2        ## its rifle's line runs up to this far to either side of it: a peek needs a clear view from there too
const PEEK_S := 3.0              ## out at most this long
const PEEK_SHOTS := 3
const AT_SPOT_M := 0.12

## The square it's shooting at (null = none). Cleared once it dies.
var attack_target: Node2D = null
## True while it's holding fire because someone is in the way.
var holding_fire := false

## Progress toward the current destination, for spotting when it's blocked.
var _best_dist := INF
var _no_progress_s := 0.0
var _detour := 1.0   ## 1 or -1: which side _steer prefers to pass obstacles on
var _next_shot_s := 0.0
var _swerve := 0.0         ## the turn off its way it's taking to get round something (radians)
var _swerve_side := 0.0    ## 1 or -1 while going round something, the side it's committed to; 0 not
var _avoid_check_s := 0.0
var _detour_s := 0.0       ## time spent going round things without getting closer
var _squares: Array[RID] = []   ## every square, not obstacles for _blocked_by()
var _ammo: Node2D = null   ## the ammo it's going for (ammo_pickup.gd), claimed
var _ammo_look_s := 0.0
## Standoff: holding fire (as of the last look), and the next look.
var _standoff := false
var _standoff_check_s := 0.0
## Surprised: what it's taking cover behind (null: none), its spot there,
## whether it's low enough to shoot over (sandbags), and peeking out.
var _hide_cover: Node2D = null
var _hide_spot := Vector2.ZERO
var _hide_low := false
var _hide_phase := HidePhase.GOING
var _hide_flanked_s := 0.0
var _peek_spot := Vector2.ZERO
var _peek_s := 0.0
var _peek_shots_left := 0


## Whether it has a live target to shoot at (dropping one that has died).
func is_attacking() -> bool:
	if attack_target != null and (not is_instance_valid(attack_target) or attack_target.dead):
		attack_target = null
	return attack_target != null


## Starts watching progress afresh, for a new destination.
func _reset_progress() -> void:
	_best_dist = INF
	_no_progress_s = 0.0
	_detour_s = 0.0
	_detour = 1.0
	_swerve = 0.0
	_swerve_side = 0.0


## Whether it's out: nothing in the rifle and no spare with any rounds
## (never with endless spares, or while reloading).
func is_out_of_ammo() -> bool:
	return (_rifle.spare_mags >= 0 and _rifle.rounds <= 0 and not _rifle.reloading
			and _rifle.spare_rounds() <= 0)


## Whether it's short: less than a full magazine, in the rifle and spares together.
func is_short_of_ammo() -> bool:
	return (_rifle.spare_mags >= 0 and not _rifle.reloading
			and _rifle.rounds + _rifle.spare_rounds() < _rifle.mag_size)


## Going for ammo: the way to walk there (jogging), or Vector2.INF when it
## isn't (it has enough, or there's none to be had), for the subclass to
## carry on as usual. There, it takes the magazine and reloads.
func _ammo_run() -> Vector2:
	var reach := 0.0
	if is_out_of_ammo():
		reach = AMMO_SEARCH_M
	elif is_short_of_ammo() and _may_top_up():   # (given an order, it drops a top-up it was on)
		reach = AMMO_TOPUP_M
	if reach <= 0.0:
		_drop_ammo_claim()
		return Vector2.INF
	if _ammo == null or not is_instance_valid(_ammo) or _ammo.is_queued_for_deletion():
		_ammo = null
		_ammo_look_s -= get_physics_process_delta_time()
		if _ammo_look_s > 0.0:
			return Vector2.INF
		_ammo_look_s = AMMO_LOOK_S
		_ammo = _nearest_ammo(reach)
		if _ammo == null:
			return Vector2.INF
		_ammo.claimed_by = self
		_reset_progress()
	var to := _ammo.global_position - global_position
	if to.length() <= _ammo.REACH_M * World.PX_PER_M:
		_ammo.give_to(self)
		_ammo = null
		_rifle.start_reload()
		return Vector2.ZERO
	_speed_scale = AMMO_RUN_SPEED
	return _steer(to)


## Whether it's free to go and top up when it's short (not yet out). Yes by default.
func _may_top_up() -> bool:
	return true


## The nearest ammo within `reach_m` that nobody else has claimed.
func _nearest_ammo(reach_m: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach_m * World.PX_PER_M
	for pickup: Node2D in get_tree().get_nodes_in_group("ammo_pickups"):
		if is_instance_valid(pickup.claimed_by) and pickup.claimed_by != self and not pickup.claimed_by.dead:
			continue
		var d := pickup.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = pickup
	return best


func _drop_ammo_claim() -> void:
	if _ammo != null and is_instance_valid(_ammo) and _ammo.claimed_by == self:
		_ammo.claimed_by = null
	_ammo = null


func _die(point: Vector2, direction: Vector2) -> void:
	_drop_ammo_claim()
	super(point, direction)


## Which way to walk toward a point `to` away (px): round solid things ahead
## (_avoid_obstacles()), then bent around any live square that's close and
## in the way, slipping past on the side it's already offset to (unless
## that side is up on a sandbag wall and the other isn't). Without
## that a squadmate whose slot is on the far side of the player walks
## straight into the player and stops.
func _steer(to: Vector2) -> Vector2:
	var px := World.PX_PER_M
	var dir := _avoid_obstacles(to)
	var push := Vector2.ZERO
	for other: Node2D in get_tree().get_nodes_in_group("units"):
		if other == self:
			continue
		var away: Vector2 = global_position - other.global_position
		var d := away.length() / px
		if d > AVOID_M or d < 0.001:
			continue
		if (-away).dot(dir) <= 0.0:
			continue   # beside or behind us: not in the way
		var side := dir.orthogonal()
		if side.dot(away) < 0.0:
			side = -side
		side *= _detour   # flipped when this way round isn't getting anywhere
		# Not onto a sandbag wall when the other way round is clear of it:
		# past a manned row it'd climb along the top at a crawl.
		var step := side * SIZE_M * px
		if _cover_under_at(global_position + step) > 0.0 and _cover_under_at(global_position - step) == 0.0:
			side = -side
		# Grows from nothing at AVOID_M to twice the walking direction at
		# contact (two half-widths apart), so close up it mostly sidesteps.
		# A gentler push snags corner-to-corner on the other square.
		var weight := clampf((AVOID_M - d) / (AVOID_M - SIZE_M), 0.0, 1.0) * 2.0
		push += (side + away.normalized() * 0.2) * weight
	return (dir + push).normalized()


## Its way toward a point `to` away, turned to get round anything solid
## ahead. Every AVOID_EVERY_S it sweeps its body's room (CLEAR_RADIUS_M)
## up to LOOK_AHEAD_M along the straight way; if something's there it tries
## turning off further and further (SWERVE_DEG) on the side it's already
## going round by (else the side away from what's in the way), and only
## then the other side, and takes the first that's clear for SKIRT_M. It keeps to that side until the
## straight way is clear again (round the corner), so it doesn't dither, and
## tries the other side when it's getting nowhere (_is_stuck() flips it).
func _avoid_obstacles(to: Vector2) -> Vector2:
	var dir := to.normalized()
	if dir == Vector2.ZERO:
		return dir
	_avoid_check_s -= get_physics_process_delta_time()
	if _avoid_check_s > 0.0:
		return dir.rotated(_swerve)
	_avoid_check_s = AVOID_EVERY_S
	_squares.clear()   # (squares are left to _steer())
	for unit: Node in get_tree().get_nodes_in_group("units"):
		_squares.append(unit.get_rid())
	_squares.append(get_rid())
	var px := World.PX_PER_M
	var goal := global_position + to
	var ahead := minf(LOOK_AHEAD_M * px, to.length())
	var blocker := _blocked_by(dir, ahead, goal)
	if blocker == Vector2.INF:
		_swerve = 0.0
		_swerve_side = 0.0
		return dir
	if _swerve_side == 0.0:
		# Round the side away from what's in the way.
		_swerve_side = -1.0 if dir.cross(blocker - global_position) > 0.0 else 1.0
	var skirt := minf(SKIRT_M * px, to.length())
	for side: float in [_swerve_side, -_swerve_side]:   # its own side first, however far it has to turn
		for deg: float in SWERVE_DEG:
			var turn := deg_to_rad(deg) * side
			if _blocked_by(dir.rotated(turn), skirt, goal) == Vector2.INF:
				_swerve = turn
				_swerve_side = side
				return dir.rotated(turn)
	return dir.rotated(_swerve)   # boxed in: keep on as it was (the stuck check takes over)


## Where it would first run into something solid (world), going `length` px
## along `dir`; Vector2.INF if it wouldn't. Squares don't count (_steer()
## handles those), nor what `goal` is at or in (what it's walking up to: a
## crate), nor what it's already against, unless it would be walking into it.
func _blocked_by(dir: Vector2, length: float, goal: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var room := CircleShape2D.new()
	room.radius = CLEAR_RADIUS_M * World.PX_PER_M
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = room
	query.collision_mask = OBSTACLE_MASK
	query.transform = Transform2D(0.0, global_position)
	var skip := _squares.duplicate()
	query.exclude = skip
	var against := space.get_rest_info(query)
	if not against.is_empty():
		if dir.dot(against.normal) < -0.2 and not _at_goal(against.rid, goal):
			return against.point   # into what it's against
		skip.append(against.rid)
		query.exclude = skip
	query.motion = dir * length
	var free := space.cast_motion(query)
	if free[0] >= 1.0:
		return Vector2.INF
	query.transform = Transform2D(0.0, global_position + dir * length * free[1])
	var hit := space.get_rest_info(query)
	if hit.is_empty() or _at_goal(hit.rid, goal):
		return Vector2.INF
	return hit.point


## Whether the solid thing `rid` is where it's going: `goal` is in it, or
## too close to it to stand at without touching it.
func _at_goal(rid: RID, goal: Vector2) -> bool:
	var room := CircleShape2D.new()
	room.radius = CLEAR_RADIUS_M * World.PX_PER_M
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = room
	query.collision_mask = OBSTACLE_MASK
	query.transform = Transform2D(0.0, goal)
	return get_world_2d().direct_space_state.intersect_shape(query, 8).any(func(found): return found.rid == rid)


## Which way to walk (0..1 of walking speed) to reach `point`; calls
## _arrive() once there, or once it gives up getting any closer.
func _walk_to(point: Vector2, speed_fraction: float) -> Vector2:
	var px := World.PX_PER_M
	var to := point - global_position
	if to.length() < ARRIVE_M * px or _is_stuck(to.length()):
		_arrive()
		return Vector2.ZERO
	var ease_off := clampf(to.length() / (SLOW_DOWN_M * px), 0.3, 1.0)
	return _steer(to) * speed_fraction * ease_off


## Got where _walk_to() was taking it (or gave up). Subclasses decide what next.
func _arrive() -> void:
	_detour = 1.0


## Watches progress toward the destination (`dist` px away). Every
## DETOUR_SWAP_S without getting closer it tries passing obstacles on the
## other side; after STUCK_TIME_S it gives up. Judging by progress rather
## than speed catches being pinned while still jiggling about, e.g. wedged
## between the player and another squadmate. Walking round something solid
## (_avoid_obstacles()) often takes it no closer for a while, so while it's
## doing that and moving freely the clock stands still (up to
## DETOUR_LIMIT_S).
func _is_stuck(dist: float) -> bool:
	if dist < _best_dist - PROGRESS_M * World.PX_PER_M:
		_best_dist = dist
		_no_progress_s = 0.0
		_detour_s = 0.0
		return false
	if (_swerve_side != 0.0 and _detour_s < DETOUR_LIMIT_S
			and velocity.length() > 0.5 * speed_mps * World.PX_PER_M):
		_detour_s += get_physics_process_delta_time()
		return false
	var before := _no_progress_s
	_no_progress_s += get_physics_process_delta_time()
	if floorf(_no_progress_s / DETOUR_SWAP_S) > floorf(before / DETOUR_SWAP_S):
		_detour = -_detour
		_swerve_side = -_swerve_side
	return _no_progress_s > STUCK_TIME_S


## While attacking: a shot every SHOT_GAP_S, but only once the rifle points
## at the target (it may have to turn round first), and never through
## someone. Subclasses can add their own conditions (_ready_to_fire()).
func _wants_to_fire() -> bool:
	_next_shot_s -= get_physics_process_delta_time()
	holding_fire = is_attacking() and _line_blocked()
	var standoff := is_attacking() and _in_standoff()   # every tick: it watches for a window
	if not is_attacking() or holding_fire or standoff or _next_shot_s > 0.0 or not _ready_to_fire():
		return false
	if _is_surprised() and not _may_fire_hidden():
		return false
	var to_target: float = (attack_target.global_position - _rifle.global_position).angle()
	if absf(angle_difference(_rifle.aim, to_target)) > deg_to_rad(LINED_UP_DEG):
		return false
	_next_shot_s = _next_shot_gap()
	if _is_surprised() and _hide_phase == HidePhase.PEEKING:
		_peek_shots_left -= 1
	return true


## How far off its target is: past the rifle's solid line its shots stray
## more (subclasses' _shot_spread_deg()) and may go into the ground.
func _shot_distance_m() -> float:
	if not is_attacking():
		return 0.0
	return _rifle.muzzle_position().distance_to(attack_target.global_position) / World.PX_PER_M


## Extra say over firing this tick (e.g. an enemy still reacting). Yes by default.
func _ready_to_fire() -> bool:
	return true


## How long until the next shot.
func _next_shot_gap() -> float:
	return randf_range(SHOT_GAP_S.x, SHOT_GAP_S.y)


## Whether a live square other than itself and the target stands between
## its rifle and the target, close enough to the line to be hit: within
## LINE_CLEAR_M plus however far its spread has opened out by then.
func _line_blocked() -> bool:
	return _blocks_line(_rifle.global_position, attack_target.global_position, [self, attack_target])


## Whether nothing solid but squares lies between `from` and `to`: squares
## don't block the view (they're seen past), stations and helicopters do.
## Low cover (sandbags) blocks it unless the viewer is at the cover (its
## proximity box), or `past_cover`: looking for someone to shoot, it's
## enough to see over cover a bullet can sometimes get over
## (lets_bullet_through()), so whoever's behind it still gets shot at.
## With `seen_over`, cover whoever's at `to` is manning (they're in its box)
## doesn't hide them either: they're looking over the top, so they show
## (spotting someone, enemy.gd _check_intruders(): two sides each dug in
## behind a wall see each other).
func _clear_view(from: Vector2, to: Vector2, past_cover := false, seen_over := false) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	var skip: Array[RID] = []
	for i in 6:   # look past up to a few squares on the way
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		# Squares don't block the view, nor does cover it's standing at
		# (sandbags.gd in_zone(): it looks over the top), nor something it
		# sees past (partial_cover.gd sees_through(): the station's desk).
		var over_cover: bool = ((hit.collider.has_method("in_zone") and (past_cover
				or hit.collider.in_zone(from) or (seen_over and hit.collider.in_zone(to))))
				or (hit.collider.has_method("sees_through") and hit.collider.sees_through()))
		if not hit.collider.has_method("take_hit") and not over_cover:
			return false
		skip.append(hit.rid)
	return true


## Whether `other` is on the other side (fine to hit). Subclasses say who;
## by default nobody, so everyone counts as in the way.
func _is_hostile(_other: Node) -> bool:
	return false


## Whether any live square that isn't hostile (and isn't in `ignore`) stands
## close enough to the line from `from` to `to` that a shot along it could
## hit it.
func _blocks_line(from: Vector2, to: Vector2, ignore: Array) -> bool:
	var px := World.PX_PER_M
	var line := to - from
	var length := line.length()
	if length < 1.0:
		return false
	var dir := line / length
	var spread := tan(deg_to_rad(maxf(_shot_spread_deg(), 1.0)))
	for other: Node2D in get_tree().get_nodes_in_group("units"):
		if other in ignore or _is_hostile(other):
			continue
		var rel := other.global_position - from
		var along := rel.dot(dir)
		if along <= 0.0 or along >= length:
			continue   # behind the rifle or past the target
		if absf(rel.cross(dir)) < (LINE_CLEAR_M + along / px * spread) * px:
			return true
	return false


# -------------------------------------------------------------- standoff --

## Whether to hold fire: its target dug in and no window on any foe (see
## the top). On a window it switches to that foe and fires.
func _in_standoff() -> bool:
	_standoff_check_s -= get_physics_process_delta_time()
	if _standoff_check_s > 0.0:
		return _standoff
	_standoff_check_s = STANDOFF_CHECK_S
	_standoff = false
	if _fire_on_order() or not _shielded(attack_target):
		return false
	var window: Node2D = null
	var best_d := STANDOFF_FOE_M * World.PX_PER_M
	for foe: Node2D in _foes():
		var d := global_position.distance_to(foe.global_position)
		if d < best_d and not _shielded(foe) and _clear_view(global_position, foe.global_position, true):
			best_d = d
			window = foe
	if window != null:
		_take_window(window)
	else:
		_standoff = true
	return _standoff


## Whether class 3 cover (scripts/cover.gd) stands anywhere on the line from
## its muzzle to `foe` (Mike, 2026-11-01: any wall on the line protects,
## however far behind it the foe is). A sandbag wall it's at doesn't count:
## its shots go over that one (sandbags.gd lets_bullet_through(), as the
## bullets judge it).
func _shielded(foe: Node2D) -> bool:
	var from: Vector2 = _rifle.muzzle_position()
	var space := get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(from, foe.global_position, HIDE_MASK, _unit_rids())
	for i in 6:   # past cover it shoots over, and anything light
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			return false
		var over: bool = hit.collider.has_method("in_zone") and hit.collider.in_zone(from)
		if not over and Cover.class_of(hit.collider) == Cover.HEAVY:
			return true
		ray.exclude = ray.exclude + [hit.rid]
	return false


## Whether class 3 cover (scripts/cover.gd) stands between `foe` and it,
## within DUG_IN_M of the foe (its cover, not ours). For being pinned
## (squadmate.gd); the standoff goes by _shielded().
func _dug_in(foe: Node2D) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(foe.global_position, global_position, HIDE_MASK, _unit_rids())
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return (not hit.is_empty() and Cover.class_of(hit.collider) == Cover.HEAVY
			and foe.global_position.distance_to(hit.position) <= DUG_IN_M * World.PX_PER_M)


## The live foes in the fight, for the standoff (the subclasses' own). None by default.
func _foes() -> Array[Node]:
	return []


## A window on `foe`: shoot at it instead (the subclasses may do more).
func _take_window(foe: Node2D) -> void:
	attack_target = foe


## Whether its target was given by an order, to be shot regardless. No by default.
func _fire_on_order() -> bool:
	return false


# ------------------------------------------------------------- surprised --

## Whether it's surprised: running for cover or fighting from it (the
## subclasses' own state). No by default.
func _is_surprised() -> bool:
	return false


## Whether it's pinned down (squadmate.gd): keeping its head down in cover.
func _is_pinned() -> bool:
	return false


## A hostile round that's passed, or is on its way to pass, within
## NEAR_MISS_M of it (by it, or into the ground or cover close by), or null.
## Judged on the round's whole path, from its last step to where it'll go
## into the ground (or its range), so a shot at it counts the moment it's
## fired, before the bang (enemy.gd _check_shots()) wakes it some other way.
func _near_miss() -> Node2D:
	var reach := NEAR_MISS_M * World.PX_PER_M
	var step := get_physics_process_delta_time()
	for bullet: Node2D in get_tree().get_nodes_in_group("bullets"):
		var shooter = bullet.shooter
		if shooter == self or (is_instance_valid(shooter) and not _is_hostile(shooter)):
			continue
		var dir: Vector2 = bullet.velocity.normalized()
		var from: Vector2 = bullet.global_position - bullet.velocity * step
		var to: Vector2 = bullet.global_position + bullet.velocity * bullet.LIFETIME_S
		if bullet.ground_at_m != INF:
			var ground: Vector2 = bullet.origin + dir * bullet.ground_at_m * World.PX_PER_M
			if (ground - from).dot(dir) < (to - from).dot(dir):
				to = ground
		var closest := Geometry2D.get_closest_point_to_segment(global_position, from, to)
		if closest.distance_to(global_position) <= reach:
			return bullet
	return null


## Looks for cover from an attacker at `foe` (see the top): sets
## `_hide_cover` and its spot and returns true, or false if there's none.
func _find_hide(foe: Vector2) -> bool:
	var px := World.PX_PER_M
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var reach := CircleShape2D.new()
	reach.radius = HIDE_SEARCH_M * px
	query.shape = reach
	query.collision_mask = HIDE_MASK
	query.transform = Transform2D(0.0, global_position)
	query.exclude = _unit_rids()
	var from_foe := global_position.distance_to(foe)
	var away := {}
	var toward := {}
	var seen := {}
	for found in space.intersect_shape(query, 64):
		var cover: Node2D = found.collider
		if seen.has(cover) or not _can_hide_behind(cover):
			continue
		seen[cover] = true
		var spot := _hide_spot_at(cover, foe)
		if spot == Vector2.INF or not _hide_spot_ok(spot, cover, foe):
			continue
		var d := spot.distance_to(global_position)
		var is_toward := spot.distance_to(foe) < from_foe
		if is_toward and d > HIDE_TOWARD_M * px:
			continue   # toward the attacker, and not right here
		var pick: Dictionary = toward if is_toward else away
		if pick.is_empty() or d < pick.d:
			pick.merge({cover = cover, spot = spot, d = d}, true)
	var best := away if not away.is_empty() else toward
	if best.is_empty():
		_hide_cover = null
		return false
	_hide_cover = best.cover
	_hide_spot = best.spot
	_hide_low = _hide_cover.has_method("in_zone")
	_hide_phase = HidePhase.GOING
	_hide_flanked_s = 0.0
	_reset_progress()
	return true


## Whether `cover` can be got behind: solid (not a square), standing, and
## not see-through (the desk hides nobody).
func _can_hide_behind(cover: Node2D) -> bool:
	if cover == null or not is_instance_valid(cover) or cover.is_queued_for_deletion() or cover.has_method("take_hit"):
		return false
	if cover.has_method("sees_through") and cover.sees_through():
		return false
	if cover.has_method("in_zone") and (not cover.built or cover.is_collapsed()):
		return false
	return true


## Where to stand behind `cover`, away from `foe`: just behind a sandbag
## wall's middle on the far side, or just off anything else's far side
## (INF if it's narrower than a square across the line from `foe`).
func _hide_spot_at(cover: Node2D, foe: Vector2) -> Vector2:
	var px := World.PX_PER_M
	if cover.has_method("in_zone"):
		var across := Vector2.from_angle(cover.global_rotation + PI / 2)
		if across.dot(cover.global_position - foe) < 0.0:
			across = -across
		return cover.global_position + across * WALL_SPOT_M * px
	var corners := _footprint(cover)
	if corners.is_empty():
		return Vector2.INF
	var mid := Vector2.ZERO
	for corner in corners:
		mid += corner
	mid /= corners.size()
	var out := (mid - foe).normalized()
	var side := out.orthogonal()
	var far := -INF
	var lo := INF
	var hi := -INF
	for corner in corners:
		far = maxf(far, (corner - mid).dot(out))
		lo = minf(lo, (corner - mid).dot(side))
		hi = maxf(hi, (corner - mid).dot(side))
	if hi - lo < HIDE_MIN_WIDTH_M * px:
		return Vector2.INF
	return mid + out * (far + HIDE_GAP_M * px)


## The corners of `cover`'s collision shapes, in the world.
func _footprint(cover: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not cover is CollisionObject2D:
		return points
	for owner_id in cover.get_shape_owners():
		if cover.is_shape_owner_disabled(owner_id):
			continue
		var xf: Transform2D = cover.global_transform * cover.shape_owner_get_transform(owner_id)
		for i in cover.shape_owner_get_shape_count(owner_id):
			var r: Rect2 = cover.shape_owner_get_shape(owner_id, i).get_rect()
			for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				points.append(xf * corner)
	return points


## Whether `spot` will do: on the field, room to stand, nobody on it or
## going there, and `cover` the first thing between it and `foe`, close by.
func _hide_spot_ok(spot: Vector2, cover: Node2D, foe: Vector2) -> bool:
	var px := World.PX_PER_M
	if not World.ARENA.grow(-SIZE_M * px).has_point(spot) or _hide_taken(spot):
		return false
	var space := get_world_2d().direct_space_state
	var room := CircleShape2D.new()
	room.radius = HIDE_ROOM_M * px
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = room
	query.collision_mask = HIDE_MASK
	query.transform = Transform2D(0.0, spot)
	query.exclude = _unit_rids()
	if not space.intersect_shape(query, 1).is_empty():
		return false
	return _hide_covers(spot, cover, foe)


## Whether `cover` is the first thing solid between `spot` and `foe`, close in front.
func _hide_covers(spot: Vector2, cover: Node2D, foe: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(spot, foe, HIDE_MASK, _unit_rids())
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return (not hit.is_empty() and hit.collider == cover
			and spot.distance_to(hit.position) <= HIDE_COVERED_M * World.PX_PER_M)


## Whether another square stands on `spot`, or a surprised or pinned one is heading for it.
func _hide_taken(spot: Vector2) -> bool:
	var near := 0.4 * World.PX_PER_M
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if unit == self or unit.dead:
			continue
		if unit.global_position.distance_to(spot) < near:
			return true
		if (unit.has_method("_is_surprised") and (unit._is_surprised() or unit._is_pinned())
				and unit._hide_cover != null and unit._hide_spot.distance_to(spot) < near):
			return true
	return false


func _unit_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for unit: Node in get_tree().get_nodes_in_group("units"):
		rids.append(unit.get_rid())
	return rids


## Surprised, each tick: run to the cover spot, then hold it. From sandbags
## it fights over the top; from anything taller it peeks out to fire. `foe`
## is where its attacker is now (INF: nobody to fight; it just stays in).
## Sets `_hide_cover` to null when the cover's gone and there's no other,
## or it's flanked with nowhere else to go: the subclass decides what next.
func _tick_hide(foe: Vector2, delta: float) -> Vector2:
	var px := World.PX_PER_M
	if not _can_hide_behind(_hide_cover):
		if foe == Vector2.INF or not _find_hide(foe):
			_hide_cover = null
			return Vector2.ZERO
	if foe != Vector2.INF and _hide_phase != HidePhase.GOING and not _hide_covers(_hide_spot, _hide_cover, foe):
		_hide_flanked_s += delta
		if _hide_flanked_s >= HIDE_FLANK_S and not _find_hide(foe):
			_hide_cover = null
			return Vector2.ZERO
	else:
		_hide_flanked_s = 0.0
	var goal := _hide_spot
	match _hide_phase:
		HidePhase.GOING:
			var dist := global_position.distance_to(_hide_spot)
			if dist < AT_SPOT_M * px or _is_stuck(dist):
				_hide_phase = HidePhase.HIDING
				_peek_s = randf_range(0.3, HIDE_S.x)   # a quick first look
			else:
				_speed_scale = HIDE_RUN_SPEED
		HidePhase.HIDING:
			_peek_s -= delta
			if not _hide_low and foe != Vector2.INF and _peek_s <= 0.0 and not _rifle.reloading:
				_peek_s = randf_range(HIDE_S.x, HIDE_S.y)
				var peek := _peek_spot_for(foe)
				if peek != Vector2.INF:
					_peek_spot = peek
					_hide_phase = HidePhase.PEEKING
					_peek_s = PEEK_S
					_peek_shots_left = PEEK_SHOTS
		HidePhase.PEEKING:
			_peek_s -= delta
			goal = _peek_spot
			if _peek_s <= 0.0 or _peek_shots_left <= 0 or _rifle.reloading or foe == Vector2.INF:
				_hide_phase = HidePhase.HIDING
				_peek_s = randf_range(HIDE_S.x, HIDE_S.y)
				goal = _hide_spot
	var to := goal - global_position
	if to.length() < ARRIVE_M * px:
		return Vector2.ZERO
	return _steer(to) * clampf(to.length() / (SLOW_DOWN_M * px), 0.3, 1.0)


## The nearest place beside its cover spot, stepping out sideways either
## way, with room to stand and a clear view of `foe` from it and PEEK_RIFLE_M
## to either side (where its rifle is); INF if none within PEEK_MAX_M.
func _peek_spot_for(foe: Vector2) -> Vector2:
	var px := World.PX_PER_M
	var side := (foe - _hide_spot).normalized().orthogonal()
	var space := get_world_2d().direct_space_state
	var room := CircleShape2D.new()
	room.radius = HIDE_ROOM_M * px
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = room
	query.collision_mask = HIDE_MASK
	query.exclude = _unit_rids()
	var step := PEEK_STEP_M
	while step <= PEEK_MAX_M:
		for way: float in [1.0, -1.0]:
			var spot := _hide_spot + side * way * step * px
			query.transform = Transform2D(0.0, spot)
			var rifle_side := side * PEEK_RIFLE_M * px   # the muzzle's off to one side: no shooting into the cover's edge
			if (space.intersect_shape(query, 1).is_empty() and _clear_view(spot, foe, true)
					and _clear_view(spot + rifle_side, foe, true) and _clear_view(spot - rifle_side, foe, true)):
				return spot
		step += PEEK_STEP_M
	return Vector2.INF


## Surprised: it fires only from its spot behind sandbags (over them), or
## stepped out from taller cover; not while running there or tucked in.
func _may_fire_hidden() -> bool:
	match _hide_phase:
		HidePhase.GOING:
			return false
		HidePhase.HIDING:
			return _hide_low
	return global_position.distance_to(_peek_spot) < AT_SPOT_M * World.PX_PER_M
