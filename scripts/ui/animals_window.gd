class_name AnimalsWindow
extends WindowBase
## Окно «Животные» (T12, справочник R6 «Окна»): сверху «На участке N/M», список всех зверей строками
## (иконка, название цветом редкости, мутация и размер, доход, «Взять», «Продать $N»),
## внизу «Разместить лучших» и «Продать лишних».
## «Взять» закрывает окно и отдаёт зверя в руки через сигнал `take_requested` (его ловит CarryController.take).

signal take_requested(uid: int)

const LIST_MIN_H: float = 120.0
const BOTTOM_H: float = 64.0

var _count_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty_label: Label
var _best_button: Button
var _extras_button: Button


func _init() -> void:
	title_key = "animals_title"


func _build_body() -> void:
	_count_label = UiStyle.outline_label("", 30, 5, UiStyle.COLOR_TEXT)
	body.add_child(_count_label)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0.0, LIST_MIN_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	_empty_label = UiStyle.outline_label("", 30, 5, AnimalRow.COLOR_SUB)
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_empty_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	body.add_child(bottom)
	_best_button = make_button("", Vector2(0.0, BOTTOM_H))
	_best_button.name = "EquipBestButton"
	_best_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_best_button.pressed.connect(_on_equip_best)
	bottom.add_child(_best_button)
	_extras_button = make_button("", Vector2(0.0, BOTTOM_H))
	_extras_button.name = "SellExtrasButton"
	_extras_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extras_button.pressed.connect(_on_sell_extras)
	bottom.add_child(_extras_button)

	if not Game.inventory_changed.is_connected(_on_game_changed):
		Game.inventory_changed.connect(_on_game_changed)
	if not Game.slots_changed.is_connected(_on_game_changed):
		Game.slots_changed.connect(_on_game_changed)


## Перестраивает список. Прокрутка сохраняется, чтобы после продажи список не прыгал вверх.
func refresh() -> void:
	if _list == null:
		return
	var keep_scroll: int = _scroll.scroll_vertical
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var animals: Array = Game.all_animals()
	animals.sort_custom(AnimalRow.by_income_desc)
	for a in animals:
		var row: AnimalRow = AnimalRow.create(a, true, true)
		row.take_pressed.connect(_on_take)
		row.sell_pressed.connect(_on_sell)
		_list.add_child(row)

	_count_label.text = Loc.t("animals_on_plot") % [Game.placed_count(), Game.total_slots()]
	_empty_label.text = Loc.t("animals_empty")
	_empty_label.visible = animals.is_empty()
	_scroll.visible = not animals.is_empty()
	_best_button.text = Loc.t("animals_equip_best")
	_best_button.disabled = animals.is_empty()
	var extras: float = Game.extras_value()
	if extras > 0.0:
		_extras_button.text = "%s (%s)" % [Loc.t("animals_sell_extras"), NumFmt.money(extras)]
	else:
		_extras_button.text = Loc.t("animals_sell_extras")
	_extras_button.disabled = extras <= 0.0
	_restore_scroll(keep_scroll)


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value


func _on_game_changed() -> void:
	if visible:
		refresh()


func _on_take(uid: int) -> void:
	close()
	take_requested.emit(uid)


func _on_sell(uid: int) -> void:
	var got: float = Game.sell(uid)
	if got > 0.0:
		show_toast(Loc.t("sold_toast") % NumFmt.money(got))


func _on_equip_best() -> void:
	Game.equip_best()
	show_toast(Loc.t("animals_equipped"))


func _on_sell_extras() -> void:
	var got: float = Game.sell_extras()
	if got > 0.0:
		show_toast(Loc.t("sold_toast") % NumFmt.money(got))
	else:
		show_toast(Loc.t("animals_no_extras"))
