# 容器内音频（Waydroid）打通 — 2026-10-11

> 任务：`TASKS.md` §2 C6 / §5 U8。设备 U2 `HA2EXB0E`，b 槽 vk64，Waydroid 1.6.2 + LineageOS 20(A13) GAPPS 镜像。
> 结论：**容器音频输出链路本身是好的；「容器内闹钟无声」是 4 层容器/镜像配置缺陷叠加。4 层全部修复并做成开机持久。**
> 原始过程：本文件即证据；测试工具 `scripts/wd-audio-test/`。

---

## 0. 结论（数字）

| 项 | 修前 | 修后 |
|---|---|---|
| 容器音频输出链路（Android→HAL→宿主 PipeWire→扬声器） | 本来就好（裸 PCM 实测通） | 保持 |
| `MediaProvider`（`media` authority） | **起不来**（AMS 10s `timeout publishing content providers` 杀） | 正常发布 |
| MediaStore 闹钟音 | `alarm_alert=null`、internal 卷空 | 已设 `content://media/internal/audio/media/6`（Timer.ogg） |
| 媒体编解码器数（`MediaCodecList`） | **0** | **53**（含 `c2.android.vorbis.decoder`） |
| 播放闹钟 | 无 sink-input | 宿主 `pactl list sink-inputs` 出现 `s16le 2ch 48000Hz`（出声） |
| 开机持久 | — | ✅（干净重启 container 后复测 codec=53、闹钟出声） |

---

## 1. 架构（核实，非推测）

```
Android AudioTrack
  → /vendor/bin/hw/android.hardware.audio.service  (audio.primary.waydroid.so，只链 libasound)
  → ALSA "pulse" PCM 插件 (libasound_module_pcm_pulse.so + libpulse.so)
  → $PULSE_RUNTIME_PATH/native = /run/xdg/pulse/native
       (prop waydroid.pulse_runtime_path；LXC bind 宿主 /run/user/1000/pulse/native)
  → 宿主 pipewire-pulse (1.6.8) → sink alsa_output...Speaker
```

- 容器**没有** `/dev/snd`，音频不走裸 ALSA，走 pulse socket（`config_session` 已 bind）。
- HAL 源码：`/mnt/Samsung/waydroid-build/hardware/waydroid/audio/audio_hw.c`
  （`snd_pcm_open(..., "pulse", ...)`，`PULSE_RUNTIME_PATH` 由 `waydroid.pulse_runtime_path` 设）。

---

## 2. 四层根因链（递进；每层都有设备证据）

### 层 1 — 输出链路（本就正常，用自建 AudioTrack 证明）
`app_process` 跑 `TestAudio`（AudioTrack 裸 PCM）→ 宿主 `pactl list sink-inputs` 出现
`s16le 2ch 48000Hz`，客户端名 `threaded-ml`（libpulse）。⇒ 说明 HAL→pulse→PipeWire 通，
后面几层都是「应用侧拿不到 codec/URI」。

### 层 2 — MediaProvider 挂死 → MediaStore 不可用
- 现象：`com.android.providers.media.module` 启动后 10s 被 AMS 杀（`timeout publishing content providers`），
  `content query --uri content://media/...` 报 `Could not find provider: media`；
  `settings put system alarm_alert <uri>` 被 SettingsProvider 拒（拿不到 mimeType）。
- `debuggerd -j` 主线程栈实锤：
  `MediaProvider.onCreate → TranscodeHelperImpl.hasHDRPlugin() → MediaCodec.createDecoderByType(HEVC)
   → MediaCodecList::getInstance → BpMediaPlayerService::getCodecList` **永久阻塞**。
- 真根因：vendor VINTF manifest 声明了 `android.hardware.media.omx`（`IOmx`/`IOmxStore`），
  但镜像里**没有 OMX 服务二进制**；`libhidltransport` 对「manifest 已声明」的 HAL 会**无限重试**
  `IOmxStore::getService()`（logcat 反复 `Waited one second for ...IOmxStore/default`）。
- 修法：给容器换一份**删掉 media.omx `<hal>` 段**的 `/vendor/etc/vintf/manifest.xml`
  （bind mount）→ `getTransport` 返回 EMPTY → `getService` 立即返回 null（日志变
  `MediaPlayerService: OMX service is not available`，优雅降级）→ MediaProvider 正常发布。

### 层 3 — 闹钟没有声音 URI
- `settings get system alarm_alert|notification_sound|ringtone` 全是 `null`（默认值没种）；
  internal 卷没扫描 → 设 URI 被校验拒。
- 修法：广播扫描系统音再设：
  `am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///system/product/media/audio/alarms/Timer.ogg`
  → `settings put system alarm_alert content://media/internal/audio/media/6`（已持久）。
- 系统音在 **`/system/product/media/audio`**（`/system/media/audio` 不存在）。

### 层 4 — 解码器启动失败（err=-12 NO_MEMORY）
- 现象（层 2 修好后）：
  `NuPlayerDecoder: Failed to start [c2.android.vorbis.decoder] decoder (err=-12)`；
  进一步 `TestCodec`：所有 C2 音频解码器 **configure OK 但 start 全 FAIL**。
- 日志实锤：
  ```
  CCodecBufferChannel: Created input block pool with allocatorID 16 ...    # 16 = DMABUFHEAPS
  E DMABUFHEAPS: No ion heap of name system exists
  W CCodecBufferChannel: start: cannot allocate memory at all
  E MediaCodec: Codec reported err 0xfffffff4/NO_MEMORY
  ```
- 真根因：容器**没有 `/dev/dma_heap`**。宿主 `system_heap.ko` 未加载（无 `/dev/dma_heap/system`），
  且 LXC `config_nodes` 没把它挂进容器。CCodec 的 buffer channel 默认用 dmabuf heap。
- 修法：宿主 `modprobe system_heap` + 把 `/dev/dma_heap` bind 进容器 → 所有 C2 解码器 start OK。
- 真根因：容器 **`debug.stagefright.ccodec=0`**（Waydroid 默认，见下）→ `Codec2InfoBuilder` 的
  `case 0: continue` 跳过**所有** Codec2 编解码器 → `MediaCodecList` 恒空。
  这解释了「重启 mediaserver 后 codec=53、重启容器又归 0」的全部现象。
- 修法：把宿主 `/var/lib/waydroid/waydroid_base.prop` 的 `debug.stagefright.ccodec` 由 `0` 改 `4`。

### 层 4b — vendor codec XML 用 OMX 名，Codec2 编解码器不被列出
- vendor `/vendor/etc/media_codecs_google_*.xml` 里只有 `OMX.google.*`；
  而 `Codec2InfoBuilder` 要求 XML 里有 `c2.android.*` 条目才认 Codec2 软件编解码器
  （`Codec2InfoBuilder.cpp:534` `parser.getCodecMap().count(nameOrAlias)==0 → continue`）。
- 修法：用 AOSP `frameworks/av/media/libstagefright/data/media_codecs_google_c2_{audio,video,telephony}.xml`
  覆盖 vendor 的三个 OMX 版 XML（bind mount）。这两层叠加才让 codec 列表变成 53。

---

## 3. 持久化改动清单（全部可回退；U2 设备侧）

| 位置 | 改动 | 备份 |
|---|---|---|
| 宿主 `/etc/modules` | 追加 `system_heap`（开机加载 → `/dev/dma_heap/system`） | 无（追加行） |
| 宿主 `/var/lib/waydroid/waydroid_base.prop` | `debug.stagefright.ccodec=0` → `4` | `waydroid_base.prop.bak-*` |
| 宿主 `/root/wd/vintf/manifest-nomx.xml` | vendor manifest 去掉 media.omx `<hal>` | 原件 `/root/manifest.xml.orig` |
| 宿主 `/root/wd/vintf/media_codecs_google_c2_{audio,video,telephony}.xml` | 覆盖 vendor OMX XML | — |
| 宿主 `/var/lib/waydroid/lxc/waydroid/config_nodes` | +4 条 `lxc.mount.entry`（manifest / 3×codec xml / `/dev/dma_heap`） | `config_nodes.bak-*` |
| 容器 settings（持久在 /data） | `alarm_alert=content://media/internal/audio/media/6` | — |
| 容器 `/system/etc/init/blank_screen.rc`（已 bind） | 无（本轮试的 restart 钩子已回退；属性修法后不需要） | `blank_screen.rc.bak-*` |

**坑**：vendor.img 是**满的**（0 空间），直接原地改文件会 `ENOSPC` 截成 0 字节；
本轮曾误截，已从 `/root/vendor.img.bak-1791711331` **还原并校验**（改 bind mount，不动镜像）。

---

## 4. 可复用测试工具

`scripts/wd-audio-test/`（Java 源码 + 构建/推送脚本）：
- `TestAudio` — AudioTrack 裸 PCM（验证输出链路）。
- `TestCodec` — 逐个 `MediaCodec.createDecoderByType` configure+start（验证解码器）。
- `ListCodecs` — 打印 `MediaCodecList` 全部 codec（验证 ccodec 配置）。
- `TestRing3` — MediaPlayer 播 OGG（**注意**：裸 `app_process` 无 Context，
  `setDataSource` 会 NPE；只有 DeskClock 等真 app 能测整链，故落盘仅作记录）。
构建：`javac`（可用 `prebuilts/sdk/current/system/android.jar`）+ `d8.jar`（`/mnt/Samsung/waydroid-build/prebuilts/sdk/tools/lib/d8.jar`）。
运行：push `*.jar` 到容器 `/data/local/tmp/`，`CLASSPATH=... app_process /data/local/tmp <Main>`。

---

## 5. 「正确收口」建议（构建侧，替代手工 bind mount）

根因都在镜像/设备构建配置，长期应改 `device/waydroid/waydroid/`：
1. `device.mk`：用 `media_codecs_google_c2_{audio,video,telephony}.xml` 取代 OMX 版 XML。
2. `manifest.xml`：删掉 `android.hardware.media.omx`（除非把 OMX 服务一并打进 vendor）。
3. `device.mk`/`init`：`setprop debug.stagefright.ccodec 4`（或改 `waydroid_base.prop` 生成逻辑）。
4. `init`/device 配置：确保 `system_heap` 加载且 `/dev/dma_heap` 进容器（或让 Android 走 memfd）。
5. 默认声音设置：启动后种 `alarm_alert/notification_sound/ringtone`。

---

## 6. 未做 / 待确认

- **宿主整机重启**回归（本轮只做了 `rc-service waydroid-container restart` 级别的干净重启；
  `/etc/modules`、`base.prop`、`config_nodes` 都在持久盘，理论必过，但未整机验证）。
- `system_heap` 常驻是否与 Q24（相机×熄屏）有交互：Q24 已定「日常零相机模块」，`system_heap` 单独加载
  在历史相机 bring-up 中本就是必需的，预计无影响；未做长时空闲对照。
- 录音（容器内 capture）未测；`TASKS.md` U8 要求「录音通路单独记」。
