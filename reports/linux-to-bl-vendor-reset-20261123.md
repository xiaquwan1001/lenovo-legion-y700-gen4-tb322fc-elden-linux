# Linux → BL 软路径恢复：PSCI SYSTEM_RESET2 vendor reset 钩子实测成功（2026-11-23）

> 背景：`PITFALLS #690/#701` 判定现役 vk192 **无 vendor reset 钩子** ⇒ 三条软路径全灭、只能物理键。
> 本轮把历史补丁（vk41 时期）叠回干净上游树，**实测打通**。

## 0. 数字结论

| 判据 | 结果 |
|---|---|
| **`reboot bootloader` 是否进 fastboot** | ✅ **是** —— 发命令后 **~21 s** `fastboot devices` 出现 `HA2EXB0E`（此前该路径只回普通重启） |
| 件 | `out/g7-reset-20261123/boot-g7a-reset.img`（sha `647784b7c7fc7a5b…`），`fastboot boot` 零写盘 |
| 内核 | `7.4.0-rc3-g7a-dwc3v11-reset-20261123-dirty`（7.4-rc3 `aebb727447` + elden DTS + 补丁） |
| 补丁 | `patches/kernel-history/elden_wifibmiss-v1v2/0003-elden-vk41-minimal-PSCI-SYSTEM_RESET2-vendor-reset-h.patch`（83 行，只改 `drivers/firmware/psci/psci.c`） |
| `fastboot reboot` 回 Linux | ✅ ~20 s 回到 `vk189-suspend`（= boot_b vk192 件） |
| `pr_info` 文本级证据 | ⏳ **未取**（vk192 无 ramoops ⇒ `/sys/fs/pstore` 空）。要拿需在 reset 核运行时**抓 ttyGS0 串口**再触发一次 |

## 1. 归因强度说明（不夸大）

- 功能证据是硬的：同一台机、同一根线，`reboot bootloader` 之后设备**出现在 fastboot**，而 `#701` 已实测过
  普通 `reboot` 回 Linux、BCB `bootonce-bootloader` 被 ABL 忽略、`qbootctl -u` 写失败 ⇒ 三条旧路径都不可能产出这个结果。
- 仍缺一环 = **内核侧 pr_info 原文**。取法（下次 BL 窗口，约 3 min）：
  1. 主机侧先起 `timeout 90 cat /dev/ttyACM0 > /tmp/console.log`（console = `ttyGS0,115200`，见 cmdline）；
  2. `fastboot boot out/g7-reset-20261123/boot-g7a-reset.img`，起核后 `reboot bootloader`；
  3. `grep 'SYSTEM_RESET2 vendor reset_type' /tmp/console.log` ⇒ 期望 `reset_type=0x80010001 cookie=0x2 (cmd=bootloader)`。
- 命令侧一处不严谨：本轮发的是 `systemctl reboot bootloader || reboot bootloader`（前者报 `Too many arguments.`），
  实际生效的是后者；下次用**单条 `reboot bootloader`** 复测，避免歧义。

## 2. 实现要点

- `psci_sys_reset()` 在 `psci_system_reset2_supported` 时先调 `psci_elden_try_vendor_reset(data)`：
  `cmd=bootloader` → `reset_type 0x80010001` / `cookie 0x2`；`cmd=edl` → `0x80000000` / `0x1`；
  **固件若拒绝并返回，则落回原普通复位路径**（不会把机器卡死）。
- 该函数为 `static` 且单点调用 ⇒ 被内联，`System.map` 无独立符号（判在不在要看 `Image` 里的
  `SYSTEM_RESET2 vendor reset` 字符串或反汇编）。

## 3. 工程记录

- 编译：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j8 Image.gz modules`（用户指定 8 核）；
  1508 个 `.ko`。增量编译只动 `psci.o` 与链接。
- 踩坑①：`drivers/net/wireless/mediatek/mt76/mt76.o` 报 `.debug_info` 重定位坏值
  （`bad reloc symbol index …`）⇒ 陈旧对象，`find … -name '*.o' -delete` 后重编即过（不是源码/硬件问题）。
- 踩坑②：`scripts/build-boot.sh` 的 DSI 身份守卫对 **pristine 上游树假阳性**
  （要求 B5 重构符号 `msm_dsi_host_bonded_*`，7.4-rc3 没有）⇒ `SKIP_KERNEL_ASSERT=1` 绕过
  （= TASKS §4.0 D5 开放项 ⑤ 的实例；应给守卫加「上游等价符号」分支）。
- USB 面（dwc3/qcom、f_acm/ncm/ecm/rndis）全部 `=y` ⇒ RAM 起新核**不需要**先部署 `/lib/modules`。

## 4. 下一步

1. 取 pr_info 原文（上面 §1 三步），通过后把 `scripts/elden-to-bootloader.sh` 的能力自检从
   「无钩子 ⇒ 自动退 BCB 臂」改为「有钩子 ⇒ 走 `systemctl reboot bootloader`」，并更新 `#690/#701` 的适用范围。
2. 把该补丁纳入日常核默认补丁栈（`patches/local/`），否则换核又丢软路径。
3. `reboot edl`（`0x80000000`）尚未实测 —— 需评估：EDL 下只能 qdl 救回，建议在用户在场且备份齐时再验。
