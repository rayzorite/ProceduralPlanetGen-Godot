shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Basic toon + planet uniforms
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color;
uniform float planet_seed;

uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0, 2.0) = 0.0;
uniform float steepness : hint_range(1.0, 8.0) = 1.0;

uniform bool use_specular = false;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.3;
uniform float specular_shininess : hint_range(0.0, 32.0) = 8.0;

uniform bool use_rim = true;
uniform float rim_width : hint_range(0.0, 16.0) = 4.0;
uniform vec4 rim_color : source_color = vec4(1.0);

uniform float radius = 1.0;
uniform float elevation_amplitude = 0.2;
uniform float sea_level_bias = 0.25;

// biome colors
uniform vec3 ocean_color : source_color = vec3(0.0, 0.25, 0.6);
uniform vec3 beach_color : source_color = vec3(0.9, 0.8, 0.6);
uniform vec3 forest_color : source_color = vec3(0.1, 0.6, 0.2);
uniform vec3 mountain_color : source_color = vec3(0.5, 0.45, 0.4);
uniform vec3 snow_color : source_color = vec3(0.9, 0.9, 0.95);

varying vec3 v_vertex;
varying vec3 v_normal;
varying vec2 v_uv;

// pseudo-random (if needed)
float rand(vec3 co) {
	return fract(sin(dot(co.xyz, vec3(12.9898, 78.233, 45.164))) * 43758.5453 + planet_seed);
}

void vertex() {
	v_vertex = VERTEX;
	v_normal = NORMAL;
	v_uv = UV;
}

void fragment() {
	float height = length(v_vertex);
	float elevation = (height - radius) / elevation_amplitude;
	float temperature = clamp(1.0 - abs(v_normal.y), 0.0, 1.0);

	vec3 biome_color;

	// Biome selection
	if (elevation < -sea_level_bias * 0.5) {
		biome_color = ocean_color;
	} else if (elevation < 0.02) {
		biome_color = beach_color;
	} else if (temperature > 0.6) {
		biome_color = forest_color;
	} else if (elevation > 0.25) {
		biome_color = mountain_color;
	} else {
		biome_color = snow_color;
	}

	biome_color = floor(biome_color * 4.0) / 4.0;

	ALBEDO = biome_color;
}

void light() {
	float attenuation = 1.0;
	#ifdef USE_ATTENUATION
		attenuation = ATTENUATION;
	#endif

	float NdotL = max(dot(NORMAL, LIGHT), 0.0);
	float diffuse_amount = NdotL + (attenuation - 1.0) + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0 / float(cuts);
	float diffuse_stepped = clamp(floor(diffuse_amount / cuts_inv) * cuts_inv, 0.0, 1.0);

	vec3 base_color = ALBEDO.rgb;
	vec3 diffuse = base_color * LIGHT_COLOR / PI;
	diffuse *= diffuse_stepped;
	DIFFUSE_LIGHT += diffuse;

	if (use_specular) {
		vec3 H = normalize(LIGHT + VIEW);
		float NdotH = max(dot(NORMAL, H), 0.0);
		float specular_amount = pow(NdotH, specular_shininess * specular_shininess) * attenuation;
		specular_amount = step(0.5, specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}

	if (use_rim) {
		float NdotV = max(dot(NORMAL, VIEW), 0.0);
		float rim = pow(1.0 - NdotV, rim_width);
		DIFFUSE_LIGHT += rim * rim_color.rgb * rim_color.a;
	}
}
