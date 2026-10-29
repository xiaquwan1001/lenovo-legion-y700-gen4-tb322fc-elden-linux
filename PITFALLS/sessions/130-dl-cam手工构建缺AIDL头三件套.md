# #466 `dl-cam` 手工构 external camera HAL 缺的三件事（AIDL 头 / aidl 版本 / 两套 backend）

## 结论（2026-10-29 实测，编译 gralloc 修法时撞出来的）

`dl-cam/build-cam-provider.sh` 一直能编，是因为 2026-10-19 那次走的是**镜像里已有的头**；
一旦动到 `HandleImporter.cpp`（经 `gralloctypes/Gralloc4.h` 依赖 AIDL），构建链就露出三个缺口：

① **从来没有生成过 AIDL 头**。`Gralloc4.h:19` 要 `#include <aidl/android/hardware/graphics/common/BlendMode.h>`，
   AOSP 里由 Soong 生成，`dl-cam` 手工构建没人生成 ⇒ `fatal error: file not found`。
   ⇒ 现在有 `dl-cam/gen-aidl.sh`（幂等）。
② **aidl 编译器版本**：Ubuntu 包 `aidl`（`1:10.0.0+r36`）与 `~/.local/hidlgen/usr/bin/aidl` 都不认
   `--stability=vintf`（分别报 `unrecognized option` / 生成的头落进 `android::hardware::…`）。
   必须用 **AOSP prebuilts/build-tools**（`android-13.0.0_r82`）：
   ```sh
   git clone --depth 1 --filter=blob:none --sparse -b android-13.0.0_r82 \
     https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/prebuilts/build-tools /tmp/bt-pre
   cd /tmp/bt-pre && git sparse-checkout set linux-x86/bin linux-x86/lib64   # ≈5 s
   ```
   跑之前必须 `LD_LIBRARY_PATH=/tmp/bt-pre/linux-x86/lib64`，否则报 `built for platform SDK version <UNKNOWN>`。
③ **`--lang=cpp` 与 `--lang=ndk` 是两套，都要生成**：
   - `--lang=cpp` → `gen-aidl/android/hardware/…`，namespace `android::hardware::…`（HIDL/C++ 侧）
   - `--lang=ndk` → `gen-aidl/aidl/android/hardware/…`，namespace `aidl::…`（**`Gralloc4.h` 要的正是这套**，
     因为 `libgralloctypes` 的 `Android.bp` 依赖 `android.hardware.graphics.common-V3-ndk`）
   只生 cpp 一套 ⇒ 编译报 `no member named 'aidl'` + `no variable template matches specialization`（像模板 bug，实际是命名空间错）。

## 定式

- 改 `dl-cam` 里任何走 AIDL 的文件：先 `./gen-aidl.sh`，自检行必须打印 `cpp 96 + ndk 96 headers`，
  并断言 `gen-aidl/aidl/…/BlendMode.h` 里有 `namespace aidl {`。
- 别拿 `--version=N` / `--min_sdk_version` 试错：本机这套组合下它们不影响命名空间；
  命名空间只由 `--lang=ndk` 决定。
- `aidl` 落盘路径：`-h <hdr_out> -o <src_out>`，二者都必填（只给 `-h` 会 `Output directory is not set`）。
