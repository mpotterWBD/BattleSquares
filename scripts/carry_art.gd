extends RefCounted
## How a part being carried to something under construction looks, from
## above, held in front of whoever's carrying it (player.gd, squadmate.gd).
## Each is its own picture, the part exactly as it is on its crate
## (blender/scripts/crates.py: `-- held` renders hold_<part>.png, `-- can`
## the ammo can):
##   desk          the desk folded into a grey bundle, legs strapped on
##   electronics   a black rugged case
##   legs          the dish's legs in an olive case
##   dish          the dish in a tan case
##   wiring        the cable reel
##   sandbags      a filled burlap sandbag (a wall's worth, sandbags.gd)
##   ammo_can      an olive ammo can (ammo_supply.gd)
##   tower_base    the watch tower's legs and braces, a bundle of tubes (watch_tower.gd)
##   tower_platform  its deck, a stack of grating panels
##   tower_stairs  a stair flight laid flat
##   tower_roof    the cabin's panels, stacked
##   tower_details  the air conditioner, boxed
## Held across the body, the picture's top away from the carrier, pulled in
## against it: its near edge OVERLAP_M under the square's front face (each
## part's own depth, DEPTH_M), drawn under the square's body (player.gd and
## squadmate.gd put the view just before Body) so the square is over it.
## Load with:
##     const CarryArt = preload("res://scripts/carry_art.gd")

const World = preload("res://scripts/world.gd")

const HALF_SQUARE_M := 0.2      ## the carrier's front face from its middle (soldier.gd SIZE_M / 2)
const OVERLAP_M := 0.06          ## how far the part's near edge goes under the square
## Each part's depth, front to back as it's held (crates.py's printout; the
## can's width, as it's turned).
const DEPTH_M := {"desk": 0.25, "electronics": 0.244, "legs": 0.244, "dish": 0.244,
		"wiring": 0.22, "sandbags": 0.267, "ammo_can": 0.16,
		"tower_base": 0.22, "tower_platform": 0.22, "tower_stairs": 0.23, "tower_roof": 0.2, "tower_details": 0.203}
const SPRITE_SCALE := 0.25      ## the pictures are rendered at 4x (crates.py RENDER_SCALE)
const TEXTURES := {
	"desk": preload("res://assets/props/hold_desk.png"),
	"electronics": preload("res://assets/props/hold_electronics.png"),
	"legs": preload("res://assets/props/hold_legs.png"),
	"dish": preload("res://assets/props/hold_dish.png"),
	"wiring": preload("res://assets/props/hold_wiring.png"),
	"sandbags": preload("res://assets/props/hold_sandbags.png"),
	"ammo_can": preload("res://assets/props/hold_ammo_can.png"),
	"tower_base": preload("res://assets/props/hold_tower_base.png"),
	"tower_platform": preload("res://assets/props/hold_tower_platform.png"),
	"tower_stairs": preload("res://assets/props/hold_tower_stairs.png"),
	"tower_roof": preload("res://assets/props/hold_tower_roof.png"),
	"tower_details": preload("res://assets/props/hold_tower_details.png"),
}
## Turned from how it's rendered, so its long side is across the body (the
## can's rendered standing up the picture).
const TURN := {"ammo_can": PI / 2}


## Draws `part` on `canvas`, held in front of something at its origin facing `facing`.
static func draw(canvas: CanvasItem, part: String, facing: float) -> void:
	var tex: Texture2D = TEXTURES.get(part)
	if tex == null:
		return
	var px := World.PX_PER_M
	var ahead: float = HALF_SQUARE_M + DEPTH_M.get(part, 0.25) / 2.0 - OVERLAP_M
	canvas.draw_set_transform(Vector2.from_angle(facing) * ahead * px, facing + PI / 2 + TURN.get(part, 0.0),
			Vector2.ONE * SPRITE_SCALE)
	canvas.draw_texture(tex, -tex.get_size() / 2.0)
	canvas.draw_set_transform(Vector2.ZERO)
