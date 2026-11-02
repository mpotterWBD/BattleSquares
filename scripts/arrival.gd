extends Node
## Opens the game with the player flown in: a helicopter
## (scripts/insertion.gd) comes in from the west and lands so that the player
## steps out of its front starboard door exactly where the Player node is
## placed in main.tscn. Until then the player is hidden and switched off,
## and command mode is shut (World.player_aboard).
##
## Before that, crates placed in the level with `early_deploy` ticked
## (crate.gd) are taken off the field and a supply helicopter
## (scripts/supply_drop.gd) parachutes them back onto their spots, turned as
## placed (air_drop.gd; they keep their own settings). Once the last is down
## and EARLY_PAUSE_S has passed, the player's helicopter comes in.
##
## Remove this node (or untick `enabled`) to start with the player already on
## the ground, as tests do (early-deploy crates are then just there).
## Unticking the player's `drop_off_animation` (player.gd) skips just the
## player's helicopter: early-deploy crates still come down, with the player
## already on the ground.

const World = preload("res://scripts/world.gd")
const Insertion = preload("res://scripts/insertion.gd")
const SupplyDrop = preload("res://scripts/supply_drop.gd")
const HELICOPTER := preload("res://scenes/helicopter.tscn")

const EARLY_PAUSE_S := 1.0   ## after the early crates are down, before the player's helicopter

@export var enabled := true
@export var player_path: NodePath = ^"../Player"

var _early_left := 0   ## early crates still on their way down


func _ready() -> void:
	if enabled:
		# The scene is still adding its children; add the helicopters after.
		_start.call_deferred()


func _start() -> void:
	var player: Node2D = get_node(player_path)
	if _flies_in():
		World.player_aboard = true
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
	var drops := []
	for crate: Node2D in get_tree().get_nodes_in_group("crates"):
		if crate.get("early_deploy"):
			drops.append({scene = crate, pos = crate.global_position, turn = crate.global_rotation})
	if drops.is_empty():
		_fly_in()
		return
	for drop in drops:
		drop.scene.get_parent().remove_child(drop.scene)   # off the field until it's dropped
	_early_left = drops.size()
	var heli: Node2D = HELICOPTER.instantiate()
	var run := SupplyDrop.new()
	heli.add_child(run)
	get_parent().add_child(heli)
	run.released.connect(func(fall: Node2D) -> void: fall.landed.connect(_on_early_landed))
	run.start(heli, drops)


func _on_early_landed() -> void:
	_early_left -= 1
	if _early_left == 0:
		get_tree().create_timer(EARLY_PAUSE_S).timeout.connect(_fly_in)


## The player's `drop_off_animation` (player.gd): off, it starts on the ground.
func _flies_in() -> bool:
	return get_node(player_path).get("drop_off_animation") != false


func _fly_in() -> void:
	if not _flies_in():
		return
	var player: Node2D = get_node(player_path)
	var heli: Node2D = HELICOPTER.instantiate()
	var run := Insertion.new()
	heli.add_child(run)
	get_parent().add_child(heli)
	run.passenger_out.connect(func(_unit: Node2D) -> void: World.player_aboard = false)
	run.start(heli, player.position - Insertion.first_out_offset(), [], [player])
