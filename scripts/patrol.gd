extends Node
## A patrol of enemies (made by scripts/enemy_spawner.gd, a testing aid)
## walking across the field from right to left in formation.
##
## It moves an anchor point steadily along `heading`, at PACE of the
## members' walking speed so stragglers can catch up; each calm member keeps
## to its slot, the anchor plus its offset (enemy.gd _keep_patrol_slot()).
## While any member is fighting or searching, the anchor waits. Once they're
## all calm again it starts afresh from where they are (the average of their
## positions less their offsets), so they re-form and walk on. A member that
## reaches the field's left edge walks off it (is removed); the patrol goes
## once it has nobody left.

const World = preload("res://scripts/world.gd")

const PACE := 0.8        ## the anchor's speed, as a fraction of walking speed
const EXIT_M := 0.6      ## a member this close to the left edge walks off the field

var heading := Vector2.LEFT
var anchor := Vector2.ZERO
var _offsets := {}       ## member -> offset from the anchor (px)
var _paused := false


## Adds `member` (an enemy, not in the tree yet) at `offset` (px) from the anchor.
func add(member: Node2D, offset: Vector2) -> void:
	_offsets[member] = offset
	member.patrol = self


## `member` leaves the patrol (e.g. to dig in behind sandbags, enemy.gd).
func release(member: Node2D) -> void:
	_offsets.erase(member)


## Where `member` should be: its slot in the formation.
func slot_for(member: Node2D) -> Vector2:
	return anchor + _offsets.get(member, Vector2.ZERO)


func _physics_process(delta: float) -> void:
	for member in _offsets.keys():
		if not is_instance_valid(member) or member.dead:
			_offsets.erase(member)
	if _offsets.is_empty():
		queue_free()
		return
	var members: Array = _offsets.keys()
	if members.any(func(m): return not m.is_calm()):
		_paused = true
		return
	if _paused:
		_paused = false
		var sum := Vector2.ZERO
		for member: Node2D in members:
			sum += member.global_position - _offsets[member]
		anchor = sum / members.size()
	var px := World.PX_PER_M
	anchor += heading * members[0].speed_mps * PACE * px * delta
	for member: Node2D in members:
		if member.global_position.x <= World.ARENA.position.x + EXIT_M * px:
			_offsets.erase(member)
			member.queue_free()
