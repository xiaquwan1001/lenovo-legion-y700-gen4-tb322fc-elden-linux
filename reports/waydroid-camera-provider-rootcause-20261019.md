# 容器侧 camera provider：三层 ABI 缺陷定位并修复（vk127，2026-10-19）

> 任务 = `TASKS/README.md` C5 ②b（容器内相机出流验收）。
> 上一轮卡在「provider 注册成功后首笔 binder 事务 SIGSEGV」，归因为含糊的「工具链 ABI 不一致」。
> **本轮把三层独立缺陷全部指名并修掉**：`init.svc.vendor.camera-provider-2-4-ext` 首次 = **running**。
> 坑：`PITFALLS` §51（#344–#349）。构建脚本：`dl-cam/build-cam-provider.sh`。

## 0. 数字结论

| 项 | 修前 | 修后 |
|---|---|---|
| `init.svc.vendor.camera-provider-2-4-ext` | `restarting`（crash-loop，每次 1 s 内崩） | **`running`（稳定存活）** |
| 崩溃点 | `BHwBinder::transact+156`，`pc=0xffffffffffffffe0` | 无崩溃 |
| 我们 `.so` 导出的冲突符号（`__tree`/`ConcurrentMap`/`ServiceManager`…） | 6309 个导出，其中大量模板实例 | **0** |
| 端到端真帧（主机 loopback `test 10`） | — | **10 帧，Y mean 107 / min 16 / max 231** |
| `dumpsys media.camera` → `Number of camera devices` | 0 | **1**（`Device 0 maps to "200"`，Facing Front） |

## 1. 缺陷一：容器 `IBinder` 比 AOSP 多一个虚函数 ⇒ 所有 Bn vtable 错位一格

**证据链**（全部可复现，反汇编 5 分钟定死）：

1. 从容器取真正在跑的平台库：
   `ssh root@<dev> 'waydroid shell cat /apex/com.android.vndk.v33/lib64/libhidlbase.so' > libhidlbase.so`
   （BuildId `f47c485f44f9efff607f7408fde18085`，与 tombstone 里的 BuildId 逐字一致 ⇒ 验证取对了）。
2. 反汇编 `BHwBinder::transact`：
   ```
   0xa1ecc: ldr x8, [x23]        ; vptr
   0xa1ee4: ldr x8, [x8, #96]    ; 槽 12 = onTransact
   0xa1f00: blr x8
   ```
3. dump 容器 `_ZTVN7android4hidl4base4V1_08BnHwBaseE`：

   | 槽 | 容器（Waydroid fork） | 我们（纯 AOSP 头） |
   |---|---|---|
   | 10 | `localBinder` | `localBinder` |
   | 11 | `remoteBinder` | `remoteBinder` |
   | **12** | **`IBinder::isHostHwBinder()`** | **`BnHwBase::~`(D1)** |
   | 13 / 14 | D1 / D0 | D0 / **onTransact** |
   | **15** | **`onTransact`** | `0xffffffffffffffe0`（磁盘填充值） |

   ⇒ 平台按槽 12 调进析构函数；我们再差一格取到 `-32` ⇒ `blr -32` = `pc=0xffff…ffe0`。

**根因**：容器 `libhidlbase.so` 是 **Waydroid 定制 fork**（`waydroid/android_system_libhwbinder`，
patch `0006-Be-more-explicit-about-using-host-hwbinder.patch`），在 `IBinder::remoteBinder()` 之后
插入 `virtual bool isHostHwBinder();` —— AOSP 上游没有这个虚函数。
⇒ **任何**用 AOSP 头编的 Bn 类在 Waydroid 容器里首笔事务必崩，与 camera 代码**无关**
（这也解释了上一轮「donor 平台自产 2.5 provider 也崩」：它是用同一套 AOSP 头编的）。

**修法**（`dl-cam/aosp/libhwbinder/include/hwbinder/IBinder.h`）：
```cpp
    virtual BHwBinder*        localBinder();
    virtual BpHwBinder*       remoteBinder();
    // ELDEN: Waydroid's libhwbinder (android_system_libhwbinder) inserts this
    // virtual right after remoteBinder(). AOSP does not have it, so a provider
    // compiled against plain AOSP headers has every Bn vtable shifted by one
    // slot and BHwBinder::transact reads onTransact from the wrong slot
    // (vtable[12] == -32) => SIGSEGV on the first binder transaction.
    virtual bool              isHostHwBinder();
```

⚠️ **坑**：`build-cam-provider.sh` 只按 `src -nt obj` 判断是否重编，**不跟踪头依赖** ⇒
改完头文件直接重跑，产物 vtable 逐槽未变，会误判「改了没用」。必须 `rm -rf out-cam/obj`。

修后核对：槽 11=`remoteBinder`、槽 12=`isHostHwBinder`、13/14=D1/D0、**15=`onTransact`**，
与容器 `BnHwBase` 逐槽相同。

## 2. 缺陷二：自编 `.so` 的模板实例抢占平台同名 WEAK 符号

vtable 修好后崩溃换位置，暴露第二层：

```
#01 free+96                     libc.so
#02 hidl_string::~hidl_string+44 libhidlbase.so     ← abort: "Pointer tag for 0x1 was truncated"
#03 getRawServiceInternal+408    libhidlbase.so
```
随后（继续修 manifest/接口后）变成：
```
#00 memcmp+12                   libc.so            ← x1 = 0x31
#01 __tree<…>::__find_equal+156 OUR BINARY
#02 ConcurrentMap<std::string,…>::set+76  libhidlbase.so
#03 hidl::manager::V1_0::static_constructor+216  libhidlbase.so
```

**判据**：`llvm-readelf --dyn-syms -W <our.so>` 统计我们自己定义的导出符号 = **6309** 个，
其中包含 `std::__1::__tree<…>`、`__hash_table`、`basic_string`、`ConcurrentMap` 等
**libc++/libhidl 模板实例**（来自 `--allow-multiple-definition` + 默认可见性）。
动态链接时这些 WEAK 定义**压过平台 `libhidlbase.so` 里的同名符号** ⇒
平台代码调进我们的实例、我们用自己的实例，两边对同一对象的布局/生命周期理解不同 ⇒ 踩内存。

**修法**：版本脚本 `dl-cam/elden-cam-exports.map`，只导出自家类与 vtable：

```
{ global:
    _ZT*;                       /* vtable/typeinfo/vthunk，平台按名取 */
    _ZN7android8hardware6camera*;
    _ZNK7android8hardware6camera*;
    _ZN7android8hardware6detail*;
    _ZN7android8hardware*registerPassthroughServiceImplementation*;
    _ZN7android8hardware6detail16HidlInstrumentor*;
    HIDL_FETCH_*;               /* legacy passthrough 的 dlsym 入口 */
  local: *; };
```
`link_so()` 与服务二进制链接都加 `-Wl,--version-script="$HERE/elden-cam-exports.map"`。
冲突导出 6309 → **0**。

⚠️ **`HIDL_FETCH_*` 必须留在 global**：被 `local: *` 吞掉后，容器日志持续报
`Passthrough lookup opened …-impl.so but could not find symbol HIDL_FETCH_ICameraProvider`
+ `Could not get passthrough implementation for …ICameraProvider/external/0` ——
服务能起来，但永远 0 设备。这一点很容易被当成「再一个 ABI 问题」而绕远路。

## 3. 缺陷三：自己生成的 `android.hidl.manager.*` Bn/Bp 盖掉平台实现

中间还出现：`IInterface::asBinder(nullptr)` SIGSEGV（`pc=0xb8`），栈为
`getRawServiceInternal+392` → **我们二进制里的** `BpHwServiceManager::_hidl_getTransport`。

**根因**：`hidl-gen -Lc++-sources` 把 `android.hidl.base/memory/allocator/manager/token`
的 Bn/Bp 也生成了一遍并链进我们的 `.so`；容器 `libhidlbase.so` 内已有权威实现 ⇒ 同名符号抢占。

**修法**：`dl-cam/gen-src.sh` 里把 `libhidl/transport/*` 全部注释掉，只生成
`android.hardware.camera.*`（+ camera 头间接需要的 `graphics.*`）。重新生成后 51 → 40 个源文件。
注意 `SELFIFACE=1` 的库过滤**只剥** `-l:android.hardware.camera.*`，`android.hidl.*` 的**链接库**要保留
（头文件仍由 `hidl-gen -Lc++-headers` 生成，只是**源码**不自己编）。

## 4. 附带修复：clang-14 在 `-O2` 下编 gen-src 会 ICE

`clang frontend command failed with exit code 139`，触发文件例
`gen-src/android/hardware/camera/device/3.4/CameraDeviceSessionAll.cpp`。
gen-src 的编译加 `-O1` 即绕过（非性能关键路径）。

## 5. 缺陷四：64 位下 `kDevicePrefixLen` 用 `sizeof(const char*)` ⇒ 设备号恒为 0（★最后一跳）

provider 稳定 running、`/dev/video100` 也在容器里可见，但 `dumpsys media.camera` 仍报
`Number of camera devices: 0`。这不是「注册」问题，而是**设备号解析错位**：

```
V CamPrvdr@2.4-external: Non-internal v4l device video100 found
I CamPrvdr@2.4-external: ExtCam: adding /dev/video100 to External Camera HAL!
V CamPrvdr@2.4-external: Constructing v3.4 external camera device
E ExtCamDev@3.4: initCameraCharacteristics: v4l2 device open /dev/video0 failed
E ExtCamDev@3.4: isInitFailedLocked: init camera characteristics failed: errorno -32
E CamPrvdr@2.4-external: getCameraDeviceInterface_V3_x: camera device /dev/video0 init failed!
```

看到 `video100` 却去 `open("/dev/video0")`，就是**设备号被算成 0**。上游 AOSP 原文：

```cpp
const char* kDevicePath = "/dev/";
constexpr char kPrefix[] = "video";
constexpr int kPrefixLen = sizeof(kPrefix) - 1;              // 5  ✅
constexpr int kDevicePrefixLen = sizeof(kDevicePath) + kPrefixLen + 1;   // ❌
```
`kDevicePath` 是 `const char*` ⇒ `sizeof` 是**指针大小**：
- 32 位：`4 + 5 + 1 = 10` ⇒ 正好是 `"/dev/video"` 长度 ⇒ `atoi("/dev/video100"+10) = 100` ✅（**上游只出 32 位，所以一直"正常"**）
- arm64：`8 + 5 + 1 = 14` ⇒ `atoi("/dev/video100"+14) = atoi("00") = 0` ❌

`addExternalCamera` 因此报 `device@3.4/external/0`；随后 `getCameraDeviceInterface_V3_x` 用
`matchDeviceName` 反算回 `/dev/video0`（容器里不存在）⇒ init failed ⇒ **永远 0 设备**。
这正是「上游 external HAL 只有 32 位」（`compile_multilib: "32"`）之外的**第二个 64 位适配缺陷**。

**修法**（`ExternalCameraProviderImpl_2_4.cpp`，2.7 同款一并修）：
```cpp
constexpr char kDevicePath[] = "/dev/";                     // 数组，不是指针
constexpr char kPrefix[] = "video";
constexpr int kPrefixLen = sizeof(kPrefix) - 1;
constexpr int kDevicePathLen = sizeof(kDevicePath) - 1;      // 5
constexpr int kDevicePrefixLen = kDevicePathLen + kPrefixLen; // 10 ✅（32/64 位都对）
```

## 6. 验收（C5 ②b 达成）

```
$ waydroid shell -- getprop init.svc.vendor.camera-provider-2-4-ext
running
$ waydroid shell -- dumpsys media.camera
Number of camera devices: 1
Number of normal camera devices: 1
Number of public camera devices visible to API1: 1
    Device 0 maps to "200"
  ...
== Camera Provider HAL external/0-0 (v2.5, remote) static info: 1 devices: ==
== Camera HAL device device@3.4/external/200 (v3.4) static information: ==
    Has a flash unit: false
    Facing: Front
    Orientation: 0
  API2 camera characteristics: 55 / 55 entries, 768 / 768 bytes of extra data.
    android.info.supportedHardwareLevel: [EXTERNAL]
```

日志侧完整链路：
```
Non-internal v4l device video100 found
index:0, format:YUYV, w 1280, h 720, framerate 30.000000
initOutputCharsKeys: advertising YUV streams for YUYV
ExtCam: adding /dev/video100 to External Camera HAL!
threadLoop start monitoring new V4L2 devices
Device interface chain: android.hardware.camera.device@3.2::ICameraDevice / android.hidl.base@1.0::IBase
```

端到端链路（本轮同时验证）：
主机 libcamera 软 ISP → `v4l2sink /dev/video100`（`test 10` 取到 10 帧，Y mean 107 / min 16 / max 231，
真帧非黑）→ LXC bind → 容器 provider → cameraserver `1 device`。

⚠️ 设备号是 **200**（= `video100` + `cameraIdOffset` 100），不是 0 —— 有些 App 会假设从 0 开始，
U7 验收时注意用 camera id `"200"`。

## 7. 下一跳（U7）与未做

1. 容器内 App 实际打开预览（`cmd media.camera` 只列出工具；需用相机 App 或 `dumpsys` 观察
   `Active Camera Clients` 出现条目）；
2. **前后摄切换**：目前只绑了前摄（`camera@31`）。后摄要先 `cam-loopback.sh start rear`，
   但 AOSP external HAL 的「切摄」本质是换 loopback 节点的内容，容器侧只有 1 个 external 设备
   ⇒ 切换语义需另行验证（可能需要第二个 loopback 节点 + 容器内多设备）；
3. 吞吐上限 ≈1.1 fps（原生）/ 2.0 fps（720p），软 ISP 瓶颈，不适合 30 fps 场景；
4. 未加载任何相机内核模块的**冷起**流程需补：现在相机栈是手工 `cam-mode.sh on` 拉起的。

## 8. 设备与仓库状态

- 设备：vk127 在机，容器 RUNNING，provider `running`；`vendor.img` = 本轮烘焙产物
  （备份 `vendor.img.bak-pre-cam-20261019-{145249,150811,151300}` 在 `/var/lib/waydroid/images/`）。
- **未加载任何相机内核模块**（Q24 默认安全态；`cam-mode.sh` 未开）。
- 改动文件：
  - `dl-cam/aosp/libhwbinder/include/hwbinder/IBinder.h`（补 `isHostHwBinder()`）
  - `dl-cam/elden-cam-exports.map`（新，版本脚本）
  - `dl-cam/build-cam-provider.sh`（version-script、gen-src `-O1`、libc++ ABI 宏）
  - `dl-cam/gen-src.sh`（去掉 `android.hidl.*` 源码生成）
  - `scripts/waydroid-camera-bake.sh`（`SMOKE=1` 时把 `hidl-smoke` 烘进 `/bin/hidl-smoke`）
- `dl-cam/` 是构建工作区（不入 git）。

## 10. 追加（同日）：容器相机上线后暴露的两个互斥/环境问题

### 10.1 Linux 相机 `couldn't play camera stream` = loopback 生产者独占 CSI/CSID

启用 C5 主机侧 loopback（`libcamerasrc → v4l2sink /dev/video100`）后，Linux 侧相机立刻失败：

```
ERROR MediaDevice: /dev/media0[qcom-camss]: Failed to setup link 'msm_csiphy4'[1] -> 'msm_csid0'[0]: Resource busy
Camera 1 not found / Failed to create camera session
```

- **根因**：`libcamerasrc` 独占整条 media pipeline（sensor → CSIPHY → CSID → VFE）。
  Linux 侧任何第二个相机客户端（`cam`、Snapshot、浏览器）都拿不到链路。
- **这是硬件事实，不是缺陷**：容器相机（C5）与 Linux 相机（G1-5）共用同一路 sensor ⇒ **同一时刻互斥**。
- 停掉生产者后 `cam -c1 -C2 --capture=2` 立刻恢复 **30.06 fps**（本轮实测）。
- **处置**：`scripts/cam-loopback.sh start` 增加互斥检查（检测到已有相机客户端会 `REFUSE`，
  `FORCE=1` 强制）；收尾必须显式 `stop`，与 `cam-mode.sh off` 同一纪律。

### 10.2 容器 GUI 拉不起 = session 挂到了 headless 空合成器

- **现象**：`waydroid app launch` / `show-full-ui` 返回 0，无窗口；用户表述「无法调起图形化界面」。
- **根因**：重启脚本固定 `XDG_RUNTIME_DIR=/run/user/0` + `weston --backend=headless-backend.so`。
  那是**没有真实输出的空合成器**；本机真实桌面是 **`xuqianhui1001`(uid 1000) 的 phoc**，
  socket 在 `/run/user/1000/wayland-0`。session 挂错合成器 ⇒ 有进程、没窗口。
- **判据**：`waydroid status | grep "Session user"` 应为 `xuqianhui1001(1000)`；
  或直接读 session 进程 environ 里的 `XDG_RUNTIME_DIR`。
- **修法**：改用会话用户的 phoc + 其 session bus（`scripts/waydroid-cam-restart.sh` 已改默认
  `MODE=desktop`；Q28 坏发才用 `MODE=headless`）。
- **连带三坑**：
  1. `waydroid container start` **不启 lxc** —— 它只是 DBus 常驻服务，容器由 `session start` 请求拉起；
  2. kill 后 dbus system bus 残留 `id.waydro.Container` ⇒ 静默 `Container service is already running`、lxc 仍旧 STOPPED；
     必须 `pkill -9 -f "waydroid containe[r] start"`；
  3. `Container: FROZEN` 是 Waydroid 的正常省电（无 UI 客户端时 `lxc-freeze`），不是故障。

### 10.3 状态

修复后：Linux 相机 `30.06 fps` 正常；容器 RUNNING、`Session user: xuqianhui1001(1000)`、GUI 已起（用户确认）。
`/dev/video100` 节点仍在但生产者已停（容器相机此时无帧，属预期互斥）。

## 9. 方法论（值得留）

1. **崩溃地址里的常量就是线索**：`pc = -32` 不是随机值，它是 `vtable[12]` 的磁盘填充；
   顺着「某个地方少/多了一个虚函数」查，比读代码快两个数量级。
2. **优先从容器里 `cat` 平台库**，不要从 vendor.img dump：容器里的才是真正在跑的那份
   （BuildId 与 tombstone 逐字比对可自证）。
3. **`.so` 导出符号必须先审**：跨 ROM 复用 HAL 时，`--dyn-syms` 里出现的 `std::`/`__tree` 一律是定时炸弹。
4. **「服务 running」和「有设备」是两件事**：前者只看注册与 binder 通路，后者还依赖
   `/dev/video*`、config XML、permission；别把 running 当验收通过。
5. 前两轮把问题记成「工具链 ABI 不一致」是含糊化，代价是多花了一整轮。
6. **占用独占硬件的实验脚本必须自带 `stop` 并写进收尾清单**：本轮忘了停 loopback 生产者，
   用户随后用 Linux 相机就撞上 `Resource busy`，看起来像「本轮改动把相机改坏了」。
7. **「进程起不来」先确认目标合成器对不对**：headless weston 与真实 phoc 是两套完全独立的
   Wayland 实例，挂错了表现为「app 有进程没窗口」，很容易被误判成容器/图形栈坏了。
   正确记法应落到**具体的槽位/符号名**上（本轮三条都能被 5 分钟反汇编独立验证）。
