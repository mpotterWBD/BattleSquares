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
## SHOT_SPREAD_DEG, holding fire while anyone is in the way (ai_soldier.gd).
##
## It also returns fire on its own: with nothing to shoot, it picks the
## alerted enemy (scripts/enemy.gd) that last hit it, or else the nearest
## alerted enemy it can see within RETURN_FIRE_M. Stop puts it on
## `hold_fire`: no returning fire until its next Fire order, or until it's
## hit itself.

enum State { IDLE, SHUFFLE, MOVE, FOLLOW, ATTENTION }

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


## Fall in at `spot` and stand at attention there, facing `face_angle`
## (radians), until the next order.
func order_attention(spot: Vector2, face_angle: float) -> void:
	_start_walk(spot, State.ATTENTION)
	follow_mode = ""
	_attention_facing = face_angle


## Shoot `target` until it dies or Stop. Takes a moment to bring the rifle up.
func order_attack(target: Node2D) -> void:
	attack_target = target
	hold_fire = false
	_next_shot_s = randf_range(0.1, SHOT_GAP_S.x)


## Cease fire, and don't return fire on its own until told to Fire again
## (or it's hit).
func order_stop_firing() -> void:
	attack_target = null
	hold_fire = true


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


func _start_walk(point: Vector2, walk_state: State) -> void:
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
	return SHOT_SPREAD_DEG


func _arrive() -> void:
	super()
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


## The enemy is fair game: they don't count as in the way of a shot.
func _is_hostile(other: Node) -> bool:
	return other.is_in_group("enemies")


## Returning fire: with nothing to shoot and not told to hold, it picks the
## nearest alerted enemy it can see within RETURN_FIRE_M. Checked every
## RETURN_FIRE_CHECK_S rather than every tick.
func _look_for_return_fire() -> void:
	_return_fire_in -= get_physics_process_delta_time()
	if _return_fire_in > 0.0 or hold_fire or is_attacking():
		return
	_return_fire_in = RETURN_FIRE_CHECK_S
	var best: Node2D = null
	var best_d := RETURN_FIRE_M * World.PX_PER_M
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if not enemy.alerted:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_d and _clear_view(global_position, enemy.global_position):
			best_d = d
			best = enemy
	if best:
		order_attack(best)
