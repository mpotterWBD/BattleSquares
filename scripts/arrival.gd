extends Node
## Opens the game with the player flown in: a helicopter
## (scripts/insertion.gd) comes in from the west and lands so that the player
## steps out of its front starboard door exactly where the Player node is
## placed in main.tscn. Until then the player is hidden and switched off,
## and command mode is shut (World.player_aboard).
##
## Remove this node (or untick `enabled`) to start with the player already on
## the ground, as tests do.

const World = preload("res://scripts/world.gd")
const Insertion = preload("res://scripts/insertion.gd")
const HELICOPTER := preload("res://scenes/helicopter.tscn")

@export var enabled := true
@export var player_path: NodePath = ^"../Player"


func _ready() -> void:
	if enabled:
		# The scene is still adding its children; add the helicopter after.
		_fly_in.call_deferred()


func _fly_in() -> void:
	var player: Node2D = get_node(player_path)
	var heli: Node2D = HELICOPTER.instantiate()
	var run := Insertion.new()
	heli.add_child(run)
	get_parent().add_child(heli)
	World.player_aboard = true
	run.passenger_out.connect(func(_unit: Node2D) -> void: World.player_aboard = false)
	run.start(heli, player.position - Insertion.first_out_offset(), [], [player])
