class_name AnimalView
extends Node3D
## Модель зверя + подписи над головой (шаг T10, справочник R4/R6/R8).

const GOLD_COLOR: Color = Color("#FFC83D")

var _id: String = ""
var _model: Node3D
var _height: float = 0.0
var _gold: bool = false
var _rarity: int = 0
var _income: float = 0.0
var _behavior: String = "idle"
var _target: Vector3 = Vector3.ZERO
var _run_t: float = 0.0
var _run_dur: float = 0.0

var _label_gold: Label3D
var _label_name: Label3D
var _label_income: Label3D


func _ready() -> void:
	_label_gold = _make_label("SignGold", Loc.t("gold"), 12, GOLD_COLOR, _height + 1.0)
	_label_name = _make_label("SignName", "", 14, AnimalData.rarity_color(0), _height + 0.55)
	_label_income = _make_label("SignIncome", "", 12, Color("#55E05A"), _height + 0.12)


## Модель + подписи: что зверь, золотой ли он, его редкость и доход.
func set_creature(id: String, gold: bool, rarity: int, income: float) -> void:
	_id = id
	_gold = gold
	_rarity = rarity
	_income = income
	_model = ModelLoader.get_animal(id)
	_model.name = "Model"
	if not is_ancestor_of(_model):
		add_child(_model)
	_height = _measure_height()
	_apply_gold()
	_update_labels()


func idle() -> void:
	_behavior = "idle"


func run_to(target: Vector3, duration: float) -> void:
	if _behavior != "run_to":
		_behavior = "run_to"
		_target = target
		_run_t = 0.0
		_run_dur = duration


func eat() -> void:
	_behavior = "eat"


func _process(delta: float) -> void:
	if _behavior == "run_to":
		_run_t += delta
		var k: float = clampf(_run_t / maxf(_run_dur, 0.001), 0.0, 1.0)
		global_position = global_position.lerp(_target, k)
		var d: Vector3 = _target - global_position
		if d.length() > 0.001:
			rotation.y = atan2(-d.x, -d.z)
		if _run_t >= _run_dur:
			_behavior = "idle"


func _make_label(node_name: String, text: String, font_size: int, color: Color, y: float) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.text = text
	l.font_size = font_size
	l.modulate = color
	l.billboard = 1  # BillboardMode: Enabled (1) — надпись всегда повёрнута к камере
	l.fixed_size = true
	l.no_depth_test = true
	l.position = Vector3(0.0, y, 0.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.outline_size = 4
	add_child(l)
	return l


func _update_labels() -> void:
	_label_gold.text = Loc.t("gold") if _gold else ""
	_label_gold.visible = _gold
	_label_name.text = Loc.t("animal_" + _id)
	_label_name.modulate = AnimalData.rarity_color(_rarity)
	_label_income.text = NumFmt.money(_income) + "/s"
	_label_gold.position = Vector3(0.0, _height + 1.0, 0.0)
	_label_name.position = Vector3(0.0, _height + 0.55, 0.0)
	_label_income.position = Vector3(0.0, _height + 0.12, 0.0)


func _measure_height() -> float:
	var bounds: Array = []
	_scan_bounds(_model, bounds)
	if bounds.is_empty():
		return 0.0
	var lo: Vector3 = bounds[0]
	var hi: Vector3 = bounds[0]
	for v in bounds:
		lo = lo.min(v)
		hi = hi.max(v)
	return hi.y - lo.y


func _scan_bounds(node: Node3D, acc: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			var aabb: AABB = (mi.mesh as Mesh).get_aabb()
			var g: Transform3D = mi.global_transform
			acc.append(g * aabb.position)
			acc.append(g * (aabb.position + aabb.size))
		if c is Node3D:
			_scan_bounds(c as Node3D, acc)


func _apply_gold() -> void:
	var mi: MeshInstance3D = _find_mesh(_model)
	if mi == null:
		return
	var mat: Material = mi.material_override
	var copy: Material = mat.duplicate() if mat != null else StandardMaterial3D.new()
	var std: StandardMaterial3D = copy as StandardMaterial3D
	std.albedo_color = GOLD_COLOR
	std.emission_enabled = true
	std.emission = GOLD_COLOR
	std.emission_energy_multiplier = 1.5
	mi.material_override = std


func _find_mesh(node: Node) -> MeshInstance3D:
	for c in node.get_children():
		if c is MeshInstance3D:
			return c as MeshInstance3D
		if c is Node3D:
			var found: MeshInstance3D = _find_mesh(c as Node3D)
			if found != null:
				return found
	return null
