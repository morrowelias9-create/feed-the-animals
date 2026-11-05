class_name PenWander
extends Node
## Автономные прогулки размещённых зверей. Переиспользует существующие AnimalView.

const WAIT_MIN := 3.0
const WAIT_MAX := 7.0
const SPEED_MIN := 1.0
const SPEED_MAX := 1.6
const EDGE_MARGIN := 1.5

var manager: Node
var _wait: Dictionary = {}
var _targets: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _paused := false


func _ready() -> void:
	_rng.randomize()
	refresh()


func refresh() -> void:
	var alive: Dictionary = {}
	for a in Game.placed_animals():
		var uid := int(a["uid"])
		alive[uid] = true
		if not _wait.has(uid):
			_wait[uid] = _rng.randf_range(WAIT_MIN, WAIT_MAX)
	for key in _wait.keys():
		if not alive.has(int(key)):
			_wait.erase(key)
			_targets.erase(key)


func _process(delta: float) -> void:
	if manager == null:
		return
	var pause_now := false
	if manager.throw_controller != null:
		var state := String(manager.throw_controller.get("state"))
		pause_now = state == ThrowController.STATE_FLIGHT or state == ThrowController.STATE_REVEAL
	if pause_now != _paused:
		_paused = pause_now
		for child in manager.get_children():
			if child is AnimalView:
				child.set_process(not _paused)
	if _paused:
		return
	for a in Game.placed_animals():
		var uid := int(a["uid"])
		var view := manager.view_of(uid)
		if view == null:
			continue
		if _targets.has(uid):
			var target: Vector3 = _targets[uid]
			if view.position.distance_to(target) < 0.2:
				Game.move_placed(uid, target)
				_targets.erase(uid)
				_wait[uid] = _rng.randf_range(WAIT_MIN, WAIT_MAX)
			elif view.is_running():
				continue
			else:
				_targets.erase(uid)
				_wait[uid] = _rng.randf_range(WAIT_MIN, WAIT_MAX)
			continue
		_wait[uid] = float(_wait.get(uid, WAIT_MIN)) - delta
		if float(_wait[uid]) <= 0.0:
			var rect := WorldLayout.pen_rect_for_level(int(Save.data.get("slots_level", 0)), EDGE_MARGIN)
			var target := Vector3(
				_rng.randf_range(rect.position.x, rect.end.x),
				0.0,
				_rng.randf_range(rect.position.y, rect.end.y)
			)
			_targets[uid] = target
			var duration := maxf(view.position.distance_to(target) / _rng.randf_range(SPEED_MIN, SPEED_MAX), 0.1)
			view.run_to(target, duration)
