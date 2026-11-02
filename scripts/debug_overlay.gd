extends Node2D
## Debug mode (Q toggles World.debug): each live square's battle-log number
## (battle_log.gd number_of(): the player 0, the rest 1, 2...) shown just
## above its top-right corner, green for our side, red for enemies, so Mike
## can ask about "number 4" and it matches the log. Drawn on the screen
## (a CanvasLayer) so the numbers stay readable at any zoom. Made by
## command.gd; one per level.
##
## While it's on the player takes no controls (player.gd _hands_off()) and
## command mode stays shut (World.commanding()). A left click on a square
## picks it: a ring round it and a panel beside it with its number, name,
## the rounds in its magazine and its spare magazines (rifle.gd), kept up to
## date. A click on open ground, its death, or Q again drops it.
##
## Under each number, what it's doing (_status()): its state (squadmate.gd
## State, enemy.gd Mode) in its number's colour (green ours, red enemies),
## and on the line under it short tags: ">n" the square it's shooting at, its cover phase (going / hiding /
## peeking, ai_soldier.gd), "hold" (a friend in the line of fire), "standoff"
## (foes all behind class 3 cover), "stop" (told to Stop), "ammo" (going
## for ammo) or "loading" (at an ammo can), "reload", and what it's
## carrying, and an enemy's crate job ("unstrapping", "can run"). "exposed": it's just fired
## over a sandbag wall it's at, so the wall covers it far less (sandbags.gd
## EXPOSED_STOP). The picked
## square's panel spells the same out in full. A click on a supply crate
## picks it instead: its contents, straps, the enemy working at it, and its
## `vicinity_m` drawn round it (enemy.gd CRATES). A click on a watch
## tower's deck or stair picks it: its height class and its three sections
## (watch_tower.gd), drawn round it. Each watch tower's overlook box is
## drawn in green. A click on anything else solid
## (a sandbag wall, the station's desk or dish, a helicopter, a building)
## picks that: its cover class and the share of shots it stops
## (scripts/cover.gd), as a crate's panel also shows. Enemies' detection
## circles (enemy_ring.gd) only show in debug mode.

const World = preload("res://scripts/world.gd")
const BattleLog = preload("res://scripts/battle_log.gd")
const Cover = preload("res://scripts/cover.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

const FONT_SIZE := 28
const OUTLINE := 6
const OFFSET_M := Vector2(0.2, -0.3)   ## from the square's centre, just past its top-right corner
const ENEMY_COLOR := Color(1.0, 0.4, 0.35)
const PICK_M := 0.4                    ## a click this close to a square's centre picks it
const RING_M := 0.4                    ## the picked square's ring
const PANEL_OFFSET := Vector2(48, 24)  ## the panel, from the picked square on screen (as player.gd's ammo panel)
const STATE_FONT_SIZE := 18   ## the state, then its tags, under the number
const TITLE_FONT_SIZE := 22   ## the picked thing's panel: its title, bold
const BODY_FONT_SIZE := 17    ## and the rest
const SHORT := {"ATTENTION": "ATTN", "SURPRISED": "SURPRISE"}   ## over the square (the panel has it in full)
const COVER_NAMES := ["NONE", "LIGHT", "MEDIUM", "HEAVY"]   ## by cover class (cover.gd)
const SECTION_COLORS := [Color(1.0, 0.35, 0.3), Color(1.0, 0.65, 0.25), Color(1.0, 0.9, 0.35)]   ## a watch tower's sections 1..3
const OVERLOOK_COLOR := Color(0.35, 1.0, 0.3)   ## a watch tower's overlook box

var _layer: CanvasLayer
var _view: Node2D
var _picked: Node2D = null
var _picked_at := Vector2.ZERO   ## where it was clicked (world): a picked object's ring and panel go there
var _picked_part := ""           ## a picked watch tower's part (watch_tower.gd PART_NAMES)
var _panel: PanelContainer
var _name_label: Label   ## the panel's title, bold and larger
var _body_label: Label   ## the rest: "LABEL: value" lines, then its own info


func _ready() -> void:
	World.debug = false
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_view = Node2D.new()
	_view.draw.connect(_draw_numbers)
	_layer.add_child(_view)
	_panel = UiStyle.panel()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_name_label = UiStyle.caption("", TITLE_FONT_SIZE)
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.0
	_name_label.add_theme_font_override("font", bold)
	_body_label = UiStyle.caption("", BODY_FONT_SIZE)
	column.add_child(_name_label)
	column.add_child(_body_label)
	_panel.add_child(column)
	_layer.add_child(_panel)
	_layer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug") and not event.is_echo():
		World.debug = not World.debug
		_layer.visible = World.debug
		_picked = null
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if World.debug and button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var point := get_viewport().get_canvas_transform().affine_inverse() * button.position
		_picked_at = point
		_picked = _square_at(point)
		if _picked == null:
			_picked = _crate_at(point)
		if _picked == null:
			_picked = _tower_at(point)
		if _picked == null:
			_picked = _object_at(point)
		get_viewport().set_input_as_handled()


## The supply crate whose pallet `point` is on (null if none).
func _crate_at(point: Vector2) -> Node2D:
	for crate: Node2D in get_tree().get_nodes_in_group("crates"):
		if not "vicinity_m" in crate:
			continue
		var local := crate.to_local(point)
		var half: Vector2 = crate.pallet_m.max(crate.load_m) * World.PX_PER_M / 2.0
		if absf(local.x) <= half.x and absf(local.y) <= half.y:
			return crate
	return null


## The watch tower whose deck, shelter or stair world `point` is on (null if
## none); which part goes in `_picked_part`.
func _tower_at(point: Vector2) -> Node2D:
	for tower: Node2D in get_tree().get_nodes_in_group("watch_towers"):
		if tower.is_visible_in_tree() and tower.part_at(point) != "":
			_picked_part = tower.part_at(point)
			return tower
	return null


## The solid thing (not a square) under world `point`: what a bullet would
## hit there (null if none).
func _object_at(point: Vector2) -> Node2D:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = false
	for hit in get_world_2d().direct_space_state.intersect_point(query):
		var body = hit.collider
		if body is Node2D and not body.is_in_group("units") and body.is_visible_in_tree():
			if _is_tower(body.get_parent()):   # its legs (the base) or stair: that part of the tower
				_picked_part = "lower_stairs" if body.name == "StairsBody" else "base"
				return body.get_parent()
			return body
	return null


func _is_crate(node: Node2D) -> bool:
	return "vicinity_m" in node


## A watch tower (watch_tower.gd): it has sections round it.
func _is_tower(node: Node) -> bool:
	return node != null and node.has_method("fired_down_pass")


## A picked solid thing that isn't a square or a crate.
func _is_object(node: Node2D) -> bool:
	return not _is_crate(node) and not _is_tower(node) and not node.is_in_group("units")


## The panel for anything that isn't a square (a crate, cover, a part of a
## watch tower), laid out the same for all of them, in capitals: its name and
## kind as the title, then COVER CLASS (from what it `stops`, cover.gd),
## HEIGHT CLASS and PROTECTION % (the share of shots it stops), then OBJECT
## SPECIFIC INFO (`extra`);
## beside world `at`.
func _show_object(title: String, kind: String, stops: float, height: int, extra: Array, at: Vector2) -> void:
	var cls := Cover.class_for(stops)
	var lines := [
		"COVER CLASS: %d (%s)" % [cls, COVER_NAMES[cls].capitalize()],
		"HEIGHT CLASS: %d" % height,
		"PROTECTION %%: %d" % roundi(stops * 100.0),
	]
	_show_panel("%s  (%s)" % [title.trim_prefix("@"), kind], lines, "OBJECT SPECIFIC INFO", extra, at)


## Fills in the panel: `title` (in capitals), then `lines`, then (if there
## are any) a gap, `heading`: and the `info` lines, indented, in capitals;
## beside world `at`.
func _show_panel(title: String, lines: Array, heading: String, info: Array, at: Vector2) -> void:
	_name_label.text = title.to_upper()
	var body := lines.duplicate()
	if not info.is_empty():
		body.append("")
		body.append(heading + ":")
		for line in info:
			body.append("  " + str(line).to_upper())
	_body_label.text = "\n".join(body)
	_panel.reset_size()
	_panel.position = get_viewport().get_canvas_transform() * at + PANEL_OFFSET


## The live, numbered square nearest world `point`, within PICK_M (null if none).
func _square_at(point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := PICK_M * World.PX_PER_M
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if unit.dead or not unit.is_visible_in_tree() or BattleLog.number_of(unit) < 0:
			continue
		var d := unit.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = unit
	return best


func _process(_delta: float) -> void:
	if not World.debug:
		return
	if _picked != null and (not is_instance_valid(_picked) or not _picked.is_visible_in_tree()
			or (_picked.is_in_group("units") and _picked.dead)):
		_picked = null
	_update_panel()
	_view.queue_redraw()


## The picked square's details, beside it.
func _update_panel() -> void:
	_panel.visible = _picked != null
	if _picked == null:
		return
	if _is_crate(_picked):
		_update_crate_panel(_picked)
		return
	if _is_object(_picked):
		_update_object_panel(_picked)
		return
	if _is_tower(_picked):
		_update_tower_panel(_picked)
		return
	var side := "enemy" if _picked.is_in_group("enemies") else ("player" if _picked.is_in_group("player") else "squad")
	var shown := "" if _picked.name.begins_with("@") else "  " + _picked.name   # spawned: no name of its own
	var lines := []
	var rifle = _picked.get_node_or_null("Rifle")
	if rifle == null:
		lines.append("AMMO: NO RIFLE")
	else:
		var empty: bool = rifle.rounds <= 0 and not rifle.reloading
		lines.append("AMMO: RELOADING" if rifle.reloading else "AMMO: %d / %d%s" % [rifle.rounds, rifle.mag_size, "  (EMPTY)" if empty else ""])
		var spares: int = rifle.spare_count()
		lines.append("MAGS: UNLIMITED" if spares < 0 else "MAGS: %d (%d ROUNDS)" % [spares, rifle.spare_rounds()])
	var status := _status(_picked)
	if status.word != "":
		lines.append("STATE: %s" % status.word)
	_show_panel("#%d%s  (%s)" % [BattleLog.number_of(_picked), shown, side], lines, "UNIT SPECIFIC INFO", status.long,
			_picked.global_position)


## A picked crate (the standard object panel): then what it holds, its
## straps, its vicinity (drawn round it, _draw_numbers()), and the enemy
## working at it.
func _update_crate_panel(crate: Node2D) -> void:
	var extra := []
	if crate.parts.is_empty():
		extra.append("contents: nothing to take")
	else:
		extra.append("%s: %d / %d left" % [crate.builds.replace("_", " "), crate.parts.size() - crate.taken, crate.parts.size()])
	extra.append("straps: %s" % ("on" if crate.strapped else "off"))
	extra.append("vicinity: %.1f m" % crate.vicinity_m)
	if crate.reserved > crate.taken:
		extra.append("owed to things being built: %d" % (crate.reserved - crate.taken))
	var worker = crate.enemy_worker
	if worker != null and is_instance_valid(worker) and not worker.dead and worker.crate_task != "":
		extra.append("enemy at it: #%d, %s" % [BattleLog.number_of(worker), worker.crate_task])
	var cans: int = crate.enemy_cans.filter(func(c): return is_instance_valid(c)).size()
	if cans > 0:
		extra.append("enemy ammo cans set up from it: %d" % cans)
	_show_object(crate.name, "crate", Cover.stop_chance(crate), Cover.height_class_of(crate), extra, crate.global_position)


## A picked solid thing (the standard object panel), and what it's part of.
func _update_object_panel(node: Node2D) -> void:
	var holder := node.get_parent()
	var kind := "cover" if holder == null or holder == get_tree().current_scene else holder.name.trim_prefix("@")
	_show_object(node.name, kind, Cover.stop_chance(node), Cover.height_class_of(node), [], _picked_at)


## A picked part of a watch tower (the standard object panel, its cover for
## whoever's in it: watch_tower.gd part_pass()): then how many are in it, and
## for a part you can stand on up there, firing down from it: its three
## sections (drawn round the tower, _draw_numbers()), how far each reaches
## and how much of the shots gets through lower cover in it.
func _update_tower_panel(tower: Node2D) -> void:
	var part := _picked_part
	var height: int = tower.part_height_class(part)
	var extra := []
	var in_it := get_tree().get_nodes_in_group("units").filter(func(u): return not u.dead and tower.part_of(u) == part).size()
	extra.append("units in it: %d" % in_it)
	if part != "base":
		extra.append("firing down from it, protection of cover below class %d:" % height)
		var inner := 0.0
		var all: Array = tower.sections()
		for i in all.size():
			var reach := "bullet range" if is_inf(all[i][0]) else "%.1f m" % all[i][0]
			var classes := "class 1: %d%%" % roundi((1.0 - all[i][1]) * 100.0)
			if height > 2:
				classes += ", class 2: %d%%" % roundi((1.0 - all[i][2]) * 100.0)
			extra.append("  section %d (%.1f m - %s): %s" % [i + 1, inner, reach, classes])
			inner = all[i][0]
	_show_object(tower.name, part.replace("_", " "), 1.0 - tower.part_pass(part), height, extra, _picked_at)


func _draw_numbers() -> void:
	var font := ThemeDB.fallback_font
	var to_screen := get_viewport().get_canvas_transform()
	var zoom := to_screen.get_scale().x
	_view.draw_string(font, Vector2(16, get_viewport().get_visible_rect().size.y - 16), "DEBUG (Q)  click a square, a crate, a tower or anything solid for its details   wheel button: pan",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(World.COMMAND_COLOR, 0.8))
	if _picked != null:
		var ring_at := _picked_at if _is_object(_picked) or _is_tower(_picked) else _picked.global_position
		_view.draw_arc(to_screen * ring_at, RING_M * World.PX_PER_M * zoom, 0.0, TAU, 40,
				Color(1.0, 0.85, 0.3, 0.9), 2.0, true)
		if _is_crate(_picked):   # its vicinity: enemies inside it use it (enemy.gd)
			var r: float = _picked.vicinity_m * World.PX_PER_M * zoom
			_view.draw_circle(to_screen * _picked.global_position, r, Color(1.0, 0.85, 0.3, 0.06))
			_view.draw_arc(to_screen * _picked.global_position, r, 0.0, TAU, 96, Color(1.0, 0.85, 0.3, 0.8), 2.0, true)
		if _is_tower(_picked) and _picked_part != "base":   # its sections: firing down from that part, more gets through lower cover
			var at := to_screen * _picked.global_position
			var all: Array = _picked.sections()
			for i in all.size():
				var label: Vector2
				if is_inf(all[i][0]):   # the last runs on as far as a bullet goes: just its number, outside the one before
					label = at + Vector2(0.0, -all[i - 1][0] * World.PX_PER_M * zoom) + Vector2(6.0, -8.0)
				else:
					var r: float = all[i][0] * World.PX_PER_M * zoom
					_view.draw_circle(at, r, Color(SECTION_COLORS[i], 0.07))
					_view.draw_arc(at, r, 0.0, TAU, 128, Color(SECTION_COLORS[i], 0.85), 2.0, true)
					label = at + Vector2(0.0, -r) + Vector2(6.0, 20.0)
				_view.draw_string_outline(font, label, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, 0.8))
				_view.draw_string(font, label, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, SECTION_COLORS[i])
	for tower: Node2D in get_tree().get_nodes_in_group("watch_towers"):   # each watch tower's overlook box
		var box: Rect2 = tower.overlook_box
		var corners := PackedVector2Array()
		for c in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.position]:
			corners.append(to_screen * tower.to_global(c * World.PX_PER_M))
		_view.draw_polyline(corners, Color(OVERLOOK_COLOR, 0.9), 3.0, true)
		_view.draw_string_outline(font, corners[0] + Vector2(6, 20), "OVERLOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
		_view.draw_string(font, corners[0] + Vector2(6, 20), "OVERLOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, OVERLOOK_COLOR)
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		var n := BattleLog.number_of(unit)
		if n < 0 or unit.dead or not unit.is_visible_in_tree():
			continue
		var at := to_screen * unit.global_position + OFFSET_M * World.PX_PER_M * zoom
		var color := ENEMY_COLOR if unit.is_in_group("enemies") else World.COMMAND_COLOR
		_view.draw_string_outline(font, at, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE, Color(0, 0, 0, 0.8))
		_view.draw_string(font, at, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
		var status := _status(unit)
		if status.word == "":
			continue
		var lines: Array = [SHORT.get(status.word, status.word)]
		if not status.tags.is_empty():
			lines.append(" ".join(status.tags))
		for k in lines.size():
			var below := at + Vector2(0.0, (k + 1) * (STATE_FONT_SIZE + 1))
			_view.draw_string_outline(font, below, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, STATE_FONT_SIZE, 4, Color(0, 0, 0, 0.8))
			_view.draw_string(font, below, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, STATE_FONT_SIZE,
					color if k == 0 else Color(color, 0.8))   # in its number's colour


## What `unit` is doing: {word (its state, "" for the player), tags
## (short, for over it), long (spelled out, for the panel)}.
func _status(unit: Node2D) -> Dictionary:
	var word := ""
	if unit.is_in_group("enemies") and "mode" in unit:
		word = unit.Mode.keys()[unit.mode]
	elif unit.is_in_group("squad") and "state" in unit:
		word = unit.State.keys()[unit.state]
		if word == "IDLE" and unit.get("under_orders"):
			word = "ORDERS"   # under orders: nothing on its own from idle (squadmate.gd)
	var tags := []
	var long := []
	var target = unit.get("attack_target")
	if target != null and is_instance_valid(target) and not target.dead:
		var n := BattleLog.number_of(target)
		tags.append(">%d" % n)
		long.append("shooting at #%d" % n)
	if unit.get("_hide_cover") != null and is_instance_valid(unit._hide_cover):
		var phase: String = unit.HidePhase.keys()[unit._hide_phase].to_lower()
		tags.append(phase)
		long.append("in cover: %s" % phase)
	elif unit.get("_cover") != null and is_instance_valid(unit._cover) and word == "DEFEND":
		long.append("dug in at a wall")
	for flag in [["holding_fire", "hold", "holding fire: a friend in the line"],
			["_standoff", "standoff", "standoff: foes all behind heavy cover"],
			["hold_fire", "stop", "told to Stop"],
			["_fire_ordered", "", "target from a Fire order"]]:
		if unit.get(flag[0]):
			if flag[1] != "":
				tags.append(flag[1])
			long.append(flag[2])
	if unit.get("crate_task"):   # an enemy at an ammo crate (enemy.gd CRATES)
		var job: String = {"unstrap": "unstrapping", "ammo": "can run"}.get(unit.crate_task, unit.crate_task)
		tags.append(job)
		long.append("at an ammo crate: %s" % ("undoing the straps" if unit.crate_task == "unstrap"
				else "setting up an ammo can for the standoff"))
	if unit.get("_loading_ammo"):
		tags.append("loading")
		long.append("loading at an ammo can")
	elif unit.get("_ammo") != null and is_instance_valid(unit._ammo):
		tags.append("ammo")
		long.append("going for ammo")
	if unit.get("exposed_s") > 0.0 and get_tree().get_nodes_in_group("deployed_sandbags").any(
			func(wall): return wall.has_method("in_zone") and wall.in_zone(unit.global_position)):
		tags.append("exposed")
		long.append("exposed: firing over a sandbag wall (it covers 40%)")
	var rifle = unit.get_node_or_null("Rifle")
	if rifle and rifle.reloading:
		tags.append("reload")
	if unit.get("carrying"):
		tags.append(unit.carrying)
		long.append("carrying %s" % unit.carrying)
	for tower in get_tree().get_nodes_in_group("watch_towers"):
		var part: String = tower.part_of(unit)
		if part != "":
			var cls: int = tower.part_cover_class(part)
			long.append("watch tower: %s (cover class %d, %s; height class %d)" % [part.replace("_", " "), cls, COVER_NAMES[cls], tower.part_height_class(part)])
	if unit.get("follow_mode"):
		long.append("in formation: %s" % unit.follow_mode)
	if "alerted" in unit and not unit.alerted and word != "":
		long.append("not alerted")
	return {word = word, tags = tags, long = long}
