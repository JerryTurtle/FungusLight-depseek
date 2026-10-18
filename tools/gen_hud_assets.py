"""Generate the pixel HUD icon set.

All art is authored here as nearest-neighbour pixel art so the HUD matches the
16-bit look of the game without importing third-party icons. Run from the
repository root:

    python tools/gen_hud_assets.py

Outputs 24x24 icons (and a 16x22 potion bottle) under game/assets/hud/.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "hud"
OUT.mkdir(parents=True, exist_ok=True)

# Shared palette lifted from the world art: soot, brass, lamp amber, mint, teal.
K = (13, 20, 22, 255)       # outline
D = (35, 31, 27, 255)       # dark metal / wood
B = (93, 66, 38, 255)       # brass shadow
G = (172, 126, 67, 255)     # brass
H = (232, 196, 118, 255)    # brass highlight
A = (240, 176, 67, 255)     # amber
a = (255, 226, 151, 255)    # pale amber
T = (72, 190, 171, 255)     # teal
t = (150, 236, 213, 255)    # mint
W = (241, 255, 244, 255)    # white glow
R = (199, 74, 65, 255)      # muted red
r = (255, 139, 107, 255)    # warm red highlight
S = (129, 145, 141, 255)    # steel
O = (0, 0, 0, 0)            # transparent


def canvas(w=24, h=24):
    image = Image.new("RGBA", (w, h), O)
    return image, ImageDraw.Draw(image)


def rect(draw, x0, y0, x1, y1, fill):
    draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=fill)


def save(image, name):
    image.save(OUT / name, optimize=True)
    print("wrote", OUT / name)


def melee():
    image, d = canvas()
    # Sweeping cut: layered arc, hot leading edge, then the lamp-staff.
    d.arc([2, 2, 22, 22], 198, 330, fill=D, width=6)
    d.arc([2, 2, 22, 22], 200, 328, fill=T, width=4)
    d.arc([3, 3, 21, 21], 202, 322, fill=t, width=2)
    d.arc([4, 4, 20, 20], 208, 314, fill=W, width=1)
    # Staff shaft behind the lantern.
    d.line([(3, 21), (14, 10)], fill=K, width=4)
    d.line([(3, 21), (14, 10)], fill=G, width=2)
    d.point((6, 18), fill=H)
    d.point((9, 15), fill=H)
    # Lantern head.
    rect(d, 14, 4, 21, 11, K)
    rect(d, 15, 5, 20, 10, G)
    rect(d, 16, 6, 19, 9, D)
    rect(d, 17, 7, 18, 8, A)
    d.point((17, 6), fill=a)
    d.point((14, 4), fill=H)
    d.point((20, 10), fill=B)
    return image


def light():
    image, d = canvas()
    # Lantern at the left edge.
    rect(d, 3, 8, 9, 16, K)
    rect(d, 4, 9, 8, 15, G)
    rect(d, 5, 10, 7, 14, D)
    rect(d, 6, 11, 7, 13, A)
    d.point((6, 10), fill=a)
    # Cone of light, broad halo first, then a hard white seam.
    d.polygon([(8, 10), (23, 5), (23, 19), (8, 14)], fill=(52, 146, 131, 190))
    d.polygon([(8, 11), (23, 8), (23, 16), (8, 13)], fill=(122, 226, 200, 220))
    d.line([(9, 12), (22, 12)], fill=W, width=1)
    d.point((14, 10), fill=t)
    d.point((18, 14), fill=T)
    return image


def shield():
    image, d = canvas()
    # Cyan dome over a lamp: the temporary ward, not a wall.
    d.polygon([(12, 2), (21, 6), (20, 17), (12, 22), (4, 17), (3, 6)], fill=K)
    d.polygon([(12, 4), (19, 7), (18, 16), (12, 20), (6, 16), (5, 7)], fill=(32, 66, 65, 255))
    d.polygon([(12, 5), (18, 8), (17, 15), (12, 18), (7, 15), (6, 8)], outline=T)
    # Lantern inside.
    rect(d, 10, 9, 15, 16, K)
    rect(d, 11, 10, 14, 15, G)
    rect(d, 12, 11, 13, 14, D)
    d.point((12, 12), fill=A)
    d.point((13, 12), fill=a)
    d.point((12, 14), fill=B)
    d.point((12, 7), fill=K)
    d.point((12, 8), fill=G)
    return image


def rain():
    image, d = canvas()
    # Root canopy / cloud, then three light-drops.
    d.arc([2, 1, 22, 14], 180, 360, fill=D, width=4)
    d.arc([3, 2, 21, 13], 180, 360, fill=T, width=2)
    d.line([(4, 7), (20, 7)], fill=K, width=1)
    for x, y in ((7, 10), (12, 8), (17, 11)):
        d.line([(x, y), (x - 2, y + 5)], fill=K, width=3)
        d.line([(x, y), (x - 2, y + 4)], fill=t, width=1)
        d.point((x - 1, y + 2), fill=W)
        d.point((x - 2, y + 6), fill=T)
    # Ground ripple.
    d.arc([4, 16, 20, 22], 200, 340, fill=T, width=1)
    d.point((9, 19), fill=t)
    d.point((15, 19), fill=t)
    return image


def dodge():
    image, d = canvas()
    # Boot silhouette with three speed cuts.
    d.polygon([(9, 3), (13, 3), (14, 11), (19, 14), (20, 20), (6, 20), (7, 12)], fill=K)
    d.polygon([(10, 4), (12, 4), (13, 11), (18, 14), (19, 19), (7, 19), (8, 12)], fill=B)
    d.polygon([(10, 5), (11, 5), (12, 12), (17, 15), (18, 17), (8, 18), (9, 12)], fill=G)
    d.line([(8, 18), (17, 18)], fill=H)
    d.point((10, 7), fill=H)
    for y in (6, 11, 16):
        d.line([(1, y), (6, y - 2)], fill=T, width=1)
    d.point((2, 8), fill=t)
    d.point((2, 14), fill=t)
    return image


def potion():
    image, d = canvas(16, 22)
    # Cork, neck, round bottle.
    rect(d, 6, 1, 10, 3, K)
    rect(d, 7, 2, 9, 3, B)
    rect(d, 6, 4, 10, 7, K)
    rect(d, 7, 4, 9, 7, (58, 86, 76, 255))
    d.ellipse([2, 6, 13, 20], fill=K)
    d.ellipse([3, 7, 12, 19], fill=(43, 59, 55, 255))
    d.ellipse([4, 11, 11, 18], fill=A)
    d.ellipse([5, 12, 10, 17], fill=a)
    d.point((5, 9), fill=(99, 143, 126, 255))
    d.point((6, 8), fill=(173, 215, 188, 255))
    d.point((10, 13), fill=A)
    d.line([(4, 16), (11, 16)], fill=G)
    d.point((5, 18), fill=B)
    return image


def potion_empty():
    image, d = canvas(16, 22)
    rect(d, 6, 1, 10, 3, K)
    rect(d, 7, 2, 9, 3, B)
    rect(d, 6, 4, 10, 7, K)
    rect(d, 7, 4, 9, 7, (58, 86, 76, 255))
    d.ellipse([2, 6, 13, 20], fill=K)
    d.ellipse([3, 7, 12, 19], fill=(38, 49, 47, 255))
    d.arc([4, 10, 11, 18], 20, 160, fill=(88, 103, 96, 255), width=1)
    d.point((5, 9), fill=(80, 99, 94, 255))
    d.point((6, 8), fill=(111, 133, 124, 255))
    return image


def main():
    save(melee(), "icon_melee.png")
    save(light(), "icon_light.png")
    save(shield(), "icon_shield.png")
    save(rain(), "icon_rain.png")
    save(dodge(), "icon_dodge.png")
    save(potion(), "icon_potion.png")
    save(potion_empty(), "icon_potion_empty.png")


if __name__ == "__main__":
    main()
