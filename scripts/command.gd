extends Node2D
## Command mode: hold Space to give your squad orders, RTS style.
##
## Holding Space, the player speaks: a cone opens out of its front face (its
## voice, see can_hear() in scripts/player.gd) and "talk waves" ripple
## along it, and a short circular command aura shows who's close enough to
## hear without being looked at. Only squadmates inside the cone or the aura
## hear: they turn to listen (scripts/squadmate.gd) and only they can be
## commanded.
##
## While Space is held:
##   - drag with the left mouse button to box-select squadmates in the cone
##     (a drag that boxes nobody counts as a click where it started, so a
##     shaky click still works)
##   - click a squadmate in the cone to select just that one (Shift-click
##     adds/removes)
##   - with squadmates selected, left click (or right click) the ground
##     anywhere to send them there, spread out side by side
##   - or click an order in the ORDERS menu left of the player. It goes to
##     the selection, or with nobody selected to everyone who can hear.
##     Follow me / Lead (held, then a shape chosen from a pop-out) form them
##     up behind or in front of the player, keeping station as it moves
##     (scripts/squadmate.gd); Disperse breaks them out of formation
##   - or deploy equipment from the DEPLOY menu right of the player: hold
##     Equipment, choose an item from the pop-out, and a see-through ghost
##     follows the mouse. Click to place it; it must go inside the command
##     aura (the ghost turns red outside it). Right click cancels. The
##     player carries a limited number of each (player.gd `deployables`).
## The cone limits who hears and can be selected, not where they can go.
## Anyone who leaves the cone drops out of the selection (they can't hear
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

## The orders menu beside the player, top to bottom. To add an order, add an
## entry here and handle its id in _give_order(). Orders with `shapes` open
## the formation pop-out while held: slide onto a shape and let go to choose
## it (a quick click uses DEFAULT_SHAPE; letting go elsewhere cancels).
const ORDERS := [
	{id = "follow", text = "Follow me", shapes = true},
	{id = "lead", text = "Lead", shapes = true},
	{id = "disperse", text = "Disperse"},
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
]
const DISPERSE_STEP_M := 0.9     ## how far Disperse sends each squadmate out from the player
const DISPERSE_JITTER_DEG := 30.0   ## randomness in each one's direction, so they fan out
const FORMATIONS := ["follow", "lead"]   ## orders that put squadmates in a formation
const MENU_GAP_PX := 36.0   ## screen gap between the player's square and the menus
const GHOST_OK := Color(0.7, 1.0, 0.7, 0.7)       ## placement ghost inside the aura
const GHOST_BAD := Color(1.0, 0.45, 0.45, 0.6)    ## ...and outside it

## The voice cone: brightest near the player, fading toward its far edge
## (shared with the dish beam, in world.gd).
const CONE_NEAR_ALPHA := World.CONE_NEAR_ALPHA
const CONE_FAR_ALPHA := World.CONE_FAR_ALPHA
const CONE_EDGE_ALPHA := World.CONE_EDGE_ALPHA
const AURA_FILL_ALPHA := 0.08    ## the command aura: hearable all round, up close
const UNLINKED_ALPHA := 0.3      ## a radio operator's (dashed) circle while out of the dish beam

## Talk waves: arcs that ripple out from the player's front face, as wide
## as the voice cone.
const WAVE_EVERY_S := 0.3
const WAVE_LIFE_S := 0.7
const WAVE_FROM_M := 0.28        ## just outside the front face
const WAVE_TO_M := 0.85
const WAVE_COLOR := Color(1.0, 1.0, 1.0, 0.85)


const UiStyle = preload("res://scripts/ui_style.gd")
const HoldPopout = preload("res://scripts/hold_popout.gd")

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
var _cone_layer: Node2D

## Pop-outs (scripts/hold_popout.gd): formation shapes, opened for
## `_shape_order` (follow / lead), and equipment.
var _shape_popout: HoldPopout
var _shape_order := ""
var _deploy_popout: HoldPopout

## Equipment placement: the deployable being placed ("" = none), its ghost,
## and where the mouse is in the world.
var _placing := ""
var _ghost: Node2D
var _mouse_world := Vector2.ZERO


func _ready() -> void:
	World.register_controls()
	z_index = 50   # rings, box, pings and the placement ghost above everything
	# The cone goes on the ground, under the squares.
	_cone_layer = Node2D.new()
	_cone_layer.z_as_relative = false
	_cone_layer.z_index = -50
	_cone_layer.draw.connect(_draw_cone)
	add_child(_cone_layer)
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
		# Placing equipment: left click puts it down, right click cancels.
		if button and button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_try_place()
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				_stop_placing()
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
		_was_commanding = commanding
	if commanding:
		for unit in _selected():
			if not _hears(unit.global_position):
				unit.selected = false   # walked out of earshot
	_hud.visible = commanding
	if commanding:
		_place_menus()
		_banner.text = ("RADIO COMMAND   radio operators in the dish beam, and anyone in their circle, can hear you   [F] hang up"
				if World.radio_commanding else "COMMAND MODE   only squadmates in your cone or close by can hear you")
	else:
		_shape_popout.close()
		_deploy_popout.close()
		if _placing != "":
			_stop_placing()
	if _placing != "":
		_ghost.position = _mouse_world
		_ghost.modulate = GHOST_OK if _can_place_at(_mouse_world) else GHOST_BAD

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
	_cone_layer.queue_redraw()


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
	for ping in _pings:
		var t: float = ping.age / PING_TIME_S
		draw_arc(ping.pos, (0.1 + 0.3 * t) * px, 0.0, TAU, 32, Color(ping.get("color", COLOR), 1.0 - t), 2.0, true)
	_draw_talk_waves()


## The voice cone and command aura, drawn by the ground-level layer while
## commanding, and over the radio each radio operator's command circle.
func _draw_cone() -> void:
	var speaker = _speaker()
	if speaker == null or not World.commanding():
		return
	if World.radio_commanding:
		_draw_radio_circles(speaker)
	var origin: Vector2 = speaker.global_position
	var aura: float = speaker.aura_radius_m * World.PX_PER_M
	_cone_layer.draw_circle(origin, aura, Color(COLOR, AURA_FILL_ALPHA))
	# The aura's edge is brighter while placing equipment, which must go inside it.
	var aura_edge := 0.8 if _placing != "" else CONE_EDGE_ALPHA
	_cone_layer.draw_arc(origin, aura, 0.0, TAU, 64, Color(COLOR, aura_edge), 1.5, true)
	var reach: float = speaker.voice_range_m * World.PX_PER_M
	var half := deg_to_rad(speaker.voice_half_angle_deg)
	var rim := PackedVector2Array()
	for i in 33:
		rim.append(origin + Vector2.from_angle(speaker.facing - half + 2.0 * half * i / 32.0) * reach)
	# A fan of triangles, bright at the player and fading toward the rim.
	var near := Color(COLOR, CONE_NEAR_ALPHA)
	var far := Color(COLOR, CONE_FAR_ALPHA)
	for i in rim.size() - 1:
		_cone_layer.draw_polygon(PackedVector2Array([origin, rim[i], rim[i + 1]]),
				PackedColorArray([near, far, far]))
	var edge := Color(COLOR, CONE_EDGE_ALPHA)
	_cone_layer.draw_line(origin, rim[0], edge, 1.5, true)
	_cone_layer.draw_line(origin, rim[rim.size() - 1], edge, 1.5, true)
	_cone_layer.draw_polyline(rim, edge, 1.5, true)


## Radio command mode: a command circle round every radio operator. Linked
## ones (in the station's dish beam) are drawn like the aura; the rest are
## a dashed outline, out of reach until the beam covers them.
func _draw_radio_circles(speaker) -> void:
	var linked: Array[Node] = speaker.linked_radio_operators()
	var radius: float = speaker.radio_circle_m() * World.PX_PER_M
	for unit in _squad():
		if unit.kit != "radio":
			continue
		var at: Vector2 = unit.global_position
		if unit in linked:
			_cone_layer.draw_circle(at, radius, Color(COLOR, AURA_FILL_ALPHA))
			_cone_layer.draw_arc(at, radius, 0.0, TAU, 64, Color(COLOR, CONE_EDGE_ALPHA), 1.5, true)
		else:
			var dashes := 36
			for i in dashes:
				var a := TAU * i / dashes
				_cone_layer.draw_arc(at, radius, a, a + TAU / dashes * 0.55, 4, Color(COLOR, UNLINKED_ALPHA), 2.0, true)


func _draw_talk_waves() -> void:
	var speaker = _speaker()
	if speaker == null or _waves.is_empty():
		return
	var px := World.PX_PER_M
	var spread := deg_to_rad(speaker.voice_half_angle_deg)
	for age in _waves:
		var t := age / WAVE_LIFE_S
		var radius := lerpf(WAVE_FROM_M, WAVE_TO_M, t) * px
		var color := Color(WAVE_COLOR, WAVE_COLOR.a * (1.0 - t))
		draw_arc(speaker.global_position, radius, speaker.facing - spread,
				speaker.facing + spread, 16, color, 2.0, true)


## The player (scripts/player.gd), whose voice cone limits command mode.
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
## anyone else). The cone limits who hears the order, not where it sends them.
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
## everyone who can hear (in the cone or the aura).
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
	match id:
		"follow", "lead":
			for unit in units:
				unit.order_follow(id, shape)
			# One shape per formation: anyone already in it re-forms too.
			for unit in _squad():
				if unit.is_following(id):
					unit.follow_shape = shape
			_assign_formation_slots()
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
	var item: Dictionary = DEPLOYABLES[DEPLOYABLES.find_custom(func(d): return d.id == id)]
	_ghost = item.scene.instantiate()
	# Just a picture: no collisions, nothing running.
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	for body in _ghost.find_children("*", "CollisionObject2D"):
		body.collision_layer = 0
		body.collision_mask = 0
	_ghost.position = _mouse_world
	add_child(_ghost)


func _stop_placing() -> void:
	_placing = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null


## Equipment has to go down inside the command aura.
func _can_place_at(point: Vector2) -> bool:
	var speaker = _speaker()
	return speaker != null and speaker.global_position.distance_to(point) <= speaker.aura_radius_m * World.PX_PER_M


func _try_place() -> void:
	if not _can_place_at(_mouse_world):
		_pings.append({pos = _mouse_world, age = 0.0, color = REFUSE_COLOR})
		return
	var item: Dictionary = DEPLOYABLES[DEPLOYABLES.find_custom(func(d): return d.id == _placing)]
	var placed: Node2D = item.scene.instantiate()
	placed.position = _mouse_world
	get_parent().add_child(placed)   # into the world, beside the squares
	_speaker().deployables[_placing] = _carried(_placing) - 1
	_pings.append({pos = _mouse_world, age = 0.0})
	_stop_placing()


# ------------------------------------------------------------------- menus --

## Keeps ORDERS just left of the player's square on screen and DEPLOY just
## right of it, and dims buttons that would do nothing.
func _place_menus() -> void:
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
		var button := UiStyle.menu_button(order.text)
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
func _draw_deploy_icon(icon: Control, _item: Dictionary) -> void:
	var c := icon.size / 2.0
	var top := c + Vector2(-4, -12)
	var foot := c + Vector2(-4, 12)
	icon.draw_line(foot, top, COLOR, 2.0, true)                            # mast
	icon.draw_line(foot, foot + Vector2(-7, 0), COLOR, 2.0, true)          # tripod
	icon.draw_line(foot, foot + Vector2(7, 0), COLOR, 2.0, true)
	icon.draw_line(top + Vector2(0, 4), foot + Vector2(-10, 0), Color(COLOR, 0.6), 1.0, true)   # guys
	icon.draw_line(top + Vector2(0, 4), foot + Vector2(10, 0), Color(COLOR, 0.6), 1.0, true)
	for r in [5.0, 9.0]:                                                   # waves
		icon.draw_arc(top, r, -PI * 0.35, PI * 0.35, 8, COLOR, 1.5, true)
