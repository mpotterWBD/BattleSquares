extends Node2D
## A guard watch tower (scenes/watch_tower.tscn; art by
## blender/scripts/watch_tower.py, after Mike's reference photo): a cream
## cabin on a galvanised steel deck DECK_Z up on four splayed legs, with a
## switchback stair down the east side. The node's origin is the middle of
## the deck, so the deploy ghost centres on the mouse.
##
## It's built from a watch tower crate (crate.gd, crates.py "tower") a part at
## a time, PARTS in the order they come off: the base (legs and lower
## bracing), the platform (upper bracing, deck and railing), the stairs,
## the roof (the cabin) and the details (window frames, the air conditioner,
## the searchlight, antenna and camera on the roof). Placed from DEPLOY
## (command.gd), it starts as a construction site (start_site(): `built`
## off), every part a faint green ghost of itself; the player (player.gd) or
## squadmates under a Build order (squadmate.gd) fetch each part from the
## crate and bring it here (a green F over the deck's middle when the player's
## got one it needs, within DELIVER_M), and install() puts it in. While it's
## being built it's in the "build_sites" group. A tower placed in a scene by
## hand starts built.
##
## A radio station placed over it from DEPLOY goes on it (command.gd,
## radio_station.gd mount_on(): the desk in the shelter, the dish on the
## roof); ticking the Inspector's Radio > Has Station starts it with one
## (_fit_radio(); Radio > Built off: as a site, built from a comms crate).
##
## Two levels (Mike, 2026-11-01). On the ground, squares walk under the deck
## between the legs: the legs (LegsBody) and the stair's lower flight
## (StairsBody, with the stringers either side of its foot: open at the
## front) are solid to them, the base is drawn under them and the rest
## over them; while the player's under the deck, the deck, cabin and details
## fade to UNDER_ALPHA so you can see yourself; likewise the stairs, under
## the upper flight, mid landing or top landing (UPPER_STAIRS_ABOVE). Built,
## a square walking up
## into the foot of the stair (steps_on()) is on the tower (soldier.gd
## `tower`): it's off the ground's collision layer and on UNIT_LAYER, and
## bumps only into the railings and cabin walls (WALLS, tower_walls.gd,
## WALL_LAYER), not the others up there (a stair is only one square wide, so
## two could never pass on it). Its height (height_at()) rises up the
## two flights to the deck, and it's drawn bigger the higher it is
## (soldier.gd view_scale()) and over the deck (UNIT_Z: under the roof).
## Walking back out of the stair's foot (steps_off()) it's on the ground
## again. Whenever anyone's inside the cabin the roof and the details on it
## fade to ROOF_ALPHA, and the cabin with its roof off (RoofOpen: its lit
## floor and walls, drawn with the deck under the squares) fades in,
## showing who's in there.
##
## Squadmates sent to a spot on the tower (on_surface()) take the stairs, and
## come down them to go anywhere else (route(), ai_soldier.gd _walk_to()).
##
## The legs stop every shot (with sparks) but don't hide anyone, the open
## stair stops some. The railings and cabin walls aren't hit as such; instead
## the tower's parts (PART_NAMES: base, under the deck; lower and upper
## stairs, split at the mid landing; top, the deck; shelter, the cabin;
## part_of()) each cover whoever's in them (Mike, 2026-11-01): of the shots
## at them from anywhere else, only `<part>_pass_through` % get through
## (Inspector groups Base / Lower Stairs / Upper Stairs / Top / Shelter: 75,
## 80, 80, 50, 0); the rest stop in its steel, sparks and a clang
## (cover_pass(), cover.gd tower_blocks(), bullet.gd). That share makes each
## part's cover class (part_cover_class(): the base and stairs 1 LIGHT, the
## top 2 MEDIUM, the shelter 3 HEAVY), and the AI goes by it (ai_soldier.gd
## _shielded()). Each part has its own height class too (`<part>_height_class`:
## both stairs 2, the rest 3): how high someone there fires down from, and how
## tall it is as cover for someone fired down on there from higher up.
##
## Its overlook box (Mike, 2026-11-01; `overlook_box`, drawn in debug mode):
## from inside it, someone up high on the tower (the upper stairs, the top,
## the shelter: is_up_high()) is in full view (in_full_view()): height class
## 1 and 2 cover in between (sandbags, the radio station, crates) neither
## hides them nor stops shots at them (ai_soldier.gd _clear_view(), _shielded();
## cover.gd overlook_past(), bullet.gd), so enemies there spot and shoot them,
## and only their part of the tower protects them. The shelter stops every
## shot (100% protection), but nobody can fire out of it (soldier.gd
## _sheltered()).
##
## Firing down from it (Mike, 2026-11-01): three sections round it (two circles, `section_1_radius_m` and
## `section_2_radius_m`, set in the Inspector, and section 3 everything past
## them, as far as a bullet goes; drawn round it when it's clicked in debug
## mode, Q) say how much of the shots fired by someone up here gets
## through cover lower than where they stand (its height class: sandbags and
## the radio station 1, crates and someone on another tower's stairs 2):
## where a shot meets class 1 or class 2 cover in section n, `section_<n>_class_<c>_new_pass_through`
## % of them get through (the Inspector's "Class 1 New Pass Through"; never
## less than gets through anyway; fired_down_pass(): in full from the deck,
## less lower down the stair). The bullets go by it (bullet.gd) and so does
## the AI judging whether a foe's behind heavy cover (ai_soldier.gd
## _shielded()).
##
## The shadows (one per part, in a CanvasGroup so where they overlap it's no
## darker) are rendered for the unturned tower; turned (the scroll wheel while
## placing), each is moved as if cast from its part's SHADOW_HEIGHT_M, so it
## still falls to the bottom-right (as radio_station.gd).

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const TowerWalls = preload("res://scripts/tower_walls.gd")
const Cover = preload("res://scripts/cover.gd")

## The parts, in the order they come off the crate, and their nodes:
## sprites and shadows to show, and collision bodies to switch on.
## Its parts as cover (part_of(), the Inspector groups Base / Stairs / Top / Shelter).
const PART_NAMES := ["base", "lower_stairs", "upper_stairs", "top", "shelter"]
const PARTS := ["tower_base", "tower_platform", "tower_stairs", "tower_roof", "tower_details"]
const PART_NODES := {
	"tower_base": ["Base", "Shadow/Base", "LegsBody"],
	"tower_platform": ["Platform", "Shadow/Platform"],
	"tower_stairs": ["Stairs", "Shadow/Stairs", "StairsBody"],
	"tower_roof": ["Roof", "RoofOpen", "Shadow/Roof"],
	"tower_details": ["Details", "Shadow/Details"],
}
## About how high each part's shadow is cast from, for moving it when turned.
const SHADOW_HEIGHT_M := {"Base": 1.4, "Stairs": 1.5, "Platform": 3.0, "Roof": 5.3, "Details": 4.0}
const DECK_Z := 3.0            ## the deck's height (watch_tower.py)
const MID_Z := 1.5             ## the stair's mid landing
const DECK_HALF_M := 1.45      ## the deck (and its railing), out from the middle each way
const UNDER_ALPHA := 0.35      ## the deck, cabin and details while the player's under them
## The upper stairs and top landing, seen from the ground under them (metres):
## the stairs fade while the player's under there (Mike, 2026-11-01).
const UPPER_STAIRS_ABOVE := Rect2(1.4, -1.8, 1.0, 3.8)
const ROOF_ALPHA := 0.2        ## the roof and details while anyone's in the cabin
const FADE_PER_S := 4.0
const GHOST := Color(0.55, 1.0, 0.55, 0.3)   ## a part still to come, as a faint green ghost
const DELIVER_M := 3.0         ## the player brings a part in within this far of the middle

## Up on the tower: squares' collision layer (and mask, with the walls').
const UNIT_LAYER := 32
const WALL_LAYER := 64
const UNIT_Z := 6              ## squares up on it: over the deck (5), under the roof (7)

## Where things are, in metres in the tower's frame (x right, y down: south;
## watch_tower.py has y up). The deck, the stair's top landing, its two
## flights and the mid landing between them, and the cabin with its door in
## the east wall.
const DECK := Rect2(-1.4, -1.4, 2.8, 2.8)
const TOP_LANDING := Rect2(1.4, -1.8, 1.0, 1.2)
const STAIR_X := Vector2(1.6, 2.4)          ## the stair, west and east side
const FLIGHT1_Y := Vector2(-0.6, 1.1)       ## top (deck level) to bottom (the mid landing)
const MID_Y := Vector2(1.1, 2.0)
const FLIGHT2_Y := Vector2(2.0, 4.1)        ## mid landing to the ground
const CABIN := Rect2(-1.3, -1.3, 2.0, 2.0)
const DOOR_Y := Vector2(-1.175, -0.325)
## The railings and cabin walls, as [from, to] in metres: everything round
## the deck and stair but the stair's foot (where the sides flare out, so a
## square coming up a little off the middle is guided in rather than caught
## on a corner), and the cabin but its door.
const WALLS := [
	[Vector2(-1.4, -1.4), Vector2(-1.4, 1.4)], [Vector2(-1.4, 1.4), Vector2(1.4, 1.4)],
	[Vector2(1.4, -0.6), Vector2(1.4, 1.4)], [Vector2(-1.4, -1.4), Vector2(1.4, -1.4)],
	[Vector2(1.4, -1.8), Vector2(1.4, -1.4)], [Vector2(1.4, -1.8), Vector2(2.4, -1.8)],
	[Vector2(2.4, -1.8), Vector2(2.4, 3.3)], [Vector2(1.6, -0.6), Vector2(1.6, 3.3)],
	# Near the foot the sides taper in a few cm (so nothing coming up meets the
	# blunt end of a side head-on, and nothing going down catches on a lip),
	# then flare out, funnelling anyone coming up a little off the middle in.
	[Vector2(1.6, 3.3), Vector2(1.66, 3.75)], [Vector2(2.4, 3.3), Vector2(2.34, 3.75)],
	[Vector2(1.66, 3.75), Vector2(1.2, 4.8)], [Vector2(2.34, 3.75), Vector2(2.8, 4.8)],
	[Vector2(1.4, -0.6), Vector2(1.6, -0.6)],
	[Vector2(-1.3, -1.3), Vector2(0.7, -1.3)], [Vector2(-1.3, -1.3), Vector2(-1.3, 0.7)],
	[Vector2(-1.3, 0.7), Vector2(0.7, 0.7)],
	[Vector2(0.7, -1.3), Vector2(0.7, -1.175)], [Vector2(0.7, -0.325), Vector2(0.7, 0.7)],
]
## Getting on: walking north (up the stair) with the middle in FOOT_ON, which
## reaches out past the bottom step (at 4.1) by more than half a square, so
## it's on (drawn over the stair) before any of it touches the stair. Off:
## once back out past FOOT_OFF_Y (meanwhile it's on the FOOT_APRON in front).
const FOOT_ON := Rect2(1.45, 3.55, 1.1, 1.2)
const FOOT_OFF_Y := 4.9
const FOOT_APRON := Rect2(1.1, 3.8, 1.8, 1.2)
## The way up and down for squadmates (route()).
const FOOT_OUT := Vector2(2.0, 5.2)        ## on the ground, just out past the stair's foot (FOOT_OFF_Y)
const FOOT_UP := Vector2(2.0, 3.3)         ## up into the foot (they're on the tower by then)
const ROUND_STAIR_M := 1.0                 ## coming from beside the stair, out this far to its side first
## The stair's lower flight that's solid from the ground (StairsBody, its foot's
## stringers included), in metres.
const STAIR_SOLID := Rect2(1.6, 2.0, 0.8, 2.1)
const TOP_IN := Vector2(1.95, -1.15)       ## on the top landing
const DECK_IN := Vector2(1.0, -1.0)        ## on the deck, in from the top landing
const DOOR_OUT := Vector2(1.05, -0.75)
const DOOR_IN := Vector2(0.35, -0.75)
const NEAR_M := 0.3                        ## a waypoint this close is passed
## A radio station mounted on it (radio_station.gd mount_on(); command.gd puts
## it here): its origin, in metres in the tower's frame (on the deck's north
## edge, which puts its desk along the shelter's west wall, Mike 2026-11-01),
## and its turn from the tower's.
const STATION_AT := Vector2(-0.22, -1.38)
const STATION_TURN := PI

## Building: whether it's done, the parts that are in, and the crate they come from.
@export var built := true

# Its parts, as cover for whoever's in or under them and as somewhere to fire
# down from (PART_NAMES): each a height class (cover.gd) and the share of
# shots from anywhere else that get through it to them (which makes its cover
# class: part_cover_class()).
@export_group("Base", "base_")
## Under the deck, among the legs (on the ground).
@export_range(1, 3, 1) var base_height_class := 3
## Of the shots at someone under the deck, this share gets through the steel.
@export_range(0, 100, 1, "suffix:%") var base_pass_through := 75

@export_group("Lower Stairs", "lower_stairs_")
## The lower flight, from the ground up to the mid landing. Firing down from
## it, it's from this high.
@export_range(1, 3, 1) var lower_stairs_height_class := 2
## Of the shots at someone on the lower stairs, this share gets through.
@export_range(0, 100, 1, "suffix:%") var lower_stairs_pass_through := 80

@export_group("Upper Stairs", "upper_stairs_")
## The mid landing and the upper flight up to the top. Firing down from it,
## it's from this high.
@export_range(1, 3, 1) var upper_stairs_height_class := 2
## Of the shots at someone on the upper stairs, this share gets through.
@export_range(0, 100, 1, "suffix:%") var upper_stairs_pass_through := 80

@export_group("Top", "top_")
## The deck, outside the shelter. Firing down from it, it's from this high.
@export_range(1, 3, 1) var top_height_class := 3
## Of the shots at someone on the deck, this share gets through.
@export_range(0, 100, 1, "suffix:%") var top_pass_through := 50

@export_group("Shelter", "shelter_")
## The cabin on the deck. Nobody fires out of it (soldier.gd: Mike,
## 2026-11-01), but it's as high as the top for being fired down on.
@export_range(1, 3, 1) var shelter_height_class := 3
## Of the shots at someone in the shelter, this share gets through (none:
## 100% protection).
@export_range(0, 100, 1, "suffix:%") var shelter_pass_through := 0

@export_group("Overlook", "overlook_")
## The box round the tower, in metres in its frame (x right, y down, from the
## deck's middle; drawn in debug mode, Q). From inside it, someone up high on
## the tower (the upper stairs, the top or the shelter: is_up_high()) is seen,
## and shot at, past height class 1 and 2 cover (sandbags, the radio station,
## crates): only the tower protects them (in_full_view()).
@export var overlook_box := Rect2(-6.0, -4.0, 14.5, 13.0)

# (Each group's prefix is left off in the Inspector: "Radius M", "Class 1 New Pass Through".)
@export_group("Section 1", "section_1_")
## The nearest circle: out to this far from the tower's middle.
@export_range(0.0, 60.0, 0.5, "suffix:m") var section_1_radius_m := 5.0
## Fired down from up here at class 1 cover (sandbags, the radio station) in
## this section, this share of the shots gets through it (sandbags let 10%
## through from the ground). Never less than the cover lets through anyway.
@export_range(0, 100, 1, "suffix:%") var section_1_class_1_new_pass_through := 78
## The same for class 2 cover (crates: none gets through from the ground).
@export_range(0, 100, 1, "suffix:%") var section_1_class_2_new_pass_through := 50

@export_group("Section 2", "section_2_")
## Out to this far from the tower's middle (from section 1's edge).
@export_range(0.0, 60.0, 0.5, "suffix:m") var section_2_radius_m := 10.0
## The share of shots fired down from up here that gets through class 1 cover
## (sandbags, the radio station) in this section.
@export_range(0, 100, 1, "suffix:%") var section_2_class_1_new_pass_through := 55
## The same for class 2 cover (crates).
@export_range(0, 100, 1, "suffix:%") var section_2_class_2_new_pass_through := 25

@export_group("Section 3", "section_3_")
## (No radius: it's everything past section 2, as far as a bullet goes.)
## The share of shots fired down from up here that gets through class 1 cover
## (sandbags, the radio station) in this section.
@export_range(0, 100, 1, "suffix:%") var section_3_class_1_new_pass_through := 33
## The same for class 2 cover (crates).
@export_range(0, 100, 1, "suffix:%") var section_3_class_2_new_pass_through := 10

@export_group("Radio", "radio_")
## Starts with a radio station fitted (the desk in the shelter, the dish on
## the roof), as if one had been placed on it from DEPLOY (radio_station.gd
## mount_on()). Only on a tower that's built.
@export var radio_has_station := false
## That station is ready to use. Unticked, it starts as a site, its parts to
## be carried up from the nearest comms crate with a station's worth left.
@export var radio_built := true

@export_group("")
var installed: Array[String] = []
var site_crate: Node2D = null
var _deliver_key: Label
var _walls: StaticBody2D
var _upper := 1.0              ## the deck, cabin and details' alpha (fading while the player's under them)
var _open := 0.0               ## how far the roof's faded off the cabin (1 while anyone's in it)
var _stairs := 1.0             ## the stairs' alpha (fading while the player's under the upper ones)
## The radio station mounted on it, if any (command.gd).
var station: Node2D = null


func _ready() -> void:
	if process_mode != Node.PROCESS_MODE_DISABLED:   # not a placing ghost (command.gd): nobody climbs that
		add_to_group("watch_towers")
	_deliver_key = UiStyle.pad_key("F", Color(World.COMMAND_COLOR, 0.55))
	_deliver_key.z_as_relative = false
	_deliver_key.z_index = 30
	_deliver_key.visible = false   # (_process() shows it; a placing ghost doesn't run)
	add_child(_deliver_key)
	if process_mode != Node.PROCESS_MODE_DISABLED:   # not a placing ghost (command.gd)
		_make_walls()
	# The legs and stair as cover in their own right take their parts' height classes.
	$LegsBody.height_class = base_height_class
	$StairsBody.height_class = lower_stairs_height_class   # (the lower flight)
	_show_parts()
	set_notify_transform(true)
	_place_shadows()
	if radio_has_station and built and process_mode != Node.PROCESS_MODE_DISABLED:
		_fit_radio.call_deferred()   # (the level's still adding its children, crates included)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		_place_shadows()


## Keeps each shadow falling bottom-right however the tower's turned: the
## images are the unturned tower's, so undo each one's sun offset in the
## tower's frame and redo it in the world's.
func _place_shadows() -> void:
	for part: String in SHADOW_HEIGHT_M:
		var d: Vector2 = World.SUN_DIR * tan(deg_to_rad(World.SUN_TILT_DEG)) * SHADOW_HEIGHT_M[part] * World.PX_PER_M
		get_node("Shadow/" + part).position = d.rotated(-global_rotation) - d


func _make_walls() -> void:
	_walls = TowerWalls.new()
	_walls.name = "Walls"
	_walls.collision_layer = WALL_LAYER
	_walls.collision_mask = 0
	add_child(_walls)
	var px := World.PX_PER_M
	for wall in WALLS:
		var a: Vector2 = wall[0] * px
		var b: Vector2 = wall[1] * px
		# A line, not a thin box: no corners or end caps to catch on where one
		# meets the next (they snagged squares at the stair's foot).
		var line := SegmentShape2D.new()
		line.a = a
		line.b = b
		var shape := CollisionShape2D.new()
		shape.shape = line
		_walls.add_child(shape)


func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	_deliver_key.visible = (not built and player != null and player.carrying != "" and needs(player.carrying)
			and can_deliver_at(player.global_position) and player.interact_target() == self)
	_deliver_key.rotation = -global_rotation   # upright however the tower's turned
	_deliver_key.position = (-_deliver_key.size / 2.0).rotated(-global_rotation)
	var under: bool = (player != null and player.visible and player.tower == null
			and DECK.grow(0.05).has_point(_metres(player.global_position)))
	_upper = move_toward(_upper, UNDER_ALPHA if under else 1.0, FADE_PER_S * delta)
	var under_stairs: bool = (player != null and player.visible and player.tower == null
			and UPPER_STAIRS_ABOVE.grow(0.05).has_point(_metres(player.global_position)))
	_stairs = move_toward(_stairs, UNDER_ALPHA if under_stairs else 1.0, FADE_PER_S * delta)
	$Stairs.self_modulate.a = _stairs
	_open = move_toward(_open, 1.0 if _anyone_in_cabin() else 0.0, FADE_PER_S * delta)
	var roof := lerpf(1.0, ROOF_ALPHA, _open)
	$Platform.self_modulate.a = _upper
	$RoofOpen.self_modulate.a = minf(_upper, _open)
	$Roof.self_modulate.a = minf(_upper, roof)
	$Details.self_modulate.a = minf(_upper, roof)
	if station and is_instance_valid(station):   # its dish on the roof fades with it
		station.fade_dish(minf(_upper, roof))


## Whether a live square up on this tower is inside the cabin.
func _anyone_in_cabin() -> bool:
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if unit.get("tower") == self and not unit.dead and CABIN.has_point(_metres(unit.global_position)):
			return true
	return false


## World `point` in the tower's frame, in metres.
func _metres(point: Vector2) -> Vector2:
	return to_local(point) / World.PX_PER_M


# ------------------------------------------------------- firing down from it --

## The three sections, nearest first: [radius m, class 1 new pass-through,
## class 2 new pass-through] (0..1).
func sections() -> Array:
	return [
		[section_1_radius_m, section_1_class_1_new_pass_through / 100.0, section_1_class_2_new_pass_through / 100.0],
		[section_2_radius_m, section_2_class_1_new_pass_through / 100.0, section_2_class_2_new_pass_through / 100.0],
		[INF, section_3_class_1_new_pass_through / 100.0, section_3_class_2_new_pass_through / 100.0],   # out as far as a bullet goes
	]


## The share (0..1) of shots fired from up here, by someone standing
## `elevation_m` up on a part of height class `from_height`, that get through
## cover of height class `cls` where they meet it at world `point`, given it
## lets `normal` through from the ground: its section's new pass-through for
## that class (never less than `normal`), in full from the deck and less the
## lower down the stair; just `normal` for cover as tall as where they stand.
func fired_down_pass(cls: int, point: Vector2, normal: float, elevation_m: float, from_height: int) -> float:
	if cls >= from_height:
		return normal
	var d := global_position.distance_to(point) / World.PX_PER_M
	for section: Array in sections():
		if d <= section[0]:
			var through: float = section[1] if cls <= 1 else section[2]
			return lerpf(normal, maxf(normal, through), clampf(elevation_m / DECK_Z, 0.0, 1.0))
	return normal


## Which part of the tower `unit` is in, as cover goes: "base" (on the ground
## under the deck), "lower_stairs" (the lower flight), "upper_stairs" (the mid
## landing and the upper flight), "top" (the deck
## outside the shelter, and the stair's top landing level with it) or
## "shelter"; "" if none.
func part_of(unit: Node) -> String:
	if not built or unit == null or not is_instance_valid(unit) or not unit is Node2D:
		return ""
	var m := _metres(unit.global_position)
	if unit.get("tower") == self:
		if _in_cabin(m):
			return "shelter"
		return _stair_part(m)
	if unit.get("tower") == null and DECK.has_point(m):
		return "base"
	return ""


## Which part is at world `point` seen from above (debug picking): the
## shelter, the top, or the upper or lower stairs; "" off the tower. (The base is under the
## top: debug_overlay.gd picks it by its legs.)
func part_at(point: Vector2) -> String:
	if not on_surface(point):
		return ""
	var m := _metres(point)
	if _in_cabin(m):
		return "shelter"
	return _stair_part(m)


## `part`'s height class and the share (0..1) of shots that get through it to
## whoever's in it (its Inspector group).
func part_height_class(part: String) -> int:
	return get(part + "_height_class") if part in PART_NAMES else 0


func part_pass(part: String) -> float:
	return get(part + "_pass_through") / 100.0 if part in PART_NAMES else 1.0


## `part`'s cover class (cover.gd) for whoever's in it, from how much it stops.
func part_cover_class(part: String) -> int:
	return Cover.class_for(1.0 - part_pass(part))


## How high (height class) `unit` is firing down from: its part's; 0 if it
## isn't up on the tower.
func height_class_of_unit(unit: Node) -> int:
	if unit == null or unit.get("tower") != self:
		return 0
	return part_height_class(part_of(unit))


## The share (0..1) of `shooter`'s shots that get through the tower's steel
## to `target` in it (its part's `<part>_pass_through`), more if the shooter's
## firing down on it from higher up (on this or another tower: that one's
## sections, with the part's height class); all of them if the target isn't
## in or under it, or the shooter's in the same part (both on the top).
func cover_pass(target: Node, shooter: Node) -> float:
	var part := part_of(target)
	if part == "" or (shooter != null and part_of(shooter) == part):
		return 1.0
	var through := part_pass(part)
	var from = shooter.get("tower") if shooter != null and is_instance_valid(shooter) else null
	if from != null and is_instance_valid(from):
		through = from.fired_down_pass(part_height_class(part), target.global_position, through,
				shooter.elevation_m, from.height_class_of_unit(shooter))
	return through


## Whether `unit` is on the stairs (either flight or the mid landing).
func on_stairs(unit: Node) -> bool:
	return part_of(unit) in ["lower_stairs", "upper_stairs"]


## Just outside the shelter's door, on the deck (world).
func door_out() -> Vector2:
	return to_global(DOOR_OUT * World.PX_PER_M)


## On the deck, just in from the stair's top landing (world).
func deck_in() -> Vector2:
	return to_global(DECK_IN * World.PX_PER_M)


## Whether `unit` is up high on the tower: on the upper stairs, the top or in
## the shelter.
func is_up_high(unit: Node) -> bool:
	return part_of(unit) in ["upper_stairs", "top", "shelter"]


## Whether world `point` is inside the overlook box.
func overlooks(point: Vector2) -> bool:
	return overlook_box.has_point(_metres(point))


## Whether, seen or shot at from world `from`, `unit` has only the tower to
## protect it, with height class 1 and 2 cover in between not counting: it's
## up high here and `from` is in the overlook box.
func in_full_view(unit: Node, from: Vector2) -> bool:
	return is_up_high(unit) and overlooks(from)


## Which section (1..3) world `point` is in (3: anywhere past section 2).
func section_at(point: Vector2) -> int:
	var d := global_position.distance_to(point) / World.PX_PER_M
	var all := sections()
	for i in all.size():
		if d <= all[i][0]:
			return i + 1
	return 0


# ------------------------------------------------------------- the levels --

## Whether a square on the ground at world `at`, moving at `velocity`, steps
## onto the stair here: it's built, and the square is walking up into its foot.
func steps_on(at: Vector2, velocity: Vector2) -> bool:
	if not built:
		return false
	var heading := velocity.rotated(-global_rotation)
	return FOOT_ON.has_point(_metres(at)) and heading.y < -1.0


## Whether a square up on the tower at world `at` has walked back off it,
## out of the stair's foot (or it's somehow off its outline, or the tower's gone).
func steps_off(at: Vector2) -> bool:
	var m := _metres(at)
	return not built or m.y > FOOT_OFF_Y or not (on_surface(at, 0.3) or FOOT_APRON.has_point(m))


## Whether world `at` is on the deck, the stair's top landing, flights or mid
## landing (`slack` metres out from their edges counts).
func on_surface(at: Vector2, slack := 0.0) -> bool:
	var m := _metres(at)
	var stair := Rect2(STAIR_X.x, FLIGHT1_Y.x, STAIR_X.y - STAIR_X.x, FLIGHT2_Y.y - FLIGHT1_Y.x)
	return DECK.grow(slack).has_point(m) or TOP_LANDING.grow(slack).has_point(m) or stair.grow(slack).has_point(m)


## How high (metres) someone up on the tower at world `at` stands: up the
## lower flight to the mid landing, up the upper flight to the deck.
func height_at(at: Vector2) -> float:
	var m := _metres(at)
	if m.x < STAIR_X.x - 0.1 or m.y < FLIGHT1_Y.x:
		return DECK_Z   # the deck or the top landing
	if m.y < FLIGHT1_Y.y:
		return lerpf(DECK_Z, MID_Z, (m.y - FLIGHT1_Y.x) / (FLIGHT1_Y.y - FLIGHT1_Y.x))
	if m.y < MID_Y.y:
		return MID_Z
	return clampf(lerpf(MID_Z, 0.0, (m.y - FLIGHT2_Y.x) / (FLIGHT2_Y.y - FLIGHT2_Y.x)), 0.0, MID_Z)


## Where a square at world `from` heads next (world) on its way to world
## `goal`: `on` whether it's up on this tower now, `goal_on` whether the goal
## is. Up: to the stair's foot, up the flights, onto the deck, in at the
## door; down the same way back. Straight to the goal once nothing's between.
func route(from: Vector2, on: bool, goal: Vector2, goal_on: bool) -> Vector2:
	var f := _metres(from)
	var g := _metres(goal)
	var next := g
	if not on:   # on the ground, going up
		var lined_up := absf(f.x - FOOT_OUT.x) < 0.45 and f.y > FLIGHT2_Y.y + 0.1   # in front of the foot
		if lined_up:
			next = FOOT_UP
		elif f.y < FOOT_OUT.y - 0.3:   # north of it (beside the stair, under the deck): round the stair's side first
			next = Vector2(FOOT_OUT.x + (-ROUND_STAIR_M if f.x < FOOT_OUT.x else ROUND_STAIR_M), FOOT_OUT.y)
		else:
			next = FOOT_OUT
	elif _in_cabin(f) and not (goal_on and _in_cabin(g)):   # out of the cabin, through the door
		next = DOOR_OUT if _lined_up(f) else DOOR_IN
	elif _on_stair(f):
		var in_line := absf(f.x - (STAIR_X.x + STAIR_X.y) / 2.0) < 0.2   # lined up with the flights
		var going_down := not goal_on or (_on_stair(g) and g.y > FLIGHT1_Y.x)
		if going_down and f.y < FLIGHT1_Y.x and not in_line:
			next = TOP_IN   # on the top landing off to one side: to its middle first, or it walks into the stair's corner
		elif not goal_on:
			next = FOOT_OUT   # down and off
		elif not _on_stair(g):   # up onto the deck, in from the top landing
			next = TOP_IN if f.y > TOP_IN.y + NEAR_M else DECK_IN
	else:   # on the deck, outside the cabin
		var target := g
		if not goal_on or _on_stair(g):   # out onto the top landing
			target = TOP_IN if f.y < FLIGHT1_Y.x and f.x > CABIN.end.x else DECK_IN
		elif _in_cabin(g) and not _in_cabin(f):   # in at the door, lined up with it first
			target = DOOR_IN if _lined_up(f) and f.x < DOOR_OUT.x + NEAR_M else DOOR_OUT
		next = _deck_step(f, target)
	if next == g:
		return goal
	return to_global(next * World.PX_PER_M)


## Where a square on the ground heads next on the way to world `goal` off
## the tower: if the straight way there runs into the stair's solid lower
## flight (STAIR_SOLID), round the front of its foot: to the corner on its own
## side (ROUND_STAIR_M out), then across to the goal's side if need be. Just `goal` otherwise, a spot just in front of
## the foot included (Mike's log 08:15: one sent to dig in there was sent
## round the stair's side and back, over and over).
func leave_way(from: Vector2, goal: Vector2) -> Vector2:
	var f := _metres(from)
	var g := _metres(goal)
	if not built or not _crosses(f, g, STAIR_SOLID.grow(0.2)):
		return goal
	# Beside or behind the stair: to the corner on its own side; out in front of
	# the foot: to the one on the goal's side (it's then clear to go straight).
	var by := g.x if f.y > STAIR_SOLID.end.y + 0.2 else f.x
	var side := -1.0 if by < FOOT_OUT.x else 1.0
	return to_global(Vector2(FOOT_OUT.x + side * ROUND_STAIR_M, FOOT_OUT.y) * World.PX_PER_M)


## Whether the straight line from `a` to `b` (metres) passes through `rect`.
static func _crosses(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	for i in 21:
		if rect.has_point(a.lerp(b, i / 20.0)):
			return true
	return false


## On the deck, round the cabin: the walkways are along its east and south
## sides, so between them it's by way of the south-east corner.
func _deck_step(f: Vector2, target: Vector2) -> Vector2:
	var corner := Vector2(DOOR_OUT.x, (CABIN.end.y + DECK.end.y) / 2.0)
	var f_south := f.y > CABIN.end.y
	var t_south := target.y > CABIN.end.y
	if f_south != t_south and (f.x < CABIN.end.x + 0.15 or target.x < CABIN.end.x + 0.15):
		return corner
	# Along the east walkway (it's narrow, past the shelter's corner): out to its
	# middle first, rather than cutting along the shelter's wall.
	if not f_south and f.x > CABIN.end.x - 0.1 and absf(f.x - corner.x) > 0.12 and absf(target.y - f.y) > 0.4:
		return Vector2(corner.x, f.y)
	return target


## Inside or just outside the cabin, square on to its door (it'll go through).
func _lined_up(m: Vector2) -> bool:
	return m.y > DOOR_Y.x + 0.12 and m.y < DOOR_Y.y - 0.12


func _on_deck(m: Vector2) -> bool:
	return m.x < DECK.end.x - 0.05


func _on_stair(m: Vector2) -> bool:
	return not _on_deck(m)   # the top landing, flights and mid landing


## On the flights or the mid landing (the stairs as a part); the top landing,
## level with the deck, is part of the top.
func _on_flights(m: Vector2) -> bool:
	return _on_stair(m) and m.y > FLIGHT1_Y.x


## Out of the cabin, which part `m` is on: "lower_stairs" (the lower flight),
## "upper_stairs" (the mid landing and the upper flight), or "top" (the deck
## and the top landing).
func _stair_part(m: Vector2) -> String:
	if not _on_flights(m):
		return "top"
	return "lower_stairs" if m.y > MID_Y.y else "upper_stairs"


func _in_cabin(m: Vector2) -> bool:
	return CABIN.has_point(m)


## Whether a radio station can go on it now: built, with none on it yet.
func can_mount_station() -> bool:
	return built and (station == null or not is_instance_valid(station))


## Fits it with a radio station at the start (`radio_has_station`): built, or
## (`radio_built` off) a site using the nearest comms crate that can set one
## up. With no such crate it's put up built anyway, with a warning.
func _fit_radio() -> void:
	if not can_mount_station():
		return
	var radio: Node2D = load("res://scenes/radio_station.tscn").instantiate()
	radio.name = name + "Radio"
	radio.mount_on(self)
	var spot := station_spot()
	radio.position = spot.pos
	radio.rotation = spot.turn
	radio.add_to_group("deployed_radio_station")
	station = radio
	var crate: Node2D = null
	if not radio_built:
		for c: Node2D in get_tree().get_nodes_in_group("crates"):
			if c.builds == "radio_station" and c.can_set_up() and (crate == null
					or c.global_position.distance_to(global_position) < crate.global_position.distance_to(global_position)):
				crate = c
		if crate == null:
			push_warning("%s: Radio Built is off but there's no comms crate to build it from; it starts built." % name)
	get_parent().add_child(radio)
	if crate:
		radio.start_site(crate)


## Where a radio station mounted on it goes (world), and its turn.
func station_spot() -> Dictionary:
	return {pos = to_global(STATION_AT * World.PX_PER_M), turn = global_rotation + STATION_TURN}


# -------------------------------------------------------------- building --

## Starts it as a construction site, its parts to come from `crate`.
func start_site(crate: Node2D) -> void:
	built = false
	installed.clear()
	site_crate = crate
	crate.reserve(self, PARTS.size())
	add_to_group("build_sites")
	_show_parts()


## Whether it still needs `part`.
func needs(part: String) -> bool:
	return not built and part in PARTS and not part in installed


## Whether the player at `at` (world) can bring a part in here.
func can_deliver_at(at: Vector2, _who: Node = null) -> bool:
	return not built and at.distance_to(global_position) <= DELIVER_M * World.PX_PER_M


## A part's been brought in: it goes in; with all of them in, it's built.
func install(part: String) -> void:
	if not needs(part):
		return
	installed.append(part)
	if installed.size() == PARTS.size():
		built = true
		remove_from_group("build_sites")
	_show_parts()


## Shows the parts that are in as they are, the rest as faint ghosts (no
## shadows, not solid). The railings and cabin walls only once it's built.
func _show_parts() -> void:
	for part: String in PART_NODES:
		var done := built or part in installed
		for node_name: String in PART_NODES[part]:
			var node := get_node(node_name)
			if node is CollisionObject2D:
				for shape in node.get_children():
					if shape is CollisionShape2D:
						shape.set_deferred("disabled", not done)
			elif node_name.begins_with("Shadow/"):
				node.visible = done
			else:
				node.modulate = Color.WHITE if done else GHOST
	if _walls:
		for shape in _walls.get_children():
			shape.set_deferred("disabled", not built)
