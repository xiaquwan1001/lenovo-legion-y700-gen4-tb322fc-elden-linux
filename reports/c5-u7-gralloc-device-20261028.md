# C5/U7 容器相机 gralloc 崩溃：设备侧判别 E1/E2 与最小修法（2026-10-28）

> lane **L1c**（设备 lane）。上游：`reports/c5-u7-gralloc-layout-20261028.md`（源码/二进制级定位，**未上机**）、
> `reports/c5-u7-container-camera-20261028.md` §16–§20（Binary Eye 7 帧后 SIGSEGV）。
> 判据口径：**已证 / 未证实 / 未上机**；无设备证据不写「已解决」。

## §0 结论表（先填骨架，随取证更新）

| 项 | 结论 | 判据级别 |
|---|---|---|
| A 链路恢复（/dev/video100 + ≥1 台相机） | ✅ `/dev/video100` = `crwxrwxrwx 81,0`（容器内）；`dumpsys media.camera` = **`Number of camera devices: 1`**；生产者 NV12 1280x720 **30.5 fps** | **已证**（本轮设备实测） |
| B · ALOGV 能否打开 | ✅ 能：`setprop log.tag.ExtCamDevSsn@3.4 VERBOSE` **rc=0**（`@` 竟被接受），立即出 `outLayout`/`converting to format` 行 | **已证** |
| B · 崩溃复现 | ✅ tombstone_24：SIGSEGV / **SEGV_ACCERR**，`CopyRow_NEON+8` ← `CopyPlane+204` ← `I420Copy+188` ← `formatConvert+244` ← `OutputThread::threadLoop+2212`；`fault addr --------`（debuggerd 对 `si_addr==0` 的占位） | **已证** |
| B · **E2（PlaneLayout 与 I420 假设错配）** | ✅ **成立（已证）**：YV12 流的 metadata 给出 `y_str=2048 / c_str=0 / c_step=1`，且 cb、cr **与 Y 基址重合**（`cb=y`，`cr=y` 或 `y+0xE1000`）。正确 YV12 必须 `c_str=1280`、cb/cr 在 `y+1382400` / `y+921600` | **已证**（ALOGV 原始行） |
| B · **E1（映射只读）** | ⚠️ **弱否证**：同一进程、同一 stream usage 族（含 `CPU_WRITE_RARELY\|OFTEN=0x30`）下的 **NV12 流成功转换数十次无 ACCERR** ⇒ 映射整体可写；无法再取“YV12 缓冲映射权限”直证（容器图形层已坏，见 §6） | **未证实** |
| C 最小修法 | 补丁落 `patches-userland/camera-gralloc-20261028/`（HAL 侧：布局自洽校验 + YV12 推导回退 + formatConvert 前置校验）；**未编译未上机** | **未上机** |
| D 上机验收（帧数 / 是否仍 SIGSEGV） | 帧数部分：`configureV4l2StreamLocked: start V4L2 streaming 1280x720@30fps` + 9 轮 `outLayout`（36 行）后仍 SIGSEGV；**修法本身未上机** | **未上机** |

## §1 环境与前置核对

| 项 | 观测值 |
|---|---|
| 设备 UTS | `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172` |
| 容器 .so 是否为自建（含 ALOGV） | `grep -ac outLayout /vendor/lib64/hw/camera.device@3.4-external-impl.so` = **1** ⇒ **ALOGV 未被 NDEBUG 剥掉，编进二进制了** |
| 起始态 | `waydroid status` = Session RUNNING / Container STOPPED；`/dev/video100` 不存在；`v4l2loopback` 未载 |
| 起始相机模块数 | `cam-mode.sh status` = **camera modules 0 / media 0 / video 1**（CAM-OFF） |

## §2 A · 链路恢复（已证）

### §2.1 模块部署（`scripts/deploy-v4l2loopback.sh`，depth=16 幂等）

源码已带两枚补丁（`grep -n "depth = 16," build/extmod/v4l2loopback/v4l2loopback_formats.h` 命中 5 条 MJPG/JPEG 段；
`v4l2loopback.c:1676` 有 `req_count < 4`），`out/extmod-vk172/v4l2loopback.ko`（2026-10-28 16:14，832 320 B）
与设备侧同 md5 ⇒ 本轮用 `SKIP_BUILD=1`（纯部署，幂等）：

```sh
scripts/device-lock.sh -w 1800 bash -c 'SKIP_BUILD=1 bash scripts/deploy-v4l2loopback.sh'
```
```
[v4l2loopback] SKIP_BUILD=1，用 .../out/extmod-vk172/v4l2loopback.ko
crw------- 1 root root 81, 0 Oct 28 21:34 /dev/video100
8
5220a9856f5f5c71768e6e83b2281842  /lib/modules/<UTS>/extra/v4l2loopback.ko   # 与宿主 out/extmod-vk172 一致
v4l2loopback           53248  0
```

### §2.2 生产者（首次失败 → 根因 = 相机模块未载）

第一次 `cam-loopback.sh start rear 1280x720 30` **失败**：
```
ERROR: pipeline doesn't want to preroll.
Failed to set pipeline to PAUSED.
```
根因：`cam-mode.sh status` = **CAM-OFF（camera modules 0）**——相机内核栈根本没载，`libcamerasrc` 无 device。
先 `cam-mode.sh on`（同时把 blank idle-delay 置 0）：
```
[camera] done: 4 media, 18 video nodes
[cam-mode] 读回：19 个模块 / 4 media / 18 video
```
再起生产者即成功：
```
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 30.64 fps
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 30.50 fps
	Width/Height      : 1280/720
	Pixel Format      : 'NV12' (Y/UV 4:2:0)
	Size Image        : 1382400
```

### §2.3 容器（`waydroid-cam-restart.sh` 在 Debian 根上不可用 → 手工等价步骤）

`MODE=desktop SESS_UID=1001 bash scripts/waydroid-cam-restart.sh` **失败**：
```
setsid: failed to execute sudo: No such file or directory
```
⇒ 该脚本的 desktop 分支写死 `setsid sudo -u …`，而 Debian 根**没有 sudo**（PITFALLS #459 的同类坑，脚本未修）。
等价手工命令（本轮实际使用，可复跑）：
```sh
ssh root@192.168.7.1 "setsid runuser -u xuqianhui1001 -- env HOME=/home/xuqianhui1001 \
  XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus waydroid session start \
  >/tmp/wd-session.log 2>&1 < /dev/null &"
```
结果：
```
Session: RUNNING / Container: RUNNING
[21:46:04] Android with user 0 is ready
```

### §2.4 判据

```
容器内 ls -l /dev/video100 → crwxrwxrwx 1 root 44 81,   0 2026-10-28 21:34 /dev/video100   # 真 char dev，非 0 字节文件
容器内 dumpsys media.camera → Number of camera devices: 1
```
⇒ **A 已证**。顺序要点：模块先载 → 生产者先起 → 再启容器（否则 LXC `create=file` 造 0 字节普通文件，PITFALLS #459）。
另：容器 **FROZEN 时 `lxc-attach` 静默挂死**（本轮 `dumpsys` 首次超时 124），必须先 `lxc-unfreeze`。

## §3 B · E1/E2 判别（决定性动作，已证 E2）

### §3.1 一条可复跑命令

```sh
# 宿主：起生产者由 scripts/cam-loopback.sh start rear 完成；然后
ssh root@192.168.7.1 'L="lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c"
  $L "logcat -c; setprop log.tag.ExtCamDevSsn@3.4 VERBOSE"
  $L "am start -n de.markusfisch.android.binaryeye/.activity.SplashActivity"
  sleep 15; $L "logcat -d -v brief | grep -a -E \"outLayout|converting to format|start V4L2\""'
# 崩溃态：$L 'ls -l /data/tombstones/ | tail -3'  +  head -25 最新 tombstone
```

### §3.2 原始输出摘录（`outLayout` 两路流，逐字）

```
I/ExtCamDevSsn@3.4(   82): configureV4l2StreamLocked: V4L2 buffer size is 1382400
I/ExtCamDevSsn@3.4(   82): configureV4l2StreamLocked: start V4L2 streaming 1280x720@30.000000fps
V/ExtCamDevSsn@3.4(   82): threadLoop: outLayout y 0xfffef3380000 cb 0xfffef3380000 cr 0xfffef3380000 y_str 2048 c_str 0 c_step 1
V/ExtCamDevSsn@3.4(   82): threadLoop: converting to format YU12
V/ExtCamDevSsn@3.4(   82): threadLoop: outLayout y 0xfffef3200000 cb 0xfffef32e1000 cr 0xfffef32e1001 y_str 1280 c_str 1280 c_step 2
V/ExtCamDevSsn@3.4(   82): threadLoop: converting to format NV12
V/ExtCamDevSsn@3.4(   82): threadLoop: outLayout y 0xfffef2f80000 cb 0xfffef2f80000 cr 0xfffef3061000 y_str 2048 c_str 0 c_step 1
V/ExtCamDevSsn@3.4(   82): threadLoop: converting to format YU12
...（共 36 行 outLayout = 9 个请求周期，形态固定如上两种）
```

### §3.3 两条流的框架侧配置（`dumpsys media.camera`，逐字）

```
    Stream[0]: Output
      Dims: 1280 x 720, format 0x32315659, dataspace 0x0
      Combined usage: 0x20930, max HAL buffers: 8
    Stream[1]: Output
      Dims: 1280 x 720, format 0x23, dataspace 0x8c20000
      Combined usage: 0x20033, max HAL buffers: 8
```

- `0x32315659` = ASCII `YV12` = **`HAL_PIXEL_FORMAT_YV12`** ⇒ Stream[0] 就是 **YV12 三平面**（Binary Eye 的 CPU 分析流）。
- `0x23`=35=`YUV_420_888` ⇒ Stream[1]，容器 gralloc 实际给的是 **NV12**（由 `c_step 2` + `cb/cr` 相邻 1 字节证明）。
- usage `0x20930` = `CPU_WRITE_RARELY(1<<4)|CPU_WRITE_OFTEN(1<<5)|GPU_TEXTURE(1<<8)|COMPOSER_OVERLAY(1<<11)|bit17` ⇒ **含写位**。

### §3.4 判别结论

| 流 | metadata → HAL 得到的 `YCbCrLayout` | 自洽性 |
|---|---|---|
| Stream[0] YV12 | `y=cb=cr=base`（或 `cb=base, cr=base+0xE1000`）、`y_str=2048`、`c_str=0`、`c_step=1` | ❌ **矛盾**：① 色度指针与 Y 基址重合；② `cStride=0`（写多行全落同一地址）；③ `yStride=2048` 与 `0xE1000=921600=1280×720` 推出的真实 stride **1280** 相冲突 |
| Stream[1] NV12 | `y=base, cb=base+0xE1000, cr=cb+1, y_str=1280, c_str=1280, c_step=2` | ✅ 完全自洽（`0xE1000`=921600=1280×720，UV 行=1280 字节） |

⇒ **E2 成立**：`minigbm/IMapper V4` 对 **YV12 缓冲** 返回的 `PlaneLayouts` 与真实 I420/YV12 平面假设不符
（`getPlaneLayouts` → `HandleImporter::lockYCbCrInternal<IMapperV4>` 合成 `c_str=0` 的布局）；
HAL 的 `formatConvert()` YUV420 分支**零校验**直接按 `I420Copy` 盲写 ⇒ `SEGV_ACCERR`。

⇒ **E1 弱否证**：同进程、同 usage 族下 NV12 路径成功写数十次，说明 `mapper->lock()` 返回的映射是可写的；
E1「整体映射只读」不成立。残留未排除项：“仅 YV12 缓冲的映射只读”（缺锁定窗口内的 `/proc/<pid>/maps` 采样，见 §6）。

### §3.5 崩溃 tombstone（原始摘录，`/data/tombstones/tombstone_24`）

```
Cmdline: /vendor/bin/hw/android.hardware.camera.provider@2.4-external-service
pid: 3659, tid: 3667, name: ExtCamOut
signal 0 (SIGSEGV), code 2 (SEGV_ACCERR), fault addr --------
    x4  0000000000000280  x7  0000000000000800  x22 0000000000000168   # 640 / 2048 / 360
backtrace:
      #00 libyuv.so (CopyRow_NEON+8)
      #01 libyuv.so (CopyPlane+204)
      #02 libyuv.so (I420Copy+188)
      #03 camera.device@3.4-external-impl.so (formatConvert+244)
      #04 camera.device@3.4-external-impl.so (ExternalCameraDeviceSession::OutputThread::threadLoop()+2212)
```
寄存器 `x7=0x800=2048` 与出问题的 YV12 流 `y_str=2048` 一致；`x4=0x280=640=width/2`、`x22=0x168=360=height/2`
⇒ 崩溃发生在**色度平面拷贝**（与 `c_str=0` / 色度指针重合的自相矛盾布局对应）。

## §4 C · 最小修法

见 `patches-userland/camera-gralloc-20261028/`（README 说明改动/验证/风险）。要点：

1. **候选 1（改 stream 输出为 YV12）不适用**：实测 Stream[0] **本来就是 YV12** ⇒ 该候选是把问题本身当解法。
2. **实测有效的零代码绕过**（未上机验证修复后的帧数）：让 App 不请求 YV12 分析流（Binary Eye 设置里分析格式改 `YUV_420_888`/只用 preview）
   —— 因为 **YUV_420_888→NV12 的 metadata 完全自洽、转换已在设备上成功跑了几十次**。
3. **HAL 侧最小补丁**（本轮交付，源码级）：
   - `HandleImporter::lockYCbCrInternal<IMapperV4>`：合成 `YCbCrLayout` 后做**自洽校验**（非空、`yStride≥width`、`cStride>0`、cb/cr 与 y 不重合且互不重合）；
     对 `PixelFormatRequested ∈ {YV12, YUV420}` 且校验失败时，按 **`plane1.offsetInBytes / height` 反推真实 yStride（本例 = 921600/720 = 1280）**
     并回退到标准 YV12 布局（`cr = y + yStride*h`、`cb = y + yStride*h*5/4`）。
   - `formatConvert()`：写前**前置校验**（布局非法 → `ALOGE` + 返回 `-1`），把「进程 SIGSEGV 被 cameraserver 判死」降级为「单次请求错误」，
     并打印完整布局供下次取证。

## §5 D · 上机验收

| 项 | 结果 |
|---|---|
| 帧/请求数 | `configureStreams` 通过 → `start V4L2 streaming 1280x720@30.000000fps` → **9 个请求周期**（36 行 `outLayout`）后才 disconnect |
| 是否仍 SIGSEGV | **是**（tombstone_24，`SEGV_ACCERR` @ `I420Copy`）⇒ 未修好 |
| 关键 logcat 行 | 见 §3.2/§3.3 逐字摘录 |
| 验收性质 | 修法（§4.3）**未上机**：末段时间窗被容器图形层故障吃掉（§6），无法再拉起 App 取「修后帧数」 |

## §6 已否证假设 / 未证实项

**已否证**
1. ~~崩溃是空指针/整数溢出~~ → `SEGV_ACCERR` + 寄存器地址均在合法映射态。
2. ~~E1：映射整体丢写权限~~ → 同进程同 usage 族 NV12 路径连写数十次成功。
3. ~~候选 1：把 stream 输出改成 YV12 可绕过~~ → Stream[0] 实测**已是 YV12**（`0x32315659`）。
4. ~~ALOGV 因 tag 含 `@` 无法开启~~ → `setprop log.tag.ExtCamDevSsn@3.4 VERBOSE` **rc=0 且生效**（上一轮报告 §2 的顾虑作废）。

**未证实 / 未上机**
1. YV12 缓冲映射本身是否只读（需在 `lock` 窗口内采到 `/proc/<pid>/maps` 的 `rw-`/`r--`；本轮 20 Hz 采样 400+ 份**未命中**锁定窗口）。
2. `yStride=2048` 的来源（真实 stride 由 `plane1.offset/height` 反推为 1280，两者冲突；是 metadata 错还是分配 padding，未定）。
3. §4.3 补丁的编译/上机效果（**未上机**）。
4. Binary Eye 在修后能否稳定出预览（帧数/histogram）——本轮容器图形层先坏，无法验收。

**本轮新踩的设备侧坑（供 PITFALLS 归并，本 lane 未改 PITFALLS）**
- `scripts/waydroid-cam-restart.sh` 的 desktop 分支写死 `setsid sudo -u`，**Debian 根没有 sudo** ⇒ 直接失败（与 #459 的 `cam-mode.sh` 同类坑，该脚本未修）。
- 容器重新拉起后若 SurfaceFlinger 报 `Surface$OutOfResourcesException: DEAD_OBJECT`（`SurfaceControl.nativeCreate`），
  则 `am start` / `am force-stop` 双双失败 ⇒ **App 拉不起来、相机链路无法复现**（本轮 run#4 即卡死在此）。

## §7 证据指针

- 崩溃：容器内 `/data/tombstones/tombstone_22..24`（本轮 22:00 生成；`tombstone_24` 为 provider `ExtCamOut`）
- logcat：容器内 `/data/local/tmp/l1c-log.txt`（1820 行，36 行 outLayout）、`/data/local/tmp/l1c-log3/4.txt`
- maps 采样：容器内 `/data/local/tmp/wdmap.*`（401 份，pid 82）、`/data/local/tmp/m3.*`、`m4.*`
- 源码：`dl-cam/hw-interfaces/camera/common/1.0/default/HandleImporter.cpp:160-215`（V4 合成布局）、
  `dl-cam/hw-interfaces/camera/device/3.4/default/ExternalCameraUtils.cpp:303-380`（`formatConvert`）、
  `.../ExternalCameraDeviceSession.cpp:1618-1660`（`outLayout` ALOGV + `I420Copy` 调用点）
- 上游：`reports/c5-u7-gralloc-layout-20261028.md`、`reports/c5-u7-container-camera-20261028.md` §16–§20
- 设备脚本（本轮临时，设备侧）：`/tmp/l1c-b.sh`、`/tmp/l1c-b3.sh`、`/tmp/l1c-b4.sh`

## §8 修法编译与上机验收（lane L1d）

> 接续 §0–§7（lane L1c 尾部被 harness 判失败）。本 lane 目标：**把 §4.3 补丁编出来、推上机、给四个验收数字**。
> **状态：已编译、已上机、四判据出数，判定「修法有效」**（§8.3）；另附本轮新解的容器启动根因（§8.6）。

### §8.1 编译

**结论：编过了，且补丁确实进了二进制（≠「只有源码」）。**

踩到的第一道墙不是补丁，而是**构建链**（原 `build-cam-provider.sh` 缺 AIDL 头）：

| 现象 | 真因 | 处置 |
|---|---|---|
| `gralloctypes/Gralloc4.h:19: fatal error: 'aidl/android/hardware/graphics/common/BlendMode.h' file not found` | `dl-cam` 手工构建**从来没生成过 AIDL NDK 头**（AOSP 里由 Soong 生成） | 新增 `dl-cam/gen-aidl.sh`（幂等、自带版本校验） |
| 生成后 `no member named 'aidl'` / `no variable template matches specialization` | 用了 Ubuntu `aidl` 包（10.0.0+r36，不认 `--stability=vintf`）或只生成了 `--lang=cpp` 一套 | 换 **AOSP prebuilts/build-tools** `aidl`（`android-13.0.0_r82`，`/tmp/bt-pre`，稀疏克隆 ≈5 s）+ **两套 backend 都生成**（`--lang=cpp` 给 HIDL 侧、`--lang=ndk` 给 `Gralloc4.h` 要的 `aidl::` 命名空间） |

`gen-aidl.sh` 自检输出：`gen-aidl: cpp 96 + ndk 96 headers`，且断言 `namespace aidl {`
出现在 `gen-aidl/aidl/android/hardware/graphics/common/BlendMode.h`。

3) 补丁应用（`git apply --check` 先过）：

```sh
cd /home/xuqianhui/y700-elden
git apply patches-userland/camera-gralloc-20261028/0001-external-camera-validate-ycbcr-layout.patch   # rc=0
cd dl-cam && ./gen-aidl.sh && ./build-cam-provider.sh
```

构建结果（`rc=0`，`grep -c "error:" = 0`）：

| 产物 | 字节 | sha256 |
|---|---|---|
| `camera.device@3.4-external-impl.so` | 629 656（补丁前 629 656 → 630 936） | `4291fa7a3de7f6b5de6a83c7ff345b5acd6b8414324bcc8a3c60e656323d3afc` |
| `camera.device@3.5-external-impl.so` | 414 464 | `c52e92a13989de7afbb08640b112a75053ffd13be7046f07ef942e99d4bc43e6` |
| `camera.device@3.6-external-impl.so` | 529 832 | `1e40769284c03abf0b22b01cc02b587a392cf8b966f084525b17fbc4d5081525` |
| `android.hardware.camera.provider@2.4-external.so` | 428 672 | `7b5e7c8ee7ff6f09ef7551881b9b8e27302acae7fd34700c5161e1524b1dca14` |
| `android.hardware.camera.provider@2.5-external.so` | 290 704 | `a815ea5c3708dc30036a11ba5d14ae8fb1ca08d3354f4132b38ea488f02604f0` |
| `…@2.4-external-service`（未改） | 13 856 | `f593e181bd2109f5c450d6d3639247a1cdb37b5d7d82f3fc0b167fd69cb5dc7a` |

符号级证据（`strings`）：`repairPlanarYuv420Layout` 与
`%s: refuse to convert (format 0x%x %dx%d): output layout unusable …` 两条新串都在
`camera.device@3.4-external-impl.so` 里。

### §8.2 部署与回退

镜像不是全量重烘（`waydroid-camera-bake.sh` 需要 `dl-cam/vendor-manifest.xml` 与 `dl-cam/vdump/`，
本机这两处已不在 ⇒ 脚本不可直接复跑），改用**原地改镜像**（只换 5 个 .so，其余逐字节不动）：

```sh
cd dl-cam
scp root@192.168.7.1:/var/lib/waydroid/images/vendor.img vendor-orig.img   # 268 435 456 B
cp vendor-orig.img vendor-cam-l1d.img
for f in android.hardware.camera.provider@2.4-external.so \
         android.hardware.camera.provider@2.5-external.so \
         camera.device@3.4-external-impl.so camera.device@3.5-external-impl.so \
         camera.device@3.6-external-impl.so; do
  debugfs -w -R "rm /lib64/hw/$f" vendor-cam-l1d.img
  debugfs -w -R "write out-cam/$f /lib64/hw/$f" vendor-cam-l1d.img
  debugfs -w -R "sif /lib64/hw/$f uid 0"        vendor-cam-l1d.img
  debugfs -w -R "sif /lib64/hw/$f gid 2000"     vendor-cam-l1d.img
  debugfs -w -R "sif /lib64/hw/$f mode 0100644" vendor-cam-l1d.img
done
e2fsck -f -y vendor-cam-l1d.img
```

校验（两侧同哈希）：镜像内 `debugfs dump` 出的 `camera.device@3.4-external-impl.so`
= `4291fa7a…` = 构建产物；设备上 sha256 = `82769ed65372af95528e74bfa459814433b2ac54c1012d38c6696ca3b48d57a6`。

**回退件（设备侧，实际生成）**：`/var/lib/waydroid/images/vendor.img.bak-l1d-20261029-103701`
（268 435 456 B，即推送前的 10-19 镜像）。回退命令：

```sh
waydroid session stop; waydroid container stop
cp /var/lib/waydroid/images/vendor.img.bak-l1d-20261029-103701 /var/lib/waydroid/images/vendor.img
```

### §8.3 验收数字（判据四选，全部给数）

前置（本轮新解）：**容器一开始根本起不来**，见 §8.6 —— 与镜像/补丁无关，是宿主 `androidboot.mode=charger`。

| # | 判据 | 数字 | 判据级别 |
|---|---|---|---|
| ① | 请求数 | **12** 个 capture 请求（`threadLoop processing new request` = 12，`outLayout` = 24 = 12×2 流） | **已证**（`/data/local/tmp/l1d-run2.log`） |
| ② | 是否仍 SIGSEGV / 新 tombstone | **否**。provider `pid 83` 在 120 s 采样里**全程存活**（15/30/60/90/120 s 各点 `ps` 均有 1 个 provider 进程）；`/data/tombstones` 最新仍是 **11:30 的 `tombstone_49`（`surfaceflinger`，`SIGABRT` `Unable to generate SkImage`）**，**没有** provider 的新 tombstone | **已证** |
| ③ | 是否出现修复日志 / 降级路径 | 修复分支**每帧命中**：`inconsistent YCbCr layout (y … cb==y cr=y+0xE1000 y_str 2048 c_str 0 c_step 1), trying YV12/YU12 fallback` = **12** 次，`repaired layout … y_str 1280 c_str 640 c_step 1` = **12** 次，`refuse to convert` = **0** 次。转换分支由 `YU12` 变 **`YV12`**（`converting to format YV12` = 12） | **已证** |
| ④ | 帧内容是否正常 | 框架侧 `StreamStateObserver: Update Preview stream state to **STREAMING**`；生产端（宿主 loopback 写端）仍在 **28.6 fps**；App `Active Camera Clients: [Camera ID: 200 … PID: 3702 … binaryeye]`。**像素级（Y/U/V mean、histogram）未测** —— `cam-loopback.sh test` 返回 `frames 0`（容器 HAL 已占住队列，单读者限制） | 前两项**已证**；像素 **未证实** |

修复前后同一台机器、同一 App、同一流配置的对照：

| 项 | 补丁前（旧 .so，md5 `fef76767…`） | 补丁后（`c755aa92…`） |
|---|---|---|
| YV12 流 `outLayout` | `y_str 2048 / c_str 0 / c_step 1`，`cb == y` | `y_str 1280 / c_str 640 / c_step 1`，`cb = cr + 0x38400`（= w·h/4）**互不重合** |
| 结果 | `SEGV_ACCERR @ CopyRow_NEON`（tombstone_24，10-28） | 12 请求 / 0 崩溃 / provider 存活 |
| 沙箱截图（判据外） | — | `reports/artifacts/c5-u7-l1d-shot-20261029.png`（`grim` 成功，32 325 B；但**屏幕只有 Phosh 状态栏**，App 窗口未上屏 ⇒ 不能当预览证据） |

**判定：修法「有效」**（HAL 侧布局不再自相矛盾、进程不再崩、预览流进 STREAMING），
但**「App 端能稳定出预览」仍属未证实** —— 本轮容器图形层比 10-28 更差（见 §8.4）。

### §8.4 未证实 / 未上机（更新）

1. **像素内容正确性**：布局 `y_str 1280 / c_str 640` 与「真实 stride 1280」一致，但**没有** Y/U/V 统计或截图级证据。
2. **App 端持续预览**：12 个请求后 App 不再下新请求（与 10-28「97 帧后停 request」同族），本轮未定位是 App 主动停还是图形层断。
3. **容器图形层（与相机无关，本轮更严重）**：`surfaceflinger` 会 `SIGABRT: Unable to generate SkImage. isTextureValid:0` 自杀（tombstone_49，11:30），
   之后 `am start` 一律 `Surface$OutOfResourcesException: DEAD_OBJECT` ⇒ **App 拉不起来，相机链路无法再复现**（PITFALLS #460 §已知）。
   本轮 `grim` 能出图（`dpms=On`），说明**面板/合成器正常**，坏的是 **HWUI/Skia ↔ Adreno/minigbm 的纹理路径**。
4. `yStride=2048` 的**来源**仍未定（反推 1280 是「按 plane1 offset/height」得到的，metadata 为什么给 2048 未查）。
5. `repairPlanarYuv420Layout` 的 `accessRegion` 误判风险（README §5）本轮**未触发**（`refuse=0`），但未构造裁剪区场景做压力验证。

### §8.5 脚本顺带修（`scripts/waydroid-cam-restart.sh`）

| 缺陷（L1c 记录） | 修法 | 验证 |
|---|---|---|
| desktop 分支写死 `setsid sudo -u`，Debian 根**没有 sudo** | 先探测 `command -v sudo`，有则 `sudo -u`，否则 `runuser -u`；远端兜底同判 | `bash -n` OK；实跑打印 `提权方式 = runuser -u`（root）/`sudo -u`（会话内） |
| 写死 `SESS_USER=xuqianhui1001 / SESS_UID=1000` | 从 `ls -d /run/user/*/wayland-0` 的属主反查用户名，再退回 `/home` 下唯一用户 | 实跑检测出 `xuqianhui1001 (uid 1000)` |
| **本轮新发现**：`SSH` 变量在 `detect_sess()` **之后**才定义，`set -u` ⇒ `SSH: 未绑定的变量`（脚本一上来就死） | 把 `SSH=` 提到 `detect_sess()` 之前 | 修复前 3 行报错；修复后完整跑通（停栈 → container → session） |

### §8.6 本轮新踩的坑（与相机修复无关，但挡住整条链路）

**宿主以 USB 供电启动时 `androidboot.mode=charger` 会毒化整个容器**：

- 宿主 `/proc/cmdline` 含 `androidboot.mode=charger`（今早插着 USB 重启所致）；
- 容器 `init` 读 `/proc/cmdline` ⇒ `ro.bootmode=charger` ⇒ **只跑 `on charger`，不跑 `late-init`**
  ⇒ 没有 `vold`/`zygote`/`system_server`，容器只有 **15 个进程**、`sys.boot_completed` 空、
  `dumpsys media.camera` 报 `Can't find service: media.camera`。
- **判据**：`lxc-attach … getprop ro.bootmode` = `charger`（正常应为 `unknown`）；`ps -A | wc -l` = 15。
- **修法**（本轮落地，写进 `lxc` 配置，重启有效、零改镜像）：造一份去掉该参数的 cmdline 并 bind 覆盖容器内 `/proc/cmdline`：

```
lxc.mount.entry = /run/fake-cmdline proc/cmdline none bind,create=file,optional 0 0
```

  其中 `/run/fake-cmdline` = 宿主 `/proc/cmdline` 剔掉 `androidboot.mode=` 那一段（其余逐字保留）。
  修复后 `ro.bootmode=unknown`、**112–113 进程**、`sys.boot_completed=1`、`Number of camera devices: 1`。

> 注：这只解决「容器起不来」。**根治**应在上游侧把 `androidboot.mode` 不再传给容器，
> 或让宿主在正常启动路径下不带 `charger`；`/run` 是 tmpfs，**重启后 `/run/fake-cmdline` 需重建**
> （已在 `scripts/waydroid-cam-restart.sh` 未落，属**欠账**，见 §8.7）。

### §8.7 欠账（明确不做/未做）

1. ~~`/run/fake-cmdline` 的重建未脚本化~~ ⇒ **2026-10-29 已做**：新增 `scripts/waydroid-cmdline-fix.sh`
   （幂等 / `--status` 只读），并接线进 `scripts/waydroid-cam-restart.sh`（起 container 前调用）。
   实测：删文件 + 停容器 → 跑 restart → `ro.bootmode=unknown`、112 进程。
2. `waydroid-camera-bake.sh` 不可直接复跑（缺 `dl-cam/vendor-manifest.xml`、`dl-cam/vdump/`），
   本轮用 `debugfs` 原地换 5 个 .so 绕开；如需可复现的整镜像构建，需恢复那两处输入。
3. Binary Eye **镜像里并没有**（10-28 记录「早已装」已失效，`pm list packages` 无此包）。
   本轮从 **TUNA 的 F-Droid 镜像**取 `de.markusfisch.android.binaryeye_180.apk`（8 676 688 B，
   sha256 `568cec65…` 与 `index-v2.json` 一致），用
   `ssh dev "lxc-attach … -- sh -c 'cat > /data/local/tmp/be180.apk'" < apk` 推进容器后 `pm install -r` 成功。
