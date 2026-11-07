#!/bin/bash
# 安装 MHS35 针接口屏支持到新系统（需 sudo，由用户在终端执行：sudo bash install_mhs35.sh）
# 只做三件事：拷贝 overlay、改 config.txt、改 cmdline.txt；原文件先备份到工作区。
set -e
S=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$S")
TS=$(date +%Y-%m-%d-%H-%M-%S)
BOOT=/boot/firmware
BK="$ROOT/drivers_extracted/backup_new_system"
mkdir -p "$BK"
echo '[1/4] 备份新系统原配置 -> ' "$BK"
cp -a "$BOOT/config.txt" "$BK/config.txt.$TS.bak"
cp -a "$BOOT/cmdline.txt" "$BK/cmdline.txt.$TS.bak"
echo '[2/4] 写入 overlay 与配置'
mount -o remount,rw "$BOOT"
cp -a "$S/mhs35.dtbo" "$BOOT/overlays/mhs35.dtbo"
cp -a "$S/proposed_config.txt" "$BOOT/config.txt"
cp -a "$S/proposed_cmdline.txt" "$BOOT/cmdline.txt"
echo '[3/4] 校验'
test -f "$BOOT/overlays/mhs35.dtbo" && echo '  mhs35.dtbo 就位'
grep -q 'dtoverlay=mhs35' "$BOOT/config.txt" && echo '  config.txt 含 mhs35'
grep -q 'dtparam=spi=on' "$BOOT/config.txt" && echo '  config.txt 含 spi'
grep -q 'fbcon=map:10' "$BOOT/cmdline.txt" && echo '  cmdline.txt 含 fbcon 映射'
echo '[4/4] 落盘'
sync
mount -o remount,ro "$BOOT" || true
echo '完成。请重启生效: sudo reboot'
echo '回退: sudo bash $S/revert_mhs35.sh'

