class_name PlanetMesh
extends Node3D

# PlanetMesh.gd
# Gerador e deformador 3D avançado de planeta baseado em cubo-esfera normalizada (Cube-Sphere).
# Suporta:
# - Deformação de malha em tempo real (Elevar, Cavar, Suavizar, Planar/Platô)
# - Pintura por elementos químicos da tabela periódica
# - Pincéis com formas: Suave (Gaussiano), Nítido (Hard) e Orgânico (Ruído fractal)
# - Sistema completo de Desfazer/Refazer (Undo/Redo - Ctrl+Z / Ctrl+Y)
# - Dispersão de vegetação, rochas e cristais 3D (PlanetScatter)
# - Camada de água/oceanos com nível do mar ajustável
# - Presets de biomas planetários (Terra, Marte, Glacial, Vulcânico, Alienígena)
# - Salvamento e carregamento de planetas em disco (JSON)

signal composition_updated(stats: Dictionary, planet_type: String)
signal history_changed(can_undo: bool, can_redo: bool)

@export var base_radius: float = 2.8
@export var face_resolution: int = 24 # 24x24 por face = 3.456 vértices otimizados

@onready var mesh_instance: MeshInstance3D = $SurfaceMesh
@onready var atmosphere_instance: MeshInstance3D = $AtmosphereMesh

var ocean_instance: MeshInstance3D
var scatter_node: PlanetScatter

var _array_mesh: ArrayMesh
var _base_dirs: PackedVector3Array = PackedVector3Array()
var _vertices: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _colors: PackedColorArray = PackedColorArray()
var _heights: PackedFloat32Array = PackedFloat32Array()
var _element_types: PackedByteArray = PackedByteArray()
var _uvs: PackedVector2Array = PackedVector2Array()
var _indices: PackedInt32Array = PackedInt32Array()

# Sistema de Histórico (Undo / Redo)
const MAX_HISTORY: int = 25
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _stroke_active: bool = false
var _stroke_initial_state: Dictionary = {}
var _stroke_modified: bool = false

# Ruído procedural para pincel orgânico
var _brush_noise: FastNoiseLite = FastNoiseLite.new()

# Materiais
var _material: ShaderMaterial
var _atmosphere_material: ShaderMaterial
var _ocean_material: StandardMaterial3D

# Nível dos mares
var sea_level: float = 0.0

# Definições dos elementos químicos
const ELEMENTS: Dictionary = {
	"water": {
		"symbol": "H₂O",
		"name": "Água / Oceanos",
		"color": Color(0.12, 0.45, 0.88),
		"roughness": 0.15,
		"metallic": 0.1,
		"default_height": -0.05
	},
	"carbon": {
		"symbol": "C",
		"name": "Carbono / Vegetação",
		"color": Color(0.18, 0.65, 0.28),
		"roughness": 0.8,
		"metallic": 0.0,
		"default_height": 0.04
	},
	"silicon": {
		"symbol": "Si",
		"name": "Silício / Rochas",
		"color": Color(0.55, 0.45, 0.38),
		"roughness": 0.9,
		"metallic": 0.05,
		"default_height": 0.08
	},
	"iron": {
		"symbol": "Fe",
		"name": "Ferro / Basalto",
		"color": Color(0.68, 0.25, 0.2),
		"roughness": 0.7,
		"metallic": 0.4,
		"default_height": 0.05
	},
	"gold": {
		"symbol": "Au",
		"name": "Ouro / Minerais",
		"color": Color(0.98, 0.78, 0.15),
		"roughness": 0.3,
		"metallic": 0.85,
		"default_height": 0.03
	},
	"ice": {
		"symbol": "N₂",
		"name": "Gelo / Nitrogênio",
		"color": Color(0.85, 0.94, 1.0),
		"roughness": 0.25,
		"metallic": 0.05,
		"default_height": 0.06
	},
	"sulfur": {
		"symbol": "S",
		"name": "Enxofre / Magma",
		"color": Color(0.95, 0.35, 0.05),
		"roughness": 0.4,
		"metallic": 0.1,
		"default_height": 0.02
	},
	"uranium": {
		"symbol": "U",
		"name": "Urânio / Energia",
		"color": Color(0.35, 0.95, 0.25),
		"roughness": 0.3,
		"metallic": 0.5,
		"default_height": 0.05
	}
}

# Terrenos e Biomas inspirados no WorldBox - God Simulator
const WORLDBOX_TERRAINS: Dictionary = {
	"deep_ocean": {
		"name": "Oceano",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_deep_ocean.png",
		"color": Color(0.06, 0.22, 0.58),
		"height": -0.16,
		"type_id": 0
	},
	"shallow_water": {
		"name": "Água Rasa",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_shallow_water.png",
		"color": Color(0.14, 0.55, 0.85),
		"height": -0.05,
		"type_id": 1
	},
	"sand": {
		"name": "Praia",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_sand.png",
		"color": Color(0.88, 0.78, 0.48),
		"height": 0.0,
		"type_id": 2
	},
	"grass": {
		"name": "Grama",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_grass.png",
		"color": Color(0.24, 0.68, 0.22),
		"height": 0.04,
		"type_id": 3
	},
	"forest": {
		"name": "Floresta",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_forest.png",
		"color": Color(0.12, 0.48, 0.18),
		"height": 0.06,
		"type_id": 4
	},
	"hills": {
		"name": "Colinas",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_hills.png",
		"color": Color(0.52, 0.44, 0.30),
		"height": 0.12,
		"type_id": 5
	},
	"mountains": {
		"name": "Montanhas",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_mountains.png",
		"color": Color(0.50, 0.48, 0.48),
		"height": 0.22,
		"type_id": 6
	},
	"snow_peak": {
		"name": "Picos Nev.",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_snow_peak.png",
		"color": Color(0.92, 0.95, 0.98),
		"height": 0.30,
		"type_id": 7
	},
	"snow": {
		"name": "Neve",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_snow.png",
		"color": Color(0.84, 0.92, 0.98),
		"height": 0.04,
		"type_id": 8
	},
	"desert": {
		"name": "Deserto",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_desert.png",
		"color": Color(0.88, 0.58, 0.25),
		"height": 0.02,
		"type_id": 9
	},
	"swamp": {
		"name": "Pântano",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_swamp.png",
		"color": Color(0.28, 0.38, 0.22),
		"height": 0.01,
		"type_id": 10
	},
	"lava": {
		"name": "Magma",
		"symbol": "",
		"icon_path": "res://resources/ui/icons/biome_lava.png",
		"color": Color(0.98, 0.32, 0.05),
		"height": 0.03,
		"type_id": 11
	}
}

func get_terrain_data(key: String) -> Dictionary:
	if WORLDBOX_TERRAINS.has(key):
		return WORLDBOX_TERRAINS[key]
	if ELEMENTS.has(key):
		return ELEMENTS[key]
	match key:
		"water": return WORLDBOX_TERRAINS["shallow_water"]
		"carbon": return WORLDBOX_TERRAINS["forest"]
		"silicon": return WORLDBOX_TERRAINS["mountains"]
		"iron": return WORLDBOX_TERRAINS["hills"]
		"gold": return WORLDBOX_TERRAINS["sand"]
		"ice": return WORLDBOX_TERRAINS["snow"]
		"sulfur": return WORLDBOX_TERRAINS["lava"]
		"uranium": return WORLDBOX_TERRAINS["lava"]
	return WORLDBOX_TERRAINS["grass"]

func _ready() -> void:
	_init_brush_noise()
	_init_scatter_system()
	_init_ocean_layer()
	_init_planet_mesh()
	setup_canvas("OCEAN")
	clear_history()

func _init_brush_noise() -> void:
	_brush_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_brush_noise.frequency = 2.0
	_brush_noise.fractal_octaves = 3

func _init_scatter_system() -> void:
	scatter_node = get_node_or_null("Scatter") as PlanetScatter
	if not scatter_node:
		scatter_node = PlanetScatter.new()
		scatter_node.name = "Scatter"
		add_child(scatter_node)

func _init_ocean_layer() -> void:
	ocean_instance = get_node_or_null("OceanMesh") as MeshInstance3D
	if not ocean_instance:
		ocean_instance = MeshInstance3D.new()
		ocean_instance.name = "OceanMesh"
		var sph := SphereMesh.new()
		sph.radius = base_radius
		sph.height = base_radius * 2.0
		sph.radial_segments = 48
		sph.rings = 24
		ocean_instance.mesh = sph
		add_child(ocean_instance)

	_ocean_material = StandardMaterial3D.new()
	_ocean_material.albedo_color = Color(0.10, 0.45, 0.85, 0.75)
	_ocean_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ocean_material.roughness = 0.12
	_ocean_material.metallic = 0.05
	_ocean_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	ocean_instance.material_override = _ocean_material
	ocean_instance.visible = false # Ativado conforme sea_level

func _init_planet_mesh() -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("SurfaceMesh") as MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "SurfaceMesh"
		add_child(mesh_instance)

	if not atmosphere_instance:
		atmosphere_instance = get_node_or_null("AtmosphereMesh") as MeshInstance3D

	# Material Cartoon com texturas procedurais orgânicas para a superfície
	var cartoon_shader: Shader = load("res://shaders/planet_cartoon.gdshader")
	_material = ShaderMaterial.new()
	_material.shader = cartoon_shader
	_material.set_shader_parameter("use_vertex_color", true)
	_material.set_shader_parameter("use_stepped", true)
	_material.set_shader_parameter("steps", 3.0)
	_material.set_shader_parameter("step_smoothness", 0.05)
	_material.set_shader_parameter("shadow_tint", Color(0.14, 0.16, 0.28, 1.0))
	_material.set_shader_parameter("shadow_tint_amount", 0.45)
	mesh_instance.material_override = _material

	# Material Cartoon para a atmosfera
	var atmo_shader: Shader = load("res://shaders/atmosphere_cartoon.gdshader")
	_atmosphere_material = ShaderMaterial.new()
	_atmosphere_material.shader = atmo_shader
	_atmosphere_material.set_shader_parameter("atmosphere_color", Color(0.25, 0.7, 1.0, 1.0))
	_atmosphere_material.set_shader_parameter("rim_power", 2.5)
	_atmosphere_material.set_shader_parameter("rim_step_start", 0.6)
	_atmosphere_material.set_shader_parameter("rim_step_end", 0.98)
	_atmosphere_material.set_shader_parameter("alpha_scale", 0.45)
	if atmosphere_instance:
		atmosphere_instance.material_override = _atmosphere_material

	_generate_cube_sphere()
	_update_mesh_arrays()
	recalculate_composition()

func _generate_cube_sphere() -> void:
	_array_mesh = ArrayMesh.new()
	_base_dirs.clear()
	_vertices.clear()
	_normals.clear()
	_colors.clear()
	_heights.clear()
	_element_types.clear()
	_uvs.clear()
	_indices.clear()

	var face_directions: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT,
		Vector3.UP, Vector3.DOWN,
		Vector3.BACK, Vector3.FORWARD
	]

	var default_color: Color = ELEMENTS["silicon"].color

	var vertex_offset: int = 0
	for face_dir in face_directions:
		var axis_a: Vector3 = Vector3(face_dir.y, face_dir.z, face_dir.x)
		var axis_b: Vector3 = face_dir.cross(axis_a)

		for y in range(face_resolution + 1):
			for x in range(face_resolution + 1):
				var fx := (float(x) / float(face_resolution)) * 2.0 - 1.0
				var fy := (float(y) / float(face_resolution)) * 2.0 - 1.0

				var cube_point: Vector3 = face_dir + axis_a * fx + axis_b * fy
				var sphere_dir: Vector3 = cube_point.normalized()

				_base_dirs.append(sphere_dir)
				_heights.append(0.0)
				_vertices.append(sphere_dir * base_radius)
				_normals.append(sphere_dir)
				_colors.append(default_color)
				_element_types.append(2) # 2 = silicon / sand
				_uvs.append(Vector2(2.0, 0.0))

		for y in range(face_resolution):
			for x in range(face_resolution):
				var i := vertex_offset + x + y * (face_resolution + 1)
				_indices.append(i)
				_indices.append(i + face_resolution + 1)
				_indices.append(i + 1)

				_indices.append(i + 1)
				_indices.append(i + face_resolution + 1)
				_indices.append(i + face_resolution + 2)

		vertex_offset += (face_resolution + 1) * (face_resolution + 1)

func _update_mesh_arrays() -> void:
	if not _array_mesh:
		return

	if _uvs.size() != _vertices.size():
		_uvs.resize(_vertices.size())
	for i in range(_vertices.size()):
		_uvs[i] = Vector2(float(_element_types[i]), _heights[i])

	var surface_arrays: Array = []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = _vertices
	surface_arrays[Mesh.ARRAY_NORMAL] = _normals
	surface_arrays[Mesh.ARRAY_COLOR] = _colors
	surface_arrays[Mesh.ARRAY_TEX_UV] = _uvs
	surface_arrays[Mesh.ARRAY_INDEX] = _indices

	_array_mesh.clear_surfaces()
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
	if mesh_instance:
		mesh_instance.mesh = _array_mesh

# --- Sistema de Histórico (Undo / Redo) ---

func begin_stroke() -> void:
	if not _stroke_active:
		_stroke_active = true
		_stroke_modified = false
		_stroke_initial_state = _create_snapshot()

func end_stroke() -> void:
	if _stroke_active:
		_stroke_active = false
		if _stroke_modified:
			_undo_stack.append(_stroke_initial_state)
			if _undo_stack.size() > MAX_HISTORY:
				_undo_stack.pop_front()
			_redo_stack.clear()
			_emit_history_changed()
			# Atualiza props de vegetação/rochas no fim do traço
			if scatter_node:
				scatter_node.update_props(_vertices, _normals, _element_types, _heights)

func _create_snapshot() -> Dictionary:
	return {
		"heights": _heights.duplicate(),
		"colors": _colors.duplicate(),
		"element_types": _element_types.duplicate()
	}

func _apply_snapshot(snapshot: Dictionary) -> void:
	_heights = (snapshot["heights"] as PackedFloat32Array).duplicate()
	_colors = (snapshot["colors"] as PackedColorArray).duplicate()
	_element_types = (snapshot["element_types"] as PackedByteArray).duplicate()

	for i in range(_vertices.size()):
		_vertices[i] = _base_dirs[i] * (base_radius + _heights[i])

	_recalculate_normals()
	_update_mesh_arrays()
	recalculate_composition()

	if scatter_node:
		scatter_node.update_props(_vertices, _normals, _element_types, _heights)

func undo() -> void:
	if _undo_stack.is_empty():
		return
	var current := _create_snapshot()
	_redo_stack.append(current)
	var prev: Dictionary = _undo_stack.pop_back()
	_apply_snapshot(prev)
	_emit_history_changed()

func redo() -> void:
	if _redo_stack.is_empty():
		return
	var current := _create_snapshot()
	_undo_stack.append(current)
	var nxt: Dictionary = _redo_stack.pop_back()
	_apply_snapshot(nxt)
	_emit_history_changed()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func _emit_history_changed() -> void:
	history_changed.emit(can_undo(), can_redo())

func clear_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_emit_history_changed()

# --- Aplicação de Pincel e Deformação ---

func apply_brush(
	hit_pos_world: Vector3,
	mode: String,
	element_key: String,
	radius: float,
	strength: float,
	delta: float,
	brush_shape: String = "SMOOTH",
	flatten_target_height: float = 0.0
) -> void:
	begin_stroke()

	var local_hit: Vector3 = (global_transform.affine_inverse() * hit_pos_world) if is_inside_tree() else hit_pos_world
	var hit_dir := local_hit.normalized()

	var terrain_data: Dictionary = get_terrain_data(element_key)
	var target_color: Color = terrain_data["color"]
	var element_id: int = terrain_data.get("type_id", 3)

	var max_angle := radius / base_radius
	var cos_max_angle := cos(max_angle)
	var modified := false

	# Limites realistas de topologia planetária (-0.30 a +0.42 do raio base)
	const MIN_HEIGHT: float = -0.30
	const MAX_HEIGHT: float = 0.42

	if mode == "SMOOTH":
		# VERDADEIRO SUAVIZADOR TOPOLÓGICO:
		# Passo 1: Calcula a média ponderada das alturas na vizinhança do pincel
		var sum_h: float = 0.0
		var sum_w: float = 0.0
		var affected_indices: Array[int] = []
		var affected_weights: Array[float] = []
		var best_dot: float = -2.0
		var best_idx: int = -1

		for i in range(_vertices.size()):
			var dir := _base_dirs[i]
			var dot_prod := dir.dot(hit_dir)
			if dot_prod > best_dot:
				best_dot = dot_prod
				best_idx = i

			if dot_prod >= cos_max_angle:
				var angle := acos(clampf(dot_prod, -1.0, 1.0))
				var dist_norm := angle / max_angle
				var t := clampf(1.0 - dist_norm, 0.0, 1.0)
				# Curva cúbica suave (Hermite)
				var w := t * t * (3.0 - 2.0 * t)
				affected_indices.append(i)
				affected_weights.append(w)
				sum_h += _heights[i] * w
				sum_w += w

		if sum_w == 0.0 and best_idx >= 0:
			affected_indices.append(best_idx)
			affected_weights.append(1.0)
			sum_h = _heights[best_idx]
			sum_w = 1.0

		if sum_w > 0.0:
			var avg_h := sum_h / sum_w
			# Passo 2: Puxa suavemente os vértices para a média, dissolvendo picos e arestas caóticas
			for k in range(affected_indices.size()):
				var idx := affected_indices[k]
				var w := affected_weights[k]
				var smooth_step := w * strength * delta * 3.5
				_heights[idx] = lerpf(_heights[idx], avg_h, clampf(smooth_step, 0.0, 0.75))
				_vertices[idx] = _base_dirs[idx] * (base_radius + _heights[idx])
				modified = true
				_stroke_modified = true

	else:
		# Modos ELEVATE, CARVE, FLATTEN e PAINT:
		var best_dot: float = -2.0
		var best_idx: int = -1

		for i in range(_vertices.size()):
			var dir := _base_dirs[i]
			var dot_prod := dir.dot(hit_dir)
			if dot_prod > best_dot:
				best_dot = dot_prod
				best_idx = i

			if dot_prod >= cos_max_angle:
				var angle := acos(clampf(dot_prod, -1.0, 1.0))
				var dist_normalized := angle / max_angle
				var t := clampf(1.0 - dist_normalized, 0.0, 1.0)

				# Curva orgânica de caimento (Bell Curve / Hermite suave)
				var falloff: float = t * t * (3.0 - 2.0 * t)

				match brush_shape:
					"HARD":
						falloff = smoothstep(1.0, 0.75, dist_normalized)
					"NOISE":
						var n_val := (_brush_noise.get_noise_3dv(dir * 3.2) + 1.0) * 0.5
						falloff = falloff * (0.75 + 0.25 * n_val)
					_: # "SMOOTH"
						falloff = t * t * (3.0 - 2.0 * t)

				var sculpt_rate: float = falloff * strength * delta * 0.32
				var paint_rate: float = falloff * strength * delta * 3.5
				modified = true
				_stroke_modified = true

				match mode:
					"PAINT":
						var p_factor: float = clampf(falloff * strength * delta * 45.0, falloff * 0.45 * strength, 1.0)
						_colors[i] = _colors[i].lerp(target_color, p_factor)
						if falloff > 0.05:
							_element_types[i] = element_id

					"ELEVATE":
						# Eleva com velocidade orgânica e controlada, gerando colinas e montanhas suaves
						_heights[i] = clampf(_heights[i] + sculpt_rate, MIN_HEIGHT, MAX_HEIGHT)
						_vertices[i] = dir * (base_radius + _heights[i])
						var e_factor: float = clampf(falloff * strength * delta * 40.0, falloff * 0.40 * strength, 1.0)
						_colors[i] = _colors[i].lerp(target_color, e_factor)
						if falloff > 0.05:
							_element_types[i] = element_id

					"CARVE":
						# Cava vales, crateras e fossas com bordas geológicas naturais
						_heights[i] = clampf(_heights[i] - sculpt_rate, MIN_HEIGHT, MAX_HEIGHT)
						_vertices[i] = dir * (base_radius + _heights[i])
						var depth_color := target_color.darkened(0.2)
						var c_factor: float = clampf(falloff * strength * delta * 40.0, falloff * 0.40 * strength, 1.0)
						_colors[i] = _colors[i].lerp(depth_color, c_factor)
						if falloff > 0.05:
							_element_types[i] = element_id

					"FLATTEN":
						# Cria platôs e mesas naturais nivelando na altura de início do clique e colorindo com o material
						var flatten_factor: float = clampf(falloff * strength * delta * 5.0, 0.0, 0.85)
						_heights[i] = lerpf(_heights[i], flatten_target_height, flatten_factor)
						_vertices[i] = dir * (base_radius + _heights[i])
						var f_color_factor: float = clampf(falloff * strength * delta * 40.0, falloff * 0.40 * strength, 1.0)
						_colors[i] = _colors[i].lerp(target_color, f_color_factor)
						if falloff > 0.05:
							_element_types[i] = element_id

		# Fallback para pincel micro / ponto fino (garante pintura precisa mesmo se raio for menor que distância entre vértices)
		if not modified and best_idx >= 0:
			var dir := _base_dirs[best_idx]
			var sculpt_rate: float = 1.0 * strength * delta * 0.32
			modified = true
			_stroke_modified = true
			match mode:
				"PAINT":
					_colors[best_idx] = target_color
					_element_types[best_idx] = element_id
				"ELEVATE":
					_heights[best_idx] = clampf(_heights[best_idx] + sculpt_rate, MIN_HEIGHT, MAX_HEIGHT)
					_vertices[best_idx] = dir * (base_radius + _heights[best_idx])
					_colors[best_idx] = target_color
					_element_types[best_idx] = element_id
				"CARVE":
					_heights[best_idx] = clampf(_heights[best_idx] - sculpt_rate, MIN_HEIGHT, MAX_HEIGHT)
					_vertices[best_idx] = dir * (base_radius + _heights[best_idx])
					var depth_color := target_color.darkened(0.2)
					_colors[best_idx] = depth_color
					_element_types[best_idx] = element_id
				"FLATTEN":
					var flatten_factor: float = clampf(1.0 * strength * delta * 3.5, 0.0, 0.85)
					_heights[best_idx] = lerpf(_heights[best_idx], flatten_target_height, flatten_factor)
					_vertices[best_idx] = dir * (base_radius + _heights[best_idx])

	if modified:
		_recalculate_normals()
		_update_mesh_arrays()

# Ferramenta Balde de Tinta / Preenchimento Global
func fill_planet(element_key: String) -> void:
	begin_stroke()
	var terrain_data: Dictionary = get_terrain_data(element_key)
	var target_color: Color = terrain_data["color"]
	var element_id: int = terrain_data.get("type_id", 3)

	for i in range(_vertices.size()):
		_colors[i] = target_color
		_element_types[i] = element_id

	_stroke_modified = true
	end_stroke()
	_update_mesh_arrays()
	recalculate_composition()

func sample_element_at(hit_pos_world: Vector3) -> String:
	if _base_dirs.is_empty():
		return "grass"
	var local_hit: Vector3 = (global_transform.affine_inverse() * hit_pos_world) if is_inside_tree() else hit_pos_world
	var hit_dir := local_hit.normalized()
	var best_dot := -2.0
	var best_idx := 0

	for i in range(_base_dirs.size()):
		var d := _base_dirs[i].dot(hit_dir)
		if d > best_dot:
			best_dot = d
			best_idx = i

	if best_idx < 0 or best_idx >= _element_types.size():
		return "grass"

	var el_id := _element_types[best_idx]
	for k in WORLDBOX_TERRAINS.keys():
		if WORLDBOX_TERRAINS[k].get("type_id", -1) == el_id:
			return k

	var keys := ELEMENTS.keys()
	if el_id >= 0 and el_id < keys.size():
		return keys[el_id]
	return "grass"

func get_height_at(hit_pos_world: Vector3) -> float:
	if _base_dirs.is_empty():
		return 0.0
	var local_hit: Vector3 = (global_transform.affine_inverse() * hit_pos_world) if is_inside_tree() else hit_pos_world
	var hit_dir := local_hit.normalized()
	var best_dot := -2.0
	var best_idx := 0

	for i in range(_base_dirs.size()):
		var d := _base_dirs[i].dot(hit_dir)
		if d > best_dot:
			best_dot = d
			best_idx = i

	if best_idx >= 0 and best_idx < _heights.size():
		return _heights[best_idx]
	return 0.0

func _recalculate_normals() -> void:
	for i in range(_normals.size()):
		_normals[i] = Vector3.ZERO

	var num_indices := _indices.size()
	for t in range(0, num_indices, 3):
		var i0 := _indices[t]
		var i1 := _indices[t + 1]
		var i2 := _indices[t + 2]
		var v0 := _vertices[i0]
		var v1 := _vertices[i1]
		var v2 := _vertices[i2]
		var fn := (v2 - v0).cross(v1 - v0)
		_normals[i0] += fn
		_normals[i1] += fn
		_normals[i2] += fn

	for i in range(_normals.size()):
		if _normals[i].length_squared() > 0.00001:
			_normals[i] = _normals[i].normalized()
		else:
			_normals[i] = _base_dirs[i]

func recalculate_composition() -> void:
	var counts := {}
	for k in ELEMENTS.keys():
		counts[k] = 0

	var total_verts := _element_types.size()
	if total_verts == 0:
		return

	var keys := ELEMENTS.keys()
	for i in range(total_verts):
		var id := _element_types[i]
		if id >= 0 and id < keys.size():
			counts[keys[id]] += 1

	var percentages := {}
	for k in keys:
		percentages[k] = (float(counts[k]) / float(total_verts)) * 100.0

	var p_type := "Planeta Rochoso Estéril"
	if percentages["water"] > 55.0:
		p_type = "Mundo Oceânico Primordial"
	elif percentages["water"] > 20.0 and percentages["carbon"] > 20.0:
		p_type = "Planeta Habitável Tipo-Terra"
	elif percentages["carbon"] > 45.0:
		p_type = "Mundo Biológico Selvagem"
	elif percentages["ice"] > 40.0:
		p_type = "Planeta Glacial / Tundra Polar"
	elif percentages["sulfur"] > 30.0:
		p_type = "Mundo Vulcânico Hiperativo"
	elif percentages["iron"] > 35.0:
		p_type = "Planeta Metálico Tipo-Marte"
	elif percentages["uranium"] > 25.0:
		p_type = "Planeta Radioativo Instável"
	elif percentages["gold"] > 25.0:
		p_type = "Mundo Rico em Metais Preciosos"

	composition_updated.emit(percentages, p_type)

# --- Nível dos Mares ---

func set_sea_level(level: float, enabled: bool = true) -> void:
	sea_level = level
	if ocean_instance:
		ocean_instance.visible = enabled
		ocean_instance.scale = Vector3.ONE * (1.0 + sea_level / base_radius)

# --- Bases / Telas em Branco para Criação pelo Jogador (Sem Seeds) ---

func setup_canvas(canvas_type: String) -> void:
	if not _array_mesh or _vertices.is_empty():
		_init_planet_mesh()
	begin_stroke()

	match canvas_type:
		"OCEAN":
			# Planeta Oceano: 100% coberto de água profunda, pronto para erguer continentes
			set_atmosphere_color(Color(0.25, 0.7, 1.0))
			set_sea_level(0.02, true)
			var ocean_col: Color = WORLDBOX_TERRAINS["deep_ocean"].color
			for i in range(_vertices.size()):
				_heights[i] = -0.06
				_colors[i] = ocean_col
				_element_types[i] = 0
				_vertices[i] = _base_dirs[i] * (base_radius + _heights[i])

		"EARTH":
			# Terra Fértil: Campos de grama verde planos, prontos para cavar mares e erguer montanhas
			set_atmosphere_color(Color(0.25, 0.7, 1.0))
			set_sea_level(0.0, false)
			var grass_col: Color = WORLDBOX_TERRAINS["grass"].color
			for i in range(_vertices.size()):
				_heights[i] = 0.0
				_colors[i] = grass_col
				_element_types[i] = 3
				_vertices[i] = _base_dirs[i] * base_radius

		"ROCK":
			# Planeta Rochoso: Esfera mineral pura e lisa para modelagem geológica total
			set_atmosphere_color(Color(0.65, 0.55, 0.45))
			set_sea_level(0.0, false)
			var rock_col: Color = WORLDBOX_TERRAINS["hills"].color
			for i in range(_vertices.size()):
				_heights[i] = 0.0
				_colors[i] = rock_col
				_element_types[i] = 5
				_vertices[i] = _base_dirs[i] * base_radius

		"DESERT":
			# Planeta Desértico: Dunas e areia limpa prontas para criação de oásis e cânions
			set_atmosphere_color(Color(0.9, 0.6, 0.3))
			set_sea_level(0.0, false)
			var sand_col: Color = WORLDBOX_TERRAINS["sand"].color
			for i in range(_vertices.size()):
				_heights[i] = 0.0
				_colors[i] = sand_col
				_element_types[i] = 2
				_vertices[i] = _base_dirs[i] * base_radius

		"RESET_RELIEF":
			# Nivelar Relevo: Redefine todas as elevações para 0.0, mantendo as pinturas e biomas do usuário
			for i in range(_vertices.size()):
				_heights[i] = 0.0
				_vertices[i] = _base_dirs[i] * base_radius

	_stroke_modified = true
	end_stroke()
	_recalculate_normals()
	_update_mesh_arrays()
	recalculate_composition()
	clear_history()

func generate_worldbox_world(preset_name: String = "OCEAN", _seed: int = -1) -> void:
	if preset_name in ["OCEAN", "ISLANDS"]:
		setup_canvas("OCEAN")
	elif preset_name in ["ROCK", "VOLCANIC", "VOLCANO"]:
		setup_canvas("ROCK")
	elif preset_name in ["DESERT", "DESERT_CHAOS"]:
		setup_canvas("DESERT")
	elif preset_name == "RESET_RELIEF":
		setup_canvas("RESET_RELIEF")
	else:
		setup_canvas("EARTH")

func apply_biome_preset(preset_name: String) -> void:
	setup_canvas(preset_name)

func reset_planet() -> void:
	begin_stroke()
	var default_color: Color = ELEMENTS["silicon"].color
	for i in range(_vertices.size()):
		_heights[i] = 0.0
		_vertices[i] = _base_dirs[i] * base_radius
		_normals[i] = _base_dirs[i]
		_colors[i] = default_color
		_element_types[i] = 2

	set_sea_level(0.0, false)
	set_atmosphere_color(Color(0.25, 0.7, 1.0))

	_stroke_modified = true
	end_stroke()
	_update_mesh_arrays()
	recalculate_composition()

func set_atmosphere_color(color: Color) -> void:
	if atmosphere_instance and atmosphere_instance.material_override is ShaderMaterial:
		var mat := atmosphere_instance.material_override as ShaderMaterial
		mat.set_shader_parameter("atmosphere_color", color)

# --- Salvamento e Carregamento (JSON) ---

func save_planet_to_file(file_path: String, planet_name: String) -> bool:
	var h_array: Array = []
	for h in _heights:
		h_array.append(snappedf(h, 0.001))

	var el_array: Array = []
	for el in _element_types:
		el_array.append(el)

	var data := {
		"version": 1,
		"name": planet_name,
		"heights": h_array,
		"elements": el_array,
		"sea_level": sea_level,
		"ocean_visible": ocean_instance.visible if ocean_instance else false
	}

	var json_str := JSON.stringify(data)
	var dir := file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)

	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()
		return true
	return false

func load_planet_from_file(file_path: String) -> Dictionary:
	var result := {"success": false, "name": ""}
	if not FileAccess.file_exists(file_path):
		return result

	var f := FileAccess.open(file_path, FileAccess.READ)
	if not f:
		return result

	var json_str := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		return result

	var data: Dictionary = json.data
	result["name"] = data.get("name", "Planeta Carregado")

	var h_array: Array = data.get("heights", [])
	var el_array: Array = data.get("elements", [])

	if h_array.size() == _heights.size() and el_array.size() == _element_types.size():
		begin_stroke()
		var keys := ELEMENTS.keys()
		for i in range(_heights.size()):
			_heights[i] = float(h_array[i])
			_element_types[i] = int(el_array[i])
			var k_idx: int = _element_types[i]
			if k_idx >= 0 and k_idx < keys.size():
				_colors[i] = ELEMENTS[keys[k_idx]]["color"]
			_vertices[i] = _base_dirs[i] * (base_radius + _heights[i])

		sea_level = float(data.get("sea_level", 0.0))
		var ocean_vis: bool = bool(data.get("ocean_visible", false))
		set_sea_level(sea_level, ocean_vis)

		_stroke_modified = true
		end_stroke()
		_recalculate_normals()
		_update_mesh_arrays()
		recalculate_composition()
		result["success"] = true

	return result
