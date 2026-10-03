# Y700 Gen4 (elden/TB322FC) 厂商内核源码与设备树 — 2026-09-30

> 目标：为马达（AW86937）等问题找**权威参考**。结论：**找到了**，而且顺带拿到 elden 的完整 DT 与厂商触觉驱动二进制。

---

## 1. 联想公开源码位置（GitHub org `lenovo-basements`）

| 仓库 | 内容 | 对我们 |
|---|---|---|
| `android_kernel_lenovo_sm8750` | SM8750 完整内核树（main 分支，~78k 文件） | ✅ 内核/GKI 基线；**无** haptic_hv/aw882xx 源码 |
| `android_kernel_lenovo_sm8750-modules` | vendor 模块源码（audio/touch/wlan/camera 等） | ✅ 音频/触屏等；**无** haptic_hv |
| **`android_device_lenovo_elden-kernel`** | **elden 预编译产物**：`kernel`、`dtbo.img`(33MB)、`vendor_dlkm/`、`system_dlkm/`、`dtb/`、`kernel-headers/` | ★★★ **黄金**：dtbo 里有 elden 完整设备树 |
| `proprietary_vendor_lenovo_elden` | vendor 固件/库 | 备用 |
| `kernel_lenovo_sm8475-devicetree` | SM8475 设备树仓库（先例） | 证明 DT 仓库形式 |

**关键实锤**：`android_device_lenovo_elden-kernel/vendor_dlkm/haptic.ko` = 厂商 **AWINIC Haptic_Hv** 驱动（`i2c:haptic_hv`，GPL v2，vermagic `6.6.56-android15-8`，**not stripped**）。源码未公开（符合 GPL issue 描述），但符号齐全、可反汇编。

已存到工作区 `backup/stock-elden/`：`kernel` / `dtbo.img` / `elden.dts`（反编译） / `elden_overlay.dtb` / `haptic.ko` / `haptic.asm` / `sm8750_kernel_filelist.txt`。

---

## 2. elden 的触觉设备树（从 dtbo.img 反解，权威）

```dts
haptic_hv_l@5A {                       // i2c6 (qupv3_se6_i2c)
    compatible = "awinic,haptic_hv_l";
    reg = <0x5a>;
    irq-gpio   = <&tlmm 0x63 0>;       // gpio 99  （与我们 DT 一致）
    reset-gpio = <&tlmm 0x7f 0>;       // gpio 127 （与我们 DT 一致）
    f0_pre = <0x6a4>;                  // 1700 Hz
    mode = [05];
    aw8693x_f0_cali_percent    = [0f];
    aw8693x_gain_bypass        = [01];
    aw8693x_uvlo_vol_default   = [00];
    aw8693x_cont_smart_loop    = [00];
    aw8693x_cont_drv1_lvl      = [7f];
    aw8693x_cont_lra_vrms      = <0x3e8>;
    aw8693x_cont_drv1_time     = [04];
    aw8693x_cont_drv2_time     = [14];
    aw8693x_cont_track_margin  = [0f];
    aw8693x_cont_brk_gain      = [08];
    aw8693x_cont_brk_time      = [04];
    aw8693x_duration_time      = [14 1e 3c];
    aw8693x_d2s_gain           = [02];
    aw8693x_trig_config        = <0x01 0x20000 0x01 0x20000 0x01 0x20000>;
    aw8693x_bst_vol_default    = <0x2134>;   // 8500 mV
    aw8693x_is_enabled_track_en;
};
// haptic_hv_r@5B 同参数，irq gpio 0x5f(95)、reset gpio 0x77(119)
```

**这解释了为什么我们的 RAM 回放不震**：厂商用一个**专用 AWINIC 驱动 + CONT/（触发）模式 + F0 跟踪**，不是我们 mainline fork 里的"内存波形回放"。

同 overlay 里还有 **`aw882xx_smartpa@34/@37`**（扬声器功放驱动，GPL v2）——音频 likewise 可参考。

---

## 3. 从 `haptic.ko` 反汇编还原的 AW8693X 寄存器语义

（`aw8693x_play_mode` / `aw8693x_cont_config` / `aw8693x_stop` / `aw8693x_play_go`）

| 寄存器 | 操作 | 含义 |
|---|---|---|
| `0x08` PLAYCFG3 | `[1:0]=3` | **STOP** |
| `0x08` PLAYCFG3 | `[1:0]=2` | **CONT 模式** |
| `0x08` PLAYCFG3 | `[1:0]=0, bit2=(非工厂)?1:0` | 其他模式（RTP/TRIG） |
| `0x09` PLAYCFG4 | `=1` | **GO**（启动） |
| `0x45` SYSCTRL3 | bit5 置位 | standby |
| `0x4c` VBATCTRL | bit6=1（CONT/模式5 时） | VBAT 模式 |
| `0x1d` CONTCFG | 低7位=cont_drv1_lvl, bit7=flag | 连续驱动电平 |
| `0x1e` / `0x20` | 写字节 | cont 时间参数 |
| `0x3f` GLBRD5 | 读，=0 表示已进 standby | 状态轮询 |
| `0x06` PLAYCFG1 | bit5 | BST 相关 |

厂商 `aw8693x_cont_config` 序列：
```
write_bits(0x08,~4,2)         # PLAYCFG3[1:0]=CONT
write_bits(0x08,~5, 非工厂?4:0)
write_bits(0x06,~0x20,0)
write_bits(0x4c,~0x40,0x40)   # VBATCTRL bit6=1
write_bits(0x1d,~0x80, flag<<7)
write_bits(0x1d,~0x80, drv1_lvl)
write(0x1e, <1B>) ; write(0x20, 0xff)
play_go(1)                    # write(0x09,1)
```
`aw8693x_stop`：`write_bits(0x08,~4,3)` → `write(0x09,1)` → 轮询 `0x3f==0`。

**厂商用的是 RTP 波形文件**：`vendor_dlkm/haptic.ko` 内含上百个 `*_RTP.bin` 文件名（work 区 `backup/fw/vendor/firmware/*_RTP.bin` 已采），即播放时从 `/lib/firmware` 流式送 RTP 采样，而非 SRAM 内存回放。

---

## 4. 下一步（马达修复）选项

1. **移植 CONT 模式**到 mainline fork 驱动：按上表 + DT 参数，把播放从 RAM 改成 CONT（`PLAYCFG3[1:0]=2` + cont 参数 + `0x09=1`）。中等工作量，风险低。
2. **移植 RTP 播放**：实现 RTP 二进制加载 + FIFO 送数（厂商路径），配合已采集的 `*_RTP.bin`。工作量大但最接近厂商效果。
3. 直接从 `haptic.ko` 反汇编补全 `aw8693x_*` 全部函数（`container_update` / `misc_para_init` / `parse_dt`）后完整重写。

**建议先做 1**（最小可验证：只要电机能动即算成功），成功后再考虑 2。

---

## 5. 已落地：AW86937 CONT 模式移植（2026-09-30，vk19）★

厂商 `haptic.ko` + DT 证实：厂商用 **CONT 连续模式**（芯片内部生成 f0 正弦波驱动 LRA），
**不是** mainline fork 的"内存波形回放"。已把厂商 `aw8693x_cont_config` 序列移植进 `aw86927.c`：

```
PLAYCFG3(0x08)[1:0]=2, bit2=1 ; PLAYCFG1(0x06) bit5=0 ; VBATCTRL(0x4c) bit6=1
CONTCFG6(0x1d)=drv1_lvl(0x7f) ; CONTCFG7(0x1e)=0x04 ; CONTCFG9(0x20)=0xff
PLAYCFG4(0x09)=GO(1)
```

- 补丁：`patches/0003-aw86927-aw86937-haptics.patch`（含 SRAM 8K 窗口修复 + CONT 播放）
- 镜像：`out/boot-elden-vk19.img`（干净版，无 debug 打印）
- **验收：设备上 `vibrate` 左右马达均可震**（`/usr/local/bin/ffrumble` + `vibrate [ms] [repeats]`，自动找 `aw86927-haptics` 设备）
- 回退：`scripts/flash-b.sh out/boot-elden-vk13.img --reboot`
