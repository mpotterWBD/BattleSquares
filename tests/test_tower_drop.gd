extends SceneTree
## The watch tower crate in a helicopter drop (Mike, 2026-11-02): it's an
## equipment choice, its icon draws, and dropped with an ammo crate it lands
## as a strapped TowerCrate that builds a watch tower.

const RT = preload("res://scripts/radio_terminal.gd")
const SupplyDrop = preload("res://scripts/supply_drop.gd")
const AirDrop = preload("res://scripts/air_drop.gd")


func _initialize() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	print("equipment choices: ", RT.EQUIPMENT_TYPES.map(func(t): return t.text))
	var tower: Dictionary = RT._equipment_type("tower")
	print("tower type: ", tower.text, ", scene ", tower.scene.resource_path, ", ghost texture ", tower.tex.resource_path)

	# Its icon (as in the slot and the pop-out).
	var rt := RT.new()
	var icon := Control.new()
	icon.size = Vector2(40, 40)
	var drawn := [false]
	icon.draw.connect(func():
		rt._draw_crate(icon, "tower", icon.size / 2.0, 1.4, 1.0)
		drawn[0] = true)
	level.add_child(icon)
	await process_frame
	await process_frame
	print("icon drew without errors: ", drawn[0])

	var center := Vector2(1900, 1000)
	var pitch := RT.DROP_PITCH_M * 1024.0 / 12.0
	var drops := []
	for k in 2:
		var kind: String = ["ammo", "tower"][k]
		drops.append({scene = RT._equipment_type(kind).scene, pos = center + Vector2((k - 0.5) * pitch, 0), turn = 0.0})
	var heli: Node2D = RT.HELICOPTER.instantiate()
	var run := SupplyDrop.new()
	heli.add_child(run)
	level.add_child(heli)
	run.start(heli, drops, 0.0)
	for f in 3000:
		await physics_frame
		if not is_instance_valid(heli) and not level.get_children().any(func(c): return c is AirDrop):
			break
	for c in level.get_children():
		if c.get("builds") != null:
			print("landed: %s at %s, strapped %s, builds %s, parts %s" % [c.name, c.position.round(), c.strapped, c.builds, c.parts])
	rt.free()
	quit()
