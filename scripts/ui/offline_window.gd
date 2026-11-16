class_name OfflineWindow
extends WindowBase
## Окно оффлайн-дохода (T21): показывает время отсутствия и накопленную сумму.
## Кнопки: «Забрать» (x1) и «x2 за рекламу». Закрытие без выбора = x1.

signal claimed

var _amount_label: Label
var _time_label: Label
var _intro_label: Label
var _claim_button: Button
var _double_button: Button
var _choice_made: bool = false


func _init() -> void:
	title_key = "offline_title"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_w_k = 0.46
	panel_w_max = 600.0
	panel_h_k = 0.6
	panel_h_max = 420.0


# Как в Роблоксе: пояснение, крупная сумма с иконкой денег, время вне игры, зелёная «Получить» и оранжевая «x2».
func _build_body() -> void:
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 10)

	var intro: Label = UiStyle.outline_label(Loc.t("offline_text"), 22, 4, UiStyle.COLOR_TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.custom_minimum_size = Vector2(500.0, 60.0)
	body.add_child(intro)
	_intro_label = intro

	var plate: PanelContainer = PanelContainer.new()
	var plate_style: StyleBoxFlat = StyleBoxFlat.new()
	plate_style.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	plate_style.set_corner_radius_all(14)
	plate_style.content_margin_top = 8.0
	plate_style.content_margin_bottom = 8.0
	plate.add_theme_stylebox_override("panel", plate_style)
	body.add_child(plate)
	var amount_row: HBoxContainer = HBoxContainer.new()
	amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_row.add_theme_constant_override("separation", 12)
	plate.add_child(amount_row)
	var coin: TextureRect = TextureRect.new()
	coin.custom_minimum_size = Vector2(64.0, 64.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var coin_path: String = UiStyle.ICON_DIR + "money.png"
	if ResourceLoader.exists(coin_path):
		coin.texture = load(coin_path) as Texture2D
	amount_row.add_child(coin)
	_amount_label = UiStyle.outline_label("", 52, 8, UiStyle.COLOR_MONEY)
	amount_row.add_child(_amount_label)

	_time_label = UiStyle.outline_label("", 22, 4, UiStyle.COLOR_TEXT)
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_time_label)

	var buttons_hbox: HBoxContainer = HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_hbox.add_theme_constant_override("separation", 14)
	body.add_child(buttons_hbox)

	_claim_button = WindowBase.make_button(Loc.t("offline_claim"), Vector2(220, 72), 32)
	_style_button(_claim_button, Color("#2FC41F"))
	_claim_button.pressed.connect(_on_claim_pressed.bind(1.0))
	buttons_hbox.add_child(_claim_button)

	_double_button = WindowBase.make_button(Loc.t("offline_double"), Vector2(220, 72), 28)
	_style_button(_double_button, Color("#FF9A1F"))
	_double_button.pressed.connect(_on_double_pressed)
	buttons_hbox.add_child(_double_button)


func _style_button(button: Button, color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.border_color = Color.BLACK
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 6)


func refresh() -> void:
	var gain: float = Game.offline_pending
	if gain <= 0.0:
		close()
		return

	var away_s: float = float(int(Time.get_unix_time_from_system()) - Game._i("last_seen"))
	var away_min: int = maxi(int(away_s / 60.0), 1)

	_intro_label.text = Loc.t("offline_text")
	_time_label.text = _away_text(away_min)
	_amount_label.text = NumFmt.money(gain)
	_claim_button.text = Loc.t("offline_claim")
	_double_button.text = Loc.t("offline_double")

	_claim_button.disabled = false
	_double_button.disabled = false
	_choice_made = false


func _away_text(minutes: int) -> String:
	if minutes >= 60:
		return Loc.t("offline_away_h") % [minutes / 60, minutes % 60]
	return Loc.t("offline_away_min") % minutes


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