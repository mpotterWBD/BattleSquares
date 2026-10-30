extends RefCounted
## World-wide constants shared by every script. Load with:
##     const World = preload("res://scripts/world.gd")

## Pixels per metre: the game's zoom level. Must match PX_PER_M in
## blender/scripts/bs_common.py, which every asset is rendered at.
const PX_PER_M := 1024.0 / 12.0

## The play area in pixels: twice the 1920x1080 design view each way (about
## 45 x 25.3 m), so at 1x zoom you see a quarter of it and at the furthest
## zoom out (0.5) all of it. Nobody can leave it (the edge barrier is drawn
## by scripts/arena_edge.gd), and the camera keeps inside it whenever the
## zoomed view is small enough.
const ARENA := Rect2(0, 0, 3840, 2160)

## The sun, matching the Blender renders: light from the top-left, tilted 40
## degrees from straight overhead, so shadows fall toward the bottom-right.
const SUN_DIR := Vector2(0.7071, 0.7071)
const SUN_TILT_DEG := 40.0

## The green of everything to do with commanding: the command circles,
## menus, selection rings, a station's dish beam and tuning wheel.
const COMMAND_COLOR := Color(0.45, 1.0, 0.45)
## The orange of fighting orders: the Fire and Stop buttons, targeting,
## and the lines from shooters to their target (scripts/command.gd).
const FIRE_COLOR := Color(1.0, 0.6, 0.15)
## How see-through the command shapes are (a station's dish beam, and the
## command circles' outline): fill brightest at the source, fading
## toward the far edge, with a faint outline.
const CONE_NEAR_ALPHA := 0.16
const CONE_FAR_ALPHA := 0.03
const CONE_EDGE_ALPHA := 0.35

## Keyboard and mouse controls. They're registered from code (see
## register_controls) rather than Project Settings > Input Map so they work
## without editing project.godot.
const KEY_CONTROLS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"command": [KEY_SPACE],   ## hold for command mode (scripts/command.gd)
	"interact": [KEY_F],      ## use what you're standing at (e.g. tune a station's dish)
	"reload": [KEY_R],        ## reload the rifle (rifle.gd start_reload())
}
const MOUSE_CONTROLS := {
	"shoot": [MOUSE_BUTTON_LEFT],
	"aim": [MOUSE_BUTTON_RIGHT],   ## hold to show the aiming line (scripts/aim_line.gd)
}


## Adds any controls that aren't registered yet. Safe to call repeatedly.
static func register_controls() -> void:
	for action: String in KEY_CONTROLS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in KEY_CONTROLS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action: String in MOUSE_CONTROLS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button: MouseButton in MOUSE_CONTROLS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)


## Radio command mode, switched on from a radio station's terminal
## (scripts/radio_terminal.gd): command mode over the radio net as well as
## the player's voice. Radio operators inside that station's dish beam
## (`radio_station`) are linked, and they and anyone within their command
## circle can hear (player.gd radio_reaches()). It stays on until the
## terminal turns it off.
static var radio_commanding := false
## The station being used for radio command (null when off).
static var radio_station: Node2D = null


## True while the player is still riding in on the opening helicopter
## (scripts/arrival.gd): command mode stays shut until they step out.
static var player_aboard := false

## True once the player has been killed (player.gd): no more command mode.
## Cleared when a level starts again.
static var player_dead := false


## True while Space is held or radio command mode is on: the mouse gives
## squad orders instead of aiming. Never while the player is aboard.
static func commanding() -> bool:
	if player_aboard or player_dead:
		return false
	return radio_commanding or (InputMap.has_action("command") and Input.is_action_pressed("command"))
