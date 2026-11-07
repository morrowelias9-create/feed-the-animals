extends Node
## Сохранения: локально (user://) и в облако Яндекса. При старте побеждает более свежая копия (поле _ts).
## Хранить только JSON-совместимые данные: числа, строки, bool, массивы, словари. Лимит SDK по размеру небольшой.

const PATH := "user://save.json"
const CLOUD_THROTTLE := 3.0  # не чаще раза в N секунд отправляем в облако

## Здесь описываешь все поля игры с дефолтами. Новые поля добавляются безопасно.
const DEFAULTS := {
	"money": 0.0,
	"strength": 1,
	"strength_xp": 0.0,
	"bar_tier": 0,            # устарело с T14 (поле не удаляем без миграции), вместо него bars_owned
	"bars_owned": 0,          # T14: сколько турников куплено (0-10), место i занимает i-й турник
	"food_unlocked": 0,
	"food_selected": 0,
	"slots_level": 0,
	"animals": [],
	"next_uid": 1,
	"catch_history": [],
	"found": [],
	"claimed_zones": [],
	"best_throw": 0,
	"throws": 0,
	"reps": 0,
	"last_seen": 0,
	"boost_until": 0,
	"tutorial_step": 0,
	"sound_on": true,
	"no_ads": false,                   # T24a: покупка «без рекламы»
	"cash_x2": false,                  # T24a: покупка «доход x2 навсегда»
	"train_x2": false,                 # T24a: покупка «опыт с турников x2 навсегда»
	"starter_claimed": false,          # T24a: стартовый набор получен (один на аккаунт)
	"lucky_throws": 0,                 # T24a: сколько «Счастливых бросков» куплено (механика броска позже)
	"processed_tokens": [],            # T24a: токены уже начисленных покупок, пока их не закрыл consume
	"last_interstitial_time": 0,       # T23: время последней межстраничной рекламы (unix time)
	"last_rewarded_time": 0,           # T23: время последней rewarded-рекламы (unix time)
	"session_start_time": 0,           # T23: время старта текущей сессии (unix time)
	"_ts": 0,
}

var data: Dictionary = DEFAULTS.duplicate(true)

var _timer: Timer
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = CLOUD_THROTTLE
	_timer.timeout.connect(_flush_cloud)
	add_child(_timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _dirty:
		_flush_cloud()


## Вызывать после Ya.initialize().
func load_all() -> void:
	var local := _read_local()
	var cloud: Dictionary = await Ya.load_cloud()
	data = _merge(local, cloud)
	Ya.user_muted = not data["sound_on"]


## Вызывать после любого значимого изменения data.
func save_data() -> void:
	data["_ts"] = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	_dirty = true
	if _timer.is_stopped():
		_timer.start()


func _flush_cloud() -> void:
	if not _dirty:
		return
	_dirty = false
	Ya.save_cloud(JSON.stringify(data))


func _read_local() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(PATH)
	if text.strip_edges().is_empty():
		return {}
	# JSON.new().parse() в отличие от JSON.parse_string() не пишет ошибку в «Вывод» на битом файле.
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}


func _merge(local: Dictionary, cloud: Dictionary) -> Dictionary:
	var newer: Dictionary = cloud if _stamp(cloud) > _stamp(local) else local
	var result: Dictionary = DEFAULTS.duplicate(true)
	result.merge(newer, true)
	# JSON отдаёт все числа как float: приводим типы по DEFAULTS. Неподходящее значение
	# (битое или чужого типа) заменяем дефолтом, чтобы игра стартовала с нуля, а не падала.
	for key in DEFAULTS:
		if typeof(result[key]) != typeof(DEFAULTS[key]):
			result[key] = _coerce(DEFAULTS[key], result[key])
	return result


# Время сохранения из поля _ts; у повреждённого значения считаем 0.
func _stamp(source: Dictionary) -> int:
	var raw: Variant = source.get("_ts", 0)
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return int(raw)
	if typeof(raw) == TYPE_STRING and (raw as String).is_valid_int():
		return (raw as String).to_int()
	return 0


# Приводит значение из JSON к типу дефолта; неподходящее значение заменяет дефолтом.
func _coerce(default_value: Variant, value: Variant) -> Variant:
	match typeof(default_value):
		TYPE_INT:
			if typeof(value) == TYPE_INT:
				return value
			if typeof(value) == TYPE_FLOAT:
				var f: float = float(value)
				return default_value if is_nan(f) or is_inf(f) else int(f)
			if typeof(value) == TYPE_STRING and (value as String).is_valid_int():
				return (value as String).to_int()
		TYPE_FLOAT:
			if typeof(value) == TYPE_INT:
				return float(value)
			if typeof(value) == TYPE_FLOAT:
				var g: float = float(value)
				return default_value if is_nan(g) or is_inf(g) else g
			if typeof(value) == TYPE_STRING and (value as String).is_valid_float():
				return (value as String).to_float()
		TYPE_BOOL:
			if typeof(value) == TYPE_BOOL:
				return value
		TYPE_ARRAY:
			if typeof(value) == TYPE_ARRAY:
				return value
		TYPE_DICTIONARY:
			if typeof(value) == TYPE_DICTIONARY:
				return value
	return default_value
