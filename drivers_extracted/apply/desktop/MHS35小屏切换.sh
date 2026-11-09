#!/bin/bash
# MHS35 小屏(480x320, /dev/fb1) 内容切换 —— 桌面版，免 sudo(用户在 video 组，/dev/fb1 是 root:video 660)
# 命令行: bash MHS35小屏切换.sh [menu|info|gen|html|image|fill|stop|status]
#   menu            zenity 菜单
#   info [秒]       抓 getInfoCN.py 输出(真机上每轮约2秒, 因程序自带 top -n1 采样1秒)
#   gen  [秒]       内置生成器(只读 /proc 与 vcgencmd, 每轮约0.6秒, 适合1秒刷新)
#   html <文件或URL> [秒]  chromium 截图 480x320 写屏(静态快照, 默认5秒)
#   image <png> / fill <颜色> / stop(清屏) / status
set -u
S=$(cd "$(dirname "$0")" && pwd)
DRAW="$S/mhs35_fb1_draw.py"
INFO="$S/mhs35_info.py"
DAEMON="$S/mhs35_daemon.py"
FB=${FB_DEV:-/dev/fb1}
APP=${INFO_APP:-$HOME/getInfoCN.py}
TMP="$HOME/.cache/mhs35"
mkdir -p "$TMP"

fill() { python3 "$DRAW" --fill "$1" --fb "$FB" >/dev/null; }

info_once() {
  python3 "$INFO" "$TMP/text.txt" "$APP"
  python3 "$DRAW" --text "$TMP/text.txt" --size 18 --fb "$FB" >/dev/null
}

gen_once() {
  python3 "$INFO" "$TMP/text.txt" ""
  python3 "$DRAW" --text "$TMP/text.txt" --size 18 --fb "$FB" >/dev/null
}

html_shot() {
  chromium --headless=new --disable-gpu --no-sandbox --window-size=480,320 --screenshot="$TMP/html.png" "$1" >/dev/null 2>&1
  [ -s "$TMP/html.png" ] && python3 "$DRAW" --image "$TMP/html.png" --fb "$FB" >/dev/null
}

# 自我调速: 把本轮耗时算进周期, 周期尽量贴近 N 秒; 耗时超过 N 就不睡
loop_pace() {
  local N=$1
  shift
  local t0 t1 cost left
  t0=$(date +%s%N)
  "$@"
  t1=$(date +%s%N)
  cost=$(( (t1 - t0) / 1000000 ))
  left=$(( N * 1000 - cost ))
  if [ "$left" -gt 0 ]; then
    sleep "$(awk -v l="$left" 'BEGIN{printf "%.3f", l/1000}')"
  fi
  echo "本轮耗时 ${cost}ms, 目标周期 $((N*1000))ms"
}

run_info() {
  N=${1:-2}
  trap 'fill black; echo "小屏已清屏"; exit 0' INT TERM EXIT
  echo "小屏显示系统信息(抓 getInfoCN.py)，目标每 $N 秒刷新（关闭本窗口或 Ctrl-C 停止并清屏）"
  while true; do loop_pace "$N" info_once; done
}

run_gen() {
  N=${1:-1}
  # 常驻渲染器: 单进程循环(采集0.4秒采样窗口+渲染0.1秒+写屏), 1秒周期稳定, Ctrl-C 清屏
  python3 "$DAEMON" "$N"
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
  echo "小屏显示 $URL 的快照，目标每 $N 秒刷新（关闭本窗口停止并清屏）"
  while true; do loop_pace "$N" html_shot "$URL"; done
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
    "系统信息(快)" "内置生成器, 目标每1秒" \
    "系统信息(原程序)" "抓 getInfoCN.py, 每轮约2秒" \
    "网页快照" "输入地址, 每5秒截图写屏" \
    "图片" "选 png 缩放写屏" \
    "纯色测试" "红→绿→蓝→白各1秒" \
    "停止(清屏)" "交还控制台")
  case "$C" in
    系统信息\(快\)*) run_gen 1 ;;
    系统信息\(原程序\)*) run_info 2 ;;
    网页快照*) run_html ;;
    图片*) run_image ;;
    纯色测试*) fill red; sleep 1; fill green; sleep 1; fill blue; sleep 1; fill white;;
    停止*) fill black;;
  esac
}

if [ ! -e "$FB" ]; then echo "没有 $FB，驱动未加载"; exit 1; fi

case "${1:-menu}" in
  info) run_info "${2:-2}" ;;
  gen) run_gen "${2:-1}" ;;
  html) run_html "${2:-}" "${3:-5}" ;;
  image) run_image "${2:-}" ;;
  fill) fill "${2:-black}"; echo "已填充 ${2:-black}" ;;
  stop) fill black; echo "已清屏" ;;
  status) echo "fb1 name=$(cat /sys/class/graphics/fb1/name) bpp=$(cat /sys/class/graphics/fb1/bits_per_pixel)"; ls -l "$FB";;
  menu) menu ;;
  *) sed -n '2,10p' "$0" | sed 's/^# //' ;;
esac

