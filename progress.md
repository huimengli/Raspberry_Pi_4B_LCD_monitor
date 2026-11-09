<!-- 已归档于 ai_buckup/progress.md_2026-11-09-11-43-00.md (2026-11-09-11-43-00, 原 99 行) -->

# 进度台账（压缩版，历史全在归档文件与 records/）

## 项目

从老系统（USB 盘 /dev/sda, Raspbian 2020 armhf）提取针接口屏（MHS35 3.5" SPI ILI9486 + ADS7846 触摸）驱动与配置到新系统（RPi OS 2026-10-06, Debian 13.7 trixie, 6.18.50+rpt-rpi-v8, labwc/Wayland），落盘于 `drivers_extracted/`，已安装并实测出图。

## 关键结论

- 驱动链: `mhs35.dtbo` + `spi-bcm2835` + `fbtft` + `fb_ili9486` + `ads7846`；`cmdline.txt` 用 `fbcon=map:10 fbcon=font:ProFont6x11 logo.nologo`。
- `/dev/fb1` = `crw-rw---- root:video 29,1`，用户在 `video` 组 → 写屏免 sudo。fb1 = 480x320@16bpp（307200 字节, RGB565 小端）。
- KMS 下无法复刻老系统 `fbcp` 镜像（需 DispmanX）；labwc 只渲染 DRM 输出，SPI fb1 不是 DRM 输出 → 小屏走「文本/截图写 fb1」方案。
- `mhs35.dtbo` 把 `spidev@0/@1` 设为 disabled，故无 `/dev/spidev*` 是设计如此。
- 刷新 1 秒靠常驻渲染器（每轮 采集0.408s + 渲染0.106s + 转RGB565 0.021s + 写屏0.001s ≈ 0.54s）。
- 自启: `/etc/xdg/labwc/autostart` 有 `lxsession-xdg-autostart`，`~/.config/autostart` 生效（实跑验证）。
- 杀进程要点: `pkill -f` 会杀自己；用 `pgrep` 锚定解释器 `^(/usr/bin/)?python3` + 排除 `$$`/父进程。flock 句柄必须保存，否则锁随句柄回收释放。

## Git 提交记录（全部本地 commit，未 push；无远程）

- `1743872` feat(AI): 提取老系统驱动与配置（215 文件）
- `ced1c3f` docs(AI): 记录 hash、rpi-fbcp 溯源、同步 tree.md
- `2897f47` docs(AI): Q2/Q3 未答保持 wait
- `d53b6e8` feat(AI): 安装脚本与 KMS 镜像结论（223 文件）
- `993d25c` docs(AI): 补记 hash 与 tree.md
- `153e34f` fix(AI): install 脚本 vfat cp -a 失败
- `560415d` feat(AI): 触摸键盘修复与 fb1 测试，记录安装成功
- `7c14357` chore(AI): 收录第二次安装备份
- `f16dc08` feat(AI): 小屏内容切换脚本
- `c06a7d6` feat(AI): 脚本落地桌面（免 sudo）+ 4 启动器
- `7cd8e66` docs(AI): 补记 c06a7d6
- `cb5cc1f` fix(AI): 捕获/CPU 数值/菜单高度/包装脚本
- `079ae57` docs(AI): 补记 7cd8e66 与 cb5cc1f
- `99dce87` docs(AI): 修正补记 hash 为 079ae57
- `a57d605` perf(AI): 刷新改 1 秒（常驻渲染器+自我调速）
- `1e69dcc` docs(AI): 补记 99dce87 与 a57d605
- `087b9bb` feat(AI): 桌面清理、开机自启每秒显示、stopall 杀光小屏进程 —— 本地 commit，未 push
- `8d36e3c` docs(AI): 补记 commit 087b9bb —— 本地 commit，未 push
- `180b159` docs(AI): README 更新为当前状态，安装位置备份入工作区 —— 本地 commit，未 push
- `6c04f0b` docs(AI): 补记 commit 8d36e3c 与 180b159 —— 本地 commit，未 push

## 2026-11-09-11-43 会话 10：桌面清理 + 自启 + 杀光小屏进程

- 实现代码迁到 `~/.local/share/mhs35/`（4 个文件），删除桌面上我的 12 个文件与 `__pycache__`（删前核对路径）；桌面现为用户 5 项 + 4 个启动器。
- 自启项 `~/.config/autostart/MHS35小屏-每秒显示.desktop`（`NoDisplay=true`，`Exec=/usr/bin/python3 .../mhs35_daemon.py 1`），实跑 `lxsession-xdg-autostart` 验证进程起来；`auto-on/auto-off` 可开关。
- `stopall`（启动器「MHS35小屏 全部停止」）杀所有小屏进程 + 清屏；`run_gen/info/html/image` 启动前也先杀，避免互相覆盖。
- 「清屏无效」根因：旧路径常驻进程（`Desktop/mhs35_daemon.py`，文件删了进程没死）持续重画；且 flock 句柄未保存导致双实例并存。均已修。
- 验证: 4 启动器 + 自启项 `desktop-file-validate` OK；自启起进程后 `stopall` 杀干净；`auto-off/on` 往返正常。
