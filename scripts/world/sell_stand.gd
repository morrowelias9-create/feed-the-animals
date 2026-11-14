class_name SellStand
extends Node3D
## Лавка продажи (T12a, справочник R1): прилавок с красно-белым полосатым навесом в точке
## WorldLayout.sell_stand_position() и подпись «Продать» над ним. Когда игрок входит в зону 3x3 м,
## открывается окно SellWindow. После закрытия окна оно откроется снова, только если выйти из зоны и войти заново.
## Модель из примитивов: один материал на цвет, без теней и без света.

const STRIPE_COUNT: int = 7
const STRIPE_W: float = 0.4
const STRIPE_LEN: float = 1.7
const AWNING_TILT: float = 0.38          # наклон навеса вперёд (радианы), передний край ниже
const COUNTER_SIZE: Vector3 = Vector3(2.6, 1.0, 1.0)
const VENDOR_Z: float = -1.4                 # продавец стоит за прилавком (T42), лицом к игроку

var player: Player
var throw_controller: Node
var carry_controller: Node
var window: SellWindow

var _was_inside: bool = false
var _label: Label3D
var _materials: Dictionary = {}          # цвет (hex) -> материал


func _ready() -> void:
	position = WorldLayout.sell_stand_position()
	_build_counter()
	_build_posts()
	_build_awning()
	_build_vendor()
	_build_floor_mark()
	_build_label()
	Loc.language_changed.connect(_update_label)


func _process(_delta: float) -> void:
	if player == null or window == null:
		return
	var rect: Rect2 = WorldLayout.sell_zone_rect()
	var inside: bool = rect.has_point(Vector2(player.position.x, player.position.z))
	if inside and not _was_inside and _can_open():
		window.open()
	_was_inside = inside


# Окно открывается только в спокойном состоянии: не бросок и не зверь в руках.
func _can_open() -> bool:
	if window.is_open():
		return false
	if throw_controller != null and throw_controller.is_busy():
		return false
	if carry_controller != null and carry_controller.is_carrying():
		return false
	return true


func _build_counter() -> void:
	_add_box(Vector3(0.0, COUNTER_SIZE.y / 2.0, -0.3), COUNTER_SIZE, Color("#8A5A32"), "Counter")
	_add_box(Vector3(0.0, COUNTER_SIZE.y + 0.05, -0.3), Vector3(COUNTER_SIZE.x + 0.2, 0.1, COUNTER_SIZE.z + 0.2), Color("#B98350"), "CounterTop")


# Четыре стойки: задние выше передних, чтобы навес наклонялся вперёд.
func _build_posts() -> void:
	var post_color: Color = Color("#5E3B1E")
	var x: float = COUNTER_SIZE.x / 2.0 - 0.05
	_add_box(Vector3(-x, 1.3, -0.8), Vector3(0.12, 2.6, 0.12), post_color, "PostBackL")
	_add_box(Vector3(x, 1.3, -0.8), Vector3(0.12, 2.6, 0.12), post_color, "PostBackR")
	_add_box(Vector3(-x, 1.0, 0.7), Vector3(0.12, 2.0, 0.12), post_color, "PostFrontL")
	_add_box(Vector3(x, 1.0, 0.7), Vector3(0.12, 2.0, 0.12), post_color, "PostFrontR")


# Навес из полос вдоль X: красная, белая, красная...
func _build_awning() -> void:
	var red: Color = Color("#D93A3A")
	var white: Color = Color("#F4F4F4")
	var total_w: float = STRIPE_COUNT * STRIPE_W
	for i in STRIPE_COUNT:
		var stripe_x: float = -total_w / 2.0 + STRIPE_W * (float(i) + 0.5)
		var stripe: MeshInstance3D = _add_box(Vector3(stripe_x, 2.3, -0.05), Vector3(STRIPE_W, 0.08, STRIPE_LEN),
				red if i % 2 == 0 else white, "Stripe%d" % i)
		stripe.rotation.x = AWNING_TILT


# Продавец-грибочек (T42): стоит на пеньке за прилавком, чуть повёрнут к центру двора.
func _build_vendor() -> void:
	var vendor: MushroomVendor = MushroomVendor.new()
	vendor.name = "Vendor"
	vendor.variant = MushroomBuilder.VARIANT_ORANGE
	vendor.yaw = 0.14
	vendor.position = Vector3(0.0, 0.0, VENDOR_Z)
	add_child(vendor)


# Жёлтая плоская отметка на земле: границы зоны входа 3x3.
func _build_floor_mark() -> void:
	var mark: MeshInstance3D = MeshInstance3D.new()
	mark.name = "ZoneMark"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(WorldLayout.SELL_ZONE_SIZE, 0.02, WorldLayout.SELL_ZONE_SIZE)
	mark.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position = Vector3(0.0, 0.015, 0.0)
	add_child(mark)


func _build_label() -> void:
	_label = Label3D.new()
	UiStyle.apply_font_3d(_label)
	_label.name = "StandLabel"
	_label.pixel_size = 0.01
	_label.font_size = 96
	_label.outline_size = 16
	_label.modulate = Color.WHITE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 3.3, 0.0)
	add_child(_label)
	_update_label()


func _update_label() -> void:
	if _label != null:
		_label.text = Loc.t("sell_stand_label")


func _add_box(center: Vector3, size: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = _flat_material(color)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = center
	add_child(inst)
	return inst


# Один материал на цвет.
func _flat_material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	_materials[key] = mat
	return mat
