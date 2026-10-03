# 复盘：桌面关机假成功 — busybox→PID1 vs elogind（2026-10-03）

> 溯源专题（只增不改）。权威：`PITFALLS.md` #89、`TASKS.md` G1-25、`scripts/fix-logind-poweroff.sh`。
> 关联：`archive/topics/复盘-2026-10-03-持久化与睡眠.md` §6（elogind 引入与第一轮误判）。

## 1. 现象

- 用户：长按电源键 →「立刻关机」（phosh 电源菜单）**无反应**；改请用户测，仍不关机。
- 更早一轮把 elogind 起来、`HandlePowerKey=ignore` 后，曾以为修好；实测仍不行。

## 2. 初始错误（前一轮）与推翻

前一轮诊断：`sleep` 的 inhibitor 正常、仅 `shutdown` 返回 `OperationInProgress`，
归因于「电源键被 elogind 抢先处理/占位」，用 `kill -9` + 重启 elogind「修复」。
**只治了症状**：`kill -9` 只清掉内存态，重新触发一次关机就又卡回去。

## 3. 本次取证（决定性）

设备 U2，内核 `7.2.0-debug-ge72a036ed4be-dirty`（vk41），elogind 255.24。

### 3.1 elogind 内部态
```text
PreparingForShutdown = true
Inhibit("shutdown")  -> org.freedesktop.login1.OperationInProgress
CanPowerOff          = yes
DelayInhibited       = "sleep"     # 并无 shutdown delay inhibitor
BlockInhibited       = "handle-power-key:handle-suspend-key:handle-hibernate-key"
```
对照 elogind 源码（v255.24 `src/login/logind-dbus.c` `method_inhibit`）：
`OperationInProgress` 仅当 `m->delayed_action && delayed_action->inhibit_what & w` 时抛出。
即 **elogind 有个 shutdown 动作卡在 `delayed_action` 里**，且 `action_job` 未清。

### 3.2 内核 dmesg（全 boot 的 elogind 日志）
```text
[    9.8] elogind[504]: Watching system buttons on /dev/input/event0 (pmic_pwrkey)
[   38.8] elogind[504]: Power key pressed short.
[   42.2] elogind[504]: The system will power off now!
[   42.2] elogind[504]: System is powering down.
[   42.2] e-poweroff[2483]: Operation 'poweroff' finished.
[  388.8] elogind[5343]: Power key pressed short.
[  391.9] elogind[5343]: The system will power off now!
[  391.9] elogind[5343]: System is powering down.
[  391.9] e-poweroff[5421]: Operation 'poweroff' finished.
[  410.1] loginctl[7036]: Failed to power off system via elogind: There's already ...
[  412.5] loginctl[7040]: Failed to power off system via elogind: There's already ...
```
**关键**：每次都打印 `System is powering down.`，但**从无 `reboot: Power down`**（内核 `kernel_power_off` 的
`pr_emerg("Power down\n")`）→ **从未真正调 `reboot(2)`**。

### 3.3 helper 实证（strace）
```text
$ strace -e trace=reboot,kill /sbin/poweroff -n
kill(1, SIGUSR2) = 0
+++ exited with 0 +++          # 没调 reboot(2)！
$ strace -e trace=reboot,kill /sbin/reboot -n
kill(1, SIGTERM) = 0 ; exited 0
$ strace -e trace=reboot,kill /sbin/halt -n
kill(1, SIGUSR1) = 0 ; exited 0
```
`busybox poweroff|reboot|halt` **不带 `-f`** 走的是「告诉 init 去做」的老协议：
给 **PID 1** 发信号。本机 PID 1 = `/bin/sh /init`（**不是 busybox init**），不处理这些信号 → 什么也没发生。
`elogind` 用的是**编译期绝对路径** `/sbin/{poweroff,reboot,halt}`（`meson poweroff-path`，与 PATH 无关）。

## 4. 根因

| # | 事实 |
|---|---|
| R1 | elogind 的 poweroff/reboot/halt helper = busybox applet，**不带 `-f` 只 `kill(1, SIG...)`**；PID 1 是 shell → 关机/重启**假成功** |
| R2 | 上述假成功让 elogind 对**非 sleep** 动作不清 `action_job/delayed_action`（父进程 SIGCHLD 分支要求 `sleep_operation != INVALID`，poweroff 恰为 INVALID）→ **永久卡 `OperationInProgress`** |
| R3 | （诱因，已规避）`HandlePowerKey` 默认 `poweroff`：开机那一次电源键（`pmic_pwrkey` 上报 KEY_POWER）会触发真关机；已用 `logind.conf` 的 `HandlePowerKey=ignore` 关闭 |

> 与内核/vk41 **无关**：vk41 只改 `psci_sys_reset`（RESTART2 vendor reset），不碰 POWER_OFF。

## 5. 修复

`scripts/fix-logind-poweroff.sh`（幂等，`start-desktop.sh` 在启动 elogind 前调用）：

```sh
for a in poweroff reboot halt; do
    f=/sbin/$a
    [ -L "$f" ] && ln -sfn "$(readlink "$f")" "$f.orig"
    rm -f "$f"                                   # 必须先删符号链接！
    printf '#!/bin/sh\nexec /bin/busybox %s -f "$@"\n' "$a" > "$f"
    chmod 755 "$f"
done
```

- **坑**：直接 `cat > /sbin/poweroff`（符号链接）会穿透截断 `/bin/busybox`（本次报 `Text file busy` 才幸免）。
- 验证（不动真格）：`strace -e inject=reboot:error=EINVAL /sbin/poweroff -n`
  → `reboot(LINUX_REBOOT_MAGIC1, MAGIC2, LINUX_REBOOT_CMD_POWER_OFF) = -1 EINVAL (INJECTED)` ✅
  （`reboot`/`halt` 同理映射到 `CMD_RESTART`/`CMD_HALT`）。
- 内核侧 `pm_power_off = psci_sys_poweroff`（`psci_0_2_set_functions()` 无条件注册）→ 最终走 PSCI `SYSTEM_OFF`。

## 6. 待办 / 未核实

- [ ] **真机验证**：`ssh root@192.168.7.1 loginctl poweroff`（应真断电）；以及长按电源键→phosh 电源菜单→「立刻关机」。
- [ ] 若 PSCI `SYSTEM_OFF` 在本固件不被支持（pm_power_off 返回），arm64 会转入 `machine_halt()` 自旋 → 需长按硬件复位；届时改用别的关机路径（如 vendor reset 到某低功耗态）再议。
- [ ] `elogind 卡死` 的 R2 只在**关机失败**时才有意义（成功关机=断电，状态无意义）；若将来关机偶发失败，需重启 elogind 清态。

## 7. 操作记录

- elogind 重启若干次排查；曾用假 `poweroff`（`/usr/local/sbin/poweroff`）验证 PATH 无关（elogind 走绝对路径，未命中），
  该假桩**已删除**。
- 调试期 elogind 以 `SYSTEMD_LOG_LEVEL=debug` 跑（日志 `/root/elogind-debug.log`，tmpfs 外的持久盘），重启后由 start-desktop.sh 正常拉起。
