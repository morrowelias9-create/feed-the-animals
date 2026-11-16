class_name BarController
extends Node3D
## Турник и тренировка на нём (T14, справочники R2 и R3).
## В мире стоит один турник, лучший из купленных; купленный новый заменяет старый на том же месте (вырастает «пружиной»).
## Тренировка: игрок стоит в зоне 6x6 м турника и не двигает джойстик. Он плавно встаёт под перекладину,
## повторения идут сами раз в BAR_REP_S секунд, каждое даёт опыт этого (лучшего) турника.
## Раз в 4-6 с над головой появляется пузырь-бонус (кнопка в HUD), тап даёт BAR_BONUS_REPS повторений,
## через BAR_BONUS_LIFE_S пузырь исчезает. Выход из зоны, движение, бросок, окно или зверь в руках заканчивают тренировку.

const BONUS_HEAD_Y: float = 2.9          # высота над землёй, над которой висит пузырь

var player: Player
var camera_rig: CameraRig
var hud: Hud
var router: InputRouter
var throw_controller: Node
var carry_controller: Node

var _view: BarView
var _training: bool = false
var _rep_t: float = 0.0
var _bonus_t: float = 0.0                # сколько ждать до следующего бонуса
var _bonus_left: float = 0.0             # сколько ещё живёт пузырь (0: пузыря нет)
var _unsaved: bool = false               # есть повторения, не записанные в сохранение


func _ready() -> void:
	_view = BarView.new()
	_view.name = "Bar"
	add_child(_view)
	_sync_view(false)
	Game.bar_changed.connect(_on_bar_changed)
	if hud != null:
		hud.bonus_pressed.connect(_on_bonus_pressed)


func is_training() -> bool:
	return _training


func _process(delta: float) -> void:
	if player == null:
		return
	var want: bool = Game.bars_owned() > 0 and _can_train() and _is_idle() \
			and WorldLayout.bar_zone_rect().has_point(Vector2(player.position.x, player.position.z))
	if want != _training:
		if want:
			_start()
		else:
			_stop()
	if not _training:
		return
	_hold_player(delta)
	_tick_reps(delta)
	_tick_bonus(delta)


# Показывает лучший купленный турник; нет ни одного: турника в мире нет.
func _sync_view(animate: bool) -> void:
	var best: int = Game.best_bar()
	_view.visible = best >= 0
	if best < 0:
		return
	_view.set_tier(best)
	if animate:
		_view.pop_in()


func _on_bar_changed() -> void:
	_sync_view(true)


# Тренировка возможна только в спокойном состоянии: не бросок, не зверь в руках, не окно.
func _can_train() -> bool:
	if not player.enabled:
		return false
	if throw_controller != null and throw_controller.is_busy():
		return false
	if carry_controller != null and carry_controller.is_carrying():
		return false
	return true


func _is_idle() -> bool:
	return router == null or router.get_move().length() < GameConfig.BAR_IDLE_INPUT


func _start() -> void:
	_training = true
	_rep_t = GameConfig.BAR_REP_S * 0.5   # первое повторение через полпериода, а не сразу
	_bonus_t = randf_range(GameConfig.BAR_BONUS_MIN_S, GameConfig.BAR_BONUS_MAX_S)
	_bonus_left = 0.0
	if hud != null:
		hud.set_training(true)


func _stop() -> void:
	_training = false
	_hide_bonus()
	if hud != null:
		hud.set_training(false)
	if player != null and player.avatar != null:
		player.avatar.reset_pose()
	if _unsaved:
		_unsaved = false
		Game.save_progress()


# Игрок плавно встаёт под перекладину и смотрит вперёд (-Z).
func _hold_player(delta: float) -> void:
	var target: Vector3 = WorldLayout.bar_position()
	player.position = player.position.move_toward(target, GameConfig.BAR_CENTER_SPEED * delta)
	player.rotation.y = lerp_angle(player.rotation.y, 0.0, clampf(10.0 * delta, 0.0, 1.0))


func _tick_reps(delta: float) -> void:
	_rep_t += delta
	while _rep_t >= GameConfig.BAR_REP_S:
		_rep_t -= GameConfig.BAR_REP_S
		var gained: float = Game.train_reps(Game.best_bar(), 1)
		_unsaved = true
		if player.avatar != null:
			player.avatar.play_pullup(GameConfig.BAR_REP_S * 0.9)
		if hud != null and gained > 0.0:
			var at: Vector2 = _bonus_screen_pos() + Vector2(randf_range(70.0, 120.0), 50.0)   # сбоку от подписи турника
			hud.popup_at("+%s" % NumFmt.format(gained), at)


func _tick_bonus(delta: float) -> void:
	if hud == null:
		return
	if _bonus_left > 0.0:
		_bonus_left -= delta
		if _bonus_left <= 0.0:
			_hide_bonus()
			_bonus_t = randf_range(GameConfig.BAR_BONUS_MIN_S, GameConfig.BAR_BONUS_MAX_S)
		else:
			hud.move_bonus(_bonus_screen_pos())
		return
	_bonus_t -= delta
	if _bonus_t <= 0.0:
		_bonus_left = GameConfig.BAR_BONUS_LIFE_S
		hud.show_bonus(GameConfig.BAR_BONUS_REPS)
		hud.move_bonus(_bonus_screen_pos())


func _hide_bonus() -> void:
	_bonus_left = 0.0
	if hud != null:
		hud.hide_bonus()


# Точка над головой игрока в экранных координатах.
func _bonus_screen_pos() -> Vector2:
	if camera_rig == null or camera_rig.camera == null:
		return Vector2(640.0, 200.0)
	return camera_rig.camera.unproject_position(player.global_position + Vector3(0.0, BONUS_HEAD_Y, 0.0))


func _on_bonus_pressed() -> void:
	if not _training or _bonus_left <= 0.0:
		return
	var at: Vector2 = hud.bonus_center()
	var gained: float = Game.train_reps(Game.best_bar(), GameConfig.BAR_BONUS_REPS)
	_unsaved = true
	if player.avatar != null:
		player.avatar.play_pullup(0.3)
	hud.popup_at("+%d" % int(gained), at)
	_hide_bonus()
	_bonus_t = randf_range(GameConfig.BAR_BONUS_MIN_S, GameConfig.BAR_BONUS_MAX_S)
