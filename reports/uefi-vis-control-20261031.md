# UEFI 控制组 + R2：A2 原件**今天仍交棒**，而「任何重建」都不交棒

> 2026-10-31 18:5x–19:1x CST。零写盘（只 `fastboot boot`）。现场目视 = 用户。

## §0 数字结论（三发，同一台机，同一晚）

| 发 | 载荷 | sha | 组成 | 交棒 | 现场/回退 |
|---|---|---|---|---|---|
| **R2** | `VIS-R2.img` | `5828196a…` | **A2 的 160 B cachefix shim** + PrePi 入口插桩 FD（`c6e0e887…`） | ❌ **不交棒**（60/60 `18d1:d00d`） | 屏幕无字；12 s 回 Linux（`acffb17c`） |
| **控制组** | `A2-v0b.img`（10-30 原件，未改一字节） | **`a38bd563…`** | 厂商 UFSDxe FD + 160 B cachefix shim | ✅ **交棒** | `Booting FAILED (usb_read failed: No such device)`，USB 掉线，45 s 内 fastboot 采样 **0/45** |
| （前两发） | `VIS-R1.img` / X1 / X2 | `d2ebbd47…` / `ed46b709…` / `9dd1c16a…` | A2 FD+色条 shim / 交叉换件 | ❌ 全不交棒 | 见 `uefi-vis-r1-20261031.md`、`uefi-swap-x1x2-20261031.md` |

**控制组结论（最重要）**：**A2 原件今天仍然交棒** ⇒ 交棒条件可复现，「10-30 那次是运气」被排除；
同时 **今晚三发重建（R1 色条 / R2 PrePi 插桩 / X1·X2 换 UFSDxe）全部不交棒** ⇒ **不是交棒概率问题，是载荷字节问题**。

## §1 两个独立故障，不能混为一谈

- **A. 早期 FB 写 = 致命（两次独立实验一致）**
  `R1`（shim 里写 `0xFC800000`）与 `R2`（PrePi `CEntryPoint` 首语句写同一地址）**都导致不交棒**，
  两者唯一的共同点就是「在 UEFI 正常流程之前/之初往 framebuffer 写」。
  ⇒ 静态报告 §2 的推断（「MMU 已关、Display Reserved 是普通 DDR、SEC 无 SMMU ⇒ 安全」）**被实测否证**。
  ⇒ **结论改写成：早期写 FB 不安全，原因未证实**（候选：该窗口 display 电源域未起 / 该区被 XPU-SMR 保护 /
  ABL 已把该区标记为设备内存 / 写触发 abort 且无 handler）。
- **B. 重建 FD 本身就不交棒（原因未证实）**
  `X1`/`X2` 只换了 FV 里的 UFSDxe 槽、**没有任何 FB 写**，仍然不交棒；而 10-30 原件交棒。
  ⇒ 需要一次**主机侧字节级对比**：同一源、重建 FD vs `SM8750_EFI-A2.fd`（`eb00db73…`），
  逐项比 FV 大小/对齐/checksum/FV 头/文件序、以及构建器的 clang 版本与时间戳。**未做**。

## §2 设备恢复过程（供复用）

A2 交棒后 ABL 回落 **stock Android**（`ro.boot.slot_suffix=_a`、`sys.boot_completed=1`），
且把 **`slot-unbootable:b` 置 `yes`**、`current-slot=a`。本机 Android 侧 **adb 可直接用**（无需按键！）：

```
adb -s HA2EXB0E shell getprop ro.boot.slot_suffix   # _a
adb -s HA2EXB0E reboot bootloader                   # 6 s 到 fastboot
fastboot --set-active=b                             # OKAY
fastboot getvar slot-unbootable:b                   # no（置 active 会自动清）
fastboot reboot                                     # 12 s 回 Linux
```
终态：`boot_id` `baf06456`、`uname -v` `#1 … 19:00:42`、根 `/dev/sda17` ext4、面板 `connected`、
`boot_b` 仍 `aedae5f1…`、失败单元 0。**这条恢复路径比「按键进 fastboot」快且无需人工**，应写进 UEFI 实验单。

## §3 下一步（主机侧，不碰设备）

1. **字节级对比**（最高优先）：`SM8750_EFI-A2.fd` vs 同一源重建的 FD —— FV 大小、`FVMAIN` 头字段、文件序、校验和、
   以及构建环境（clang 版本、时间戳、`-n 12` 并行度是否影响布局）。目标：找出「重建即失效」的那一个差异。
2. **确认 FB 写的真实死因**：用「写到一个已知安全的 DDR 暂存区」做对照（不改 FB），
   若对照组交棒 ⇒ 坐实是 FB 地址本身的问题；若不交棒 ⇒ 问题在「PrePi 里多一行 C 代码」这个更粗的层面。
3. **在拿到 1/2 结论前，不再打任何「重建 + 插桩」组合**——每发都要用户盯着屏幕并可能落到 Android，成本太高。

## §4 证据
`reports/artifacts/uefi-vis-r2-20261031/`（VIS-R2 载荷 + usb 采样）、
`reports/artifacts/uefi-vis-control-20261031/`（`SHA256SUMS`、`boot.txt`、`usb.txt`、`recover.txt`、`post.txt`）。
