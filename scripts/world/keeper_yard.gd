class_name KeeperYard
extends Node3D
## Загон Хранителя зверей (T54): показательный сосед в Лесу, пока игрок не долетел до Саванны.
## Занимает левый соседний участок (WorldLayout.KEEPER_PLOT). Звери гуляют по загону, над Хранителем
## речевой пузырь с репликами (как в комиксах). Состав и доход берутся из KeeperLogic.
## Всё создаётся один раз в _ready; в _process нет создания узлов и объектов, кроме редких событий.

const PUFF_COLOR := Color("#FFE066")
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
var _puff: CPUParticles3D
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
	_build_puff()
	Loc.language_changed.connect(_refresh_texts)
	_refresh_texts()


func _process(delta: float) -> void:
	if _leaving:
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


# Облачко прощания создаётся заранее и лежит выключенным: в момент ухода только запускается.
func _build_puff() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = mat
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	_puff = CPUParticles3D.new()
	_puff.name = "Puff"
	_puff.emitting = false
	_puff.one_shot = true
	_puff.explosiveness = 0.95
	_puff.amount = 60
	_puff.lifetime = 1.0
	_puff.direction = Vector3.UP
	_puff.spread = 180.0
	_puff.gravity = Vector3(0.0, -3.0, 0.0)
	_puff.initial_velocity_min = 3.0
	_puff.initial_velocity_max = 9.0
	_puff.scale_amount_min = 0.7
	_puff.scale_amount_max = 1.8
	_puff.scale_amount_curve = shrink
	_puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puff.emission_sphere_radius = 1.0
	_puff.mesh = sphere
	_puff.color = PUFF_COLOR
	add_child(_puff)


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

# Аккуратный уход: звери и Хранитель сжимаются, облачко, плашка, флаг в сохранении, потом узел удаляется.
func _leave() -> void:
	_leaving = true
	Save.data["keeper_gone"] = true
	Save.save_data()
	Game.notice.emit("notice_keeper_farewell", [])
	_kill_tween()
	_bubble.visible = false
	_puff.global_position = _root.global_position + Vector3(0.0, 1.2, 0.0)
	_puff.restart()
	_puff.emitting = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_root, "scale", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for view in _views:
		if is_instance_valid(view):
			tween.tween_property(view, "scale", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_callback(queue_free)
