extends Node
## The radio terminal at a station's desk (a child of scenes/radio_station.tscn).
## Stand beside the desk, on its west side (the station's OperatorZone), and press F
## for the RADIO menu, beside the player like the command-mode menus:
##
##   Command  radio command mode (World.radio_commanding): command mode over
##            (with DEPLOY too, and Back to return to this menu, command.gd)
##            this station's radio net. Radio operators in its dish beam,
##            and anyone in their command circle, hear you, as well as
##            anyone in earshot of your voice (player.gd can_hear()). F
##            again, or stepping off the box, hangs up.
##   Exit     closes the menu (as F does).
##   Dish     aim the station's dish: the menu goes and the wheel opens round
##            the dish (radio_station.gd start_tuning(); it used to be F at
##            the dish). Click or F locks the heading in; stepping away
##            from the desk or Space closes it; X goes back to this menu.
##   Deploy   hold for Troops / Equipment / Vehicles.
##            Let go on Troops:
##              1. MAX_TROOPS slots, in rows of PER_ROW. Press a slot for
##                 the unit-type pop-out (Infantry or Radio operator; a
##                 quick click fills it with Infantry). Fill as many as you
##                 want.
##              2. filled slots are readied one after another,
##                 `seconds_per_troop` each
##              3. once they're all ready, Send helicopter: a ghost
##                 helicopter follows the mouse to mark the LZ (inside the
##                 play area; right click goes back), and a click sends a
##                 helicopter to fly them in (scripts/insertion.gd)
##            Let go on Equipment: the same, for supplies dropped by
##            parachute:
##              1. EQUIP_SLOTS slots, EQUIP_PER_ROW to a row (2 x 2). Press a
##                 slot for the pop-out (Ammo crate, Sandbag crate, Comms
##                 crate or Watch tower crate; a quick click gives an ammo
##                 crate).
##              2. filled slots are readied one after another,
##                 `seconds_per_crate` each
##              3. Send helicopter: a ghost of the drop, the crates in one
##                 line in slot order (DROP_PITCH_M apart), follows the
##                 mouse, like lining up troops at Attention; the scroll
##                 wheel turns it (15 degrees a notch, on the same grid),
##                 and the helicopter flies in along the line. Red
##                 where a crate can't come down (off the field, or on
##                 something). A click sends a helicopter over to drop them
##                 (scripts/supply_drop.gd): each comes down by parachute
##                 right on its spot (scripts/air_drop.gd). Right click goes back.
##            Let go on Vehicles (Mike, 2026-11-03: the supply truck,
##            deployable by helicopter like troops): the same, one vehicle a
##            helicopter:
##              1. one slot: press it for the pop-out (Supply truck; a quick
##                 click gives one).
##              2. it's readied, `seconds_per_vehicle`.
##              3. Send helicopter: a ghost of the helicopter with the truck
##                 under it follows the mouse to mark the LZ, red where the
##                 truck wouldn't fit (off the field, or on something); a
##                 click sends a helicopter to bring it in slung under it on
##                 cables and set it down there, nose east
##                 (scripts/sling_drop.gd). Right click goes back.
##
## The request and its countdown live here, so they carry on while the
## player is away; reopening the menu shows where they're at, and while the
## menu is closed a timer above the operator's box shows the total time
## left (or that the troops are ready). While the menu
## is open the player doesn't aim or fire (player.gd `busy`). F or Esc closes
## it.

const World = preload("res://scripts/world.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const HoldPopout = preload("res://scripts/hold_popout.gd")
const Insertion = preload("res://scripts/insertion.gd")
const SupplyDrop = preload("res://scripts/supply_drop.gd")
const SlingDrop = preload("res://scripts/sling_drop.gd")
const HELICOPTER := preload("res://scenes/helicopter.tscn")
const PALLET_TEX := preload("res://assets/props/pallet.png")

const COLOR := World.COMMAND_COLOR
const MAX_TROOPS := 10
const PER_ROW := 5
const MENU_GAP_PX := 36.0
const DESK_HALF_PX := 60.0        ## the desk's half length on screen (the timer shows just past it)
const PAD_KEY_ALPHA := 0.55       ## the green F is see-through, so the desk shows under it
const KINDS := [
	{id = "troops", text = "Troops"},
	{id = "equipment", text = "Equipment"},
	{id = "vehicles", text = "Vehicles"},
]
## What an equipment slot can hold: a crate scene, and its load's sprite for
## the drop-zone ghost.
const EQUIPMENT_TYPES := [
	{id = "ammo", text = "Ammo crate", scene = preload("res://scenes/crate_ammo.tscn"),
			tex = preload("res://assets/props/crate_ammo.png")},
	{id = "sandbags", text = "Sandbag crate", scene = preload("res://scenes/crate_sandbags.tscn"),
			tex = preload("res://assets/props/crate_sandbags.png")},
	{id = "comms", text = "Comms crate", scene = preload("res://scenes/crate_comms.tscn"),
			tex = preload("res://assets/props/crate_comms.png")},   ## the kit a radio station is built from
	{id = "tower", text = "Watch tower crate", scene = preload("res://scenes/crate_tower.tscn"),
			tex = preload("res://assets/props/crate_tower.png")},   ## the parts a watch tower is built from (Mike, 2026-11-02)
]
const EQUIP_SLOTS := 4
const EQUIP_PER_ROW := 2
const DROP_PITCH_M := 1.6          ## crates in a drop land this far apart (centre to centre)
const DROP_TURN_DEG := 15.0        ## one scroll-wheel notch turns the drop this far
const DROP_CLEAR_M := 0.85         ## a crate's spot must be this clear of anything solid (square)
const CRATE_SPRITE_SCALE := 0.25   ## crate sprites are rendered at 4x
const OLIVE := Color(0.33, 0.35, 0.22)
const BURLAP := Color(0.76, 0.66, 0.48)
const STRAP_BLACK := Color(0.06, 0.06, 0.06)
const POLYMER := Color(0.1, 0.1, 0.1)
const DISH_TAN := Color(0.80, 0.72, 0.58)
const TOWER_GALV := Color(0.64, 0.65, 0.64)        ## the watch tower crate's steel (watch_tower.py GALV)
const TOWER_GALV_DARK := Color(0.42, 0.43, 0.43)
const TOWER_CREAM := Color(0.86, 0.79, 0.6)        ## its roof panels
const TOWER_WHITE := Color(0.88, 0.88, 0.85)       ## its air conditioner
## Unit types a troop slot can hold.
const UNIT_TYPES := [
	{id = "infantry", text = "Infantry"},
	{id = "radio", text = "Radio"},   ## infantry with a radio pack (soldier.gd kit)
]
const INFANTRY_RED := Color(0.85, 0.15, 0.12)
const PACK_BROWN := Color(0.42, 0.29, 0.16)
const LZ_OK := Color(0.7, 1.0, 0.7, 0.55)
const LZ_BAD := Color(1.0, 0.45, 0.45, 0.5)
## What a vehicle slot can hold: its scene, and for its slot and the LZ
## ghost, its picture and the part of it that's the vehicle (in the picture's pixels).
const VEHICLE_TYPES := [
	{id = "supply_truck", text = "Supply truck", scene = preload("res://scenes/supply_truck.tscn"),
			tex = preload("res://assets/vehicles/supply_truck_body.png"), region = Rect2(30, 286, 742, 230),
			size_m = Vector2(4.3, 1.37)},   ## (supply_truck.gd LENGTH_M, WIDTH_M)
]
const VEHICLE_SPRITE_SCALE := 0.5   ## vehicle sprites are rendered at 2x

@export var seconds_per_troop := 1.0   # 1 s for testing; was 30
@export var seconds_per_crate := 1.0   # 1 s for testing
@export var seconds_per_vehicle := 1.0   # 1 s for testing
@export var zone_path: NodePath = ^"../OperatorZone"
@export var pad_path: NodePath = ^"../StandBox"   ## the desk's middle: the green F shows there, the timer above it

enum Screen { CLOSED, MENU, SLOTS, LZ, EQUIP, DZ, VEHICLES, VLZ }
var screen := Screen.CLOSED

## The troop request: one entry per slot, "" while empty or a unit type id.
var slots: Array[String] = []
var _pad_prompt: Label
var _pad_timer: Label
var _progress: Array[float] = []   ## seconds of readying done, per slot
var _queue: Array[int] = []        ## filled slots, in the order they were filled

## The equipment request, likewise: "" or an EQUIPMENT_TYPES id per slot.
var equip_slots: Array[String] = []
var _equip_progress: Array[float] = []
var _equip_queue: Array[int] = []
var _equip_for_slot := -1
var _dz_turn := 0.0                 ## how the drop is turned (radians, on the 15-degree grid)
var _dz_ghost: Node2D

var _owns_radio := false            ## this terminal switched radio command on
var _free_player_on_release := false
var _mouse_world := Vector2.ZERO
var _ghost: Node2D
var _type_for_slot := -1

var _layer: CanvasLayer
var _menu: VBoxContainer
var _deploy_button: Button
var _command_button: Button
var _kinds_popout: HoldPopout
var _types_popout: HoldPopout
var _slots_panel: PanelContainer
var _slots_grid: GridContainer
var _slot_buttons: Array[Button] = []
var _status_label: Label
var _send_button: Button
var _equip_popout: HoldPopout
var _equip_panel: PanelContainer
var _equip_buttons: Array[Button] = []
var _equip_status: Label
var _equip_send: Button

## The vehicle request: "" or a VEHICLE_TYPES id, and how far it's readied.
var vehicle_slot := ""
var _vehicle_progress := 0.0
var _vehicle_popout: HoldPopout
var _vehicle_panel: PanelContainer
var _vehicle_button: Button
var _vehicle_status: Label
var _vehicle_send: Button
var _vehicle_ghost: Node2D

@onready var _zone: Area2D = get_node(zone_path)


func _ready() -> void:
	add_to_group("interactables")   # F at the desk (player.gd interact_target())
	World.register_controls()
	_build_ui()
	_pad_prompt = _make_pad_prompt()
	get_node(pad_path).add_child(_pad_prompt)
	_pad_timer = _make_pad_timer()
	get_node(pad_path).add_child(_pad_timer)
	# Upright and above/below the box however the station is turned.
	var station := get_parent()
	if station.has_method("keep_upright"):
		station.keep_upright(_pad_prompt, get_node(pad_path))
		station.keep_upright(_pad_timer, get_node(pad_path))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if _owns_radio:
			hang_up()
			get_viewport().set_input_as_handled()
		elif screen != Screen.CLOSED:
			close()
			get_viewport().set_input_as_handled()
		elif _player_on_box() and not World.commanding() and _player().interact_target() == self:
			open_menu()
			get_viewport().set_input_as_handled()
		return
	if screen == Screen.CLOSED:
		return
	if event.is_action_pressed("ui_cancel"):
		if screen == Screen.LZ:
			_stop_lz(true)
		elif screen == Screen.DZ:
			_stop_dz(true)
		elif screen == Screen.VLZ:
			_stop_vlz(true)
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if screen == Screen.DZ:
		_dz_input(event)
		return
	if screen == Screen.VLZ:
		_vlz_input(event)
		return
	if screen != Screen.LZ:
		return
	# Marking the LZ: the ghost follows the mouse; left click sends, right
	# click goes back to the request.
	var mouse := event as InputEventMouse
	if mouse:
		_mouse_world = _to_world(mouse.position)
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT and _lz_ok(_mouse_world):
			_send_helicopter(_mouse_world)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_stop_lz(true)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_tick_readying(delta)
	var on_box := _player_on_box()
	_pad_prompt.visible = on_box and screen == Screen.CLOSED and not _owns_radio and _player().interact_target() == self
	_update_pad_timer()
	if _owns_radio and not on_box:
		hang_up()
	if screen != Screen.CLOSED and (not on_box or (World.commanding() and not World.radio_commanding)):
		close()
	if _free_player_on_release and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_free_player_on_release = false
		if screen == Screen.CLOSED and _player():
			_player().busy = false
	match screen:
		Screen.MENU, Screen.SLOTS, Screen.EQUIP, Screen.VEHICLES:
			_place_ui()
			_refresh_slots()
			_refresh_equipment()
			_refresh_vehicle()
		Screen.VLZ:
			_vehicle_ghost.global_position = _mouse_world
			_vehicle_ghost.modulate = LZ_OK if _vlz_ok(_mouse_world) else LZ_BAD
		Screen.LZ:
			_ghost.global_position = _mouse_world
			_ghost.modulate = LZ_OK if _lz_ok(_mouse_world) else LZ_BAD
		Screen.DZ:
			_dz_ghost.queue_redraw()


# ----------------------------------------------------------------- opening --

func _player():
	return get_tree().get_first_node_in_group("player")


func _player_on_box() -> bool:
	var player = _player()
	return get_parent().built and player != null and _zone.overlaps_body(player)


## For the player's interact_target(): the desk, while F would open it.
func interact_point() -> Variant:
	if screen == Screen.CLOSED and not _owns_radio and _player_on_box():
		return get_node(pad_path).global_position
	return null


func open_menu() -> void:
	_show(Screen.MENU)
	_player().busy = true


func close() -> void:
	if screen == Screen.LZ:
		_stop_lz(false)
	if screen == Screen.DZ:
		_stop_dz(false)
	if screen == Screen.VLZ:
		_stop_vlz(false)
	_show(Screen.CLOSED)
	_release_player()


func hang_up() -> void:
	World.radio_commanding = false
	World.radio_station = null
	_owns_radio = false


## Frees the player to aim and fire again, but not while the left button is
## still down from the click that closed the menu (it would fire).
func _release_player() -> void:
	var player = _player()
	if player == null:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_free_player_on_release = true
	else:
		player.busy = false


func _show(which: Screen) -> void:
	screen = which
	_layer.visible = which in [Screen.MENU, Screen.SLOTS, Screen.EQUIP, Screen.VEHICLES]
	_slots_panel.visible = which == Screen.SLOTS
	_equip_panel.visible = which == Screen.EQUIP
	_vehicle_panel.visible = which == Screen.VEHICLES
	_kinds_popout.close()
	_types_popout.close()
	_equip_popout.close()
	_vehicle_popout.close()
	if which in [Screen.MENU, Screen.SLOTS, Screen.EQUIP, Screen.VEHICLES]:
		_place_ui()


func _on_command() -> void:
	close()
	World.radio_commanding = true
	World.radio_station = get_parent()   # this station's dish carries the link
	_owns_radio = true


## Dish: the menu goes and the station's aiming wheel opens round its dish
## (radio_station.gd start_tuning()); the player stays busy (it takes over).
func _on_dish() -> void:
	_show(Screen.CLOSED)
	get_parent().start_tuning()


func _on_deploy_down() -> void:
	_kinds_popout.open(_deploy_button)


func _on_kind_chosen(kind: String, _at: Vector2) -> void:
	if kind == "vehicles":
		_show(Screen.VEHICLES)
		return
	if kind == "equipment":
		if equip_slots.is_empty():
			_new_equip_request()
		_show(Screen.EQUIP)
		return
	if kind != "troops":
		return
	if slots.is_empty():
		_new_request()
	_show(Screen.SLOTS)   # otherwise a request is already under way


# ------------------------------------------------------------- the request --

## MAX_TROOPS empty slots; fill as many as you want sent.
func _new_request() -> void:
	slots.clear()
	_progress.clear()
	_queue.clear()
	for i in MAX_TROOPS:
		slots.append("")
		_progress.append(0.0)


func _on_slot_down(index: int) -> void:
	if slots[index] != "":
		return   # already filled
	_type_for_slot = index
	_types_popout.open(_slot_buttons[index], "infantry", _slots_panel)   # left of the whole panel


func _on_type_chosen(unit_type: String, _at: Vector2) -> void:
	if _type_for_slot < 0 or slots[_type_for_slot] != "":
		return
	slots[_type_for_slot] = unit_type
	_queue.append(_type_for_slot)
	_type_for_slot = -1


func _on_clear() -> void:
	_new_request()


## Readies filled slots one at a time, in the order they were filled (the
## troop and equipment requests each at their own pace, side by side).
func _tick_readying(delta: float) -> void:
	if vehicle_slot != "":
		_vehicle_progress = minf(_vehicle_progress + delta, seconds_per_vehicle)
	for index in _equip_queue:
		if _equip_progress[index] < seconds_per_crate:
			_equip_progress[index] = minf(_equip_progress[index] + delta, seconds_per_crate)
			break
	for index in _queue:
		if _progress[index] < seconds_per_troop:
			_progress[index] = minf(_progress[index] + delta, seconds_per_troop)
			return


func _slot_ready(index: int) -> bool:
	return slots[index] != "" and _progress[index] >= seconds_per_troop


## Every filled slot is ready (and at least one is filled).
func troops_ready() -> bool:
	return not _queue.is_empty() and _queue.all(_slot_ready)


func _seconds_left() -> float:
	var left := 0.0
	for index in _queue:
		left += seconds_per_troop - _progress[index]
	return left


# ----------------------------------------------------- the equipment request --

## EQUIP_SLOTS empty slots; fill as many as you want dropped.
func _new_equip_request() -> void:
	equip_slots.clear()
	_equip_progress.clear()
	_equip_queue.clear()
	for i in EQUIP_SLOTS:
		equip_slots.append("")
		_equip_progress.append(0.0)


func _on_equip_slot_down(index: int) -> void:
	if equip_slots[index] != "":
		return   # already filled
	_equip_for_slot = index
	_equip_popout.open(_equip_buttons[index], "ammo", _equip_panel)


func _on_equip_chosen(kind: String, _at: Vector2) -> void:
	if _equip_for_slot < 0 or equip_slots[_equip_for_slot] != "":
		return
	equip_slots[_equip_for_slot] = kind
	_equip_queue.append(_equip_for_slot)
	_equip_for_slot = -1


func _on_equip_clear() -> void:
	_new_equip_request()


func _equip_slot_ready(index: int) -> bool:
	return equip_slots[index] != "" and _equip_progress[index] >= seconds_per_crate


## Every filled equipment slot is ready (and at least one is filled).
func equipment_ready() -> bool:
	return not _equip_queue.is_empty() and _equip_queue.all(_equip_slot_ready)


func _equip_seconds_left() -> float:
	var left := 0.0
	for index in _equip_queue:
		left += seconds_per_crate - _equip_progress[index]
	return left


static func _equipment_type(id: String) -> Dictionary:
	for kind in EQUIPMENT_TYPES:
		if kind.id == id:
			return kind
	return {}


# --------------------------------------------------------- the drop zone --

func _on_equip_send() -> void:
	if not equipment_ready():
		return
	_show(Screen.DZ)
	_dz_ghost = Node2D.new()
	_dz_ghost.z_index = 45
	_dz_ghost.draw.connect(_draw_dz_ghost)
	get_parent().get_parent().add_child(_dz_ghost)


func _stop_dz(back_to_request: bool) -> void:
	if _dz_ghost:
		_dz_ghost.queue_free()
		_dz_ghost = null
	if back_to_request:
		_show(Screen.EQUIP)


## Marking the drop zone: the ghost follows the mouse, the wheel turns it,
## left click drops (if every crate can come down where it is), right click
## goes back to the request.
func _dz_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse:
		_mouse_world = _to_world(mouse.position)
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if _dz_layout(_mouse_world).all(func(d): return d.ok):
				_send_drop(_mouse_world)
		MOUSE_BUTTON_RIGHT:
			_stop_dz(true)
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			_dz_turn = _turned(_dz_turn, -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	get_viewport().set_input_as_handled()


## One scroll-wheel notch (`notch` 1 or -1) on from `turn`, on the fixed
## 15-degree grid command mode turns formations and equipment on
## (command.gd _turned_attention()), so a drop lines up with the world's edges.
static func _turned(turn: float, notch: int) -> float:
	var step := deg_to_rad(DROP_TURN_DEG)
	var nearest := roundi(turn / step)
	var steps: int
	if absf(turn - nearest * step) < 0.001:
		steps = nearest + notch
	else:
		steps = floori(turn / step) + (1 if notch > 0 else 0)
	return wrapf(steps * step, -PI, PI)


## Where each filled slot's crate comes down if the drop is centred on
## `center`: one line, in slot order, DROP_PITCH_M apart, along the
## helicopter's run (turned `_dz_turn`; at 0 it flies east). As
## [{kind, pos, ok}].
func _dz_layout(center: Vector2) -> Array:
	var out := []
	var pitch := DROP_PITCH_M * World.PX_PER_M
	var filled := _equip_queue.duplicate()
	filled.sort()
	for k in filled.size():
		var offset := Vector2((k - (filled.size() - 1) / 2.0) * pitch, 0.0).rotated(_dz_turn)
		var pos := center + offset
		out.append({kind = equip_slots[filled[k]], pos = pos, ok = _drop_spot_ok(pos)})
	return out


## A crate can come down at `point`: on the field, with nothing solid (a
## square, a crate, a station, sandbags...) within its DROP_CLEAR_M square.
func _drop_spot_ok(point: Vector2) -> bool:
	var px := World.PX_PER_M
	if not World.ARENA.grow(-DROP_CLEAR_M / 2.0 * px).has_point(point):
		return false
	var box := RectangleShape2D.new()
	box.size = Vector2.ONE * DROP_CLEAR_M * px
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(_dz_turn, point)
	return get_viewport().world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


## The ghost: each crate as it'll land (pallet and load, see-through), green
## where it can come down, red where it can't, with the grid's outline.
func _draw_dz_ghost() -> void:
	for drop in _dz_layout(_mouse_world):
		var kind := _equipment_type(drop.kind)
		var tint := LZ_OK if drop.ok else LZ_BAD
		_dz_ghost.draw_set_transform(drop.pos, _dz_turn, Vector2.ONE * CRATE_SPRITE_SCALE)
		for tex: Texture2D in [PALLET_TEX, kind.tex]:
			_dz_ghost.draw_texture(tex, -tex.get_size() / 2.0, tint)
		_dz_ghost.draw_set_transform(drop.pos, _dz_turn)
		var half := DROP_CLEAR_M / 2.0 * World.PX_PER_M
		_dz_ghost.draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(tint, 0.9), false, 1.5)
	_dz_ghost.draw_set_transform(Vector2.ZERO)


## Sends a helicopter over to drop the request's crates, centred on `center`.
func _send_drop(center: Vector2) -> void:
	var drops := []
	for drop in _dz_layout(center):
		drops.append({scene = _equipment_type(drop.kind).scene, pos = drop.pos, turn = _dz_turn})
	var heli: Node2D = HELICOPTER.instantiate()
	var run := SupplyDrop.new()
	heli.add_child(run)
	get_parent().get_parent().add_child(heli)
	run.start(heli, drops, _dz_turn)
	equip_slots.clear()
	_equip_progress.clear()
	_equip_queue.clear()
	close()


# -------------------------------------------------------------- the LZ --

func _on_send() -> void:
	if not troops_ready():
		return
	_show(Screen.LZ)
	_ghost = HELICOPTER.instantiate()
	# Just a picture: nothing running, no collisions, no shadows.
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_ghost.get_node("Hull/Outline").disabled = true
	_ghost.get_node("Shadows").visible = false
	_ghost.z_index = 45
	get_parent().get_parent().add_child(_ghost)
	_ghost.global_position = _mouse_world


func _stop_lz(back_to_request: bool) -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if back_to_request:
		_show(Screen.SLOTS)


## The LZ just has to be inside the play area.
func _lz_ok(point: Vector2) -> bool:
	return World.ARENA.has_point(point)


func _send_helicopter(lz: Vector2) -> void:
	var units := _queue.map(func(index: int) -> String: return slots[index])
	var heli: Node2D = HELICOPTER.instantiate()
	var run := Insertion.new()
	heli.add_child(run)
	get_parent().get_parent().add_child(heli)
	run.start(heli, lz, units)
	slots.clear()
	_progress.clear()
	_queue.clear()
	close()


# --------------------------------------------------- the vehicle request --

func _vehicle_type(id: String) -> Dictionary:
	for kind: Dictionary in VEHICLE_TYPES:
		if kind.id == id:
			return kind
	return VEHICLE_TYPES[0]


func _on_vehicle_slot_down() -> void:
	if vehicle_slot != "":
		return   # already chosen
	_vehicle_popout.open(_vehicle_button, VEHICLE_TYPES[0].id, _vehicle_panel)   # left of the whole panel


func _on_vehicle_chosen(kind: String, _at: Vector2) -> void:
	if vehicle_slot != "":
		return
	vehicle_slot = kind
	_vehicle_progress = 0.0


func _on_vehicle_clear() -> void:
	vehicle_slot = ""
	_vehicle_progress = 0.0


func vehicle_ready() -> bool:
	return vehicle_slot != "" and _vehicle_progress >= seconds_per_vehicle


func _refresh_vehicle() -> void:
	if screen != Screen.VEHICLES:
		return
	_vehicle_button.queue_redraw()
	_vehicle_send.disabled = not vehicle_ready()
	if vehicle_slot == "":
		_vehicle_status.text = "Press the slot to choose a vehicle"
	elif vehicle_ready():
		_vehicle_status.text = "%s ready - send the helicopter" % _vehicle_type(vehicle_slot).text
	else:
		_vehicle_status.text = "%s - ready in %s" % [_vehicle_type(vehicle_slot).text,
				_clock(seconds_per_vehicle - _vehicle_progress)]


## Send helicopter: a ghost of the helicopter with the vehicle under it, nose
## east, follows the mouse to mark where it's set down.
func _on_vehicle_send() -> void:
	if not vehicle_ready():
		return
	_show(Screen.VLZ)
	_vehicle_ghost = Node2D.new()
	_vehicle_ghost.z_index = 45
	var kind := _vehicle_type(vehicle_slot)
	var truck := Sprite2D.new()
	truck.texture = kind.tex
	truck.scale = Vector2.ONE * VEHICLE_SPRITE_SCALE
	truck.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vehicle_ghost.add_child(truck)
	var heli := HELICOPTER.instantiate()
	# Just a picture: nothing running, no collisions, no shadows.
	heli.process_mode = Node.PROCESS_MODE_DISABLED
	heli.get_node("Hull/Outline").disabled = true
	heli.get_node("Shadows").visible = false
	heli.modulate.a = 0.6
	_vehicle_ghost.add_child(heli)
	get_parent().get_parent().add_child(_vehicle_ghost)
	_vehicle_ghost.global_position = _mouse_world


func _stop_vlz(back_to_request: bool) -> void:
	if _vehicle_ghost:
		_vehicle_ghost.queue_free()
		_vehicle_ghost = null
	if back_to_request:
		_show(Screen.VEHICLES)


## Marking where the vehicle goes: the ghost follows the mouse; left click
## sends, right click goes back to the request.
func _vlz_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse:
		_mouse_world = _to_world(mouse.position)
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT and _vlz_ok(_mouse_world):
			_send_vehicle(_mouse_world)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_stop_vlz(true)
		get_viewport().set_input_as_handled()


## Whether the vehicle fits at `point` (nose east): wholly inside the play
## area and on nothing solid (squares, crates, sandbags, anything else).
func _vlz_ok(point: Vector2) -> bool:

	var half: Vector2 = _vehicle_type(vehicle_slot).size_m / 2.0 * World.PX_PER_M
	if not World.ARENA.has_point(point - half) or not World.ARENA.has_point(point + half):
		return false
	var box := RectangleShape2D.new()
	box.size = half * 2.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1 | 4   # squares, crates and the like, sandbags
	return get_parent().get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## A helicopter brings the vehicle in slung under it and sets it down at `lz`
## (scripts/sling_drop.gd).
func _send_vehicle(lz: Vector2) -> void:
	var level := get_parent().get_parent()
	var vehicle: Node2D = _vehicle_type(vehicle_slot).scene.instantiate()
	level.add_child(vehicle)
	var heli: Node2D = HELICOPTER.instantiate()
	var run := SlingDrop.new()
	heli.add_child(run)
	level.add_child(heli)
	run.start(heli, lz, vehicle)
	vehicle_slot = ""
	_vehicle_progress = 0.0
	close()


## The vehicle slot: "+" while empty; the vehicle's picture once chosen, with
## a green fill rising as it's readied, and a bright border when ready.
func _draw_vehicle_slot() -> void:
	var button := _vehicle_button
	var rect := Rect2(Vector2.ZERO, button.size)
	var c := rect.get_center()
	if vehicle_slot == "":
		button.draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), Color(COLOR, 0.6), 2.0)
		button.draw_line(c + Vector2(0, -9), c + Vector2(0, 9), Color(COLOR, 0.6), 2.0)
		return
	var done := _vehicle_progress / seconds_per_vehicle
	var inner := rect.grow(-4)
	if done < 1.0:
		var fill_h := inner.size.y * done
		button.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - fill_h), Vector2(inner.size.x, fill_h)),
				Color(COLOR, 0.3))
	_draw_vehicle(button, vehicle_slot, c, inner.size.x - 12.0, 1.0 if done >= 1.0 else 0.6)
	if done >= 1.0:
		button.draw_rect(inner, COLOR, false, 2.0)


## A vehicle's picture, `width` px long, centred on `center`, nose right.
func _draw_vehicle(canvas: CanvasItem, id: String, center: Vector2, width: float, alpha: float) -> void:
	var kind := _vehicle_type(id)
	var region: Rect2 = kind.region
	var size := Vector2(width, width * region.size.y / region.size.x)
	canvas.draw_texture_rect_region(kind.tex, Rect2(center - size / 2.0, size), region, Color(1, 1, 1, alpha))


func _draw_vehicle_icon(icon: Control, kind: Dictionary) -> void:
	_draw_vehicle(icon, kind.id, icon.size / 2.0, icon.size.x - 6.0, 1.0)


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


# ---------------------------------------------------------------- the UI --

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.visible = false
	add_child(_layer)

	# RADIO, left of the player.
	_menu = UiStyle.menu_column("RADIO")
	_deploy_button = UiStyle.menu_button("Deploy")
	_deploy_button.button_down.connect(_on_deploy_down)
	_command_button = UiStyle.menu_button("Command")
	_command_button.pressed.connect(_on_command)
	_menu.add_child(_deploy_button)
	_menu.add_child(_command_button)
	var dish_button := UiStyle.menu_button("Dish")
	dish_button.pressed.connect(_on_dish)
	_menu.add_child(dish_button)
	var exit_button := UiStyle.menu_button("Exit")
	exit_button.pressed.connect(close)
	_menu.add_child(exit_button)
	_layer.add_child(_menu)

	_kinds_popout = HoldPopout.new()
	_kinds_popout.setup(KINDS, _draw_kind_icon, -1.0)
	_kinds_popout.chosen.connect(_on_kind_chosen)
	_types_popout = HoldPopout.new()
	_types_popout.setup(UNIT_TYPES, _draw_unit_icon, -1.0)
	_types_popout.chosen.connect(_on_type_chosen)

	# The request: slots, status and Send.
	_slots_panel = UiStyle.panel()
	var slots_box := VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	slots_box.add_child(UiStyle.title("TROOP REQUEST"))
	_slots_grid = GridContainer.new()
	_slots_grid.columns = PER_ROW
	_slots_grid.add_theme_constant_override("h_separation", 6)
	_slots_grid.add_theme_constant_override("v_separation", 6)
	slots_box.add_child(_slots_grid)
	_status_label = UiStyle.caption("", 18)
	slots_box.add_child(_status_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_send_button = UiStyle.menu_button("Send helicopter", Vector2(200, 42))
	_send_button.pressed.connect(_on_send)
	var clear := UiStyle.menu_button("Clear", Vector2(100, 42))
	clear.pressed.connect(_on_clear)
	row.add_child(_send_button)
	row.add_child(clear)
	slots_box.add_child(row)
	_slots_panel.add_child(slots_box)
	_slots_panel.visible = false
	_layer.add_child(_slots_panel)

	# The equipment request: a 2 x 2 grid, status and Send.
	_equip_popout = HoldPopout.new()
	_equip_popout.setup(EQUIPMENT_TYPES, _draw_equip_icon, -1.0)
	_equip_popout.chosen.connect(_on_equip_chosen)
	_equip_panel = UiStyle.panel()
	var equip_box := VBoxContainer.new()
	equip_box.add_theme_constant_override("separation", 10)
	equip_box.add_child(UiStyle.title("EQUIPMENT REQUEST"))
	var equip_grid := GridContainer.new()
	equip_grid.columns = EQUIP_PER_ROW
	equip_grid.add_theme_constant_override("h_separation", 6)
	equip_grid.add_theme_constant_override("v_separation", 6)
	for i in EQUIP_SLOTS:
		var button := UiStyle.menu_button("", Vector2(72, 72))
		button.button_down.connect(_on_equip_slot_down.bind(i))
		button.draw.connect(_draw_equip_slot.bind(button, i))
		equip_grid.add_child(button)
		_equip_buttons.append(button)
	var grid_row := HBoxContainer.new()
	grid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_row.add_child(equip_grid)
	equip_box.add_child(grid_row)
	_equip_status = UiStyle.caption("", 18)
	equip_box.add_child(_equip_status)
	var equip_row := HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", 6)
	_equip_send = UiStyle.menu_button("Send helicopter", Vector2(200, 42))
	_equip_send.pressed.connect(_on_equip_send)
	var equip_clear := UiStyle.menu_button("Clear", Vector2(100, 42))
	equip_clear.pressed.connect(_on_equip_clear)
	equip_row.add_child(_equip_send)
	equip_row.add_child(equip_clear)
	equip_box.add_child(equip_row)
	_equip_panel.add_child(equip_box)
	_equip_panel.visible = false
	_layer.add_child(_equip_panel)

	# The vehicle request: one slot, status and Send.
	_vehicle_popout = HoldPopout.new()
	_vehicle_popout.setup(VEHICLE_TYPES, _draw_vehicle_icon, -1.0)
	_vehicle_popout.chosen.connect(_on_vehicle_chosen)
	_vehicle_panel = UiStyle.panel()
	var vehicle_box := VBoxContainer.new()
	vehicle_box.add_theme_constant_override("separation", 10)
	vehicle_box.add_child(UiStyle.title("VEHICLE REQUEST"))
	_vehicle_button = UiStyle.menu_button("", Vector2(150, 72))
	_vehicle_button.button_down.connect(_on_vehicle_slot_down)
	_vehicle_button.draw.connect(_draw_vehicle_slot)
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_child(_vehicle_button)
	vehicle_box.add_child(slot_row)
	_vehicle_status = UiStyle.caption("", 18)
	vehicle_box.add_child(_vehicle_status)
	var vehicle_row := HBoxContainer.new()
	vehicle_row.add_theme_constant_override("separation", 6)
	_vehicle_send = UiStyle.menu_button("Send helicopter", Vector2(200, 42))
	_vehicle_send.pressed.connect(_on_vehicle_send)
	var vehicle_clear := UiStyle.menu_button("Clear", Vector2(100, 42))
	vehicle_clear.pressed.connect(_on_vehicle_clear)
	vehicle_row.add_child(_vehicle_send)
	vehicle_row.add_child(vehicle_clear)
	vehicle_box.add_child(vehicle_row)
	_vehicle_panel.add_child(vehicle_box)
	_vehicle_panel.visible = false
	_layer.add_child(_vehicle_panel)

	_layer.add_child(_kinds_popout)
	_layer.add_child(_types_popout)
	_layer.add_child(_equip_popout)
	_layer.add_child(_vehicle_popout)
	_build_slot_buttons()


func _build_slot_buttons() -> void:
	for i in MAX_TROOPS:
		var button := UiStyle.menu_button("", Vector2(56, 56))
		button.button_down.connect(_on_slot_down.bind(i))
		button.draw.connect(_draw_slot.bind(button, i))
		_slots_grid.add_child(button)
		_slot_buttons.append(button)


## RADIO just left of the player's square on screen; the slot panel just
## left of RADIO.
func _place_ui() -> void:
	var player = _player()
	if player == null:
		return
	var view := get_viewport().get_visible_rect()
	var canvas := get_viewport().get_canvas_transform()
	var at: Vector2 = canvas * player.global_position
	var half_square: float = 0.2 * World.PX_PER_M * canvas.get_scale().x
	_menu.reset_size()
	var menu_pos := Vector2(at.x - half_square - MENU_GAP_PX - _menu.size.x, at.y - _menu.size.y / 2.0)
	_menu.position = menu_pos.clamp(view.position, view.end - _menu.size)
	for panel: PanelContainer in [_slots_panel, _equip_panel, _vehicle_panel]:
		if panel.visible:
			panel.reset_size()
			var pos := Vector2(_menu.position.x - 12.0 - panel.size.x, at.y - panel.size.y / 2.0)
			panel.position = pos.clamp(view.position, view.end - panel.size)


func _refresh_slots() -> void:
	if screen != Screen.SLOTS:
		return
	for button in _slot_buttons:
		button.queue_redraw()
	var filled := _queue.size()
	_send_button.disabled = not troops_ready()
	if filled == 0:
		_status_label.text = "Press a slot to choose its unit"
	elif troops_ready():
		_status_label.text = "%d ready - send the helicopter" % filled
	else:
		_status_label.text = "%d of %d filled - ready in %s" % [filled, slots.size(), _clock(_seconds_left())]


func _refresh_equipment() -> void:
	if screen != Screen.EQUIP:
		return
	for button in _equip_buttons:
		button.queue_redraw()
	var filled := _equip_queue.size()
	_equip_send.disabled = not equipment_ready()
	if filled == 0:
		_equip_status.text = "Press a slot to choose a crate"
	elif equipment_ready():
		_equip_status.text = "%d ready - send the helicopter" % filled
	else:
		_equip_status.text = "%d of %d - ready in %s" % [filled, equip_slots.size(), _clock(_equip_seconds_left())]


func _clock(seconds: float) -> String:
	var left := ceili(seconds)
	return "%d:%02d" % [left / 60, left % 60]


## A big green F on the desk while the player stands at it (like the one on
## the dish, ui_style.gd pad_key()).
func _make_pad_prompt() -> Label:
	return UiStyle.pad_key("F", Color(COLOR, PAD_KEY_ALPHA))


## The timer above the operator's box: how many troopers and the total time
## left, or that they're ready. Only while the menu is closed (the menu
## shows it otherwise).
func _make_pad_timer() -> Label:
	var settings := LabelSettings.new()
	settings.font_size = 26
	settings.font_color = COLOR
	settings.outline_size = 6
	settings.outline_color = Color(0, 0, 0, 0.8)
	var label := Label.new()
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(260, 36)
	# Centred just above the desk (DESK_HALF_PX from its middle).
	label.position = Vector2(-label.size.x / 2, -DESK_HALF_PX - 6.0 - label.size.y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 30
	label.visible = false
	return label


func _update_pad_timer() -> void:
	_pad_timer.visible = screen == Screen.CLOSED and not (_queue.is_empty() and _equip_queue.is_empty() and vehicle_slot == "")
	if not _pad_timer.visible:
		return
	var lines: Array[String] = []
	if not _queue.is_empty():
		var troops := _queue.size()
		var noun := "trooper" if troops == 1 else "troopers"
		if troops_ready():
			lines.append("%d %s READY" % [troops, noun])
		else:
			lines.append("%d %s  %s" % [troops, noun, _clock(_seconds_left())])
	if not _equip_queue.is_empty():
		var crates := _equip_queue.size()
		var noun := "crate" if crates == 1 else "crates"
		if equipment_ready():
			lines.append("%d %s READY" % [crates, noun])
		else:
			lines.append("%d %s  %s" % [crates, noun, _clock(_equip_seconds_left())])
	if vehicle_slot != "":
		var vehicle_name: String = _vehicle_type(vehicle_slot).text
		lines.append("%s READY" % vehicle_name if vehicle_ready() else "%s  %s" % [vehicle_name, _clock(seconds_per_vehicle - _vehicle_progress)])
	_pad_timer.text = "\n".join(lines)
	_pad_timer.size.y = 36.0 * lines.size()
	_pad_timer.position.y = -DESK_HALF_PX - 6.0 - _pad_timer.size.y


## A slot: "+" while empty; the unit's icon once filled, with a green fill
## rising as it's readied, and a bright border when ready.
func _draw_slot(button: Button, index: int) -> void:
	if index >= slots.size():
		return
	var rect := Rect2(Vector2.ZERO, button.size)
	var c := rect.get_center()
	if slots[index] == "":
		button.draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), Color(COLOR, 0.6), 2.0)
		button.draw_line(c + Vector2(0, -9), c + Vector2(0, 9), Color(COLOR, 0.6), 2.0)
		return
	var done: float = _progress[index] / seconds_per_troop
	var inner := rect.grow(-4)
	if done < 1.0:
		var fill_h := inner.size.y * done
		button.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - fill_h), Vector2(inner.size.x, fill_h)),
				Color(COLOR, 0.3))
	_draw_unit(button, slots[index], c, 1.0 if done >= 1.0 else 0.6)
	if done >= 1.0:
		button.draw_rect(inner, COLOR, false, 2.0)


## A unit's icon, facing up: a red square with a rifle poking out; a radio
## operator also has a brown pack on its back with an antenna.
func _draw_unit(canvas: CanvasItem, unit: String, center: Vector2, alpha: float) -> void:
	if unit == "radio":
		center.y -= 4.0   # room below for the pack
		var pack := Rect2(center + Vector2(-7, 8), Vector2(14, 6))
		canvas.draw_rect(pack, Color(PACK_BROWN, alpha))
		canvas.draw_rect(pack, Color(0, 0, 0, 0.6 * alpha), false, 1.0)
		canvas.draw_line(center + Vector2(-4, 13), center + Vector2(-9, 19), Color(0.05, 0.05, 0.05, alpha), 1.5)
	canvas.draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color(INFANTRY_RED, alpha))
	canvas.draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color(0, 0, 0, 0.6 * alpha), false, 1.0)
	canvas.draw_line(center + Vector2(5, -4), center + Vector2(5, -16), Color(0.25, 0.26, 0.27, alpha), 3.0)


func _draw_unit_icon(icon: Control, unit: Dictionary) -> void:
	_draw_unit(icon, unit.id, icon.size / 2.0, 1.0)


## An equipment slot: "+" while empty; the crate's icon once filled, with a
## green fill rising as it's readied, and a bright border when ready.
func _draw_equip_slot(button: Button, index: int) -> void:
	if index >= equip_slots.size():
		return
	var rect := Rect2(Vector2.ZERO, button.size)
	var c := rect.get_center()
	if equip_slots[index] == "":
		button.draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), Color(COLOR, 0.6), 2.0)
		button.draw_line(c + Vector2(0, -10), c + Vector2(0, 10), Color(COLOR, 0.6), 2.0)
		return
	var done: float = _equip_progress[index] / seconds_per_crate
	var inner := rect.grow(-4)
	if done < 1.0:
		var fill_h := inner.size.y * done
		button.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - fill_h), Vector2(inner.size.x, fill_h)),
				Color(COLOR, 0.3))
	_draw_crate(button, equip_slots[index], c, 1.4, 1.0 if done >= 1.0 else 0.6)
	if done >= 1.0:
		button.draw_rect(inner, COLOR, false, 2.0)


## A crate's icon from above: a wooden pallet edge round its load (olive
## ammo cans, tan sandbags, the comms kit's cases: black, olive, tan and a
## cable reel, or the watch tower's parts: steel tubes across the top, the
## deck grating and a stair flight, the cream roof panels and the white air
## conditioner) under a black strap cross.
func _draw_crate(canvas: CanvasItem, kind: String, center: Vector2, size: float, alpha: float) -> void:
	var half := 12.0 * size
	canvas.draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), Color(0.62, 0.47, 0.30, alpha))
	var load := half * 0.8
	if kind == "tower":
		var row := load * 2.0 / 3.0
		var top := center.y - load
		canvas.draw_rect(Rect2(center.x - load, top, load * 2.0, row).grow(-0.8), Color(TOWER_GALV, alpha))
		for k in 2:   # the tubes' seams
			var y := top + row * (k + 1) / 3.0
			canvas.draw_line(Vector2(center.x - load + 1.0, y), Vector2(center.x + load - 1.0, y), Color(TOWER_GALV_DARK, alpha), 1.0)
		canvas.draw_rect(Rect2(center.x - load, top + row, load, row).grow(-0.8), Color(TOWER_GALV_DARK, alpha))
		canvas.draw_rect(Rect2(center.x, top + row, load, row).grow(-0.8), Color(TOWER_GALV, alpha))
		canvas.draw_rect(Rect2(center.x - load, top + row * 2.0, load, row).grow(-0.8), Color(TOWER_CREAM, alpha))
		canvas.draw_rect(Rect2(center.x, top + row * 2.0, load, row).grow(-0.8), Color(TOWER_WHITE, alpha))
	elif kind == "comms":
		var q := load
		canvas.draw_rect(Rect2(center + Vector2(-q, -q), Vector2(q, q)).grow(-0.8), Color(POLYMER, alpha))
		canvas.draw_circle(center + Vector2(-q / 2.0, -q / 2.0), q * 0.42, Color(OLIVE, alpha))
		canvas.draw_rect(Rect2(center + Vector2(0, -q), Vector2(q, q)).grow(-0.8), Color(POLYMER, alpha))
		canvas.draw_rect(Rect2(center + Vector2(-q, 0), Vector2(q, q)).grow(-0.8), Color(OLIVE, alpha))
		canvas.draw_rect(Rect2(center, Vector2(q, q)).grow(-0.8), Color(DISH_TAN, alpha))
	elif kind == "sandbags":
		for i in 2:
			for j in 3:
				var bag := Rect2(center + Vector2(-load + i * load, -load + j * load * 2.0 / 3.0),
						Vector2(load, load * 2.0 / 3.0)).grow(-1.0)
				canvas.draw_rect(bag, Color(BURLAP, alpha))
	else:
		for i in 4:
			var can := Rect2(center + Vector2(-load + i * load / 2.0, -load), Vector2(load / 2.0, load * 2.0)).grow(-0.8)
			canvas.draw_rect(can, Color(OLIVE, alpha))
	canvas.draw_line(center + Vector2(-load, 0), center + Vector2(load, 0), Color(STRAP_BLACK, alpha), 2.0)
	canvas.draw_line(center + Vector2(-load * 0.45, -load), center + Vector2(-load * 0.45, load), Color(STRAP_BLACK, alpha), 2.0)
	canvas.draw_line(center + Vector2(load * 0.45, -load), center + Vector2(load * 0.45, load), Color(STRAP_BLACK, alpha), 2.0)


func _draw_equip_icon(icon: Control, kind: Dictionary) -> void:
	_draw_crate(icon, kind.id, icon.size / 2.0, 1.0, 1.0)


## Troops: three little squares; equipment: a crate; vehicles: a
## helicopter-ish cross.
func _draw_kind_icon(icon: Control, kind: Dictionary) -> void:
	var c := icon.size / 2.0
	if kind.id == "equipment":
		_draw_crate(icon, "ammo", c, 0.9, 1.0)
		return
	if kind.id == "troops":
		for dx in [-12.0, 0.0, 12.0]:
			var square := Rect2(c + Vector2(dx - 4, -4), Vector2(8, 8))
			icon.draw_rect(square, INFANTRY_RED)
			icon.draw_rect(square, Color(0, 0, 0, 0.6), false, 1.0)
	else:
		icon.draw_line(c + Vector2(-14, 0), c + Vector2(10, 0), COLOR, 4.0)
		icon.draw_line(c + Vector2(4, -11), c + Vector2(4, 11), COLOR, 1.5)
		icon.draw_line(c + Vector2(-7, -11), c + Vector2(15, 11), COLOR, 1.5)
