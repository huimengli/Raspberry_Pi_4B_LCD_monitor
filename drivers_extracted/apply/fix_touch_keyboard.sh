#!/bin/bash
# 修复: 触摸点击在文本框里弹出触摸键盘（labwc 鼠标模拟导致）
# 用法: bash fix_touch_keyboard.sh  （只改你自己的 ~/.config/labwc/rc.xml，无需 sudo）
RC="$HOME/.config/labwc/rc.xml"
TS=$(date +%Y-%m-%d-%H-%M-%S)
if [ ! -f "$RC" ]; then echo "未找到 $RC"; exit 1; fi
cp -a "$RC" "$RC.bak.$TS"
sed -i 's/mouseEmulation="yes"/mouseEmulation="no"/' "$RC"
echo '已把 mouseEmulation 改为 no（触摸屏不再模拟鼠标点击，点击文本框不再弹键盘）'
grep -n 'touch' "$RC"
killall -s SIGHUP labwc 2>/dev/null && echo 'labwc 已重载配置' || echo '请手动重启会话（注销/重启）使配置生效'
echo '如想彻底移除触摸映射: 删除该行并 killall -s SIGHUP labwc'
echo '回退: cp $RC.bak.$TS $RC && killall -s SIGHUP labwc'

