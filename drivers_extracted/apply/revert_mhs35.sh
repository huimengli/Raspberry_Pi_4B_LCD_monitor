#!/bin/bash
# 回退到新系统原配置（sudo bash revert_mhs35.sh）
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)
W=$(cd "$S/../.." && pwd)
BK="$W/drivers_extracted/backup_new_system"
BOOT=/boot/firmware
LAST=$(ls -1t "$BK"/config.txt.*.bak 2>/dev/null | head -1 || true)
LASTC=$(ls -1t "$BK"/cmdline.txt.*.bak 2>/dev/null | head -1 || true)
if [ -z "$LAST" ] || [ -z "$LASTC" ]; then echo '未找到备份，拒绝回退'; exit 1; fi
mount -o remount,rw "$BOOT"
cp "$LAST" "$BOOT/config.txt"
cp "$LASTC" "$BOOT/cmdline.txt"
rm -f "$BOOT/overlays/mhs35.dtbo"
sync
mount -o remount,ro "$BOOT" || true
echo "已回退: $LAST / $LASTC（overlay 已移除）。请 sudo reboot"

