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
