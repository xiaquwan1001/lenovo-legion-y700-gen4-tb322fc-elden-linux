# #701 现役 vk192 上「Linux → fastboot」三条软路径全灭：BCB 复测不采纳、qbootctl 写失败、PSCI 钩子缺 ⇒ 只能物理键

- 日期：2026-11-21（设备在线轮，用户在场）。目的 = 让 AVB 债验收与 Android S1–S5 不必人肉按键。
- 三条臂与判据（逐条可复跑）：
  1. **PSCI**：`grep -c 'psci_elden_try_vendor_reset' /proc/kallsyms` = 0、`dmesg | grep -c 'SYSTEM_RESET2 vendor reset'` = 0、
     `/proc/device-tree/psci/` 无 `qcom,reset-mode` ⇒ 现役主线核无 vendor reset 钩子（#690 同源），`systemctl reboot bootloader` 只会普通重启。
  2. **BCB**：写 `misc` 头 4 KiB `command="bootonce-bootloader"`（读回校验通过）→ `systemctl reboot` → **普通重启**（host 侧看到 `uptime 33245 s → 18 s`、无 `fastboot devices`）；
     用户目视「只是普通重启」⇒ ABL 不采纳（与 Q23 2026-10-03 结论一致，本轮**可复现**）。
     注：**清 BCB 只写头 4 KiB 是安全的** —— 本机 misc 头 4 KiB 本来就全零（slot 元数据不在这一段），所以清零不会碰 qbootctl 的计数区。
  3. **`qbootctl -u b`**（标 active 槽 unbootable 逼 ABL 停 fastboot）：`gpt_disk_commit: Invalid args` /
     `update_slot_attribute: Failed to commit disk` / `SLOT _b: Failed to set as unbootable`，随后 `Bootable : 1` 未变。
     原因 = `qbootctl` 要同时改 UFS 启动 LUN，bLun 改不了时默认拒写；`-i`（只写 GPT 头）**未测**。
- 结论/纪律：**vk192 上没有软路径**。要进 fastboot 只能物理键（长按电源 10 s 关机 → 按住音量上+电源）。
  agent 侧**不再盲试**软路径；每次测试前先跑 `scripts/to-bootloader.sh --dry-run` 看能力自检结论，别把「没进 fastboot」当设备问题。
- 工具（本轮交付，在有钩子的核上仍有用）：设备侧 `scripts/elden-to-bootloader.sh`（能力自检 + 两臂 + 备份/读回校验 + `--clear-bcb`），
  主机侧 `scripts/to-bootloader.sh`（三态判据：fastboot=rc0 / 回 Linux=rc10 且自动清 BCB / 都没有=rc11）。
- 恢复「一键进 fastboot」的三条后续路线（按代价）：换回带钩子的核（补丁现成，需重放内核树）> `qbootctl -i -u <slot>`（故意标不可启，
  成功后必须 `fastboot --set-active=b` 复原，见 #677）> EDL dload-mode（只能进 9008，未真机验证）。

## 2026-11-24 更正（第一条腿作废）

「三条软路径全灭」里**第一条腿**（PSCI 钩子缺 ⇒ 无软路径）已被 **#712**
（`345-Linux到BL一直可用-推翻只能物理键.md`）推翻：`systemctl reboot bootloader` 一直可用。

- 仍成立：`misc` BCB `bootonce-bootloader` **ABL 不采纳**（写后读回校验通过仍普通重启）；
  `qbootctl -u b` / `-s` 写失败（`gpt_disk_commit: Invalid args`，要同时改 UFS bLun）⇒ #701 现在只剩
  「**切槽写原语**不可用」这个含义（切槽仍必须到 fastboot 用 ABL 的 `--set-active`）。
- 进 fastboot 的唯一实现 = `scripts/lib-soft-bootloader.sh`；脚本层 #701 fail-closed 门已于 2026-11-24 全部删除。
- 物理键组合：**音量下 + 电源**（用户实操记录）；本条旧正文的「音量上 + 电源」是笔误。
