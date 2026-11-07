class_name PremiumWindow
extends WindowBase
## Магазин за яны (T24a, справочник R9): горизонтальная прокрутка карточек товаров из каталога SDK.
## Карточка: картинка товара (из SDK), название, описание, цена строкой IProduct.price и иконка валюты из SDK,
## кнопка «Купить» или «Куплено» (у постоянных). Своих «рублей» и самодельных иконок валюты нет:
## нет иконки в каталоге, показываем одну строку цены.
## Нет каталога (оффлайн, редактор без заглушки, ошибка SDK) — вместо карточек «Магазин недоступен».
## Названия и описания берутся из каталога; если там пусто, подставляются запасные тексты из Loc.

const CARD_W: float = 250.0
const IMAGE_SIZE: float = 110.0
const CURRENCY_ICON_SIZE: float = 32.0
const BUTTON_H: float = 64.0
const CARD_PAD: int = 12
const COLOR_CARD: Color = Color("#3A3A44")
const COLOR_CARD_BORDER: Color = Color("#6A6A78")
const COLOR_OWNED_BORDER: Color = Color("#FFC83D")
const COLOR_IMAGE_BG: Color = Color("#2A2A32")
const COLOR_SUB: Color = Color("#B8B8C4")
const COLOR_PRICE: Color = Color("#FFC83D")

var _status: Label
var _scroll: ScrollContainer
var _row: HBoxContainer
var _catalog: Array[Dictionary] = []     # товары из каталога SDK, которые знает игра (ShopData)
var _cards: Array[Dictionary] = []       # на каждый товар: id, button
var _textures: Dictionary = {}           # адрес картинки -> Texture2D
var _loading: bool = false
var _busy: bool = false                  # идёт покупка: кнопки заблокированы


func _init() -> void:
	title_key = "shop"


func _build_body() -> void:
	_status = UiStyle.outline_label("", 32, 5, UiStyle.COLOR_TEXT)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_status)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.visible = false
	body.add_child(_scroll)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", 14)
	_scroll.add_child(_row)


## Каталог запрашивается при первом открытии (и повторно, если он был пуст); дальше карточки перестраиваются из него.
func refresh() -> void:
	if _row == null or _loading:
		return
	if _catalog.is_empty():
		_load_catalog()
	else:
		_rebuild_cards()


func _load_catalog() -> void:
	_loading = true
	_show_status(Loc.t("shop_loading"))
	var raw: Array = await Ya.get_catalog()
	_loading = false
	_catalog = _known_products(raw)
	_rebuild_cards()


# Оставляет только товары, которые игра умеет выдавать (id из R9), в порядке справочника.
func _known_products(raw: Array) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for item in raw:
		if item is Dictionary and ShopData.is_known(str(item.get("id", ""))):
			list.append(item)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ShopData.order_of(str(a["id"])) < ShopData.order_of(str(b["id"])))
	return list


func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = true
	_scroll.visible = false


func _rebuild_cards() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	if _catalog.is_empty():
		_show_status(Loc.t("shop_unavailable"))
		return
	_status.visible = false
	_scroll.visible = true
	for entry in _catalog:
		_build_card(entry)
	_update_states()


func _build_card(entry: Dictionary) -> void:
	var product_id: String = str(entry["id"])
	var product: Dictionary = ShopData.by_id(product_id)

	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = COLOR_CARD
	frame.set_corner_radius_all(16)
	frame.set_border_width_all(3)
	frame.border_color = COLOR_CARD_BORDER
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Card_" + product_id
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

	# Картинка товара из SDK (если адрес есть и загрузилась), на тёмной плашке.
	var image_bg: StyleBoxFlat = StyleBoxFlat.new()
	image_bg.bg_color = COLOR_IMAGE_BG
	image_bg.set_corner_radius_all(12)
	var image_box: Panel = Panel.new()
	image_box.custom_minimum_size = Vector2(IMAGE_SIZE, IMAGE_SIZE)
	image_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image_box.add_theme_stylebox_override("panel", image_bg)
	column.add_child(image_box)
	var image_rect: TextureRect = TextureRect.new()
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_box.add_child(image_rect)
	_fetch_texture(str(entry.get("image", "")), image_rect)

	var title_text: String = str(entry.get("title", ""))
	if title_text == "":
		title_text = Loc.t(str(product["name_key"]))
	var title_label: Label = UiStyle.outline_label(title_text, 28, 5, UiStyle.COLOR_TEXT)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)

	var desc_text: String = str(entry.get("description", ""))
	if desc_text == "":
		desc_text = Loc.t(str(product["desc_key"]))
	var desc_label: Label = UiStyle.outline_label(desc_text, 20, 4, COLOR_SUB)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.custom_minimum_size = Vector2(0.0, 96.0)
	column.add_child(desc_label)

	# Цена: строка IProduct.price как есть и иконка валюты из SDK.
	var price_row: HBoxContainer = HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	column.add_child(price_row)
	price_row.add_child(UiStyle.outline_label(str(entry.get("price", "")), 30, 5, COLOR_PRICE))
	var currency_rect: TextureRect = TextureRect.new()
	currency_rect.custom_minimum_size = Vector2(CURRENCY_ICON_SIZE, CURRENCY_ICON_SIZE)
	currency_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	currency_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	currency_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	currency_rect.visible = false
	price_row.add_child(currency_rect)
	_fetch_texture(str(entry.get("currency_icon", "")), currency_rect)

	var button: Button = make_button("", Vector2(0.0, BUTTON_H))
	button.pressed.connect(_on_buy.bind(product_id))
	column.add_child(button)

	_cards.append({"id": product_id, "button": button, "frame": frame})


# Кнопки и рамки: «Куплено» у уже включённых постоянных товаров, на время покупки всё заблокировано.
func _update_states() -> void:
	for card in _cards:
		var owned: bool = ShopLogic.is_owned(Save.data, str(card["id"]))
		var button: Button = card["button"] as Button
		var frame: StyleBoxFlat = card["frame"] as StyleBoxFlat
		button.text = Loc.t("shop_owned") if owned else Loc.t("shop_buy")
		button.disabled = owned or _busy
		frame.border_color = COLOR_OWNED_BORDER if owned else COLOR_CARD_BORDER
		frame.set_border_width_all(5 if owned else 3)


func _on_buy(product_id: String) -> void:
	if _busy:
		return
	_busy = true
	_update_states()
	show_toast(Loc.t("shop_processing"))
	var result: Dictionary = await PurchaseFlow.buy(product_id)
	_busy = false
	show_toast(Loc.t("shop_bought_toast") if bool(result["ok"]) else Loc.t("shop_failed_toast"))
	if is_inside_tree():
		_update_states()


# Загружает картинку по адресу из SDK и кладёт в rect. Если не вышло (нет адреса, сеть, формат), rect остаётся пустым.
func _fetch_texture(url: String, rect: TextureRect) -> void:
	if url == "":
		return
	if _textures.has(url):
		rect.texture = _textures[url] as Texture2D
		rect.visible = true
		return
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	if request.request(url) != OK:
		request.queue_free()
		return
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		return
	var texture: Texture2D = _texture_from_bytes(response[3] as PackedByteArray)
	if texture == null:
		return
	_textures[url] = texture
	if is_instance_valid(rect):
		rect.texture = texture
		rect.visible = true


# Картинки каталога приходят как PNG, JPEG или WebP; формат определяем по первым байтам.
static func _texture_from_bytes(bytes: PackedByteArray) -> Texture2D:
	if bytes.size() < 8:
		return null
	var image: Image = Image.new()
	var status: int = ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		status = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		status = image.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x52 and bytes[1] == 0x49:
		status = image.load_webp_from_buffer(bytes)
	if status != OK:
		return null
	return ImageTexture.create_from_image(image)
