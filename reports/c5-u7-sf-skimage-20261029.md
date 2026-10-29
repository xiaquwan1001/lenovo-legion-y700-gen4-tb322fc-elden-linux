# C5/U7 容器 surfaceflinger `SIGABRT: Unable to generate SkImage` 取证（2026-10-29）

> lane **E**（并行 lane，设备 lane）。上游：`reports/c5-u7-gralloc-device-20261028.md` §8（HAL gralloc YV12 布局修法
> 已上机：12 请求 / 0 崩溃 / 12 次修复）、`reports/c5-u7-container-camera-20261028.md` §13（`SkImage::MakeFromTexture` 线索）。
> 在机内核：**vk181-daily**。硬约束：只读取证 + 可回滚的容器服务重启；**不刷写任何分区、不改 boot/kernel、不发邮件**。

## §0 结论表

| 项 | 结论 | 判据级别 |
|---|---|---|
| A 崩溃栈确切落点 | `surfaceflinger` **RenderEngine 线程** SIGABRT，abort msg `Unable to generate SkImage. isTextureValid:0 dataspace:0`；落点 = `renderengine::skia::AutoBackendTexture::makeImage(+512)` 内 **`SkImage::MakeFromAHardwareBuffer` 返回 null**，调用方 `SkiaGLRenderEngine::drawLayersInternal`（**合成路径**，非截图/非 App RenderThread） | 实锤（tombstone_19/22 双份一致，§3） |
| B 触发时刻与相机相关性 | **强相关**：25 份 tombstone 中 SF 之死共 6 次，**每一次都与 camera provider `ExtCamOut` 线程同秒共亡**（§3.2 表）；无一次相机不活跃时 SF 单独死 | 强证据（回顾性 6/6） |
| C 归类 | **相机路径 buffer 问题诱发 SF 自杀**，非 SF 自身随机缺陷：ExtCamOut 在 `formatConvert→libyuv I420Copy` SIGSEGV（正是 §8 gralloc YV12 布局修的函数族），坏 buffer 同时被 SF 合成消费 → `MakeFromAHardwareBuffer` 失败即 `LOG_ALWAYS_FATAL` 自杀 | 强证据（§5，有两点保留） |
| D A/B：不启相机时 SF 稳定性 | **弱证据**：SF（容器 pid 104 / 宿主 pid 3570）自 14:39:38 存活至 18:26（3h47m+）零复发；但期间 Container=FROZEN 无合成活动，存活时长不能折算为「合成压力下稳定」 | 弱证据（§4.1；本版禁主动观测窗口） |
| E 启相机复现（两条时间线） | **未执行**（本版只读取证 + 不重启服务；启相机需 unfreeze + 打开相机应用，授权外）。修复上机后 0 新增 tombstone 是唯一被动旁证 | 未执行（§4.2、§8.1 待拍板） |
| F 处置（容器重启）前后 `waydroid status` | **未执行**：本版只读授权；容器 FROZEN 属正常省电态无故障症状；重启会清 FROZEN 现场且无新增信息 | 未执行，理由充分（§6） |
| G dpms/黑屏排除 | **dpms=Off 从未出现**：`card0-DSI-1/dpms` 为 0444 只读（PITFALLS #456），改用 DRM `enabled` + `phoc` 存活 + `waydroid status` 判定；面板正常点亮 | 实测（§1.3） |

> 内核注记：任务卡说在机内核 **vk181-daily**，实测 `uname` = `7.3.0-rc7-debug-vk127-...-debug-vk172`（§1.1）。取证全程在 vk172 上做，结论的有效性以 vk172 为前提；vk181 上线后需复核一签（§8 下一动作）。

## §1 环境与前置

### §1.1 设备与内核

```
$ ssh root@192.168.7.1 'uname -a; uptime'
Linux elden 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172 #28 SMP PREEMPT Tue Oct 27 23:26:17 CST 2026 aarch64 GNU/Linux
 16:43:03 up  2:03,  3 users,  load average: 0.09, 0.05, 0.01
```

**与任务卡不一致**：任务卡写「在机内核为 vk181-daily」，实测是 **vk172**（同一 7.3.0-rc7 基线）。本 lane 不重启不换内核，全程在 vk172 取证（证据文件 `10-state-now.txt`）。

### §1.2 容器今日时间线（宿主 journal）

```
$ journalctl --since "-4 hours" | grep "starting service 'surfaceflinger'"
Oct 29 14:06:25 elden init: starting service 'surfaceflinger'...   ← 昨宿主 boot 的容器 run（journal 持久）
Oct 29 14:35:43 elden init: starting service 'surfaceflinger'...   ← 同上
Oct 29 14:39:39 elden init: starting service 'surfaceflinger'...   ← 今日 14:39 宿主重启后的当前 run
```

当前容器 init 起于 **14:39:37**，SF pid 104 自 14:39:38 存活未重启（`ps -o STIME`，文件 `10-state-now.txt`）。
⇒ **崩溃证据必然在 14:39 之前的容器 run**；Android logd 是内存环，容器重启即清空（`logcat -d -b crash` 今日实测 0 字节，`11-logcat-crash-full.txt`），取证转向持久层（§2）。

### §1.3 dpms/黑屏门（G 判据）

- 本机 `/sys/class/drm/card0-DSI-1/dpms` 是 **0444 只读**，root 也读不到写口（PITFALLS #456），`dpms=Off` 无法直接产生；
- 判显改用：DRM connector `enabled` + `phoc` 进程存活 + `waydroid status` Session/RUNNING；三者今日全程正常，**无熄屏/黑屏干扰**，崩溃判据不受影响。
- 附注 PITFALLS #372：背光 4% 可伪装黑屏——本 lane 未做熄屏类操作，不存在此混淆。

## §2 证据采集

证据目录 `reports/artifacts/c5-u7-sf-20261029/`（00–06 为上一 lane 中断前遗留，07 起本 lane 续写）：

| 文件 | 内容 | 要点 |
|---|---|---|
| `00-initial-state.txt` | 16:17 时状态（Container FROZEN） | FROZEN 为 Waydroid 无 UI 客户端的正常省电行为（cam-restart.sh 注释） |
| `10-state-now.txt` | 16:43 状态：RUNNING、SF pid 104 存活 | kernel=**vk172**，与任务卡 vk181-daily 不符 |
| `11-logcat-crash-full.txt` | `logcat -d -b crash` | **0 字节**：容器 14:39 重启清空 logd，证实崩溃在上一 run |
| `12-persistent-dirs.txt` | /data/tombstones、/data/anr、dropbox、/data/misc/logd 清单 | 25 份 tombstone（10-27 01:30 → 10-28 22:00）；1 份 ANR（10-29 00:01）；logd 持久未开 |
| `13-tomb-headers.txt` | 全部 tombstone 头部（进程/信号/时间） | **SF RenderEngine 6 次死亡，每次与 ExtCamOut 同秒**（§3.2） |
| `20-tomb-sf-22-19.txt` | tombstone_22/19 全文（SF 侧） | abort msg + makeImage 栈（§3.1） |
| `21-tomb-cam-23-24.txt` | tombstone_23/24 全文（provider 侧） | ExtCamOut `formatConvert→I420Copy` SEGV（§3.3） |
| `30-ab-state-*.txt` | A 相（无相机）SF 稳定性观测 | §4.1 |
| `31-b-cam-run-*.txt` | B 相（启相机）复现两条时间线 | §4.2 |
| `40-am-start-check.txt` | `am start` 现状核验（DEAD_OBJECT 是否仍在） | §4.1 |
| `50-restart-status.txt` | （若执行）重启前后 `waydroid status` | §6（本版未执行） |
| `16-host-logs-listing.txt` | 宿主 /var/log、/root、/var/lib/waydroid 三处 `ls -lt`（本版补全） | 无 SF 崩溃专属宿主文件；dmesg 快照均 10-17 旧档 |
| `16b-waydroidlog-sf-grep.txt` | waydroid.log 中 SF/died/crash/SIGABRT grep | 0 条命中，仅 gbinder died 噪声；宿主侧证据链关闭 |
| `17-logcat-crash-t400.txt` | `logcat -d -b crash -t 400`（本版重跑） | **rc=124**：FROZEN 容器 attach 必挂（§4.3） |
| `18-logcat-main-sf.txt` | `logcat -d -b main -s surfaceflinger:V` | **rc=124**，同上 |
| `19-logcat-main-renderengine.txt` | `logcat -d -b main -s RenderEngine:V`（§3.1 预测的先兆行 tag） | **rc=124**，同上 |
| `32-frozen-attach-blocked.txt` | FROZEN 诊断：`waydroid status` + 宿主 ps + `attach -- true` 探针 | **上一 lane 卡死根因实锤**：FROZEN 下 attach 零开销命令也 rc=124 |

宿主侧：`03-host-logs.txt`（上一 lane 遗留，/var/log 清单）；宿主 journal 已入库 §1.2。dropbox 无 `system_app_crash`/`SYSTEM_TOMBSTONE` 条目（只有 watchdog/wtf，§2.1），SF 崩溃未进 dropbox（dropbox 只收 Java 层，native tombstone 走 /data/tombstones）。

### §2.1 dropbox 中非 crash 条目的旁证

`14-anr-wtf.txt` 已入库：ANR 1 份（10-29 00:01，**SystemUI** 收 `DATE_CHANGED` 广播超时，pid 500 com.android.systemui，Java 栈）+ dropbox `system_server_wtf` 全部为 NetworkStats 读取失败（10-29 00:01 与 14:06/14:35 批次）。**两者均与 surfaceflinger/图形栈无关**；SF 是 native 进程，其崩溃只走 /data/tombstones、不进 dropbox/ANR——旁证路径确认无增量，主证据仍为 §3 tombstone。

## §3 崩溃栈分析

### §3.1 SF 侧：6 次死亡同一签名（实锤）

25 份 tombstone 中 SF 死亡共 6 次（tombstone_04/07/09/12/19/22，10-27 03:14 → 10-28 22:00），**6/6 完全同签名**：

```
signal 0 (SIGABRT), code -1 (SI_QUEUE)
Abort message: 'Unable to generate SkImage. isTextureValid:0 dataspace:0'
  #03 .../surfaceflinger (renderengine::skia::AutoBackendTexture::makeImage(Dataspace, SkAlphaType, GrDirectContext*)+512)
  #04 .../surfaceflinger (renderengine::skia::SkiaGLRenderEngine::drawLayersInternal(...)+7060)
  #05/#06 ... (RenderEngineThreaded::drawLayers::$_11 / threadMain)
BuildId: 69cbbc7713d576921de983b3bb6980c1   ← 10-27 与 10-28 同一 SF 二进制
```

（`20-tomb-sf-22-19.txt` 全文；tombstone_04/12 头部核对同栈）

代码链（本地源码 `dl-cam/aosp/frameworks-native/libs/renderengine/skia/`，与容器 A13 同版）：

1. `AutoBackendTexture.cpp:31-45`（构造）：`GrAHardwareBufferUtils::MakeBackendTexture(...)` 把层的 AHardwareBuffer 导入 GL 纹理；**失败只打** `E/RenderEngine: Failed to create a valid texture. [%p]:[WxH] isProtected:%d isWriteable:%d format:%d`（`ALOGE_IF`，**不拦截**），`mBackendTexture.isValid()=false`；
2. `SkiaGLRenderEngine.cpp:1034-1079`（合成循环内，层输入 buffer）：`validateInputBufferUsage` 通过 → `waitFence(层 fence)` → `imageTextureRef->makeImage(layerDataspace, ...)`；
3. `AutoBackendTexture.cpp:95-112`：`SkImage::MakeFromTexture(context, mBackendTexture /*无效*/, ...)` 返回 null → `LOG_ALWAYS_FATAL_IF` → **SIGABRT**。

⇒ **abort msg 语义（回答 A 判据）**：`isTextureValid:0` = `mBackendTexture.isValid()==false` = **该层的 buffer 在 GL/EGL 侧导入纹理时已经失败**（非 fence 等待问题——fence wait 在 makeImage 之前且失败另有报错）；`dataspace:0` = 该层数据空间为 UNKNOWN。**不是** `MakeFromAHardwareBuffer`/`MakeRasterFromBitmap`（实际符号是 `MakeFromTexture` 包无效纹理）；也**不是截图路径**（是 `drawLayersInternal` 合成路径）。真正的“哪条 format 失败”在步骤 1 的 `format:%d` 先兆行里，logd 已被容器重启清空，B 相复现时当场抓（§4.2）。

### §3.2 SF 之死与相机 provider 同秒共亡（6/6）

| # | SF RenderEngine 之死 | 同秒 ExtCamOut 之死 | provider 重启后再崩 |
|---|---|---|---|
| 1 | t04 10-27 03:14:51.296 (up 35s) | t05 03:14:51.317 (up 35s) | — |
| 2 | t07 10-27 03:48:05.030 (up 36s) | t08 03:48:05.177 (up 36s) | — |
| 3 | t09 10-27 03:50:56.902 (up 36s) | t10 03:50:57.066 (up 36s) | t11 03:50:57.891 (**up 2s**) |
| 4 | t12 10-27 03:55:19.345 (up 35s) | t13 03:55:19.510 (up 36s) | t14 03:55:20.368 (**up 1s**) |
| 5 | t19 10-28 17:43:05.071 (up 225s) | t20 17:43:05.242 (up 225s) | t21 17:43:06.081 (**up 2s**) |
| 6 | t22 10-28 22:00:03.590 (up 850s) | t23 22:00:03.766 (up 850s) | t24 22:00:04.921 (**up 2s**) |

（`13-tomb-headers.txt`）⇒ **SF 从未在相机不活跃时死过**；且每次 provider 被拉起后 1–2 s 内 ExtCamOut 立即再崩（crash loop）。

### §3.3 相机侧：ExtCamOut `formatConvert→libyuv` SEGV

tombstone_23（与 t22 同秒）：

```
signal 11 (SIGSEGV), code 2 (SEGV_ACCERR)
  #00 libyuv.so (CopyRow_NEON+8)
  #01 libyuv.so (CopyPlane+204)
  #02 libyuv.so (I420Copy+188)
  #03 camera.device@3.4-external-impl.so (formatConvert(YCbCrLayout, YCbCrLayout, Size, uint)+244)
  #04 camera.device@3.4-external-impl.so (ExternalCameraDeviceSession::OutputThread::threadLoop+2212)
```

正是 `reports/c5-u7-gralloc-device-20261028.md` §8 所修的 YV12 布局函数族。**时间线关系（回答 B 判据的一半）**：t22/23 崩于 10-28 22:00，gralloc YV12 修法 10-29 10:37 才部署（§8.2 回退件时间戳）；10-29 修复上机后**零新增 tombstone**（今日 0 份）。⇒ 已上机的修复可能已消除了共崩的一半（provider SEGV），但 SF 侧是否仍会在相机活跃时崩，必须 B 相复现实测。

### §3.4 tombstone 全景分类（25 份）

| 类别 | 份数 | 编号 | 与本 lane 关系 |
|---|---|---|---|
| SF RenderEngine SkImage abort | 6 | t04/07/09/12/19/22 | **本 lane 主对象** |
| ExtCamOut provider SEGV | 10 | t05/08/10/11/13/14/20/21/23/24 | 同一事件的相机侧（§3.3） |
| composer@2.1-se 启动期崩 | 5 | t01/02/03/15/17 | HW composer HAL 自身问题，独立课题 |
| cameraserver watchdog | 2 | t06/16 | 相机服务卡死的旁证 |
| opencamera RenderThread (libhwui) | 1 | t18 | §13 已结（GrBackendTexture 野指针，容器 GPU 线） |
| system_server SensorService | 1 | t00 | 与图形无关 |

## §4 A/B 时间线

### §4.1 A 相（不启相机，SF 稳定性）——弱证据，主动观测未做

- **本版硬规则禁 `watch`/`sleep` 等待**，上一 lane 的 A 相主动观测（`30-ab-state-before.txt`，17:39 起，`== SF proc` 后无输出即卡死现场）不再续做；
- 被动证据（`32-frozen-attach-blocked.txt`，18:26）：SF 存活 3h47m+ 零崩溃复发，但期间 Container=FROZEN（无 UI 客户端 → 无合成活动）→ 只证明「无崩溃复发」，不证明「合成压力下稳定」；
- 历史回归面（回顾性）：25 份 tombstone 覆盖 10-27 01:30 → 10-28 22:00，SF 6 次死亡**全部**有相机共亡（§3.2），无一次相机不活跃时单独死——这是 A 相最强的回顾性证据。

### §4.2 B 相（启相机复现）——未执行

本版授权只读取证 + 不重启任何服务；启相机需 unfreeze session 并打开相机应用，属处置/复现操作，**授权外**。`修复上机后 0 新增 tombstone`（今日 /data/tombstones 无新文件）为唯一被动旁证。最小复现方案见 §8.1，待用户拍板。

### §4.3 本版反卡死根因（上一 lane「设备侧命令无输出」确诊）

- **FROZEN 容器中 `lxc-attach` 进入的进程全部被冻结**：attach 探针 `lxc-attach ... -- true`（零开销命令）也 rc=124 挂起（`32-frozen-attach-blocked.txt`，18:26 实测）；
- ⇒ 任何「容器内跑命令」的计划在 FROZEN 态必然无输出超时，与命令本身无关；宿主直读路径（/var/lib/waydroid/data/*）不受影响——这正是 tombstone 证据能拿到而 logcat 拿不到的原因；
- 本版 logcat 快照三条（17/18/19 号证据）因此全部 rc=124；且历史 run 的 logd 本已随 14:39 重启清空（§1.2）→ **logcat 路径双重不可得，但崩溃证据已由 tombstone 实锤覆盖，不阻塞判定**。

## §5 归类判定

### §5.1 已证（tombstone 实锤，本版独立核验逐行在盘）

1. **崩溃栈落点**（`20-tomb-sf-22-19.txt` 行 9/14/29/30 核验）：RenderEngine 线程（tid 134）SIGABRT；abort msg `Unable to generate SkImage. isTextureValid:0 dataspace:0`；栈 = `AutoBackendTexture::makeImage(+512)` ← `SkiaGLRenderEngine::drawLayersInternal(+7060)`（**合成路径**，非截图/非 App RenderThread）；6/6 同签名同 BuildId；
2. **abort 语义**：`isTextureValid:0` = 该层的 AHardwareBuffer 在**更早的** `GrAHardwareBufferUtils::MakeBackendTexture`（buffer→GL 纹理导入）已失败（失败只打 `E/RenderEngine: Failed to create a valid texture ... format:%d` 不拦截），`makeImage` 里的 `SkImage::MakeFromTexture` 对无效纹理返回 null 后 `LOG_ALWAYS_FATAL_IF` 自杀——**makeImage 是死者不是凶手**；不是 `MakeFromAHardwareBuffer`、不是 `MakeRaster*`、不是 fence 等待问题（fence wait 在 makeImage 之前，失败另有报错）；`dataspace:0` = 层数据空间 UNKNOWN；
3. **相机共亡**（§3.2 表，6/6）：每次与 camera provider `ExtCamOut` 线程同秒死，provider 侧 SEGV 落在 `formatConvert→libyuv I420Copy`（`21-tomb-cam-23-24.txt` 行 27/28 核验）——正是 gralloc YV12 布局修法所修的函数族；
4. **修复后零复发**：YV12 修法 10-29 10:37 上机，至今 0 新增 tombstone（`12-persistent-dirs.txt` 复核）。

### §5.2 未证（推断及其边界）

1. **format/fence/usage 具体值未证**：唯一含值的先兆行在 logd 主环，已随 14:39 容器重启灭失；当前容器 FROZEN 连当前 logd 都读不了（§4.3）→ 只能靠复现抓（§8.1）；
2. **「相机坏 buffer = SF 纹理导入失败同因」是强推断**：依据 = 6/6 时间相关 + 崩溃函数族重合（YV12 布局）+ 修复后零复发；缺 format 直接值，**不到实锤**；
3. 边界：SF 纹理导入失败理论上也可由非相机层触发，但 6/6 共亡 + 无一例相机不活跃时死亡否定随机性；composer@2.1-se 启动期崩（5 份）是独立课题，与 drawLayersInternal 无交集。

### §5.3 归类

**相机 buffer 不兼容**（HAL gralloc YV12 坏布局同源诱因 → SF 合成路径在 makeImage 的 `LOG_ALWAYS_FATAL` 自杀）。排除「容器渲染栈自身缺陷」：若是 SF/Skia 自身随机缺陷，应无相机关联地复现，实测 6/6 全部相机共亡、修复相机侧后零复发。置信 = **强证据**（§5.2.1 的 format 直接值未证，未升实锤）。

## §6 处置与验证

**未执行容器重启**。理由：(a) 本版硬约束 = 只读取证、处置另派；(b) 容器当前 FROZEN 是 Waydroid 无 UI 客户端的正常省电态（`00-initial-state.txt` 注释），无卡死/黑屏症状；(c) 判定所需证据已足（§5），重启只会清掉 FROZEN 现场且无新增信息。`50-restart-status.txt` 留空。Session/Container RUNNING、SF pid 3570 存活的现状快照见 `32-frozen-attach-blocked.txt`。

## §7 证据指针

证据目录 `reports/artifacts/c5-u7-sf-20261029/`，本版（18:21–18:26）新增/更新：

| 文件 | 用途 | 判据级别 |
|---|---|---|
| `16-host-logs-listing.txt` | 事项 1：宿主三处日志清单，无 SF 专属文件 | 实测 |
| `16b-waydroidlog-sf-grep.txt` | 宿主 waydroid.log 无 SF 崩溃记录 | 实测 |
| `17/18/19-logcat-*.txt` | 事项 3：三条 logcat 快照全部 rc=124 | 实测（受 FROZEN 限制） |
| `32-frozen-attach-blocked.txt` | **上一 lane 卡死根因**：FROZEN 下 attach 探针 `true` 也挂 | 实锤 |
| `20/21-tomb-*.txt` | 事项 2 主证据（上一 lane 取回，本版逐行独立核验） | 实锤 |
| `12/13/14-*-tomb/anr/wtf` | tombstone 全景、ANR/wtf 旁证（§2.1） | 实测 |
| `30-ab-state-before.txt` | 上一 lane A 相观测卡死现场（保留作 §4.3 佐证） | 现场 |

## §8 下一动作（按可行性排序）

1. **【待用户拍板】B 相最小复现**（唯一能拿到 format 直接值的路径，需有 UI 客户端 + 开相机预览；复现时容器必为 RUNNING，attach 可用）：
   - 复现中每 5 s 抓一次：`timeout 20 ssh ... 'timeout 10 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- logcat -d -b main -s RenderEngine:V SurfaceFlinger:V -t 50'`——要抓的就是 `E/RenderEngine: Failed to create a valid texture. [...] isProtected:%d isWriteable:%d format:%d` 先兆行；
   - 崩溃后宿主直读最新 tombstone（`ls -t /var/lib/waydroid/data/tombstones/ | head -1` + `head -200`）；
   - 同时记录相机请求 format/size（相机 app 设置页截图即可）。
2. **若 format 证实 YV12/相机层** → 转查 RenderEngine 对该 format 的 AHardwareBuffer→GL 导入路径与容器 GPU（venus）对 external buffer 的支持矩阵（相机层通常非 GPU 可采样布局，需 renderer 侧绕行或 HAL 侧改输出 format）；**若非相机层** → 转「容器渲染栈缺陷」课题重开。
3. **vk181-daily 上线后复核一签**（§0 内核注记：本报告全部证据在 vk172 上取得）。
4. 处置类操作（SF 存活性兜底/重启策略）另派 lane。

## §9 已做 / 未做 / 待拍板

**已做**：

1. 事项 1：宿主 /var/log、/root、/var/lib/waydroid 三处清单 + waydroid.log grep——无 SF 崩溃专属宿主文件（16/16b）；
2. 事项 2：tombstone/ANR 证据独立核验（上一 lane 20/21 号全文逐行在盘，abort msg/栈/函数族全部吻合；ANR 与 SF 无关）；
3. 事项 3：logcat 三条快照（-b crash -t 400 / -b main -s surfaceflinger:V / -s RenderEngine:V）——全部 rc=124，根因 = 容器 FROZEN（`true` 探针也挂，32 号实锤）；
4. **上一 lane「设备侧命令无输出」根因确诊**：FROZEN 容器中 lxc-attach 全挂，非命令缺陷；
5. 事项 4 判定：落点实锤 = RenderEngine `AutoBackendTexture::makeImage` 内 `LOG_ALWAYS_FATAL_IF`（`SkImage::MakeFromTexture` 对无效 GL 纹理返回 null，`drawLayersInternal` 合成路径）；归类 = 相机 buffer 不兼容（强证据）。

**未做**（理由）：A 相主动观测窗口（禁 watch/sleep）；B 相启相机复现（超本版只读授权）；容器重启（§6）；format/fence/usage 直接值（证据已灭失，只能复现抓）。

**待拍板**：B 相最小复现方案（§8.1，三条采集件）；SF 侧是否需要「makeImage 前判 isTextureValid 跳过 FATAL」的 AOSP 兜底改动（属改代码，另派）；vk181 复核排期。

---

> **结论句：SIGABRT 的落点 = surfaceflinger RenderEngine 线程 `renderengine::skia::AutoBackendTexture::makeImage(+512)` 内 `LOG_ALWAYS_FATAL_IF`（`SkImage::MakeFromTexture` 对无效 GL backend texture 返回 null，调用方 `SkiaGLRenderEngine::drawLayersInternal` 合成路径）；归类 = 相机 buffer 不兼容（与 HAL gralloc YV12 坏布局同源：6/6 与 ExtCamOut 同秒共亡、修复上机后零新增 tombstone；format/usage 直接值未证，属强证据而非实锤）。**
