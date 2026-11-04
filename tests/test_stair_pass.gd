extends SceneTree
## Shooting across the watch tower's lower flight from the ground: the share
## that gets through follows the lower stairs profile's Pass Through.

const PX := 1024.0 / 12.0
const Bullet = preload("res://scripts/bullet.gd")


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(20, 12) * PX
	level.add_child(tower)
	for f in 3: await physics_frame
	for pct in [0, 50, 100]:
		var profile: HeightProfile = tower.lower_stairs.duplicate(true)
		profile.pass_through = pct
		tower.lower_stairs = profile
		tower._apply_stair_profile()
		await physics_frame
		var through := 0
		var shots := 300
		var from := tower.to_global(Vector2(0.6, 3.0) * PX)   # beside the flight, west
		for i in shots:
			var b: Node2D = Bullet.new()
			b.setup(from, 0.0, 30.0, null, 0.0)   # east, across it
			b.ground_at_m = 40.0
			level.add_child(b)
			for f in 20:
				await physics_frame
				if not is_instance_valid(b):
					break
				if tower.to_local(b.global_position).x / PX > 2.8:
					through += 1
					b.queue_free()
					break
		print("Pass Through %3d%%: stair hit chance %.2f; bullets across it %d%%" % [pct, tower.get_node("StairsBody").hit_chance, roundi(100.0 * through / shots)])
	quit()
