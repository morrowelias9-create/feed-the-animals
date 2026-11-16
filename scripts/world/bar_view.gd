class_name BarView
extends Node3D
## Турник перед своим загоном (T14, справочники R1 и R3): модель, цвет и подпись
## берутся из UpgradeData по номеру тира. Новый турник заменяет старый на том же месте: set_tier() меняет
## цвет и подпись, pop_in() вырастает «пружиной» (T15a). Игрок стоит в точке турника, перекладина чуть впереди (-Z)
## на высоте поднятых рук. Модель строит BarModel (богаче с ростом тира), здесь подпись, пружина и пунктир зоны.

const POST_SIZE: Vector3 = Vector3(0.14, 2.45, 0.14)
const POST_X: float = 1.2
const CROSSBAR_Y: float = 2.3
const CROSSBAR_Z: float = -0.2
const CROSSBAR_T: float = 0.12
const LABEL_Y: float = 3.3
const POP_S: float = 0.6
const DASH_LEN: float = 0.45             # длина штриха белой пунктирной границы зоны турника
const DASH_GAP: float = 0.3
const DASH_W: float = 0.12
const DASH_Y: float = 0.04

var tier: int = 0

var _model: Node3D                   # модель турника (BarModel), пересобирается при смене тира
var _label: Label3D
var _pop: Tween
var _zone: MultiMeshInstance3D       # пунктир границы зоны


func _ready() -> void:
	position = WorldLayout.bar_position()

	_label = Label3D.new()
	UiStyle.apply_font_3d(_label)
	_label.name = "BarLabel"
	_label.pixel_size = 0.005
	_label.font_size = 32
	_label.outline_size = 6
	_label.modulate = Color.WHITE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, LABEL_Y, CROSSBAR_Z)
	add_child(_label)
	_build_zone_dashes()
	Loc.language_changed.connect(_refresh)
	_refresh()


# Белая пунктирная граница зоны турника (квадрат BAR_ZONE_SIZE): один MultiMesh, меши строятся один раз.
func _build_zone_dashes() -> void:
	var half: float = WorldLayout.BAR_ZONE_SIZE / 2.0
	var step: float = DASH_LEN + DASH_GAP
	var count_side: int = int(floor(WorldLayout.BAR_ZONE_SIZE / step))
	var quad: BoxMesh = BoxMesh.new()
	quad.size = Vector3(DASH_LEN, 0.02, DASH_W)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count_side * 4
	var offset: float = (WorldLayout.BAR_ZONE_SIZE - (count_side * step - DASH_GAP)) / 2.0 + DASH_LEN / 2.0
	var idx: int = 0
	for side in 4:
		for k in count_side:
			var t: float = -half + offset + k * step
			var basis: Basis = Basis()
			var pos: Vector3
			match side:
				0: pos = Vector3(t, DASH_Y, -half)
				1: pos = Vector3(t, DASH_Y, half)
				2:
					pos = Vector3(-half, DASH_Y, t)
					basis = Basis(Vector3.UP, PI / 2.0)
				_:
					pos = Vector3(half, DASH_Y, t)
					basis = Basis(Vector3.UP, PI / 2.0)
			mm.set_instance_transform(idx, Transform3D(basis, pos))
			idx += 1
	_zone = MultiMeshInstance3D.new()
	_zone.name = "ZoneDashes"
	_zone.multimesh = mm
	_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_zone)


## Ставит турник тира i (0-9): цвет и подпись.
func set_tier(i: int) -> void:
	tier = clampi(i, 0, UpgradeData.BARS.size() - 1)
	_refresh()


## Вырастание «пружиной»: из точки до полного размера с перелётом.
func pop_in() -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	scale = Vector3(0.01, 0.01, 0.01)
	_pop = create_tween()
	_pop.tween_property(self, "scale", Vector3.ONE, POP_S).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	if _label == null:
		return
	var data: Dictionary = UpgradeData.BARS[clampi(tier, 0, UpgradeData.BARS.size() - 1)]
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	_model = BarModel.build(LookData.bar_look(String(data["id"])), POST_X, CROSSBAR_Y, CROSSBAR_Z)
	add_child(_model)
	_label.text = Loc.t("bar_label") % [Loc.t(String(data["name_key"])), int(float(data["xp"]))]
