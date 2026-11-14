class_name ThrowMeter
extends Control
## Шкала броска (T48, справочник R6): горизонтальная капсула с сегментами по открытым биомам.
## Ползунок ходит слева направо и обратно; остановка в сегменте старого биома бросает еду в этот биом,
## правый (самый широкий) сегмент это «максимальная дальность». Логика сегментов в ThrowScale.

const BAR_MAX_W: float = 1200.0
const BAR_MARGIN: float = 80.0          # минимум свободного места по краям экрана (суммарно)
const CAPSULE_Y: float = 470.0
const CAPSULE_H: float = 60.0
const CAPSULE_RADIUS: int = 30
const CAPSULE_PAD: float = 4.0          # отступ цветных сегментов от чёрной подложки
const DIVIDER_W: float = 5.0
const ICON_D: float = 44.0
const ICON_Y: float = 440.0
const ICON_ACTIVE_SCALE: float = 1.25
const SLIDER_W: float = 14.0
const SLIDER_H: float = 84.0
const BACKING_W: float = 26.0
const BACKING_H: float = 96.0
const SLIDER_CENTER_Y: float = 500.0
const LABEL_Y: float = 395.0
const LABEL_FONT_SIZE: int = 34
const LABEL_OUTLINE: int = 6
const BACKING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const ANIM_PERIOD: float = 2.6          # туда-обратно, секунд (раньше 1.4)

var _open: int = 1
var _dmax: float = 0.0
var _widths: Array[float] = [1.0]
var _starts: Array[float] = [0.0]
var _from: Array[float] = [0.0]         # начало дальности каждого сегмента, м
var _to: Array[float] = [0.0]           # конец дальности каждого сегмента, м
var _boxes: Array[StyleBoxFlat] = []    # цветные сегменты, создаются один раз в configure
var _sb_outer: StyleBoxFlat
var _sb_backing: StyleBoxFlat
var _sb_slider: StyleBoxFlat

var _v: float = 0.0
var _t: float = 0.0
var _running: bool = false
var _label: Label
var _label_key: int = -1                # (мини-зона, метры): текст пересобирается только при смене
var _label_size: Vector2 = Vector2.ZERO
var _x0: float = 0.0                    # левый край капсулы, считается по ширине экрана
var _bar_w: float = BAR_MAX_W


func _init() -> void:
	_sb_outer = StyleBoxFlat.new()
	_sb_outer.bg_color = Color.BLACK
	_sb_outer.set_corner_radius_all(CAPSULE_RADIUS)
	_sb_backing = StyleBoxFlat.new()
	_sb_backing.bg_color = BACKING_COLOR
	_sb_backing.set_corner_radius_all(13)
	_sb_slider = StyleBoxFlat.new()
	_sb_slider.bg_color = Color.WHITE
	_sb_slider.set_corner_radius_all(7)
	configure(1, 0.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_label = UiStyle.outline_label("", LABEL_FONT_SIZE, LABEL_OUTLINE, UiStyle.COLOR_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	resized.connect(queue_redraw)
	Loc.language_changed.connect(_on_language_changed)


## Задать число сегментов (открытых биомов) и максимальную дальность. Вызывается перед start().
## Не зависит от дерева сцены: только считает числа и готовит стили.
func configure(open_zones: int, dmax: float) -> void:
	_open = maxi(open_zones, 1)
	_dmax = maxf(dmax, 0.0)
	_widths = ThrowScale.segment_widths(_open)
	_starts = ThrowScale.segment_starts(_open)
	_from.clear()
	_to.clear()
	_boxes.clear()
	for i in _open:
		var zone: int = clampi(i, 0, ZoneData.count() - 1)
		var from_m: float = float(ZoneData.ZONES[zone]["start_m"])
		var to_m: float
		if i < _open - 1:
			to_m = float(ZoneData.ZONES[zone]["end_m"]) - ThrowScale.END_EPS
		else:
			to_m = maxf(_dmax, from_m)
		_from.append(from_m)
		_to.append(to_m)
		_boxes.append(_make_segment_box(i, zone))
	_label_key = -1
	queue_redraw()


# Цветной сегмент: скруглены только внешние углы первого и последнего.
func _make_segment_box(index: int, zone: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ZoneBadge.zone_color(zone)
	var r: int = CAPSULE_RADIUS - int(CAPSULE_PAD)
	if index == 0:
		sb.corner_radius_top_left = r
		sb.corner_radius_bottom_left = r
	if index == _open - 1:
		sb.corner_radius_top_right = r
		sb.corner_radius_bottom_right = r
	return sb


## Запуск анимации ползунка слева направо и обратно (период ANIM_PERIOD).
func start() -> void:
	_running = true
	_t = 0.0
	_v = 0.0
	_label_key = -1
	set_process(true)
	_update_label()
	queue_redraw()


## Остановить: ползунок фиксируется на текущем значении, возвращается оно (0…1).
func stop() -> float:
	_running = false
	set_process(false)
	queue_redraw()
	return _v


func get_value() -> float:
	return _v


## Дальность броска в метрах для положения ползунка v.
func distance_for(v: float) -> float:
	return ThrowScale.distance_at(v, _open, _dmax)


## Дальность при текущем положении ползунка.
func current_distance() -> float:
	return distance_for(_v)


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	var pos: float = fposmod(_t, ANIM_PERIOD)
	var tri: float = pos / (ANIM_PERIOD * 0.5)
	if tri > 1.0:
		tri = 2.0 - tri
	_v = tri
	_update_label()
	queue_redraw()   # перерисовка только пока ползунок движется


func _layout() -> void:
	_bar_w = minf(BAR_MAX_W, size.x - BAR_MARGIN)
	_x0 = (size.x - _bar_w) * 0.5


# Номер сегмента для положения x по кэшированным границам (без выделения массивов в кадре).
func _segment_index(x: float) -> int:
	var result: int = 0
	for i in _starts.size():
		if x >= _starts[i]:
			result = i
	return result


# То же, что ThrowScale.distance_at, но по кэшу: вызывается каждый кадр для подписи.
func _dist_cached(v: float) -> float:
	var x: float = clampf(v, 0.0, 1.0)
	var i: int = _segment_index(x)
	var t: float = 0.0
	if _widths[i] > 0.0:
		t = clampf((x - _starts[i]) / _widths[i], 0.0, 1.0)
	return _from[i] + t * (_to[i] - _from[i])


func _draw() -> void:
	_layout()
	var inner_x: float = _x0 + CAPSULE_PAD
	var inner_w: float = _bar_w - CAPSULE_PAD * 2.0
	var seg_y: float = CAPSULE_Y + CAPSULE_PAD
	var seg_h: float = CAPSULE_H - CAPSULE_PAD * 2.0
	draw_style_box(_sb_outer, Rect2(_x0, CAPSULE_Y, _bar_w, CAPSULE_H))
	for i in _open:
		draw_style_box(_boxes[i], Rect2(inner_x + _starts[i] * inner_w, seg_y, _widths[i] * inner_w, seg_h))
	for i in range(1, _open):
		draw_rect(Rect2(inner_x + _starts[i] * inner_w - DIVIDER_W * 0.5, seg_y, DIVIDER_W, seg_h), Color.BLACK)
	var current: int = _segment_index(_v)
	for i in _open:
		var cx: float = inner_x + (_starts[i] + _widths[i] * 0.5) * inner_w
		var d: float = ICON_D * (ICON_ACTIVE_SCALE if i == current else 1.0)
		ZoneBadge.draw_badge(self, Vector2(cx, ICON_Y), d, i)
	var sx: float = inner_x + _v * inner_w
	draw_style_box(_sb_backing, Rect2(sx - BACKING_W * 0.5, SLIDER_CENTER_Y - BACKING_H * 0.5, BACKING_W, BACKING_H))
	draw_style_box(_sb_slider, Rect2(sx - SLIDER_W * 0.5, SLIDER_CENTER_Y - SLIDER_H * 0.5, SLIDER_W, SLIDER_H))


# Подпись над ползунком: «Название мини-зоны  187 м». Текст пересобирается только при смене значения.
func _update_label() -> void:
	if _label == null:
		return
	_layout()
	var dist: float = _dist_cached(_v)
	var zone: int = ZoneData.zone_at(dist)
	var mini: int = MiniZoneData.index_at(dist)
	var key: int = (zone * MiniZoneData.PER_ZONE + mini) * 100000 + int(dist)
	if key != _label_key:
		_label_key = key
		_label.text = Loc.t(MiniZoneData.name_key(zone, mini)) + "  " + str(int(dist)) + " " + Loc.t("unit_m")
		_label_size = _label.get_minimum_size()
		_label.size = _label_size
	var inner_x: float = _x0 + CAPSULE_PAD
	var sx: float = inner_x + _v * (_bar_w - CAPSULE_PAD * 2.0)
	var lx: float = clampf(sx - _label_size.x * 0.5, _x0, maxf(_x0, _x0 + _bar_w - _label_size.x))
	_label.position = Vector2(lx, LABEL_Y - _label_size.y * 0.5)


func _on_language_changed() -> void:
	_label_key = -1
	_update_label()
	queue_redraw()
