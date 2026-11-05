class_name ThrowController
extends Node3D
## Бросок: шкала, полёт, приземление, кинематика получения зверя (шаги T09/T10c, справочник R2/R3/R6).
## Состояния: FREE -> AIMING -> THROWING -> FLIGHT -> LANDED -> REVEAL -> COOLDOWN -> (AIMING | FREE).
## В REVEAL всё ведёт RevealController: камера, зверь, экран награды.

signal landed(dist: float, zone: int, perfect: bool, position: Vector3)
signal state_changed(state: String)
signal reveal_completed

const STATE_FREE: String = "FREE"
const STATE_AIMING: String = "AIMING"
const STATE_THROWING: String = "THROWING"
const STATE_FLIGHT: String = "FLIGHT"
const STATE_LANDED: String = "LANDED"
const STATE_REVEAL: String = "REVEAL"
const STATE_COOLDOWN: String = "COOLDOWN"

const COOLDOWN_S: float = 0.6
const LANDED_S: float = 0.25          # пауза после приземления перед кинематикой
const LAND_T: float = 1.2             # плашка с дальностью держится поверх начала REVEAL
const THROW_ANIM_S: float = 0.55
const BACK_CANCEL: float = 0.3          # насколько назад надо потянуть, чтобы отменить прицеливание
const TOAST_UP: float = 2.5
const HAND_H: float = 1.3             # высота руки над землёй при броске
const LAND_X_LIMIT: float = 15.0      # еда падает не дальше этого от оси коридора

var state: String = STATE_FREE
var player: Player
var camera_rig: CameraRig
var hud: Hud
var carry_controller: Node

var _meter: ThrowMeter
var _food: FoodView
var _reveal: RevealController
var _toast: Label3D
var _toast_t: float = 0.0
var _throw_t: float = 0.0
var _landed_t: float = 0.0
var _cooldown_t: float = 0.0
var _rearm_blocked: bool = false      # после отмены не прицеливаемся снова, пока игрок не выйдет из зоны
var _land_pos: Vector3 = Vector3.ZERO
var _dist: float = 0.0
var _zone: int = 0
var _perfect: bool = false


func _ready() -> void:
	var toast := Label3D.new()
	toast.name = "LandToast"
	toast.visible = false
	toast.font_size = 48
	toast.pixel_size = 0.02
	toast.outline_size = 12
	toast.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	toast.no_depth_test = true
	toast.modulate = Color.WHITE
	add_child(toast)
	_toast = toast
	_reveal = RevealController.new()
	_reveal.name = "RevealController"
	add_child(_reveal)
	_reveal.throw_controller = self


## Событие короткого нажатия (действие) из InputRouter: в AIMING это бросок, в REVEAL пропуск или выход.
func action_pressed() -> void:
	if state == STATE_REVEAL:
		_reveal.tap()
		return
	if carry_controller != null and carry_controller.is_carrying():
		carry_controller.place_at_cursor()
		return
	if state != STATE_AIMING or player == null or camera_rig == null:
		return
	var v: float = _meter.stop()
	var eff: int = ThrowCalc.eff_power(Game.strength(), v)
	var dist: float = ThrowCalc.distance(eff)
	_perfect = ThrowCalc.is_perfect(ThrowCalc.bonus_of(v))
	_zone = ZoneData.zone_at(dist)
	_dist = dist
	# Бросок строго вперёд (-Z). Еда падает на землю в точке dist от линии: на краю земли или на пол коридора.
	var from: Vector3 = player.position + Vector3(0.0, HAND_H, 0.0)
	var land_z: float = -minf(WorldLayout.landing_dist(dist), WorldLayout.CORRIDOR_LEN - 12.0)
	var to: Vector3 = Vector3(clampf(player.position.x, -LAND_X_LIMIT, LAND_X_LIMIT), 0.0, land_z)
	to.y = WorldLayout.ground_y(to.z)
	var height: float = clampf(dist * 0.15, 3.0, 60.0)
	if _food == null:
		_food = FoodView.new()
		_food.name = "Food"
		add_child(_food)
	_food.visible = true
	_food.scale = Vector3.ONE
	_food.rotation = Vector3.ZERO
	_food.launch_arc(from, to, height, ThrowCalc.flight_time(dist))
	_food.set_color(_food_color())
	camera_rig.follow_food(_food)
	player.avatar.play_throw()
	state = STATE_THROWING
	_throw_t = 0.0
	_lock_player()


func _process(delta: float) -> void:
	if _toast != null and _toast.visible:
		_toast_t += delta
		if _toast_t >= LAND_T:
			_set_toast(false)
	match state:
		STATE_FREE:
			if carry_controller == null or not carry_controller.is_carrying():
				if player != null:
					var in_zone: bool = _in_throw_zone()
					if _rearm_blocked:
						if not in_zone:
							_rearm_blocked = false
					elif in_zone:
						_enter_aiming()
		STATE_AIMING:
			if _wants_back():
				_cancel_aiming()
		STATE_THROWING:
			_throw_t += delta
			if _throw_t >= THROW_ANIM_S:
				_throw_t = 0.0
				state = STATE_FLIGHT
		STATE_FLIGHT:
			hud.set_flight(true)
			if _food != null and _food.is_landed():
				_land()
		STATE_LANDED:
			_landed_t += delta
			if _landed_t >= LANDED_S:
				_begin_reveal()
		STATE_REVEAL:
			if _reveal.is_finished():
				_end_reveal()
		STATE_COOLDOWN:
			_cooldown_t += delta
			if _cooldown_t >= COOLDOWN_S:
				_cooldown_t = 0.0
				_finish_cooldown()


func is_busy() -> bool:
	return state != STATE_FREE


## Сбрасывает прицеливание и блокировку движения при взятии зверя из рюкзака.
func cancel_for_carry() -> void:
	if state == STATE_AIMING:
		state = STATE_FREE
		_rearm_blocked = true
		_meter.stop()
		state_changed.emit(state)
	_unlock_player()
	if hud != null:
		hud.set_flight(false)


func _in_throw_zone() -> bool:
	if player == null:
		return false
	var rect: Rect2 = WorldLayout.throw_zone_rect()
	return rect.has_point(Vector2(player.position.x, player.position.z))


# Движение блокируется с входа в зону броска до отмены (шаг назад) или конца броска.
func _lock_player() -> void:
	if player != null:
		player.enabled = false


func _unlock_player() -> void:
	if player != null:
		player.enabled = true


# Игрок тянет назад, от линии (+Z в мире с учётом поворота камеры): это отмена прицеливания.
func _wants_back() -> bool:
	if player == null or player.input_router == null:
		return false
	var move: Vector2 = player.input_router.get_move()
	if move.length() < BACK_CANCEL:
		return false
	var world: Vector3 = Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, deg_to_rad(camera_rig.yaw_deg))
	return world.z > BACK_CANCEL


func _enter_aiming() -> void:
	state = STATE_AIMING
	_lock_player()
	hud.set_mode(false)
	_meter.start()
	state_changed.emit(state)


func _cancel_aiming() -> void:
	state = STATE_FREE
	_rearm_blocked = true
	_unlock_player()
	hud.set_mode(true)
	_meter.stop()
	state_changed.emit(state)


func _return_to_free() -> void:
	state = STATE_FREE
	_unlock_player()
	if carry_controller != null and carry_controller.is_carrying():
		hud.set_mode(false)
		hud.set_hint("Сначала поставь зверя")
	else:
		hud.set_mode(true)
	_meter.stop()
	state_changed.emit(state)


func _begin_reveal() -> void:
	state = STATE_REVEAL
	_landed_t = 0.0
	hud.set_reveal(true)
	camera_rig.set_scripted(true)
	state_changed.emit(state)
	_reveal.start(_zone, _dist, _land_pos, _food, _perfect)


func _end_reveal() -> void:
	hud.set_reveal(false)
	hud.set_mode(true)
	if _food != null:
		_food.visible = false
	state = STATE_COOLDOWN
	_cooldown_t = 0.0
	state_changed.emit(state)
	reveal_completed.emit()


# Камеру к игроку вернула сама кинематика (return_to_player), здесь только выбираем следующее состояние.
func _finish_cooldown() -> void:
	if carry_controller != null and carry_controller.is_carrying():
		_return_to_free()
	elif player != null and _in_throw_zone():
		_enter_aiming()
	else:
		_return_to_free()


func _land() -> void:
	var dist: float = _dist
	var zone: int = _zone
	var perfect: bool = _perfect
	var position: Vector3 = _food.landing_position()
	_land_pos = position
	_landed_t = 0.0
	# Счёт и рекорд броска (шаг T09, справочник R5).
	Save.data["throws"] = int(Save.data.get("throws", 0)) + 1
	Save.data["best_throw"] = maxi(int(Save.data.get("best_throw", 0)), int(dist))
	Save.save_data()
	_set_toast(true, dist)
	_spawn_land_fx(position)
	landed.emit(dist, zone, perfect, position)
	state = STATE_LANDED


func _set_toast(show: bool, dist: float = 0.0) -> void:
	if _toast == null:
		return
	_toast.visible = show
	_toast_t = 0.0
	if show:
		_toast.text = Loc.t("land_toast") % int(dist)
		_toast.position = _land_pos + Vector3(0.0, TOAST_UP, 0.0)


func _spawn_land_fx(position: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "LandParticles"
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.0
	var chip := BoxMesh.new()
	chip.size = Vector3(0.15, 0.15, 0.15)
	var chip_mat := StandardMaterial3D.new()
	chip_mat.albedo_color = _food_color()
	chip.material = chip_mat
	particles.mesh = chip
	particles.position = position
	add_child(particles)
	particles.emitting = true
	# Одноразовый эффект убирается сам, иначе узлов становится больше с каждым броском.
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _food_color() -> Color:
	var tier: int = int(Save.data.get("food_selected", 0))
	var food: Dictionary = FoodData.FOODS[clampi(tier, 0, FoodData.FOODS.size() - 1)]
	if food.has("color"):
		return Color.html(str(food["color"]))
	return Color.ORANGE
