#!/bin/bash
# 在 SPI 小屏上画测试图案（验证屏与驱动，需 sudo）
# 用法: sudo bash fb1_test.sh [color]
FB=/dev/fb1
W=480; H=320
C=${1:-red}
case $C in red) R=255; G=0; B=0 ;; green) R=0; G=255; B=0 ;; blue) R=0; G=0; B=255 ;; black) R=0; G=0; B=0 ;; white) R=255; G=255; B=255 ;; *) echo 'color: red/green/blue/black/white'; exit 1 ;; esac
if [ ! -e $FB ]; then echo '没有 $FB，驱动未加载'; exit 1; fi
bpp=$(cat /sys/class/graphics/fb1/bits_per_pixel)
if [ "$bpp" != 16 ]; then echo 'fb1 不是 16bpp（当前 $bpp），此脚本只支持 16bpp'; exit 1; fi
python3 - "$R" "$G" "$B" <<'EOF'
import sys
r,g,b = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
# fb_ili9486: RGB565, 小端
px = ((r>>3)<<11) | ((g>>2)<<5) | (b>>3)
data = px.to_bytes(2,'little') * (480*320)
open('/dev/fb1','wb').write(data)
print('已填充 fb1 单色图案 480x320')
EOF
echo '小屏应显示颜色；如仍黑屏，检查 dmesg | grep -i fbtft'

