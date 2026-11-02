extends Node2D
## A deployed ammo can (scenes/ammo_supply.tscn; the can is crates.py's
## assets/props/hold_ammo_can.png): loose rounds, no magazines, for topping up.
##
## Laid from command mode's DEPLOY like a sandbag wall,
## it's built from an ammo crate (crate.gd, a can a part): it goes down as a
## site (start_site()), a faint green ghost, until someone carries a can
## over from the crate (the player, player.gd, or squadmates under a Build
## order, squadmate.gd; a green F shows on it when the player's carrying
## one within DELIVER_M) and install() sets it down.
##
## Then it holds `rounds` (120). Like a dead square's magazine
## (ammo_pickup.gd) it's in the "ammo_pickups" group, and anyone standing at
## it (within REACH_M) whose spare magazines aren't full loads from it
## (work_load()): the player just by standing there, squadmates and enemies
## when they come for ammo (ai_soldier.gd _ammo_run()), one at a time: the
## one coming or loading claims it (`claimed_by`), and the next waits until
## it's done (the player isn't held back).
## Opening it takes OPEN_S, then a round goes into the spares every
## ROUND_S (rifle.gd load_round(): the fullest that isn't full first). The
## magazine count never goes up: there are only bullets in it. Firing or
## reloading pauses it; stepping away, it starts again with the lid. A ring
## round the can fills with the loader's spares while it's going; for the
## player, "+n rds" floats up when they stop. Empty, it fades and is gone.
## In command mode the rounds left show over it.

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const AmmoPickup = preload("res://scripts/ammo_pickup.gd")

const REACH_M := 0.6           ## loading from it within this far of its middle
const DELIVER_M := 1.0         ## a can's brought in within this far of the site
const OPEN_S := 0.6            ## getting the lid open before the first round
const HEIGHT_M := 0.207        ## the can's top (crate.gd's lone can), for its shadow
const SHADOW_ALPHA := 0.55
const SITE_GHOST := Color(0.55, 1.0, 0.55, 0.6)
const GHOST_BRIGHT := Color(2.2, 2.2, 2.2)   ## the dark olive can lifted so a ghost or site reads on grass
const RING_M := 0.3
const RING_COLOR := Color(1.0, 0.85, 0.3, 0.9)
const FADE_S := 1.0
const MARK_M := 0.24           ## the outline's width round the can (1.6x as long)

## Loose rounds in it.
@export_range(1, 2000, 1) var rounds := 120
## Loading one round into a magazine.
@export_range(0.01, 2.0, 0.01, "suffix:s") var round_s := 0.1
## Up and usable, or still a site waiting for its can.
@export var built := true

## Who's loading from it: {square: {t, loaded, tick}} (seconds at it, rounds
## loaded this visit, physics tick last worked).
var _loaders := {}
## The square on its way to it or loading from it (ai_soldier.gd); others wait.
var claimed_by: Node2D = null
var _key: Label
var _count: Label
var _ring: Node2D
var _mark: Node2D
var _empty := false

@onready var _body: Sprite2D = $Body
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	z_as_relative = false
	z_index = -4   # on the ground, under the squares (like a dropped rifle)
	var away: Vector2 = World.SUN_DIR * HEIGHT_M * tan(deg_to_rad(World.SUN_TILT_DEG)) * World.PX_PER_M
	_shadow.position = away.rotated(-rotation)
	_shadow.modulate = Color(0, 0, 0, SHADOW_ALPHA)
	# The can's small and dark on the grass: an outline round it and its
	# loading reach make a ghost or a site easy to see.
	_mark = Node2D.new()
	_mark.z_as_relative = false
	_mark.z_index = -3
	_mark.draw.connect(_draw_mark)
	add_child(_mark)
	if process_mode == Node.PROCESS_MODE_DISABLED:
		_body.self_modulate = GHOST_BRIGHT
		return   # a placing ghost (command.gd)
	_ring = Node2D.new()
	_ring.z_as_relative = false
	_ring.z_index = 5
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_count = UiStyle.title("", 13)
	_count.z_as_relative = false
	_count.z_index = 30
	add_child(_count)
	_show_built()


func _physics_process(delta: float) -> void:
	if not built or _empty:
		return
	var player = get_tree().get_first_node_in_group("player")
	if (player != null and not player.dead and player.carrying == "" and useful_to(player)
			and player.global_position.distance_to(global_position) <= REACH_M * World.PX_PER_M):
		work_load(player, delta)
	# Loaders that stopped (walked off, done, fell): the next visit starts with the lid.
	var now := Engine.get_physics_frames()
	for who in _loaders.keys():
		if not is_instance_valid(who) or who.dead or _loaders[who].tick < now - 1:
			_finish(who)


func _process(_delta: float) -> void:
	if _key:
		var player = get_tree().get_first_node_in_group("player")
		_key.visible = (not built and player != null and player.carrying == "ammo_can"
				and can_deliver_at(player.global_position) and player.interact_target() == self)
		_key.rotation = -global_rotation
		_key.position = (-_key.size / 2.0).rotated(-global_rotation)
	if _count:
		_count.visible = built and not _empty and World.commanding()
		_count.text = "%d" % rounds
		_count.rotation = -global_rotation
		_count.position = Vector2(-_count.size.x / 2.0, -0.42 * World.PX_PER_M - _count.size.y).rotated(-global_rotation)
	if _ring:
		_ring.visible = not _loaders.is_empty()
		_ring.queue_redraw()
	_mark.visible = not built or (World.commanding() and not _empty)


# ---------------------------------------------------------- building --

## Starts it as a site, its can to come from `crate`.
func start_site(crate: Node2D) -> void:
	built = false
	crate.reserve(self, 1)
	add_to_group("build_sites")
	_key = UiStyle.pad_key("F", Color(World.COMMAND_COLOR, 0.55))
	_key.scale = Vector2.ONE * 0.6
	add_child(_key)
	_show_built()


func needs(part: String) -> bool:
	return not built and part == "ammo_can"


func can_deliver_at(at: Vector2, _who: Node = null) -> bool:
	return not built and at.distance_to(global_position) <= DELIVER_M * World.PX_PER_M


## The can's come: it's down and in use.
func install(part: String) -> void:
	if not needs(part):
		return
	built = true
	remove_from_group("build_sites")
	if _key:
		_key.queue_free()
		_key = null
	_show_built()


func _show_built() -> void:
	_body.modulate = Color.WHITE if built else SITE_GHOST
	_body.self_modulate = Color.WHITE if built else GHOST_BRIGHT
	_shadow.visible = built
	if built and not _empty:
		add_to_group("ammo_pickups")


# ----------------------------------------------------------- loading --

## Whether `square` has room in its spares and there are rounds to give.
func useful_to(square: Node2D) -> bool:
	return built and not _empty and rounds > 0 and square.get_node("Rifle").spare_room() > 0


## `square` keeps at it for `delta` seconds (every physics tick while it's
## there): the lid, then a round every `round_s` into its spares. True once
## it's done (spares full, or the can's empty).
func work_load(square: Node2D, delta: float) -> bool:
	if not useful_to(square):
		return true
	var rifle: Node2D = square.get_node("Rifle")
	var state: Dictionary = _loaders.get(square, {t = 0.0, loaded = 0, tick = 0})
	state.tick = Engine.get_physics_frames()
	_loaders[square] = state
	if not rifle.ready_to_load():
		return false   # firing or reloading: it waits
	state.t += delta
	while state.t >= OPEN_S + round_s and rounds > 0 and rifle.load_round():
		state.t -= round_s
		state.loaded += 1
		rounds -= 1
	if rounds <= 0:
		_run_dry()
		return true
	return rifle.spare_room() <= 0


## `who` stopped loading: "+n rds" over the player.
func _finish(who: Variant) -> void:
	var state: Dictionary = _loaders[who]
	_loaders.erase(who)
	if is_instance_valid(who) and who.is_in_group("player") and state.loaded > 0:
		AmmoPickup.note(get_parent(), who.global_position, "+%d rds" % state.loaded)


## Empty: out of the pickups, fades and is gone.
func _run_dry() -> void:
	_empty = true
	remove_from_group("ammo_pickups")
	for who in _loaders.keys():
		_finish(who)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_S)
	fade.tween_callback(queue_free)


## An outline round the can and a ring at REACH_M (where you load from it),
## in the command green: on a placing ghost (tinted with it), on a site,
## and on a can that's down while in command mode.
func _draw_mark() -> void:
	var px := World.PX_PER_M
	var half := MARK_M / 2.0 * px
	var color := Color(World.COMMAND_COLOR, 0.9)
	_mark.draw_rect(Rect2(-half, -half * 1.6, half * 2.0, half * 3.2), color, false, 1.5)
	_mark.draw_circle(Vector2.ZERO, REACH_M * px, Color(World.COMMAND_COLOR, 0.08))
	_mark.draw_arc(Vector2.ZERO, REACH_M * px, 0.0, TAU, 48, Color(World.COMMAND_COLOR, 0.55), 1.5, true)


## Round the can: how full the loader's spares are (the first loader's).
func _draw_ring() -> void:
	var who = _loaders.keys()[0] if not _loaders.is_empty() else null
	if not is_instance_valid(who):
		return
	var rifle: Node2D = who.get_node("Rifle")
	var full: float = rifle.spare_mags * rifle.mag_size
	var share := clampf(rifle.spare_rounds() / maxf(full, 1.0), 0.0, 1.0)
	var r := RING_M * World.PX_PER_M
	_ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 3.0, true)
	_ring.draw_arc(Vector2.ZERO, r, -PI / 2, -PI / 2 + TAU * share, 48, RING_COLOR, 3.0, true)
