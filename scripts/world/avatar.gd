class_name Avatar
extends Node3D
## Герой: подросток-смотритель зоопарка (данные HeroRecipe, меш HeroBuilder). Вся анимация кодом по костям, без AnimationPlayer.
## Публичный интерфейс прежний (set_walk, set_carrying, carry_socket, play_throw, play_pullup, reset_pose, set_colors),
## остальной код ничего не замечает. Герой смотрит в -Z, как раньше.
##
## Два способа собрать скелет (переключатель USE_SKELETON):
##  false: узлы-кости Node3D, у каждой кости свой меш (около 20 MeshInstance3D). Надёжный путь, внешне то же самое.
##  true:  Skeleton3D и один MeshInstance3D со скином (один вызов отрисовки на героя). Включай после проверки в вебе.
## Каждый блок целиком привязан к одной кости, поэтому оба режима выглядят одинаково.
##
## Слои позы по порядку: покой (дыхание, моргание, оглядывание), ходьба и бег (по скорости), бросок, зверь в руках, подтягивание.
## Сверху вторичное движение: рюкзак и зелёная ткань запаздывают за телом, наклон в повороте.

const USE_SKELETON: bool = false

const WALK_SPEED_MAX: float = 7.0
const WALK_PHASE_PER_M: float = 1.9          # радиан фазы на метр пути
const WALK_AMP_RATE: float = 8.0             # скорость появления и затухания шага
const RUN_FROM: float = 3.5                  # со скорости выше этой начинается переход от ходьбы к бегу
const THROW_TIME: float = 0.55
const PULLUP_DEFAULT: float = 0.3
const PULLUP_HOLD_S: float = 0.7             # сколько герой висит на турнике после последнего повторения
const SHOULDER_Y: float = 1.18              # высота плеча над ногами в покое (по модели героя, HeroRecipe)
const ARM_UPPER: float = 0.25                # плечо: от плеча до локтя
const ARM_LOWER: float = 0.30                # предплечье с кистью: от локтя до центра кисти
const GRIP_FORWARD: float = 0.2              # перекладина впереди игрока по -Z (BarView.CROSSBAR_Z относительно игрока)
const HANG_BACK: float = 0.3                # на сколько тело отодвинуто назад от перекладины (+Z), чтобы голова не входила в неё
const HANG_REACH: float = 0.545              # расстояние плечо-кисть в виске (почти прямые руки)
const PULLUP_RISE: float = 0.10              # на сколько плечо приближается к перекладине в верхней точке повторения
const CARRY_ANCHOR_POS: Vector3 = Vector3(-0.20, 0.34, 0.0)   # от кости chest: плечо левой руки, как у прежнего аватара
const CARRY_ANCHOR_ROT_X: float = 1.45       # такой же поворот, как у прежней руки: CarryController не меняется
const BLINK_TIME: float = 0.14

var _built: bool = false
var _carrying: bool = false
var _walk_speed: float = 0.0
var _walk_amp: float = 0.0
var _walk_phase: float = 0.0
var _run_k: float = 0.0
var _throw_t: float = 0.0
var _pullup_t: float = 0.0
var _pullup_duration: float = PULLUP_DEFAULT
var _hang_t: float = 0.0
var _hang_w: float = 0.0
var _pull_k: float = 0.0
var _carry_w: float = 0.0
var _t: float = 0.0
var _body_y: float = 0.0
var _body_z: float = 0.0
var _blink_in: float = 2.5
var _blink_t: float = -1.0
var _look_in: float = 3.0
var _look_target: float = 0.0
var _look_yaw: float = 0.0
var _pack_x: float = 0.0
var _cloth1: float = 0.0
var _cloth2: float = 0.0
var _turn_roll: float = 0.0
var _last_parent_yaw: float = 0.0
var _prev_bob: float = 0.0

var _bone_names: Array[String] = []
var _bone_rest: PackedVector3Array = PackedVector3Array()
var _idx: Dictionary = {}                # имя кости -> номер
var _rot: PackedVector3Array = PackedVector3Array()   # углы (рад, порядок YXZ) каждой кости на этом кадре
var _nodes: Array[Node3D] = []           # режим узлов-костей
var _skeleton: Skeleton3D                # режим Skeleton3D
var _carry_anchor: Node3D
var _eye_l: int = -1
var _eye_r: int = -1


func _ready() -> void:
	ensure_built()


## Собирает героя, если ещё не собран (нужно, например, в тестах, где узел не в дереве).
func ensure_built() -> void:
	if not _built:
		_build()


## Раньше задавало цвета кожи, рубашки и штанов. Кастомизации пока нет, метод оставлен для совместимости и ничего не делает.
func set_colors(_skin: Color, _shirt: Color, _pants: Color) -> void:
	pass


## Текущая скорость ходьбы в м/с. 0 останавливает анимацию шага.
func set_walk(speed: float) -> void:
	_walk_speed = clampf(speed, 0.0, WALK_SPEED_MAX)


func set_carrying(value: bool) -> void:
	_carrying = value
	_throw_t = 0.0
	if value:
		_pullup_t = 0.0
		_hang_t = 0.0


## Точка крепления зверя. Рамка совпадает с прежним плечом левой руки: CarryController ставит зверя тем же смещением.
func carry_socket() -> Node3D:
	ensure_built()
	return _carry_anchor if _carry_anchor != null else self


func play_throw() -> void:
	if _carrying:
		return
	_throw_t = THROW_TIME


## Одно повторение. Пока повторения идут, герой висит на перекладине, после паузы PULLUP_HOLD_S отпускает её.
func play_pullup(duration: float = PULLUP_DEFAULT) -> void:
	_pullup_duration = maxf(duration, 0.05)
	_pullup_t = _pullup_duration
	_hang_t = PULLUP_HOLD_S + _pullup_duration


func reset_pose() -> void:
	_walk_speed = 0.0
	_walk_amp = 0.0
	_walk_phase = 0.0
	_run_k = 0.0
	_throw_t = 0.0
	_pullup_t = 0.0
	_hang_t = 0.0
	_hang_w = 0.0
	_pull_k = 0.0
	_carry_w = 1.0 if _carrying else 0.0
	_body_y = 0.0
	_body_z = 0.0
	position.y = 0.0
	position.z = 0.0
	if _built:
		_rot.fill(Vector3.ZERO)
		_apply_pose(1.0)


func _process(delta: float) -> void:
	if not _built:
		return
	_update_state(delta)
	_rot.fill(Vector3.ZERO)
	_body_y = 0.0
	_body_z = 0.0
	_pose_idle()
	_pose_walk()
	_pose_throw()
	_pose_carry()
	_pose_hang()
	_pose_secondary(delta)
	_apply_pose(_eye_scale())


# ---------- Состояние ----------

func _update_state(delta: float) -> void:
	_t += delta
	var k: float = clampf(delta * WALK_AMP_RATE, 0.0, 1.0)
	_walk_amp = lerpf(_walk_amp, 1.0 if _walk_speed > 0.15 else 0.0, k)
	_walk_phase += _walk_speed * WALK_PHASE_PER_M * delta
	_run_k = lerpf(_run_k, clampf((_walk_speed - RUN_FROM) / (WALK_SPEED_MAX - RUN_FROM), 0.0, 1.0), clampf(delta * 6.0, 0.0, 1.0))
	_throw_t = maxf(_throw_t - delta, 0.0)
	_pullup_t = maxf(_pullup_t - delta, 0.0)
	_hang_t = maxf(_hang_t - delta, 0.0)
	_hang_w = move_toward(_hang_w, 1.0 if _hang_t > 0.0 else 0.0, delta * 7.0)
	var rep: float = 0.0
	if _pullup_t > 0.0:
		rep = sin((1.0 - _pullup_t / _pullup_duration) * PI)
	_pull_k = lerpf(_pull_k, rep, clampf(delta * 18.0, 0.0, 1.0))
	_carry_w = move_toward(_carry_w, 1.0 if _carrying else 0.0, delta * 6.0)
	# моргание
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t >= BLINK_TIME:
			_blink_t = -1.0
			_blink_in = randf_range(2.0, 5.5)
	else:
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_t = 0.0
	# в покое герой изредка оглядывается
	_look_in -= delta
	if _look_in <= 0.0:
		_look_target = 0.0 if absf(_look_target) > 0.05 else randf_range(-0.7, 0.7)
		_look_in = randf_range(2.5, 6.0)
	_look_yaw = lerpf(_look_yaw, _look_target, clampf(delta * 3.0, 0.0, 1.0))
	# наклон в повороте по скорости вращения родителя (игрока)
	var par: Node3D = get_parent() as Node3D
	var yaw_rate: float = 0.0
	if par != null:
		yaw_rate = angle_difference(_last_parent_yaw, par.rotation.y) / maxf(delta, 0.0001)
		_last_parent_yaw = par.rotation.y
	_turn_roll = lerpf(_turn_roll, clampf(-yaw_rate * 0.025, -0.18, 0.18) * _walk_amp, clampf(delta * 8.0, 0.0, 1.0))


func _eye_scale() -> float:
	if _blink_t < 0.0:
		return 1.0
	return 1.0 - 0.9 * sin(_blink_t / BLINK_TIME * PI)


# ---------- Слои позы ----------

# Покой: дыхание, лёгкий перенос веса, расслабленные руки, оглядывание.
func _pose_idle() -> void:
	var calm: float = 1.0 - _walk_amp
	var br: float = sin(_t * 1.9)
	_add("chest", br * 0.014, 0.0, 0.0)
	_add("spine", 0.03 + br * 0.008, 0.0, sin(_t * 0.45) * 0.02 * calm)
	_add("hips", 0.0, 0.0, -sin(_t * 0.45) * 0.02 * calm)
	_add("neck", 0.0, _look_yaw * 0.4 * calm, 0.0)
	_add("head", -0.03 - br * 0.012, _look_yaw * 0.6 * calm, 0.0)
	_add("upper_arm_L", 0.0, 0.0, -0.10)
	_add("upper_arm_R", 0.0, 0.0, 0.10)
	_add("forearm_L", 0.14, 0.0, 0.0)
	_add("forearm_R", 0.14, 0.0, 0.0)
	_add("hand_L", 0.05, 0.0, 0.0)
	_add("hand_R", 0.05, 0.0, 0.0)


# Ходьба и бег: размах и сгиб колена растут со скоростью, руки против ног, корпус скручивается и наклоняется вперёд.
func _pose_walk() -> void:
	var a: float = _walk_amp
	if a < 0.001:
		return
	var r: float = _run_k
	var p: float = _walk_phase
	var s: float = sin(p)
	var c: float = cos(p)
	var swing: float = lerpf(0.55, 1.0, r) * a
	_add("thigh_L", s * swing, 0.0, 0.0)
	_add("thigh_R", -s * swing, 0.0, 0.0)
	var knee: float = lerpf(0.9, 1.5, r) * a
	_add("shin_L", -(0.12 + maxf(c, 0.0) * knee) * a, 0.0, 0.0)
	_add("shin_R", -(0.12 + maxf(-c, 0.0) * knee) * a, 0.0, 0.0)
	_add("foot_L", (0.1 * s + maxf(c, 0.0) * 0.25) * a, 0.0, 0.0)
	_add("foot_R", (-0.1 * s + maxf(-c, 0.0) * 0.25) * a, 0.0, 0.0)
	var arm: float = lerpf(0.5, 0.9, r) * a
	_add("upper_arm_L", -s * arm, 0.0, 0.0)
	_add("upper_arm_R", s * arm, 0.0, 0.0)
	var bend: float = lerpf(0.25, 1.4, r) * a
	_add("forearm_L", bend + maxf(s, 0.0) * 0.2 * a, 0.0, 0.0)
	_add("forearm_R", bend + maxf(-s, 0.0) * 0.2 * a, 0.0, 0.0)
	_add("spine", lerpf(0.03, 0.22, r) * a, s * 0.10 * a, 0.0)
	_add("chest", 0.0, s * 0.08 * a, 0.0)
	_add("hips", 0.0, -s * 0.10 * a, c * 0.04 * a)
	_add("head", -lerpf(0.0, 0.12, r) * a, -s * 0.17 * a, 0.0)
	_body_y += (1.0 - absf(s)) * lerpf(0.035, 0.07, r) * a


# Бросок: замах назад, быстрый выпуск (еда вылетает примерно на 0.32 с), доводка.
func _pose_throw() -> void:
	if _throw_t <= 0.0:
		return
	var u: float = 1.0 - _throw_t / THROW_TIME
	var w: float = smoothstep(0.0, 0.10, u) * (1.0 - smoothstep(0.80, 1.0, u))
	var wind: float = smoothstep(0.0, 0.28, u) * (1.0 - smoothstep(0.28, 0.46, u))
	var swing: float = smoothstep(0.28, 0.56, u) * (1.0 - smoothstep(0.64, 1.0, u))
	_blend("upper_arm_R", -1.6 * wind + 2.65 * swing, 0.0, 0.38 * wind + 0.10 * swing, w)
	_blend("forearm_R", 1.7 * wind + 0.15 * swing, 0.0, 0.0, w)
	_blend("hand_R", -0.3 * wind, 0.0, 0.0, w)
	_blend("upper_arm_L", 1.0 * wind - 0.6 * swing, 0.0, -0.2 * wind - 0.5 * swing, w)
	_blend("forearm_L", 0.45 * wind, 0.0, 0.0, w)
	_blend("spine", -0.1 * wind + 0.28 * swing, -0.45 * wind + 0.42 * swing, 0.0, w)
	_blend("chest", 0.0, -0.25 * wind + 0.25 * swing, 0.0, w)
	_blend("head", -0.05 * swing, 0.5 * wind - 0.5 * swing, 0.0, w)
	_blend("thigh_L", 0.25 * wind + 0.7 * swing, 0.0, 0.0, w)
	_blend("shin_L", -0.2 * wind - 0.45 * swing, 0.0, 0.0, w)
	_blend("thigh_R", -0.28 * wind - 0.4 * swing, 0.0, 0.0, w)
	_blend("shin_R", -0.25 * wind - 0.3 * swing, 0.0, 0.0, w)
	_body_y += -0.03 * wind * w


# Зверь в руках: левая рука держит рамку CarryAnchor, правая подпирает. Ноги продолжают ходить.
func _pose_carry() -> void:
	var w: float = _carry_w
	if w < 0.001:
		return
	_blend("upper_arm_L", CARRY_ANCHOR_ROT_X, 0.0, -0.05, w)
	_blend("forearm_L", 0.15, 0.0, 0.0, w)
	_blend("hand_L", 0.1, 0.0, 0.0, w)
	_blend("upper_arm_R", 1.25, 0.0, -0.30, w)
	_blend("forearm_R", 0.35, 0.0, 0.0, w)
	_add("spine", -0.10 * w, 0.0, 0.0)
	_add("chest", -0.05 * w, 0.0, 0.0)
	_add("head", 0.08 * w, 0.0, 0.0)


# Подтягивание: руки вверх, повторение сгибает локти и поднимает тело, голова запрокидывается над перекладиной.
func _pose_hang() -> void:
	var w: float = _hang_w
	if w < 0.001:
		return
	var k: float = _pull_k
	# Кисти на перекладине (BarView.CROSSBAR_Y), плечо опускается/поднимается; углы руки решаем как двузвенник в плоскости (вверх, вперёд).
	# Локоть сгибается вперёд-вверх (положительный поворот предплечья), как у человека: назад он не выворачивается.
	var fwd: float = GRIP_FORWARD + HANG_BACK
	var up: float = sqrt(maxf(HANG_REACH * HANG_REACH - fwd * fwd, 0.0)) - PULLUP_RISE * k
	var arm: Vector3 = _arm_angles(up, fwd)
	_blend("upper_arm_L", arm.x, 0.0, -0.12, w)
	_blend("upper_arm_R", arm.x, 0.0, 0.12, w)
	_blend("forearm_L", arm.y, 0.0, 0.0, w)
	_blend("forearm_R", arm.y, 0.0, 0.0, w)
	_blend("hand_L", 0.15 * k, 0.0, 0.0, w)
	_blend("hand_R", 0.15 * k, 0.0, 0.0, w)
	_blend("thigh_L", 0.2 + 0.1 * k, 0.0, 0.0, w)
	_blend("thigh_R", 0.12 + 0.1 * k, 0.0, 0.0, w)
	_blend("shin_L", -1.1, 0.0, 0.0, w)
	_blend("shin_R", -1.2, 0.0, 0.0, w)
	_blend("foot_L", 0.35, 0.0, 0.0, w)
	_blend("foot_R", 0.35, 0.0, 0.0, w)
	_blend("spine", -0.05, 0.0, 0.0, w)
	_blend("chest", -0.05 * k, 0.0, 0.0, w)
	_blend("head", -0.3 * k, 0.0, 0.0, w)
	_body_y += (BarView.CROSSBAR_Y - up - SHOULDER_Y) * w
	_body_z += HANG_BACK * w


# Углы руки (x: плечо, y: предплечо относительно плеча) так, чтобы кисть была на `up` выше плеча и на `fwd` впереди него.
# Положительный угол ведёт вперёд-вверх; локоть всегда ниже линии плечо-кисть. Слишком далёкая цель даёт прямую руку.
func _arm_angles(up: float, fwd: float) -> Vector3:
	var reach: float = maxf(sqrt(up * up + fwd * fwd), 0.001)
	var theta_hand: float = atan2(fwd, -up)
	if reach >= ARM_UPPER + ARM_LOWER:
		return Vector3(theta_hand, 0.0, 0.0)
	var inner: float = acos(clampf((ARM_UPPER * ARM_UPPER + ARM_LOWER * ARM_LOWER - reach * reach) / (2.0 * ARM_UPPER * ARM_LOWER), -1.0, 1.0))
	var beta: float = acos(clampf((ARM_UPPER * ARM_UPPER + reach * reach - ARM_LOWER * ARM_LOWER) / (2.0 * ARM_UPPER * reach), -1.0, 1.0))
	return Vector3(theta_hand - beta, PI - inner, 0.0)


# Вторичное движение: рюкзак и ткань отстают от корпуса и подпрыгивают с шагом.
func _pose_secondary(delta: float) -> void:
	var a: float = _walk_amp
	var bob: float = _body_y
	var bob_vel: float = (bob - _prev_bob) / maxf(delta, 0.0001)
	_prev_bob = bob
	var lean: float = _rot[int(_idx.get("spine", 0))].x + _rot[int(_idx.get("chest", 0))].x
	var k: float = clampf(delta * 9.0, 0.0, 1.0)
	_pack_x = lerpf(_pack_x, -lean * 0.8 - clampf(bob_vel * 0.03, -0.12, 0.12), k)
	_add("backpack", _pack_x, 0.0, -_turn_roll * 0.6)
	_add("spine", 0.0, 0.0, _turn_roll)
	var speed_n: float = _walk_speed / WALK_SPEED_MAX
	_cloth1 = lerpf(_cloth1, -0.18 * speed_n * a + sin(_walk_phase - 0.9) * 0.14 * a + sin(_t * 1.6) * 0.04, clampf(delta * 8.0, 0.0, 1.0))
	_cloth2 = lerpf(_cloth2, -0.25 * speed_n * a + sin(_walk_phase - 1.8) * 0.22 * a + sin(_t * 1.6 - 0.8) * 0.06, clampf(delta * 6.0, 0.0, 1.0))
	_add("cloth1", _cloth1, 0.0, 0.0)
	_add("cloth2", _cloth2, 0.0, 0.0)


func _add(bone: String, x: float, y: float, z: float) -> void:
	var i: int = int(_idx.get(bone, -1))
	if i >= 0:
		_rot[i] += Vector3(x, y, z)


# Плавный переход кости к заданным углам с весом w.
func _blend(bone: String, x: float, y: float, z: float, w: float) -> void:
	var i: int = int(_idx.get(bone, -1))
	if i >= 0:
		_rot[i] = _rot[i].lerp(Vector3(x, y, z), w)


func _apply_pose(eye_y: float) -> void:
	position.y = _body_y
	position.z = _body_z
	var eye_scale := Vector3(1.0, eye_y, 1.0)
	for i in _rot.size():
		if _skeleton != null:
			_skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(_rot[i]))
		else:
			_nodes[i].rotation = _rot[i]
	if _skeleton != null:
		if _eye_l >= 0:
			_skeleton.set_bone_pose_scale(_eye_l, eye_scale)
		if _eye_r >= 0:
			_skeleton.set_bone_pose_scale(_eye_r, eye_scale)
	else:
		if _eye_l >= 0:
			_nodes[_eye_l].scale = eye_scale
		if _eye_r >= 0:
			_nodes[_eye_r].scale = eye_scale


# ---------- Сборка ----------

func _build() -> void:
	var bones: Array = HeroRecipe.BONES
	var parents: PackedInt32Array = PackedInt32Array()
	for i in bones.size():
		var bone: Array = bones[i]
		var bone_name: String = String(bone[0])
		_bone_names.append(bone_name)
		_bone_rest.append(bone[2] as Vector3)
		_idx[bone_name] = i
		var parent_name: String = String(bone[1])
		parents.append(int(_idx[parent_name]) if parent_name != "" else -1)
	var data: Dictionary = HeroBuilder.generate(bones, HeroRecipe.BLOCKS)
	var errors: Array = data["errors"]
	if not errors.is_empty():
		push_error("Avatar: данные героя с ошибками: " + str(errors))
		return
	_rot.resize(bones.size())
	_rot.fill(Vector3.ZERO)
	if USE_SKELETON:
		_build_skeleton(data, parents)
	else:
		_build_nodes(data, parents)
	_eye_l = int(_idx.get("eye_L", -1))
	_eye_r = int(_idx.get("eye_R", -1))
	_built = true


func _local_rest(i: int, parents: PackedInt32Array) -> Vector3:
	var parent: int = parents[i]
	return _bone_rest[i] - (_bone_rest[parent] if parent >= 0 else Vector3.ZERO)


func _build_nodes(data: Dictionary, parents: PackedInt32Array) -> void:
	for i in _bone_names.size():
		var node := Node3D.new()
		node.name = _bone_names[i]
		node.position = _local_rest(i, parents)
		var host: Node3D = self if parents[i] < 0 else _nodes[parents[i]]
		host.add_child(node)
		_nodes.append(node)
		var mesh: ArrayMesh = HeroBuilder.mesh_for_bone(data, _bone_names[i], _bone_rest[i])
		if mesh != null:
			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = mesh
			mi.material_override = AnimalBuilder.material()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 0.5
			node.add_child(mi)
	_carry_anchor = _make_anchor()
	_nodes[int(_idx["chest"])].add_child(_carry_anchor)


func _build_skeleton(data: Dictionary, parents: PackedInt32Array) -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton"
	add_child(_skeleton)
	for i in _bone_names.size():
		_skeleton.add_bone(_bone_names[i])
	for i in _bone_names.size():
		if parents[i] >= 0:
			_skeleton.set_bone_parent(i, parents[i])
	for i in _bone_names.size():
		_skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, _local_rest(i, parents)))
	_skeleton.reset_bone_poses()
	var skin := Skin.new()
	for i in _bone_names.size():
		skin.add_named_bind(_bone_names[i], _skeleton.get_bone_global_rest(i).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = HeroBuilder.skinned_mesh(data, _bone_names)
	mi.skin = skin
	mi.material_override = AnimalBuilder.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 0.5
	_skeleton.add_child(mi)
	var attach := BoneAttachment3D.new()
	attach.name = "ChestAttach"
	_skeleton.add_child(attach)
	attach.bone_name = "chest"
	_carry_anchor = _make_anchor()
	attach.add_child(_carry_anchor)


func _make_anchor() -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "CarryAnchor"
	anchor.position = CARRY_ANCHOR_POS
	anchor.rotation.x = CARRY_ANCHOR_ROT_X
	return anchor
