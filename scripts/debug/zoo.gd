extends Node3D
## Отладочная сцена «зоопарк» (шаг T24d): все звери с рецептами стоят рядами, можно быстро их осмотреть.
## Запуск: открыть scenes/debug/zoo.tscn и «Запустить текущую сцену» (F6). Игра эту сцену не загружает.
## Звери стоят боком к камере (мордой вправо), камера смотрит вдоль -Z под углом, как в игре.
## Клавиши: 0-5 вариант, [ и ] ступень размера, R покой/бег на месте, T силуэт (всё чёрное на светлом),
## Влево/Вправо следующий зверь, Вверх/Вниз или колесо дистанция, Home обзор всех.
## Подписи только id зверей. Локализация не нужна.

const ROW_SIZE: int = 8
const GAP_M: float = 2.0                  # зазор между зверьми в ряду
const ROW_GAP_M: float = 10.0             # расстояние между рядами (ряды уходят вглубь, к -Z)
const CAM_PITCH_DEG: float = -25.0        # угол камеры; в CameraRig орбита pitch -60..-5, сверь значение при необходимости
const CAM_DIST_MIN: float = 3.0
const CAM_DIST_MAX: float = 90.0
const SIZE_STEP_MULT: float = 1.12        # во сколько раз зверь крупнее за ступень (только для осмотра)
const SIZE_STEP_MAX: int = 8
const SMOOTH: float = 6.0                 # скорость сглаживания камеры
const BG_NORMAL: Color = Color("#CFE6F7")
const BG_SILHOUETTE: Color = Color("#F4F4F4")
const GROUND_NORMAL: Color = Color("#86B36B")
const GROUND_SILHOUETTE: Color = Color("#DDDDDD")

var _views: Array[AnimalView] = []
var _ids: Array[String] = []
var _slots: Array[Vector3] = []
var _focus: int = 0
var _overview: bool = false
var _dist: float = 6.0
var _overview_dist: float = 40.0
var _overview_center: Vector3 = Vector3.ZERO
var _variant: int = 0
var _size_step: int = 0
var _running: bool = false
var _silhouette: bool = false
var _cam: Camera3D
var _cam_focus: Vector3 = Vector3.ZERO
var _cam_dist: float = 6.0
var _env: Environment
var _ground_mat: StandardMaterial3D
var _sil_mat: StandardMaterial3D
var _info: Label


func _ready() -> void:
	_build_environment()
	_build_ground()
	_spawn_animals()
	_build_camera()
	_build_hud()
	_focus_on(0)
	_cam_focus = _focus_point()
	_cam_dist = _dist
	_apply_look()
	_update_info()


func _process(delta: float) -> void:
	if _cam == null:
		return
	var k: float = clampf(delta * SMOOTH, 0.0, 1.0)
	var want_dist: float = _overview_dist if _overview else _dist
	_cam_focus = _cam_focus.lerp(_focus_point(), k)
	_cam_dist = lerpf(_cam_dist, want_dist, k)
	var pitch: float = deg_to_rad(CAM_PITCH_DEG)
	var offset: Vector3 = Vector3(0.0, -sin(pitch), cos(pitch)) * _cam_dist
	_cam.look_at_from_position(_cam_focus + offset, _cam_focus, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_dist(0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_dist(1.14)
		return
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	match ke.keycode:
		KEY_0, KEY_KP_0:
			_set_variant(0)
		KEY_1, KEY_KP_1:
			_set_variant(1)
		KEY_2, KEY_KP_2:
			_set_variant(2)
		KEY_3, KEY_KP_3:
			_set_variant(3)
		KEY_4, KEY_KP_4:
			_set_variant(4)
		KEY_5, KEY_KP_5:
			_set_variant(5)
		KEY_BRACKETLEFT:
			_set_size_step(_size_step - 1)
		KEY_BRACKETRIGHT:
			_set_size_step(_size_step + 1)
		KEY_R:
			_running = not _running
			for view in _views:
				view.set_anim_running(_running)
			_update_info()
		KEY_T:
			_silhouette = not _silhouette
			_apply_look()
			_update_info()
		KEY_LEFT:
			_focus_on(_focus - 1)
		KEY_RIGHT:
			_focus_on(_focus + 1)
		KEY_UP:
			_change_dist(0.88)
		KEY_DOWN:
			_change_dist(1.14)
		KEY_HOME:
			_overview = not _overview
			_update_info()


# ---------- Сборка сцены ----------

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	add_child(sun)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = BG_NORMAL
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("#EAF2FF")
	_env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = _env
	add_child(we)
	_sil_mat = StandardMaterial3D.new()
	_sil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sil_mat.albedo_color = Color.BLACK


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.albedo_color = GROUND_NORMAL
	_ground_mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.material_override = _ground_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _spawn_animals() -> void:
	var row: int = 0
	var col: int = 0
	var cursor_x: float = 0.0
	var prev_half: float = 0.0
	var max_x: float = 0.0
	for a in AnimalData.ANIMALS:
		var id: String = String(a["id"])
		if not AnimalRecipes.has_recipe(id):
			continue
		if col >= ROW_SIZE:
			row += 1
			col = 0
			cursor_x = 0.0
		var size_m: float = float(a["size_m"])
		var half: float = size_m * 0.5
		if col == 0:
			cursor_x = half
		else:
			cursor_x += prev_half + GAP_M + half
		prev_half = half
		max_x = maxf(max_x, cursor_x + half)
		var pos: Vector3 = Vector3(cursor_x, 0.0, -float(row) * ROW_GAP_M)
		var view := AnimalView.new()
		view.name = id
		add_child(view)
		view.position = pos
		view.rotation_degrees = Vector3(0.0, -90.0, 0.0)   # мордой вправо, боком к камере
		view.set_creature(id, 0, AnimalData.rarity_of(id), 0.0)
		view.set_signs_visible(false)
		_views.append(view)
		_ids.append(id)
		_slots.append(pos)
		_add_id_label(id, pos + Vector3(0.0, 0.25, size_m * 0.25 + 0.8))
		col += 1
	var rows: int = row + 1
	_overview_center = Vector3(max_x * 0.5, 1.0, -float(rows - 1) * ROW_GAP_M * 0.5)
	_overview_dist = clampf(max_x * 0.7 + float(rows - 1) * ROW_GAP_M * 0.5, 12.0, CAM_DIST_MAX)


func _add_id_label(id: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.name = "Id_" + id
	l.text = id
	l.font_size = 48
	l.pixel_size = 0.008
	l.modulate = Color("#1A1A1A")
	l.outline_modulate = Color.WHITE
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov = CameraRig.FOV
	_cam.current = true
	add_child(_cam)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(12.0, 8.0)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_color_override("font_color", Color("#1A1A1A"))
	_info.add_theme_color_override("font_outline_color", Color.WHITE)
	_info.add_theme_constant_override("outline_size", 5)
	layer.add_child(_info)


# ---------- Действия ----------

func _focus_on(index: int) -> void:
	if _views.is_empty():
		return
	_focus = posmod(index, _views.size())
	_overview = false
	var size_m: float = float(AnimalData.by_id(_ids[_focus]).get("size_m", 1.2))
	_dist = clampf(size_m * 2.0 * _view_scale(), 4.0, 24.0)
	_update_info()


func _focus_point() -> Vector3:
	if _views.is_empty():
		return Vector3.ZERO
	if _overview:
		return _overview_center
	var view: AnimalView = _views[_focus]
	return _slots[_focus] + Vector3(0.0, view.model_height() * view.scale.y * 0.45, 0.0)


func _change_dist(factor: float) -> void:
	if _overview:
		_overview_dist = clampf(_overview_dist * factor, CAM_DIST_MIN, CAM_DIST_MAX)
	else:
		_dist = clampf(_dist * factor, CAM_DIST_MIN, CAM_DIST_MAX)


func _view_scale() -> float:
	return pow(SIZE_STEP_MULT, float(_size_step))


func _set_variant(v: int) -> void:
	_variant = v
	for view in _views:
		view.set_variant(v, 0.0)
	_apply_look()
	_update_info()


func _set_size_step(step: int) -> void:
	_size_step = clampi(step, 0, SIZE_STEP_MAX)
	var s: float = _view_scale()
	for view in _views:
		view.scale = Vector3(s, s, s)
	_focus_on(_focus)


# Силуэт или обычный вид: фон, земля и материалы зверей. set_variant возвращает материал варианта, поэтому
# после смены варианта вид применяется заново.
func _apply_look() -> void:
	_env.background_color = BG_SILHOUETTE if _silhouette else BG_NORMAL
	_ground_mat.albedo_color = GROUND_SILHOUETTE if _silhouette else GROUND_NORMAL
	_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if _silhouette else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for view in _views:
		var fx: Node3D = view.get_node_or_null("VariantFx") as Node3D
		if fx != null:
			fx.visible = not _silhouette
		var model: Node3D = view.get_node_or_null("Model") as Node3D
		if model == null:
			continue
		if _silhouette:
			for mi in _mesh_instances(model):
				mi.material_override = _sil_mat
		else:
			ModelLoader.apply_variant(model, _variant)


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	for c in node.get_children():
		if c is MeshInstance3D:
			list.append(c as MeshInstance3D)
		list.append_array(_mesh_instances(c))
	return list


func _update_info() -> void:
	if _info == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	var who: String = "overview" if _overview else "%s [%d/%d]" % [_ids[_focus], _focus + 1, _ids.size()]
	var mutation: String = String(VariantData.VARIANTS[_variant]["id"])
	lines.append("zoo T24d   view: %s   variant: %d %s   size step: %d   motion: %s   silhouette: %s" % [
		who, _variant, mutation, _size_step, "run" if _running else "rest", "on" if _silhouette else "off"])
	lines.append("0-5 variant | [ ] size | R rest/run | T silhouette | Left/Right animal | Up/Down, wheel zoom | Home overview")
	var text: String = "\n".join(lines)
	_info.text = text
