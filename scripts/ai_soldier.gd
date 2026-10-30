extends "res://scripts/soldier.gd"
## The shared AI body for computer-run squares (scripts/squadmate.gd for the
## player's squad, scripts/enemy.gd for the blue enemies): walking to a spot
## round other squares, noticing when it's stuck, and shooting at
## `attack_target` with fire discipline. What to walk to and what to shoot
## is up to the subclass.
##
## Walking (_walk_to): heads for a point, easing off over the last stretch,
## bending round any square in the way (_steer). If it stops getting closer
## it tries passing on the other side, and after STUCK_TIME_S gives up and
## calls _arrive() as if it had got there.
##
## Shooting (_wants_to_fire): while it has a live `attack_target`, a shot
## every SHOT_GAP_S once the rifle points at the target. It holds fire
## (`holding_fire`) while any other square stands in the line of fire,
## close enough to be hit allowing for its spread, and shoots as soon as the
## line clears. Friendly fire is still on: this only stops it shooting
## through someone on purpose.

const ARRIVE_M := 0.08           ## close enough to count as arrived
const SLOW_DOWN_M := 0.3         ## eases off over the last stretch
const STUCK_TIME_S := 2.0        ## gives up on a spot it gets no closer to for this long
const PROGRESS_M := 0.05         ## getting this much closer counts as progress
const DETOUR_SWAP_S := 0.7       ## no progress for this long: try going round the other side
const AVOID_M := 0.8             ## steers around squares closer than this that are in the way
const LOOK_DISTANCE_M := 10.0

## Firing on a target.
const SHOT_GAP_S := Vector2(0.35, 0.6)   ## between shots, picked at random each time
const LINED_UP_DEG := 4.0                ## the rifle must point this close to the target to fire
## A square whose centre is closer than this to the line of fire is in the
## way: half a square's diagonal (0.28 m, a corner turned toward the line)
## plus a margin. The spread's widening is added with distance.
const LINE_CLEAR_M := 0.35

## The square it's shooting at (null = none). Cleared once it dies.
var attack_target: Node2D = null
## True while it's holding fire because someone is in the way.
var holding_fire := false

## Progress toward the current destination, for spotting when it's blocked.
var _best_dist := INF
var _no_progress_s := 0.0
var _detour := 1.0   ## 1 or -1: which side _steer prefers to pass obstacles on
var _next_shot_s := 0.0


## Whether it has a live target to shoot at (dropping one that has died).
func is_attacking() -> bool:
	if attack_target != null and (not is_instance_valid(attack_target) or attack_target.dead):
		attack_target = null
	return attack_target != null


## Starts watching progress afresh, for a new destination.
func _reset_progress() -> void:
	_best_dist = INF
	_no_progress_s = 0.0
	_detour = 1.0


## Bends a walking direction around any live square that's close and in the
## way, slipping past on the side it's already offset to. Without this a
## squadmate whose slot is on the far side of the player walks straight into
## the player and stops.
func _steer(dir: Vector2) -> Vector2:
	var px := World.PX_PER_M
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
		# Grows from nothing at AVOID_M to twice the walking direction at
		# contact (two half-widths apart), so close up it mostly sidesteps.
		# A gentler push snags corner-to-corner on the other square.
		var weight := clampf((AVOID_M - d) / (AVOID_M - SIZE_M), 0.0, 1.0) * 2.0
		push += (side + away.normalized() * 0.2) * weight
	return (dir + push).normalized()


## Which way to walk (0..1 of walking speed) to reach `point`; calls
## _arrive() once there, or once it gives up getting any closer.
func _walk_to(point: Vector2, speed_fraction: float) -> Vector2:
	var px := World.PX_PER_M
	var to := point - global_position
	if to.length() < ARRIVE_M * px or _is_stuck(to.length()):
		_arrive()
		return Vector2.ZERO
	var ease_off := clampf(to.length() / (SLOW_DOWN_M * px), 0.3, 1.0)
	return _steer(to.normalized()) * speed_fraction * ease_off


## Got where _walk_to() was taking it (or gave up). Subclasses decide what next.
func _arrive() -> void:
	_detour = 1.0


## Watches progress toward the destination (`dist` px away). Every
## DETOUR_SWAP_S without getting closer it tries passing obstacles on the
## other side; after STUCK_TIME_S it gives up. Judging by progress rather
## than speed catches being pinned while still jiggling about, e.g. wedged
## between the player and another squadmate.
func _is_stuck(dist: float) -> bool:
	if dist < _best_dist - PROGRESS_M * World.PX_PER_M:
		_best_dist = dist
		_no_progress_s = 0.0
		return false
	var before := _no_progress_s
	_no_progress_s += get_physics_process_delta_time()
	if floorf(_no_progress_s / DETOUR_SWAP_S) > floorf(before / DETOUR_SWAP_S):
		_detour = -_detour
	return _no_progress_s > STUCK_TIME_S


## While attacking: a shot every SHOT_GAP_S, but only once the rifle points
## at the target (it may have to turn round first), and never through
## someone. Subclasses can add their own conditions (_ready_to_fire()).
func _wants_to_fire() -> bool:
	_next_shot_s -= get_physics_process_delta_time()
	holding_fire = is_attacking() and _line_blocked()
	if not is_attacking() or holding_fire or _next_shot_s > 0.0 or not _ready_to_fire():
		return false
	var to_target: float = (attack_target.global_position - _rifle.global_position).angle()
	if absf(angle_difference(_rifle.aim, to_target)) > deg_to_rad(LINED_UP_DEG):
		return false
	_next_shot_s = _next_shot_gap()
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
func _clear_view(from: Vector2, to: Vector2, past_cover := false) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	var skip: Array[RID] = []
	for i in 6:   # look past up to a few squares on the way
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		# Squares don't block the view, nor does cover it's standing at
		# (sandbags.gd in_zone(): it looks over the top).
		var over_cover: bool = hit.collider.has_method("in_zone") and (past_cover
				or hit.collider.in_zone(from))
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
