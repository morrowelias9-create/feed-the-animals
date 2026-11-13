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

const FONT_PATH := "res://assets/ui/fonts/Nunito-Black.ttf"   # единый шрифт интерфейса (Nunito Black, SIL OFL, кириллица)
const CAPTION_FONT_SIZE: int = 28
const CAPTION_OUTLINE: int = 8

const BUTTON_SIZE: Vector2 = Vector2(94.0, 94.0)
const BUTTON_FONT_SIZE: int = 21
const BUTTON_OUTLINE_SIZE: int = 4


static var _font: Font = null
static var _font_checked: bool = false


## Шрифт интерфейса или null, если файл ещё не импортирован (тогда работает стандартный шрифт Godot).
static func font() -> Font:
	if not _font_checked:
		_font_checked = true
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH) as Font
	return _font


## Единый шрифт для надписи Label3D (у Label3D свой шрифт, тема на него не действует).
static func apply_font_3d(label: Label3D) -> void:
	var f: Font = font()
	if f != null:
		label.font = f


static func outline_label(text: String, font_size: int, outline_size: int, color: Color) -> Label:
	var label := Label.new()
	var f: Font = font()
	if f != null:
		label.add_theme_font_override("font", f)
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


## Кнопка-иконка. Если задана подпись (caption), она рисуется под иконкой (Label «Caption», обновляется при смене языка).
static func make_icon_button(key: String, icon_path: String, label: String, parent: Control,
		size: Vector2 = BUTTON_SIZE, caption: String = "") -> Button:
	var button := Button.new()
	button.name = "Btn_" + key
	button.custom_minimum_size = size
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
	var has_caption: bool = caption != ""
	button.add_theme_constant_override("icon_max_width", int(size.x * (0.74 if has_caption else 0.9)))
	button.icon = _load_icon(icon_path)
	button.text = label.substr(0, 1) if button.icon == null else ""
	if has_caption:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var cap: Label = outline_label(caption, CAPTION_FONT_SIZE, CAPTION_OUTLINE, COLOR_TEXT)
		cap.name = "Caption"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		cap.offset_top = -(CAPTION_FONT_SIZE + 8.0)
		cap.offset_bottom = 4.0
		button.add_child(cap)
	parent.add_child(button)
	return button


## Меняет подпись под иконкой (например, при смене языка).
static func set_caption(button: Button, text: String) -> void:
	var cap: Label = button.get_node_or_null("Caption") as Label
	if cap != null:
		cap.text = text


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
