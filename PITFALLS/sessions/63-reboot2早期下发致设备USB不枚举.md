# #368 `reboot2 bootloader` 在设备刚硬复位后「早期」下发 ⇒ 不进 fastboot、USB 完全不枚举

## 症状

`scripts/n5b-vk64-death-rate.sh`（以及任何「死亡后自动重进 fastboot」的循环）在设备**刚硬复位、内核才起来 ~11 s** 时下发 `reboot2 bootloader`：

- 串口尾部只看到 `[KD] stage=11a before device_shutdown` + 若干 `sd: Synchronizing SCSI cache`，随后串口关闭；
- 之后 `fastboot devices` 空、`lsusb` 无 `18d1/05c6`、无 `/dev/ttyACM*`、`ping 192.168.7.1` 不通，**持续 10 分钟不恢复**；
- 必须**人工长按电源 ~15 s 强制关机再开机**才能回来。

## 根因（现状口径）

【已证实】现象与时序（`logs/n5b-vk64-20261023-133658.log.serial`、2026-10-23）。

【推测】`reboot2 bootloader` 走 PSCI `SYSTEM_RESET2` vendor reset；在 `device_shutdown()` 阶段就把设备树里的 UFS/USB 控制器拆掉，而 ABL 这次没有正常接管 fastboot gadget（早期复位/供电状态未稳）。与 `PITFALLS #166`「`reboot2` 暖复位粘坏态」同族，但这里是**热路径 + 早期时序**，后果更重（USB 全失，连串口都没有）。

## 规则

① **唯一入口 = `scripts/to-fastboot.sh`**（内部 `eldroid-bootctl reboot bootloader` + 6 s sysrq-b 看门狗，见 #542）。`reboot2 bootloader` 已停用：两者内核路径相同，`reboot2` 只是少了兜底看门狗（裁决 = `TASKS/README.md` §4、`reports/script-redundancy-audit-20261112.md` §1）。时序门（`wait_ssh` + `uptime` ≥ 60 s + `pidof phoc` 非空）**继续保留**，作用是降低撞上关机路径卡死的概率，不是「等够就改用 reboot2」。
- `boot_vk64` 类函数先看当前内核：若已是目标内核，直接复用（脚本 2026-10-20 已加这条，但仍需上面的时序门）。
- 自动化循环里 `SETUP-FAIL` 上限保持 2 —— 第 2 次不通就停，**不要重试**（重试会继续打设备，且此时设备已无通道可判断）。宁可人工确认。
- 判「设备彻底没了」的三件套：`lsusb | grep -E '18d1|05c6'`、`ls /dev/ttyACM*`、`ping 192.168.7.1`。三者全空 = 物理断电复位，别在主机侧继续折腾（EDL 也不会出现，除非真的是 EDL 模式）。

## 相关

- `scripts/n5b-vk64-death-rate.sh`（本轮修了 ScreenSaver no-op 与空读数误判；时序门仍未加）
- `reports/q24-n5b-20261023.md`
- `PITFALLS #542`（**同一故障**：内核路径同为 RESTART2→PSCI SYSTEM_RESET2，差别只在 6 s sysrq-b 看门狗；`eldroid-bootctl` 已内置 ⇒ 唯一入口 `scripts/to-fastboot.sh`，`reboot2 bootloader` 停用，裁决见 `TASKS/README.md` §4 与 `reports/script-redundancy-audit-20261112.md` §1）
- `PITFALLS #166`（暖复位粘坏态）、`#363`（nohup 无人看管）

---

## 2026-11-12 复现（**长 uptime 也中招**，原口径「刚硬复位 ~11 s 才触发」不完整）

- 现场：设备 uptime ≈ 6 h（19:41 之前一直正常，Phosh/fcitx5 在跑），文本 `reboot2 bootloader` 一次
  ⇒ 上一轮 journal 到 `19:41:04` 结束；之后 **19:41–20:05 主机侧 `journalctl -k` 零 USB 事件**
  （无 `18d1`/`05c6`/`1d6b`）⇒ fastboot gadget 根本没起来；屏幕不亮（无背光）。
- 恢复：用户 ~20:05 人工断电重开 ⇒ 20:05:59 短暂出现 Android gadget（`18d1:d00d`，9 s），
  20:06:50 回到 Linux gadget（`1d6b:0104`），20:07 起 Linux（`uptime` 可证）。
- 结论：**触发条件不止「刚复位早发」**，长 uptime 下也可能中招；判据仍是「USB 全不枚举 + 无串口」
  ⇒ 不要试图重试，直接请用户断电。**下发前无法预判**，因此把「进 fastboot」当作有物理依赖的动作、
  在用户在场时做。
- 附带发现（同轮）：Linux 侧 USB gadget 的 serial 是**写死 `HA2CB1KY`**（`/usr/local/sbin/usb-gadget:41`），
  与真实 SN `HA2EXB0E`（ABL 在 cmdline 里给）不同 ⇒ 主机侧按 serial 认设备会认错，**只能按 USB 端口/product 串判**。
  这也是本轮把另一台华为手机（`MDX5T20730009849` = ELS-AN00）误当目标板、把手机 `adb reboot bootloader`
  送进 fastboot 的原因（已 `fastboot reboot` 恢复）。
