#!/bin/bash
# MHS35 小屏(480x320, /dev/fb1) 内容切换 —— 免 sudo(用户在 video 组, /dev/fb1 是 root:video 660)
# 用法: MHS35小屏切换.sh [menu|gen|info|html|image|fill|stopall|status]
#   menu            zenity 菜单(桌面 4 个 .desktop 的入口)
#   gen [秒]        常驻渲染器 1 秒刷新(内置生成器), 默认1秒
#   info [秒]       抓 getInfoCN.py 输出(真机每轮约2秒), 默认2秒
#   html <地址> [秒] chromium 截图 480x320 写屏(静态快照)
#   fill <颜色>     红/绿/蓝/黑/白
#   stopall         杀掉所有小屏相关进程(渲染器/循环/渲染) 并清屏
set -u
S=$(cd "$(dirname "$0")" && pwd)
DRAW="$S/mhs35_fb1_draw.py"
INFO="$S/mhs35_info.py"
DAEMON="$S/mhs35_daemon.py"
FB=${FB_DEV:-/dev/fb1}
APP=${INFO_APP:-$HOME/getInfoCN.py}
TMP="$HOME/.cache/mhs35"
mkdir -p "$TMP"

# 杀进程: 匹配安装目录的 python/脚本, 排除自己与父进程(否则会自杀)
kill_all() {
  # 只杀小屏相关进程: 锚定到解释器(含 /usr/bin/ 前缀, 自启项用的就是 /usr/bin/python3),
  # 并排除自己与父进程, 避免 pgrep 匹配到自己的命令行导致自杀
  local p me=$$ pp=$PPID
  local pat='^(/usr/bin/)?python3 .*mhs35_daemon.py'
  pat="$pat|^(/usr/bin/)?python3 .*mhs35_fb1_draw.py"
  pat="$pat|^(/usr/bin/)?python3 .*mhs35_info.py"
  pat="$pat|^(/usr/bin/)?bash .*MHS35小屏切换.sh"
  pat="$pat|^sh -c .*MHS35小屏切换.sh"
  for p in $(pgrep -f "$pat"); do
    [ "$p" = "$me" ] && continue
    [ "$p" = "$pp" ] && continue
    kill "$p" 2>/dev/null
  done
  sleep 0.4
}

fill() { python3 "$DRAW" --fill "$1" --fb "$FB" >/dev/null; }

info_once() {
  python3 "$INFO" "$TMP/text.txt" "$APP"
  python3 "$DRAW" --text "$TMP/text.txt" --size 18 --fb "$FB" >/dev/null
}

html_shot() {
  chromium --headless=new --disable-gpu --no-sandbox --window-size=480,320 --screenshot="$TMP/html.png" "$1" >/dev/null 2>&1
  [ -s "$TMP/html.png" ] && python3 "$DRAW" --image "$TMP/html.png" --fb "$FB" >/dev/null
}

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
}

run_gen() {
  N=${1:-1}
  kill_all
  python3 "$DAEMON" "$N"
}

run_info() {
  N=${1:-2}
  kill_all
  trap 'fill black; echo "小屏已清屏"; exit 0' INT TERM EXIT
  echo "小屏显示系统信息(抓 getInfoCN.py)，目标每 $N 秒刷新（关窗口或 Ctrl-C 停止并清屏）"
  while true; do loop_pace "$N" info_once; done
}

run_html() {
  SRC=${1:-}
  if [ -z "$SRC" ]; then
    SRC=$(zenity --title="小屏网页" --text="输入网页地址(http...)或本地 html 文件路径" --entry --width=420)
    [ -z "$SRC" ] && exit 0
  fi
  case "$SRC" in http*|file*) URL="$SRC" ;; *) URL="file://$(readlink -f "$SRC")" ;; esac
  N=${2:-5}
  kill_all
  trap 'fill black; echo "小屏已清屏"; exit 0' INT TERM EXIT
  echo "小屏显示 $URL 的快照，目标每 $N 秒刷新（关窗口停止并清屏）"
  while true; do loop_pace "$N" html_shot "$URL"; done
}

run_image() {
  SRC=${1:-}
  [ -z "$SRC" ] && SRC=$(zenity --file-selection --title="选择图片" --file-types="PNG 图片:.png")
  [ -z "$SRC" ] && exit 0
  kill_all
  python3 "$DRAW" --image "$SRC" --fb "$FB" >/dev/null
  echo "已显示 $SRC"
}

stopall() {
  kill_all
  fill black
  echo "已杀掉所有小屏进程并清屏"
  pgrep -f "$S/" | sed 's/^/残留: /'
}

menu() {
  C=$(zenity --list --title="MHS35 小屏" --text="选择小屏显示内容" --width=520 --height=360 \
    --column="功能" --column="说明" \
    "系统信息(快)" "常驻渲染器, 1秒刷新" \
    "系统信息(原程序)" "抓 getInfoCN.py, 每轮约2秒" \
    "网页快照" "输入地址, 每5秒截图写屏" \
    "图片" "选 png 缩放写屏" \
    "纯色测试" "红→绿→蓝→白各1秒" \
    "全部停止(杀进程+清屏)" "stopall")
  case "$C" in
    系统信息\(快\)*) run_gen 1 ;;
    系统信息\(原程序\)*) run_info 2 ;;
    网页快照*) run_html ;;
    图片*) run_image ;;
    纯色测试*) kill_all; fill red; sleep 1; fill green; sleep 1; fill blue; sleep 1; fill white;;
    全部停止*) stopall ;;
  esac
}

if [ ! -e "$FB" ]; then echo "没有 $FB，驱动未加载"; exit 1; fi

case "${1:-menu}" in
  gen) run_gen "${2:-1}" ;;
  info) run_info "${2:-2}" ;;
  html) run_html "${2:-}" "${3:-5}" ;;
  image) run_image "${2:-}" ;;
  fill) fill "${2:-black}"; echo "已填充 ${2:-black}" ;;
  stopall) stopall ;;
  status) echo "fb1 name=$(cat /sys/class/graphics/fb1/name) bpp=$(cat /sys/class/graphics/fb1/bits_per_pixel)"; pgrep -f "$S/" | sed 's/^/进程: /';;
  menu) menu ;;
  auto-off) mv -f "$HOME/.config/autostart/MHS35小屏-每秒显示.desktop" "$S/autostart.desktop.disabled" && echo "已关闭开机自启(重启后小屏不再自动刷新)" ;;
  auto-on) mv -f "$S/autostart.desktop.disabled" "$HOME/.config/autostart/MHS35小屏-每秒显示.desktop" && echo "已开启开机自启" ;;
  *) sed -n '2,10p' "$0" | sed 's/^# //' ;;
esac

