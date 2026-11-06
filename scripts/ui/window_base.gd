class_name WindowBase
extends Control
## Основа окон интерфейса (справочник R6 «Окна»): затемнение 50%, панель по центру шириной 80% экрана
## (не больше 1000) и высотой 80%, заголовок по центру, крестик 64x64 справа сверху, закрытие тапом по затемнению.
## Наследники задают `title_key` до добавления в дерево и переопределяют `_build_body()` и `refresh()`.
## Окно живёт в CanvasLayer поверх HUD. Пока оно открыто, игра для Яндекса считается на паузе (Ya.gameplay_stop).

signal opened
signal closed

const PANEL_W_K: float = 0.8
const PANEL_W_MAX: float = 1000.0
const PANEL_H_K: float = 0.8
const CLOSE_SIZE: float = 64.0
const DIM_ALPHA: float = 0.5
const TITLE_FONT_SIZE: int = 40
const TOAST_FONT_SIZE: int = 28
const TOAST_HOLD_S: float = 1.0
const TOAST_FADE_S: float = 0.4
const BUTTON_FONT_SIZE: int = 24
const PADDING: int = 16

var title_key: String = ""
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
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PADDING)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_title = UiStyle.outline_label(Loc.t(title_key), TITLE_FONT_SIZE, 6, UiStyle.COLOR_TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := make_button("×", Vector2(CLOSE_SIZE, CLOSE_SIZE), 40)
	close_button.name = "CloseButton"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)

	_toast = UiStyle.outline_label("", TOAST_FONT_SIZE, 5, UiStyle.COLOR_MONEY)
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)


# Панель по центру: 80% ширины (не больше 1000) и 80% высоты; сообщение сразу под панелью.
func _layout() -> void:
	if _panel == null:
		return
	var w: float = minf(size.x * PANEL_W_K, PANEL_W_MAX)
	var h: float = size.y * PANEL_H_K
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
