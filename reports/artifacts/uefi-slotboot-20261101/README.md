# uefi-slotboot-20261101 — 「槽位正常启动」实验与事故现场

事故全记录：`reports/uefi-slotboot-stuck-fastboot-20261101.md`

| 文件 | 说明 |
|---|---|
| `preflight.txt` | 实验前基线（uname/boot_b 分区 sha/槽位/ boot_id/logfs 首段 sha） |
| `timeline.tsv` | `reboot` 后 150 s、逐秒 `lsusb`/`fastboot`/`ssh` 三态采样 |
| `flash-readback.txt` | 写 `boot_b` 后的 96 MiB 读回 sha（`769c3800…`，与写入件一致） |
| `logfs-before.bin` | 16:28 基线（10 段有效启动段，`492e1124…`） |
| `logfs-after.bin` | 19:05 抓（GPT 修复**之前**；最新段只有 `Start EBS [7940]`，无 `Booting from slot`；`efc88d9f…`） |
| `lun4-gpt-primary-raw.bin` / `lun4-gpt-backup-raw.bin` | LUN4 GPT 原始双表 34 块（**回滚用**，`ed56f1da…` / `0bbfa568…`） |
| `lun4-gpt-primary-new.bin` / `lun4-gpt-backup-new.bin` | 改槽位属性后的双表（`boot_a=0x78`、`boot_b=0x7f`，`fb18e8ea…` / `bab69f0f…`） |

## 回滚一条命令

```bash
cd ~/edl-tool/bkerler-edl-1cda1a6
L=~/下载/tb322fc/xbl_s_devprg_ns.melf
python3 edl.py --loader=$L ws 0        ~/y700-elden/reports/artifacts/uefi-slotboot-20261101/lun4-gpt-primary-raw.bin --lun=4
python3 edl.py --loader=$L ws 1048542  ~/y700-elden/reports/artifacts/uefi-slotboot-20261101/lun4-gpt-backup-raw.bin  --lun=4
```

## 未存件（96 MiB，按需重抓）

`boot_a`（`d4772c11…`，与原厂 `backup/stock-259/boot_a.img` 逐字节相同）、
`boot_b`（`fb55997c…`，与 `bootslot-b/boot_b.img` 逐字节相同）——两者都有等价的主机侧副本，故未入库。
