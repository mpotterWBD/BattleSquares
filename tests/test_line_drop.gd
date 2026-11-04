extends SceneTree
# A 4-crate drop turned 45 degrees: crates in one line, helicopter flies along it
# and lets each go right overhead.

const RT = preload("res://scripts/radio_terminal.gd")
const SupplyDrop = preload("res://scripts/supply_drop.gd")
const AirDrop = preload("res://scripts/air_drop.gd")

func _initialize() -> void:
	var level := Node2D.new()
	root.add_child(level)
	var rt := RT.new()
	rt.equip_slots = ["ammo", "sandbags", "", "comms"] as Array[String]
	rt._equip_queue = [3, 0, 1] as Array[int]
	rt._dz_turn = deg_to_rad(45)
	var center := Vector2(1900, 1000)
	# _dz_layout needs a viewport for spot checks; compute offsets the same way
	var pitch := RT.DROP_PITCH_M * 1024.0 / 12.0
	var filled := rt._equip_queue.duplicate(); filled.sort()
	var drops := []
	for k in filled.size():
		var pos := center + Vector2((k - (filled.size() - 1) / 2.0) * pitch, 0).rotated(rt._dz_turn)
		drops.append({scene = RT.EQUIPMENT_TYPES[0].scene, pos = pos, turn = rt._dz_turn, kind = rt.equip_slots[filled[k]]})
	print("order: ", drops.map(func(d): return d.kind))
	var heli: Node2D = RT.HELICOPTER.instantiate()
	var run := SupplyDrop.new()
	heli.add_child(run)
	level.add_child(heli)
	run.start(heli, drops, rt._dz_turn)
	print("heli start ", heli.position, " rot ", rad_to_deg(heli.rotation))
	var released := 0
	for f in 2000:
		await physics_frame
		for c in level.get_children():
			if c is AirDrop and not c.has_meta("seen"):
				c.set_meta("seen", true)
				released += 1
				var miss: float = c._from.distance_to(c._target) / (1024.0 / 12.0)
				print("release ", released, " target ", c._target, " heli offset m ", snappedf(miss, 0.01))
		if not is_instance_valid(heli):
			print("heli gone at frame ", f)
			break
	rt.free()
	quit()
