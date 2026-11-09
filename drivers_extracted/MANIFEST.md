# MANIFEST · 从老系统提取的针接口双屏驱动

- 时间：2026-11-07-12-16-48（记录 `records/2026-11-07-12-16-48.md`）
- 来源设备：`/dev/sda`（USB 接入的老系统硬盘）
  - `/dev/sda1`（vfat 256M）挂载于 `/media/huimengli/boot`（只读）
  - `/dev/sda2`（ext4 59.4G）由 `udisksctl mount -b /dev/sda2 -o ro` 挂载于 `/media/huimengli/rootfs`（只读）
- 全程只读，未修改老系统任何文件。

## 两套系统事实

| 项目 | 老系统 | 新系统（当前运行） |
| --- | --- | --- |
| 发行版 | Raspbian 参考版 2020-05-27（stage5, armhf） | Raspberry Pi OS 2026-10-06（stage4），Debian 13.7 trixie，arm64 |
| 内核 | `5.10.103` / `5.10.103-v8+`（固件 2023-10-24） | `6.18.50+rpt-rpi-v8` |
| 显示模式 | 无 KMS（`vc4-fkms-v3d` 被注释），`fbcp` 在 `rc.local` | `dtoverlay=vc4-kms-v3d` + `max_framebuffers=2` |
| SPI | `dtparam=spi=on` 已开 | **未开**（`/dev/spidev*` 不存在） |
| 针接口屏 | `dtoverlay=mhs35:rotate=270` | **无 mhs35 相关配置** |
| 屏幕数 | 1 块针接口屏（MHS35）+ 1 块 HDMI（自定义 cvt 模式） | 未知（等用户确认） |

## 针接口屏规格（从 `mhs35.dtbo` 反编译得到）

- 屏：MHS35，3.5 寸，480x320，控制器 **ILITEK ILI9486**，SPI0 **CS0**，`spi-max-frequency = 115MHz`，`fps=30`，`rotate=90`（overlay 默认），bgr=0，buswidth=8，regwidth=16
- 引脚：**RESET = GPIO25**，**DC = GPIO24**，pinctrl 输入 = GPIO17/25/24
- 触摸：**TI ADS7846** 电阻触摸，SPI0 **CS1**，2MHz，**PENIRQ = GPIO17**，`ti,x-plate-ohms=60`，`ti,pressure-max=255`
- 老系统 `config.txt` 用 `dtoverlay=mhs35:rotate=270`；`.have_installed` = `gpio:resistance:mhs35:90:480:320`

## 驱动栈（老系统实际生效的部分）

1. ``dtoverlay=mhs35``（`mhs35.dtbo`）→ 设备树实例化 `ilitek,ili9486` + `ti,ads7846`
2. 内核模块（自动加载）：`spi-bcm2835` → `fbtft` → `fb_ili9486`；触摸 `ads7846`
3. `cmdline.txt` 的 `fbcon=map:10 fbcon=font:ProFont6x11 logo.nologo` → 控制台输出到 SPI 屏（fb1）
4. `rc.local` 的 `fbcp &`（32 位 armhf 二进制）→ 把 HDMI framebuffer 复制到 SPI 屏
5. X11：`99-fbturbo.conf`（fbdev 驱动，`/dev/fb0`）+ `99-calibration.conf`（触摸校准）+ `45-evdev.conf`
6. `/etc/modules` 只有 `i2c-dev`：老系统**没有**用 `fbtft_device`/`flexfb`（LCD-show 自带的 `modprobe.d/fbtft.conf` 未被安装，且 5.10 内核也没有 `fbtft_device.ko`）

## 新系统为什么"驱动找不到"

- `mhs35.dtbo` 是**厂商自定义**覆盖层，新系统 `/boot/firmware/overlays` 里**没有**（对比结果：`mhs35.dtbo`、`mhs35-overlay.dtb` 在新系统中缺失；`anyspi`/`tinylcd35` 两系统都有）
- 新内核 `6.18.50+rpt-rpi-v8` **仍有** `fbtft.ko.xz`、`fb_ili9486.ko.xz`、`ads7846.ko.xz`、`spi-bcm2835.ko.xz`，且官方 `fbtft.dtbo` 支持 `ili9486` 覆盖参数
- 新内核**没有** `fbtft_device.ko`（上游已删除），所以只能走**设备树 overlay**，不能再用 `fbtft_device` 模块参数方式
- `config.txt` 未开 `dtparam=spi=on`：`/dev/spidev*` 不存在，SPI 屏自然无设备
- 老系统的 `fbcp` 是 32 位 armhf 二进制，在 arm64 + KMS 内核下不可用

## 提取内容一览

```
drivers_extracted/
├── boot_firmware/          老系统 boot 分区（来源 /media/huimengli/boot）
│   ├── mhs35.dtbo          厂商自定义 SPI 屏覆盖层 ← 关键缺失文件
│   ├── mhs35-overlay.dtb   同一份 overlay（LCD-show 源文件）
│   ├── config.txt          老系统当前配置（2025-03-24，含 mhs35:rotate=270 + hdmi_cvt 1280x720）
│   ├── config*.bak         8 份按分辨率的 config 备份（320/400/480/640/720/1080 + Back 变体）
│   ├── cmdline.txt         含 fbcon=map:10、console=ttyAMA0
│   └── issue.txt           老系统版本标识
├── src/                    重建的可编译 overlay 源码
│   ├── mhs35-overlay.dts   由 dtc 反编译后人工整理的可编译 DTS
│   ├── mhs35-rebuild.dtbo  dtc -@ 编译产物（已验证：__fixups__ 指向 spi0/gpio，init 序列逐字节一致）
│   └── rebuild.dts         编译产物的反编译对照
├── decompiled/             反编译 .dts（mhs35.dtbo / mhs35-overlay.dtb / 新系统 fbtft.dtbo）
├── old_kernel_modules/5.10.103-v8+/   老内核模块（仅供参考，**不能**插入 6.18 内核：vermagic 不匹配）
│   ├── fbtft/              fbtft.ko + 全部 fb_* 驱动（含 fb_ili9486.ko）
│   ├── touchscreen/        ads7846.ko, ili210x.ko
│   └── spi/                spi-bcm2835.ko
├── LCD-show/               goodtft/LCD-show 安装包（来源 /media/huimengli/rootfs/home/pi/LCD-show，上游 https://github.com/goodtft/LCD-show.git；已删除副本内的 .git，避免与本仓库嵌套）
│   ├── MHS35-show          老系统实际执行过的安装脚本（拷贝 overlay、写 config.txt、装 fbcp、装 evdev）
│   ├── rpi-fbcp/           fbcp 源码（上游 https://github.com/tasanakorn/rpi-fbcp；已删除副本内的 .git）
│   └── build/              2020-12-04 的 32 位 armhf 构建产物（含 fbcp 二进制）
│   └── usr/                各屏 overlay .dtb（mhs35/mhs35b/mhs24/mhs32/mhs395/mis35/tft35a/tft9341/qddpi24）、fbcp 32 位二进制、calibration/fbturbo 配置、.deb（armhf）
├── xorg_config/            老系统实际安装的 X11/自启配置（99-calibration.conf, 99-fbturbo.conf, 45-evdev.conf, 10-evdev.conf, rc.local）
└── switch_scripts/         home/pi/Desktop/Item/显示器输出/*.sh（8 个 config 切换脚本）
```

## 新系统安装建议（**未执行**，等用户确认）

```text
1) 覆盖层：sudo cp drivers_extracted/boot_firmware/mhs35.dtbo /boot/firmware/overlays/
   （或自建：sudo dtc -@ -I dts -O dtb -o /boot/firmware/overlays/mhs35.dtbo drivers_extracted/src/mhs35-overlay.dts）
2) config.txt（sudo 编辑 /boot/firmware/config.txt）追加：
   dtparam=spi=on
   dtoverlay=mhs35:rotate=270        # 老系统用的旋转值
   # 第二块屏（若为 HDMI 非标准分辨率）：
   hdmi_group=2 / hdmi_mode=1 / hdmi_mode=87 / hdmi_cvt ... / hdmi_drive=2
3) 触摸校准：sudo cp xorg_config/99-calibration.conf /etc/X11/xorg.conf.d/
4) KMS 冲突：新系统 vc4-kms-v3d 下 32 位 fbcp 无效。SPI 屏在 KMS 下作为独立 fbdev 设备，
   可用 fbdev 后端的 X/Weston 直接把 SPI 屏当独立显示；若要把 HDMI 画面镜像到 SPI 屏，
   需要 KMS 版 fbcp（fbcp-26 等）重新编译 —— 待用户确认第二块屏是什么之后再定。
5) 老系统 5.10 的 .ko 不能插入 6.18（vermagic 5.10.103-v8+ vs 6.18.50+rpt-rpi-v8）。
   新内核自带 fbtft/fb_ili9486/ads7846，正常无需编译；若需自编，新系统已有
   linux-headers-6.18.50+rpt-rpi-v8。
```

## 校验和（关键文件）

```
c5505a9cd634486830ee5a0c03cee2b6  boot_firmware/mhs35.dtbo
c5505a9cd634486830ee5a0c03cee2b6  boot_firmware/mhs35-overlay.dtb
506202c9e6e2eea6d9292147e2fe5c4a  boot_firmware/config.txt
e74a7a85f1046f3ce379124d0934faee  boot_firmware/cmdline.txt
```
## KMS 镜像（老系统 fbcp 的等价能力）结论

- 老系统的镜像靠 `fbcp`（DISPMANX）：新系统 **无 `/dev/vchiq`、无 `/opt/vc`（vcos/bcm_host/dispmanx 库全部移除）**，`tasanakorn/rpi-fbcp` 与 `juj/fbcp-ili9341`（README 2024-02 明确已归档、依赖 DispmanX）在 `vc4-kms-v3d` 下**无法构建/运行**。
- 核查过的仓库：`tasanakorn/rpi-fbcp`(2020 停)、`juj/fbcp-ili9341`(1818★，已归档)、`balena-labs-projects/fbcp`(仅 Docker 包装，仍是上述两者)、`jobitjoseph/fbcp-ST7796`、`bitbank2/BB-CP`(2018)。均依赖 DispmanX，无 KMS 版可用。
- 新系统已装 `xserver-xorg-video-fbdev`（`fbdev_drv.so`），Xorg 可以把 SPI 屏的 `/dev/fb1` 作为独立 X screen；fbtft 在 KMS 内核下正常注册 fbdev。
- 因此现实路径：① SPI 屏作为独立 framebuffer（控制台/X 独立会话）；② "两块屏显示相同内容" 需在 KMS 下重做（选项见下），老式 fbcp 镜像不可复现。

### KMS 下实现"同内容"的可选路径（未实施，等 Q4/Q5 确认）

| 方案 | 做法 | 代价 |
| --- | --- | --- |
| A. 双 X server | `Xorg :0` 走 KMS(HDMI) + `Xorg :1` 走 fbdev(/dev/fb1)，程序在两个 DISPLAY 各跑一份 | 需要程序跑两实例；触摸各自标定 |
| B. Xephyr 嵌套 | `Xephyr -fbdev /dev/fb1 -screen 480x320` 把应用窗口渲染进 SPI 屏 | 需装 Xephyr；只镜像指定窗口 |
| C. 只给 SPI 屏跑 X | `Xorg` 以 fbdev 驱动 `/dev/fb1` 为唯一显示，HDMI 接控制台/串口 | HDMI 无图形 |
| D. 改回 legacy 模式 | 新固件里 `vc4-fkms-v3d-pi4.dtbo` 存在，可试 `dtoverlay=vc4-fkms-v3d` + 重编译 fbcp | 新 OS 缺 vcos 库，几乎不可行；且失去 KMS/图形加速 |

## 安装产物（新增 `apply/`）

- `apply/proposed_config.txt`：新系统 config.txt 完整版（保留原 KMS/64 位设置，在 `[all]` 加 `dtparam=spi=on` + `dtoverlay=mhs35:rotate=270` + 老系统 HDMI 自定义分辨率段，带 `>>> forDisplay MHS35 <<<` 标记）
- `apply/proposed_cmdline.txt`：新系统 cmdline + `fbcon=map:10 fbcon=font:ProFont6x11 logo.nologo`（控制台输出到 SPI 屏）
- `apply/mhs35.dtbo`：拷入 `/boot/firmware/overlays/` 的覆盖层
- `apply/install_mhs35.sh`（`bash -n` 通过）：备份原 config/cmdline 到 `backup_new_system/` → remount rw → 装 overlay → 覆盖 config/cmdline → 校验 → remount ro
- `apply/revert_mhs35.sh`：按最新备份回退并删除 overlay
- `apply/verify_mhs35.sh`：重启后只读验证（`/dev/spidev*`、`fb*`、`dmesg` fbtft/ili9486/ads7846、输入设备）
- `apply/touch_calibrate.sh`：X 下触摸矩阵校准提示（老标定值 `3936 227 268 3880` + `SwapAxes=1` 是 rotate 90 标定的，rotate 270 下需重标）
- 已验证运行内核 DT 存在 overlay 目标：`/sys/firmware/devicetree/base/soc/spi@7e204000`（spi0）与 `gpio@7e200000`，`__fixups__` 的 `spi0`/`gpio` 可解析
- 限制：本会话 `sudo` 被 `no new privileges` 阻止，`/boot/firmware` 只读，安装命令**必须由用户在终端执行**
## 小屏显示与交互脚本（2026-11-08 追加）

- `apply/fix_touch_keyboard.sh`：把 `~/.config/labwc/rc.xml` 的 `mouseEmulation` 由 yes 改 no（RPi OS 的 `/usr/bin/autotouch` 会在检测到触摸设备时自动写入该行，`rc.bak` 为其自动备份），并 `killall -s SIGHUP labwc` 重载。
- `apply/fb1_test.sh`：向 `/dev/fb1` 写 RGB565 单色图案（red/green/blue/black/white）验证屏与驱动链路，需 sudo。
- `apply/fb1_draw.py`：把文本 / 图片 / 纯色渲染成 480x320 RGB565 写入 `/dev/fb1`；中文用 `DroidSansFallbackFull.ttf`、拉丁与数字用 `DejaVuSans.ttf` 按字符分段渲染（单一 Droid 字体缺拉丁字形，会出现豆腐块）。`--out preview.png` 可离线预览。
- `apply/switch_small_screen.sh`：小屏内容切换，子命令 `info`（跑 `getInfoCN.py` 抓取输出，每 N 秒刷新）/ `html <文件或URL>`（chromium `--headless=new --window-size=480,320 --screenshot` 截图后写屏）/ `image <png>` / `fill <颜色>` / `stop`（清屏交还控制台）/ `status`。需 sudo（写 `/dev/fb1`）。
- 依赖：`python3-pil`（已装 11.1.0）、`chromium`（已装 154.0.8037）、`DejaVuSans.ttf`、`DroidSansFallbackFull.ttf`；`python3-evdev` 未装（本方案不需要）。
- 已验证：文本渲染预览（`tmp/preview_info2.png`）、chromium 截图链路（`tmp/fb1_html.png`，480x320）、fb1 字节流 307200 = 480×320×2。真机写屏需用户 sudo 执行。
## 桌面版小屏切换（2026-11-09 追加，用户要求放在桌面上）

- 关键发现：`/dev/fb1` 权限 `root:video 660`，用户 `huimengli` 在 `video` 组 → **无需 sudo 即可写屏**，脚本可直接双击运行。实测 `python3 fb1_draw.py --fill red --fb /dev/fb1` 成功。
- 桌面交付物（已装到 `/home/huimengli/Desktop/`，仓库副本在 `apply/desktop/`）：
  - `MHS35小屏切换.sh`：子命令 `menu`(zenity 菜单) / `info` / `html` / `image` / `fill` / `stop` / `status`；循环模式挂 trap，退出即清屏
  - `mhs35_fb1_draw.py`：文本/图片/纯色 → RGB565 写 fb1（CJK 用 Droid，拉丁用 DejaVu 分段）
  - `MHS35小屏-菜单.desktop`、`MHS35小屏-系统信息.desktop`、`MHS35小屏-网页.desktop`、`MHS35小屏-停止.desktop`（`desktop-file-validate` 全部 OK）
- 修复要点：`info` 模式抓 `getInfoCN.py` 输出必须用 `python3 -u` + `timeout 3`，否则重定向到文件时是块缓冲，被 timeout 杀掉前不落盘，抓到 0 字节（实测抓到 864 字节，CPU 温度真实值）。
- 限制：`Exec` 里不能有引号与 `&`（`desktop-file-validate` 报 reserved character），故用绝对路径 + 参数；首次双击需在文件管理器右键「Allow Launching」。
- 首次安装版 `apply/switch_small_screen.sh`（sudo 版）保留作参考，日常用桌面版。
## 桌面版修订（2026-11-09-10-56，针对用户四点反馈）

- 问题①：`MHS35小屏-系统信息.desktop` 报「无法捕获内容」。根因：原 `info` 用 `timeout N python3 -u app` 抓输出，`getInfoCN.py` 是无限循环永不退出，每轮要等满 timeout，且抓空时只显示占位文字。改为 `capture_first_block()`：读到第一个 `---------` 信息块就 `terminate()`，每轮约 1 秒；抓不到时走内置生成器（`/proc/stat`+`/proc/meminfo`+`statvfs`+`vcgencmd`）。
- 问题②：`CPU 使用 = %` 无数值。根因：`getInfoCN.py` 用 `top -n1 | awk '/Cpu\(s\):/ {print $2}'`，无 tty 时 top 报 `failed tty get`（实测），中文 locale 下字段位置不稳。改为脚本用 `/proc/stat` 两次采样求差值，并替换输出里的 CPU 行（实测 12.6%/24.5% 正常）。
- 问题③：菜单太短显示不全。`zenity --list` 加 `--width=520 --height=360`，条目文案缩短。
- 问题④（说明）：`html` 模式 = `chromium --headless=new --window-size=480,320 --screenshot` 把网页渲染成 480x320 PNG，再转 RGB565 写入 `/dev/fb1`；小屏得到的是**静态快照**，每 N 秒重拍一次，小屏上不能滚动/点击，动图与视频不会动。
- 启动器改造：`lxterminal -e` 会吞掉 `脚本 参数` 里的参数，改为单 token 包装脚本 `run_menu.sh`/`run_info.sh`/`run_html.sh`/`run_stop.sh`，`.desktop` 的 `Exec` 只指向包装脚本，`desktop-file-validate` 全 OK。