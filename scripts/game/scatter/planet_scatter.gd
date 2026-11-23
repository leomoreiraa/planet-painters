class_name PlanetScatter
extends Node3D

# PlanetScatter.gd
# Sistema de vegetação, árvores e rochas 3D na superfície do planeta.
# Utiliza MultiMeshInstance3D para renderizar centenas de árvores e rochas estilizadas em tempo real.

const MAX_PROPS_PER_TYPE: int = 2000

var tree_multimesh: MultiMeshInstance3D
var shrub_multimesh: MultiMeshInstance3D
var rock_multimesh: MultiMeshInstance3D

var _tree_transforms: Array[Transform3D] = []
var _shrub_transforms: Array[Transform3D] = []
var _rock_transforms: Array[Transform3D] = []

func _ready() -> void:
	_setup_multimeshes()

func _setup_multimeshes() -> void:
	# 1. MultiMesh de Árvores / Pinheiros Cartoon em Camadas (Floresta)
	tree_multimesh = MultiMeshInstance3D.new()
	tree_multimesh.name = "TreeScatter"
	var tree_mm := MultiMesh.new()
	tree_mm.transform_format = MultiMesh.TRANSFORM_3D
	tree_mm.instance_count = MAX_PROPS_PER_TYPE
	tree_mm.visible_instance_count = 0
	tree_mm.mesh = _create_tree_mesh()
	tree_multimesh.multimesh = tree_mm
	add_child(tree_multimesh)

	# 2. MultiMesh de Arbustos e Vegetação Baixa (Grama e Clareiras)
	shrub_multimesh = MultiMeshInstance3D.new()
	shrub_multimesh.name = "ShrubScatter"
	var shrub_mm := MultiMesh.new()
	shrub_mm.transform_format = MultiMesh.TRANSFORM_3D
	shrub_mm.instance_count = MAX_PROPS_PER_TYPE
	shrub_mm.visible_instance_count = 0
	shrub_mm.mesh = _create_shrub_mesh()
	shrub_multimesh.multimesh = shrub_mm
	add_child(shrub_multimesh)

	# 3. MultiMesh de Rochas e Boulders (Colinas e Montanhas)
	rock_multimesh = MultiMeshInstance3D.new()
	rock_multimesh.name = "RockScatter"
	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	rock_mm.instance_count = MAX_PROPS_PER_TYPE
	rock_mm.visible_instance_count = 0
	rock_mm.mesh = _create_rock_mesh()
	rock_multimesh.multimesh = rock_mm
	add_child(rock_multimesh)

func _create_tree_mesh() -> ArrayMesh:
	# Árvore cartoon exuberante em camadas, visível da órbita do planeta
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.specular_mode = StandardMaterial3D.SPECULAR_DISABLED

	# Tronco (Cilindro de 6 lados, madeira escura robusta)
	var trunk_col := Color(0.34, 0.22, 0.14)
	var trunk_r := 0.024
	var trunk_h := 0.08
	var trunk_segs := 6
	for i in range(trunk_segs):
		var a1 := float(i) * TAU / float(trunk_segs)
		var a2 := float(i + 1) * TAU / float(trunk_segs)
		var p1 := Vector3(cos(a1) * trunk_r, 0.0, sin(a1) * trunk_r)
		var p2 := Vector3(cos(a2) * trunk_r, 0.0, sin(a2) * trunk_r)
		var p3 := Vector3(cos(a1) * trunk_r, trunk_h, sin(a1) * trunk_r)
		var p4 := Vector3(cos(a2) * trunk_r, trunk_h, sin(a2) * trunk_r)

		st.set_color(trunk_col)
		st.add_vertex(p1)
		st.add_vertex(p3)
		st.add_vertex(p2)
		st.add_vertex(p2)
		st.add_vertex(p3)
		st.add_vertex(p4)

	# Copa em 3 camadas de cones verdes (proporcionais e volumosas)
	var tiers: Array[Dictionary] = [
		{"r": 0.11,  "base": 0.06, "tip": 0.19, "col": Color(0.12, 0.44, 0.18)},
		{"r": 0.085, "base": 0.13, "tip": 0.26, "col": Color(0.16, 0.54, 0.22)},
		{"r": 0.055, "base": 0.20, "tip": 0.33, "col": Color(0.22, 0.65, 0.26)}
	]

	var cone_segs := 7
	for tier: Dictionary in tiers:
		var r: float = tier["r"]
		var by: float = tier["base"]
		var ty: float = tier["tip"]
		var c: Color = tier["col"]
		var tip := Vector3(0.0, ty, 0.0)

		st.set_color(c)
		for i in range(cone_segs):
			var a1 := float(i) * TAU / float(cone_segs)
			var a2 := float(i + 1) * TAU / float(cone_segs)
			var p1 := Vector3(cos(a1) * r, by, sin(a1) * r)
			var p2 := Vector3(cos(a2) * r, by, sin(a2) * r)

			st.add_vertex(p1)
			st.add_vertex(tip)
			st.add_vertex(p2)

	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func _create_shrub_mesh() -> ArrayMesh:
	# Arbusto arredondado cartoon para campinas e bordas de floresta
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.specular_mode = StandardMaterial3D.SPECULAR_DISABLED

	var shrub_col := Color(0.25, 0.68, 0.22)
	var r := 0.065
	var h := 0.08
	var segs := 6
	var center_top := Vector3(0.0, h, 0.0)

	st.set_color(shrub_col)
	for i in range(segs):
		var a1 := float(i) * TAU / float(segs)
		var a2 := float(i + 1) * TAU / float(segs)
		var p1 := Vector3(cos(a1) * r, 0.01, sin(a1) * r)
		var p2 := Vector3(cos(a2) * r, 0.01, sin(a2) * r)

		st.add_vertex(p1)
		st.add_vertex(center_top)
		st.add_vertex(p2)

	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func _create_rock_mesh() -> ArrayMesh:
	# Rocha facetada cartoon marcante
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.specular_mode = StandardMaterial3D.SPECULAR_DISABLED

	var rock_col := Color(0.50, 0.46, 0.44)
	var pts: Array[Vector3] = [
		Vector3(0, 0.12, 0),
		Vector3(-0.08, 0.02, -0.07),
		Vector3(0.07, 0.02, -0.08),
		Vector3(0.09, 0.02, 0.06),
		Vector3(-0.06, 0.02, 0.08),
		Vector3(0, -0.02, 0)
	]

	var tris := [
		0, 1, 2,  0, 2, 3,  0, 3, 4,  0, 4, 1,
		5, 2, 1,  5, 3, 2,  5, 4, 3,  5, 1, 4
	]

	st.set_color(rock_col)
	for idx in tris:
		st.add_vertex(pts[idx])

	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

# Atualiza a distribuição de vegetação e rochas baseada nos biomas do planeta
func update_props(vertices: PackedVector3Array, normals: PackedVector3Array, element_types: PackedByteArray, heights: PackedFloat32Array) -> void:
	if not tree_multimesh:
		_setup_multimeshes()

	_tree_transforms.clear()
	_shrub_transforms.clear()
	_rock_transforms.clear()

	var total := vertices.size()
	# Passo de amostragem compacto para uma distribuição rica e densa de vegetação
	var step := 3
	for i in range(0, total, step):
		var el_id: int = element_types[i]
		var h: float = heights[i]
		var pos: Vector3 = vertices[i]
		var norm: Vector3 = normals[i]

		# Orienta na normal da superfície esférica
		var up := norm
		var right: Vector3 = up.cross(Vector3.UP)
		if right.length_squared() < 0.01:
			right = up.cross(Vector3.RIGHT)
		right = right.normalized()
		var forward := up.cross(right).normalized()

		# Variação sutil de escala e rotação aleatória
		var seed_val := int(abs(pos.x * 123.45 + pos.y * 234.56 + pos.z * 345.67)) % 100
		var scale_factor := 0.8 + (float(seed_val) / 100.0) * 0.4
		var random_yaw := float(seed_val) * 0.15

		var rot_basis := Basis(right, up, forward)
		rot_basis = rot_basis.rotated(up, random_yaw)
		rot_basis = rot_basis.scaled(Vector3.ONE * scale_factor)

		var xform := Transform3D(rot_basis, pos)

		# 1. BIOMA FLORESTA (el_id == 4): Vegetação exuberante e densa
		if el_id == 4:
			if h >= -0.02 and _tree_transforms.size() < MAX_PROPS_PER_TYPE and seed_val < 78:
				_tree_transforms.append(xform)
			elif h >= -0.02 and _shrub_transforms.size() < MAX_PROPS_PER_TYPE and seed_val >= 78:
				_shrub_transforms.append(xform)

		# 2. BIOMA GRAMA (el_id == 3): Arbustos e árvores ocasionais
		elif el_id == 3:
			if h >= -0.01 and seed_val < 38 and _shrub_transforms.size() < MAX_PROPS_PER_TYPE:
				_shrub_transforms.append(xform)
			elif h >= -0.01 and seed_val >= 80 and _tree_transforms.size() < MAX_PROPS_PER_TYPE:
				_tree_transforms.append(xform)

		# 3. BIOMA PÂNTANO (el_id == 10): Vegetação úmida esparsa
		elif el_id == 10:
			if seed_val < 30 and _tree_transforms.size() < MAX_PROPS_PER_TYPE:
				_tree_transforms.append(xform)

		# 4. COLINAS E MONTANHAS (el_id in [5, 6, 7]): Boulders e rochas
		elif el_id in [5, 6, 7]:
			if h > 0.06 and seed_val < 36 and _rock_transforms.size() < MAX_PROPS_PER_TYPE:
				_rock_transforms.append(xform)

	_apply_transforms_to_multimesh(tree_multimesh, _tree_transforms)
	_apply_transforms_to_multimesh(shrub_multimesh, _shrub_transforms)
	_apply_transforms_to_multimesh(rock_multimesh, _rock_transforms)

func _apply_transforms_to_multimesh(mm_inst: MultiMeshInstance3D, transforms: Array[Transform3D]) -> void:
	if not mm_inst or not mm_inst.multimesh:
		return
	var mm := mm_inst.multimesh
	var count := mini(transforms.size(), mm.instance_count)
	mm.visible_instance_count = count
	for i in range(count):
		mm.set_instance_transform(i, transforms[i])

func clear() -> void:
	if not tree_multimesh:
		_setup_multimeshes()
	_tree_transforms.clear()
	_shrub_transforms.clear()
	_rock_transforms.clear()
	if tree_multimesh and tree_multimesh.multimesh:
		tree_multimesh.multimesh.visible_instance_count = 0
	if shrub_multimesh and shrub_multimesh.multimesh:
		shrub_multimesh.multimesh.visible_instance_count = 0
	if rock_multimesh and rock_multimesh.multimesh:
		rock_multimesh.multimesh.visible_instance_count = 0
