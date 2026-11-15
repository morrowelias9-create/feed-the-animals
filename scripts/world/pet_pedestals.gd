class_name PetPedestals
extends Node3D
## T53: аллея наград — пять постаментов питомцев справа от двора.
## Постамент это один цилиндр и одна модель зверя: закрытый показывает тёмный силуэт,
## открытый — обычную модель без мутаций. Подписи Label3D создаются один раз.
## Игрок подходит на 3 м и нажимает действие, чтобы взять питомца; активен только один питомец.
## Новых узлов в _process нет: там только поиск ближайшего постамента и подсказка.

const BASE_RADIUS: float = 0.78
const BASE_TOP_RADIUS: float = 0.62
const BASE_H: float = 0.8
const MODEL_Y: float = BASE_H
const LABEL_Y: float = 2.05
const HINT_Y: float = 2.55
const TOAST_Y: float = 3.0
const BURST_TOP_Y: float = 1.15

const LABEL_FONT: int = 54
const LABEL_PIXEL: float = 0.006
const HINT_FONT: int = 48
const HINT_PIXEL: float = 0.0055
const TOAST_FONT: int = 54
const TOAST_PIXEL: float = 0.006

const BASE_COLOR := Color("#6E6252")
const SILHOUETTE_COLOR := Color("#2A2A2E")
const GOLD_TEXT := Color("#FFD23F")

const BURST_AMOUNT: int = 26
const BURST_LIFE: float = 1.1

var player: Player

var _labels: Array[Label3D] = []
var _models: Array[Node3D] = []
var _model_materials: Array = []       # для каждого постамента: материалы обычной модели
var _hint: Label3D
var _toast: Label3D
var _burst: CPUParticles3D
var _silhouette_mat: StandardMaterial3D
var _toast_tween: Tween
var _near: int = -1


func _ready() -> void:
	_build()
	Game.pet_unlocked.connect(_on_pet_unlocked)
	Game.pet_active_changed.connect(_on_pet_active_changed)
	# Прогресс закрытого постамента меняется при каждом новом звере, а не только при открытии питомца.
	Game.inventory_changed.connect(_refresh_labels)
	Loc.language_changed.connect(_refresh_labels)
	_refresh_labels()


func _process(_delta: float) -> void:
	_update_hint()


## true, если игрок рядом с открытым постаментом и действие уже использовано (бросок не начинать).
func try_activate() -> bool:
	if player == null:
		return false
	var index: int = _nearby_index()
	if index < 0 or not Game.is_pet_unlocked(index):
		return false
	var pet: Dictionary = PetData.by_zone(index)
	if pet.is_empty():
		return false
	var pet_id: String = String(pet["id"])
	if Game.active_pet_id() != pet_id:
		Game.set_active_pet(pet_id)
	return true


# ---------- Постройка ----------

func _build() -> void:
	_silhouette_mat = StandardMaterial3D.new()
	_silhouette_mat.albedo_color = SILHOUETTE_COLOR
	_silhouette_mat.roughness = 1.0
	_silhouette_mat.metallic = 0.0

	for i in PetData.count():
		var root := Node3D.new()
		root.name = "PetPedestal_%d" % i
		root.position = WorldLayout.pet_pedestal_position(i)
		add_child(root)

		_add_base(root)
		var pet: Dictionary = PetData.by_zone(i)
		var model: Node3D = ModelLoader.get_animal(String(pet["model_animal"]), PetData.VARIANT)
		model.name = "Pet"
		# Обёртка задаёт высоту по пояс и стоит на крышке постамента: масштаб модели
		# уже подогнан под размер зверя, поэтому уменьшаем всю обёртку целиком.
		var holder := Node3D.new()
		holder.name = "PetHolder"
		holder.position = Vector3(0.0, MODEL_Y, 0.0)
		holder.scale = Vector3.ONE * (PetData.HEIGHT_M / maxf(ModelLoader.height_of(model), 0.001))
		holder.add_child(model)
		root.add_child(holder)
		_models.append(holder)
		_model_materials.append(_materials_of(holder))

		var label: Label3D = _make_label("Label", LABEL_FONT, LABEL_PIXEL)
		label.position = Vector3(0.0, LABEL_Y, 0.0)
		root.add_child(label)
		_labels.append(label)

	_hint = _make_label("Hint", HINT_FONT, HINT_PIXEL, GOLD_TEXT)
	_hint.visible = false
	_hint.text = Loc.t("pet_take")
	add_child(_hint)

	_toast = _make_label("Toast", TOAST_FONT, TOAST_PIXEL, GOLD_TEXT)
	_toast.visible = false
	add_child(_toast)

	_burst = _make_burst()
	add_child(_burst)


func _add_base(root: Node3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = BASE_TOP_RADIUS
	mesh.bottom_radius = BASE_RADIUS
	mesh.height = BASE_H
	mesh.radial_segments = 24
	mesh.rings = 1
	var inst := MeshInstance3D.new()
	inst.name = "Base"
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BASE_COLOR
	mat.roughness = 0.9
	inst.material_override = mat
	inst.position = Vector3(0.0, BASE_H / 2.0, 0.0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


func _make_label(node_name: String, font_size: int, pixel_size: float, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	UiStyle.apply_font_3d(label)
	label.name = node_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 12
	label.outline_modulate = Color.BLACK
	label.modulate = color
	label.shaded = false
	label.double_sided = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.render_priority = 2
	label.outline_render_priority = 1
	return label


func _make_burst() -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.name = "GoldBurst"
	burst.one_shot = true
	burst.emitting = false
	burst.amount = BURST_AMOUNT
	burst.lifetime = BURST_LIFE
	burst.lifetime_randomness = 0.35
	burst.explosiveness = 0.95
	burst.randomness = 0.8
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.45
	burst.direction = Vector3.UP
	burst.spread = 65.0
	burst.gravity = Vector3(0.0, -3.5, 0.0)
	burst.initial_velocity_min = 1.6
	burst.initial_velocity_max = 3.4
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = GOLD_TEXT
	mat.disable_receive_shadows = true
	quad.material = mat
	burst.mesh = quad
	return burst


# ---------- Состояние и подписи ----------

func _refresh_labels() -> void:
	for i in _labels.size():
		var pet: Dictionary = PetData.by_zone(i)
		var unlocked: bool = Game.is_pet_unlocked(i)
		var active: bool = unlocked and Game.active_pet_id() == String(pet["id"])
		var text: String = ""
		if unlocked:
			text = Loc.t(String(pet["name_key"]))
			text += "\n" + _bonus_text(pet)
		else:
			text = Loc.t("pet_locked")
			text += "\n" + Loc.t("pet_progress") % [
				Loc.t(String(ZoneData.ZONES[i]["name_key"])),
				PetLogic.found_in_zone(i), AnimalData.zone_animals(i).size()
			]
		_labels[i].text = text
		_labels[i].modulate = GOLD_TEXT if unlocked else Color(0.72, 0.72, 0.78)
		# Питомец с игроком уходит с постамента и возвращается, когда выбирают другого.
		_models[i].visible = not active
		_apply_model_state(i, unlocked)
	if _hint != null:
		_hint.text = Loc.t("pet_take")


func _bonus_text(pet: Dictionary) -> String:
	var percent: int = int(roundf(float(pet["value"]) * 100.0))
	return Loc.t("pet_bonus_" + String(pet["bonus"])) % percent


func _apply_model_state(index: int, unlocked: bool) -> void:
	var meshes: Array = _mesh_list(_models[index])
	var materials: Array = _model_materials[index]
	for i in mini(meshes.size(), materials.size()):
		(meshes[i] as MeshInstance3D).material_override = materials[i] if unlocked else _silhouette_mat


func _on_pet_unlocked(zone: int, _pet_id: String) -> void:
	if zone < 0 or zone >= _labels.size():
		return
	_refresh_labels()
	_play_unlock(zone)


func _on_pet_active_changed(_pet_id: String) -> void:
	_refresh_labels()


func _update_hint() -> void:
	if _hint == null:
		return
	if player == null:
		_near = -1
		_hint.visible = false
		return
	_near = _nearby_index()
	if _near < 0 or not Game.is_pet_unlocked(_near):
		_hint.visible = false
		return
	_hint.text = Loc.t("pet_take")
	_hint.visible = true
	_hint.position = WorldLayout.pet_pedestal_position(_near) + Vector3(0.0, HINT_Y, 0.0)

func _play_unlock(zone: int) -> void:
	var at: Vector3 = WorldLayout.pet_pedestal_position(zone)
	_burst.position = at + Vector3(0.0, BURST_TOP_Y, 0.0)
	_burst.restart()
	_toast.text = Loc.t("pet_unlocked_toast") % Loc.t(String(PetData.by_zone(zone)["name_key"]))
	_toast.position = at + Vector3(0.0, TOAST_Y, 0.0)
	_toast.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.45)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _nearby_index() -> int:
	if player == null:
		return -1
	var p: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	var best: int = -1
	var best_d: float = WorldLayout.PET_INTERACT_RADIUS
	for i in PetData.count():
		var at: Vector3 = WorldLayout.pet_pedestal_position(i)
		var d: float = p.distance_to(Vector2(at.x, at.z))
		if d <= best_d:
			best_d = d
			best = i
	return best


func _mesh_list(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_mesh_list(child))
	return result


func _materials_of(node: Node3D) -> Array:
	var result: Array = []
	for mi in _mesh_list(node):
		result.append((mi as MeshInstance3D).material_override)
	return result
