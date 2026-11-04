extends Node2D
## The magazine in a dead square's rifle, there for the taking (added by
## death_fall.gd once the dropped rifle has come to rest with rounds in it).
##
## A little green circle on the ground round the gun marks it, breathing
## gently. Everyone carries the same number of magazines (rifle.gd
## `spare_mags`), so it's a swap: the player walking over it (their square
## within the circle) takes that magazine, with the rounds left in it, in
## place of their emptiest spare if it has more in it (rifle.gd
## swap_magazine()), and leaves theirs in the dead rifle (put_magazine());
## a short "MAG n" floats up over the player. If what was left behind is
## empty the circle's gone; if not, it's still there for someone else. No
## better than what they've got, nothing happens (useful_to()). Only the
## magazine that was in the gun: a dead square's spares aren't there to be had.
##
## Squadmates and enemies out of ammo come for it too (ai_soldier.gd
## _ammo_run()): one claims it (`claimed_by`) so the others look elsewhere,
## and takes it with give_to() when it gets there. The player can still
## take it first.

const World = preload("res://scripts/world.gd")

const RADIUS_M := 0.32          ## the circle round the gun
const REACH_M := 0.32           ## the player's centre this close to the gun picks it up
const COLOR := Color(0.55, 0.95, 0.55)
const ALPHA := 0.55
const BREATHE_HZ := 0.8         ## the circle swells a little...
const BREATHE := 0.08           ## ...by this much, this often
const NOTE_RISE_M := 0.5        ## "+1 MAG" floats up this far...
const NOTE_S := 1.2             ## ...fading over this long

var _rifle: Node2D
var _t := 0.0
## The square on its way to take it (null: nobody).
var claimed_by: Node2D = null
## The watch tower it's up on (null: on the ground). Only the player up
## there too can take it (not from the ground under the deck).
var tower: Node2D = null


## `rifle` is the dead square's (rifle.gd), down on the ground, or up on `on_tower`'s deck or stairs.
func setup(rifle: Node2D, on_tower: Node2D = null) -> void:
	_rifle = rifle
	tower = on_tower


func _ready() -> void:
	add_to_group("ammo_pickups")
	z_as_relative = false
	z_index = -5   # painted on the ground, under the gun (death_fall.gd GUN_DOWN_Z -4) and every square
	if tower:
		z_index = 5   # on the tower's deck (5: added after it, so drawn over it), under the gun and the squares up there (6)
	global_position = _rifle.global_position


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_rifle) or _rifle.rounds <= 0:
		queue_free()
		return
	global_position = _rifle.global_position
	queue_redraw()
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		return
	if (player.get("tower") == tower and player.global_position.distance_to(global_position) <= REACH_M * World.PX_PER_M
			and useful_to(player)):
		give_to(player)


func _draw() -> void:
	var r := RADIUS_M * World.PX_PER_M * (1.0 + BREATHE * sin(TAU * BREATHE_HZ * _t))
	draw_circle(Vector2.ZERO, r, Color(COLOR, ALPHA * 0.18))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(COLOR, ALPHA), 2.0, true)


## Whether the magazine has more in it than `square`'s emptiest spare.
func useful_to(square: Node2D) -> bool:
	var spares: Array = square.get_node("Rifle")._spares
	return is_instance_valid(_rifle) and not spares.is_empty() and _rifle.rounds > spares.min()


## `square` swaps its emptiest spare for the magazine (the note only for
## the player); gone once what's left in the dead rifle is empty.
func give_to(square: Node2D) -> void:
	var rounds: int = _rifle.rounds
	var old: int = square.get_node("Rifle").swap_magazine(rounds)
	if old < 0:
		return   # no better than what it has
	_rifle.take_magazine()
	if old > 0:
		_rifle.put_magazine(old)
	if square.is_in_group("player"):
		note(get_parent(), square.global_position, "MAG  %d" % rounds)
	if old <= 0:
		queue_free()


## `text` (e.g. "MAG 12") rising over world `at` and fading, in `parent`.
static func note(parent: Node, at: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	label.z_as_relative = false
	label.z_index = 30
	parent.add_child(label)
	label.reset_size()
	var px := World.PX_PER_M
	label.global_position = at + Vector2(-label.size.x / 2.0, -0.5 * px - label.size.y)
	var rise := label.create_tween().set_parallel()
	rise.tween_property(label, "global_position:y", label.global_position.y - NOTE_RISE_M * px, NOTE_S)
	rise.tween_property(label, "modulate:a", 0.0, NOTE_S).set_ease(Tween.EASE_IN)
	rise.chain().tween_callback(label.queue_free)
