extends Node
## The battle log: F9 (or the button at the top left) starts and stops
## recording everything every square does to a text file, for Claude to read
## when assessing a test (the battle-log skill, .claude/skills/battle-log).
## Starting a log wipes the last one. Made by command.gd; one per level.
##
## Every square (player, squad, enemies, anyone who turns up later) has a
## number for the whole level, logging or not: the player 0, the rest 1, 2...
## as they're first seen (number_of()). Debug mode (Q, debug_overlay.gd)
## shows them over the squares, so Mike can ask about one by its number.
## Recorded: when it turns up (or the log starts); where it is
## and which way it faces (SAMPLE_S, only once it's moved or turned); every
## change in what it's doing (its state, target, cover, alert, holding
## fire...), checked every tick; every shot and where it ended up; every hit
## it takes; every order a squadmate gets; and the solid things on the
## field (cover, with its class) as they appear, change or go. The file
## starts with a legend of the line codes, so it explains itself.
##
## Plain text, one line per thing, tab-separated, in metres and seconds:
## a few hundred KB for a few minutes of fighting, and readable as it is
## (a binary file would need converting before it could be read).
## Running from the editor it's written to logs/battle_log.txt in the
## project (logs/ has a .gdignore, so the editor leaves it alone); in an
## exported game, to user://battle_log.txt.

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Cover = preload("res://scripts/cover.gd")

const FORMAT := 1
const SAMPLE_S := 0.2             ## positions this often (5 a second)...
const MOVED_M := 0.05             ## ...once it's moved this far
const TURNED_DEG := 5.0           ## or turned this far
const SPOT_GRID_M := 0.5          ## an enemy's chosen spot, rounded to this
const MAP_SCAN_S := 1.0           ## looks for new, changed or gone objects this often
const FLUSH_S := 1.0              ## onto the disk this often, so a crash loses at most this much
const MAP_MASK := 1 | 4           ## solid things and sandbags (ai_soldier.gd HIDE_MASK)
const RECORD_COLOR := Color(1.0, 0.35, 0.3)

const LEGEND := [
	"# Lines: <t seconds since start> <code> <fields>, tab-separated. Positions in metres",
	"#   (x right, y down, from the arena's top-left); angles in degrees (0 east, 90 south).",
	"#   Squares are numbers: the player 0, the rest 1, 2... in the order they turned up in the level",
	"#   (the numbers debug mode, Q, shows over them; not restarted by a new log, so gaps are squares",
	"#   that died before it). Objects are o1, o2...; shots are s1, s2...; - is none.",
	"# U  <unit> <side player|squad|enemy> <node name> <kit> <max hp> <x> <y>   turned up",
	"# P  <unit> <x> <y> <facing>                    where it is (every 0.2 s, once it's moved or turned)",
	"# ~  <unit> key=value ...                       what changed in what it's doing (keys below)",
	"# F  <shot> <unit> <target> <x> <y> <dir> <range> <rounds left>   fired (range: m to where it'd go into",
"#                                                the ground, - for its full flight; target - for the player)",
	"# X  <shot> <result> <x> <y>                    where it ended: a unit it hit, an object (o#), ground, spent",
	"# H  <unit> <by> <damage> <hp left>              took a hit",
	"# O  <unit> <order> [args]                       a squadmate was told to (command mode, a helicopter",
	"#                                                drop-off, or its own move to a new wall spot)",
	"# M  <object> <kind> <x> <y> <w> <h> <class> [extra]   a solid thing: new, or changed (centre, size,",
	"#                                                cover class 0-3, scripts/cover.gd: 3 stops over 60%)",
	"# G  <object>                                    gone",
	"# Keys in ~ lines:",
	"#   state    squadmate: IDLE SHUFFLE MOVE FOLLOW ATTENTION DEFEND BUILD SURPRISED PINNED;",
	"#            enemy: CALM ENGAGE SEARCH RETURN SURPRISED",
	"#   target   who it's shooting at       threat  who an enemy is fighting   alert  enemy alerted 1/0",
	"#   cover    what it's behind (o#)      hide    in cover: GOING HIDING PEEKING",
	"#   spot     where an enemy is heading to fight from (x,y)",
	"#   blocked  holding fire: someone in the line   standoff  holding fire: foes all dug in, no window",
	"#   stop     told to Stop (won't shoot back)     ordered   its target came from a Fire order",
	"#   carry    the part it's carrying     reload  reloading 1/0   rounds  in the magazine (on reload)",
	"#   follow   follow / lead              cmd     player in command mode 1/0   busy  player at a menu 1/0",
	"#   dead     1 once killed",
]

## The log being written, for the hooks below (null when not logging).
static var _live = null
## This level's battle log, which numbers the squares (debug_overlay.gd shows them).
static var _level = null

var _file: FileAccess
var _path := ""
var _lines := 0
var _t := 0.0
var _sample_s := 0.0
var _map_s := 0.0
var _flush_s := 0.0
var _numbers := {}       ## instance id -> number, for the whole level (the player 0)
var _next_number := 1
var _introduced := {}    ## numbers with a U line in this log
var _unit_nodes := {}    ## number -> WeakRef: introduced and still alive, polled
var _status := {}        ## number -> {key: value} as last written
var _pose := {}          ## number -> Vector3(x m, y m, facing deg) as last written
var _objects := {}       ## instance id -> number
var _object_nodes := {}  ## number -> WeakRef
var _object_last := {}   ## number -> its M line's fields as last written
var _shots := {}         ## bullet instance id -> shot number
var _enum_names := {}    ## "script path:enum" -> {value: name}
var _button: Button
var _note: Label
var _shown_s := -1


# ------------------------------------------------------------------ hooks --

## A bullet's just been fired (bullet.gd setup()).
static func shot(bullet: Node2D) -> void:
	if _live:
		_live._shot(bullet)


## A bullet's done: it hit `what` (null: into the ground, or `how` "spent").
static func shot_end(bullet: Node2D, what: Object, at: Vector2, how := "") -> void:
	if _live:
		_live._shot_end(bullet, what, at, how)


## `unit` is hit by `by` for `damage` (soldier.gd take_hit()).
static func hit(unit: Node2D, by: Node2D, damage: float) -> void:
	if _live:
		_live._hit(unit, by, damage)


## A squadmate's been given an order (squadmate.gd order_*()). `args` are
## points, squares or objects, or anything to write as it is.
static func order(unit: Node2D, what: String, args := []) -> void:
	if _live:
		_live._order(unit, what, args)


static func is_logging() -> bool:
	return _live != null


## A square's number, the same in the log and over it in debug mode: the
## player 0, everyone else 1, 2... in the order they turned up in the level.
## -1 if it hasn't one (not a square, or no battle log in this level).
static func number_of(unit: Node) -> int:
	if _level == null or unit == null:
		return -1
	return _level._numbers.get(unit.get_instance_id(), -1)


# ---------------------------------------------------------- start / stop --

func _ready() -> void:
	process_priority = 100              # after everyone else, so it sees this tick's changes
	process_physics_priority = 100
	_level = self
	_build_hud()


func _exit_tree() -> void:
	stop()
	if _level == self:
		_level = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("battle_log") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _file:
		stop()
	else:
		start()


## Starts a new log, wiping the last one.
func start() -> void:
	_path = "user://battle_log.txt"
	if OS.has_feature("editor"):
		var dir := ProjectSettings.globalize_path("res://logs")
		DirAccess.make_dir_recursive_absolute(dir)
		if not FileAccess.file_exists(dir + "/.gdignore"):
			FileAccess.open(dir + "/.gdignore", FileAccess.WRITE)   # the editor doesn't import it
		_path = dir + "/battle_log.txt"
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		_note.text = "Can't write %s (%s)" % [_path, error_string(FileAccess.get_open_error())]
		return
	_live = self
	_t = 0.0
	_lines = 0
	for d in [_introduced, _unit_nodes, _status, _pose, _objects, _object_nodes, _object_last, _shots]:
		d.clear()
	_sample_s = 0.0
	_map_s = 0.0
	_flush_s = FLUSH_S
	_raw("# BattleSquares battle log, format %d" % FORMAT)
	_raw("# Started %s. Level %s. Arena %.1f x %.1f m." % [Time.get_datetime_string_from_system(false, true),
			get_tree().current_scene.scene_file_path if get_tree().current_scene else "?",
			World.ARENA.size.x / World.PX_PER_M, World.ARENA.size.y / World.PX_PER_M])
	for line: String in LEGEND:
		_raw(line)
	_scan_map()
	_poll_units(true)
	_note.text = "Recording to %s" % _path.get_file()
	_update_button()


func stop() -> void:
	if _file == null:
		return
	_raw("%.2f\tEND\t%d squares, %d shots" % [_t, _introduced.size(), _shots.size()])
	_file.close()
	_file = null
	if _live == self:
		_live = null
	_note.text = "Saved %d lines: %s" % [_lines, _path]
	_update_button()


# ------------------------------------------------------------- recording --

func _physics_process(delta: float) -> void:
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		_number(unit)   # numbered whether or not it's logging, for debug mode
	if _file == null:
		return
	_t += delta
	_map_s -= delta
	if _map_s <= 0.0:
		_map_s = MAP_SCAN_S
		_scan_map()
	_sample_s -= delta
	var sample := _sample_s <= 0.0
	if sample:
		_sample_s = SAMPLE_S
	_poll_units(sample)
	_flush_s -= delta
	if _flush_s <= 0.0:
		_flush_s = FLUSH_S
		_file.flush()


func _process(_delta: float) -> void:
	if _file and int(_t) != _shown_s:
		_update_button()


## Every square: new ones turn up, and what's changed is written.
func _poll_units(sample: bool) -> void:
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		_unit_id(unit)
	for n: int in _unit_nodes.keys():
		var unit: Node2D = _unit_nodes[n].get_ref()
		if unit == null:
			_unit_nodes.erase(n)
			continue
		_write_status(n, _read_status(unit))
		if unit.dead:
			_unit_nodes.erase(n)   # it's down: nothing more to say about it
		elif sample:
			_write_pose(n, unit)


## Its number, giving it one if it's new: the player 0, the rest in turn.
func _number(unit: Node) -> int:
	var key := unit.get_instance_id()
	if not _numbers.has(key):
		if unit.is_in_group("player"):
			_numbers[key] = 0
		else:
			_numbers[key] = _next_number
			_next_number += 1
	return _numbers[key]


## Its number for the log, writing it up if it's new to this log. "-" for none.
func _unit_id(unit: Object) -> String:
	if unit == null or not is_instance_valid(unit):
		return "-"
	if not unit.has_method("take_hit") or not "dead" in unit:
		return _object_id(unit)   # not a square: a crate, sandbags...
	var n := _number(unit)
	if _introduced.has(n):
		return str(n)
	_introduced[n] = true
	_unit_nodes[n] = weakref(unit)
	var side := "enemy" if unit.is_in_group("enemies") else ("player" if unit.is_in_group("player")
			else ("squad" if unit.is_in_group("squad") else "other"))
	_line("U", [n, side, unit.name, unit.kit if unit.kit != "" else "-", unit.max_health,
			_m(unit.global_position.x), _m(unit.global_position.y)])
	_write_status(n, _read_status(unit))
	_write_pose(n, unit)
	return str(n)


## What it's doing, as key -> text.
func _read_status(unit: Node2D) -> Dictionary:
	var s := {}
	if "state" in unit:
		s.state = _enum_name(unit, "State", unit.state)
	if "mode" in unit:
		s.state = _enum_name(unit, "Mode", unit.mode)
	if "attack_target" in unit:
		s.target = _unit_id(unit.attack_target)
	if "threat" in unit:
		s.threat = _unit_id(unit.threat)
	if "alerted" in unit:
		s.alert = _flag(unit.alerted)
	var cover: Object = null
	for key in ["_hide_cover", "_cover", "cover_wall"]:
		if key in unit and unit.get(key) != null and is_instance_valid(unit.get(key)):
			cover = unit.get(key)
			break
	s.cover = _object_id(cover) if cover else "-"
	if "_hide_cover" in unit:
		s.hide = _enum_name(unit, "HidePhase", unit._hide_phase) if unit._hide_cover != null else "-"
	if "mode" in unit and "tactical_spot" in unit:
		var spot: Vector2 = (unit.tactical_spot / (SPOT_GRID_M * World.PX_PER_M)).round() * SPOT_GRID_M
		s.spot = "%s,%s" % [spot.x, spot.y] if unit.mode == 1 else "-"   # Mode.ENGAGE
	for pair in [["blocked", "holding_fire"], ["standoff", "_standoff"], ["stop", "hold_fire"],
			["ordered", "_fire_ordered"], ["busy", "busy"]]:
		if pair[1] in unit:
			s[pair[0]] = _flag(unit.get(pair[1]))
	if "carrying" in unit:
		s.carry = unit.carrying if unit.carrying != "" else "-"
	if "follow_mode" in unit:
		s.follow = unit.follow_mode if unit.follow_mode != "" else "-"
	var rifle = unit.get("_rifle")
	if rifle:
		s.reload = _flag(rifle.reloading)
	if unit.is_in_group("player"):
		s.cmd = _flag(World.commanding())
	if unit.dead:
		s.dead = "1"
	return s


## A ~ line with whatever changed since it was last written.
func _write_status(n: int, now: Dictionary) -> void:
	var was: Dictionary = _status.get(n, {})
	var parts := []
	for key: String in now:
		if was.get(key) != now[key]:
			parts.append("%s=%s" % [key, now[key]])
	if was.get("reload") == "0" and now.get("reload") == "1":
		var rifle = _unit_nodes[n].get_ref().get("_rifle") if _unit_nodes.has(n) else null
		if rifle:
			parts.append("rounds=%d" % rifle.rounds)
	if not parts.is_empty():
		_line("~", [n] + parts)
	_status[n] = now


func _write_pose(n: int, unit: Node2D) -> void:
	var now := Vector3(unit.global_position.x / World.PX_PER_M, unit.global_position.y / World.PX_PER_M,
			rad_to_deg(unit.facing))
	if _pose.has(n):
		var was: Vector3 = _pose[n]
		if (Vector2(now.x, now.y).distance_to(Vector2(was.x, was.y)) < MOVED_M
				and absf(angle_difference(deg_to_rad(now.z), deg_to_rad(was.z))) < deg_to_rad(TURNED_DEG)):
			return
	_pose[n] = now
	_line("P", [n, "%.2f" % now.x, "%.2f" % now.y, "%d" % roundi(now.z)])


func _shot(bullet: Node2D) -> void:
	var s := _shots.size() + 1
	_shots[bullet.get_instance_id()] = s
	var by: Node2D = bullet.shooter if is_instance_valid(bullet.shooter) else null
	var target := "-"
	var rounds := "-"
	if by:
		target = _unit_id(by.get("attack_target")) if "attack_target" in by else "-"
		var rifle = by.get("_rifle")
		if rifle:
			rounds = str(rifle.rounds)
	_line("F", ["s%d" % s, _unit_id(by), target, _m(bullet.origin.x), _m(bullet.origin.y),
			"%d" % roundi(rad_to_deg(bullet.velocity.angle())),
			"%.1f" % bullet.ground_at_m if bullet.ground_at_m != INF else "-", rounds])


func _shot_end(bullet: Node2D, what: Object, at: Vector2, how: String) -> void:
	var s = _shots.get(bullet.get_instance_id())
	if s == null:
		return   # fired before the log started
	var result := how
	if what != null:
		result = _unit_id(what)
	_line("X", ["s%d" % s, result, _m(at.x), _m(at.y)])


func _hit(unit: Node2D, by: Node2D, damage: float) -> void:
	_line("H", [_unit_id(unit), _unit_id(by), "%.0f" % damage, "%.0f" % (unit.health - damage)])


func _order(unit: Node2D, what: String, args: Array) -> void:
	var fields: Array = [_unit_id(unit), what]
	for arg in args:
		if arg is Vector2:
			fields.append("%s,%s" % [_m(arg.x), _m(arg.y)])
		elif arg is Object:
			fields.append(_unit_id(arg))
		elif str(arg) != "":
			fields.append(str(arg))
	_line("O", fields)


# -------------------------------------------------------------------- map --

## Solid things on the field: new ones, ones that changed (moved, cover
## class, straps) and ones that are gone.
func _scan_map() -> void:
	var seen := {}
	var scene := get_tree().current_scene
	if scene:
		_scan_node(scene, seen)
	for n: int in _object_nodes.keys():
		if not seen.has(n):
			_object_nodes.erase(n)
			_object_last.erase(n)
			_line("G", ["o%d" % n])


func _scan_node(node: Node, seen: Dictionary) -> void:
	if (node is PhysicsBody2D and node.collision_layer & MAP_MASK and not node.has_method("take_hit")
			and not node.is_in_group("bullets")
			and node.get_children().any(func(c): return c is CollisionShape2D or c is CollisionPolygon2D)):
		var id := _object_id(node)
		seen[int(id.substr(1))] = true
	for child in node.get_children():
		_scan_node(child, seen)


## An object's number ("o3"), giving it one if it's new; writes its M line
## when it's new or has changed.
func _object_id(node: Object) -> String:
	if node == null or not is_instance_valid(node) or not node is Node2D:
		return "-"
	var key := node.get_instance_id()
	var n: int = _objects.get(key, 0)
	if n == 0:
		n = _objects.size() + 1
		_objects[key] = n
		_object_nodes[n] = weakref(node)
	var fields := _describe(node)
	if _object_last.get(n) != fields:
		_object_last[n] = fields
		_line("M", ["o%d" % n] + fields)
	return "o%d" % n


## kind, centre x, y, width, height (its collision shapes' bounding box,
## metres), cover class, and anything else worth knowing.
func _describe(node: Node2D) -> Array:
	var kind: String = node.get_script().resource_path.get_file().get_basename() if node.get_script() else str(node.name)
	var box := Rect2()
	var found := false
	for child in node.get_children():
		var r := Rect2()
		if child is CollisionShape2D and child.shape and not child.disabled:
			r = child.global_transform * child.shape.get_rect()
		elif child is CollisionPolygon2D and child.polygon.size() > 0 and not child.disabled:
			var points: PackedVector2Array = child.global_transform * child.polygon
			r = Rect2(points[0], Vector2.ZERO)
			for p in points:
				r = r.expand(p)
		else:
			continue
		box = box.merge(r) if found else r
		found = true
	if not found:
		box = Rect2(node.global_position, Vector2.ZERO)
	var px := World.PX_PER_M
	var fields: Array = [kind, "%.1f" % (box.get_center().x / px), "%.1f" % (box.get_center().y / px),
			"%.1f" % (box.size.x / px), "%.1f" % (box.size.y / px), Cover.class_of(node)]
	if node.get("strapped") == true:
		fields.append("strapped")
	return fields


# ---------------------------------------------------------------- writing --

func _line(code: String, fields: Array) -> void:
	var text := "%.2f\t%s" % [_t, code]
	for f in fields:
		text += "\t" + str(f)
	_raw(text)


func _raw(text: String) -> void:
	if _file:
		_file.store_line(text)
		_lines += 1


func _m(px: float) -> String:
	return "%.2f" % (px / World.PX_PER_M)


func _flag(on) -> String:
	return "1" if on else "0"


## The name of `value` in the enum `enum_name` of the unit's script (or a
## script it extends): "PINNED" rather than 8.
func _enum_name(unit: Object, enum_name: String, value: int) -> String:
	var script: Script = unit.get_script()
	var key := "%s:%s" % [script.resource_path, enum_name]
	if not _enum_names.has(key):
		var names := {}
		while script:
			var consts := script.get_script_constant_map()
			if consts.has(enum_name):
				for k: String in consts[enum_name]:
					names[consts[enum_name][k]] = k
				break
			script = script.get_base_script()
		_enum_names[key] = names
	return _enum_names[key].get(value, str(value))


# -------------------------------------------------------------------- HUD --

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := UiStyle.panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	layer.add_child(panel)
	var column := UiStyle.menu_column("BATTLE LOG (testing)")
	panel.add_child(column)
	_button = UiStyle.menu_button("", Vector2(220, 36))
	_button.pressed.connect(toggle)
	column.add_child(_button)
	_note = UiStyle.title("", 13)
	column.add_child(_note)
	_update_button()


func _update_button() -> void:
	if _file:
		_shown_s = int(_t)
		_button.text = "■ Stop log  %d:%02d  (F9)" % [_shown_s / 60, _shown_s % 60]
		_button.add_theme_color_override("font_color", RECORD_COLOR)
	else:
		_button.text = "● Start log  (F9)"
		_button.add_theme_color_override("font_color", World.COMMAND_COLOR)
