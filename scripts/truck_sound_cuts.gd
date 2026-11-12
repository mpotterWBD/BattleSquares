@tool   # (in the editor: its Cut Sounds button runs there)
extends Resource
class_name TruckSoundCuts
## Which sections of Mike's recordings the supply truck's sounds are cut from
## (assets/sfx/supply_truck/): times in seconds into each MP3 (Mike,
## 2026-11-03: he wants to choose them). The truck (supply_truck.gd) shows it
## under Sound > Sound Cuts; it's saved as truck_sound_cuts.tres.
##
## Change the times, then press Cut Sounds: it runs Blender headless
## (blender/scripts/cut_truck_sounds.py, which joins the idle stretches into one
## seamless loop where the waveforms line up) to re-cut the WAVs, a couple of
## seconds, and the editor reimports them. The Output panel says what it made.
## Run the game to hear them (a running game keeps the old ones).

const BLENDER := "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
const CUTTER := "res://blender/scripts/cut_truck_sounds.py"
const SOUNDS := ["truck_start.wav", "truck_stop.wav", "truck_idle.wav", "truck_run.wav", "door_open.wav", "door_slam.wav", "crane_move.wav", "crane_start.wav", "winch.wav", "stabilizer.wav", "crane_motor.wav", "crane_switch.wav"]
const SOUND_DIR := "res://assets/sfx/supply_truck/"
const CUTS_FILE := "user://truck_sound_cuts.json"   ## the sections, handed to the cutter

@export_tool_button("Cut Sounds", "AudioStreamWAV") var cut_sounds_button = cut_sounds

## Which recording the engine's sounds come from (Start, Running, Driving,
## Stop): one of the MP3s in assets/sfx/supply_truck/.
@export_file("*.mp3") var engine_recording := "res://assets/sfx/supply_truck/TransportVehicle.mp3"

@export_group("Engine Start", "start_")
## The engine recording: the start played as it's started, ignition to idle
## (the starter from about 2.95 s, idle by 6.4 s). Any quiet lead-in is
## trimmed off, so it begins as soon as the door shuts however early you start it.
@export_range(0.0, 120.0, 0.05, "suffix:s") var start_from_s := 2.85
@export_range(0.0, 120.0, 0.05, "suffix:s") var start_to_s := 6.6

@export_group("Engine Running", "idle_")
## The engine recording: up to three steady stretches, joined into the one
## loop that plays while it runs (pitched up with speed). One that isn't
## longer than a second (0 to 0: unused) is left out. Longer ones repeat less.
@export_range(0.0, 120.0, 0.05, "suffix:s") var idle_1_from_s := 12.4
@export_range(0.0, 120.0, 0.05, "suffix:s") var idle_1_to_s := 16.6
@export_range(0.0, 120.0, 0.05, "suffix:s") var idle_2_from_s := 23.6
@export_range(0.0, 120.0, 0.05, "suffix:s") var idle_2_to_s := 27.0
@export_range(0.0, 120.0, 0.05, "suffix:s") var idle_3_from_s := 0.0
@export_range(0.0, 120.0, 0.05, "suffix:s") var idle_3_to_s := 0.0
## How long each stretch blends into the next, and the loop's end into its
## start (for the driving loop too): longer melts one into the next more
## gradually (Mike: the joins sounded like different sounds swapping);
## the loop comes out this much shorter for each join.
@export_range(0.05, 3.0, 0.05, "suffix:s") var idle_blend_s := 1.0

@export_group("Engine Driving", "run_")
## The engine working, driving along: up to two stretches joined into a
## second loop the truck blends into as it speeds up (0 to 0: none, and it
## uses the running loop alone, pitched up). A drift in pitch across them
## (revving up as it goes) is levelled out, so the loop doesn't jump back.
@export_range(0.0, 120.0, 0.05, "suffix:s") var run_1_from_s := 0.0
@export_range(0.0, 120.0, 0.05, "suffix:s") var run_1_to_s := 0.0
@export_range(0.0, 120.0, 0.05, "suffix:s") var run_2_from_s := 0.0
@export_range(0.0, 120.0, 0.05, "suffix:s") var run_2_to_s := 0.0

@export_group("Engine Stop", "stop_")
## The engine recording: switched off as the driver gets out (it dies at about 17 s).
@export_range(0.0, 120.0, 0.05, "suffix:s") var stop_from_s := 16.3
@export_range(0.0, 120.0, 0.05, "suffix:s") var stop_to_s := 17.7

@export_group("Door Open", "door_open_")
## front_door.mp3: somewhere round the door opening; the silence either side
## is trimmed off (the take's two: about 5.7 and 18.4 s).
@export_range(0.0, 30.0, 0.05, "suffix:s") var door_open_from_s := 18.2
@export_range(0.0, 30.0, 0.05, "suffix:s") var door_open_to_s := 19.4

@export_group("Door Slam", "door_slam_")
## front_door.mp3: round the slam, trimmed the same (about 11.65 and 24.1 s).
@export_range(0.0, 30.0, 0.05, "suffix:s") var door_slam_from_s := 23.9
@export_range(0.0, 30.0, 0.05, "suffix:s") var door_slam_to_s := 25.4

@export_group("Crane Moving", "crane_")
## Which recording the crane's hydraulics come from: one of the recordings in
## assets/sfx/supply_truck/ (Mike, 2026-11-11: Crane3.wav; Crane2.mp3 before).
@export_file("*.wav", "*.mp3") var crane_recording := "res://assets/sfx/supply_truck/Crane3.wav"
## Play the recording whole (Mike, 2026-11-11): from its start each time the
## crane starts moving, and if a move outlasts it, round again from a point
## found between Loop From S and Loop To S that carries on best from its end.
## Crane3.wav: quiet to 0.4 s, a start-up burst to 2.2 s, a steady quiet run to
## 16 s, building to a louder steady run from 21 s. Off: the stretches below
## are joined into a short loop instead.
@export var crane_whole_take := true
@export_range(0.0, 120.0, 0.05, "suffix:s") var crane_loop_from_s := 22.0
@export_range(0.0, 120.0, 0.05, "suffix:s") var crane_loop_to_s := 45.0
## Up to two steady stretches of it, joined into the loop that plays while the
## turret turns or the boom slides, with Whole Take off (Mike, 2026-11-09). Crane2.mp3: a thin,
## hissy run to 18.5 s, then the hydraulics working hard, lower and louder,
## steadiest 26.75-33.25 s (pulsing from 34 s). Crane.mp3: steady 1.75-10 s.
## 0 to 0: unused.
@export_range(0.0, 60.0, 0.05, "suffix:s") var crane_1_from_s := 27.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var crane_1_to_s := 33.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var crane_2_from_s := 0.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var crane_2_to_s := 0.0
## The same recording: the click played once as the hydraulics start (Mike,
## 2026-11-09). Crane2.mp3's opens it: 0-0.13 s, its hiss from 0.4 s. Not
## re-cut with Whole Take on (crane_start.wav stays as it is).
@export_range(0.0, 60.0, 0.01, "suffix:s") var crane_start_from_s := 0.0
@export_range(0.0, 60.0, 0.01, "suffix:s") var crane_start_to_s := 0.25

@export_group("Winch", "winch_")
## Winch.mp3: up to two stretches, joined into the loop that plays while the
## line takes a crate up or lets it down. A short take (0.25-2.5 s) and a long
## one (3.25-10.5 s, steadiest 3.4-7 s).
@export_range(0.0, 30.0, 0.05, "suffix:s") var winch_1_from_s := 3.4
@export_range(0.0, 30.0, 0.05, "suffix:s") var winch_1_to_s := 7.0
@export_range(0.0, 30.0, 0.05, "suffix:s") var winch_2_from_s := 0.0
@export_range(0.0, 30.0, 0.05, "suffix:s") var winch_2_to_s := 0.0

@export_group("Stabilizer", "stabilizer_")
## Which recording the stabilisers' sound comes from (Mike, 2026-11-11: Stablizer3).
@export_file("*.wav", "*.mp3") var stabilizer_recording := "res://assets/sfx/supply_truck/Stablizer3.wav"
## The part of it played, once, as the stabilisers come down or go up: the
## whole movement, start to end (the truck speeds it up or slows it to fit
## Stabilizer Down S / Up S). Stablizer3.wav: quiet to 0.4 s, building, a
## clunk at 3.4 s, gone by 4.2 s (4.6 s long). Make it as long as the movement.
@export_range(0.0, 30.0, 0.05, "suffix:s") var stabilizer_from_s := 0.2
@export_range(0.0, 30.0, 0.05, "suffix:s") var stabilizer_to_s := 4.2

@export_group("Crane Motor", "motor_")
## Which recording the crane's motor comes from (Mike, 2026-11-09): it runs
## from the operator's switch until the crane's put away.
@export_file("*.mp3") var motor_recording := "res://assets/sfx/supply_truck/CraneMotor.mp3"
## Up to two stretches, joined into its loop. CraneMotor.mp3 is 3 minutes of
## it running steadily, all the same loudness.
@export_range(0.0, 200.0, 0.05, "suffix:s") var motor_1_from_s := 5.0
@export_range(0.0, 200.0, 0.05, "suffix:s") var motor_1_to_s := 15.0
@export_range(0.0, 200.0, 0.05, "suffix:s") var motor_2_from_s := 0.0
@export_range(0.0, 200.0, 0.05, "suffix:s") var motor_2_to_s := 0.0

@export_group("Switch", "switch_")
## Which recording the operator's switch comes from, and the part of it
## played. Switch.wav: its click at 0.26 s, a little rattle from 0.18 s.
@export_file("*.wav", "*.mp3") var switch_recording := "res://assets/sfx/supply_truck/Switch.wav"
@export_range(0.0, 10.0, 0.01, "suffix:s") var switch_from_s := 0.15
@export_range(0.0, 10.0, 0.01, "suffix:s") var switch_to_s := 0.5


## Re-cuts the WAVs from these sections (Blender), then has the editor reimport them.
func cut_sounds() -> void:
	var cuts := {
		"engine": engine_recording.get_file(),
		"blend": idle_blend_s,
		"run": [[run_1_from_s, run_1_to_s], [run_2_from_s, run_2_to_s]],
		"start": [start_from_s, start_to_s],
		"stop": [stop_from_s, stop_to_s],
		"idle": [[idle_1_from_s, idle_1_to_s], [idle_2_from_s, idle_2_to_s], [idle_3_from_s, idle_3_to_s]],
		"door_open": [door_open_from_s, door_open_to_s],
		"door_slam": [door_slam_from_s, door_slam_to_s],
		"crane_recording": crane_recording.get_file(),
		"crane_start": [crane_start_from_s, crane_start_to_s],
		"crane_take": crane_whole_take,
		"crane_loop": [crane_loop_from_s, crane_loop_to_s],
		"crane": [[crane_1_from_s, crane_1_to_s], [crane_2_from_s, crane_2_to_s]],
		"winch": [[winch_1_from_s, winch_1_to_s], [winch_2_from_s, winch_2_to_s]],
		"stabilizer_recording": stabilizer_recording.get_file(),
		"stabilizer": [stabilizer_from_s, stabilizer_to_s],
		"motor_recording": motor_recording.get_file(),
		"motor": [[motor_1_from_s, motor_1_to_s], [motor_2_from_s, motor_2_to_s]],
		"switch_recording": switch_recording.get_file(),
		"switch": [switch_from_s, switch_to_s],
	}
	if not FileAccess.file_exists(BLENDER):
		push_error("Cut Sounds: Blender isn't at %s" % BLENDER)
		return
	print("Cut Sounds: cutting with Blender...")
	# The sections go in a file (Windows strips the quotes off JSON on a command line).
	var cuts_file := ProjectSettings.globalize_path(CUTS_FILE)
	var file := FileAccess.open(cuts_file, FileAccess.WRITE)
	file.store_string(JSON.stringify(cuts))
	file.close()
	var output := []
	var code := OS.execute(BLENDER, ["--background", "--factory-startup", "--python-exit-code", "1",
			"--python", ProjectSettings.globalize_path(CUTTER), "--", cuts_file], output, true)
	for line in "".join(output).split("\n"):
		if (line.begins_with("idle") or line.begins_with("driving") or line.begins_with("start") or line.begins_with("engine") or line.begins_with("loops")
				or line.begins_with("doors") or line.begins_with("crane") or line.begins_with("winch") or line.begins_with("stabilizer") or line.begins_with("motor") or line.begins_with("switch") or line.contains(".wav") or line.contains("cut_truck_sounds")):
			print("  " + line.strip_edges())
	if code != 0:
		push_error("Cut Sounds: Blender failed (exit %d); the sounds weren't changed. Its output:\n%s" % [code, "".join(output)])
		return
	# (Not named outright: this script loads in the game too, which has no editor.)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var paths := PackedStringArray()
		for sound: String in SOUNDS:
			if not FileAccess.file_exists(SOUND_DIR + sound):   # (truck_run.wav, with no driving stretch)
				continue
			paths.append(SOUND_DIR + sound)
		Engine.get_singleton("EditorInterface").get_resource_filesystem().reimport_files(paths)
	print("Cut Sounds: done. Run the game to hear them.")
