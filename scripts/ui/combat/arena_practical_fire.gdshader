shader_type canvas_item;
render_mode blend_add;

// Subtle turbulence for the practical brazier flame overlay. The approved art
// is a static cluster; this adds only a slow rise, a tip-weighted sway, and an
// intensity breath that also shortens the flame.
//
// Every frequency is an integer multiple of motion_rate, so the clock wrapping
// at MOTION_PERIOD_SECONDS in arena_practical_fire.gd is a true common period
// and has no seam.
//
// motion_amount and flicker_amount go to 0.0 for reduced motion, which
// collapses the output to the untouched texture.

uniform float time_seconds = 0.0;
uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 1.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.55;
uniform float phase = 0.0;
uniform float motion_rate = 0.05;
uniform vec4 flame_tint : source_color = vec4(1.0, 0.88, 0.68, 1.0);

// The incoming canvas color (this node's modulate including every ancestor)
// must be carried across explicitly: assigning COLOR in fragment() replaces it,
// which would silently disable the compensation that keeps this ivory flame off
// the floor's lifted modulate.
varying vec4 inherited_color;

void vertex() {
	inherited_color = COLOR;
}

void fragment() {
	float t = time_seconds;
	// UV.y grows downward, so the flame tip is small UV.y and the point where
	// the flame meets the brazier is UV.y ~ 1. Every mask below is tip-weighted,
	// which keeps the attachment base still and un-faded.
	float tip = clamp(1.0 - UV.y, 0.0, 1.0);
	float tip_mask = smoothstep(0.30, 1.0, tip);

	// A rising flame shortens as it brightens; brightening alone reads as a
	// pulsing glow.
	float shorten = (0.055 + 0.045 * sin(t * motion_rate * 52.0 + phase * 1.3)) * motion_amount;

	// Two distinct harmonics keep the sway off an obvious short loop.
	vec2 uv = UV;
	float sway = sin(t * motion_rate * 43.0 + phase + UV.y * 6.0) * 0.011
		+ sin(t * motion_rate * 74.0 + phase * 1.6 + UV.y * 9.5) * 0.0055;
	uv.x += sway * tip * motion_amount;
	// Sampling above the tip retracts it; the mask leaves the base alone.
	uv.y -= tip_mask * shorten * 0.60;
	uv.y += sin(t * motion_rate * 26.0 + phase) * 0.0045 * motion_amount * tip;

	vec4 base = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));

	float breathe = 1.0 - tip_mask * shorten * 1.6;
	float flicker = 1.0
		+ (sin(t * motion_rate * 134.0 + phase) * 0.055
		+ sin(t * motion_rate * 226.0 + phase * 2.0) * 0.035) * flicker_amount;

	float alpha = clamp(base.a * breathe, 0.0, 1.0);
	vec3 rgb = base.rgb * flame_tint.rgb * intensity * flicker;
	COLOR = vec4(rgb * inherited_color.rgb, alpha * inherited_color.a);
}
