# 会话记录 2026-10-18 晚：相机黑帧真根因（AGC exposureTarget）+ 主机交叉编译管线

- **日期**：2026-10-18 15:10–16:20
- **主题**：① 平板编译速度评估 / 能否主机编译；② 相机「黑帧」根因收口
- **结论**：✅ **真根因已定：`exposureTarget: 0.22` 低于 AGC 可达下限（MSV 只有 5 bin）⇒ 曝光冻结 ⇒ 恒黑**。
  只改 tuning 到 `0.30` 即好。**同时推翻**早前「libcrypto 构建」结论（#322）。

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 平板自编 libcamera | 8 核，全量 **4–6 min**（`-j4`） |
| **主机交叉编译** | 28 核，全量 **≈10 s**，增量 **1–2 s** ⇒ 已建管线，设备只做运行 |
| 黑帧真因 | `target ≤ 0.24` ⇒ 第 1 帧 MSV=1 落进滞回带 ⇒ 曝光永不改变 |
| 修复 | tuning `exposureTarget: 0.30`（**零代码改动**；代码兜底 clamp 到 0.28 也有 patch） |
| 验收（Alpine 原版二进制） | 前摄 **30 fps / mean 37.5 / max 92**；后摄 **30 fps / mean 10.4 / max 28**（低光场景，`test_pattern=2` 时 mean 124.5/max 248 证链路完好） |

## 1. 决定性 A/B（同一二进制，只改 tuning，固定起点 exp=256 gain=1，1500 帧）

| `exposureTarget` | AGC 轨迹 | 末帧 mean/max |
|---|---|---|
| 0.22 | `exp 256 again 0.03125` **1500 帧不动** | **0.0 / 0** |
| 0.24 | 同上 | 0.0 / 0 |
| 0.30 | `281→372→493→655→871→1158→1540→2049→2725→3174` | 11.4 / 31 |

## 2. 为什么（代码级）

`agc.cpp`：MSV = 5 个 bin 的加权平均 ⇒ 数学上恒在 `[1,5]`；`optimal = exposureTarget × 5`；
滞回 `kExposureSatisfactory = 0.2`。当 `optimal + 0.2 ≤ 1`（即 `target ≤ 0.24`）时，
第 1 帧 `MSV = 1` 就满足"已达标"，**加曝光分支（`MSV < optimal-0.2`）永不成立** ⇒ 冻结。

## 3. 推翻了什么（诚实记录）

| 旧结论 | 状态 | 反证 |
|---|---|---|
| 软 ISP「只写第 0 帧」（#320） | ❌ 已作废 | 逐帧 mean 会爬升（AE 在动） |
| 「启用 libcrypto 的 libcamera 构建导致黑帧」（#322） | ❌ **推翻** | Alpine 原版(libcrypto) + target 0.30 ⇒ 正常出图；自编无-libcrypto + target 0.22 ⇒ 同样黑帧 |
| 方法论教训 | **新增 #324** | 两臂必须在**同一配方**下才可比；当时两臂都用了 0.22，把「构建方式」误判成因果 |

## 4. 主机交叉编译管线（新资产）

| 项 | 值 |
|---|---|
| 源码 | `~/lc-cross/lc-src`（libcamera v0.7.1） |
| 交叉文件 | `/tmp/x3.ini`（**待固化**：musl gcc + `-B/tmp/lldbin` + `-idirafter /tmp/dev-sysroot/usr/include`） |
| 设备 sysroot | `/tmp/dev-sysroot`（`ssh tar` 取 `usr/include` + 选定 `.so`，13 MB）+ `/tmp/sysroot-aarch64`（合成） |
| 产物 | `DESTDIR=/tmp/lc-install ninja -C b-gcc install` → 5 个文件 |
| 装机 | `scp` + `ldconfig`，约 5 s |

三坑（#325）：① GNU ld 2.37 读不了 Alpine `.relr.dyn` ⇒ 用 `ld.lld`；② `PKG_CONFIG_LIBDIR` 必须指设备 `.pc`；
③ 头文件用 `-idirafter` 而非 `-isystem`。

## 5. 另两个抓帧陷阱（#326/#327）

- **`cam -cN` ≠ `--list` 编号**：`-c1` 打开的是**前摄**（`camera@31`），`-c2` 才是后摄。用完整 camera id。
- **设备 `/tmp` 是 7.3 G tmpfs**：1280×720×ABGR = 3.7 MB/帧，`-C500` 写满 ⇒ 之后全 0 字节文件被误判黑帧。抓帧写 `/var/tmp`。

## 6. 收尾状态

- 设备：libcamera = **Alpine 原版**（`md5 6f94f614`）；tuning = 0.30（备份 `/root/cam-tune-20261018/*.prev`）；
  **CAM-OFF**（0 模块 / 0 media / 0 video），`idle=300 lock=true`，Q24 口径合规。
- 新增：`reports/camera-linux-vk127-20261018-agc-rootcause.md`、`patches/camera-agc-rootcause-20261018/`（patch + README）、
  `PITFALLS §46`（#323–#327）、本记录；`TASKS/README.md` G1-5 行已改写。
- 待办：① 明亮场景目视复核；② 后摄曝光上限/增益映射是否还能提；③ 把 target 下限做成上游 issue/补丁。
