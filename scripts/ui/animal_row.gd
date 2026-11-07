class_name AnimalRow
extends PanelContainer
## Строка зверя в окнах «Животные» (T12) и «Лавка» (T12a): иконка-заглушка, название цветом редкости,
## мутация и размер, доход (по желанию), кнопки «Взять» (по желанию) и «Продать $N».
## Иконок моделей ещё нет (T25), поэтому вместо них цветной квадрат с первой буквой названия.

signal take_pressed(uid: int)
signal sell_pressed(uid: int)

const ROW_H: float = 80.0
const ICON_SIZE: float = 56.0
const BUTTON_H: float = 64.0
const TAKE_W: float = 130.0
const SELL_W: float = 220.0
const INCOME_W: float = 150.0
const NAME_FONT_SIZE: int = 26
const SUB_FONT_SIZE: int = 20
const COLOR_SUB: Color = Color(0.78, 0.78, 0.8)
const COLOR_PLACED: Color = Color("#8FE39A")

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
	style.bg_color = Color(0.12, 0.12, 0.13)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = rarity_color.darkened(0.3)
	style.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(row)

	row.add_child(_make_icon(animal_name, rarity_color, id))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(info)
	var name_label: Label = UiStyle.outline_label(animal_name, NAME_FONT_SIZE, 4, rarity_color)
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
		var income_label: Label = UiStyle.outline_label(NumFmt.money(income) + "/s", NAME_FONT_SIZE, 4, UiStyle.COLOR_MONEY)
		income_label.custom_minimum_size = Vector2(INCOME_W, 0.0)
		income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		income_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(income_label)

	if with_take:
		var take_button: Button = WindowBase.make_button(Loc.t("animal_take"), Vector2(TAKE_W, BUTTON_H))
		take_button.name = "TakeButton"
		take_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		take_button.pressed.connect(_on_take)
		row.add_child(take_button)

	var price: float = Economy.sell_price(id, variant, size_step)
	var sell_button: Button = WindowBase.make_button(Loc.t("animal_sell") + " " + NumFmt.money(price), Vector2(SELL_W, BUTTON_H), 22)
	sell_button.name = "SellButton"
	sell_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_button.pressed.connect(_on_sell)
	row.add_child(sell_button)


# Иконка зверя: загружает PNG из assets/ui/icons/animal_<id>.png (T25),
# если нет — фоллбек: квадрат цвета редкости с первой буквой.
func _make_icon(animal_name: String, rarity_color: Color, animal_id: String = "") -> Control:
	var icon := ColorRect.new()
	icon.color = rarity_color.darkened(0.55)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if animal_id != "":
		var icon_path: String = "res://assets/ui/icons/animal_%s.png" % animal_id
		if ResourceLoader.exists(icon_path):
			var tex_rect: TextureRect = TextureRect.new()
			tex_rect.texture = load(icon_path) as Texture2D
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(tex_rect)
			return icon
	
	# Фоллбек: буква
	var letter: Label = UiStyle.outline_label(animal_name.left(1).to_upper(), 32, 4, rarity_color)
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(letter)
	return icon


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
	var label: Label = UiStyle.outline_label(text, SUB_FONT_SIZE, 3, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_take() -> void:
	take_pressed.emit(uid)


func _on_sell() -> void:
	sell_pressed.emit(uid)
