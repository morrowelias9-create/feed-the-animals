class_name UiStyle
extends RefCounted
## Стили интерфейса: обводка текста, панель, кнопка-иконка, пульсация (шаг T08, справочник R6).

const ICON_DIR := "res://assets/ui/icons/"

const COLOR_PANEL: Color = Color(0.169, 0.169, 0.184)
const COLOR_PANEL_BORDER: Color = Color(0.82, 0.82, 0.82)
const COLOR_TEXT: Color = Color.WHITE
const COLOR_OUTLINE: Color = Color.BLACK
const COLOR_STRENGTH: Color = Color("#4DB8FF")
const COLOR_MONEY: Color = Color("#55E05A")

const BUTTON_SIZE: Vector2 = Vector2(94.0, 94.0)
const BUTTON_FONT_SIZE: int = 21
const BUTTON_OUTLINE_SIZE: int = 4


static func outline_label(text: String, font_size: int, outline_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_border_width_all(3)
	style.border_color = COLOR_PANEL_BORDER
	style.set_corner_radius_all(20)
	return style


static func make_icon_button(key: String, icon_path: String, label: String, parent: Control) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	# Прозрачный стиль — иконка И ЕСТЬ кнопка, никаких рамок и фона
	var transparent_style := StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	transparent_style.set_border_width_all(0)
	transparent_style.set_content_margin_all(0)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(st, transparent_style)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	button.add_theme_constant_override("outline_size", BUTTON_OUTLINE_SIZE)
	# Иконка почти на весь размер кнопки (90%), центрируется автоматически
	button.add_theme_constant_override("icon_max_width", int(BUTTON_SIZE.x * 0.9))
	button.icon = _load_icon(icon_path)
	button.text = label.substr(0, 1) if button.icon == null else ""
	parent.add_child(button)
	return button


static func _load_icon(icon_path: String) -> Texture2D:
	if not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


static func pulse(node: Control, duration: float = 0.5) -> void:
	var tween := node.create_tween()
	var scale_down := tween.tween_property(node, "scale", Vector2(0.85, 0.85), duration)
	scale_down.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var scale_up := tween.tween_property(node, "scale", Vector2.ONE, duration)
	scale_up.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
