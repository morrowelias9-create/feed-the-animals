class_name NoticeCard
extends PanelContainer
## Карточка-уведомление сверху экрана в стиле Роблокса: цветная шапка с заголовком, строка «Теперь вы можете
## купить», название и цена, кнопка действия и полоска времени внизу. Висит `lifetime` секунд и гаснет.
## Только отображение: что делать по кнопке, решает владелец (сигнал `action_pressed`).

signal action_pressed
signal finished                    # карточка закрыта (кнопкой, крестиком или по времени)

const CARD_WIDTH: float = 420.0
const HEADER_COLOR: Color = Color("#C21FD0")
const BODY_COLOR: Color = Color("#0B0B10")
const NAME_COLOR: Color = Color("#4DA3FF")
const BUTTON_COLOR: Color = Color("#2FC41F")
const TIMER_COLOR: Color = Color("#FF9A1F")

var lifetime: float = 5.0

var _timer_bar: ColorRect
var _timer_track: Control
var _tween: Tween
var _closed: bool = false


## Собирает карточку: title (шапка), hint (малый серый текст), item (название), price (цена), action (кнопка).
func setup(title: String, hint: String, item: String, price: String, action: String) -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BODY_COLOR
	style.set_corner_radius_all(18)
	style.set_border_width_all(4)
	style.border_color = Color.BLACK
	add_theme_stylebox_override("panel", style)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	var header: PanelContainer = PanelContainer.new()
	var header_style: StyleBoxFlat = StyleBoxFlat.new()
	header_style.bg_color = HEADER_COLOR
	header_style.corner_radius_top_left = 14
	header_style.corner_radius_top_right = 14
	header_style.content_margin_left = 16.0
	header_style.content_margin_right = 8.0
	header_style.content_margin_top = 2.0
	header_style.content_margin_bottom = 2.0
	header.add_theme_stylebox_override("panel", header_style)
	column.add_child(header)
	var header_row: HBoxContainer = HBoxContainer.new()
	header.add_child(header_row)
	var title_label: Label = UiStyle.outline_label(title, 24, 5, Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_row.add_child(title_label)
	var close_button: Button = WindowBase.make_button("X", Vector2(64, 64), 28)
	close_button.pressed.connect(close)
	header_row.add_child(close_button)

	var body: MarginContainer = MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 16)
	body.add_theme_constant_override("margin_top", 6)
	body.add_theme_constant_override("margin_bottom", 8)
	column.add_child(body)
	var body_row: HBoxContainer = HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 14)
	body.add_child(body_row)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(texts)
	var hint_label: Label = UiStyle.outline_label(hint, 18, 3, Color("#C8C8D0"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(hint_label)
	var item_label: Label = UiStyle.outline_label(item, 28, 5, NAME_COLOR)
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(item_label)
	var price_label: Label = UiStyle.outline_label(price, 26, 5, UiStyle.COLOR_MONEY)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(price_label)

	var action_button: Button = WindowBase.make_button(action, Vector2(150, 64), 28)
	action_button.size_flags_vertical = Control.SIZE_SHRINK_END
	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.bg_color = BUTTON_COLOR
	button_style.set_corner_radius_all(10)
	button_style.set_border_width_all(3)
	button_style.border_color = Color.BLACK
	for state in ["normal", "hover", "pressed", "focus"]:
		action_button.add_theme_stylebox_override(state, button_style)
	action_button.pressed.connect(_on_action)
	body_row.add_child(action_button)

	_timer_track = Control.new()
	_timer_track.custom_minimum_size = Vector2(0.0, 10.0)
	column.add_child(_timer_track)
	_timer_bar = ColorRect.new()
	_timer_bar.color = TIMER_COLOR
	_timer_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer_track.add_child(_timer_bar)


## Показывает карточку: появление, полоска времени убывает, в конце плавное исчезновение.
func start() -> void:
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_method(_set_timer, 1.0, 0.0, lifetime)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(close)


func close() -> void:
	if _closed:
		return
	_closed = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()


func _set_timer(value: float) -> void:
	if _timer_bar != null and _timer_track != null:
		_timer_bar.anchor_right = value


func _on_action() -> void:
	action_pressed.emit()
	close()
