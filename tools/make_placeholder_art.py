#!/usr/bin/env python3
"""Draw the placeholder 16x16 tile sheet (assets/placeholder_tiles.png).

The real art is Kenney's Tiny Dungeon sheet. Sprite names and their cells live
in ui/sprites.gd, so switching sheets means changing that one file.
Run: python3 tools/make_placeholder_art.py
"""
from PIL import Image, ImageDraw
import os

T = 16
COLS = 8
NAMES = [
    "floor", "wall", "stairs", "shrine", "floor_alt", "wall_top", "door", "bones",
    "guard", "cutpurse", "adept", "rat", "bat", "slime", "goblin", "archer",
    "spider", "orc", "wraith", "cultist", "golem", "shade", "mimic", "warden",
    "potion", "scroll", "weapon", "armor", "food", "oil", "bomb", "smoke",
]

def px(d, pts, c):
    for x, y in pts:
        d.point((x, y), fill=c)

def humanoid(d, body, head=(236, 200, 160), extra=None):
    d.rectangle([6, 2, 9, 5], fill=head)              # head
    d.rectangle([5, 6, 10, 11], fill=body)            # torso
    d.rectangle([5, 12, 6, 14], fill=(60, 50, 50))    # legs
    d.rectangle([9, 12, 10, 14], fill=(60, 50, 50))
    d.point((7, 3), fill=(20, 20, 20)); d.point((8, 3), fill=(20, 20, 20))
    if extra:
        extra(d)

def draw(name, d):
    if name == "floor":
        d.rectangle([0, 0, 15, 15], fill=(74, 63, 58))
        px(d, [(3, 4), (11, 9), (6, 13), (13, 2)], (88, 76, 70))
    elif name == "floor_alt":
        d.rectangle([0, 0, 15, 15], fill=(70, 60, 56))
        px(d, [(2, 10), (9, 3), (12, 12)], (86, 74, 68))
    elif name in ("wall", "wall_top"):
        d.rectangle([0, 0, 15, 15], fill=(52, 48, 62))
        for y in (0, 5, 10):
            d.line([0, y, 15, y], fill=(36, 33, 44))
        for y, off in ((0, 0), (5, 4), (10, 0)):
            for x in range(off, 16, 8):
                d.line([x, y, x, y + 4], fill=(36, 33, 44))
        if name == "wall_top":
            d.rectangle([0, 0, 15, 2], fill=(90, 84, 104))
    elif name == "stairs":
        d.rectangle([0, 0, 15, 15], fill=(74, 63, 58))
        for i, y in enumerate(range(3, 14, 3)):
            d.rectangle([2 + i, y, 13 - i, y + 1], fill=(150, 140, 120))
        d.rectangle([5, 13, 10, 15], fill=(10, 8, 8))
    elif name == "shrine":
        d.rectangle([0, 0, 15, 15], fill=(74, 63, 58))
        d.rectangle([4, 9, 11, 14], fill=(170, 170, 190))
        d.ellipse([5, 2, 10, 8], fill=(120, 200, 255))
    elif name == "door":
        d.rectangle([2, 0, 13, 15], fill=(120, 80, 40))
    elif name == "bones":
        d.line([3, 12, 12, 9], fill=(220, 220, 200))
    elif name == "guard":
        humanoid(d, (70, 110, 200), extra=lambda d: (d.rectangle([11, 6, 13, 11], fill=(180, 180, 190)),
                                                    d.line([3, 3, 3, 11], fill=(220, 220, 230))))
    elif name == "cutpurse":
        humanoid(d, (60, 130, 70), head=(80, 70, 60))
        d.line([12, 7, 14, 5], fill=(220, 220, 230))
    elif name == "adept":
        humanoid(d, (170, 60, 50))
        d.line([12, 2, 12, 14], fill=(140, 100, 60)); d.point((12, 1), fill=(255, 160, 40))
    elif name == "rat":
        d.ellipse([3, 8, 11, 13], fill=(130, 110, 100)); d.line([11, 11, 15, 12], fill=(200, 150, 150))
        d.point((5, 10), fill=(255, 40, 40))
    elif name == "bat":
        d.polygon([(1, 5), (7, 8), (8, 8), (14, 5), (12, 10), (3, 10)], fill=(90, 70, 110))
        px(d, [(6, 8), (9, 8)], (255, 220, 40))
    elif name == "slime":
        d.ellipse([2, 6, 13, 14], fill=(90, 200, 90)); px(d, [(5, 9), (9, 9)], (20, 60, 20))
    elif name == "goblin":
        humanoid(d, (120, 90, 50), head=(110, 170, 70))
    elif name == "archer":
        humanoid(d, (200, 200, 190), head=(230, 230, 220))
        d.arc([10, 3, 15, 13], 270, 90, fill=(140, 100, 60))
    elif name == "spider":
        d.ellipse([5, 6, 10, 11], fill=(40, 30, 40))
        for y in (5, 8, 11):
            d.line([1, y, 14, y + 1], fill=(40, 30, 40))
        px(d, [(6, 7), (9, 7)], (255, 40, 40))
    elif name == "orc":
        d.rectangle([4, 1, 11, 6], fill=(80, 140, 60)); d.rectangle([3, 7, 12, 12], fill=(100, 70, 50))
        d.rectangle([4, 13, 6, 15], fill=(60, 50, 50)); d.rectangle([9, 13, 11, 15], fill=(60, 50, 50))
        px(d, [(5, 6), (10, 6)], (240, 240, 220))
    elif name == "wraith":
        d.polygon([(8, 1), (13, 6), (12, 15), (8, 12), (4, 15), (3, 6)], fill=(160, 170, 220))
        px(d, [(6, 5), (10, 5)], (20, 20, 60))
    elif name == "cultist":
        d.polygon([(8, 1), (12, 6), (13, 15), (3, 15), (4, 6)], fill=(110, 30, 120))
        d.rectangle([6, 4, 9, 6], fill=(20, 0, 20)); px(d, [(7, 5), (8, 5)], (255, 80, 80))
    elif name == "golem":
        d.rectangle([3, 2, 12, 13], fill=(120, 115, 110)); d.rectangle([1, 5, 2, 11], fill=(120, 115, 110))
        d.rectangle([13, 5, 14, 11], fill=(120, 115, 110)); px(d, [(6, 5), (9, 5)], (120, 220, 255))
    elif name == "shade":
        d.ellipse([3, 2, 12, 15], fill=(25, 20, 35)); px(d, [(6, 6), (9, 6)], (240, 240, 255))
    elif name == "mimic":
        d.rectangle([2, 6, 13, 13], fill=(150, 100, 40)); d.rectangle([2, 4, 13, 7], fill=(170, 120, 50))
        px(d, [(4, 8), (6, 8), (8, 8), (10, 8)], (240, 240, 230))
    elif name == "warden":
        d.rectangle([3, 1, 12, 5], fill=(200, 170, 60)); d.rectangle([2, 6, 13, 13], fill=(60, 60, 80))
        d.rectangle([3, 14, 5, 15], fill=(40, 40, 50)); d.rectangle([10, 14, 12, 15], fill=(40, 40, 50))
        px(d, [(6, 3), (9, 3)], (255, 60, 30))
    elif name == "potion":
        d.rectangle([7, 2, 8, 5], fill=(200, 200, 220)); d.ellipse([4, 5, 11, 13], fill=(220, 60, 120))
    elif name == "scroll":
        d.rectangle([3, 4, 12, 11], fill=(230, 220, 180)); d.line([5, 6, 10, 6], fill=(120, 100, 80))
        d.line([5, 8, 10, 8], fill=(120, 100, 80))
    elif name == "weapon":
        d.line([3, 12, 12, 3], fill=(220, 220, 235), width=2); d.line([3, 9, 6, 12], fill=(140, 100, 60), width=2)
    elif name == "armor":
        d.polygon([(3, 3), (12, 3), (12, 10), (8, 14), (3, 10)], fill=(150, 150, 165))
    elif name == "food":
        d.ellipse([3, 6, 12, 12], fill=(190, 120, 70)); d.line([6, 8, 10, 8], fill=(230, 180, 120))
    elif name == "oil":
        d.rectangle([5, 4, 10, 13], fill=(230, 170, 40)); d.rectangle([6, 2, 9, 3], fill=(120, 90, 50))
    elif name == "bomb":
        d.ellipse([3, 5, 12, 14], fill=(40, 40, 50)); d.line([9, 5, 12, 2], fill=(200, 150, 80))
        d.point((12, 1), fill=(255, 200, 40))
    elif name == "smoke":
        d.ellipse([3, 5, 12, 14], fill=(140, 140, 150)); d.ellipse([6, 2, 13, 9], fill=(170, 170, 180))

def main():
    rows = (len(NAMES) + COLS - 1) // COLS
    img = Image.new("RGBA", (COLS * T, rows * T), (0, 0, 0, 0))
    for i, n in enumerate(NAMES):
        tile = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        draw(n, ImageDraw.Draw(tile))
        img.paste(tile, ((i % COLS) * T, (i // COLS) * T))
    root = os.path.join(os.path.dirname(__file__), "..")
    img.save(os.path.join(root, "assets", "placeholder_tiles.png"))
    print("wrote", len(NAMES), "sprites")

if __name__ == "__main__":
    main()
