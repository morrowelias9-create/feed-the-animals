extends Control
## Демо-сцена: показывает, как пользоваться каркасом. Удали и сделай свою игру.

var _score := 0
var _info: Label
var _stats: Label
var _buttons := {}


func _ready() -> void:
	Loc.language_changed.connect(_refresh_texts)
	_build_ui()
	_refresh_texts()
	await Ya.initialize()
	await Save.load_all()
	Game.start()
	Ya.loading_ready()
	Ya.gameplay_start()
	_refresh_texts()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	_info = _make_label(box)
	_stats = _make_label(box)
	_add_button(box, "tap", _on_tap)
	_add_button(box, "interstitial", func(): Ya.show_interstitial())
	_add_button(box, "rewarded", _on_rewarded)
	_add_button(box, "submit", func(): Ya.submit_score("main", int(Save.data["best_throw"])))
	_add_button(box, "sound", _on_sound)


func _make_label(parent: Node) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	parent.add_child(l)
	return l


func _add_button(parent: Node, key: String, cb: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(440, 72)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons[key] = b


func _refresh_texts() -> void:
	for key in _buttons:
		_buttons[key].text = Loc.t(key)
	_info.text = Loc.t("sdk_ok") if Ya.sdk_ok else Loc.t("sdk_mock")
	_stats.text = "%s: %d    %s: %d" % [Loc.t("coins"), int(Game.money()), Loc.t("score"), _score]


func _on_tap() -> void:
	_score += 1
	Game.add_money(1)
	Save.data["best_throw"] = maxi(int(Save.data["best_throw"]), _score)
	Save.save_data()
	_refresh_texts()


func _on_rewarded() -> void:
	Ya.show_rewarded(func():
		Game.add_money(10)
		_refresh_texts()
	)


func _on_sound() -> void:
	Save.data["sound_on"] = not Save.data["sound_on"]
	Ya.user_muted = not Save.data["sound_on"]
	Save.save_data()
