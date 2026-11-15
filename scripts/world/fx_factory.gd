class_name FxFactory
extends RefCounted
## Лёгкие эффекты полёта и приземления: мягкие круглые частицы на CPUParticles3D (без GPU-частиц и шейдеров).
## Всё создаётся один раз при показе, в _process ничего не создаётся.

static var _soft_tex: ImageTexture


## Мягкий круглый спрайт 32x32 (яркая середина, плавный край).
static func soft_texture() -> ImageTexture:
	if _soft_tex == null:
		var n: int = 32
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
		var c: float = (float(n) - 1.0) * 0.5
		for y in n:
			for x in n:
				var d: float = Vector2(float(x) - c, float(y) - c).length() / c
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(clampf(1.0 - d, 0.0, 1.0), 1.3)))
		_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex


static func _quad(size: float) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft_texture()
	mat.particles_anim_h_frames = 1
	mat.particles_anim_v_frames = 1
	mat.no_depth_test = false
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	mesh.material = mat
	return mesh


static func _fade(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([from, to])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	return g


static func _shrink() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.7))
	c.add_point(Vector2(1.0, 0.1))
	return c


static func _grow() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(1.0, 1.0))
	return c


## Мягкий шлейф за летящей едой: частицы остаются в мире, пока еда летит дальше. Включается через emitting.
static func make_trail(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Trail"
	p.amount = 28
	p.lifetime = 0.7
	p.local_coords = false
	p.emitting = false
	p.explosiveness = 0.0
	p.direction = Vector3(0.0, 0.0, 1.0)
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.mesh = _quad(0.7)
	p.scale_amount_curve = _shrink()
	p.color_ramp = _fade(Color(color.r, color.g, color.b, 0.75).lerp(Color(1, 1, 1, 0.75), 0.35), Color(color.r, color.g, color.b, 0.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Пыль при приземлении: облако вверх-в-стороны и кольцо, которое разбегается по земле. one_shot, узел убрать после показа.
static func make_dust(color: Color, power: float) -> Array[CPUParticles3D]:
	var res: Array[CPUParticles3D] = []
	var puff := CPUParticles3D.new()
	puff.name = "DustPuff"
	puff.one_shot = true
	puff.amount = 18
	puff.lifetime = 0.9
	puff.explosiveness = 1.0
	puff.direction = Vector3(0.0, 1.0, 0.0)
	puff.spread = 55.0
	puff.gravity = Vector3(0.0, -1.5, 0.0)
	puff.initial_velocity_min = 2.0 * power
	puff.initial_velocity_max = 5.0 * power
	puff.damping_min = 2.0
	puff.damping_max = 3.0
	puff.mesh = _quad(1.6)
	puff.scale_amount_curve = _grow()
	puff.color_ramp = _fade(Color(color.r, color.g, color.b, 0.7).lerp(Color(0.85, 0.8, 0.7, 0.7), 0.6), Color(0.85, 0.8, 0.7, 0.0))
	res.append(puff)
	var ring := CPUParticles3D.new()
	ring.name = "DustRing"
	ring.one_shot = true
	ring.amount = 20
	ring.lifetime = 0.7
	ring.explosiveness = 1.0
	ring.direction = Vector3(1.0, 0.0, 0.0)
	ring.spread = 180.0
	ring.flatness = 1.0
	ring.gravity = Vector3.ZERO
	ring.initial_velocity_min = 5.0 * power
	ring.initial_velocity_max = 7.0 * power
	ring.damping_min = 5.0
	ring.damping_max = 7.0
	ring.mesh = _quad(1.0)
	ring.scale_amount_curve = _grow()
	ring.color_ramp = _fade(Color(0.9, 0.85, 0.75, 0.6), Color(0.9, 0.85, 0.75, 0.0))
	res.append(ring)
	return res
