#!/bin/bash
# 安装 MHS35 针接口屏（需 sudo：sudo bash install_mhs35.sh）
# 只做：备份 -> 装 overlay -> 覆盖 config.txt / cmdline.txt -> 校验
# 注意: /boot/firmware 是 vfat，不能用 cp -a（无法保留权限会报错中断）
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)
W=$(cd "$S/../.." && pwd)
TS=$(date +%Y-%m-%d-%H-%M-%S)
BOOT=/boot/firmware
BK="$W/drivers_extracted/backup_new_system"
mkdir -p "$BK"
echo '[1/5] 备份新系统原配置 -> ' "$BK"
cp -a "$BOOT/config.txt" "$BK/config.txt.$TS.bak"
cp -a "$BOOT/cmdline.txt" "$BK/cmdline.txt.$TS.bak"
echo '[2/5] 允许写 boot 分区'
mount -o remount,rw "$BOOT"
echo '[3/5] 写 overlay 与配置'
cp "$S/mhs35.dtbo" "$BOOT/overlays/mhs35.dtbo"
cp "$S/proposed_config.txt" "$BOOT/config.txt"
cp "$S/proposed_cmdline.txt" "$BOOT/cmdline.txt"
echo '[4/5] 校验写入结果'
test -f "$BOOT/overlays/mhs35.dtbo" && echo '  mhs35.dtbo 就位'
grep -q 'dtoverlay=mhs35' "$BOOT/config.txt" && echo '  config.txt 含 mhs35' || { echo '  失败: config.txt 无 mhs35'; exit 1; }
grep -q 'dtparam=spi=on' "$BOOT/config.txt" && echo '  config.txt 含 spi'
grep -q 'fbcon=map:10' "$BOOT/cmdline.txt" && echo '  cmdline.txt 含 fbcon 映射'
echo '[5/5] 落盘'
sync
mount -o remount,ro "$BOOT" || true
echo '完成。重启生效: sudo reboot'
echo '回退: sudo bash $S/revert_mhs35.sh'

