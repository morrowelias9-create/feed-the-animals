class_name RevealController
extends Node3D
## Кинематика получения зверя (шаг T10c, справочник R2 «Кинематика получения», R3, R6 «Экран награды»).
## Фазы: A «глаза зверя» -> B «сбоку и имя» -> C «итог» -> D «выход». Камерой управляет через CameraRig.set_pose.
## Зверь выбирается в start(), добавляется игроку в начале фазы C. Тап в A или B прыгает сразу к C.

signal finished
signal result_dismissed  # T23: тап «продолжить» в фазе итога (путь А межстраничной рекламы)

enum Phase { NONE, EYES, SIDE, RESULT, EXIT }

const RUN_UP_M: float = 12.0            # стартовая дистанция камеры и зверя от еды
const EYE_END_DIST: float = 1.2         # камера подходит к еде на столько
const EYE_PITCH_FROM: float = -25.0
const EYE_PITCH_TO: float = -40.0
const EYE_FOV_FROM: float = 75.0
const EYE_FOV_TO: float = 68.0
const BOB_AMP_M: float = 0.12           # покачивание шагов по вертикали (для крупных пропорционально размеру)
const ROLL_DEG: float = 3.0
const STEP_HZ: float = 3.0
const SIDE_FOV: float = 68.0
const TO_RESULT_S: float = 0.4          # плавный переход к виду 3/4
const RESULT_AZIMUTH_DEG: float = 35.0
const TAP_LOCK_S: float = 0.25          # после перехода тапы игнорируются
const NAME_HOLD_S: float = 0.3          # пауза после конца печати имени
const EXIT_EAT_S: float = 0.3           # зверь съедает еду
const EXIT_S: float = 0.6               # весь выход
const CAM_X_LIMIT: float = 28.5         # камера не выходит за толщу стен коридора (иначе стена загородит вид)
const FOOD_SPIN: float = 1.0            # рад/с

var throw_controller: ThrowController

var _overlay: RevealOverlay
var _camera_rig: CameraRig
var _phase: Phase = Phase.NONE
var _t: float = 0.0
var _lock_t: float = 0.0
var _hold_t: float = 0.0
var _finished: bool = true
var _flashed: bool = false

var _animal_id: String = ""
var _variant: int = 0
var _size_step: int = 0
var _rarity: int = 0
var _income: float = 0.0
var _size: float = 1.2
var _dist: float = 0.0

var _land: Vector3 = Vector3.ZERO       # точка земли под едой
var _floor_y: float = 0.0
var _dir: Vector3 = Vector3(0.0, 0.0, 1.0)    # куда бежит зверь
var _side: Vector3 = Vector3(-1.0, 0.0, 0.0)  # с какой стороны камера в фазах B и C
var _stop: Vector3 = Vector3.ZERO       # где зверь останавливается
var _run_from: Vector3 = Vector3.ZERO   # откуда он вбегает
var _view: AnimalView
var _food: Node3D

var _cam_pos: Vector3 = Vector3.ZERO
var _cam_target: Vector3 = Vector3.ZERO
var _cam_fov: float = EYE_FOV_TO
var _c_from_pos: Vector3 = Vector3.ZERO
var _c_from_target: Vector3 = Vector3.ZERO
var _c_to_pos: Vector3 = Vector3.ZERO
var _c_to_target: Vector3 = Vector3.ZERO
var _face_from: float = 0.0
var _face_to: float = 0.0

var _luck: int = 0                # SCORE фазы C: очки удачи, дальность * luck еды
var _final_luck: int = 0          # финальное значение SCORE, до которого накручивается
var _final_size: int = 0          # финальная ступень цепочки роста размера (мутация)
var _size_k: int = 0               # текущая ступень в цепочке роста (0 — без мутации)
var _ramp_done: bool = false      # накрутка SCORE закончилась (или показана итог сразу)
var _skip_final: bool = false     # тап во время накрутки: сразу показываем итог
var _next_step_t: float = 0.0     # время следующего шага цепочки роста
var _pop_t: float = -1.0          # поп-эффект вспухания: -1 — тика нет, иначе секунда с начала
var _score_shown: int = 0         # SCORE, который сейчас показывает экран (накрутка от 0)
var _score_ticked: int = 0        # последний SCORE, на который уже был тик звука
var _sound_t: float = 0.0         # накопленная длительность до следующего тика звука


func _ready() -> void:
	_overlay = RevealOverlay.new()
	_overlay.name = "RevealOverlay"
	add_child(_overlay)


## Запуск после приземления: land_pos это точка земли под едой, food это узел еды (лежит и вращается).
## perfect — «Идеально!»: множитель удачи SCORE (1.25), тот же учитывает мутацию размера.
func start(zone: int, dist: float, land_pos: Vector3, food: Node3D, perfect: bool = false) -> void:
	_cleanup()
	_camera_rig = throw_controller.camera_rig if throw_controller != null else null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var history: Array = []
	if Save.data.get("catch_history", []) is Array:
		history = Save.data["catch_history"]
	var roll: Dictionary = SpawnRoller.roll(dist, int(Save.data.get("food_selected", 0)), history, rng, _luck_mult(perfect))
	_animal_id = String(roll["animal_id"])
	if _animal_id.is_empty():
		_animal_id = "frog"
	_variant = int(roll["variant"])
	_size_step = int(roll.get("size", 0))
	var data: Dictionary = AnimalData.by_id(_animal_id)
	_rarity = AnimalData.rank_to_rarity(int(data.get("rank", 1)))
	_size = float(data.get("size_m", 1.2))
	_income = Economy.income(_animal_id, _variant, _size_step)
	_luck = int(roll.get("luck", 0))
	_final_luck = _luck
	_final_size = SizeData.clamp_size(_size_step)
	_dist = dist
	_land = land_pos
	_floor_y = land_pos.y
	_food = food
	_compute_layout()
	_finished = false
	if _camera_rig == null:
		# Без камеры показывать нечего: зверя всё равно получаем.
		Game.add_animal(_animal_id, _variant, _size_step)
		_finish_run()
		return
	_overlay.open()
	_enter_eyes()


func is_finished() -> bool:
	return _finished


## Тап игрока: из A или B сразу к итогу, из итога к выходу. Тапы сразу после перехода игнорируются.
## Во время накрутки SCORE (фаза C) тап сразу показывает итог: финализация без накрутки.
func tap() -> void:
	if _finished or _lock_t > 0.0:
		return
	match _phase:
		Phase.EYES, Phase.SIDE:
			_enter_result()
		Phase.RESULT:
			if not _ramp_done and not _skip_final:
				_skip_to_final()
			# T23: путь А — тап «продолжить» в конце кинематики.
			result_dismissed.emit()
			_enter_exit()


## Тап во время накрутки: показываем итог сразу — без накрутки и без роста размера.
func _skip_to_final() -> void:
	_skip_final = true
	_t = TO_RESULT_S
	_ramp_done = true
	_size_k = _final_size
	_pop_t = -1.0
	_overlay.set_score(int(_final_luck))
	if _view != null:
		if _final_size > 0:
			_view.float_size(_final_size)
		_view.scale = Vector3.ONE * _final_view_scale()


## Масштаб зверя на финальную ступень цепочки роста: мутация > 0 — визуальный масштаб, иначе 1.0.
func _final_view_scale() -> float:
	if _final_size <= 0:
		return 1.0
	return SizeData.visual_scale(_final_size)


## Множитель удачи SCORE: «Идеально!» даёт 1.25, обычный бросок — 1.0.
static func _luck_mult(perfect: bool) -> float:
	return 1.25 if perfect else 1.0


func _process(delta: float) -> void:
	if _phase == Phase.NONE:
		return
	_t += delta
	_lock_t = maxf(_lock_t - delta, 0.0)
	if _food != null and is_instance_valid(_food) and _phase != Phase.EXIT:
		_food.rotation.y += delta * FOOD_SPIN
	match _phase:
		Phase.EYES:
			_update_eyes()
		Phase.SIDE:
			_update_side(delta)
		Phase.RESULT:
			_update_result(delta)
		Phase.EXIT:
			_update_exit()


# ---------- Раскладка сцены ----------

func _compute_layout() -> void:
	# Зверь приходит из глубины коридора к игроку (+Z). Если еда упала на край земли, наоборот: от игрока к обрыву.
	var on_ledge: bool = _land.z > -WorldLayout.LEDGE_D
	_dir = Vector3(0.0, 0.0, -1.0) if on_ledge else Vector3(0.0, 0.0, 1.0)
	# Камера сбоку так, чтобы зверь бежал по экрану слева направо.
	_side = _dir.cross(Vector3.UP).normalized()
	_stop = _land - _side * (0.25 * _size + 0.3) - _dir * (0.5 * _size + 0.2)
	_stop.y = _floor_y
	_run_from = _stop - _dir * (4.5 * _size + 3.0)
	_run_from.y = _floor_y


# ---------- Фаза A: глаза зверя ----------

func _enter_eyes() -> void:
	_phase = Phase.EYES
	_t = 0.0
	_lock_t = TAP_LOCK_S
	_update_eyes()


func _update_eyes() -> void:
	var u: float = clampf(_t / GameConfig.REVEAL_EYES_S, 0.0, 1.0)
	var k: float = 1.0 - (1.0 - u) * (1.0 - u)    # ease_out
	var d: float = lerpf(RUN_UP_M, EYE_END_DIST, k)
	var eye: float = maxf(0.35, 0.45 * _size)
	var amp: float = BOB_AMP_M * maxf(1.0, _size / 1.2)
	var pos: Vector3 = _land - _dir * d
	pos.y = _floor_y + eye + sin(TAU * STEP_HZ * _t) * amp
	var pitch: float = deg_to_rad(lerpf(EYE_PITCH_FROM, EYE_PITCH_TO, u))
	var forward: Vector3 = Vector3(_dir.x * cos(pitch), sin(pitch), _dir.z * cos(pitch))
	var roll: float = sin(TAU * STEP_HZ * 0.5 * _t) * ROLL_DEG
	_set_pose(pos, pos + forward * 5.0, lerpf(EYE_FOV_FROM, EYE_FOV_TO, u), roll)
	if _t >= GameConfig.REVEAL_EYES_S:
		_enter_side()


# ---------- Фаза B: сбоку и имя ----------

func _enter_side() -> void:
	_phase = Phase.SIDE
	_t = 0.0
	_hold_t = 0.0
	_lock_t = TAP_LOCK_S
	_spawn_view(_run_from)
	_overlay.begin_typing(Loc.t("animal_" + _animal_id), GameConfig.REVEAL_LETTER_S)
	if _view != null:
		_view.set_anim_running(true)   # включаем анимацию бега (ноги, хвост, части)
	_update_side(0.0)


func _update_side(delta: float) -> void:
	var u: float = clampf(_t / GameConfig.REVEAL_SIDE_S, 0.0, 1.0)
	var k: float = 1.0 - (1.0 - u) * (1.0 - u)
	var p: Vector3 = _run_from.lerp(_stop, k)
	p.y = _floor_y + 0.06 * _size * absf(sin(TAU * STEP_HZ * _t)) * (1.0 - u)   # подскоки на бегу
	_view.position = p
	var cam_h: float = maxf(0.3, 0.5 * _size)
	var pos: Vector3 = _land + _side * _side_distance(3.2 * _size)
	pos.y = _floor_y + cam_h
	var target: Vector3 = (_land + _stop) * 0.5
	target.y = pos.y
	_set_pose(pos, target, SIDE_FOV, 0.0)
	if _t >= GameConfig.REVEAL_SIDE_S and _overlay.typing_done():
		_hold_t += delta
		if _hold_t >= NAME_HOLD_S:
			_enter_result()


# Дальность камеры сбоку, ограниченная стенами коридора по оси X.
func _side_distance(wanted: float) -> float:
	var room: float = CAM_X_LIMIT - _side.x * _land.x
	return maxf(minf(wanted, room), 1.5)


# ---------- Фаза C: итог ----------

func _enter_result() -> void:
	_phase = Phase.RESULT
	_t = 0.0
	_lock_t = TAP_LOCK_S
	_score_shown = 0
	_score_ticked = 0
	_sound_t = 0.0
	_next_step_t = 0.0
	if _view == null:
		_spawn_view(_stop)
	_view.position = _stop
	if _view != null:
		_view.set_anim_running(false)   # останавливаем анимацию бега, зверь стоит на месте
	_overlay.skip_typing()
	_overlay.hide_typing()
	Game.add_animal(_animal_id, _variant, _size_step)
	_view.set_variant(_variant, _income)
	var lucky: bool = _final_size > 0 or _variant != VariantData.NONE or _rarity >= 3
	if _variant != VariantData.NONE:
		_overlay.flash(0.6)
	_overlay.show_result({
		"score": int(_final_luck),
		"variant": _variant,
		"name": Loc.t("animal_" + _animal_id),
		"rarity": _rarity,
		"income": _income,
		"lucky": lucky,
		"size_step": _final_size,
	})
	# Вид 3/4 спереди: камера впереди зверя и сбоку, зверь поворачивается к ней.
	var az: float = deg_to_rad(RESULT_AZIMUTH_DEG)
	var cdir: Vector3 = _side * cos(az) + _dir * sin(az)
	var dc: float = 4.0 * _size
	if absf(cdir.x) > 0.01:
		var limit_x: float = CAM_X_LIMIT if cdir.x > 0.0 else -CAM_X_LIMIT
		dc = minf(dc, (limit_x - _stop.x) / cdir.x)
	dc = maxf(dc, 1.5)
	_c_to_pos = _stop + cdir * dc
	_c_to_pos.y = _floor_y + 0.6 * _size
	_c_to_target = _stop.lerp(_land, 0.35)
	_c_to_target.y = _floor_y + 0.45 * _size
	_c_from_pos = _cam_pos
	_c_from_target = _cam_target
	_face_from = _view.rotation.y
	_face_to = _yaw_of(cdir)


func _update_result(delta: float) -> void:
	var k: float = smoothstep(0.0, 1.0, clampf(_t / TO_RESULT_S, 0.0, 1.0))
	_set_pose(_c_from_pos.lerp(_c_to_pos, k), _c_from_target.lerp(_c_to_target, k), SIDE_FOV, 0.0)
	_view.rotation.y = lerp_angle(_face_from, _face_to, k)
	_update_score(delta)
	_update_size(delta)
	if _t >= GameConfig.REVEAL_AUTO_S:
		_enter_exit()


## Накрутка SCORE: от 0 до _final_luck за REVEAL_SCORE_S с ease_out, тик звука type ≤ 15/с.
func _update_score(delta: float) -> void:
	var score_now: int = int(_final_luck) if _skip_final else _overlay.score_at(_t)
	_sound_t += delta
	if score_now > _score_ticked and _sound_t >= GameConfig.REVEAL_SCORE_TICK_S:
		_sound_t = 0.0
		_score_ticked = score_now
		# SoundBank.play("type") — тик нарастания SCORE (R2, T11b; проигрывание — T26).
	if score_now != _score_shown:
		_score_shown = score_now
	if not _skip_final and _t >= GameConfig.REVEAL_SCORE_S:
		_ramp_done = true


## Рост цепочки размера: шаг каждые REVEAL_SIZE_EVERY_S, «вспухание» и всплытие названия.
func _update_size(delta: float) -> void:
	if _final_size > 0 and not _skip_final and _size_k < _final_size and _t >= _next_step_t:
		_size_k += 1
		_next_step_t = _t + GameConfig.REVEAL_SIZE_EVERY_S
		_pop_t = 0.0
		if _view != null:
			_view.float_size(_size_k)
		_overlay.flash(0.6)
	_pop_t = maxf(_pop_t - delta, -1.0)
	if _final_size > 0 and _view != null:
		var pop_env: float = 0.0
		if _pop_t >= 0.0:
			pop_env = 1.0 - smoothstep(0.0, GameConfig.REVEAL_SIZE_POP_S, _pop_t)
		_view.scale = Vector3.ONE * SizeData.visual_scale(_size_k) * (1.0 + GameConfig.SIZE_GROWTH * pop_env)
	else:
		_view.scale = Vector3.ONE


# ---------- Фаза D: выход ----------

func _enter_exit() -> void:
	_phase = Phase.EXIT
	_t = 0.0
	_flashed = false
	# Камера возвращается к игроку в его текущей позиции; сам игрок не телепортируется.
	_camera_rig.set_scripted(false)
	_camera_rig.return_to_player(EXIT_S)


func _update_exit() -> void:
	var eat: float = clampf(_t / EXIT_EAT_S, 0.0, 1.0)
	if _food != null and is_instance_valid(_food):
		_food.scale = Vector3.ONE * (1.0 - eat)
	if _view != null:
		_view.position = _stop.lerp(_stop + (_land - _stop) * 0.35, eat)
		if _t >= EXIT_EAT_S:
			if not _flashed:
				_flashed = true
				_overlay.flash(0.8)
			var shrink: float = 1.0 - clampf((_t - EXIT_EAT_S) / (EXIT_S - EXIT_EAT_S), 0.0, 1.0)
			_view.scale = Vector3.ONE * maxf(shrink, 0.001)
	var fade: float = 1.0 - clampf(_t / EXIT_S, 0.0, 1.0)
	_overlay.set_fade(fade)
	_overlay.set_vignette(fade)
	if _t >= EXIT_S:
		_finish_run()


# ---------- Общее ----------

func _spawn_view(at: Vector3) -> void:
	_view = AnimalView.new()
	_view.name = "AnimalView"
	add_child(_view)
	# Вариант проявится в фазе C: «Удача!» не должна выдаваться заранее.
	_view.set_creature(_animal_id, VariantData.NONE, _rarity, _income)
	_view.set_part_mode(AnimalBuilder.PART_FULL)   # T24f: один зверь на экране получения, до 12 мешей
	_view.set_signs_visible(false)
	_view.position = at
	_view.rotation.y = _yaw_of(_dir)


func _set_pose(pos: Vector3, target: Vector3, fov: float, roll: float) -> void:
	_cam_pos = pos
	_cam_target = target
	_cam_fov = fov
	_camera_rig.set_pose(pos, target, fov, roll)


# Поворот вокруг Y, при котором взгляд зверя (-Z модели) смотрит вдоль v.
func _yaw_of(v: Vector3) -> float:
	return atan2(-v.x, -v.z)


func _finish_run() -> void:
	_cleanup()
	_finished = true
	finished.emit()


func _cleanup() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	if _food != null and is_instance_valid(_food):
		_food.scale = Vector3.ONE
	_food = null
	_phase = Phase.NONE
	if _overlay != null:
		_overlay.reset()
