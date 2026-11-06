class_name XpBar
extends Control
## Шкала опыта силы внизу по центру: «Уровень N  x/y» (T14, справочники R2 и R6).
## Видна только пока идёт тренировка (показывает и прячет Hud.set_training).
## Сама слушает Game и перерисовывается по сигналам, лишних обновлений в _process нет.

const BAR_W: float = 480.0
const BAR_H: float = 44.0
const BOTTOM_GAP: float = 20.0
const FONT_SIZE: int = 26
const BORDER: float = 3.0

var _bg: StyleBoxFlat
var _fill: StyleBoxFlat
var _label: Label
var _ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Привязка к низу по центру: на любом соотношении сторон шкала стоит одинаково.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -BAR_W / 2.0
	offset_right = BAR_W / 2.0
	offset_top = -(BAR_H + BOTTOM_GAP)
	offset_bottom = -BOTTOM_GAP

	_bg = UiStyle.panel_style()
	_bg.set_corner_radius_all(int(BAR_H / 2.0))
	_fill = StyleBoxFlat.new()
	_fill.bg_color = UiStyle.COLOR_STRENGTH
	_fill.set_corner_radius_all(int((BAR_H - BORDER * 2.0) / 2.0))

	_label = UiStyle.outline_label("", FONT_SIZE, 5, UiStyle.COLOR_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

	if not Game.xp_changed.is_connected(_on_changed):
		Game.xp_changed.connect(_on_changed)
	if not Game.strength_changed.is_connected(_on_changed):
		Game.strength_changed.connect(_on_changed)
	Loc.language_changed.connect(_on_changed)
	_refresh()


func _draw() -> void:
	if _bg == null:
		return
	draw_style_box(_bg, Rect2(Vector2.ZERO, size))
	if _ratio > 0.0:
		var inner_w: float = size.x - BORDER * 2.0
		var w: float = maxf(inner_w * _ratio, BAR_H - BORDER * 2.0)
		draw_style_box(_fill, Rect2(Vector2(BORDER, BORDER), Vector2(w, size.y - BORDER * 2.0)))


func _on_changed(_value: Variant = null) -> void:
	_refresh()


func _refresh() -> void:
	var level: int = Game.strength()
	var need: float = maxf(Economy.xp_needed(level), 1.0)
	var xp: float = Game.strength_xp()
	_ratio = clampf(xp / need, 0.0, 1.0)
	_label.text = Loc.t("xp_level") % [level, int(xp), int(need)]
	queue_redraw()
