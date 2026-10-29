shader_type canvas_item;
// Draws a part's shadow from its top-down outline: every pixel takes the
// darkest of `steps` copies of the outline, shifted from nothing up to
// `sweep` (in texture pixels). With `sweep` set to how far the shadow moves
// between the part's lowest and highest points, that's the shadow a solid
// spanning those heights casts. One pass, so no visible stepping.
// `opacity` darkens it to taste when it isn't inside a faded shadow group.
// Used by scripts/helicopter.gd and scripts/radio_station.gd.

uniform vec2 sweep = vec2(0.0);
uniform int steps = 24;
uniform float opacity = 1.0;

void fragment() {
	float a = 0.0;
	for (int i = 0; i <= steps; i++) {
		vec2 uv = UV - sweep * TEXTURE_PIXEL_SIZE * (float(i) / float(steps));
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
			a = max(a, texture(TEXTURE, uv).a);
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, a * opacity);
}
