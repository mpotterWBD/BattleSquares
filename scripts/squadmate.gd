extends "res://scripts/soldier.gd"
## A squadmate: the same square as the player (scripts/soldier.gd), run by
## simple AI.
##
## Idle, it stands at its post, every few seconds either glancing somewhere
## new or shuffling a step or two, never straying more than SHUFFLE_RADIUS_M.
## Given a move order (by scripts/command.gd) it walks there facing where
## it's going, and takes up a new post on arrival.
##
## Ordered to "follow" (Follow me) or "lead" (Lead), it keeps station in a
## formation slot behind or in front of the player, lined up along the
## player's formation_heading, in one of two shapes (follow_shape):
##   "column": two abreast, rows ROW_GAP_M apart
##   "line":   everyone side by side in a single row, FILE_GAP_M apart
## It jogs to catch up when out of position, and in position looks the way
## the player faces. command.gd hands out the slots (follow_slot/follow_count).
##
## While the player is in command mode (holding Space) and it's inside the
## player's voice cone, it turns to face the player, listening, even while
## walking somewhere. Outside the cone it can't hear and carries on.

enum State { IDLE, SHUFFLE, MOVE, FOLLOW }

const ARRIVE_M := 0.08           ## close enough to count as arrived
const SLOW_DOWN_M := 0.3         ## eases off over the last stretch
const SHUFFLE_RADIUS_M := 0.25   ## how far idle shuffling strays from the post
const SHUFFLE_SPEED := 0.35      ## fraction of walking speed when shuffling
const STUCK_TIME_S := 2.0        ## gives up on a spot it gets no closer to for this long
const PROGRESS_M := 0.05         ## getting this much closer counts as progress
const DETOUR_SWAP_S := 0.7       ## no progress for this long: try going round the other side
const LOOK_DISTANCE_M := 10.0

## Formation slots, in metres from the player along its formation heading.
const FOLLOW_FIRST_ROW_M := 0.9  ## first row behind the player (Follow me)
const LEAD_FIRST_ROW_M := 1.2    ## first row ahead of the player (Lead), clear of the muzzle
const ROW_GAP_M := 0.7
const FILE_GAP_M := 0.9          ## side-to-side gap between the pair in a row
const IN_SLOT_M := 0.12          ## close enough to its slot to stand still
const JOG_FROM_M := 1.0          ## further than this from its slot, it jogs
const JOG_SPEED := 1.4           ## jogging speed, as a multiple of walking speed
const AVOID_M := 0.8             ## steers around squares closer than this that are in the way

@export var idle_min_s := 1.5    ## shortest pause between idle glances/shuffles
@export var idle_max_s := 5.0    ## longest pause

## Set by command mode; shown as a ring while Space is held.
var selected := false
var state := State.IDLE
## Where it's walking to (meaningful while state isn't IDLE).
var destination := Vector2.ZERO
## In FOLLOW: "follow" (behind the player) or "lead" (in front), its slot
## number and how many share that formation. Set by command.gd.
var follow_mode := ""
var follow_shape := "column"   ## "column" or "line"
var follow_slot := 0
var follow_count := 1

var _post := Vector2.ZERO
var _look_angle := 0.0
var _next_idle_s := 0.0
var _listening := false
## Progress toward the current destination, for spotting when it's blocked.
var _best_dist := INF
var _no_progress_s := 0.0
var _detour := 1.0   ## 1 or -1: which side _steer prefers to pass obstacles on


func _ready() -> void:
	super()
	add_to_group("squad")
	_post = global_position
	_look_angle = facing
	_next_idle_s = randf_range(idle_min_s, idle_max_s)


## Walk to `point` and stand there.
func order_move(point: Vector2) -> void:
	_start_walk(point, State.MOVE)
	follow_mode = ""


## Keep station behind ("follow") or in front of ("lead") the player, in a
## "column" or a "line".
func order_follow(mode: String, shape := "column") -> void:
	state = State.FOLLOW
	follow_mode = mode
	follow_shape = shape


func is_moving() -> bool:
	return state == State.MOVE


func _start_walk(point: Vector2, walk_state: State) -> void:
	destination = point
	state = walk_state
	_best_dist = INF
	_no_progress_s = 0.0
	_detour = 1.0


func is_following(mode: String) -> bool:
	return state == State.FOLLOW and follow_mode == mode


func _move_intent() -> Vector2:
	_speed_scale = 1.0
	match state:
		State.MOVE:
			return _walk_to(destination, 1.0)
		State.SHUFFLE:
			return _walk_to(destination, SHUFFLE_SPEED)
		State.FOLLOW:
			return _keep_station()
	_tick_idle()
	return Vector2.ZERO


## Heads for its formation slot: jogs when well out of position, eases in
## as it gets close, and stands still once there.
func _keep_station() -> Vector2:
	var px := World.PX_PER_M
	var to := _slot_position() - global_position
	var dist := to.length() / px
	if dist < IN_SLOT_M:
		return Vector2.ZERO
	if dist > JOG_FROM_M:
		_speed_scale = JOG_SPEED
	return _steer(to.normalized()) * clampf(dist / (SLOW_DOWN_M * 2.0), 0.0, 1.0)


## Bends a walking direction around any square (player or squadmate) that's
## close and in the way, slipping past on the side it's already offset to.
## Without this a squadmate whose slot is on the far side of the player walks
## straight into the player and stops.
func _steer(dir: Vector2) -> Vector2:
	var px := World.PX_PER_M
	var push := Vector2.ZERO
	var others := get_tree().get_nodes_in_group("squad") + get_tree().get_nodes_in_group("player")
	for other in others:
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


## Its slot in the formation, in world coordinates.
func _slot_position() -> Vector2:
	var leader = _leader()
	if leader == null:
		return global_position
	var row := 0
	var side := 0.0
	if follow_shape == "line":
		side = (follow_slot - (follow_count - 1) / 2.0) * FILE_GAP_M
	else:
		row = follow_slot / 2
		var in_row := mini(2, follow_count - row * 2)
		side = 0.0 if in_row == 1 else (-0.5 if follow_slot % 2 == 0 else 0.5) * FILE_GAP_M
	var ahead := LEAD_FIRST_ROW_M + row * ROW_GAP_M
	if follow_mode == "follow":
		ahead = -(FOLLOW_FIRST_ROW_M + row * ROW_GAP_M)
	# Local x points along the heading, local y to the player's right.
	var offset := Vector2(ahead, side).rotated(leader.formation_heading) * World.PX_PER_M
	var area := World.ARENA.grow(-SIZE_M * World.PX_PER_M)
	return (leader.global_position + offset).clamp(area.position, area.end)


func _leader():
	return get_tree().get_first_node_in_group("player")   # player.gd


## Faces the player while it can hear command mode; otherwise looks where
## it's walking on a move order, keeps the player's heading in formation, or
## looks around when idle.
func _aim_point() -> Vector2:
	var leader = _leader()
	if World.commanding():
		# Turn to the player only when hearing its voice; over the radio
		# there's nobody to look at.
		if leader and leader.hears_voice(global_position):
			_listening = true
			return leader.global_position
	if _listening:
		# Command mode just ended: carry on from where it's facing now.
		_listening = false
		_look_angle = facing
	var px := World.PX_PER_M
	if state == State.MOVE:
		var to := destination - global_position
		if to.length() > SLOW_DOWN_M * px:
			return global_position + to.normalized() * LOOK_DISTANCE_M * px
	if state == State.FOLLOW and leader:
		var to_slot := _slot_position() - global_position
		if to_slot.length() > 0.5 * px:
			return global_position + to_slot.normalized() * LOOK_DISTANCE_M * px
		_look_angle = leader.formation_heading
	return global_position + Vector2.from_angle(_look_angle) * LOOK_DISTANCE_M * px


func _walk_to(point: Vector2, speed_fraction: float) -> Vector2:
	var px := World.PX_PER_M
	var to := point - global_position
	if to.length() < ARRIVE_M * px or _is_stuck(to.length()):
		_arrive()
		return Vector2.ZERO
	var ease_off := clampf(to.length() / (SLOW_DOWN_M * px), 0.3, 1.0)
	return _steer(to.normalized()) * speed_fraction * ease_off


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


func _arrive() -> void:
	if state == State.MOVE:
		_post = global_position
		_look_angle = facing   # keep looking the way it came
	state = State.IDLE
	_detour = 1.0
	_next_idle_s = randf_range(idle_min_s, idle_max_s)


func _tick_idle() -> void:
	_next_idle_s -= get_physics_process_delta_time()
	if _next_idle_s > 0.0:
		return
	_next_idle_s = randf_range(idle_min_s, idle_max_s)
	var px := World.PX_PER_M
	if randf() < 0.35:
		# Shuffle a step or two, staying near the post.
		var spot := _post + Vector2.from_angle(randf() * TAU) * randf_range(0.08, SHUFFLE_RADIUS_M) * px
		var area := World.ARENA.grow(-SIZE_M * px)
		_start_walk(spot.clamp(area.position, area.end), State.SHUFFLE)
	else:
		# Glance somewhere new: usually a modest turn, now and then over the shoulder.
		_look_angle = facing + randf_range(-1.0, 1.0) * (PI * 0.75 if randf() < 0.2 else PI / 3)
