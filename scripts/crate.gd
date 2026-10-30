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
## A bullet that stops in it can show it (bullet_hit()): with `impact` set,
## that impact sound (scripts/impact_sound.gd) and, for "metal" (the ammo
## cans), sparks (scripts/hit_sparks.gd), or else a puff of dust (e.g. "sand",
## the sandbag crate); with it empty, nothing.

const World = preload("res://scripts/world.gd")
const HitDust = preload("res://scripts/hit_dust.gd")
const HitSparks = preload("res://scripts/hit_sparks.gd")
const ImpactSound = preload("res://scripts/impact_sound.gd")

const SHADOW_ALPHA := 0.71     ## an open-ground shadow (soldier.gd)

## The pallet's footprint and height (crates.py PALLET_L x PALLET_W, PALLET_H);
## zero for no pallet.
@export var pallet_m := Vector2(0.8, 0.8)
@export var pallet_height_m := 0.144
## The load's footprint and the top of it, straps included (printed by crates.py).
@export var load_m := Vector2(0.632, 0.618)
@export var load_height_m := 0.732
## What a bullet hitting it sounds like (an impact_sound.gd kind: "metal"
## with sparks; "sand", "dirt" or "concrete" with a puff of dust); empty for
## nothing.
@export var impact := ""

@onready var _shadow: CanvasGroup = $Shadow
@onready var _shadow_shape: Node2D = $Shadow/Shape
@onready var _deck_shadow: CanvasGroup = get_node_or_null("PalletShadow")
@onready var _deck_shadow_shape: Node2D = get_node_or_null("PalletShadow/Shape")


func _ready() -> void:
	add_to_group("crates")
	_shadow.self_modulate = Color(1, 1, 1, SHADOW_ALPHA)
	_shadow_shape.draw.connect(_draw_shadow)
	if _deck_shadow:
		_deck_shadow.self_modulate = Color(1, 1, 1, SHADOW_ALPHA)
		_deck_shadow_shape.draw.connect(_draw_deck_shadow)


## A bullet stopped in it (bullet.gd): sparks or dust, and the impact
## sound, if it has an `impact`.
func bullet_hit(point: Vector2, direction: Vector2) -> void:
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
	if pallet_m == Vector2.ZERO:
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
