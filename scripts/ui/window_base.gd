class_name WindowBase
extends Control
## Основа окон интерфейса (справочник R6 «Окна»): затемнение 50%, панель по центру шириной 80% экрана
## (не больше 1000) и высотой 80%, заголовок по центру, крестик 64x64 справа сверху, закрытие тапом по затемнению.
## Наследники задают `title_key` до добавления в дерево и переопределяют `_build_body()` и `refresh()`.
## Окно живёт в CanvasLayer поверх HUD. Пока оно открыто, игра для Яндекса считается на паузе (Ya.gameplay_stop).

signal opened
signal closed

const CLOSE_SIZE: float = 64.0
const HEADER_COLOR: Color = Color("#C21FD0")   # фиолетовая шапка в стиле Роблокса
const BODY_COLOR: Color = Color("#17171E")
const CLOSE_COLOR: Color = Color("#E0262B")
const DIM_ALPHA: float = 0.5
const TITLE_FONT_SIZE: int = 36
const TOAST_FONT_SIZE: int = 28
const TOAST_HOLD_S: float = 1.0
const TOAST_FADE_S: float = 0.4
const BUTTON_FONT_SIZE: int = 24
const PADDING: int = 12

var title_key: String = ""
# Размер панели: доля экрана и предел в пикселях базового разрешения; наследники меняют в _init().
var panel_w_k: float = 0.7
var panel_w_max: float = 900.0
var panel_h_k: float = 0.78
var panel_h_max: float = 620.0
var body: VBoxContainer

var _panel: PanelContainer
var _title: Label
var _toast: Label
var _toast_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# Окно закрыто, пока его не откроют через open(). Скрываем здесь, а не в _init: так оно точно не покажется на старте.
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	_build_body()
	resized.connect(_layout)
	Loc.language_changed.connect(_on_language_changed)
	_layout()


## Открывает окно и обновляет содержимое.
func open() -> void:
	if visible:
		return
	refresh()
	_layout()
	visible = true
	Ya.gameplay_stop()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	Ya.gameplay_start()
	closed.emit()


func is_open() -> bool:
	return visible


## Перерисовывает содержимое. Наследники переопределяют.
func refresh() -> void:
	pass


## Строит содержимое в `body`. Наследники переопределяют.
func _build_body() -> void:
	pass


## Короткое сообщение под панелью (например, «Продано: +$30»), гаснет само.
func show_toast(text: String) -> void:
	if _toast == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_HOLD_S)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE_S)


## Кнопка окна: минимальный размер задаётся, фокус клавиатуры не нужен.
static func make_button(text: String, min_size: Vector2, font_size: int = BUTTON_FONT_SIZE) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var frame := StyleBoxFlat.new()
	frame.bg_color = BODY_COLOR
	frame.set_corner_radius_all(22)
	frame.set_border_width_all(4)
	frame.border_color = Color.BLACK
	_panel.add_theme_stylebox_override("panel", frame)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_panel.add_child(column)

	# Шапка: цветная полоса, название слева, красный крестик справа.
	var header_panel := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = HEADER_COLOR
	header_style.corner_radius_top_left = 18
	header_style.corner_radius_top_right = 18
	header_style.content_margin_left = 20.0
	header_style.content_margin_right = 10.0
	header_style.content_margin_top = 6.0
	header_style.content_margin_bottom = 6.0
	header_panel.add_theme_stylebox_override("panel", header_style)
	column.add_child(header_panel)
	var header := HBoxContainer.new()
	header_panel.add_child(header)
	_title = UiStyle.outline_label(Loc.t(title_key), TITLE_FONT_SIZE, 7, UiStyle.COLOR_TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := make_button("×", Vector2(CLOSE_SIZE, CLOSE_SIZE), 40)
	close_button.name = "CloseButton"
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = CLOSE_COLOR
	close_style.set_corner_radius_all(10)
	close_style.set_border_width_all(3)
	close_style.border_color = Color.BLACK
	for state in ["normal", "hover", "pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, close_style)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PADDING)
	column.add_child(margin)

	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

	_toast = UiStyle.outline_label("", TOAST_FONT_SIZE, 5, UiStyle.COLOR_MONEY)
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)


# Панель по центру; сообщение сразу под панелью.
func _layout() -> void:
	if _panel == null:
		return
	var w: float = minf(size.x * panel_w_k, panel_w_max)
	var h: float = minf(size.y * panel_h_k, panel_h_max)
	_panel.size = Vector2(w, h)
	_panel.position = Vector2((size.x - w) * 0.5, (size.y - h) * 0.5)
	_toast.size = Vector2(w, 40.0)
	_toast.position = Vector2(_panel.position.x, _panel.position.y + h + 6.0)


# Закрытие по отпусканию на затемнении (мышь или касание).
func _on_dim_input(event: InputEvent) -> void:
	var released: bool = false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		released = mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed
	elif event is InputEventScreenTouch:
		released = not (event as InputEventScreenTouch).pressed
	if released:
		close()


func _on_language_changed() -> void:
	if _title != null:
		_title.text = Loc.t(title_key)
	if visible:
		refresh()
