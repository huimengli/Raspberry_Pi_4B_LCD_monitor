#!/bin/bash
# MHS35 小屏(480x320, /dev/fb1) 内容切换 —— 桌面版，免 sudo(用户在 video 组，/dev/fb1 是 root:video 660)
# 命令行: bash MHS35小屏切换.sh [menu|info|html|image|fill|stop|status]
#   menu            zenity 菜单(双击 MHS35小屏-菜单.desktop 即此)
#   info [秒]       显示系统信息(抓 getInfoCN.py 输出, 用 /proc/stat 修正 CPU 使用率, 抓不到则用内置生成器)
#   html <文件或URL> [秒]  chromium 截图 480x320 写屏(快照, 每N秒刷新一次)
#   image <png>     图片缩放到 480x320 写屏
#   fill <red|green|blue|black|white>
#   stop            清屏(黑)，交还控制台
set -u
S=$(cd "$(dirname "$0")" && pwd)
DRAW="$S/mhs35_fb1_draw.py"
INFO="$S/mhs35_info.py"
FB=${FB_DEV:-/dev/fb1}
APP=${INFO_APP:-$HOME/getInfoCN.py}
TMP="$HOME/.cache/mhs35"
mkdir -p "$TMP"

fill() { python3 "$DRAW" --fill "$1" --fb "$FB" >/dev/null; }

info_once() {
  python3 "$INFO" "$TMP/text.txt" "$APP"
  python3 "$DRAW" --text "$TMP/text.txt" --size 18 --fb "$FB" >/dev/null
}

html_shot() {
  chromium --headless=new --disable-gpu --no-sandbox --window-size=480,320 --screenshot="$TMP/html.png" "$1" >/dev/null 2>&1
  [ -s "$TMP/html.png" ] && python3 "$DRAW" --image "$TMP/html.png" --fb "$FB" >/dev/null
}

run_info() {
  N=${1:-2}
  trap 'fill black; echo "小屏已清屏"; exit 0' INT TERM EXIT
  echo "小屏显示系统信息，每 $N 秒刷新（关闭本窗口或 Ctrl-C 停止并清屏）"
  while true; do info_once; sleep "$N"; done
}

run_html() {
  SRC=${1:-}
  if [ -z "$SRC" ]; then
    SRC=$(zenity --title="小屏网页" --text="输入网页地址(http...)或本地 html 文件路径" --entry --width=420)
    [ -z "$SRC" ] && exit 0
  fi
  case "$SRC" in http*|file*) URL="$SRC" ;; *) URL="file://$(readlink -f "$SRC")" ;; esac
  N=${2:-5}
  trap 'fill black; echo "小屏已清屏"; exit 0' INT TERM EXIT
  echo "小屏显示 $URL 的快照，每 $N 秒刷新（关闭本窗口停止并清屏）"
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
  C=$(zenity --list --title="MHS35 小屏" --text="选择小屏显示内容" --width=520 --height=360 \
    --column="功能" --column="说明" \
    "系统信息" "每2秒刷新(CPU/内存/磁盘/IP)" \
    "网页快照" "输入地址, 每5秒截图写屏" \
    "图片" "选 png 缩放写屏" \
    "纯色测试" "红→绿→蓝→白各1秒" \
    "停止(清屏)" "交还控制台")
  case "$C" in
    系统信息*) run_info 2 ;;
    网页快照*) run_html ;;
    图片*) run_image ;;
    纯色测试*) fill red; sleep 1; fill green; sleep 1; fill blue; sleep 1; fill white;;
    停止*) fill black;;
  esac
}

if [ ! -e "$FB" ]; then echo "没有 $FB，驱动未加载"; exit 1; fi

case "${1:-menu}" in
  info) run_info "${2:-2}" ;;
  html) run_html "${2:-}" "${3:-5}" ;;
  image) run_image "${2:-}" ;;
  fill) fill "${2:-black}"; echo "已填充 ${2:-black}" ;;
  stop) fill black; echo "已清屏" ;;
  status) echo "fb1 name=$(cat /sys/class/graphics/fb1/name) bpp=$(cat /sys/class/graphics/fb1/bits_per_pixel)"; ls -l "$FB";;
  menu) menu ;;
  *) sed -n '2,10p' "$0" | sed 's/^# //' ;;
esac

