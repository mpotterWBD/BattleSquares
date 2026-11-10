@tool
extends Node2D
## A tree (Mike, 2026-11-09): add scenes/tree.tscn, place it by its trunk, and
## pick in the Inspector its Type (pine, spruce, oak, maple, cottonwood), its
## Growth (sapling, young, mature: each its own shape, not one shrunk) and its
## Size (a scale on top, for variety: 100% is the type's usual size at that
## growth, see assets/props/trees/trees.json for the metres). It shows in the
## editor as it will in the game.
##
## Rendered in Blender (blender/scripts/trees.py) straight down under the
## standard sun, like the other props; trees don't turn, so don't rotate one
## (its light would turn with it). Made of:
##   - its shadow on the ground (its own image, at half density: shown at 2x),
##     at the props' shadow darkness (0.71), under the squares
##   - the tree itself, drawn over the squares (z CANOPY_Z: over a watch
##     tower's roof, under a helicopter), fading to see-through while a square
##     is under it (CANOPY_SEE_THROUGH), so they're never lost under it
##   - its trunk: solid (a circle its trunk's size), so squares and the truck go
##     round it and it stops every shot: heavy cover (cover.gd), to hide behind.

const World = preload("res://scripts/world.gd")

enum Type { PINE, SPRUCE, OAK, MAPLE, COTTONWOOD }
enum Growth { SAPLING, YOUNG, MATURE }

const TYPE_NAMES := ["pine", "spruce", "oak", "maple", "cottonwood"]
const GROWTH_NAMES := ["sapling", "young", "mature"]
const DIR := "res://assets/props/trees/"
const SHADOW_ALPHA := 0.71
const SHADOW_Z := -45          ## over the grass (-100), roads (-60) and arena edge (-50); under the squares
const CANOPY_Z := 12           ## over the squares and a tower's roof (7); under a helicopter (19, 20)
const CANOPY_SEE_THROUGH := 0.35   ## its opacity while a square's under it
const FADE_PER_S := 4.0
const UNDER_SHARE := 0.8       ## a square this far out (of its crown's radius) counts as under it

@export var type := Type.OAK:
	set(value):
		type = value
		_rebuild()
@export var growth := Growth.MATURE:
	set(value):
		growth = value
		_rebuild()
## Bigger or smaller than the type's usual for its growth (100%).
@export_range(0.5, 1.6, 0.05, "suffix:x") var size := 1.0:
	set(value):
		size = value
		_rebuild()

static var _info: Dictionary = {}

var _shadow: Sprite2D
var _canopy: Sprite2D
var _trunk: StaticBody2D
var _trunk_shape: CircleShape2D
var _radius_px := 0.0      ## the crown's radius as shown (px)


func _ready() -> void:
	add_to_group("trees")
	_rebuild()
	set_process(not Engine.is_editor_hint())


## Its measurements (blender/scripts/trees.py writes them): height, crown and
## trunk radius, and where its shadow image goes.
static func info(t: int, g: int) -> Dictionary:
	if _info.is_empty():
		var file := FileAccess.open(DIR + "trees.json", FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_info = parsed
	return _info.get("%s_%s" % [TYPE_NAMES[t], GROWTH_NAMES[g]], {})


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var key := "%s_%s" % [TYPE_NAMES[type], GROWTH_NAMES[growth]]
	var d := info(type, growth)
	if d.is_empty():
		push_warning("tree.gd: no measurements for %s (render it: blender/scripts/trees.py)" % key)
		return
	var px := World.PX_PER_M
	if _shadow == null:
		for child in get_children(true):   # (left over from before a script reload)
			if child.has_meta("tree_part"):
				child.queue_free()
		_shadow = _part(Sprite2D.new()) as Sprite2D
		_shadow.z_as_relative = false
		_shadow.z_index = SHADOW_Z
		_canopy = _part(Sprite2D.new()) as Sprite2D
		_canopy.z_as_relative = false
		_canopy.z_index = CANOPY_Z
		_trunk = _part(StaticBody2D.new()) as StaticBody2D
		_trunk.collision_layer = 1   # solid, as a crate: squares, the truck and shots meet it
		_trunk.collision_mask = 0
		var shape := CollisionShape2D.new()
		_trunk_shape = CircleShape2D.new()
		shape.shape = _trunk_shape
		_trunk.add_child(shape)
	_shadow.texture = load(DIR + "tree_%s_shadow.png" % key)
	_shadow.scale = Vector2.ONE * size / float(d.shadow_density)
	_shadow.position = Vector2(d.shadow_centre_m[0], d.shadow_centre_m[1]) * px * size
	_shadow.modulate = Color(1, 1, 1, SHADOW_ALPHA)
	_canopy.texture = load(DIR + "tree_%s.png" % key)
	_canopy.scale = Vector2.ONE * size
	_trunk_shape.radius = maxf(float(d.trunk_radius_m) * size, 0.05) * px
	_radius_px = float(d.canopy_radius_m) * size * px


func _part(node: Node) -> Node:
	node.set_meta("tree_part", true)
	add_child(node, false, Node.INTERNAL_MODE_FRONT)   # (made here: not saved with the scene)
	return node


## Fades the crown while a square's under it.
func _process(delta: float) -> void:
	if _canopy == null:
		return
	var reach := _radius_px * UNDER_SHARE
	var under := false
	for unit: Node2D in get_tree().get_nodes_in_group("units"):
		if not unit.get("dead") and unit.global_position.distance_squared_to(global_position) < reach * reach:
			under = true
			break
	var want := CANOPY_SEE_THROUGH if under else 1.0
	_canopy.modulate.a = move_toward(_canopy.modulate.a, want, FADE_PER_S * delta)


## Whether a square at world `point` is under its crown (it's faded then).
func covers(point: Vector2) -> bool:
	return point.distance_to(global_position) < _radius_px * UNDER_SHARE
