# #702 `--set-active=a` 后 ABL 直接走 recovery_a；而 recovery 里的 `adb reboot bootloader` 会改写 misc BCB

> **⚠ 2026-11-21 更正（#703）**：本条引用的 `logfs` 原文（`Loading Image recovery_a` / `Booting from slot (_a)` /
> `factory_build = 1`）**不是这次启动产生的** —— `logfs` 只有 **segment 0** 会被 ABL 重写，seg≥1 与出厂包逐段字节相同（`PITFALLS #703`）；
> 且 `Loading Image <part>` 是每次任务启动的头部探测（b 槽同样有 `recovery_b`），真 recovery 会打 `Recovery:1`。
> ⇒ 本条**目前剩下的弱证据只有**：`adb devices` 当时枚举为 `HA2EXB0E recovery`（需重现才算硬证）；
> 「ABL 选 recovery_a」属**无证据命题**。H1/H2 判别改为先做 **H5（刷原厂 `vbmeta_a`）**，见 `reports/android-a-slot-laneC-20261121.md`。

- 日期：2026-11-21（设备在线轮，用户两次物理键进 BL 配合）
- 现象/判据：
  1. 在 fastboot 里**先** `fastboot flash misc <4 KiB 零>`（OKAY，清 BCB）**再** `fastboot --set-active=a` + `fastboot reboot`
     ⇒ 设备仍落 **recovery**：`adb devices` = `HA2EXB0E recovery`；logfs 原文 `Loading Image recovery_a` /
     `Booting from slot (_a)` / `BootLinux: factory_build = 1`。⇒ 落 recovery **不是** BCB 污染造成的。
  2. 从 recovery 出来用 `adb -s HA2EXB0E reboot bootloader`，随后在 Linux 读 misc = **`bootonce-bootloader`**（19 B）。
     对照：Linux 侧把 misc 清 0 后**静置 20 s 仍为 0**，`qbootctl -m` 也不写它 ⇒ 写者 = recovery 的 reboot 处理。
- 两个候选解释（未判别，判别实验 = S3 回写原厂 super 对照）：
  H1「`--set-active` 后 ABL 自己写 `boot-recovery`，按设计进 recovery 完成切换」；
  H2「a 槽 Android（v3 slim super + 自签 vbmeta_a flags=1）自身不可启，ABL 以 recovery 兜底」。
- 纪律：
  * 从 recovery 出来**先清 BCB**（Linux: `dd` 4 KiB 零；fastboot: `fastboot flash misc` 4 KiB 零）再谈样本；
  * 别把 `misc == bootonce-bootloader` 当作「板子会进 fastboot」的证据 —— ABL **不采纳**（#701），
    它只是 recovery/工具链留下的痕迹；
  * `fastboot flash misc` 是 fastboot 侧唯一可用的 BCB 清法（分区 1 MiB，但 ABL 只看头 4 KiB；本机头 4 KiB 本就全零）。
