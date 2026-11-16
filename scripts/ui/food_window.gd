class_name FoodWindow
extends WindowBase
## Окно палатки еды (T15, T38, справочники R3, R4, R6) в стиле Роблокса: горизонтальный ряд карточек.
## Карточка сверху вниз: название, редкость, иконка на цветном фоне редкости, короткая польза,
## «Уровень N» (за кулисами работает прежняя удача), кнопка: цена / «Выбрать» / «Экипировано».
## Закрытая еда: иконка затемнена, по центру замок, «Открой биом» и значок биома.

const CARD_W: float = 196.0
const ICON_SIZE: float = 118.0
const BUTTON_H: float = 60.0
const CARD_PAD: int = 10
const LOCKED_DIM: Color = Color(0.18, 0.18, 0.22, 1.0)
const COLOR_BORDER: Color = Color.BLACK
const COLOR_SELECTED_BORDER: Color = Color("#7CFF4D")
const COLOR_LEVEL_PLATE: Color = Color(0.0, 0.0, 0.0, 0.45)
const COLOR_BUY: Color = Color("#FF9A1F")
const COLOR_EQUIP_OK: Color = Color("#2FC41F")
const COLOR_EQUIPPED: Color = Color("#5A5A66")
const COLOR_LOCKED_BTN: Color = Color("#33333D")
## Фон карточки по редкости 0-4: обычный, необычный, редкий, эпический, легендарный.
const RARITY_BG: Array[Color] = [
	Color("#7D8794"), Color("#46B84A"), Color("#3F86F0"), Color("#9B49DC"), Color("#F2A71B"),
]

var _scroll: ScrollContainer
var _row: HBoxContainer
var _cards: Array[Dictionary] = []


func _init() -> void:
	title_key = "food_title"
	panel_w_k = 0.7
	panel_w_max = 900.0
	panel_h_k = 0.72
	panel_h_max = 520.0


func _build_body() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", 10)
	_scroll.add_child(_row)

	for tier in FoodData.count():
		_build_card(tier)

	if not Game.food_changed.is_connected(_on_game_changed):
		Game.food_changed.connect(_on_game_changed)
	if not Game.money_changed.is_connected(_on_money_changed):
		Game.money_changed.connect(_on_money_changed)


## Обновляет карточки на месте и прокручивает к той, что можно купить следующей.
func refresh() -> void:
	if _cards.is_empty():
		return
	_update_cards()
	_focus_current()


func _build_card(tier: int) -> void:
	var food: Dictionary = FoodData.FOODS[tier]
	var rarity: int = FoodData.rarity(tier)

	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = RARITY_BG[rarity]
	frame.set_corner_radius_all(16)
	frame.set_border_width_all(4)
	frame.border_color = COLOR_BORDER

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Card%d" % tier
	panel.custom_minimum_size = Vector2(CARD_W, 0.0)
	panel.add_theme_stylebox_override("panel", frame)
	_row.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, CARD_PAD)
	panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var name_label: Label = UiStyle.outline_label("", 26, 5, UiStyle.COLOR_TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(CARD_W - CARD_PAD * 2, 64.0)   # две строки без скачков высоты
	column.add_child(name_label)

	var rarity_label: Label = UiStyle.outline_label(Loc.t("rarity_%d" % rarity), 18, 4, UiStyle.COLOR_TEXT)
	column.add_child(rarity_label)

	# Иконка еды; поверх неё для закрытой еды замок и условие открытия.
	var icon_box: Control = Control.new()
	icon_box.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_box)

	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.name = "FoodTexture"
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon_path: String = UiStyle.ICON_DIR + "food_%s.png" % String(food["id"])
	if ResourceLoader.exists(icon_path):
		tex_rect.texture = load(icon_path) as Texture2D
	icon_box.add_child(tex_rect)

	var lock_box: VBoxContainer = _build_lock_overlay(int(food["zone"]))
	icon_box.add_child(lock_box)

	var benefit_label: Label = UiStyle.outline_label("", 16, 3, Color(1.0, 1.0, 1.0, 0.92))
	benefit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	benefit_label.custom_minimum_size = Vector2(CARD_W - CARD_PAD * 2, 42.0)
	column.add_child(benefit_label)

	var level_plate: PanelContainer = PanelContainer.new()
	var plate_style: StyleBoxFlat = StyleBoxFlat.new()
	plate_style.bg_color = COLOR_LEVEL_PLATE
	plate_style.set_corner_radius_all(8)
	plate_style.set_border_width_all(2)
	plate_style.border_color = Color.BLACK
	level_plate.add_theme_stylebox_override("panel", plate_style)
	column.add_child(level_plate)
	var level_label: Label = UiStyle.outline_label(Loc.t("food_level") % FoodData.level(tier), 22, 4, UiStyle.COLOR_TEXT)
	level_plate.add_child(level_label)

	var button: Button = make_button("", Vector2(0.0, BUTTON_H), 26)
	button.pressed.connect(_on_button.bind(tier))
	column.add_child(button)

	_cards.append({
		"frame": frame,
		"tex_rect": tex_rect,
		"lock_box": lock_box,
		"name": name_label,
		"rarity": rarity_label,
		"benefit": benefit_label,
		"level": level_label,
		"button": button,
		"panel": panel,
	})


# Замок по центру иконки, «Открой биом» и значок биома. Размытие шейдером запрещено правилами 3D/веба,
# поэтому закрытая иконка просто затемнена.
func _build_lock_overlay(zone_idx: int) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "LockOverlay"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false

	var lock_icon: TextureRect = TextureRect.new()
	lock_icon.custom_minimum_size = Vector2(26.0, 26.0)
	lock_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lock_path: String = UiStyle.ICON_DIR + "lock.png"
	lock_icon.texture = load(lock_path) as Texture2D if ResourceLoader.exists(lock_path) else _create_lock_texture()
	box.add_child(lock_icon)

	var hint: Label = UiStyle.outline_label(Loc.t("food_unlock_hint"), 14, 3, UiStyle.COLOR_TEXT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)

	var zone_icon: TextureRect = TextureRect.new()
	zone_icon.custom_minimum_size = Vector2(34.0, 34.0)
	zone_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	zone_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zone_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	zone_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zone_path: String = UiStyle.ICON_DIR + "zone_%s.png" % String(ZoneData.ZONES[zone_idx]["id"])
	if ResourceLoader.exists(zone_path):
		zone_icon.texture = load(zone_path) as Texture2D
	box.add_child(zone_icon)

	var zone_name: Label = UiStyle.outline_label(Loc.t(String(ZoneData.ZONES[zone_idx]["name_key"])), 15, 3, UiStyle.COLOR_TEXT)
	zone_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(zone_name)
	return box


func _create_lock_texture() -> Texture2D:
	# Создаём простую текстуру замка через код (Image)
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var lock_color: Color = Color.WHITE
	var bg_color: Color = Color(0, 0, 0, 0.6)
	
	# Рисуем фон под замок (круг)
	for x in range(64):
		for y in range(64):
			var dx: float = x - 31.5
			var dy: float = y - 31.5
			if dx * dx + dy * dy <= 28.0 * 28.0:
				img.set_pixel(x, y, bg_color)
	
	# Рисуем замок (упрощённый: прямоугольник + дуга)
	# Корпус замка
	for x in range(18, 46):
		for y in range(28, 50):
			img.set_pixel(x, y, lock_color)
	# Дуга замка
	for x in range(14, 50):
		for y in range(16, 30):
			var cx: float = 32.0
			var cy: float = 28.0
			var dx: float = x - cx
			var dy: float = y - cy
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist >= 14.0 and dist <= 18.0 and dy <= 0:
				img.set_pixel(x, y, lock_color)
	# Дырочка в замке
	for x in range(26, 38):
		for y in range(34, 42):
			img.set_pixel(x, y, bg_color)
	
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex


func _update_cards() -> void:
	var selected: int = Game.food_selected()
	var money: float = Game.money()
	for tier in _cards.size():
		var food: Dictionary = FoodData.FOODS[tier]
		var card: Dictionary = _cards[tier]
		var owned: bool = Game.is_food_owned(tier)
		var available: bool = Game.is_food_available(tier)
		var price: float = FoodData.price(tier)
		var button: Button = card["button"] as Button
		var tex_rect: TextureRect = card["tex_rect"] as TextureRect

		(card["name"] as Label).text = Loc.t(String(food["name_key"]))
		(card["rarity"] as Label).text = Loc.t("rarity_%d" % FoodData.rarity(tier))
		(card["benefit"] as Label).text = _get_benefit_text(int(food["aim_rank"]))
		(card["level"] as Label).text = Loc.t("food_level") % FoodData.level(tier)
		(card["lock_box"] as Control).visible = not available
		tex_rect.modulate = Color.WHITE if available else LOCKED_DIM

		var is_selected: bool = available and owned and tier == selected
		if not available:
			_style_button(button, COLOR_LOCKED_BTN)
			button.text = NumFmt.money(price)
			button.disabled = true
		elif is_selected:
			_style_button(button, COLOR_EQUIPPED)
			button.text = Loc.t("food_equipped")
			button.disabled = true
		elif owned:
			_style_button(button, COLOR_EQUIP_OK)
			button.text = Loc.t("food_select")
			button.disabled = false
		else:
			_style_button(button, COLOR_BUY if money >= price else COLOR_BUY.darkened(0.45))
			button.text = Loc.t("food_free") if price <= 0.0 else NumFmt.money(price)
			button.disabled = false   # без денег нажатие покажет «Не хватает денег»

		var frame: StyleBoxFlat = card["frame"] as StyleBoxFlat
		frame.border_color = COLOR_SELECTED_BORDER if is_selected else COLOR_BORDER
		frame.set_border_width_all(6 if is_selected else 4)


# Единый вид кнопки карточки: цвет заливки, чёрная обводка, белый текст с контуром.
func _style_button(button: Button, color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_border_width_all(3)
	style.border_color = Color.BLACK
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.75))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 5)


func _focus_current() -> void:
	var target_tier: int = _cards.size() - 1
	for tier in _cards.size():
		if Game.is_food_available(tier) and not Game.is_food_owned(tier):
			target_tier = tier
			break
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.ensure_control_visible(_cards[target_tier]["panel"] as Control)


func _on_button(tier: int) -> void:
	var food_name: String = Loc.t(String(FoodData.FOODS[tier]["name_key"]))
	if Game.is_food_owned(tier):
		Game.select_food(tier)
		show_toast(Loc.t("food_selected_toast") % food_name)
	elif Game.is_food_available(tier):
		if Game.buy_food(tier):
			show_toast(Loc.t("food_bought_toast") % food_name)
		else:
			show_toast(Loc.t("food_no_money"))
	else:
		show_toast(Loc.t("food_zone_locked"))


func _on_game_changed() -> void:
	if visible:
		_update_cards()


func _on_money_changed(_value: float) -> void:
	if visible:
		_update_cards()

func _get_benefit_text(aim_rank: int) -> String:
	match aim_rank:
		2:
			return Loc.t("food_benefit_2")
		5:
			return Loc.t("food_benefit_5")
		8:
			return Loc.t("food_benefit_8")
		_:
			return ""
