shader_type canvas_item;
// Full-screen finishing pass for the game world (the HUD draws above it).
// Soft bloom on bright pixels, region colour grade, vignette, a touch of
// lens fringing at the edges, and a red edge pulse when the robot is hit.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float enabled = 1.0;
uniform float bloom_strength = 0.28;
uniform float bloom_threshold = 0.93;
uniform float bloom_radius = 2.5;
uniform float vignette = 0.22;
uniform float aberration = 0.0;
uniform float saturation = 1.1;
uniform vec3 shadow_tint = vec3(0.9, 0.97, 1.1);
uniform vec3 highlight_tint = vec3(1.07, 1.0, 0.93);
uniform float hit_flash = 0.0;
uniform float low_health = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 base = texture(screen_tex, uv).rgb;
	if (enabled < 0.5) {
		COLOR = vec4(base, 1.0);
	} else {
		vec2 dir = uv - 0.5;
		float d = length(dir);
		float ab = aberration * d * d * 4.0 + hit_flash * 4.0;
		vec3 col;
		col.r = texture(screen_tex, uv + dir * px * ab).r;
		col.g = base.g;
		col.b = texture(screen_tex, uv - dir * px * ab).b;

		vec3 bloom = vec3(0.0);
		float total = 0.0;
		for (int i = 0; i < 10; i++) {
			float a = 6.2831853 * float(i) / 10.0 + 0.3;
			vec2 o = vec2(cos(a), sin(a));
			for (int r = 1; r <= 3; r++) {
				vec2 off = o * px * bloom_radius * 2.0 * float(r);
				vec3 s = texture(screen_tex, uv + off).rgb;
				float b = max(max(s.r, s.g), s.b);
				float w = 1.0 / float(r);
				bloom += s * smoothstep(bloom_threshold, 1.0, b) * w;
				total += w;
			}
		}
		col += (bloom / total) * bloom_strength * 3.0;

		float l = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(l), col, saturation);
		col *= mix(shadow_tint, highlight_tint, smoothstep(0.08, 0.7, l));

		float edge = smoothstep(0.32, 0.9, d);
		col *= 1.0 - vignette * edge;
		float red = clamp(hit_flash * 0.45 + low_health * 0.18, 0.0, 0.6);
		col = mix(col, vec3(0.9, 0.12, 0.1), red * edge);
		COLOR = vec4(col, 1.0);
	}
}
