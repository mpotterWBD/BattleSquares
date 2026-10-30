@tool
extends Path2D
## A paved road laid along this path. Draw it in the editor with the Path2D
## tools (select the Road, then in the toolbar above the 2D view: add points
## by clicking, drag a point's handles out to curve it). The road follows
## the curve and updates as you edit it. To make a road longer, add points
## to the end of the same Road.
##
## The texture (assets/textures/road_asphalt.png, from
## blender/scripts/road_asphalt.py) is a 12 m strip of clean two-lane
## asphalt (white edge lines, yellow centre dashes) with grassy verges that
## fade to transparent, so the field underneath shows through and the road
## blends into the grass. `condition` picks how damaged it is: Clean, Ok,
## Medium or Bad (road_asphalt.png, road_asphalt_ok/_medium/_bad.png): from
## fresh paint, through fading paint, cracks and patches, to potholes,
## crumbling edges and grass in the cracks. `centre_line` off leaves out the
## yellow centre dashes (the *_no_centre.png strips: otherwise identical,
## so a road with and one without join seamlessly). All are the same size. It
## repeats end to end along the path at its real size (1 m = World.PX_PER_M px).
##
## Joining roads (in the editor): drag a road's first or last point within
## SNAP_M of another road's first or last point and it clicks onto it, and
## its handle turns so the road carries straight on through the join. Pull
## it more than SNAP_M away to let go. A road that starts where another
## ends carries on that road's pattern (`_line`'s shader offsets the
## texture by the other road's length), so the centre dashes keep their
## rhythm across the join. Joins are end to end only; there are no
## junctions yet.
##
## Keep curves gentle: a bend tighter than about 3 m radius (half the strip's
## 6 m width) folds the inside edge over itself. A road can run off the
## arena; the arena edge dims it like the rest of the ground outside.
## It's just ground: squares walk across it as on grass.

const World = preload("res://scripts/world.gd")

enum Condition { CLEAN, OK, MEDIUM, BAD }

const TEXTURES := {
	Condition.CLEAN: preload("res://assets/textures/road_asphalt.png"),
	Condition.OK: preload("res://assets/textures/road_asphalt_ok.png"),
	Condition.MEDIUM: preload("res://assets/textures/road_asphalt_medium.png"),
	Condition.BAD: preload("res://assets/textures/road_asphalt_bad.png"),
}
## The same strips without the yellow centre dashes.
const TEXTURES_NO_CENTRE := {
	Condition.CLEAN: preload("res://assets/textures/road_asphalt_no_centre.png"),
	Condition.OK: preload("res://assets/textures/road_asphalt_ok_no_centre.png"),
	Condition.MEDIUM: preload("res://assets/textures/road_asphalt_medium_no_centre.png"),
	Condition.BAD: preload("res://assets/textures/road_asphalt_bad_no_centre.png"),
}
const BAKE_PX := 8.0     ## how finely curves are followed (smaller = smoother)
const SNAP_M := 1.0      ## an end this close to another road's end clicks onto it
const JOINED_PX := 0.5   ## ends this close together count as joined
const ALIGN_DEG := 0.5   ## a joined end's handle is turned if it's further off than this
## Offsets the texture along the road, so a road joined onto the end of
## another carries on its pattern. In a canvas shader on a Line2D, COLOR
## starts as the texture's colour times the line's, and the line is white.
const SHADER_CODE := """
shader_type canvas_item;
uniform float u_offset = 0.0;
void fragment() {
	COLOR = texture(TEXTURE, UV + vec2(u_offset, 0.0));
}
"""

static var _shader: Shader

## How damaged the road is (pick in the Inspector; it updates right away).
@export var condition := Condition.CLEAN:
	set(value):
		condition = value
		if is_node_ready():
			_apply_texture()

## Whether it has the yellow centre dashes (white edge lines either way).
@export var centre_line := true:
	set(value):
		centre_line = value
		if is_node_ready():
			_apply_texture()

var _line: Line2D
var _watched: Curve2D


func _ready() -> void:
	add_to_group("roads")
	_apply_texture()
	_rebuild()
	# Once every road is in, pick up the pattern from whatever this one joins.
	_update_offset.call_deferred()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	# In the editor the path's Curve2D can be swapped for another; follow it.
	if curve != _watched or _line_missing():
		_rebuild()
	_snap_ends()
	_update_offset()


## The Line2D that draws the road, set up on first use. Also after the editor
## reloads this script on a road already in the scene: _ready() doesn't run
## again then, and the old line (from older code) may be missing its shader.
func _get_line() -> Line2D:
	if _line_missing():
		if _line and is_instance_valid(_line):
			_line.queue_free()
		for child in get_children(true):   # a line left over from before a reload
			if child is Line2D:
				child.queue_free()
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER_CODE
		_line = Line2D.new()
		_line.texture_mode = Line2D.LINE_TEXTURE_TILE
		_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_line.z_as_relative = false
		_line.z_index = -60   # over the grass (-100), under the arena edge (-50) and everything else
		_line.material = ShaderMaterial.new()
		_line.material.shader = _shader
		add_child(_line, false, Node.INTERNAL_MODE_FRONT)   # not saved with the scene
		_apply_texture()
		if curve:
			_line.points = curve.get_baked_points()
	return _line


func _line_missing() -> bool:
	return (_line == null or not is_instance_valid(_line) or _line.is_queued_for_deletion()
			or not (_line.material is ShaderMaterial))


func _rebuild() -> void:
	var line := _get_line()
	if _watched and _watched.changed.is_connected(_rebuild):
		_watched.changed.disconnect(_rebuild)
	_watched = curve
	if curve == null:
		line.points = PackedVector2Array()
		return
	if curve.bake_interval != BAKE_PX:
		curve.bake_interval = BAKE_PX   # (before connecting: this emits `changed`)
	curve.changed.connect(_rebuild)
	line.points = curve.get_baked_points()


func _apply_texture() -> void:
	var line := _get_line()
	var texture: Texture2D = (TEXTURES if centre_line else TEXTURES_NO_CENTRE)[condition]
	line.texture = texture
	line.width = texture.get_height()   # the strip at its real size


# ------------------------------------------------------------- joining --

## The ends of this road's path: [index of the first point, of the last].
func _ends() -> Array[int]:
	if curve == null or curve.point_count < 2:
		return []
	return [0, curve.point_count - 1]


## Where point `i` of this road's path is, in world coordinates.
func end_position(i: int) -> Vector2:
	return to_global(curve.get_point_position(i))


## The way out of this road at its end point `i` (world, unit vector): the
## direction a road joined on there should carry on in.
func end_outward(i: int) -> Vector2:
	var handle: Vector2
	var neighbour: Vector2
	if i == 0:
		handle = curve.get_point_out(0)
		neighbour = curve.get_point_position(1)
	else:
		handle = curve.get_point_in(i)
		neighbour = curve.get_point_position(i - 1)
	var local := -handle if handle.length() > 1.0 else curve.get_point_position(i) - neighbour
	return global_transform.basis_xform(local).normalized()


## The other roads with an end within `reach` px of world point `at`: the
## closest as [road, its end index], or [] if none.
func _nearest_end(at: Vector2, reach: float) -> Array:
	var best := []
	for other in get_tree().get_nodes_in_group("roads"):
		if other == self or not other.is_inside_tree() or other.curve == null:
			continue
		for j in other._ends():
			var d: float = other.end_position(j).distance_to(at)
			if d < reach:
				reach = d
				best = [other, j]
	return best


## Editor: an end dragged near another road's end clicks onto it, with its
## handle turned to carry straight on.
func _snap_ends() -> void:
	for i in _ends():
		var found := _nearest_end(end_position(i), SNAP_M * World.PX_PER_M)
		if found.is_empty():
			continue
		var other = found[0]
		var j: int = found[1]
		var there: Vector2 = other.end_position(j)
		if end_position(i).distance_to(there) > JOINED_PX:
			curve.set_point_position(i, to_local(there))
		# This road leaves the join the way the other road comes out of it.
		var outward: Vector2 = other.end_outward(j)
		var local_dir := global_transform.affine_inverse().basis_xform(outward).normalized()
		var neighbour := curve.get_point_position(1 if i == 0 else i - 1)
		var handle := curve.get_point_out(0) if i == 0 else curve.get_point_in(i)
		var length := handle.length()
		if length < 1.0:
			length = curve.get_point_position(i).distance_to(neighbour) / 3.0
		if handle.length() < 1.0 or rad_to_deg(handle.angle_to(local_dir)) > ALIGN_DEG \
				or rad_to_deg(handle.angle_to(local_dir)) < -ALIGN_DEG:
			if i == 0:
				curve.set_point_out(0, local_dir * length)
			else:
				curve.set_point_in(i, local_dir * length)


## How far along its texture pattern this road starts, in strip lengths: 0,
## or where the road it carries on from (one whose last point is on this
## one's first) leaves off. `seen` stops a loop of roads going round forever.
func pattern_start(seen := []) -> float:
	if curve == null or curve.point_count < 2 or self in seen:
		return 0.0
	seen.append(self)
	var start := end_position(0)
	for other in get_tree().get_nodes_in_group("roads"):
		if other == self or other.curve == null or other.curve.point_count < 2:
			continue
		if other.end_position(other.curve.point_count - 1).distance_to(start) <= JOINED_PX:
			return fposmod(other.pattern_start(seen) + other.pattern_length(), 1.0)
	return 0.0


## This road's length in strip lengths (one strip = the texture's width,
## since the line is as wide as the texture is tall).
func pattern_length() -> float:
	return curve.get_baked_length() / float(TEXTURES[condition].get_width())


func _update_offset() -> void:
	if not is_inside_tree():
		return
	var material: ShaderMaterial = _get_line().material
	var offset := pattern_start()
	if material.get_shader_parameter("u_offset") != offset:
		material.set_shader_parameter("u_offset", offset)
