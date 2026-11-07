class_name Hotbar
extends Control
## Нижняя панель выбора зверей из рюкзака. Временно использует цветные иконки-заглушки.

signal animal_selected(uid: int)

const MAX_VISIBLE := 8
const ITEM_SIZE := Vector2(64.0, 64.0)
var carried_uid := -1
var _buttons: Array[Button] = []
var _uids: Array[int] = []


func _ready() -> void:
	# Корень растянут на весь экран и лежит поверх кнопок HUD: он не должен забирать клики (иначе «Индекс»,
	# «Магазин» и «Животные» не нажимаются). Иконки зверей внутри остаются нажимаемыми.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	if not Game.inventory_changed.is_connected(refresh):
		Game.inventory_changed.connect(refresh)
	if not Loc.language_changed.is_connected(refresh):
		Loc.language_changed.connect(refresh)
	refresh()


func _build() -> void:
	var row := HBoxContainer.new()
	row.name = "Items"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-288.0, -82.0)
	row.size = Vector2(576.0, 72.0)
	add_child(row)
	for i in MAX_VISIBLE:
		var b := Button.new()
		b.custom_minimum_size = ITEM_SIZE
		b.size = ITEM_SIZE
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_button.bind(i))
		row.add_child(b)
		_buttons.append(b)


func refresh() -> void:
	_uids.clear()
	for a in Game.backpack_animals():
		if int(a["uid"]) == carried_uid:
			continue
		if _uids.size() >= MAX_VISIBLE:
			break
		_uids.append(int(a["uid"]))
	for i in _buttons.size():
		var b := _buttons[i]
		if i < _uids.size():
			var a := Game.animal_by_uid(_uids[i])
			var id := String(a.get("animal_id", "?"))
			var animal_name: String = Loc.t("animal_" + id)
			
			# Иконка зверя: PNG (T25) или фоллбек — буква
			var icon_path: String = "res://assets/ui/icons/animal_%s.png" % id
			if ResourceLoader.exists(icon_path):
				b.icon = load(icon_path) as Texture2D
				b.add_theme_constant_override("icon_max_width", int(ITEM_SIZE.x * 0.9))
				b.text = ""
			else:
				b.icon = null
				b.text = animal_name.left(1).to_upper()
				b.modulate = Color.from_hsv(float(abs(id.hash()) % 1000) / 1000.0, 0.55, 1.0)
			b.tooltip_text = animal_name
			b.visible = true
		else:
			b.visible = false


func _on_button(index: int) -> void:
	if index >= 0 and index < _uids.size():
		animal_selected.emit(_uids[index])
