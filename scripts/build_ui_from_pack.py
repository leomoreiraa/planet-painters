"""
build_ui_from_pack.py
Extracts and generates pixel-perfect UI textures directly from:
- resources/Images/UI assets pack 2/UI books & more.png
- resources/Images/UI assets pack 2/UI cooking.png

Features:
- Fundo mais de madeira: authentic horizontal mahogany wood planks with wood grain and gold filigree brackets.
- Esse azul: deep royal slate blue buttons with raised 3D pixel bevel, gold rims, and distinct tactile feedback.
- Recessed slots and gold-rimmed sliders.
"""
import os
from PIL import Image, ImageEnhance

BOOKS_PATH = r"resources/Images/UI assets pack 2/UI books & more.png"
COOKING_PATH = r"resources/Images/UI assets pack 2/UI cooking.png"
OUTPUT_DIR = r"resources/ui"
os.makedirs(OUTPUT_DIR, exist_ok=True)

books = Image.open(BOOKS_PATH).convert("RGBA")
cooking = Image.open(COOKING_PATH).convert("RGBA")

print("Opened pack images successfully.")

# 1. Base card & Dock bar: (96x96) -> rich mahogany wood planks + gold filigree corner brackets
w, h = 96, 96
wood_card = Image.new("RGBA", (w, h), (0, 0, 0, 0))

w_seam = (38, 22, 14, 255)       # dark seam between planks
w_shadow = (58, 34, 22, 255)     # bottom shadow of plank
w_grain = (78, 48, 32, 255)      # fine grain lines
w_base = (98, 62, 42, 255)       # rich mahogany base
w_mid = (118, 76, 52, 255)      # warm wood mid-tone
w_hi = (142, 94, 66, 255)        # top highlight bevel of plank

for y in range(4, h - 4):
    for x in range(4, w - 4):
        # 3 horizontal planks of 29px each (seamless horizontal tiling)
        py = (y - 4) % 29
        if py == 0:
            c = w_seam
        elif py == 1:
            c = w_hi
        elif py == 2:
            c = w_mid
        elif py == 28:
            c = w_shadow
        else:
            wave = int(2.0 * ((x % 32) / 32.0))
            gy = (y + wave) % 7
            if gy == 0:
                c = w_grain
            elif gy == 1:
                c = w_mid
            elif ((x * 11 + y * 17) % 31 == 0):
                c = w_grain
            else:
                c = w_base
        wood_card.putpixel((x, y), c)

# Ornate gold brackets from card_grey_gold (768, 16, 816, 64)
gold_src = books.crop((768, 16, 816, 64)).resize((96, 96), Image.NEAREST)
for y in range(h):
    for x in range(w):
        cg = gold_src.getpixel((x, y))
        if cg[3] > 0 and not (cg[0] == 213 and cg[1] == 214 and cg[2] == 219):
            wood_card.putpixel((x, y), cg)

wood_card.save(os.path.join(OUTPUT_DIR, "dock_bar.png"))
wood_card.save(os.path.join(OUTPUT_DIR, "panel_card.png"))
print("Saved dock_bar.png and panel_card.png (rich mahogany wood + gold)")

# 2. Action buttons: 'esse azul' with 3D bevel & gold rim (48x48)
def make_blue_btn(state='normal'):
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    if state == 'normal':
        bg = (56, 75, 105, 255)      # 'esse azul' core
        hi = (96, 126, 172, 255)     # raised bevel highlight
        sh = (30, 42, 60, 255)       # raised bevel shadow
        rim_dark = (120, 85, 45, 255)
        rim_mid = (195, 145, 60, 255)
        rim_light = (245, 195, 95, 255)
        stud = (255, 220, 130, 255)
    elif state == 'hover':
        bg = (76, 102, 142, 255)
        hi = (128, 162, 218, 255)
        sh = (44, 60, 84, 255)
        rim_dark = (150, 105, 55, 255)
        rim_mid = (225, 170, 75, 255)
        rim_light = (255, 225, 125, 255)
        stud = (255, 245, 175, 255)
    elif state == 'pressed':
        bg = (40, 54, 76, 255)
        hi = (24, 34, 50, 255)       # inverted: top is shadow
        sh = (78, 104, 144, 255)     # inverted: bottom is highlight
        rim_dark = (95, 68, 36, 255)
        rim_mid = (165, 120, 50, 255)
        rim_light = (210, 160, 70, 255)
        stud = (215, 170, 90, 255)
    elif state == 'active':
        bg = (52, 92, 150, 255)      # radiant royal blue
        hi = (130, 185, 255, 255)
        sh = (28, 52, 90, 255)
        rim_dark = (185, 130, 40, 255)
        rim_mid = (245, 190, 65, 255)
        rim_light = (255, 235, 120, 255)
        stud = (255, 255, 190, 255)

    for y in range(48):
        for x in range(48):
            if (x == 0 or x == 47) and (y == 0 or y == 47):
                continue
            if (x <= 1 or x >= 46) and (y <= 1 or y >= 46):
                im.putpixel((x, y), stud)
                continue
            if x <= 2 or x >= 45 or y <= 2 or y >= 45:
                if y <= 1 or x <= 1:
                    im.putpixel((x, y), rim_light)
                elif y >= 46 or x >= 46:
                    im.putpixel((x, y), rim_dark)
                else:
                    im.putpixel((x, y), rim_mid)
                continue
            if x <= 4 or y <= 4:
                im.putpixel((x, y), hi)
            elif x >= 43 or y >= 43:
                im.putpixel((x, y), sh)
            else:
                im.putpixel((x, y), bg)
    return im

btn_norm = make_blue_btn('normal')
btn_hov = make_blue_btn('hover')
btn_press = make_blue_btn('pressed')
btn_act = make_blue_btn('active')

btn_norm.save(os.path.join(OUTPUT_DIR, "btn_dark.png"))
btn_hov.save(os.path.join(OUTPUT_DIR, "btn_dark_hover.png"))
btn_press.save(os.path.join(OUTPUT_DIR, "btn_dark_pressed.png"))
btn_act.save(os.path.join(OUTPUT_DIR, "btn_dark_active.png"))
print("Saved btn_dark states (48x48, blue + 3D bevel + gold rim)")

# 3. Close Button (48x48)
cross1_raw = books.crop((784, 208, 800, 224)) # 16x16
cross2_raw = books.crop((784, 224, 800, 240)) # 16x16 pressed

cross_white = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
for y in range(16):
    for x in range(16):
        r, g, b, a = cross1_raw.getpixel((x, y))
        if a > 0:
            if r > 100:
                cross_white.putpixel((x, y), (255, 255, 255, a))
            else:
                cross_white.putpixel((x, y), (15, 20, 30, a))

cross_white_hover = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
for y in range(16):
    for x in range(16):
        r, g, b, a = cross1_raw.getpixel((x, y))
        if a > 0:
            if r > 100:
                cross_white_hover.putpixel((x, y), (255, 130, 130, a))
            else:
                cross_white_hover.putpixel((x, y), (15, 20, 30, a))

cross_w24 = cross_white.resize((24, 24), Image.NEAREST)
cross_w24_hov = cross_white_hover.resize((24, 24), Image.NEAREST)
cross_w24_press = cross2_raw.resize((24, 24), Image.NEAREST)

btn_close = btn_norm.copy()
btn_close.paste(cross_w24, (12, 12), cross_w24)
btn_close.save(os.path.join(OUTPUT_DIR, "btn_close.png"))

btn_close_hov = btn_hov.copy()
btn_close_hov.paste(cross_w24_hov, (12, 12), cross_w24_hov)
btn_close_hov.save(os.path.join(OUTPUT_DIR, "btn_close_hover.png"))

btn_close_press = btn_press.copy()
btn_close_press.paste(cross_w24_press, (12, 13), cross_w24_press)
btn_close_press.save(os.path.join(OUTPUT_DIR, "btn_close_pressed.png"))
print("Saved btn_close states (48x48)")

# 4. Input Field: recessed blue-slate with gold rim (48x32)
inp = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
for y in range(32):
    for x in range(48):
        if (x == 0 or x == 47) and (y == 0 or y == 31):
            continue
        if x <= 1 or x >= 46 or y <= 1 or y >= 30:
            if y >= 30 or x >= 46:
                inp.putpixel((x, y), (210, 160, 70, 255))
            else:
                inp.putpixel((x, y), (110, 78, 40, 255))
        elif y <= 3:
            inp.putpixel((x, y), (20, 28, 42, 255))
        else:
            inp.putpixel((x, y), (30, 42, 60, 255))
inp.save(os.path.join(OUTPUT_DIR, "input_field.png"))
print("Saved input_field.png")

# 5. Slider Track: recessed blue-slate groove (48x12)
trk = Image.new("RGBA", (48, 12), (0, 0, 0, 0))
for y in range(12):
    for x in range(48):
        if (x == 0 or x == 47) and (y == 0 or y == 11):
            continue
        if x <= 1 or x >= 46 or y <= 1 or y >= 10:
            if y >= 10:
                trk.putpixel((x, y), (195, 145, 60, 255))
            else:
                trk.putpixel((x, y), (90, 60, 30, 255))
        elif y <= 3:
            trk.putpixel((x, y), (18, 24, 36, 255))
        else:
            trk.putpixel((x, y), (28, 38, 54, 255))
trk.save(os.path.join(OUTPUT_DIR, "slider_track.png"))
print("Saved slider_track.png")

# 6. Badges and Ribbons: blue ribbon with gold border (64x32)
ribbon_navy_raw = books.crop((224, 272, 256, 288))
ribbon_2x = ribbon_navy_raw.resize((64, 32), Image.NEAREST)
ribbon_2x.save(os.path.join(OUTPUT_DIR, "badge_dark.png"))
ribbon_2x.save(os.path.join(OUTPUT_DIR, "header_ribbon.png"))
print("Saved badge_dark.png and header_ribbon.png")
