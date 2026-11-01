extends "res://scripts/soldier.gd"
## The square you control (see scripts/soldier.gd for how every square
## moves, turns and carries its rifle).
##
## WASD or the arrow keys walk, the mouse aims, left click fires. A shot
## goes exactly where you click within the rifle's accurate range, and
## strays more the further past it you click (rifle.gd `aim_*`); hold right
## mouse to see that as the aiming line (scripts/aim_line.gd). Holding Space
## enters command mode (scripts/command.gd): the mouse then gives squad
## orders, so this square keeps looking where it last aimed and won't fire.
## It's in the "player" group so squadmates and the command overlay can
## find it.
##
## Its voice carries all round it within its command circle
## (`aura_radius_m`), whichever way it faces. In command mode only
## squadmates inside the circle hear it: they turn to listen and can be
## selected and given orders, which can send them anywhere.
##
## Over the radio (radio command mode at a station's terminal) its own
## command circle is bigger (`radio_aura_multiplier`), and orders also
## go through the radio net: radio operators (soldier `kit` "radio") inside
## that station's dish beam are linked, and they pass orders on to anyone
## within their own command circle (`radio_circle_radius_m`).
## Communications decide who can be commanded.

const AimLine = preload("res://scripts/aim_line.gd")
const CarryArt = preload("res://scripts/carry_art.gd")
const RELOAD_RING_M := 0.36   ## the reload progress arc's radius
## Carrying a station part (crate.gd, radio_station.gd): this much of walking
## speed, and no rifle (hands full).
const CARRY_SPEED := 0.65
## Running on dirt: Mike's SprintOnDirt.mp3 (10.7 s of footfalls), looped
## while it runs, from a random point each time; quiet on the road's
## asphalt (road.gd covers()). It fades out over RUN_STEPS_FADE_S.
const RUN_STEPS_SOUND := "res://assets/sfx/SprintOnDirt.mp3"
const RUN_STEPS_DB := -6.0
const RUN_STEPS_FADE_S := 0.15
const RUN_STEPS_QUIET_DB := -40.0
const UiStyle = preload("res://scripts/ui_style.gd")
const AMMO_HUD_OFFSET := Vector2(48, 24)   ## the ammo panel, from the player's square on screen
const EMPTY_COLOR := Color(1.0, 0.4, 0.35)
const DeathMenu = preload("res://scripts/death_menu.gd")

## Dying plays out in slow motion: the game runs at this speed until the
## body and rifle come to rest (the camera closes in meanwhile,
## game_camera.gd); then a menu offers Restart or Quit.
const DEATH_TIME_SCALE := 0.3
const DEATH_MENU_DELAY_S := 0.6   ## real seconds after coming to rest

## The command circle: how far its voice carries, all round. (Until
## 2026-10-29 this was 2.475 m plus an 8 m voice cone out of its front face.)
@export var aura_radius_m := 8.0
## In radio command mode the player's own command circle grows to this many
## times `aura_radius_m` (2 = 100% bigger, twice the radius).
@export_range(1.0, 5.0, 0.05, "suffix:x") var radio_aura_multiplier := 2.0
## A radio operator's command circle radius. Its own setting: it used to be
## twice the player's old 2.475 m circle.
@export var radio_circle_radius_m := 4.95
## How far away equipment can be put down from command mode's DEPLOY menu.
@export var deploy_reach_m := 4.95
## Equipment carried, to deploy from command mode: deployable id -> count
## (-1 = unlimited). Ids match DEPLOYABLES in scripts/command.gd.
## Sandbags unlimited for now (2026-10-30; was 6).
@export var deployables := {"radio_station": 1, "sandbags": -1}
## Running (hold Shift): this fast, in metres per second (walking is
## `speed_mps`, 1.6). Not while carrying a part, or in command mode (where
## Shift adds to the selection).
@export_range(0.5, 8.0, 0.1, "suffix:m/s") var run_speed_mps := 3.2
## How fast the squad's formation swings round to match the way this square
## faces, so sweeping the aim doesn't send followers running in circles.
@export var formation_turn_dps := 90.0
## Enemy (anyone else's) bullets passing within this far of the player
## whizz past with a flyby sound (bullet.gd).
@export_range(0.0, 10.0, 0.05, "suffix:m") var flyby_radius_m := 1.5:
	set(value):
		flyby_radius_m = value
		if _flyby_ring:
			_flyby_ring.queue_redraw()
## Draw the flyby circle round the player (to see it while tuning it).
@export var show_flyby_circle := false:
	set(value):
		show_flyby_circle = value
		if _flyby_ring:
			_flyby_ring.visible = value

## The direction squadmates on Follow me / Lead line up along (radians):
## `facing`, smoothed.
var formation_heading := -PI / 2
## Set while something else has the mouse (e.g. a station's tuning wheel):
## this square then keeps looking where it last aimed and won't fire.
var busy := false


## Not taking Mike's controls: something else has the mouse (`busy`), or
## debug mode is on (Q; debug_overlay.gd), when it stands still too.
func _hands_off() -> bool:
	return busy or World.debug

var _last_aim := Vector2.ZERO
var _aim_line: Node2D
var _flyby_ring: Node2D
var _reload_ring: Node2D
## The station part in its hands ("" for none), and the crate it came from.
var carrying := ""
var _carried_from: Node2D = null
var _running := false               ## holding Shift and allowed to run (_move_intent())
var _run_steps: AudioStreamPlayer2D   ## the running footfalls (null without the file)
var _carry_view: Node2D
## The ammo panel, shown while the right mouse button is held: rounds in
## the magazine and spare magazines.
var _ammo_hud: PanelContainer
var _ammo_label: Label
var _mags_label: Label


func _ready() -> void:
	super()
	add_to_group("player")
	# A fresh start (statics and the time scale outlive a scene reload).
	World.player_dead = false
	World.placing = false
	World.radio_commanding = false
	World.radio_station = null
	Engine.time_scale = 1.0
	World.register_controls()
	if ResourceLoader.exists(RUN_STEPS_SOUND):
		var steps = load(RUN_STEPS_SOUND).duplicate()   # (an AudioStreamMP3: it has `loop`)
		steps.loop = true
		_run_steps = AudioStreamPlayer2D.new()
		_run_steps.stream = steps
		_run_steps.volume_db = RUN_STEPS_DB
		add_child(_run_steps)
	_last_aim = global_position + Vector2.from_angle(facing) * 10.0 * World.PX_PER_M
	formation_heading = facing
	_aim_line = AimLine.new()
	_aim_line.weapon = _rifle
	_aim_line.visible = false
	add_child(_aim_line)
	_flyby_ring = Node2D.new()
	_flyby_ring.visible = show_flyby_circle
	_flyby_ring.draw.connect(func() -> void:
		_flyby_ring.draw_arc(Vector2.ZERO, flyby_radius_m * World.PX_PER_M, 0.0, TAU, 64,
				Color(1.0, 0.85, 0.3, 0.6), 1.5, true))
	add_child(_flyby_ring)
	# While reloading: an arc round the player, filling as the reload goes.
	_reload_ring = Node2D.new()
	_reload_ring.z_index = 5
	_reload_ring.draw.connect(func() -> void:
		var r := RELOAD_RING_M * World.PX_PER_M
		_reload_ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 3.0, true)
		_reload_ring.draw_arc(Vector2.ZERO, r, -PI / 2, -PI / 2 + TAU * _rifle.reload_progress, 48,
				Color(1.0, 0.85, 0.3, 0.9), 3.0, true))
	add_child(_reload_ring)
	_carry_view = Node2D.new()
	_carry_view.z_index = 2
	_carry_view.draw.connect(func() -> void: CarryArt.draw(_carry_view, carrying, facing))
	add_child(_carry_view)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ammo_hud = UiStyle.panel()
	_ammo_hud.visible = false
	_ammo_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_ammo_label = UiStyle.caption("", 20)
	_mags_label = UiStyle.title("", 15)
	column.add_child(_ammo_label)
	column.add_child(_mags_label)
	_ammo_hud.add_child(column)
	layer.add_child(_ammo_hud)


func _physics_process(delta: float) -> void:
	super(delta)
	formation_heading = wrapf(rotate_toward(formation_heading, facing,
			deg_to_rad(formation_turn_dps) * delta), -PI, PI)
	_aim_line.visible = Input.is_action_pressed("aim") and not World.commanding() and not _hands_off() and not dead
	_aim_line.target = _last_aim
	if Input.is_action_just_pressed("reload") and not dead and not _hands_off() and not World.commanding() and carrying == "":
		_rifle.start_reload()
	# Hands full: the part in front of it, no rifle.
	_rifle.visible = carrying == "" or dead   # the fall (death_fall.gd) takes the rifle over
	get_node("Shadows/RifleShadow").visible = _rifle.visible
	_carry_view.visible = carrying != "" and not dead
	if _carry_view.visible:
		_carry_view.queue_redraw()
	_tick_unstrap(delta)
	_update_run_steps(delta)
	_update_ammo_hud()
	_reload_ring.visible = _rifle.reloading and not dead
	if _reload_ring.visible:
		_reload_ring.rotation = -rotation   # the arc fills clockwise from the top, whichever way it faces
		_reload_ring.queue_redraw()


## Holding F with empty hands at a strapped crate: working its straps off
## (crate.gd work_unstrap(); let go and it starts again).
func _tick_unstrap(delta: float) -> void:
	if dead or _hands_off() or World.commanding() or carrying != "" or not Input.is_action_pressed("interact"):
		return
	for crate: Node2D in get_tree().get_nodes_in_group("crates"):
		if crate.has_method("can_unstrap") and crate.can_unstrap(self):
			crate.work_unstrap(self, delta)
			return


## The running footfalls: on while it's running faster than it walks on
## dirt, faded out otherwise.
func _update_run_steps(delta: float) -> void:
	if _run_steps == null:
		return
	var on_road := get_tree().get_nodes_in_group("roads").any(func(road): return road.covers(global_position))
	var want := (_running and not dead and not on_road
			and velocity.length() > speed_mps * World.PX_PER_M * 1.05)
	if want:
		_run_steps.volume_db = RUN_STEPS_DB
		if not _run_steps.playing:
			_run_steps.play(randf() * _run_steps.stream.get_length())
	elif _run_steps.playing:
		_run_steps.volume_db -= (RUN_STEPS_DB - RUN_STEPS_QUIET_DB) / RUN_STEPS_FADE_S * delta
		if _run_steps.volume_db <= RUN_STEPS_QUIET_DB:
			_run_steps.stop()


## Holding the right mouse button: the ammo panel beside the square, with
## the rounds left in the magazine (red when it's empty) and the spare
## magazines (and their rounds).
func _update_ammo_hud() -> void:
	_ammo_hud.visible = Input.is_action_pressed("aim") and not dead and not _hands_off() and not World.commanding()
	if not _ammo_hud.visible:
		return
	var spares: int = _rifle.spare_count()
	if _rifle.reloading:
		_ammo_label.text = "RELOADING"
	else:
		_ammo_label.text = "AMMO  %d / %d" % [_rifle.rounds, _rifle.mag_size]
	_ammo_label.add_theme_color_override("font_color", EMPTY_COLOR if _rifle.rounds <= 0 and not _rifle.reloading else UiStyle.COLOR)
	if spares < 0:
		_mags_label.text = "MAGS  unlimited"
	else:
		_mags_label.text = "MAGS  %d  (%d rounds)" % [spares, _rifle.spare_rounds()]
	_ammo_hud.reset_size()
	_ammo_hud.position = get_viewport().get_canvas_transform() * global_position + AMMO_HUD_OFFSET


## Killed: it falls like any square (soldier.gd), but stays down. Command
## mode shuts, the game slows to DEATH_TIME_SCALE while it falls, and once
## it's at rest the time goes back to normal and the death menu comes up.
func _die(point: Vector2, direction: Vector2) -> void:
	if carrying != "" and is_instance_valid(_carried_from):
		_carried_from.return_part(carrying)   # it goes back on the crate
	carrying = ""
	World.player_dead = true
	World.radio_commanding = false
	World.radio_station = null
	_aim_line.visible = false
	super(point, direction)
	_fall.drops_ammo = false   # nobody left to pick it up
	_fall.came_to_rest.connect(_on_fall_at_rest)
	Engine.time_scale = DEATH_TIME_SCALE


func _on_fall_at_rest() -> void:
	Engine.time_scale = 1.0
	await get_tree().create_timer(DEATH_MENU_DELAY_S, true, false, true).timeout
	get_tree().current_scene.add_child(DeathMenu.new())


func _move_intent() -> Vector2:
	_speed_scale = CARRY_SPEED if carrying != "" else 1.0
	_running = false
	if World.debug:
		return Vector2.ZERO
	if carrying == "" and Input.is_action_pressed("run") and not World.commanding():
		_speed_scale = run_speed_mps / speed_mps
		_running = true
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## F: with empty hands at a supply crate that owes something a part, takes
## one off it; carrying one, at a site that needs it (the nearest), puts it in.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo() or dead or _hands_off() or World.commanding():
		return
	if carrying != "":
		var best: Node2D = null
		for site: Node2D in get_tree().get_nodes_in_group("build_sites"):
			if site.needs(carrying) and site.can_deliver_at(global_position):
				if best == null or site.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
					best = site
		if best:
			best.install(carrying)
			carrying = ""
			_carried_from = null
			get_viewport().set_input_as_handled()
		return
	for crate: Node2D in get_tree().get_nodes_in_group("crates"):
		if crate.has_method("can_take") and crate.can_take(self):
			carrying = crate.take_part()
			_carried_from = crate
			get_viewport().set_input_as_handled()
			return


## Where to aim: the mouse, except in command mode, when the mouse is busy
## giving orders. A gamepad stick or an AI could supply this instead.
func _aim_point() -> Vector2:
	if not World.commanding() and not _hands_off():
		_last_aim = get_global_mouse_position()
	return _last_aim


## Holds still while commanding: the mouse is giving orders, so the body
## doesn't drift round as it settles toward its last aim.
func _turn_toward(target: Vector2, delta: float) -> void:
	if not World.commanding():
		super(target, delta)


## How far the shot may stray: none within the rifle's accurate range of
## the point clicked, more the further past it.
func _shot_spread_deg() -> float:
	return _rifle.spread_at(_shot_distance_m())


## The point clicked: the further past the solid line, the likelier the
## shot goes into the ground short of it.
func _shot_distance_m() -> float:
	return _rifle.muzzle_position().distance_to(_last_aim) / World.PX_PER_M


## Not when the click is on a button on screen (the battle log's, the enemy spawner's).
func _wants_to_fire() -> bool:
	return (Input.is_action_just_pressed("shoot") and not World.commanding() and not _hands_off() and carrying == ""
			and get_viewport().gui_get_hovered_control() == null)


## Whether a squadmate at `point` can be commanded: it hears the player's
## voice, or (in radio command mode) the radio net reaches it.
func can_hear(point: Vector2) -> bool:
	return hears_voice(point) or (World.radio_commanding and radio_reaches(point))


## The player's command circle radius right now, in metres: `aura_radius_m`,
## times `radio_aura_multiplier` in radio command mode.
func command_circle_m() -> float:
	return aura_radius_m * (radio_aura_multiplier if World.radio_commanding else 1.0)


## A radio operator's command circle radius, in metres.
func radio_circle_m() -> float:
	return radio_circle_radius_m


## Radio operators the station in use links to: those inside its dish beam.
func linked_radio_operators() -> Array[Node]:
	var station = World.radio_station
	if station == null or not is_instance_valid(station):
		return []
	return get_tree().get_nodes_in_group("squad").filter(
			func(unit): return unit.kit == "radio" and station.beam_covers(unit.global_position))


## Whether the radio net reaches `point`: within the command circle of a
## linked radio operator (which includes the operator itself).
func radio_reaches(point: Vector2) -> bool:
	var reach := radio_circle_m() * World.PX_PER_M
	for operator in linked_radio_operators():
		if operator.global_position.distance_to(point) <= reach:
			return true
	return false


## Whether a point is within earshot of the player's voice: inside its
## command circle.
func hears_voice(point: Vector2) -> bool:
	return global_position.distance_to(point) <= command_circle_m() * World.PX_PER_M
