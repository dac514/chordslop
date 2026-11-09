#!/usr/bin/env python3
"""Draw cover.png (600x350) and thumbnail.png (120x45) for renoise.com.

Input is a capture of the ChordSlop dialog (from `just screenshot`), in C major
with the first preset loaded and no pad of the first row selected. Needs
Pillow. See scripts/cover/README.md.

    python3 scripts/cover/compose.py dist/screenshot-...-2.png dist/cover
"""

import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 4  # draw at four times the size, then scale down for smooth edges

BG = (31, 31, 31)
WHITE = (242, 242, 242)
GREEN = (98, 193, 126)
GREY = (160, 160, 160)
DIM = (120, 120, 120)

CIRCLE_SIZE = 400  # CIRCLE_SIZE in src/ui.lua
R_OUTER = 0.42  # circle.layout: label ring radius, as a share of the size
R_EDGE = 0.49  # circle.layout: disc edge

FONTS = {
    "bold": [
        "/usr/share/fonts/rsms-inter-fonts/InterDisplay-Bold.ttf",
        "C:/Windows/Fonts/segoeuib.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
    ],
    "regular": [
        "/usr/share/fonts/rsms-inter-fonts/Inter-Regular.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
    ],
}


def font(kind, px):
    for path in FONTS[kind]:
        if os.path.exists(path):
            return ImageFont.truetype(path, px * SS)
    sys.exit(f"error no {kind} font found; add one to FONTS")


def find_circle(src):
    """Top-left corner of the circle stack, found from the green tonic marker.

    The marker is a triangle at the top centre of the canvas, so its top row
    is the stack's top edge and its centre is the stack's centre line.
    """
    px = src.load()
    for y in range(src.height):
        xs = [x for x in range(min(src.width, 440)) if _greenish(px[x, y])]
        if xs:
            return round((min(xs) + max(xs)) / 2 - CIRCLE_SIZE / 2), y
    sys.exit("error tonic marker not found; is the dialog in the capture?")


def _greenish(c):
    return c[1] > c[0] + 35 and c[1] > c[2] + 25


def sample(src, cx, cy, k, dx):
    """Colour of the outer ring button at position k (0 = top, clockwise)."""
    import math

    a = math.radians(k * 30)
    r = CIRCLE_SIZE * R_OUTER
    x = cx + CIRCLE_SIZE / 2 + r * math.sin(a) + dx
    y = cy + CIRCLE_SIZE / 2 - r * math.cos(a) + 6
    return src.getpixel((round(x), round(y)))[:3]


def radial(size, box, color, alpha, blur):
    """A soft coloured glow: a filled ellipse, blurred, as an RGBA layer."""
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse(box, fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(mask)
    return layer


def draw_disc(img, src, circle, x, y, d):
    """Paste the circle of fifths from the capture as a disc of diameter d."""
    cx, cy = circle
    full = round(d / (2 * R_EDGE))  # the disc edge is 0.49 of the stack
    stack = src.crop((cx, cy, cx + CIRCLE_SIZE, cy + CIRCLE_SIZE)).resize(
        (full, full), Image.LANCZOS
    )
    off = (full - d) // 2
    disc = stack.crop((off, off, off + d, off + d))
    shadow = radial(img.size, (x - 6 * SS, y, x + d + 6 * SS, y + d + 14 * SS), (0, 0, 0), 170, 10 * SS)
    img.alpha_composite(shadow)
    mask = Image.new("L", (d, d), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, d - 1, d - 1), fill=255)
    img.paste(disc, (x, y), mask)
    ImageDraw.Draw(img).ellipse(
        (x, y, x + d - 1, y + d - 1), outline=(255, 255, 255, 60), width=max(1, round(1.5 * SS / 2))
    )


def two_tone(draw, xy, size, first, second):
    x, y = xy
    f = font("bold", size)
    draw.text((x, y), first, font=f, fill=WHITE)
    w = draw.textlength(first, font=f)
    draw.text((x + w - SS, y), second, font=f, fill=GREEN)


def cover(src, circle, pads, colors):
    W, H = 600 * SS, 350 * SS
    img = Image.new("RGBA", (W, H), BG + (255,))
    # soft glows behind the disc: green for home, a little blue for next door
    img.alpha_composite(radial(img.size, (300 * SS, 10 * SS, 640 * SS, 350 * SS), GREEN, 60, 60 * SS))
    img.alpha_composite(radial(img.size, (430 * SS, 150 * SS, 640 * SS, 360 * SS), colors["near"], 40, 50 * SS))
    draw_disc(img, src, circle, 345 * SS, 32 * SS, 250 * SS)

    draw = ImageDraw.Draw(img)
    x0 = 34 * SS
    two_tone(draw, (x0, 40 * SS), 50, "Chord", "Slop")
    tag = font("regular", 18)
    draw.text((x0, 116 * SS), "Chord pads for trackers.", font=tag, fill=WHITE)
    draw.text((x0, 144 * SS), "Sixteen chords that fit the key.", font=tag, fill=GREY)
    draw.text((x0, 168 * SS), "Play from pads, MIDI or QWERTY.", font=tag, fill=GREY)

    # the first pad row from the capture, at half size
    gx, gy, gw, gh = pads
    row = src.crop((gx, gy, gx + gw, gy + gh)).resize((gw * SS // 2, gh * SS // 2), Image.LANCZOS)
    img.paste(row, (x0, 214 * SS))

    # legend: the three colours of the circle and the pads
    small = font("regular", 13)
    x = x0
    y = 266 * SS
    for name, label in (("home", "Home"), ("near", "Next door"), ("far", "Far")):
        s = 11 * SS
        draw.rounded_rectangle((x, y + 2 * SS, x + s, y + 2 * SS + s), radius=3 * SS, fill=colors[name])
        x += s + 7 * SS
        draw.text((x, y), label, font=small, fill=GREY)
        x += draw.textlength(label, font=small) + 18 * SS

    draw.text((x0, 316 * SS), "Renoise 3.5", font=small, fill=DIM)
    return img.resize((600, 350), Image.LANCZOS).convert("RGB")


def thumbnail(src, circle):
    W, H = 120 * SS, 45 * SS
    img = Image.new("RGBA", (W, H), BG + (255,))
    draw_disc(img, src, circle, 5 * SS, 5 * SS, 35 * SS)
    two_tone(ImageDraw.Draw(img), (43 * SS, 10 * SS), 15, "Chord", "Slop")
    return img.resize((120, 45), Image.LANCZOS).convert("RGB")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("capture", help="PNG of the ChordSlop dialog")
    ap.add_argument("out", help="folder for cover.png and thumbnail.png")
    ap.add_argument(
        "--pads",
        default="446,65,504,61",
        help="first pad row inside the capture: x,y,w,h (default %(default)s)",
    )
    args = ap.parse_args()
    src = Image.open(args.capture).convert("RGB")
    circle = find_circle(src)
    pads = tuple(int(v) for v in args.pads.split(","))
    cx, cy = circle
    colors = {
        "home": sample(src, cx, cy, 0, 18),  # C
        "near": sample(src, cx, cy, 2, 18),  # D, next door in C major
        "far": sample(src, cx, cy, 9, 18),  # Eb, far from C major
    }
    os.makedirs(args.out, exist_ok=True)
    cover(src, circle, pads, colors).save(os.path.join(args.out, "cover.png"))
    thumbnail(src, circle).save(os.path.join(args.out, "thumbnail.png"))
    print(f"ok circle at {circle}, colours {colors}, wrote {args.out}/cover.png and thumbnail.png")


if __name__ == "__main__":
    main()
