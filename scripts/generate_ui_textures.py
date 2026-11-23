"""
generate_ui_textures.py
Generates polished, pixel-perfect, 4x SSAA anti-aliased 2D UI sprite images for Planet Painters.
Based on the reference UI kit design system (white porcelain cards with thick dark borders,
overhanging dark ribbons, close buttons, dark action tiles, and crisp drop shadows).
"""

import os
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "resources", "ui")
os.makedirs(OUTPUT_DIR, exist_ok=True)

SCALE = 4  # 4x Supersampling for clean anti-aliasing

def create_card_panel(name="panel_card.png", size=(128, 128), radius=14, border_w=3.5, shadow_h=6):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = radius * SCALE
    bw = int(border_w * SCALE)
    sh = int(shadow_h * SCALE)
    pad = int(4 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    x0, y0 = pad, pad
    x1, y1 = w - pad - 1, h - pad - sh - 1

    # Drop shadow
    shadow_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_img)
    s_draw.rounded_rectangle([x0, y0 + sh, x1, y1 + sh], radius=r, fill=(14, 18, 27, 110))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=SCALE * 1.5))
    img.paste(shadow_img, (0, 0), shadow_img)

    # Dark outer border
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=(31, 36, 50, 255))

    # White card body
    in_box = [x0 + bw, y0 + bw, x1 - bw, y1 - bw]
    in_r = max(1, r - bw)
    draw.rounded_rectangle(in_box, radius=in_r, fill=(246, 248, 250, 255))

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def create_dock_bar(name="dock_bar.png", size=(128, 96), radius=10, border_w=3.0, shadow_h=5):
    create_card_panel(name=name, size=size, radius=radius, border_w=border_w, shadow_h=shadow_h)

def create_header_ribbon(name="header_ribbon.png", size=(128, 48), radius=8, border_w=2.0, shadow_h=4):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = radius * SCALE
    bw = int(border_w * SCALE)
    sh = int(shadow_h * SCALE)
    pad = int(4 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    x0, y0 = pad, pad
    x1, y1 = w - pad - 1, h - pad - sh - 1

    # Shadow
    shadow_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_img)
    s_draw.rounded_rectangle([x0, y0 + sh, x1, y1 + sh], radius=r, fill=(12, 16, 24, 130))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=SCALE))
    img.paste(shadow_img, (0, 0), shadow_img)

    # Outer border
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=(20, 24, 34, 255))

    # Body fill (dark navy)
    in_box = [x0 + bw, y0 + bw, x1 - bw, y1 - bw]
    in_r = max(1, r - bw)
    draw.rounded_rectangle(in_box, radius=in_r, fill=(31, 36, 50, 255))

    # Top bevel highlight line
    hl_y = y0 + bw + int(1 * SCALE)
    draw.rounded_rectangle([x0 + bw + int(2 * SCALE), hl_y, x1 - bw - int(2 * SCALE), hl_y + int(1.5 * SCALE)],
                           radius=int(1 * SCALE), fill=(56, 66, 90, 255))

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def create_close_button(name="btn_close.png", hover=False, pressed=False, size=(48, 48)):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = int(6 * SCALE)
    bw = int(2.0 * SCALE)
    sh = 0 if pressed else int(3 * SCALE)
    pad = int(4 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    y_off = int(2 * SCALE) if pressed else 0
    x0, y0 = pad, pad + y_off
    x1, y1 = w - pad - 1, h - pad - (0 if pressed else sh) - 1 + y_off

    # Shadow
    if not pressed:
        shadow_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(shadow_img)
        s_draw.rounded_rectangle([x0, y0 + sh, x1, y1 + sh], radius=r, fill=(12, 15, 22, 120))
        shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=SCALE * 0.8))
        img.paste(shadow_img, (0, 0), shadow_img)

    if hover:
        border_col = (180, 40, 40, 255)
        body_col = (226, 68, 68, 255)
        top_hl = (250, 115, 115, 255)
    elif pressed:
        border_col = (16, 20, 28, 255)
        body_col = (22, 26, 36, 255)
        top_hl = (30, 36, 50, 255)
    else:
        border_col = (20, 24, 34, 255)
        body_col = (31, 36, 50, 255)
        top_hl = (56, 66, 90, 255)

    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=border_col)
    in_box = [x0 + bw, y0 + bw, x1 - bw, y1 - bw]
    draw.rounded_rectangle(in_box, radius=max(1, r - bw), fill=body_col)

    if not pressed:
        draw.line([(x0 + bw + int(2 * SCALE), y0 + bw + int(1 * SCALE)),
                   (x1 - bw - int(2 * SCALE), y0 + bw + int(1 * SCALE))],
                  fill=top_hl, width=int(1.5 * SCALE))

    # White "X" cross
    cx = (x0 + x1) // 2
    cy = (y0 + y1) // 2
    arm = int(8 * SCALE)
    lw = int(3.5 * SCALE)
    draw.line([(cx - arm, cy - arm), (cx + arm, cy + arm)], fill=(255, 255, 255, 255), width=lw)
    draw.line([(cx + arm, cy - arm), (cx - arm, cy + arm)], fill=(255, 255, 255, 255), width=lw)

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def create_button(name="btn_dark.png", state="normal", active=False, size=(64, 48)):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = int(5 * SCALE)
    bw = int(2.5 * SCALE) if active else int(1.8 * SCALE)
    sh = 0 if state == "pressed" else int(3 * SCALE)
    pad = int(3 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    y_off = int(2 * SCALE) if state == "pressed" else 0
    x0, y0 = pad, pad + y_off
    x1, y1 = w - pad - 1, h - pad - (0 if state == "pressed" else sh) - 1 + y_off

    # Shadow
    if state != "pressed":
        shadow_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(shadow_img)
        s_draw.rounded_rectangle([x0, y0 + sh, x1, y1 + sh], radius=r, fill=(12, 16, 24, 120))
        shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=SCALE * 0.7))
        img.paste(shadow_img, (0, 0), shadow_img)

    if active:
        border_col = (59, 130, 246, 255)
        body_col = (38, 48, 70, 255)
        top_hl = (90, 160, 255, 255)
    elif state == "hover":
        border_col = (45, 58, 82, 255)
        body_col = (46, 56, 78, 255)
        top_hl = (76, 92, 126, 255)
    elif state == "pressed":
        border_col = (18, 22, 32, 255)
        body_col = (20, 24, 34, 255)
        top_hl = (28, 34, 48, 255)
    else:
        border_col = (22, 26, 36, 255)
        body_col = (34, 40, 56, 255)
        top_hl = (58, 68, 94, 255)

    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=border_col)
    in_box = [x0 + bw, y0 + bw, x1 - bw, y1 - bw]
    draw.rounded_rectangle(in_box, radius=max(1, r - bw), fill=body_col)

    if state != "pressed":
        draw.line([(x0 + bw + int(2 * SCALE), y0 + bw + int(1 * SCALE)),
                   (x1 - bw - int(2 * SCALE), y0 + bw + int(1 * SCALE))],
                  fill=top_hl, width=int(1.5 * SCALE))

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def create_input_field(name="input_field.png", size=(64, 40)):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = int(5 * SCALE)
    bw = int(1.8 * SCALE)
    pad = int(2 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    x0, y0 = pad, pad
    x1, y1 = w - pad - 1, h - pad - 1

    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=(31, 36, 50, 255))
    draw.rounded_rectangle([x0 + bw, y0 + bw, x1 - bw, y1 - bw], radius=max(1, r - bw), fill=(255, 255, 255, 255))

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def create_badge(name="badge_dark.png", size=(64, 32)):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = int(5 * SCALE)
    pad = int(2 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle([pad, pad, w - pad - 1, h - pad - 1], radius=r, fill=(31, 36, 50, 255))

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def create_slider_track(name="slider_track.png", size=(48, 14)):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = int(5 * SCALE)
    bw = int(1.5 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=(31, 36, 50, 255))
    draw.rounded_rectangle([bw, bw, w - 1 - bw, h - 1 - bw], radius=max(1, r - bw), fill=(18, 22, 32, 255))

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def create_slider_grabber(name="slider_grabber.png", hover=False, size=(24, 24)):
    w, h = size[0] * SCALE, size[1] * SCALE
    r = w // 2
    bw = int(2.0 * SCALE)
    sh = int(2 * SCALE)
    pad = int(2 * SCALE)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    x0, y0 = pad, pad
    x1, y1 = w - pad - 1, h - pad - sh - 1

    # Shadow
    s_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(s_img)
    s_draw.ellipse([x0, y0 + sh, x1, y1 + sh], fill=(12, 16, 24, 120))
    s_img = s_img.filter(ImageFilter.GaussianBlur(radius=SCALE * 0.6))
    img.paste(s_img, (0, 0), s_img)

    border_col = (45, 60, 90, 255) if hover else (22, 26, 36, 255)
    body_col = (56, 70, 100, 255) if hover else (38, 46, 66, 255)

    draw.ellipse([x0, y0, x1, y1], fill=border_col)
    draw.ellipse([x0 + bw, y0 + bw, x1 - bw, y1 - bw], fill=body_col)

    # Highlight dot
    dot_r = int(2.5 * SCALE)
    cx = (x0 + x1) // 2
    cy = (y0 + y1) // 2
    draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=(255, 255, 255, 220))

    res = img.resize(size, Image.Resampling.LANCZOS)
    res.save(os.path.join(OUTPUT_DIR, name), "PNG")
    print(f"Created {name}")

def main():
    print("Generating UI textures...")
    create_card_panel("panel_card.png", size=(128, 128), radius=14, border_w=3.5, shadow_h=6)
    create_dock_bar("dock_bar.png", size=(128, 96), radius=10, border_w=3.0, shadow_h=5)
    create_header_ribbon("header_ribbon.png", size=(128, 48), radius=8, border_w=2.0, shadow_h=4)

    # Close buttons
    create_close_button("btn_close.png", hover=False, pressed=False)
    create_close_button("btn_close_hover.png", hover=True, pressed=False)
    create_close_button("btn_close_pressed.png", hover=False, pressed=True)

    # Action / Tool Buttons
    create_button("btn_dark.png", state="normal", active=False)
    create_button("btn_dark_hover.png", state="hover", active=False)
    create_button("btn_dark_pressed.png", state="pressed", active=False)
    create_button("btn_dark_active.png", state="normal", active=True)

    # Input and badge
    create_input_field("input_field.png")
    create_badge("badge_dark.png")

    # Slider elements
    create_slider_track("slider_track.png")
    create_slider_grabber("slider_grabber.png", hover=False)
    create_slider_grabber("slider_grabber_hover.png", hover=True)

    print("All UI textures generated successfully in resources/ui/!")

if __name__ == "__main__":
    main()
