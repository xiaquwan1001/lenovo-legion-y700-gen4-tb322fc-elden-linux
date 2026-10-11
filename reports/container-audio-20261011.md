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
| 容器内录音 | 未测 | ✅ **可用**：`TestRecord` 5s → `samples=232800 rms≈457 peak=1815`（另一次 376800/rms≈495/peak=2350）；宿主出现 `source-output 364 51 356 s32le 2ch 16000Hz` |

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
- `TestRecord` — `AudioRecord(MIC)` 采集 N 秒，打印 samples/rms/peak（验证录音通路）。
- `ListCodecs` — 打印 `MediaCodecList` 全部 codec（验证 ccodec 配置）。
- `TestRing3` — MediaPlayer 播 OGG（**注意**：裸 `app_process` 无 Context，
  `setDataSource` 会 NPE；只有 DeskClock 等真 app 能测整链，故落盘仅作记录）。
构建：`javac`（可用 `prebuilts/sdk/current/system/android.jar`）+ `d8.jar`（`/mnt/Samsung/waydroid-build/prebuilts/sdk/tools/lib/d8.jar`）。
运行：push `*.jar` 到容器 `/data/local/tmp/`，`CLASSPATH=... app_process /data/local/tmp <Main>`。

---

## 5. 构建侧收口（2026-10-11 已落地 + 上机验证）

镜像侧改动（`/mnt/Samsung/waydroid-build`，lineage-20）：
1. `device/waydroid/waydroid/device.mk`：3 个 `PRODUCT_COPY_FILES` 改用
   `media_codecs_google_c2_{audio,telephony,video}.xml`（目标名不变，`media_codecs.xml` 的 include 不用改）。
2. `device/waydroid/waydroid/manifest.xml`：删掉 `android.hardware.media.omx` `<hal>`。
3. 补丁：`patches/waydroid-c2-codecs-drop-omx.patch`；本地全量快照 `patches/waydroid-buildtree-local-20261011.patch`。

**构建 `m vendorimage` 踩到的树漂移（非音频，但必须修才能出镜像）**：
- `hardware/waydroid/gatekeeper/*` 用 `gatekeeper::SizedBuffer` 私有成员 `buffer/length` 编译不过
  ⇒ 改用公共 API `size()`/`Data<uint8_t>()`（enroll/verify 改拷贝）。
- Mesa 报 `Program 'mesa_clc' not found`（`BoardConfig.mk` 写死 `-Dmesa-clc=system`）
  ⇒ 改 `-Dmesa-clc=auto -Dprecomp-compiler=auto`（freedreno 不需要 OpenCL C 编译器）。
- hwcomposer 报缺 `fractional-scale-v1-client-protocol.h` ⇒ **构建前必须 `apply-waydroid-patches`**
  （Waydroid 补丁给 `external/wayland-protocols` 加 staging fractional-scale；脚本见
   `vendor/extra/waydroid-patches/apply-patches.sh`，`mesa-build.sh` 有调用，`m vendorimage` 不会自动调用）。
- 构建命令：`bash /mnt/Samsung/waydroid-build/build-vendor-c2.sh`（内部 source envsetup + lunch +
  apply-waydroid-patches + `m vendorimage -j16`）。

**产物与上机**：
- `out/target/product/waydroid_arm64_only/vendor.img`（82 MiB；原 OTA 镜像 225 MiB）。
  差异：少了 `libLLVM22.so`(82M) 与 `vulkan.{broadcom,lvp,panfrost,radeon,virtio}.so`、`libdrm_{amdgpu,radeon}.so`
  （软渲/非 Adreno 用，本机无关），多了 `egl/libGLES_mesa.so`；Mesa 26.1.8(freedreno) 直接烘进镜像。
- 已换到设备 `/var/lib/waydroid/images/vendor.img`（备份 `/root/vendor.img.pre-c2build-*`），
  并从 `config_nodes` **删掉** manifest-nomx + 3×codec XML 这 4 条 bind。
- 上机复测：`boot_completed=1`、`grep media.omx /vendor/etc/vintf/manifest.xml`=0、
  codec=**53**、SurfaceFlinger running、**闹钟出声**（宿主 sink-input 出现 + `DMABUFHEAPS: Using DMA-BUF heap named: system`）。

**仍需 host 侧（不在镜像内）**：`waydroid_base.prop` 里 `debug.stagefright.ccodec=4`、
`/etc/modules` 加 `system_heap`、`config_nodes` 保留 `/dev/dma_heap` bind（见 §3）。

---

## 5.5 容器内录音（2026-10-11 已测）

- **音频采集链路（与播放反向）**：Android `AudioRecord(MIC)` → Waydroid audio HAL
  （`snd_pcm_open("pulse", CAPTURE)`，HAL 固定 16 kHz）→ host PipeWire **source
  `alsa_input.platform-sound.HiFi__Mic__source`**。
- **实测（`TestRecord`，裸 `app_process` 跑 `AudioRecord`，无 Context 需求）**：
  `AudioRecord.getMinBufferSize`=1280、state=1、recordingState=3；5 s → `samples=232800 rms≈457 peak=1815`
  （另一次 8 s → 376800 / rms≈495 / peak≈2350，**非零**）；同时宿主
  `pactl list source-outputs` 出现 `364 51 356 PipeWire s32le 2ch 16000Hz`（=容器采集流）。
  ⇒ **容器内录音通路可用**（含权限：root/app_process 下 RECORD_AUDIO 通过）。
- **“合适的 app”核实**：镜像自带 **`org.lineageos.recorder`**（LineageOS Recorder，UI 名 `RecorderActivity`），
  且带 **`SoundRecorderService`，可用无头 intent 驱动**：
  `am start-foreground-service -n org.lineageos.recorder/.service.SoundRecorderService -a org.lineageos.recorder.service.{START,STOP,PAUSE,RESUME}`。
  **但在本容器里崩**：`getExternalFilesDir()` 返回 null → `SoundRecorderService.createNewAudioFile` NPE，
  因为 **emulated storage 没挂上**（`sm list-volumes all` = `emulated;0 unmountable`；
  `vold: Failed to find mounted volume for /storage/emulated/0/...`）。
  ⚠️ **这是容器存储缺口（vold 无 fstab/FUSE 挂 emulated），与音频无关**；
  同一原因也会让任何依赖 `getExternalFilesDir()`/外部存储的录音 app 崩溃。
- ~~崩~~ → **已修（见 §5.6），现可正常录音**：`am start-foreground-service … -a …service.START --es extra_filename testrec`
  → `/storage/emulated/0/Android/data/org.lineageos.recorder/files/Recordings/testrec`（发送 STOP 后 m4a 含 `moov`+`mdat`，21954→29821 B）。
  注意：START 不带 `extra_filename` 会 NPE（`String.format(null,…)`）；playback 的完整命令追加 `--es extra_filename <name>` 即可。

---

## 5.6 容器 emulated storage 修复（2026-10-11，TASKS Q30）

- **现象**：`sm list-volumes all` = `emulated;0 unmountable`；`/storage/emulated/0` 不是 FUSE 挂载；
  `vold: Failed to find mounted volume for /storage/emulated/0/...`
  ⇒ 所有 `getExternalFilesDir()`/外部存储的 app 崩（含自带 Recorder）。
- **根因**：容器**缺 `/dev/fuse`**。Waydroid `lxc.py` 本有 `make_entry("/dev/fuse")`，
  但 `config_nodes` 是在宿主 `/dev/fuse` 还不存在时生成的（Alpine 由 udevd 在 fuse 模块加载后创建该节点），
  于是这一条被（optional）跳过；之后 `config_nodes` 未重生成。
- **修**：`config_nodes` 补 `lxc.mount.entry = /dev/fuse dev/fuse none bind,create=file,optional 0 0`；
  `/etc/modules` 加 `fuse`（确保开机有 `/dev/fuse`）。
- **验证**：容器内 `/dev/fuse` 存在；`sm list-volumes`=`emulated;0 mounted`；
  `/storage/emulated`、`/mnt/user/0/emulated` 为 fuse 挂载；Recorder 出 m4a。
- 备注：该修复**不在 vendor.img 内**（host+LXC 配置），故与 §5 镜像收口独立。

---

## 6. 未做 / 待确认

- **宿主整机重启**回归：本轮做过 `waydroid-container restart` + 换 vendor.img 后的干净重启；
  `/etc/modules`、`base.prop`、`config_nodes` 全在持久盘，理论必过，但未整机 cold boot 验证。
- ~~容器 emulated storage~~ → **2026-10-11 已修（§5.6，TASKS Q30）**：容器缺 `/dev/fuse` 所致；
  修后 `emulated;0 mounted`、自带 Recorder 可录音。（本轮 `apply-waydroid-patches` 的
  `system/vold/...fuse...` 补丁不影响此修复；vold 在 system.img，未重建。）
- `system_heap` 常驻是否与 Q24（相机×熄屏）有交互：Q24 已定「日常零相机模块」，`system_heap` 单独加载
  在历史相机 bring-up 中本就是必需的，预计无影响；未做长时空闲对照。
- **（待办 Q29）** Mesa bind mount（`/root/wd/mesa/lib64/*`）现在与镜像内 Mesa 重叠（镜像已烘入 26.1.8）；
  未核对两者是否逐字节相同，暂保留 bind（无害）；核对相同后应移除这些 bind。
