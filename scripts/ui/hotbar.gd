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
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	if not Game.inventory_changed.is_connected(refresh):
		Game.inventory_changed.connect(refresh)
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
			b.text = id.left(1).to_upper()
			b.tooltip_text = Loc.t("animal_" + id)
			b.modulate = Color.from_hsv(float(abs(id.hash()) % 1000) / 1000.0, 0.55, 1.0)
			b.visible = true
		else:
			b.visible = false


func _on_button(index: int) -> void:
	if index >= 0 and index < _uids.size():
		animal_selected.emit(_uids[index])
