class_name OfflineWindow
extends WindowBase
## Окно оффлайн-дохода (T21): показывает время отсутствия и накопленную сумму.
## Кнопки: «Забрать» (x1) и «x2 за рекламу». Закрытие без выбора = x1.

signal claimed

var _amount_label: Label
var _time_label: Label
var _claim_button: Button
var _double_button: Button
var _choice_made: bool = false


func _init() -> void:
	title_key = "offline_title"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_body() -> void:
	# Время отсутствия
	_time_label = UiStyle.outline_label("", 32, 4, UiStyle.COLOR_TEXT)
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_time_label)

	# Сумма дохода
	_amount_label = UiStyle.outline_label("", 40, 5, UiStyle.COLOR_MONEY)
	_amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_amount_label)

	# Контейнер для кнопок
	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 20)
	body.add_child(buttons_hbox)

	# Кнопка «Забрать» (x1)
	_claim_button = WindowBase.make_button(Loc.t("offline_claim"), Vector2(240, 80), 28)
	_claim_button.pressed.connect(_on_claim_pressed.bind(1.0))
	buttons_hbox.add_child(_claim_button)

	# Кнопка «x2 за рекламу»
	_double_button = WindowBase.make_button(Loc.t("offline_double"), Vector2(240, 80), 28)
	_double_button.pressed.connect(_on_double_pressed)
	buttons_hbox.add_child(_double_button)


func refresh() -> void:
	var gain: float = Game.offline_pending
	if gain <= 0.0:
		close()
		return

	var away_s: float = float(int(Time.get_unix_time_from_system()) - Game._i("last_seen"))
	var away_min: int = maxi(int(away_s / 60.0), 1)

	_time_label.text = Loc.t("offline_text") % away_min
	_amount_label.text = Loc.t("offline_amount") % NumFmt.format(gain)

	_claim_button.disabled = false
	_double_button.disabled = false
	_choice_made = false


func _on_claim_pressed(mult: float) -> void:
	_choice_made = true
	var gained: float = Game.claim_offline(mult)
	if gained > 0.0:
		show_toast(Loc.t("sold_toast") % NumFmt.format(gained))
	claimed.emit()
	close()


func _on_double_pressed() -> void:
	Ya.show_rewarded(_on_rewarded_callback.bind(2.0))


func _on_rewarded_callback(mult: float) -> void:
	_choice_made = true
	var gained: float = Game.claim_offline(mult)
	if gained > 0.0:
		show_toast(Loc.t("sold_toast") % NumFmt.format(gained))
	claimed.emit()
	close()


func close() -> void:
	if visible and not _choice_made and Game.offline_pending > 0.0:
		var gained: float = Game.claim_offline(1.0)
		if gained > 0.0:
			show_toast(Loc.t("sold_toast") % NumFmt.format(gained))
		claimed.emit()
	visible = false
	Ya.gameplay_start()
	closed.emit()


func _on_language_changed() -> void:
	if _title != null:
		_title.text = Loc.t(title_key)
	if visible:
		refresh()