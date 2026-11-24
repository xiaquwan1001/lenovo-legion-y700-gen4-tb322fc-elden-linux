# #712 「Linux → BL 只能物理键」是错的：`reboot bootloader` 一直可用

> 更正条目，对应旧条目 #690（`322-主线核无vendor-restart2软路径不存在.md`）与 #701。编号只增不改。

## 判据（2026-11-23 实测，同机同线，`fastboot reboot` 回日常核后逐条做）

| # | 内核 | vendor-reset 钩子 | 命令 | 结果 |
|---|---|---|---|---|
| 1 | 7.4-rc3 + 本仓 vendor-reset 补丁 | 有 | `reboot bootloader` | 21 s 进 fastboot |
| 2 | 7.4-rc3，**补丁已 stash 重编**（`Image` 无 `SYSTEM_RESET2 vendor reset`） | 无 | `reboot bootloader` | 进 fastboot |
| 3 | **vk192 日常核**（`7.3.1-debug-vk189-suspend…`） | 无 | `reboot bootloader` | 30 s 内进 fastboot |
| 4 | 同上，**同一次启动**先发 | 无 | `systemctl reboot` | **回 Linux** |
| 5 | 同上，紧接步骤 4 | 无 | `reboot bootloader` | **进 fastboot** |

4/5 是同启动内对照，唯一变量 = reboot cmd 字符串 ⇒ 归因确定：**ABL 依 `reboot(2)` 的 reason 字符串选路**，
内核侧不需要任何钩子（上游 `psci_sys_reset()` 根本不看 cmd，`grep '"bootloader"' drivers/firmware/psci/psci.c` = 0）。

## 为什么旧判据会判错（编号见条目定义表）

旧条目的判据是**静态的**（`kallsyms` 里 vendor reset 处理函数 0 命中、`dmesg` 无 `SYSTEM_RESET2 vendor`），
而 `scripts/elden-to-bootloader.sh` 当时**默认 fail-closed**：无钩子 ⇒ 自动退 BCB 臂、`ALLOW_SOFT_RESET=1` 才发软命令。
⇒ 那条命令**很可能从未真正发出**，「设备不动」是没发命令的结果，不是路径不存在。

## 处置

- `scripts/elden-to-bootloader.sh`：`--auto` **恒走 psci 臂**（= `systemctl reboot bootloader`），头注已重写；已部署设备。
- 主判据改为端到端：发命令 → 主机侧 `timeout N fastboot devices` 见 `HA2EXB0E` 即 PASS；**不要**再用 kallsyms 静态判据。
- `reboot edl` 尚未实测（EDL 只能 qdl 救，需用户在场 + 备份齐）。
- 影响面：#690/#701 的「唯一可靠路径 = 物理键」在 RUNBOOK/scripts 里的引用需逐处更正。

## 2026-11-24 补充（实机）：命令形态随 systemd 版本变，别照抄

本条的实测命令写的是 `systemctl reboot bootloader`。**在现役 Debian trixie 根（systemd 257）上这条会失败**：

```
# 设备上实测（2026-11-24）
$ systemctl reboot bootloader
Too many arguments.
rc=1          # 设备不动
$ systemctl reboot --reboot-argument=bootloader
rc=0          # ~9 s 进 fastboot（HA2EXB0E 出现在 fastboot devices）
```

原因：systemd 257 把 `reboot` 的位置参数改成了 `--reboot-argument=ARG`（`systemctl --help` 里能看到该选项，
位置参数形态被拒）。**结论不变**（软路径可用、不需要 vendor-reset 钩子、不需要物理键），只是命令形态要跟着 systemd 走。

处置：唯一实现 `scripts/lib-soft-bootloader.sh` 的 `sb_reboot_cmd()` 会先探一次
`systemctl reboot --help | grep -- --reboot-argument`，有就用新形态、没有回退位置参数；
已同步 4 个直接内联该命令的脚本（`uefi-oneshot` / `uefi-flashed-trial` /
`android-v3-bringup-walkthrough` / `elden-to-bootloader`）与活文档（`AGENT-OPS` §2、`RUNBOOK` §8、
`LINUX-STATE-REPRO`）。教训：**「某条命令实测可用」要连 systemd/工具版本一起记**，否则换根/升级后静默失效。
