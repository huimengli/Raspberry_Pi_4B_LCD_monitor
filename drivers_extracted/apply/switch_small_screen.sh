#!/bin/bash
# 小屏(SPI 480x320, /dev/fb1)内容切换工具。需 sudo 运行（写 /dev/fb1 要 root）。
# 用法:
#   sudo bash switch_small_screen.sh info [秒]      显示 getInfoCN.py 的输出(默认每2秒刷新)
#   sudo bash switch_small_screen.sh html <html文件|URL> [秒]   显示网页(截图到小屏)
#   sudo bash switch_small_screen.sh image <png> [秒]           显示图片
#   sudo bash switch_small_screen.sh fill <red|green|blue|black|white>   纯色测试
#   sudo bash switch_small_screen.sh stop           清屏(黑)，交还给控制台
#   sudo bash switch_small_screen.sh status         查看小屏状态
set -u
S=$(cd "$(dirname "$0")" && pwd)
DRAW="$S/fb1_draw.py"
FB=${FB_DEV:-/dev/fb1}
APP=${INFO_APP:-$HOME/getInfoCN.py}
U=${SUDO_USER:-$USER}
TMP="$S/../tmp"
mkdir -p "$TMP"

if [ ! -e "$FB" ]; then echo "没有 $FB，驱动未加载"; exit 1; fi

fill() { python3 "$DRAW" --fill "$1" --fb "$FB"; }

capture_once() {
  # 运行一次程序并抓取输出（对 打印->sleep 循环的程序有效）
  timeout 1 python3 "$APP" 2>/dev/null
}

trap 'fill black; echo "已清屏，交还控制台"; exit 0' INT

case "${1:-}" in
  info)
    N=${2:-2}
    [ -f "$APP" ] || { echo "找不到 $APP，用 INFO_APP=路径 指定"; exit 1; }
    echo "小屏显示 $APP 输出，每 $N 秒刷新。Ctrl-C 停止"
    while true; do
      capture_once > "$TMP/fb1_text.txt"
      python3 "$DRAW" --text "$TMP/fb1_text.txt" --size 18 --fb "$FB" >/dev/null
      sleep "$N"
    done
    ;;
  html)
    SRC=${2:-}
    N=${3:-5}
    [ -n "$SRC" ] || { echo '需要 html 文件或 URL'; exit 1; }
    case "$SRC" in http*|file*) URL="$SRC" ;; *) URL="file://$(readlink -f "$SRC")" ;; esac
    echo "小屏显示 $URL，每 $N 秒刷新。Ctrl-C 停止"
    while true; do
      sudo -u "$U" chromium --headless=new --disable-gpu --no-sandbox --window-size=480,320 --screenshot="$TMP/fb1_html.png" "$URL" 2>/dev/null
      [ -f "$TMP/fb1_html.png" ] && python3 "$DRAW" --image "$TMP/fb1_html.png" --fb "$FB" >/dev/null
      sleep "$N"
    done
    ;;
  image)
    SRC=${2:-}
    N=${3:-0}
    [ -f "$SRC" ] || { echo '需要图片路径'; exit 1; }
    python3 "$DRAW" --image "$SRC" --fb "$FB"
    [ "$N" != 0 ] && { echo "每 $N 秒刷新"; while true; do sleep "$N"; python3 "$DRAW" --image "$SRC" --fb "$FB" >/dev/null; done; }
    ;;
  fill)
    fill "${2:-black}"
    ;;
  stop)
    fill black
    ;;
  status)
    echo "fb1 name=$(cat /sys/class/graphics/fb1/name 2>/dev/null) bpp=$(cat /sys/class/graphics/fb1/bits_per_pixel 2>/dev/null)"
    ls -l "$FB"
    ;;
  *)
    sed -n '2,10p' "$0" | sed 's/^# //'
    ;;
esac

