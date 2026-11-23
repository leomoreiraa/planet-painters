class_name PlanetCreatorController
extends Node3D

# PlanetCreatorController.gd
# Gerencia a câmera orbital, raycast do pincel 3D, atalhos de teclado profissionais
# e ferramentas de pintura e escultura da malha do planeta.

signal element_picked(element_key: String)
signal tool_mode_changed(mode: String)
signal brush_radius_changed(new_radius: float)
signal planet_scale_changed(new_scale: float)

@export var planet: PlanetMesh
@export var camera: Camera3D
@export var brush_cursor: Node3D

# Configurações do Pincel
var current_mode: String = "PAINT" # "PAINT", "ELEVATE", "CARVE", "SMOOTH", "FLATTEN", "FILL", "EYEDROPPER"
var current_element: String = "water"
var brush_shape: String = "SMOOTH" # "SMOOTH", "HARD", "NOISE"
var brush_radius: float = 0.25
var brush_strength: float = 1.0
var flatten_target_height: float = 0.0

# Tamanho do Planeta
var planet_scale: float = 1.0

# Controles de Câmera Orbital
var camera_distance: float = 13.5
var min_distance: float = 5.0
var max_distance: float = 22.0
var orbit_rot_x: float = -0.22
var orbit_rot_y: float = 0.5
var target_rot_x: float = -0.22
var target_rot_y: float = 0.5

var is_orbiting: bool = false
var is_painting: bool = false
var auto_rotate: bool = false
var auto_rotate_speed: float = 0.2

var last_mouse_pos: Vector2 = Vector2.ZERO
var _sound_timer: float = 0.0

func _ready() -> void:
	_update_camera_transform()
	_update_mouse_cursor()

func _process(delta: float) -> void:
	if auto_rotate and not is_orbiting and not is_painting:
		target_rot_y += auto_rotate_speed * delta

	orbit_rot_x = lerpf(orbit_rot_x, target_rot_x, delta * 12.0)
	orbit_rot_y = lerpf(orbit_rot_y, target_rot_y, delta * 12.0)
	_update_camera_transform()

	if is_painting and planet:
		_apply_brush_at_mouse(delta)

		_sound_timer -= delta
		if _sound_timer <= 0.0:
			if current_mode == "PAINT" or current_mode == "FILL":
				SoundEffects.play_paint()
			else:
				SoundEffects.play_sculpt()
			_sound_timer = 0.12

func _update_camera_transform() -> void:
	if not camera:
		return

	target_rot_x = clampf(target_rot_x, -1.45, 1.45)
	var rot := Basis(Vector3.UP, orbit_rot_y) * Basis(Vector3.RIGHT, orbit_rot_x)
	var offset := rot * Vector3(0, 0, camera_distance)
	var center: Vector3 = planet.global_position if planet else Vector3.ZERO
	# Desloca ligeiramente o ponto focal para baixo (-0.27), enquadrando o planeta
	# perfeitamente no centro da área útil entre a TopBar e a BottomDock
	var target_look: Vector3 = center + Vector3(0, -0.27, 0)
	camera.global_position = center + offset
	camera.look_at(target_look, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	# Atalhos de Teclado Profissionais
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		# Ctrl+Z (Desfazer) e Ctrl+Y / Ctrl+Shift+Z (Refazer)
		if k.is_command_or_control_pressed():
			if k.keycode == KEY_Z:
				if k.shift_pressed:
					if planet and planet.can_redo():
						planet.redo()
						SoundEffects.play_click()
				else:
					if planet and planet.can_undo():
						planet.undo()
						SoundEffects.play_click()
				return
			elif k.keycode == KEY_Y:
				if planet and planet.can_redo():
					planet.redo()
					SoundEffects.play_click()
				return

		# Teclas de ferramentas 1 a 6
		match k.keycode:
			KEY_1:
				set_tool_mode("PAINT")
			KEY_2:
				set_tool_mode("ELEVATE")
			KEY_3:
				set_tool_mode("CARVE")
			KEY_4:
				set_tool_mode("SMOOTH")
			KEY_5:
				set_tool_mode("FLATTEN")
			KEY_6:
				set_tool_mode("FILL")
			KEY_I:
				set_tool_mode("EYEDROPPER")
			KEY_BRACKETLEFT:
				brush_radius = clampf(brush_radius - 0.02, 0.04, 1.6)
				brush_radius_changed.emit(brush_radius)
			KEY_BRACKETRIGHT:
				brush_radius = clampf(brush_radius + 0.02, 0.04, 1.6)
				brush_radius_changed.emit(brush_radius)
			KEY_PAGEDOWN:
				set_planet_scale(planet_scale - 0.1)
			KEY_PAGEUP:
				set_planet_scale(planet_scale + 0.1)
			KEY_SPACE:
				auto_rotate = not auto_rotate
				SoundEffects.play_click()

	# Zoom da câmera e atalho de tamanho do pincel (Ctrl+Roda ou Shift+Roda)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.is_command_or_control_pressed() or mb.shift_pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				brush_radius = clampf(brush_radius + 0.02, 0.04, 1.6)
				brush_radius_changed.emit(brush_radius)
				_update_brush_cursor(mb.position)
				get_viewport().set_input_as_handled()
				return
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				brush_radius = clampf(brush_radius - 0.02, 0.04, 1.6)
				brush_radius_changed.emit(brush_radius)
				_update_brush_cursor(mb.position)
				get_viewport().set_input_as_handled()
				return

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera_distance = clampf(camera_distance - 0.5, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera_distance = clampf(camera_distance + 0.5, min_distance, max_distance)

		# Botão direito ou meio: rotaciona câmera
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				is_orbiting = true
				last_mouse_pos = mb.position
			else:
				is_orbiting = false

		# Botão esquerdo: pinta / esculpe
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit_result := _raycast_planet(mb.position)
				if hit_result.hit:
					if current_mode == "EYEDROPPER":
						var sampled: String = planet.sample_element_at(hit_result.position)
						element_picked.emit(sampled)
						SoundEffects.play_click()
						set_tool_mode("PAINT")
						return
					elif current_mode == "FILL":
						planet.fill_planet(current_element)
						SoundEffects.play_paint()
						return
					elif current_mode == "FLATTEN":
						flatten_target_height = planet.get_height_at(hit_result.position)

					is_painting = true
					_apply_brush_at_pos(hit_result.position, 0.016)
				else:
					is_orbiting = true
					last_mouse_pos = mb.position
			else:
				if is_painting and planet:
					planet.end_stroke()
					planet.recalculate_composition()
				is_painting = false
				is_orbiting = false

	# Movimento do mouse
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_orbiting:
			var diff := mm.position - last_mouse_pos
			target_rot_y -= diff.x * 0.006
			target_rot_x -= diff.y * 0.006
			last_mouse_pos = mm.position

		_update_brush_cursor(mm.position)

func set_planet_scale(s: float) -> void:
	planet_scale = clampf(s, 0.5, 2.0)
	if planet:
		planet.scale = Vector3.ONE * planet_scale
	planet_scale_changed.emit(planet_scale)
	SoundEffects.play_click()

func set_tool_mode(mode: String) -> void:
	current_mode = mode
	_update_mouse_cursor()
	tool_mode_changed.emit(mode)
	SoundEffects.play_click()

func _update_mouse_cursor() -> void:
	var cur_path: String = "res://resources/ui/cursor_pointer.png"
	var hotspot: Vector2 = Vector2(2, 2)
	if current_mode == "EYEDROPPER":
		cur_path = "res://resources/ui/cursor_eyedrop.png"
		hotspot = Vector2(6, 6)
	elif current_mode in ["ELEVATE", "CARVE", "SMOOTH", "FLATTEN"]:
		cur_path = "res://resources/ui/cursor_hammer.png"
		hotspot = Vector2(6, 6)
	var tex = load(cur_path)
	if tex:
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)

func _update_brush_cursor(mouse_pos: Vector2) -> void:
	if not brush_cursor or not planet:
		return

	var hit := _raycast_planet(mouse_pos)
	if hit.hit:
		brush_cursor.visible = true
		var normal: Vector3 = (hit.position - planet.global_position).normalized()
		# Eleva ligeiramente acima da superfície para não cortar ou afundar na esfera
		brush_cursor.global_position = hit.position + normal * (0.025 * planet_scale)

		# Alinha a base para que o eixo local Y seja a normal da esfera.
		# Como o TorusMesh fica no plano X-Z, o anel circular fica 100% paralelo e tangente à superfície do planeta!
		var up: Vector3 = normal
		var right: Vector3 = up.cross(Vector3.UP)
		if right.length_squared() < 0.001:
			right = up.cross(Vector3.RIGHT)
		right = right.normalized()
		var forward: Vector3 = right.cross(up).normalized()

		var eff_r: float = brush_radius * planet_scale
		brush_cursor.global_basis = Basis(right * eff_r, up * eff_r, forward * eff_r)
	else:
		brush_cursor.visible = false

func _apply_brush_at_mouse(delta: float) -> void:
	var viewport := get_viewport()
	if not viewport:
		return
	var mouse_pos := viewport.get_mouse_position()
	var hit := _raycast_planet(mouse_pos)
	if hit.hit:
		_apply_brush_at_pos(hit.position, delta)
		_update_brush_cursor(mouse_pos)

func _apply_brush_at_pos(pos: Vector3, delta: float) -> void:
	if not planet:
		return

	planet.apply_brush(
		pos,
		current_mode,
		current_element,
		brush_radius,
		brush_strength,
		delta,
		brush_shape,
		flatten_target_height
	)

func _raycast_planet(mouse_pos: Vector2) -> Dictionary:
	var result := {"hit": false, "position": Vector3.ZERO}
	if not camera or not planet:
		return result

	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var center := planet.global_position
	var r := (planet.base_radius + 0.35) * planet_scale

	var oc := ray_origin - center
	var b := oc.dot(ray_dir)
	var c := oc.dot(oc) - r * r
	var disc := b * b - c

	if disc >= 0.0:
		var sqrt_disc := sqrt(disc)
		var t := -b - sqrt_disc
		if t > 0.0:
			result.hit = true
			result.position = ray_origin + ray_dir * t

	return result
