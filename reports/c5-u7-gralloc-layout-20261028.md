# C5/U7 容器相机「帧交给图形层」崩溃：gralloc 布局定位（2026-10-28）

> **来源与可信度**：lane L1（`1efe5103`，2026-10-28 19:31–19:50）做了源码级/镜像级取证，但**产物未落盘**（报告停留在 616 B 骨架），
> 其结论只存在于子代理过程文本。本节由**编排者据该过程文本重建**，逐条标可信度：
> `[源码]` = 引脚到 AOSP/minigbm 源码行；`[二进制]` = 对容器 .so 的符号/常量取证；`[推断]` = 汇编级推断、**未复核**。
> **没有一条经过设备侧实测**（设备当时被 G3 lane 占用）。

## §0 结论（先数字）

| 项 | 结论 | 可信度 |
|---|---|---|
| 崩溃位置 | `camera.device@3.4-external-impl.so` `formatConvert()+244` → `libyuv::I420Copy` → `CopyPlane` → `CopyRow_NEON+8` **SEGV_ACCERR（权限错，不是空指针）** | 已证（tombstone） |
| **旧假设「`lockYCbCr` 与 HAL 期望不符」** | **机制上不成立**：本容器 gralloc = **IMapper V4（minigbm/gbm_mesa）**，HAL 走 `lock()` + gralloc4 `PlaneLayouts` 元数据，**根本没有 `lockYCbCr` 调用** | [二进制] |
| HAL 侧校验 | `ExternalCameraUtils.cpp` `formatConvert()` YUV420 分支**对输出布局零校验**，直接按 `out.yStride/cStride` 盲写；**crop 只作用于输入**，输出按整帧写 | [源码] |
| minigbm 平面表 | `GetPlaneLayoutsMap` = 静态 per-DRM-format 表；表内观察到的键含 **NV12 / NV21 / YV12 / P010 / AB24 / AR24 / AB30 / AB48 / R8 / R16 / RG16**；表外格式 `getPlaneLayouts` 返回 `-EINVAL` | [二进制] |
| 指针合成 | `cros_gralloc_buffer::lock` 以 usage 推导映射标志，平面指针 = `mapped + drv_bo_get_plane_offset(i)`；mapper 只回 plane-0 基址，HAL 再叠加 `PlaneLayouts.offsetInBytes` | [二进制] |

## §1 两个待判别假设（都未证实）

- **E1 · 映射丢了写权限**：`convertToMapUsage()` 把 mapper 的 `cpuUsage` 转成 `DRV_BO_MAP_*`；若写位丢失 ⇒ `mmap(PROT_READ)` ⇒ 第一次写 Y 平面即 `ACCERR`。
  HAL 侧 `cpuUsage = usage | CPU_WRITE_OFTEN | CAMERA_OUTPUT` **看起来**有写位，但 4.0 BufferUsage（64 bit）→ minigbm 位的转换是否对齐未核。
- **E2 · 平面/步长错配**：`PlaneLayouts.strideInBytes` 给色度平面用了整平面 stride（或 0），HAL 叠加后写出映射边界 ⇒ `ACCERR`。

## §2 决定性设备侧检查（下一轮，唯一动作）

开 **ALOGV** 跑一次 preview，抓 `outLayout y/cb/cr` 那行（`y_str/c_str/c_step`）：
- 若 `c_str` 或 `c_step` 与 `width/2` 不符 ⇒ **E2**；
- 若布局正确但仍 ACCERR ⇒ **E1**（用 `/proc/<pid>/maps` 核该 buffer 的 `rw-`/`r--` 权限）。

命令级配方与判据写在此处，**本轮未执行**：
```sh
# 宿主侧起流（同既有链路），容器侧：
adb shell setprop log.tag.ExtCamDevice D   # 或 HAL 侧 ALOGV 开关
adb logcat -c; adb logcat | grep -E 'outLayout|ExtCamOut|formatConvert'
```

## §3 修法候选（按成本排序，均未实施）

1. **最小**：容器 stream 输出格式改 **YV12**（表内有条目，且 I420/YV12 只差 U/V 顺序 ⇒ 若错配来自 NV12 半平面 stride，可绕过）。风险低，判据 = 不再 ACCERR 且画面颜色顺序正确。
2. **中**：HAL 侧 `formatConvert` 前置校验 + `accessRegion` 传实际 crop，并在写前 `getPlaneLayouts` 交叉核对 stride/offset（补丁落 `patches-userland/camera-gralloc-20261028/`，**本轮未创建**）。
3. **中**：HAL 改为 `lock(buffer)` 后按 `drv_bo_get_plane_offset` 手工分平面拷贝，不依赖 PlaneLayouts 元数据。
4. **高**：换容器 gralloc 后端（libgbm ↔ minigbm 直连），风险最大，仅在前三条全失败时考虑。

## §4 未证实项

- E1/E2 哪一条成立（§2 一次设备侧取证即可判别）。
- OpenCamera 的 `libhwui GrBackendTexture` 野指针是否与本案同源（**未证实**，可能完全独立）。

## §5 证据指针

- 崩溃栈与帧计数：`reports/c5-u7-container-camera-20261028.md` §16–§20、`PITFALLS #460`
- 宿主链路与写端：`patches-userland/mjpgfeed-loopback/`、`PITFALLS #438–#441`
- lane 过程文本：`/home/xuqianhui/.cache/pi-tmp/pi-fabric-runs-hah09u/1efe5103661d4ce19a5b5b6fce2e341d/events.jsonl`
