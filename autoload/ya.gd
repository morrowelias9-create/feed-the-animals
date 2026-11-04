extends Node
## Обёртка над Яндекс Играми SDK.
## В браузере на Яндексе работает с настоящим SDK, в редакторе и вне Яндекса - в режиме заглушки (mock).
## Все вызовы JS идут через window.YaBridge (см. web/shell.html), ответы приходят одним колбэком.

signal initialized(ok: bool)
signal rewarded_granted
signal ad_started(kind: String)
signal ad_finished(kind: String, shown: bool)

## Минимальный интервал между полноэкранной рекламой, секунд. Подстрой под правила платформы.
const INTERSTITIAL_COOLDOWN := 61.0
const INIT_TIMEOUT := 6.0
const CLOUD_TIMEOUT := 5.0

var sdk_ok := false
var lang := "ru"
var user_muted := false: set = set_user_mute

var _is_web := OS.has_feature("web")
var _bridge: JavaScriptObject
var _cb: JavaScriptObject  # держим ссылку, иначе колбэк соберёт GC
var _init_done := false
var _ad_active := false
var _was_paused := false
var _platform_paused := false
var _focused := true
var _last_interstitial := -1000.0
var _reward_cb := Callable()
var _cloud_done := false
var _cloud_data := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_apply_audio()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_apply_audio()


# --- Инициализация ---------------------------------------------------------

## Вызывать один раз при старте. Возвращает true, если настоящий SDK поднялся.
func initialize() -> bool:
	if _init_done:
		return sdk_ok
	if not _is_web:
		_init_done = true
		initialized.emit(false)
		return false
	_bridge = JavaScriptBridge.get_interface("YaBridge")
	if _bridge == null:
		_init_done = true
		initialized.emit(false)
		return false
	_cb = JavaScriptBridge.create_callback(_on_js_event)
	_bridge.setHandler(_cb)
	_bridge.init()
	var t := 0.0
	while not _init_done and t < INIT_TIMEOUT:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not _init_done:
		_init_done = true
		initialized.emit(false)
	return sdk_ok


## Сообщить платформе, что игра загрузилась и готова (LoadingAPI.ready).
func loading_ready() -> void:
	if sdk_ok:
		_bridge.loadingReady()


## Начало и конец игрового процесса (GameplayAPI). Вызывай на старте/конце уровня, паузе, выходе в меню.
func gameplay_start() -> void:
	if sdk_ok:
		_bridge.gameplayStart()


func gameplay_stop() -> void:
	if sdk_ok:
		_bridge.gameplayStop()


# --- Реклама ---------------------------------------------------------------

func show_interstitial() -> void:
	if _ad_active:
		return
	if _is_web and not sdk_ok:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_interstitial < INTERSTITIAL_COOLDOWN:
		return
	_last_interstitial = now
	_begin_ad("interstitial")
	if _is_web:
		_bridge.showInterstitial()
	else:
		_mock_ad("interstitial")


## on_reward вызывается только если игрок реально досмотрел рекламу.
func show_rewarded(on_reward: Callable) -> void:
	if _ad_active:
		return
	if _is_web and not sdk_ok:
		return
	_reward_cb = on_reward
	_begin_ad("rewarded")
	if _is_web:
		_bridge.showRewarded()
	else:
		_mock_ad("rewarded")


func _mock_ad(kind: String) -> void:
	await get_tree().create_timer(0.4).timeout
	if kind == "rewarded":
		_grant_reward()
	_end_ad(kind, true)


func _begin_ad(kind: String) -> void:
	_ad_active = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_apply_audio()
	ad_started.emit(kind)


func _end_ad(kind: String, shown: bool) -> void:
	if not _ad_active:
		return
	_ad_active = false
	get_tree().paused = _was_paused or _platform_paused
	_apply_audio()
	ad_finished.emit(kind, shown)


func _grant_reward() -> void:
	if _reward_cb.is_valid():
		_reward_cb.call()
	_reward_cb = Callable()
	rewarded_granted.emit()


# --- Облачные сохранения и лидерборды --------------------------------------

func load_cloud() -> Dictionary:
	if not sdk_ok:
		return {}
	_cloud_done = false
	_cloud_data = {}
	_bridge.loadData()
	var t := 0.0
	while not _cloud_done and t < CLOUD_TIMEOUT:
		await get_tree().process_frame
		t += get_process_delta_time()
	return _cloud_data


func save_cloud(json: String) -> void:
	if sdk_ok:
		_bridge.saveData(json)


## Лидерборд с таким именем должен быть создан в консоли разработчика.
func submit_score(board: String, score: int) -> void:
	if sdk_ok:
		_bridge.setScore(board, score)


# --- Звук ------------------------------------------------------------------

func set_user_mute(value: bool) -> void:
	user_muted = value
	_apply_audio()


func _apply_audio() -> void:
	var muted := user_muted or _ad_active or _platform_paused or not _focused
	AudioServer.set_bus_mute(0, muted)


# --- События из JS ---------------------------------------------------------

func _on_js_event(args: Array) -> void:
	var event := str(args[0])
	var parsed = JSON.parse_string(str(args[1]))
	var payload: Dictionary = parsed if parsed is Dictionary else {}
	match event:
		"init":
			sdk_ok = payload.get("ok", false)
			if sdk_ok:
				lang = str(payload.get("lang", "ru"))
				Loc.set_language(lang)
			else:
				push_warning("Yandex SDK недоступен: %s" % payload.get("error", "?"))
			_init_done = true
			initialized.emit(sdk_ok)
		"ad_rewarded":
			_grant_reward()
		"ad_close":
			_end_ad(str(payload.get("kind", "")), payload.get("shown", true))
		"ad_error":
			push_warning("Ошибка рекламы: %s" % payload.get("error", "?"))
			_end_ad(str(payload.get("kind", "")), false)
		"data_loaded":
			_cloud_data = payload
			_cloud_done = true
		"platform_pause":
			_platform_paused = true
			get_tree().paused = true
			_apply_audio()
		"platform_resume":
			_platform_paused = false
			if not _ad_active:
				get_tree().paused = _was_paused
			_apply_audio()
		"visibility":
			_focused = not payload.get("hidden", false)
			_apply_audio()
