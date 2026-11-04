extends SceneTree
## Getting on the stair from all round its foot (Mike, 2026-11-02: "a small
## space I go behind when getting on the ramp"). From a grid of starts in
## front of and beside the foot, walking up, up-left or up-right, flags any
## frame where the square is:
##   - on the tower but outside the stair's sides (x < 1.6 or > 2.4 north of
##     the bottom step, 4.1): it's slipped outside the walls;
##   - on the ground but overlapping the stair (its top edge north of 4.1
##     between the sides): it's drawn under the stair.

const PX := 1024.0 / 12.0
const HALF := 0.2

var main: Node
var player: Node2D
var tower: Node2D


func _m() -> Vector2:
	return tower.to_local(player.global_position) / PX


func _release() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arrival").enabled = false
	root.add_child(main)
	current_scene = main
	for e in main.get_children():
		if e.get_script() and e.get_script().resource_path.ends_with("enemy.gd"):
			e.queue_free()
	player = main.get_node("Player")
	tower = load("res://scenes/watch_tower.tscn").instantiate()
	tower.position = Vector2(30, 8) * PX
	main.add_child(tower)
	for f in 3: await physics_frame

	var bad := 0
	var runs := 0
	for start in [Vector2(2.0, 5.4), Vector2(1.5, 5.4), Vector2(2.5, 5.4), Vector2(1.3, 5.0), Vector2(2.7, 5.0),
			Vector2(1.0, 4.6), Vector2(3.0, 4.6), Vector2(1.2, 4.4), Vector2(2.8, 4.4), Vector2(0.6, 5.2), Vector2(3.4, 5.2),
			Vector2(1.45, 4.5), Vector2(2.55, 4.5)]:
		for keys in [["move_up"], ["move_up", "move_right"], ["move_up", "move_left"]]:
			runs += 1
			player._set_tower(null)
			player.global_position = tower.to_global(start * PX)
			for f in 3: await physics_frame
			for k in keys:
				Input.action_press(k)
			var outside := 0
			var under := 0
			var first := ""
			for f in 240:
				await physics_frame
				var m := _m()
				if player.tower == tower and m.y < 4.1 and (m.x < 1.6 or m.x > 2.4):
					outside += 1
					if first == "": first = "outside the walls at (%.2f, %.2f)" % [m.x, m.y]
				if player.tower == null and m.y - HALF < 4.1 and m.x + HALF > 1.6 and m.x - HALF < 2.4 and m.y > 2.0:
					under += 1
					if first == "": first = "under the stair at (%.2f, %.2f)" % [m.x, m.y]
				if m.y < 2.5 or m.y > 6.5 or m.x < -1.0 or m.x > 5.0:
					break
			_release()
			var m := _m()
			if outside or under:
				bad += 1
				print("from (%.2f, %.2f) %-24s: %d frames outside, %d under; first %s; ended (%.2f, %.2f) on tower %s" % [
					start.x, start.y, str(keys), outside, under, first, m.x, m.y, player.tower != null])
			for f in 5: await physics_frame
	print("%d of %d approaches went wrong" % [bad, runs])
	quit()
