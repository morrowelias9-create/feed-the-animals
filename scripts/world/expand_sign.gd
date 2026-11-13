class_name ExpandSign
extends Node3D
## Табличка расширения участка (T16). Стоит на передней ограде своего загона,
## лицевой стороной во двор (-Z), поэтому текст читается с камеры перед табличкой.
## Игрок входит в зону 3x3 м перед табличкой или нажимает действие, стоя в зоне.

const BOARD_SIZE: Vector3 = Vector3(2.4, 0.95, 0.14)
const BOARD_CENTER_Y: float = 1.5
const BOARD_Z: float = -0.28          # чуть впереди столбика ограды (25.8), чтобы не утопить доску
const TRIM_SIZE: Vector3 = Vector3(2.52, 0.07, 0.2)
const PRICE_PLATE_SIZE: Vector3 = Vector3(1.9, 0.4, 0.12)
const PRICE_PLATE_Y: float = 0.82     # сразу под доской
const TEXT_Z: float = -0.37           # перед лицевой гранью доски
const PLATE_TEXT_Z: float = -0.36

const POP_TIME: float = 0.48
const SHAKE_TIME: float = 0.28
const SHAKE_AMOUNT: float = 0.08
const PAD_DISK_H: float = 0.06
const PAD_RIM_EXTRA: float = 0.12

const WOOD_DARK := Color("#654326")
const WOOD := Color("#9A683B")
const DARK_PLATE := Color("#292522")
const PAW_COLOR := Color("#F2C14E")
const PRICE_OK := Color("#65E36B")
const PRICE_BAD := Color("#FF5555")
const PAD_DISK := Color("#FF9A1F")
const PAD_RIM := Color("#5E3A10")

var player: Player
var throw_controller: Node
var carry_controller: Node

var _board: Node3D
var _numbers: Label3D
var _price: Label3D
var _price_plate: MeshInstance3D
var _price_arrow: MeshInstance3D
var _price_arrow_mat: StandardMaterial3D
var _pad: Node3D
var _pad_price: Label3D
var _pad_caption: Label3D
var _was_inside: bool = false
var _pop_tween: Tween
var _shake_tween: Tween
var _pad_shake_tween: Tween


func _ready() -> void:
	position = WorldLayout.sign_position()
	_build_sign()
	_build_pad()
	Game.money_changed.connect(_on_money_changed)
	Game.slots_changed.connect(_on_slots_changed)
	Loc.language_changed.connect(_update_text)
	_update_text()


func _process(_delta: float) -> void:
	if player == null:
		return
	var inside := _in_zone()
	if inside and not _was_inside:
		_try_buy()
	_was_inside = inside


## true означает, что действие использовано табличкой и не должно запускать бросок.
func try_activate() -> bool:
	if player == null or not _in_zone():
		return false
	_try_buy()
	return true


func _in_zone() -> bool:
	var pad: Vector3 = WorldLayout.sign_pad_position()
	var dx: float = player.global_position.x - pad.x
	var dz: float = player.global_position.z - pad.z
	return Vector2(dx, dz).length() <= WorldLayout.SIGN_PAD_RADIUS


func _can_buy() -> bool:
	if throw_controller != null and throw_controller.is_busy():
		return false
	if carry_controller != null and carry_controller.is_carrying():
		return false
	return player == null or player.enabled


func _try_buy() -> void:
	if _at_max():
		return
	if not _can_buy():
		return
	if not Game.buy_slots():
		_shake()


func _at_max() -> bool:
	return Game.total_slots() >= WorldLayout.SLOT_COUNT \
			or Game.slots_level() >= UpgradeData.SLOT_PRICES.size()


func _build_sign() -> void:
	_board = Node3D.new()
	_board.name = "Board"
	add_child(_board)

	_add_box(_board, Vector3(0.0, BOARD_CENTER_Y, BOARD_Z), BOARD_SIZE, WOOD, "WoodBoard")
	_add_box(_board, Vector3(0.0, BOARD_CENTER_Y + BOARD_SIZE.y / 2.0, BOARD_Z), TRIM_SIZE, WOOD_DARK, "TopTrim")
	_add_box(_board, Vector3(0.0, BOARD_CENTER_Y - BOARD_SIZE.y / 2.0, BOARD_Z), TRIM_SIZE, WOOD_DARK, "BottomTrim")

	# Тёмная плашка с ценой висит под доской.
	_price_plate = _add_box(_board, Vector3(0.0, PRICE_PLATE_Y, BOARD_Z), PRICE_PLATE_SIZE, DARK_PLATE, "PricePlate")

	_add_paw_shape()
	_numbers = _make_label("CapacityLabel", -0.1, BOARD_CENTER_Y, 48)
	_price = _make_label("PriceLabel", -0.12, PRICE_PLATE_Y, 38, PRICE_OK)
	_price_arrow_mat = _material(PRICE_OK, true)
	_price_arrow = _add_triangle(
		Vector3(0.5, PRICE_PLATE_Y, PLATE_TEXT_Z + 0.01), Vector2(0.2, 0.16), "PriceArrow"
	)


# Видимая кнопка на полу в зоне таблички: оранжевый диск с ободком, как у турника (T15a).
func _build_pad() -> void:
	_pad = Node3D.new()
	_pad.name = "BuyPad"
	_pad.position = WorldLayout.sign_pad_position() - position
	add_child(_pad)
	_add_cylinder(_pad, "PadRim", WorldLayout.SIGN_PAD_RADIUS + PAD_RIM_EXTRA, PAD_DISK_H, 0.0, PAD_RIM)
	_add_cylinder(_pad, "PadTop", WorldLayout.SIGN_PAD_RADIUS, PAD_DISK_H, 0.02, PAD_DISK)

	_pad_price = _make_pad_label("PadPriceLabel", 74, 12, 1.0)
	_pad_caption = _make_pad_label("PadCaptionLabel", 32, 7, 0.42)


func _make_pad_label(node_name: String, font_size: int, outline: int, height: float) -> Label3D:
	var label := Label3D.new()
	UiStyle.apply_font_3d(label)
	label.name = node_name
	label.pixel_size = 0.01
	label.font_size = font_size
	label.outline_size = outline
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = _pad.position + Vector3(0.0, height, 0.0)
	add_child(label)
	return label


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, lift: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 1
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = _material(color)
	inst.position = Vector3(0.0, height / 2.0 + lift, 0.0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


func _add_paw_shape() -> void:
	# Лапа-заглушка слева от цифр (с камеры со стороны двора местная +X это левый край).
	_add_ellipsoid(Vector3(0.86, 1.44, TEXT_Z + 0.01), Vector3(0.115, 0.08, 0.025), PAW_COLOR, "PawPad")
	var toe_x: Array[float] = [0.99, 0.905, 0.815, 0.73]
	for i in 4:
		var y: float = 1.58 + (0.02 if i == 1 or i == 2 else 0.0)
		_add_ellipsoid(Vector3(toe_x[i], y, TEXT_Z + 0.01), Vector3(0.042, 0.058, 0.022), PAW_COLOR, "PawToe%d" % i)


func _make_label(node_name: String, x: float, y: float, font_size: int, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	UiStyle.apply_font_3d(label)
	label.name = node_name
	label.pixel_size = 0.01
	label.font_size = font_size
	label.outline_size = 10
	label.modulate = color
	label.outline_modulate = Color.BLACK
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.double_sided = false       # с обратной стороны надписи не видно, зеркального текста нет
	label.rotation.y = PI            # лицевая сторона Label3D (+Z) развёрнута во двор (-Z)
	label.position = Vector3(x, y, TEXT_Z)
	_board.add_child(label)
	return label


func _update_text() -> void:
	if _numbers == null or _price == null:
		return
	if _at_max():
		_numbers.text = Loc.t("expand_max")
		_price.text = ""
		_price_plate.visible = false
		_price_arrow.visible = false
		_pad.visible = false
		_pad_price.visible = false
		_pad_caption.visible = false
		return
	var current: int = Game.total_slots()
	var next: int = current + UpgradeData.SLOTS_PER_LEVEL
	var cost: float = UpgradeData.SLOT_PRICES[Game.slots_level()]
	_numbers.text = Loc.t("expand_capacity") % [current, next]
	_price.text = NumFmt.money(cost)
	var color: Color = PRICE_OK if Game.money() >= cost else PRICE_BAD
	_price.modulate = color
	_price_arrow_mat.albedo_color = color
	_price_plate.visible = true
	_price_arrow.visible = true
	_pad.visible = true
	_pad_price.text = NumFmt.money(cost)
	_pad_price.modulate = color
	_pad_caption.text = Loc.t("expand_pad_caption")
	_pad_price.visible = true
	_pad_caption.visible = true


func _on_money_changed(_value: float) -> void:
	_update_text()


func _on_slots_changed() -> void:
	_update_text()
	_pop()


func _pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_board.scale = Vector3(0.86, 0.86, 0.86)
	_pop_tween = create_tween()
	_pop_tween.tween_property(_board, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _pad != null:
		_pad.scale = Vector3(0.3, 1.0, 0.3)
		_pop_tween.parallel().tween_property(_pad, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_board.position.x = 0.0
	_shake_tween = create_tween()
	for offset in [SHAKE_AMOUNT, -SHAKE_AMOUNT, SHAKE_AMOUNT * 0.55, -SHAKE_AMOUNT * 0.55, 0.0]:
		_shake_tween.tween_property(_board, "position:x", float(offset), SHAKE_TIME / 5.0)
	if _pad != null:
		if _pad_shake_tween != null and _pad_shake_tween.is_valid():
			_pad_shake_tween.kill()
		_pad.position.x = 0.0
		_pad_shake_tween = create_tween()
		for offset in [SHAKE_AMOUNT * 2.0, -SHAKE_AMOUNT * 2.0, SHAKE_AMOUNT, 0.0]:
			_pad_shake_tween.tween_property(_pad, "position:x", float(offset), SHAKE_TIME / 4.0)


func _add_box(parent: Node3D, center: Vector3, size: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = _material(color)
	inst.position = center
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


func _add_ellipsoid(center: Vector3, scale_value: Vector3, color: Color, node_name: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.scale = scale_value * 2.0
	inst.position = center
	inst.material_override = _material(color)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.add_child(inst)


# Плоский треугольник-стрелка вверх для плашки цены (без шрифтовых символов).
func _add_triangle(center: Vector3, size: Vector2, node_name: String) -> MeshInstance3D:
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-hw, -hh, 0.0), Vector3(hw, -hh, 0.0), Vector3(0.0, hh, 0.0)
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0)
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = _price_arrow_mat
	inst.position = center
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.add_child(inst)
	return inst


func _material(color: Color, double_side: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if double_side:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
