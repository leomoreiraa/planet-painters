extends Control

# Efeito visual de fundo procedural para o Planet Painters:
# - Campo de estrelas cintilantes
# - Planeta estilizado com atmosfera e anéis orbitando

var stars: Array = []
var time: float = 0.0

func _ready() -> void:
	# Inicializa estrelas aleatórias
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(120):
		stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"size": rng.randf_range(1.0, 2.5),
			"speed": rng.randf_range(1.0, 3.5),
			"alpha_base": rng.randf_range(0.3, 0.9),
			"color": Color(rng.randf_range(0.8, 1.0), rng.randf_range(0.85, 1.0), 1.0)
		})

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size

	# Fundo gradiente espacial profundo
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.04, 0.05, 0.09, 1.0))

	# Nebulosa sutil ao fundo
	var nebula_center := Vector2(viewport_size.x * 0.72, viewport_size.y * 0.45)
	draw_circle(nebula_center, viewport_size.y * 0.45, Color(0.12, 0.08, 0.28, 0.35))
	draw_circle(nebula_center + Vector2(-40, 20), viewport_size.y * 0.35, Color(0.05, 0.18, 0.32, 0.3))

	# Estrelas
	for s in stars:
		var pos: Vector2 = Vector2(s.pos.x * viewport_size.x, s.pos.y * viewport_size.y)
		var twinkle: float = (sin(time * s.speed + pos.x) + 1.0) * 0.5
		var alpha: float = s.alpha_base * (0.4 + 0.6 * twinkle)
		var star_color: Color = s.color
		star_color.a = alpha
		draw_circle(pos, s.size, star_color)

	# Planeta estilizado no canto direito
	var planet_pos := Vector2(viewport_size.x * 0.74, viewport_size.y * 0.50)
	var radius := minf(viewport_size.x, viewport_size.y) * 0.22

	# Brilho de atmosfera externa (Glow)
	draw_circle(planet_pos, radius * 1.25, Color(0.15, 0.45, 0.9, 0.12))
	draw_circle(planet_pos, radius * 1.12, Color(0.2, 0.6, 1.0, 0.25))

	# Corpo do Planeta
	draw_circle(planet_pos, radius, Color(0.16, 0.28, 0.55, 1.0))

	# Faixas / continentes estilizados no planeta (sombra / relevo)
	draw_circle(planet_pos + Vector2(radius * 0.15, radius * 0.15), radius * 0.85, Color(0.22, 0.4, 0.72, 0.6))
	draw_circle(planet_pos + Vector2(-radius * 0.1, -radius * 0.2), radius * 0.45, Color(0.35, 0.75, 0.65, 0.4))
	draw_circle(planet_pos + Vector2(radius * 0.25, -radius * 0.1), radius * 0.35, Color(0.85, 0.45, 0.65, 0.35))

	# Sombra suave no lado direito do planeta
	draw_circle(planet_pos + Vector2(radius * 0.35, radius * 0.15), radius * 0.8, Color(0.03, 0.04, 0.1, 0.55))

	# Anel orbital do planeta (elipse desenhada por arcos)
	var ring_points := PackedVector2Array()
	var ring_color := Color(0.5, 0.75, 1.0, 0.4)
	var num_pts := 48
	var ring_rx := radius * 1.7
	var ring_ry := radius * 0.45
	var angle_tilt := -0.35

	for i in range(num_pts + 1):
		var theta := float(i) / float(num_pts) * TAU
		var pt := Vector2(cos(theta) * ring_rx, sin(theta) * ring_ry)
		pt = pt.rotated(angle_tilt) + planet_pos
		ring_points.append(pt)

	if ring_points.size() > 1:
		for i in range(ring_points.size() - 1):
			draw_line(ring_points[i], ring_points[i + 1], ring_color, 3.5, true)
