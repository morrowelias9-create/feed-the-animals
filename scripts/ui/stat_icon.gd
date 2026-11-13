class_name StatIcon
extends Control
## Иконка показателя в левом нижнем углу HUD: «strength» (гантель) и «money» (монета).
## Если лежит файл res://assets/ui/icons/stat_<вид>.png, рисуется он (иконки можно подменить позже без правок кода),
## иначе иконка рисуется кодом из простых фигур. Перерисовка только при смене размера, в _process ничего нет.

const KIND_STRENGTH: String = "strength"
const KIND_MONEY: String = "money"
const OUTLINE: Color = Color(0.0, 0.0, 0.0, 1.0)

var kind: String = KIND_MONEY
var _texture: Texture2D = null


static func create(new_kind: String, icon_size: float) -> StatIcon:
	var icon := StatIcon.new()
	icon.kind = new_kind
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = UiStyle.ICON_DIR + "stat_%s.png" % new_kind
	if ResourceLoader.exists(path):
		icon._texture = load(path) as Texture2D
	return icon


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _texture != null:
		draw_texture_rect(_texture, rect, false)
		return
	if kind == KIND_STRENGTH:
		_draw_dumbbell(rect)
	else:
		_draw_coin(rect)


# Монета: тёмно-золотая кайма, золотой диск, внутренний ободок, знак «$» и блик.
func _draw_coin(rect: Rect2) -> void:
	var c: Vector2 = rect.get_center()
	var r: float = minf(rect.size.x, rect.size.y) * 0.46
	draw_circle(c, r, OUTLINE)
	draw_circle(c, r * 0.9, Color("#B8860B"))
	draw_circle(c, r * 0.8, Color("#FFC83D"))
	draw_arc(c, r * 0.62, 0.0, TAU, 32, Color("#E0A000"), maxf(r * 0.1, 1.5), true)
	var f: Font = UiStyle.font()
	if f == null:
		f = ThemeDB.fallback_font
	var fs: int = int(r * 1.25)
	var text_size: Vector2 = f.get_string_size("$", HORIZONTAL_ALIGNMENT_CENTER, -1.0, fs)
	var pos := Vector2(c.x - text_size.x * 0.5, c.y + f.get_ascent(fs) * 0.5 - text_size.y * 0.02)
	draw_string(f, pos + Vector2(0.0, r * 0.04), "$", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color("#8A5A00"))
	draw_arc(c, r * 0.72, deg_to_rad(200.0), deg_to_rad(260.0), 10, Color(1.0, 1.0, 1.0, 0.75), maxf(r * 0.1, 1.5), true)


# Гантель под наклоном: серый гриф, по две синие «блины» с каждой стороны, чёрная обводка.
func _draw_dumbbell(rect: Rect2) -> void:
	var c: Vector2 = rect.get_center()
	var u: float = minf(rect.size.x, rect.size.y)
	draw_set_transform(c, deg_to_rad(-35.0), Vector2.ONE)
	var bar := Rect2(Vector2(-u * 0.34, -u * 0.05), Vector2(u * 0.68, u * 0.10))
	_rounded(bar.grow(u * 0.03), OUTLINE)
	_rounded(bar, Color("#C9CED6"))
	for side in [-1.0, 1.0]:
		var big := Rect2(Vector2(u * 0.23 * side - u * 0.075, -u * 0.30), Vector2(u * 0.15, u * 0.60))
		var small := Rect2(Vector2(u * 0.37 * side - u * 0.05, -u * 0.20), Vector2(u * 0.10, u * 0.40))
		_rounded(big.grow(u * 0.03), OUTLINE)
		_rounded(small.grow(u * 0.03), OUTLINE)
		_rounded(big, UiStyle.COLOR_STRENGTH)
		_rounded(small, Color("#2E8FD6"))
		# блик на большом диске
		_rounded(Rect2(big.position + Vector2(u * 0.02, u * 0.04), Vector2(u * 0.03, big.size.y * 0.45)), Color(1.0, 1.0, 1.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Прямоугольник со скруглёнными углами из StyleBoxFlat.
func _rounded(rect: Rect2, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.4))
	draw_style_box(sb, rect)
