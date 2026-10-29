# camera-gralloc-20261028 — external-camera HAL：YV12 输出布局校验与回退

状态：**源码级补丁，未编译、未上机**（判据 = 未上机）。

## 1. 为什么（设备实证）

容器（Waydroid / TB322FC）里 Binary Eye 的打码分析流是 **`HAL_PIXEL_FORMAT_YV12`**
（`dumpsys media.camera` → `Stream[0] ... format 0x32315659, usage 0x20930`）。
`ExternalCameraDeviceSession::OutputThread::threadLoop()` 把 gralloc 缓冲交给
`formatConvert(V4L2_PIX_FMT_YVU420)` → `libyuv::I420Copy()`，
随后崩在 `CopyRow_NEON`：

```
signal 0 (SIGSEGV), code 2 (SEGV_ACCERR), fault addr --------
  #00 libyuv.so (CopyRow_NEON+8)
  #01 libyuv.so (CopyPlane+204)
  #02 libyuv.so (I420Copy+188)
  #03 camera.device@3.4-external-impl.so (formatConvert+244)
```

打开 ALOGV（`setprop log.tag.ExtCamDevSsn@3.4 VERBOSE`）后拿到的**输出布局**：

```
outLayout y 0xfffef2f80000 cb 0xfffef2f80000 cr 0xfffef3061000 y_str 2048 c_str 0 c_step 1   ← YV12 流
outLayout y 0xfffef3200000 cb 0xfffef32e1000 cr 0xfffef32e1001 y_str 1280 c_str 1280 c_step 2  ← NV12 流（正常）
```

YV12 流的布局三条自相矛盾：
1. `cStride == 0`（多行色度全写同一行地址）；
2. `cb`/`cr` **与 `y` 基址重合**（`cb == y`）；
3. `yStride = 2048`，而 `cr - y = 0xE1000 = 921600 = 1280 × 720` ⇒ 真实 stride 是 **1280**。

来源是 `HandleImporter::lockYCbCrInternal<IMapperV4>`：它把
`IMapper@4.0 get(MetadataType_PlaneLayouts)` 的每个 `PlaneLayout` 分量直接合成
`YCbCrLayout`（`cStride = plane.strideInBytes`、`cb/cr = mapped + plane.offsetInBytes`），
**零校验**。NV12 缓冲的同一函数输出完全自洽，说明缺陷是 **YV12 三平面专用**。

因此本轮的判别结论：**E2（PlaneLayout 与 I420 平面假设错配）成立**，E1（映射只读）被弱否证
（同一进程同一 usage 族下 NV12 路径连写数十次无 ACCERR）。

## 2. 改了什么

`0001-external-camera-validate-ycbcr-layout.patch`（`git apply --check` 通过）：

1. `dl-cam/hw-interfaces/camera/common/1.0/default/HandleImporter.cpp`
   - 新增 TU 内 `isLayoutSane()` / `repairPlanarYuv420Layout()`；
   - `lockYCbCrInternal<IMapperV4>` 返回前经过 `repairPlanarYuv420Layout()`：
     - 布局自洽（NV12 / 正常 YV12）⇒ **原样返回，行为不变**；
     - 布局矛盾 ⇒ `ALOGE` + 用 **`planeLayouts[1].offsetInBytes / height` 反推真实 yStride**
       （本例 921600/720 = 1280），按 plane1 的组件类型判断 V-first/YV12 还是 U-first/YU12，
       回退到标准平面布局（`cr = y + yStride*h`、`cb = cr + yStride*h/4`、`cStride = (yStride+1)/2`）；
     - 回退后仍不自洽 ⇒ 返回**全零布局**，让上层 `getLayout()` 报错。
2. `dl-cam/hw-interfaces/camera/device/3.4/default/ExternalCameraUtils.cpp`
   - `formatConvert()` 入口加前置校验（空指针 / `yStride < width` / `cStride <= 0` /
     cb、cr 与 y 重合），非法即 `ALOGE` 打印完整布局并 `return -EINVAL`。
     目的：把「HAL 进程 SIGSEGV → cameraserver 判 provider 死亡 → 整条链路断」
     降级为「单次 capture 请求失败」，并留下下次取证所需的布局。

不改 V4L2 生产端、不改 App、不动 gralloc 二进制。

## 3. 最小验证命令（上机）

```sh
# 0) 宿主：生产者 + 容器
scripts/cam-loopback.sh start rear
scripts/device-lock.sh -w 1800 bash -c 'ssh root@192.168.7.1 "waydroid session stop; waydroid session start &"'

# 1) 打补丁 → 重编 external provider（沿用 scripts/waydroid-camera-bake.sh 的 bake 流程）
cd dl-cam && git apply ../patches-userland/camera-gralloc-20261028/0001-*.patch
scripts/waydroid-camera-bake.sh     # 产物推回容器，重启 provider

# 2) 打开 ALOGV 后跑 Binary Eye，看是否出现修复行 / 是否仍崩
ssh root@192.168.7.1 'L="lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c"
  $L "logcat -c; setprop log.tag.ExtCamDevSsn@3.4 VERBOSE"
  $L "am start -n de.markusfisch.android.binaryeye/.activity.SplashActivity"'
# 期望（A）：出现 "repairPlanarYuv420Layout: repaired layout ... y_str 1280 c_str 640 c_step 1"
#           且不再有 tombstone / SIGSEGV
# 期望（B，若修复不成立）：出现 "formatConvert: refuse to convert ..." 而不是进程崩溃
ssh root@192.168.7.1 'L="lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c"
  $L "logcat -d -v brief | grep -a -E \"repaired layout|refuse to convert|FATAL|ExtCamOut\""'
ssh root@192.168.7.1 'L="lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c"; $L "ls -l /data/tombstones | tail -3"'
```

## 4. 零代码绕过（先试，成本最低）

`Stream[1]`（`YUV_420_888` → 容器实际给 NV12）的布局**完全自洽、转换已在设备上成功跑了几十次**。
把 Binary Eye 的分析格式/预览格式设成 `YUV_420_888`（不要 YV12）即可绕开整条缺陷路径
（该设置项本轮未在设备上验证，属**未上机**）。

## 5. 风险

- `yStride` 反推依赖「plane1 offset = yStride × height」这一 YUV420 通例；若某 gralloc 给
  plane1 加了对齐 padding，反推会偏大 ⇒ 用 `isLayoutSane` 复检 + 上界 `1<<20` 保护，
  但**仍可能算错**。保守替代：把回退关掉、只用 `-EINVAL` 前置校验（不崩但不出图）。
- `repairPlanarYuv420Layout` 用 `accessRegion.width/height` 做校验基准；`lockYCbCr` 的
  `accessRegion` 是请求裁剪区，非缓冲全尺寸时 `yStride < width` 判断可能误报——上机需看
  `ALOGE` 里的实际数值确认。
- 未编译验证（本轮设备时间窗被容器图形层故障吃掉），**编译/上机风险自负**。
- 不解决根因（minigbm 的 YV12 `PlaneLayouts` 本身错），属 HAL 侧兜底；
  真正的上游化应该是修 gralloc 的 `getPlaneLayouts(YV12)`。
