# UEFI 上机实测（2026-10-30）：E0 不交棒、A2 交棒后早死——载荷相关，非 header 问题

> 父会话执行。依据 `reports/uefi-testplan-20261030.md`（下称「执行单」）与 `reports/uefi-consolidated-20261030.md`。
> 零写盘：只 `fastboot boot`；唯一写操作 = 恢复时的 `fastboot set_active b`（GPT 双表已备份，见 §4）。
> 本轮**未出 UEFI 画面**，J1（屏上出字）**未达成**。

## §0 数字结论

| 发 | 镜像 | sha256（前 16） | `Booting` 结果 | 交棒 | 屏幕/后续 |
|---|---|---|---|---|---|
| **1** | E0-v0b | `ad450e28faa75fd2` | `OKAY [10.108s]` | ❌ **未交棒**（`fastboot devices` 全程应答 18d1:d00d，`current-slot` 不变） | **卡联想 logo**，ABL 留在 fastboot |
| **2** | A2-v0b | `a38bd56361492549` | **`FAILED (usb_read failed: No such device)`** | ✅ **真交棒**（USB 掉线 ≥15 s） | 全静默 → ~30 s 后回落 **stock Android**（`17ef:7f3d`，`adb` 可通，`ro.boot.slot_suffix=_a`） |

**两枚 header 逐字段相同**（v0 / page 4096 / `kernel_addr=0x10008000` / `ramdisk_addr=0x11000000` / `tags_addr=0x10000100` / `os_version=0x1e000133` / 同一 `id`），唯一差异 = 载荷（E0 = 4194416 B，A2 = 4194464 B）。

⇒ **「E0 不交棒」不是 header/base 问题**（`#418` 的规则已满足），而是 **ABL 对该载荷本身有额外拒绝条件**；
**「A2 交棒」证明整条链路（repack → fastboot → ABL → 载荷执行）本身没问题**。

## §1 这轮证伪了什么、确立了什么

**证伪**
- ❌ 「只要 repack 到 `kernel_addr=0x10008000`，ABL 就会交棒」——E0 反例。
- ❌ 「E0（10-05 口径）能复现 10-05 的屏上出字」——本机这发连交棒都没有。

**确立**
- ✅ **A2 型载荷可交棒**（与 2026-10-26 记录一致），所以后续实验应以 A2/N2 为载具，不要再用 E0 当第一发。
- ✅ A2 交棒后**仍然全静默、无屏上出字** ⇒ 复现 10-26 的「UEFI 早期死亡」，即 `uefi-n2-v0-attempt-20261026.md` §0 的形态。
- ✅ 崩溃后设备回 **stock Android 槽 a**、`slot-unbootable:b=yes` —— 与 `#418` 记录逐条一致（本轮再次确认）。

## §2 E0 不交棒的可能原因（**未证实**，按可查性排序）

| # | 假设 | 支持 | 如何判 |
|---|---|---|---|
| H1 | ABL 对 arm64 壳的 **Image magic / 头部字段**有额外校验（E0 壳与 A2 壳不同版本） | 同 header 下两枚行为分叉，唯一变量是载荷。**实测壳头部前 64 B 已分叉**：`code0` E0=`0x10000381` vs A2=`0x10000501`（差 `0x180`=384），其余字段（`magic@56=0x644d5241`、`text_offset=0xff300000`、`image_size=0x400000`）逐字相同 | 反汇编两枚壳的入口 stub，确认 `code0` 指向的入口点与 BootShim 长度差异（已知两枚 BootShim 112 B / 160 B）；再判断 ABL 是否可能对此字段做范围校验 |
| H2 | ABL 依据载荷长度/对齐做 DRAM 预检（两枚差 48 B） | 差异极小却行为分叉 | 构造「A2 载荷 + 截断/填充到 E0 长度」对照 |
| H3 | E0 与 A2 的 **UFSDxe/组件组合**触发 ABL 侧某条早退路径 | E0 = 10-05 口径，A2 = 厂商件 + cache 补丁 | 用 N2（纯 Mu + cache 补丁）做第三点 |

⇒ 执行单 §3.4 的下一步（A2/N2 对照）**已在计划内**，建议下一轮直接做 **N2-v0b**（`90659a4d…`，已备好）以完成三点定位。

## §3 现场证据

| 项 | 值 |
|---|---|
| 发 1 前槽位 | `current-slot=b`、`slot-unbootable:b=no`、`slot-retry-count:b=6` |
| 发 1 后 | `current-slot=b` 未变、retry 仍 6 ⇒ ABL 未把这次当已消耗启动 |
| 发 1 期间 | `18d1:d00d` 持续 28 s 无变化（10 次采样，`fastboot devices` 全程应答） |
| 发 2 后 | `current-slot=a`、`slot-unbootable:b=yes`、`17ef:7f3d` + `adb device` |
| 恢复 | `set_active b` → `current-slot=b`、`slot-unbootable:b=no` → `fastboot reboot` → **15 s 回 Linux**，`uname -v=#1 …Oct 30 11:22:59`、面板 connected/enabled |
| 镜像存档 | `reports/artifacts/uefi-onboard-20261030/`（四枚 + `SHA256SUMS`，9.4 MB） |
| 壳头部比对 | E0 `code0=0x10000381` vs A2 `code0=0x10000501`；`magic@56`/`text_offset`/`image_size` 逐字相同 |

## §4 写操作审计

唯一写操作 = `fastboot set_active b`（改 misc 槽属性，非分区内容）。写前已有：
`backup/HA2EXB0E-16+512/m8ab-restart-20261030/gpt-sda-{primary,backup}.bin`、`gpt-sde-{primary,backup}.bin`；
写后读回 `current-slot=b`、`slot-unbootable:b=no` 与恢复前一致。

## §5 未做 / 待定

1. **N2-v0b 对照未做**（执行单 §3.4 第 2 项）——建议下一轮首发。
2. **E0 与 A2 的壳头部逐字段比对未做**（H1 的判据）。
3. **B1（`0xD6ABB030` 是否在 MemMap）仍无解**：本轮 UEFI 从未活到能执行 `memmap`，该问题**只能靠串口或早显**推进，不能靠反复 `fastboot boot`。
4. **无串口**是本轮唯一的观察盲区：A2 交棒后 60 s 内没有任何可用输出面，只能靠「USB 是否重新枚举」判死。
