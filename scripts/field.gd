extends Sprite2D
## Tiles the grass texture across everything the camera can see.
##
## The visible area changes with the window shape and the camera's zoom and
## position, so the grass is re-fitted every frame (cheap: it just changes
## the sprite's region). The script doesn't run in the editor, so main.tscn
## saves the Field covering the whole arena (World.ARENA, 3840 x 2160): the
## editor then shows the real field.

## Extra grass beyond the visible edges, so a fast zoom or pan never shows
## a gap before the next update.
const MARGIN_PX := 64.0


func _ready() -> void:
	# Run after the camera has moved this frame.
	process_priority = 100


func _process(_delta: float) -> void:
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	view = view.grow(MARGIN_PX)
	position = view.position
	# Offsetting the region by the same amount keeps the grass pattern
	# fixed in place as the view moves.
	region_rect = view
