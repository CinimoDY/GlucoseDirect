#!/usr/bin/env python3
"""Generate DOSBTS app icon with CGM sensor disc + chart line."""

from PIL import Image, ImageDraw
import math
import os

SIZE = 1024

# Colors (matching AmberTheme)
BLACK = (0, 0, 0, 255)
AMBER = (255, 176, 0, 255)       # #FFB000
AMBER_DIM = (154, 87, 0, 255)    # #9A5700
AMBER_LIGHT = (253, 202, 159, 255)  # #FDCA9F


def draw_sensor_disc(draw, cx, cy, radius, s):
    """Draw a CGM sensor disc (circular, like Libre sensor)."""
    LINE_W = max(3, int(8 * s))

    # Outer ring
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        outline=AMBER, width=LINE_W
    )

    # Inner ring (sensor housing)
    inner_r = radius * 0.65
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        outline=AMBER, width=max(2, int(5 * s))
    )

    # Center dot (sensor filament entry)
    dot_r = radius * 0.15
    draw.ellipse(
        [cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r],
        fill=AMBER
    )

    # Small tick marks around outer ring (adhesive pattern)
    tick_count = 12
    for i in range(tick_count):
        angle = (2 * math.pi * i / tick_count) - math.pi / 2
        outer_x = cx + math.cos(angle) * (radius + radius * 0.08)
        outer_y = cy + math.sin(angle) * (radius + radius * 0.08)
        inner_x = cx + math.cos(angle) * (radius - radius * 0.04)
        inner_y = cy + math.sin(angle) * (radius - radius * 0.04)
        draw.line(
            [(inner_x, inner_y), (outer_x, outer_y)],
            fill=AMBER_DIM, width=max(2, int(3 * s))
        )


def draw_chart_line(draw, size):
    """Draw a glucose chart line below the sensor."""
    s = size / 1024.0
    LINE_W = max(3, int(10 * s))

    # Chart line points (glucose trace)
    base_y = size * 0.78
    points = [
        (size * 0.08, base_y + size * 0.02),
        (size * 0.20, base_y - size * 0.04),
        (size * 0.32, base_y + size * 0.01),
        (size * 0.45, base_y - size * 0.06),
        (size * 0.55, base_y - size * 0.01),
        (size * 0.68, base_y - size * 0.08),
        (size * 0.80, base_y - size * 0.03),
        (size * 0.92, base_y - size * 0.10),
    ]

    draw.line(points, fill=AMBER, width=LINE_W, joint="curve")


def draw_fork_knife(draw, cx, cy, s):
    """Draw a small fork+knife symbol."""
    LINE_W = max(2, int(4 * s))
    h = 50 * s  # total height of utensils

    # Fork (left)
    fork_x = cx - 14 * s
    # Handle
    draw.line([(fork_x, cy + h * 0.5), (fork_x, cy - h * 0.1)], fill=AMBER_DIM, width=LINE_W)
    # Tines
    for dx in [-6 * s, 0, 6 * s]:
        draw.line([(fork_x + dx, cy - h * 0.1), (fork_x + dx, cy - h * 0.5)], fill=AMBER_DIM, width=max(1, int(2 * s)))

    # Knife (right)
    knife_x = cx + 14 * s
    draw.line([(knife_x, cy + h * 0.5), (knife_x, cy - h * 0.5)], fill=AMBER_DIM, width=LINE_W)
    # Blade widening
    draw.line([(knife_x, cy - h * 0.5), (knife_x + 8 * s, cy - h * 0.15)], fill=AMBER_DIM, width=max(1, int(2 * s)))


def generate_icon(size):
    """Generate icon at given size."""
    img = Image.new('RGBA', (size, size), BLACK)
    draw = ImageDraw.Draw(img)

    s = size / 1024.0

    # 1. CGM sensor disc (center-upper)
    sensor_cx = size * 0.50
    sensor_cy = size * 0.38
    sensor_r = size * 0.22
    draw_sensor_disc(draw, sensor_cx, sensor_cy, sensor_r, s)

    # 2. Chart line (bottom)
    draw_chart_line(draw, size)

    # 3. Small fork+knife (bottom-right of sensor)
    draw_fork_knife(draw, size * 0.78, size * 0.58, s)

    return img.convert('RGB')


# Generate all required sizes
ICON_DIR = "Library/Assets.xcassets/AppIcon.appiconset"
SIZES = [20, 29, 40, 50, 57, 58, 60, 72, 76, 80, 87, 100, 114, 120, 144, 152, 167, 180, 1024]

# Generate 1024 master and resize
master = generate_icon(1024)

for s in SIZES:
    resized = master.resize((s, s), Image.LANCZOS)
    path = os.path.join(ICON_DIR, f"{s}.png")
    resized.save(path)
    print(f"  Saved {path}")

print("Done!")
