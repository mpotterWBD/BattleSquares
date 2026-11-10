@tool
extends Node2D
## A road junction: a T or a crossroads (4-way), to join roads (road.gd)
## (Mike, 2026-11-09). Add one with scenes/road_junction.tscn, place it where
## the roads meet, and turn it with the editor's rotate tool (hold Ctrl to step
## in whole degrees); pick its Kind and Condition in the Inspector.
##
## It's a 12 m square tile (assets/textures/road_junction_*.png, from
## blender/scripts/road_junction.py) with an arm reaching each open side's
## edge, 6 m from its middle: the through road east and west, and the T's
## stem south (down, at no rotation; the crossroads north too). At each arm's
## end the asphalt is the road strip's, so a road ending there carries on
## from it. Drag a road's first or last point onto an arm's end (within
## road.gd SNAP_M) and it clicks on, its handle turned to carry straight on
## out of the arm, as two roads join. The yellow centre dashes stop at a
## junction; its edge lines go round the corners.
##
## It's in the "roads" group like a road (bullets and footsteps on it are on
## the road: covers()), with no `curve`, so the code walking roads' curves
## passes it by; the drivers' road map (vehicle_ai.gd) drives through it along
## centre_lines().

const World = preload("res://scripts/world.gd")

enum Kind { T, CROSS }
## (the same order as road.gd's Condition)
enum Condition { CLEAN, OK, MEDIUM, BAD }

const TEXTURES := {
	Kind.T: {
		Condition.CLEAN: preload("res://assets/textures/road_junction_t.png"),
		Condition.OK: preload("res://assets/textures/road_junction_t_ok.png"),
		Condition.MEDIUM: preload("res://assets/textures/road_junction_t_medium.png"),
		Condition.BAD: preload("res://assets/textures/road_junction_t_bad.png"),
	},
	Kind.CROSS: {
		Condition.CLEAN: preload("res://assets/textures/road_junction_cross.png"),
		Condition.OK: preload("res://assets/textures/road_junction_cross_ok.png"),
		Condition.MEDIUM: preload("res://assets/textures/road_junction_cross_medium.png"),
		Condition.BAD: preload("res://assets/textures/road_junction_cross_bad.png"),
	},
}
const ARM_M := 6.0              ## each arm's end: this far from the middle (the tile's edge)
const ASPHALT_HALF_M := 2.5     ## (road.gd's)

## A T (east, west and south) or a crossroads (and north).
@export var kind := Kind.T:
	set(value):
		kind = value
		if is_node_ready():
			_apply()
## How damaged it is, as a road's Condition (match the roads joining it).
@export var condition := Condition.CLEAN:
	set(value):
		condition = value
		if is_node_ready():
			_apply()

## Never set: it's how road code walking the "roads" group tells it's not a road with a path.
var curve = null

var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("roads")
	add_to_group("road_junctions")
	_apply()


func _apply() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		for child in get_children(true):   # one left over from before a script reload
			if child is Sprite2D:
				child.queue_free()
		_sprite = Sprite2D.new()
		_sprite.z_as_relative = false
		_sprite.z_index = -59   # as roads (-60), just over them; under the arena edge (-50)
		add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)   # not saved with the scene
	_sprite.texture = TEXTURES[kind][condition]


## Its arms' ways out (local unit vectors): east, west, south (down), and for the crossroads north.
func arm_dirs() -> Array[Vector2]:
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]
	if kind == Kind.CROSS:
		dirs.append(Vector2.UP)
	return dirs


## Its arms, as a road's ends (road.gd snaps a road's end onto one): their indexes.
func arm_indexes() -> Array[int]:
	var out: Array[int] = []
	for j in arm_dirs().size():
		out.append(j)
	return out


## Where arm `j` ends, in world coordinates (as road.gd end_position()).
func end_position(j: int) -> Vector2:
	return to_global(arm_dirs()[j] * ARM_M * World.PX_PER_M)


## The way out along arm `j` (world, unit vector): a road joined on there carries on that way (as road.gd end_outward()).
func end_outward(j: int) -> Vector2:
	return global_transform.basis_xform(arm_dirs()[j]).normalized()


## Whether world `point` is on its asphalt.
func covers(point: Vector2) -> bool:
	var p := to_local(point) / World.PX_PER_M
	if absf(p.x) <= ARM_M and absf(p.y) <= ASPHALT_HALF_M:
		return true   # the through road
	for d in arm_dirs():
		if d.y == 0.0:
			continue
		var along := p.dot(d)
		if along >= 0.0 and along <= ARM_M and absf(p.x) <= ASPHALT_HALF_M:
			return true   # a road across
	return false


## The roads through it for the drivers' map (vehicle_ai.gd): the through
## road end to end, and each other arm from the middle to its end. World metres.
func centre_lines() -> Array[PackedVector2Array]:
	var px := World.PX_PER_M
	var middle := global_position / px
	var lines: Array[PackedVector2Array] = [PackedVector2Array([end_position(1) / px, end_position(0) / px])]
	for j in range(2, arm_dirs().size()):
		lines.append(PackedVector2Array([middle, end_position(j) / px]))
	return lines
