class_name FoodWindow
extends WindowBase
## Окно палатки еды (T15, T38, справочники R3, R4, R6): горизонтальная прокрутка карточек еды.
## Карточка: иконка (файл assets/ui/icons/food_<id>.png, а пока его нет цветной кружок), название,
## «Зона N», цена и кнопка «Купить», «Выбрать» или «Выбрано»; внизу «Целится в: ранг K зоны Z».
## T38: можно купить любую доступную еду (зона разблокирована), порядок свободный.
## Доступная еда видна в цвете, недоступная (закрытая зона) — силуэты с названием «???».
## Карточки строятся один раз, потом обновляются на месте, поэтому прокрутка не прыгает, когда меняются деньги.

const CARD_W: float = 220.0
const ICON_SIZE: float = 120.0
const BUTTON_H: float = 64.0
const CARD_PAD: int = 12
const COLOR_SILHOUETTE: Color = Color("#1E1E24")
const COLOR_CARD: Color = Color("#3A3A44")
const COLOR_CARD_BORDER: Color = Color("#6A6A78")
const COLOR_SELECTED_BORDER: Color = Color("#FFC83D")
const COLOR_PRICE_BAD: Color = Color("#FF5A5A")
const COLOR_SUB: Color = Color("#B8B8C4")

var _scroll: ScrollContainer
var _row: HBoxContainer
var _cards: Array[Dictionary] = []       # на каждую еду: frame, icon, tex, name, zone, price, button, aims, panel


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
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	# Иконка: цветной кружок-заглушка, поверх него картинка, если файл есть.
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = Color.html(String(food["color"]))
	icon_style.set_corner_radius_all(int(ICON_SIZE / 2.0))
	var icon: Panel = Panel.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.add_theme_stylebox_override("panel", icon_style)
	column.add_child(icon)
	var tex_rect: TextureRect = null
	var icon_path: String = UiStyle.ICON_DIR + "food_%s.png" % String(food["id"])
	if ResourceLoader.exists(icon_path):
		tex_rect = TextureRect.new()
		tex_rect.texture = load(icon_path) as Texture2D
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.add_child(tex_rect)

	var name_label: Label = UiStyle.outline_label("", 30, 5, UiStyle.COLOR_TEXT)
	column.add_child(name_label)
	var zone_label: Label = UiStyle.outline_label(Loc.t("food_zone") % (int(food["zone"]) + 1), 22, 4, COLOR_SUB)
	column.add_child(zone_label)
	var price_label: Label = UiStyle.outline_label("", 28, 5, UiStyle.COLOR_MONEY)
	column.add_child(price_label)

	var button: Button = make_button("", Vector2(0.0, BUTTON_H))
	button.pressed.connect(_on_button.bind(tier))
	column.add_child(button)

	var aims_label: Label = UiStyle.outline_label("", 20, 4, COLOR_SUB)
	aims_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aims_label.custom_minimum_size = Vector2(0.0, 52.0)
	column.add_child(aims_label)

	_cards.append({
		"frame": frame, "icon": icon_style, "tex": tex_rect, "name": name_label, "zone": zone_label,
		"price": price_label, "button": button, "aims": aims_label, "panel": panel,
	})


# Состояние каждой карточки: куплена, доступна для покупки или недоступна (зона закрыта).
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

		# Иконка и название: цветные если доступна, силуэт если зона закрыта
		(card["icon"] as StyleBoxFlat).bg_color = Color.html(String(food["color"])) if available else COLOR_SILHOUETTE
		if card["tex"] != null:
			(card["tex"] as TextureRect).modulate = Color.WHITE if available else Color.BLACK
		(card["name"] as Label).text = Loc.t(String(food["name_key"])) if available else Loc.t("food_unknown")
		(card["zone"] as Label).text = Loc.t("food_zone") % (int(food["zone"]) + 1)
		(card["aims"] as Label).text = Loc.t("food_aims") % [int(food["aim_rank"]), int(food["zone"]) + 1]

		var price_label: Label = card["price"] as Label
		if owned:
			price_label.text = ""
		else:
			price_label.text = NumFmt.money(price)
			# Цена зелёная если хватает денег, красная если нет (только для доступной еды)
			if available:
				price_label.add_theme_color_override("font_color", UiStyle.COLOR_MONEY if money >= price else COLOR_PRICE_BAD)
			else:
				price_label.add_theme_color_override("font_color", COLOR_SUB)

		var button: Button = card["button"] as Button
		if owned and tier == selected:
			button.text = Loc.t("food_selected")
			button.disabled = true
		elif owned:
			button.text = Loc.t("food_select")
			button.disabled = false
		elif available:
			button.text = Loc.t("food_buy")
			button.disabled = not can_buy
		else:
			button.text = Loc.t("food_buy")
			button.disabled = true

		var frame: StyleBoxFlat = card["frame"] as StyleBoxFlat
		var is_selected: bool = owned and tier == selected
		frame.border_color = COLOR_SELECTED_BORDER if is_selected else COLOR_CARD_BORDER
		frame.set_border_width_all(5 if is_selected else 3)


# Прокручивает к первой доступной некупленной еде (или к последней, если всё куплено).
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
