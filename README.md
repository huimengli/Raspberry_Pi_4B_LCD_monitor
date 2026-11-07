# forDisplay

从树莓派 4B 老系统（USB 硬盘接入）中提取两块外接"针接口"屏幕的驱动与配置，落到本工作区，由用户确认后在新系统上安装。

## 背景

- 设备：树莓派 4B。
- 新系统（当前运行）：`Linux pi 6.18.50+rpt-rpi-v8`，Debian 13 (trixie) 13.7，arm64 64 位（用户称"x64 系统"）。
- 老系统：通过 USB 接入的硬盘 `/dev/sda`（59.6G），boot 分区文件时间 2023-10-24。
  - `/dev/sda1` 256M vfat：老系统 boot 分区，已挂载到 `/media/huimengli/boot`（只读）。
  - `/dev/sda2` 59.4G ext4：老系统根分区，**未挂载**。
- 现象：老系统上通过针接口（非 HDMI）驱动的两块外接屏幕，在新系统里找不到驱动。

## 目标与验收

1. 从老系统定位屏幕驱动相关文件（内核模块、DTBO 覆盖层、`config.txt` 配置、模块加载与显示配置）。
2. 全部提取到本工作区 `drivers_extracted/`，附来源路径与用途说明清单 `MANIFEST.md`。
3. 用户确认清单后，再给出安装步骤（本阶段**不改动新系统**）。

## 用法

- `tree.md`：工作区结构快照。
- `progress.md`：跨会话进度台账。
- `records/`：需求记录（原始需求、验收、实施记录）。
- `need_user.md`：需要用户确认的阻塞问题（挂载权限、屏幕型号等）。
- `drivers_extracted/`：提取产物，按来源分区组织，附 `MANIFEST.md`。

## 依赖

- 挂载 `/dev/sda2` 需要 root 权限：当前会话 `sudo` 被 `no new privileges` 标志阻止，需用户手动执行（见 `need_user.md` Q1）。
