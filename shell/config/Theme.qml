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


    // Each role: [lightness, chroma] in dark, then in light, at the seed hue
    // (tertiary roles are offset from it; error has its own hue). Kept as a
    // table so a role can be read in either theme: foot and the window
    // borders get both (see services/Settings.qml).
    readonly property var roles: ({
        surface:                 [0.165, 0.012, 0.975, 0.008],
        surfaceContainerLow:     [0.195, 0.014, 0.955, 0.010],
        surfaceContainer:        [0.215, 0.015, 0.940, 0.012],
        surfaceContainerHigh:    [0.250, 0.016, 0.920, 0.014],
        surfaceContainerHighest: [0.290, 0.018, 0.895, 0.016],
        fgSurface:               [0.920, 0.012, 0.220, 0.015],
        fgSurfaceVariant:        [0.790, 0.020, 0.420, 0.020],
        outline:                 [0.600, 0.020, 0.550, 0.020],
        outlineVariant:          [0.360, 0.020, 0.820, 0.015],
        primary:                 [0.820, 0.100, 0.460, 0.110],
        fgPrimary:               [0.300, 0.070, 0.990, 0.010],
        primaryContainer:        [0.380, 0.090, 0.900, 0.060],
        fgPrimaryContainer:      [0.930, 0.050, 0.280, 0.070],
        secondaryContainer:      [0.360, 0.035, 0.900, 0.025],
        fgSecondaryContainer:    [0.910, 0.025, 0.280, 0.030],
        tertiaryContainer:       [0.380, 0.070, 0.900, 0.050],
        fgTertiaryContainer:     [0.930, 0.040, 0.280, 0.060],
        error:                   [0.780, 0.120, 0.500, 0.170],
        // Solid wallpaper; it only shows in gaps inside a workspace and on empty workspaces.
        wallpaper:               [0.340, 0.050, 0.840, 0.050],
    })

    function role(name: string, isDark: bool): color {
        const r = roles[name];
        const hue = name === "error" ? 25 : name.includes("ertiary") ? seedHue + 70 : seedHue;
        return isDark ? oklch(r[0], r[1], hue) : oklch(r[2], r[3], hue);
    }
    // "rrggbb", for configs outside the shell.
    function hex(name: string, isDark: bool): string {
        return role(name, isDark).toString().slice(1);
    }

    readonly property color surface:                 role("surface", dark)
    readonly property color surfaceContainerLow:     role("surfaceContainerLow", dark)
    readonly property color surfaceContainer:        role("surfaceContainer", dark)
    readonly property color surfaceContainerHigh:    role("surfaceContainerHigh", dark)
    readonly property color surfaceContainerHighest: role("surfaceContainerHighest", dark)
    readonly property color fgSurface:               role("fgSurface", dark)
    readonly property color fgSurfaceVariant:        role("fgSurfaceVariant", dark)
    readonly property color outline:                 role("outline", dark)
    readonly property color outlineVariant:          role("outlineVariant", dark)
    readonly property color primary:                 role("primary", dark)
    readonly property color fgPrimary:               role("fgPrimary", dark)
    readonly property color primaryContainer:        role("primaryContainer", dark)
    readonly property color fgPrimaryContainer:      role("fgPrimaryContainer", dark)
    readonly property color secondaryContainer:      role("secondaryContainer", dark)
    readonly property color fgSecondaryContainer:    role("fgSecondaryContainer", dark)
    readonly property color tertiaryContainer:       role("tertiaryContainer", dark)
    readonly property color fgTertiaryContainer:     role("fgTertiaryContainer", dark)
    readonly property color error:                   role("error", dark)
    readonly property color wallpaper:               role("wallpaper", dark)
}
