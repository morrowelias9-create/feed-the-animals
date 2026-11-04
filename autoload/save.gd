extends Node
## Сохранения: локально (user://) и в облако Яндекса. При старте побеждает более свежая копия (поле _ts).
## Хранить только JSON-совместимые данные: числа, строки, bool, массивы, словари. Лимит SDK по размеру небольшой.

const PATH := "user://save.json"
const CLOUD_THROTTLE := 3.0  # не чаще раза в N секунд отправляем в облако

## Здесь описываешь все поля игры с дефолтами. Новые поля добавляются безопасно.
const DEFAULTS := {
	"coins": 0,
	"best_score": 0,
	"sound_on": true,
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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


func _merge(local: Dictionary, cloud: Dictionary) -> Dictionary:
	var newer := local
	if cloud.get("_ts", 0) > local.get("_ts", 0):
		newer = cloud
	var result: Dictionary = DEFAULTS.duplicate(true)
	result.merge(newer, true)
	# JSON отдаёт все числа как float - возвращаем int там, где в дефолтах int
	for key in DEFAULTS:
		if typeof(DEFAULTS[key]) == TYPE_INT:
			result[key] = int(result[key])
	return result
