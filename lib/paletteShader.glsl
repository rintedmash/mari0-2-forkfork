extern number n;
extern vec4 oldColors[4];
extern vec4 newColors[4];

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);

    for (int i = 0; i < 4; i++) {
        if (float(i) < n && all(equal(pixel, oldColors[i]))) {
            return newColors[i] * color;
        }
    }

    return pixel * color;
}
