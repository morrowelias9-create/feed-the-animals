class_name SlotManager
extends Node3D
## Участок игрока (шаг T11, справочник R1/R3): размещённые звери стоят свободно в загоне
## в 16 местах WorldLayout.slot_position(i). Ограду строит WorldBuilder, соседние загоны пустые.
## - Обновляется по разнице: у неизменившихся зверей AnimalView не пересоздаётся.
## - Место зверя закреплено за uid, пока он размещён; новый зверь занимает самое раннее свободное.
## - Места с i >= Game.total_slots() закрыты тёмной плиткой с замком (всё в двух MultiMeshInstance3D).
## - В загоне зверь не длиннее MAX_DISPLAY_M (крупные ужимаются).
## - Появление зверя: масштаб 0 -> 1 за POP_S. Пока идёт кинематика получения (REVEAL), появление ждёт её конца.
## - Раз в POPUP_EVERY_S над случайным зверем всплывает «+$N» (пул из POPUP_POOL подписей).

const MAX_DISPLAY_M: float = 5.0
const POP_S: float = 0.3
const LOCK_ANIM_S: float = 0.3
const TILE_X: float = 5.0
const TILE_Y: float = 0.05
const TILE_Z: float = 4.6
const POPUP_POOL: int = 8
const POPUP_EVERY_S: float = 2.0
const POPUP_LIFE_S: float = 1.2
const POPUP_RISE_M: float = 1.5
const REVEAL_STATE: String = "REVEAL"  # ThrowController.STATE_REVEAL, без ссылки на класс (тесты с `-s`)

# Части замка: смещение центра и размер (тело, две стойки дужки, перекладина).
const LOCK_PARTS: Array = [
	[Vector3(0.0, 0.35, 0.0), Vector3(0.9, 0.7, 0.5)],
	[Vector3(-0.28, 0.95, 0.0), Vector3(0.14, 0.5, 0.14)],
	[Vector3(0.28, 0.95, 0.0), Vector3(0.14, 0.5, 0.14)],
	[Vector3(0.0, 1.22, 0.0), Vector3(0.7, 0.14, 0.14)],
]

## Нужен, чтобы появление зверя ждало конца кинематики получения (не обязателен).
## Тип Node, а не ThrowController: иначе тесты с `-s` потянут его зависимости-автозагрузки.
var throw_controller: Node

var _game: Node                        # автозагрузка Game из дерева (в тестах с `-s` имя как идентификатор недоступно)
var _views: Dictionary = {}            # uid -> AnimalView
var _slot_of: Dictionary = {}          # uid -> номер места
var _fit: Dictionary = {}              # uid -> масштаб ужатия (<= 1)
var _pop: Dictionary = {}              # uid -> секунд с начала появления
var _pending: Array[int] = []          # звери, появление которых ждёт конца REVEAL
var _done: Array[int] = []             # временный список закончивших появление (без новых объектов в кадре)
var _slot_used: Array[int] = []        # место -> uid или -1
var _initialized: bool = false

var _tiles_mm: MultiMesh
var _lock_mm: MultiMesh
var _lock_vis: Array[float] = []       # 1 плитка видна, 0 скрыта
var _lock_target: Array[float] = []
var _locks_dirty: bool = true

var _popup_nodes: Array[Label3D] = []
var _popup_t: Array[float] = []        # секунд с начала показа, -1 если не активна
var _popup_y: Array[float] = []
var _popup_clock: float = 0.0


func _init() -> void:
	_slot_used.resize(WorldLayout.SLOT_COUNT)
	_slot_used.fill(-1)


func _ready() -> void:
	_game = _autoload("Game")
	_build_locks()
	_build_popups()
	if _game != null:
		_game.inventory_changed.connect(refresh)
		_game.slots_changed.connect(refresh)
	refresh()
	_locks_dirty = false
	_apply_locks()    # сразу, чтобы в первый кадр не торчали единичные кубы


## Автозагрузка из дерева: в тестах с `-s` имена автозагрузок не видны как идентификаторы.
func _autoload(autoload_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(autoload_name)
	return null


func _process(delta: float) -> void:
	_release_pending()
	_update_pops(delta)
	_update_lock_anim(delta)
	_update_popups(delta)
	_popup_clock += delta
	if _popup_clock >= POPUP_EVERY_S:
		_popup_clock = 0.0
		show_income_popup()


# ---------- Публичное ----------

## Приводит загон в соответствие с Game: убирает ушедших, добавляет новых, обновляет замки.
func refresh() -> void:
	if _game == null:
		return
	var placed: Array = _game.placed_animals()
	var alive: Dictionary = {}
	for a in placed:
		alive[int(a["uid"])] = a
	var gone: Array[int] = []
	for uid in _views:
		if not alive.has(uid):
			gone.append(int(uid))
	for uid in gone:
		_despawn(uid)
	for a in placed:
		if not _views.has(int(a["uid"])):
			_spawn(a)
	_update_lock_targets()
	_initialized = true


func view_count() -> int:
	return _views.size()


func view_of(uid: int) -> AnimalView:
	return _views.get(uid) as AnimalView


## Номер места зверя или -1, если его нет в загоне.
func slot_of(uid: int) -> int:
	return int(_slot_of.get(uid, -1))


## Сколько плиток с замком должно быть видно (места за пределами открытых).
func locked_count() -> int:
	var n: int = 0
	for t in _lock_target.size():
		if _lock_target[t] > 0.5:
			n += 1
	return n


func active_popups() -> int:
	var n: int = 0
	for t in _popup_t:
		if t >= 0.0:
			n += 1
	return n


## Масштаб зверя в загоне: крупные ужимаются до MAX_DISPLAY_M.
static func display_scale(animal_id: String) -> float:
	var size_m: float = float(AnimalData.by_id(animal_id).get("size_m", 1.2))
	if size_m <= MAX_DISPLAY_M:
		return 1.0
	return MAX_DISPLAY_M / size_m


## Показывает «+$N» над случайным зверем. false, если звери не стоят или пул занят.
## Сумма равна доходу зверя за POPUP_EVERY_S без учёта буста.
func show_income_popup() -> bool:
	var candidates: Array[int] = []
	for uid in _views:
		if not _pending.has(int(uid)):
			candidates.append(int(uid))
	if candidates.is_empty():
		return false
	var idx: int = -1
	for i in POPUP_POOL:
		if _popup_t[i] < 0.0:
			idx = i
			break
	if idx == -1:
		return false
	var uid: int = candidates[randi() % candidates.size()]
	var view: AnimalView = _views[uid]
	var scale_k: float = float(_fit.get(uid, 1.0))
	var head: Vector3 = view.position + Vector3(0.0, (view.model_height() + 1.3) * scale_k, 0.0)
	var label: Label3D = _popup_nodes[idx]
	label.text = "+" + NumFmt.money(view.income * POPUP_EVERY_S)
	label.position = head
	label.modulate = Color(UiStyle.COLOR_MONEY, 1.0)
	label.visible = true
	_popup_t[idx] = 0.0
	_popup_y[idx] = head.y
	return true


# ---------- Звери ----------

func _spawn(a: Dictionary) -> void:
	var slot: int = _free_slot()
	if slot == -1:
		push_warning("SlotManager: нет свободного места для зверя")
		return
	var uid: int = int(a["uid"])
	var id: String = String(a["animal_id"])
	var variant: int = VariantData.clamp_variant(int(a.get("variant", 0)))
	var rarity: int = int(AnimalData.by_id(id).get("rarity", 0))
	var view: AnimalView = AnimalView.new()
	view.name = "Pet%d" % uid
	add_child(view)
	view.set_creature(id, variant, rarity, Economy.income(id, variant))
	view.position = WorldLayout.slot_position(slot)
	view.rotation.y = 0.0    # лицом к -Z, к игроку, который ходит перед загонами
	var fit: float = display_scale(id)
	_views[uid] = view
	_slot_of[uid] = slot
	_slot_used[slot] = uid
	_fit[uid] = fit
	if not _initialized:
		view.scale = Vector3.ONE * fit    # при загрузке без анимации
		return
	view.scale = Vector3.ONE * 0.001
	if _reveal_active():
		view.visible = false
		_pending.append(uid)
	else:
		_pop[uid] = 0.0


func _despawn(uid: int) -> void:
	var view: AnimalView = _views.get(uid) as AnimalView
	if view != null:
		remove_child(view)    # сразу убираем из дерева, чтобы узлы не копились до конца кадра
		view.queue_free()
	var slot: int = int(_slot_of.get(uid, -1))
	if slot >= 0 and slot < _slot_used.size():
		_slot_used[slot] = -1
	_views.erase(uid)
	_slot_of.erase(uid)
	_fit.erase(uid)
	_pop.erase(uid)
	_pending.erase(uid)


func _free_slot() -> int:
	for i in _slot_used.size():
		if _slot_used[i] == -1:
			return i
	return -1


func _reveal_active() -> bool:
	return throw_controller != null and String(throw_controller.get("state")) == REVEAL_STATE


func _release_pending() -> void:
	if _pending.is_empty() or _reveal_active():
		return
	for uid in _pending:
		var view: AnimalView = _views.get(uid) as AnimalView
		if view != null:
			view.visible = true
			_pop[uid] = 0.0
	_pending.clear()


func _update_pops(delta: float) -> void:
	if _pop.is_empty():
		return
	_done.clear()
	for uid in _pop:
		var t: float = float(_pop[uid]) + delta
		var view: AnimalView = _views.get(uid) as AnimalView
		if view == null:
			_done.append(int(uid))
			continue
		var k: float = clampf(t / POP_S, 0.0, 1.0)
		view.scale = Vector3.ONE * maxf(float(_fit.get(uid, 1.0)) * _ease_out_back(k), 0.001)
		if k >= 1.0:
			_done.append(int(uid))
		else:
			_pop[uid] = t
	for uid in _done:
		_pop.erase(uid)


# Выскакивание с лёгким перелётом, в конце ровно 1.
static func _ease_out_back(k: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var x: float = k - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x


# ---------- Замки ----------

func _build_locks() -> void:
	var count: int = WorldLayout.SLOT_COUNT - UpgradeData.START_SLOTS
	_lock_vis.resize(count)
	_lock_vis.fill(1.0)
	_lock_target.resize(count)
	_lock_target.fill(1.0)

	var unit: BoxMesh = BoxMesh.new()
	unit.size = Vector3.ONE

	var tile_mat: StandardMaterial3D = StandardMaterial3D.new()
	tile_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.5)
	tile_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tile_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tiles_mm = _make_multimesh(unit, count, "LockTiles", tile_mat)

	var lock_mat: StandardMaterial3D = StandardMaterial3D.new()
	lock_mat.albedo_color = Color("#D5D8E0")
	lock_mat.roughness = 0.7
	_lock_mm = _make_multimesh(unit, count * LOCK_PARTS.size(), "LockIcons", lock_mat)
	_locks_dirty = true


func _make_multimesh(mesh: Mesh, count: int, node_name: String, mat: Material) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _update_lock_targets() -> void:
	var open_slots: int = int(_game.total_slots()) if _game != null else UpgradeData.START_SLOTS
	for t in _lock_target.size():
		_lock_target[t] = 1.0 if (UpgradeData.START_SLOTS + t) >= open_slots else 0.0
		if not _initialized:
			_lock_vis[t] = _lock_target[t]    # при загрузке без анимации
	_locks_dirty = true


func _update_lock_anim(delta: float) -> void:
	for t in _lock_vis.size():
		if not is_equal_approx(_lock_vis[t], _lock_target[t]):
			_lock_vis[t] = move_toward(_lock_vis[t], _lock_target[t], delta / LOCK_ANIM_S)
			_locks_dirty = true
	if _locks_dirty:
		_locks_dirty = false
		_apply_locks()


func _apply_locks() -> void:
	var parts: int = LOCK_PARTS.size()
	for t in _lock_vis.size():
		var v: float = maxf(_lock_vis[t], 0.0001)
		var base: Vector3 = WorldLayout.slot_position(UpgradeData.START_SLOTS + t)
		_tiles_mm.set_instance_transform(t,
			Transform3D(Basis.from_scale(Vector3(TILE_X, TILE_Y, TILE_Z) * v), base + Vector3(0.0, 0.04, 0.0)))
		for k in parts:
			var part: Array = LOCK_PARTS[k]
			var offset: Vector3 = (part[0] as Vector3) * v
			var size: Vector3 = (part[1] as Vector3) * v
			_lock_mm.set_instance_transform(t * parts + k,
				Transform3D(Basis.from_scale(size), base + Vector3(0.0, 0.04, 0.0) + offset))


# ---------- «+$N» ----------

func _build_popups() -> void:
	for i in POPUP_POOL:
		var l: Label3D = Label3D.new()
		l.name = "IncomePopup%d" % i
		l.font_size = 18
		l.outline_size = 6
		l.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.no_depth_test = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible = false
		add_child(l)
		_popup_nodes.append(l)
		_popup_t.append(-1.0)
		_popup_y.append(0.0)


func _update_popups(delta: float) -> void:
	for i in _popup_nodes.size():
		if _popup_t[i] < 0.0:
			continue
		var t: float = _popup_t[i] + delta
		var label: Label3D = _popup_nodes[i]
		if t >= POPUP_LIFE_S:
			_popup_t[i] = -1.0
			label.visible = false
			continue
		_popup_t[i] = t
		var k: float = t / POPUP_LIFE_S
		label.position.y = _popup_y[i] + POPUP_RISE_M * smoothstep(0.0, 1.0, k)
		var fade: float = 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
		label.modulate.a = fade
