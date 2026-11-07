# need_user.md

## Q1 · 挂载老系统根分区 `/dev/sda2`

- status: wait
- 时间：2026-11-07-12-16-48
- 问题：老系统根分区 `/dev/sda2`（ext4, 59.4G）未挂载，而本会话 `sudo` 被 `no new privileges` 标志阻止，agent 无法挂载，因此无法扫描老系统的 `/lib/modules`、`/etc` 等驱动文件。
- 请用户在终端执行（只读挂载，安全，不改老系统）：
  ```bash
  sudo mkdir -p /mnt/oldroot
  sudo mount -o ro /dev/sda2 /mnt/oldroot
  ```
  用完卸载：`sudo umount /mnt/oldroot`
- 期望：挂载后回报 `ls /mnt/oldroot` 结果（或直接告知"已挂载"）。
- 回答：
