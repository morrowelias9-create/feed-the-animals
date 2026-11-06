extends Control
## Точка входа (шаг T13): сначала SDK и сохранение, затем мир, интерфейс и броски.

var _world_builder: WorldBuilder
var _world: Node3D
var _player: Player
var _camera_rig: CameraRig
var _zone_look: ZoneLook
var _router: InputRouter
var _hud: Hud
var _throw_controller: ThrowController
var _slot_manager: SlotManager
var _pen_wander: PenWander
var _carry_controller: CarryController
var _hotbar: Hotbar
var _window_layer: CanvasLayer
var _animals_window: AnimalsWindow
var _sell_window: SellWindow
var _sell_stand: SellStand
var _food_window: FoodWindow
var _food_tent: FoodTent
var _bar_controller: BarController
var _buy_pad: BuyPad
var _expand_sign: ExpandSign
var _index_window: IndexWindow


func _ready() -> void:
	# Порядок старта (CLAUDE.md): SDK, сохранение, Game.start(), и только потом мир и интерфейс.
	# Если собрать HUD и загон до загрузки, они читают пустые данные и ждут первого сигнала.
	await Ya.initialize()
	await Save.load_all()
	Game.start()
	_build_world()
	# Расширение участка (T16): забор перестраивается после покупки мест.
	if not Game.slots_changed.is_connected(_world_builder.refresh_pen_geometry):
		Game.slots_changed.connect(_world_builder.refresh_pen_geometry)
	_build_hud()
	_setup_throw()
	Ya.loading_ready()
	Ya.gameplay_start()


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
	_expand_sign = ExpandSign.new()
	_expand_sign.name = "ExpandSign"
	_expand_sign.player = _player
	world.add_child(_expand_sign)
	_camera_rig = CameraRig.new()
	_camera_rig.name = "CameraRig"
	world.add_child(_camera_rig)
	_player.camera_rig = _camera_rig
	_camera_rig.set_follow_target(_player)
	_camera_rig.snap_to_target()
	# Смена неба, тумана и света по зоне под камерой (T17).
	_zone_look = ZoneLook.new()
	_zone_look.name = "ZoneLook"
	_zone_look.camera_rig = _camera_rig
	_zone_look.world_builder = _world_builder
	world.add_child(_zone_look)
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


# HUD из scenes/ui/hud.tscn: шкала броска, деньги, сила и кнопки окон.
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
	_router.action_pressed.connect(_on_action_pressed)
	_expand_sign.throw_controller = _throw_controller
	# Загон игрока (T11): звери в местах, замки на закрытых, «+$N» над зверями.
	_slot_manager = SlotManager.new()
	_slot_manager.name = "SlotManager"
	_slot_manager.throw_controller = _throw_controller
	_world.add_child(_slot_manager)

	# Прогулки зверей по загону (T11c): без этого узла звери стоят на месте.
	_pen_wander = PenWander.new()
	_pen_wander.name = "PenWander"
	_pen_wander.manager = _slot_manager
	_world.add_child(_pen_wander)

	_carry_controller = CarryController.new()
	_carry_controller.name = "CarryController"
	_carry_controller.player = _player
	_carry_controller.camera_rig = _camera_rig
	_carry_controller.hud = _hud
	_carry_controller.slot_manager = _slot_manager
	_carry_controller.router = _router
	_carry_controller.throw_controller = _throw_controller
	_world.add_child(_carry_controller)
	_expand_sign.carry_controller = _carry_controller
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


# Окна (T12, T12a, T18) в своём слое поверх HUD и лавка продажи в мире.
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

	# Палатка еды (T15): окно с карточками еды, пока нет магазина за яны кнопка «Магазин» открывает его же.
	_food_window = FoodWindow.new()
	_food_window.name = "FoodWindow"
	_window_layer.add_child(_food_window)

	# Индекс зверей (T18)
	_index_window = IndexWindow.new()
	_index_window.name = "IndexWindow"
	_window_layer.add_child(_index_window)
	_index_window.zone_reward_claimed.connect(_hud._refresh)

	for window in [_animals_window, _sell_window, _food_window, _index_window]:
		(window as WindowBase).opened.connect(_on_window_opened)
		(window as WindowBase).closed.connect(_on_window_closed)
	_hud.animals_pressed.connect(_on_animals_pressed)
	_hud.shop_pressed.connect(_on_shop_pressed)
	_hud.index_pressed.connect(_on_index_pressed)

	_sell_stand = SellStand.new()
	_sell_stand.name = "SellStand"
	_sell_stand.player = _player
	_sell_stand.throw_controller = _throw_controller
	_sell_stand.carry_controller = _carry_controller
	_sell_stand.window = _sell_window
	_world.add_child(_sell_stand)

	_food_tent = FoodTent.new()
	_food_tent.name = "FoodTent"
	_food_tent.player = _player
	_food_tent.throw_controller = _throw_controller
	_food_tent.carry_controller = _carry_controller
	_food_tent.window = _food_window
	_world.add_child(_food_tent)
	_setup_training()


# Турники и тренировка (T14), диск покупки турников на полу (T15a).
func _setup_training() -> void:
	_bar_controller = BarController.new()
	_bar_controller.name = "BarController"
	_bar_controller.player = _player
	_bar_controller.camera_rig = _camera_rig
	_bar_controller.hud = _hud
	_bar_controller.router = _router
	_bar_controller.throw_controller = _throw_controller
	_bar_controller.carry_controller = _carry_controller
	_world.add_child(_bar_controller)

	_buy_pad = BuyPad.new()
	_buy_pad.name = "BuyPad"
	_buy_pad.player = _player
	_buy_pad.throw_controller = _throw_controller
	_world.add_child(_buy_pad)


# Сначала проверяем действие у таблички; иначе передаём его обычному броску.
func _on_action_pressed() -> void:
	if _expand_sign != null and _expand_sign.try_activate():
		return
	_throw_controller.action_pressed()


# Кнопка «Животные»: не во время броска, не с зверем в руках и не поверх другого окна.
func _on_animals_pressed() -> void:
	if _throw_controller.is_busy() or _carry_controller.is_carrying() or _sell_window.is_open() or _food_window.is_open():
		return
	_animals_window.open()


# Кнопка «Магазин»: до T24a открывает окно еды (T15), с теми же условиями, что у «Животных».
func _on_shop_pressed() -> void:
	if _throw_controller.is_busy() or _carry_controller.is_carrying() or _sell_window.is_open() or _animals_window.is_open():
		return
	_food_window.open()


# Кнопка «Индекс» (T18): не во время броска, не с зверем в руках и не поверх другого окна.
func _on_index_pressed() -> void:
	if _throw_controller.is_busy() or _carry_controller.is_carrying() or _sell_window.is_open() or _animals_window.is_open() or _food_window.is_open():
		return
	_index_window.open()


# Пока окно открыто, игрок стоит на месте и ввод по миру не работает.
func _on_window_opened() -> void:
	_router.enabled = false
	_player.enabled = false


func _on_window_closed() -> void:
	_router.enabled = true
	_player.enabled = true


# ---------- Временный тур по биомам (F2) ----------
# Удалить перед релизом.

var _tour_active: bool = false
var _tour_zone: int = 0
var _tour_t: float = 0.0
const TOUR_ZONE_TIME: float = 3.0
const TOUR_CAM_HEIGHT: float = 8.0
const TOUR_CAM_DIST: float = 25.0

func _process(delta: float) -> void:
	# F2 — запуск тура по 5 биомам за ~15 сек.
	if Input.is_key_pressed(KEY_F2) and not _tour_active:
		_tour_active = true
		_tour_zone = 0
		_tour_t = 0.0
		_camera_rig.set_scripted(true)
		_router.enabled = false
		_player.enabled = false
		print("DEBUG: биом-тур запущен (F2)")
	if _tour_active:
		_tour_t += delta
		if _tour_zone < ZoneData.count():
			var z_start: float = WorldLayout.floor_start_z(_tour_zone)
			var pos: Vector3 = Vector3(0.0, TOUR_CAM_HEIGHT, z_start + TOUR_CAM_DIST)
			var target: Vector3 = Vector3(0.0, 0.0, z_start)
			_camera_rig.set_pose(pos, target, CameraRig.FOV, 0.0)
		if _tour_t >= TOUR_ZONE_TIME:
			_tour_t = 0.0
			_tour_zone += 1
			if _tour_zone >= ZoneData.count():
				_tour_active = false
				_camera_rig.set_scripted(false)
				_camera_rig.return_to_player(CameraRig.RETURN_DEFAULT)
				_router.enabled = true
				_player.enabled = true
				print("DEBUG: биом-тур завершён, камера вернулась к игроку")

