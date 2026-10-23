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

① **死亡后不要立刻 `reboot2 bootloader`**：先 `wait_ssh` 成功 **且** `uptime` ≥ 60 s **且** `pidof phoc` 非空，再进 fastboot 流程。
- `boot_vk64` 类函数先看当前内核：若已是目标内核，直接复用（脚本 2026-10-20 已加这条，但仍需上面的时序门）。
- 自动化循环里 `SETUP-FAIL` 上限保持 2 —— 第 2 次不通就停，**不要重试**（重试会继续打设备，且此时设备已无通道可判断）。宁可人工确认。
- 判「设备彻底没了」的三件套：`lsusb | grep -E '18d1|05c6'`、`ls /dev/ttyACM*`、`ping 192.168.7.1`。三者全空 = 物理断电复位，别在主机侧继续折腾（EDL 也不会出现，除非真的是 EDL 模式）。

## 相关

- `scripts/n5b-vk64-death-rate.sh`（本轮修了 ScreenSaver no-op 与空读数误判；时序门仍未加）
- `reports/q24-n5b-20261023.md`
- `PITFALLS #166`（暖复位粘坏态）、`#363`（nohup 无人看管）
