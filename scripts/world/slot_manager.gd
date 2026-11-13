class_name SlotManager
extends Node3D
## Участок игрока (шаг T11, справочник R1/R3): размещённые звери стоят свободно в загоне
## в 16 местах WorldLayout.slot_position(i). Ограду строит WorldBuilder, соседние загоны пустые.
## - Обновляется по разнице: у неизменившихся зверей AnimalView не пересоздаётся.
## - Место зверя закреплено за uid, пока он размещён; новый зверь занимает самое раннее свободное.
## - В загоне зверь не длиннее MAX_DISPLAY_M (крупные ужимаются).
## - Появление зверя: масштаб 0 -> 1 за POP_S. Пока идёт кинематика получения (REVEAL), появление ждёт её конца.
## - Раз в POPUP_EVERY_S над случайным зверем всплывает «+$N» (пул из POPUP_POOL подписей).

const POP_S: float = 0.3
const POPUP_POOL: int = 8
const POPUP_EVERY_S: float = 2.0
const POPUP_LIFE_S: float = 1.2
const POPUP_RISE_M: float = 1.5
const REVEAL_STATE: String = "REVEAL"  # ThrowController.STATE_REVEAL, без ссылки на класс (тесты с `-s`)

# Части замка: смещение центра и размер (тело, две стойки дужки, перекладина).

## Нужен, чтобы появление зверя ждало конца кинематики получения (не обязателен).
## Тип Node, а не ThrowController: иначе тесты с `-s` потянут его зависимости-автозагрузки.
var throw_controller: Node

var _game: Node                        # автозагрузка Game из дерева (в тестах с `-s` имя как идентификатор недоступно)
var _hud: Node                          # для доступа к CanvasLayer подписей (HUD автозагрузка)
var _camera: Camera3D                  # для проецирования 3D позиций в 2D экранные координаты
var _views: Dictionary = {}            # uid -> AnimalView
var _slot_of: Dictionary = {}          # uid -> номер места
var _fit: Dictionary = {}              # uid -> масштаб зверя
var _pop: Dictionary = {}              # uid -> секунд с начала появления
var _pending: Array[int] = []          # звери, появление которых ждёт конца REVEAL
var _done: Array[int] = []             # временный список закончивших появление (без новых объектов в кадре)
var _slot_used: Array[int] = []        # место -> uid или -1
var _initialized: bool = false


var _popup_nodes: Array[Label3D] = []
var _popup_t: Array[float] = []        # секунд с начала показа, -1 если не активна
var _popup_y: Array[float] = []
var _popup_clock: float = 0.0


func _init() -> void:
	_slot_used.resize(WorldLayout.SLOT_COUNT)
	_slot_used.fill(-1)


func _ready() -> void:
	_game = _autoload("Game")
	_build_popups()
	if _game != null:
		_game.inventory_changed.connect(refresh)
		_game.slots_changed.connect(refresh)
	refresh()


## Автозагрузка из дерева: в тестах с `-s` имена автозагрузок не видны как идентификаторы.
func _autoload(autoload_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(autoload_name)
	return null


func _process(delta: float) -> void:
	_release_pending()
	_update_pops(delta)
	_update_popups(delta)
	_popup_clock += delta
	if _popup_clock >= POPUP_EVERY_S:
		_popup_clock = 0.0
		show_income_popup()
	# Обновляем позиции 2D подписей зверей
	if _camera != null:
		for uid in _views:
			var view: AnimalView = _views[uid]
			if view != null and is_instance_valid(view):
				view._update_ui_positions(_camera)


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
		var view: AnimalView = _views.get(int(a["uid"])) as AnimalView
		if view == null:
			continue
		var saved: Array = a.get("pos", [])
		# Гуляющего зверя не трогаем: иначе, когда другой зверь дошёл до цели и сохранился, он прыгнул бы на старое место.
		if saved.size() >= 2 and not view.is_running():
			view.position = Vector3(float(saved[0]), 0.0, float(saved[1]))
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
	return 0


func active_popups() -> int:
	var n: int = 0
	for t in _popup_t:
		if t >= 0.0:
			n += 1
	return n


## Масштаб зверя в загоне: только мутация размера. Базовый размер вида (size_m) уже применил ModelLoader
## при подгонке модели, поэтому умножать на него второй раз нельзя (раньше носорог 3.5 м вырастал до 12 м).
static func display_scale(_animal_id: String, size_step: int = 0) -> float:
	return SizeData.visual_scale(size_step)


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
	var size_step: int = SizeData.clamp_size(int(a.get("size", 0)))
	var rarity: int = AnimalData.rarity_of(id)
	var view: AnimalView = AnimalView.new()
	view.name = "Pet%d" % uid
	add_child(view)
	view.set_creature(id, variant, rarity, Economy.income(id, variant, size_step))
	if _hud != null:
		view.ensure_ui_labels(_hud)
		view.update_ui_labels()
	if GameConfig.PEN_PARTS_ENABLED:
		view.set_part_mode(AnimalBuilder.PART_FULL)   # T24f: звери загона в полном режиме (до 12 мешей на зверя, среднее ~7.4)
	view.position = WorldLayout.slot_position(slot)
	view.rotation.y = 0.0    # лицом к -Z, к игроку, который ходит перед загонами
	var fit: float = display_scale(id, size_step)
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
		view.clear_ui_labels()
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
		var current_scale: float = maxf(float(_fit.get(uid, 1.0)) * _ease_out_back(k), 0.001)
		view.scale = Vector3.ONE * current_scale
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
