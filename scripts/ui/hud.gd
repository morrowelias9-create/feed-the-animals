class_name Hud
extends Control
## HUD: деньги, сила, кнопки, подсказка цели, шкала броска (шаги T08/T09, справочник R6).
## Сцена: scenes/ui/hud.tscn (Control на весь экран, mouse_filter = IGNORE, якоря от краёв).

signal index_pressed
signal shop_pressed
signal animals_pressed
signal bonus_pressed               # T14: тап по пузырю-бонусу на турнике

const BONUS_SIZE: float = 96.0
const BOOST_BTN_SIZE: float = 96.0
const SOUND_BTN_SIZE: float = 48.0

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
var _boost_button: Button               # T22: кнопка буста x2 за рекламу
var _boost_timer: Label                 # T22: таймер буста "x2 MM:SS"
var _sound_button: Button               # T26: кнопка звука вкл/выкл
var _training: bool = false
var _bonus_shown: bool = false
var _boost_active: bool = false
var _boost_pulse_tween: Tween
var _index_pulse_tween: Tween
var _index_has_reward: bool = false
var _hint_pulse_tween: Tween            # T19: пульс подсказки внизу (шаг обучения 1)
var _shop_pulse_tween: Tween            # T19: пульс кнопки «Магазин» (шаг обучения 2)

# CanvasLayer для 2D подписей зверей (над HUD, под модальными окнами)
var _label_layer: CanvasLayer


func _ready() -> void:
	# Слой для подписей зверей (layer = 15, HUD layer = 0, WindowLayer = 20)
	_label_layer = CanvasLayer.new()
	_label_layer.name = "AnimalLabelLayer"
	_label_layer.layer = 15
	add_child(_label_layer)
	_build_texts()
	_build_stats()
	_build_buttons()
	_build_boost()                      # T22
	_build_throw_meter()
	_build_training()
	_refresh()
	if not Game.money_changed.is_connected(_on_money_changed):
		Game.money_changed.connect(_on_money_changed)
	if not Game.strength_changed.is_connected(_on_strength_changed):
		Game.strength_changed.connect(_on_strength_changed)
	if not Game.boost_changed.is_connected(_on_boost_changed):
		Game.boost_changed.connect(_on_boost_changed)
	Loc.language_changed.connect(_on_language_changed)


func set_goal(text: String) -> void:
	_goal.text = text


func set_hint(text: String) -> void:
	_hint.text = text


## Пульсация подсказки внизу «Нажмите, чтобы бросить!» (обучение, шаг 1).
func set_hint_pulse(active: bool) -> void:
	_hint_pulse_tween = _set_pulse(_hint, _hint_pulse_tween, active)


## Пульсация кнопки «Магазин» (обучение, шаг 2: хватает денег на яблоко).
func set_shop_pulse(active: bool) -> void:
	var shop_button: Button = _buttons["shop"]
	_shop_pulse_tween = _set_pulse(shop_button, _shop_pulse_tween, active)


# Включает или выключает бесконечную пульсацию масштаба узла; возвращает новый Tween (или null).
func _set_pulse(node: Control, old_tween: Tween, active: bool) -> Tween:
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	node.scale = Vector2.ONE
	if not active:
		return null
	node.pivot_offset = node.size / 2.0
	var tween: Tween = node.create_tween()
	tween.set_loops()
	var grow: PropertyTweener = tween.tween_property(node, "scale", Vector2(1.15, 1.15), 0.5)
	grow.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shrink: PropertyTweener = tween.tween_property(node, "scale", Vector2.ONE, 0.5)
	shrink.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


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


## Возвращает CanvasLayer для 2D подписей зверей.
func get_label_layer() -> CanvasLayer:
	return _label_layer
	var animals_button: Button = _buttons["animals"]
	animals_button.text = Loc.t("animals")
	# T22: кнопка буста и таймер
	if _boost_button != null:
		_boost_button.text = Loc.t("boost_btn")
	# T26: кнопка звука
	if _sound_button != null:
		var sound_bank: Node = Game.get_node_or_null("SoundBank")
		var sound_on: bool = sound_bank.is_enabled() if sound_bank != null else true
		_update_sound_button(sound_on)
	_update_boost_display()


# T22: обработчик изменения буста
func _on_boost_changed() -> void:
	_update_boost_display()


func _update_boost_display() -> void:
	var active: bool = Game._boost_active()
	if active == _boost_active:
		return
	_boost_active = active
	if active:
		# Буст активен: показываем таймер, прячем кнопку
		_boost_button.visible = false
		_boost_timer.visible = _full
		# Обновляем таймер каждый кадр
		if not is_processing_internal():
			set_process_internal(true)
	else:
		# Буст неактивен: показываем кнопку с пульсацией, прячем таймер
		_boost_button.visible = _full
		_boost_timer.visible = false
		set_process_internal(false)
		# Запускаем пульсацию кнопки
		_start_boost_pulse()


func _start_boost_glow() -> void:
	if _boost_pulse_tween != null and _boost_pulse_tween.is_valid():
		_boost_pulse_tween.kill()
	var tween: Tween = _boost_button.create_tween()
	tween.set_loops()
	# Тихое пульсирование прозрачности (modulate.a) 1.0 -> 0.7 -> 1.0
	var fade_out: PropertyTweener = tween.tween_property(_boost_button, "modulate:a", 0.7, 1.5)
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var fade_in: PropertyTweener = tween.tween_property(_boost_button, "modulate:a", 1.0, 1.5)
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_boost_pulse_tween = tween


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS:
		_update_boost_timer()


func _update_boost_timer() -> void:
	if not _boost_active:
		return
	var rem: int = Game.boost_remaining()
	if rem <= 0:
		_on_boost_changed()
		return
	var minutes: int = rem / 60
	var seconds: int = rem % 60
	_boost_timer.text = "x2 %02d:%02d" % [minutes, seconds]


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
	# Компактный layout для 720p: сила (564-610), деньги (610-660), доход (660-686), кнопки (620-716) - но кнопки справа
	_strength = UiStyle.outline_label(str(Game.strength()), 46, 6, UiStyle.COLOR_STRENGTH)
	_strength.position = Vector2(20.0, 564.0)
	_strength.size = Vector2(360.0, 46.0)
	add_child(_strength)

	_money = UiStyle.outline_label(NumFmt.money(Game.money()), 50, 6, UiStyle.COLOR_MONEY)
	_money.position = Vector2(20.0, 612.0)
	_money.size = Vector2(360.0, 50.0)
	add_child(_money)

	_income = UiStyle.outline_label(NumFmt.money(Game.income_per_sec()) + "/s", 26, 4, UiStyle.COLOR_MONEY)
	_income.position = Vector2(20.0, 664.0)
	_income.size = Vector2(360.0, 26.0)
	add_child(_income)

	# T22: кнопка буста x2 и таймер справа от денег/дохода
	_build_boost()
	# T26: кнопка звука справа от буста
	_build_sound()


# T22: создаёт кнопку буста и таймер под строкой дохода
func _build_boost() -> void:
	# Кнопка "х2 дохода за рекламу" (правый верхний угол, над звуком)
	_boost_button = Button.new()
	_boost_button.name = "BoostButton"
	const BOOST_BTN_W: float = 220.0
	const BOOST_BTN_H: float = 56.0
	_boost_button.custom_minimum_size = Vector2(BOOST_BTN_W, BOOST_BTN_H)
	_boost_button.size = Vector2(BOOST_BTN_W, BOOST_BTN_H)
	_boost_button.focus_mode = Control.FOCUS_NONE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#4A90D9")
	style.set_border_width_all(3)
	style.border_color = Color("#1A4A7A")
	style.set_corner_radius_all(int(BOOST_BTN_H / 2.0))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		_boost_button.add_theme_stylebox_override(st, style)
	_boost_button.add_theme_font_size_override("font_size", 18)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_boost_button.add_theme_color_override(color_name, UiStyle.COLOR_TEXT)
	_boost_button.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_boost_button.add_theme_constant_override("outline_size", 3)
	# Текст на двух строках
	_boost_button.text = Loc.t("boost_btn")
	_boost_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Позиция: справа сверху, над кнопкой звука
	var margin: float = 16.0
	_boost_button.position = Vector2(1280.0 - BOOST_BTN_W - margin, margin)
	_boost_button.pressed.connect(_on_boost_pressed)
	add_child(_boost_button)

	# Таймер буста "х2 MM:SS" — под кнопкой
	_boost_timer = Label.new()
	_boost_timer.name = "BoostTimer"
	_boost_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boost_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boost_timer.add_theme_font_size_override("font_size", 22)
	_boost_timer.add_theme_color_override("font_color", UiStyle.COLOR_MONEY)
	_boost_timer.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_boost_timer.add_theme_constant_override("outline_size", 4)
	_boost_timer.position = Vector2(1280.0 - BOOST_BTN_W - margin, margin + BOOST_BTN_H + 4.0)
	_boost_timer.size = Vector2(BOOST_BTN_W, 32.0)
	_boost_timer.visible = false
	add_child(_boost_timer)

	# Изначально: если буст не активен — кнопка видна БЕЗ пульсации, с лёгкой свето-анимацией
	var active: bool = Game._boost_active()
	_boost_active = active
	if active:
		_boost_button.visible = false
		_boost_timer.visible = _full
		if not is_processing_internal():
			set_process_internal(true)
	else:
		_boost_button.visible = _full
		_boost_timer.visible = false
		set_process_internal(false)
		# Тихое пульсирование свечения (opacity), без масштабирования
		_start_boost_glow()


# T26: создаёт маленькую кнопку звука в правом верхнем углу
func _build_sound() -> void:
	var sound_on: bool = Save.data.get("sound_on", true)
	_sound_button = Button.new()
	_sound_button.name = "SoundButton"
	_sound_button.custom_minimum_size = Vector2(SOUND_BTN_SIZE, SOUND_BTN_SIZE)
	_sound_button.size = Vector2(SOUND_BTN_SIZE, SOUND_BTN_SIZE)
	_sound_button.focus_mode = Control.FOCUS_NONE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#8B8B8B")
	style.set_border_width_all(2)
	style.border_color = Color("#4A4A4A")
	style.set_corner_radius_all(int(SOUND_BTN_SIZE / 2.0))  # круглый
	for st in ["normal", "hover", "pressed", "focus"]:
		_sound_button.add_theme_stylebox_override(st, style)
	# Без текста — просто иконка динамика через unicode
	_sound_button.add_theme_font_size_override("font_size", 22)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		_sound_button.add_theme_color_override(color_name, UiStyle.COLOR_TEXT)
	_sound_button.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_sound_button.add_theme_constant_override("outline_size", 2)
	# Правый верхний угол с отступом
	var margin: float = 16.0
	_sound_button.position = Vector2(1280.0 - SOUND_BTN_SIZE - margin, margin)
	_sound_button.pressed.connect(_on_sound_pressed)
	add_child(_sound_button)
	_update_sound_button(sound_on)


func _update_sound_button(sound_on: bool) -> void:
	if _sound_button == null:
		return
	# Unicode speaker icons
	_sound_button.text = "🔊" if sound_on else "🔇"


func _on_sound_pressed() -> void:
	var sound_bank: Node = Game.get_node_or_null("SoundBank")
	if sound_bank != null:
		var new_state: bool = not sound_bank.is_enabled()
		sound_bank.set_enabled(new_state)
		_update_sound_button(new_state)
		# Проигрываем клик для обратной связи
		sound_bank.play("click")


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
	_update_boost_display()
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
	# T22: буст кнопка и таймер
	if _boost_button != null:
		_boost_button.visible = _full and not _boost_active
	if _boost_timer != null:
		_boost_timer.visible = _full and _boost_active
	# T26: кнопка звука
	if _sound_button != null:
		_sound_button.visible = _full


func _on_index_pressed() -> void:
	index_pressed.emit()


func _on_shop_pressed() -> void:
	shop_pressed.emit()


func _on_animals_pressed() -> void:
	animals_pressed.emit()


# T22: нажатие кнопки буста — показываем rewarded рекламу
func _on_boost_pressed() -> void:
	Ya.show_rewarded(Callable(Game, "activate_boost"))
