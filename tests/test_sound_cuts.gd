extends SceneTree
## The truck's sound cuts (truck_sound_cuts.gd): the resource loads on the
## truck with its sections; Cut Sounds with the second idle stretch moved
## re-cuts truck_idle.wav (a different length), the others still there.
## It overwrites the sounds: run it on the scratch copy (with assets/sfx/supply_truck/
## and blender/scripts/cut_truck_sounds.py copied), never the real project.
func _init() -> void:
	var truck = load("res://scenes/supply_truck.tscn").instantiate()
	var cuts: TruckSoundCuts = truck.sound_cuts
	print("on the truck: ", cuts != null, "; start %.2f-%.2f, idle 1 %.2f-%.2f" % [cuts.start_from_s, cuts.start_to_s, cuts.idle_1_from_s, cuts.idle_1_to_s])
	var idle := "res://assets/sfx/supply_truck/truck_idle.wav"
	var before := FileAccess.get_file_as_bytes(idle).size()
	cuts.idle_2_from_s = 24.0
	cuts.idle_2_to_s = 26.0
	cuts.cut_sounds()
	var after := FileAccess.get_file_as_bytes(idle).size()
	print("truck_idle.wav %d -> %d bytes: %s" % [before, after, "OK re-cut" if after != before and after > 0 else "FAIL"])
	truck.free()
	quit()
