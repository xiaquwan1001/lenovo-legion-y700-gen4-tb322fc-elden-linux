# 四十六、相机 AE 三个独立 bug：exposureTarget 不可达 / 增益步长被截断 / helper 语义不符（#323–#330）

> **本节推翻 §45 #322**（「libcrypto 构建导致黑帧」）。
> 报告：`reports/camera-linux-vk127-20261018-agc-rootcause.md`；
> 配方与补丁：`patches/libcamera-ae-totalfix-20261018/`（三个补丁 + tuning + 实测）；
> 图：`logs/cam-bright-20261018/`。

## 结果（先看结论）

冷起 `exp=256, gain=1`、明亮环境、1280×720、**AE 自行收敛**：

| 相机 | 轨迹 | 收敛后 | 驱动终值 |
|---|---|---|---|
| 后摄 `s5kjns` | `16 → 2.6 → 5.5 → 10.4 → 17.4 → 52 → 78.5 → 94.4` | **115.2 稳定** | exp 3174, gain 28 |
| 前摄 `gc08a8` | `16 → 8.3 → 17.7 → 27.2 → 36.2 → 91.9 → 126.1 → 133.7` | **133.5 稳定** | exp 2532, gain 16 |

## #323 `exposureTarget` 有不可达下限

MSV 由 5 个 bin 加权平均得出、**恒在 `[1,5]`**；判决用 `optimal = target×5` 与滞回 `±0.2`。
`target ≤ 0.24` 时第 1 帧 `MSV=1` 已落在带内 ⇒ **加曝光分支永不成立** ⇒ 恒黑。
实测（同一二进制、固定起点、1500 帧）：0.22/0.24 ⇒ `exp` 一动不动、末帧 mean **0.0**；0.60 ⇒ 爬满、mean 115。
修：tuning 用 **0.60**（0.45 偏暗；0.22/0.30 会被钳制或过暗）；代码兜底钳到 `(1+2×0.2)/5 = 0.28` 并 WARN。

## #324 推翻 #322 的方法论教训

只变一个变量，且要变的是**可疑的那一维**。#322 把「系统包 vs 自编包」当唯一变量，
但两臂都在 `target=0.22` 配方下跑过（目标值改动未记录），于是把「构建方式」误判成因果。
反证：Alpine 原版（libcrypto）在 0.60 下正常出图；自编无 libcrypto 在 0.22 下同样黑帧
⇒ **libcrypto / IPA 隔离对出图无因果作用**。

## #325 增益步长必须 ≥ 1 个增益码（"后摄永远黑"的第二因）

`againMinStep = (gainMax-gainMin)/100`，后摄 = `(64-1)/100 = 0.63`。
`CameraSensorHelper::gainCode()` **整数除法截断**：`gain=1.63` 与 `1.63+0.63=2.26` 都量化回码 1
⇒ **每帧的增益更新被吞掉，增益永远停在 1**，曝光爬到 max 后也不变亮。
修：`againMinStep = max(1.0, …)`。实测修后驱动增益真的在动（28 / 16）。

## #326 helper 增益语义必须与所用驱动一致

本机 `build/m1-73` 驱动已改成**真实增益**语义（控制值就是倍数，写寄存器时才乘）：
`s5kjns` 控制 1..64 写 `val*32`；`gc08a8` 控制 1..16 写 `val*1024`。
⇒ helper 必须是 **identity `AnalogueGainLinear{1,0,0,1}`** + `blackLevel 4096`。
若写成 `{1,0,0,32}`：IPA 以为范围只有 0.03–2 → 后摄增量被量化归零（叠加 #325）、
前摄算到上限仍不够 + 滞回 ⇒ **大幅振荡（37↔130↔8↔139）**。

## #327（最贵的一条）装完必验 helper 真的编进去了

本轮曾用 pristine 源码 `cp` 覆盖 `src/ipa/libipa/camera_sensor_helper.cpp`，之后**约 1 小时**的测试
全跑在「无 helper」的回退路径上，还误判成「前摄物理上限不够（2532×16 vs 3174×64）」。
**验收命令**：`strings /usr/lib/libcamera/ipa/ipa_soft_simple.so | grep -cE '^s5kjns$|^gc08a8$'` **必须 = 2**。

## #328 `cam -cN` 与 `cam --list` 编号不一致

列表按 DT 顺序（1=后摄 `camera@56`、2=前摄 `camera@31`），但 `cam -c1` 打开**前摄**、`-c2` 是**后摄**。
前后摄对比实验按 `-c1/-c2` 记标签会整体张冠李戴 ⇒ **一律用完整 camera id**。

## #329 设备 `/tmp` 是 7.3 G tmpfs

1280×720 ABGR = 3.7 MB/帧，`-C500` 即写满；写满后抓到的帧全是 **0 字节**，会被判成"黑帧/ISP 不写"。
抓帧写 `/var/tmp`，**判图前先看 `ls -la` 尺寸**。

## #330 主机交叉编译 aarch64-musl（Alpine）三件套

① GNU ld 2.37 读不了 Alpine 的 **`.relr.dyn`** ⇒ `-B/tmp/lldbin`（`ld`→`ld.lld` 软链）或 clang+lld；
② `pkg-config` / `PKG_CONFIG_LIBDIR` 必须指向**设备 sysroot 的 `.pc`**，否则静默链上主机 x86 库；
③ 头文件用 `-idirafter` 而非 `-isystem`，让工具链 musl 头优先。
本机 **28 核全量 ≈ 10 s**（release）、增量 1–2 s，对比平板 `-j4` 的 4–6 min。
装机必须拷 **5 个文件**（主库 ×2、IPA ×2、`soft_ipa_proxy` 到 `/usr/libexec/libcamera/`），只换 IPA 不够。
