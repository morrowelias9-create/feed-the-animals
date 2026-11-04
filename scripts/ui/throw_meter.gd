class_name ThrowMeter
extends Control
## Шкала броска: вертикальная капсула с градиентом, чёрными делениями и ползунком (шаг T09, справочник R6).

const X_MIN: float = 595.0
const X_MAX: float = 685.0
const Y_MIN: float = 117.0
const Y_MAX: float = 530.0
const TICK_THICK: float = 5.0
const BACKING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const SLIDER_COLOR: Color = Color.WHITE
const CAPSULE_RADIUS: int = 40
const SEGMENT_COLORS: Array[Color] = [
	Color(0.25, 0.85, 0.30),   # зелёный, верх шкалы
	Color(0.65, 0.92, 0.25),   # жёлто-зелёный
	Color(0.95, 0.80, 0.20),   # жёлтый
	Color(0.95, 0.55, 0.15),   # оранжевый
	Color(0.90, 0.25, 0.20),   # красный, низ
]
const TICKS_Y: Array[float] = [190.0, 257.0, 390.0, 457.0]
const ANIM_PERIOD: float = 1.4

var _v: float = 0.0
var _t: float = 0.0
var _running: bool = false
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label = UiStyle.outline_label("+0", 43, 5, UiStyle.COLOR_TEXT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(723.0, Y_MAX - 20.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Запуск анимации ползунка вверх-вниз (период 1.4 с туда-обратно).
func start() -> void:
	_running = true
	_t = 0.0
	_v = 0.0
	_update_label()


## Остановить: ползунок фиксируется на текущем значении, возвращается оно.
func stop() -> float:
	_running = false
	return _v


func get_value() -> float:
	return _v


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	var cycles: int = int(_t / ANIM_PERIOD)
	var pos: float = _t - ANIM_PERIOD * cycles
	var half: float = ANIM_PERIOD * 0.5
	var tri: float = pos / half
	if tri > 1.0:
		tri = 2.0 - tri
	_v = tri
	_update_label()


func _draw() -> void:
	var w: float = X_MAX - X_MIN
	var bounds: Array[float] = [Y_MIN, TICKS_Y[0], TICKS_Y[1], TICKS_Y[2], TICKS_Y[3], Y_MAX]
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.BLACK
	outline.set_corner_radius_all(CAPSULE_RADIUS)
	draw_style_box(outline, Rect2(X_MIN, Y_MIN, w, Y_MAX - Y_MIN))
	for i in range(bounds.size() - 1):
		var seg := StyleBoxFlat.new()
		seg.bg_color = SEGMENT_COLORS[i]
		seg.set_corner_radius_all(int(minf(CAPSULE_RADIUS, (bounds[i + 1] - bounds[i]) * 0.5)))
		draw_style_box(seg, Rect2(X_MIN, bounds[i], w, bounds[i + 1] - bounds[i]))
	for ty in TICKS_Y:
		var tick := StyleBoxFlat.new()
		tick.bg_color = Color.BLACK
		draw_style_box(tick, Rect2(X_MIN, ty - TICK_THICK * 0.5, w, TICK_THICK))
	var slider_y: float = lerp(Y_MAX, Y_MIN, _v)
	var backing := StyleBoxFlat.new()
	backing.bg_color = BACKING_COLOR
	backing.set_corner_radius_all(12)
	draw_style_box(backing, Rect2(576.5, slider_y - 23.5, 127.0, 47.0))
	var slider := StyleBoxFlat.new()
	slider.bg_color = SLIDER_COLOR
	slider.set_corner_radius_all(8)
	draw_style_box(slider, Rect2(583.5, slider_y - 11.5, 113.0, 23.0))


func _update_label() -> void:
	if _label == null:
		return
	var bonus: int = ThrowCalc.bonus_of(_v)
	_label.text = "+" + str(bonus)
	_label.position = Vector2(723.0, lerp(Y_MAX, Y_MIN, _v) - 20.0)
