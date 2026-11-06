class_name SellWindow
extends WindowBase
## Окно лавки продажи (T12a): звери из рюкзака (неразмещённые) с ценой и «Продать»,
## сверху «Продать всё ($N)». Если среди проданных будут редкие (ранг 7-8, мутация или размер 2+),
## сначала спрашиваем подтверждение. Размещённых в загоне зверей окно не показывает и не трогает.

const LIST_MIN_H: float = 120.0
const TOP_BUTTON_H: float = 64.0
const CONFIRM_W: float = 600.0

var _sell_all_button: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty_label: Label
var _confirm: ColorRect
var _confirm_label: Label
var _confirm_yes: Button
var _confirm_no: Button


func _init() -> void:
	title_key = "sell_title"


func open() -> void:
	if _confirm != null:
		_confirm.visible = false
	super.open()


func close() -> void:
	if _confirm != null:
		_confirm.visible = false
	super.close()


func _build_body() -> void:
	_sell_all_button = make_button("", Vector2(0.0, TOP_BUTTON_H), 28)
	_sell_all_button.name = "SellAllButton"
	_sell_all_button.pressed.connect(_on_sell_all)
	body.add_child(_sell_all_button)

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

	_build_confirm()
	if not Game.inventory_changed.is_connected(_on_game_changed):
		Game.inventory_changed.connect(_on_game_changed)


## Перестраивает список рюкзака. Прокрутка сохраняется.
func refresh() -> void:
	if _list == null:
		return
	var keep_scroll: int = _scroll.scroll_vertical
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var animals: Array = Game.backpack_animals()
	animals.sort_custom(AnimalRow.by_income_desc)
	for a in animals:
		var row: AnimalRow = AnimalRow.create(a, false, false)
		row.sell_pressed.connect(_on_sell)
		_list.add_child(row)

	var total: float = Game.backpack_value()
	_sell_all_button.text = Loc.t("sell_all") % NumFmt.money(total)
	_sell_all_button.disabled = animals.is_empty()
	_empty_label.text = Loc.t("sell_empty")
	_empty_label.visible = animals.is_empty()
	_scroll.visible = not animals.is_empty()
	_confirm_yes.text = Loc.t("sell_confirm_yes")
	_confirm_no.text = Loc.t("sell_confirm_no")
	if animals.is_empty():
		_confirm.visible = false
	_restore_scroll(keep_scroll)


# Окно подтверждения поверх панели: затемнение и карточка по центру.
func _build_confirm() -> void:
	_confirm = ColorRect.new()
	_confirm.name = "Confirm"
	_confirm.color = Color(0.0, 0.0, 0.0, 0.6)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	add_child(_confirm)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel_style())
	center.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	_confirm_label = UiStyle.outline_label("", 28, 4, UiStyle.COLOR_TEXT)
	_confirm_label.custom_minimum_size = Vector2(CONFIRM_W, 0.0)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_confirm_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_confirm_no = make_button("", Vector2(0.0, TOP_BUTTON_H), 26)
	_confirm_no.name = "ConfirmNo"
	_confirm_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_no.pressed.connect(_on_confirm_no)
	buttons.add_child(_confirm_no)
	_confirm_yes = make_button("", Vector2(0.0, TOP_BUTTON_H), 26)
	_confirm_yes.name = "ConfirmYes"
	_confirm_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_yes.pressed.connect(_on_confirm_yes)
	buttons.add_child(_confirm_yes)


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value


func _on_game_changed() -> void:
	if visible:
		refresh()


func _on_sell(uid: int) -> void:
	var got: float = Game.sell(uid)
	if got > 0.0:
		show_toast(Loc.t("sold_toast") % NumFmt.money(got))


# «Продать всё»: с редкими среди зверей сначала подтверждение с суммой.
func _on_sell_all() -> void:
	var total: float = Game.backpack_value()
	if total <= 0.0:
		return
	if Game.backpack_has_rare():
		_confirm_label.text = Loc.t("sell_confirm_text") % NumFmt.money(total)
		_confirm.visible = true
		return
	_sell_all_now()


func _on_confirm_yes() -> void:
	_sell_all_now()


func _on_confirm_no() -> void:
	_confirm.visible = false


func _sell_all_now() -> void:
	_confirm.visible = false
	var got: float = Game.sell_backpack()
	if got > 0.0:
		show_toast(Loc.t("sold_toast") % NumFmt.money(got))
