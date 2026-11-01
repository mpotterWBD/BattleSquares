extends Node2D
## The magazine in a dead square's rifle, there for the taking (added by
## death_fall.gd once the dropped rifle has come to rest with rounds in it).
##
## A little green circle on the ground round the gun marks it, breathing
## gently. The player walking over it (their square within the circle)
## takes that one magazine with the rounds that were left in it: it goes in
## with their spares (rifle.gd add_spare()), the dead rifle shows with no
## magazine (take_magazine()), a short "+1 MAG" floats up over the player,
## and the circle's gone. Only the magazine that was in the gun: a dead
## square's spares aren't there to be had.
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


## `rifle` is the dead square's (rifle.gd), down on the ground.
func setup(rifle: Node2D) -> void:
	_rifle = rifle


func _ready() -> void:
	add_to_group("ammo_pickups")
	z_as_relative = false
	z_index = -5   # painted on the ground, under the gun (death_fall.gd GUN_DOWN_Z -4) and every square
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
	if player.global_position.distance_to(global_position) <= REACH_M * World.PX_PER_M:
		give_to(player)


func _draw() -> void:
	var r := RADIUS_M * World.PX_PER_M * (1.0 + BREATHE * sin(TAU * BREATHE_HZ * _t))
	draw_circle(Vector2.ZERO, r, Color(COLOR, ALPHA * 0.18))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(COLOR, ALPHA), 2.0, true)


## `square` takes the magazine into its spares (the note only for the player).
func give_to(square: Node2D) -> void:
	var rounds: int = _rifle.take_magazine()
	square.get_node("Rifle").add_spare(rounds)
	if square.is_in_group("player"):
		_note(square.global_position, "+1 MAG  (%d)" % rounds)
	queue_free()


## "+1 MAG (n)" rising over the player and fading, in the level.
func _note(at: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	label.z_as_relative = false
	label.z_index = 30
	get_parent().add_child(label)
	label.reset_size()
	var px := World.PX_PER_M
	label.global_position = at + Vector2(-label.size.x / 2.0, -0.5 * px - label.size.y)
	var rise := label.create_tween().set_parallel()
	rise.tween_property(label, "global_position:y", label.global_position.y - NOTE_RISE_M * px, NOTE_S)
	rise.tween_property(label, "modulate:a", 0.0, NOTE_S).set_ease(Tween.EASE_IN)
	rise.chain().tween_callback(label.queue_free)
