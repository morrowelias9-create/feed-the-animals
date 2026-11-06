class_name AdWarning
extends Control
## Плашка предупреждения перед межстраничной рекламой (путь Б, T23, R7 редакция 3).
## Показывает «Реклама через 2...1» по центру экрана на 2 секунды, игра на паузе.

signal finished

const WARNING_TIME: float = 2.0
const COUNTDOWN_START: int = 2

var _label: Label
var _panel: Panel
var _timer: float = 0.0
var _current_count: int = COUNTDOWN_START
var _finished: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Создаём панель с текстом по центру экрана
	_panel = Panel.new()
	_panel.name = "AdWarningPanel"
	_panel.anchors_preset = Control.PRESET_CENTER
	_panel.offset_left = -200
	_panel.offset_top = -60
	_panel.offset_right = 200
	_panel.offset_bottom = 60
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style_box.corner_radius_top_left = 16
	style_box.corner_radius_top_right = 16
	style_box.corner_radius_bottom_left = 16
	style_box.corner_radius_bottom_right = 16
	_panel.add_theme_stylebox_override("panel", style_box)
	
	_label = Label.new()
	_label.name = "AdWarningLabel"
	_label.anchors_preset = Control.PRESET_FULL_RECT
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("outline_color", Color.BLACK)
	_panel.add_child(_label)
	
	visible = false


func start() -> void:
	_finished = false
	_timer = 0.0
	_current_count = COUNTDOWN_START
	_update_label()
	visible = true
	# Ставим игру на паузу
	get_tree().paused = true
	AudioServer.set_bus_mute(0, true)


func _process(delta: float) -> void:
	if not visible or _finished:
		return
	_timer += delta
	var new_count: int = COUNTDOWN_START - int(_timer)
	if new_count != _current_count and new_count >= 0:
		_current_count = new_count
		_update_label()
	if _timer >= WARNING_TIME:
		_finish()


func _update_label() -> void:
	if _label != null:
		_label.text = Loc.t("ad_warning") % _current_count


func _finish() -> void:
	if _finished:
		return
	_finished = true
	visible = false
	# Снимаем паузу
	get_tree().paused = false
	AudioServer.set_bus_mute(0, false)
	finished.emit()


func is_finished() -> bool:
	return _finished