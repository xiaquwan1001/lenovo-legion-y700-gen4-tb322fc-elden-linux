# Linux 侧相机成像「黑帧」真根因 = AGC exposureTarget 不可达（2026-10-18 晚）

> **本篇更正 `reports/camera-linux-vk127-20261018.md` §7 与 `PITFALLS #322`**：
> 「启用 libcrypto 的 libcamera 构建导致软 ISP 黑帧」**是误判**。真根因是
> **tuning 文件里的 `exposureTarget: 0.22` 低于 AGC 的可达下限**。

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 真根因 | `agc.cpp` 的 MSV 只有 **5 个 bin（取值 1..5）**，`optimal = exposureTarget × 5`；`target ≤ 0.24` 时第 1 帧 `MSV=1` 就落在滞回带内 ⇒ **上下两支都不动作，曝光永不改变** ⇒ 恒黑 |
| 修复 | ① 纯 tuning：`exposureTarget: 0.30`（**无需改任何代码**）；② 代码兜底：`Agc::init()` 把 target 夹到 `(1+2×0.2)/5 = 0.28` 并 WARN |
| 已推翻 | 「libcrypto 构建 ⇒ 黑帧」。Alpine 原版包（libcrypto）在 0.30 下**正常出图**；自编无 libcrypto 构建在 0.22 下**同样黑帧** ⇒ 该变量**无因果作用** |
| 在机状态 | Alpine 原版二进制（`md5 6f94f614`，未改一行）+ tuning 0.30 ⇒ 前摄稳定出图、后摄出图（低光场景受上限限制） |
| 设备速度 | 平板自编 ≈ **4–6 min**（8 核 `-j4`）；**主机交叉编译 ≈ 10 s 全量 / 1–2 s 增量**（28 核 `-j20+`）⇒ 已在主机建好交叉管线 |

## 1. 决定性 A/B（同一二进制，只改 tuning）

固定起点 `exposure=256, gain=1`（排除 AE 历史），640×480，1500 帧：

| `exposureTarget` | AGC 轨迹 | 末帧 mean / max |
|---|---|---|
| **0.22** | `exp 256 again 0.03125` × 1500 帧**完全不动** | **0.0 / 0** |
| **0.24** | 同上 | 0.0 / 0 |
| **0.30** | `281→372→493→655→871→1158→1540→2049→2725→3174` | 11.4 / 31 |

推理：MSV = 5 个 bin 的加权平均，恒在 `[1,5]`；`optimal = target×5`。
`target=0.22` ⇒ `optimal=1.1`，滞回带 `[0.9,1.3]` **包含 MSV=1** ⇒
"太暗"分支（`MSV < optimal-0.2`）永不成立 ⇒ 曝光冻结在起始值。
`target=0.30` ⇒ `optimal=1.5`，需 `MSV≥1.7` 才满足 ⇒ 一路爬升。

## 2. 现在能出图到什么程度

Alpine 原版二进制 + `exposureTarget: 0.30`，1280×720：

| 相机 | 帧率 | 末帧 mean / max | 备注 |
|---|---|---|---|
| 前摄 `gc08a8` | 30 fps | 37.5 / 92 | AE 正常收敛（~158 帧内到位） |
| 后摄 `s5kjns` | 30 fps | 10.4 / 28（低光场景） | AE 已到上限 `exp=3174, gain=64`；`test_pattern=2` 时 **mean 124.5 / max 248** ⇒ 链路完好，暗是场景/上限 |

`test_pattern=2` 证明 **ISP/驱动链路完整**（不依赖场景光照）。后摄在明亮场景
（或更大曝光上限）才能到正常亮度；这是 sensor/场景限制，不是软件 bug。

## 3. 主机交叉编译管线（新建，设备只做运行）

| 资产 | 路径 |
|---|---|
| 源码树 | `~/lc-cross/lc-src`（v0.7.1） |
| 交叉文件 | `/tmp/x3.ini`（待固化进仓库） |
| 设备 headers+libs 快照 | `/tmp/dev-sysroot`（`ssh tar` 取 `usr/include` + 选定 `.so`） |
| 合成 sysroot | `/tmp/sysroot-aarch64`（musl 工具链 + 设备 lib/include） |
| 构建目录 | `b-gcc`（release，gcc + `ld.lld`） |
| 产物 | `DESTDIR=/tmp/lc-install ninja -C b-gcc install` → 5 个文件（`libcamera.so`、`libcamera-base.so`、IPA、IPA sign、`soft_ipa_proxy`） |
| 装机 | `scp` 5 文件 + `ldconfig`（约 5 s） |

关键坑：
- GNU ld 2.37（musl 工具链自带）读不了 Alpine 的 **`.relr.dyn`** ⇒ 必须 `-B/tmp/lldbin`（`ld` → `ld.lld` 符号链接）。
- `pkg-config` 必须指向**设备 sysroot 的 `.pc`**，否则会链到主机的 x86 库。
- 用 `-idirafter` 而不是 `-isystem`，让工具链自己的 musl 头优先。
- `meson` 的 `needs_exe_wrapper`：没有 qemu-musl sysroot 时会被拒，但**不设也不影响**（无测试目标）。
- `-Dcam=disabled -Dlc-compliance=disabled` 才不缺 `-levent`（设备没装 libevent）。

## 4. 两条与黑帧无关、但当天各踩一次的坑

1. **`cam -c2` 与 `--list` 编号不一致**：`--list` 按 DT 顺序（1=后摄 `camera@56`、2=前摄
   `camera@31`），但 `cam -c1` 打开的是**前摄**、`-c2` 是**后摄**。用完整 id
   （`-c /base/soc@0/cci@ac7b000/i2c-bus@0/camera@56`）避免歧义 —— 本报告所有"后摄"数据都用了完整 id。
2. **设备 `/tmp` 是 7.3 G tmpfs**：1280×720 ABGR 每帧 3.7 MB，`-C500` 就写满
   ⇒ 之后抓到的全是 **0 字节文件**，被误读成"黑帧"。抓帧一律写 `/var/tmp`。

## 5. 收尾状态

- 设备：libcamera = **Alpine 原版**（`md5 6f94f614`）；tuning = 本轮修正版（0.30）；
  原 tuning 备份在 `/root/cam-tune-20261018/*.prev`；相机模块 **CAM-OFF**（Q24 口径）。
- 补丁/记录：`patches/camera-agc-rootcause-20261018/`（含代码兜底 patch + README）。
