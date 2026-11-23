shader_type spatial;

// PlanetCartoon.gdshader
// Toon / Cel-Shader estilizado com suporte completo a:
// - Shading Toon Stepped (degraus de cel-shading vivos)
// - Texturas procedurais cartoon para cada material (água animada, folhagem, magma com emissão, dunas, rochas, neve)
// - Luz de borda / Rim Lighting
// - Padrão Screentone / Halftone (pattern)
// - Cores de vértice fiéis (v_vertex_color) e texturas albedo

group_uniforms Shader.Albedo;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform bool use_texture = false;
uniform sampler2D albedo_texture;

group_uniforms Shader.Light;
uniform bool use_stepped = true;
uniform float steps = 3.0;
uniform float step_smoothness : hint_range(0.0, 1.0, 0.05) = 0.05;
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.22, 0.38, 1.0);
uniform float shadow_tint_amount : hint_range(0.0, 1.0, 0.05) = 0.5;

group_uniforms Shader.Specular;
uniform float specular : hint_range(0.0, 1.0, 0.05) = 0.0;

group_uniforms Shader.Normal;
uniform float normal_strength : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform sampler2D normal_texture;

group_uniforms Shader.Rim;
uniform bool use_rim = false;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_amount = 2.0;
uniform float rim_smoothness = 0.2;
uniform float rim_mask_shadow : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float rim_blend : hint_range(0.0, 1.0, 0.05) = 1.0;

group_uniforms Shader.Pattern;
uniform bool use_pattern = false;
uniform sampler2D pattern_texture;
uniform int pattern_uv_mode : hint_enum("UV", "Screen", "Local Screen") = 2;
uniform float pattern_tiling = 32.0;
uniform float pattern_amount : hint_range(0.0, 1.0, 0.05) = 0.5;
uniform float pattern_smoothness : hint_range(0.0, 1.0, 0.05) = 0.5;
uniform float pattern_blend : hint_range(0.0, 1.0, 0.05) = 0.2;

varying vec4 node_position;
varying vec3 v_local_pos;
varying vec2 v_uv;
varying vec4 v_vertex_color;

// --- Funções de Ruído Procedural 3D para Superfície Esférica ---

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(dot(hash33(i + vec3(0.0,0.0,0.0)) - 0.5, f - vec3(0.0,0.0,0.0)),
				dot(hash33(i + vec3(1.0,0.0,0.0)) - 0.5, f - vec3(1.0,0.0,0.0)), f.x),
			mix(dot(hash33(i + vec3(0.0,1.0,0.0)) - 0.5, f - vec3(0.0,1.0,0.0)),
				dot(hash33(i + vec3(1.0,1.0,0.0)) - 0.5, f - vec3(1.0,1.0,0.0)), f.x), f.y),
		mix(mix(dot(hash33(i + vec3(0.0,0.0,1.0)) - 0.5, f - vec3(0.0,0.0,1.0)),
				dot(hash33(i + vec3(1.0,0.0,1.0)) - 0.5, f - vec3(1.0,0.0,1.0)), f.x),
			mix(dot(hash33(i + vec3(0.0,1.0,1.0)) - 0.5, f - vec3(0.0,1.0,1.0)),
				dot(hash33(i + vec3(1.0,1.0,1.0)) - 0.5, f - vec3(1.0,1.0,1.0)), f.x), f.y), f.z) + 0.5;
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	mat3 rot = mat3(vec3(0.8, 0.6, 0.0), vec3(-0.6, 0.8, 0.0), vec3(0.0, 0.0, 1.0));
	for (int i = 0; i < 3; i++) {
		v += a * noise3(p);
		p = rot * p * 2.02;
		a *= 0.5;
	}
	return v;
}

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

vec2 pattern_uv(vec2 uv, vec2 screen_uv) {
	vec2 p_uv = uv;
	if (pattern_uv_mode == 1) {
		p_uv = screen_uv;
	} else if (pattern_uv_mode == 2) {
		p_uv = (node_position.xy / node_position.w) * 0.5 + 0.5;
	}
	return p_uv;
}

float shape_value(float value, vec2 uv, vec2 viewport_size) {
	float aspect = viewport_size.x / viewport_size.y;
	vec2 p_uv = uv * pattern_tiling * vec2(1.0, aspect);
	float shadow_pattern = texture(pattern_texture, p_uv).r;
	shadow_pattern = clamp(smoothstep(shadow_pattern - pattern_smoothness, shadow_pattern + pattern_smoothness, value + pattern_amount), 0.0, value + pattern_amount);
	return shadow_pattern;
}

void vertex() {
	node_position = (PROJECTION_MATRIX * vec4(NODE_POSITION_VIEW, 1.0));
	v_local_pos = VERTEX;
	v_uv = UV;
	v_vertex_color = COLOR; // Passa a cor de vértice real para o fragment
}

void fragment() {
	vec4 albedo = albedo_color;
	if (use_texture) {
		albedo *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		albedo *= v_vertex_color;
	}

	vec3 dir = normalize(v_local_pos);
	vec3 base_col = albedo.rgb;
	float mat_rough = 0.85;
	float mat_spec = specular;
	vec3 mat_emissive = vec3(0.0);

	// Determina o bioma pelo UV.x configurado pelo PlanetMesh
	int biome_id = int(round(v_uv.x));

	// 1. ÁGUA (Oceano e Água Rasa)
	if (biome_id == 0 || biome_id == 1) {
		vec3 wp = dir * 42.0 + vec3(TIME * 0.7, TIME * 0.45, TIME * 0.55);
		float w1 = sin(wp.x * 2.2 + wp.y * 1.6 + TIME * 1.8);
		float w2 = cos(wp.y * 1.9 - wp.z * 2.3 + TIME * 1.3);
		float wave = (w1 + w2) * 0.5;
		float foam = smoothstep(0.70, 0.86, fbm3(wp * 1.3));

		vec3 wave_light = base_col * 1.25 + vec3(0.05, 0.12, 0.18);
		vec3 wave_dark = base_col * 0.82;
		base_col = mix(wave_dark, wave_light, wave * 0.5 + 0.5);
		base_col = mix(base_col, vec3(0.85, 0.95, 1.0), foam * 0.65);
		mat_rough = 0.12;
		mat_spec = max(mat_spec, 0.85);
	}
	// 2. FLORESTA (Vegetação Densa)
	else if (biome_id == 4) {
		vec3 fp = dir * 55.0;
		float foliage = fbm3(fp * 1.6);
		float leafy_clumps = smoothstep(0.35, 0.65, foliage);
		float micro_detail = noise3(fp * 4.2) * 0.25;
		vec3 foliage_dark = base_col * 0.75;
		vec3 foliage_bright = base_col * 1.30;
		base_col = mix(foliage_dark, foliage_bright, clamp(leafy_clumps + micro_detail, 0.0, 1.0));
		mat_rough = 0.85;
	}
	// 3. GRAMA (Campos e Prados)
	else if (biome_id == 3) {
		vec3 gp = dir * 65.0;
		float grass_pat = fbm3(gp * 1.8);
		vec3 grass_dark = base_col * 0.82;
		vec3 grass_light = base_col * 1.22;
		base_col = mix(grass_dark, grass_light, grass_pat);
		mat_rough = 0.88;
	}
	// 4. MAGMA / LAVA INCANDESCENTE
	else if (biome_id == 11) {
		vec3 mp = dir * 32.0;
		float pulse = sin(TIME * 2.8 + mp.x * 2.0 + mp.y * 1.5) * 0.18 + 0.82;
		float cracks = abs(fbm3(mp * 1.5) - 0.5) * 2.0;
		float crust = smoothstep(0.16, 0.36, cracks);

		vec3 basalt_crust = vec3(0.12, 0.08, 0.08);
		vec3 lava_core = vec3(1.0, 0.90, 0.25);
		vec3 lava_fire = vec3(1.0, 0.28, 0.02);
		vec3 molten = mix(lava_fire, lava_core, smoothstep(0.22, 0.0, cracks) * pulse);

		base_col = mix(molten, basalt_crust, crust);
		mat_emissive = mix(molten * 3.0 * pulse, vec3(0.0), crust);
		mat_rough = mix(0.30, 0.95, crust);
		mat_spec = mix(0.50, 0.05, crust);
	}
	// 5. PRAIA & DESERTO (Areia e Dunas)
	else if (biome_id == 2 || biome_id == 9) {
		vec3 dp = dir * (biome_id == 9 ? 36.0 : 70.0);
		float dune = sin(dp.x * 2.8 + dp.y * 1.8 + fbm3(dp) * 2.2) * 0.5 + 0.5;
		vec3 sand_dark = base_col * 0.80;
		vec3 sand_light = base_col * 1.20;
		base_col = mix(sand_dark, sand_light, dune);
		mat_rough = 0.94;
	}
	// 6. MONTANHAS & COLINAS (Rocha e Falésias)
	else if (biome_id == 5 || biome_id == 6) {
		vec3 mtp = dir * 55.0;
		float strata = sin(mtp.y * 7.5 + noise3(mtp) * 3.5) * 0.5 + 0.5;
		float crag = fbm3(mtp * 2.2);
		vec3 rock_dark = base_col * 0.75;
		vec3 rock_light = base_col * 1.25;
		base_col = mix(rock_dark, rock_light, strata * 0.55 + crag * 0.45);
		mat_rough = 0.92;
	}
	// 7. NEVE & PICOS NEVADOS
	else if (biome_id == 7 || biome_id == 8) {
		vec3 np = dir * 60.0;
		float sparkle = smoothstep(0.70, 0.90, noise3(np * 4.5));
		vec3 snow_base = base_col;
		vec3 snow_sparkle = vec3(1.0, 1.0, 1.0);
		base_col = mix(snow_base, snow_sparkle, sparkle * 0.55);
		mat_rough = 0.40;
		mat_spec = max(mat_spec, 0.35);
	}
	// 8. PÂNTANO
	else if (biome_id == 10) {
		vec3 swp = dir * 50.0;
		float algae = smoothstep(0.42, 0.62, fbm3(swp * 1.8));
		vec3 muck_water = base_col * 0.75;
		vec3 green_algae = base_col * 1.35;
		base_col = mix(muck_water, green_algae, algae);
		mat_rough = mix(0.20, 0.85, algae);
	}

	ALBEDO = base_col;
	ROUGHNESS = mat_rough;
	SPECULAR = mat_spec;
	EMISSION = mat_emissive;

	vec4 normal_map = texture(normal_texture, UV);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), normal_map.rgb, normal_strength);
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float light = ndotl;

	if (use_stepped) {
		float light_mult = light * steps;
		float step_base = floor(light_mult);
		float light_factor = light_mult - step_base;
		light_factor = smoothstep(0.5 - step_smoothness, 0.5 + step_smoothness, light_factor);
		light = (step_base + light_factor) / steps;
	}

	if (use_pattern) {
		vec2 p_uv = pattern_uv(UV, SCREEN_UV);
		light = mix(light, shape_value(light, p_uv, VIEWPORT_SIZE), pattern_blend);
	}

	// Iluminação Toon cel-shading com sombras ricas e coloridas, sem escurecer demais
	vec3 lit_color = ALBEDO * LIGHT_COLOR;
	vec3 shadow_color = ALBEDO * mix(vec3(0.35, 0.38, 0.48), shadow_tint.rgb, shadow_tint_amount);
	vec3 diffuse = mix(shadow_color, lit_color, light);

	if (use_rim) {
		float rim_value = fresnel(rim_amount, NORMAL, VIEW);
		rim_value = smoothstep(0.5 - (rim_smoothness / 2.0), 0.5 + (rim_smoothness / 2.0), rim_value);
		rim_value = mix(rim_value, rim_value * light, rim_mask_shadow);
		diffuse += rim_color.rgb * rim_value * rim_blend;
	}

	DIFFUSE_LIGHT += diffuse;
	SPECULAR_LIGHT += vec3(pow(light, 50.0)) * specular * LIGHT_COLOR;
}
