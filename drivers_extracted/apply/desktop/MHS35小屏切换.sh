#!/bin/bash
# MHS35 小屏(480x320, /dev/fb1) 内容切换 —— 桌面版，免 sudo(用户在 video 组，/dev/fb1 是 root:video 660)
# 命令行用法: bash MHS35小屏切换.sh [info|html|image|fill|stop|status]
#   info [秒]        显示 getInfoCN.py 输出(默认每2秒刷新)
#   html <文件或URL> [秒]  显示网页(chromium 截图写屏)
#   image <png>      显示图片
#   fill <red|green|blue|black|white>
#   stop            清屏(黑)，交还控制台
set -u
S=$(cd "$(dirname "$0")" && pwd)
DRAW="$S/mhs35_fb1_draw.py"
FB=${FB_DEV:-/dev/fb1}
APP=${INFO_APP:-$HOME/getInfoCN.py}
TMP="$HOME/.cache/mhs35"
mkdir -p "$TMP"

fill() { python3 "$DRAW" --fill "$1" --fb "$FB" >/dev/null; }

info_once() {
  # -u 关闭缓冲，保证被 timeout 杀之前输出已落盘
  timeout 3 python3 -u "$APP" 2>/dev/null > "$TMP/text.txt"
  [ -s "$TMP/text.txt" ] || echo "读取失败: 未捕获到 $APP 输出" > "$TMP/text.txt"
  python3 "$DRAW" --text "$TMP/text.txt" --size 18 --fb "$FB" >/dev/null
}

html_shot() {
  chromium --headless=new --disable-gpu --no-sandbox --window-size=480,320 --screenshot="$TMP/html.png" "$1" >/dev/null 2>&1
  [ -f "$TMP/html.png" ] && python3 "$DRAW" --image "$TMP/html.png" --fb "$FB" >/dev/null
}

# 清屏只在循环模式里挂 trap，避免 fill/status 模式退出时把画面刷黑

run_info() {
  [ -f "$APP" ] || { zenity --error --text="找不到 $APP"; exit 1; }
  N=${2:-2}
  trap 'fill black; echo "小屏已清屏"; exit 0' INT TERM EXIT
  echo "小屏显示 $APP，每 $N 秒刷新（关闭本窗口或 Ctrl-C 停止并清屏）"
  while true; do info_once; sleep "$N"; done
}

run_html() {
  SRC=${1:-}
  if [ -z "$SRC" ]; then
    SRC=$(zenity --title="小屏网页" --text="输入网页地址或本地 html 文件路径" --entry)
    [ -z "$SRC" ] && exit 0
  fi
  case "$SRC" in http*|file*) URL="$SRC" ;; *) URL="file://$(readlink -f "$SRC")" ;; esac
  N=${2:-5}
  trap 'fill black; echo "小屏已清屏"; exit 0' INT TERM EXIT
  echo "小屏显示 $URL，每 $N 秒刷新（关闭本窗口停止并清屏）"
  while true; do html_shot "$URL"; sleep "$N"; done
}

run_image() {
  SRC=${1:-}
  [ -z "$SRC" ] && SRC=$(zenity --file-selection --title="选择图片" --file-types="PNG 图片:.png")
  [ -z "$SRC" ] && exit 0
  python3 "$DRAW" --image "$SRC" --fb "$FB" >/dev/null
  echo "已显示 $SRC"
}

menu() {
  C=$(zenity --list --title="MHS35 小屏" --text="选择小屏显示内容" --column="功能" --column="说明" \
    "系统信息(getInfoCN.py)" "每2秒刷新" \
    "网页(HTML/URL)" "chromium 截图写屏" \
    "图片(png)" "缩放到 480x320" \
    "纯色测试" "red/green/blue/white" \
    "停止(清屏)" "交还控制台")
  case "$C" in
    系统信息*) run_info info ;;
    网页*) run_html ;;
    图片*) run_image ;;
    纯色测试*) fill red; sleep 1; fill green; sleep 1; fill blue; sleep 1; fill white;;
    停止*) fill black;;
  esac
}

if [ ! -e "$FB" ]; then echo "没有 $FB，驱动未加载"; exit 1; fi

case "${1:-menu}" in
  info) run_info info "${2:-2}" ;;
  html) run_html "${2:-}" "${3:-5}" ;;
  image) run_image "${2:-}" ;;
  fill) fill "${2:-black}"; echo "已填充 ${2:-black}" ;;
  stop) fill black; echo "已清屏" ;;
  status) echo "fb1 name=$(cat /sys/class/graphics/fb1/name) bpp=$(cat /sys/class/graphics/fb1/bits_per_pixel)"; ls -l "$FB";;
  menu) menu ;;
  *) sed -n '2,10p' "$0" | sed 's/^# //' ;;
esac

