class_name UiStyle
extends RefCounted
## Стили интерфейса: обводка текста, панель, кнопка-иконка, пульсация (шаг T08, справочник R6).
## Стиль «как в Roblox»: глянцевые кнопки с чёрной обводкой и нижней «губой», градиентные плитки цвета редкости,
## тёмные полосы прокрутки со светлым ползунком. Всё строится кодом, картинок не нужно.

const ICON_DIR := "res://assets/ui/icons/"

const COLOR_PANEL: Color = Color(0.169, 0.169, 0.184)
const COLOR_PANEL_BORDER: Color = Color(0.82, 0.82, 0.82)
const COLOR_TEXT: Color = Color.WHITE
const COLOR_OUTLINE: Color = Color.BLACK
const COLOR_STRENGTH: Color = Color("#4DB8FF")
const COLOR_MONEY: Color = Color("#55E05A")

const FONT_PATH := "res://assets/ui/fonts/Nunito-Black.ttf"   # единый шрифт интерфейса (Nunito Black, SIL OFL, кириллица)
const CAPTION_FONT_SIZE: int = 24
const CAPTION_OUTLINE: int = 7

const BUTTON_SIZE: Vector2 = Vector2(94.0, 94.0)
const BUTTON_FONT_SIZE: int = 21
const BUTTON_OUTLINE_SIZE: int = 4

# Палитра кнопок окон: [основной цвет, цвет нижней «губы»].
const BTN_PALETTE: Dictionary = {
	"blue": [Color("#2F9BFF"), Color("#1665C9")],
	"red": [Color("#EF3340"), Color("#A8141E")],
	"green": [Color("#3CCB4F"), Color("#1D8A2E")],
	"orange": [Color("#FFA21A"), Color("#C7660A")],
	"purple": [Color("#B04CF0"), Color("#7623B5")],
	"magenta": [Color("#D02BDB"), Color("#8B1496")],
	"gray": [Color("#5C5C6B"), Color("#3A3A47")],
}
const BTN_RADIUS: int = 12
const BTN_BORDER: int = 3
const BTN_LIP: int = 5                 # высота нижней «губы» кнопки
const BTN_DISABLED_TEXT: Color = Color(0.8, 0.8, 0.85)

static var _font: Font = null
static var _font_checked: bool = false
static var _btn_cache: Dictionary = {}     # "цвет|состояние" -> StyleBoxFlat
static var _grad_shader: Shader = null
static var _window_theme: Theme = null


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


# ---------- Кнопки окон в стиле Roblox ----------

## Стиль кнопки цвета key (из BTN_PALETTE) для состояния: normal, hover, pressed или disabled. Стили общие и кэшируются.
static func button_style(key: String, state: String) -> StyleBoxFlat:
	var cache_key: String = key + "|" + state
	if _btn_cache.has(cache_key):
		return _btn_cache[cache_key] as StyleBoxFlat
	var pal: Array = BTN_PALETTE.get(key, BTN_PALETTE["blue"])
	var base: Color = pal[0]
	var lip: Color = pal[1]
	var lip_h: int = BTN_LIP
	match state:
		"hover":
			base = base.lightened(0.12)
		"pressed":
			base = base.darkened(0.12)
			lip_h = 1
		"disabled":
			var gray: Array = BTN_PALETTE["gray"]
			base = gray[0]
			lip = gray[1]
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(BTN_RADIUS)
	sb.set_border_width_all(BTN_BORDER)
	sb.border_color = Color.BLACK
	# Нижняя «губа»: тень без размытия, сдвинутая вниз, даёт объёмную кнопку.
	sb.shadow_color = lip
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0.0, float(lip_h))
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	_btn_cache[cache_key] = sb
	return sb


## Делает кнопку Roblox-кнопкой цвета key: цветная заливка, чёрная обводка, белый текст с обводкой, нижняя «губа».
static func apply_button(button: Button, key: String = "blue") -> void:
	button.add_theme_stylebox_override("normal", button_style(key, "normal"))
	button.add_theme_stylebox_override("hover", button_style(key, "hover"))
	button.add_theme_stylebox_override("pressed", button_style(key, "pressed"))
	button.add_theme_stylebox_override("disabled", button_style(key, "disabled"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_apply_button_text(button)


## Вкладка: обычная серая; выбранная (кнопка с disabled = true) заливается цветом accent. Клик по выбранной не нужен.
static func apply_tab(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", button_style("gray", "normal"))
	button.add_theme_stylebox_override("hover", button_style("gray", "hover"))
	button.add_theme_stylebox_override("pressed", button_style("gray", "pressed"))
	var active := StyleBoxFlat.new()
	active.bg_color = accent
	active.set_corner_radius_all(BTN_RADIUS)
	active.set_border_width_all(BTN_BORDER)
	active.border_color = Color.BLACK
	active.shadow_color = accent.darkened(0.4)
	active.shadow_size = 1
	active.shadow_offset = Vector2(0.0, float(BTN_LIP))
	active.content_margin_left = 14.0
	active.content_margin_right = 14.0
	active.content_margin_top = 6.0
	active.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("disabled", active)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_apply_button_text(button)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT)


static func _apply_button_text(button: Button) -> void:
	var f: Font = font()
	if f != null:
		button.add_theme_font_override("font", f)
	var size: int = button.get_theme_font_size("font_size")
	var outline: int = clampi(int(round(float(size) * 0.22)), 4, 9)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)
	button.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	button.add_theme_constant_override("outline_size", outline)


# ---------- Градиентные плитки ----------

const GRADIENT_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(1.0);
uniform vec4 bottom_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 border_color : source_color = vec4(1.0);
uniform float radius_px = 14.0;
uniform float border_px = 3.0;
uniform float stripes = 0.0;
uniform float flat_bottom = 0.0;
uniform vec2 rect_size = vec2(100.0, 100.0);

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size;
	float shift = radius_px * flat_bottom;
	vec2 half_size = vec2(rect_size.x * 0.5, rect_size.y * 0.5 + shift);
	float d = sd_box(p - vec2(0.0, shift), half_size, radius_px);
	float outer = 1.0 - smoothstep(-1.0, 0.0, d);
	float inner = 1.0 - smoothstep(-1.0, 0.0, d + border_px);
	vec4 fill = mix(top_color, bottom_color, clamp(UV.y, 0.0, 1.0));
	float gloss = 1.0 - smoothstep(0.0, 0.5, UV.y);
	fill.rgb += vec3(0.10) * gloss;
	float s = fract((p.x - p.y) / 110.0);
	float band = smoothstep(0.0, 0.03, s) * (1.0 - smoothstep(0.22, 0.25, s));
	fill.rgb += vec3(0.07) * band * stripes;
	vec4 col = mix(border_color, fill, inner);
	col.a *= outer;
	COLOR = col;
}
"""


## Плитка с вертикальным градиентом (светлее сверху), скруглёнными углами и обводкой. Рисуется шейдером, поэтому
## корректно тянется под любой размер. Внутрь можно класть дочерние узлы (иконку, подписи).
## flat_bottom: нижние углы прямые (для шапки окна). stripes: лёгкие диагональные блики (для шапки).
static func gradient_rect(min_size: Vector2, top: Color, bottom: Color, radius: float = 14.0, border: float = 3.0,
		border_color: Color = Color.BLACK, stripes: float = 0.0, flat_bottom: bool = false) -> ColorRect:
	if _grad_shader == null:
		_grad_shader = Shader.new()
		_grad_shader.code = GRADIENT_SHADER_CODE
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.custom_minimum_size = min_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _grad_shader
	mat.set_shader_parameter("top_color", top)
	mat.set_shader_parameter("bottom_color", bottom)
	mat.set_shader_parameter("border_color", border_color)
	mat.set_shader_parameter("radius_px", radius)
	mat.set_shader_parameter("border_px", border)
	mat.set_shader_parameter("stripes", stripes)
	mat.set_shader_parameter("flat_bottom", 1.0 if flat_bottom else 0.0)
	mat.set_shader_parameter("rect_size", min_size)
	rect.material = mat
	rect.resized.connect(func() -> void: mat.set_shader_parameter("rect_size", rect.size))
	return rect


## Плитка цвета редкости (как в Roblox): светлый верх, насыщенный низ. dim: приглушённая версия для неоткрытых.
static func rarity_tile(min_size: Vector2, rarity_color: Color, radius: float = 14.0, border: float = 3.0,
		border_color: Color = Color.WHITE, dim: bool = false) -> ColorRect:
	var top: Color = rarity_color.lightened(0.30)
	var bottom: Color = rarity_color.darkened(0.25)
	if dim:
		top = rarity_color.darkened(0.30)
		bottom = rarity_color.darkened(0.55)
	return gradient_rect(min_size, top, bottom, radius, border, border_color)


# ---------- Тема окон: полосы прокрутки ----------

## Тема для содержимого окон: тёмная дорожка и светлый скруглённый ползунок.
static func window_theme() -> Theme:
	if _window_theme != null:
		return _window_theme
	var t := Theme.new()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	track.set_corner_radius_all(9)
	track.content_margin_left = 9.0
	track.content_margin_right = 9.0
	track.content_margin_top = 0.0
	track.content_margin_bottom = 0.0
	var grabber: StyleBoxFlat = _grabber_style(Color("#E4E4F0"))
	var grabber_hover: StyleBoxFlat = _grabber_style(Color("#FFFFFF"))
	var grabber_pressed: StyleBoxFlat = _grabber_style(Color("#D02BDB"))
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber_hover)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber_pressed)
	_window_theme = t
	return t


static func _grabber_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = Color.BLACK
	sb.content_margin_left = 9.0
	sb.content_margin_right = 9.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	return sb
