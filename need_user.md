# need_user.md

<!-- 已归档于 ai_buckup/need_user.md_2026-11-07-12-52-00.md（Q1）、ai_buckup/need_user.md_2026-11-07-14-17-00.md（Q2/Q3） -->

## Q1 · 挂载老系统根分区 `/dev/sda2`

- status: done（`udisksctl mount -b /dev/sda2 -o ro` 免 sudo 成功，只读，`/media/huimengli/rootfs`）

## Q2 · 第二块屏幕是什么

- status: done
- 答复（2026-11-07-14-17）："对的，3.5寸小屏幕，可触摸，只有一块，老系统只能让两块屏幕显示相同内容"
- 解读：针接口屏只有 MHS35 一块（3.5 寸 + 触摸）；"两块屏同内容"= 老系统 `fbcp` 的镜像效果，另一块是 HDMI。

## Q3 · 新系统安装授权

- status: done
- 答复（2026-11-07-14-17）："如果不会损坏设备，你可以尝试安装"
- 约束：本会话 `sudo` 被 `no new privileges` 阻止，`/boot/firmware` 只读挂载 → 安装脚本已备好，需用户在终端 `sudo` 执行。
- 安全性说明：只改 `/boot/firmware/config.txt`、`cmdline.txt` 与新增一个 overlay 文件；不刷固件、不动 SPI 电气参数（115MHz 是老系统用过的同一配置）；原配置先备份到 `drivers_extracted/backup_new_system/`，可一键回退。

## Q4 · 第二块屏（HDMI）用哪一档分辨率

- status: wait
- 时间：2026-11-07-14-17
- 问题：老系统有 8 档 `config*.bak`（480x320 / 600x400 / 720x480 / 960x640 / 1280x720 / 1920x1080 + 两个 Back 变体），`apply/proposed_config.txt` 目前取 1280x720（老系统当前 `config.txt` 用的档位）。
- 需要：确认第二块屏的分辨率档位（或直接告诉我它型号/原生分辨率）。

## Q5 · KMS 下"两块屏显示相同内容"用哪种实现

- status: wait
- 时间：2026-11-07-14-17
- 背景：老系统的 `fbcp` 镜像在新系统不可复现（无 DispmanX）。KMS 下可行路径：A 双 X server（HDMI=:0 KMS + SPI fbdev :1，程序跑两实例）/ B Xephyr 嵌套到 SPI 屏 / C 只在 SPI 屏跑 X / D 改回 fkms+重编译 fbcp（新 OS 缺 vcos，几乎不可行）。
- 需要：选 A/B/C/D 之一（推荐 A），并说明需要在 SPI 屏上跑的是什么程序（老系统上有 `getInfoCN.py` 等自启程序？）。

## 追问记录

- 2026-11-07-13-15：会话内提问 Q2/Q3，两次等待超时未答（当时保持 wait）。
- 2026-11-07-14-17：用户直接答复 Q2/Q3（见上），Q4/Q5 为新增。
## Q6 · 弹出的是哪个触摸键盘

- status: wait
- 时间：2026-11-08-21-44
- 现象（用户）：「现在会经常性的弹出触摸键盘」。系统未安装 wvkbd/onboard 等 OSK，怀疑是应用自带屏幕键盘（如 Chromium 虚拟键盘）被触摸点击触发。
- 需要：键盘外观/标题，或弹出时打开的是什么程序。
- 可先试：bash drivers_extracted/apply/fix_touch_keyboard.sh（把 mouseEmulation 改为 no，点击不再模拟鼠标，通常就不弹键盘）。

## Q4/Q5 状态更新（2026-11-08-21-44）

- Q4（HDMI 分辨率档位）：仍 wait。当前用 1280x720。
- Q5（KMS 下两块屏显示相同内容）：仍 wait。已确认 labwc 只渲染 DRM 输出；可行方向是小屏跑独立 fbdev/X 会话，或程序直接画 /dev/fb1。
## Q5 状态更新（2026-11-08-22-24）

- 用户答复：「小屏幕我暂时没想好，能不能做个切换的sh，允许执行并显示 getInfoCN.py 或显示 html 相同内容」
- 已实现 drivers_extracted/apply/switch_small_screen.sh：info / html / image / fill / stop / status（直接写 /dev/fb1，绕过 X/Wayland，不涉及触摸冲突）
- 需要：用户真机 sudo 试用后反馈；若要「两块屏相同内容」，HDMI 侧同时跑同一程序（info 模式让 HDMI 控制台也打印，或 html 模式两边同页）

## Q6 状态更新（2026-11-08-22-24）

- 用户反馈：fix_touch_keyboard.sh（mouseEmulation→no）执行后仍然弹触摸键盘 → 弹出者不是 labwc 鼠标模拟路径
- 需要：键盘外观/标题栏，或弹出时打开的程序；可执行 sudo ps -eo comm | grep -iE 'kbd|keyboard|wvkbd' 看进程名
