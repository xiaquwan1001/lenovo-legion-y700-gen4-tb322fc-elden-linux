# UEFI `N2-v0b` 上机：**不交棒**（与 E0 同，A2 对照仍为真交棒）—— 2026-10-30 14:16

> 父会话执行。执行单 = `reports/uefi-testplan-20261030.md` §3.4 第 2 项；总账 = `reports/uefi-consolidated-20261030.md`。
> 本轮**只做一次 `fastboot boot`**，不写任何分区、不改槽、不动 `uefi_a`/`imagefv_a`/GPT；失败即止。

## §0 数字结论

| 项 | 结果 |
|---|---|
| 载荷 | `reports/artifacts/uefi-onboard-20261030/N2-v0b.img`，sha256 **`90659a4d…`**，`sha256sum -c SHA256SUMS` **4/4 OK** |
| header（实测） | `hv=0`、`pagesize=4096`、**`kernel_addr=0x10008000`**、`ksize=2436721`、`osver=0x1e000133`、`second_addr=0x10f00000` ⇒ 满足 `PITFALLS` #418 的 base 要求 |
| 前置状态 | `current-slot=b`、`slot-unbootable:b=no`、`slot-unbootable:a=no`、`product=elden_prc_wifi`、`secure=yes` |
| **fastboot 输出** | `Sending 'boot.img' (2384 KB) OKAY [0.055s]` / **`Booting OKAY [10.107s]`** |
| **判据（USB）** | 60 s 内每 1 s 采样 **60/60 全部为 `18d1:d00d`（fastboot）** ⇒ fastboot 全程应答 = **未交棒**（`PITFALLS` #387/#418 同形态） |
| 屏幕 | **待用户确认**（预期 = 卡联想 logo，与 E0 同） |
| 回退 | `fastboot reboot` → **15 s 回 Linux**；`uname -v` `#2 … 13:06:36`、根 `/dev/sda17 ext4`、面板 `connected`、`slot-unbootable:b=no`、`current-slot=b` ⇒ **零写盘、无残留** |
| 取证 | `reports/artifacts/uefi-n2v0b-20261030/{pre-state,fastboot-pre,boot-attempt,usb-watch,post}.txt` |

## §1 三点定位结果（关键）

| 发 | 载荷 | 上机时间 | 交棒 | 观察 |
|---|---|---|---|---|
| E0-v0b | 10-05 口径 | 10-30 12:xx | ❌ | fastboot 全程应答；卡 logo |
| A2-v0b | 厂商 UFSDxe + cache shim | 10-30 12:xx | ✅ | USB 掉线（`usb_read failed`），UEFI 早期全静默，~30 s 回落 stock Android |
| **N2-v0b** | **纯 Mu + cache shim** | **10-30 14:16** | ❌ | **60/60 s fastboot 在**（本报告） |

⇒ **交棒与否不是 header/base 问题**（四枚 header 逐字段相同，只有 `second_addr` 在旧/新 N2 之间差一版；`kernel_addr` 全为 `0x10008000`）。
⇒ **判别量在载荷内容**，且目前与「载荷里有没有 UFSDxe」相关：

| 载荷 | 压缩后 ksize | 含 UFSDxe | 交棒 |
|---|---|---|---|
| E0-v0b | 2 436 681 | 无（dodge 前） | ❌ |
| **N2-v0b** | 2 436 721 | 无（纯 Mu） | ❌ |
| A2-v0b | 2 437 509 | 厂商 UFSDxe | ✅ |
| E1-v0b | 2 437 723 | dodge `UFSDxe.patched.efi` | **未测** |

`E1-v0b` 正好是「有 UFSDxe 但非厂商件」的第三点：**测它可把「有 UFSDxe」与「厂商件」区分开**（成本 = 一发 `fastboot boot` + 15 s 回退）。

## §2 为什么「fastboot 仍应答」= 未交棒（口径重申）

`fastboot boot` 后若真的跳到载荷，ABL 的 fastboot gadget 会被销毁、USB 重新枚举（A2 那次就是 `usb_read failed` + USB 掉线）。
本次 60 s 内 USB 设备描述符始终是 `18d1:d00d`（= 同一 fastboot gadget、同一 bus/device 号），说明**从未离开 ABL**。
这条判据不依赖屏幕、也不依赖串口，是本机唯一可靠的「交棒」判据（`PITFALLS` #387）。

## §3 未做 / 下一步

1. **E1-v0b 对照**（推荐，1 发）：验「有 UFSDxe ⇒ 交棒」假设；若 E1 交棒，判别量收敛到「载荷是否含 UFSDxe」这一层。
2. **J1（屏上出字）仍为 0**：目前只有 A2 真交棒且全静默；若交棒条件搞清，下一步才是可见性（BootShim cache 补丁已在 A2/N2 里）。
3. 硬件串口 / `UsbSerial`（上游建议）= 另一条独立线，单独立项。
