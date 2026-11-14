shader_type canvas_item;
// Full-screen hazard veil (hazards.gd): dust storm haze or radiation glow.
// Worked out on chunky 4 px cells so it keeps the pixel-art look (no blur).

uniform float strength = 0.0;            // 0 = invisible
uniform vec4 tint : source_color = vec4(1.0);
uniform float centre = 0.0;              // 0 = only the screen edges, 1 = everywhere
uniform float scan = 0.0;                // moving scanlines (radiation)
uniform float drift = 0.0;               // dust blotches blowing sideways (storm)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 4.0);
	float edge = smoothstep(0.2, 0.75, distance(UV, vec2(0.5)));
	float a = mix(edge, 1.0, centre);
	if (drift > 0.0) {
		a *= 0.6 + 0.8 * noise(cell * 0.05 + vec2(-TIME * 7.0, TIME * 1.0) * drift);
	}
	if (scan > 0.0) {
		a *= 1.0 - scan * 0.4 * step(0.5, fract(cell.y * 0.5 - TIME * 2.0));
	}
	COLOR = vec4(tint.rgb, clamp(a * strength, 0.0, 0.85));
}
