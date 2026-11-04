class_name ThrowController
extends Node3D
## Бросок: шкала, полёт, приземление (шаг T09, справочник R2/R3/R6).
## Состояния: FREE -> AIMING -> THROWING -> FLIGHT -> LANDED -> ARRIVE -> CLAIM -> COOLDOWN -> (AIMING | FREE).
## ARRIVE и CLAIM ведут ArrivalController (шаг T10).

signal landed(dist: float, zone: int, perfect: bool, position: Vector3)
signal state_changed(state: String)

const STATE_FREE: String = "FREE"
const STATE_AIMING: String = "AIMING"
const STATE_THROWING: String = "THROWING"
const STATE_FLIGHT: String = "FLIGHT"
const STATE_LANDED: String = "LANDED"
const STATE_COOLDOWN: String = "COOLDOWN"
const STATE_ARRIVE: String = "ARRIVE"
const STATE_CLAIM: String = "CLAIM"

const COOLDOWN_S: float = 0.6
const CLAIM_S: float = 1.5
const LAND_T: float = 1.2
const THROW_ANIM_S: float = 0.55
const GRAVITY: float = 9.8
const MOVE_CANCEL_M: float = 0.05
const TOAST_UP: float = 2.5

var state: String = STATE_FREE
var player: Player
var camera_rig: CameraRig
var hud: Hud

var _meter: ThrowMeter
var _food: FoodView
var _toast: Label3D
var _toast_t: float = 0.0
var _throw_t: float = 0.0
var _cooldown_t: float = 0.0
var _aim_enter: Vector3 = Vector3.ZERO
var _land_pos: Vector3 = Vector3.ZERO
var _dist: float = 0.0
var _zone: int = 0
var _perfect: bool = false
var _arrival: ArrivalController
var _claim_t: float = 0.0


func _ready() -> void:
	var toast := Label3D.new()
	toast.name = "LandToast"
	toast.visible = false
	toast.font_size = 30.0
	toast.modulate = Color.WHITE
	add_child(toast)
	_toast = toast
	_arrival = ArrivalController.new()
	_arrival.name = "ArrivalController"
	add_child(_arrival)
	_arrival.throw_controller = self


## Событие короткого нажатия (действие) из InputRouter: в AIMING это бросок.
func action_pressed() -> void:
	if state != STATE_AIMING or player == null or camera_rig == null:
		return
	var v: float = _meter.stop()
	var eff: int = ThrowCalc.eff_power(Game.strength(), v)
	var dist: float = ThrowCalc.distance(eff)
	_perfect = ThrowCalc.is_perfect(ThrowCalc.bonus_of(v))
	_zone = ZoneData.zone_at(dist)
	_dist = dist
	var from: Vector3 = player.position
	var forward: Vector3 = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(camera_rig.yaw_deg))
	var flight: float = ThrowCalc.flight_time(dist)
	var height: float = clampf(dist * 0.15, 3.0, 60.0)
	var vel_y: float = (height + 0.5 * GRAVITY * flight * flight) / flight
	var vel_z: float = dist / flight
	var vel: Vector3 = Vector3(forward.x * vel_z, vel_y, forward.z * vel_z)
	var land_t: float = 2.0 * vel_y / GRAVITY
	if _food == null:
		_food = FoodView.new()
		_food.name = "Food"
		add_child(_food)
	_food.launch(from, vel, land_t)
	_food.set_color(_food_color())
	camera_rig.follow_food(_food)
	player.avatar.play_throw()
	state = STATE_THROWING
	_throw_t = 0.0
	_aim_enter = from


func _process(delta: float) -> void:
	match state:
		STATE_FREE:
			if player != null and _in_throw_zone():
				_enter_aiming()
		STATE_AIMING:
			if player != null and player.position.distance_to(_aim_enter) > MOVE_CANCEL_M:
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
			_toast_t += delta
			if _toast_t >= LAND_T:
				_toast_t = 0.0
				_set_toast(false)
				_begin_arrive()
		STATE_ARRIVE:
			if _arrival.is_finished():
				arrival_done()
		STATE_CLAIM:
			_claim_t += delta
			if _claim_t >= CLAIM_S:
				_claim_t = 0.0
				_enter_cooldown()
		STATE_COOLDOWN:
			_cooldown_t += delta
			if _cooldown_t >= COOLDOWN_S:
				_cooldown_t = 0.0
				_enter_cooldown()


func is_busy() -> bool:
	return state != STATE_FREE


func _in_throw_zone() -> bool:
	if player == null:
		return false
	var rect: Rect2 = WorldLayout.throw_zone_rect()
	return rect.has_point(Vector2(player.position.x, player.position.z))


func _enter_aiming() -> void:
	state = STATE_AIMING
	_aim_enter = player.position
	hud.set_mode(false)
	_meter.start()
	state_changed.emit(state)


func _cancel_aiming() -> void:
	state = STATE_FREE
	hud.set_mode(true)
	_meter.stop()
	state_changed.emit(state)


func _return_to_free() -> void:
	state = STATE_FREE
	hud.set_mode(true)
	_meter.stop()
	state_changed.emit(state)


func _begin_arrive() -> void:
	state = STATE_ARRIVE


func arrival_done() -> void:
	state = STATE_CLAIM
	_claim_t = 0.0


func _enter_cooldown() -> void:
	_cooldown_t = 0.0
	camera_rig.return_to_player()
	if player != null and _in_throw_zone():
		_enter_aiming()
	else:
		_return_to_free()


func _land() -> void:
	var dist: float = _dist
	var zone: int = _zone
	var perfect: bool = _perfect
	var position: Vector3 = _food.landing_position()
	_land_pos = position
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
	if show:
		_toast.text = Loc.t("land_toast") % int(dist)
		_toast.position = _land_pos + Vector3(0.0, TOAST_UP, 0.0)
		_toast_t = 0.0


func _spawn_land_fx(position: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "LandParticles"
	particles.one_shot = true
	particles.amount = 1 + int(randi() % 20)
	particles.lifetime = 0.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.direction = Vector3(0.0, 1.0, 0.0)
	var param: int = CPUParticles3D.PARAM_INITIAL_LINEAR_VELOCITY
	particles.set_param_min(param, 2.0)
	particles.set_param_max(param, 2.0)
	particles.position = position
	add_child(particles)


func _food_color() -> Color:
	var tier: int = int(Save.data.get("food_selected", 0))
	var food: Dictionary = FoodData.FOODS[clampi(tier, 0, FoodData.FOODS.size() - 1)]
	if food.has("color"):
		return Color.html(str(food["color"]))
	return Color.ORANGE
