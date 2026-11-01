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
## If its wall is shot down (sandbags.gd), it moves to the nearest free spot
## behind another wall facing the same way (within RESPOT_M) and digs in
## there; with none free, it stays put on the defensive, without cover.
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

## Given a Build order (order_build(), command.gd), it builds: over and over
## it goes to the nearest supply crate (crate.gd), however far, that
## owes a part to something under construction (a radio station, a sandbag
## wall), undoes its straps if they're still on (crate.gd UNSTRAP_S; one
## unit at a time, the others wait by it), takes one, carries it to the site that needs it and puts it in,
## until nothing needs anything, then it stands where it is. It takes the
## nearest site no other carrier is already bringing a part to (so two
## don't race for one tile and the loser chase the next one along), and
## heads for the site's deliver_spot() if it has one: beside a sandbag
## tile, so it walks alongside the wall rather than climbing along its top. While
## carrying it goes at CARRY_SPEED with its rifle away (no shooting), the
## part held in front (carry_art.gd). Another order (move, Follow me, Lead,
## Attention, Disperse) stops it, and a part it's carrying goes back on its
## crate, as it does if it's killed.

## Surprised (SURPRISED): attacked while idle (hit, or an enemy round passing
## or landing within NEAR_MISS_M), it runs for cover from the attacker and
## fights from there (ai_soldier.gd _find_hide(), _tick_hide(): sandbags,
## a crate, the dish, a helicopter; the nearest not toward the attacker, or
## one toward it only a couple of metres off; over sandbags it fires from
## its spot, behind anything taller it peeks out to fire). It stays in cover
## until it's given an order, shooting back at whoever it can. With no
## cover near it just shoots back where it stands, as before.

## Pinned (PINNED): fighting on its own account (idle, defending a wall, or
## surprised) at an enemy behind class 3 cover (scripts/cover.gd: within
## DUG_IN_M of the enemy, between them, ai_soldier.gd _dug_in()), with more
## alerted enemies within PIN_ENEMY_M than the squad has live squares (squadmates and the player),
## shooting is a waste of ammo: it stops, and gets down behind cover (stays
## at its wall's spot, or tucked in behind what it's hiding behind without
## peeking, or runs for the nearest cover from the open). Checked every
## PIN_CHECK_S: once the numbers even out, its target leaves that cover or
## dies, it goes back to what it was doing (from the open, if it found cover,
## to fighting from it, SURPRISED). Any order takes it out of it, and a Fire
## order is carried out regardless (_fire_ordered: never pinned over it).

enum State { IDLE, SHUFFLE, MOVE, FOLLOW, ATTENTION, DEFEND, BUILD, SURPRISED, PINNED }

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

const PIN_CHECK_S := 1.0         ## how often it checks whether it's pinned (or still is)
const PIN_ENEMY_M := 35.0        ## alerted enemies this close count toward being outnumbered
const SHOT_SPREAD_DEG := 1.5     ## how far a shot may stray either side of the aim
const RETURN_FIRE_M := 20.0      ## shoots back at alerted enemies it can see this close
const RETURN_FIRE_CHECK_S := 0.3 ## how often it looks for someone to shoot back at
const DEFEND_FIRE_M := 30.0      ## defending behind sandbags, it engages alerted enemies this far out
const DEFEND_SCAN_DEG := 35.0    ## defending, it scans this far either side of straight out
const DEFEND_ARRIVE_M := 0.3     ## it digs in only if it got this close to its spot
const RESPOT_M := 10.0           ## its wall shot down, it looks this far for another spot
const COVER_SPOT_M := 0.42       ## a defensive spot is this far behind a wall's middle (as command.gd)
const CARRY_SPEED := 0.65        ## carrying a part, this much of walking speed (as the player)
const CarryArt = preload("res://scripts/carry_art.gd")
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
## Its target came from a Fire order (not picked by itself): it's shot even pinned.
var _fire_ordered := false
## Pinned: what it was doing before (it goes back to that), and the next check.
var _unpinned_state := State.IDLE
var _pin_check_s := 0.0

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
## Building: the part in its hands ("" for none), its crate, and where it's taking it.
var carrying := ""
var _carried_from: Node2D = null
var _build_site: Node2D = null
var _build_from: Node2D = null   ## building from just this crate (null: any)
var _carry_view: Node2D


func _ready() -> void:
	super()
	add_to_group("squad")
	_body_layer = collision_layer
	_carry_view = Node2D.new()
	_carry_view.z_index = 2
	_carry_view.visible = false
	_carry_view.draw.connect(func() -> void: CarryArt.draw(_carry_view, carrying, facing))
	add_child(_carry_view)
	_post = global_position
	_look_angle = facing
	_next_idle_s = randf_range(idle_min_s, idle_max_s)


## Walk to `point` and stand there. With `take_cover`, a spot inside a
## sandbag wall's proximity box means taking up the defensive there.
func order_move(point: Vector2, take_cover := false) -> void:
	BattleLog.order(self, "move", [point, "cover" if take_cover else ""])
	_stop_building()
	_start_walk(point, State.MOVE)
	follow_mode = ""
	_cover = _cover_at(point) if take_cover else null


## Keep station behind ("follow") or in front of ("lead") the player, in a
## "column" or a "line".
func order_follow(mode: String, shape := "column") -> void:
	BattleLog.order(self, mode, [shape])
	_stop_building()
	_cover = null
	_dig_in(false)
	state = State.FOLLOW
	follow_mode = mode
	follow_shape = shape


## Fall in at `spot` and stand at attention there, facing `face_angle`
## (radians), until the next order.
func order_attention(spot: Vector2, face_angle: float) -> void:
	BattleLog.order(self, "attention", [spot])
	_stop_building()
	_cover = null
	_start_walk(spot, State.ATTENTION)
	follow_mode = ""
	_attention_facing = face_angle


## Shoot `target` until it dies or Stop. Takes a moment to bring the rifle up.
## `ordered`: a Fire order from the player (command.gd), which it carries out
## even pinned; false when it picks a target itself (shooting back).
func order_attack(target: Node2D, ordered := true) -> void:
	if ordered:   # its own picks show as a change of target
		BattleLog.order(self, "fire", [target])
	attack_target = target
	_fire_ordered = ordered
	hold_fire = false
	_next_shot_s = randf_range(0.1, SHOT_GAP_S.x)
	if ordered:
		_unpin()


## Cease fire, and don't return fire on its own until told to Fire again
## (or it's hit). It also stops defending: it just stands there.
func order_stop_firing() -> void:
	BattleLog.order(self, "stop")
	_unpin()
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
	if _is_idle():
		_surprise(by, by.global_position)
	elif not is_attacking():
		order_attack(by, false)


func _is_idle() -> bool:
	return state == State.IDLE or state == State.SHUFFLE


func _is_surprised() -> bool:
	return state == State.SURPRISED


func _is_pinned() -> bool:
	return state == State.PINNED


## Attacked while idle: it shoots back at `by` (unless it was told to hold
## fire and this was only a near miss) and runs for cover from it (or from
## `from`, where the shot came from), if there's any near.
func _surprise(by: Node2D, from: Vector2) -> void:
	var alive: bool = by != null and is_instance_valid(by) and not by.dead
	if alive and not hold_fire:
		order_attack(by, false)
	if _find_hide(by.global_position if alive else from):
		state = State.SURPRISED


## Build what's under construction, fetching the parts (see above). Given
## `from` (a supply crate: the player clicked it with this one selected), it
## only takes parts from that crate, and stops once that crate owes nothing.
func order_build(from: Node2D = null) -> void:
	BattleLog.order(self, "build", [from])
	_build_from = from
	_cover = null
	_dig_in(false)
	follow_mode = ""
	state = State.BUILD
	_reset_progress()


## Short of ammo, it only tops up when it isn't walking somewhere it was
## sent, holding a wall, or building (out of ammo, it goes anyway:
## ai_soldier.gd).
func _may_top_up() -> bool:
	return not state in [State.MOVE, State.DEFEND, State.BUILD, State.SURPRISED, State.PINNED]


func is_building() -> bool:
	return state == State.BUILD


## Off building: a part in its hands goes back on its crate.
func _stop_building() -> void:
	if carrying != "" and is_instance_valid(_carried_from):
		_carried_from.return_part(carrying)
	carrying = ""
	_carried_from = null
	_build_site = null
	_build_from = null
	if state == State.BUILD:
		state = State.IDLE
		_post = global_position


func _die(point: Vector2, direction: Vector2) -> void:
	_stop_building()
	_carry_view.visible = false
	super(point, direction)


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


## Its wall's been shot down (sandbags.gd): it makes for the nearest free
## spot behind another wall facing the same way, within RESPOT_M, to dig in
## there; with none, it stays where it is, still on the defensive (no cover now).
func _cover_lost() -> void:
	_cover = null
	var spot := _free_cover_spot()
	if spot != Vector2.INF:
		order_move(spot, true)
	else:
		_dig_in(false)   # nothing to squeeze past now


## The nearest free defensive spot behind a standing wall that faces out the
## way it was facing (within RESPOT_M), or INF.
func _free_cover_spot() -> Vector2:
	var px := World.PX_PER_M
	var out := Vector2.from_angle(_defend_facing)
	var best := Vector2.INF
	var best_d := RESPOT_M * px
	for wall: Node2D in get_tree().get_nodes_in_group("deployed_sandbags"):
		if not wall.built or wall.is_collapsed():
			continue
		var across := Vector2.from_angle(wall.global_rotation + PI / 2)
		if absf(across.dot(out)) < 0.5:
			continue   # turned the wrong way to face out the same way
		var toward := across if across.dot(out) > 0.0 else -across
		var spot: Vector2 = wall.global_position - toward * COVER_SPOT_M * px   # behind it, looking out over it
		var d := spot.distance_to(global_position)
		if d < best_d and not _spot_taken(spot):
			best_d = d
			best = spot
	return best


## Whether another square is on `spot`, or a squadmate's on its way to it or holding it.
func _spot_taken(spot: Vector2) -> bool:
	var near := 0.35 * World.PX_PER_M
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if unit == self or unit.dead:
			continue
		if unit.global_position.distance_to(spot) < near:
			return true
		if unit.has_method("is_moving") and unit.is_moving() and unit.destination.distance_to(spot) < near:
			return true
	return false


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
	# Hands full: the part in front of it, its rifle away.
	_rifle.visible = carrying == ""
	get_node("Shadows/RifleShadow").visible = _rifle.visible
	_carry_view.visible = carrying != ""
	if _carry_view.visible:
		_carry_view.queue_redraw()
	if _is_idle():
		var miss := _near_miss()
		if miss != null:
			_surprise(miss.shooter if is_instance_valid(miss.shooter) else null, miss.origin)
	if carrying == "":
		var run := _ammo_run()   # out of ammo: off to get some first
		if run != Vector2.INF:
			return run
	_check_pinned()
	match state:
		State.PINNED:
			return _tick_pinned()
		State.SURPRISED:
			var move := _tick_hide(attack_target.global_position if is_attacking() else Vector2.INF,
					get_physics_process_delta_time())
			if _hide_cover == null:   # no cover any more: fights where it stands
				state = State.IDLE
				_post = global_position
			return move
		State.BUILD:
			return _tick_build()
		State.MOVE:
			return _walk_to(destination, 1.0)
		State.SHUFFLE:
			return _walk_to(destination, SHUFFLE_SPEED)
		State.FOLLOW:
			return _head_for(_slot_position())
		State.ATTENTION:
			return _head_for(destination, AT_ATTENTION_M)
		State.DEFEND:
			if _cover != null and (not is_instance_valid(_cover) or _cover.is_queued_for_deletion()
					or _cover.is_collapsed()):
				_cover_lost()   # shot down: another spot, or hold here
				if state != State.DEFEND:
					return Vector2.ZERO
			_tick_scan()
			return _head_for(_post, AT_ATTENTION_M)
	_tick_idle()
	return Vector2.ZERO


## Every PIN_CHECK_S: pinned if it should be (see the top), back to what it
## was doing if it no longer should be.
func _check_pinned() -> void:
	_pin_check_s -= get_physics_process_delta_time()
	if _pin_check_s > 0.0:
		return
	_pin_check_s = PIN_CHECK_S
	var can_pin := state in [State.IDLE, State.SHUFFLE, State.DEFEND, State.SURPRISED, State.PINNED]
	var pinned := can_pin and _pinned_down()
	if pinned and state != State.PINNED:
		_unpinned_state = State.IDLE if state == State.SHUFFLE else state
		state = State.PINNED
		if _unpinned_state == State.IDLE and attack_target != null:
			_find_hide(attack_target.global_position)   # out in the open: into cover
		elif _unpinned_state == State.SURPRISED:
			_hide_phase = HidePhase.HIDING   # tucked in, no peeking
	elif not pinned and state == State.PINNED:
		_unpin()


## Whether it's pinned down: shooting on its own account at an enemy with
## heavy cover in front of it, and the enemies in the fight outnumber the squad.
func _pinned_down() -> bool:
	if _fire_ordered or not is_attacking() or not attack_target.is_in_group("enemies"):
		return false
	return _dug_in(attack_target) and _outnumbered()


## Standoff (ai_soldier.gd): the alerted enemies.
func _foes() -> Array[Node]:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.dead and e.alerted)


## Standoff: a window on `foe`, shot at as if shooting back.
## That ends being pinned too.
func _take_window(foe: Node2D) -> void:
	order_attack(foe, false)
	_unpin()


func _fire_on_order() -> bool:
	return _fire_ordered


## More alerted enemies within PIN_ENEMY_M than live squadmates and player.
func _outnumbered() -> bool:
	var reach := PIN_ENEMY_M * World.PX_PER_M
	var enemies := 0
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if not enemy.dead and enemy.alerted and enemy.global_position.distance_to(global_position) <= reach:
			enemies += 1
	var ours := 0
	for unit: Node2D in get_tree().get_nodes_in_group("squad") + get_tree().get_nodes_in_group("player"):
		if not unit.dead:
			ours += 1
	return enemies > ours


## Back to what it was doing before it was pinned: from the open, if it got
## into cover, to fighting from there.
func _unpin() -> void:
	if state != State.PINNED:
		return
	state = _unpinned_state
	if state == State.IDLE and _hide_cover != null and attack_target != null:
		state = State.SURPRISED
	if state == State.SURPRISED:
		_hide_phase = HidePhase.HIDING
		_peek_s = randf_range(0.3, HIDE_S.x)
	_post = global_position if state == State.IDLE else _post
	_pin_check_s = PIN_CHECK_S


## Pinned: down behind cover, not firing. At its wall's spot (from
## DEFEND); tucked in where it's hiding, no peeking (from SURPRISED or the
## open, if it found cover); or where it stands.
func _tick_pinned() -> Vector2:
	if _unpinned_state == State.DEFEND:
		return _head_for(_post, AT_ATTENTION_M)
	if _hide_cover != null:
		return _tick_hide(Vector2.INF, get_physics_process_delta_time())   # no attacker given: no peeking
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
	return _steer(to) * clampf(dist / (SLOW_DOWN_M * 2.0), 0.0, 1.0)


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
	if state == State.BUILD and velocity.length() > 0.3 * px:
		return global_position + velocity.normalized() * LOOK_DISTANCE_M * px   # building: looks where it's going
	if state == State.ATTENTION:
		var to_spot := destination - global_position
		if to_spot.length() > 0.5 * px:
			return global_position + to_spot.normalized() * LOOK_DISTANCE_M * px
		_look_angle = _attention_facing
	return global_position + Vector2.from_angle(_look_angle) * LOOK_DISTANCE_M * px


## No shooting with its hands full, or pinned (though it still watches for a
## window, in super()).
func _wants_to_fire() -> bool:
	var fire := super()
	return fire and carrying == "" and state != State.PINNED


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


## Building, each tick: carrying a part, take it to a site that needs it
## and put it in; otherwise fetch one from the nearest crate that owes one;
## with nothing to do, stand where it is.
func _tick_build() -> Vector2:
	var px := World.PX_PER_M
	if carrying != "":
		if not is_instance_valid(_build_site) or not _build_site.needs(carrying):
			_build_site = _site_needing(carrying)
			if _build_site == null:
				_stop_building()   # nothing needs it any more: back on the crate
				return Vector2.ZERO
		if _build_site.can_deliver_at(global_position):
			_build_site.install(carrying)
			carrying = ""
			_carried_from = null
			_build_site = null
			return Vector2.ZERO
		var spot: Vector2 = (_build_site.deliver_spot(global_position)
				if _build_site.has_method("deliver_spot") else _build_site.global_position)
		var to_site := _head_for(spot, 0.0)
		_speed_scale *= CARRY_SPEED
		return to_site
	var crate := _crate_with_work()
	if crate == null:
		_stop_building()   # all done
		return Vector2.ZERO
	if crate.strapped and crate.in_reach(self):
		# Still strapped: undo the straps first, or wait by it while
		# someone else does.
		_look_angle = (crate.global_position - global_position).angle()
		if not crate.unstrapping_by_other(self):
			crate.work_unstrap(self, get_physics_process_delta_time())
		return Vector2.ZERO
	if crate.can_take(self):
		carrying = crate.take_part()
		_carried_from = crate
		_build_site = _site_needing(carrying)
		return Vector2.ZERO
	return _head_for(crate.global_position, 0.0)


## The nearest supply crate, however far, that owes something a part (only
## the one it was sent to, if it was sent to one).
func _crate_with_work() -> Node2D:
	if _build_from != null:
		return _build_from if is_instance_valid(_build_from) and _build_from.wanted() else null
	var best: Node2D = null
	var best_d := INF
	for crate: Node2D in get_tree().get_nodes_in_group("crates"):
		if not crate.has_method("wanted") or not crate.wanted():
			continue
		var d := crate.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = crate
	return best


## Where `part` should go: a site of the crate it came from first, else the
## nearest site anywhere that needs it; one no other carrier is heading for
## if there is one.
func _site_needing(part: String) -> Node2D:
	var claimed := _sites_claimed()
	if is_instance_valid(_carried_from):
		var own: Node2D = _carried_from.site_for(part, global_position, claimed)
		if own:
			return own
	var best: Node2D = null
	var best_free := false
	for site: Node2D in get_tree().get_nodes_in_group("build_sites"):
		if not site.needs(part):
			continue
		var free: bool = not site in claimed
		if (best == null or (free and not best_free)
				or (free == best_free and site.global_position.distance_to(global_position)
					< best.global_position.distance_to(global_position))):
			best = site
			best_free = free
	return best


## The sites other squadmates are carrying parts to.
func _sites_claimed() -> Array:
	var claimed := []
	for mate: Node in get_tree().get_nodes_in_group("squad"):
		if mate != self and mate.carrying != "" and is_instance_valid(mate._build_site):
			claimed.append(mate._build_site)
	return claimed


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
	if _return_fire_in > 0.0 or hold_fire or is_attacking() or carrying != "":
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
		order_attack(best, false)
