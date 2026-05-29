shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

// Podstawowe parametry materiału
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_scissor_threshold = 0.5;

// Siła efektów wiatru i interakcji z graczem
uniform float wind_strength_multiplier = 1.0;
uniform float interactive_multiplier = 0.5;
uniform float object_height = 2.0;

// Odtworzenie zmiennych globalnych (global uniforms) zapożyczonych z projektu procedural-forest-demo (SimpleGrassTextured)
// by nasze liście/krzaki reagowały tak samo jak Twoja trawa!
global uniform vec3 sgt_player_position;
global uniform vec3 sgt_player_mov;
global uniform sampler2D sgt_normal_displacement;
global uniform sampler2D sgt_motion_texture;
global uniform vec3 sgt_wind_direction;
global uniform float sgt_wind_strength;
global uniform sampler2D sgt_wind_pattern;
global uniform vec3 sgt_wind_movement;

void vertex() {
	// 1. OBLICZANIE BAZY WIATRU
	// Wiatr jest silniejszy im wyżej na obiekcie się znajdujemy (vertex.y)
	// Clampujemy y od zera do wysokości obiektu, by korzenie/pień stały w miejscu
	float height_factor = clamp(VERTEX.y, 0.0, object_height) / object_height;
	
	// Symulacja szumu wiatru bazująca na teksturze (tak ja w grass.gdshaderinc)
	float text_wind = texture(sgt_wind_pattern, (vec2(NODE_POSITION_WORLD.x, NODE_POSITION_WORLD.z) * 0.005) - sgt_wind_movement.xz).r;
	
	// 2. GŁÓWNY KIERUNEK WIATRU (Sway)
	float wind_sway = text_wind * height_factor * sgt_wind_strength * wind_strength_multiplier;
	VERTEX.x += wind_sway * sgt_wind_direction.x;
	VERTEX.z += wind_sway * sgt_wind_direction.z;
	
	// 3. MIKRO-WIBRACJE LIŚCI (Zależne od czasu)
	// Używamy pozycji w świecie by krzaki nie ruszały się identycznie w tym samym tempie
	float rand = fract(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233)));
	float time_puls = TIME * 2.0 + rand * 10.0;
	
	VERTEX.x += sin(time_puls) * 0.05 * sgt_wind_strength * height_factor;
	VERTEX.y += cos(time_puls * 0.9) * 0.02 * sgt_wind_strength * height_factor;
	VERTEX.z += sin(time_puls * 1.1) * 0.05 * sgt_wind_strength * height_factor;

	// 4. INTERAKCJA Z GRACZEM (Odepchnięcie krzaka, gdy gracz przez niego przechodzi)
	// Mechanika 1:1 z procedural-forest-demo (wymaga mapy przemieszczeń)
	float node_x = NODE_POSITION_WORLD.x / 50.0;
	float node_z = NODE_POSITION_WORLD.z / 50.0;
	vec2 uv_disp = vec2(clamp((node_x - (sgt_player_position.x - 0.5)), 0.0, 1.0), clamp((node_z - (sgt_player_position.z - 0.5)), 0.0, 1.0));
	
	vec3 norm_mov = textureLod(sgt_normal_displacement, uv_disp - sgt_player_mov.xz, 0).rgb;
	norm_mov.xy = (norm_mov.xy * 2.0 - 1.0) * interactive_multiplier * height_factor;
	
	// Aplikujemy przesunięcie wywołane uderzeniem/przejściem gracza
	VERTEX.xz += norm_mov.xy;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ALPHA = albedo_tex.a * albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
