#!/bin/bash
# 重启后验证（只读，无需 sudo：bash verify_mhs35.sh）
echo '=== SPI 设备 ==='
ls -la /dev/spidev* 2>&1
echo '=== framebuffer ==='
for d in /sys/class/graphics/fb*; do [ -f "$d/name" ] && echo "$d -> $(cat "$d/name") videomode=$(cat "$d/videomode" 2>/dev/null)"; done
echo '=== 内核日志（fbtft / ili9486 / ads7846）==='
dmesg 2>/dev/null | grep -i -E 'fbtft|ili9486|ads7846|spi' | tail -20
echo '=== 触摸输入设备 ==='
grep -A4 -i -E 'ads7846|touch' /proc/bus/input/devices 2>/dev/null

