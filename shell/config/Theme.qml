pragma Singleton

import Quickshell
import QtQuick

// Material-style color roles derived from one seed hue, in OKLCH, matching
// the prototype. Everything is opaque: apps and the shell use these surfaces,
// never transparency.
Singleton {
    id: root

    property real seedHue: 160
    property bool dark: true

    function oklch(L, C, h) {
        const hr = h * Math.PI / 180;
        const A = C * Math.cos(hr), B = C * Math.sin(hr);
        const l = Math.pow(L + 0.3963377774 * A + 0.2158037573 * B, 3);
        const m = Math.pow(L - 0.1055613458 * A - 0.0638541728 * B, 3);
        const s = Math.pow(L - 0.0894841775 * A - 1.2914855480 * B, 3);
        const enc = x => {
            x = Math.min(1, Math.max(0, x));
            return x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
        };
        return Qt.rgba(enc(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                       enc(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                       enc(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s), 1);
    }

    readonly property real h: seedHue
    readonly property real th: seedHue + 70

    readonly property color surface:              dark ? oklch(0.165, 0.012, h) : oklch(0.975, 0.008, h)
    readonly property color surfaceContainerLow:  dark ? oklch(0.195, 0.014, h) : oklch(0.955, 0.010, h)
    readonly property color surfaceContainer:     dark ? oklch(0.215, 0.015, h) : oklch(0.940, 0.012, h)
    readonly property color surfaceContainerHigh: dark ? oklch(0.250, 0.016, h) : oklch(0.920, 0.014, h)
    readonly property color surfaceContainerHighest: dark ? oklch(0.290, 0.018, h) : oklch(0.895, 0.016, h)
    readonly property color fgSurface:            dark ? oklch(0.920, 0.012, h) : oklch(0.220, 0.015, h)
    readonly property color fgSurfaceVariant:     dark ? oklch(0.790, 0.020, h) : oklch(0.420, 0.020, h)
    readonly property color outline:              dark ? oklch(0.600, 0.020, h) : oklch(0.550, 0.020, h)
    readonly property color outlineVariant:       dark ? oklch(0.360, 0.020, h) : oklch(0.820, 0.015, h)
    readonly property color primary:              dark ? oklch(0.820, 0.100, h) : oklch(0.460, 0.110, h)
    readonly property color fgPrimary:            dark ? oklch(0.300, 0.070, h) : oklch(0.990, 0.010, h)
    readonly property color primaryContainer:     dark ? oklch(0.380, 0.090, h) : oklch(0.900, 0.060, h)
    readonly property color fgPrimaryContainer:   dark ? oklch(0.930, 0.050, h) : oklch(0.280, 0.070, h)
    readonly property color secondaryContainer:   dark ? oklch(0.360, 0.035, h) : oklch(0.900, 0.025, h)
    readonly property color fgSecondaryContainer: dark ? oklch(0.910, 0.025, h) : oklch(0.280, 0.030, h)
    readonly property color tertiaryContainer:    dark ? oklch(0.380, 0.070, th) : oklch(0.900, 0.050, th)
    readonly property color fgTertiaryContainer:  dark ? oklch(0.930, 0.040, th) : oklch(0.280, 0.060, th)
    readonly property color error:                dark ? oklch(0.780, 0.120, 25) : oklch(0.500, 0.170, 25)

    // Solid wallpaper; it only shows in gaps inside a workspace and on empty workspaces.
    readonly property color wallpaper:            dark ? oklch(0.340, 0.050, h) : oklch(0.840, 0.050, h)
}
