---
title: "Optimize README screenshots via Pillow when oxipng/pngcrush aren't installed"
date: 2026-04-22
category: best-practices
module: tooling
problem_type: best_practice
component: tooling
severity: low
applies_when:
  - "Adding or updating screenshots in a repo's README or docs"
  - "PNGs exported from `xcrun simctl io booted screenshot` or a phone's native screenshot"
  - "Repo doesn't have oxipng, pngcrush, or exiftool installed"
  - "Screenshots render smaller than capture size (e.g., README `width=280` on a 1179×2556 source)"
tags:
  - png
  - screenshots
  - optimization
  - pillow
  - readme-maintenance
  - metadata-strip
  - macos-native
---

# Optimize README screenshots via Pillow when oxipng/pngcrush aren't installed

## Context

Screenshots captured by `xcrun simctl io booted screenshot` — or by tapping volume-up + side-button on a phone — come out as high-bit-depth PNGs with metadata. Native iPhone 17 output is 1179×2556 at either 8-bit RGB or 16-bit RGB, with EXIF containing a capture timestamp and "Screenshot" description. That's fine for archival, but when the README renders the image at `width="280"`, the wasted bytes cost clone size on every `git clone` forever.

Classic tooling answer is `oxipng --strip all`, `pngcrush`, or `exiftool -all=`. None of those ship with macOS by default, and installing via Homebrew is friction for a task that runs once per README refresh. The macOS-native path: Python Pillow, which comes with system Python in most recent setups. One command re-encodes 16-bit → 8-bit, strips metadata, and applies optimal compression.

Discovered during PR #24 ce:review on DOSBTS when two of four screenshots were 998KB and 637KB while the other two were 224KB and 315KB — the difference was entirely bit depth (`file Screenshots/*.png` revealed half were `16-bit/color RGB`). `ps-5` finding in the same review flagged EXIF timestamps as a minor privacy-by-design violation.

## Guidance

### One-pass Pillow script

```python
from PIL import Image
import os

files = [
    'Screenshots/dosbts-overview.png',
    'Screenshots/dosbts-digest.png',
    'Screenshots/dosbts-meal-entry.png',
    'Screenshots/dosbts-settings.png',
]

for f in files:
    before = os.path.getsize(f)
    img = Image.open(f)

    # Convert 16-bit to 8-bit (safe for display-oriented screenshots)
    if img.mode in ('I', 'I;16'):
        img = img.convert('RGB')
    # Keep RGBA — don't strip alpha; some screenshot UIs use it

    # Re-encode without the info dict (strips EXIF + text chunks),
    # keep ICC profile if present (preserves wide-gamut color)
    tmp = f + '.tmp'
    img.save(tmp, 'PNG', optimize=True, compress_level=9)
    os.replace(tmp, f)

    after = os.path.getsize(f)
    print(f'{f}: {before:,} -> {after:,} bytes ({100*after/before:.0f}%)')
```

Run it from the repo root. `Image.save` without `exif=` or `pnginfo=` arguments writes a clean stream. `icc_profile` is preserved automatically because Pillow reads it into `img.info['icc_profile']` and re-embeds it on save unless explicitly removed.

### Check before you optimize

```bash
file Screenshots/*.png
```

Expected clean output: `8-bit/color RGB` or `8-bit/color RGBA`. If you see `16-bit/color RGB`, the file is a candidate for re-encode. File size alone isn't enough — a small 16-bit file may be fine but a large 8-bit file may already be optimal.

### Keep the ICC profile for wide-gamut captures

`oxipng --strip all` strips ICC profiles along with everything else. For the DOSBTS amber screenshots, stripping the Display P3 ICC flattens the rendered color to sRGB, which visibly dulls the phosphor glow. If the screenshot contains amber, neon green, or other out-of-sRGB colors that depend on P3, **keep the ICC**. Pillow's default save-without-`icc_profile=None` behavior is correct — don't override it.

To verify ICC survived:

```python
from PIL import Image
img = Image.open('Screenshots/dosbts-overview.png')
print('icc_profile' in img.info)  # True if preserved
```

## Why This Matters

- **Repo weight is forever.** Git stores every version of a PNG. Shipping 1MB instead of 230KB for a screenshot multiplies every clone for every contributor, forever. Optimizing at check-in time costs seconds; not optimizing costs bytes on every `git clone` into the future.
- **Privacy.** The capture timestamp in EXIF is minor but accumulates: a README with 4 screenshots all captured at `2026:04:22 15:2x:xx` reveals the exact session where they were made, which a careful reader can cross-reference against commit timestamps.
- **Render quality parity.** README displays at 280px regardless — the difference between 8-bit and 16-bit depth is invisible at that scale. The visible difference is that ICC-less screenshots lose their color vibrance.
- **Zero-install.** Pillow is already on the system. Asking a contributor to `brew install oxipng` before opening a screenshot PR is avoidable friction.

## When to Apply

- Before committing new screenshots to a repo's README or docs folder
- After a bulk screenshot harvest (post-feature demo, post-redesign)
- During a README refresh when existing screenshots are heavier than ~500KB each
- As part of a ce:review fix round when an oversized-asset finding appears

## Examples

### DOSBTS build-61 screenshot refresh (2026-04-22)

Before (4 PNGs, all 1179×2556):

```
file Screenshots/dosbts-*.png
Screenshots/dosbts-digest.png:     PNG image data, 1179 x 2556, 16-bit/color RGB   1,021,833 bytes
Screenshots/dosbts-meal-entry.png: PNG image data, 1179 x 2556, 8-bit/color RGB      228,513 bytes
Screenshots/dosbts-overview.png:   PNG image data, 1179 x 2556, 16-bit/color RGB     652,600 bytes
Screenshots/dosbts-settings.png:   PNG image data, 1206 x 2622, 8-bit/color RGBA     323,077 bytes
```

After running the Pillow script above:

```
Screenshots/dosbts-overview.png: 652,600 -> 232,546 bytes (36%)
Screenshots/dosbts-digest.png:   1,021,833 -> 403,030 bytes (39%)
Screenshots/dosbts-meal-entry.png:  228,513 -> 163,794 bytes (72%)
Screenshots/dosbts-settings.png:    323,077 -> 244,362 bytes (76%)

Total: 2,226,023 -> 1,043,732 bytes (47% reduction)
```

EXIF creation timestamps gone. Display P3 `icc_profile` preserved on overview and digest. README renders identically at `width=280`.

## Related

- PR #24 (DOSBTS) `dcf498ed` — first application of this pattern
- ce:review finding `ps-4` / `ps-5` from run `20260422-152942-caefe00d` — the size and metadata flags that prompted it
- `docs/solutions/best-practices/ios-26-uiscreen-main-migration-20260422.md` — sibling finding from the same review cycle
