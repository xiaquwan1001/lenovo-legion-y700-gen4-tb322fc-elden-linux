# UEFI `E1-v0b` 上机：**不交棒**（60/60 fastboot 应答）—— 证伪「载荷含 UFSDxe ⇒ 交棒」

> 2026-10-31 15:0x CST。执行单 = `reports/uefi-testplan-20261030.md` §3.4 第 1 项（父会话执行）。
> **零写盘**：只做一次 `fastboot boot`，未刷任何分区、未改槽、未动 `uefi_a`/`imagefv_a`/GPT。

## §0 数字结论

| 项 | 值 |
|---|---|
| 载荷 | `reports/artifacts/uefi-onboard-20261030/E1-v0b.img`，sha256 **`2ff27bf0…`**（与 `SHA256SUMS` 一致） |
| 前置 | `current-slot=b`、`slot-unbootable:a=no`、`slot-unbootable:b=no`、`boot_b` sha `aedae5f1…`（vk183-fastrpc） |
| `fastboot boot` | `Sending 2388 KB OKAY [0.055s]` / **`Booting OKAY [10.110s]`** |
| 交棒判据 | **未交棒**：60 s × 每秒采样 **60/60 全是 `18d1:d00d`、同一 bus/device `001/014`**（ABL 的 fastboot gadget 从未销毁） |
| 回退 | `fastboot reboot` → **9 s 回 Linux**；`boot_id` 换新 `d13951f3`、`uname -v` 仍 `#1 … 19:00:42`、根 `/dev/sda17 ext4`、面板 `connected`、`boot_b` 仍 `aedae5f1`、失败单元 **0** |

## §1 四点定位表（含本轮）

| 载荷 | 含 UFSDxe | 交棒 | 观察 |
|---|---|---|---|
| E0-v0b | 无（dodge 前） | ❌ | 60/60 fastboot |
| N2-v0b | 无（纯 Mu + cache shim） | ❌ | 60/60 fastboot |
| **E1-v0b** | **有（dodge `e76b555f…`）** | ❌ | **60/60 fastboot（本轮）** |
| A2-v0b | 有（**厂商件**） | ✅ | USB 掉线 `usb_read failed`，UEFI 早期静默，~30 s 回落 stock Android |

⇒ **「载荷含 UFSDxe ⇒ 会交棒」被证伪**。E1 与 A2 的区别不在「有没有 UFSDxe」，而在 UFSDxe 的**来源/代次**：
E1 内是 dodge 件（`E1-UFSDxe-in-FV-SEC2.pe32` 去 4 B 段头逐字节相等，155 652 B，2 处补丁），
A2 内是厂商件（`00ae059f…`，补丁集不等价：E1 少第三点 `0x1b080` 的 IOMMU stub，基座代次也不同）——
见 `reports/uefi-e1-identity-20261030.md`。

**仍成立的边界**：交棒与否**不是 header/base 问题**（四枚 header 逐字段相同，`kernel_addr` 全 `0x10008000`）；
判别量在载荷内容，但**不在「有没有 UFSDxe」这一层**，需要再往下切（厂商件 vs dodge 件 / 基座代次 / FV 内 SEC2 段布局）。

## §2 J1（屏上出字）仍为 0

目前唯一真交棒发（A2）全程静默；E0/E1/N2 三发都不交棒 ⇒ 可见性问题**在交棒问题之后**，本轮未推进 J1。

## §3 判据重申（为什么「fastboot 仍应答」= 未交棒）

真跳载荷时 ABL 的 fastboot gadget 会被销毁、USB 重新枚举（A2 即 `usb_read failed` + USB 掉线）。
本轮 60 s 内设备描述符始终是 `18d1:d00d` 且 bus/device 号不变 ⇒ 从未离开 ABL。该判据不依赖屏幕与串口，
是本机唯一可靠的「交棒」判据（`PITFALLS` #387）。

## §4 下一步（按成本）

1. **A2 的厂商 UFSDxe 单变量**：把 A2 里的 `00ae059f…` 厂商件替换进 E1 基座（或反向），一次一发即可把
   「厂商件 vs dodge 件」与「基座代次」分开。**需先做二进制替换与 header 复核，属主机侧施工**。
2. 硬件串口 / `UsbSerial`（上游建议）—— 独立线，单独立项，是解决「交棒后全静默」的唯一低成本观测面。
3. **不建议**再盲试 pristine/纯 Mu 形态（三发同形阴性，无判别力）。

## §5 证据

`reports/artifacts/uefi-e1v0b-20261031/`：`pre-state.txt`、`to-fastboot.txt`、`fastboot-pre.txt`、
`boot-attempt.txt`、`usb-watch.txt`（60 行原始采样）、`recover.txt`、`post.txt`。
