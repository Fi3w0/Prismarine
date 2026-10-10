.pragma library

// Minecraft's unfolded cuboid textures: origin, width, height and depth in pixels.
function parts(slim, legacy, layers) {
    const arm = slim && !legacy ? 3 : 4;
    let parts = [
        {x: 0, y: 12, w: 8, h: 8, d: 8, u: 0, v: 0},
        {x: 0, y: 2, w: 8, h: 12, d: 4, u: 16, v: 16},
        {x: -(4 + arm / 2), y: 2, w: arm, h: 12, d: 4, u: 40, v: 16},
        {x: 4 + arm / 2, y: 2, w: arm, h: 12, d: 4, u: legacy ? 40 : 32, v: legacy ? 16 : 48, mirror: legacy},
        {x: -2, y: -10, w: 4, h: 12, d: 4, u: 0, v: 16},
        {x: 2, y: -10, w: 4, h: 12, d: 4, u: legacy ? 0 : 16, v: legacy ? 16 : 48, mirror: legacy}
    ];
    if (layers) {
        parts.push({x: 0, y: 12, w: 8, h: 8, d: 8, u: 32, v: 0, inflate: 0.5});
        if (!legacy) parts = parts.concat([
            {x: 0, y: 2, w: 8, h: 12, d: 4, u: 16, v: 32, inflate: 0.25},
            {x: -(4 + arm / 2), y: 2, w: arm, h: 12, d: 4, u: 40, v: 32, inflate: 0.25},
            {x: 4 + arm / 2, y: 2, w: arm, h: 12, d: 4, u: 48, v: 48, inflate: 0.25},
            {x: -2, y: -10, w: 4, h: 12, d: 4, u: 0, v: 32, inflate: 0.25},
            {x: 2, y: -10, w: 4, h: 12, d: 4, u: 0, v: 48, inflate: 0.25}
        ]);
    }
    return parts;
}
