"""Draws the launcher icon: the game's five colours running along one arrow
that points at the top-right corner.

Run from the project root:  python tool/make_icon.py
"""

from PIL import Image, ImageDraw
import os

COLORS = ['#FF4040', '#FFB800', '#1FD67A', '#2F8CFF', '#9160FF']  # lib/theme.dart
BG = '#141C26'

RES = 'android/app/src/main/res'
# Android asks for one icon per screen density.
LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
# An adaptive icon is drawn on a larger canvas and cropped by the launcher.
ADAPTIVE = {k: round(v * 2.25) for k, v in LEGACY.items()}
# Only the middle of that canvas is guaranteed to stay visible. The arrow is
# a diagonal band, so its tips sit well inside its own bounding box.
SAFE = 0.80

S = 1024


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(colors, width):
    """One pixel row running through every colour in turn."""
    strip = Image.new('RGB', (width, 1))
    px, stops = strip.load(), [rgb(c) for c in colors]
    for x in range(width):
        t = x / (width - 1) * (len(stops) - 1)
        i = min(int(t), len(stops) - 2)
        f = t - i
        a, b = stops[i], stops[i + 1]
        px[x, 0] = tuple(round(a[k] + (b[k] - a[k]) * f) for k in range(3))
    return strip


def arrow():
    """The arrow alone, on transparent pixels. Drawn lying flat so the
    gradient can simply run along its length, then turned to point up-right."""
    big = int(S * 1.5)
    c, u = big / 2, S / 1000
    tail, tip = c - 330 * u, c + 350 * u
    shaft, head = 160 * u, 235 * u

    mask = Image.new('L', (big, big), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(
        [tail, c - shaft / 2, c + 150 * u, c + shaft / 2],
        radius=shaft / 2, fill=255,
    )
    d.polygon([(tip, c), (c + 80 * u, c - head), (c + 80 * u, c + head)], fill=255)

    grad = Image.new('RGB', (big, big), rgb(COLORS[-1]))
    grad.paste(Image.new('RGB', (int(tail), big), rgb(COLORS[0])), (0, 0))
    span = int(tip - tail)
    grad.paste(ramp(COLORS, span).resize((span, big), Image.BICUBIC), (int(tail), 0))

    layer = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    layer.paste(grad.convert('RGBA'), mask=mask)
    layer = layer.rotate(45, Image.BICUBIC)
    o = (big - S) // 2
    return layer.crop((o, o, o + S, o + S))


def rounded(size, radius):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def main():
    art = arrow()

    plate = rounded(S, int(S * 0.22))
    legacy = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    legacy.paste(Image.new('RGBA', (S, S), rgb(BG) + (255,)), mask=plate)
    legacy.alpha_composite(art)
    legacy.putalpha(Image.composite(legacy.getchannel('A'), plate, plate))

    inner = round(S * SAFE)
    foreground = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    foreground.paste(art.resize((inner, inner), Image.LANCZOS), ((S - inner) // 2,) * 2)

    for density, px in LEGACY.items():
        out = f'{RES}/mipmap-{density}'
        os.makedirs(out, exist_ok=True)
        legacy.resize((px, px), Image.LANCZOS).save(f'{out}/ic_launcher.png')
        fg = ADAPTIVE[density]
        foreground.resize((fg, fg), Image.LANCZOS).save(f'{out}/ic_launcher_foreground.png')
        print(f'{density}: {px}px icon, {fg}px foreground')


if __name__ == '__main__':
    main()
