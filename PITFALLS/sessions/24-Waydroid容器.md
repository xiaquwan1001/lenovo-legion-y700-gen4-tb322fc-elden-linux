## 二十四、Waydroid 容器（音频/媒体）

189. **★容器内「闹钟无声 / 无媒体解码器」是 4 层叠加缺陷，不是音频链路坏（2026-10-11 实机定位并修通，C6）。**
    - **先证链路**：自建 `TestAudio`（`app_process` 跑 AudioTrack 裸 PCM，`tools/wd-audio-test/`）→ 宿主 `pactl list sink-inputs` 出现 `s16le 2ch 48000Hz`（client `threaded-ml`）。⇒ HAL→ALSA `pulse` 插件→宿主 PipeWire 本就通；别再从音频驱动找。
    - **层① MediaProvider 挂死**：`com.android.providers.media.module` 10s 被 AMS 杀（`timeout publishing content providers`），`content query content://media/...` 报 `Could not find provider: media`。`debuggerd -j` 主线程栈：`MediaProvider.onCreate → TranscodeHelperImpl.hasHDRPlugin → MediaCodec.createDecoderByType → MediaCodecList::getInstance → BpMediaPlayerService::getCodecList` **永久阻塞**。真根因 = vendor VINTF manifest 声明了 `android.hardware.media.omx` 但**镜像无 OMX 服务二进制** ⇒ `libhidltransport` 对 manifest 声明的 HAL **无限重试** `IOmxStore::getService()`（logcat `Waited one second for ...IOmxStore/default`）。**修**：bind 一份删掉 media.omx `<hal>` 的 `/vendor/etc/vintf/manifest.xml` ⇒ 日志变 `OMX service is not available`（优雅降级）、MediaProvider 正常发布。**通用教训**：vendor manifest **声明了却没有对应 service** 的 HIDL HAL，会让任何 `getService()` 卡死；「删声明」比「补 service」通常更省。
    - **层② 无声音 URI**：`settings get system alarm_alert/notification_sound/ringtone` 全 `null`，internal 卷未扫描 ⇒ 写 URI 被 SettingsProvider 校验拒（`failure to find mimeType`）。**修**：`am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///system/product/media/audio/alarms/Timer.ogg` 扫描后再 `settings put system alarm_alert content://media/internal/audio/media/<id>`。注意系统音在 **`/system/product/media/audio`**（`/system/media/audio` 不存在）。
    - **层③ codec=0**：`MediaCodecList` 恒 0 ⇒ `NuPlayer: Failed to create audio/vorbis decoder`。两个原因叠加：**(a)** vendor `/vendor/etc/media_codecs_google_*.xml` 只有 `OMX.google.*`，而 `Codec2InfoBuilder`（`sfplugin/Codec2InfoBuilder.cpp:534`）要求 XML 有 `c2.android.*` 条目才认 Codec2 软件编解码器（否则 `component '...' not found in xml` → 跳过）⇒ 用 AOSP `frameworks/av/libstagefright/data/media_codecs_google_c2_{audio,video,telephony}.xml` 覆盖；**(b)** **`debug.stagefright.ccodec=0`**（Waydroid 写死在宿主 `/var/lib/waydroid/waydroid_base.prop`，由 lxc.py `props.append("debug.stagefright.ccodec=0")` 生成）⇒ `Codec2InfoBuilder` 的 `switch(option)` **`case 0: continue`** 跳过全部 Codec2 codec。**修**：`waydroid_base.prop` 里改 `=4`。**这一条最能解释「重启 mediaserver 后 codec=53、重启容器又回 0」的诡异现象——别误判成 boot race。**
    - **层④ 解码器 start 失败 err=-12**：`TestCodec` configure OK 但 start 全 FAIL；日志 `CCodecBufferChannel: ... allocatorID 16`（=DMABUFHEAPS）+ `E DMABUFHEAPS: No ion heap of name system exists` + `start: cannot allocate memory at all` + `NO_MEMORY`。真根因 = 容器**无 `/dev/dma_heap`**：宿主 `system_heap.ko` 未加载（无 `/dev/dma_heap/system`）且 LXC `config_nodes` 未挂。**修**：宿主 `modprobe system_heap`（并写 `/etc/modules` 持久）+ `lxc.mount.entry = /dev/dma_heap dev/dma_heap none bind,create=dir,optional 0 0`。注意 PITFALLS #130：**只加 `system_heap`，不要加载 `cma_heap`**（后者造 `/dev/dma_heap/reserved` 会干扰 libcamera）。
    - **操作坑**：(1) vendor.img **满盘 0 空间**，`open(w)` 原地改文件会 `ENOSPC` 截成 0 字节——改 `/vendor` 一律走 bind mount，别动镜像（本轮曾误截，已从备份还原校验）。(2) `lxc.mount.entry` 的 `create=file` 在**只读** `/system`/`/vendor` 上，仅当目标文件**已存在**才成功；新造 rc 文件必然失败并让 LXC 「Failed to setup mount entries」（`blank_screen.rc` 能挂是因为镜像里本就有该文件）。要给 init 加 action，可**追加到已 bind 的既有 rc**（如 `/root/wd/blank_screen.rc`）。(3) `setprop ctl.restart media` 在服务处于 `init.svc.media=stopping` 时不生效；要强制重建用 `kill -9 $(pidof mediaserver)`。(4) 裸 `app_process` 跑 `MediaPlayer` 会因无 `Context` 在 `setDataSource→FileUtils.convertToModernFd` NPE——MediaPlayer 整链只能用真 app（如 DeskClock timer）测。
    - 全量配方/持久化清单/构建侧收口建议：`reports/container-audio-20261011.md`；测试工具 `scripts/wd-audio-test/`。

190. **★Waydroid 镜像（lineage-20 `m vendorimage`）在本树重建的 3 个必须先修的树漂移（2026-10-11 实机出镜像）。**
    - **① 必须先 `apply-waydroid-patches`**（`/mnt/Samsung/waydroid-build`，envsetup 后为 shell 函数）。
      不跑的话 `hardware/waydroid/hwcomposer/wayland-hwc.cpp` 报 `fractional-scale-v1-client-protocol.h` 找不到
      （补丁向 `external/wayland-protocols` 加 staging fractional-scale）。`mesa-build.sh` 有调用，**`m vendorimage` 不会自动应用**。
    - **② gatekeeper 编译不过**：`hardware/waydroid/gatekeeper/SoftGateKeeper.h|Device.cpp` 直访
      `gatekeeper::SizedBuffer::buffer/length`，而树里 `system/gatekeeper/.../gatekeeper_messages.h` 已把它们改私有
      ⇒ 改用 `size()` / `Data<uint8_t>()`（enroll/verify 改拷贝 `new uint8_t[]`+memcpy，不要再用 `buffer.release()`）。
    - **③ Mesa 报 `Program 'mesa_clc' not found`**：`device/waydroid/waydroid/BoardConfig.mk` 写死
      `-Dmesa-clc=system -Dprecomp-compiler=system`。本机无 `mesa_clc`/`vtn_bindgen2` ⇒ 改 `-Dmesa-clc=auto -Dprecomp-compiler=auto`
      （freedreno 不依赖 OpenCL C 编译器；`auto` 时 `with_clc=false`，不会去构建/要求它）。
    - 构建脚本：`/mnt/Samsung/waydroid-build/build-vendor-c2.sh`（envsetup+lunch+apply-patches+`m vendorimage -j16`）；
      全量本地改动快照 `patches/waydroid-buildtree-local-20261011.patch`。
    - 镜像大小坑：重建的 vendor.img 82 MiB vs OTA 225 MiB——少的只有 `libLLVM22.so`(82M, 软渲)
      与 `vulkan.{broadcom,lvp,panfrost,radeon,virtio}.so`、`libdrm_{amdgpu,radeon}.so`（非 Adreno，无关）；多了 `egl/libGLES_mesa.so`。
      **别只看大小就以为镜像不全**，要 `comm` 对比文件清单。
    - 上机换镜像前先 `waydroid container stop`（否则不能覆 vendor.img），并备份 `/var/lib/waydroid/images/vendor.img`；
      换后把已烘入镜像的 bind（manifest/XML）从 `config_nodes` 删掉。

191. **★容器 emulated storage 不可挂 → 所有写外存的 app 崩（`getExternalFilesDir()` 返 null）= 容器缺 `/dev/fuse`（2026-10-11 修，TASKS Q30）。**
    - 现象：`sm list-volumes all` = `emulated;0 unmountable`；`/storage/emulated/0` 非 FUSE 挂载；
      `vold: Failed to find mounted volume for /storage/emulated/0/...`；自带 `org.lineageos.recorder` 起动即
      `SoundRecorderService.createNewAudioFile` NPE（`getExternalFilesDir` 为 null）。
    - 根因：Waydroid `lxc.py` 本有 `make_entry("/dev/fuse")`，但 **容器 `config_nodes` 是宿主 `/dev/fuse` 还不存在时生成的**
      （Alpine 由 udevd 在 fuse 模块加载后才造该节点）⇒ 这条被 optional 跳过且此后未重生成。
    - 修：`config_nodes` 补 `/dev/fuse` bind + `/etc/modules` 加 `fuse` ⇒ `emulated;0 mounted`。
    - 复盘方法：容器内 `ls -l /dev/fuse`（应 10:229）+ 宿主 `ls -l /dev/fuse` + `grep fuse config_nodes`，
      若宿主有、容器无、config_nodes 也没那条 = 命中本坑。
    - 附带坑：无头驱动 `org.lineageos.recorder` 必须带 `--es extra_filename <name>`，
      否则 `startRecording(null)` → `String.format(null,…)` NPE（不是存储问题）。

---

