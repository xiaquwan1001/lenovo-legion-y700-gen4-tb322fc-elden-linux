# 2026-11-15：`dl-cam/hw-interfaces` 工作区改动快照（= Waydroid ExternalCamera YV12 布局修复）

## 为什么有这份

`dl-cam/hw-interfaces` 是 AOSP `platform/hardware/interfaces` 的镜像克隆（`origin` = ustc 镜像，
`blob:none` 部分克隆），在**主仓 `.gitignore` 第 122 行整目录忽略**（`/dl-cam/hw-interfaces/`）。
树里 6 个文件的改动**在仓库层面完全不可见**，一旦重克隆/清目录就永久丢失 —— 故按
`patches/local/` 既有惯例（同 `20261113-daily-worktree`）逐字存成 patch 作为耐久副本。

- 树内状态：`git status` 6 个 `M`，`+266 / −14`；HEAD = `fa455d8`（`Merge cherrypicks of [19214732] into tm-release.`）
- 快照：`0001-external-camera-yv12-layout-repair.patch`（428 行，sha256 `c2faf2b90a01…`）
- 验证：在树内对该 patch `git apply -R --check` → **rc=0**（2026-11-15 实测），即快照 == 当前工作区
- **未在该仓 commit、未 push**（保留上游镜像近净状态，改动以本 patch 为准；工作区仍保持改动后的内容）

## 内容

| 文件 | 改动 |
|---|---|
| `camera/common/1.0/default/HandleImporter.cpp` | 新增 `isLayoutSane()` / `repairPlanarYuv420Layout()`：校验 `YCbCrLayout` 自洽性，不自洽时用 `plane1.offsetInBytes / height` 反推真实 `yStride` 并回退到标准 YV12/YU12 布局；仍不可用则返回全零布局交由调用方报错，**绝不盲写** |
| `camera/device/3.4/default/ExternalCameraDevice.cpp` | 接入上述修复 + 相应日志 |
| `camera/device/3.4/default/ExternalCameraDeviceSession.cpp` | 会话侧使用修复后的布局 |
| `camera/device/3.4/default/ExternalCameraUtils.cpp` | 工具侧适配 |
| `camera/provider/2.4/default/ExternalCameraProviderImpl_2_4.cpp` | provider 适配 |
| `camera/provider/2.7/default/ExternalCameraProviderImpl_2_7.cpp` | provider 适配 |

## 背景（为什么必须有）

Waydroid/minigbm 的 `IMapper@4.0` 对 `HAL_PIXEL_FORMAT_YV12` 缓冲会返回自相矛盾的 PlaneLayouts
（实测 1280x720 YV12、usage 0x20930 → `y_str 2048 / c_str 0 / c_step 1`，且 CB/CR 与 Y 基址重合）；
原样交给 `libyuv::I420Copy()` 会在 `CopyRow_NEON` 内越界写并触发 `SEGV_ACCERR`（tombstone_24 实证）。
适用场景 = 安卓容器（G2）里跑外接/虚拟相机。

## 复原方式

```sh
cd dl-cam/hw-interfaces && git apply /home/xuqianhui/y700-elden/patches/local/20261115-dl-cam-hw-interfaces/0001-external-camera-yv12-layout-repair.patch
```
