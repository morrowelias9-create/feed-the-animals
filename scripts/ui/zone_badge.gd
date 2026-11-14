class_name ZoneBadge
extends RefCounted
## Круглый значок биома: чёрное кольцо, заливка цветом земли зоны, первая буква названия (T48, T40).
## Если есть файл res://assets/ui/icons/zone_<id>.png, рисуется он вместо буквы (как в StatIcon).

const RING: float = 3.0
const BASE_DIAMETER: float = 44.0
const BASE_FONT: int = 26
const BASE_OUTLINE: int = 6
const ICON_PATH: String = "res://assets/ui/icons/zone_%s.png"

static var _colors: Array[Color] = []
static var _textures: Dictionary = {}   # id зоны -> Texture2D или null (проверено, файла нет)


## Цвет земли зоны (кэшируется, строка разбирается один раз).
static func zone_color(zone: int) -> Color:
	if _colors.is_empty():
		for z in ZoneData.ZONES:
			_colors.append(Color.html(str(z["ground"])))
	return _colors[clampi(zone, 0, _colors.size() - 1)]


static func _texture_for(zone: int) -> Texture2D:
	var id: String = str(ZoneData.ZONES[clampi(zone, 0, ZoneData.count() - 1)]["id"])
	if not _textures.has(id):
		var path: String = ICON_PATH % id
		_textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[id]


## Рисует значок на canvas (Control или другом CanvasItem) в его координатах.
static func draw_badge(canvas: CanvasItem, center: Vector2, diameter: float, zone: int) -> void:
	var r: float = diameter * 0.5
	var tex: Texture2D = _texture_for(zone)
	if tex != null:
		canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(diameter, diameter)), false)
		return
	canvas.draw_circle(center, r, Color.BLACK)
	canvas.draw_circle(center, r - RING, zone_color(zone))
	var f: Font = UiStyle.font()
	if f == null:
		f = ThemeDB.fallback_font
	var k: float = diameter / BASE_DIAMETER
	var fs: int = maxi(int(BASE_FONT * k), 8)
	var letter: String = Loc.t(str(ZoneData.ZONES[clampi(zone, 0, ZoneData.count() - 1)]["name_key"])).substr(0, 1).to_upper()
	var ts: Vector2 = f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var pos := Vector2(center.x - ts.x * 0.5, center.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	canvas.draw_string_outline(f, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, int(BASE_OUTLINE * k), Color.BLACK)
	canvas.draw_string(f, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color.WHITE)
