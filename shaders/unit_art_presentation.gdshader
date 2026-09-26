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

// The exposure curve is deliberately shadow-weighted: it lifts the dark body of
// a figure far more than its lit masses, which is what separates a character
// from dark stone without turning the sprite into a bright rectangle. The
// highlight rolloff and the edge definition then describe the subject's own
// form. Nothing here brightens the sprite as a whole, and nothing adds a glow
// outside the silhouette.
//
// Sampling bias. An isolated bracket comparison of the same source and value
// curve (tests/visual/UnitArtSamplingBiasReview.tscn, 64px and 80px texture
// rects, four unit sprites) selected -0.5 for board/bench and combat: it keeps
// more figure form than an unbiased mip read while avoiding the level-0 noise of
// the mip-less sample. Portraits stay at 0.0 until a portrait-specific case
// supports a change. The third texture() argument is a sampling bias, not an
// explicit LOD, and no runtime mip level or runtime display size is claimed here.
uniform float exposure_gamma : hint_range(1.0, 2.0) = 1.38;
uniform float contrast : hint_range(0.8, 1.4) = 1.03;
uniform float contrast_pivot : hint_range(0.0, 1.0) = 0.26;
uniform float key_light : hint_range(0.0, 0.30) = 0.05;
uniform float highlight_rolloff : hint_range(0.0, 0.60) = 0.12;
uniform float edge_definition : hint_range(0.0, 1.0) = 0.26;
uniform float contact_shade : hint_range(0.0, 0.60) = 0.0;
uniform float contact_start : hint_range(0.0, 1.0) = 0.82;
uniform float sample_bias : hint_range(-2.0, 2.0) = 0.0;

varying vec4 v_tint;

void vertex() {
	v_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV, sample_bias);
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
		// Highlight restraint: compress only the top of the range, so a lit face
		// or blade keeps its shape instead of flattening into a bright patch.
		float peak = dot(c, vec3(0.299, 0.587, 0.114));
		c *= 1.0 - highlight_rolloff * smoothstep(0.55, 1.0, peak);
		// Very subtle neutral key light from above; deliberately no colour cast.
		c *= 1.0 + key_light * (0.5 - UV.y);
		if (edge_definition > 0.0) {
			// Silhouette definition from the sprite's own alpha edge. The MINIMUM
			// neighbour alpha is what identifies the outermost opaque texel: a
			// texel on the boundary has at least one transparent neighbour, while
			// a texel one step inside has four opaque ones. (A maximum would be
			// inert on any solid silhouette, so it is deliberately not used.)
			// The boundary texel is nudged down and the interior is left alone,
			// so the figure separates by its own drawn edge. This never adds
			// light outside the silhouette, so there is no halo, and the source
			// identity is untouched.
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
			// Seat the base of the figure against the ground it stands on.
			float seat = smoothstep(contact_start, 1.0, UV.y) * contact_shade;
			c *= 1.0 - seat;
		}
		COLOR = vec4(clamp(c, 0.0, 1.0), tex.a) * v_tint;
	}
}
