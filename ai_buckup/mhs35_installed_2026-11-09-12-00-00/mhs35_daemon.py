#!/usr/bin/env python3
# 小屏常驻渲染器: 循环 采集->渲染->写屏, 周期=参数(秒); 单实例锁避免开机自启与手动启动打架
# 用法: python3 mhs35_daemon.py [周期秒]   Ctrl-C/终止 -> 清屏退出
import os, sys, time, signal, fcntl
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mhs35_info as INFO
from PIL import Image, ImageDraw, ImageFont
import numpy as np

W, H = 480, 320
FB = os.environ.get("FB_DEV", "/dev/fb1")
LOCK = os.path.expanduser("~/.cache/mhs35/daemon.lock")
FONT_CJK = "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"
FONT_LAT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
f_cjk = ImageFont.truetype(FONT_CJK, 18)
f_lat = ImageFont.truetype(FONT_LAT, 18)

def is_cjk(ch):
    o = ord(ch)
    return 0x2E80 <= o <= 0x9FFF or 0xFF00 <= o <= 0xFFEF or 0x3000 <= o <= 0x303F

def render(text, size=18):
    img = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(img)
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
            d.text((x, y), ch, font=f, fill=(255, 255, 255))
            x += w
        y += lh
        if y > H - size:
            break
    return img

def to565(img):
    a = np.frombuffer(img.tobytes(), dtype=np.uint8).reshape(H, W, 3)
    v = ((a[:,:,0].astype("uint16") >> 3) << 11) | ((a[:,:,1].astype("uint16") >> 2) << 5) | (a[:,:,2].astype("uint16") >> 3)
    return v.astype("<u2").tobytes()

def write(raw):
    with open(FB, "wb") as fh:
        fh.write(raw)

def fill_black():
    write(np.full(H*W, 0, dtype="<u2").tobytes())

LOCKFH = None  # 必须持有句柄: 句柄被回收=锁自动释放(之前的bug)
def acquire():
    os.makedirs(os.path.dirname(LOCK), exist_ok=True)
    fh = open(LOCK, "w")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("已有小屏渲染器在运行, 本实例退出")
        sys.exit(0)
    fh.write(str(os.getpid()))
    fh.write(str(os.getpid()))
    fh.flush()
    global LOCKFH
    LOCKFH = fh  # 保存句柄, 进程存活期间锁不释放
    return fh

def main():
    period = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(0))
    acquire()
    print("小屏常驻渲染器启动, 目标周期", period, "秒")
    try:
        while True:
            t0 = time.time()
            text = INFO.fallback()
            write(to565(render(text)))
            left = period - (time.time() - t0)
            if left > 0:
                time.sleep(left)
    finally:
        fill_black()
        print("小屏已清屏")

if __name__ == "__main__":
    main()

