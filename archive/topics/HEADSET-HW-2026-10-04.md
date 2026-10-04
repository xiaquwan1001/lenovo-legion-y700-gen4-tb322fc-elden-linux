# 有线耳麦（WCD939x HPHL/HPHR + 耳麦麦）bring-up —— 硬件受限挂起（2026-10-04）

> 承接 `WCD939X-2026-10-04.md`（采集打通）。关联 `TASKS.md` G1-4、`PITFALLS.md` #90/#91/#92。
> 本篇记录「音频剩余问题 R1（有线耳机/耳麦）」的一轮尝试：**代码就绪，但因缺 USB-C 模拟耳机/转接头，
> 无法做听声验收，按用户指示记录后跳过。** 内核/tplg 改动已作为 vk48 draft 提交（未验证），不构成"可用"结论。

## 0. 一句话结论

**R1 挂起（硬件受限）**。已按上游 SM8750-MTP 权威配方实现 WCD939x 耳机输出通路（DTS dai-link + 路由、
tplg RX 播放子图），构建了零写盘 RAM 镜像 **vk48**；但本机（TB322FC，GSMArena 规格 **无 3.5mm 孔**，双 USB-C）
需要 **USB-C 模拟耳机/模拟转接头**才能听声验证，用户手上没有此类硬件，故只做静态/串口层面的检查无法闭环，
**记录后跳过**。

## 1. 问题定义

- 现象：WCD939x 有 `HPHL/HPHR`、`Headphone Jack`/`Mic Jack`（MBHC）控件与 input 设备，但**没有任何
  dai-link 把 `lpass_rxmacro` 挂进声卡** → 卡上 `RX_MACRO RX0 MUX`、`RX INT0_1 MIX1 INP0` 等 RX 宏控件
  一个都不出现；插耳机也无播放 PCM 通路。
- 采集侧（AMIC1）已通（见 `WCD939X-2026-10-04.md`）；缺的是**播放侧 RX** 与**耳麦麦 AMIC2**。
- 本机无 3.5mm，有线音频只能走 **USB-C 模拟耳机**（经 `wcd939x-usbss` 模拟开关；数字 DAC dongle 走
  USB Audio 类，与本路无关）。

## 2. 权威参照（rootfs 内自带）

本机 rootfs 的 alsa-ucm-conf 自带 **`Qualcomm/sm8750/MTP/HiFi.conf`**——与 elden 同 SoC、同 WCD939x
codec、同机器驱动（`qcom,sm8750-sndcard`）。其 `Headphones` / `Headset` 设备与
`include/codecs/wcd939x/*`、`include/codecs/qcom-lpass/{rx,tx}-macro/*` 就是本平台的正确控制序列。

关键 dais/控件（照 MTP `sm8750-mtp.dts` + 上游 UCM）：

| 用途 | DAI | codec | 关键控件 |
|---|---|---|---|
| 耳机播放 | `RX_CODEC_DMA_RX_0` | `wcd939x(0)+swr1+lpass_rxmacro` | `RX_MACRO RX0/RX1 MUX=AIF1_PB`、`RX INT0/1_1 MIX1 INP0=RX0/RX1`、`HPHL/HPHR Switch`、`CLSH Switch`、`RX HPH Mode=CLS_H_LOHIFI` |
| 耳麦采集 | `TX_CODEC_DMA_TX_3` | `wcd939x(1)+swr2+lpass_txmacro` | `ADC2 MUX=CH2_AMIC2`、`TX SMIC MUX0=SWR_MIC1`（与内置麦 AMIC1 共用 ADC2，二者互斥） |

## 3. 已实现（vk48 draft，未验证）

- **内核 DTS**（`linux/.../sm8750-lenovo-elden.dts`，+18 行）：
  - `audio-routing` 增 `"IN1_HPHL","HPHL_OUT"`、`"IN2_HPHR","HPHR_OUT"`；
  - 新增 `wcd-playback-dai-link`（cpu `RX_CODEC_DMA_RX_0`，codec `<&wcd939x 0>,<&swr1 0>,<&lpass_rxmacro 0>`）——
    与 `sm8750-mtp.dts` 逐字对齐。
- **tplg**（`scripts/audio-tplg/SM8750-Lenovo-Y700-Gen4.m4`，+12 行）：新增
  `RX_CODEC_DMA_RX_0` 设备子图（`LPAIF_INTF_TYPE_RXTX`/`CODEC_INTF_IDX_RX0`，iid `0x4006/0x4006/0x6060`）+
  `STREAM_DEVICE_PLAYBACK_MIXER/ROUTE`（到 MultiMedia1/2）→ 新 tplg **18236 B `c6fffdbc…`**。
- **产物**：`out/boot-elden-vk48.img`（`cf835ba2…`）、`out/boot-elden-vk48-ram.img`（`fc59031d…`，含新内核+新 tplg，
  tplg 以 `tplg-overlay-vk48.cpio.gz` 叠加，内核 initramfs 后段覆盖前段）。
- 未做：UCM `Headphones`/`Headset` 设备、`wcd939x-usbss` 节点/模拟开关（USB-C 模拟耳机路由）。

## 4. 一旦有硬件，如何验收

### 4.0 串口静态检查（2026-10-04 已做 ✅，vk48 RAM）

在 headless vk48 RAM 镜像上验证：新增 `wcd-playback-dai-link` 后 **RX 宏控件全部出现**（`RX_MACRO RX0..RX5 MUX`、
`RX INT0_1 MIX1 INP0..2`、`RX INT0/1 DEM MUX`、`RX_HPH PWR Mode`、`RX_HPH HD2 Mode Switch` 等，
numid 126–165），声卡正常注册（`/proc/asound/cards`、`aplay -l` 的 MultiMedia1/2 无误），
WCD939x RX/TX 均 bound。**结论：vk48 改动在寄存器/DAPM 层面有效，仅差听声**（听声需耳机，挂起）。

### 4.1 听声（需耳机）

1. RAM 试（零写盘）：`fastboot boot out/boot-elden-vk48-ram.img`，插 USB-C 模拟耳机。
2. 串口/SSH 静态检查（无耳机也能做）：
   - `dmesg | grep -iE 'wcd|soundwire'`（RX/TX 均 bound）；
   - `amixer -c0 controls | grep -E "RX_MACRO|RX INT|CLSH|HPH"`（RX 宏控件应出现）；
   - `/proc/asound/card0/pcm0p` 存在；`aplay -l` 正常。
3. 听声（需耳机）：
   ```
   amixer -c0 cset "name='RX_CODEC_DMA_RX_0 Audio Mixer MultiMedia1'" 1   # 若按名找不到，用 numid
   amixer -c0 cset "name='HPHR Volume'" 20
   amixer -c0 cset "name='HPHL Volume'" 20
   amixer -c0 cset "name='HPHL_RDAC Switch'" 1
   amixer -c0 cset "name='HPHR_RDAC Switch'" 1
   amixer -c0 cset "name='HPHL_COMP Switch'" 1
   amixer -c0 cset "name='HPHR_COMP Switch'" 1
   amixer -c0 cset "name='HPHL Switch'" 1
   amixer -c0 cset "name='HPHR Switch'" 1
   amixer -c0 cset "name='CLSH Switch'" 1
   amixer -c0 cset "name='RX HPH Mode'" CLS_H_LOHIFI
   amixer -c0 cset "name='RX_HPH PWR Mode'" LOHIFI
   amixer -c0 cset "name='RX_MACRO RX0 MUX'" AIF1_PB
   amixer -c0 cset "name='RX_MACRO RX1 MUX'" AIF1_PB
   amixer -c0 cset "name='RX INT0_1 MIX1 INP0'" RX0
   amixer -c0 cset "name='RX INT1_1 MIX1 INP0'" RX1
   amixer -c0 cset "name='RX INT0 DEM MUX'" CLSH_DSM_OUT
   amixer -c0 cset "name='RX INT1 DEM MUX'" CLSH_DSM_OUT
   aplay -D hw:0,0 /usr/share/sounds/alsa/Front_Center.wav
   ```
   注：`amixer sget/set` 对本卡部分 DAPM 控件按名会报 "Unable to find simple control"，可直接用
   `cset numid=<n>`（见 `amixer -c0 controls`）。
4. 通过后再做 UCM（照上游 `sm8750/MTP/HiFi.conf`，加 `Headphones`(hw:0,0, JackControl "Headphone Jack",
   JackHWMute "Speaker") + `Headset`(hw:0,2, ADC2=AMIC2, JackControl "Mic Jack")）并落持久。

## 5. 待办（若日后拿到硬件）

- [x] vk48 串口静态检查（RX 宏控件出现 / 卡注册不受影响）——✅ 2026-10-04 已做（§4.0）。
- [ ] 有耳机后按 §4 听声，闭环后加 UCM 并落持久。
- [ ] USB-C 模拟耳机还需要 `wcd939x-usbss`（i2c typec-mux@0x0e + pmic_glink SBU 图）才能把模拟信号路由到
      WCD939x——本机 `&i2c3` 尚未启用，stock overlay `fragment@22` 证明原厂确实配了 `wcd_usbss`。

---

## 6. 更正与阻塞点（2026-10-04 二次勘察，附带期间 R3 收尾）

上游 §2/§5 假设本机 USB-C 模拟音频走 `wcd939x-usbss`（i2c typec-mux@0x0e）。**实测 DTS 否定了该假设**：

- 本机模拟开关是 **FSA4480**（`fcs,fsa4480`），在 **`&i2c5`** 的 `typec-mux@42`/`typec-mux@43`，DTS 已启用：
  `fsa4480_sbu_mux` → `pmic_glink_sbu`（connector@0）、`fsa4480_hs_sbu_mux` → `pmic_glink_hs_sbu`（connector@1）。
  即 `i2c3`/`wcd_usbss` 那条路与本机无关，**不要再按 §5 去启用 i2c3**。
- 内核 `CONFIG_TYPEC_MUX_FSA4480=m`（模块）。当前 vk47/48 用 RAM 启动（无 `/lib/modules`）加载不了；
  持久根 `/dev/sda17` 的 `/lib/modules/7.2.0-debug-gba28ec16f01f-dirty/` 是**旧内核**版本、且不含 `fsa4480.ko`
  → **FSA4480 目前在任何启动方式下都用不上**。结论：要用它需 `CONFIG_TYPEC_MUX_FSA4480=y`（built-in），
  或为现用内核 `gbd114ca33` 补齐匹配的模块目录。
- 仍未确定：谁把 FSA4480 切到 **AUDIO** 模式。mainline `fsa4480.c` 只提供 typec-mux/switch 端口；
  模拟附件检测后的 audio-mode 请求通常由 codec 的 MBHC/下游 `wcd_usbss` API 发起，本机是否需补 glue 待查。

**硬件阻塞（2026-10-04）**：无 USB-C 模拟耳机/转接头，R1 听声验收无法进行，进度到此为止。
数字 DAC dongle 是另一条更简单的路（USB-Audio class，插上即枚举），但同样需硬件验证。

## 7. 期间顺带完成：R3 裸 ALSA 默认（2026-10-04）

见 `scripts/audio-alsa-init.sh` 与 `TASKS.md` G1-4：无桌面/PipeWire 时 `aplay -D default`/`arecord` 开箱可用，
`/init` 在 RAM 与持久根都调用，默认硬件增益取保守值 400（满值 1023 过响）。已 commit `4aacf40`。
