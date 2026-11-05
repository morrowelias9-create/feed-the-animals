class_name RevealOverlay
extends CanvasLayer
## Экран кинематики получения зверя (шаг T10c, справочник R2 и R6): виньетка, имя по буквам,
## итоговый экран («Удача!», SCORE, название, доход), вспышка. Отдельный слой над HUD.
## Всё в базе 1280x720, по центру, без плашек. Касания не перехватывает: их читает InputRouter.

const LETTER_POP_S: float = 0.1
const LETTER_POP_SCALE: float = 1.4
const DASH_W: float = 47.0
const DASH_H: float = 13.0
const DASH_GAP: float = 2.0
const DASH_CENTER_Y: float = 585.0
const NAME_MAX_W: float = 1180.0
const SLOT_H: float = 60.0
const RAYS_CENTER_Y: float = 167.0
const LUCK_COLOR: Color = Color("#FFD9A0")
const RAY_COLOR: Color = Color("#FF2D55")

var _root: Control
var _vignette: TextureRect
var _ui: Control
var _rays: RayBurst
var _title: Label
var _score: Label
var _score_val: int = 0
var _variant: Label
var _name: Label
var _rarity: Label
var _income: Label
var _size: Label
var _prompt: Label
var _slots_root: Control
var _flash: ColorRect

var _letters: Array[Dictionary] = []   # {label: Label, at: float}, at < 0 пока буква не показана
var _order: Array[int] = []            # порядок появления букв (индексы в _letters)
var _next: int = 0
var _interval: float = 0.12
var _type_t: float = 0.0
var _typing: bool = false
var _clock: float = 0.0
var _flash_a: float = 0.0
var _result_on: bool = false


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_vignette()
	_ui = Control.new()
	_ui.name = "Ui"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ui)
	_rays = RayBurst.new()
	_rays.name = "Rays"
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_rays.offset_left = 0.0
	_rays.offset_right = 0.0
	_rays.offset_top = RAYS_CENTER_Y
	_rays.offset_bottom = RAYS_CENTER_Y
	_ui.add_child(_rays)
	_title = _row("Title", 40, 8, LUCK_COLOR, 57.0)
	_score = _row("Score", 57, 9, Color.WHITE, 127.0)
	_variant = _row("Variant", 27, 6, Color.WHITE, 550.0)
	_name = _row("Name", 50, 8, Color.WHITE, 605.0)
	_rarity = _row("Rarity", 20, 5, Color.WHITE, 635.0)
	_income = _row("Income", 33, 6, UiStyle.COLOR_MONEY, 665.0)
	_size = _row("Size", 18, 4, Color.WHITE, 652.0)
	_prompt = _row("Prompt", 20, 5, Color.WHITE, 703.0)
	_slots_root = Control.new()
	_slots_root.name = "NameSlots"
	_slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_slots_root)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_flash)
	reset()


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_clock += delta
	if _typing:
		_type_t += delta
		while _next < _order.size() and _type_t >= _interval:
			_type_t -= _interval
			_show_letter(_order[_next])
	for item in _letters:
		var at: float = float(item["at"])
		if at < 0.0:
			continue
		var k: float = clampf((_clock - at) / LETTER_POP_S, 0.0, 1.0)
		var label: Label = item["label"]
		label.scale = Vector2.ONE * lerpf(LETTER_POP_SCALE, 1.0, k)
	if _result_on:
		_rays.rotation += delta * 0.35
		_prompt.pivot_offset = _prompt.size * 0.5
		_prompt.scale = Vector2.ONE * (1.0 + 0.06 * sin(_clock * 5.0))
	if _flash_a > 0.0:
		_flash_a = maxf(_flash_a - delta * 3.0, 0.0)
		_flash.color.a = _flash_a


## Скрывает и сбрасывает всё. Вызывается в начале и в конце кинематики.
func reset() -> void:
	_root.visible = false
	_typing = false
	_result_on = false
	_flash_a = 0.0
	_flash.color.a = 0.0
	_ui.modulate.a = 1.0
	_clear_slots()
	for l in [_title, _score, _variant, _name, _rarity, _income, _size, _prompt]:
		(l as Label).visible = false
	_rays.visible = false


## Показывает слой (виньетка включена, остальное по фазам).
func open() -> void:
	reset()
	_root.visible = true
	_vignette.modulate.a = 1.0


func set_vignette(alpha: float) -> void:
	_vignette.modulate.a = clampf(alpha, 0.0, 1.0)


## Прозрачность всего интерфейса (без виньетки): гасим на выходе.
func set_fade(alpha: float) -> void:
	_ui.modulate.a = clampf(alpha, 0.0, 1.0)


## Белая вспышка на весь экран, гаснет сама.
func flash(strength: float = 0.8) -> void:
	_flash_a = clampf(strength, 0.0, 1.0)
	_flash.color.a = _flash_a


# ---------- Печать имени (фаза B) ----------

## Чёрточки по числу букв, буквы появляются по одной в случайном порядке.
func begin_typing(text: String, interval: float) -> void:
	_clear_slots()
	_interval = maxf(interval, 0.01)
	_type_t = 0.0
	_next = 0
	var count: int = text.length()
	if count == 0:
		_typing = false
		return
	var letters_n: int = text.replace(" ", "").length()
	var slot_w: float = minf(DASH_W, floorf((NAME_MAX_W - DASH_GAP * float(count - 1)) / float(maxi(count, 1))))
	var total: float = slot_w * float(count) + DASH_GAP * float(count - 1)
	var top: float = DASH_CENTER_Y - DASH_H * 0.5 - (SLOT_H - DASH_H)
	_slots_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_slots_root.offset_left = -total * 0.5
	_slots_root.offset_right = total * 0.5
	_slots_root.offset_top = top
	_slots_root.offset_bottom = top + SLOT_H
	for i in count:
		var ch: String = text.substr(i, 1)
		if ch == " ":
			continue
		var x: float = float(i) * (slot_w + DASH_GAP)
		var dash := Panel.new()
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dash.position = Vector2(x, SLOT_H - DASH_H)
		dash.size = Vector2(slot_w, DASH_H)
		dash.add_theme_stylebox_override("panel", _dash_style())
		_slots_root.add_child(dash)
		var label: Label = UiStyle.outline_label(ch, 42, 7, Color.WHITE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(x, 0.0)
		label.size = Vector2(slot_w, SLOT_H - DASH_H)
		label.pivot_offset = label.size * 0.5
		label.visible = false
		_slots_root.add_child(label)
		_letters.append({"label": label, "at": -1.0})
	_order.clear()
	for i in letters_n:
		_order.append(i)
	_order.shuffle()
	_typing = true


func typing_done() -> bool:
	return _next >= _order.size()


## Показывает остаток букв сразу (пропуск по тапу).
func skip_typing() -> void:
	while _next < _order.size():
		_show_letter(_order[_next])
	_typing = false


func hide_typing() -> void:
	_typing = false
	_clear_slots()


# ---------- Итог (фаза C) ----------

## info: score (дальность), variant, name, rarity, income, lucky (показывать ли «Удача!» с лучами),
## size_step (ступень цепочки роста размера: мелкая строка «Размер: ...»).
func show_result(info: Dictionary) -> void:
	var variant: int = int(info.get("variant", 0))
	var rarity: int = int(info.get("rarity", 0))
	var rarity_color: Color = AnimalData.rarity_color(rarity)
	_result_on = true
	_title.text = Loc.t("reveal_luck")
	_title.visible = bool(info.get("lucky", false))
	_rays.visible = _title.visible
	_rays.color = RAY_COLOR if variant != VariantData.NONE else rarity_color
	_rays.queue_redraw()
	_score_val = int(info.get("score", 0))
	_score.text = Loc.t("reveal_score") % _score_val
	_score.visible = true
	_variant.visible = variant != VariantData.NONE
	if _variant.visible:
		_variant.text = Loc.t(VariantData.name_key(variant))
		_variant.add_theme_color_override("font_color", VariantData.text_color(variant))
	_name.text = String(info.get("name", ""))
	_name.add_theme_color_override("font_color", rarity_color)
	_name.visible = true
	_rarity.text = Loc.t("rarity_" + str(rarity))
	_rarity.add_theme_color_override("font_color", rarity_color)
	_rarity.visible = true
	_income.text = NumFmt.money(float(info.get("income", 0.0))) + "/s"
	_income.visible = true
	var size_step: int = int(info.get("size_step", 0))
	_size.visible = size_step > 0
	_size.text = _size_text(size_step)
	_prompt.text = Loc.t("reveal_tap")
	_prompt.visible = true


## Цель накрутки SCORE (финиш): текст экрана обновляется до этого значения.
func set_score(final: int) -> void:
	_score_val = int(final)
	_score.text = Loc.t("reveal_score") % _score_val


## Текущий SCORE с накруткой: t секунд с начала фазы C, ease_out от 0 до _score_val.
## Обновляет текст и возвращает текущее значение: накрутка сама идёт от 0 до итогового.
func score_at(t: float) -> int:
	var u: float = clampf(t / GameConfig.REVEAL_SCORE_S, 0.0, 1.0)
	var k: float = 1.0 - pow(1.0 - u, 2.0)
	var value: int = int(roundf(lerpf(0.0, float(_score_val), k)))
	_score.text = Loc.t("reveal_score") % value
	return value


## Ступень цепочки роста размера: мелкая строка под названием зверя.
func set_size_step(size_step: int) -> void:
	_size.visible = size_step > 0
	_size.text = _size_text(size_step)


func _size_text(size_step: int) -> String:
	if size_step <= 0:
		return ""
	var mult: float = SizeData.income_mult(size_step)
	return Loc.t("reveal_size") % [SizeData.name(size_step), str(roundf(mult * 10.0) / 10.0)]


# ---------- Внутреннее ----------

func _show_letter(index: int) -> void:
	if index < 0 or index >= _letters.size():
		_next += 1
		return
	var item: Dictionary = _letters[index]
	var label: Label = item["label"]
	label.visible = true
	label.scale = Vector2.ONE * LETTER_POP_SCALE
	item["at"] = _clock
	_next += 1


func _clear_slots() -> void:
	_letters.clear()
	_order.clear()
	_next = 0
	if _slots_root == null:
		return
	for c in _slots_root.get_children():
		c.queue_free()


func _dash_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_border_width_all(2)
	style.border_color = Color.BLACK
	style.set_corner_radius_all(7)
	return style


# Строка текста по центру экрана: cy это центр по y в базе 720, высота по шрифту.
func _row(node_name: String, font_size: int, outline: int, color: Color, cy: float) -> Label:
	var label: Label = UiStyle.outline_label("", font_size, outline, color)
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var h: float = float(font_size) * 1.4
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = cy - h * 0.5
	label.offset_bottom = cy + h * 0.5
	_ui.add_child(label)
	return label


func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.45)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_vignette = TextureRect.new()
	_vignette.name = "Vignette"
	_vignette.texture = tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_vignette)


## Лучи за заголовком «Удача!»: полупрозрачные клинья, гаснущие к краям. Вращается самим узлом.
class RayBurst extends Control:
	var color: Color = Color("#FF2D55")
	var rays: int = 14
	var radius: float = 900.0

	func _draw() -> void:
		var step: float = TAU / float(rays)
		for i in rays:
			var a0: float = step * float(i)
			var a1: float = a0 + step * 0.5
			var inner: Color = color
			inner.a = 0.55
			var outer: Color = color
			outer.a = 0.0
			var points := PackedVector2Array([
				Vector2.ZERO,
				Vector2(cos(a0), sin(a0)) * radius,
				Vector2(cos(a1), sin(a1)) * radius,
			])
			draw_polygon(points, PackedColorArray([inner, outer, outer]))
