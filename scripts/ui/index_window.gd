class_name IndexWindow
extends WindowBase
## Окно «Индекс» (T18): 5 вкладок по зонам, сетка из 8 карточек.
## Открытые (`found`) с названием и редкостью, неоткрытые тёмным силуэтом и «???».
## Сверху общий процент, на вкладках «x/8». Если все 8 открыты и награда не получена — кнопка «Забрать $N».

signal zone_reward_claimed

const CARD_W: float = 130.0
const CARD_H: float = 160.0
const CARD_SPACING: float = 12.0
const TABS_H: float = 60.0
const BUTTON_H: float = 64.0
const BUTTON_W: float = 200.0

var _tabs: HBoxContainer
var _content: VBoxContainer
var _header_label: Label
var _tab_buttons: Array[Button] = []
var _claim_button: Button
var _grid_containers: Array[GridContainer] = []
var _current_zone: int = 0
var _total_found: int = 0
var _total_all: int = 40

func _init() -> void:
	title_key = "index_title"
	super._init()

func _build_body() -> void:
	# Заголовок с общим процентом
	_header_label = UiStyle.outline_label("", 30, 5, UiStyle.COLOR_TEXT)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_header_label)

	# Вкладки зон
	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.add_theme_constant_override("separation", 8)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size = Vector2(0.0, TABS_H)
	body.add_child(_tabs)

	for zone_idx in ZoneData.count():
		var zone_data: Dictionary = ZoneData.ZONES[zone_idx]
		var tab_button: Button = WindowBase.make_button("", Vector2(0.0, TABS_H), 22)
		tab_button.name = "Tab_%d" % zone_idx
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.theme_type_variation = "Tab"
		tab_button.pressed.connect(_on_tab_pressed.bind(zone_idx))
		_tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)

	# Контейнер для контента вкладки
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content)

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
	_claim_button = WindowBase.make_button("", Vector2(BUTTON_W, BUTTON_H), 28)
	_claim_button.name = "ClaimButton"
	_claim_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_claim_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_claim_button.visible = false
	_claim_button.pressed.connect(_on_claim_pressed)
	body.add_child(_claim_button)

	# Подписка на изменения инвентаря (новые звери)
	if not Game.inventory_changed.is_connected(_on_game_changed):
		Game.inventory_changed.connect(_on_game_changed)

func refresh() -> void:
	_update_header()
	_update_tabs()
	_update_current_grid()
	_update_claim_button()

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
		btn.text = Loc.t("index_tab") % [zone_found, 8]
		# Подсветка текущей вкладки
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

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(CARD_W, CARD_H)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.13)
		style.set_corner_radius_all(14)
		style.set_border_width_all(2)
		if is_found:
			var rarity_color: Color = AnimalData.rarity_color(AnimalData.rarity_of(animal_id))
			style.border_color = rarity_color.darkened(0.3)
		else:
			style.border_color = Color(0.3, 0.3, 0.35)
		style.set_content_margin_all(10.0)
		card.add_theme_stylebox_override("panel", style)

		var card_vbox: VBoxContainer = VBoxContainer.new()
		card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vbox.add_theme_constant_override("separation", 6)
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(card_vbox)

		# Иконка / силуэт
		var icon: Control = _make_card_icon(animal_id, is_found)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_vbox.add_child(icon)

		# Название
		var name_label: Label = UiStyle.outline_label("", 22, 4, UiStyle.COLOR_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(name_label)

		if is_found:
			name_label.text = Loc.t("animal_" + animal_id)
			name_label.add_theme_color_override("font_color", AnimalData.rarity_color(AnimalData.rarity_of(animal_id)))
		else:
			name_label.text = "???"
			name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))

		# Редкость (только для найденных)
		if is_found:
			var rarity_label: Label = UiStyle.outline_label("", 18, 3, UiStyle.COLOR_TEXT)
			rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rarity_label.text = Loc.t("rarity_%d" % AnimalData.rarity_of(animal_id))
			rarity_label.add_theme_color_override("font_color", AnimalData.rarity_color(AnimalData.rarity_of(animal_id)))
			card_vbox.add_child(rarity_label)

		grid.add_child(card)

func _refresh_zone_grid(zone_idx: int) -> void:
	var grid: GridContainer = _grid_containers[zone_idx]
	var found: Array = Game._arr("found")

	for i in grid.get_child_count():
		var card: Control = grid.get_child(i)
		if not card is PanelContainer:
			continue
		var card_vbox: VBoxContainer = card.get_child(0)
		if card_vbox.get_child_count() < 2:
			continue
		var icon: Control = card_vbox.get_child(0)
		var name_label: Label = card_vbox.get_child(1)
		# Ранг определяется по порядку в сетке
		var rank: int = i + 1
		var animal: Dictionary = AnimalData.at_rank(zone_idx, rank)
		if animal.is_empty():
			continue
		var animal_id: String = String(animal["id"])
		var is_found: bool = found.has(animal_id)

		if is_found:
			name_label.text = Loc.t("animal_" + animal_id)
			name_label.add_theme_color_override("font_color", AnimalData.rarity_color(AnimalData.rarity_of(animal_id)))
			# Обновляем иконку
			icon.queue_free()
			var new_icon: Control = _make_card_icon(animal_id, true)
			new_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_vbox.add_child(new_icon)
			new_icon.move_child(new_icon, 0)
			# Редкость
			if card_vbox.get_child_count() >= 3:
				var rarity_label: Label = card_vbox.get_child(2)
				rarity_label.text = Loc.t("rarity_%d" % AnimalData.rarity_of(animal_id))
				rarity_label.add_theme_color_override("font_color", AnimalData.rarity_color(AnimalData.rarity_of(animal_id)))
		else:
			name_label.text = "???"
			name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			icon.queue_free()
			var new_icon: Control = _make_card_icon(animal_id, false)
			new_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_vbox.add_child(new_icon)
			new_icon.move_child(new_icon, 0)
			# Убираем редкость если была
			if card_vbox.get_child_count() >= 3:
				var rarity_label: Label = card_vbox.get_child(2)
				rarity_label.queue_free()

		# Обновляем рамку карточки
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.13)
		style.set_corner_radius_all(14)
		style.set_border_width_all(2)
		if is_found:
			var rarity_color: Color = AnimalData.rarity_color(AnimalData.rarity_of(animal_id))
			style.border_color = rarity_color.darkened(0.3)
		else:
			style.border_color = Color(0.3, 0.3, 0.35)
		style.set_content_margin_all(10.0)
		card.add_theme_stylebox_override("panel", style)

func _make_card_icon(animal_id: String, is_found: bool) -> Control:
	var icon_size: float = 70.0
	if is_found:
		# Цветной квадрат с первой буквой (как в AnimalRow)
		var icon := ColorRect.new()
		var rarity_color: Color = AnimalData.rarity_color(AnimalData.rarity_of(animal_id))
		icon.color = rarity_color.darkened(0.55)
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var animal_name: String = Loc.t("animal_" + animal_id)
		var letter: Label = UiStyle.outline_label(animal_name.left(1).to_upper(), 36, 5, rarity_color)
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(letter)
		return icon
	else:
		# Тёмный силуэт
		var icon := ColorRect.new()
		icon.color = Color(0.18, 0.18, 0.2)
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var qmark: Label = UiStyle.outline_label("???", 28, 4, Color(0.5, 0.5, 0.55))
		qmark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		qmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(qmark)
		return icon

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