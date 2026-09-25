shader_type canvas_item;
render_mode blend_mix;

// Presentation-only exposure for character art over dark, busy stone. The
// shipped unit art is dark (median luminance ~0.10-0.22), so on the board and
// the muddy arena characters read as granular silhouettes instead of figures.
// Only the rendered luminance curve is remapped; the same texture is drawn, so
// artwork, silhouette and identity are untouched.
//
// The CanvasItem tint is captured in vertex() instead of read from the fragment
// COLOR, because the fragment COLOR may already contain the sampled texture.
// Reading it would double-multiply RGB and darken instead of lift.

uniform float exposure_gamma : hint_range(1.0, 2.0) = 1.34;
uniform float contrast : hint_range(0.8, 1.4) = 1.06;
uniform float contrast_pivot : hint_range(0.0, 1.0) = 0.30;
uniform float key_light : hint_range(0.0, 0.30) = 0.09;
uniform float contact_shade : hint_range(0.0, 0.60) = 0.0;
uniform float contact_start : hint_range(0.0, 1.0) = 0.82;

varying vec4 v_tint;

void vertex() {
	v_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		// Fully transparent texels stay transparent; no early return, the
		// fragment processor does not allow one.
		COLOR = vec4(0.0);
	} else {
		vec3 c = clamp(tex.rgb, 0.0, 1.0);
		// Shadow-weighted exposure: darks move most, highlights stay restrained.
		c = pow(c, vec3(1.0 / exposure_gamma));
		// Gentle contrast around a low pivot keeps mid-tones apart without crushing.
		c = clamp((c - contrast_pivot) * contrast + contrast_pivot, 0.0, 1.0);
		// Very subtle neutral key light from above; deliberately no colour cast.
		c *= 1.0 + key_light * (0.5 - UV.y);
		if (contact_shade > 0.0) {
			// Seat the base of the figure against the ground it stands on.
			float seat = smoothstep(contact_start, 1.0, UV.y) * contact_shade;
			c *= 1.0 - seat;
		}
		COLOR = vec4(clamp(c, 0.0, 1.0), tex.a) * v_tint;
	}
}
