# 44 — 容器侧 camera provider（64-bit 自编 / vendor.img 烘入 / ABI 崩溃 / YUYV 协商）

> 2026-10-18 实测（vk127，Waydroid 1.6.2 MAINLINE）。报告：`reports/waydroid-camera-provider-64bit-20261018.md`。
> 补丁与构建脚本：`patches/waydroid-camera-64bit-20261018/`。

## #306 vendor.img 是「100% 满」的：`debugfs write` 直接 `Could not allocate inode`

- 现象：`debugfs -w -R "write foo /vendor/bin/hw/foo"` ⇒ `Could not allocate inode`；`dumpe2fs` 显示
  **inode 总数 496、空闲 14**（debian/waydroid 的 128 MiB vendor 镜像把 inode 算得刚好）。
- 判据：先 `dumpe2fs -h vendor.img | grep -E "Inode count|Free inodes"`，不要盲试 `write`。
- 治法（已固化进 `scripts/waydroid-camera-bake.sh`）：
  ① `mke2fs -t ext4 -N 8192 -d stage <new.img> 128M`（先解到 `stage/` 再整树重建）；
  ② 用 `debugfs -w -R "sif <path> mode <0:2000>"` 逐个恢复 SELinux label（`mke2fs -d` 不保留 xattr）。
- 另：`debugfs` 的 `rm`/`write` **不同步位图**，收尾必须 `e2fsck -fp`。

## #307 上游 external camera HAL 只有 32 位；Waydroid 通用镜像里没有任何 camera HAL

- `camera/device/3.x/default/Android.bp`：`compile_multilib: "32"` ⇒ arm64 容器（`cameraserver` 是 64-bit）加载不到 `-impl.so`。
- Waydroid 通用镜像：`/vendor/bin/hw`、`/vendor/lib64/hw`、`/system/bin/hw`、`/system/lib64` **全无 camera**，
  `/vendor/etc/vintf/manifest.xml` 无 camera 条目 ⇒ C5「绑 `/dev/video*` 就完」不成立，必须自带
  provider 二进制 + `external_camera_config.xml` + vintf 条目（`ro.hardware.camera=v4l2` 只是「用什么后端」，不是「有 HAL」）。
- 验收口径：`dumpsys media.camera` 的 `Number of camera devices`；`init.svc.vendor.camera-provider-*-ext` 必须是 `running`。

## #308 Debian 的 `aidl` 不接受 `@VintfStability`；NDK 编译要用 AOSP prebuilt

- `aidl --lang=ndk` 生成的 header 必须落在 `namespace aidl {`（`gralloctypes/Gralloc4.h` 依赖）⇒ 必须 `--lang=ndk`。
- Debian 包 `aidl` 见到 `@VintfStability` 直接报错不认 ⇒ 用 AOSP prebuilt：
  `prebuilts/build-tools/linux-x86/bin/aidl` + `LD_LIBRARY_PATH=…/linux-x86/lib64`，
  flags `--lang=ndk --structured --stability=vintf --min_sdk_version=33`。
- 其它编译硬点：`-D_LIBCPP_ABI_NAMESPACE=__1`（否则 `std::__ndk1` 未定义符号）、
  `-Wl,--allow-multiple-definition`（hidl_enum_values 重复）、per-version `INC_V`（3.4/3.5 同名头文件会互相串）。
- `HIDL_FETCH_ICameraProvider` 缺失 ⇒ `Could not get passthrough implementation`：补一个 fetch shim，安装成 `@2.4-impl.so`。

## #309 NDK libc++ ≠ 平台 libc++：provider 注册成功后**首笔 binder 事务**就 SIGSEGV

- 签名（记住这一组，别误判成「枚举崩」）：
  ```
  F libc : invalid pointer 0xffff…3008 (page signature mismatch)
  signal 0 (SIGSEGV), code 1 (SEGV_MAPERR), pc ffffffffffffffe0
  #01 libhidlbase.so android::hardware::BHwBinder::transact(… std::__1::function<…>)
  ```
  `pc = …fffe0` + `page signature mismatch` = ABI 错位后被读成函数指针（`std::function` 布局/名字空间不一致）。
- **必做的 A/B**：把设备绑定注释掉（例如 `/dev/video100` 那行加 `#TMPCAM#`）再重启。
  仍崩 ⇒ 崩在 provider 基座/注册路径，与你的枚举代码无关（本轮即此结论），别在枚举逻辑里空转。
- 治法（推荐）：用 `external/libcxx/include` 重编（`-nostdinc++ -isystem <libcxx>/include` + 平台 ABI 宏），
  不要指望 NDK 的 libc++ 与平台 ABI 兼容。
- 备路：直接用 donor 镜像里 AOSP 原生构建的 64-bit prebuilt；但注意上游 `provider/2.5/default/service.cpp`
  **只注册 `legacy/0`**，`external/0` 那条 32-bit 专用 main 没有 64-bit 版本。

## #310 `cannot find suitable cropping type` 是两个坑叠加：格式枚举回退 + 四cc 白名单

① **v4l2loopback 不支持 `ENUM_FRAMESIZES`/`ENUM_FRAMEINTERVALS`** —— `v4l2-ctl --list-formats-ext` 能出尺寸是因为它回退到 `G_FMT`。
   ⇒ HAL 里要加 `G_FMT`/`G_PARM` 回退。
② **`kSupportedFourCCs` 上游只有 `MJPEG`/`Z16`** ⇒ YUYV 在更早一步就被过滤掉，**只修回退现象不变**。
   ⇒ 加 `YUYV`/`NV12`，并把 `initOutputCharsKeys` 的 `hasColor` 拆出 `hasColorMjpeg` + 独立 YUV 流公布数组；
   会话层补 `YUY2ToI420`/`NV12ToI420`。
- 另一条已否证的路：MJPEG 生产者。本机 `v4l2loopback` **无 `pixelformats` 模块参数**，
  `v4l2-ctl --set-fmt-video pixelformat=MJPEG` 直接 `invalid`；`v4l2sink` 虽列 `image/jpeg`，实测 `not-negotiated (-4)`。

## #311 Waydroid 1.6.2（openrc）容器启动的两个死点

- 服务脚本传 `-p <pidfile>`，**该版本不支持** ⇒ 服务起来就死。用 `setsid waydroid container start` 绕过。
- `root` 不能用 `XDG_RUNTIME_DIR=/run/user/1000`（属 uid 1000）⇒ headless 时在 `/run/user/0` 起 `weston`（`weston-backend-headless`）。
- `apk add` 遇 DNS 抖动失败时，从镜像站下单个 `.apk` 再 `apk add --allow-untrusted` 即可（别在这上面反复重试整仓同步）。

## #312 设备侧长命令必须带 `timeout`；Q28 坏发要用「有界重启」而不是人手连按

- 本轮实测 **连续 7 发 Q28 坏**（`panel init attempt 2 failed: -5`），第 8 发 GOOD。人会以为「刷坏了」。
- 判据：每发只看三项 —— SSH 可达 / `/sys/class/drm/card0` 存在 / 面板 init 日志无 `-5`。
- helper 已入库思路：设备侧脚本内 `for i in $(seq 1 12); do reboot; sleep 75; …; done`，**每步都有 `timeout`**；
  主机侧所有 `ssh`/`scp`/`adb` 一律 `timeout N`，否则 Q28 坏发会把调用方挂死（用户已两次指出）。
- 另：`pkill -f <pattern>` 会匹配到自己那条 `bash -c`（本轮 `waydroid container start` 自杀一次，空输出 `exit 143`）。
  设备侧脚本用显式 PID 或 `[p]attern`/`$p ≠ $$` 过滤，见技能 `pkill-self-match`。

## #313 换机后 `avbtool.py` + `bootslot-b/avb.key` 丢失：重建 key ⇒ 公钥 sha1 变 ⇒ vbmeta_b 必须同步重签

- 重建后 `avbtool info_image --image boot_b.img` 的 **Public key sha1 = `1e54e86ef19fad73…`**（旧链 `fc1e3b33…` 作废）。
- `scripts/sign-boot-b.sh` 只签 boot；`vbmeta_b` 的 chain descriptor 必须同时用新 key 重签，否则 ABL 直接拒（无声黑屏/回 fastboot）。
- 写后校验只看 **读回 sha256**（本轮 `bootslot-b/boot_b.img` 与设备 `dd /dev/disk/by-partlabel/boot_b` 逐字节一致：
  `83d4e08add88abd2…`）；本机 ABL **无 `fastboot fetch`**（#290），读回走设备侧 `dd`。

## #314 VINTF manifest 的三个「ill-formed」陷阱（错一个 → 整份 vendor manifest 作废）

- 判据：`logcat | grep "VINTF parse error"`，`hwservicemanager` 会直接报出**具体**规则（别猜）：
  1. `Duplicated manifest.hal entry android.hardware.camera.provider`
     ⇒ **同名 HAL 只能有一个 `<hal>` 块**（我把 legacy/0 写成第二个 `<hal>` 就触发）。
  2. `Duplicated interface entry "ICameraProvider"; if additional instances are needed, add them to the existing <interface> node`
     ⇒ **同名 interface 只能有一个 `<interface>`，多实例写成多行 `<instance>`**。
  3. `'android.hardware.camera.provider' is not a valid Manifest HAL: Duplicated major version: 2.5 vs. 2.4`
     ⇒ 同一个 `<hal>` 里不能同时列 `2.4` 和 `2.5`（同 major）；写一条 `2.5` 即可（`@2.4::…/legacy/0` 的 fqname 仍可用）。
- **代价**：manifest 一旦 ill-formed，**所有** vendor HAL 都 `must be in VINTF manifest` 而注册失败，
  容器半启动（`dumpsys media.camera` → `Can't find service: media.camera`）。现象很像「镜像坏了」，实际是 XML 规则。
- 正确写法（`scripts/waydroid-camera-bake.sh --legacy` 已固化为模板）：
  ```xml
  <hal format="hidl">
    <name>android.hardware.camera.provider</name>
    <transport>hwbinder</transport>
    <version>2.5</version>
    <interface>
      <name>ICameraProvider</name>
      <instance>external/0</instance>
      <instance>legacy/0</instance>
    </interface>
    <fqname>@2.4::ICameraProvider/external/0</fqname>
    <fqname>@2.5::ICameraProvider/legacy/0</fqname>
    <fqname>@2.4::ICameraProvider/legacy/0</fqname>
  </hal>
  ```
- ⚠️ 更正前稿：曾把「全体 HAL 注册失败」归因于「`debugfs` 替换 manifest 丢 SELinux label」——**错**，
  真因就是上面的 XML 规则（`debugfs` 替换本身无害，本轮多次验证）。

## #315 A/B 结论会翻转：平台自产二进制也崩 ⇒ 先验证「环境」再怀疑自编件

- 第一次 A/B 曾看到 donor 的平台自产 `provider@2.5-service_64` = `init.svc…running`，据此判定「锅在自编 ABI」。
  **manifest 修好后（真能投递事务）它同样在首笔事务 SIGSEGV，且寄存器指纹与自编件逐字相同**
  （`pc = x8 = 0xffffffffffffffe0`、`x1 = 0x0f43484e`、`x22` 相同）⇒ **不是自编件独有**。
- 教训：`init.svc…=running` 只代表**进程活着**；没有事务（`dumpsys media.camera` 真连上）就不算存活证明。
  判活必须带「有事务进来」：看 `getService: found dead hwbinder service` / `is not actually available` 有没有消失。
- 两条 64-bit camera provider 的共同点 = **都用了 donor 产出的、带 vtable 的 camera HIDL 库**
  （`android.hardware.camera.provider@2.4.so` / `-legacy.so` / `camera.device@3.x-impl.so`）；
  容器自己的 HIDL 服务（audio/sensors/light）都正常 ⇒ 下一步应当**自编这些 interface 库（Bn/Bp）**、
  彻底不用 donor 二进制再测，而不是继续调编译参数。
- 2026-10-18 当时的设备状态已回滚到「自编 provider + 崩」的基线镜像（`sha256 7ec8f245…`），容器可正常启动。

## #316 先写「最小客户端冒烟」再怀疑业务代码（3 行程序省掉一天）

- 判据程序（`patches/waydroid-camera-64bit-20261018/hidl-smoke.cpp`）：
  ```cpp
  ProcessState::initWithDriver("/dev/vndbinder");           // 容器里 root shell 直跑需要；init 服务可省
  auto sm = android::hidl::manager::V1_0::IServiceManager::getService();
  ```
  编译：把我们生成的 iface objects 一起链上（不需要任何 camera 库），推到 `/vendor/bin/hw/hidl-smoke` 直接跑。
- 它**崩**就说明问题在工具链/头文件/ABI 层，**与业务代码无关**；它**不崩**才有必要读 camera 代码。
  本轮就是靠它把「camera provider 崩」定性为「任何进程碰 `getRawServiceInternal` 都崩」。
- 反汇编法（判定结构体布局是否一致，30 秒）：
  ```bash
  aarch64-linux-gnu-objdump -d --start-address=<~hidl_string> --stop-address=<+0x40> libhidlbase.so
  # 本轮实测： [+0]=mBuffer  [+8]=uint32 mSize  [+12]=bool mOwnsBuffer  ⇒ 16 B，与头文件一致
  ```
- 反面教训：`Pointer tag for 0x30 was truncated` 这类 bionic abort **不是**「标签命名空间不对」的指纹，
  它只说明**传到 free 的指针是垃圾**（局部对象/栈被踩）。别拿它直接推 `__ndk1`/`__1` 的结论。

## #317 Waydroid 容器 vk127 上「64-bit HIDL 服务集体崩」的已知边界（2026-10-18 未解）

- 现状：**容器自带**的 HIDL 服务（audio/sensors/light/composer）正常；**任何外来的** 64-bit HIDL 进程
  （自编 camera provider、donor AOSP 自产 2.5 provider、3 行最小客户端）一碰 `getRawServiceInternal` 就 abort。
- 排除项（都做过）：`__ndk1` 命名空间、`hidl_string` 布局、NDK vs 平台 libc++ 头、donor interface 库、
  legacy passthrough 路径、manifest 白名单。
- 待验方向：我们 `libhidl` = `tm-release (Snap for 8656240)` 与容器 VNDK33（`TQ3A.230901.001`）**AOSP tag 不同**；
  下一步按容器镜像的 tag 重取 `system/libhidl`/`libhwbinder`/`system/core`/`frameworks/native` 头重编，
  并用 `hidl-smoke` 二分（`defaultServiceManager()` → `sm->get()`）。
