extends Node
class_name SoundBank
## Банк звуков (T26): пул из 8 AudioStreamPlayer для SFX и один для музыки.
## play(name, pitch) — проигрывает assets/audio/sfx/<name>.ogg, если файл есть (иначе тишина без ошибок).
## play_music("loop") — проигрывает assets/audio/music/loop.ogg в цикле.

const SFX_POOL_SIZE: int = 8
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music_player: AudioStreamPlayer
var _enabled: bool = true


func _ready() -> void:
	# Создаём пул SFX плееров
	for i in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SfxPlayer_%d" % i
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)
	
	# Создаём плеер для музыки
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)
	
	# Применяем сохранённое состояние звука
	_enabled = Save.data.get("sound_on", true)
	if not _enabled:
		_music_player.stop()
		for p in _sfx_pool:
			p.stop()


## Включает/выключает весь звук. Сохраняется в Save.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	Save.data["sound_on"] = enabled
	if not enabled:
		_music_player.stop()
		for p in _sfx_pool:
			p.stop()
	else:
		# Можно здесь возобновить музыку, если была
		pass
	Save.save_data()


func is_enabled() -> bool:
	return _enabled


## Проигрывает звуковой эффект. pitch — перестройка (1.0 = нормально).
## Если файл не найден — молча игнорируем.
func play(name: String, pitch: float = 1.0) -> void:
	if not _enabled:
		return
	var path: String = SFX_DIR + name + ".ogg"
	if not ResourceLoader.exists(path, "AudioStream"):
		return
	var stream: AudioStream = ResourceLoader.load(path)
	if stream == null:
		return
	
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


## Проигрывает музыку в цикле. name — имя файла без расширения (ожидается loop.ogg).
func play_music(name: String) -> void:
	if not _enabled:
		return
	var path: String = MUSIC_DIR + name + ".ogg"
	if not ResourceLoader.exists(path, "AudioStream"):
		return
	var stream: AudioStream = ResourceLoader.load(path)
	if stream == null:
		return
	
	_music_player.stream = stream
	_music_player.loop = true
	_music_player.play()


## Останавливает музыку.
func stop_music() -> void:
	_music_player.stop()