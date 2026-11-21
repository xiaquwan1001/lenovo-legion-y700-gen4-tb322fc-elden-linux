# Linux → fastboot（BL）软路径：三条臂全灭，现役 vk192 只能物理键

> 2026-11-21（设备在线轮，用户在场）。目的 = 给「AVB 债验收（`fastboot flash vbmeta_b` + `fastboot boot`）」
> 与「Android a 槽 S1–S5」找一条**不用人肉按键**的进 fastboot 通道，并把工具部署到设备上。
> 结论一句话：**在 vk192 上没有任何可用的软路径** —— 三条臂逐一实测/取证否掉，上机测试必须物理键。

## 0. 数字结论

| 臂 | 机制 | 结果 | 证据 |
|---|---|---|---|
| A. PSCI SYSTEM_RESET2 vendor reset | `reboot bootloader` → reset_type `0x80010001` | **不可用（内核无钩子）** | `/proc/kallsyms`：`psci_system_reset2_supported` 在、`vendor_reset|restart2` 其它命中 **0**；`dmesg \| grep -c 'SYSTEM_RESET2 vendor reset'` = **0**；DT `/proc/device-tree/psci/` 无 `qcom,reset-mode`。与 PITFALLS **#690** 一致 |
| B. `misc` BCB `bootonce-bootloader` | 写 misc 头 4 KiB `command="bootonce-bootloader"` → reboot，ABL 应进 fastboot | **ABL 不采纳 = 普通重启** | 写后读回 `command="bootonce-bootloader"`（校验通过）；reboot 后 host 观察 → 设备回 Linux（`uptime 33245 s → 18 s`）。用户目视确认「只是普通重启」。与 Q23（2026-10-03）结论一致，本轮**可复现** |
| C. `qbootctl -u b`（把 active 槽标 unbootable 逼 ABL 进 fastboot） | Qualcomm bootctrl HAL 写 GPT 属性 | **写失败** | `qbootctl -u b` → `gpt_disk_commit: Invalid args` / `update_slot_attribute: Failed to commit disk` / `SLOT _b: Failed to set as unbootable`（随后 `Bootable : 1` 未变）。原因见 `qbootctl -h`：它要**同时改 UFS 启动 LUN**，默认在 bLun 改不了时拒写；`-i`（「仍写 GPT 头，即使 bLun 改不了」）**未测** |

⇒ **三条路都不通**。items 2（AVB 债验收）与 3（Android S1–S5）的**真实前置 = 物理键**：
长按电源 ~10 s 关机 → 按住 **音量上 + 电源** 至 fastboot 屏（`DEVICE/README.md` §1.6 的在线判据里 `fastboot devices` 见 `HA2EXB0E`）。

## 1. 本轮交付（工具本身在「有钩子的核」上仍然有用）

| 件 | 位置 | 作用 |
|---|---|---|
| 设备侧单入口 | `scripts/elden-to-bootloader.sh` → 设备 `/usr/local/sbin/elden-to-bootloader` | **能力自检**（kallsyms 符号 / dmesg pr_info）→ 有钩子走 `systemctl reboot bootloader`，无钩子自动退 BCB 臂；`--dry-run` 只打印；`--clear-bcb` 只清 4 KiB；写 misc 前**备份原 4 KiB**（全零则跳过）并**读回校验** command 字符串；全程 `conv=fsync` + `sync` |
| 主机侧驱动 | `scripts/to-bootloader.sh` | 设备锁 + 缺件自动部署 + 三态判据（fastboot 上线 = rc0 / 回 Linux = **rc10 且自动清 BCB** / 都没有 = rc11）+ 成功后打印「先 `fastboot reboot-bootloader` 再灌件」（PITFALLS #650）与「拿 shell 先 `slot-switch.sh status`」（防 retry 抽干 #672） |

实测记录（本轮）：

```
$ bash scripts/to-bootloader.sh --dry-run
[to-bl] 设备在 Linux：uptime=33243s、UTS=7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0
[elden-to-bootloader] 内核 PSCI vendor-reset 钩子: 无（UTS 7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0）
[elden-to-bootloader] 自动选臂: --bcb
[elden-to-bootloader] 原 BCB 全零（无需备份）
[dry] 写 misc[0:32]="bootonce-bootloader" + 其余 4 KiB 清零，然后 systemctl reboot

$ bash scripts/to-bootloader.sh --arm bcb
[to-bl] 发重启（arm=bcb）：设备会断连，随后等 fastboot…
[to-bl] ⚠ 设备回到了 Linux（uptime 18s < 之前 33245s）⇒ arm=bcb 对本核**无效**
[to-bl]   结论登记：BCB bootonce-bootloader 未被 ABL 采纳（与 Q23 一致）

$ qbootctl -u b            # 臂 C
gpt_disk_commit: Invalid args
update_slot_attribute: Failed to commit disk
SLOT _b: Failed to set as unbootable
```

## 2. 收尾态（实测，本轮结束）

- 设备已回 Linux 且干净：`uptime 44 s`、BCB 头 4 KiB **nonzero=0**、`qbootctl` = `_a: Active0/Succ0/Bootable1`、`_b: Active1/Succ1/Bootable1`、
  `is-system-running=running`、`graphical.target=active`。
- 设备侧两件工具在位：`/usr/local/sbin/elden-to-bootloader`（chuang 755）、`/usr/local/sbin/suspend-resource-sample.sh`；
  T9 timer `active`、`/var/lib/elden/suspend-resource.tsv` 5 行（本轮 T9 恢复见 `reports/t9-sampler-restored-20261121.md`）。

## 3. 以后要恢复「一键进 fastboot」的可能路线（按代价排序，均未做）

1. **换回带钩子的核**（`v7.2-elden` 基线 / `elden/vk4x…vk6x` 源，或等上游 reboot-mode 13 补丁系列合入后重基到主线）——
   钩子代码现成：`patches/kernel-history/*/0003-elden-vk41-minimal-PSCI-SYSTEM_RESET2-vendor-reset-h.patch`。
   代价 = 一次内核重建（当前 `build/` 已清，需重放 payload，属 M1 线重活）。
2. **`qbootctl -i -u <slot>`**（强行只写 GPT 头，接受 UFS bLun 不变）—— 机制上能让 ABL 看到「active 槽不可启」而停 fastboot；
   但它是**故意把当前槽标成不可启**，成功后必须 `fastboot --set-active=b` 复原（#677：会同时清 unbootable + retry=7）。
   风险：若 ABL 反而去启 a 槽（Android 当前也起不来）会多绕一圈；**必须在用户在场时试**。
3. **EDL 9008（`reboot edl`）**：走 `qcom_scm` download_mode + TCSR（`qcom,dload-mode`，`patches/edl-dload-20261020/`），
   同样依赖本核 DT 支持，**从未真机验证**；且 9008 只能进 EDL，不是 fastboot。

## 4. 对 items 2 / 3 的影响（下轮怎么走）

- **item 2（AVB 债验收）**：件已就绪（`out/vbmeta-b/vbmeta_b-flags3.img`）。设备窗口里由用户按物理键进 fastboot，然后
  `fastboot -s HA2EXB0E flash vbmeta_b out/vbmeta-b/vbmeta_b-flags3.img` → `fastboot -s HA2EXB0E reboot-bootloader` →
  `fastboot -s HA2EXB0E boot bootslot-b/boot_b.img`（判据：`OKAY` = 债了结；仍失败 = 归因排除本项）。
  回退件：`logs/forensics-20261120-2210/vbmeta_b.img`（在机现役）或 `backup/vbmeta_b-20261110.img`。
- **item 3（Android S1–S5）**：执行包 `scripts/android-v3-bringup-walkthrough.sh` 已就绪（本轮另修了前置校验的
  `fastboot` 假 MISS，PITFALLS #699）；仍需物理键进 fastboot，且 `boot_a` 属性每轮上机前必须复位（PITFALLS #695）。
- 两件事都**会打断当前桌面 1–2 h**，需要你给窗口 + 按键；agent 侧不再盲试软路径。
