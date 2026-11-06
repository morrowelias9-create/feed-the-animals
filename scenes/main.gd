extends Control
## Демо-сцена: показывает, как пользоваться каркасом. Удали и сделай свою игру.

var _score := 0
var _info: Label
var _stats: Label
var _buttons := {}
var _world_builder: WorldBuilder  # временно, в T13 станет частью чистого main
var _world: Node3D
var _player: Player
var _camera_rig: CameraRig
var _router: InputRouter
var _hud: Hud
var _throw_controller: ThrowController
var _slot_manager: SlotManager
var _carry_controller: CarryController
var _hotbar: Hotbar
var _window_layer: CanvasLayer
var _animals_window: AnimalsWindow
var _sell_window: SellWindow
var _sell_stand: SellStand


func _ready() -> void:
	Loc.language_changed.connect(_refresh_texts)
	_build_world()
	_build_ui()
	_build_hud()
	_refresh_texts()
	await Ya.initialize()
	await Save.load_all()
	Game.start()
	_world_builder.refresh_pen_geometry()
	if not Game.slots_changed.is_connected(_world_builder.refresh_pen_geometry):
		Game.slots_changed.connect(_world_builder.refresh_pen_geometry)
	Ya.loading_ready()
	Ya.gameplay_start()
	_refresh_texts()
	_setup_throw()


# ВРЕМЕННО (T06): мир, игрок и камера. Демо-кнопки уберутся в T13.
func _build_world() -> void:
	var world: Node3D = Node3D.new()
	world.name = "World"
	add_child(world)
	_world = world
	_world_builder = WorldBuilder.new()
	_world_builder.build(world)
	_player = Player.new()
	_player.name = "Player"
	world.add_child(_player)
	_camera_rig = CameraRig.new()
	_camera_rig.name = "CameraRig"
	world.add_child(_camera_rig)
	_player.camera_rig = _camera_rig
	_camera_rig.set_follow_target(_player)
	_camera_rig.snap_to_target()
	_build_input()


# Ввод: один роутер на всю игру, два плавающих джойстика (движение слева, камера справа), но под интерфейсом.
func _build_input() -> void:
	_router = InputRouter.new()
	_router.name = "InputRouter"
	add_child(_router)
	var joy_movement: JoystickView = JoystickView.new()
	joy_movement.name = "VirtualJoystick"
	add_child(joy_movement)
	var joy_camera: JoystickView = JoystickView.new()
	joy_camera.name = "CameraJoystick"
	add_child(joy_camera)
	_router.movement_joystick = joy_movement
	_router.camera_joystick = joy_camera
	_router.look_delta.connect(_camera_rig.rotate_by)
	_router.zoom_delta.connect(_camera_rig.zoom)
	_player.input_router = _router


# ВРЕМЕННО (T09): HUD из scenes/ui/hud.tscn для шкалы броска. Демо-панель уберут в T13.
func _build_hud() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	_hud = hud_scene.instantiate()
	_hud.name = "Hud"
	add_child(_hud)


func _setup_throw() -> void:
	_throw_controller = ThrowController.new()
	_throw_controller.name = "ThrowController"
	_world.add_child(_throw_controller)
	_throw_controller.player = _player
	_throw_controller.camera_rig = _camera_rig
	_throw_controller.hud = _hud
	_throw_controller._meter = _hud.throw_meter
	_router.action_pressed.connect(_throw_controller.action_pressed)
	# Загон игрока (T11): звери в местах, замки на закрытых, «+$N» над зверями.
	_slot_manager = SlotManager.new()
	_slot_manager.name = "SlotManager"
	_slot_manager.throw_controller = _throw_controller
	_world.add_child(_slot_manager)

	_carry_controller = CarryController.new()
	_carry_controller.name = "CarryController"
	_carry_controller.player = _player
	_carry_controller.camera_rig = _camera_rig
	_carry_controller.hud = _hud
	_carry_controller.slot_manager = _slot_manager
	_carry_controller.router = _router
	_carry_controller.throw_controller = _throw_controller
	_world.add_child(_carry_controller)
	_throw_controller.carry_controller = _carry_controller
	_throw_controller.reveal_completed.connect(_carry_controller.on_reveal_finished)

	_hotbar = Hotbar.new()
	_hotbar.name = "Hotbar"
	_carry_controller.hotbar = _hotbar
	_hotbar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud.add_child(_hotbar)
	_hotbar.animal_selected.connect(_carry_controller.take)
	_setup_windows()


# Окна (T12, T12a) в своём слое поверх HUD и лавка продажи в мире.
func _setup_windows() -> void:
	_window_layer = CanvasLayer.new()
	_window_layer.name = "WindowLayer"
	_window_layer.layer = 20
	add_child(_window_layer)

	_animals_window = AnimalsWindow.new()
	_animals_window.name = "AnimalsWindow"
	_window_layer.add_child(_animals_window)
	_animals_window.take_requested.connect(_carry_controller.take)

	_sell_window = SellWindow.new()
	_sell_window.name = "SellWindow"
	_window_layer.add_child(_sell_window)

	for window in [_animals_window, _sell_window]:
		(window as WindowBase).opened.connect(_on_window_opened)
		(window as WindowBase).closed.connect(_on_window_closed)
	_hud.animals_pressed.connect(_on_animals_pressed)

	_sell_stand = SellStand.new()
	_sell_stand.name = "SellStand"
	_sell_stand.player = _player
	_sell_stand.throw_controller = _throw_controller
	_sell_stand.carry_controller = _carry_controller
	_sell_stand.window = _sell_window
	_world.add_child(_sell_stand)


# Кнопка «Животные»: не во время броска, не с зверем в руках и не поверх другого окна.
func _on_animals_pressed() -> void:
	if _throw_controller.is_busy() or _carry_controller.is_carrying() or _sell_window.is_open():
		return
	_animals_window.open()


# Пока окно открыто, игрок стоит на месте и ввод по миру не работает.
func _on_window_opened() -> void:
	_router.enabled = false
	_player.enabled = false


func _on_window_closed() -> void:
	_router.enabled = true
	_player.enabled = true


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_LEFT)
	center.position = Vector2(16.0, 16.0)
	center.size = Vector2(460.0, 460.0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
