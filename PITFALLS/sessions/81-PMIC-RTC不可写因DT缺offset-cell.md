# PMIC RTC 不可写（`hwclock -w` → `-ENODEV`）⇒ 每次开机被 1970 覆盖：DT 缺 offset cell（#392）

> 日期：2026-10-25 · 场景：设备重启后系统时间总是回到 1970，`hwclock -w` 报
> `ioctl(RTC_SET_TIME) failed: No such device`。RTC 节点、驱动、绑定**三层全正常**。

## 症状与判据

```bash
cat /sys/class/rtc/rtc0/name      # rtc-pm8xxx c400000.spmi:pmic@0:rtc@6100  ← 驱动在
cat /sys/class/rtc/rtc0/since_epoch   # 574328 ← 硬件原始值停在 1970
hwclock -w                        # ioctl(RTC_SET_TIME) failed: No such device (-ENODEV)
```
⇒ `CONFIG_RTC_HCTOSYS` 每次开机用这个 1970 值覆盖系统时间。**不是 chrony 的问题**
（chronyd 正常起、`rtcsync`/`makestep` 都在；它只是没机会拿到正确时间）。

## 根因（代码级）

`drivers/rtc/rtc-pm8xxx.c`：`allow-set-time` 未设时 `set_time()` 走
`pm8xxx_rtc_update_offset()`，其第一句就是
`if (!nvmem_cell && !use_uefi) return -ENODEV;` —— 即**没有 nvmem offset cell 就永远不能写**。
- 主线 `pmk8550.dtsi` 的 `rtc@6100` 与厂商 stock DT **都是裸节点**（无 `allow-set-time`、
无 `nvmem-cells`、无 `qcom,uefi-rtc-info`）⇒ 两边都写不了。

## 修法（上游规范做法，已落地）

把 offset 存进 SDAM2（`pmk8550_sdam_2`），不移动 PMIC 原始计数器（与 Android 语义兼容）：

```dts
&pmk8550_rtc {
	nvmem-cells = <&rtc_offset>;
	nvmem-cell-names = "offset";
	status = "okay";
};

&pmk8550_sdam_2 {
	rtc_offset: rtc-offset@b0 {
		reg = <0xb0 0x4>;
	};
};
```
（`patches/dt/0002-arm64-dts-qcom-sm8750-elden-pmk8550-rtc-offset.patch`；SDAM2 里厂商已用
`0x48/0x58/0x76-0x7b/0x9a/0x9c/0x9f/0xa2`，`0xb0` 空闲。）

**实测闭环（2026-10-25，boot_b 持久镜像 `dtbo3`）**：
`hwclock -w` → 成功；对时后重启 → 开机 `date -u` 直接是真实时间（`/sys/class/rtc/rtc0/since_epoch`
= 1792893691，不再是 574328）。

## 纪律

- 「RTC 不准」先分三层：节点/驱动/绑定（`/sys/class/rtc/*/name`）、**可写性**（`hwclock -w`）、
  上游时间源（NTP）。**`-ENODEV` 就是可写性层**，别去改 chrony。
- 只改 DTB 的修复不需要重编内核：`DTC_FLAGS=-@ make … qcom/<board>.dtb`
  （注意：直接指定 dtb 目标时 Makefile 里的 `DTC_FLAGS_<dtb>` **不生效**，必须用环境变量 `DTC_FLAGS=-@`
  才会带上 `__symbols__`，否则 DTB 从 201 KB 静默退回 153 KB —— 见 #389）。
