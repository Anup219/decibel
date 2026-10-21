import math
from PIL import Image, ImageDraw

def render_decibel_icon(size=1024, with_bg=True, corner_radius_ratio=0.2246):
    # Scale factor for supersampling (4x for extreme antialiasing quality)
    scale = 4
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base design coordinates are 512x512
    s = canvas_size / 512.0

    # 1. Background
    if with_bg:
        rx = 115 * s if corner_radius_ratio is None else (512 * corner_radius_ratio * s)
        bg_color = (12, 12, 16, 255) # #0C0C10
        draw.rounded_rectangle([0, 0, canvas_size - 1, canvas_size - 1], radius=rx, fill=bg_color)

    # Transform: translate(256,256) scale(1.2) translate(-181,-140)
    # X' = (X - 181) * 1.2 + 256
    # Y' = (Y - 140) * 1.2 + 256
    def tx(x):
        return ((x - 181) * 1.2 + 256) * s

    def ty(y):
        return ((y - 140) * 1.2 + 256) * s

    def ts(dim):
        return dim * 1.2 * s

    # 2. Outer circle: cx=160, cy=150, r=62, stroke=12, color=#F2EFE9
    cx, cy = tx(160), ty(150)
    r_outer = ts(62)
    w_outer = ts(12)
    color_bone = (242, 239, 233, 255) # #F2EFE9
    draw.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], outline=color_bone, width=max(1, int(round(w_outer))))

    # 3. Middle circle: cx=160, cy=150, r=36, stroke=6, color=#FF6B4A
    r_mid = ts(36)
    w_mid = ts(6)
    color_coral = (255, 107, 74, 255) # #FF6B4A
    draw.ellipse([cx - r_mid, cy - r_mid, cx + r_mid, cy + r_mid], outline=color_coral, width=max(1, int(round(w_mid))))

    # 4. Inner circle (dot): cx=160, cy=150, r=11, filled, color=#FF6B4A
    r_dot = ts(11)
    draw.ellipse([cx - r_dot, cy - r_dot, cx + r_dot, cy + r_dot], fill=color_coral)

    # 5. Stem: rect x=216, y=62, w=20, h=156, rx=10, fill=#F2EFE9
    sx = tx(216)
    sy = ty(62)
    sw = ts(20)
    sh = ts(156)
    srx = ts(10)
    draw.rounded_rectangle([sx, sy, sx + sw, sy + sh], radius=srx, fill=color_bone)

    # 6. Ticks at x=250:
    # tick0: y=77, w=22, h=6, rx=3, color=#FF6B4A, alpha=1.0
    # tick1: y=103, w=14, h=6, rx=3, color=#FF6B4A, alpha=1.0
    # tick2: y=129, w=22, h=6, rx=3, color=#F2EFE9, alpha=0.55
    # tick3: y=155, w=14, h=6, rx=3, color=#F2EFE9, alpha=0.40
    # tick4: y=181, w=22, h=6, rx=3, color=#F2EFE9, alpha=0.25
    ticks = [
        (77, 22, 6, 3, color_coral, 1.0),
        (103, 14, 6, 3, color_coral, 1.0),
        (129, 22, 6, 3, color_bone, 0.55),
        (155, 14, 6, 3, color_bone, 0.40),
        (181, 22, 6, 3, color_bone, 0.25),
    ]

    for y, w, h, rx, col, alpha in ticks:
        tx_pos = tx(250)
        ty_pos = ty(y)
        tw = ts(w)
        th = ts(h)
        trx = ts(rx)
        c = (col[0], col[1], col[2], int(round(col[3] * alpha)))
        
        # Draw on a transparent overlay to correctly blend alpha
        tick_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        tick_draw = ImageDraw.Draw(tick_layer)
        tick_draw.rounded_rectangle([tx_pos, ty_pos, tx_pos + tw, ty_pos + th], radius=trx, fill=c)
        img = Image.alpha_composite(img, tick_layer)

    # Downsample using high quality Lanczos filter
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

if __name__ == '__main__':
    # 1. Main 1024x1024 and 512x512 app icon
    icon1024 = render_decibel_icon(1024, with_bg=True)
    icon1024.save("assets/app_icon.png", "PNG")
    print("Saved assets/app_icon.png")

    # Android mipmap densities:
    densities = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    import os
    for folder, px in densities.items():
        dirpath = f"android/app/src/main/res/{folder}"
        os.makedirs(dirpath, exist_ok=True)
        
        # Standard launcher icon
        ico = render_decibel_icon(px, with_bg=True)
        ico.save(f"{dirpath}/ic_launcher.png", "PNG")
        
        # Round launcher icon
        ico_round = render_decibel_icon(px, with_bg=True, corner_radius_ratio=0.5)
        ico_round.save(f"{dirpath}/ic_launcher_round.png", "PNG")
        print(f"Saved {dirpath}/ic_launcher.png and ic_launcher_round.png ({px}x{px})")

    # Adaptive icons for Android 8.0+ (res/mipmap-anydpi-v26)
    # Foreground size in adaptive icon is typically 432x432 (safe zone 264x264 centered)
    # Foreground centered with transparency:
    for folder, px in densities.items():
        # Adaptive icon foreground (centered logo mark scaled to fit 66% safe zone)
        # 108dp * density: mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432
        dp_ratio = px / 48.0
        adaptive_px = int(round(108 * dp_ratio))
        fg_icon = render_decibel_icon(int(round(adaptive_px * 0.72)), with_bg=False)
        
        # Place centered in adaptive canvas
        fg_canvas = Image.new("RGBA", (adaptive_px, adaptive_px), (0, 0, 0, 0))
        offset = (adaptive_px - fg_icon.width) // 2
        fg_canvas.paste(fg_icon, (offset, offset), fg_icon)
        
        dirpath = f"android/app/src/main/res/{folder}"
        fg_canvas.save(f"{dirpath}/ic_launcher_foreground.png", "PNG")

    print("All icons successfully generated!")
