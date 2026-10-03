# 移除 Linux 双系统分区 + Android 扩容回原大小（2026-10-02）

## 结果（数字先行）

- `linux`(sda17, 65 GiB) **已从 GPT 删除**；`/dev/block/by-name/linux` 不再存在。
- `userdata`(sda16) 从 146.4 GiB **扩回 211.4 GiB**；`/data` 实测 **211G（可用 202G）**（Android 首启自动 `resize.f2fs`）。
- root / SUSFS / Zygisk 不受影响（`verifiedbootstate=green`、`zn-daemon` 在跑）。

## 备份（先备份，后删除）

- `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz`（**3.44 GB**，30852 项，含 `/root` `/etc` `/usr` `init*` 等）
- `env-pass/backup-20261002/linux17-inventory-20261002.txt`（目录清单 / du / init 备份列表）
- 原始 GPT dump：`env-pass/gpt-20261002/gpt_primary.bin`、`gpt_backup.bin`

## GPT 逆手术（4 KiB 扇区）

1. dump：`dd if=/dev/block/sda bs=4096 count=34 of=gpt_primary.bin`（主）；备份在 LBA `61390847`（`skip=61390814 count=34`）。
2. 用 `scripts/gpt-restore-tb322fc.py build`：
   - `userdata.last_lba = last_usable(61390842)`；
   - 删除 `linux` 项（idx16 → 空槽）；
   - 重算 entries CRC / header CRC（顺序：先 entries_crc，后 hdr_crc）。
   - 产物 `restore_main0.bin` / `restore_backup0.bin`（各 139264 B）。
3. 写回（Android root）：
   ```sh
   dd if=restore_main0.bin   of=/dev/block/sda bs=4096 seek=0        conv=notrunc
   dd if=restore_backup0.bin of=/dev/block/sda bs=4096 seek=61390814 conv=notrunc
   sync
   ```
4. 回读校验：主 GPT md5 `86ab6336…`、备份 md5 `9cae157b…` **与源文件一致**。
5. 重启 → `/data` 自动扩容。

## 回退（万一 GPT 写坏）

用同一 dd 把 `env-pass/gpt-20261002/gpt_primary.bin` / `gpt_backup.bin` 写回原位置（或 EDL 写 LBA0 / LBA61390814）。

## 收尾：b 槽装回原厂安卓（2026-10-02）

- `fastboot flash boot_b backup/stock-259/boot_b.img`（stock Android kernel `6.6.56-android15-8-…`）
- `fastboot flash dtbo_b backup/dtbo_a.img`（原厂 dtbo；已验证 `dtbo_a` 与 `stock-259/dtbo_b` 自 offset 4096 起完全相同，b 的前 4KB 只是被 dummy 覆盖过）
- 重启后 slot a 正常（`verifiedbootstate=green`、SUSFS 内核、`/data` 211G）。
- 说明：`init_boot_b` 仍是早先的 Magisk 版（非本次 Linux 引入）；`vbmeta_b` 是另一套固件 key（原厂状态），未动。
  如需 b 完全 stock：`fastboot flash init_boot_b ~/下载/tb322fc/init_boot.img`（固件包里的 stock init_boot）。

## 可选项（未做）

- `init_boot_a` 仍是 SukiSU LKM 版（内置 KSU 后冗余，ksuinit 自检跳过；可留可恢复 stock）。

## 工具

- `scripts/gpt-restore-tb322fc.py`（新建，逆向手术）
- `scripts/gpt-surgery-tb322fc.py`（原正向手术，参考）
- 方法论文档：`.pi/skills/qualcomm-edl-flashing/references/gpt-surgery.md`
