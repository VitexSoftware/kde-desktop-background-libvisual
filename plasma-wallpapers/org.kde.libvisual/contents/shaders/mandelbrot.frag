#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Qt6 ShaderEffect uniform block: qt_Matrix and qt_Opacity must be first.
layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;
    float audioPeak;
    float audioSensitivity;
    float centerX;
    float centerY;
    int   colorScheme;
    int   maxIter;
} ubuf;

// Mirror the QML color scheme function in GLSL so all modes look consistent.
vec4 colorForScheme(float ratio, float intensity) {
    float r, g, b;
    if (ubuf.colorScheme == 0) {          // Rainbow Spectrum
        float h = ratio * 6.0;
        int   s = int(h);
        float f = h - float(s);
        if      (s == 0) { r = 1.0;     g = f;      b = 0.0; }
        else if (s == 1) { r = 1.0 - f; g = 1.0;    b = 0.0; }
        else if (s == 2) { r = 0.0;     g = 1.0;    b = f; }
        else if (s == 3) { r = 0.0;     g = 1.0 - f;b = 1.0; }
        else if (s == 4) { r = f;       g = 0.0;    b = 1.0; }
        else             { r = 1.0;     g = 0.0;    b = 1.0 - f; }
        float sat = 0.8 + intensity * 0.2;
        float val = 0.5 + intensity * 0.5;
        r = val * (1.0 - sat * (1.0 - r));
        g = val * (1.0 - sat * (1.0 - g));
        b = val * (1.0 - sat * (1.0 - b));
    } else if (ubuf.colorScheme == 1) {   // Blue Gradient
        r = 0.1 + intensity * 0.3;
        g = 0.3 + intensity * 0.5;
        b = 0.5 + intensity * 0.5;
    } else if (ubuf.colorScheme == 2) {   // Fire
        r = 0.8 + intensity * 0.2;
        g = 0.3 * intensity;
        b = 0.1 * intensity;
    } else if (ubuf.colorScheme == 3) {   // Plasma
        r = 0.5 + intensity * 0.5;
        g = 0.2 * intensity;
        b = 0.5 + intensity * 0.5;
    } else {                               // Monochrome
        float gray = 0.3 + intensity * 0.7;
        r = gray; g = gray; b = gray;
    }
    return vec4(r, g, b, 0.9);
}

void main() {
    vec2 uv = qt_TexCoord0;

    // Audio-reactive zoom: same formula as the Canvas version
    float zoomLevel = pow(0.95, ubuf.time * 10.0 + ubuf.audioPeak * 20.0);
    zoomLevel = max(zoomLevel, 1e-6);  // guard against denormals after long run

    float x0 = (uv.x - 0.5) * 3.5 * zoomLevel + ubuf.centerX;
    float y0 = (uv.y - 0.5) * 2.0 * zoomLevel + ubuf.centerY;

    float x = 0.0, y = 0.0;
    int iteration = 0;
    int limit = min(ubuf.maxIter, 200); // cap loop bound for shader compiler

    for (int i = 0; i < 200; ++i) {
        if (i >= limit) break;
        if (x * x + y * y > 4.0) break;
        float xtemp = x * x - y * y + x0;
        y = 2.0 * x * y + y0;
        x = xtemp;
        iteration = i + 1;
    }

    if (iteration < limit) {
        float ratio     = float(iteration) / float(limit);
        float intensity = 0.8 + ubuf.audioPeak * 0.2;
        fragColor = colorForScheme(ratio, intensity) * ubuf.qt_Opacity;
    } else {
        // Interior of the Mandelbrot set — black
        fragColor = vec4(0.0, 0.0, 0.0, ubuf.qt_Opacity);
    }
}
