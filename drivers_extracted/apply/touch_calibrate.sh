#!/bin/bash
# 触摸校准（X + libinput 下）。老系统标定值: Calibration "3936 227 268 3880", SwapAxes=1（rotate 90 时标定）
# 新 config 用 rotate=270，方向可能不同，必要时重新标定。
NAME=$(xinput list --name-only 2>/dev/null | grep -i -E 'ads7846|touch' | head -1)
if [ -z "$NAME" ]; then echo '未找到触摸设备（先确认 overlay 生效、重启过）'; exit 1; fi
ID=$(xinput list --id-only "$NAME")
echo "设备: $NAME id=$ID"
echo '当前矩阵:'; xinput get-prop "$ID" 'Coordinate Transformation Matrix'
echo '提示: 安装标定工具: sudo apt install xinput-calibrator; xinput_calibrator'
echo '参考矩阵(旋转90的老标定): 0 -1 1 1 0 0 0 0 1'

