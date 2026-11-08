class_name CarryController
extends Node3D
## Перенос пойманного зверя, маркер свободного размещения и возврат в рюкзак.
## Маркер и кнопка «Поставить» работают только пока игрок стоит внутри своего загона; снаружи подсказка зовёт зайти.

const MARKER_RADIUS := 0.8

var player: Player
var camera_rig: CameraRig
var hud: Hud
var slot_manager: Node
var router: InputRouter
var hotbar: Hotbar
var throw_controller: ThrowController
var current_uid := -1
var pending_uid := -1
var _held: AnimalView
var _marker: MeshInstance3D
var _put_button: Button
var _back_button: Button
var _message: Label
var _inside: bool = false              # игрок сейчас в своём загоне


func _ready() -> void:
	_build_marker()
	_build_controls()
	Game.animal_received.connect(_on_animal_received)
	Game.inventory_changed.connect(_refresh_hotbar)


func is_carrying() -> bool:
	return current_uid >= 0


func _on_animal_received(animal: Dictionary) -> void:
	if int(animal.get("sold", 0)) == 1:
		return
	pending_uid = int(animal.get("uid", -1))


func on_reveal_finished() -> void:
	if pending_uid < 0:
		return
	var uid := pending_uid
	pending_uid = -1
	Game.unplace(uid)
	take(uid)


func take(uid: int) -> void:
	if is_carrying():
		put_away()
	var animal := Game.animal_by_uid(uid)
	if animal.is_empty():
		return
	if int(animal.get("placed", 0)) == 1:
		Game.unplace(uid)
	if throw_controller != null:
		throw_controller.cancel_for_carry()
	if player != null:
		player.enabled = true
	current_uid = uid
	_refresh_hotbar()
	if player != null:
		player.set_carrying(true)
		if player.avatar != null:
			player.avatar.set_carrying(true)
	_attach_held(animal)
	_put_button.visible = true
	_back_button.visible = true
	_message.visible = true
	_set_inside(_player_in_pen(), true)
	if hud != null:
		hud.set_mode(false)
		hud.set_throw_meter_enabled(false)
		hud.set_hint("Сначала поставь зверя")


func put_away() -> void:
	if not is_carrying():
		return
	if _held != null and is_instance_valid(_held):
		_held.queue_free()
	_held = null
	current_uid = -1
	_refresh_hotbar()
	if player != null:
		player.set_carrying(false)
		if player.avatar != null:
			player.avatar.set_carrying(false)
	_marker.visible = false
	_put_button.visible = false
	_back_button.visible = false
	_message.visible = false
	_refresh_hotbar()
	if hud != null:
		hud.set_throw_meter_enabled(true)
		hud.set_mode(true)


func place_at_cursor() -> bool:
	if not is_carrying():
		return false
	if not _player_in_pen():
		_show_message(Loc.t("carry_enter_pen"))
		return false
	if Game.placed_count() >= Game.total_slots():
		_show_message("Загон полон")
		return false
	var point := _target_point()
	if not WorldLayout.pen_rect_for_level(int(Save.data.get("slots_level", 0)), 1.5).has_point(Vector2(point.x, point.z)):
		return false
	var uid := current_uid
	if not Game.place(uid, point):
		_show_message("Загон полон")
		return false
	if _held != null:
		_held.queue_free()
	_held = null
	current_uid = -1
	if player != null:
		player.set_carrying(false)
		if player.avatar != null:
			player.avatar.set_carrying(false)
	_marker.visible = false
	_put_button.visible = false
	_back_button.visible = false
	_message.visible = false
	if slot_manager != null:
		slot_manager.refresh()
	_refresh_hotbar()
	if hud != null:
		hud.set_throw_meter_enabled(true)
		hud.set_mode(true)
	return true


func _process(_delta: float) -> void:
	if not is_carrying():
		return
	_set_inside(_player_in_pen())
	if _inside:
		_marker.position = _target_point() + Vector3.UP * 0.04


# Игрок стоит внутри своего загона (за передней оградой).
func _player_in_pen() -> bool:
	return player != null and WorldLayout.in_player_pen(player.position, Game.slots_level())


# Маркер и «Поставить» доступны только в загоне; текст подсказки меняется вместе с этим.
func _set_inside(value: bool, force: bool = false) -> void:
	if value == _inside and not force:
		return
	_inside = value
	_marker.visible = value
	_put_button.disabled = not value
	_message.text = Loc.t("carry_hint") if value else Loc.t("carry_enter_pen")


func _target_point() -> Vector3:
	if OS.has_feature("mobile") and player != null:
		return WorldLayout.clamp_pen_position(player.position + (-player.global_basis.z) * 2.0, int(Save.data.get("slots_level", 0)))
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var mouse := get_viewport().get_mouse_position()
		var origin := camera.project_ray_origin(mouse)
		var direction := camera.project_ray_normal(mouse)
		if absf(direction.y) > 0.0001:
			var t := -origin.y / direction.y
			if t > 0.0:
				var hit := origin + direction * t
				return WorldLayout.clamp_pen_position(hit, int(Save.data.get("slots_level", 0)))
	if player != null:
		var forward := -player.global_basis.z
		return WorldLayout.clamp_pen_position(player.position + forward * 2.0, int(Save.data.get("slots_level", 0)))
	return WorldLayout.clamp_pen_position(WorldLayout.pen_gate_position())


func _attach_held(animal: Dictionary) -> void:
	if player == null:
		return
	_held = AnimalView.new()
	_held.name = "CarriedAnimal"
	var socket: Node3D = player.avatar.carry_socket() if player.avatar != null else player
	socket.add_child(_held)
	var id := String(animal.get("animal_id", "frog"))
	var variant := int(animal.get("variant", 0))
	var size_step := SizeData.clamp_size(int(animal.get("size", 0)))
	_held.set_creature(id, variant, AnimalData.rarity_of(id),
		Economy.income(id, variant, size_step))
	_held.set_signs_visible(false)
	# Естественный масштаб: базовый размер вида × мутация размера
	var base_size_m: float = float(AnimalData.by_id(id).get("size_m", 1.2))
	var size_mult: float = SizeData.visual_scale(size_step)
	_held.scale = Vector3.ONE * (base_size_m * size_mult)
	_held.position = Vector3(0.0, -0.58, -0.05)
	_held.rotation.x = -1.45


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "PlacementMarker"
	var mesh := TorusMesh.new()
	mesh.inner_radius = MARKER_RADIUS - 0.06
	mesh.outer_radius = MARKER_RADIUS
	mesh.rings = 4
	mesh.ring_segments = 32
	_marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mat
	_marker.visible = false
	add_child(_marker)


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CarryControls"
	add_child(layer)
	_put_button = Button.new()
	_put_button.text = Loc.t("carry_place")
	_put_button.custom_minimum_size = Vector2(150, 64)
	_put_button.position = Vector2(960, 620)
	_put_button.visible = false
	_put_button.pressed.connect(place_at_cursor)
	layer.add_child(_put_button)
	_back_button = Button.new()
	_back_button.text = Loc.t("carry_back")
	_back_button.custom_minimum_size = Vector2(150, 64)
	_back_button.position = Vector2(960, 690)
	_back_button.visible = false
	_back_button.pressed.connect(put_away)
	layer.add_child(_back_button)
	_message = Label.new()
	_message.position = Vector2(380, 650)
	_message.size = Vector2(600, 40)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 26)
	_message.visible = false
	layer.add_child(_message)


func _show_message(value: String) -> void:
	_message.text = value
	_message.visible = true


func _refresh_hotbar() -> void:
	if hotbar != null:
		hotbar.carried_uid = current_uid
		hotbar.refresh()
