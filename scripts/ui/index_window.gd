class_name IndexWindow
extends WindowBase
## Окно «Индекс» (T18): 5 вкладок по зонам, сетка из 8 карточек в стиле Roblox.
## Карточка это плитка цвета редкости (светлый верх, насыщенный низ): название сверху, иконка зверя, редкость снизу.
## Открытые (`found`) яркие с белой рамкой, неоткрытые приглушённые, с чёрным силуэтом зверя и «???».
## Сверху общий процент, на вкладках название зоны и «x/8». Если все 8 открыты и награда не получена — зелёная кнопка «Забрать $N».

signal zone_reward_claimed

const CARD_W: float = 170.0
const CARD_H: float = 124.0
const CARD_SPACING: float = 10.0
const TABS_H: float = 52.0
const TAB_FONT_SIZE: int = 21
const BUTTON_H: float = 68.0
const BUTTON_W: float = 260.0
const NAME_FONT_SIZE: int = 18
const RARITY_FONT_SIZE: int = 15
const SILHOUETTE_COLOR := Color(0.0, 0.0, 0.0, 0.88)   # неоткрытый зверь: иконка, закрашенная в чёрный

var _tabs: HBoxContainer
var _content: VBoxContainer
var _header_label: Label
var _tab_buttons: Array[Button] = []
var _claim_button: Button
var _pet_panel: PanelContainer
var _pet_panel_style: StyleBoxFlat
var _pet_icon: TextureRect
var _pet_letter: Label
var _pet_name: Label
var _pet_bonus: Label
var _grid_containers: Array[GridContainer] = []
var _current_zone: int = 0
var _total_found: int = 0
var _total_all: int = 40

func _init() -> void:
	title_key = "index_title"
	panel_w_k = 0.78
	panel_w_max = 980.0
	panel_h_k = 0.93
	panel_h_max = 690.0
	super._init()

func _build_body() -> void:
	# Заголовок с общим процентом
	_header_label = UiStyle.outline_label("", 26, 6, UiStyle.COLOR_TEXT)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_header_label)

	# Вкладки зон: кнопки-пилюли, выбранная заливается цветом зоны
	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.add_theme_constant_override("separation", 10)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size = Vector2(0.0, TABS_H + 6.0)
	body.add_child(_tabs)

	for zone_idx in ZoneData.count():
		var tab_button: Button = WindowBase.make_button("", Vector2(0.0, TABS_H), TAB_FONT_SIZE)
		tab_button.name = "Tab_%d" % zone_idx
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.clip_text = true
		UiStyle.apply_tab(tab_button, _zone_accent(zone_idx))
		tab_button.pressed.connect(_on_tab_pressed.bind(zone_idx))
		_tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)

	# Контейнер для контента вкладки
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	body.add_child(_content)

	# T53: строка «Питомец зоны» — значок, название и бонус, у закрытого прогресс Индекса.
	_build_pet_row()

	# Сетки для каждой зоны (скрыты по умолчанию)
	for zone_idx in ZoneData.count():
		var grid: GridContainer = GridContainer.new()
		grid.name = "Grid_%d" % zone_idx
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", int(CARD_SPACING))
		grid.add_theme_constant_override("v_separation", int(CARD_SPACING))
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.visible = false
		_content.add_child(grid)
		_grid_containers.append(grid)

	# Кнопка «Забрать» (спрятана до условия)
	_claim_button = WindowBase.make_button("", Vector2(BUTTON_W, BUTTON_H), 30, "green")
	_claim_button.name = "ClaimButton"
	_claim_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_claim_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_claim_button.visible = false
	_claim_button.pressed.connect(_on_claim_pressed)
	body.add_child(_claim_button)

	# Подписка на изменения инвентаря (новые звери)
	if not Game.inventory_changed.is_connected(_on_game_changed):
		Game.inventory_changed.connect(_on_game_changed)
	# T53: открытие питомца обновляет строку, если окно уже открыто.
	if not Game.pet_unlocked.is_connected(_on_pet_unlocked):
		Game.pet_unlocked.connect(_on_pet_unlocked)


## Яркий цвет зоны для выбранной вкладки (из цвета земли зоны, подтянутый по насыщенности и яркости).
func _zone_accent(zone_idx: int) -> Color:
	var ground: Color = Color.html(String(ZoneData.ZONES[zone_idx]["ground"]))
	return Color.from_hsv(ground.h, clampf(ground.s * 1.15 + 0.1, 0.0, 1.0), clampf(maxf(ground.v, 0.8), 0.0, 1.0))


## T53: строка питомца зоны. Значок берётся из существующих animal_*.png, новых картинок нет.
func _build_pet_row() -> void:
	_pet_panel = PanelContainer.new()
	_pet_panel.name = "PetRow"
	_pet_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pet_panel_style = StyleBoxFlat.new()
	_pet_panel_style.bg_color = Color("#101018")
	_pet_panel_style.set_corner_radius_all(16)
	_pet_panel_style.set_border_width_all(3)
	_pet_panel_style.set_content_margin_all(8.0)
	_pet_panel.add_theme_stylebox_override("panel", _pet_panel_style)
	_content.add_child(_pet_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pet_panel.add_child(row)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(52.0, 52.0)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_box)

	_pet_icon = TextureRect.new()
	_pet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pet_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_pet_icon)

	_pet_letter = UiStyle.outline_label("?", 34, 6, Color(0.6, 0.6, 0.65))
	_pet_letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pet_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pet_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pet_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_pet_letter)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)

	var title: Label = UiStyle.outline_label(Loc.t("pet_index_title"), 16, 4, Color(0.75, 0.75, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title)

	_pet_name = UiStyle.outline_label("", 22, 5, UiStyle.COLOR_TEXT)
	_pet_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pet_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_pet_name)

	_pet_bonus = UiStyle.outline_label("", 17, 4, UiStyle.COLOR_MONEY)
	_pet_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pet_bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_pet_bonus)


func refresh() -> void:
	_update_header()
	_update_tabs()
	_update_current_grid()
	_update_claim_button()
	_update_pet_row()

func _update_header() -> void:
	_total_found = 0
	var found: Array = Game._arr("found")
	for zone_idx in ZoneData.count():
		for a in AnimalData.zone_animals(zone_idx):
			if found.has(String(a["id"])):
				_total_found += 1
	_total_all = ZoneData.count() * 8
	var percent: float = (_total_found / float(_total_all)) * 100.0
	_header_label.text = Loc.t("index_header") % [str(_total_found), str(_total_all), "%.0f" % percent]

func _update_tabs() -> void:
	var found: Array = Game._arr("found")
	for zone_idx in ZoneData.count():
		var zone_found: int = 0
		for a in AnimalData.zone_animals(zone_idx):
			if found.has(String(a["id"])):
				zone_found += 1
		var btn: Button = _tab_buttons[zone_idx]
		btn.text = "%s %s" % [Loc.t(String(ZoneData.ZONES[zone_idx]["name_key"])), Loc.t("index_tab") % zone_found]
		# Выбранная вкладка: disabled-стиль (залит цветом зоны), клик по ней не нужен
		btn.disabled = (zone_idx == _current_zone)

func _update_current_grid() -> void:
	for zone_idx in ZoneData.count():
		_grid_containers[zone_idx].visible = (zone_idx == _current_zone)

	if _grid_containers[_current_zone].get_child_count() == 0:
		_build_zone_grid(_current_zone)
	else:
		_refresh_zone_grid(_current_zone)

func _build_zone_grid(zone_idx: int) -> void:
	var grid: GridContainer = _grid_containers[zone_idx]
	var found: Array = Game._arr("found")

	for rank in range(1, 9):
		var animal: Dictionary = AnimalData.at_rank(zone_idx, rank)
		if animal.is_empty():
			continue
		var animal_id: String = String(animal["id"])
		var is_found: bool = found.has(animal_id)
		var rarity: int = AnimalData.rarity_of(animal_id)
		var rarity_color: Color = AnimalData.rarity_color(rarity)

		# Плитка цвета редкости: у открытых яркая с белой рамкой, у неоткрытых приглушённая с тёмной.
		var border_color: Color = Color.WHITE if is_found else rarity_color.darkened(0.6)
		var card: ColorRect = UiStyle.rarity_tile(Vector2(CARD_W, CARD_H), rarity_color, 16.0, 3.0, border_color, not is_found)
		card.name = "Card_" + animal_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(margin)

		var card_vbox: VBoxContainer = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 0)
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(card_vbox)

		# Название сверху (у неоткрытых «???»)
		var name_label: Label = UiStyle.outline_label("", NAME_FONT_SIZE, 6, UiStyle.COLOR_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = Loc.t("animal_" + animal_id) if is_found else "???"
		card_vbox.add_child(name_label)

		# Иконка / силуэт по центру
		card_vbox.add_child(_make_card_icon(animal_id, is_found, rarity_color))

		# Редкость снизу (показываем и у неоткрытых, как в Roblox)
		var rarity_label: Label = UiStyle.outline_label(Loc.t("rarity_%d" % rarity), RARITY_FONT_SIZE, 5, UiStyle.COLOR_TEXT)
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(rarity_label)

		grid.add_child(card)

func _refresh_zone_grid(zone_idx: int) -> void:
	# Карточек всего 8: проще пересобрать их целиком, чем править детей по индексам.
	var grid: GridContainer = _grid_containers[zone_idx]
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_build_zone_grid(zone_idx)

## Иконка зверя в карточке: растягивается на всё свободное место между названием и редкостью.
## Открытый: PNG с прозрачным фоном (assets/ui/icons/animal_<id>.png). Неоткрытый: тот же PNG, закрашенный в чёрный
## (силуэт); если картинки нет, буква или «?».
func _make_card_icon(animal_id: String, is_found: bool, rarity_color: Color) -> Control:
	var icon_path: String = "res://assets/ui/icons/animal_%s.png" % animal_id
	if ResourceLoader.exists(icon_path):
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = load(icon_path) as Texture2D
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(0.0, 56.0)
		tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not is_found:
			tex_rect.modulate = SILHOUETTE_COLOR   # прозрачный фон остаётся прозрачным, зверь становится чёрным
		return tex_rect
	# Нет картинки: буква названия у открытого, «?» у неоткрытого
	var text: String = Loc.t("animal_" + animal_id).left(1).to_upper() if is_found else "?"
	var letter: Label = UiStyle.outline_label(text, 40, 7, rarity_color.lightened(0.5) if is_found else Color(0.55, 0.55, 0.6))
	letter.custom_minimum_size = Vector2(0.0, 56.0)
	letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return letter

func _update_claim_button() -> void:
	var found: Array = Game._arr("found")
	var zone_complete: bool = true
	for a in AnimalData.zone_animals(_current_zone):
		if not found.has(String(a["id"])):
			zone_complete = false
			break

	var reward_claimed: bool = Game.is_zone_reward_claimed(_current_zone)

	if zone_complete and not reward_claimed:
		var reward: float = Economy.zone_reward(_current_zone)
		_claim_button.text = Loc.t("index_claim") % NumFmt.money(reward)
		_claim_button.visible = true
		_claim_button.disabled = false
	else:
		_claim_button.visible = false

func _update_pet_row() -> void:
	if _pet_panel == null:
		return
	var pet: Dictionary = PetData.by_zone(_current_zone)
	if pet.is_empty():
		_pet_panel.visible = false
		return
	_pet_panel.visible = true
	var unlocked: bool = Game.is_pet_unlocked(_current_zone)
	var animal_id: String = String(pet["model_animal"])
	var icon_path: String = UiStyle.ICON_DIR + "animal_" + animal_id + ".png"
	var icon_tex: Texture2D = null
	if unlocked and ResourceLoader.exists(icon_path):
		icon_tex = load(icon_path) as Texture2D
	_pet_icon.texture = icon_tex
	_pet_icon.visible = icon_tex != null
	_pet_letter.visible = icon_tex == null

	if unlocked:
		_pet_panel_style.border_color = Color(1.0, 0.82, 0.25)
		_pet_name.text = Loc.t(String(pet["name_key"]))
		_pet_name.add_theme_color_override("font_color", Color("#FFD23F"))
		var percent: int = int(roundf(float(pet["value"]) * 100.0))
		_pet_bonus.text = Loc.t("pet_bonus_" + String(pet["bonus"])) % percent
		_pet_bonus.add_theme_color_override("font_color", UiStyle.COLOR_MONEY)
		_pet_letter.text = Loc.t(String(pet["name_key"])).left(1).to_upper()
		_pet_letter.add_theme_color_override("font_color", Color("#FFD23F"))
	else:
		_pet_panel_style.border_color = Color(0.3, 0.3, 0.35)
		_pet_name.text = Loc.t("pet_locked")
		_pet_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		var found: int = PetLogic.found_in_zone(_current_zone)
		var total: int = AnimalData.zone_animals(_current_zone).size()
		_pet_bonus.text = Loc.t("pet_progress") % [
			Loc.t(String(ZoneData.ZONES[_current_zone]["name_key"])), found, total
		]
		_pet_bonus.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_pet_letter.text = "?"


func _on_tab_pressed(zone_idx: int) -> void:
	if zone_idx == _current_zone:
		return
	_current_zone = zone_idx
	refresh()

func _on_claim_pressed() -> void:
	var reward: float = Game.claim_zone_reward(_current_zone)
	if reward > 0.0:
		show_toast(Loc.t("index_claimed") % NumFmt.money(reward))
		zone_reward_claimed.emit()
		refresh()

func _on_game_changed() -> void:
	if visible:
		refresh()


func _on_pet_unlocked(_zone: int, _pet_id: String) -> void:
	if visible:
		refresh()

func _on_language_changed() -> void:
	if _title != null:
		_title.text = Loc.t(title_key)
	refresh()

## Проверяет, есть ли неполученные награды за зоны.
static func has_unclaimed_rewards() -> bool:
	for zone_idx in ZoneData.count():
		if Game.is_zone_complete(zone_idx) and not Game.is_zone_reward_claimed(zone_idx):
			return true
	return false
