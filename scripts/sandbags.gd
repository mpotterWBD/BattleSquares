@tool
extends StaticBody2D
## A deployable sandbag wall (scenes/sandbags.tscn; art from
## blender/scripts/sandbags.py): a 0.8 m tile of three courses of big burlap
## sandbags, one bag deep, two squares wide and about as high as a square.
## Squares can climb over it: it's on its own collision layer (3), which
## squares don't collide with, and a square on it (climb_at()) goes slowly,
## lifted and jostled (soldier.gd). Bullets and lines of sight still meet it
## (their rays check every layer). Squares draw over it (it's low; their
## shadows fall on it).
##
## Placed by hand in a scene, `extra_sandbags` lays that many more walls end
## to end after it (along its +x, as it's turned), joining into one row: in
## the editor it previews the whole row; in the game each extra is laid as a
## wall of its own (_lay_extras()). (The script runs in the editor only for
## that preview: everything else waits for the game.)
##
## Walls laid end to end (TILE_PX apart, turned the same way; command.gd
## snaps and lays rows like that) join into one wall: each picks the tile
## that matches its neighbours (_update_tile()): "single" alone, "start" /
## "end" at the ends of a row, and one of three "mid" tiles in between. The
## bond carries on across the joins, so a row reads as one wall. A wall
## coming or going tells its neighbours to look again.
##
## Its proximity box (`zone_length_m` along the wall by `zone_depth_m` out
## from it on each side; shown faintly in command mode and on the placing
## ghost) is where you're using it as cover: a shot fired from inside the
## box goes over this wall (lets_bullet_through()), and from inside you see
## over it (in_zone(), ai_soldier.gd _clear_view()). A shot from outside
## stops in it with a puff of dust (bullet_hit()), except
## `through_chance` of them, which skim over the top. Seen from outside, it
## hides whoever's behind it (but enemies in a fight shoot anyway). Put down
## from command mode's DEPLOY menu, turned with the scroll wheel while
## placing. Walls are in the "deployed_sandbags" group, including ones
## placed by hand in a scene (but not the placing ghosts).
##
## The tiles are lit by the fixed top-left sun, so turned, a wall's baked
## lighting turns too (little shows on the rounded bags). Its shadow is
## drawn here (_draw_shadow()): its footprint swept along the sun from the
## ground to WALL_HEIGHT_M, worked out against the node's turn so it falls
## the right way at any angle, and carried on across joins so a row's
## shadow is one unbroken band.

const World = preload("res://scripts/world.gd")
const HitDust = preload("res://scripts/hit_dust.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")

const TILES := {
	"single": preload("res://assets/props/sandbags_single.png"),
	"start": preload("res://assets/props/sandbags_start.png"),
	"end": preload("res://assets/props/sandbags_end.png"),
}
const MID_TILES := [
	preload("res://assets/props/sandbags_mid_0.png"),
	preload("res://assets/props/sandbags_mid_1.png"),
	preload("res://assets/props/sandbags_mid_2.png"),
]
const TILE_PX := 68.0          ## a tile's length; walls this far apart join (sandbags.py TILE_M)
const JOIN_SLACK_PX := 4.0     ## a neighbour this close to where one would join counts
const WALL_HEIGHT_M := 0.354   ## the top of the wall; printed by sandbags.py
const FOOT_PX := Vector2(68, 24)   ## the footprint (and collision box); matches sandbags.tscn
const END_INSET_PX := 2.6      ## a finished end stops this far inside the tile (sandbags.py END_INSET)
const SHADOW_ALPHA := 0.71     ## an open-ground shadow (soldier.gd)
## A square starts climbing this far (px) before its centre reaches the
## wall: about as soon as its edge touches it.
const CLIMB_MARGIN_PX := 14.0
const ZONE_FILL := Color(World.COMMAND_COLOR, 0.08)
const ZONE_EDGE := Color(World.COMMAND_COLOR, 0.55)

## The proximity box: how long it is along the wall, centred on it.
@export_range(0.2, 5.0, 0.05, "suffix:m") var zone_length_m := 1.0
## How far the proximity box reaches out from the wall's middle, each side.
@export_range(0.1, 3.0, 0.05, "suffix:m") var zone_depth_m := 0.8
## The chance a shot fired from outside the box goes over the wall instead of
## stopping in it (0.1 = 10%).
@export_range(0.0, 1.0, 0.01) var through_chance := 0.1
## More walls laid end to end after this one (along its length, the way it's
## turned), joining into one row. Shown in the editor; laid in the game.
@export_range(0, 60, 1) var extra_sandbags := 0:
	set(value):
		extra_sandbags = value
		if _preview:
			_preview.queue_redraw()

var _preview: Node2D   ## editor only: draws the row extra_sandbags makes

var _zone: Node2D
var _joined_before := false   ## a wall joins on at -x
var _joined_after := false    ## ...and at +x

@onready var _shadow: Node2D = $Shadow
@onready var _body: Sprite2D = $Body


func _ready() -> void:
	if Engine.is_editor_hint():
		_preview = Node2D.new()
		_preview.z_index = 1   # over the wall's own (single) tile
		_preview.draw.connect(_draw_preview)
		add_child(_preview)   # not owned: never saved into the scene
		return
	var ghost := process_mode == Node.PROCESS_MODE_DISABLED   # a placing ghost (command.gd)
	if not ghost:
		add_to_group("deployed_sandbags")
		tree_exiting.connect(_on_leaving)
	# The proximity box, on the ground under the wall: always on a ghost, in
	# command mode on a placed wall.
	_zone = Node2D.new()
	_zone.z_index = -3
	_zone.draw.connect(_draw_zone)
	_zone.visible = ghost
	add_child(_zone)
	_shadow.draw.connect(_draw_shadow)
	set_notify_transform(true)
	_update_tile()
	if not ghost:
		_update_neighbours()
		if extra_sandbags > 0:
			_lay_extras.call_deferred()   # the parent is still busy adding its children


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_zone.visible = World.commanding()


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		_update_tile()   # a ghost being moved and turned: join up where it would go


## Lays the `extra_sandbags` walls after this one, beside it in the level,
## with its settings (but no extras of their own).
func _lay_extras() -> void:
	var scene: PackedScene = load(scene_file_path if scene_file_path != "" else "res://scenes/sandbags.tscn")
	for i in range(1, extra_sandbags + 1):
		var wall: Node2D = scene.instantiate()
		wall.position = transform * Vector2(TILE_PX * i, 0)
		wall.rotation = rotation
		wall.zone_length_m = zone_length_m
		wall.zone_depth_m = zone_depth_m
		wall.through_chance = through_chance
		get_parent().add_child(wall)


## Editor preview of the row: this wall and its extras, each with the tile
## it will have in the game (start, middles, end), drawn over its own.
func _draw_preview() -> void:
	if extra_sandbags <= 0:
		return
	var scale_to := _body.scale
	for i in extra_sandbags + 1:
		var tex: Texture2D = TILES.start if i == 0 else (TILES.end if i == extra_sandbags
				else MID_TILES[posmod(i, MID_TILES.size())])
		var size := tex.get_size() * scale_to
		_preview.draw_texture_rect(tex, Rect2(Vector2(TILE_PX * i, 0) - size / 2.0, size), false)


# ------------------------------------------------------------- joining --

## The wall joined on at `side` (-1 = -x, 1 = +x): one TILE_PX along this
## one's length, turned the same way (or end for end). null if none.
func joined(side: int) -> Node2D:
	var axis := Vector2.from_angle(global_rotation)
	var at := global_position + axis * side * TILE_PX
	for wall: Node2D in get_tree().get_nodes_in_group("deployed_sandbags"):
		if wall == self or wall.is_queued_for_deletion():
			continue
		if (wall.global_position.distance_to(at) <= JOIN_SLACK_PX
				and absf(sin(wall.global_rotation - global_rotation)) < 0.05):
			return wall
	return null


## Picks the tile that matches the walls joined on, and redraws the shadow.
func _update_tile() -> void:
	if not is_inside_tree():   # gone too (the whole level unloading)
		return
	_joined_before = joined(-1) != null
	_joined_after = joined(1) != null
	if _joined_before and _joined_after:
		# Which middle tile: fixed by where it is, so it doesn't flicker.
		var cell := Vector2i((global_position / TILE_PX).round())
		_body.texture = MID_TILES[posmod(cell.x * 7 + cell.y * 13, MID_TILES.size())]
	elif _joined_after:
		_body.texture = TILES.start
	elif _joined_before:
		_body.texture = TILES.end
	else:
		_body.texture = TILES.single
	_shadow.queue_redraw()


## A wall's arrived next to these: they look again.
func _update_neighbours() -> void:
	for side in [-1, 1]:
		var wall := joined(side)
		if wall:
			wall._update_tile()


## Leaving: the walls it was joined to look again once it's gone.
func _on_leaving() -> void:
	remove_from_group("deployed_sandbags")
	for side in [-1, 1]:
		var wall := joined(side)
		if wall:
			wall._update_tile.call_deferred()


# ------------------------------------------------------------ shadow --

## The wall's shadow on the ground: its footprint swept along the sun from
## the foot to the top, in the node's (maybe turned) frame. Where a wall
## joins on, the footprint is carried on past the join and the shadow cut
## off at it, so each tile draws its own stretch of one unbroken band.
func _draw_shadow() -> void:
	var d := (World.SUN_DIR * tan(deg_to_rad(World.SUN_TILT_DEG)) * WALL_HEIGHT_M
			* World.PX_PER_M).rotated(-global_rotation)
	var half := FOOT_PX / 2.0
	var reach := absf(d.x) + 1.0   # how far past a join the footprint carries on
	var x0 := -half.x - reach if _joined_before else -half.x + END_INSET_PX
	var x1 := half.x + reach if _joined_after else half.x - END_INSET_PX
	var foot := [Vector2(x0, -half.y), Vector2(x1, -half.y), Vector2(x1, half.y), Vector2(x0, half.y)]
	var points := PackedVector2Array()
	for p in foot:
		points.append(p)
		points.append(p + d)
	var hull := Geometry2D.convex_hull(points)
	var big := 10000.0
	var clip := PackedVector2Array([
		Vector2(-half.x if _joined_before else -big, -big), Vector2(half.x if _joined_after else big, -big),
		Vector2(half.x if _joined_after else big, big), Vector2(-half.x if _joined_before else -big, big)])
	for piece in Geometry2D.intersect_polygons(hull, clip):
		_shadow.draw_colored_polygon(piece, Color(0, 0, 0, SHADOW_ALPHA))


# ------------------------------------------------------------- cover --

## Whether a world point is inside the proximity box.
func in_zone(point: Vector2) -> bool:
	var local := to_local(point)
	return (absf(local.x) <= zone_length_m / 2.0 * World.PX_PER_M
			and absf(local.y) <= zone_depth_m * World.PX_PER_M)


## How far up the wall a square centred at world `point` is: 0 off it (or
## just touching), rising to 1 once it's well onto the top.
func climb_at(point: Vector2) -> float:
	var local := to_local(point)
	var past := Vector2(absf(local.x), absf(local.y)) - FOOT_PX / 2.0   # < 0 inside, per axis
	var edge := maxf(past.x, past.y)   # how far outside the footprint (negative: inside)
	return 1.0 - smoothstep(-FOOT_PX.y * 0.3, CLIMB_MARGIN_PX, edge)


## Asked by a bullet (bullet.gd) once, when it reaches this wall: whether it
## goes over. Always from inside the box, `through_chance` from outside.
func lets_bullet_through(bullet: Node2D) -> bool:
	return in_zone(bullet.origin) or randf() < through_chance


## A bullet stopped in the wall (bullet.gd): sand flies back out the way it
## came, with the thud of a round into sand.
func bullet_hit(point: Vector2, direction: Vector2) -> void:
	var dust := HitDust.new()
	dust.setup(point, direction)
	var level := get_tree().current_scene
	(level if level else get_parent()).add_child(dust)
	ImpactSound.play(level if level else get_parent(), point, "sand")


func _draw_zone() -> void:
	var half := Vector2(zone_length_m / 2.0, zone_depth_m) * World.PX_PER_M
	var rect := Rect2(-half, half * 2.0)
	_zone.draw_rect(rect, ZONE_FILL)
	_zone.draw_rect(rect, ZONE_EDGE, false, 1.5)
