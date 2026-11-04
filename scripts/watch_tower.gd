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
## at them from anywhere else, only their part's pass-through gets through
## (75, 80, 80, 50, 0%); the rest stop in its steel, sparks and a clang
## (cover_pass(), cover.gd tower_blocks(), bullet.gd). That share makes each
## part's cover class (part_cover_class(): the base and stairs 1 LIGHT, the
## top 2 MEDIUM, the shelter 3 HEAVY), and the AI goes by it (ai_soldier.gd
## _shielded()). The shelter stops every shot, but nobody can fire out of it
## (soldier.gd _sheltered()).
##
## Height (Mike, 2026-11-02): the parts you stand on each have a height
## profile (height_profile.gd, in the Inspector: Lower Stairs, Upper Stairs,
## Top, Shelter; files in assets/height_profiles/): its height class (both
## stairs 2, the top and shelter 3), its pass-through, and two lists of
## sections round that part's own middle (part_middle()), nearest first
## (drawn round it when the part's clicked in debug mode, Q):
##   - Shots Away: firing from up there, past cover as high as where they
##     stand or lower, by how far that cover is from the part: how much gets
##     through, by its height class (cover.gd height_extra(), bullet.gd).
##   - Shots Into: shot at up there, by how far the shooter is from the part:
##     the part's pass-through for shots from that far (part_pass_from(),
##     cover_pass(): easier to hit them from close up), and whether low cover
##     hides them from there (Seen: cover.gd seen_past()).
## Each part's profile counts the same all over it (flat, no slope up the
## stairs). The AI goes by them too, judging whether a foe's behind heavy
## cover or in view (ai_soldier.gd _shielded(), _clear_view()). The base (the ground under the
## deck) has no profile, just its height class and pass-through.
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
## Up on these a square fires, and looks, at the cabin's height (up_high()).
const HIGH_PARTS := ["top", "shelter", "upper_stairs"]
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
## on a corner), and the cabin but its door. Split, since a body can go over
## a railing but not through the cabin's wall (wall_near(), death_fall.gd).
const RAILS := [
	[Vector2(-1.4, -1.4), Vector2(-1.4, 1.4)], [Vector2(-1.4, 1.4), Vector2(1.4, 1.4)],
	[Vector2(1.4, -0.6), Vector2(1.4, 1.4)], [Vector2(-1.4, -1.4), Vector2(1.4, -1.4)],
	[Vector2(1.4, -1.8), Vector2(1.4, -1.4)], [Vector2(1.4, -1.8), Vector2(2.4, -1.8)],
	[Vector2(2.4, -1.8), Vector2(2.4, 4.1)], [Vector2(1.6, -0.6), Vector2(1.6, 4.1)],
	# The sides run straight to the bottom step, then flare out, funnelling
	# anyone coming up a little off the middle in. (They used to taper in a few
	# cm first, a bump going down: Mike, 2026-11-02. As lines meeting end to
	# end there's no lip or corner to catch on without it.)
	[Vector2(1.6, 4.1), Vector2(1.2, 4.8)], [Vector2(2.4, 4.1), Vector2(2.8, 4.8)],
	[Vector2(1.4, -0.6), Vector2(1.6, -0.6)],
]
const CABIN_WALLS := [
	[Vector2(-1.3, -1.3), Vector2(0.7, -1.3)], [Vector2(-1.3, -1.3), Vector2(-1.3, 0.7)],
	[Vector2(-1.3, 0.7), Vector2(0.7, 0.7)],
	[Vector2(0.7, -1.3), Vector2(0.7, -1.175)], [Vector2(0.7, -0.325), Vector2(0.7, 0.7)],
]
const WALLS := RAILS + CABIN_WALLS
## Getting on: walking north (up the stair) with the middle in FOOT_ON, which
## reaches out past the bottom step (at 4.1) by more than half a square, so
## it's on (drawn over the stair) before any of it touches the stair. Off:
## once back out past FOOT_OFF_Y (meanwhile it's on the FOOT_APRON in front),
## or, walking down, as soon as it's clear of the bottom step (FOOT_CLEAR_Y), so
## the foot's flared guides don't steer one turning off it (Mike, 2026-11-02:
## an invisible curve at the end of the ramp).
const FOOT_ON := Rect2(1.45, 3.55, 1.1, 1.2)
const FOOT_OFF_Y := 4.9
const FOOT_CLEAR_Y := 4.35     ## the bottom step (4.1) plus half a square and a little
## The foot's flared guides (WALLS) widen this much each side per metre out past
## the bottom step. A square only steps on wholly between them (_in_funnel()):
## one stepping on across a flare, coming at the foot slantwise from beside it,
## ended up on the tower outside the stair's side (Mike, 2026-11-02).
const FLARE_PER_M := 0.4 / 0.7
const UNIT_HALF_M := 0.2       ## half a square (soldier.gd SIZE_M)
const FOOT_APRON := Rect2(1.1, 3.8, 1.8, 1.2)
## Down by the stair's foot its rails are below a square's head (the flight's
## under 0.8 m up south of 3.0 m), so a square on the ground beside or in
## front of it (FOOT_OVER: within a turned square's reach of its sides) is
## drawn over the stairs, at GROUND_OVER_FOOT_Z (Mike, 2026-11-02: a rail end
## drawn on top of him); anywhere else on the ground it's under them.
const FOOT_OVER := Rect2(1.25, 3.0, 1.5, 2.0)
const GROUND_OVER_FOOT_Z := 5
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
## Where a squadmate sent up here can stand (Mike, 2026-11-02): the top
## landing, the east walkway from its north end past the door, the south
## walkway, the mid landing, and in the shelter. Sent anywhere else up here
## (the flights, the walkway between the door and the shelter's south-east
## corner), it goes to the nearest of these (stay_spots()).
const STAY_AREAS := [
	Rect2(1.4, -1.8, 1.0, 1.2),    # the top landing
	Rect2(0.7, -1.4, 0.7, 1.1),    # the east walkway, from its north end past the door
	Rect2(-1.4, 0.7, 2.8, 0.7),    # the south walkway
	Rect2(1.6, 1.1, 0.8, 0.9),     # the mid landing
	CABIN,                         # in the shelter (only for a spot in it: it's walled off)
]
const STAY_PITCH_M := 0.45     ## squadmates sent up here together stand this far apart (a square and a little)
## A radio station mounted on it (radio_station.gd mount_on(); command.gd puts
## it here): its origin, in metres in the tower's frame (on the deck's north
## edge, which puts its desk along the shelter's west wall, Mike 2026-11-01),
## and its turn from the tower's.
const STATION_AT := Vector2(-0.22, -1.38)
const STATION_TURN := PI

## Building: whether it's done, the parts that are in, and the crate they come from.
@export var built := true

# Its parts, as cover for whoever's in or under them and as somewhere to fire
# from (PART_NAMES).
@export_group("Base", "base_")
## Under the deck, among the legs (on the ground).
@export_range(1, 3, 1) var base_height_class := 3
## Of the shots at someone under the deck, this share gets through the steel.
@export_range(0, 100, 1, "suffix:%") var base_pass_through := 75

@export_group("Height Profiles")
## The lower flight, from the ground up to the mid landing (height_profile.gd).
@export var lower_stairs: HeightProfile = preload("res://assets/height_profiles/watch_tower_lower_stairs.tres")
## The mid landing and the upper flight up to the top.
@export var upper_stairs: HeightProfile = preload("res://assets/height_profiles/watch_tower_upper_stairs.tres")
## The deck, outside the shelter, and the stair's top landing.
@export var top: HeightProfile = preload("res://assets/height_profiles/watch_tower_top.tres")
## The cabin on the deck (nobody fires out of it: its Shots Away don't count).
@export var shelter: HeightProfile = preload("res://assets/height_profiles/watch_tower_shelter.tres")

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
## Run from the editor, its profile files are watched for saves (live tuning):
## when each was last saved, and the countdown to the next look.
var _profile_saved := {}
var _profile_look_s := 0.0
const PROFILE_LOOK_S := 1.0
const PROFILE_PARTS := ["lower_stairs", "upper_stairs", "top", "shelter"]


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
	_apply_stair_profile()
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
	_walls.rail_count = RAILS.size()   # (its shapes are WALLS in order: the railings, then the cabin's walls)
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
	if OS.has_feature("editor"):
		_reload_saved_profiles(delta)
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


## Live tuning (Mike, 2026-11-02): the game run from the editor has its own
## copy of the height profiles, so an edit in the editor's Inspector doesn't
## reach it. Every PROFILE_LOOK_S it looks at each profile's file, and one
## that's been saved since (Ctrl+S, or the Inspector's save) is loaded afresh.
## (A profile made unique to this tower lives in the scene: not watched.)
func _reload_saved_profiles(delta: float) -> void:
	_profile_look_s -= delta
	if _profile_look_s > 0.0:
		return
	_profile_look_s = PROFILE_LOOK_S
	for part: String in PROFILE_PARTS:
		var profile: HeightProfile = get(part)
		if profile == null or not profile.resource_path.begins_with("res://") or "::" in profile.resource_path:
			continue
		var path := profile.resource_path
		var saved := FileAccess.get_modified_time(path)
		if not _profile_saved.has(path):
			_profile_saved[path] = saved
		elif saved != _profile_saved[path]:
			_profile_saved[path] = saved
			var fresh = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
			if fresh is HeightProfile:
				for other in get_tree().get_nodes_in_group("watch_towers"):   # every tower sharing it
					for p: String in PROFILE_PARTS:
						var theirs: HeightProfile = other.get(p)
						if theirs != null and theirs.resource_path == path:
							other.set(p, fresh)
				print("%s: reloaded %s" % [name, path.get_file()])
	_apply_stair_profile()


## The lower flight as something in the way (StairsBody, partial_cover.gd: a
## shot at anyone or anything past it) goes by the lower stairs' profile too:
## its height class, and its Pass Through is the share of shots that get
## through it (Mike, 2026-11-02: at 0%, he could still shoot through the stair).
func _apply_stair_profile() -> void:
	if lower_stairs == null:
		return
	$StairsBody.height_class = lower_stairs.height_class
	$StairsBody.hit_chance = 1.0 - lower_stairs.pass_through / 100.0


## Whether a live square up on this tower is inside the cabin.
func _anyone_in_cabin() -> bool:
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if unit.get("tower") == self and not unit.dead and CABIN.has_point(_metres(unit.global_position)):
			return true
	return false


## World `point` in the tower's frame, in metres.
func _metres(point: Vector2) -> Vector2:
	return to_local(point) / World.PX_PER_M


# ------------------------------------------------------- height profiles --

## `part`'s height profile (height_profile.gd): null for the base (the ground
## under the deck) or none.
func profile_for(part: String) -> HeightProfile:
	return get(part) if part in PART_NAMES and part != "base" else null


## The middle of `part` (world), which its profile's sections are measured
## from (Mike, 2026-11-02: each part's own, not the tower's): the lower and
## upper stairs' flights (the upper with the mid landing), the deck, the
## cabin; the tower's middle for the base or none.
func part_middle(part: String) -> Vector2:
	var stair_x := (STAIR_X.x + STAIR_X.y) / 2.0
	var m := Vector2.ZERO
	match part:
		"lower_stairs":
			m = Vector2(stair_x, (FLIGHT2_Y.x + FLIGHT2_Y.y) / 2.0)
		"upper_stairs":
			m = Vector2(stair_x, (FLIGHT1_Y.x + MID_Y.y) / 2.0)
		"top":
			m = DECK.get_center()
		"shelter":
			m = CABIN.get_center()
	return to_global(m * World.PX_PER_M)


## The height profile of where `unit` stands up on this tower (null if it isn't).
func profile_of(unit: Node) -> HeightProfile:
	if unit == null or not is_instance_valid(unit) or unit.get("tower") != self:
		return null
	return profile_for(part_of(unit))


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
## whoever's in it (the base's Inspector group; the rest, their profiles).
func part_height_class(part: String) -> int:
	if part == "base":
		return base_height_class
	var profile := profile_for(part)
	return profile.height_class if profile else 0


func part_pass(part: String) -> float:
	if part == "base":
		return base_pass_through / 100.0
	var profile := profile_for(part)
	return profile.pass_through / 100.0 if profile else 1.0


## The share (0..1) of shots by `shooter` that get through `part` to whoever's
## in it: its profile's Shots Into section for how far the shooter is from the
## part's middle (Mike, 2026-11-02: easier to hit them from close up), or its
## Pass Through with no sections or no shooter.
func part_pass_from(part: String, shooter: Node) -> float:
	var profile := profile_for(part)
	if profile == null or profile.shots_into.is_empty() or shooter == null or not is_instance_valid(shooter):
		return part_pass(part)
	var section := profile.into_section(part_middle(part).distance_to(shooter.global_position) / World.PX_PER_M)
	return section.pass_through / 100.0 if section else part_pass(part)


## Whether a shot fired from world `from`, high or low by `roll` (0..1, as
## it was fired: bullet.gd), passes `unit` by (Mike, 2026-11-02): `unit` on a
## part here and the shot below it, or on the ground under a part here and the
## shot above it, by that part's Shots Into section for how far away `from`
## is (its Above %: under it, the shot's above). False with no sections, and
## for a shot by `shooter` up here too at `unit` up here: it's fired at their
## level, so it's neither (Mike, 2026-11-03: shots at someone on the top
## beside him went through them).
func passes_by(unit: Node, from: Vector2, roll: float, shooter: Node = null) -> bool:
	if not built or unit == null or not is_instance_valid(unit) or not unit is Node2D:
		return false
	var on: bool = unit.get("tower") == self
	if on and shooter != null and is_instance_valid(shooter) and shooter.get("tower") == self:
		return false
	var part := part_of(unit) if on else (part_above(unit.global_position) if unit.get("tower") == null else "")
	var share := above_share(part, from)
	if share < 0.0:
		return false
	var high := roll < share
	return not high if on else high


## Of the shots fired from world `from`, the share (0..1) that go above
## `part`: its Shots Into section for that distance; -1 with none.
func above_share(part: String, from: Vector2) -> float:
	var profile := profile_for(part)
	if profile == null or profile.shots_into.is_empty():
		return -1.0
	var section := profile.into_section(part_middle(part).distance_to(from) / World.PX_PER_M)
	return section.above / 100.0 if section else -1.0


## The part of the tower over world `point` on the ground (someone under it):
## the shelter over the cabin's floor, the top over the deck and the stair's
## top landing, the upper stairs over the upper flight and mid landing; ""
## elsewhere (the lower flight's solid to the ground: nobody's under it).
func part_above(point: Vector2) -> String:
	if not built:
		return ""
	var m := _metres(point)
	if CABIN.has_point(m):
		return "shelter"
	if DECK.has_point(m) or TOP_LANDING.has_point(m):
		return "top"
	if Rect2(STAIR_X.x, FLIGHT1_Y.x, STAIR_X.y - STAIR_X.x, MID_Y.y - FLIGHT1_Y.x).has_point(m):
		return "upper_stairs"
	return ""


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
## to `target` in it (its part's pass-through for how far away the shooter
## is: part_pass_from()), more if the shooter's firing
## from higher up (on this or another tower: the Shots Away of where it
## stands, with the part's height class: cover.gd away_pass()); all of them
## if the target isn't in or under it, or the shooter's in the same part
## (both on the top). None into the shelter, from anywhere, whatever its
## profile or the shooter's Shots Away say (Mike, 2026-11-03); only shots
## flying under it (Above, passes_by()) go on, to whoever's under the deck.
func cover_pass(target: Node, shooter: Node) -> float:
	var part := part_of(target)
	if part == "shelter":
		return 0.0
	if part == "" or (shooter != null and part_of(shooter) == part):
		return 1.0
	return Cover.away_pass(shooter, part_height_class(part), target.global_position, part_pass_from(part, shooter))


## Whether `unit` is on the stairs (either flight or the mid landing).
func on_stairs(unit: Node) -> bool:
	return part_of(unit) in ["lower_stairs", "upper_stairs"]


## Just outside the shelter's door, on the deck (world).
func door_out() -> Vector2:
	return to_global(DOOR_OUT * World.PX_PER_M)


## On the deck, just in from the stair's top landing (world).
func deck_in() -> Vector2:
	return to_global(DECK_IN * World.PX_PER_M)


# ------------------------------------------------------------- the levels --

## Whether a square on the ground at world `at`, moving at `velocity`, steps
## onto the stair here: it's built, and the square is walking up into its foot,
## inside the flared guides.
func steps_on(at: Vector2, velocity: Vector2) -> bool:
	if not built:
		return false
	var heading := velocity.rotated(-global_rotation)
	var m := _metres(at)
	return FOOT_ON.has_point(m) and _in_funnel(m) and heading.y < -1.0


## Whether a square at `m` (metres) is wholly between the stair's sides and
## the flared guides out in front of its foot (a few cm' slack).
func _in_funnel(m: Vector2) -> bool:
	var half_width := (STAIR_X.y - STAIR_X.x) / 2.0 + maxf(0.0, m.y - FLIGHT2_Y.y) * FLARE_PER_M
	return absf(m.x - (STAIR_X.x + STAIR_X.y) / 2.0) + UNIT_HALF_M <= half_width + 0.03


## Where `count` squadmates sent to world `point` up here stand (world): in the
## STAY_AREA nearest it (the shelter only if it's in the shelter), on a grid
## STAY_PITCH_M apart filling it, nearest `point` first; once that's full, on
## into the next nearest. More than they all hold share the first spot (up
## here squares pass each other).
func stay_spots(point: Vector2, count: int) -> Array[Vector2]:
	var m := _metres(point)
	# On the stair, its landings; on the deck, its walkways (and the shelter if
	# it's in it): never across a railing to the other.
	var stair := _on_stair(m)
	var areas: Array = []
	for area: Rect2 in STAY_AREAS:
		if area == CABIN and not CABIN.has_point(m):
			continue
		if _on_stair(area.get_center()) != stair:
			continue
		areas.append(_room_in(area))
	areas.sort_custom(func(a: Rect2, b: Rect2): return (m.distance_to(m.clamp(a.position, a.end))
			< m.distance_to(m.clamp(b.position, b.end))))
	var spots: Array[Vector2] = []
	for room: Rect2 in areas:
		var start := m.clamp(room.position, room.end)
		var grid: Array[Vector2] = [start]   # where it was sent first, then the grid's points nearest it
		var cols := floori(room.size.x / STAY_PITCH_M) + 1
		var rows := floori(room.size.y / STAY_PITCH_M) + 1
		var cells: Array[Vector2] = []
		for i in cols:
			for j in rows:
				cells.append(room.position + room.size * Vector2(
						0.5 if cols == 1 else float(i) / (cols - 1), 0.5 if rows == 1 else float(j) / (rows - 1)))
		cells.sort_custom(func(a, b): return a.distance_to(start) < b.distance_to(start))
		grid.append_array(cells)
		for spot in grid:
			if spots.any(func(s): return s.distance_to(spot) < STAY_PITCH_M * 0.8):
				continue
			spots.append(spot)
			if spots.size() == count:
				break
		if spots.size() == count:
			break
	while spots.size() < count:
		spots.append(spots[0])
	var out: Array[Vector2] = []
	for spot in spots:
		out.append(to_global(spot * World.PX_PER_M))
	return out


## Whether world `at` (a square up here) is on the stair: its landings or
## flights, not the deck.
func on_stair_at(at: Vector2) -> bool:
	return _on_stair(_metres(at))


## Whether world `at` (a square up here) is somewhere to stand (STAY_AREAS).
func can_stay(at: Vector2) -> bool:
	var m := _metres(at)
	return STAY_AREAS.any(func(area: Rect2): return area.has_point(m))


## Where a square's middle can be in `area` (metres) without poking out of it.
func _room_in(area: Rect2) -> Rect2:
	var h := Vector2(minf(UNIT_HALF_M, area.size.x / 2.0), minf(UNIT_HALF_M, area.size.y / 2.0))
	return area.grow_individual(-h.x, -h.y, -h.x, -h.y)


## Whether a square on the ground at world `at` is down by the stair's foot,
## where it's drawn over the stairs (FOOT_OVER).
func by_foot(at: Vector2) -> bool:
	return FOOT_OVER.has_point(_metres(at))


## Whether a square up on the tower at world `at`, moving at `velocity`, has
## walked back off it, out of the stair's foot (or it's somehow off its
## outline, or the tower's gone). Walking down (south), that's once it's clear
## of the bottom step; otherwise out past FOOT_OFF_Y, so one that's just
## stepped on walking up isn't put straight off again.
func steps_off(at: Vector2, velocity := Vector2.ZERO) -> bool:
	var m := _metres(at)
	var heading := velocity.rotated(-global_rotation)
	return (not built or m.y > FOOT_OFF_Y or (m.y > FOOT_CLEAR_Y and heading.y > 1.0)
			or not (on_surface(at, 0.3) or FOOT_APRON.has_point(m)))


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


## Whether `unit` is up on this tower at the cabin's height (HIGH_PARTS):
## its shots and sight stop in the cabin's walls (tower_walls.gd), and its
## tracers are drawn over the deck (bullet.gd).
func up_high(unit: Node) -> bool:
	return (unit != null and is_instance_valid(unit) and unit.get("tower") == self
			and part_of(unit) in HIGH_PARTS)


## The railing or cabin wall nearest world `at`, if one's within `radius_m`
## (death_fall.gd: a body meeting one as it falls): {point (world, on it),
## distance_m, out (world: across it, away from `inside`'s side), rail (a
## railing, which a body can go over; not the cabin's wall)}. Empty with none.
func wall_near(at: Vector2, radius_m: float, inside: Vector2) -> Dictionary:
	if not built:
		return {}
	var m := _metres(at)
	var from := _metres(inside)
	var best := {}
	for i in WALLS.size():
		var a: Vector2 = WALLS[i][0]
		var b: Vector2 = WALLS[i][1]
		var p := Geometry2D.get_closest_point_to_segment(m, a, b)
		var d := p.distance_to(m)
		if d > radius_m or (not best.is_empty() and d >= best.distance_m):
			continue
		var out := (b - a).orthogonal().normalized()
		if out.dot(p - from) < 0.0:
			out = -out
		best = {"point": to_global(p * World.PX_PER_M), "distance_m": d,
				"out": out.rotated(global_rotation), "rail": i < RAILS.size()}
	return best


## What's under world `at` on the tower (death_fall.gd: a body or rifle
## coming down): [world point, height (m)] of the deck or stair there, the
## point pulled `half_m` in from a stair's side rails so it lies between
## them; empty if `at` isn't over the tower.
func landing(at: Vector2, half_m := 0.0) -> Array:
	if not built or not on_surface(at):
		return []
	var m := _metres(at)
	if m.x >= STAIR_X.x - 0.1 and m.y >= FLIGHT1_Y.x:   # on the stair (as height_at())
		m.x = clampf(m.x, STAIR_X.x + half_m, STAIR_X.y - half_m)
	return [to_global(m * World.PX_PER_M), height_at(at)]


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
