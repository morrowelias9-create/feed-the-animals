class_name Hud
extends Control
## HUD: деньги, сила, кнопки, подсказка цели, шкала броска (шаги T08/T09, справочник R6).
## Сцена: scenes/ui/hud.tscn (Control на весь экран, mouse_filter = IGNORE, якоря от краёв).

signal index_pressed
signal shop_pressed
signal animals_pressed
signal notice_action(kind: String, index: int)   # кнопка «Купить» в уведомлении
signal bonus_pressed               # T14: тап по пузырю-бонусу на турнике

const NOTICE_SECONDS: float = 5.0
const NOTICE_TOP: float = 84.0
const BONUS_SIZE: float = 96.0
const SOUND_BTN_SIZE: float = 64.0         # не меньше 64 пикселей (правило мобильности)
const SIDE_BTN_SIZE: Vector2 = Vector2(128.0, 128.0)   # крупные кнопки «Индекс», «Магазин», «Животные» с подписью под иконкой
const SIDE_MARGIN: float = 12.0
const STATS_MARGIN: float = 18.0           # отступ левого нижнего блока от краёв экрана
const STATS_WIDTH: float = 330.0           # правее начинается панель зверей (по центру), поэтому не шире
const STAT_ICON_SIZE: float = 60.0
const STRENGTH_FONT: int = 52
const MONEY_FONT: int = 56
const INCOME_FONT: int = 28
const BOOST_BTN_W: float = 200.0           # кнопка буста: меньше прежней (220x56), чтобы не закрывать панель зверей
const BOOST_BTN_H: float = 50.0

var _full: bool = true
var _throw_meter_enabled: bool = true
var _hint_visible: bool = true           # T37: подсказку внизу можно скрыть (пока зверь в руках)

var _goal: Label
var _notice_card: NoticeCard
var _notice_queue: Array[Dictionary] = []
var busy_check: Callable             # true, пока идёт бросок: уведомления ждут
var _hint: Label
var _strength: Label
var _money: Label
var _income: Label
var _stats_box: VBoxContainer           # левый нижний блок: сила, деньги, доход, буст
var _strength_row: Control
var _money_row: Control
var _income_row: Control
var _buttons: Dictionary = {}
var throw_meter: ThrowMeter
var mini_zone_bar: MiniZoneBar          # T46: зона и мини-зона слева вверху, плашка «Новая местность»
var xp_bar: XpBar                       # T14: шкала «Уровень N x/y», видна только на тренировке
var _bonus: Button                      # T14: пузырь-бонус 96x96 в экранных координатах
var _boost_button: Button               # T22: кнопка буста x2 за рекламу
var _boost_timer: Label                 # T22: таймер буста "x2 MM:SS"
var _sound_button: Button               # T26: кнопка звука вкл/выкл
var _training: bool = false
var _zone_rewards: Array[Dictionary] = []   # награды за новые мини-зоны, ждут конца полёта
var _flight: bool = false              # бросок сделан: шкала и инвентарь скрыты до конца кинематики
var hotbar: Control                    # инвентарь зверей (создаёт main.gd)
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
	Game.mini_zone_reached.connect(_on_mini_zone_reached)
	_build_stats()
	_build_buttons()
	_build_mini_zone_bar()
	_build_throw_meter()
	_build_training()
	_refresh()
	if not Game.money_changed.is_connected(_on_money_changed):
		Game.money_changed.connect(_on_money_changed)
	if not Game.strength_changed.is_connected(_on_strength_changed):
		Game.strength_changed.connect(_on_strength_changed)
	if not Game.food_affordable.is_connected(_on_food_affordable):
		Game.food_affordable.connect(_on_food_affordable)
	if not Game.bar_affordable.is_connected(_on_bar_affordable):
		Game.bar_affordable.connect(_on_bar_affordable)
	if not Game.boost_changed.is_connected(_on_boost_changed):
		Game.boost_changed.connect(_on_boost_changed)
	# Доход в HUD должен обновляться при изменении инвентаря (звери размещены/убраны),
	# смене активного питомца и активации/деактивации буста.
	if not Game.inventory_changed.is_connected(_on_inventory_changed):
		Game.inventory_changed.connect(_on_inventory_changed)
	if not Game.pet_active_changed.is_connected(_on_pet_active_changed):
		Game.pet_active_changed.connect(_on_pet_active_changed)
	Loc.language_changed.connect(_on_language_changed)


func set_goal(text: String) -> void:
	_goal.text = text


func set_hint(text: String) -> void:
	_hint.text = text


## T37: скрывает подсказку внизу, не меняя её текст (пока зверь в руках, текст броска не нужен).
func set_hint_visible(on: bool) -> void:
	if _hint_visible == on:
		return
	_hint_visible = on
	_update_visibility()


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
	if active:
		_flight = false


## В полёте шкала броска скрывается: приземление уже сделано, цель — полёт.
func set_flight(active: bool) -> void:
	if _flight == active:
		return
	_flight = active
	_update_visibility()
	if not active:
		_flush_zone_rewards()


# Награда за вход в новую мини-зону: во время полёта шкала мини-зон скрыта, поэтому показываем вылетающую надпись после посадки.
func _on_mini_zone_reached(zone: int, index: int, reward: float) -> void:
	_zone_rewards.append({"zone": zone, "index": index, "reward": reward})
	if not _flight:
		_flush_zone_rewards()


func _flush_zone_rewards() -> void:
	var center: Vector2 = get_viewport_rect().size * Vector2(0.5, 0.3)
	var shift: float = 0.0
	for item in _zone_rewards:
		var name_text: String = Loc.t("mini_zone_new") % Loc.t(MiniZoneData.name_key(int(item["zone"]), int(item["index"])))
		float_text(name_text, center + Vector2(0.0, shift), Color("#FFD23F"), 30, Vector2(0.0, -50.0), 2.2)
		float_text("+" + NumFmt.money(float(item["reward"])), center + Vector2(0.0, shift + 36.0), UiStyle.COLOR_MONEY, 34, Vector2(0.0, -50.0), 2.2)
		shift += 80.0
	_zone_rewards.clear()


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


func _on_food_affordable(tier: int) -> void:
	_enqueue_notice({"kind": "food", "index": tier})


func _on_bar_affordable(index: int) -> void:
	_enqueue_notice({"kind": "bar", "index": index})


# ---------- Уведомления «можно купить» ----------

## Карточка не показывается, пока идёт бросок (еда летит, камера у зверя): ждёт очереди.
func _enqueue_notice(entry: Dictionary) -> void:
	_notice_queue.append(entry)


func _process(_delta: float) -> void:
	if _notice_card != null or _notice_queue.is_empty():
		return
	if busy_check.is_valid() and bool(busy_check.call()):
		return
	_show_notice_card(_notice_queue.pop_front())


func _show_notice_card(entry: Dictionary) -> void:
	var kind: String = String(entry["kind"])
	var index: int = int(entry["index"])
	var title: String
	var item: String
	var price: float
	if kind == "food":
		if Game.is_food_owned(index):
			return
		title = Loc.t("notice_food_title")
		item = Loc.t(String(FoodData.FOODS[index]["name_key"]))
		price = FoodData.price(index)
	else:
		if Game.bars_owned() > index:
			return
		title = Loc.t("notice_bar_title")
		item = Loc.t(String(UpgradeData.BARS[index]["name_key"]))
		price = float(UpgradeData.BARS[index]["price"])
	var card: NoticeCard = NoticeCard.new()
	card.lifetime = NOTICE_SECONDS
	card.setup(title, Loc.t("notice_hint"), item, NumFmt.money(price), Loc.t("notice_buy"))
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.offset_left = -NoticeCard.CARD_WIDTH / 2.0
	card.offset_right = NoticeCard.CARD_WIDTH / 2.0
	card.offset_top = NOTICE_TOP
	card.z_index = 20
	card.action_pressed.connect(func() -> void: notice_action.emit(kind, index))
	card.finished.connect(func() -> void: _notice_card = null)
	add_child(card)
	_notice_card = card
	card.start()


## Мелкий вылетающий текст: летит в случайную сторону и гаснет (опыт за подтягивания, надписи над головой).
func float_text(text: String, screen_pos: Vector2, color: Color, font_size: int, travel: Vector2, life: float) -> void:
	var label: Label = UiStyle.outline_label(text, font_size, maxi(font_size / 6, 3), color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.size = Vector2(320.0, float(font_size) + 12.0)
	label.global_position = screen_pos - label.size * 0.5
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + travel, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, life * 0.5).set_delay(life * 0.5)
	tween.chain().tween_callback(label.queue_free)


## Опыт за подтягивание: маленькое «+N» в случайную сторону вверх.
func xp_popup(text: String, screen_pos: Vector2) -> void:
	var dir: Vector2 = Vector2.from_angle(randf_range(-PI * 0.92, -PI * 0.08))
	float_text(text, screen_pos, UiStyle.COLOR_STRENGTH, 26, dir * randf_range(50.0, 110.0), 0.9)


## Новый уровень силы: две небольшие надписи над головой, медленно уплывают вверх.
func level_up_popup(power_gain: int, screen_pos: Vector2) -> void:
	float_text(Loc.t("levelup_title"), screen_pos + Vector2(0.0, -34.0), Color("#FFD23F"), 34, Vector2(0.0, -70.0), 1.8)
	float_text(Loc.t("levelup_power") % power_gain, screen_pos, UiStyle.COLOR_STRENGTH, 30, Vector2(0.0, -70.0), 1.8)


func _on_language_changed() -> void:
	# Цель обучения обновляет TutorialController: здесь её не трогаем, иначе после обучения она вернётся (T37).
	_hint.text = Loc.t("hint_throw")
	UiStyle.set_caption(_buttons["index"] as Button, Loc.t("index"))
	UiStyle.set_caption(_buttons["shop"] as Button, Loc.t("shop"))
	UiStyle.set_caption(_buttons["animals"] as Button, Loc.t("animals"))
	# T22: кнопка буста и таймер
	if _boost_button != null:
		_boost_button.text = Loc.t("boost_btn")
	# T26: кнопка звука
	if _sound_button != null:
		var sound_bank: Node = Game.get_node_or_null("SoundBank")
		var sound_on: bool = sound_bank.is_enabled() if sound_bank != null else true
		_update_sound_button(sound_on)
	_update_boost_display()


## Возвращает CanvasLayer для 2D подписей зверей.
func get_label_layer() -> CanvasLayer:
	return _label_layer


# T22: обработчик изменения буста
func _on_boost_changed() -> void:
	_update_boost_display()
	_update_income_display()


## Обновляет отображение дохода в секунду (вызывается при изменении инвентаря, питомца, буста).
func _update_income_display() -> void:
	set_income_per_sec(Game.income_per_sec())


func _on_inventory_changed() -> void:
	_update_income_display()


func _on_pet_active_changed(_pet_id: String) -> void:
	_update_income_display()


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
		# Буст неактивен: показываем кнопку БЕЗ пульсации масштаба, с лёгким пульсированием прозрачности
		_boost_button.visible = _full
		_boost_timer.visible = false
		set_process_internal(false)
		# Тихое пульсирование прозрачности (opacity 1.0 -> 0.7 -> 1.0), без масштабирования
		_start_boost_glow()


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
	_goal = UiStyle.outline_label(Loc.t("goal_buy_bar"), 38, 8, UiStyle.COLOR_TEXT)
	_goal.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_goal.offset_top = 64.0
	_goal.offset_bottom = 112.0
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal)

	_hint = UiStyle.outline_label(Loc.t("hint_throw"), 42, 8, UiStyle.COLOR_TEXT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -170.0
	_hint.offset_bottom = -118.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


# Левый нижний угол (как в Roblox): сила, деньги, доход в секунду и кнопка буста x2. Всё в одном контейнере,
# привязанном к углу, поэтому на любом соотношении сторон стоит в углу. Иконки показателей рисуются кодом (StatIcon),
# позже заменяются файлами stat_strength.png и stat_money.png.
func _build_stats() -> void:
	_stats_box = VBoxContainer.new()
	_stats_box.name = "Stats"
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_box.anchor_left = 0.0
	_stats_box.anchor_right = 0.0
	_stats_box.anchor_top = 1.0
	_stats_box.anchor_bottom = 1.0
	_stats_box.offset_left = STATS_MARGIN
	_stats_box.offset_right = STATS_MARGIN + STATS_WIDTH
	_stats_box.offset_top = -STATS_MARGIN
	_stats_box.offset_bottom = -STATS_MARGIN
	_stats_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stats_box.add_theme_constant_override("separation", 0)
	add_child(_stats_box)

	_strength = UiStyle.outline_label(str(Game.strength()), STRENGTH_FONT, 10, UiStyle.COLOR_STRENGTH)
	_strength_row = _stat_row(StatIcon.KIND_STRENGTH, _strength)
	_money = UiStyle.outline_label(NumFmt.money(Game.money()), MONEY_FONT, 10, UiStyle.COLOR_MONEY)
	_money_row = _stat_row(StatIcon.KIND_MONEY, _money)

	_income = UiStyle.outline_label(NumFmt.money(Game.income_per_sec()) + "/s", INCOME_FONT, 7, UiStyle.COLOR_MONEY)
	_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_income.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var income_row := HBoxContainer.new()
	income_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(STAT_ICON_SIZE + 8.0, 0.0)
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	income_row.add_child(indent)
	income_row.add_child(_income)
	_income_row = income_row
	_stats_box.add_child(income_row)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 8.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_box.add_child(gap)

	# T22: кнопка буста x2 и таймер (в этом же блоке, под деньгами)
	_build_boost()
	# T26: кнопка звука в правом верхнем углу
	_build_sound()


# Строка показателя: иконка и крупное число слева.
func _stat_row(kind: String, value_label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.add_child(StatIcon.create(kind, STAT_ICON_SIZE))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)
	# порядок в блоке: сила, деньги, затем доход (добавляется в _build_stats)
	_stats_box.add_child(row)
	return row


# T22: создаёт кнопку буста и таймер (правый верхний угол, над звуком)
func _build_boost() -> void:
	# Кнопка "х2 дохода за рекламу": левый нижний блок, под деньгами и доходом (T22, перенесена из правого верхнего угла)
	_boost_button = Button.new()
	_boost_button.name = "BoostButton"
	_boost_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	_boost_button.add_theme_font_size_override("font_size", 17)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_boost_button.add_theme_color_override(color_name, UiStyle.COLOR_TEXT)
	_boost_button.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_boost_button.add_theme_constant_override("outline_size", 3)
	# Текст на двух строках
	_boost_button.text = Loc.t("boost_btn")
	_boost_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boost_button.pressed.connect(_on_boost_pressed)
	_stats_box.add_child(_boost_button)

	# Таймер буста "х2 MM:SS" — на месте кнопки, пока буст идёт
	_boost_timer = Label.new()
	_boost_timer.name = "BoostTimer"
	_boost_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boost_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boost_timer.add_theme_font_size_override("font_size", 28)
	_boost_timer.add_theme_color_override("font_color", UiStyle.COLOR_MONEY)
	_boost_timer.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_boost_timer.add_theme_constant_override("outline_size", 4)
	_boost_timer.custom_minimum_size = Vector2(BOOST_BTN_W, BOOST_BTN_H)
	_boost_timer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_boost_timer.visible = false
	_stats_box.add_child(_boost_timer)

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
	_sound_button.add_theme_font_size_override("font_size", 30)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		_sound_button.add_theme_color_override(color_name, UiStyle.COLOR_TEXT)
	_sound_button.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_sound_button.add_theme_constant_override("outline_size", 2)
	# Правый верхний угол с отступом (привязан к углу)
	var margin: float = 16.0
	_sound_button.anchor_left = 1.0
	_sound_button.anchor_right = 1.0
	_sound_button.offset_left = -(SOUND_BTN_SIZE + margin)
	_sound_button.offset_right = -margin
	_sound_button.offset_top = margin
	_sound_button.offset_bottom = margin + SOUND_BTN_SIZE
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
	var index_button: Button = _side_button("index", "index.png", Loc.t("index"), true, -250.0)
	index_button.pressed.connect(_on_index_pressed)
	var shop_button: Button = _side_button("shop", "shop.png", Loc.t("shop"), true, -105.0)
	shop_button.pressed.connect(_on_shop_pressed)
	var animals_button: Button = _side_button("animals", "animals.png", Loc.t("animals"), false, -90.0)
	animals_button.pressed.connect(_on_animals_pressed)


# Крупная кнопка у края экрана (слева или справа по центру по высоте) с подписью под иконкой.
# top_offset это отступ верха кнопки от середины экрана по высоте.
func _side_button(key: String, icon_file: String, caption: String, left: bool, top_offset: float) -> Button:
	var button: Button = UiStyle.make_icon_button(key, UiStyle.ICON_DIR + icon_file, caption, self, SIDE_BTN_SIZE, caption)
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.anchor_left = 0.0 if left else 1.0
	button.anchor_right = button.anchor_left
	button.offset_left = SIDE_MARGIN if left else -(SIDE_MARGIN + SIDE_BTN_SIZE.x)
	button.offset_right = button.offset_left + SIDE_BTN_SIZE.x
	button.offset_top = top_offset
	button.offset_bottom = top_offset + SIDE_BTN_SIZE.y
	button.pivot_offset = SIDE_BTN_SIZE / 2.0
	_buttons[key] = button
	return button


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


func _build_mini_zone_bar() -> void:
	mini_zone_bar = MiniZoneBar.new()
	mini_zone_bar.name = "MiniZoneBar"
	add_child(mini_zone_bar)


func _build_throw_meter() -> void:
	throw_meter = ThrowMeter.new()
	throw_meter.name = "ThrowMeter"
	throw_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_meter.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(throw_meter)


func _update_visibility() -> void:
	_goal.visible = _full
	if mini_zone_bar != null:
		mini_zone_bar.set_shown(_full)
	_hint.visible = not _full and _hint_visible
	_strength_row.visible = true
	_money_row.visible = _full
	_income_row.visible = _full
	var meter_shown: bool = not _full and _throw_meter_enabled and not _flight
	if throw_meter != null:
		throw_meter.visible = meter_shown
	# Инвентарь прячется на тренировке (там шкала опыта), при прицеливании и в полёте.
	if hotbar != null:
		hotbar.visible = not _training and not meter_shown and not _flight
	_goal.visible = _full and not _flight
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
