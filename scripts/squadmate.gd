extends "res://scripts/ai_soldier.gd"
## A squadmate: the same square as the player (scripts/soldier.gd), run by
## simple AI (walking, steering and fire discipline are in scripts/ai_soldier.gd).
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
## Called to Attention (order_attention()) it falls in: it goes to the spot
## command.gd picked for it in a line or column formed up in front of the
## player, and stands there facing the way it was told (toward the player),
## still: no idle glancing or shuffling, and it doesn't follow the player.
## It stays until it's given another order.
##
## While the player is in command mode (holding Space) and it's inside the
## player's command circle, it turns to face the player, listening, even while
## walking somewhere. Outside the circle it can't hear and carries on.
##
## Given a Fire order (order_attack()) it shoots `attack_target` until the
## target dies or it's told to Stop (order_stop_firing()). Firing is on top
## of whatever else it's doing: it still stands, walks or keeps formation,
## but aims at the target (even while listening) and fires every
## SHOT_GAP_S whenever its rifle is lined up, each shot straying up to
## SHOT_SPREAD_DEG plus the rifle's own spread at that range (rifle.gd
## spread_at(); far shots may also go into the ground), holding fire while anyone is in the way (ai_soldier.gd).
##
## It also returns fire on its own: with nothing to shoot, it picks the
## alerted enemy (scripts/enemy.gd) that last hit it, or else the nearest
## alerted enemy it can see within RETURN_FIRE_M. Stop puts it on
## `hold_fire`: no returning fire until its next Fire order, or until it's
## hit itself.
##
## Sent to a spot inside a sandbag wall's proximity box (a move order from
## command mode, order_move(point, true)), it takes up the defensive there
## on arrival (DEFEND): it holds that spot (stepping back to it if knocked
## off), faces out over the wall, scanning a little either side
## (DEFEND_SCAN_DEG), and shoots alerted enemies out to DEFEND_FIRE_M
## (further than RETURN_FIRE_M), over the wall. It stays until another
## order (move, Follow me, Lead, Attention, Disperse or Stop) takes it out;
## a Fire order just picks its target, and it stays in cover. It only digs
## in if it got to its spot (within DEFEND_ARRIVE_M; not if it was stopped
## short). While dug in it's on DEFEND_LAYER instead of the squares' layer,
## so others can squeeze past a manned row (the spots are a hair under two
## squares apart); bullets and sight lines still meet it (their rays check
## every layer).

enum State { IDLE, SHUFFLE, MOVE, FOLLOW, ATTENTION, DEFEND }

const SHUFFLE_RADIUS_M := 0.25   ## how far idle shuffling strays from the post
const SHUFFLE_SPEED := 0.35      ## fraction of walking speed when shuffling

## Formation slots, in metres from the player along its formation heading.
const FOLLOW_FIRST_ROW_M := 0.9  ## first row behind the player (Follow me)
const LEAD_FIRST_ROW_M := 1.2    ## first row ahead of the player (Lead), clear of the muzzle
const ROW_GAP_M := 0.7
const FILE_GAP_M := 0.9          ## side-to-side gap between the pair in a row
const IN_SLOT_M := 0.12          ## close enough to its slot to stand still
const AT_ATTENTION_M := 0.03     ## at Attention it steps in this close, so the ranks are straight
const JOG_FROM_M := 1.0          ## further than this from its slot, it jogs
const JOG_SPEED := 1.4           ## jogging speed, as a multiple of walking speed

const SHOT_SPREAD_DEG := 1.5     ## how far a shot may stray either side of the aim
const RETURN_FIRE_M := 20.0      ## shoots back at alerted enemies it can see this close
const RETURN_FIRE_CHECK_S := 0.3 ## how often it looks for someone to shoot back at
const DEFEND_FIRE_M := 30.0      ## defending behind sandbags, it engages alerted enemies this far out
const DEFEND_SCAN_DEG := 35.0    ## defending, it scans this far either side of straight out
const DEFEND_ARRIVE_M := 0.3     ## it digs in only if it got this close to its spot
const DEFEND_LAYER := 16         ## collision layer 5 while dug in: squares (mask layer 1) pass it

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
## Set by Stop: it won't return fire on its own until its next Fire order
## or until it's hit.
var hold_fire := false

var _post := Vector2.ZERO
var _look_angle := 0.0
var _next_idle_s := 0.0
var _listening := false
var _return_fire_in := 0.0
var _attention_facing := 0.0   ## which way it faces at Attention (radians)
## The sandbag wall it's taking cover behind (on its way there, or in
## DEFEND), and which way is out over it (radians).
var _cover: Node2D = null
var _defend_facing := 0.0
var _body_layer := 0          ## its usual collision layer, while dug in


func _ready() -> void:
	super()
	add_to_group("squad")
	_body_layer = collision_layer
	_post = global_position
	_look_angle = facing
	_next_idle_s = randf_range(idle_min_s, idle_max_s)


## Walk to `point` and stand there. With `take_cover`, a spot inside a
## sandbag wall's proximity box means taking up the defensive there.
func order_move(point: Vector2, take_cover := false) -> void:
	_start_walk(point, State.MOVE)
	follow_mode = ""
	_cover = _cover_at(point) if take_cover else null


## Keep station behind ("follow") or in front of ("lead") the player, in a
## "column" or a "line".
func order_follow(mode: String, shape := "column") -> void:
	_cover = null
	_dig_in(false)
	state = State.FOLLOW
	follow_mode = mode
	follow_shape = shape


## Fall in at `spot` and stand at attention there, facing `face_angle`
## (radians), until the next order.
func order_attention(spot: Vector2, face_angle: float) -> void:
	_cover = null
	_start_walk(spot, State.ATTENTION)
	follow_mode = ""
	_attention_facing = face_angle


## Shoot `target` until it dies or Stop. Takes a moment to bring the rifle up.
func order_attack(target: Node2D) -> void:
	attack_target = target
	hold_fire = false
	_next_shot_s = randf_range(0.1, SHOT_GAP_S.x)


## Cease fire, and don't return fire on its own until told to Fire again
## (or it's hit). It also stops defending: it just stands there.
func order_stop_firing() -> void:
	attack_target = null
	hold_fire = true
	if state == State.DEFEND:
		_stand_down()


## Hit by an enemy: that ends any Stop, and with nothing else to shoot it
## shoots back at whoever hit it.
func take_hit(point: Vector2, direction: Vector2, damage := 0.0, by: Node2D = null) -> void:
	super(point, direction, damage, by)
	if dead or by == null or not is_instance_valid(by) or not by.is_in_group("enemies"):
		return
	hold_fire = false
	if not is_attacking():
		order_attack(by)


func is_moving() -> bool:
	return state == State.MOVE


func is_defending() -> bool:
	return state == State.DEFEND


## Which way it looks out over its wall (radians), while defending.
func defend_facing() -> float:
	return _defend_facing


## The sandbag wall whose proximity box `point` is in, or null.
func _cover_at(point: Vector2) -> Node2D:
	for wall: Node2D in get_tree().get_nodes_in_group("deployed_sandbags"):
		if wall.in_zone(point):
			return wall
	return null


## Takes up the defensive behind `_cover`, here: faces out over it.
func _take_cover() -> void:
	state = State.DEFEND
	_dig_in(true)
	_post = global_position
	var out := Vector2.from_angle(_cover.global_rotation + PI / 2)   # the wall's across axis
	if out.dot(_cover.global_position - global_position) < 0.0:
		out = -out   # from this side, out is across the wall
	_defend_facing = out.angle()
	_look_angle = _defend_facing
	_next_idle_s = randf_range(idle_min_s, idle_max_s)


## Stops defending, staying where it is.
func _stand_down() -> void:
	_cover = null
	_dig_in(false)
	state = State.IDLE
	_post = global_position
	_next_idle_s = randf_range(idle_min_s, idle_max_s)


## Dug in (DEFEND), it's on DEFEND_LAYER so others can squeeze past; back
## on its usual layer otherwise. (Never once it's dead: that clears it.)
func _dig_in(on: bool) -> void:
	if not dead:
		collision_layer = DEFEND_LAYER if on else _body_layer


func _start_walk(point: Vector2, walk_state: State) -> void:
	_dig_in(false)
	destination = point
	state = walk_state
	_reset_progress()


func is_following(mode: String) -> bool:
	return state == State.FOLLOW and follow_mode == mode


func _move_intent() -> Vector2:
	_speed_scale = 1.0
	_look_for_return_fire()
	match state:
		State.MOVE:
			return _walk_to(destination, 1.0)
		State.SHUFFLE:
			return _walk_to(destination, SHUFFLE_SPEED)
		State.FOLLOW:
			return _head_for(_slot_position())
		State.ATTENTION:
			return _head_for(destination, AT_ATTENTION_M)
		State.DEFEND:
			if not is_instance_valid(_cover) or _cover.is_queued_for_deletion():
				_stand_down()   # the wall's gone
				return Vector2.ZERO
			_tick_scan()
			return _head_for(_post, AT_ATTENTION_M)
	_tick_idle()
	return Vector2.ZERO


## Heads for its place in a formation (its Follow me / Lead slot, or its
## Attention spot): jogs when well out of position, eases in as it gets
## close, and stands still once there.
func _head_for(spot: Vector2, close_enough := IN_SLOT_M) -> Vector2:
	var px := World.PX_PER_M
	var to := spot - global_position
	var dist := to.length() / px
	if dist < close_enough:
		return Vector2.ZERO
	if dist > JOG_FROM_M:
		_speed_scale = JOG_SPEED
	return _steer(to.normalized()) * clampf(dist / (SLOW_DOWN_M * 2.0), 0.0, 1.0)


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
	if is_attacking():
		_listening = false
		return attack_target.global_position
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
	if state == State.ATTENTION:
		var to_spot := destination - global_position
		if to_spot.length() > 0.5 * px:
			return global_position + to_spot.normalized() * LOOK_DISTANCE_M * px
		_look_angle = _attention_facing
	return global_position + Vector2.from_angle(_look_angle) * LOOK_DISTANCE_M * px


func _shot_spread_deg() -> float:
	return SHOT_SPREAD_DEG + _rifle.spread_at(_shot_distance_m())


func _arrive() -> void:
	super()
	# Defends only if it got into the wall's box (not stuck short of it).
	if (state == State.MOVE and is_instance_valid(_cover) and _cover.in_zone(global_position)
			and global_position.distance_to(destination) <= DEFEND_ARRIVE_M * World.PX_PER_M):
		_take_cover()
		return
	_cover = null
	if state == State.MOVE:
		_post = global_position
		_look_angle = facing   # keep looking the way it came
	state = State.IDLE
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


## Defending: every so often it looks a little to one side or the other of
## straight out over the wall, scanning the ground in front.
func _tick_scan() -> void:
	_next_idle_s -= get_physics_process_delta_time()
	if _next_idle_s > 0.0:
		return
	_next_idle_s = randf_range(idle_min_s, idle_max_s)
	_look_angle = _defend_facing + deg_to_rad(randf_range(-DEFEND_SCAN_DEG, DEFEND_SCAN_DEG))


## The enemy is fair game: they don't count as in the way of a shot.
func _is_hostile(other: Node) -> bool:
	return other.is_in_group("enemies")


## Returning fire: with nothing to shoot and not told to hold, it picks the
## nearest alerted enemy it can see within RETURN_FIRE_M (DEFEND_FIRE_M
## while defending). Checked every RETURN_FIRE_CHECK_S rather than every tick.
func _look_for_return_fire() -> void:
	_return_fire_in -= get_physics_process_delta_time()
	if _return_fire_in > 0.0 or hold_fire or is_attacking():
		return
	_return_fire_in = RETURN_FIRE_CHECK_S
	var best: Node2D = null
	var best_d := (DEFEND_FIRE_M if state == State.DEFEND else RETURN_FIRE_M) * World.PX_PER_M
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if not enemy.alerted:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_d and _clear_view(global_position, enemy.global_position, true):   # over sandbags too
			best_d = d
			best = enemy
	if best:
		order_attack(best)
