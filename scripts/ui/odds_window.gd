class_name OddsWindow
extends WindowBase
## T58: окно «Подробности» (открывается кнопкой в палатке еды). Показывает шансы выпадения для выбранной еды
## на середине её зоны: звери по рангам, мутации (обычный и счастливый бросок рядом), шанс крупного размера.
## Числа берутся из SpawnRoller.get_odds, то есть из тех же функций, что и сам бросок.
## Не учитывает страховку от невезения, джекпот и анти-повтор зверей (это поправки поверх шансов).

const COL_W: float = 170.0
const ROW_FONT: int = 24
const SECTION_FONT: int = 28
const NOTE_FONT: int = 20
const COLOR_SECTION: Color = Color("#FFD23F")

var _scroll: ScrollContainer
var _content: VBoxContainer
var _tier: int = 0


func _init() -> void:
	title_key = "odds_title"
	panel_w_k = 0.72
	panel_w_max = 860.0
	panel_h_k = 0.9
	panel_h_max = 660.0


## Открывает окно для еды tier.
func show_for(tier: int) -> void:
	_tier = clampi(tier, 0, FoodData.count() - 1)
	open()


func _build_body() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	_scroll.add_child(_content)


func refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var zone: int = clampi(FoodData.zone_of(_tier), 0, ZoneData.count() - 1)
	var z: Dictionary = ZoneData.ZONES[zone]
	var dist: float = (float(z["start_m"]) + float(z["end_m"])) * 0.5
	var plain: Dictionary = SpawnRoller.get_odds(dist, _tier, false)
	var lucky: Dictionary = SpawnRoller.get_odds(dist, _tier, true)

	var food_name: String = Loc.t(String(FoodData.FOODS[_tier]["name_key"]))
	var zone_name: String = Loc.t(String(z["name_key"]))
	_content.add_child(_note(Loc.t("odds_note") % [food_name, zone_name]))

	# Звери зоны по рангам
	_content.add_child(_section(Loc.t("odds_animals")))
	var ranks: Array = plain["ranks"]
	for i in ranks.size():
		var animal: Dictionary = AnimalData.at_rank(zone, i + 1)
		if animal.is_empty():
			continue
		var id: String = String(animal["id"])
		var color: Color = AnimalData.rarity_color(AnimalData.rarity_of(id)).lightened(0.3)
		_content.add_child(_row(Loc.t("animal_" + id), _pct(float(ranks[i])), "", color, false))

	# Мутации: обычный и счастливый бросок
	_content.add_child(_section(Loc.t("odds_mutations")))
	_content.add_child(_row("", Loc.t("odds_normal"), Loc.t("odds_lucky"), AnimalRow.COLOR_SUB, true))
	var pv: Array = plain["variants"]
	var lv: Array = lucky["variants"]
	for v in range(1, pv.size()):
		_content.add_child(_row(Loc.t(VariantData.name_key(v)), _pct(float(pv[v])), _pct(float(lv[v])), VariantData.text_color(v), false))
	_content.add_child(_row(Loc.t("odds_any_mutation"), _pct(1.0 - float(pv[0])), _pct(1.0 - float(lv[0])), UiStyle.COLOR_TEXT, false))

	# Размер
	_content.add_child(_section(Loc.t("odds_size")))
	var sizes: Array = plain["sizes"]
	_content.add_child(_row(Loc.t("odds_size_bigger"), _pct(1.0 - float(sizes[0])), "", UiStyle.COLOR_TEXT, false))
	_content.add_child(_note(Loc.t("odds_lucky_note")))


# Процент с одним знаком; очень малые шансы показываются как «<0.1%».
func _pct(p: float) -> String:
	var v: float = p * 100.0
	if v > 0.0 and v < 0.1:
		return "<0.1%"
	return "%.1f%%" % v


func _section(text: String) -> Label:
	var label: Label = UiStyle.outline_label(text, SECTION_FONT, 6, COLOR_SECTION)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.custom_minimum_size = Vector2(0.0, 44.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _note(text: String) -> Label:
	var label: Label = UiStyle.outline_label(text, NOTE_FONT, 4, AnimalRow.COLOR_SUB)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0.0, 30.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Строка таблицы: название слева, две колонки процентов справа. header даёт приглушённую шапку колонок.
func _row(left: String, mid: String, right: String, color: Color, header: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_label: Label = UiStyle.outline_label(left, ROW_FONT, 5, color)
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left_label)
	var text_color: Color = color if header else UiStyle.COLOR_TEXT
	for text in [mid, right]:
		var cell: Label = UiStyle.outline_label(String(text), ROW_FONT, 5, text_color)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.custom_minimum_size = Vector2(COL_W, 0.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cell)
	return row
