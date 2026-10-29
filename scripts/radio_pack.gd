extends Node2D
## The radio operator's backpack and whip antenna (assets/characters/
## radio_pack.png, from blender/scripts/radio_pack.py), worn on the back of
## a square whose `kit` is "radio" (scripts/soldier.gd adds it).
##
## The image is centred on the square's centre with the square facing right,
## lit from straight overhead, so it just turns with the square's facing.
## It's drawn over the body (the pack's top is a little higher than the
## square's). Its shadow is the same shape, darkened, in the square's
## "Shadows" group, offset away from the sun by the pack's height.

const World = preload("res://scripts/world.gd")
const TEXTURE := preload("res://assets/characters/radio_pack.png")

## radio_pack.png is rendered at 4x the game's pixel density (RENDER_SCALE
## in radio_pack.py); shrink it back.
const SPRITE_SCALE := 1.0 / 4.0
const HEIGHT_M := 0.35   ## roughly the pack and antenna's height, for the shadow offset

var _pack: Sprite2D
var _shadow: Sprite2D


## `shadows` is the square's shadow group.
func setup(shadows: CanvasGroup) -> void:
	_pack = _sprite()
	add_child(_pack)
	_shadow = _sprite()
	_shadow.modulate = Color.BLACK
	shadows.add_child(_shadow)


## Called by the square each tick: `facing` in radians, `lift_m` its hop.
func update_pose(facing: float, lift_m: float) -> void:
	_pack.rotation = facing
	_pack.scale = Vector2.ONE * SPRITE_SCALE * (1.0 + lift_m)
	_shadow.rotation = facing
	_shadow.position = (World.SUN_DIR * (HEIGHT_M + lift_m) * tan(deg_to_rad(World.SUN_TILT_DEG))
			* World.PX_PER_M)


func _sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	# Mipmaps keep the shrunk-down sprite smooth instead of shimmering as it turns.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite
