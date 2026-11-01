# uefi-edl-read-20261101 — 「只能进 fastboot」闭环取证（EDL 全只读）

事故/结论：`../../uefi-slotboot-stuck-fastboot-20261101.md` §8；坑 `PITFALLS #484/#485`。

工具链：`~/edl-tool/bkerler-edl-1cda1a6` + loader `~/下载/tb322fc/xbl_s_devprg_ns.melf`。
EDL 9008 需 udev 规则（`05c6:9008` → `MODE=0666,GROUP=plugdev`）+ **必须**
`udevadm control --reload-rules && udevadm trigger --subsystem-match=usb --action=change`（只 reload 不生效）。

## 关键结论（本目录证据支撑）

本机**双代引导固件并存**，ABL 按活动槽选 boot LUN：

| 活动槽 | boot LUN | XBL | ABL | UEFI |
|---|---|---|---|---|
| `a` | 1 | `xbl_a` `8b09b3ae…` | `abl_a` `e7062378…` | `uefi_a` `fc68d2f9…` = **6.0.260611（Jun 11 2026）= 官方包原厂件** |
| `b` | 2 | `xbl_b` `fc4fd270…` | `abl_b` `811489f0…` | `uefi_b` `ae3c1c92…` = **6.0.260514（May 14 2026）= 上一版** |

卡死那次 = `slot=b` 却跑在 `UFS Boot LUN: 1`。修复 = `fastboot --set-active` 另一槽，双向复现。

## 文件

| 文件 | 说明 |
|---|---|
| `SHA256SUMS.txt` | 全部件校验和（**唯一入库的账**；`.bin` 本体不入库） |
| `logfs-now.bin` | 8 MiB 环形日志 ×10 段（**只有 seg0 是本机的**，见 #485） |
| `uefi_a.bin` / `uefi_b.bin` | 5 MiB 各一，两代 UEFI（`uefi_a` = 官方包逐字节相同） |
| `abl_a.bin` / `abl_b.bin` | 各 1 MiB，两代 ABL |
| `xbl_a.bin` / `xbl_b.bin` | 各 3.5 MiB，LUN1/LUN2 的 XBL |
| `xbl_config_a.bin` | 344 KiB，LUN1 的 XBL config（= 官方包逐字节相同） |
| `xbl-config-lun1-raw.bin` | LUN1 sector 0..351 原样（含 xbl_a + xbl_config_a + GPT） |
| `devinfo.bin` | 4 KiB；`ANDROID-BOOT!` + 0d/0e/0f = 1/1/1（解锁/解锁关键/充电屏，**正常值**） |
| `misc.bin` | 1 MiB，**全 0**（BCB 干净） |
| `vbmeta_a-device.bin` / `vbmeta_b-device.bin` | 各 64 KiB；a = 官方包逐字节同，b = 我们自签 `fc1e3b33…` flags=3 |
| `uefivarstore.bin` | 512 KiB，PTBL 表头 + 4 个条目 |
| `lun{0,1,2,4}-gpt-primary.bin` / `lun4-gpt-backup-NOW.bin` | 各 LUN 的 GPT（主/备；header+entry CRC 均 OK） |
| `printgpt.txt` | `edl.py printgpt` 全量输出（6 个 LUN） |
| `android-after/` | 恢复后进 Android 的取证（`props.txt`/`state.txt`/`bootconfig.txt`） |

## 复现

```bash
cd ~/edl-tool/bkerler-edl-1cda1a6
L=~/下载/tb322fc/xbl_s_devprg_ns.melf
python3 edl.py --loader=$L r logfs   <out>
python3 edl.py --loader=$L r uefi_a  <out>   # 同理 uefi_b / abl_a / abl_b / xbl_a / xbl_b
python3 edl.py --loader=$L r devinfo <out>
python3 edl.py --loader=$L r misc    <out>
python3 edl.py --loader=$L rs 0 34 --lun=4 <out>
cd ~/y700-elden && python3 scripts/logfs-decode.py <logfs> --segment 0
```
