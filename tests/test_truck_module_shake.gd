extends SceneTree
## The supply truck's engine module shakes while the engine runs (Mike,
## 2026-11-11): still with it off; module_shake_m at idle (the wobble's never
## more than that a side, so the gap it opens in the body stays small); more
## while it's cranking. Prints OK / FAIL.
const PX := 1024.0 / 12.0

var fails := 0


func check(what: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## How far the module strays from its place over `ticks` frames (m).
func stray(truck: Node2D, ticks: int) -> float:
	var most := 0.0
	for f in ticks:
		await process_frame
		await physics_frame
		most = maxf(most, (truck._module.position / PX - truck.MODULE_AT_M).length())
	return most


func _initialize() -> void:
	var truck: Node2D = load("res://scenes/supply_truck.tscn").instantiate()
	root.add_child(truck)
	await process_frame
	check("the module is its own sprite, on the body", truck._module != null and truck._module.texture != null)
	var off: float = await stray(truck, 30)
	check("engine off: still (%.4f m)" % off, off == 0.0)
	truck._engine = truck.EngineState.RUNNING
	var idle: float = await stray(truck, 90)
	var shake: float = truck.module_shake_m
	check("running: it shakes (%.4f m), no more than module_shake_m a side (%.3f)" % [idle, shake],
			idle > shake * 0.3 and idle <= shake * 1.42)
	truck._engine = truck.EngineState.STARTING
	var cranking: float = await stray(truck, 90)
	check("cranking: it shakes more (%.4f m)" % cranking, cranking > idle)
	truck._engine = truck.EngineState.OFF
	var stopped: float = await stray(truck, 5)
	check("off again: back in its place", stopped == 0.0)
	print("DONE, %d failed" % fails)
	quit(fails)
