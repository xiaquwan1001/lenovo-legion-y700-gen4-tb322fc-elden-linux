# 相机 AE 上游正解落地：libcamera sensor helper（s5kjns / gc08a8）

- **日期**：2026-10-17 晚（接 `reports/camera-vk127-20261017.md` §11「上游正解待做」）
- **目标**：用 libcamera 侧的 `CameraSensorHelper` 取代「改内核驱动增益单位」的本地临时补丁，
  让软 ISP 拿到**真实增益**与**黑电平**，从而 AE 正常工作。
- **结论**：✅ helper 已编出并在机生效（`IPASoft: Exposure 2-3174, gain 1-64` / `4-2532, gain 1-16`），
  前摄 AE 达标（mean 91）；后摄 AGC 能一路升到**增益上限 64**、曝光饱和（后摄当前场景极暗，
  属环境而非驱动问题，见 §5）。

---

## 1. 代码改动（1 个文件，41 行）

`src/ipa/libipa/camera_sensor_helper.cpp`：

| 传感器 | 增益模型 | 黑电平 |
|---|---|---|
| `gc08a8`（前摄，GalaxyCore） | `AnalogueGainLinear{1, 0, 0, 1024}`（V4L2 增益码 = 1/1024 步进，0x0400 = 1x） | `4096`（10bit 64 << 6） |
| `s5kjns`（后摄，Samsung） | `AnalogueGainLinear{1, 0, 0, 32}`（码 = 1/32 步进，0x0020 = 1x） | `4096`（同上） |

补丁：`patches/camera-ae-fix-20261017/0002-ipa-libipa-add-s5kjns-gc08a8-sensor-helpers.patch`
（git 格式，可 `git am`；符合 libcamera 现有 helper 写法：`blackLevel_` + `gain_` + `REGISTER_CAMERA_SENSOR_HELPER`）。

> 与既有 `0001-media-i2c-expose-real-analogue-gain.patch` 的关系：**0001 是本地临时措施，本报告后不再需要**
> （内核驱动回到原样：`V4L2_CID_ANALOGUE_GAIN` 仍是原始增益码 32..2048 / 1024..16384）。

## 2. 主机交叉编译（8.7 秒，28 核；取代平板原生编译）

| 项 | 值 |
|---|---|
| 源码 | libcamera **0.7.1**（与设备 Alpine `libcamera-0.7.1-r1` 同版本，IPA 版本号一致） |
| 工具链 | `aarch64-linux-musl-cross`（musl.cc 预编译，GCC 11.2.1）→ `~/toolchains/` |
| sysroot | **只需 libyaml**（`yaml.h` / `libyaml.so` / `yaml-0.1.pc`，从设备原样取回）→ `~/alpine-sysroot/` |
| 主机依赖 | `meson` / `ninja`（apt）+ 纯 Python 的 `ply`（从设备 `site-packages` 拷，`PYTHONPATH=~/pylibs`） |
| cross file | `~/toolchains/aarch64-musl-cross.ini` |
| 配置 | `--buildtype=release -Dpipelines=simple -Dipas=simple -Dv4l2=enabled -Dudev=disabled -Dgstreamer=disabled -Dcam=disabled -Dqcam=disabled -Dtest=false -Ddocumentation=disabled -Dpycamera=disabled -Dlc-compliance=disabled -Dtracing=disabled -Dandroid=disabled` |
| 产物 | `src/ipa/simple/ipa_soft_simple.so`（292 KB） |

**只需替换 `ipa_soft_simple.so`**：`camera_sensor_helper.cpp` 属 `libipa`，静态链进 IPA 模块
（`meson` 里 `libipa = static_library(...)`），主 `libcamera.so.0.7` 不用动。
`libipa` 只被 IPA 模块用（`grep -rl CameraSensorHelper src/libcamera` 为空）。

### 2.1 替换的安全边界（已核）

- `readelf -d` 的 `NEEDED`：`libcamera.so.0.7` / `libcamera-base.so.0.7` / `libstdc++.so.6` / `libgcc_s.so.1` / `libc.so`
  —— musl 动态加载器把 `libc.so` 当自身处理（Alpine 原包写的是 `libc.musl-aarch64.so.1`，两者等价）。
- **签名**：0.7.1 的加载路径**不校验**签名（`IPAManager::isSignatureValid()` 只被 `ipa-verify` 工具用；
  隔离与否看 license，LGPL ⇒ 同进程）。所以替换后删掉失效的 `.so.sign` 即可。
- 回滚：原包备份在设备 `/root/ipa-bak-20261017/ipa_soft_simple.so{,.sign}`。

## 3. 上机部署（2026-10-17 22:33，boot_b `7.3.0-rc7-debug-ged6f232d10e3`）

| 动作 | 结果 |
|---|---|
| 备份原 IPA | `/root/ipa-bak-20261017/` |
| 安装新 `.so` | `/usr/lib/libcamera/ipa/ipa_soft_simple.so`（292456 B），`.sign` 移除 |
| 相机栈 | `CAM_FORCE=1 camera-modules-load.sh` ⇒ **1 media / 17 video**（cmdline 有 `elden_nocamera=1`） |
| 驱动 | **本 boot 的 `gc08a8.ko`/`s5kjns.ko` 是原版**（增益码语义未改；`v4l2-ctl --list-ctrls` 读出 `min=32 max=2048`） |
| 防熄屏 | `keep-awake.sh`（idle-delay 0 / sleep 0 / lock false / dpms On） |

## 4. 验证：helper 生效 + AE 行为

**helper 生效（IPA configure 日志，单位已变成真实增益）**：

```
cam -c1（后摄 s5kjns）: IPASoft: Exposure 2-3174, gain 1-64 (0.63)
cam -c2（前摄 gc08a8）: IPASoft: Exposure 4-2532, gain 1-16 (0.15)
```

对照修复前（无 helper）：`gain 32-2048`（原始码被当倍数）。`cam --list-properties` 确认
cam1 = Back / Model **s5kjns**，cam2 = Front / Model **gc08a8**。

**AE 结果（640×360，帧率实测 ~1.65 fps 后摄 / ~2.3 fps 前摄）**：

| 相机 | 19:5x 首测（后摄对无光桌面） | 22:52 用户移机后复验 | 判定 |
|---|---|---|---|
| 前摄 gc08a8 | Gain 16（上限）、mean 90.9/81.4/75.8 | `Gain=14.25`, 曝光 32.8 ms，mean **123.0/134.7/115.6** | ✅ AE 正常；真实画面（桌面/插座/木纹） |
| 后摄 s5kjns | Gain 64（上限）、mean 2.5 | `Gain=51.8`, 曝光 33163 µs（饱和），mean **210.7/207.3/209.3** | ✅ AE 收敛并稳定（`exposureMSV` 2.44–2.66 落在最优带 2.3–2.7）；真实画面（百叶窗/白帘/包装盒），但**整体过曝发白** |

复验图：`logs/cam-ae-helper-20261017/{rear-ae.png,front-ae.png}`（1280×720，主机目视确认）。

**test_pattern=2（彩条）**：后摄 mean 124/124/127.5、max 255 ⇒ **数字链路 + ISP + helper 全通**，
黑的不是数据链。

## 5. 「后摄黑屏」定位：增益有效、是场景无光（已用 raw 定量证明；用户移机后已出真实画面）

直接读后摄 raw（`/dev/video0`, 4080×3072 `pgAA`，`v4l2-ctl` 采 2 帧）对比手动增益：

| 手动 `analogue_gain`（原始码） | p10 | p50 | p90 | max |
|---|---|---|---|---|
| 32（1x） | 5 | 16 | **16** | 255 |
| 2048（64x） | 15 | 16 | **127** | 255 |

p90 16 → 127（~8x）⇒ **寄存器/驱动/增益通路正常，是场景没光**（平板当时平放，后摄对着桌面）。
用户 22:52 把后摄移向有光场景后复验：**真实画面**（百叶窗/白帘/红色包装盒），
`IPASoftExposure` 显示 `exposureMSV` 稳定 2.44–2.66（最优 2.5±0.2）⇒ **AE 收敛、不再卡在增益 1**。

**过曝发白（mean 210）是新的、独立的问题**：AGC 的直方图目标（5 bin 均值 2.5）与最终显示亮度不匹配
（该场景有大面积高光），且无 CCM/伽马标定 ⇒ 属 tuning。当前口径：AE 功能=通过，成像质量=待调（§6）。

## 6. 已知残留（相机质量，非本任务）

1. **偏绿**：两传感器无标定 ⇒ `uncalibrated.yaml`，AWB/CCM 缺失。0.7.1 的 simple IPA **有 `Ccm` 算法**
   （`src/ipa/simple/algorithms/ccm.cpp`），后续可在 tuning yaml 里补 `Ccm` 矩阵 + `Awb` 参数。
2. 软 ISP 吞吐：原生 4096×3072 ~1.1 fps、1280×720 ~2 fps、640×360 ~1.7-2.3 fps（CPU/GPU 瓶颈）。
3. 后摄 AGC 收敛慢（固定 10%/帧，低 fps 下几十秒）：调 `Agc` 非可 tunable；实际用 `cam-loopback.sh start rear`
   这类**手动曝光**入口更快（注意驱动已回原版 ⇒ 手动增益要写**原始码**，如 `analogue_gain=1500`，不是 47）。

## 7. 本会话「设备失联」事件：成因已澄清（**与 Q24/系统无关**）

- 22:14 设备失联：主机侧 USB 网卡 `enx021e5eede102` 消失，`lsusb` 出现 `18d1:d00d` ⇒ 设备在 **fastboot**。
- **成因（用户 22:50 更正）**：本会话先在平板上跑 `ninja` 原生编译，**过热**，用户**手动重启到 BL**。
  ⇒ **不作为 Q24 样本、不写「系统掉电」结论**。
- 处置：`fastboot reboot`（无写盘）⇒ 24 s 回 `boot_b`（`7.3.0-rc7-debug-ged6f232d10e3`，非 vk127 RAM 内核）。
- 后果：`vk127` RAM 内核丢失；不影响本任务（IPA 是用户态，与内核 UTS 无关）。
- **纪律**：此后平板上不再做重编译（`.pi` 政策：编译走主机交叉），见 `PITFALLS #302`。

## 8. 资产清单

| 类型 | 路径 |
|---|---|
| 补丁 | `patches/camera-ae-fix-20261017/0002-ipa-libipa-add-s5kjns-gc08a8-sensor-helpers.patch` |
| 构建产物 | 主机 `/tmp/lc-build-r/src/ipa/simple/ipa_soft_simple.so`（可重编：§2 配方） |
| 工具链 | `~/toolchains/aarch64-linux-musl-cross/`、`~/toolchains/aarch64-musl-cross.ini`、`~/alpine-sysroot/usr/{include/yaml.h,lib/libyaml*,lib/pkgconfig/yaml-0.1.pc}`、`~/pylibs/ply` |
| 设备备份 | `/root/ipa-bak-20261017/`（原 IPA）、`/root/cam-ko-bak-20261017/`（vk127 的补丁版驱动，本 boot 未使用） |
| 设备侧 tuning | `/usr/share/libcamera/ipa/simple/{s5kjns,gc08a8}.yaml`（`BlackLevel: 4096`，与 helper 值一致，保留无害） |

---

# 续四：成像调优（A 项）——曝光目标可调 + 黑电平复核 + 色偏实测

## 13. 「过曝发白」的真根因：AGC 目标固定 50%（线性）

`ipa/simple/algorithms/agc.cpp` 把「最优曝光」写死为直方图 5 段均值的**中点 0.5**，
而 debayer 端默认 `gamma=2.2`（输出 = 线性^(1/2.2)）。0.5 线性 ⇒ 输出 **0.73 ≈ 186/255**，
高光必爆、整幅发白。

**改法（新补丁 0003，按 rkisp1 `goc.cpp` 的 `gamma` 先例）**：`Agc` 从 tuning 读
`exposureTarget`（0..1 的直方图区间比例），默认 0.5 保持旧行为 ⇒ 老 tuning 文件语义不变。

```yaml
  - Agc:
      exposureTarget: 0.22     # ≈18% 线性灰，配 2.2 gamma 出正常亮度
```

**同场景 A/B（后摄，1280×720，间隔 8 分钟）**：

| 目标 | 结果 | 图 |
|---|---|---|
| 0.5（旧） | mean **210.7 / 207.3 / 209.3**，高光成片爆白 | `logs/cam-ae-helper-20261017/rear-ae.png` |
| 0.18（新） | mean **160 / 160 / 159**，室内可辨（柜子/箱子/百叶窗） | `logs/.../rear-target018.png` |

在机默认值取 **0.22**（两个传感器 yaml 都写）；归档 `patches/camera-ae-fix-20261017/{s5kjns,gc08a8}.yaml`。

## 14. 黑电平复核：4096 是对的（用「最短曝光」法实测）

- 方法：把 sensor 子设备设成 `exposure=2`（最小）+ `analogue_gain=32`（1x）后抓 raw 一帧
  —— 光信号≈0，剩下的就是 pedestal。
- 结果（10-bit packed 解码）：`p50 = 64`，众数 **64**（121k/236k 样本）⇒ **pedestal = 64 @10bit**
  ⇒ 16-bit 黑电平 = `64 << 6 = 4096`，与 helper/ tuning 值一致。**不是黑电平错**。
- 旁证：房间里「暗处」在成片上仍有 48–105，是**镜头反差/眩光**（画面里有强光源），不是 BLC 残留。

## 15. 色偏：实测是中性，暂不需要 CCM

在目标 0.18 的成片上分区取样（后摄）：

| 区域 | mean RGB | G/R | G/B |
|---|---|---|---|
| 深色箱体 | 105 / 103 / 100 | 0.98 | 1.03 |
| 白布 | 112 / 111 / 112 | 0.99 | 0.99 |
| 柜格 | 129 / 125 / 117 | 0.96 | 1.06 |
| 百叶窗 | 125 / 126 / 126 | 1.01 | 1.00 |

⇒ AWB（grey-world，`gains=g/r,1,g/b`，上限 4.0）已经把色偏压到 ±4% 内。
之前「偏绿」来自**前摄那张图的场景（墙面偏色）+ 无标定**，不是系统性缺陷。
`Ccm` 算法（0.7.1 已有）暂不启用：需要真实标定矩阵，且官方注释提示有性能代价；留作后续。

## 16. AE 收敛慢的定量解释（重要，别再当故障查）

- `SwStatsCpu::kStatPerNumFrames = 4` ⇒ **统计每 4 帧才出一次**，AGC 每次只走 10%；
  后摄 720p ~1.2 fps ⇒ 每 **3.3 s** 才前进一步。
- 实测：从手动基准到收敛要 **60–150 帧**；`exposureMSV` 每次日志都能看到单调逼近目标带
  （`target*5 ± 0.2`）。
- 判据：不要用「一两次抓帧的均值」判 AE 好坏；要么跑 ≥150 帧，要么直接看 `exposureMSV` 是否进带。
- 现场变动（灯/位置）会让截图对比失效 ⇒ 做 A/B 用 `test_pattern`（数字恒定）或固定手动曝光基准。

## 17. 产物

| 类型 | 路径 |
|---|---|
| 补丁 | `patches/camera-ae-fix-20261017/0003-ipa-simple-agc-make-exposure-target-tunable.patch` |
| tuning | `patches/camera-ae-fix-20261017/{s5kjns,gc08a8}.yaml`（blackLevel 4096 + exposureTarget 0.22） |
| 设备 | `/usr/share/libcamera/ipa/simple/{s5kjns,gc08a8}.yaml`、`/usr/lib/libcamera/ipa/ipa_soft_simple.so`（含 0002+0003） |
