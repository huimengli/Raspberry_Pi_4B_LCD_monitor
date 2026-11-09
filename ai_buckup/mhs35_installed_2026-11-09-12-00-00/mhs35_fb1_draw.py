#!/usr/bin/env python3
# 把文本 / 图片 / 纯色画到 SPI 小屏 /dev/fb1 (fb_ili9486, 480x320, RGB565)
# 用法:
#   sudo python3 fb1_draw.py --text file      渲染文本(UTF-8)到 fb1
#   sudo python3 fb1_draw.py --image x.png     图片缩放到 480x320 写 fb1
#   sudo python3 fb1_draw.py --fill red|green|blue|black|white
#   python3 fb1_draw.py --out preview.png --text file   离线预览(不写 fb1)
import sys, argparse
from PIL import Image, ImageDraw, ImageFont

W, H = 480, 320
FONT_CJK = "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"
FONT_LAT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
COLORS = {"red":(255,0,0), "green":(0,255,0), "blue":(0,0,255), "black":(0,0,0), "white":(255,255,255)}

def is_cjk(ch):
    o = ord(ch)
    return 0x2E80 <= o <= 0x9FFF or 0xFF00 <= o <= 0xFFEF or 0x3000 <= o <= 0x303F

def to_rgb565_raw(img):
    img = img.convert("RGB").resize((W, H))
    try:
        import numpy as np  # 向量转换约0.04秒(纯Python逐像素约0.6秒)
        a = np.frombuffer(img.tobytes(), dtype=np.uint8).reshape(H, W, 3)
        v = ((a[:,:,0].astype("uint16") >> 3) << 11) | ((a[:,:,1].astype("uint16") >> 2) << 5) | (a[:,:,2].astype("uint16") >> 3)
        return v.astype("<u2").tobytes()
    except ImportError:
        out = bytearray()
        for r, g, b in img.getdata():
            px = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
            out += px.to_bytes(2, "little")
        return bytes(out)
    img = img.convert("RGB").resize((W, H))
    out = bytearray()
    for r, g, b in img.getdata():
        px = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
        out += px.to_bytes(2, "little")
    return bytes(out)

def render_text(text, size=16, fg=(255,255,255), bg=(0,0,0)):
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    f_cjk = ImageFont.truetype(FONT_CJK, size)
    f_lat = ImageFont.truetype(FONT_LAT, size)
    lh = size + 4
    y = 6
    for line in text.split("\n"):
        x = 6
        for ch in line:
            f = f_cjk if is_cjk(ch) else f_lat
            w = d.textlength(ch, font=f)
            if x + w > W - 4:
                y += lh
                x = 6
                if y > H - size:
                    return img
            d.text((x, y), ch, font=f, fill=fg)
            x += w
        y += lh
        if y > H - size:
            break
    return img

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--text")
    ap.add_argument("--image")
    ap.add_argument("--fill")
    ap.add_argument("--size", type=int, default=16)
    ap.add_argument("--fb", default="/dev/fb1")
    ap.add_argument("--out")
    a = ap.parse_args()
    if a.fill:
        img = Image.new("RGB", (W, H), COLORS[a.fill])
    elif a.image:
        img = Image.open(a.image)
    elif a.text:
        img = render_text(open(a.text, encoding="utf-8").read(), a.size)
    else:
        print("需要 --text / --image / --fill"); sys.exit(1)
    if a.out:
        img.convert("RGB").resize((W, H)).save(a.out)
        print("预览已保存: " + a.out)
        return
    raw = to_rgb565_raw(img)
    with open(a.fb, "wb") as fh:
        fh.write(raw)
    print("已写入 " + a.fb)

if __name__ == "__main__":
    main()

