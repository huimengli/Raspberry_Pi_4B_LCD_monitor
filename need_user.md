# need_user.md

<!-- 已归档于 ai_buckup/need_user.md_2026-11-07-12-52-00.md（Q1 已解决） -->

## Q1 · 挂载老系统根分区 `/dev/sda2`

- status: done
- 时间：2026-11-07-12-16-48
- 问题：`sudo` 被 `no new privileges` 阻止，agent 无法挂载 `sda2` 扫描老系统驱动。
- 回答：无需用户介入，`udisksctl mount -b /dev/sda2 -o ro` 免授权成功，挂载于 `/media/huimengli/rootfs`（只读）。已归档。

## Q2 · 第二块屏幕是什么

- status: wait
- 时间：2026-11-07-12-52-00
- 问题：老系统 `config.txt` 里针接口屏只有 1 块（MHS35，3.5 寸 480x320 SPI 屏），另有 HDMI 自定义分辨率 `hdmi_cvt 1280 720`（及 8 份按分辨率的 `config*.bak` + `显示器输出/*.sh` 切换脚本）。`Xorg.1.log` 经查是 VNC，不是第二块屏。
- 需要确认：
  1. 两块屏幕的**型号/尺寸/接口**（是否两块都是 SPI 针接口屏？第二块接在 SPI1 还是 HDMI？）。
  2. 若是两块 SPI 屏，第二块的控制器型号与接线 GPIO（RESET/DC/CS）分别是什么。
  3. 老系统当时两块屏分别显示什么（各自分辨率/旋转）。
- 影响：决定安装方案（第二块屏需要额外 overlay，如 `spi1-1cs` + `fbtft,ili9486` 或新增自定义 dts）。

## Q3 · 新系统安装授权

- status: wait
- 时间：2026-11-07-12-52-00
- 问题：安装需要 root（`sudo` 在本会话不可用），且要改 `/boot/firmware/config.txt`（当前只读挂载）与拷贝 overlay 到 `/boot/firmware/overlays/`。
- 请确认：
  1. 是否授权由用户在终端执行 `MANIFEST.md` 第"新系统安装建议"里的命令（agent 提供逐条命令，用户执行）。
  2. 是否先只启用 MHS35 单屏（最小改动：`dtparam=spi=on` + `dtoverlay=mhs35:rotate=270`），验证后再处理第二块屏。
- 回答：
