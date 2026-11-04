class_name ArrivalController
extends Node3D
## Зверь приходит после приземления и забирается игроком (шаг T10, справочник R2/R3/R8).
## Слушает событие landed у ThrowController: появление зверя, бег к еде, еда, получение.

const RUN_S: float = 1.2
const EAT_S: float = 0.6
const POPUP_S: float = 1.2

var throw_controller: ThrowController
var _phase: int = 0
var _phase_t: float = 0.0
var _finished: bool = false
var _animal_id: String = ""
var _gold: bool = false
var _rarity: int = 0
var _income: float = 0.0
var _target: Vector3 = Vector3.ZERO
var _view: AnimalView
var _popup: Label3D
var _popup_t: float = 0.0


func _ready() -> void:
	var parent := get_parent() as ThrowController
	if parent != null and not parent.landed.is_connected(_on_landed):
		parent.landed.connect(_on_landed)


## Событие приземления еды: запуск прибытия зверя.
func _on_landed(dist: float, zone: int, perfect: bool, position: Vector3) -> void:
	start(zone, position)


func start(zone: int, position: Vector3) -> void:
	_finished = false
	var rng := RandomNumberGenerator.new()
	var roll: Dictionary = SpawnRoller.roll(zone, int(Save.data.get("food_selected", 0)), rng)
	_animal_id = String(roll["animal_id"])
	_gold = int(roll["gold"]) == 1
	var data: Dictionary = AnimalData.by_id(_animal_id)
	_rarity = int(data.get("rarity", 0))
	_income = Economy.income(_animal_id, int(roll["gold"]))
	_target = position
	_phase = 0
	_phase_t = 0.0
	_finished = false
	_spawn(position)


func is_finished() -> bool:
	return _finished


func _process(delta: float) -> void:
	if _finished or _view == null:
		return
	_phase_t += delta
	if _phase == 0:
		_view.run_to(_target, RUN_S)
		if _phase_t >= RUN_S:
			_phase_t = 0.0
			_phase = 1
			_view.eat()
			_popup.visible = true
			_popup_t = 0.0
	elif _phase == 1:
		_popup_t += delta
		if _popup_t >= POPUP_S:
			_popup_t = 0.0
			_popup.visible = false
		if _phase_t >= EAT_S:
			_phase_t = 0.0
			_finish()


func _spawn(position: Vector3) -> void:
	var view := AnimalView.new()
	view.name = "AnimalView"
	add_child(view)
	view.set_creature(_animal_id, _gold, _rarity, _income)
	view.position = position + Vector3(0.0, 0.0, -12.0)
	_view = view
	_popup = _make_popup()
	var camera_rig := throw_controller.camera_rig
	if camera_rig != null:
		camera_rig.follow_food(view)


func _make_popup() -> Label3D:
	var l := Label3D.new()
	l.name = "ArrivePopup"
	l.visible = false
	l.font_size = 30
	l.modulate = Color.WHITE
	add_child(l)
	return l


func _finish() -> void:
	var title: String = Loc.t("animal_" + _animal_id)
	_popup.text = Loc.t("arrive_popup") % [title, Loc.t("rarity_" + str(_rarity))]
	_popup.visible = true
	_popup_t = 0.0
	if _rarity >= 3:
		throw_controller.hud.show_rare_card(title, _rarity, _income)
	Game.add_animal(_animal_id, _gold)
	_view.queue_free()
	_finished = true
	throw_controller.arrival_done()
