# hard_bug.md

<!-- 暂无 -->
## BUG-1 · 2026-11-07-15-30 · 状态：已修复（脚本侧），等待用户重跑

- **影响**：首次安装只写入了 overlay，`config.txt`/`cmdline.txt` 未更新 → `spi0` 仍 `disabled`，无 `/dev/fb1`、无 `/dev/spidev*`、`dmesg` 无 fbtft，小屏纯白无显示。
- **现象**：`/boot/firmware/overlays/mhs35.dtbo` 已就位（2616B，2020 原件时间戳）；`/boot/firmware/config.txt` 1272B（原样，`[all]` 空）；`cmdline.txt` 214B（原样，无 fbcon）；备份落在错误目录 `drivers_extracted/drivers_extracted/backup_new_system/`（root 属主）。
- **尝试**：`dmesg` 无 fbtft/ads7846 记录；`ls /dev/spidev*` 无；`/sys/firmware/devicetree/base/soc/spi@7e204000/status` = `disabled`；`/proc/bus/input/devices` 无触摸设备。
- **根因**：`install_mhs35.sh` 在 vfat（`/boot/firmware`）上使用 `cp -a`。`cp -a` 要保留权限/所有权，vfat 不支持 → `cp` 返回非 0，配合 `set -e`，脚本在拷完 overlay 后立刻中止，`config.txt`/`cmdline.txt` 的拷贝从未执行。次要 bug：`BK="$(dirname $S)/drivers_extracted/backup_new_system"` 路径拼接重复了一层 `drivers_extracted`，备份写进不存在于版本管理的目录。
- **方案**：① 写 vfat 改用普通 `cp`（不再 `cp -a`），备份仍用 `cp -a` 到工作区（ext4）；② `BK` 改为从脚本目录上溯两级定位工作区（`W=$(cd "$S/../.." && pwd)`）；③ 已把备份内容复制回 `drivers_extracted/backup_new_system/`（校验和：config `ac9390ad0a78d4337ac813344123f133`、cmdline `bfb3bfa4b2f792d6376b043d6c3b2e49`，均等于新系统原文件）；④ root 属主的多余目录 `drivers_extracted/drivers_extracted/` 需用户 `sudo rm -r` 清理（我的沙箱无权删 root 目录）；⑤ 用户重跑 `sudo bash drivers_extracted/apply/install_mhs35.sh`。
- **关联需求/测试**：`records/2026-11-07-12-16-48.md`（Q3 安装授权）；无 `tests/`。

