shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_front, unshaded;

// atmosphere_cartoon.gdshader
// Halo de atmosfera cartoon suave - blend_mix para evitar saturação excessiva (estouro)

uniform vec4 atmosphere_color : source_color = vec4(0.25, 0.7, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 6.0) = 2.5;
uniform float rim_step_start : hint_range(0.1, 0.9) = 0.6;
uniform float rim_step_end : hint_range(0.5, 1.0) = 0.98;
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float fresnel = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float pow_fresnel = pow(fresnel, rim_power);

	// Apenas a borda externa da atmosfera recebe opacidade, mantendo o planeta nítido
	float toon_alpha = smoothstep(rim_step_start, rim_step_end, pow_fresnel) * alpha_scale;

	ALBEDO = atmosphere_color.rgb;
	ALPHA = toon_alpha;
}
