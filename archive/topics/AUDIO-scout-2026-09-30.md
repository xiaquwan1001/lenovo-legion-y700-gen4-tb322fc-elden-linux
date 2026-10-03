# 音频侦察报告 — TB322FC "elden"（2026-09-30）

> 结论先行：**内置扬声器出声不是"差一点"，而是缺一个大件——ADSP AudioReach 拓扑（tplg）没有 MI2S/aw88461 后端**。
> 现状：codec、machine driver、声卡、混音控件全部就位，但 ADSP 图里没有 MI2S 后端 → `no backend DAIs enabled`。

---

## 1. 已经就位的部分（真机实测）

| 组件 | 证据 |
|---|---|
| codec 驱动 | `aw88461` 绑定到 i2c `9-0034`(Left) / `9-0037`(Right) |
| machine driver | `sc8280xp.c` 匹配 `qcom,sm8750-sndcard`（fork 已扩展 sm8750 支持） |
| 声卡 | `/proc/asound/cards` → `LenovoY700Gen4`，PCM：MultiMedia1/2 playback、3/4 capture、compr4 |
| DAPM | 机器级 `Left/Right Speaker`、Headphone/Mic Jack 在册 |
| 固件 | `awinic/y700-gen4-speakers.bin`（1792 B）存在 |
| ADSP | `remoteproc0: adsp` up；`apr/gpr` service 注册 |

## 2. 真正的卡点

打开 PCM 报错：
```
MultiMedia1 Playback: ASoC: no backend DAIs enabled for MultiMedia1 Playback,
possibly missing ALSA mixer-based routing or UCM profile
```
→ FE（MultiMedia1）的 DPCM **be 列表为空**，没连到任何后端。

### 根因：tplg 是通用占位，不含 MI2S

`q6apm` 启动时按 `qcom/<driver_name>/<card_name>-tplg.bin` 找拓扑
（`topology.c: audioreach_tplg_init`）。设备上确实有：
```
/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin.zst   (内核支持 .zst，能解)
```
**但** `Lenovo-Y700-Gen4 / SM8750-MTP / SM8750-QRD` 三个文件 **sha256 完全相同**，
解压后 `strings` 只含：
- FE：`MultiMedia1..5`
- BE：`RX_CODEC_DMA_RX_0` / `TX_CODEC_DMA_TX_3` / `WSA_CODEC_DMA_RX_0` / `VA_CODEC_DMA_TX_0`
- 若干 `streamN.*` 模块

**没有 `SECONDARY_MI2S_RX`、没有 `aw88461`**。即这是给 MTP/QRD（WCD939x + WSA883x，SoundWire）的通用拓扑，
拿来当占位；我们的 DT 用的是 **Secondary MI2S + aw88461**，ADSP 图里没有对应后端 → 路由建不起来。

旁证：boot 时 `qcom-apm gprsvc:service:2:1: CMD timeout for [1001021] opcode` = 图打开失败。

## 3. 顺带发现：没有声音服务端

- 只有 `/usr/bin/pulseaudio`，**没有 pipewire/wireplumber 二进制**（只有 libpipewire-module-*）。
- 没有任何 `bluetoothd/pipewire/pulseaudio` 进程在跑。
- → 即使 ALSA 出声打通，GUI 应用还需要一个声音服务端 + UCM 路由。

## 4. 结论 / 工作量

音频出声 = **三件事**，都不是几行代码：
1. **生成/获取匹配的 AudioReach tplg**（MI2S backend + aw88461 + PCM 模块），这是大头，需理解 Qualcomm
   AudioReach 模块 ID 与 sub-graph/container 结构（`audioreach.h` 有定义），可能要手搓二进制或找厂商 tplg。
2. **装声音服务端**（PipeWire 或 PulseAudio）+ 路由。
3. **写 UCM profile**（card = `Lenovo-Y700-Gen4`）把 FE→BE + codec 初始化串起来。

**建议**：音频单独立项、设时间盒；不放进当前小步快跑节奏。

---

## 5. 相关文件/命令

```bash
# 设备
zcat /proc/config.gz | grep -E "FW_LOADER_COMPRESS|INPUT_AW86927"
cat /proc/asound/cards
amixer -c0 controls
dmesg | grep -iE "tplg|apm|snd-sc8280|no backend"

# 主机内核源
sound/soc/qcom/common.c            # qcom_snd_parse_of：DT 只建 BE，FE 是 dynamic
sound/soc/qcom/qdsp6/topology.c    # audioreach_tplg_init：tplg 名字 = qcom/<drv>/<card>-tplg.bin
sound/soc/qcom/qdsp6/audioreach.h  # AudioReach 模块/子图定义
sound/soc/qcom/sc8280xp.c          # sm8750 特化 hw_params
arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts  # sound 节点 + i2c9 aw88461
```
