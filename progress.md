# progress.md

## 2026-11-07-12-16-48 会话 1：项目初始化 + 环境勘察

需求：从 USB 接入的老系统提取树莓派 4B 两块针接口外接屏幕的驱动到工作区（`records/2026-11-07-12-16-48.md`）。

- 工作区 `/home/huimengli/Desktop/forDisplay` 初始仅有 `.git`（`master` 无提交，无远程地址）。已落盘 README/progress/tree/todo/records/need_user。
- 新系统：`Linux pi 6.18.50+rpt-rpi-v8` Debian 13.7 arm64；`/dev/mmcblk0p2` 以只读挂载为 `/`；`/dev/mmcblk0p1` → `/boot/firmware`（只读）。
- 老系统：`/dev/sda` 59.6G；`sda1`(vfat, 256M) 已挂载 `/media/huimengli/boot`（只读），`sda2`(ext4, 59.4G) 未挂载。
- `sda1` 可见 `config.txt`(2025-03-24) 及 8 个按分辨率命名的 `config*.bak`（1080p/720p/640p/480p/400p/320p/320pBack/1080pBack），提示老系统是多分辨率/多屏切换配置。
- 阻塞：`sudo` 被 `no new privileges` 阻止，无法挂载 `sda2` → 记入 `need_user.md` Q1（需用户执行挂载命令）。
- 状态：**进行中**（boot 分区勘察 + 用户挂载根分区后继续）。
## 2026-11-07-12-52-00 会话 2：驱动勘察与提取完成

- `udisksctl mount -b /dev/sda2 -o ro` **免 sudo** 成功挂载老系统根分区 → `/media/huimengli/rootfs`（只读），Q1 已解决（`sudo` 因 `no new privileges` 不可用）。
- 老系统确认为 Raspbian 2020-05-27 armhf + 内核 5.10.103；针接口屏为 **MHS35（ILI9486, SPI0/CS0, RESET=GPIO25, DC=GPIO24）+ ADS7846 触摸（CS1, PENIRQ=GPIO17）**，老 `config.txt` 用 `dtoverlay=mhs35:rotate=270`。
- 新系统缺失点：`mhs35.dtbo` 不在 `/boot/firmware/overlays`；`dtparam=spi=on` 未开（无 `/dev/spidev*`）；新内核仍含 `fbtft/fb_ili9486/ads7846` 模块，官方 `fbtft.dtbo` 支持 `ili9486`；新内核无 `fbtft_device.ko`（上游已删）→ 只能走设备树 overlay。
- 老 `fbcp` 为 32 位 armhf 二进制，arm64 + KMS 内核下不可用；`Xorg.1.log` 经查为 VNC，非第二块屏。
- 提取 230 个文件到 `drivers_extracted/`（boot_firmware / src / decompiled / old_kernel_modules / LCD-show / xorg_config / switch_scripts），`MANIFEST.md` 逐条说明来源与用途。
- 用 `dtc` 把 `mhs35.dtbo` 反编译，重建可编译 `src/mhs35-overlay.dts` 并编译出 `mhs35-rebuild.dtbo`：`__fixups__` 指向 `spi0`/`gpio`，init 序列逐字节一致（已 diff 验证）。
- 新系统**未被改动**。安装步骤写入 `MANIFEST.md`，等用户确认（`need_user.md` Q2 第二块屏是什么、Q3 安装授权）。

## Git 提交记录

- `1743872` feat(AI): 提取老系统针接口双屏驱动与配置到工作区（215 个文件）
  - 已本地 commit，**未 push**（本仓库无远程地址）
  - 过程 hash：`c766bdb` → `a2e9ce7` → `df598c9` → `1743872`（amend 修正嵌入 git 仓库与 tree.md）
- `ced1c3f` docs(AI): 记录提交 hash、rpi-fbcp 溯源并同步 tree.md —— 本地 commit，未 push
- `2897f47` docs(AI): 记录 Q2/Q3 追问超时未答，保持 wait —— 本地 commit，未 push
- `d53b6e8` feat(AI): 准备新系统安装脚本与 KMS 镜像结论（223 个文件）—— 本地 commit，未 push
- `993d25c` docs(AI): 补记 commit hash 并同步 tree.md —— 本地 commit，未 push
- `153e34f` fix(AI): 修复 install 脚本在 vfat 上 cp -a 失败导致的安装中断 —— 本地 commit，未 push
- `560415d` feat(AI): 新增触摸键盘修复与 fb1 测试脚本，记录驱动安装成功 —— 本地 commit，未 push
- `7c14357` chore(AI): 收录第二次安装备份并补记 560415d —— 本地 commit，未 push
- `f16dc08` feat(AI): 新增小屏内容切换脚本（getInfoCN 文本 / HTML 截图写 fb1） —— 本地 commit，未 push
## 2026-11-07-14-17 会话 3：用户答复 Q2/Q3，准备安装

- Q2 答复：针接口屏只有 1 块（3.5 寸、可触摸，即 MHS35）；老系统靠 `fbcp` 让两块屏显示**相同内容（镜像）**。
- Q3 答复：授权"在不损坏设备的前提下尝试安装"。本会话 `sudo` 不可用、`/boot/firmware` 只读 → 只能准备脚本，由用户执行。
- 结论：老式 `fbcp` 镜像在新系统不可复现（无 `/dev/vchiq`、无 `/opt/vc`；`rpi-fbcp`/`fbcp-ili9341` 均依赖 DispmanX，后者 2024-02 已归档）。核查仓库清单与 KMS 替代方案表写入 `MANIFEST.md`。
- 新增 `drivers_extracted/apply/`：proposed_config.txt / proposed_cmdline.txt / mhs35.dtbo / install_mhs35.sh / revert_mhs35.sh / verify_mhs35.sh / touch_calibrate.sh（全部 `bash -n` 通过）。
- 已验证运行内核 DT 有 `spi@7e204000`(spi0) 与 `gpio@7e200000`，overlay `__fixups__` 目标存在。
- 新系统仍未改动；安装需用户在终端 `sudo bash drivers_extracted/apply/install_mhs35.sh`。
- 新增 Q4（第二块屏/HDMI 实际分辨率档位）、Q5（KMS 下"同内容"实现方案选择）→ `need_user.md`。
## 2026-11-07-15-30 会话 4：首次安装后诊断，修复脚本 bug

- 用户执行了安装+重启。诊断结果：`mhs35.dtbo` 已进 `/boot/firmware/overlays/`，但 `config.txt`(1272B)/`cmdline.txt`(214B) **未被修改**，`spi@7e204000` status=`disabled`，无 `fb1`/`spidev`，`dmesg` 无 fbtft，小屏纯白（符合预期：无驱动）。
- 根因与修复见 `hard_bug.md` BUG-1（vfat 上 `cp -a` 失败 + `set -e` 中断；备份路径拼接重复）。已把备份复制回 `drivers_extracted/backup_new_system/`（校验和已核对，等于新系统原文件）。
- `install_mhs35.sh`/`revert_mhs35.sh` 重写（普通 `cp` 写 vfat、`W` 定位工作区、`set -euo pipefail`、写后 grep 校验），`bash -n` 通过。
- 待用户在终端重跑 `sudo bash drivers_extracted/apply/install_mhs35.sh` + `sudo reboot`，再 `bash drivers_extracted/apply/verify_mhs35.sh`。
- 新系统 `config.txt` 仍未改动（overlay 文件已新增，可回退）。
## 2026-11-08-21-44 会话 5：安装生效确认，处理触摸键盘与小屏显示

- 用户重跑安装后 verify 结果：fb1 -> fb_ili9486 480x320 fps=31 @115MHz；ads7846 spi0.1 注册为 input9/event8。驱动侧完全成功。
- /dev/spidev* 缺失是设计如此：mhs35 overlay 把 spidev@0/@1 设为 disabled，CS0/CS1 让给屏与触摸。
- 小屏黑屏+光标 = fb1 是 Linux 控制台（fbcon=map:10，dmesg Console: switching to colour frame buffer device 480x135，vtcon1 bind=1）；labwc 只渲染 DRM 输出（HDMI-A-1/2），SPI 屏不是 DRM 输出，桌面画面永远不会出现在小屏。
- 触摸键盘弹出根因：/etc/xdg/autostart/autotouch.desktop 调用 /usr/bin/autotouch，在「1 显示 + 1 触摸」时自动往 ~/.config/labwc/rc.xml 写入 touch 行（mouseEmulation=yes），diff 证实 rc.xml 比 rc.bak 只多这一行。点击文本框获得焦点触发屏幕键盘。
- 系统未安装 wvkbd/onboard 等 OSK（apt-cache 有 wvkbd，未安装）；弹键盘的具体程序待用户确认（Q6）。
- 新增 apply/fix_touch_keyboard.sh（mouseEmulation 改 no，带备份与回退，killall -SIGHUP labwc）与 apply/fb1_test.sh（向 /dev/fb1 写 RGB565 单色图案验证屏）。均 bash -n 通过。
- Q4（HDMI 分辨率档位）与 Q5（KMS 下同内容方案）仍 wait；新增 Q6。
## 2026-11-08-22-24 会话 6：小屏内容切换工具（getInfoCN.py / HTML）

- 用户答复：fix_touch_keyboard.sh 已执行，触摸键盘仍弹出（Q6 未解，需用户告知键盘来源程序）；小屏需求明确为「做个切换脚本，可显示 getInfoCN.py 或显示 HTML 相同内容」。
- 读 /home/huimengli/getInfoCN.py（97 行）：纯文本程序，clear + print + sleep 1 循环，无 X/Wayland 依赖。
- 方案：不碰 X/Wayland，直接向 /dev/fb1 写 RGB565 像素。新增 apply/fb1_draw.py（文本/图片/纯色 → fb1）与 apply/switch_small_screen.sh（info/html/image/fill/stop/status）。
- 字体坑：DroidSansFallbackFull.ttf 有 CJK 但缺拉丁数字（预览出现豆腐块）→ 改为按字符分段，CJK 用 Droid、拉丁用 DejaVuSans，预览已确认正常（tmp/preview_info2.png）。
- 验证：chromium --headless=new --window-size=480,320 --screenshot 产出 480x320 PNG（tmp/fb1_html.png，中文正常）；fb1 写入字节数 307200 = 480*320*2 匹配。
- 抓取 getInfoCN 输出用 timeout 1 python3 app（对 print→sleep 循环有效，沙箱内验证机制可用，vcgencmd/top 在沙箱受限属正常）。
- 脚本 bash -n 通过；写 /dev/fb1 需 root，由用户 sudo 执行。
## 2026-11-09-10-37 会话 7：小屏切换脚本落地桌面（免 sudo），键盘问题按用户决定关闭

- 用户三点指令：已开完全权限；把切换 sh 放到桌面上；网页端已映射到别的设备，不用管虚拟键盘（Q6 按用户决定 done，不再追查）。
- 关键发现：`/dev/fb1` 是 `root:video 660` 且 `huimengli` 在 `video` 组 → 免 sudo 直接写屏，实测 `--fill red` 成功，双击启动器可行。
- 交付到 `/home/huimengli/Desktop/`：`MHS35小屏切换.sh`（menu/info/html/image/fill/stop/status）、`mhs35_fb1_draw.py`、4 个 `.desktop` 启动器（菜单/系统信息/网页/停止），`desktop-file-validate` 全 OK，仓库副本 `apply/desktop/`。
- 修掉两个真 bug：① `info` 抓输出用 `python3 -u` + `timeout 3`（重定向块缓冲导致抓到 0 字节），实测 864 字节含真实 CPU 温度；② `.desktop` 的 `Exec` 含引号与 `&` 被 validate 拒绝，改绝对路径+参数；另修 `[Desktop Entry]` 组头（首版写成注释）。
- 清屏 trap 只挂在 info/html 循环里，避免 `fill`/`status` 退出时把刚画的颜色刷黑。
- 限制记录：`top -n1` 在无 tty 的环境返回空（沙箱实测），从 lxterminal 启动的 info 模式不受影响。