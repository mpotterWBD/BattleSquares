extends "res://scripts/ai_soldier.gd"
## A blue enemy square (scenes/enemy.tscn): the same square and rifle as
## everyone else, run by tactical AI. It's in the "enemies" group.
##
## CALM   It stands at its post, glancing about, and leaves you alone. It
##        wakes (alert()) when the player or a squadmate walks into its
##        detection circle (`detection_radius_m`, drawn faintly on the
##        ground) where it can see them, or when someone shoots within it:
##        a bullet fired from inside it or flying through it, or a hit. An alerted
##        enemy wakes every calm enemy inside its own circle, which can
##        chain through a group.
## ENGAGE It fights the player and the squad. Every `rethink_s` it picks
##        where to stand by scoring spots around its target (_best_spot()):
##        inside its fighting range, round the target's side or back
##        (flanking: off the way the target faces), spread round the target
##        from the other enemies for crossfire, not bunched up with them, with
##        a clear view and line of fire, not too far to go, and not crossing
##        in front of the target's rifle. Whoever's already well placed
##        holds and fires while the others swing wide, so a base of fire and
##        flankers fall out of the scoring. Flankers swing round the target
##        in an arc, keeping their distance, rather than walking past it
##        (_route()). If the target aims straight at it
##        close up, it sidesteps. It fires in short bursts after a moment to
##        react, as accurately as the rifle allows at that range
##        (rifle.gd spread_at()), worse on the move, and never through
##        another enemy.
## SEARCH Out of sight of anyone for `lose_contact_s`, it goes to where it
##        last saw them and looks around for `search_s`...
## RETURN ...then walks back to its post and goes CALM again. Any shot in
##        its circle or sight of someone on the way puts it back in ENGAGE.

enum Mode { CALM, ENGAGE, SEARCH, RETURN }

const RangeRing = preload("res://scripts/enemy_ring.gd")

const THINK_S := 0.25           ## how often it looks for targets
const SPOT_RINGS := 3           ## distances tried round the target, across the fighting range
const SPOT_ANGLES := 12         ## directions tried round the target
const SPOT_KEEP_BONUS := 0.6    ## sticks with its current spot unless another is clearly better
const DODGE_COOLDOWN_S := Vector2(1.5, 2.5)
const SEARCH_LOOK_S := 1.2      ## how often it looks somewhere new while searching
const SPACING_WEIGHT := 6.0     ## how much bunching up with another enemy counts against a spot
const ARC_STEP_DEG := 35.0      ## swinging round the target, it aims this far further round at a time
const JOG_FROM_M := 3.0         ## further than this from its spot, it jogs
const JOG_SPEED := 1.35

## How far round it a shot wakes it: fired from inside this circle or
## flying through it.
@export_range(1.0, 40.0, 0.5, "suffix:m") var detection_radius_m := 10.0
## Draw the detection circle on the ground (a testing aid).
@export var show_detection := true
## How far it can see once it's awake (solid things like stations block the view).
@export_range(1.0, 60.0, 0.5, "suffix:m") var sight_m := 22.0
## The closest it likes to fight from.
@export_range(1.0, 30.0, 0.5, "suffix:m") var min_range_m := 5.0
## The furthest it likes to fight from. Keep near the rifle's accurate range
## (Rifle > Aim > Aim Accurate M) so its shots land.
@export_range(1.0, 40.0, 0.5, "suffix:m") var max_range_m := 9.0
## How often it rethinks where to stand while fighting.
@export_range(0.2, 5.0, 0.1, "suffix:s") var rethink_s := 0.8
## How long it keeps fighting with nobody in sight before it goes searching.
@export_range(0.5, 20.0, 0.5, "suffix:s") var lose_contact_s := 3.0
## How long it searches before heading back to its post.
@export_range(0.0, 60.0, 0.5, "suffix:s") var search_s := 10.0
## Shortest and longest pause before its first shot at a new target.
@export var reaction_s := Vector2(0.3, 0.6)
## Extra spread, either side, when it fires while moving.
@export_range(0.0, 20.0, 0.5, "suffix:°") var moving_spread_deg := 3.0
## Shots in a burst, and the pause between bursts.
@export_range(1, 10) var burst_shots := 3
@export_range(0.0, 5.0, 0.1, "suffix:s") var burst_pause_s := 0.9
## How far away from another enemy it tries to keep.
@export_range(0.5, 10.0, 0.5, "suffix:m") var spacing_m := 2.5
## How much it wants to get round the target's side and back (0 = doesn't care).
@export_range(0.0, 10.0, 0.5) var flank_weight := 3.0
## Sidesteps this far when its target aims straight at it close up.
@export_range(0.0, 3.0, 0.1, "suffix:m") var dodge_m := 1.2
## Which way it faces at its post, in degrees (0 = right/east, 90 = down/south).
@export_range(-180.0, 180.0, 1.0, "suffix:°") var start_facing_deg := 180.0

var mode := Mode.CALM
## True from waking until it's calm again; squadmates only shoot back at
## alerted enemies.
var alerted := false
## Who woke it or it's fighting (the player or a squadmate), and where it
## last saw anyone.
var threat: Node2D = null
var last_seen := Vector2.ZERO
## Where it's heading in a fight (world px); other enemies read it to spread out.
var tactical_spot := Vector2.ZERO

var _post := Vector2.ZERO
var _post_facing := 0.0
var _look_angle := 0.0
var _think_in := 0.0
var _rethink_in := 0.0
var _unseen_s := 0.0
var _reaction_left := 0.0
var _burst_left := 0
var _search_left := 0.0
var _search_look_in := 0.0
var _dodge_in := 0.0
var _dodge_spot := Vector2.INF
var _next_glance_s := 0.0
var _ring: Node2D


func _ready() -> void:
	super()
	add_to_group("enemies")
	facing = deg_to_rad(start_facing_deg)
	_post = global_position
	_post_facing = facing
	_look_angle = facing
	last_seen = global_position
	tactical_spot = global_position
	_next_glance_s = randf_range(2.0, 5.0)
	_ring = RangeRing.new()
	_ring.enemy = self
	add_child(_ring)


## Wakes it: `source` (whoever fired) becomes its threat; if that isn't
## known, `from` (where the shot came from) is where it looks. Then every
## calm enemy inside its own detection circle wakes too, which can chain.
func alert(source: Node2D, from := Vector2.INF) -> void:
	if dead:
		return
	if source != null and is_instance_valid(source) and not source.is_in_group("enemies"):
		if threat == null or not _alive(threat):
			threat = source
		last_seen = source.global_position
	elif from != Vector2.INF and not _alive(threat):
		last_seen = from
	if mode != Mode.ENGAGE:
		_engage()
	alerted = true
	var reach := detection_radius_m * World.PX_PER_M
	for other: Node2D in get_tree().get_nodes_in_group("enemies"):
		if other != self and not other.alerted and other.global_position.distance_to(global_position) <= reach:
			other.alert(source, last_seen)


## A hit from the other side wakes it (friendly fire from another enemy
## doesn't). The alarm goes up before the hit lands, so even a killing shot
## wakes the enemies round it.
func take_hit(point: Vector2, direction: Vector2, damage := 0.0, by: Node2D = null) -> void:
	if not dead and by != null and is_instance_valid(by) and not by.is_in_group("enemies"):
		alert(by)
	super(point, direction, damage, by)


func _is_hostile(other: Node) -> bool:
	return other.is_in_group("player") or other.is_in_group("squad")


# -------------------------------------------------------------- each tick --

func _move_intent() -> Vector2:
	var delta := get_physics_process_delta_time()
	_speed_scale = 1.0
	_check_shots()
	_think_in -= delta
	if _think_in <= 0.0 and mode == Mode.CALM:
		_think_in = THINK_S
		_check_intruders()
	if _think_in <= 0.0 and mode != Mode.CALM:
		_think_in = THINK_S
		_look_for_targets()
	match mode:
		Mode.ENGAGE:
			return _fight(delta)
		Mode.SEARCH:
			return _search(delta)
		Mode.RETURN:
			return _walk_to(_post, 1.0)
	_idle(delta)
	return Vector2.ZERO


## The player or a squadmate inside its circle, where it can see them
## (not behind a station), wakes it.
func _check_intruders() -> void:
	var reach := detection_radius_m * World.PX_PER_M
	for hostile: Node2D in _hostiles():
		if (hostile.global_position.distance_to(global_position) <= reach
				and _clear_view(global_position, hostile.global_position)):
			alert(hostile)
			return


## Any shot fired from inside its circle or flying through it, by someone
## not on its side, wakes it.
func _check_shots() -> void:
	var reach := detection_radius_m * World.PX_PER_M
	for bullet: Node2D in get_tree().get_nodes_in_group("bullets"):
		var shooter = bullet.shooter
		if shooter != null and is_instance_valid(shooter) and shooter.is_in_group("enemies"):
			continue
		if (bullet.origin.distance_to(global_position) <= reach
				or bullet.global_position.distance_to(global_position) <= reach):
			if mode == Mode.CALM or not _alive(threat):
				alert(shooter if shooter != null and is_instance_valid(shooter) else null, bullet.origin)
			return


## Awake: who can it see? Its threat if visible, otherwise the nearest
## player or squadmate in sight. Nobody for `lose_contact_s` and it searches.
func _look_for_targets() -> void:
	var best: Node2D = null
	var best_d := sight_m * World.PX_PER_M
	for hostile: Node2D in _hostiles():
		var d := global_position.distance_to(hostile.global_position)
		if d > sight_m * World.PX_PER_M or not _clear_view(global_position, hostile.global_position):
			continue
		if hostile == threat:
			d *= 0.7   # sticks with whoever it was fighting
		if d < best_d:
			best_d = d
			best = hostile
	if best:
		if best != attack_target:
			_reaction_left = randf_range(reaction_s.x, reaction_s.y)
			_burst_left = burst_shots
		attack_target = best
		threat = best
		last_seen = best.global_position
		_unseen_s = 0.0
		if mode != Mode.ENGAGE:
			_engage()
	else:
		attack_target = null
		_unseen_s += THINK_S
		if mode == Mode.ENGAGE and _unseen_s >= lose_contact_s:
			mode = Mode.SEARCH
			_search_left = search_s
			_reset_progress()


func _hostiles() -> Array[Node]:
	var all := get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("squad")
	return all.filter(func(h): return _alive(h))


func _alive(node) -> bool:
	return node != null and is_instance_valid(node) and not node.dead


func _engage() -> void:
	mode = Mode.ENGAGE
	alerted = true
	_unseen_s = 0.0
	_rethink_in = 0.0
	_think_in = 0.0


## Fighting: rethink where to stand now and then, dodge a rifle pointed
## straight at it, and walk (or jog) to its spot.
func _fight(delta: float) -> Vector2:
	var focus := attack_target.global_position if is_attacking() else last_seen
	_rethink_in -= delta
	if _rethink_in <= 0.0:
		_rethink_in = rethink_s * randf_range(0.8, 1.25)   # out of step with the others
		var spot := _best_spot(focus)
		if spot.distance_to(tactical_spot) > 0.3 * World.PX_PER_M:
			_reset_progress()
		tactical_spot = spot
	_dodge_in -= delta
	if is_attacking() and _dodge_in <= 0.0 and _aimed_at_by(attack_target):
		_dodge_in = randf_range(DODGE_COOLDOWN_S.x, DODGE_COOLDOWN_S.y)
		var across := (focus - global_position).normalized().orthogonal()
		if across.dot(tactical_spot - global_position) < 0.0:
			across = -across   # sidestep the way it was heading anyway
		var area := World.ARENA.grow(-SIZE_M * World.PX_PER_M)
		_dodge_spot = (global_position + across * dodge_m * World.PX_PER_M).clamp(area.position, area.end)
		_reset_progress()
	var goal := _route(focus, tactical_spot) if _dodge_spot == Vector2.INF else _dodge_spot
	if goal.distance_to(global_position) > JOG_FROM_M * World.PX_PER_M or _dodge_spot != Vector2.INF:
		_speed_scale = JOG_SPEED
	return _walk_to(goal, 1.0)


## Swinging round: if the straight way to `goal` would take it closer to
## `focus` than its fighting range (e.g. flanking to the far side), it heads
## for a point up to ARC_STEP_DEG further round instead, at a range inside
## its band, so it circles the target rather than walking past it. Too close
## already, that point is also further out.
func _route(focus: Vector2, goal: Vector2) -> Vector2:
	var px := World.PX_PER_M
	var way := goal - global_position
	var t := clampf((focus - global_position).dot(way) / maxf(way.length_squared(), 1.0), 0.0, 1.0)
	var nearest := (global_position + way * t).distance_to(focus)
	var from_me := global_position - focus
	if nearest >= min_range_m * px * 0.9 and from_me.length() >= min_range_m * px * 0.9:
		return goal
	var r := clampf(from_me.length(), min_range_m * px, max_range_m * px)
	var turn := angle_difference(from_me.angle(), (goal - focus).angle())
	var step := signf(turn) * minf(absf(turn), deg_to_rad(ARC_STEP_DEG))
	var area := World.ARENA.grow(-SIZE_M * px)
	return (focus + Vector2.from_angle(from_me.angle() + step) * r).clamp(area.position, area.end)


## Whether `who` is aiming straight at it from close enough to hurt.
func _aimed_at_by(who: Node2D) -> bool:
	var to_me := global_position - who.global_position
	if to_me.length() > max_range_m * 1.5 * World.PX_PER_M:
		return false
	return absf(angle_difference(who.facing, to_me.angle())) < deg_to_rad(8.0)


## Got to its spot (or gave up getting closer): a dodge is over; searching,
## it looks around; heading home, it's calm again.
func _arrive() -> void:
	super()
	_dodge_spot = Vector2.INF
	if mode == Mode.RETURN:
		mode = Mode.CALM
		alerted = false
		threat = null
		attack_target = null
		_look_angle = _post_facing


## The best place to fight `focus` from, scored over rings of spots round it.
func _best_spot(focus: Vector2) -> Vector2:
	var px := World.PX_PER_M
	var target_facing: float = attack_target.facing if is_attacking() else (global_position - focus).angle()
	var friends: Array = get_tree().get_nodes_in_group("enemies").filter(
			func(e): return e != self and e.alerted and not e.dead)
	var area := World.ARENA.grow(-SIZE_M * px)
	var best := global_position
	var best_score := -INF
	var candidates: Array[Vector2] = [global_position, tactical_spot]
	var spin := randf() * TAU / SPOT_ANGLES   # a different set of directions each time
	for ring in SPOT_RINGS:
		var r := lerpf(min_range_m, max_range_m, (ring + 0.5) / SPOT_RINGS) * px
		for k in SPOT_ANGLES:
			candidates.append(focus + Vector2.from_angle(spin + TAU * k / SPOT_ANGLES) * r)
	for spot in candidates:
		spot = spot.clamp(area.position, area.end)
		var score := _score_spot(spot, focus, target_facing, friends)
		if spot.distance_to(tactical_spot) < 0.5 * px:
			score += SPOT_KEEP_BONUS
		if score > best_score:
			best_score = score
			best = spot
	return best


func _score_spot(spot: Vector2, focus: Vector2, target_facing: float, friends: Array) -> float:
	var px := World.PX_PER_M
	var score := 0.0
	var from_target := spot - focus
	var range_m := from_target.length() / px
	# In its fighting range.
	if range_m < min_range_m:
		score -= (min_range_m - range_m) * 1.5
	elif range_m > max_range_m:
		score -= (range_m - max_range_m) * 1.0
	# Round the target's side or back: 0 in front of it, flank_weight behind.
	var off := absf(angle_difference(target_facing, from_target.angle()))
	score += flank_weight * off / PI
	# Spread round the target from the others (crossfire), and not bunched up.
	var widest := PI / 2
	for friend in friends:
		var their: Vector2 = friend.tactical_spot
		var apart := absf(angle_difference(from_target.angle(), (their - focus).angle()))
		widest = minf(widest, apart)
		# Kept apart from where it's heading and from where it is now.
		var gap := minf(spot.distance_to(their), spot.distance_to(friend.global_position)) / px
		if gap < spacing_m:
			score -= SPACING_WEIGHT * (1.0 - gap / spacing_m)
	score += 2.0 * widest / (PI / 2)
	# Not far to go, and not across the front of the target's rifle.
	score -= 0.15 * global_position.distance_to(spot) / px
	var mid := (global_position + spot) / 2.0
	for p in [mid, spot]:
		var rel: Vector2 = p - focus
		if rel.length() < max_range_m * 1.5 * px and absf(angle_difference(target_facing, rel.angle())) < deg_to_rad(25.0):
			score -= 2.0
	# Able to see and shoot it from there (the costly checks, last).
	if not _clear_view(spot, focus):
		score -= 5.0
	elif _blocks_line(spot, focus, [self, attack_target]):
		score -= 2.0
	return score


## Searching: go to where it last saw anyone and look around; give up after
## `search_s` and head back to its post.
func _search(delta: float) -> Vector2:
	_search_left -= delta
	if _search_left <= 0.0:
		mode = Mode.RETURN
		_reset_progress()
		return Vector2.ZERO
	_search_look_in -= delta
	if _search_look_in <= 0.0:
		_search_look_in = SEARCH_LOOK_S
		_look_angle = facing + randf_range(-PI * 0.6, PI * 0.6)
	if global_position.distance_to(last_seen) < 0.3 * World.PX_PER_M:
		return Vector2.ZERO
	return _walk_to(last_seen, 0.8)


func _idle(delta: float) -> void:
	_next_glance_s -= delta
	if _next_glance_s <= 0.0:
		_next_glance_s = randf_range(2.0, 5.0)
		_look_angle = _post_facing + randf_range(-PI / 3, PI / 3)


func _aim_point() -> Vector2:
	var px := World.PX_PER_M
	if is_attacking():
		return attack_target.global_position
	if mode == Mode.ENGAGE:
		return last_seen
	if mode == Mode.RETURN:
		var home := _post - global_position
		if home.length() > 0.5 * px:
			return global_position + home.normalized() * LOOK_DISTANCE_M * px
		_look_angle = _post_facing
	return global_position + Vector2.from_angle(_look_angle) * LOOK_DISTANCE_M * px


# ---------------------------------------------------------------- firing --

## Its first shot at a new target waits for it to react.
func _ready_to_fire() -> bool:
	_reaction_left -= get_physics_process_delta_time()
	return mode == Mode.ENGAGE and _reaction_left <= 0.0


## Bursts: `burst_shots` quick shots, then a pause.
func _next_shot_gap() -> float:
	_burst_left -= 1
	if _burst_left <= 0:
		_burst_left = burst_shots
		return burst_pause_s * randf_range(0.8, 1.2)
	return randf_range(SHOT_GAP_S.x, SHOT_GAP_S.y)


## As accurate as the rifle is at that range, worse on the move.
func _shot_spread_deg() -> float:
	var spread := 0.0
	if is_attacking():
		spread = _rifle.spread_at(_rifle.muzzle_position().distance_to(attack_target.global_position) / World.PX_PER_M)
	if velocity.length() > 0.3 * World.PX_PER_M:
		spread += moving_spread_deg
	return spread
