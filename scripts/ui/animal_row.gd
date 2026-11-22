class_name AnimalRow
extends PanelContainer
## Строка зверя в окнах «Животные» (T12) и «Лавка» (T12a) в стиле Roblox: слева плитка цвета редкости с иконкой,
## по центру название (цветом редкости), мутация и размер, доход, справа столбиком синяя «Взять» и красная «Продать $N».
## Иконка берётся из assets/ui/icons/animal_<id>.png (прозрачный фон), без неё показывается первая буква названия.

signal take_pressed(uid: int)
signal sell_pressed(uid: int)

const ROW_H: float = 112.0
const ICON_SIZE: float = 92.0
const BUTTON_H: float = 42.0
const SELL_ONLY_H: float = 56.0         # если «Взять» нет, «Продать» делаем крупнее
const TAKE_W: float = 130.0
const SELL_W: float = 200.0
const INCOME_W: float = 150.0
const NAME_FONT_SIZE: int = 30
const SUB_FONT_SIZE: int = 20
const INCOME_FONT_SIZE: int = 26
const BUTTON_FONT_SIZE: int = 24
const COLOR_SUB: Color = Color(0.78, 0.78, 0.8)
const COLOR_PLACED: Color = Color("#8FE39A")
const ROW_BG: Color = Color("#101018")
const ROW_BORDER: Color = Color(1.0, 1.0, 1.0)

var uid: int = -1


## Порядок для списков: сначала самые доходные, при равенстве меньший uid первым.
static func by_income_desc(x: Dictionary, y: Dictionary) -> bool:
	var ix: float = Economy.income(String(x["animal_id"]), int(x.get("variant", 0)), int(x.get("size", 0)))
	var iy: float = Economy.income(String(y["animal_id"]), int(y.get("variant", 0)), int(y.get("size", 0)))
	if ix != iy:
		return ix > iy
	return int(x["uid"]) < int(y["uid"])


## Готовая строка для словаря зверя {uid, animal_id, variant, size, placed}.
static func create(animal: Dictionary, with_take: bool, with_income: bool) -> AnimalRow:
	var row := AnimalRow.new()
	row._build(animal, with_take, with_income)
	return row


func _build(animal: Dictionary, with_take: bool, with_income: bool) -> void:
	uid = int(animal.get("uid", -1))
	var id: String = String(animal.get("animal_id", ""))
	var variant: int = VariantData.clamp_variant(int(animal.get("variant", 0)))
	var size_step: int = SizeData.clamp_size(int(animal.get("size", 0)))
	var placed: bool = int(animal.get("placed", 0)) == 1
	var rarity_color: Color = AnimalData.rarity_color(AnimalData.rarity_of(id))
	var animal_name: String = Loc.t("animal_" + id)

	custom_minimum_size = Vector2(0.0, ROW_H)
	mouse_filter = Control.MOUSE_FILTER_PASS   # чтобы перетаскивание по строке прокручивало список
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG
	style.set_corner_radius_all(18)
	style.set_border_width_all(3)
	# Белая рамка, как в Roblox; у зверя в загоне рамка зеленоватая.
	style.border_color = COLOR_PLACED if placed else ROW_BORDER
	style.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(row)

	row.add_child(_make_icon(animal_name, rarity_color, id))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(info)
	var name_label: Label = UiStyle.outline_label(animal_name, NAME_FONT_SIZE, 6, rarity_color.lightened(0.2))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)
	var sub: HBoxContainer = _make_sub_line(variant, size_step, placed)
	if sub.get_child_count() > 0:
		info.add_child(sub)
	else:
		sub.free()
	if with_income:
		var income: float = Economy.income(id, variant, size_step)
		var income_label: Label = UiStyle.outline_label(NumFmt.money(income) + "/s", INCOME_FONT_SIZE, 5, UiStyle.COLOR_MONEY)
		income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		income_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(income_label)

	# Кнопки столбиком справа: «Взять» сверху, «Продать» снизу.
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 8)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(buttons)
	if with_take:
		var take_button: Button = WindowBase.make_button(Loc.t("animal_take"), Vector2(SELL_W, BUTTON_H), BUTTON_FONT_SIZE, "blue")
		take_button.name = "TakeButton"
		take_button.pressed.connect(_on_take)
		buttons.add_child(take_button)

	var price: float = Economy.sell_price(id, variant, size_step)
	var sell_h: float = BUTTON_H if with_take else SELL_ONLY_H
	var sell_button: Button = WindowBase.make_button(Loc.t("animal_sell") + " " + NumFmt.money(price), Vector2(SELL_W, sell_h), BUTTON_FONT_SIZE, "red")
	sell_button.name = "SellButton"
	sell_button.pressed.connect(_on_sell)
	buttons.add_child(sell_button)


# Иконка зверя на плитке цвета редкости: PNG из assets/ui/icons/animal_<id>.png (T25, прозрачный фон),
# если нет, то первая буква названия.
func _make_icon(animal_name: String, rarity_color: Color, animal_id: String = "") -> Control:
	var tile: ColorRect = UiStyle.rarity_tile(Vector2(ICON_SIZE, ICON_SIZE), rarity_color, 14.0, 3.0, Color.BLACK)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if animal_id != "":
		var icon_path: String = "res://assets/ui/icons/animal_%s.png" % animal_id
		if ResourceLoader.exists(icon_path):
			var tex_rect: TextureRect = TextureRect.new()
			tex_rect.texture = load(icon_path) as Texture2D
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex_rect.offset_left = 4.0
			tex_rect.offset_top = 4.0
			tex_rect.offset_right = -4.0
			tex_rect.offset_bottom = -4.0
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(tex_rect)
			return tile

	# Фоллбек: буква
	var letter: Label = UiStyle.outline_label(animal_name.left(1).to_upper(), 40, 6, UiStyle.COLOR_TEXT)
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(letter)
	return tile


# Вторая строка: мутация (её цветом), размер и пометка «В загоне».
func _make_sub_line(variant: int, size_step: int, placed: bool) -> HBoxContainer:
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 10)
	sub.mouse_filter = Control.MOUSE_FILTER_PASS
	if variant != VariantData.NONE:
		sub.add_child(_small_label(Loc.t(VariantData.name_key(variant)), VariantData.text_color(variant)))
	if size_step > 0:
		sub.add_child(_small_label(Loc.t(SizeData.name_key(size_step)), COLOR_SUB))
	if placed:
		sub.add_child(_small_label(Loc.t("animal_placed"), COLOR_PLACED))
	return sub


func _small_label(text: String, color: Color) -> Label:
	var label: Label = UiStyle.outline_label(text, SUB_FONT_SIZE, 4, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_take() -> void:
	take_pressed.emit(uid)


func _on_sell() -> void:
	sell_pressed.emit(uid)
