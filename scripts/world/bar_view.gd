class_name BarView
extends Node3D
## Турник перед своим загоном (T14, справочники R1 и R3): две стойки и перекладина, цвет и подпись
## берутся из UpgradeData по номеру тира. Новый турник заменяет старый на том же месте: set_tier() меняет
## цвет и подпись, pop_in() вырастает «пружиной» (T15a). Игрок стоит в точке турника, перекладина чуть впереди (-Z)
## на высоте поднятых рук. Три меша и один материал, без теней и света.

const POST_SIZE: Vector3 = Vector3(0.14, 2.45, 0.14)
const POST_X: float = 1.2
const CROSSBAR_Y: float = 2.3
const CROSSBAR_Z: float = -0.2
const CROSSBAR_T: float = 0.12
const LABEL_Y: float = 3.3
const POP_S: float = 0.6

var tier: int = 0

var _mat: StandardMaterial3D
var _label: Label3D
var _pop: Tween
var _gems: MultiMeshInstance3D       # камни на перекладине и шары на стойках (один узел на турник)
var _gem_mat: StandardMaterial3D


func _ready() -> void:
	position = WorldLayout.bar_position()
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.6
	_add_box("PostLeft", POST_SIZE, Vector3(-POST_X, POST_SIZE.y / 2.0, CROSSBAR_Z))
	_add_box("PostRight", POST_SIZE, Vector3(POST_X, POST_SIZE.y / 2.0, CROSSBAR_Z))
	_add_box("Crossbar", Vector3(POST_X * 2.0 + POST_SIZE.x, CROSSBAR_T, CROSSBAR_T), Vector3(0.0, CROSSBAR_Y, CROSSBAR_Z))

	_label = Label3D.new()
	UiStyle.apply_font_3d(_label)
	_label.name = "BarLabel"
	_label.pixel_size = 0.01
	_label.font_size = 44
	_label.outline_size = 10
	_label.modulate = Color.WHITE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, LABEL_Y, CROSSBAR_Z)
	add_child(_label)
	Loc.language_changed.connect(_refresh)
	_refresh()


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
	if _mat == null or _label == null:
		return
	var data: Dictionary = UpgradeData.BARS[clampi(tier, 0, UpgradeData.BARS.size() - 1)]
	_mat.albedo_color = Color.html(String(data["color"]))
	var look: Dictionary = LookData.bar_look(String(data["id"]))
	_mat.metallic = float(look.get("metal", 0.0))
	_mat.roughness = float(look.get("rough", 0.6))
	_rebuild_gems(look)
	var glow: bool = bool(data.get("glow", false))
	_mat.emission_enabled = glow
	if glow:
		_mat.emission = _mat.albedo_color
		_mat.emission_energy_multiplier = 1.5
	_label.text = Loc.t("bar_label") % [Loc.t(String(data["name_key"])), int(float(data["xp"]))]


func _add_box(node_name: String, size: Vector3, pos: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# Камни по перекладине и шары на верхушках стоек: один MultiMeshInstance3D, один материал.
func _rebuild_gems(look: Dictionary) -> void:
	if _gems != null:
		remove_child(_gems)
		_gems.queue_free()
		_gems = null
	var gem_hex: String = String(look.get("gem", ""))
	if gem_hex == "":
		return
	var items: Array[Transform3D] = []
	var count: int = int(look.get("count", 0))
	var hang: bool = bool(look.get("hang", false))
	var gem_y: float = CROSSBAR_Y - 0.17 if hang else CROSSBAR_Y + 0.14
	for i in count:
		var k: float = 0.5 if count == 1 else float(i) / float(count - 1)
		var x: float = lerpf(-POST_X + 0.15, POST_X - 0.15, k)
		var b: Basis = Basis.from_scale(Vector3(0.17, 0.2, 0.17))
		if hang:
			b = Basis(Vector3.RIGHT, PI) * b      # сосульки остриём вниз
		items.append(Transform3D(b, Vector3(x, gem_y, CROSSBAR_Z)))
	if bool(look.get("caps", false)):
		for sx in [-1.0, 1.0]:
			items.append(Transform3D(Basis.from_scale(Vector3(0.28, 0.28, 0.28)), Vector3(sx * POST_X, POST_SIZE.y + 0.1, CROSSBAR_Z)))
	if items.is_empty():
		return
	var mesh: Mesh
	match String(look.get("shape", "sphere")):
		"cone":
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 5
			cone.rings = 1
			mesh = cone
		"prism":
			var prism: SphereMesh = SphereMesh.new()   # граненый «алмаз»: сфера из 4 граней и 2 колец
			prism.radius = 0.5
			prism.height = 1.0
			prism.radial_segments = 4
			prism.rings = 2
			mesh = prism
		_:
			var ball: SphereMesh = SphereMesh.new()
			ball.radius = 0.5
			ball.height = 1.0
			ball.radial_segments = 10
			ball.rings = 5
			mesh = ball
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.albedo_color = Color.html(gem_hex)
	_gem_mat.metallic = 0.3
	_gem_mat.roughness = 0.15
	if bool(look.get("glow", false)):
		_gem_mat.emission_enabled = true
		_gem_mat.emission = _gem_mat.albedo_color
		_gem_mat.emission_energy_multiplier = 1.6
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i])
	_gems = MultiMeshInstance3D.new()
	_gems.name = "Gems"
	_gems.multimesh = mm
	_gems.material_override = _gem_mat
	_gems.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gems)
