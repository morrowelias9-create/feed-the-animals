class_name MiniZoneBar
extends Control
## T46: слева вверху название самой дальней мини-зоны, в которую залетала еда, с полосой «сколько из 6 мини-зон биома пройдено»,
## плюс плашка «Новая местность» с наградой при первом входе в мини-зону. Обновляется по сигналу `Game.mini_zone_reached` и смене языка, не в _process.

const BOX_POS: Vector2 = Vector2(16.0, 12.0)
const BOX_W: float = 320.0
const TITLE_FONT: int = 28
const TITLE_OUTLINE: int = 6
const BAR_H: float = 14.0
const BAR_BACK: Color = Color(0.0, 0.0, 0.0, 0.55)
const ANNOUNCE_TOP: float = 124.0          # под подсказкой цели (она занимает 64…112)
const ANNOUNCE_FONT: int = 46
const REWARD_FONT: int = 38
const FADE_IN_S: float = 0.25
const HOLD_S: float = 2.5
const FADE_OUT_S: float = 0.4

var _box: VBoxContainer
var _title: Label
var _bar: Control
var _announce: VBoxContainer
var _announce_name: Label
var _announce_reward: Label
var _tween: Tween
var _fill: float = 0.0
var _fill_color: Color = Color.WHITE
var _back_style: StyleBoxFlat
var _fill_style: StyleBoxFlat
var _last_zone: int = 0
var _last_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_style = StyleBoxFlat.new()
	_back_style.bg_color = BAR_BACK
	_back_style.set_corner_radius_all(int(BAR_H / 2.0))
	_fill_style = StyleBoxFlat.new()
	_fill_style.set_corner_radius_all(int(BAR_H / 2.0))

	_box = VBoxContainer.new()
	var box: VBoxContainer = _box
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = BOX_POS
	box.custom_minimum_size = Vector2(BOX_W, 0.0)
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_title = UiStyle.outline_label("", TITLE_FONT, TITLE_OUTLINE, UiStyle.COLOR_TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(BOX_W, BAR_H)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)

	_announce = VBoxContainer.new()
	_announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_announce.offset_top = ANNOUNCE_TOP
	_announce.offset_bottom = ANNOUNCE_TOP + ANNOUNCE_FONT + REWARD_FONT + 24.0
	_announce.add_theme_constant_override("separation", 0)
	_announce.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_announce.visible = false
	add_child(_announce)
	_announce_name = UiStyle.outline_label("", ANNOUNCE_FONT, 10, UiStyle.COLOR_TEXT)
	_announce_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce.add_child(_announce_name)
	_announce_reward = UiStyle.outline_label("", REWARD_FONT, 8, UiStyle.COLOR_MONEY)
	_announce_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce.add_child(_announce_reward)

	Game.mini_zone_reached.connect(_on_mini_zone_reached)
	Loc.language_changed.connect(_refresh)
	_refresh()


## Скрывает строку и полосу слева вверху в режиме прицеливания; плашка «Новая местность» остаётся (она нужна в полёте).
func set_shown(on: bool) -> void:
	_box.visible = on


@warning_ignore("integer_division")
func _refresh() -> void:
	# Самая дальняя мини-зона, в которую уже залетала еда (поле mini_reached); полоса это сколько из 6 мини-зон биома пройдено.
	var g: int = maxi(int(Save.data.get("mini_reached", 0)), 0)
	var zone: int = clampi(g / MiniZoneData.PER_ZONE, 0, ZoneData.count() - 1)
	var index: int = g % MiniZoneData.PER_ZONE
	_title.text = Loc.t("zone_progress_fmt") % [Loc.t(String(ZoneData.ZONES[zone]["name_key"])),
		Loc.t(MiniZoneData.name_key(zone, index)), index + 1]
	_fill = float(index + 1) / float(MiniZoneData.PER_ZONE)
	_fill_color = Color.html(String(ZoneData.ZONES[zone]["ground"]))
	_bar.queue_redraw()


func _draw_bar() -> void:
	var full: Rect2 = Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_style_box(_back_style, full)
	var w: float = maxf(_bar.size.x * _fill, BAR_H)
	_fill_style.bg_color = _fill_color
	_bar.draw_style_box(_fill_style, Rect2(Vector2.ZERO, Vector2(minf(w, _bar.size.x), _bar.size.y)))


func _on_mini_zone_reached(zone: int, index: int, reward: float) -> void:
	_announce_name.text = Loc.t("mini_zone_new") % Loc.t(MiniZoneData.name_key(zone, index))
	_announce_reward.text = "+" + NumFmt.money(reward)
	_announce.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_announce.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tween = create_tween()
	_tween.tween_property(_announce, "modulate:a", 1.0, FADE_IN_S)
	_tween.tween_interval(HOLD_S)
	_tween.tween_property(_announce, "modulate:a", 0.0, FADE_OUT_S)
	_tween.tween_callback(func() -> void: _announce.visible = false)

