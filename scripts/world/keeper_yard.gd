class_name KeeperYard
extends Node3D
## Загон Хранителя зверей (T54): показательный сосед в Лесу, пока игрок не долетел до Саванны.
## Занимает левый соседний участок (WorldLayout.KEEPER_PLOT). Звери гуляют по загону, над Хранителем
## речевой пузырь с репликами (как в комиксах). Состав и доход берутся из KeeperLogic.
## Уход: звери по очереди, потом Хранитель рассыпаются цветной пылью, которую уносит вбок и вверх (около 5 секунд).
## Всё создаётся один раз в _ready; в _process нет создания узлов и объектов, кроме редких событий.

const INK := Color("#2B2B2B")                      # цвет контура и текста пузыря
const BUBBLE_LAYER: int = 11                       # над миром, ниже окон и экрана награды
const BUBBLE_W: float = 190.0                      # ширина текста внутри пузыря (небольшое облачко)
const BUBBLE_FONT: int = 17
const BUBBLE_TAIL_H: float = 14.0
const BUBBLE_ANCHOR_Y: float = 3.2                 # высота хвостика над землёй, м (над именем Хранителя)

## Задаёт main.gd: игрок нужен для реплик и чтобы Хранитель уходил, пока игрок во дворе.
var player: Node3D = null

var _root: Node3D                       # персонаж Хранителя и его подписи
var _views: Array[AnimalView] = []
var _wait: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _name_label: Label3D
var _income_label: Label3D
var _income_total: float = 0.0
var _poll_t: float = 0.0
var _talk_left: float = 0.0
var _line: int = 0
var _near: bool = false
var _leaving: bool = false
var _wander_rect: Rect2

var _bubble_layer: CanvasLayer
var _bubble: Control                    # корень: точка (0, 0) это кончик хвостика
var _bubble_panel: PanelContainer
var _bubble_label: Label
var _bubble_tween: Tween

# Состояние ухода: параллельные массивы по участникам (звери в случайном порядке, Хранитель последним).
var _leave_t: float = 0.0
var _leave_nodes: Array[Node3D] = []
var _leave_base: Array[Vector3] = []              # исходный масштаб
var _leave_start: Array[float] = []
var _leave_dur: Array[float] = []
var _leave_dust: Array[CPUParticles3D] = []
var _leave_phase: Array[int] = []                 # 0 ждёт, 1 рассыпается, 2 готов
var _leave_bubble_hidden: bool = false


func _ready() -> void:
	name = "KeeperYard"
	if KeeperLogic.is_gone():
		# Игрок уже был в Саванне (старое сохранение): тихо убираемся и запоминаем.
		Save.data["keeper_gone"] = true
		set_process(false)   # узел ещё живёт до конца кадра, а строить в нём нечего
		queue_free()
		return
	_rng.seed = 54
	var plot: Rect2 = WorldLayout.plot_rect(WorldLayout.KEEPER_PLOT)
	var m: float = KeeperData.WANDER_EDGE_MARGIN
	_wander_rect = Rect2(plot.position + Vector2(m, m), plot.size - Vector2(m, m) * 2.0)
	var pen: Array[Dictionary] = KeeperLogic.build_pen()
	_income_total = KeeperLogic.pen_income(pen)
	_build_keeper()
	_build_pen(pen)
	_build_labels()
	_build_bubble()
	Loc.language_changed.connect(_refresh_texts)
	_refresh_texts()


func _process(delta: float) -> void:
	if _leaving:
		_update_leave(delta)
		return
	_wander(delta)
	if _talk_left > 0.0:
		_talk_left -= delta
		if _talk_left <= 0.0:
			_hide_bubble()
	if _bubble.visible:
		_update_bubble()
	_poll_t += delta
	if _poll_t < KeeperData.POLL_S:
		return
	_poll_t = 0.0
	if KeeperLogic.is_gone():
		# Уходим, когда игрок вернулся во двор (не у линии броска и не в полёте).
		if player == null or player.global_position.z > KeeperData.LEAVE_MIN_Z:
			_leave()
		return
	_check_talk()


# ---------- построение ----------

# Хранитель: человечек как у игрока (Avatar), смотрит в сторону игрока.
func _build_keeper() -> void:
	_root = Node3D.new()
	_root.name = "Keeper"
	_root.position = WorldLayout.keeper_position()
	var dir: Vector3 = WorldLayout.spawn_position() - _root.position
	_root.rotation.y = atan2(-dir.x, -dir.z)
	add_child(_root)
	var avatar := Avatar.new()
	avatar.name = "Avatar"
	_root.add_child(avatar)
	avatar.set_walk(0.0)


# Звери стоят на местах как в загоне игрока (колонки и ряды WorldLayout), потом гуляют.
func _build_pen(pen: Array[Dictionary]) -> void:
	var cx: float = WorldLayout.plot_center_x(WorldLayout.KEEPER_PLOT)
	for i in pen.size():
		var entry: Dictionary = pen[i]
		var id: String = String(entry["animal_id"])
		var view := AnimalView.new()
		view.name = "KeeperAnimal_%d" % i
		add_child(view)
		view.position = Vector3(cx + WorldLayout.SLOT_COL_X[i % 4], 0.0, WorldLayout.SLOT_ROW_Z[floori(i / 4.0)])
		view.set_creature(id, int(entry["variant"]), AnimalData.rarity_of(id), KeeperLogic.entry_income(entry))
		# Полная анимация по частям (ноги, хвост, уши, голова) у показательных, лёгкая у остальных: так выходит живо и недорого.
		view.set_part_mode(AnimalBuilder.PART_FULL if bool(entry["showcase"]) else AnimalBuilder.PART_LIGHT)
		view.scale = Vector3.ONE * SizeData.visual_scale(int(entry["size"]))
		view.ensure_ui_labels()
		view.set_signs_visible(bool(entry["showcase"]))   # подписи только у показательных, чтобы не загромождать
		view.update_ui_labels()
		_views.append(view)
		_wait.append(_rng.randf_range(0.3, KeeperData.WANDER_WAIT_MAX))


func _build_labels() -> void:
	_name_label = _make_label("KeeperName", 1.35, Color.WHITE, 2.75)
	_income_label = _make_label("KeeperIncome", 1.0, UiStyle.COLOR_MONEY, 2.35)


func _make_label(label_name: String, size_k: float, color: Color, height: float) -> Label3D:
	var l := Label3D.new()
	UiStyle.apply_font_3d(l)
	l.name = label_name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = AnimalView.LABEL_FONT_SIZE
	l.pixel_size = AnimalView.LABEL_PIXEL_SIZE * size_k
	l.outline_size = AnimalView.LABEL_OUTLINE
	l.outline_modulate = Color.BLACK
	l.modulate = color
	l.shaded = false
	l.double_sided = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	l.render_priority = 2
	l.outline_render_priority = 1
	l.position = Vector3(0.0, height, 0.0)
	_root.add_child(l)
	return l


# Речевой пузырь: белый с чёрным контуром, закруглённый, с хвостиком вниз к Хранителю.
# Рисуется на экране (CanvasLayer) и следует за точкой над головой, поэтому текст всегда чёткий.
func _build_bubble() -> void:
	_bubble_layer = CanvasLayer.new()
	_bubble_layer.name = "BubbleLayer"
	_bubble_layer.layer = BUBBLE_LAYER
	add_child(_bubble_layer)
	_bubble = Control.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_bubble_layer.add_child(_bubble)
	_bubble_panel = PanelContainer.new()
	_bubble_panel.name = "Panel"
	_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.border_color = INK
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0.0, 2.0)
	_bubble_panel.add_theme_stylebox_override("panel", sb)
	_bubble.add_child(_bubble_panel)
	_bubble_label = Label.new()
	_bubble_label.name = "Text"
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.custom_minimum_size = Vector2(BUBBLE_W, 0.0)
	_bubble_label.add_theme_font_size_override("font_size", BUBBLE_FONT)
	_bubble_label.add_theme_color_override("font_color", INK)
	var font: Font = UiStyle.font()
	if font != null:
		_bubble_label.add_theme_font_override("font", font)
	_bubble_panel.add_child(_bubble_label)
	# Хвостик: чёрный треугольник чуть больше белого, белый перекрывает контур панели в месте стыка.
	var tail_edge := Polygon2D.new()
	tail_edge.name = "TailEdge"
	tail_edge.color = INK
	tail_edge.polygon = PackedVector2Array([
		Vector2(-11.0, -BUBBLE_TAIL_H - 2.0), Vector2(11.0, -BUBBLE_TAIL_H - 2.0), Vector2(0.0, 3.0)])
	_bubble.add_child(tail_edge)
	var tail_fill := Polygon2D.new()
	tail_fill.name = "TailFill"
	tail_fill.color = Color.WHITE
	tail_fill.polygon = PackedVector2Array([
		Vector2(-7.0, -BUBBLE_TAIL_H - 5.0), Vector2(7.0, -BUBBLE_TAIL_H - 5.0), Vector2(0.0, -2.0)])
	_bubble.add_child(tail_fill)


func _refresh_texts() -> void:
	if _name_label == null:
		return
	_name_label.text = Loc.t("keeper_name")
	_income_label.text = NumFmt.money(_income_total) + "/s"


# ---------- прогулки зверей ----------

# Каждый зверь по очереди делает короткие шаги по своему загону; пока бежит, ждать не нужно.
func _wander(delta: float) -> void:
	for i in _views.size():
		var view: AnimalView = _views[i]
		if view.is_running():
			continue
		_wait[i] -= delta
		if _wait[i] > 0.0:
			continue
		var target: Vector3 = _hop_target(view.position)
		var speed: float = _rng.randf_range(KeeperData.WANDER_SPEED_MIN, KeeperData.WANDER_SPEED_MAX)
		view.run_to(target, maxf(view.position.distance_to(target) / speed, 0.1))
		_wait[i] = _rng.randf_range(KeeperData.WANDER_WAIT_MIN, KeeperData.WANDER_WAIT_MAX)


# Точка в 2-5 м от зверя в случайную сторону, внутри загона. Если упёрся в границу, идёт в обратную сторону.
func _hop_target(from: Vector3) -> Vector3:
	var angle: float = _rng.randf_range(0.0, TAU)
	var dir := Vector3(cos(angle), 0.0, sin(angle))
	var step: float = _rng.randf_range(KeeperData.WANDER_HOP_MIN, KeeperData.WANDER_HOP_MAX)
	var target: Vector3 = _clamp_to_pen(from + dir * step)
	if from.distance_to(target) < 1.0:
		target = _clamp_to_pen(from - dir * step)
	return target


func _clamp_to_pen(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, _wander_rect.position.x, _wander_rect.end.x),
		0.0,
		clampf(point.z, _wander_rect.position.y, _wander_rect.end.y))


# ---------- реплики ----------

# Реплика, когда игрок подошёл; снова заговорит, если игрок отошёл дальше TALK_RESET_RADIUS.
func _check_talk() -> void:
	if player == null:
		return
	var d: float = player.global_position.distance_to(_root.global_position)
	if d <= KeeperData.TALK_RADIUS and not _near:
		_near = true
		_say(Loc.t(KeeperData.LINE_KEYS[_line % KeeperData.LINE_KEYS.size()]))
		_line += 1
	elif d > KeeperData.TALK_RESET_RADIUS:
		_near = false


func _say(text: String) -> void:
	_bubble_label.text = text
	_bubble_panel.reset_size()
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_bubble.scale = Vector2(0.7, 0.7)
	_kill_tween()
	_bubble_tween = create_tween()
	_bubble_tween.set_parallel(true)
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.15)
	_bubble_tween.tween_property(_bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_talk_left = KeeperData.TALK_SECONDS
	_update_bubble()


func _hide_bubble() -> void:
	_kill_tween()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.25)
	_bubble_tween.tween_callback(func() -> void: _bubble.visible = false)


func _kill_tween() -> void:
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()


# Кончик хвостика следует за точкой над головой Хранителя; пузырь стоит над ним.
func _update_bubble() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var head: Vector3 = _root.global_position + Vector3(0.0, BUBBLE_ANCHOR_Y, 0.0)
	if cam.is_position_behind(head):
		_bubble.position = Vector2(-10000.0, -10000.0)
		return
	_bubble.position = cam.unproject_position(head)
	_bubble_panel.position = Vector2(-_bubble_panel.size.x * 0.5, -_bubble_panel.size.y - BUBBLE_TAIL_H)


# ---------- уход ----------

# Начало ухода: флаг в сохранении, плашка, прощальная реплика над головой и расписание рассыпания.
func _leave() -> void:
	_leaving = true
	_leave_t = 0.0
	Save.data["keeper_gone"] = true
	Save.save_data()
	Game.notice.emit("notice_keeper_farewell", [])
	for view in _views:
		if is_instance_valid(view):
			view.idle()   # звери замирают, пока их очередь рассыпаться
	_say(Loc.t("keeper_farewell_line"))
	_talk_left = 0.0
	_build_leave_schedule()


# Расписание: звери стартуют по очереди в случайном порядке в течение LEAVE_ANIMAL_SPAN_S, Хранитель последним.
# У каждого участника свой источник пыли (создаётся один раз в момент ухода, не по кадрам).
func _build_leave_schedule() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = KeeperData.LEAVE_DUST_RADIUS
	mesh.height = KeeperData.LEAVE_DUST_RADIUS * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.1))
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var order: Array[int] = []
	for i in _views.size():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):   # перемешать (Фишер-Йетс), порядок случайный, но детерминированный
		var j: int = _rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var steps: float = float(maxi(order.size() - 1, 1))
	for pos in order.size():
		var view: AnimalView = _views[order[pos]]
		var start: float = KeeperData.LEAVE_ANIMAL_SPAN_S * float(pos) / steps
		var bounds: AABB = view.model_bounds()
		var center: Vector3 = view.global_transform * bounds.get_center()
		var extents: Vector3 = bounds.size * view.scale * 0.5
		var tint: Color = VariantData.text_color(view.variant) if view.variant != VariantData.NONE else AnimalData.rarity_color(view.rarity)
		_add_leave_entry(view, start, KeeperData.LEAVE_ANIMAL_DUR_S, center, extents, tint.lerp(Color.WHITE, 0.35), mesh, shrink, fade)
	var keeper_extents := Vector3(0.45, 0.95, 0.35)
	_add_leave_entry(_root, KeeperData.LEAVE_KEEPER_START_S, KeeperData.LEAVE_KEEPER_DUR_S,
		_root.global_position + Vector3(0.0, 0.95, 0.0), keeper_extents, Color("#E9F1FF"), mesh, shrink, fade)


func _add_leave_entry(node: Node3D, start: float, dur: float, center: Vector3, extents: Vector3, tint: Color,
		mesh: Mesh, shrink: Curve, fade: Gradient) -> void:
	var k: float = clampf(maxf(extents.x, maxf(extents.y, extents.z)) / 1.2, 0.7, 2.6)   # крупным больше и крупнее пыль
	var dust := CPUParticles3D.new()
	dust.name = "Dust_%d" % _leave_nodes.size()
	dust.emitting = false
	dust.local_coords = false                     # пыль остаётся в мире и улетает, а не едет вместе с узлом
	dust.amount = clampi(int(70.0 * k * k), 50, 220)
	dust.lifetime = KeeperData.LEAVE_DUST_LIFE_S
	dust.explosiveness = 0.0
	dust.randomness = 0.6
	dust.direction = KeeperData.LEAVE_DRIFT.normalized()
	dust.spread = 28.0
	dust.gravity = KeeperData.LEAVE_WIND
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 2.4
	dust.scale_amount_min = 0.5 * k
	dust.scale_amount_max = 1.3 * k
	dust.scale_amount_curve = shrink
	dust.color_ramp = fade
	dust.color = tint
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = extents
	dust.mesh = mesh
	add_child(dust)
	dust.global_position = center
	_leave_nodes.append(node)
	_leave_base.append(node.scale)
	_leave_start.append(start)
	_leave_dur.append(dur)
	_leave_dust.append(dust)
	_leave_phase.append(0)


# Каждый кадр ухода: по расписанию участник начинает рассыпаться (уменьшается, всплывает, сыплет пыль) и пропадает.
func _update_leave(delta: float) -> void:
	_leave_t += delta
	for i in _leave_nodes.size():
		var phase: int = _leave_phase[i]
		if phase >= 2:
			continue
		var node: Node3D = _leave_nodes[i]
		var p: float = clampf((_leave_t - _leave_start[i]) / _leave_dur[i], 0.0, 1.0)
		if phase == 0 and _leave_t >= _leave_start[i]:
			_leave_phase[i] = 1
			_leave_dust[i].emitting = true
		if _leave_t < _leave_start[i]:
			continue
		if p >= 1.0:
			_leave_phase[i] = 2
			_leave_dust[i].emitting = false
			node.visible = false
			continue
		var factor: float = 1.0 - smoothstep(0.1, 1.0, p)
		node.scale = _leave_base[i] * maxf(factor, 0.0001)
		node.position.y = p * KeeperData.LEAVE_LIFT_M
	if not _leave_bubble_hidden and _leave_t >= KeeperData.LEAVE_BUBBLE_HIDE_S:
		_leave_bubble_hidden = true
		_hide_bubble()
	if _bubble.visible:
		_update_bubble()
	if _leave_t >= KeeperData.LEAVE_END_S:
		queue_free()
