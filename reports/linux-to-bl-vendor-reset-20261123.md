# Linux → BL 软路径：**一直可用**，此前的「只能物理键」结论被推翻（2026-11-23）

> 一句话：`systemctl reboot bootloader`（= `reboot(2)` 带 cmd 字符串）在本机**任何在册内核**上都能进 fastboot，
> **不需要** vendor-reset 钩子，也**不需要**物理键。`PITFALLS #690/#701` 的结论因此作废。

## 0. 证据矩阵（同机同线，`fastboot reboot` 回日常核后再做下一行）

| # | 内核 | vendor-reset 钩子 | 发出的命令 | 结果 |
|---|---|---|---|---|
| 1 | `7.4.0-rc3-g7a-…-reset-20261123`（**带**本仓补丁） | 有 | `reboot bootloader` | **21 s 进 fastboot** |
| 2 | 同上，**补丁 stash 掉后重编**（`Image` 无 `SYSTEM_RESET2 vendor reset` 串） | 无 | `reboot bootloader` | **进 fastboot** |
| 3 | `7.3.1-debug-vk189-suspend…`（= 日常 vk192） | 无 | `reboot bootloader` | **30 s 内进 fastboot** |
| 4 | 同上，**同一次启动内**先发无参 `systemctl reboot` | 无 | `systemctl reboot` | **回 Linux**（`up 0 minutes`，UTS 不变） |
| 5 | 同上，紧接步骤 4 的同一启动 | 无 | `reboot bootloader` | **进 fastboot** |

步骤 4/5 是**同启动内对照**：唯一变量就是 reboot cmd 字符串 ⇒ 归因确定。

## 1. 机制（据实测推断，非源码实证）

- `/usr/sbin/reboot` → `systemctl`；`systemctl reboot <arg>` 把 `<arg>` 作为 reboot reason 传给 `reboot(2)`，
  内核 `machine_restart(cmd)` → `psci_sys_reset(data=cmd)`；上游 psci 只按 `reboot_mode` 决定 warm/architectural，
  **不使用 cmd 字符串**（`grep 'bootloader' drivers/firmware/psci/psci.c` = 0）⇒ 内核行为在两种命令下相同。
- 因此差异只能来自 **ABL/XBL 侧**：它读取 reboot reason（字符串）后决定进 fastboot。
- 未做的实证：串口 `ttyGS0` 抓取失败两次（reboot 时 USB 重新枚举，`cat` 立即 EOF）；`ramoops` 在 vk192 未启用，
  `/sys/fs/pstore` 空 ⇒ 没有 `pr_info` 级文本证据。**但步骤 4/5 的行为对照已足以定论。**

## 2. 旧结论为何错

`#701` 表里「臂 A：PSCI vendor reset」判据是**静态的**（`kallsyms` 里 vendor reset handler 计数、`dmesg` 里
`SYSTEM_RESET2 vendor` 计数），并且 `scripts/elden-to-bootloader.sh` **默认 fail-closed**（无钩子自动退 BCB 臂，
`ALLOW_SOFT_RESET=1` 才发软命令）⇒ **那条命令很可能从未真正发出过**，于是得出「设备不动」。
本次是第一次真正端到端发出 `reboot bootloader`。

## 3. 交付

| 件 | 变化 |
|---|---|
| `scripts/elden-to-bootloader.sh` | 头注重写（含更正说明）；`--auto` **恒走 psci 臂**（不再因无钩子退 BCB）；已部署到设备 `/usr/local/sbin/`，`--dry-run` 自检通过 |
| `patches/local/psci-vendor-reset-20261123/` | 保留（对 `reboot edl` 可能仍有用、且便于对照实验），README 已写明「**不是进 fastboot 的必要条件**」 |
| `out/g7-reset-20261123/` | `boot-g7a-reset.img`（带钩子，sha `647784b7…`）+ `boot-g7a-ctl.img`（对照，无钩子，sha `f79dcbcb…`） |
| `PITFALLS` | 新增更正条目（见 §4） |

## 4. 对待办的影响

1. **`reboot edl` 未测**：若 ABL 同样按字符串选路，`reboot edl` 应进 EDL（9008）。风险 = EDL 下只能 qdl 救，
   需用户在场 + 备份齐再验。
2. `#690/#701` 的「唯一可靠路径 = 物理键」表述在 `PITFALLS`/`scripts`/`RUNBOOK` 里仍有引用，需在本轮之后统一扫一遍替换。
3. `scripts/to-bootloader.sh`（主机侧）可简化：等 fastboot 的三态判据保留，软路径默认值改回「直接发」。
