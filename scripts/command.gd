extends Node2D
## Command mode: hold Space to give your squad orders, RTS style.
##
## Holding Space, the player speaks: its command circle shows round it (its
## voice carries that far all round, see can_hear() in scripts/player.gd)
## and "talk waves" ripple out from it. Only squadmates inside the circle
## hear: they turn to listen (scripts/squadmate.gd) and only they can be
## commanded.
##
## While Space is held:
##   - drag with the left mouse button to box-select squadmates in the
##     circle (a drag that boxes nobody counts as a click where it started,
##     so a shaky click still works)
##   - click a squadmate in the circle to select just that one (Shift-click
##     adds/removes)
##   - with squadmates selected, left click (or right click) the ground
##     anywhere to send them there, spread out side by side
##   - or click an order in the ORDERS menu left of the player. It goes to
##     the selection, or with nobody selected to everyone who can hear.
##     Follow me / Lead (held, then a shape chosen from a pop-out) form them
##     up behind or in front of the player, keeping station as it moves
##     (scripts/squadmate.gd); Attention (held, then a shape) calls them to
##     fall in: the next left click picks where (a preview of their spots
##     follows the mouse; the scroll wheel turns it, 15 degrees a notch on a
##     fixed grid (0, 15, 30 ... degrees), so it can face exactly along the
##     world's edges;
##     right click cancels), and they form up there in a line or a column,
##     facing the player unless turned, and stand still; Disperse breaks
##     them out of formation.
##     Fire and Stop (orange) are fighting orders: Fire arms everyone the
##     order reaches, then the next left click picks the target (any live
##     square but the player and the shooters; right click cancels), and
##     they shoot it until it dies. Stop makes them cease fire. While
##     commanding, an orange line runs from each shooter to its target
##     (dashed while it's holding fire because someone is in the way).
##   - or deploy equipment from the DEPLOY menu right of the player: hold
##     Equipment, choose an item from the pop-out, and a see-through ghost
##     follows the mouse. Click to place it; it must go within the player's
##     deploy reach (player.gd `deploy_reach_m`, a brighter ring while
##     placing; the ghost turns red outside it). The scroll wheel turns it,
##     15 degrees a notch on the same fixed grid as Attention, so it can
##     line up with the world's edges. Items laid in rows (sandbags, with a
##     `line_px`) snap onto the free end of one already down, and holding
##     the button and dragging lays a row of them, one ghost each, put down
##     on release (as many as fit and as are carried; red ones out of reach
##     or on top of another are skipped). Right click cancels. The
##     player carries a limited number of each (player.gd `deployables`).
## The circle limits who hears and can be selected, not where they can go.
## Anyone who leaves the circle drops out of the selection (they can't hear
## further orders), and the selection is cleared whenever Space is pressed
## or released. The player keeps walking with WASD but stops aiming and
## firing. Selected squadmates are ringed, with lines to where they're
## heading; a ping marks each order.
##
## Squadmates are found through the "squad" group and the player through
## the "player" group.

const World = preload("res://scripts/world.gd")

const DRAG_THRESHOLD_PX := 8.0   ## mouse travel (screen px) that makes a click a drag
const PICK_RADIUS_M := 0.24      ## a click this close to a squadmate's centre picks it (about its body)
const SPACING_M := 0.7           ## gap between squadmates sent to the same spot
const RING_RADIUS_M := 0.34
const PING_TIME_S := 0.6
const COLOR := World.COMMAND_COLOR
const REFUSE_COLOR := Color(1.0, 0.4, 0.35)
const FIRE_COLOR := World.FIRE_COLOR
const TARGET_PICK_M := 0.3       ## a click this close to a square's centre targets it
const TARGET_RING_M := 0.38

## The orders menu beside the player, top to bottom. To add an order, add an
## entry here and handle its id in _give_order(). Orders with `shapes` open
## the formation pop-out while held: slide onto a shape and let go to choose
## it (a quick click uses DEFAULT_SHAPE; letting go elsewhere cancels).
## `color` overrides the button's green (orange for fighting orders).
const ORDERS := [
	{id = "follow", text = "Follow me", shapes = true},
	{id = "lead", text = "Lead", shapes = true},
	{id = "attention", text = "Attention", shapes = true},
	{id = "disperse", text = "Disperse"},
	{id = "fire", text = "Fire", color = World.FIRE_COLOR},
	{id = "stop", text = "Stop", color = World.FIRE_COLOR},
]
## Formation shapes in the pop-out, with their icon layouts as (column, row)
## cells. Squadmate slots for each shape are in squadmate.gd _slot_position().
const SHAPES := [
	{id = "line", text = "Line", cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	{id = "column", text = "Column", cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
]
const DEFAULT_SHAPE := "column"
## Equipment that can be deployed, listed in the DEPLOY pop-out. How many
## the player has is in player.gd `deployables`, by the same id.
const DEPLOYABLES := [
	{id = "radio_station", text = "Radio station", scene = preload("res://scenes/radio_station.tscn")},
	# `line_px`: laid end to end this far apart (centre to centre): it snaps
	# onto the open ends of ones already down, and a held drag lays a row.
	{id = "sandbags", text = "Sandbags", scene = preload("res://scenes/sandbags.tscn"), line_px = 64.0},
]
const DISPERSE_STEP_M := 0.9     ## how far Disperse sends each squadmate out from the player
const DISPERSE_JITTER_DEG := 30.0   ## randomness in each one's direction, so they fan out
## Attention: rows and files are spaced as in Follow me / Lead (squadmate.gd).
## A spot picked closer to the player than this faces the way the player does.
const ATTENTION_MIN_M := 0.5
const ATTENTION_TURN_DEG := 15.0   ## how far one scroll-wheel notch turns the formation (or equipment being placed)
const FORMATIONS := ["follow", "lead"]   ## orders that put squadmates in a formation
const MENU_GAP_PX := 36.0   ## screen gap between the player's square and the menus
const MENU_PICKING_ALPHA := 0.35   ## the menus while a click on the field is wanted
const SNAP_M := 0.4   ## a row-laid item's ghost snaps onto a free end within this of the mouse
const GHOST_OK := Color(0.7, 1.0, 0.7, 0.7)       ## placement ghost within deploy reach
const GHOST_BAD := Color(1.0, 0.45, 0.45, 0.6)    ## ...and outside it

const CONE_EDGE_ALPHA := World.CONE_EDGE_ALPHA
const AURA_FILL_ALPHA := 0.08    ## the command circle's fill (the dish beam's fading fill alphas are in world.gd)
const UNLINKED_ALPHA := 0.3      ## a radio operator's (dashed) circle while out of the dish beam

## Talk waves: rings that ripple out all round the player, as its voice does.
const WAVE_EVERY_S := 0.3
const WAVE_LIFE_S := 0.7
const WAVE_FROM_M := 0.28        ## just outside the square
const WAVE_TO_M := 0.85
const WAVE_COLOR := Color(1.0, 1.0, 1.0, 0.85)


const UiStyle = preload("res://scripts/ui_style.gd")
const HoldPopout = preload("res://scripts/hold_popout.gd")
const Squadmate = preload("res://scripts/squadmate.gd")

var _dragging := false
var _drag_start := Vector2.ZERO   ## viewport coordinates
var _drag_now := Vector2.ZERO
var _pings: Array[Dictionary] = []   ## {pos: Vector2, age: float, color: Color}
var _waves: Array[float] = []        ## ages of the talk waves in flight
var _next_wave_s := 0.0
var _was_commanding := false

var _hud: CanvasLayer
var _banner: Label
var _menu: VBoxContainer
var _order_buttons: Array[Button] = []
var _deploy_menu: VBoxContainer
var _deploy_button: Button
var _ground_layer: Node2D

## Pop-outs (scripts/hold_popout.gd): formation shapes, opened for
## `_shape_order` (follow / lead), and equipment.
var _shape_popout: HoldPopout
var _shape_order := ""
var _deploy_popout: HoldPopout

## Equipment placement: the deployable being placed ("" = none), its ghosts
## (one per spot it would go down, several while dragging out a row), and
## where the mouse is in the world.
var _placing := ""
## Which way the equipment being placed is turned (radians, 0 = as built).
## Kept between placings, so a run of them can all face the same way.
var _placing_turn := 0.0
var _ghosts: Array[Node2D] = []
## Row-laid items: where the left button went down (INF = not held), and the
## free end it snapped onto there ({} if none; see _snap_slot()).
var _drag_from := Vector2.INF
var _drag_slot := {}
var _mouse_world := Vector2.ZERO

## Fire order waiting for its target: the squadmates it went to (empty =
## not picking a target).
var _arming: Array[Node] = []
## Attention order waiting for its spot: the squadmates it went to (empty =
## not picking a spot) and the shape chosen.
var _attention_units: Array[Node] = []
var _attention_shape := ""
## The way the formation will face once the scroll wheel has turned it
## (radians); NAN until then, when it faces the player.
var _attention_facing := NAN


func _ready() -> void:
	World.register_controls()
	z_index = 50   # rings, box, pings and the placement ghost above everything
	# The circles go on the ground, under the squares.
	_ground_layer = Node2D.new()
	_ground_layer.z_as_relative = false
	_ground_layer.z_index = -50
	_ground_layer.draw.connect(_draw_circles)
	add_child(_ground_layer)
	_hud = _build_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not World.commanding():
		_dragging = false
		return
	var mouse := event as InputEventMouse
	if mouse:
		_mouse_world = _to_world(mouse.position)
	var button := event as InputEventMouseButton
	if _placing != "":
		# Placing equipment: left click puts it down (row-laid items: on
		# release, after maybe dragging out a row), right click cancels, the
		# scroll wheel turns it (instead of zooming).
		if button and button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				if _item().has("line_px"):
					_drag_from = _mouse_world
					_drag_slot = _snap_slot(_mouse_world)
				else:
					_place(_layout())
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				_stop_placing()
			elif button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_placing_turn = _turned_attention(_placing_turn,
						-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
		elif button and button.button_index == MOUSE_BUTTON_LEFT and _drag_from != Vector2.INF:
			_place(_layout())
			_drag_from = Vector2.INF
			get_viewport().set_input_as_handled()
		return
	if not _arming.is_empty():
		# Picking a Fire target: left click a square, right click cancels.
		if button and button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_try_target(_to_world(button.position))
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				_arming.clear()
			get_viewport().set_input_as_handled()
		return
	if not _attention_units.is_empty():
		# Picking where to fall in: left click there, right click cancels, the
		# scroll wheel turns the formation (instead of zooming).
		if button and button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_fall_in(_to_world(button.position))
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				_attention_units.clear()
			elif button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				if is_nan(_attention_facing):
					_attention_facing = _attention_layout(_mouse_world)[2]   # from where it faces now
				_attention_facing = _turned_attention(_attention_facing,
						-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_drag_now = motion.position
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_drag_start = button.position
			_drag_now = button.position
		elif _dragging:
			_dragging = false
			_drag_now = button.position
			var a := _to_world(_drag_start)
			var b := _to_world(_drag_now)
			if _drag_now.distance_to(_drag_start) > DRAG_THRESHOLD_PX and _box_has_listener(a, b):
				_box_select(a, b, button.shift_pressed)
			else:
				# A plain click, or a slightly shaky one that boxed nobody: act
				# on the spot where the button went down.
				_click(a, button.shift_pressed)
		get_viewport().set_input_as_handled()
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		_order_move(_to_world(button.position))
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var commanding := World.commanding()
	if commanding != _was_commanding:
		_clear_selection()   # a fresh start every time Space goes down or up
		_arming.clear()
		_attention_units.clear()
		_was_commanding = commanding
	_arming = _arming.filter(func(u): return is_instance_valid(u) and not u.dead)
	_attention_units = _attention_units.filter(func(u): return is_instance_valid(u) and not u.dead)
	# Read the mouse every frame: over the menus the buttons take its motion
	# events, which used to freeze the previews there until it moved off.
	if commanding:
		_mouse_world = _to_world(get_viewport().get_mouse_position())
	if commanding:
		for unit in _selected():
			if not _hears(unit.global_position):
				unit.selected = false   # walked out of earshot
	_hud.visible = commanding
	if commanding:
		_place_menus()
		if not _arming.is_empty():
			_banner.text = "FIRE   click a target for %d to shoot   [right click] cancel" % _arming.size()
			_banner.add_theme_color_override("font_color", FIRE_COLOR)
		elif not _attention_units.is_empty():
			_banner.text = "ATTENTION   click where %d fall in (%s)   [scroll] turn   [right click] cancel" % [_attention_units.size(), _attention_shape]
			_banner.add_theme_color_override("font_color", COLOR)
		else:
			_banner.text = ("RADIO COMMAND   radio operators in the dish beam, and anyone in their circle, can hear you   [F] hang up"
					if World.radio_commanding else "COMMAND MODE   only squadmates inside your command circle can hear you")
			_banner.add_theme_color_override("font_color", COLOR)
	else:
		_shape_popout.close()
		_deploy_popout.close()
		if _placing != "":
			_stop_placing()
	if _placing != "":
		_update_ghosts()

	for ping in _pings:
		ping.age += delta
	_pings = _pings.filter(func(p): return p.age < PING_TIME_S)
	# A new wave every WAVE_EVERY_S while commanding, the first one at once.
	for i in _waves.size():
		_waves[i] += delta
	_waves = _waves.filter(func(age): return age < WAVE_LIFE_S)
	if commanding:
		_next_wave_s -= delta
		if _next_wave_s <= 0.0:
			_waves.append(0.0)
			_next_wave_s += WAVE_EVERY_S
	else:
		_next_wave_s = 0.0
	queue_redraw()
	_ground_layer.queue_redraw()


func _draw() -> void:
	var px := World.PX_PER_M
	if World.commanding():
		for unit in _selected():
			draw_arc(unit.global_position, RING_RADIUS_M * px, 0.0, TAU, 40, COLOR, 2.0, true)
			if unit.is_moving():
				draw_line(unit.global_position, unit.destination, Color(COLOR, 0.5), 1.5, true)
				draw_circle(unit.destination, 3.0, Color(COLOR, 0.8))
		if _dragging and _drag_now.distance_to(_drag_start) > DRAG_THRESHOLD_PX:
			var box := Rect2(_to_world(_drag_start), Vector2.ZERO).expand(_to_world(_drag_now))
			draw_rect(box, Color(COLOR, 0.12))
			draw_rect(box, COLOR, false, 1.5)
		_draw_fire(px)
		_draw_attention(px)
	for ping in _pings:
		var t: float = ping.age / PING_TIME_S
		draw_arc(ping.pos, (0.1 + 0.3 * t) * px, 0.0, TAU, 32, Color(ping.get("color", COLOR), 1.0 - t), 2.0, true)
	_draw_talk_waves()


## Fighting orders, while commanding: an orange line from each shooter to
## its target and a ring round each target. While picking a Fire target,
## the armed squadmates are ringed and the square under the mouse gets a
## crosshair (or the mouse a small one, when it's over nothing to shoot).
func _draw_fire(px: float) -> void:
	var targets := {}
	for unit in _squad():
		if unit.is_attacking():
			targets[unit.attack_target] = true
			var from: Vector2 = unit.global_position
			var to: Vector2 = unit.attack_target.global_position
			if unit.holding_fire:   # someone's in the way: dashed and fainter
				draw_dashed_line(from, to, Color(FIRE_COLOR, 0.3), 1.5, 8.0, true, true)
			else:
				draw_line(from, to, Color(FIRE_COLOR, 0.45), 1.5, true)
	for target: Node2D in targets:
		draw_arc(target.global_position, TARGET_RING_M * px, 0.0, TAU, 40, FIRE_COLOR, 2.0, true)
	if _arming.is_empty():
		return
	for unit in _arming:
		draw_arc(unit.global_position, RING_RADIUS_M * px, 0.0, TAU, 40, FIRE_COLOR, 2.0, true)
	var target := _target_at(_mouse_world)
	var at := target.global_position if target else _mouse_world
	var size := TARGET_RING_M * px if target else 8.0
	var color := FIRE_COLOR if target else Color(FIRE_COLOR, 0.6)
	draw_arc(at, size, 0.0, TAU, 40, color, 2.0, true)
	for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		draw_line(at + dir * size * 0.6, at + dir * size * 1.4, color, 2.0, true)


## The player's command circle, drawn by the ground-level layer while
## commanding; over the radio, each radio operator's command circle too;
## and while placing equipment, the deploy reach as a brighter ring.
func _draw_circles() -> void:
	var speaker = _speaker()
	if speaker == null or not World.commanding():
		return
	if World.radio_commanding:
		_draw_radio_circles(speaker)
	var origin: Vector2 = speaker.global_position
	var radius: float = speaker.command_circle_m() * World.PX_PER_M   # bigger over the radio
	_ground_layer.draw_circle(origin, radius, Color(COLOR, AURA_FILL_ALPHA))
	_ground_layer.draw_arc(origin, radius, 0.0, TAU, 96, Color(COLOR, CONE_EDGE_ALPHA), 1.5, true)
	if _placing != "":
		var reach: float = speaker.deploy_reach_m * World.PX_PER_M
		_ground_layer.draw_circle(origin, reach, Color(COLOR, AURA_FILL_ALPHA))
		_ground_layer.draw_arc(origin, reach, 0.0, TAU, 64, Color(COLOR, 0.8), 1.5, true)


## Radio command mode: a command circle round every radio operator. Linked
## ones (in the station's dish beam) are drawn like the player's; the rest are
## a dashed outline, out of reach until the beam covers them.
func _draw_radio_circles(speaker) -> void:
	var linked: Array[Node] = speaker.linked_radio_operators()
	var radius: float = speaker.radio_circle_m() * World.PX_PER_M
	for unit in _squad():
		if unit.kit != "radio":
			continue
		var at: Vector2 = unit.global_position
		if unit in linked:
			_ground_layer.draw_circle(at, radius, Color(COLOR, AURA_FILL_ALPHA))
			_ground_layer.draw_arc(at, radius, 0.0, TAU, 64, Color(COLOR, CONE_EDGE_ALPHA), 1.5, true)
		else:
			var dashes := 36
			for i in dashes:
				var a := TAU * i / dashes
				_ground_layer.draw_arc(at, radius, a, a + TAU / dashes * 0.55, 4, Color(COLOR, UNLINKED_ALPHA), 2.0, true)


func _draw_talk_waves() -> void:
	var speaker = _speaker()
	if speaker == null or _waves.is_empty():
		return
	var px := World.PX_PER_M
	for age in _waves:
		var t := age / WAVE_LIFE_S
		var radius := lerpf(WAVE_FROM_M, WAVE_TO_M, t) * px
		var color := Color(WAVE_COLOR, WAVE_COLOR.a * (1.0 - t))
		draw_arc(speaker.global_position, radius, 0.0, TAU, 40, color, 2.0, true)


## The player (scripts/player.gd), whose command circle limits command mode.
func _speaker():
	return get_tree().get_first_node_in_group("player")


func _hears(point: Vector2) -> bool:
	var speaker = _speaker()
	return speaker != null and speaker.can_hear(point)


## Viewport coordinates (mouse events) -> world coordinates.
func _to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


func _squad() -> Array[Node]:
	return get_tree().get_nodes_in_group("squad")


func _selected() -> Array[Node]:
	return _squad().filter(func(u): return u.selected)


func _clear_selection() -> void:
	for unit in _squad():
		unit.selected = false


func _click(point: Vector2, shift: bool) -> void:
	var hit: Node = null
	var best := PICK_RADIUS_M * World.PX_PER_M
	for unit in _squad():
		var d: float = unit.global_position.distance_to(point)
		if d < best and _hears(unit.global_position):
			best = d
			hit = unit
	if hit:
		if shift:
			hit.selected = not hit.selected
		else:
			for unit in _squad():
				unit.selected = unit == hit
	elif not _selected().is_empty():
		_order_move(point)


## Whether the box from `a` to `b` contains a squadmate that can hear.
func _box_has_listener(a: Vector2, b: Vector2) -> bool:
	var box := Rect2(a, Vector2.ZERO).expand(b)
	return _squad().any(func(u): return box.has_point(u.global_position) and _hears(u.global_position))


func _box_select(a: Vector2, b: Vector2, shift: bool) -> void:
	var box := Rect2(a, Vector2.ZERO).expand(b)
	for unit in _squad():
		if box.has_point(unit.global_position) and _hears(unit.global_position):
			unit.selected = true
		elif not shift:
			unit.selected = false


## Sends the selection to `point`, anywhere on the field, lined up side by
## side across the direction of travel (ordered so nobody has to cross over
## anyone else). The circle limits who hears the order, not where it sends them.
func _order_move(point: Vector2) -> void:
	var units := _selected()
	if units.is_empty():
		return
	var center := Vector2.ZERO
	for unit in units:
		center += unit.global_position
	center /= units.size()
	var heading := (point - center).normalized()
	if heading == Vector2.ZERO:
		heading = Vector2.UP
	var side := heading.orthogonal()
	units.sort_custom(func(u, v): return u.global_position.dot(side) < v.global_position.dot(side))
	var px := World.PX_PER_M
	var area := World.ARENA.grow(-0.3 * px)
	for i in units.size():
		var offset := (i - (units.size() - 1) / 2.0) * SPACING_M * px
		units[i].order_move((point + side * offset).clamp(area.position, area.end))
	_pings.append({pos = point, age = 0.0})
	_assign_formation_slots()   # anyone sent off leaves a gap to close up


## Who a menu order goes to: the selection if there is one, otherwise
## everyone who can hear (inside the command circle, or over the radio).
func _order_targets() -> Array[Node]:
	var units := _selected()
	if units.is_empty():
		units = _squad().filter(func(u): return _hears(u.global_position))
	return units


## Gives a menu order to _order_targets(). `shape` is the formation chosen in
## the pop-out, for orders that have one.
func _give_order(id: String, shape := DEFAULT_SHAPE) -> void:
	var units := _order_targets()
	if units.is_empty():
		return
	_arming.clear()             # a new order drops one still waiting for its click
	_attention_units.clear()
	match id:
		"follow", "lead":
			for unit in units:
				unit.order_follow(id, shape)
			# One shape per formation: anyone already in it re-forms too.
			for unit in _squad():
				if unit.is_following(id):
					unit.follow_shape = shape
			_assign_formation_slots()
		"attention":
			# The next left click picks where they fall in (_fall_in).
			_attention_units = units
			_attention_shape = shape
			_attention_facing = NAN   # faces the player until the wheel turns it
			return
		"fire":
			# Arm them; the next left click picks what they shoot (_try_target).
			_arming = units
			return
		"stop":
			for unit in units:
				unit.order_stop_firing()
		"disperse":
			# Break formation: each steps out away from the player, fanned a
			# little, and stands at ease there. The rest close up.
			var origin: Vector2 = _speaker().global_position
			var px := World.PX_PER_M
			var area := World.ARENA.grow(-0.3 * px)
			for unit in units:
				var away: Vector2 = unit.global_position - origin
				if away.length() < 1.0:
					away = Vector2.from_angle(randf() * TAU)
				away = away.normalized().rotated(deg_to_rad(randf_range(-DISPERSE_JITTER_DEG, DISPERSE_JITTER_DEG)))
				var spot: Vector2 = unit.global_position + away * DISPERSE_STEP_M * px
				unit.order_move(spot.clamp(area.position, area.end))
			_assign_formation_slots()
	for unit in units:
		_pings.append({pos = unit.global_position, age = 0.0})


## The Attention formation's facing (radians) after one scroll-wheel notch
## (`notch` 1 or -1) from `facing`; also turns equipment being placed. It steps on a fixed grid of
## ATTENTION_TURN_DEG in world angles (0, 15, 30 ... degrees), so the
## formation can line up exactly with the world's edges: from off the grid,
## the first notch goes to the next grid angle that way.
static func _turned_attention(facing: float, notch: int) -> float:
	var step := deg_to_rad(ATTENTION_TURN_DEG)
	var nearest := roundi(facing / step)
	var steps: int
	if absf(facing - nearest * step) < 0.001:
		steps = nearest + notch
	else:
		steps = floori(facing / step) + (1 if notch > 0 else 0)
	return wrapf(steps * step, -PI, PI)


## Attention: where each of _attention_units stands if they fall in with
## the front of the formation at `front`, as [units, spots, facing]. They
## face the player, unless the scroll wheel has turned the formation
## (_attention_facing). "line": one rank across. "column": two abreast, rows
## going away from the player. Places are dealt out so nobody crosses
## anybody: front rows to those nearest the front, left to right across
## each row.
func _attention_layout(front: Vector2) -> Array:
	var speaker = _speaker()
	var px := World.PX_PER_M
	var to_player: Vector2 = speaker.global_position - front
	var facing: float = (to_player.angle() if to_player.length() > ATTENTION_MIN_M * px
			else speaker.facing)
	if not is_nan(_attention_facing):
		facing = _attention_facing
	var back := -Vector2.from_angle(facing)   # rows go this way, away from the player
	var right := back.rotated(PI / 2)         # to the right as the player looks at them
	var area := World.ARENA.grow(-0.3 * px)
	var units: Array[Node] = _attention_units.duplicate()
	var n := units.size()
	var across := func(u, v): return u.global_position.dot(right) < v.global_position.dot(right)
	var spots: Array[Vector2] = []
	if _attention_shape == "line":
		units.sort_custom(across)
		for i in n:
			spots.append(front + right * (i - (n - 1) / 2.0) * Squadmate.FILE_GAP_M * px)
	else:
		units.sort_custom(func(u, v): return u.global_position.dot(back) < v.global_position.dot(back))
		for row in ceili(n / 2.0):
			var pair := units.slice(row * 2, row * 2 + 2)
			pair.sort_custom(across)
			for i in pair.size():
				units[row * 2 + i] = pair[i]
				var side := 0.0 if pair.size() == 1 else (i - 0.5) * Squadmate.FILE_GAP_M
				spots.append(front + back * row * Squadmate.ROW_GAP_M * px + right * side * px)
	for i in n:
		spots[i] = spots[i].clamp(area.position, area.end)
	return [units, spots, facing]


## Attention, second step: they fall in with the front of the formation at
## `front` (anywhere on the field) and stand there at attention.
func _fall_in(front: Vector2) -> void:
	var layout := _attention_layout(front)
	var units: Array = layout[0]
	var spots: Array = layout[1]
	for i in units.size():
		units[i].order_attention(spots[i], layout[2])
		_pings.append({pos = spots[i], age = 0.0})
	_attention_units.clear()
	_assign_formation_slots()   # anyone who left a formation leaves a gap to close up


## While picking where to fall in: each squadmate ringed, with a faint line
## to a see-through square where it would stand, following the mouse, and
## a tick on the side it will face.
func _draw_attention(px: float) -> void:
	if _attention_units.is_empty():
		return
	var layout := _attention_layout(_mouse_world)
	var units: Array = layout[0]
	var spots: Array = layout[1]
	var half: float = Squadmate.SIZE_M / 2.0 * px
	var square := Rect2(-half, -half, half * 2.0, half * 2.0)
	for i in units.size():
		var unit: Node2D = units[i]
		var spot: Vector2 = spots[i]
		draw_arc(unit.global_position, RING_RADIUS_M * px, 0.0, TAU, 40, COLOR, 2.0, true)
		draw_line(unit.global_position, spot, Color(COLOR, 0.3), 1.5, true)
		draw_set_transform(spot, layout[2])
		draw_rect(square, Color(COLOR, 0.15))
		draw_rect(square, Color(COLOR, 0.8), false, 1.5)
		draw_line(Vector2(half, 0), Vector2(half + 0.12 * px, 0), Color(COLOR, 0.8), 2.0, true)
		draw_set_transform(Vector2.ZERO)


## The live square nearest `point` that a Fire order may target: anyone in
## the "units" group except the player and the squadmates being armed.
func _target_at(point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := TARGET_PICK_M * World.PX_PER_M
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if unit.is_in_group("player") or unit in _arming:
			continue
		var d := unit.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = unit
	return best


## Picking a Fire target: a square sets the armed squadmates on it; a click
## on nothing is refused and they stay armed.
func _try_target(point: Vector2) -> void:
	var target := _target_at(point)
	if target == null:
		_pings.append({pos = point, age = 0.0, color = REFUSE_COLOR})
		return
	for unit in _arming:
		unit.order_attack(target)
	_pings.append({pos = target.global_position, age = 0.0, color = FIRE_COLOR})
	_arming.clear()


## Numbers the squadmates in each formation so nobody has to run past the
## others: for a column, nearest the player first (they take the front row);
## for a line, left to right across the player's heading.
func _assign_formation_slots() -> void:
	var speaker = _speaker()
	if speaker == null:
		return
	var origin: Vector2 = speaker.global_position
	var right := Vector2.from_angle(speaker.formation_heading + PI / 2)
	for mode in FORMATIONS:
		var members := _squad().filter(func(u): return u.is_following(mode))
		if not members.is_empty() and members[0].follow_shape == "line":
			members.sort_custom(func(u, v):
				return u.global_position.dot(right) < v.global_position.dot(right))
		else:
			members.sort_custom(func(u, v):
				return u.global_position.distance_squared_to(origin) < v.global_position.distance_squared_to(origin))
		for i in members.size():
			members[i].follow_slot = i
			members[i].follow_count = members.size()


# --------------------------------------------------------------- deploying --

## How many of a deployable the player has left.
func _carried(id: String) -> int:
	var speaker = _speaker()
	return speaker.deployables.get(id, 0) if speaker else 0


func _start_placing(id: String) -> void:
	if _carried(id) <= 0:
		return
	_placing = id
	_drag_from = Vector2.INF
	_update_ghosts()


func _stop_placing() -> void:
	_placing = ""
	_drag_from = Vector2.INF
	for ghost in _ghosts:
		ghost.queue_free()
	_ghosts.clear()


## The DEPLOYABLES entry being placed.
func _item() -> Dictionary:
	return DEPLOYABLES[DEPLOYABLES.find_custom(func(d): return d.id == _placing)]


## A see-through copy of the item being placed: just a picture, with no
## collisions (its own body included) and nothing running.
func _make_ghost() -> Node2D:
	var ghost: Node2D = _item().scene.instantiate()
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	var bodies := ghost.find_children("*", "CollisionObject2D")
	if ghost is CollisionObject2D:
		bodies.append(ghost)
	for body in bodies:
		body.collision_layer = 0
		body.collision_mask = 0
	add_child(ghost)
	return ghost


## One ghost per spot the item would go down at now, red where it can't.
func _update_ghosts() -> void:
	var spots := _layout()
	while _ghosts.size() < spots.size():
		_ghosts.append(_make_ghost())
	while _ghosts.size() > spots.size():
		_ghosts.pop_back().queue_free()
	for i in spots.size():
		_ghosts[i].position = spots[i].pos
		_ghosts[i].rotation = spots[i].turn
		_ghosts[i].modulate = GHOST_OK if _spot_ok(spots[i].pos) else GHOST_BAD


## Where the item being placed would go down, as [{pos, turn}]. One spot at
## the mouse (or the free end it snaps onto), unless the left button is
## held on a row-laid item: then a row from where it went down toward the
## mouse, one every `line_px`, as many as fit and as the player carries.
## A row started on a free end carries that wall on; otherwise it runs
## along the drag, turned on the same 15-degree grid as the scroll wheel.
func _layout() -> Array:
	var item := _item()
	var single := {pos = _mouse_world, turn = _placing_turn}
	if not item.has("line_px"):
		return [single]
	if _drag_from == Vector2.INF:
		var snap := _snap_slot(_mouse_world)
		return [snap if not snap.is_empty() else single]
	var step: float = item.line_px
	var start: Vector2 = _drag_slot.pos if not _drag_slot.is_empty() else _drag_from
	var drag := _mouse_world - start
	var dir: Vector2
	var turn: float
	if not _drag_slot.is_empty():
		dir = _drag_slot.dir
		turn = _drag_slot.turn
	elif drag.length() < step / 2.0:
		return [{pos = start, turn = _placing_turn}]
	else:
		var grid := deg_to_rad(ATTENTION_TURN_DEG)
		turn = wrapf(roundi(drag.angle() / grid) * grid, -PI, PI)
		dir = Vector2.from_angle(turn)
	var count := mini(floori(maxf(drag.dot(dir), 0.0) / step + 0.5) + 1, maxi(_carried(_placing), 1))
	var spots := []
	for i in count:
		spots.append({pos = start + dir * step * i, turn = turn})
	return spots


## The free end of a row-laid item already down nearest `at` (within
## SNAP_M), as {pos, turn, dir}: where the next one goes to carry that wall
## on, its turn, and the way the wall would carry on from there. {} if none.
func _snap_slot(at: Vector2) -> Dictionary:
	var item := _item()
	if not item.has("line_px"):
		return {}
	var best := {}
	var reach := SNAP_M * World.PX_PER_M
	for laid: Node2D in get_tree().get_nodes_in_group("deployed_" + _placing):
		var axis := Vector2.from_angle(laid.global_rotation)
		for side in [-1.0, 1.0]:
			var slot: Vector2 = laid.global_position + axis * side * item.line_px
			var d := at.distance_to(slot)
			if d < reach and not _occupied(slot):
				reach = d
				best = {pos = slot, turn = laid.global_rotation, dir = axis * side}
	return best


## Whether one of the item being placed is already down at `point`.
func _occupied(point: Vector2) -> bool:
	var item := _item()
	if not item.has("line_px"):
		return false
	for laid: Node2D in get_tree().get_nodes_in_group("deployed_" + _placing):
		if laid.global_position.distance_to(point) < item.line_px * 0.6:
			return true
	return false


## Equipment has to go down within the player's deploy reach.
func _can_place_at(point: Vector2) -> bool:
	var speaker = _speaker()
	return speaker != null and speaker.global_position.distance_to(point) <= speaker.deploy_reach_m * World.PX_PER_M


func _spot_ok(point: Vector2) -> bool:
	return _can_place_at(point) and not _occupied(point)


## Puts the item down at each spot it can go (within reach, not on top of
## another), while the player has any left; a refusal ping where it can't.
## Placing ends once anything went down.
func _place(spots: Array) -> void:
	var item := _item()
	var placed_any := false
	for spot in spots:
		if _carried(_placing) <= 0:
			break
		if not _spot_ok(spot.pos):
			_pings.append({pos = spot.pos, age = 0.0, color = REFUSE_COLOR})
			continue
		var placed: Node2D = item.scene.instantiate()
		placed.position = spot.pos
		placed.rotation = spot.turn
		placed.add_to_group("deployed_" + _placing)   # for snapping onto it
		get_parent().add_child(placed)   # into the world, beside the squares
		_speaker().deployables[_placing] = _carried(_placing) - 1
		_pings.append({pos = spot.pos, age = 0.0})
		placed_any = true
	if placed_any:
		_placing_turn = spots[0].turn   # the next one starts turned the same way
		_stop_placing()


# ------------------------------------------------------------------- menus --

## Keeps ORDERS just left of the player's square on screen and DEPLOY just
## right of it, and dims buttons that would do nothing. While a click is
## wanted on the field (an Attention spot, a Fire target, equipment), the
## menus fade and let the mouse through, so a click over them lands on the
## field instead of pressing a button.
func _place_menus() -> void:
	var picking := not _attention_units.is_empty() or not _arming.is_empty() or _placing != ""
	for menu: Control in [_menu, _deploy_menu]:
		menu.modulate.a = MENU_PICKING_ALPHA if picking else 1.0
		var controls: Array = [menu] + menu.find_children("*", "Control", true, false)
		for control: Control in controls:
			if not control.has_meta("mouse_filter_was"):
				control.set_meta("mouse_filter_was", control.mouse_filter)   # its own setting, to go back to
			control.mouse_filter = (Control.MOUSE_FILTER_IGNORE if picking
					else control.get_meta("mouse_filter_was"))
	var speaker = _speaker()
	if speaker == null:
		return
	var screen: Vector2 = get_viewport().get_canvas_transform() * speaker.global_position
	var half_square: float = 0.2 * World.PX_PER_M * get_viewport().get_canvas_transform().get_scale().x
	var view := get_viewport().get_visible_rect()
	var left := Vector2(screen.x - half_square - MENU_GAP_PX - _menu.size.x, screen.y - _menu.size.y / 2.0)
	_menu.position = left.clamp(view.position, view.end - _menu.size)
	var right := Vector2(screen.x + half_square + MENU_GAP_PX, screen.y - _deploy_menu.size.y / 2.0)
	_deploy_menu.position = right.clamp(view.position, view.end - _deploy_menu.size)
	var nobody := _order_targets().is_empty()
	for button in _order_buttons:
		button.disabled = nobody
	_deploy_button.disabled = DEPLOYABLES.all(func(d): return _carried(d.id) <= 0)


func _open_deploy_popout() -> void:
	for item in DEPLOYABLES:
		var count := _carried(item.id)
		_deploy_popout.set_option(item.id, "%s  x%d" % [item.text, count], count <= 0)
	_deploy_popout.open(_deploy_button)


func _build_hud() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.visible = false
	_banner = UiStyle.caption("", 26)
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 20
	layer.add_child(_banner)

	# ORDERS, left of the player: a column of see-through buttons.
	_menu = UiStyle.menu_column("ORDERS")
	for order in ORDERS:
		var button := UiStyle.menu_button(order.text, Vector2(170, 42), order.get("color", COLOR))
		if order.get("shapes", false):
			var id: String = order.id
			button.button_down.connect(func():
				_shape_order = id
				_shape_popout.open(button, DEFAULT_SHAPE))
		else:
			button.pressed.connect(_give_order.bind(order.id))
		_menu.add_child(button)
		_order_buttons.append(button)
	layer.add_child(_menu)

	# DEPLOY, right of the player.
	_deploy_menu = UiStyle.menu_column("DEPLOY")
	_deploy_button = UiStyle.menu_button("Equipment")
	_deploy_button.button_down.connect(_open_deploy_popout)
	_deploy_menu.add_child(_deploy_button)
	layer.add_child(_deploy_menu)

	_shape_popout = HoldPopout.new()
	_shape_popout.setup(SHAPES, _draw_shape_icon, -1.0)
	_shape_popout.chosen.connect(func(shape, _at): _give_order(_shape_order, shape))
	_deploy_popout = HoldPopout.new()
	_deploy_popout.setup(DEPLOYABLES, _draw_deploy_icon, 1.0)
	_deploy_popout.chosen.connect(func(id, at):
		_mouse_world = _to_world(at)
		_start_placing(id))
	layer.add_child(_shape_popout)
	layer.add_child(_deploy_popout)
	add_child(layer)
	_menu.reset_size()
	_deploy_menu.reset_size()
	return layer


## A formation shape's icon: little squares at its (column, row) cells.
func _draw_shape_icon(icon: Control, shape: Dictionary) -> void:
	const CELL := 7.0
	const GAP := 3.0
	var cols := 0
	var rows := 0
	for c: Vector2i in shape.cells:
		cols = maxi(cols, c.x + 1)
		rows = maxi(rows, c.y + 1)
	var size := Vector2(cols * CELL + (cols - 1) * GAP, rows * CELL + (rows - 1) * GAP)
	var origin := (icon.size - size) / 2.0
	for c: Vector2i in shape.cells:
		var square := Rect2(origin + Vector2(c) * (CELL + GAP), Vector2(CELL, CELL))
		icon.draw_rect(square, COLOR)
		icon.draw_rect(square, Color(0, 0, 0, 0.6), false, 1.0)


## A deployable's icon. The radio station: a guyed mast on a tripod with
## radio waves coming off the top.
func _draw_deploy_icon(icon: Control, item: Dictionary) -> void:
	var c := icon.size / 2.0
	if item.id == "sandbags":   # three courses of bags, staggered
		for row in 3:
			var y := c.y + 6.0 - row * 7.0
			var xs := [-9.0, 0.0, 9.0] if row % 2 == 0 else [-4.5, 4.5]
			if row == 2:
				xs = [-4.5, 4.5]
			for x in xs:
				icon.draw_rect(Rect2(c.x + x - 4.5, y - 3.0, 9.0, 6.0), Color(COLOR, 0.35))
				icon.draw_rect(Rect2(c.x + x - 4.5, y - 3.0, 9.0, 6.0), COLOR, false, 1.5)
		return
	var top := c + Vector2(-4, -12)
	var foot := c + Vector2(-4, 12)
	icon.draw_line(foot, top, COLOR, 2.0, true)                            # mast
	icon.draw_line(foot, foot + Vector2(-7, 0), COLOR, 2.0, true)          # tripod
	icon.draw_line(foot, foot + Vector2(7, 0), COLOR, 2.0, true)
	icon.draw_line(top + Vector2(0, 4), foot + Vector2(-10, 0), Color(COLOR, 0.6), 1.0, true)   # guys
	icon.draw_line(top + Vector2(0, 4), foot + Vector2(10, 0), Color(COLOR, 0.6), 1.0, true)
	for r in [5.0, 9.0]:                                                   # waves
		icon.draw_arc(top, r, -PI * 0.35, PI * 0.35, 8, COLOR, 1.5, true)
