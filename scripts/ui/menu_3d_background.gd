extends Node3D

@onready var planet_pivot: Node3D = %PlanetPivot
@onready var atmosphere: MeshInstance3D = %AtmosphereMesh
@onready var camera: Camera3D = %Camera3D

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta

	# Rotação suave do planeta e dos anéis em torno de seu eixo polar
	if planet_pivot:
		planet_pivot.rotate_object_local(Vector3.UP, delta * 0.1)

	# Pulsação sutil na atmosfera
	if atmosphere and atmosphere.material_override is StandardMaterial3D:
		var mat := atmosphere.material_override as StandardMaterial3D
		var pulse := (sin(_time * 1.5) + 1.0) * 0.5
		mat.albedo_color.a = lerpf(0.25, 0.45, pulse)

	# Movimento suave de respiração da câmera
	if camera:
		camera.position.x = 0.8 + sin(_time * 0.4) * 0.08
		camera.position.y = 0.2 + cos(_time * 0.3) * 0.05
