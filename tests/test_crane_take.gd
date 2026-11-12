extends SceneTree
## The crane's hydraulics as a whole take (2026-11-11): crane_move.wav (cut from
## Crane3.wav by cut_truck_sounds.py) carries its own loop points, which Godot
## reads on import; the truck's player keeps them, so a long move plays the take
## from its start, then repeats only the part inside it. Prints OK / FAIL.

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var wav: AudioStreamWAV = load("res://assets/sfx/supply_truck/crane_move.wav")
	var rate := float(wav.mix_rate)
	var frames := wav.get_length() * rate
	print("    crane_move.wav: %.2f s, loop %s, %.2f-%.2f s" % [wav.get_length(), wav.loop_mode, wav.loop_begin / rate, wav.loop_end / rate])
	check("its loop points came in from the WAV: forward", wav.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	check("it repeats a part well inside it, to (about) its end",
			wav.loop_begin > 10.0 * rate and wav.loop_end > frames - 0.1 * rate and wav.loop_end - wav.loop_begin > 5.0 * rate)
	var truck: Node2D = load("res://scenes/supply_truck.tscn").instantiate()
	root.add_child(truck)
	await process_frame
	var played: AudioStreamWAV = truck._crane_snd.stream
	check("the truck's player keeps them (not looping the whole take from 0)",
			played.loop_mode == AudioStreamWAV.LOOP_FORWARD and played.loop_begin == wav.loop_begin and played.loop_end == wav.loop_end)
	var winch: AudioStreamWAV = truck._winch_snd.stream
	check("a sound with no loop points of its own (the winch) still loops whole", winch.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and winch.loop_begin == 0)
	print("DONE, %d failed" % fails)
	quit(fails)
