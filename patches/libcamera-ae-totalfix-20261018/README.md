# libcamera 软 ISP AE 完整修复（2026-10-18）— 两摄自动曝光真正可用

> 上游位置：libcamera v0.7.1。三个补丁互相独立，可分别上送。
> 本目录是**唯一**的 AE 配方；`patches/libcamera-20261018/`（libcrypto 说）与
> `patches/camera-agc-rootcause-20261018/`（早期仅 target 钳制）已被本目录取代。

## 三个独立 bug（缺任一个 AE 都不可用）

| # | 补丁 | 症状 | 机理 |
|---|---|---|---|
| 1 | `0001-…exposure-target-tunable-and-clamped` | `exposureTarget: 0.22` ⇒ 恒黑 | MSV 只有 5 个 bin（取值 1..5），`optimal = target×5`。`target ≤ 0.24` 时第 1 帧 `MSV=1` 就落进 ±0.2 滞回带 ⇒ 加曝光分支永不成立。钳到 `(1+2×0.2)/5 = 0.28` 并 WARN |
| 2 | `0002-…gain-step-must-survive-code-quantization` | 增益永远卡在 1（后摄"总是黑的"） | `againMinStep = (gainMax-gainMin)/100`，后摄 = 0.63。`CameraSensorHelper::gainCode()` **整数除法截断**，`gain=1.63` 与 `1.63+0.63=2.26` 都量化回码 1 ⇒ 每帧更新丢失。改为 `max(1.0, …)` |
| 3 | `0003-…sensor-helpers-identity-gain` | 前摄/后摄增益语义错、振荡 | 本机驱动已把 `V4L2_CID_ANALOGUE_GAIN` 改成**真实增益**（s5kjns 1..64 写寄存器 ×32；gc08a8 1..16 写 ×1024），所以 helper 必须 `AnalogueGainLinear{1,0,0,1}` + `blackLevel 4096`。若写成 `{1,0,0,32}`，IPA 以为范围只有 0.03–2，每次增量被量化成 0（后摄）或算到上限仍不够（前摄）⇒ 振荡 |

## tuning

`s5kjns.yaml` / `gc08a8.yaml`：`blackLevel: 4096` + **`exposureTarget: 0.60`**
（0.22/0.30 都会被钳制或过暗；0.45 偏暗，0.60 实测最佳）。

## 实测结果（在机 vk127，1280×720，明亮环境）

| 相机 | 冷起 → 收敛 | 收敛后稳定值 | 驱动终值 |
|---|---|---|---|
| 后摄 `s5kjns` | `16 → 2.6 → 5.5 → 10.4 → 17.4 → 52 → 78.5 → 94.4` | **115.2（不动）** | exp 3174, gain **28** |
| 前摄 `gc08a8` | `16 → 8.3 → 17.7 → 27.2 → 36.2 → 91.9 → 126.1 → 133.7` | **133.5（不动）** | exp 2532, gain **16** |

图：`logs/cam-bright-20261018/01-后摄-AE自动收敛.png`、`02-前摄-AE自动收敛.png`
（后摄 RGB mean 101/108/112、p50=93；前摄 144/134/124、p50=128）。

## 主机交叉编译（10 s 全量，设备只做运行）

设备侧自编要 4–6 min，改一次代码很痛。现在走主机：

```sh
cd ~/lc-cross/lc-src          # v0.7.1 源码
# 交叉文件要点：musl gcc + -B/tmp/lldbin（ld→ld.lld）+ -idirafter 设备头 + 设备 .pc
PYTHONPATH=~/pylibs ninja -C b-gcc -j28
DESTDIR=/tmp/lc-out ninja -C b-gcc install
# 装机：5 个文件 scp + ldconfig（约 5 s）
#   lib/libcamera.so.0.7.1  lib/libcamera-base.so.0.7.1
#   lib/libcamera/ipa/ipa_soft_simple.so{,.sign}  libexec/libcamera/soft_ipa_proxy
```

⚠️ **必须装 5 个文件**：只换 `ipa_soft_simple.so` 不够（主库和 proxy worker 也要同步），
且 `soft_ipa_proxy` 在 `/usr/libexec/libcamera/`（不是 `/usr/lib/libcamera/proxy/worker/`）。

⚠️ **验证 helper 真的编进去了**：
`strings /usr/lib/libcamera/ipa/ipa_soft_simple.so | grep -cE '^s5kjns$|^gc08a8$'` 必须 = 2。
（本轮曾因用 pristine 源码覆盖 `camera_sensor_helper.cpp` 而丢掉 helper，导致后续测试全跑在
无 helper 的回退路径上，白测一小时。）
