shader_type canvas_item;
render_mode blend_mix;

// Fixture-local copy of shaders/unit_art_presentation.gdshader. The ONLY change
// is that every texture() call takes this fixture's `sample_bias` argument, so a
// comparison row differs from the production baseline in sampling alone. The
// value curve, the tint varying and the alpha handling are identical to
// production: the incoming CanvasItem tint is captured in vertex(), alpha is
// passed through unchanged, and nothing is tinted twice.
//
// `texture(sampler2D, vec2, float)`: the third parameter is a BIAS added to the
// implicit mip selection, not an absolute LOD. Godot 4.5 declares this overload
// in servers/rendering/shader_language.cpp, lines 3161-3166, with the parameter
// named "bias" and tagged TAG_GLOBAL (callable from canvas_item). Reference:
// https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/shading_language.html

uniform float exposure_gamma : hint_range(1.0, 2.0) = 1.38;
uniform float contrast : hint_range(0.8, 1.4) = 1.03;
uniform float contrast_pivot : hint_range(0.0, 1.0) = 0.26;
uniform float key_light : hint_range(0.0, 0.30) = 0.05;
uniform float highlight_rolloff : hint_range(0.0, 0.60) = 0.12;
uniform float edge_definition : hint_range(0.0, 1.0) = 0.26;
uniform float contact_shade : hint_range(0.0, 0.60) = 0.22;
uniform float contact_start : hint_range(0.0, 1.0) = 0.82;
uniform float sample_bias : hint_range(-2.0, 2.0) = 0.0;

varying vec4 v_tint;

void vertex() {
	v_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV, sample_bias);
	if (tex.a <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec3 c = clamp(tex.rgb, 0.0, 1.0);
		c = pow(c, vec3(1.0 / exposure_gamma));
		c = clamp((c - contrast_pivot) * contrast + contrast_pivot, 0.0, 1.0);
		float peak = dot(c, vec3(0.299, 0.587, 0.114));
		c *= 1.0 - highlight_rolloff * smoothstep(0.55, 1.0, peak);
		c *= 1.0 + key_light * (0.5 - UV.y);
		if (edge_definition > 0.0) {
			vec2 neighbor = TEXTURE_PIXEL_SIZE;
			float outer_alpha = min(
				min(
					texture(TEXTURE, UV + vec2(neighbor.x, 0.0), sample_bias).a,
					texture(TEXTURE, UV - vec2(neighbor.x, 0.0), sample_bias).a
				),
				min(
					texture(TEXTURE, UV + vec2(0.0, neighbor.y), sample_bias).a,
					texture(TEXTURE, UV - vec2(0.0, neighbor.y), sample_bias).a
				)
			);
			float rim = clamp(1.0 - outer_alpha, 0.0, 1.0) * smoothstep(0.05, 0.55, tex.a);
			c *= 1.0 - edge_definition * rim;
		}
		if (contact_shade > 0.0) {
			float seat = smoothstep(contact_start, 1.0, UV.y) * contact_shade;
			c *= 1.0 - seat;
		}
		COLOR = vec4(clamp(c, 0.0, 1.0), tex.a) * v_tint;
	}
}
