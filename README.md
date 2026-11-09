# Raspberry Pi 4B 针接口小屏（MHS35 3.5"）驱动与显示工具

树莓派 4B 上从老系统（Raspbian 2020-05-27, armhf, kernel 5.10.103-v8+）提取**针接口屏**（非 HDMI）的驱动与配置，安装到新系统（Raspberry Pi OS 2026-10-06, Debian 13.7 trixie, kernel 6.18.50+rpt-rpi-v8, arm64, labwc/Wayland），并实现"小屏显示内容"工具链：系统信息 / 网页快照 / 图片 / 纯色 / 杀进程清屏 / 开机自启每秒刷新。

## 硬件

| 项目 | 值 |
| --- | --- |
| 屏 | MHS35 3.5", 控制器 ILITEK ILI9486, 480x320 |
| 接口 | SPI0 CS0, `spi-max-frequency=115000000`, `txbuflen=0x8000` |
| 控制脚 | RESET=GPIO25, DC=GPIO24（pinctrl 0x11/0x19/0x18 = GPIO17/25/24） |
| 旋转/帧率 | `rotate=270`, `fps=30` |
| 触摸 | TI ADS7846 接 SPI0 CS1, 2MHz, PENIRQ=GPIO17, `ti,x-plate-ohms=60`, `ti,pressure-max=255` |
| 写入设备 | `/dev/fb1` = `crw-rw---- root:video 29,1` → 用户在 video 组，写屏免 sudo |
| 像素格式 | 16bpp RGB565 小端：`((r>>3)<<11)|((g>>2)<<5)|(b>>3)`，一帧 307200 字节 |

## 安装

```text
cd drivers_extracted/apply
sudo ./install_mhs35.sh        # 复制 mhs35.dtbo 到 /boot/firmware/overlays, 追加 config.txt / cmdline.txt
sudo ./verify_mhs35.sh         # 校验
sudo ./revert_mhs35.sh         # 回退（备份在 drivers_extracted/backup_new_system/）
```

生效结果（实测）：

```text
graphics fb1: fb_ili9486 frame buffer, 480x320, 300 KiB video memory, 32 KiB buffer memory, fps=31, spi0.0 at 115 MHz
Console: switching to colour frame buffer device 480x135
ads7846 spi0.1: touchscreen, irq 58 -> input: ADS7846 Touchscreen
vtcon1: bind=1
```

`cmdline.txt` 关键参数：`fbcon=map:10 fbcon=font:ProFont6x11 logo.nologo`。

## 小屏工具链

安装位置 `~/.local/share/mhs35/`，桌面 4 个启动器：`菜单` / `系统信息(1秒)` / `网页` / `全部停止`。

```text
MHS35小屏切换.sh menu             zenity 菜单
MHS35小屏切换.sh gen [秒]         常驻渲染器, 内置生成器, 默认 1 秒刷新
MHS35小屏切换.sh info [秒]        抓 getInfoCN.py 输出(真机每轮约2秒), 用 /proc/stat 修正 CPU
MHS35小屏切换.sh html <地址> [秒]  chromium --headless --window-size=480,320 --screenshot 写屏(静态快照)
MHS35小屏切换.sh image <png>      缩放到 480x320 写屏
MHS35小屏切换.sh fill <颜色>       红/绿/蓝/黑/白
MHS35小屏切换.sh stopall          杀掉所有小屏进程并清屏
MHS35小屏切换.sh auto-on/auto-off  开关开机自启
```

1 秒刷新实测：每轮 采集 0.408s（CPU 采样窗口）+ 渲染 0.106s + 转 RGB565 0.021s + 写屏 0.001s ≈ **0.54s**，周期稳定。CPU 占用率必须有采样窗口，1 秒是合理下限。

- 中文渲染分字体：CJK 用 `DroidSansFallbackFull.ttf`（有汉字、无拉丁/数字），拉丁用 `DejaVuSans.ttf`，逐字拼接，避免豆腐块。
- 开机自启：`~/.config/autostart/MHS35小屏-每秒显示.desktop`（`NoDisplay=true`）；`/etc/xdg/labwc/autostart` 内含 `lxsession-xdg-autostart`，实跑验证生效。
- 单实例锁：flock 句柄保存在全局变量（句柄被回收 = 锁释放，曾导致两个渲染器互相覆盖）。杀进程用锚定解释器的 pgrep 模式 `^(/usr/bin/)?python3 .*mhs35_daemon.py` 并排除自身与父进程（`pkill -f` 会连自己的命令行一起杀）。

## 已知限制

- **KMS 下无法复刻老系统的 `fbcp` 双屏镜像**：`fbcp` 依赖 DispmanX（`/dev/vciq`、`/opt/vc`），新内核已无此接口；tasanakorn/rpi-fbcp、juj/fbcp-ili9341、balena-labs-projects/fbcp 都需要它。labwc 只渲染 DRM 输出，SPI 的 `fb1` 不是 DRM 输出，桌面永远不会出现在小屏上 —— 小屏走"直接写 fb1"（文本/截图），HDMI 侧另跑同一程序可达到"两块屏相同内容"。
- 老系统 `.ko`（vermagic 5.10.103-v8+）在 6.18 内核无法加载；新内核自带 `fbtft.ko.xz`/`fb_ili9486.ko.xz`/`ads7846.ko.xz`/`spi-bcm2835.ko.xz`，上游无 `fbtft_device.ko`，所以只能走 DT overlay。
- `mhs35.dtbo` 把 `spidev@0/@1` 设为 `disabled`，因此没有 `/dev/spidev*` 是设计如此，不是故障。
- 触摸校准（`rotate=270`）未做；`xinput` 未安装。触摸虚拟键盘问题由用户决定改用外部网页后关闭（`/etc/xdg/autostart/autotouch.desktop` 向 `rc.xml` 写入 `mouseEmulation="yes"`，`fix_touch_keyboard.sh` 可改 `no`）。
- dmesg 噪声：反复 `hwmon hwmon1: Undervoltage detected!`（115MHz SPI 下供电警告）、`fbtft: module is from the staging directory`、`SPI driver fb_ili9486 has no spi_device_id`、`ads7846: supply vcc not found`。
- HDMI 分辨率档位待确认（`need_user.md` Q4，当前 `hdmi_cvt` 1280x720）。

## 目录

```text
README.md  progress.md  tree.md  todo.md  hard_bug.md  need_user.md
records/            需求记录（时间戳 yyyy-MM-dd-HH-mm-ss）
ai_buckup/          归档与安装位置备份（含 SHA256SUMS）
drivers_extracted/MANIFEST.md    提取清单 + 两系统对比 + KMS 镜像结论
drivers_extracted/apply/         mhs35.dtbo, install/verify/revert, 触摸与键盘脚本
drivers_extracted/apply/desktop/ 小屏工具链与 4 个启动器、自启项（仓库副本）
drivers_extracted/LCD-show/      老系统 LCD-show 脚本与 dtb/overlay 原件
```

## 隐私

仓库内无 IP、无凭据、无密钥（已扫描：仅 `mhs35_info.py` 里的 `192.168.1.1` 是获取本机 IP 用的 UDP 探测占位）。提交作者邮箱在 git 元数据中可见；如需 GitHub 匿名邮箱，后续提交可设 `git config user.email <编号+用户名@users.noreply.github.com>`（不改写历史）。

推送由用户本人执行（本地规则禁止 agent 执行 `git push`）。
