extends RefCounted
## The thud of a bullet hitting something, heard from where it hit: one of
## the impact sounds for what it hit, at random (never the same one twice
## running), pitched a little up or down. Each set is cut from Mike's
## recordings in assets/sfx/ (see DEVLOG):
##   "dirt"      a round into the ground (bullet.gd), off the road
##   "concrete"  a round into the road's asphalt (bullet.gd, road.gd covers())
##   "sand"      a round stopped by sandbags (sandbags.gd bullet_hit())
##   "metal"     a round striking steel: the ammo crate's cans, a lone ammo
##               can (crate.gd `impact`)
##   "flyby"     not an impact: the whizz of a round passing close by the
##               player (bullet.gd, player.gd `flyby_radius_m`)
## Load with:
##     const ImpactSound = preload("res://scripts/impact_sound.gd")

const World = preload("res://scripts/world.gd")

const SOUNDS := {
	"dirt": [
		preload("res://assets/sfx/dirt_impact/dirt_impact_0.wav"),
		preload("res://assets/sfx/dirt_impact/dirt_impact_1.wav"),
		preload("res://assets/sfx/dirt_impact/dirt_impact_2.wav"),
		preload("res://assets/sfx/dirt_impact/dirt_impact_3.wav"),
		preload("res://assets/sfx/dirt_impact/dirt_impact_4.wav"),
		preload("res://assets/sfx/dirt_impact/dirt_impact_5.wav"),
		preload("res://assets/sfx/dirt_impact/dirt_impact_6.wav"),
		preload("res://assets/sfx/dirt_impact/dirt_impact_7.wav"),
	],
	"concrete": [
		preload("res://assets/sfx/concrete_impact/concrete_impact_0.wav"),
		preload("res://assets/sfx/concrete_impact/concrete_impact_1.wav"),
		preload("res://assets/sfx/concrete_impact/concrete_impact_2.wav"),
		preload("res://assets/sfx/concrete_impact/concrete_impact_3.wav"),
		preload("res://assets/sfx/concrete_impact/concrete_impact_4.wav"),
		preload("res://assets/sfx/concrete_impact/concrete_impact_5.wav"),
		preload("res://assets/sfx/concrete_impact/concrete_impact_6.wav"),
		preload("res://assets/sfx/concrete_impact/concrete_impact_7.wav"),
	],
	"sand": [
		preload("res://assets/sfx/sand_impact/sand_impact_0.wav"),
		preload("res://assets/sfx/sand_impact/sand_impact_1.wav"),
		preload("res://assets/sfx/sand_impact/sand_impact_2.wav"),
		preload("res://assets/sfx/sand_impact/sand_impact_3.wav"),
		preload("res://assets/sfx/sand_impact/sand_impact_4.wav"),
		preload("res://assets/sfx/sand_impact/sand_impact_5.wav"),
		preload("res://assets/sfx/sand_impact/sand_impact_6.wav"),
		preload("res://assets/sfx/sand_impact/sand_impact_7.wav"),
	],
	"metal": [
		preload("res://assets/sfx/metal_impact/metal_impact_0.wav"),
		preload("res://assets/sfx/metal_impact/metal_impact_1.wav"),
		preload("res://assets/sfx/metal_impact/metal_impact_2.wav"),
	],
	"flyby": [
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_0.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_1.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_2.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_3.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_4.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_5.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_6.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_7.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_8.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_9.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_10.wav"),
		preload("res://assets/sfx/bullet_flyby/bullet_flyby_11.wav"),
	],
}
const VOLUME_DB := -4.0
const PITCH_JITTER := 0.08
const HEARING_M := 30.0      ## fades out to nothing this far from the camera

static var _last := {}       ## kind -> the sound played last, not to repeat it


## Plays a `kind` impact at world `point`, added under `parent` (the level).
## It has its own short-lived player, gone once it has played.
static func play(parent: Node, point: Vector2, kind: String) -> void:
	var set: Array = SOUNDS[kind]
	var last: int = _last.get(kind, -1)
	var pick := randi() % (set.size() - 1)
	if last >= 0 and pick >= last:
		pick += 1   # skip the one played last
	_last[kind] = pick
	var thud := AudioStreamPlayer2D.new()
	thud.stream = set[pick]
	thud.position = point
	thud.volume_db = VOLUME_DB
	thud.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	thud.max_distance = HEARING_M * World.PX_PER_M
	thud.finished.connect(thud.queue_free)
	parent.add_child(thud)
	thud.play()
