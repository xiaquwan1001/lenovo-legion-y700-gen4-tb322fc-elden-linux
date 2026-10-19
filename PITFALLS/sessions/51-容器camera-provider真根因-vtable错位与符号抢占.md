# 51 — 容器 camera provider 的真根因：`IBinder` vtable 错位 + ELF 符号抢占（2026-10-19 实测，已修）

> 设备 vk127，Waydroid 1.6.2 MAINLINE（`TQ3A.230901.001`，VNDK 33）。上一会话把 C5 ②b 卡在
> 「provider 注册成功后首笔 binder 事务 SIGSEGV」，并把原因记成含糊的「工具链 ABI 不一致」。
> 本轮把三层**独立**缺陷全部指名并修掉，provider 首次 **`init.svc…= running`**（不再 crash-loop）。
> 报告：`reports/waydroid-camera-provider-64bit-20261018.md`；构建脚本 `dl-cam/build-cam-provider.sh`。

## #344 「`BHwBinder::transact` 崩在 `pc=0xffffffffffffffe0`」= 容器 `IBinder` 比 AOSP 多一个虚函数

- 现象：`SIGSEGV`，`pc = x8 = 0xffffffffffffffe0`（-32），`x23` = 对象、`[x23]` = vptr、
  落在 `/vendor/lib64/android.hardware.camera.provider@2.4.so` 的 `.data.rel.ro`；
  栈顶 `BHwBinder::transact+156`，`x1 = 0x0f43484e`（'NHC\\x0f'，AIDL/HIDL 事务码）。
- 判据（三步即可定死，别猜）：
  1. 从容器取平台库：`ssh root@<dev> 'waydroid shell cat /apex/com.android.vndk.v33/lib64/libhidlbase.so' > libhidlbase.so`
     （容器里 `cat` 出来的是**真正在跑的**那份，比 vendor.img 里 dump 更可信）。
  2. 反汇编 `BHwBinder::transact`：`ldr x8,[x23]` → `ldr x8,[x8,#96]` → `blr x8`
     ⇒ **槽 12（偏移 96）= onTransact**。
  3. dump 容器 `_ZTVN7android4hidl4base4V1_08BnHwBaseE` 的槽位：**槽 12 = `IBinder::isHostHwBinder()`**，
     D1/D0 在 13/14，onTransact 在 **15**；而我们（纯 AOSP 头）编出的类：D1/D0 在 12/13、onTransact 在 **14**
     ⇒ 平台按槽 12 取到的是**析构函数**、我们再差一格取到磁盘上的 `-32` 填充值。
- 根因：容器 `libhidlbase.so` 是 **Waydroid 定制 fork**（`waydroid/android_system_libhwbinder`，
  patch `0006-Be-more-explicit-about-using-host-hwbinder.patch`），在 `IBinder` 的
  `localBinder()/remoteBinder()` **之后**插了 `virtual bool isHostHwBinder();`；AOSP 上游没有。
  ⇒ **任何**用 AOSP 头编的 Bn 类在 Waydroid 容器里首笔事务必崩，与 camera 代码无关。
- 治法（`dl-cam/aosp/libhwbinder/include/hwbinder/IBinder.h`）：
  ```cpp
      virtual BHwBinder*   localBinder();
      virtual BpHwBinder*  remoteBinder();
      virtual bool         isHostHwBinder();   // ELDEN: Waydroid fork 专有，必须在 destructor 之前
  ```
- 坑：改完头文件 **`build-cam-provider.sh` 不会自动重编**（它只按 `src -nt obj` 判断，不跟踪头依赖）
  ⇒ 症状一模一样，会误判「改了没用」。必须 `rm -rf out-cam/obj`。
- 一般化：**HAL 二进制的 vtable 是 ABI 契约**。跨 ROM/容器复用 HAL 前，先 dump 平台基类的
  vtable 槽位表（`llvm-readelf -sW` 找 `_ZTV…` + `llvm-readelf -rW` 看每槽的重定位名），
  与自己的头文件声明顺序逐槽对齐；这类问题**反汇编 5 分钟能定死**，靠跑测试猜要几小时。

## #345 我们导出的 libc++/libhidl 模板实例会**抢占**平台同名 WEAK 符号 ⇒ 数据结构错配

- 现象：vtable 修好后崩溃换位置——`hidl_string::~hidl_string+44` 里 `free(0x1)` abort
  （`Pointer tag for 0x1 was truncated`），随后是 `ConcurrentMap<std::string,…>::set` →
  **我们自己的二进制里**的 `std::__1::__tree<…>::__find_equal` → `memcmp(x1=0x31)` SIGSEGV。
- 判据：`llvm-readelf --dyn-syms -W <our.so> | grep -c __tree`；本轮我们导出了 **6309 个**符号，
  含 `__tree`/`__hash_table`/`basic_string`/`ConcurrentMap` 等模板实例（`--allow-multiple-definition`
  + 默认可见性）。动态链接时这些 **WEAK 定义会压过平台 `libhidlbase.so` 里的同名符号** ⇒
  平台代码调进我们的实例、我们用自己的实例，两边对同一对象的生命周期/布局理解不同。
- 治法：加**版本脚本**（`dl-cam/elden-cam-exports.map`）只导出自家类与 vtable：
  ```
  { global: _ZT*; _ZN7android8hardware6camera*; _ZNK7android8hardware6camera*;
            _ZN7android8hardware6detail*; _ZN7android8hardware*registerPassthroughServiceImplementation*;
            _ZN7android8hardware6detail16HidlInstrumentor*; HIDL_FETCH_*;
    local: *; };
  ```
  链接加 `-Wl,--version-script=<map>` 后冲突导出从 6309 → **0**。
- **`HIDL_FETCH_*` 必须留在 global**：它是 legacy passthrough 的 dlsym 入口，
  被 `local: *` 吞掉后容器日志会一直报
  `Passthrough lookup opened …-impl.so but could not find symbol HIDL_FETCH_ICameraProvider`
  + `Could not get passthrough implementation for …::ICameraProvider/external/0`（服务能起、但永远 0 设备）。
- 一般化：**给 Android HAL 写 `.so` 时应默认 `local: *` + 白名单导出**。
  C++ 模板实例（`std::`/`android::hardware` 内部容器）绝不能泄漏到动态符号表。

## #346 不要自己生成 `android.hidl.manager.*` 的 Bn/Bp —— 平台已有，会盖掉

- 现象：`IInterface::asBinder(nullptr)` SIGSEGV，`pc=0xb8`，栈：
  `getRawServiceInternal+392` → **我们二进制里的** `BpHwServiceManager::_hidl_getTransport`。
- 根因：`hidl-gen -Lc++-sources` 把 `android.hidl.base/memory/allocator/manager/token` 的 Bn/Bp
  也生成了一遍；容器 `libhidlbase.so` 内有权威实现，我们的同名定义抢了绑定。
- 治法：`dl-cam/gen-src.sh` 的包列表里把 `libhidl/transport/*` 全部注释掉，只生成
  `android.hardware.camera.*`（+ `graphics.*` 被 camera 头间接需要的部分）；重新生成后 51 → 40 个源文件。
  同时 `SELFIFACE=1` 的库过滤只剥 camera 系 `-l:android.hardware.camera.*`，**不能**把 `android.hidl.*` 也剥掉。
  （`android.hidl.*` 的**头文件**仍要用 `hidl-gen -Lc++-headers` 生成，只是**源码**不自己编。）

## #347 clang-14 在 `-O2` 下编某些 hidl-gen 生成文件会 ICE（exit 139）

- 现象：`clang frontend command failed with exit code 139`，栈里是 llvm 内部；触发文件例：
  `gen-src/android/hardware/camera/device/3.4/CameraDeviceSessionAll.cpp`。
- 治法：gen-src 的编译加 `-O1`（这些不是性能关键路径）。别为此换 NDK 或降 codegen 全局选项。

## #348 容器里跑自编探针的三条限制（别浪费时间）

- **`waydroid shell <cmd>` 会被 argparse 吃掉**带 `-` 的参数（报 `unrecognized arguments`）⇒
  一律写 `waydroid shell -- <cmd>`。
- **不能往容器 stdin 灌数据**（`waydroid shell -- sh -c "cat > f"` 也不成）；
  `adb` 在 Waydroid 主机侧**没有** device；`/var/lib/waydroid/overlay*` **不是挂载点**（vendor 就是 loop 挂的 ext4）
  ⇒ 往容器加文件**只能重烘 vendor.img**（`scripts/waydroid-camera-bake.sh`，`SMOKE=1` 会顺带把
  `hidl-smoke` 装到 `/vendor/bin/hidl-smoke`）。
- **`waydroid shell` 上下文有 seccomp（`Seccomp: 2`）**：自编的 `hidl-smoke` 在那里会
  `Binder driver could not be opened. Terminating.`——这是**权限/profile**问题，**不是 ABI 问题**，
  不要据此改代码。要验证 ABI 就让 `init` 拉起服务（`.rc` + `init.svc.<name>`）看它是否 `running`。

## #350 64 位下 `kDevicePrefixLen = sizeof(kDevicePath) + kPrefixLen + 1` ⇒ 设备号恒为 0（★「0 devices」的最后一跳）

- 现象：provider `running`、容器里 `/dev/video100` 可见、日志有
  `Non-internal v4l device video100 found` + `ExtCam: adding /dev/video100`，但
  `dumpsys media.camera` = **0 devices**，且日志紧跟
  `E ExtCamDev@3.4: v4l2 device open /dev/video0 failed` + `init failed!`。
  **看到 video100 却 open video0** ⇒ 设备号被算成 0。
- 根因：上游 `ExternalCameraProviderImpl_2_4.cpp` 里
  ```cpp
  const char* kDevicePath = "/dev/";
  constexpr int kDevicePrefixLen = sizeof(kDevicePath) + kPrefixLen + 1;
  ```
  `sizeof(const char*)` = **指针大小**：32 位 → 4+5+1 = **10**（恰好是 `"/dev/video"` 长度，对）；
  arm64 → 8+5+1 = **14** ⇒ `atoi("/dev/video100"+14) = atoi("00") = 0` ⇒ 全设备号都是 0。
  上游 external HAL 只出 32 位（`compile_multilib: "32"`），所以这个 bug 上游从未暴露。
- 治法：`kDevicePath` 声明成**数组**，用 `sizeof(kDevicePath)-1` 拿长度：
  ```cpp
  constexpr char kDevicePath[] = "/dev/";
  constexpr int kDevicePrefixLen = (sizeof(kDevicePath) - 1) + kPrefixLen;  // 10
  ```
  2.7 版同款一并修（`ExternalCameraProviderImpl_2_7.cpp`）。
- 判据：改完 `dumpsys media.camera` 出现 `Number of camera devices: 1` 与
  `Device 0 maps to "200"`（**200 = video100 + cameraIdOffset 100，不是 0**）；
  日志出现 `Device interface chain: …camera.device@3.2::ICameraDevice`。
- 一般化：**把只出 32 位的上游 HAL 移植到 64 位，`sizeof(指针)` 是头号嫌疑**。
  `grep -n "sizeof(k[A-Z][A-Za-z]*)" ` 逐条核，凡是 `sizeof(指针变量)` 当长度用的都要改成
  `sizeof(数组) - 1` 或 `strlen()`。

## #351 容器的 camera 相关排查手感（省时间）

- `waydroid shell -- logcat -G 32M` 先放大缓冲，**重启容器后立刻** `waydroid shell -- logcat -d -b all > host.log`
  再 grep —— provider 是 pid 82 早早启动的，日志很容易在排查时已被滚掉（本轮因此误判「服务没打日志」）。
- provider 的 `LOG_TAG = "CamPrvdr@2.4-external"`（不是包名！），device 层是 `ExtCamDev@3.4`、
  config 层是 `ExtCamUtils@3.4`。按包名 grep 会一无所获。
- **`getCameraIdList()` 按 AOSP 设计永远返回空**（`ExternalCameraProviderImpl_2_4::getCameraIdList`
  注释写明「External camera HAL always report 0 camera」）——设备只通过
  `cameraDeviceStatusChange` 回调上报。所以「`getCameraIdList` 空」**不是** bug 判据，
  要看 `dumpsys media.camera` 的 `Camera service events log: ADD device …`。
- `stop vendor.camera-provider-2-4-ext` 会卡在 `stopping`（init 里该服务无 `oneshot`/`disabled` 语义），
  `start` 也起不来 ⇒ **要重启 provider 就重启整个容器**（`scripts/waydroid-cam-restart.sh`）。
- 主机侧 `v4l2loopback` + gst 生产者在容器重启后**不会自动回来**；且
  `/var/lib/waydroid/lxc/waydroid/config` 里 `/dev/video100` 的 bind 行历史上被 A/B 注释成
  `#TMPCAM# …`，会让容器看不到节点 —— 排查「容器没有 /dev/video100」先看这一行。

## #349 Q24 口径更正：「相机模块在位 ⇒ 熄屏必掉电」不是绝对的

- 旧的绝对口径（2026-10-09 用户裁决）已被证据削弱，**2026-10-19 用户指示改写**：
  7.3 线（vk127）在**完整相机栈在位**（`camcc`+`cambist` 配对 + `qcom_camss` + 双 sensor、17 个 `/dev/video*`）
  下连续 **41 发**真实 `dpms On→Off→On` **全部存活**（N2'/N3 12 + N7 12 + 2026-10-19 9 发，`boot_id` 全程不变）；
  致死**只在 vk64（7.2 血统）**复现过（N5，n=2：1 死 1 活）。
- 且 **suspend 假设已被能力级排除**：本机 `CONFIG_SUSPEND=n`（`/sys/power/state` 空、无 `mem_sleep`），
  20 份历史 `patches/config-*` 里只有 1 份开启过（vk128，上机即死、从未成为基线）；
  `ScreenSaver.SetActive(true)` 只走 DPMS，与 `PM_SUSPEND` 是不同子系统。
  ⇒ 排除项靠**能力/存档证据**，不必再跑实验（`reports/q24-suspend-hypothesis-excluded-20261019.md`）。
- 现在的口径：**未解**，但**「在位即常态掉电」不再当既成事实**；「镜像血统」是唯一受实测支持的候选，
  需 **N5b**（vk64 上 n≥5）或 **N6'**（vk127 上反向加回 7.2 payload 子集二分）定性。
  **日常仍默认零相机模块 + `cam-mode.sh on/off`**（安全策略，不是判决），
  但**不再据此拒绝**相机常驻 / 容器联调类实验。
