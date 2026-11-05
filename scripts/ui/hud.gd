class_name Hud
extends Control
## HUD: деньги, сила, кнопки, подсказка цели, шкала броска (шаги T08/T09, справочник R6).
## Сцена: scenes/ui/hud.tscn (Control на весь экран, mouse_filter = IGNORE, якоря от краёв).

signal index_pressed
signal shop_pressed
signal animals_pressed

var _full: bool = true

var _goal: Label
var _hint: Label
var _strength: Label
var _money: Label
var _income: Label
var _buttons: Dictionary = {}
var throw_meter: ThrowMeter


func _ready() -> void:
	_build_texts()
	_build_stats()
	_build_buttons()
	_build_throw_meter()
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


## Кинематика получения зверя: HUD скрыт целиком, кнопки недоступны (справочник R2, фаза REVEAL).
func set_reveal(active: bool) -> void:
	visible = not active


## В полёте шкала броска скрывается: приземление уже сделано, цель — полёт.
func set_flight(active: bool) -> void:
	if throw_meter != null:
		throw_meter.visible = not active


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


func _refresh() -> void:
	_strength.text = str(Game.strength())
	_money.text = NumFmt.money(Game.money())
	_income.text = NumFmt.money(Game.income_per_sec()) + "/s"
	_update_visibility()


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
		throw_meter.visible = not _full
	for key in _buttons:
		var button: Button = _buttons[key]
		button.visible = _full


func _on_index_pressed() -> void:
	index_pressed.emit()


func _on_shop_pressed() -> void:
	shop_pressed.emit()


func _on_animals_pressed() -> void:
	animals_pressed.emit()
