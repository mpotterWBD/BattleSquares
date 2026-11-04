extends SceneTree
## Firing down from a watch tower: lower cover stops less, by section.

const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")
const Cover = preload("res://scripts/cover.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(8, 6) * PX
	main.add_child(tower)
	var player: Node2D = main.get_node("Player")
	var sandbags: Node2D = load("res://scenes/sandbags.tscn").instantiate()
	main.add_child(sandbags)
	var crate: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	main.add_child(crate)
	for f in 3: await physics_frame
	print("height classes: sandbags %d, crate %d, desk %d, tower %d, tower legs %d, helicopter-ish (no say) %d" % [Cover.height_class_of(sandbags),
			Cover.height_class_of(crate), Cover.height_class_of(main.get_node("RadioStation/DeskBody")), tower.top_height_class,
			Cover.height_class_of(tower.get_node("LegsBody")), Cover.height_class_of(main.get_node("Road"))])
	for where in [["deck", Vector2(1.05, 0.0), true], ["ground", Vector2(-3.0, 0.0), false]]:
		player.global_position = tower.to_global(where[1] * PX)
		player._set_tower(tower if where[2] else null)
		player.elevation_m = 3.0 if where[2] else 0.0
		for d in [3.0, 8.0, 15.0, 25.0, 40.0]:
			var row := []
			for target in [sandbags, crate]:
				sandbags.global_position = Vector2(-50, -50) * PX
				crate.global_position = Vector2(-60, -60) * PX
				target.global_position = tower.global_position + Vector2(d, 0) * PX
				for f in 2: await physics_frame
				var through := 0
				for i in 2000:
					var b := Bullet.new()
					b.setup(player.global_position, 0.0, 300.0, player)
					b.global_position = target.global_position - Vector2(0.4, 0) * PX
					var q := PhysicsRayQueryParameters2D.create(b.global_position, target.global_position + Vector2(0.5, 0) * PX)
					q.collide_with_bodies = true
					var hit := root.get_world_2d().direct_space_state.intersect_ray(q)
					if hit.is_empty() or hit.collider != target:
						b.free()
						continue
					if (target.has_method("lets_bullet_through") and target.lets_bullet_through(b)) or b._fired_down_past(hit):
						through += 1
					b.free()
				row.append("%s %4.1f%% through" % ["sandbags" if target == sandbags else "crate", through / 20.0])
			print("from the %-6s at %4.1f m (section %d): %s" % [where[0], d, tower.section_at(tower.global_position + Vector2(d, 0) * PX), " | ".join(row)])
	# The AI: a squadmate up the tower judging a foe behind sandbags.
	var mate: Node2D = main.get_node("Squadmate")
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate()
	main.add_child(enemy)
	sandbags.global_position = tower.global_position + Vector2(4.0, 0) * PX
	sandbags.rotation = 0.0
	enemy.global_position = sandbags.global_position + Vector2(0.5, 0) * PX
	enemy.speed_mps = 0.0
	for f in 3: await physics_frame
	mate.global_position = tower.to_global(Vector2(1.05, 0.0) * PX)
	mate._set_tower(tower)
	mate.elevation_m = 3.0
	print("squadmate on the deck: foe 4.5 m out behind sandbags shielded? %s" % mate._shielded(enemy))
	mate._set_tower(null)
	mate.elevation_m = 0.0
	mate.global_position = tower.to_global(Vector2(1.05, 2.2) * PX) - Vector2(0, 2.2) * PX
	print("same squadmate on the ground: shielded? %s" % mate._shielded(enemy))
	# The desk lets 70% through already: a lower setting doesn't make it stronger.
	tower.section_1_class_1_new_pass_through = 50
	var desk: Node2D = main.get_node("RadioStation/DeskBody")
	var pt: Vector2 = tower.global_position + Vector2(2, 0) * PX
	print("desk (lets 70%% through), setting 50: extra %.2f -> through %.0f%%" % [Cover.fired_down_extra(desk, pt, mate), 100.0 * (0.7 + 0.3 * Cover.fired_down_extra(desk, pt, mate))])
	quit()
