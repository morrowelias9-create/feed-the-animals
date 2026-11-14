class_name FlightFx
extends Node3D
## Эффекты полёта еды (T40): верхняя плашка текущего биома и мини-зоны, счётчик удачи, вспышки и всплески
## частиц при пересечении границ, большой всплеск при приземлении.
## Границы определяются по реальной координате Z еды (ThrowPath.dist_at_z), а не по таймеру.
## Все узлы создаются один раз в _ready (пул из четырёх излучателей), в update() новых объектов нет.

const LAYER: int = 12                    # ниже экрана награды (15) и белого перехода (30)
const BIG_COUNT: int = 2                 # излучатели для границ биомов и приземления
const SMALL_COUNT: int = 2               # излучатели для границ мини-зон
const MINI_FX_GAP_S: float = 0.34        # вспышки мини-зон не чаще ~3 раз в секунду
const BIOME_FLASH_ALPHA: float = 0.28
const MINI_FLASH_ALPHA: float = 0.07
const HINT_THROWS: int = 10              # пояснение к удаче показываем первые броски
const BURST_LIFE_BIG: float = 0.8
const BURST_LIFE_SMALL: float = 0.45
const GOLD: Color = Color("#FFD23F")

var _active: bool = false
var _dist: float = 1.0
var _luck_total: int = 0
var _zone: int = -1
var _gidx: int = -1                      # сквозной номер мини-зоны, чтобы замечать смену
var _clock: float = 0.0
var _last_mini_fx: float = -10.0
var _luck_shown: int = -1

var _layer: CanvasLayer
var _flash: ColorRect
var _banner: VBoxContainer
var _badge: _BadgeView
var _zone_label: Label
var _mini_label: Label
var _luck_box: VBoxContainer
var _luck_label: Label
var _hint_label: Label

var _bursts: Array[CPUParticles3D] = []
var _burst_left: Array[float] = []
var _next_big: int = 0
var _next_small: int = 0

var _pop_tween: Tween
var _flash_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	_build_ui()
	_build_bursts()
	_layer.visible = false


## Начало полёта: dist это дальность броска, luck_total это итоговая удача (то же число, что SCORE).
func begin(dist: float, luck_total: int) -> void:
	_dist = maxf(dist, 1.0)
	_luck_total = luck_total
	_zone = -1
	_gidx = -1
	_clock = 0.0
	_last_mini_fx = -10.0
	_luck_shown = -1
	_active = true
	_kill(_fade_tween)
	_layer.visible = true
	_banner.modulate.a = 1.0
	_luck_box.modulate.a = 1.0
	_flash.color.a = 0.0
	_hint_label.visible = int(Save.data.get("throws", 0)) < HINT_THROWS and _hint_label.text != "flight_luck_hint"
	_set_luck(0)


## Вызывается каждый кадр полёта с мировой позицией еды.
func update(food_pos: Vector3, delta: float) -> void:
	if not _active:
		return
	_clock += delta
	for i in _bursts.size():
		if _burst_left[i] > 0.0:
			_burst_left[i] -= delta
			_bursts[i].global_position = food_pos   # всплеск «едет» вместе с едой и камерой
	var d: float = clampf(ThrowPath.dist_at_z(food_pos.z), 0.0, _dist)
	var zone: int = ZoneData.zone_at(d)
	var gidx: int = MiniZoneData.global_index(d)
	if zone != _zone:
		_on_zone(zone, MiniZoneData.index_at(d), food_pos)
	elif gidx != _gidx:
		_on_mini(zone, MiniZoneData.index_at(d), food_pos)
	_gidx = gidx
	var luck: int = ThrowPath.luck_at(_luck_total, d, _dist)
	if luck != _luck_shown:
		_set_luck(luck)


## Приземление: счётчик показывает итог, большой всплеск цвета биома (золотой при «Идеально!»), плашки гаснут.
func finish(land_pos: Vector3, zone: int, perfect: bool) -> void:
	_active = false
	if _layer.visible:
		_set_luck(_luck_total)
	var color: Color = GOLD if perfect else ZoneBadge.zone_color(zone).lerp(Color.WHITE, 0.35)
	_start_burst(true, land_pos, color)
	_kill(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_interval(0.5)
	_fade_tween.tween_property(_banner, "modulate:a", 0.0, 0.35)
	_fade_tween.parallel().tween_property(_luck_box, "modulate:a", 0.0, 0.35)
	_fade_tween.tween_callback(func() -> void: _layer.visible = false)


func _on_zone(zone: int, mini: int, food_pos: Vector3) -> void:
	var first: bool = _zone < 0
	_zone = zone
	var color: Color = ZoneBadge.zone_color(zone)
	_badge.zone = zone
	_badge.queue_redraw()
	_zone_label.text = Loc.t(str(ZoneData.ZONES[zone]["name_key"]))
	_zone_label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.6))
	_mini_label.text = Loc.t(MiniZoneData.name_key(zone, mini))
	_pop(1.18)
	if not first:
		_flash_screen(color, BIOME_FLASH_ALPHA, 0.45)
		_start_burst(true, food_pos, color.lerp(Color.WHITE, 0.25))
		_last_mini_fx = _clock


func _on_mini(zone: int, mini: int, food_pos: Vector3) -> void:
	_mini_label.text = Loc.t(MiniZoneData.name_key(zone, mini))
	if _clock - _last_mini_fx < MINI_FX_GAP_S:
		return
	_last_mini_fx = _clock
	var color: Color = ZoneBadge.zone_color(zone)
	_pop(1.07)
	_flash_screen(color.lerp(Color.WHITE, 0.5), MINI_FLASH_ALPHA, 0.18)
	_start_burst(false, food_pos, color.lerp(Color.WHITE, 0.4))


func _set_luck(n: int) -> void:
	_luck_shown = n
	var fmt: String = Loc.t("flight_luck")
	# Если ключа ещё нет в Loc.T, Loc.t отдаёт сам ключ: показываем просто число, без ошибки форматирования.
	_luck_label.text = fmt % n if fmt.contains("%") else str(n)


func _pop(peak: float) -> void:
	_kill(_pop_tween)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(peak, peak)
	_pop_tween = create_tween()
	_pop_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_screen(color: Color, alpha: float, duration: float) -> void:
	_kill(_flash_tween)
	_flash.color = Color(color.r, color.g, color.b, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, duration)


# Берёт следующий излучатель нужного размера из пула и запускает всплеск вокруг позиции.
func _start_burst(big: bool, pos: Vector3, color: Color) -> void:
	var idx: int
	if big:
		idx = _next_big
		_next_big = (_next_big + 1) % BIG_COUNT
	else:
		idx = BIG_COUNT + _next_small
		_next_small = (_next_small + 1) % SMALL_COUNT
	var p: CPUParticles3D = _bursts[idx]
	p.global_position = pos
	p.color = color
	p.restart()
	p.emitting = true
	_burst_left[idx] = BURST_LIFE_BIG if big else BURST_LIFE_SMALL


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _build_bursts() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = mat
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	for i in BIG_COUNT + SMALL_COUNT:
		var big: bool = i < BIG_COUNT
		var p := CPUParticles3D.new()
		p.name = "Burst%d" % i
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.local_coords = true
		p.amount = 36 if big else 14
		p.lifetime = BURST_LIFE_BIG if big else BURST_LIFE_SMALL
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 7.0 if big else 3.5
		p.initial_velocity_max = 14.0 if big else 7.0
		p.scale_amount_min = 0.6 if big else 0.4
		p.scale_amount_max = 1.6 if big else 1.0
		p.scale_amount_curve = shrink
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.6
		p.mesh = sphere
		add_child(p)
		_bursts.append(p)
		_burst_left.append(0.0)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "FlightLayer"
	_layer.layer = LAYER
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 18.0
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	_banner = VBoxContainer.new()
	_banner.add_theme_constant_override("separation", 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_banner)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	_badge = _BadgeView.new()
	_badge.custom_minimum_size = Vector2(64.0, 64.0)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_badge)
	_zone_label = UiStyle.outline_label("", 56, 10, UiStyle.COLOR_TEXT)
	_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_zone_label)
	_mini_label = UiStyle.outline_label("", 32, 7, UiStyle.COLOR_TEXT)
	_mini_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_mini_label)
	_luck_box = VBoxContainer.new()
	_luck_box.add_theme_constant_override("separation", 0)
	_luck_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_luck_box)
	_luck_label = UiStyle.outline_label("", 44, 8, GOLD)
	_luck_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_luck_box.add_child(_luck_label)
	_hint_label = UiStyle.outline_label(Loc.t("flight_luck_hint"), 22, 5, UiStyle.COLOR_TEXT)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_luck_box.add_child(_hint_label)


## Круглый значок биома в плашке: рисует общий ZoneBadge.
class _BadgeView extends Control:
	var zone: int = 0

	func _draw() -> void:
		ZoneBadge.draw_badge(self, size * 0.5, minf(size.x, size.y), zone)
