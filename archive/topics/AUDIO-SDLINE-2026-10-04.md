# 音频出声修复：tplg MI2S SD 线 SD0→SD1（2026-10-04）

> 承接 `archive/topics/AUDIO-2026-10-02.md`（APM 图 GRAPH_START 已通，待听声）。
> 权威：`PITFALLS.md` #90、`TASKS.md` G1-4。产物：`scripts/audio-tplg/`、`out/boot-elden-vk43.img`。

## 1. 背景 / 本次目标

用户："vk39 附近有两项内核改动，一项音频一项温度传感器，验证是否功能正常。"

两项 = **音频**（`patches/0009` APM cmd header + `0011` MI2S BE graph 在 prepare 启动）
与 **温控**（`patches/0010` 四级热 trip）。但**当前 vk41 内核里这两项都被回退**——
`elden/vk34-recon` 为隔离"熄屏→重启"把它们整批撤回（见 `AUDIO` 旧文档 / `TASKS` G1-22）。

## 2. vk42：干净重落两项改动

从 `elden/vk34-recon`（=vk41 基线）重建分支 `elden/vk42-audio-thermal`：
- 音频：`git apply 0011` + 手工补回 `q6apm.c` 3 处 `audioreach_alloc_apm_cmd_pkt`（0009；`audioreach.c` 里函数已在）。
- 温控：`git apply 0010`。
- 不带 vk40 的 DBG 插桩。commit `eb432f18a`，uname `7.2.0-debug-geb432f18a0d1`。
- 产物 `out/boot-elden-vk42.img`（sha `40c8797611ba8e9b…`）。

**温控验证 ✅**：所有 CPU/GPU 热区 trip = `120000 125000 70000 82000 90000 105000`
（hot/critical + 四级 passive）；cdev `cpufreq-cpu0/6`、`devfreq-3d00000.gpu` 就位；空闲 38–44 ℃。
（vk41 对照：单级 `105000`。）

## 3. 音频：图全通但无声

vk42 冷启后 ALSA 直放（`amixer -c0 cset numid=8 on` + `speaker-test -D hw:0,0`）：
- 整条 APM/DAPM 图 **全 On**：`MultiMedia1 Playback` → `SECONDARY_MI2S_RX Audio Mixer`
  → `device18.i2s_rx1` → bedais `Secondary MI2S Playback` → aw88461 `Left/Right Playback/AIFIN/Amplifier/OUT`。
- `SEC_MI2S_IBIT` = **1.536 MHz**（`dai@12 bclk`）。
- 功放寄存器：未静音（HMUTE/ULS_HMUTE=0）、TXEN=1、VOLUME 衰减=11（近最大）。
- **SYSST = `0x0215`：bit8 `SWITCHING` = 0** → 功放没有输入信号在开关。
- 用户："没有声音"；且设置界面输入输出设备为空（后者是另一问题，见 §6）。

## 4. 根因：MI2S SD 数据线对不上

| | |
|---|---|
| 硬件 | 功放 I2S DIN 接 **`gpio124 = i2s1_data1`（=SD1）** |
| 依据 | 主 DTS `secondary_mi2s_default` 与原厂 DT dump `probe/result/devicetree.dts:4636`（`function="i2s1_data1"; pins="gpio124"`）**一致**；`gpio122=i2s1_data0`，`gpio124=i2s1_data1` |
| tplg | 抄自 Google SC7180 SEC-I2S 模板，用 **`SD_LINE_IDX_I2S_SD0`**（`audioreach.m4`：SD0=1 / SD1=2） |
| 后果 | ADSP 往 **SD0/gpio122** 发数据，功放挂在 **SD1** 收不到 → 图全 On、时钟在走、功放就绪，但无声 |

## 5. 修复

`scripts/audio-tplg/SM8750-Lenovo-Y700-Gen4.m4`：`DEVICE_SG_ADD` 的
`SD_LINE_IDX_I2S_SD0` → **`SD_LINE_IDX_I2S_SD1`**。重建 tplg
`db7e16e7373fe744ef52523a9b8726d284bcd8d40133dc2ad1e349053fd96773`（同尺寸 10436 B）。

部署（tplg 在 boot 早期从 **initramfs** 加载，必须冷启）：
1. ramdisk `out/rootfs-overlaid.cpio.gz`：因新旧 tplg **同尺寸**，做**字节级替换**（不改 cpio 元数据）。
2. 持久 root `/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`。
3. 重建 boot = **`out/boot-elden-vk43.img`**（sha `f3e53fe40693493e…`）。

> 运行期 unbind/bind 重载不可用（ADSP 图状态残留 → map status=1 → can't create pcm，旧文档已记）。

## 6. 验证结果（vk43 冷启，2026-10-04）

- **用户确认：扬声器出声** ✅
- 客观：`SEC_MI2S_IBIT`=1.536 MHz；**SYSST `0x0215` → `0x2315`（bit8 SWITCHING 置位）**
  —— 功放确认收到 I2S 数据并在开关输出。dmesg 无 q6apm/aw88461 报错。

**尚未做**：
- 左/右两片 AW88461 分别验证（当前是同一测试音）。
- 录音通路。
- **UI/应用音频**：系统只装了 `pipewire-libs`/`libpulse`（库），**没有音频服务守护进程**
  → 设置界面"输入输出设备"为空。需装并启用 PipeWire + WirePlumber（或 PulseAudio）
  把 ALSA 卡暴露为 sink/source（`TASKS.md` C6）。

## 7. 非回归确认

- vk42 冷启未复现"熄屏→重启"（用户："这一版没有重启"）——但两增量是否是其诱因需另做长时窗观察。
- boot 6.8 s 的 `qcom-apm … CMD timeout for [1001021]` 在 **vk41 也有**，非本次引入。

## 8. 操作记录

- `devlogs.sh`（运行日志采集：snapshot/pstore/tail/serial/watch）建立，见 `TASKS`/工具头注释。
- 期间 elogind 调试实例已在电源验证收口时清理；本专题只动内核/ramdisk tplg，未改持久 root 其他内容。

## 9. 桌面音频服务（PipeWire + UCM2）— 2026-10-04

承 §6"UI/应用音频"。`pulseaudio` 其实早已装（只是没跑）；本次改装 **PipeWire**：

- 包：`apk add pipewire pipewire-pulse pipewire-alsa wireplumber`（会替换 pulseaudio）。
- 但 ACP 只给 `Dummy Output` / `Pro Audio`：本卡机器驱动没有可用 port
  （唯一 port 是 "analog-output-headphones" 且 unavailable），`api.acp.auto-profile=false`。
- 正解：给卡写 **UCM2**
  - `scripts/audio-ucm/HiFi.conf`：`SectionVerb` + `SectionDevice."Speaker"`，
    EnableSequence `cset` 开 `SECONDARY_MI2S_RX Audio Mixer MultiMedia1` 并把
    `Left/Right Playback Volume` 抬到 1023（默认 0=静音）；`PlaybackPCM "hw:${CardId},0"`。
  - `scripts/audio-ucm/Lenovo-Y700-Gen4.conf`（Syntax 4，HiFi use case）→ 装到
    `/usr/share/alsa/ucm2/conf.d/sm8750/Lenovo-Y700-Gen4.conf`。
  - `scripts/audio-ucm/install.sh` 幂等安装，由 `start-desktop.sh` 调用。
- PipeWire 自启：Alpine 装了 `/etc/xdg/autostart/pipewire.desktop`
  → `pipewire-launcher` → pipewire + wireplumber + pipewire-pulse，gnome-session 拉起。
- **冷启实测**：`Active Profile=HiFi`；sink `alsa_output.platform-sound.HiFi__Speaker__sink`
  （GNOME 显示 "Built-in Audio Speaker playback"）；UCM 自动 `numid8=on`、音量=1023；
  经 PipeWire 播放 SYSST `0x0315`（SWITCHING 置位）。

**仍缺**：**输入设备**——本卡只有 Secondary MI2S 播放 DAI，`arecord -l` 为空；
麦克风（VA/TX macro DMIC）是另立的 bring-up，不在本轮。
