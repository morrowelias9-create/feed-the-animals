class_name Hud
extends Control
## HUD: деньги, сила, кнопки, подсказка цели, шкала броска (шаги T08/T09, справочник R6).
## Сцена: scenes/ui/hud.tscn (Control на весь экран, mouse_filter = IGNORE, якоря от краёв).

signal index_pressed
signal shop_pressed
signal animals_pressed
signal bonus_pressed               # T14: тап по пузырю-бонусу на турнике

const BONUS_SIZE: float = 96.0

var _full: bool = true
var _throw_meter_enabled: bool = true

var _goal: Label
var _hint: Label
var _strength: Label
var _money: Label
var _income: Label
var _buttons: Dictionary = {}
var throw_meter: ThrowMeter
var xp_bar: XpBar                       # T14: шкала «Уровень N x/y», видна только на тренировке
var _bonus: Button                      # T14: пузырь-бонус 96x96 в экранных координатах
var _training: bool = false
var _bonus_shown: bool = false
var _index_pulse_tween: Tween
var _index_has_reward: bool = false


func _ready() -> void:
	_build_texts()
	_build_stats()
	_build_buttons()
	_build_throw_meter()
	_build_training()
	_refresh()
	if not Game.money_changed.is_connected(_on_money_changed):
		Game.money_changed.connect(_on_money_changed)
	if not Game.strength_changed.is_connected(_on_strength_changed):
		Game.strength_changed.connect(_on_strength_changed)
	Loc.language_changed.connect(_on_language_changed)


func set_goal(text: String) -> void:
	_goal.text = text


func set_hint(text: String) -> void:
	_hint.text = text


func set_mode(full: bool) -> void:
	_full = full
	_update_visibility()


## Отключает шкалу броска независимо от режима HUD (например, пока зверь в руках).
func set_throw_meter_enabled(enabled: bool) -> void:
	_throw_meter_enabled = enabled
	_update_visibility()


## Кинематика получения зверя: HUD скрыт целиком, кнопки недоступны (справочник R2, фаза REVEAL).
func set_reveal(active: bool) -> void:
	visible = not active


## В полёте шкала броска скрывается: приземление уже сделано, цель — полёт.
func set_flight(active: bool) -> void:
	if throw_meter != null:
		throw_meter.visible = not active and not _full and _throw_meter_enabled


func set_strength(value: int) -> void:
	_strength.text = str(value)


func set_money(value: float) -> void:
	_money.text = NumFmt.money(value)


func set_income_per_sec(value: float) -> void:
	_income.text = NumFmt.money(value) + "/s"


func _on_money_changed(value: float) -> void:
	_money.text = NumFmt.money(value)


func _on_strength_changed(value: int) -> void:
	_strength.text = str(value)


func _on_language_changed() -> void:
	_goal.text = Loc.t("goal_buy_bar")
	_hint.text = Loc.t("hint_throw")
	var index_button: Button = _buttons["index"]
	index_button.text = Loc.t("index")
	var shop_button: Button = _buttons["shop"]
	shop_button.text = Loc.t("shop")
	var animals_button: Button = _buttons["animals"]
	animals_button.text = Loc.t("animals")


func _build_texts() -> void:
	_goal = UiStyle.outline_label(Loc.t("goal_buy_bar"), 30, 6, UiStyle.COLOR_TEXT)
	_goal.position = Vector2(0.0, 68.0)
	_goal.size = Vector2(1280.0, 30.0)
	add_child(_goal)

	_hint = UiStyle.outline_label(Loc.t("hint_throw"), 33, 6, UiStyle.COLOR_TEXT)
	_hint.position = Vector2(0.0, 562.0)
	_hint.size = Vector2(1280.0, 34.0)
	add_child(_hint)


func _build_stats() -> void:
	_strength = UiStyle.outline_label(str(Game.strength()), 46, 6, UiStyle.COLOR_STRENGTH)
	_strength.position = Vector2(20.0, 564.0)
	_strength.size = Vector2(360.0, 46.0)
	add_child(_strength)

	_money = UiStyle.outline_label(NumFmt.money(Game.money()), 50, 6, UiStyle.COLOR_MONEY)
	_money.position = Vector2(20.0, 642.0)
	_money.size = Vector2(360.0, 50.0)
	add_child(_money)

	_income = UiStyle.outline_label(NumFmt.money(Game.income_per_sec()) + "/s", 26, 4, UiStyle.COLOR_MONEY)
	_income.position = Vector2(20.0, 701.0)
	_income.size = Vector2(360.0, 26.0)
	add_child(_income)


func _build_buttons() -> void:
	_buttons.clear()
	var index_button: Button = UiStyle.make_icon_button("index", UiStyle.ICON_DIR + "index.png", Loc.t("index"), self)
	index_button.position = Vector2(13.0, 253.0)
	index_button.size = Vector2(94.0, 94.0)
	index_button.pressed.connect(_on_index_pressed)
	_buttons["index"] = index_button

	var shop_button: Button = UiStyle.make_icon_button("shop", UiStyle.ICON_DIR + "shop.png", Loc.t("shop"), self)
	shop_button.position = Vector2(13.0, 370.0)
	shop_button.size = Vector2(94.0, 94.0)
	shop_button.pressed.connect(_on_shop_pressed)
	_buttons["shop"] = shop_button

	var animals_button: Button = UiStyle.make_icon_button("animals", UiStyle.ICON_DIR + "animals.png", Loc.t("animals"), self)
	animals_button.position = Vector2(1173.0, 313.0)
	animals_button.size = Vector2(94.0, 94.0)
	animals_button.pressed.connect(_on_animals_pressed)
	_buttons["animals"] = animals_button


# ---------- Тренировка на турнике (T14) ----------

## Включает и выключает шкалу опыта; при выключении пузырь тоже прячется.
func set_training(active: bool) -> void:
	_training = active
	if not active:
		_bonus_shown = false
	_update_visibility()


## Показывает пузырь-бонус с «+N» повторений.
func show_bonus(reps: int) -> void:
	_bonus.text = "+%d" % reps
	_bonus_shown = true
	_update_visibility()


func hide_bonus() -> void:
	_bonus_shown = false
	_update_visibility()


## Ставит центр пузыря в точку экрана (не выходит за края).
func move_bonus(screen_pos: Vector2) -> void:
	var half: Vector2 = Vector2(BONUS_SIZE, BONUS_SIZE) * 0.5
	var view: Vector2 = get_viewport_rect().size
	_bonus.global_position = screen_pos.clamp(half, view - half) - half


func bonus_center() -> Vector2:
	return _bonus.global_position + Vector2(BONUS_SIZE, BONUS_SIZE) * 0.5


## Всплывающее «+N» в точке экрана: поднимается и гаснет.
func popup_at(text: String, screen_pos: Vector2, color: Color = UiStyle.COLOR_STRENGTH) -> void:
	var label: Label = UiStyle.outline_label(text, 44, 7, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.size = Vector2(160.0, 50.0)
	label.global_position = screen_pos - label.size * 0.5
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _build_training() -> void:
	xp_bar = XpBar.new()
	xp_bar.name = "XpBar"
	xp_bar.visible = false
	add_child(xp_bar)

	_bonus = Button.new()
	_bonus.name = "BonusBubble"
	_bonus.custom_minimum_size = Vector2(BONUS_SIZE, BONUS_SIZE)
	_bonus.size = Vector2(BONUS_SIZE, BONUS_SIZE)
	_bonus.focus_mode = Control.FOCUS_NONE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#FFC83D")
	style.set_border_width_all(6)
	style.border_color = Color("#7A4A00")
	style.set_corner_radius_all(int(BONUS_SIZE / 2.0))
	for state in ["normal", "hover", "pressed", "focus"]:
		_bonus.add_theme_stylebox_override(state, style)
	_bonus.add_theme_font_size_override("font_size", 40)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		_bonus.add_theme_color_override(color_name, UiStyle.COLOR_TEXT)
	_bonus.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_bonus.add_theme_constant_override("outline_size", 6)
	_bonus.visible = false
	_bonus.pressed.connect(_on_bonus_pressed)
	add_child(_bonus)


func _on_bonus_pressed() -> void:
	bonus_pressed.emit()


func _refresh() -> void:
	_strength.text = str(Game.strength())
	_money.text = NumFmt.money(Game.money())
	_income.text = NumFmt.money(Game.income_per_sec()) + "/s"
	_update_index_button_pulse()
	_update_visibility()


## Проверяет, есть ли неполученные награды за зоны, и запускает/останавливает пульсацию кнопки «Индекс».
func _update_index_button_pulse() -> void:
	var has_reward: bool = IndexWindow.has_unclaimed_rewards()
	if has_reward == _index_has_reward:
		return
	_index_has_reward = has_reward
	var index_button: Button = _buttons["index"]
	if index_button == null:
		return
	if _index_pulse_tween != null and _index_pulse_tween.is_valid():
		_index_pulse_tween.kill()
	if has_reward:
		# Пульсация: масштаб 1.0 -> 1.15 -> 1.0
		_index_pulse_tween = index_button.create_tween()
		_index_pulse_tween.set_loops()
		var scale_up = _index_pulse_tween.tween_property(index_button, "scale", Vector2(1.15, 1.15), 0.6)
		scale_up.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var scale_down = _index_pulse_tween.tween_property(index_button, "scale", Vector2(1.0, 1.0), 0.6)
		scale_down.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		index_button.scale = Vector2(1.0, 1.0)


func _build_throw_meter() -> void:
	throw_meter = ThrowMeter.new()
	throw_meter.name = "ThrowMeter"
	throw_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_meter.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(throw_meter)


func _update_visibility() -> void:
	_goal.visible = _full
	_hint.visible = not _full
	_strength.visible = true
	_money.visible = _full
	_income.visible = _full
	if throw_meter != null:
		throw_meter.visible = not _full and _throw_meter_enabled
	for key in _buttons:
		var button: Button = _buttons[key]
		button.visible = _full
	if xp_bar != null:
		xp_bar.visible = _training and _full
	if _bonus != null:
		_bonus.visible = _bonus_shown and _full


func _on_index_pressed() -> void:
	index_pressed.emit()


func _on_shop_pressed() -> void:
	shop_pressed.emit()


func _on_animals_pressed() -> void:
	animals_pressed.emit()
