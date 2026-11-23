class_name PlanetCreatures
extends Node3D

# PlanetCreatures.gd
# Gerenciador de criaturinhas vivas que vagam pela superfície do planeta esférico
# Inspirado nas criaturas e civilizações de WorldBox - God Simulator.

@export var planet: Node3D

const MAX_CREATURES: int = 50

class CreatureInstance:
	var node: Node3D
	var dir: Vector3 # Direção normalizada na esfera
	var walk_dir: Vector3 # Direção tangente de caminhada
	var speed: float = 0.25
	var step_phase: float = 0.0
	var wander_timer: float = 2.0
	var type: String = "sheep" # "sheep", "human"

var _creatures: Array[CreatureInstance] = []

var _sheep_mesh: ArrayMesh
var _human_mesh: ArrayMesh

func _ready() -> void:
	_create_creature_meshes()

func _create_creature_meshes() -> void:
	# 1. Malha estilizada da Ovelha (Corpo fofo branco + cabeça preta)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = StandardMaterial3D.SPECULAR_DISABLED

	# Corpo (Cubo branco fofo)
	_add_box(st, Vector3.ZERO, Vector3(0.12, 0.10, 0.16), Color(0.96, 0.96, 0.96))
	# Cabeça (Cubo escuro na frente)
	_add_box(st, Vector3(0.0, 0.04, 0.10), Vector3(0.07, 0.07, 0.08), Color(0.15, 0.15, 0.18))
	_sheep_mesh = st.commit()
	_sheep_mesh.surface_set_material(0, mat)

	# 2. Malha estilizada do Aldeão (Corpo túnica vermelha/azul + cabeça bege)
	var st_h := SurfaceTool.new()
	st_h.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Corpo/Túnica
	_add_box(st_h, Vector3(0.0, 0.05, 0.0), Vector3(0.08, 0.12, 0.08), Color(0.85, 0.25, 0.25))
	# Cabeça
	_add_box(st_h, Vector3(0.0, 0.14, 0.0), Vector3(0.07, 0.07, 0.07), Color(0.95, 0.80, 0.65))
	_human_mesh = st_h.commit()
	_human_mesh.surface_set_material(0, mat)

func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var corners := [
		center + Vector3(-hx, -hy, -hz),
		center + Vector3(hx, -hy, -hz),
		center + Vector3(hx, hy, -hz),
		center + Vector3(-hx, hy, -hz),
		center + Vector3(-hx, -hy, hz),
		center + Vector3(hx, -hy, hz),
		center + Vector3(hx, hy, hz),
		center + Vector3(-hx, hy, hz)
	]

	var faces := [
		[0, 2, 1], [0, 3, 2], # Trás
		[4, 5, 6], [4, 6, 7], # Frente
		[0, 4, 7], [0, 7, 3], # Esquerda
		[1, 2, 6], [1, 6, 5], # Direita
		[3, 7, 6], [3, 6, 2], # Cima
		[0, 1, 5], [0, 5, 4]  # Baixo
	]

	st.set_color(col)
	for f in faces:
		st.add_vertex(corners[f[0]])
		st.add_vertex(corners[f[1]])
		st.add_vertex(corners[f[2]])

func spawn_creature(world_pos: Vector3, type: String = "sheep") -> void:
	if _creatures.size() >= MAX_CREATURES:
		var oldest: CreatureInstance = _creatures.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()

	if not planet:
		return

	var local_pos := (planet.global_transform.affine_inverse() * world_pos) if planet.is_inside_tree() else world_pos
	var spawn_dir := local_pos.normalized()

	var c := CreatureInstance.new()
	c.dir = spawn_dir
	c.type = type
	c.speed = randf_range(0.2, 0.4)

	# Vetor tangente para caminhar
	var up := spawn_dir
	var tangent := up.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = up.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	c.walk_dir = tangent.rotated(up, randf_range(0.0, TAU))

	var mi := MeshInstance3D.new()
	mi.mesh = _sheep_mesh if type == "sheep" else _human_mesh
	add_child(mi)
	c.node = mi

	_update_creature_transform(c, 0.0)
	_creatures.append(c)
	SoundEffects.play_spawn()

func update_simulation(delta: float, time_speed: float) -> void:
	if time_speed <= 0.0 or not planet:
		return

	var sim_delta := delta * time_speed

	for i in range(_creatures.size() - 1, -1, -1):
		var c: CreatureInstance = _creatures[i]
		if not is_instance_valid(c.node):
			_creatures.remove_at(i)
			continue

		c.wander_timer -= sim_delta
		if c.wander_timer <= 0.0:
			c.wander_timer = randf_range(2.0, 5.0)
			# Vira um pouco de direção
			c.walk_dir = c.walk_dir.rotated(c.dir, randf_range(-1.2, 1.2)).normalized()

		# Avança na direção de caminhada
		var step: Vector3 = c.walk_dir * (c.speed * sim_delta)
		var next_dir: Vector3 = (c.dir + step).normalized()

		# Reavalia terreno: se for oceano profundo, inverte o passo
		var h: float = planet.get_height_at(next_dir * planet.base_radius)
		if h < planet.sea_level - 0.04:
			c.walk_dir = -c.walk_dir.rotated(c.dir, randf_range(-0.5, 0.5)).normalized()
		else:
			c.dir = next_dir
			# Recalcula tangente para manter 90 graus com a nova normal
			c.walk_dir = (c.walk_dir - c.dir * c.walk_dir.dot(c.dir)).normalized()

		c.step_phase += sim_delta * 8.0 * (c.speed / 0.3)
		_update_creature_transform(c, c.step_phase)

func _update_creature_transform(c: CreatureInstance, step_phase: float) -> void:
	if not is_instance_valid(c.node) or not planet:
		return

	var up: Vector3 = c.dir
	var fwd: Vector3 = c.walk_dir
	var right: Vector3 = up.cross(fwd).normalized()
	fwd = right.cross(up).normalized()

	var h: float = planet.get_height_at(c.dir * planet.base_radius)
	var surface_pos: Vector3 = c.dir * (planet.base_radius + h)

	# Efeito cartoon de saltinho ao caminhar
	var bob: float = abs(sin(step_phase)) * 0.02
	var final_pos := surface_pos + up * bob

	var rot_basis := Basis(right, up, fwd)
	c.node.transform = Transform3D(rot_basis, final_pos)

func clear_creatures() -> void:
	for c in _creatures:
		if is_instance_valid(c.node):
			c.node.queue_free()
	_creatures.clear()
