extends SceneTree
## Early-deploy crates are dropped by a supply helicopter before the player's
## helicopter comes in.

const PX := 1024.0 / 12.0
const World = preload("res://scripts/world.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var c1: Node2D = main.get_node("AmmoCrate")
	var c2: Node2D = main.get_node("SandbagCrate")
	c1.early_deploy = true
	c2.early_deploy = true
	c2.rotation = 0.5
	c1.strapped = true
	var want1 := c1.position
	var want2 := c2.position
	root.add_child(main)
	current_scene = main
	var player: Node2D = main.get_node("Player")
	var landed := {}
	var heli_seen := []
	var player_out := -1.0
	for f in 60 * 60:
		await physics_frame
		var t := f / 60.0
		if f < 3:
			continue
		for n in main.get_children():
			if n.has_node("Hull") and not n in heli_seen:
				heli_seen.append(n)
				var kind := "supply" if n.get_children().any(func(c): return c.get_script() and c.get_script().resource_path.ends_with("supply_drop.gd")) else "insertion"
				print("%5.1f s  %s helicopter appears" % [t, kind])
		for c in [c1, c2]:
			if not landed.has(c) and c.is_inside_tree() and c.z_index == 0 and c.get_node("Collision").disabled == false and c.global_position.distance_to(want1 if c == c1 else want2) < 1.0:
				landed[c] = t
				print("%5.1f s  %s down at %s (placed %s), turned %.2f, strapped %s" % [t, c.name, (c.global_position / PX).snapped(Vector2(0.01, 0.01)),
						((want1 if c == c1 else want2) / PX).snapped(Vector2(0.01, 0.01)), c.rotation, c.strapped])
		if f == 30:
			print("  0.5 s  in tree: AmmoCrate %s, SandbagCrate %s; player visible %s, aboard %s" % [c1.is_inside_tree(), c2.is_inside_tree(), player.visible, World.player_aboard])
		if player_out < 0 and player.visible and not World.player_aboard:
			player_out = t
			print("%5.1f s  player out of the helicopter at %s" % [t, (player.global_position / PX).snapped(Vector2(0.01, 0.01))])
			break
	quit()
