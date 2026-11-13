class_name BuyPad
extends Node3D
## Кнопка покупки турника на полу (T15a, справочники R3 и R6 «В мире»): плоский оранжевый диск
## радиусом 1.2 м всегда в одной точке рядом с турником, над ним цена и подпись «Купить: Стальной турник (+2)».
## Вход на диск покупает следующий турник (Game.buy_bar), он заменяет старый на месте и вырастает «пружиной»
## (BarController), на диске меняются цена и подпись. Не хватает денег: цена красная и диск трясётся.
## Когда куплены все 10 турников, диск исчезает.

const DISK_H: float = 0.06
const RIM_EXTRA: float = 0.12
const SHAKE_S: float = 0.3
const SHAKE_AMP: float = 0.18
const POP_S: float = 0.5
const COLOR_DISK: Color = Color("#FF9A1F")
const COLOR_RIM: Color = Color("#5E3A10")
const COLOR_PRICE_OK: Color = Color.WHITE
const COLOR_PRICE_BAD: Color = Color("#FF4D4D")

var player: Player
var throw_controller: Node

var _disk: Node3D                        # диск с ободком: его трясём и «пружиним», подписи стоят отдельно
var _price: Label3D
var _caption: Label3D
var _was_inside: bool = false
var _shake: Tween
var _pop: Tween


func _ready() -> void:
	_build_disk()
	_build_labels()
	position = WorldLayout.buy_pad_position()
	Game.bar_changed.connect(_on_bar_changed)
	Game.money_changed.connect(_on_money_changed)
	Loc.language_changed.connect(_update_texts)
	_place(false)


## Куда ведут стрелки обучения (T19): центр диска.
func target_position() -> Vector3:
	return position


func _process(_delta: float) -> void:
	if player == null or not visible:
		return
	var dx: float = player.position.x - position.x
	var dz: float = player.position.z - position.z
	var inside: bool = Vector2(dx, dz).length() <= WorldLayout.BUY_PAD_RADIUS
	if inside and not _was_inside:
		_try_buy()
	_was_inside = inside


func _try_buy() -> void:
	if throw_controller != null and throw_controller.is_busy():
		return
	if Game.buy_bar():
		return   # bar_changed: турник заменится и вырастет, цена на диске сменится
	_shake_disk()


func _on_bar_changed() -> void:
	_place(true)


func _on_money_changed(_value: float) -> void:
	_update_state()


# Диск стоит на месте, обновляются цена и подпись; все турники куплены: диск прячется.
func _place(animate: bool) -> void:
	if Game.bars_owned() >= UpgradeData.BARS.size():
		visible = false
		return
	visible = true
	_update_texts()
	if animate:
		_pop_disk()


func _update_texts() -> void:
	var next: int = Game.bars_owned()
	if next >= UpgradeData.BARS.size() or _price == null:
		return
	var data: Dictionary = UpgradeData.BARS[next]
	_price.text = NumFmt.money(float(data["price"]))
	_caption.text = Loc.t("bar_buy_caption") % [Loc.t(String(data["name_key"])), int(float(data["xp"]))]
	_update_state()


# Цена красная, пока денег не хватает.
func _update_state() -> void:
	if not visible or _price == null:
		return
	var price: float = Game.next_bar_price()
	_price.modulate = COLOR_PRICE_OK if price >= 0.0 and Game.money() >= price else COLOR_PRICE_BAD


func _shake_disk() -> void:
	if _shake != null and _shake.is_valid():
		_shake.kill()
	_disk.position.x = 0.0
	_shake = create_tween()
	var step: float = SHAKE_S / 6.0
	for dx in [SHAKE_AMP, -SHAKE_AMP, SHAKE_AMP * 0.6, -SHAKE_AMP * 0.6, SHAKE_AMP * 0.3, 0.0]:
		_shake.tween_property(_disk, "position:x", float(dx), step)


func _pop_disk() -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_disk.scale = Vector3(0.3, 1.0, 0.3)
	_pop = create_tween()
	_pop.tween_property(_disk, "scale", Vector3.ONE, POP_S).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _build_disk() -> void:
	_disk = Node3D.new()
	_disk.name = "Disk"
	add_child(_disk)
	_add_cylinder("Rim", WorldLayout.BUY_PAD_RADIUS + RIM_EXTRA, DISK_H, 0.0, COLOR_RIM)
	_add_cylinder("Top", WorldLayout.BUY_PAD_RADIUS, DISK_H, 0.02, COLOR_DISK)


func _add_cylinder(node_name: String, radius: float, height: float, lift: float, color: Color) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, height / 2.0 + lift, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disk.add_child(mi)


func _build_labels() -> void:
	_price = _make_label("PriceLabel", 130, 22, 2.0)
	_caption = _make_label("CaptionLabel", 52, 10, 1.3)


func _make_label(node_name: String, font_size: int, outline: int, height: float) -> Label3D:
	var label: Label3D = Label3D.new()
	UiStyle.apply_font_3d(label)
	label.name = node_name
	label.pixel_size = 0.01
	label.font_size = font_size
	label.outline_size = outline
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, height, 0.0)
	add_child(label)
	return label
