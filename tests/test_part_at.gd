extends SceneTree
const PX := 1024.0 / 12.0
func _init() -> void:
	var tower: Node2D = load("res://scenes/watch_tower.tscn").instantiate()
	root.add_child(tower)
	for spot in [["top landing, north end", Vector2(2.0, -1.6)], ["top landing, by the deck", Vector2(1.6, -1.0)], ["top of the upper flight", Vector2(2.0, -0.4)],
			["mid landing", Vector2(2.0, 1.5)], ["bottom of the mid landing", Vector2(2.0, 1.95)], ["top of the lower flight", Vector2(2.0, 2.1)], ["lower flight", Vector2(2.0, 3.0)], ["deck", Vector2(1.05, 0.5)], ["shelter", Vector2(0.0, 0.0)]]:
		print("%-26s -> %s" % [spot[0], tower.part_at(tower.to_global(spot[1] * PX))])
	quit()
