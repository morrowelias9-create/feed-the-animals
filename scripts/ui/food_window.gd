class_name FoodWindow
extends WindowBase
## Окно палатки еды (T15, T38, справочники R3, R4, R6): горизонтальная прокрутка карточек еды.
## Карточка: иконка еды (настоящая текстура), название, польза, удача, цена, кнопка.
## Заблокированная еда: настоящее изображение еды с лёгким затемнением,
## небольшой замок по центру, условие открытия "Открой биом «...»", кнопка "ЗАКРЫТО".

const CARD_W: float = 220.0
const ICON_SIZE: float = 120.0
const BUTTON_H: float = 64.0
const CARD_PAD: int = 12
const COLOR_CARD: Color = Color("#3A3A44")
const COLOR_CARD_BORDER: Color = Color("#6A6A78")
const COLOR_SELECTED_BORDER: Color = Color("#FFC83D")
const COLOR_PRICE_BAD: Color = Color("#FF5A5A")
const COLOR_SUB: Color = Color("#B8B8C4")
const CONTENT_MIN_H: float = 240.0  # минимальная высота контентной области для равных карточек
const LOCKED_DIM: Color = Color(0.5, 0.5, 0.5, 0.7)  # затемнение для заблокированной еды

var _scroll: ScrollContainer
var _row: HBoxContainer
var _cards: Array[Dictionary] = []


func _init() -> void:
	title_key = "food_title"


func _build_body() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", 14)
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
	
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = COLOR_CARD
	frame.set_corner_radius_all(16)
	frame.set_border_width_all(3)
	frame.border_color = COLOR_CARD_BORDER

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
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	# --- Иконка еды (настоящая текстура) ---
	# Используем PanelContainer с фиксированным размером для гарантированной области изображения
	var icon_panel: PanelContainer = PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_panel_style.bg_color = Color(0, 0, 0, 0)  # прозрачный фон
	icon_panel_style.set_corner_radius_all(0)
	icon_panel_style.set_border_width_all(0)
	icon_panel.add_theme_stylebox_override("panel", icon_panel_style)
	column.add_child(icon_panel)

	# Текстура еды (если есть файл)
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.name = "FoodTexture"
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon_path: String = UiStyle.ICON_DIR + "food_%s.png" % String(food["id"])
	if ResourceLoader.exists(icon_path):
		tex_rect.texture = load(icon_path) as Texture2D
	else:
		tex_rect.visible = false  # скрываем, если текстуры нет
	icon_panel.add_child(tex_rect)

	# Замок (невидимый по умолчанию) — поверх текстуры еды
	var lock_icon: TextureRect = TextureRect.new()
	lock_icon.name = "LockIcon"
	lock_icon.custom_minimum_size = Vector2(36.0, 36.0)
	lock_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Создаём замок программно или загружаем иконку
	var lock_path: String = UiStyle.ICON_DIR + "lock.png"
	if ResourceLoader.exists(lock_path):
		lock_icon.texture = load(lock_path) as Texture2D
	else:
		lock_icon.texture = _create_lock_texture()
	lock_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lock_icon.anchor_left = 0.5
	lock_icon.anchor_top = 0.5
	lock_icon.anchor_right = 0.5
	lock_icon.anchor_bottom = 0.5
	lock_icon.offset_left = -18.0
	lock_icon.offset_top = -18.0
	lock_icon.offset_right = 18.0
	lock_icon.offset_bottom = 18.0
	lock_icon.visible = false
	icon_panel.add_child(lock_icon)

	# Название еды
	var name_label: Label = UiStyle.outline_label("", 30, 5, UiStyle.COLOR_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(CARD_W - CARD_PAD * 2, 0.0)
	column.add_child(name_label)

	# Контейнер для текстового контента с фиксированной минимальной высотой
	# Это гарантирует одинаковую высоту карточек независимо от длины описания
	var content_container: VBoxContainer = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 4)
	content_container.custom_minimum_size = Vector2(0.0, CONTENT_MIN_H)
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content_container)

	# Польза еды (описание ранга)
	var benefit_label: Label = UiStyle.outline_label("", 20, 4, COLOR_SUB)
	benefit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	benefit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	benefit_label.custom_minimum_size = Vector2(CARD_W - CARD_PAD * 2, 0.0)
	content_container.add_child(benefit_label)

	# Удача
	var luck_label: Label = UiStyle.outline_label("", 20, 4, COLOR_SUB)
	luck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(luck_label)

	# Условие открытия (для заблокированной еды)
	var unlock_label: Label = UiStyle.outline_label("", 20, 4, COLOR_SUB)
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_label.custom_minimum_size = Vector2(CARD_W - CARD_PAD * 2, 0.0)
	unlock_label.visible = false
	content_container.add_child(unlock_label)

	# Цена
	var price_label: Label = UiStyle.outline_label("", 28, 5, UiStyle.COLOR_MONEY)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(price_label)

	# Кнопка
	var button: Button = make_button("", Vector2(0.0, BUTTON_H))
	button.pressed.connect(_on_button.bind(tier))
	column.add_child(button)

	_cards.append({
		"frame": frame,
		"tex_rect": tex_rect,
		"lock_icon": lock_icon,
		"name": name_label,
		"benefit": benefit_label,
		"luck": luck_label,
		"unlock": unlock_label,
		"price": price_label,
		"button": button,
		"panel": panel,
		"content_container": content_container,
	})


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
		var can_buy: bool = Game.can_buy_food(tier)
		var price: float = FoodData.price(tier)
		var zone_idx: int = int(food["zone"])
		var zone_name: String = Loc.t(String(ZoneData.ZONES[zone_idx]["name_key"]))
		var aim_rank: int = int(food["aim_rank"])
		var luck_val: float = FoodData.luck(tier)

		# Название еды — всегда видно
		(card["name"] as Label).text = Loc.t(String(food["name_key"]))

		# Польза еды (описание ранга)
		var benefit_label: Label = card["benefit"] as Label
		benefit_label.text = _get_benefit_text(aim_rank)
		benefit_label.visible = true

		# Удача
		var luck_label: Label = card["luck"] as Label
		luck_label.text = Loc.t("food_luck") % str(luck_val)
		luck_label.visible = true

		# Условие открытия / кнопка / изображение
		var unlock_label: Label = card["unlock"] as Label
		var button: Button = card["button"] as Button
		var tex_rect: TextureRect = card["tex_rect"] as TextureRect
		var lock_icon: TextureRect = card["lock_icon"] as TextureRect
		var price_label: Label = card["price"] as Label

		if available:
			# Доступная еда: полноцветная, без замка
			tex_rect.modulate = Color.WHITE
			lock_icon.visible = false
			unlock_label.visible = false
			unlock_label.text = ""

			if owned and tier == selected:
				button.text = Loc.t("food_selected")
				button.disabled = true
			elif owned:
				button.text = Loc.t("food_select")
				button.disabled = false
			else:
				button.text = Loc.t("food_buy")
				button.disabled = not can_buy
			
			# Цена
			if owned:
				price_label.text = ""
			else:
				price_label.text = NumFmt.money(price)
				price_label.add_theme_color_override("font_color", UiStyle.COLOR_MONEY if money >= price else COLOR_PRICE_BAD)
		else:
			# Заблокированная еда: лёгкое затемнение, замок
			tex_rect.modulate = LOCKED_DIM
			lock_icon.visible = true
			
			# Текст условия открытия (ТОЛЬКО здесь, не на кнопке)
			unlock_label.text = Loc.t("food_unlock_hint") % zone_name
			unlock_label.visible = true
			
			# Кнопка — просто "ЗАКРЫТО"
			button.text = Loc.t("food_locked_button")
			button.disabled = true
			# Приглушённый стиль кнопки
			var disabled_style: StyleBoxFlat = StyleBoxFlat.new()
			disabled_style.bg_color = Color("#2A2A34")
			disabled_style.set_corner_radius_all(12)
			disabled_style.border_color = Color("#555566")
			disabled_style.set_border_width_all(2)
			button.add_theme_stylebox_override("disabled", disabled_style)
			button.add_theme_color_override("font_color", Color("#888899"))
			
			# Цена (видна, но приглушённая)
			price_label.text = NumFmt.money(price)
			price_label.add_theme_color_override("font_color", COLOR_SUB)

		# Рамка выбранной карточки
		var frame: StyleBoxFlat = card["frame"] as StyleBoxFlat
		var is_selected: bool = owned and tier == selected
		frame.border_color = COLOR_SELECTED_BORDER if is_selected else COLOR_CARD_BORDER
		frame.set_border_width_all(5 if is_selected else 3)


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