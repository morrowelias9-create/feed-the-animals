class_name TutorialController
extends Node3D
## Обучение (T19, T30, справочник R6 «Обучение»). Шаг хранится в Save.data["tutorial_step"], цель выводится в HUD.
## Шаги: 0 идти к линии броска, 1 бросить, 2 накопить и купить яблоко (в палатке еды), 3 подтянуться 10 раз, 4 бросить 5 раз,
## 5 обучение закончено. Условия перехода проверяются раз в CHECK_S секунд по состоянию игры,
## поэтому сохранение с прогрессом само пролистывает пройденные шаги. После шага 4 подсказки исчезают навсегда.

const STEP_DONE: int = 5
const CHECK_S: float = 0.2
const REPS_GOAL: int = 10               # повторений на турнике для шага 3
const THROWS_GOAL: int = 5              # бросков после шага 3 для шага 4
const APPLE_ID: String = "apple"
const GOAL_KEYS: Array[String] = ["tut_goal_0", "tut_goal_1", "tut_goal_2", "tut_goal_3", "tut_goal_4"]

var player: Player
var hud: Hud

var _arrows: GuideArrows
var _step: int = 0
var _check_t: float = 0.0
var _throws_at_step4: int = 0
var _apple_tier: int = 1
var _shop_pulse: bool = false
var _arrows_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	_step = clampi(int(Save.data.get("tutorial_step", 0)), 0, STEP_DONE)
	_apple_tier = _find_apple_tier()
	Loc.language_changed.connect(_apply_goal)
	if _step >= STEP_DONE:
		_finish()
		return
	_arrows = GuideArrows.new()
	_arrows.name = "GuideArrows"
	_arrows.player = player
	add_child(_arrows)
	if _step == 4:
		_throws_at_step4 = _throws()
	_apply_step()


func _process(delta: float) -> void:
	_check_t += delta
	if _check_t < CHECK_S:
		return
	_check_t = 0.0
	var advanced: bool = false
	while _step < STEP_DONE and _step_completed(_step):
		_step += 1
		advanced = true
		if _step == 4:
			_throws_at_step4 = _throws()
	if advanced:
		Save.data["tutorial_step"] = _step
		Save.save_data()
		if _step >= STEP_DONE:
			_finish()
			return
		_apply_step()
	_update_shop_pulse()
	_update_arrows_target()


# Условие завершения шага step (таблица R6).
func _step_completed(step: int) -> bool:
	match step:
		0:
			return _in_throw_zone()
		1:
			return _throws() >= 1
		2:
			return int(Save.data.get("food_unlocked", 0)) >= _apple_tier
		3:
			return int(Save.data.get("reps", 0)) >= REPS_GOAL
		4:
			return _throws() - _throws_at_step4 >= THROWS_GOAL
	return true


# Цель в HUD, пульс подсказки и стрелки для текущего шага.
func _apply_step() -> void:
	_apply_goal()
	hud.set_hint_pulse(_step == 1)
	_update_shop_pulse()
	_update_arrows_target()


func _apply_goal() -> void:
	if _step >= STEP_DONE:
		hud.set_goal("")
		return
	hud.set_goal(Loc.t(GOAL_KEYS[_step]))


# Кнопка «Магазин» пульсирует на шаге 1 (подсказка броска), на шаге 2 пульсации нет — покупка в палатке.
func _update_shop_pulse() -> void:
	var want: bool = _step == 1
	if want == _shop_pulse:
		return
	_shop_pulse = want
	hud.set_shop_pulse(want)


# Стрелки: шаг 0 — к линии броска; шаг 2 — к палатке еды (когда хватает денег и яблоко не куплено);
# шаг 3 — к диску покупки турника, потом к самому турнику.
func _update_arrows_target() -> void:
	if _arrows == null:
		return
	match _step:
		0:
			var center: Vector2 = WorldLayout.throw_line_rect().get_center()
			_point_arrows(Vector3(center.x, 0.0, center.y))
		2:
			# Показываем стрелки к палатке еды, только если яблоко доступно для покупки и ещё не куплено.
			if int(Save.data.get("food_unlocked", 0)) < _apple_tier and Game.money() >= _apple_price():
				_point_arrows(WorldLayout.food_tent_position())
			elif _arrows.is_active():
				_arrows.hide_guide()
		3:
			if Game.bars_owned() == 0:
				_point_arrows(WorldLayout.buy_pad_position())
			else:
				_point_arrows(WorldLayout.bar_position())
		_:
			if _arrows.is_active():
				_arrows.hide_guide()


# Цель стрелок меняется редко; сами стрелки обновляются по своему таймеру.
func _point_arrows(target: Vector3) -> void:
	if _arrows.is_active() and _arrows_target.is_equal_approx(target):
		return
	_arrows_target = target
	_arrows.show_to(target)


# Обучение закончено: цели нет, подсказок нет, узел больше ничего не проверяет.
func _finish() -> void:
	hud.set_goal("")
	hud.set_hint_pulse(false)
	hud.set_shop_pulse(false)
	if _arrows != null:
		_arrows.queue_free()
		_arrows = null
	set_process(false)


func _in_throw_zone() -> bool:
	if player == null:
		return false
	return WorldLayout.throw_zone_rect().has_point(Vector2(player.position.x, player.position.z))


func _throws() -> int:
	return int(Save.data.get("throws", 0))


func _apple_price() -> float:
	return float(FoodData.FOODS[_apple_tier]["price"])


func _find_apple_tier() -> int:
	for i in FoodData.FOODS.size():
		if String(FoodData.FOODS[i]["id"]) == APPLE_ID:
			return i
	return 1
