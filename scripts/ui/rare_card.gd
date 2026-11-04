class_name RareCard
extends Control
## Крупная карточка редкости на 1.5 с (шаг T10, справочник R6).

const CARD_S: float = 1.5

var _visible: bool = false
var _timer: float = 0.0
var _rarity: int = 0
var _panel: PanelContainer
var _title: Label
var _rarity_label: Label
var _income_label: Label


func open(animal_name: String, rarity: int, income: float) -> void:
	_visible = true
	_timer = 0.0
	_rarity = rarity
	_title.text = animal_name
	_rarity_label.text = Loc.t("rarity_" + str(rarity))
	_income_label.text = NumFmt.money(income) + "/s"
	var style := UiStyle.panel_style()
	style.border_color = AnimalData.rarity_color(rarity)
	_panel.add_theme_stylebox_override("panel", style)
	_timer = CARD_S


func close() -> void:
	_visible = false


func _ready() -> void:
	_build()
	visible = false


func _process(delta: float) -> void:
	if not _visible:
		return
	_timer += delta
	if _timer >= CARD_S:
		_timer = 0.0
		close()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := UiStyle.panel_style()
	style.border_color = AnimalData.rarity_color(_rarity)
	style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_panel = panel
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_title = _make_label(box, "RareCardTitle", 40, AnimalData.rarity_color(_rarity))
	_rarity_label = _make_label(box, "RareCardRarity", 26, Color.WHITE)
	_income_label = _make_label(box, "RareCardIncome", 24, UiStyle.COLOR_MONEY)


func _make_label(parent: Container, node_name: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(420.0, float(font_size * 2))
	parent.add_child(l)
	return l
