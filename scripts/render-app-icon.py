"""
Render the DOSBTS app icon — eiDotter yolk restated as a 3-cellular CGM sensor.

Uses Pillow primitives (circles + arcs + gradients) so no libcairo dependency.
Source of truth is the SVG at scripts/app-icon.svg; this script is the
rasterizer. If the SVG changes, the shapes here should be kept in sync.

Palette hexes match eiDotter brand tokens from
  src/components/Brand/components/Logo.tsx:
    amber base    #FFB000
    dome          #FFD97A
    specular      #FFE8A8
"""

from PIL import Image, ImageDraw, ImageFilter
from math import cos, sin, radians

SIZE = 1024
CENTER = (SIZE // 2, SIZE // 2)

# --- Palette (brand-locked to eiDotter) ---
BLACK = (0, 0, 0, 255)
AMBER = (255, 176, 0, 255)         # #FFB000
AMBER_DARK = (154, 87, 0, 255)     # #9A5700
DOME = (255, 217, 122, 255)        # #FFD97A
SPECULAR = (255, 232, 168, 255)    # #FFE8A8
WHITE = (255, 255, 255, 255)


def radial_gradient_circle(size: int, radius: int, center: tuple[int, int],
                           inner: tuple[int, int, int, int],
                           mid: tuple[int, int, int, int],
                           outer: tuple[int, int, int, int],
                           highlight_offset: tuple[int, int] = (0, 0)) -> Image.Image:
    """Build a radially-shaded filled circle on a transparent canvas.

    `highlight_offset` lets the brightest spot sit off-centre (matches the
    radialGradient cx/cy in the SVG — 45%/42% of the circle bounds).
    """
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx, cy = center
    hx, hy = highlight_offset
    bright_cx, bright_cy = cx + hx, cy + hy
    for y in range(cy - radius, cy + radius + 1):
        for x in range(cx - radius, cx + radius + 1):
            dx = x - cx
            dy = y - cy
            dist = (dx * dx + dy * dy) ** 0.5
            if dist > radius:
                continue
            # Distance from bright spot → used to pick gradient stop
            bdx = x - bright_cx
            bdy = y - bright_cy
            bright_dist = (bdx * bdx + bdy * bdy) ** 0.5
            # Normalise 0 (bright) → 1 (outer edge)
            t = min(bright_dist / (radius * 1.1), 1.0)
            if t < 0.55:
                # inner → mid
                k = t / 0.55
                color = tuple(int(inner[i] * (1 - k) + mid[i] * k) for i in range(4))
            else:
                # mid → outer
                k = (t - 0.55) / 0.45
                color = tuple(int(mid[i] * (1 - k) + outer[i] * k) for i in range(4))
            canvas.putpixel((x, y), color)
    return canvas


BODY_RADIUS = 460   # fills ~90% of the 1024 frame — iOS mask rounds the corners
SCAN_RADIUS = 258   # the "active zone" ring, concentric with body
DOME_RADIUS = 72    # central filament exit point


def render() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), BLACK)
    draw = ImageDraw.Draw(img)

    # === Transmission arcs — symmetric cellular hint just outside the body ===
    # Four short arcs at the diagonals, reading as emissions radiating out.
    # Drawn first so the body's darker edge overlaps their inner ends.
    for angle_center in [45, 135, 225, 315]:
        span = 18
        for radius, width, alpha in [(BODY_RADIUS + 30, 14, 92),
                                     (BODY_RADIUS + 68, 10, 62),
                                     (BODY_RADIUS + 104, 6, 38)]:
            bbox = (CENTER[0] - radius, CENTER[1] - radius,
                    CENTER[0] + radius, CENTER[1] + radius)
            draw.arc(bbox,
                     start=angle_center - span, end=angle_center + span,
                     fill=(AMBER[0], AMBER[1], AMBER[2], alpha),
                     width=width)

    # === Layer 1 — sensor body (yolk outer disc) ===
    # Radial gradient from bright highlight → amber → darker amber at edge.
    body = radial_gradient_circle(
        SIZE, BODY_RADIUS, CENTER,
        inner=DOME,                   # brightest point
        mid=AMBER,                    # main fill
        outer=AMBER_DARK,             # edge falloff
        highlight_offset=(-65, -55),  # matches SVG radialGradient cx=45% cy=42%
    )
    img.alpha_composite(body)

    # Body edge — thin darker ring for definition against scanlines
    draw = ImageDraw.Draw(img)
    draw.ellipse(
        (CENTER[0] - BODY_RADIUS, CENTER[1] - BODY_RADIUS,
         CENTER[0] + BODY_RADIUS, CENTER[1] + BODY_RADIUS),
        outline=AMBER_DARK, width=8,
    )

    # === Phosphor glow — blur a copy of the bright layers, composite under ===
    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    # Active-scan ring
    glow_draw.ellipse(
        (CENTER[0] - SCAN_RADIUS, CENTER[1] - SCAN_RADIUS,
         CENTER[0] + SCAN_RADIUS, CENTER[1] + SCAN_RADIUS),
        outline=DOME, width=26,
    )
    # Central filament dome
    glow_draw.ellipse(
        (CENTER[0] - DOME_RADIUS, CENTER[1] - DOME_RADIUS,
         CENTER[0] + DOME_RADIUS, CENTER[1] + DOME_RADIUS),
        fill=SPECULAR,
    )
    # Blur + composite for phosphor bloom
    blurred = glow_layer.filter(ImageFilter.GaussianBlur(radius=20))
    img.alpha_composite(blurred)
    img.alpha_composite(glow_layer)

    # Inner dome highlight — hint of curvature on the filament exit
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)
    h_radius = 24
    h_cx, h_cy = CENTER[0] - 18, CENTER[1] - 18
    h_draw.ellipse(
        (h_cx - h_radius, h_cy - h_radius, h_cx + h_radius, h_cy + h_radius),
        fill=(WHITE[0], WHITE[1], WHITE[2], 140),  # opacity ~0.55
    )
    img.alpha_composite(highlight)

    # === Cardinal tick marks on the active-scan ring ===
    tick_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tick_draw = ImageDraw.Draw(tick_layer)
    tick_color = (AMBER[0], AMBER[1], AMBER[2], 217)  # opacity 0.85
    tick_inner = SCAN_RADIUS - 32
    tick_outer = SCAN_RADIUS + 32
    # top
    tick_draw.line([(CENTER[0], CENTER[1] - tick_outer),
                    (CENTER[0], CENTER[1] - tick_inner)], fill=tick_color, width=7)
    # bottom
    tick_draw.line([(CENTER[0], CENTER[1] + tick_inner),
                    (CENTER[0], CENTER[1] + tick_outer)], fill=tick_color, width=7)
    # left
    tick_draw.line([(CENTER[0] - tick_outer, CENTER[1]),
                    (CENTER[0] - tick_inner, CENTER[1])], fill=tick_color, width=7)
    # right
    tick_draw.line([(CENTER[0] + tick_inner, CENTER[1]),
                    (CENTER[0] + tick_outer, CENTER[1])], fill=tick_color, width=7)
    img.alpha_composite(tick_layer)

    # === Scanline overlay ===
    # Horizontal 2px-dark / 2px-transparent pattern, 8% opacity.
    scanlines = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sl_draw = ImageDraw.Draw(scanlines)
    for y in range(0, SIZE, 4):
        sl_draw.rectangle([(0, y), (SIZE, y + 2)], fill=(0, 0, 0, 20))
    img.alpha_composite(scanlines)

    return img.convert("RGB")


if __name__ == "__main__":
    out_path = "scripts/app-icon-1024.png"
    image = render()
    image.save(out_path, "PNG", optimize=True)
    print(f"wrote {out_path} ({image.size[0]}x{image.size[1]})")
