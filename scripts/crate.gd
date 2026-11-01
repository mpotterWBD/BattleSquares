extends StaticBody2D
## A supply crate: a load strapped to a wooden pallet (scenes/crate_<kind>.tscn;
## art from blender/scripts/crates.py: one sprite per load, and the pallet's
## own sprite, assets/props/pallet.png, shared by every crate).
##
## The pallet (`$Pallet`) is drawn under the squares and the load (`$Body`)
## at their level, and only the load is solid (its collision box is the
## load's footprint): a square can step up close, over the pallet's edge,
## and is drawn over the pallet, but can't go into the load. The load is
## solid like a station: squares walk round it, and bullets and sight lines
## stop at it (it's cover, and it hides whoever's behind it).
##
## Its shadow is drawn here (_draw_shadow()): the pallet's footprint swept
## along the sun up to the pallet's height, and the load's swept up to its
## top, in one CanvasGroup so where they overlap isn't doubly dark. It's
## worked out against the node's turn, so a turned crate's shadow still
## falls away from the sun. The load's shadow also falls across the
## pallet's deck (`$PalletShadow`, over the pallet, under the squares): the
## load swept from the deck's height to its top, cut to the deck. The sizes
## come from crates.py's printout.
## Something standing on its own, with no pallet (a lone ammo can,
## scenes/ammo_can.tscn), sets `pallet_m` to zero.
##
## Some crates are a supply that things are built from (`builds`): the comms
## crate a radio station (radio_station.gd), the sandbag crate sandbag walls
## (sandbags.gd). Their `parts` come off one at a time (take_part()),
## carried to whatever's being built by the player (player.gd) or by
## squadmates under a Build order (squadmate.gd); `stage_textures` shows the
## load getting smaller (the stage for how many are off: they spread over
## the parts, so 4 pictures can cover 10 parts), and with the last part
## gone it's just the pallet, no longer solid. Something can be set up from
## it anywhere on the map, however far (command.gd DEPLOY: the crate nearest
## the spot supplies it), so where crates are dropped decides how far the
## parts have to be carried. Setting something up reserves its parts (reserve()): all of them for one radio station
## (`single_site`), one per sandbag wall. Parts are only taken while some
## are owed to something (wanted()). A green F shows on it when the player
## can take one. A part that's put back (its carrier fell, or was given
## another order) goes back on the crate and is the next one taken.
##
## A crate arrives `strapped` (its load under black ratchet straps) and
## nothing comes off it until they're undone: someone with empty hands
## holds F at it (the player, player.gd) or a squadmate building from it
## stands at it (squadmate.gd) for UNSTRAP_S (work_unstrap()), one at a
## time, a ring round it filling as they go; let go or step away and it
## starts again. Then the straps are off: the load shows without them
## (`open_texture`, crates.py's crate_<kind>_open.png), with UNSTRAP_SOUND.
## Something with no `open_texture` (a lone ammo can) has no straps.
##
## A bullet that stops in it can show it (bullet_hit()): with `impact` set,
## that impact sound (scripts/impact_sound.gd) and, for "metal" (the ammo
## cans), sparks (scripts/hit_sparks.gd), or else a puff of dust (e.g. "sand",
## the sandbag crate); with it empty, nothing.

const World = preload("res://scripts/world.gd")
const HitDust = preload("res://scripts/hit_dust.gd")
const HitSparks = preload("res://scripts/hit_sparks.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")
const Cover = preload("res://scripts/cover.gd")

const UNSTRAP_S := 2.0         ## holding at it this long undoes the straps
const UNSTRAP_RING_M := 0.62   ## the progress ring's radius, round the crate's middle
## The straps breaking away (Mike's BandBreak.mp3).
const UNSTRAP_SOUND := "res://assets/sfx/BandBreak.mp3"
const UNSTRAP_DB := 0.0
const SOUND_HEARING_M := 30.0

const SHADOW_ALPHA := 0.71     ## an open-ground shadow (soldier.gd)
const UiStyle = preload("res://scripts/ui_style.gd")
const TAKE_M := 1.25           ## the player takes a part within this far of its middle
const PAD_KEY_ALPHA := 0.55    ## the green F, see-through like the station's

## The pallet's footprint and height (crates.py PALLET_L x PALLET_W, PALLET_H);
## zero for no pallet.
@export var pallet_m := Vector2(0.8, 0.8)
@export var pallet_height_m := 0.144
## The load's footprint and the top of it, straps included (printed by crates.py).
@export var load_m := Vector2(0.632, 0.618)
@export var load_height_m := 0.732
## What's built from it (a DEPLOY id, command.gd: "radio_station", "sandbags"); empty for nothing.
@export var builds := ""
## Its parts, in the order they come off (empty: an ordinary crate).
@export var parts: Array[String] = []
## Whether one thing takes all its parts (the comms crate: one station), or
## each thing one part (the sandbag crate: a wall a part).
@export var single_site := false
## The load getting smaller as parts come off (full first; spread over the parts).
@export var stage_textures: Array[Texture2D] = []
## The load's height (for its shadow) at each of those stages; empty: `load_height_m` throughout.
@export var stage_heights: Array[float] = []
## What a bullet hitting it sounds like (an impact_sound.gd kind: "metal"
## with sparks; "sand", "dirt" or "concrete" with a puff of dust); empty for
## nothing.
@export var impact := ""
## Under its straps: nothing comes off it until they're undone.
@export var strapped := true
## The full load with the straps off; none means it has no straps.
@export var open_texture: Texture2D

signal unstrapped

@onready var _shadow: CanvasGroup = $Shadow
@onready var _shadow_shape: Node2D = $Shadow/Shape
## What's being built from it, how many of its parts are promised to those,
## and how many are off it.
var sites: Array = []
var reserved := 0
var taken := 0
var _next := 0                       ## the next part in `parts` never yet taken
var _returned: Array[String] = []    ## parts put back, taken again first
var _key: Label
## Undoing the straps: how long it's been worked at, by whom, and the
## physics tick it was last worked (not this tick or the last: let go).
var unstrap_progress := 0.0
var _unstrapper: Node2D = null
var _worked_tick := -1
var _ring: Node2D

@onready var _deck_shadow: CanvasGroup = get_node_or_null("PalletShadow")
@onready var _deck_shadow_shape: Node2D = get_node_or_null("PalletShadow/Shape")


func _ready() -> void:
	add_to_group("crates")
	if open_texture == null:
		strapped = false
	_shadow.self_modulate = Color(1, 1, 1, SHADOW_ALPHA)
	_shadow_shape.draw.connect(_draw_shadow)
	if _deck_shadow:
		_deck_shadow.self_modulate = Color(1, 1, 1, SHADOW_ALPHA)
		_deck_shadow_shape.draw.connect(_draw_deck_shadow)
	if not parts.is_empty() or strapped:
		_key = UiStyle.pad_key("F", Color(World.COMMAND_COLOR, PAD_KEY_ALPHA))
		add_child(_key)
		_show_stage()
	# Undoing the straps: an arc round it, filling clockwise from the top.
	_ring = Node2D.new()
	_ring.z_index = 5
	_ring.visible = false
	_ring.draw.connect(func() -> void:
		var r := UNSTRAP_RING_M * World.PX_PER_M
		_ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0, 0, 0, 0.35), 3.0, true)
		_ring.draw_arc(Vector2.ZERO, r, -PI / 2, -PI / 2 + TAU * unstrap_progress / UNSTRAP_S, 64,
				Color(1.0, 0.85, 0.3, 0.9), 3.0, true))
	add_child(_ring)


func _process(_delta: float) -> void:
	_ring.visible = _unstrapper != null
	if _ring.visible:
		_ring.rotation = -global_rotation
		_ring.queue_redraw()
	if _key == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	_key.visible = player != null and _unstrapper == null and (can_take(player) or can_unstrap(player))
	_key.rotation = -global_rotation   # upright however the crate's turned
	_key.position = (-_key.size / 2.0).rotated(-global_rotation)


## Whoever was undoing the straps stopped (let go, walked off, fell): it
## starts again from nothing.
func _physics_process(_delta: float) -> void:
	if _unstrapper != null and (_worked_tick < Engine.get_physics_frames() - 1
			or not is_instance_valid(_unstrapper) or _unstrapper.dead):
		_unstrapper = null
		unstrap_progress = 0.0


## Whether `who` is close enough to work at it (take a part, undo the straps).
func in_reach(who: Node2D) -> bool:
	return who.global_position.distance_to(global_position) <= TAKE_M * World.PX_PER_M


## Whether `who` (the player or a squadmate) can work at its straps now: it's
## strapped, `who` is at it with empty hands, and nobody else is on them.
func can_unstrap(who: Node2D) -> bool:
	return (strapped and not who.dead and who.carrying == "" and in_reach(who)
			and (_unstrapper == null or _unstrapper == who))


## `who` works at the straps for `delta` seconds (every physics tick while
## it keeps at them). Once that adds up to UNSTRAP_S they break away. True
## once they're off.
func work_unstrap(who: Node2D, delta: float) -> bool:
	if not can_unstrap(who):
		return not strapped
	_unstrapper = who
	_worked_tick = Engine.get_physics_frames()
	unstrap_progress += delta
	if unstrap_progress >= UNSTRAP_S:
		_break_straps()
	return not strapped


## Someone other than `who` is undoing its straps.
func unstrapping_by_other(who: Node2D) -> bool:
	return _unstrapper != null and _unstrapper != who


## The straps come off: the load shows without them.
func _break_straps() -> void:
	strapped = false
	_unstrapper = null
	unstrap_progress = 0.0
	var level: Node = get_tree().current_scene
	if level == null:
		level = get_parent()
	if ResourceLoader.exists(UNSTRAP_SOUND):
		var snap := AudioStreamPlayer2D.new()
		snap.stream = load(UNSTRAP_SOUND)
		snap.position = global_position
		snap.volume_db = UNSTRAP_DB
		snap.max_distance = SOUND_HEARING_M * World.PX_PER_M
		snap.finished.connect(snap.queue_free)
		level.add_child(snap)
		snap.play()
	_show_stage()
	unstrapped.emit()


## The share of shots reaching it that it stops: every one while there's a
## load on it (cover class 3, scripts/cover.gd); none once it's down to the
## bare pallet.
func cover_stop_chance() -> float:
	return 1.0 if load_m != Vector2.ZERO else 0.0


func cover_class() -> int:
	return Cover.class_of(self)


## Parts not yet promised to anything.
func available() -> int:
	return parts.size() - reserved


## Something more can be set up from it (a radio station: only from a full crate).
func can_set_up() -> bool:
	return builds != "" and available() > 0 and (not single_site or reserved == 0)


## `site` is being built from it, and `count` of its parts are for it.
func reserve(site: Node2D, count: int) -> void:
	reserved += count
	sites.append(site)


## Whether a part is owed to something being built (so it's worth taking one).
func wanted() -> bool:
	return taken < reserved


## How many parts other crates of its kind owe to things still waiting on
## them that it could give instead (so units sent to it have work). Not for
## a single-site crate: a radio station's parts come from its own crate.
func could_take_over() -> int:
	if single_site or builds == "":
		return 0
	var owed := 0
	for other in _same_kind():
		owed += other.reserved - other.taken
	return mini(owed, available())


## Takes those over: the waiting things get their parts from here instead,
## and the other crates have those parts free again.
func take_over() -> void:
	if single_site or builds == "":
		return
	for other in _same_kind():
		var count := mini(other.reserved - other.taken, available())
		if count <= 0:
			continue
		other.reserved -= count
		reserved += count
		for site in other.sites:
			if is_instance_valid(site) and not site in sites:
				sites.append(site)


func _same_kind() -> Array:
	return get_tree().get_nodes_in_group("crates").filter(func(other):
		return other != self and other.has_method("wanted") and other.builds == builds)


## Whether `carrier` (the player, or a squadmate) can take a part now: one's
## owed, the straps are off, and it's at the crate with empty hands.
func can_take(carrier: Node2D) -> bool:
	return wanted() and not strapped and carrier.carrying == "" and not carrier.dead and in_reach(carrier)


## The next part to come off (empty if none).
func next_part() -> String:
	if not _returned.is_empty():
		return _returned.back()
	return parts[_next] if _next < parts.size() else ""


## Takes the next part off: it's gone from the crate.
func take_part() -> String:
	var part := next_part()
	if part == "":
		return part
	if not _returned.is_empty():
		_returned.pop_back()
	else:
		_next += 1
	taken += 1
	_show_stage()
	return part


## A part comes back (its carrier fell, or was sent elsewhere): it's the next taken.
func return_part(part: String) -> void:
	if taken <= 0:
		return
	_returned.append(part)
	taken -= 1
	_show_stage()


## The nearest thing being built from it, to world `at`, that needs `part`
## (null if none). One not in `claimed` (someone's already bringing it a
## part) if there is one.
func site_for(part: String, at: Vector2, claimed: Array = []) -> Node2D:
	var best: Node2D = null
	var best_free := false
	for site in sites:
		if is_instance_valid(site) and site.needs(part):
			var free: bool = not site in claimed
			if (best == null or (free and not best_free)
					or (free == best_free and site.global_position.distance_to(at) < best.global_position.distance_to(at))):
				best = site
				best_free = free
	return best


## Shows the load with `taken` parts gone (the stage pictures spread over the
## parts); empty, just the pallet, no longer solid or casting the load's shadow.
func _show_stage() -> void:
	var body: Sprite2D = $Body
	if parts.is_empty():   # nothing comes off it (the ammo crate): just the straps
		if not strapped and open_texture:
			body.texture = open_texture
		return
	body.visible = taken < parts.size()
	var stage := mini(taken * stage_textures.size() / maxi(parts.size(), 1), stage_textures.size() - 1)
	if body.visible and stage >= 0:
		body.texture = stage_textures[stage]
		if stage < stage_heights.size():
			load_height_m = stage_heights[stage]
	if body.visible and stage <= 0 and not strapped and open_texture:
		body.texture = open_texture   # the full load, straps off
	var empty := taken >= parts.size()
	$Collision.set_deferred("disabled", empty)
	if empty:
		load_m = Vector2.ZERO
	_shadow_shape.queue_redraw()
	if _deck_shadow_shape:
		_deck_shadow_shape.queue_redraw()


## A bullet stopped in it (bullet.gd): sparks or dust, and the impact
## sound, if it has an `impact`.
func bullet_hit(point: Vector2, direction: Vector2, _damage := 0.0) -> void:
	if impact == "":
		return
	var level: Node = get_tree().current_scene
	if level == null:
		level = get_parent()
	if impact == "metal":
		var sparks := HitSparks.new()
		sparks.setup(point, direction)
		level.add_child(sparks)
	else:
		var dust := HitDust.new()
		dust.setup(point, direction)
		level.add_child(dust)
	ImpactSound.play(level, point, impact)


## Each footprint swept from the ground to its height along the sun, as a
## solid black shape (the group fades it).
func _draw_shadow() -> void:
	for part in [[pallet_m, pallet_height_m], [load_m, load_height_m]]:
		if part[0] == Vector2.ZERO:
			continue
		var half: Vector2 = part[0] * World.PX_PER_M / 2.0
		var height: float = part[1]
		_shadow_shape.draw_colored_polygon(_sweep(part[0], height), Color.BLACK)


## The load's shadow on the pallet's deck: swept from the deck up to the
## load's top, and cut to the deck.
func _draw_deck_shadow() -> void:
	if pallet_m == Vector2.ZERO or load_m == Vector2.ZERO:
		return
	var half := pallet_m * World.PX_PER_M / 2.0
	var deck := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	for piece in Geometry2D.intersect_polygons(_sweep(load_m, load_height_m - pallet_height_m), deck):
		_deck_shadow_shape.draw_colored_polygon(piece, Color.BLACK)


## A `size_m` footprint (centred) swept `height_m` along the sun, in the
## node's own (maybe turned) frame.
func _sweep(size_m: Vector2, height_m: float) -> PackedVector2Array:
	var half := size_m * World.PX_PER_M / 2.0
	var d := (World.SUN_DIR * tan(deg_to_rad(World.SUN_TILT_DEG)) * height_m
			* World.PX_PER_M).rotated(-global_rotation)
	var points := PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		points.append(corner)
		points.append(corner + d)
	return Geometry2D.convex_hull(points)
