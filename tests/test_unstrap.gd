extends SceneTree
## Unstrapping crates: the player holding F, letting go early, and
## squadmates on a Build order undoing the straps before taking a part.

const PX := 1024.0 / 12.0


class FakeSite extends Node2D:
	var got := 0
	func _ready() -> void:
		add_to_group("build_sites")
	func needs(_part: String) -> bool:
		return got < 1
	func can_deliver_at(at: Vector2) -> bool:
		return at.distance_to(global_position) < 1.0 * PX
	func install(_part: String) -> void:
		got += 1


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func tex(crate: Node2D) -> String:
	return crate.get_node("Body").texture.resource_path.get_file()


func _init() -> void:
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(1000, 1000)
	level.add_child(player)
	var crate: Node2D = load("res://scenes/crate_sandbags.tscn").instantiate()
	crate.position = Vector2(1000 + 0.9 * PX, 1000)
	level.add_child(crate)
	var ammo: Node2D = load("res://scenes/crate_ammo.tscn").instantiate()
	ammo.position = Vector2(400, 400)
	level.add_child(ammo)
	var can: Node2D = load("res://scenes/ammo_can.tscn").instantiate()
	can.position = Vector2(300, 300)
	level.add_child(can)
	await process_frame
	await ticks(2)
	var site := FakeSite.new()
	site.position = Vector2(1000, 1300)
	level.add_child(site)
	crate.reserve(site, 1)
	print("start: sandbags strapped=%s (%s), ammo strapped=%s (%s), can strapped=%s (%s)" % [crate.strapped, tex(crate),
			ammo.strapped, tex(ammo), can.strapped, tex(can)])
	print("while strapped: can_take=%s can_unstrap=%s key=%s" % [crate.can_take(player), crate.can_unstrap(player), crate._key.visible])

	Input.action_press("interact")
	await ticks(60)
	await process_frame
	print("held 1 s: progress=%.2f ring=%s" % [crate.unstrap_progress, crate._ring.visible])
	Input.action_release("interact")
	await ticks(3)
	print("let go: progress=%.2f strapped=%s" % [crate.unstrap_progress, crate.strapped])

	Input.action_press("interact")
	var held := 0
	while crate.strapped and held < 300:
		await physics_frame
		held += 1
	Input.action_release("interact")
	await ticks(2)
	print("held again %.2f s: strapped=%s tex=%s can_take=%s" % [held / 60.0, crate.strapped, tex(crate), crate.can_take(player)])
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await ticks(2)
	print("F press: player carrying '%s', crate tex=%s" % [player.carrying, tex(crate)])

	# Two squadmates building from a strapped comms crate.
	var crate2: Node2D = load("res://scenes/crate_comms.tscn").instantiate()
	crate2.position = Vector2(2200, 1000)
	level.add_child(crate2)
	var site2 := FakeSite.new()
	site2.position = Vector2(2200, 1400)
	level.add_child(site2)
	await ticks(2)
	crate2.reserve(site2, 1)
	var mate: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	mate.position = Vector2(2200 - 3 * PX, 1000)
	level.add_child(mate)
	var mate2: Node2D = load("res://scenes/squadmate.tscn").instantiate()
	mate2.position = Vector2(2200 + 3.5 * PX, 1000)
	level.add_child(mate2)
	await ticks(2)
	mate.order_build()
	mate2.order_build()
	var t := 0
	var began := -1
	var off := -1
	var both_worked := false
	var who: Node2D = null
	while t < 60 * 20 and site2.got == 0:
		await physics_frame
		t += 1
		if began < 0 and crate2.unstrap_progress > 0.0:
			began = t
			who = crate2._unstrapper
		if crate2._unstrapper != null and who != null and crate2._unstrapper != who:
			both_worked = true
		if off < 0 and not crate2.strapped:
			off = t
	print("squad: straps begun %.2f s by %s, off at %.2f s (%.2f s work), part delivered=%d at %.2f s, unstrapper changed=%s"
			% [began / 60.0, "mate" if who == mate else "mate2", off / 60.0, (off - began) / 60.0, site2.got, t / 60.0, both_worked])
	print("comms tex now %s" % tex(crate2))
	quit()
