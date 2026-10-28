# 2026-10-28 · M4 camss v2 投递并复核 + Binary Eye 实测（容器相机卡点定位）

用户指示「做 1、2，三不做；4 也不做」⇒ 只做 ① 发 M4 v2、② Binary Eye 验证。

## ① M4 camss v2 已投递并复核

| 项 | 值 |
|---|---|
| 发送 | `git send-email --confirm=never`，**10 封全部 `Result: 250`**（17:29:54 +0800） |
| Message-ID | `<20261028093003.722745-1..10-xiaqinghuan@mail.ustc.edu.cn>`（`References` 自洽，单线程） |
| Subject | `[PATCH v2 0/9]` … `[PATCH v2 9/9] media: camss: add SM8750 support` |
| 收件人 | 与 v1 一致：To = Bryan O'Donoghue + Mauro；Cc = Rob/Krzysztof/Conor/Bjorn/Konrad/Hangxiang + 4 个列表 |
| lore `/all/` | **10/10 归档**（`scripts/lore-fetch-raw.py all`，Subject 全核对） |
| 列表 inbox 抽验 | `/linux-media/`(#6) `/linux-arm-msm/`(#9) `/linux-devicetree/`(#2) `/lkml/`(#1) 全命中 |
| **逐字节复核** | lore 取回 9 枚（跳 cover）拼 mbox → pristine `24a19b953` `git am` **9/9 干净**，与 `m4/v2-20261028` `git diff` **空** |
| Sent Items | **10/10** 回读 |
| 前置 | 发前核对：v2 目录 9 枚补丁与分支 tip `ca3d71e71` 逐字节一致（9/9 SAME）、dry-run 10 × `Result: OK` |

**新坑**：直接 `curl https://lore.kernel.org/all/<msgid>/raw` 全部 **403**（Anubis PoW）⇒ 必须走 `scripts/lore-fetch-raw.py`（带挑战处理），
否则会误判「没归档」。（与 `PITFALLS #457` 同族，已在该条覆盖「不能带尖括号」，这次补上「必须用带挑战的取件器」。）

## ② Binary Eye 实测 —— 相机链路对 App **可用**，卡点在图形层

| 项 | 结果 |
|---|---|
| App | 容器里**早已装** `de.markusfisch.android.binaryeye`（`~/.local/share/waydroid/data/app/…`）；启动 Activity = **`.activity.SplashActivity`**（`MainActivity` 不存在，`am start` 会 `Error type 3`） |
| 链路 | `Camera 200: Opened` → `configureStreams` → **`start V4L2 streaming 1280x720@30.000000fps`** |
| **真出帧** | **`ProcessCaptureRequest latency histogram (7) samples`**、`Stream 0 dequeueBuffer latency histogram (8) samples` ⇒ 确实跑了 7 个请求 |
| 崩溃 | provider `android.hardware.camera.provider@2.4-external-service` **SIGSEGV**（`Camera provider 'external/0-0' has died`） |
| 堆栈 | `ExtCamOut` → `libyuv.so CopyRow_NEON+8` ← `CopyPlane` ← **`I420Copy`** ← `camera.device@3.4-external-impl.so formatConvert()+244` ← `OutputThread::threadLoop()` |

**根因（源码级）**：`formatConvert()`（`ExternalCameraUtils.cpp:303`）在 `V4L2_PIX_FMT_YUV420` 分支调
`libyuv::I420Copy(in → out, sz)`，`out` 来自 `sHandleImporter.lockYCbCr()`（gralloc 输出缓冲）。
`CopyRow_NEON` 的 `SEGV_ACCERR` = **输出侧 `YCbCrLayout`（`cStride`/`chromaStep`）与 I420 平面假设不符**
⇒ **容器 gralloc 的 `lockYCbCr` 与 HAL 3.4 期望不匹配**（本镜像 2026-10-19 版）。

⇒ **与相机链路无关**（输入侧全通、真出帧）。两处阻塞同属「帧交给 Android 图形层」：
1. OpenCamera → `libhwui.so` `GrBackendTexture` 析构野指针（HWUI+Adreno/ANGLE）
2. Binary Eye → HAL `formatConvert` 写 gralloc 输出 `SEGV_ACCERR`（gralloc 布局）

## 设备终态

CAM-OFF（模块 0 / media 0 / video 0）、`v4l2loopback` 卸、`/dev/video100` 无、容器 STOPPED、`dpms=On`、blank idle=300。

## 操作坑补充

- 容器 **FROZEN 时 `pm list packages` 返回空**（不是没装）⇒ 先 `lxc-unfreeze` 再查。
- `lxc-stop -k` 无效；可靠 = `kill -9 $(pgrep -f "lxc-start.*waydroid")`（**可能有多个**），
  再 `kill -9 $(pgrep -f "waydroid containe[r]")`。
- 主目录里 `tools/` 被 gitignore ⇒ 写端源码落 `patches-userland/mjpgfeed-loopback/`（入库位置）。

## 产物

- `patches/upstream/m4-camss-series-20261028-v2/README.md` §6（投递记录）
- `reports/c5-u7-container-camera-20261028.md` §16–§20
- `out/mail-20261028/m4-camss-v2-send.txt`（发送转录，`out/` 不入库）
- `TASKS/README.md` §2 C5 行、`PROGRESS.md` 时间线
