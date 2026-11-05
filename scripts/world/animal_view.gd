class_name AnimalView
extends Node3D
## Модель зверя + подпись из трёх строк над головой (шаги T10/T10b, справочник R4/R6/R8):
## вариант (его цветом, мелко), название цветом редкости, доход зелёным.

const SIGN_GAP: Array[float] = [1.0, 0.55, 0.12]   # высота строк над головой: вариант, имя, доход

var animal_id: String = ""
var variant: int = 0
var rarity: int = 0
var income: float = 0.0

var _model: Node3D
var _fx: Node3D
var _height: float = 1.0
var _size_m: float = 1.2
var _signs_visible: bool = true
var _behavior: String = "idle"
var _target: Vector3 = Vector3.ZERO
var _run_t: float = 0.0
var _run_dur: float = 0.0

var _label_variant: Label3D
var _label_name: Label3D
var _label_income: Label3D


func _ready() -> void:
	_ensure_labels()
	_update_labels()


## Модель, подписи и эффекты: что за зверь, какой вариант, редкость и доход.
func set_creature(id: String, new_variant: int, new_rarity: int, new_income: float) -> void:
	_ensure_labels()
	animal_id = id
	variant = VariantData.clamp_variant(new_variant)
	rarity = new_rarity
	income = new_income
	_size_m = float(AnimalData.by_id(id).get("size_m", 1.2))
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = ModelLoader.get_animal(id, variant)
	_model.name = "Model"
	add_child(_model)
	_height = ModelLoader.height_of(_model)
	_rebuild_fx()
	_update_labels()


## Меняет вариант уже стоящего зверя (экран награды: «Удача!» вспыхивает позже появления).
func set_variant(new_variant: int, new_income: float) -> void:
	variant = VariantData.clamp_variant(new_variant)
	income = new_income
	if _model != null:
		ModelLoader.apply_variant(_model, variant)
	_rebuild_fx()
	_update_labels()


func set_signs_visible(on: bool) -> void:
	_signs_visible = on
	_update_labels()


func model_height() -> float:
	return _height


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


func _rebuild_fx() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = ModelLoader.make_variant_fx(variant, _size_m)
	add_child(_fx)


func _ensure_labels() -> void:
	if _label_variant != null:
		return
	_label_variant = _make_label("SignVariant", 12, Color.WHITE)
	_label_name = _make_label("SignName", 14, AnimalData.rarity_color(0))
	_label_income = _make_label("SignIncome", 12, UiStyle.COLOR_MONEY)


func _make_label(node_name: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.font_size = font_size
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # надпись всегда повёрнута к камере
	l.fixed_size = true
	l.no_depth_test = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.outline_size = 4
	add_child(l)
	return l


func _update_labels() -> void:
	if _label_variant == null:
		return
	var has_variant: bool = variant != VariantData.NONE
	_label_variant.visible = _signs_visible and has_variant
	_label_name.visible = _signs_visible
	_label_income.visible = _signs_visible
	if has_variant:
		_label_variant.text = _t(VariantData.name_key(variant))
		_label_variant.modulate = VariantData.text_color(variant)
	else:
		_label_variant.text = ""
	_label_name.text = _t("animal_" + animal_id) if animal_id != "" else ""
	_label_name.modulate = AnimalData.rarity_color(rarity)
	_label_income.text = NumFmt.money(income) + "/s"
	_label_variant.position = Vector3(0.0, _height + SIGN_GAP[0], 0.0)
	_label_name.position = Vector3(0.0, _height + SIGN_GAP[1], 0.0)
	_label_income.position = Vector3(0.0, _height + SIGN_GAP[2], 0.0)


## Перевод через автозагрузку Loc из дерева: в тестах с `-s` имя Loc как идентификатор недоступно.
func _t(key: String) -> String:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var loc: Node = (loop as SceneTree).root.get_node_or_null("Loc")
		if loc != null:
			return String(loc.call("t", key))
	return key
