# Hindsight — elden（y700-elden）

Techniques and root causes proven on Qualcomm/Lenovo tablet flashing. Host-machine

<!-- Older entries compacted -->
 加 WCD 采集子图；UCM 加 Mic。
4. 稳压映射照原厂（`L15B`=WCD vdd、`BOB1`=mic-bias）。

**B. 先用 USB/Type-C 或蓝牙麦兜底**（当前可用，快速让"输入设备"不为空）。

## 顺带：haptics 已定位（不是包缺失）

- 硬件正常（`Haptic.Vibrate` 返回 true）。
- 原因：feedback profile='full'（默认，只映射 Sound）。**已设 `org.sigxcpu.feedbackd profile=quiet`**（震动代替声音）。

> 想要 LineageOS 那种"声音+震动强度分开"：feedbackd 每个事件只能一种类型（Sound **或** Vibra）。要两者兼得，需要写自定义 device theme（例如按键走 Vibra、其他走 Sound），并可用 `max-haptic-strength` 调强度——可以做，但要权衡。

**要我开始做 A（WCD939x）吗？** 这是麦克风/耳麦正路。或者先做 B 兜底、再排期 A？


## Automatic settled outcome - 2026-10-03

收到——**input 未打通，到此停下**。

## 技术报告已落盘

- `archive/topics/AUDIO-INPUT-2026-10-04.md`（本日全量技术报告）
- 提交 `5d70996`；`check-doctor` **FAIL=0/WARN=0**

## 结论汇总

| 项 | 状态 | 一句话 |
|---|---|---|
| **音频播放** | ✅ | 真根因＝tplg MI2S **SD 线错**（SD0→SD1），修 tplg 后出声（vk43） |
| **桌面音频** | ✅ | PipeWire+WirePlumber+UCM2 → "Built-in Audio Speaker playback" |
| **温控** | ✅ | 四级热 trip 70/82/90/105 ℃ + cdev 生效（vk42） |
| **音频输入** | ❌ **未打通** | **本机麦克风是模拟麦接 WCD939x，不是 DMIC**；主线 DTS 未启用 WCD939x |
| **按键震动** | ◐ | 硬件正常；根因 profile='full'，已设 **quiet** |
| **日志方法** | ✅ | `scripts/devlogs.sh` |

## 输入未通的根因（关键）

原厂设备树 `backup/stock-elden/elden.dts` 的 `qcom,audio-routing` **全是 `AMIC*`/`VA AMIC*` + `MIC BIAS*`，没有一条 `VA DMIC`**：

- 本机音频栈 ＝ Awinic smart PA（I2S，已通）＋ **WCD939x 编解码器（SoundWire）**；
- 麦克风偏置来自 **WCD939x 的 MIC BIAS**，ADC 在 WCD，经 SWR 送 ADSP；
- 我们按上游 MTP 做的 VA DMIC 采集虽然 **ALSA/APM 图全绿**（`MultiMedia3 Capture`、DAPM 全 On、`vdd-micb` On、寄存器正确），但硬件无 DMIC → 录音恒 0。

⇒ 正路是 **WCD939x bring-up**（镜像 `sm8750-mtp.dts`：wcd939x + rx/va SWR master + 稳压 + capture dai-link + tplg + UCM），**本轮未做**。

## 设备当前状态

- 内核 **vk45**（`7.2.0-debug-g26cc186e9485-dirty`），播放正常（HiFi 扬声器 sink）。
- 期间 UCM 加 `Mic` 段曾弄坏 HiFi verb，**已撤回并重启恢复**（`PITFALLS #91` 已记这个坑）。

停止。下一步若要继续，从 **WCD939x bring-up** 开工。


## Automatic settled outcome - 2026-10-04

## 项目进度快照（实测 + 文档核对）

**设备实测（U2，刚 SSH 确认在线）**
| 项 | 实测值 |
|---|---|
| 内核 | `7.2.0-debug-g26cc186e9485-dirty` = **vk45** |
| 持久根 | `/dev/sda17` ext4 ✅ |
| 运行时长 | **up 7h20m**（当前无重启环） |
| 采集 PCM | `MultiMedia3 Capture` 在，但录音恒 0（硬件是模拟麦→WCD939x，非 DMIC） |
| adb/fastboot | 空（U1 未接入） |

**目标完成度**
| 目标 | 完成度 | 本轮变化 |
|---|---|---|
| **G1** | **≈82%**（22 ✅ / 3 🟡 相机·TF·BT / 3 ⬜ DP·NFC·CDSP） | 音频**播放**听声 ✅、桌面 PipeWire+UCM2 ✅、温控四级 ✅、关机/重启 ✅ |
| **G2** | ≈45%（C4 代码全就绪待上机、C9 用例定稿） | 无 |

**硬缺口（4 个）**：① 音频**输入**（WCD939x，正路未做，v45 DMIC 方向已证伪）② 相机出流 ③ TF 卡写稳定 ④ BT 配对收口。
**稳定性阻塞**：熄屏→重启（G1-22，源锁定在 vk34 后 5 文件增量，未根治，靠禁空闲熄屏规避）。

## 文档漂移（已发现，需收口）

- `INDEX.md §3`：仍写"vk40 未上机 / 无单元在机 mainline / 剩 4 缺口含音频听声"——**过时**（现 U2=vk45）。
- `TASKS.md §0`：进行中仍列"音频听声"——**过时**（G1-4 已 ✅）。
- `check-doctor`：**WARN=1**（会话 jsonl 53 ≠ 索引 52）。
- `.pi/memory/HINDSIGHT.md` 有**未提交**改动。

## 下一步规划（按性价比排序）

**P0 · 零设备成本（本会话即可做完）**
1. 文档收口：改 `INDEX §3` + `TASKS §0` 数字，`RESOURCES §4` 补第 53 会话，提交 HINDSIGHT，跑 `check-doctor` 到 FAIL=0/WARN=0。

**P1 · 占 U1（"覆盖 a 槽前不可复得"，越早越值）**
2. **C0 真 Android 对照取证 + Q13 AVF 资产复采**：U1 仍 stock+root。`getprop` 全量 / Widevine 级别 / 7 传感器采样 CSV / 目标 App 录屏 + AVF APEX 解包。这是兼容层的"标准答案"，U1 一旦动手术就没了。

**P2 · 占 U2（主线技术攻坚，二选一）**
3. **WCD939x bring-up（音频输入正路）**：镜像 `sm8750-mtp.dts` 的 wcd939x + rx/va SWR master + 稳压 + capture dai-link + tplg + UCM。中等偏大工作量，是你上轮定的下一步。
4. **G1-22 熄屏→重启根治**：现 uptime 7h20m 稳定（规避生效），但要日常可用必须解；可在有带外串口+EDL 回退前提下做 vk34→vk40 五文件二分（已有 V1/V2 镜像）。

**P3 · 常规缺口**：G1-5 相机出流（只差 config/部署）→ G1-6 TF 卡 → G1-7 BT。

**我的建议**：先 **P0 收口（10 分钟）**，然后 **P1（U1 取证，过期作废）**——趁 U1 还是 stock，把不可复得的东西先采下来；之后回 U2 攻 **WCD939x**。

要我先执行 P0 收口吗？或者你直接指定 P1/P2 哪条开工。


## Automatic settled outcome - 2026-10-04

## P0 + P1（主机侧）完成

**P0 文档收口** — 提交 `4d69c47`，`check-doctor` **FAIL=0 / WARN=0**
- `INDEX §3`、`TASKS §0` 对齐 vk45 现状（G1 80%→82%，音频听声→已完成）
- `RESOURCES §4` 补第 53 会话（53=53）、修正统计与"最后确认版本=vk45"、补 vk41–45 内核时间线
- `PITFALLS`/`RESOURCES` 正文 #1–#88 → #1–#91；§15.5 音频条目更新

**P1 主机侧（不占设备）** — 提交 `1ba016b`
- **AVF 资产已复原**（GAPS Q13 资产部分闭合）：从原厂 259 镜像 `/mnt/Samsung/l2/system_a.pristine.img` 离线 debugfs 提取 → `backup/avf/`
  - `bin/crosvm`（**含 Gunyah/Geniezone/KVM 后端**）、`vm`、`virtmgr`、`virtualizationservice`…
  - `etc-fs/microdroid_kernel`（**6.6.77-android15-8**）、`microdroid_super.img`、`u-boot.bin`、`rialto.bin`、initrd ×2
  - 重跑脚本 `scripts/extract-avf-assets.sh` 可复原，**不需要设备**（同 259 build，与 U1 a 槽等价）
- **C0 取证采集器就绪**：`scripts/c0-android-evidence.sh`（adb 采 getprop/DRM/传感器清单/分区 → `backup/<SN>-<档>/c0-baseline/` + SHA256SUMS）

## P1 设备侧：阻塞，需要你接入 U1

当前 USB 只有 U2 的 NCM 网关（`1d6b:0104`），**U1 未连接**。a 槽覆盖前真正不可复得的只剩 C0 真机数据，越早采越好。

**请这样操作：**
1. U1 用 USB 连主机，打开「USB 调试」并授权。
2. 告诉我，我跑 `scripts/c0-android-evidence.sh`（自动识别 SN/容量档）。

**两项需你亲自补（采集器尾已打印提示）：**
- **7 颗传感器 30 s CSV**：设备 Termux 里 `pkg install termux-api` → `termux-sensor -l` 列出后逐颗 `termux-sensor -s <名> -n 300 > c0-<名>.csv`
- **5 个目标 App 关键流程录屏**：`adb shell screenrecord --time-limit 30 /sdcard/c0-app-N.mp4` 后 pull

## 下一步选择

U1 就绪前，主机侧能做的已做完。**要不要现在就在 U2 上开工 P2 的 WCD939x bring-up（音频输入正路）？** 
这是你上轮定的方向，且 U2 现在空闲（uptime >7 h 稳定）。或者你先把 U1 接上，我立刻跑 C0。


## Automatic settled outcome - 2026-10-04

先给你判断依据——C0 采集的**每一项、来源、是否已有等价数据**：

## C0 采集清单与"稀缺性"评估

| # | 采集项 | 已有等价物？ | 真正需要 U1 吗 |
|---|---|---|---|
| 1 | `getprop` 全量 / dalvik 属性 | ✅ 已有 U2 解锁前基线 `backup/HA2EXB0E-16+512/pre-unlock/getprop-locked.txt`；原厂镜像在手 | ❌ |
| 2 | DRM 级别 / Widevine（`dumpsys media.drm`） | ◐ pre-unlock 只记了 `sys.lenovo.widevine_security_level=L1`；U1 已解锁（2026-08-16）→ 大概率 L3，**不新增 L1 参照** | ❌（L1 参照 U2 基线已占） |
| 3 | 分区 `by-name` / `packages` / `proc-partitions` | ✅ pre-unlock 基线 + 原厂镜像 | ❌ |
| 4 | 传感器**清单** | ✅ pre-unlock 基线有传感器清单 | ❌ |
| 5 | AVF / virt | ✅ 今天已从镜像离线提取（crosvm+u-boot+microdroid） | ❌ |
| 6 | **7 颗传感器 30 s 采样 CSV** | ❌ 无 | ✅ **唯一真数据**（但见下） |
| 7 | **5 个目标 App 关键流程录屏/表现** | ❌ 无 | ✅ **唯一真数据**（但见下） |

## 关键判断点

1. **C0 的"自动采集"部分（#1–#5）基本冗余**——已有 U2 解锁前基线 + 原厂镜像 + 今天的离线 AVF 提取覆盖。
2. **真正不可复得的只有 #6/#7（运行时行为）**，它们是 G2 容器兼容度的"尺子"。
3. **但运行时证据不必用 U1**：U2 的 **a 槽仍是 stock 259 Android**（BL 已解锁），随时可启动 Android 采同样的 #6/#7。而 Phase B（回收 a 槽）尚远、未拍板。⇒ 用 U1 只是"免得动 U2"，不是唯一来源。
4. 项目原则是**设备等价**，任何单元状态满足就能干活。

## 结论（供你拍板）

**不建议为 C0 专门接 U1。** 理由：自动项冗余；运行时项（传感器/App）可在 U2 a 槽做，且在 Phase B 前任何时间都来得及，**不阻塞 G1，也不阻塞容器主线**。

- 若你愿意顺手接 U1：我可以 5 分钟跑完自动项 + 你在 U1 上录 5 段、采 7 段，落一份"真机参照"，成本也就一次接线。
- 若嫌麻烦：**跳过 U1**，我直接开 **U2 的 P2（WCD939x 音频输入正路）**；运行时 C0 等哪次切 U2 a 槽再补。

你倾向哪种？


## Automatic settled outcome - 2026-10-04

P2 第一版已就绪。以下是本次完成内容与上机步骤。

## 已完成（主机侧，vk46）

**DTS**（`linux/.../sm8750-lenovo-elden.dts`，已 commit `4c68eb5ed`）
- 新增 `wcd939x` codec 节点：reset = **TLMM gpio101**（原厂 base dtb 证实）、稳压 **L15B**（buck/rxtx/io）+ **BOB1**（mic-bias）+ **L2I**（px）、micbias 2.0/2.7/1.8/2.0 V（照原厂）
- `sound` 新增 **`WCD Capture`** dai-link：cpu `TX_CODEC_DMA_TX_3`，codec `wcd939x + swr2 + lpass_txmacro`
- audio-routing 加 `AMIC1–5 → MIC BIAS*` + `TX SWR_INPUT1 ← ADC2_OUTPUT`
- `&swr1/&swr2` 使能并挂 `wcd_rx`/`wcd_tx`（端口映射照 MTP/原厂）

**tplg**（`scripts/audio-tplg/*.m4`，commit `819cfc9`）
- MultiMedia3 capture 增加 `TX_CODEC_DMA_TX_3` device 子图（与 VA DMIC 并列），重建 **16860 B `3bd05394…`**

**产物**
| 文件 | 用途 | sha256 |
|---|---|---|
| `out/boot-elden-vk46.img` | 持久 b 槽 | `1ddf239b…`（签名后 `0f96e381…`） |
| `out/boot-elden-vk46-ram.img` | **零写盘 RAM 验收** | `57d99228…` |
| `bootslot-b/boot_b.img` | 已签名的持久 boot_b | 96 MiB |

**已顺手更新持久根 tplg** → `/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`（旧版备份到 `/root/Lenovo-Y700-Gen4-tplg.vk45.bak`）。

## 请你上机（推荐先 RAM 试，零风险）

```bash
cd ~/y700-elden
# 1) 进 fastboot（vk45 已带 PSCI vendor reset）
ssh root@192.168.7.1 'eldroid-bootctl reboot bootloader'
# 2) 零写盘 RAM 启动 vk46（不动 boot_b；失败掉电即回 vk45）
fastboot boot out/boot-elden-vk46-ram.img
```

回到 Linux（SSH `192.168.7.1`）后我验证：
- `dmesg | grep -iE 'wcd|swr|soundwire'`（编解码器是否枚举）
- `arecord -l` / `aplay -l`（是否出现 `WCD Capture`）
- `amixer -c0 sget 'ADC2 MUX'` + `arecord` 录一段看是否非静音

**若确认无碍**，再落持久版（我来或你来均可）：
```bash
scripts/flash-b.sh out/boot-elden-vk46.img --reboot
```
**回滚**：`scripts/flash-b.sh out/boot-elden-vk45.img --reboot`（boot_b），tplg 从设备 `/root/Lenovo-Y700-Gen4-tplg.vk45.bak` 还原。

⚠️ 风险提示：新增 WCD dai-link 若编解码器未枚举，声卡可能整体注册失败（连播放一起挂）——所以**先 RAM 试**。fastboot 因涉及物理恢复，按惯例请你亲自执行；要不要我通过 SSH 直接把持久版刷上（`flash-b.sh` 带读回校验）？


## Automatic settled outcome - 2026-10-04

串口核心发现 + WCD 进展已收口。汇报：

## 1. 你遇到的"没进桌面"——**不是 vk46 内核故障**

串口显示设备停在 initramfs（`findmnt /`=`rootfs`），`/proc/cmdline` **没有 `elden_root=LABEL=linux17`**。原因：`scripts/build-boot.sh` 每次会把最后产物覆盖为 `out/boot-elden.img`；我先建持久版再建 RAM 版 → `out/boot-elden.img` 变成了 **RAM 变体**。RAM 变体按设计**不切持久根、不启桌面**。已记 `PITFALLS #92`。

## 2. WCD939x 音频输入 bring-up（本次实质进展）

| 项 | 结果 |
|---|---|
| DTS 新增 `wcd939x` codec（reset=TLMM101、L15B/BOB1/L2I 稳压、micbias 照原厂）+ `&swr1/&swr2` + `wcd-capture-dai-link`（TX_CODEC_DMA_TX_3） | ✅ |
| tplg 新增 WCD TX3 采集子图 | ✅ |
| **codec 枚举** | ✅ `bound sdw:2:…00:4` / `sdw:3:…00:3`（RX/TX 都绑定） |
| **声卡注册 / 播放** | ✅ `Lenovo-Y700-Gen4`、`arecord -l` 出现 `MultiMedia3 Capture`、`speaker-test` 正常 |
| **WCD 采集** | ❌ `arecord` → `pcm_read I/O error`（APM 图启动**无报错**、无数据） |

**已排除**：RAM 模式、双采集 BE（去 VA 仍错）、DAPM mux 未设（按序设 mux 仍错）、codec 未枚举。
**新证据**：原厂 Android 用 HAL `mixer_paths_sun_*.xml`（非 ALSA tplg）。提取 `primary-mic` 权威序列 = **ADC1/AMIC1 → SWR_MIC4 → SMIC MUX2 → DEC2 → AIF1**（我们走 ADC2/SWR_INPUT1 + TX3）。

## 3. 设备当前状态

已刷 **持久 vk47**：**桌面正常（Phosh）+ 播放正常**；WCD codec 在位；输入仍未打通（与之前一样，实际无回归）。回退：`bootslot-b/boot_b-vk34recon.img` 或重刷 vk45。

## 4. 已提交

- 内核：`4c68eb5ed`(vk46)、`bd114ca33`(vk47)
- 主仓：tplg `819cfc9`/`5430be8`；文档 `fc7077c`（含 `archive/topics/WCD939X-2026-10-04.md`、`PITFALLS #92`）
- `check-doctor` **FAIL=0 / WARN=0**

## 5. 建议下一步（详见专题档案 §4）

1. **对齐原厂索引**：capture BE 改到 AIF1 对应 codec-DMA，DTS 路由改 `TX SWR_INPUT4 ← ADC1_OUTPUT`，按 `primary-mic` 序列设 mux。
2. **ADSP 侧取证**：抓 ADSP 日志看 TX3 容器是否被拒。
3. **兜底**：USB/Type-C 或蓝牙麦（不依赖 ADSP 静态图）。

要我从第 1 条继续，还是先做兜底（BT/USB 麦）让"输入设备"可用？


## Automatic settled outcome - 2026-10-04

已侦察完（文档/任务台账/git 状态/设备实测）。先给结论，再给编排方案。

## 一、数字结论

**真正能并发的只有「主机侧、且不碰同一资源」的 3 条 lane；设备相关一律串行。** 约束来自三把锁：

| 锁 | 现状 | 后果 |
|---|---|---|
| **设备锁** | 仅 U2 在线（`192.168.7.1`，uptime 28 min）；U1 未接（adb/fastboot 空）；刷写按惯例由你操作 | 所有上机/复现任务**串行**，且需人 |
| **内核树锁** | `geekidos-linux`（13 G）**单一工作树**，非 submodule，HEAD=`bd114ca33`；主库 `.gitignore` 排除整树 | 两个 agent 同时改内核 = 冲突；并发须 `git worktree` |
| **文档 SSOT 锁** | 每文件单写者；主库单 index，无 remote | 多 agent 同时 `git commit` = `index.lock` 竞争；文档并行改 = 冲突 |

## 二、当前可并发的 3 条主机 lane（互补、零资源重叠）

| Lane | 内容 | 资源占用 | 建议执行者 |
|---|---|---|---|
| **L1 内核草稿**（单写者） | G1-5 相机 DTS/config 补齐 **或** WCD939x 采集修复草稿（二选一，不可同时） | **独立 worktree**（`git -C geekidos-linux worktree add ../wt-camera -b elden/camera-wip`），只改 DTS/驱动，不 build 全量 | 子 agent（camera 角色）+ 主 agent 复核 |
| **L2 脚本/工具**（主库独立目录） | C7 `slot-switch.sh`、A16 残留 `new-tablet` 参数化 | `scripts/` 独立文件，**不碰文档/内核** | 子 agent（脚本角色） |
| **L3 只读研究**（零写入） | C3 身份/DRM 社区×本机取证对照表；G1-9 DP 的 `pmic_glink`/UCSI 只读勘察（日志+DTS 依赖） | 只读 `archive/`、`RESOURCES §1.3`、web | 子 agent（research 角色），产出**草稿到独立路径** |

**设备 lane（串行、主 agent 协调+你操作）**：WCD939x 采集正路 或 G1-22/23 二分，**同一时刻只做一件**。

## 三、主 agent 编排 / 子 agent 执行 分工

```
主 agent（编排者 + 唯一设备协调者 + 唯一 git 提交者 + 独立验证者）
 ├─ 设备 lane：串行发指令 → 你上机 → 主 agent 独立复跑验收（不信子 agent 自报）
 ├─ 子 agent ×3（后台，并发上限 ≤3，deepseek-flash 已默认）
 │    ├─ L1: worktree 内改内核 → 产出 patch 到 patches/（不 commit 内核）
 │    ├─ L2: 写 scripts/ 新文件（不动既有文档）
 │    └─ L3: 只读研究 → 草稿写 archive/ 或 .pi/drafts/
 └─ 收口：主 agent 统一 git add/commit + check-doctor + 更新 TASKS/RESOURCES
```

铁律（写进 `.pi/README.md`/AGENTS）：
1. **子 agent 一律不 commit、不改领域层文档**——避免单 index 竞争与 SSOT 破坏；
2. 内核改动走 **worktree**，主 agent 验后 `git -C geekidos-linux diff` 回导 `patches/`；
3. 设备 lane 与"改内核 DTS 的 L1"**互斥**（同树），要并行须给设备任务也开 worktree；
4. 并发 ≤3，避免 ustc_ai/budget 式 429（deepse


## Automatic settled outcome - 2026-10-04

音频输入**彻底打通并持久化**。本轮总结：

## 🎉 核心成果：WCD939x 麦克风可用

**G1 从 82% → 85%**（硬缺口 4 → 3：剩相机出流、TF 卡、BT 配对）。

| 项 | 结果 |
|---|---|
| WCD939x codec | ✅ RX/TX SoundWire 均 bound、声卡注册 |
| 播放 | ✅ 扬声器 sink 正常（未回归） |
| **输入** | ✅ **`HiFi__Mic__source` 在桌面可用**（`arecord -D default` rc=0 出数据） |
| 重启持久 | ✅ 重启后自动可用 |

## 两个关键根因（都已记档）

1. **"没进桌面"** = 刷/启的是 **RAM 变体**（`build-boot.sh` 覆盖 `out/boot-elden.img`），cmdline 无 `elden_root` → 停在 initramfs。**非 vk46 内核故障**。→ `PITFALLS #92`

2. **采集 I/O error** = 缺采集路径的 **DAPM mixer/mux 控件**（尤其 `ADC2_MIXER Switch`），**不是 ADSP 问题**（kretprobe 证明图命令全返回 0、厂商 `resourcemanager` 也印证 TX-3 索引正确）。→ `PITFALLS #91`
   - 另：UCM 加 capture 段会被 **ACP 探测**（打开 PCM）拒绝——因 DPCM 采集 PCM 在 FE-BE 未连时打不开；解法是把 FE-BE 路由放进 **`SectionVerb.EnableSequence`**。

## 交付

- **内核**：`4c68eb5ed`(vk46)、`bd114ca33`(vk47，去 VA DMIC + WCD 采集)
- **tplg**：`819cfc9`/`5430be8`
- **UCM2 Mic**：`11f06ac` + 修正 `f2bf682`
- **文档**：`archive/topics/WCD939X-2026-10-04.md`、`PITFALLS #91/#92`
- `check-doctor` **FAIL=0 / WARN=0**

## 设备现状

持久 **vk47**：Phosh 桌面 + 扬声器 + **麦克风源**均可用。可在「设置 → 声音」看到输入设备，或直接录音测试。

**下一步可选**：① non-PipeWire 场景的 ALSA mixer 默认；② 双麦/阵列（AMIC2–5）；③ Type-C 耳麦（需 `wcd939x-usbss`）。或回到 G1 缺口：相机出流 / TF 卡 / BT 配对。


## Automatic settled outcome - 2026-10-04

我已经把「音频剩下的问题」摸清并动手了。先给结论。

## 一、现状核验（U2 在线，持久 vk47，实时查）

| 项 | 状态 |
|---|---|
| 扬声器 sink | ✅ `HiFi__Speaker__sink`，Active Profile=HiFi |
| 麦克风 source | ✅ `HiFi__Mic__source`（现在被「设置」的 peak-detect 占用，故 raw ALSA `hw:0,2` 会 busy） |
| 双功放 | ✅ 两片 `aw88461` 都在 i2c9（0x34/0x37）且驱动已绑定 |
| 卡控制 | ✅ 有 `Headphone Jack`/`Mic Jack`（MBHC）、`HPHL/HPHR Switch` 等 |

## 二、剩余音频问题（4 项）

| # | 问题 | 性质 | 需要你 |
|---|---|---|---|
| **R1** | **有线耳机/耳麦**：WCD939x 的 HPHL/HPHR 放着没接（缺 `RX_CODEC_DMA_RX_0` 播放 dai-link），耳机插上也无声；耳麦麦(AMIC2)未路由 | 功能缺口 | 要 |
| R2 | 双麦/阵列 AMIC2–5 | 增强 | 要（环境声） |
| R3 | 非 PipeWire 的裸 ALSA 默认混音 | 收尾 | 否 |
| R4 | C6 容器（Waydroid）音频 | G2 | 要 |

**注意**：GSMArena 规格写 **本机无 3.5mm 耳机孔**（双 USB-C）。所以 R1 只能是 **USB-C 模拟耳机**（或模拟转接头，非带 DAC 的数字 dongle）。请你看一眼机器确认——如果有 3.5mm 请纠正我。

## 三、本轮已做（R1 第一半：耳机输出）

根因：声卡上 `RX_MACRO RX0 MUX`、`HPHL/HPHR Switch` 等 **RX 宏控件一个都没有**——因为没有任何 dai-link 把 `lpass_rxmacro` 挂进卡。而 rootfs 里恰好自带 **上游 SM8750-MTP 的 WCD939x UCM**（同 codec 同 sndcard），是权威配方。

改动（已 commit 前，待验证）：
- **DTS**：新增 `wcd-playback-dai-link`（cpu `RX_CODEC_DMA_RX_0`；codec `wcd939x(0)+swr1+lpass_rxmacro`）+ 路由 `IN1_HPHL←HPHL_OUT`、`IN2_HPHR←HPHR_OUT`（照 MTP）
- **tplg**：新增 `RX_CODEC_DMA_RX_0` 播放子图 + `... Audio Mixer MultiMedia1` 路由（18236 B `c6fffdbd…`）
- 已构建 **`out/boot-elden-vk48-ram.img`**（`fc59031d…`，零写盘，含新内核+新 tplg）

## 四、请你上机（RAM 试，零风险）

```bash
cd ~/y700-elden
ssh root@192.168.7.1 'eldroid-bootctl reboot bootloader'
fastboot boot out/boot-elden-vk48-ram.img
# 启动后插上 USB-C 模拟耳机
```
回到 Linux（SSH `192.168.7.1`）后我来跑：查 RX 宏控件是否出现 → `RX_CODEC_DMA_RX_0 Audio Mixer MultiMedia1 on` + HPH 序列 → `aplay hw:0,0` 放音，**你听耳机有没有声**。

**问一句**：你有 USB-C **模拟**耳机/转接头吗？没有的话 R1 没法验证，我就先做 R3 并转 R2/G1 其它缺口。


## Automatic settled outcome - 2026-10-04

进入 **R2：双麦/阵列（AMIC2–5）**。先把「下一项」的可选范围说清，再给静态勘察结果。

## 下一项候选（R1 已记录跳过）

| # | 项 | 能否纯串口检查 | 备注 |
|---|---|---|---|
| R2 | 双麦/阵列 AMIC2–5 | ✅（录各级电平，你敲击机身） | 本次主攻 |
| R3 | 非 PipeWire 裸 ALSA 默认 | ✅ | 低价值收尾 |
| R4 | C6 容器音频 | ❌ | 设备上**未装 Waydroid**，暂不可做 |
| — | BT 音频（G1-7） | 需 BT 耳机 | 有线耳机缺失时的替代，但也要外设 |

## R2 静态勘察（原厂 `mixer_paths_sun_qrd_sku2.xml` 权威麦克风图）

| 用途 | 物理麦 | ADC | DEC | TX SWR | SMIC MUX |
|---|---|---|---|---|---|
| **primary-mic** | **AMIC1** | ADC1 | DEC2 | SWR_MIC4 | MUX2 |
| **secondary-mic** | **AMIC4** | ADC3 | DEC5 | SWR_MIC8 | MUX5 |
| **headset-mic** | **AMIC2** | ADC2 | DEC0 | SWR_MIC5 | MUX0 |
| amic3 | AMIC3 | ADC2 | DEC2 | SWR_MIC5 | MUX2 |

关键点：本机卡上 `ADC2 MUX` 的枚举是 `CH2_AMIC_DISABLE / AMIC1 / AMIC2 / AMIC3 / AMIC4 / AMIC5` —— **5 个模拟麦都能经 ADC2 路由**，所以我能只切 `ADC2 MUX` 就逐路测电平，不必动 DEC/SMIC。

我们当前工作路径 = **ADC2/AMIC1 + TX SWR_INPUT1（即 primary 麦）**；原厂次级麦是 **AMIC4**。要确认本机到底有几颗实体麦、次级在哪，需要一次实测。

## 请你配合（实测 AMIC1–5 电平）

**回复「开始」**，我就跑：
```
切 ADC2 MUX = CH2_AMIC1..5 各录 3 s → 打印 peak/rms
```
**期间（约 15–20 s）请持续用指甲敲击机身顶部/底部、并对着机器说话**，好让各麦都收到声音。

如果你不想做外设/敲击类测试，直接说，我就先做 **R3（裸 ALSA 默认，纯软件）**。


## Automatic settled outcome - 2026-10-04

查清了，问题确实在文档。先给结论。

## 结论

**根因：文档把「RAM 启动」当成单一概念，而实际有两种镜像，副作用完全不同。** `fastboot boot` 既可零写盘、又可带桌面——"要零写盘就必须用 RAM 变体"是错误推论。

| 镜像 | cmdline | 根文件系统 | 桌面/系统服务 | 用途 |
|---|---|---|---|---|
| `out/boot-elden-vkNN.img`（持久变体） | 含 `elden_root=LABEL=linux17` | 挂磁盘根、`switch_root` | ✅ Phosh/PipeWire/bluetoothd/Waydroid 全有 | **功能/服务级测试（零写盘）** |
| `out/boot-elden-vkNN-ram.img`（纯 RAM） | 无 `elden_root` | 停在 initramfs | ❌ 只起 getty、不启桌面 | 内核/DTS/分区级验证、首次 bring-up |

设备 `rootfs/init` 里所有服务都带 `[ "$on_initramfs" = 0 ]` 门（`start-desktop.sh`、`bt-up.sh`、`net-up.sh`…），所以纯 RAM 变体下蓝牙音频这类测试**必然失败，且现象像功能坏了**。

## 错在哪（三处强制约束 + 一处命令示例）

1. `PITFALLS.md` **§0 零号纪律 #3**："…先 RAM 引导验证"——被当作通则，未区分变体。
2. `PITFALLS.md` **#92 纪律**："RAM 验收用 `…-ram.img`"——直接把纯 RAM 指定为验收镜像。
3. `RUNBOOK-BRINGUP.md` **Phase 2**：把"RAM 版"当验收步骤，未标注其无桌面。
4. `INDEX.md` **命令示例**：只列了 `-ram` 保底。

实锤：会话 `01a10440` 音频 bring-up 就是先建了 `vk47-ram` 启动 → 停在 initramfs → 误以为内核/功能故障，切回持久才通；与 BL 解锁记录里"locked 无 RAM 兜底"的焦虑叠加，放大了"必须纯 RAM"的印象。

## 已改（4 文件，未提交）

- `PITFALLS.md`：§0 #3 改写（零写盘用 `fastboot boot`，区分变体）；#92 纪律修正；**新增 #93** 完整记录两种镜像 + 选择规则 + 判断方法；表头更新。
- `RUNBOOK-BRINGUP.md` Phase 2：加警示「本 Phase 纯 RAM 无桌面，功能验收用持久根或持久变体」。
- `INDEX.md`：命令示例补持久变体的零写盘用法。
- `AGENTS.md`：「规则」新增测试环境选择一条；`#1–#88` → `#1–#93`。

`check-doctor`：**FAIL=0 / WARN=1**（唯一 WARN 是 `RESOURCES §4` 会话索引 57≠54，与本次无关，pre-existing）。

要我把这次修正提交吗？另外可顺手把 `-ram` 变体的行为加一行提示（打印"纯 RAM：无桌面"），或改 `build-boot.sh` 让 `-ram` 后缀自动带提示——需要的话一起做。


## Automatic settled outcome - 2026-10-04

已提交。

**`2c765a6`** — `docs: 厘清「RAM 启动」两种镜像，修正测试环境约束`

- 提交内容：`AGENTS.md`、`INDEX.md`、`PITFALLS.md`、`RUNBOOK-BRINGUP.md`（4 文件，+25/−7）。
- `.pi/memory/HINDSIGHT.md` 未纳入——它在会话开始前就已是 dirty（harness 自动追加），非本次改动。

`check-doctor` 仍为 **FAIL=0 / WARN=1**（唯一 WARN 为 `RESOURCES §4` 会话索引 57≠54，pre-existing）。

要不要我顺手做那两项可选改进（`-ram` 变体启动时打印"纯 RAM：无桌面"提示；或 `build-boot.sh` 对 `-ram` 后缀自动加提示）？


## Automatic settled outcome - 2026-10-04

已实测两处的实际定义与配置。结论先行。

## 一、数字结论

**两者完全等价，差别 = 0**——`flashing` 不是 profile，只是 4 行的 `cd` 包装脚本：

```bash
# /home/xuqianhui1001/.local/bin/flashing   (2026-09-30 生成)
cd "/home/xuqianhui1001/y700-elden" || exit 1
exec pi "$@"
```

所以在 `~/y700-elden` 里输 `pi` 和在任何地方输 `flashing`，加载的东西一模一样。**差别只在「你在别处输 `pi`」时才出现**，而且不是 `flashing` 有什么魔力，纯粹是 cwd 决定加载范围。

同类快捷方式还有 `eacndev`、`lob-remake`，形态完全相同。

## 二、cwd 决定加载范围（真正的差别）

| 项目 | cwd = `~/y700-elden`（= `flashing`） | cwd = 家目录 / 别处裸 `pi` |
|---|---|---|
| 项目指令 `<repo>/AGENTS.md` | ✅ | ❌（只有全局 `~/.pi/agent/AGENTS.md`） |
| 项目技能 `.pi/skills/`（`qualcomm-android-flashing`、`qualcomm-edl-flashing`、`gsi-device-adaptation`） | ✅ 与全局技能叠加 | ❌ 只剩全局 `~/.pi/agent/skills/` |
| `.pi/settings.json`（`sessionDir=.pi/sessions`、默认 `deepseek/deepseek-flash`、thinking low、retry 8） | ✅ 覆盖全局 | ❌ 用全局（`ustc_ai/deepseek-flash-2`） |
| `profile_memory` 落盘 | `.pi/memory/`（HINDSIGHT 76 KB 的设备结论） | `~/.pi/agent/memory/`（另一套，标题是 "main agent (default profile)"） |
| 会话存储 | `~/y700-elden/.pi/sessions/` | `~/.pi/agent/sessions/--home-…--/` |
| `pi -c` / `-r` 看到的历史 | 刷机全部会话 | **空的/错的**——这是最容易误判的一条 |
| swarm 任务卡 `.pi/missions/` + `.pi/agents/`（6 角色） | ✅ | ❌ |

（当前会话 `PI_PROVIDER=ustc_ai PI_MODEL=qwen3.8-flash-next-2` 是显式覆盖，不代表默认值。）

## 三、一个反直觉的特例：项目**子目录**里输 `pi`

按 pi 文档（`docs/configuration.md`）两类文件解析规则不同：

- **AGENTS.md**：从 cwd **向上找**，所以在 `flashing-bundle/` 里也能读到 → 看起来"项目生效了"。
- **`.pi` 配置**：只认**工作目录下**的 `.pi`，不向上找。

后果：子目录启动 = 有项目说明，但**项目技能不加载、`sessionDir` 不生效（会话落错桶）、默认模型回到全局**。→ 在子目录里也该 `cd ~ && flashing`，或 `flashing -c`。

> **【2026-10-04 更正】**上述 `flashing`/`eacndev`/`lob-remake` 三个包装入口**已删除**；现役写法 = `cd ~/y700-elden && pi`。本节其余（cwd 决定加载范围、子目录特例）仍然成立。见 `archive/2026-10-04-retired-entrypoints/`。

## 四、名字的历史包袱（别被误导）

`flashing` 这名字来自旧机制 **pi-profile-switch** 的 `flashing` profile（`flashing-bundle/README.md` §2 记着）。现已废弃：`~/.pi-profile-switch` **在本机不存在**，改为「按工作目录叠加加载，无需切 profile」（`AGENTS.md` 亦如此写）。两处残留是纯化石：

- `.pi/memory/*.md` 标题 `# … — flashing`
- `f


## Automatic settled outcome - 2026-10-04

**音频收尾（R3）完成并提交** `4aacf40`。

## 做了什么

| 项 | 结果 |
|---|---|
| `scripts/audio-alsa-init.sh` | 新增：幂等地设好播放（`SECONDARY_MI2S_RX`+增益）与采集（AMIC1→ADC2→DEC0→TX3）路由 |
| `/init` 钩子 | RAM 根与持久根都在 `dmesg` 之后后台调用（与 UCM/PipeWire 同值幂等共存） |
| `build-rootfs.sh` | 脚本纳入 RAM 镜像打包清单 |
| 持久根 `/dev/sda17` | 已**离线挂载装入**脚本 + `/init` 钩子（`sh -n` 语法通过），无需刷机 |
| 默认音量 | **400**（可 `ALSA_PLAYBACK_VOLUME` 覆盖）——上次 1023 满值太吵，抱歉 |
| 实测 | U2 **RAM** 环境 `aplay -D default` rc=0 + 扬声器听声 ✅；`arecord` 路径同样设定 |
| 文档 | `TASKS.md` G1-4 记录 R3；`check-doctor` **FAIL=0 / WARN=1**（会话计数 59≠54，pre-existing） |

## 音频剩余（未闭环，均非本轮可解）

- **R1 有线耳麦**：代码就绪（vk48：`wcd-playback-dai-link`+RX 宏控件静态检查✅），**缺 USB-C 模拟耳机硬件**无法听声；另需 `wcd939x-usbss`（i2c TYPEC mux）。
- **R2 双麦**：已实测为 AMIC1+AMIC4 阵列，双路采集价值低，文档记录不做。
- **R4 容器音频**：设备未装 Waydroid，暂不可做。

## 唯一待确认

持久根的改动**尚未经历一次持久启动验证**（我只离线写入+语法校验）。你下次正常重启到持久系统时，`/run/audio-alsa-init.log` 应有一行输出，桌面音频不受影响。

要不要我现在就做 R1 的 UCM `Headphones`/`Headset` 段（照上游 MTP 配方，代码完成待硬件验收），还是转去 G1 其它缺口（相机出流 / TF 卡 / BT 配对）？


## Automatic settled outcome - 2026-10-04

状态核清了，给你**决定路径的判断方法**——先插上试 2 分钟就能分岔。

## 当前设备状态

| 项 | 状态 |
|---|---|
| 运行镜像 | **vk48 RAM**（R1 播放 DTS 已加载：RX 宏控件 29 个 ✅、`HPHL Switch`/`RX_HPH PWR Mode` 在） |
| USB-C 模拟开关 | 本机是 **FSA4480**（`fcs,fsa4480` @ i2c5 0x42/0x43），**不是** `wcd_usbss` |
| FSA4480 驱动 | 内核 `CONFIG_TYPEC_MUX_FSA4480=m`（模块）→ **当前 RAM 启动无 `/lib/modules`，加载不了**；持久根模块版本还停在旧内核 `gba28ec16f01f`，与现用 `gbd114ca33` 不匹配 |

## 关键分岔：插上你的耳机，回我结果

请把耳机/转接头插到**设备上没接线的那个 USB-C 口**（另一个口在跑 USB-NCM 到主机），然后告诉我哪个现象出现：

| 现象 | 类型 | 结论 |
|---|---|---|
| 插上后 `dmesg` 出现 **`new full-speed USB device` / `USB Audio`**；`aplay -l` 多出一个 **USB 声卡** | **数字**（自带 DAC） | 大概率**开箱即用**，我直接帮你切到它出声 |
| 插上后**没有** USB 声卡出现，只有 Type-C/UCSI 事件 | **模拟**（无 DAC） | 需补工作：把 FSA4480 编成 **built-in** + 处理"谁把它切到 AUDIO 模式" |

你插上后回我一句（或直接把 `dmesg | tail` 贴给我），我这边同时查。**先说结论：如果是数字耳机，R1 今天就能听声闭环；如果是模拟，我们要多一步改内核。**

你手上的是哪一种？


## Automatic settled outcome - 2026-10-04

**音频收尾到此为一个干净的停顿点。** 两个提交：

| commit | 内容 |
|---|---|
| `4aacf40` | **R3 裸 ALSA 默认**：`scripts/audio-alsa-init.sh`，无桌面/PipeWire 时 `aplay`/`arecord` 开箱可用；`/init` 在 RAM+持久根调用；默认增益 400；U2 RAM 实测听声 ✅；持久根 `/dev/sda17` 已离线装入 |
| `2d4408d` | **R1 冻结 + 更正**：本机 USB-C 模拟开关是 **FSA4480**（`&i2c5` @0x42/0x43），非之前假设的 `wcd_usbss`/i2c3；驱动 `=m` 且 RAM 无模块、持久根模块旧版本 → 需编 built-in；无耳机硬件，听声验收冻结 |

`check-doctor`：**FAIL=0 / WARN=1**（会话计数 59≠54，pre-existing，与本次无关）。

## 音频总账

- **输出**：扬声器 ✅（G1-4 已闭环，桌面 PipeWire/UCM + 裸 ALSA 双通路）。
- **输入**：内置麦 AMIC1 ✅（UCM `Mic`）。
- **耳机（R1）**：代码就绪，**硬件冻结**。日后拿到 USB-C 耳机后：数字 dongle → 大概率即插即用；模拟耳机 → 先编 `CONFIG_TYPEC_MUX_FSA4480=y`，见 `archive/topics/HEADSET-HW-2026-10-04.md` §6。
- **R2 双麦**：实测 AMIC1+AMIC4 阵列，双路价值低，不做。
- **R4 容器音频**：设备无 Waydroid，不可做。

下一步若继续 G1，剩余缺口是 **相机出流 / TF 卡写稳定 / BT 配对** 三项。要不要挑一个？


## Memory - 2026-10-04

2026-10-04 入口清理（eld/y700-elden）：现役启动入口 = `cd ~/y700-elden && pi`；`~/.local/bin/{flashing,eacndev,lob-remake}` 三个 cd 包装已删除（pi-profile-switch 机制早废，本机无 ~/.pi-profile-switch）。并发子代理 = `Agent` 工具 + `.pi/agents/*.md`（插件 @tintinweb/pi-subagents），**无 harness 守护进程**；旧 `pi-messenger-swarm` 已卸载，其 6 脚本+2 补丁+`.pi/pi-messenger.json`+`.pi/messenger/` 全部移入 `archive/2026-10-04-retired-entrypoints/`（判据 §3、恢复 §4、被移出记忆区的原文附录 §6）。`scripts/check-doctor.sh` 新增第 4 项：这些路径若回到活跃树即 FAIL，机器层快捷入口复辟则 WARN。判据教训：**卸载插件后其脚本会静默失效（node ENOENT）而不报错**，故凡引用 `~/.pi/agent/npm/node_modules/<pkg>/` 的仓库脚本必须纳入 doctor 存在性检查。


## Automatic settled outcome - 2026-10-04

**清理完成并提交 `c5351c3`；`check-doctor` FAIL=0 / WARN=1（唯一 WARN 是清理前就存在的会话索引 54 vs 实有 59）。**

## 一、移除与归档了什么

| 类 | 内容 | 去向 |
|---|---|---|
| **shell 快捷入口 3 个** | `~/.local/bin/{flashing,eacndev,lob-remake}`（同为 4 行 `cd` 包装，pi-profile-switch 时代命名）| 已删除，副本 → `archive/2026-10-04-retired-entrypoints/bin/` |
| **死插件 `pi-messenger-swarm` 资产 10 项** | 6 脚本（`swarm.sh`/`swarm-monitor.sh`/`y700-swarm-reset.sh`/`y700-harness-restart.sh`/`start-y700-harness.sh`/`apply-swarm-patch.sh`）+ 2 补丁 + `.pi/pi-messenger.json` + `.pi/messenger/`(848K) + `logs/swarm-monitor.log` | 脚本/补丁 `git mv` 入归档；运行时目录 tar 留证（96K）；日志删 |
| **不存在的插件经验** | `FAILURES.md` 的 `## Memory - 2026-10-02` swarm 块（600 字符，全是挂在已卸载插件上的修法）| 原文 + 「仍有效的抽象结论」→ 归档 §6 |

判据（写进归档 §3）：`pi list` 无此包 → `node_modules` 无此目录 → 脚本硬编码的 `…/pi-messenger-swarm/dist/harness/server.js` 不存在 = **静默失效而非报错**；`AGENTS.md` 旧引用的 `swarm.py`、`.pi/messenger/agent-card.json` **从未在本机存在过**。

## 二、防止复辟 + 文档收口

- `scripts/check-doctor.sh` 新增**第 4 项**：上述路径若回到活跃树 → **FAIL**；`~/.local/bin/*` 复辟 → **WARN**（13 项全 ok）。
- `AGENTS.md` §其他 明确现役入口 `cd ~/y700-elden && pi` + 并发形态 = `Agent` + `.pi/agents/`（**无守护进程**）；`INDEX.md` §4 加注、§6 补归档行、#91→**#93**。
- `PITFALLS §15.1` +5 行废弃登记、`§15.2` 登记 7 处孤儿目录；`RESOURCES §3` 台账体积/计数刷新；`.pi/README.md` 删 `pi-messenger.json`/`messenger/` 两行、`missions/agents` 改挂 pi-subagents；`.gitignore` 保留规则但注明出处。
- 记忆区：三份标题去掉废弃 profile 名 `flashing` → `elden（y700-elden）`；HINDSIGHT 旧「用 flashing」段加**行内更正指针**（不改写原文）。

## 三、两件需要你知道 / 拍板的事

1. **并发会话抢提交**：我的 8 个 `git mv` + 1 个 `git rm` 被**同时运行的另一个 pi 会话**（R1 耳机取证，`archive/topics/HEADSET-HW-2026-10-04.md`）的提交 `2d4408d` 一起扫走入库——路径变更完整无损，只是提交信息不匹配，已在归档 README 记明原因。教训：**同 worktree 并发会话下禁用 `git commit -a`**（本次我全程显式列路径）。
2. **机器层孤儿目录 12.2 M 待授权清理**（`grep` node_modules 无任何已安装包引用）：`~/.pi/agent/pi-sessions/` 12 M、`~/.pi/


## Automatic settled outcome - 2026-10-04

三个子代理已并行派发（后台运行，完成后会通知我）：

| 子代理 | 缺口 | 绑定 key | 本轮范围 |
|---|---|---|---|
| `camera-vk49` | G1-5 相机出流 | `ustc_ai_2` | 构建**内核+相机模块匹配**的新 boot 镜像、冷启自动加载、精确验收步骤 |
| `tf-card` | G1-6 TF 卡写稳定 | `ustc_ai_3` | 厂商 `uses_level_shifter` 移植分析、候选补丁、A/B 实验设计与压测脚本 |
| `bt-link` | G1-7 BT 链路高延迟 | `ustc_ai_4` | 排除 IBS 后重定位根因、上游修复检索、候选补丁与测试脚本 |

主会话保留 `ustc_ai` key，四 key 均在用（负载均衡）。

**协作约束（已写进各自 prompt）**：只做主机侧、不刷机/不重启/不写设备；不 `git commit`；不改根目录 6 份维护文档（结论各写 `archive/topics/*-2026-10-04-subagent.md`）；共享内核树构建用 `flock /tmp/y700-kbuild.lock` 串行；TF/BT 只产出 `patches/candidate-*.patch` 提案，不直接改 `linux/`。

**设备侧**：U2 现在停在 **fastboot**。等三个代理交回资产后，我会汇总成一份串行的上机验收清单（相机镜像 / TF 压测 / BT 测试），由你逐项执行——符合"用户操作设备"。

我现在不轮询，等它们完成通知。三个都回来后我会独立复核产物（不采信自报成功），再给你收口计划。


## Memory - 2026-10-04

判定 node_modules「孤立依赖」的正确方法（2026-10-04 教训）：不能对 `ls node_modules` 数条目——scoped 包是**作用域目录**（`@aws`/`@babel`/`@google` 本身不是包，展开后可能只剩 1 个子包，卸载后残留空壳会让 `du` 显示 40K–128K）。正确判据 = 用 `package.json` 的直接依赖 + `package-lock.json`(v3 `packages` 字段) 的传递依赖求闭包，与磁盘**展开 scoped 后的包名**比对；`npm prune --dry-run` 只认 lockfile，lockfile 已清则报 "up to date" 而磁盘残留仍在（或反之）。据此本机结论：pi 扩展 node_modules 11 包 = lockfile 闭包 11 包，无需清理。


## Automatic settled outcome - 2026-10-04

三项全部落地，两个提交。

## 数字

| 项 | 结果 |
|---|---|
| `~/.bash_profile` 修正 | `导出 PATH=` → `export PATH=`；登录 shell 不再报错，`~/.dotnet/tools` 已进 PATH；备份 `~/.bash_profile.bak-20261004` |
| `~/.pi` 孤儿目录 | 9 处 → **移动到** `~/.pi/_trash-2026-10-04/`（**13 M**，未硬删） |
| `node_modules` 疑似孤立依赖 | **判定为不需要清**（见下） |
| `check-doctor` | FAIL=0 / WARN=1（唯一 WARN 仍是会话索引 54 vs 实有 59，与本次无关） |
| 提交 | `c5351c3`（清理+归档）、`3812b39`（机器层收尾登记）；工作树干净 |

## 一、孤儿目录（回收目录，可回滚）

`~/.pi/agent/pi-sessions/`(12 M，含已卸载 swarm 的 `messaging/broker.log`) · `~/.pi/wechat/`(1.1 M，含该渠道 `credentials.json`) · `~/.pi/todos/`(11 个) · `agent/pi-agent-profiles/` · `session-control/` · `_wtest` · `agent/{_cron_backup,missions,git}/`。
确认无影响后你自己执行：`rm -rf ~/.pi/_trash-2026-10-04`

⚠️ **回收前看一眼**：`_trash…/agent__cron_backup/crontab.2026-10-04-preclean.bak` 是今早 08:51 另一个会话清空 crontab 前的**唯一备份**（lobcorp-remake 的 swarm 看门狗 `*/10 … swarm_watch.sh`；当前 `crontab -l` 为空）。若 lobcorp 还要它，从该文件恢复。

## 二、一处更正：node_modules 其实没有孤立依赖

我上一条把 `@aws`/`@babel`/`@google` 当包数了——**scoped 目录是作用域，不是包**（`@aws` 已空、`@babel/types` 只是残留空壳）。按正确判据算：`package.json` 7 个直接依赖 + lockfile 传递闭包 = **11 个包**，与磁盘展开后 **11 个完全一致**（`croner`/`nanoid`/`typebox` 都是 `pi-subagents` 的传递依赖）。故未动 `npm/node_modules`。判据已写入持久记忆，避免下次重犯。

`~/.pi/workflows/` 按承诺**保留**（pi-subagents 的 `SubagentWorkflow` 保存位）。

## 三、现役入口（今后只需这一条）

```bash
cd ~/y700-elden && pi        # 并发 = Agent 工具 + .pi/agents/*.md，无 harness 守护进程
```


## Automatic settled outcome - 2026-10-04

## 汇报 — TF 卡写稳定性（主机侧静态分析 + 资产）

**改动文件 7 项，全部未 commit；未刷机/未写设备/未编内核/未改根 6 文档。**
新增：`scripts/tf-stress.sh`、`patches/candidate-tf-{levelshifter,drop-dma-coherent,uhs-1p8,lower-hs-hz,bus-width-1}.patch`、`archive/topics/TF卡-2026-10-04-subagent.md`。（`git status` 里 `HINDSIGHT.md/rootfs/init/camera-*` 是并发会话的，非本轮。）

### 1. 根因判定倾向
**卡本身 ~70–80%**。硬证据：尺寸相关性（64 MB 大块多轮全对 vs 8 MB 小写间歇丢）、`err_stats` 全 0、`e2fsck` 前后一致（坏在卡上）、白牌 `NCard`/date 2010/`OEM 0x0303`、已在最保守 3.3V/SD_HS 档仍坏。**相干性/DMA 错误会按字节随机发生，不会只挑小写** → 强烈指向卡。最终仍须换卡 A/B 定性。

### 2. `qcom,uses_level_shifter` 精确结论（本轮最硬发现）
厂商该属性**唯一功能 = SD_HS 时钟封顶 37.5 MHz**（`sdhci-msm.c` L638-640，`LEVEL_SHIFTER_HIGH_SPEED_FREQ=37500000`）；**不碰 DLL/DDR 寄存器**（DLL config 两边一致 `0x0007442c`/`0x80040868`）。主线靠 `sm8750.dtsi` 的 `max-sd-hs-hz=<37500000>` 达到**完全相同数值**（实机 ios 也确认 37.5 MHz）→ **无效移植，不能作为根因候选**。厂商另有 `qcom,external-fb-clk`（VENDOR_SPEC_FUNC4.EXTERN_FB_CLK，主线缺）但本机 DT 未使用。

### 3. 候选补丁（按代价排序，均已 `git apply --check` 通过）
| 补丁 | 代价 | 区分什么 | 预期 |
|---|---|---|---|
| a levelshifter | 低 | 时钟源一致性 | **无变化**（留档） |
| b drop-dma-coherent | 低 | 一致性声明错误 | PASS→相干性根因 |
| d lower-hs-hz(12.5M) | 低 | 时序/信号余量 | PASS→余量问题 |
| c uhs-1p8 | 中 | 3.3V-HS vs 1.8V-UHS | 预期更差（对照） |
| e bus-width-1 | 低 | DAT1-3 信号完整 | PASS→数据线 |

（只改 DT 的补丁重编 DTB 即可；构建须 `flock /tmp/y700-kbuild.lock`。）

### 4. 用户 A/B 实验步骤
1. 启动 Linux（`fastboot boot out/boot-elden-vk48.img` 或 b 槽），TF 挂到 `/mnt/tf`；
2. `scp scripts/tf-stress.sh root@192.168.7.1:/tmp/ && ssh root@192.168.7.1 'sh /tmp/tf-stress.sh -r 3 --fsck /mnt/tf'` → 记基线；
3. **换已知良好卡**重跑同一步（决定性）；
4. 本卡插安卓/PC 读卡器跑等价写后读回；
5. （建议）全卡写满再读回排除扩容黑片。

### 5. 压测脚本
`scripts/tf-stress.sh` — 幂等/低干扰（只写 `.tf-stress.$pid/` 临时文件、退出自清）、自限（总 `timeout` + 单 dd 超时）、防假阳性（`sync`+`drop_caches` 后回读哈希）、快照 `cid/ios/err_stats`、可选 `--fsck`。
用法：`tf-stress.sh [-r 轮][-n 块][-m Mi


## Automatic settled outcome - 2026-10-04

`tf-card` 完成，我已**独立复核**（未采信自报）：

- 7 个文件都在；`tf-stress.sh` 语法 OK；5 个 `candidate-tf-*.patch` 对 `linux` 树 `git apply --check` **全部 OK**。
- 抽验其最硬结论：主线 `sm8750.dtsi` 确有 `max-sd-hs-hz = <37500000>`，与厂商 `LEVEL_SHIFTER_HIGH_SPEED_FREQ 37500000` **数值相同** → "移植 level-shifter 无效" 的判定成立。
- 根因倾向 **卡本身 70–80%**（小写丢/大块全对、`err_stats` 全 0、`e2fsck` 前后一致、已是最保守 3.3V-HS 档），最终仍需**换卡 A/B** 定性——需要你一张已知良好的 TF 卡。

**提交策略**：先挂起，等 `camera-vk49` 与 `bt-link` 都回来，我统一复核后按主题分批提交（避免并发半成品混进 git）。

`camera-vk49`（要编内核，最慢）与 `bt-link` 仍在跑，我等通知。


## Automatic settled outcome - 2026-10-04

## 汇报（相机 G1-5 主机侧）

### 数字结论
| 产物 | 大小 | sha256（前 8） |
|---|---|---|
| `out/boot-elden-vk49.img`（持久） | 88.1 MiB | `249ee683` |
| `out/boot-elden-vk49-ram.img`（纯 RAM） | 88.1 MiB | `ddeb5735` |
| `out/boot_b-vk49.img`（b 槽签名，pad 96 MiB） | 96 MiB | `1c44343c` |
| `out/camera-modules-7.2.0-debug-g5a70ade46a88.tar.gz` | 8.6 MiB | `7cd5835c` |

- 内核 `uname -r` = **`7.2.0-debug-g5a70ade46a88`**（`#46` 12:31）；模块 **20/20** vermagic 全等，同一次构建。
- 镜像内内核 DTB 含 `s5kjns/gc08a8/gt9764/qcom,sm8750-camss/wl2868c`；ramdisk 第二段含 20 `.ko` + `modules.dep` + 加载器 + `/init` 钩子（逐项列验）。
- 体积 < 96 MiB boot 分区；曾因叠加基座错误涨到 101 MB，已用 `.bak-vk48` 重建修正。

### 证据摘要
- `modinfo -F vermagic` 20 模块 = `…g5a70ade46a88 SMP preempt mod_unload aarch64`。
- 解 boot 镜像内核流：`strings` 得同串 uname；追加段 `cpio -t` 得 20 `.ko` + `/usr/local/sbin/camera-modules-load.sh` + `modules.dep`。
- `sign-boot-b.sh`：公钥 sha1 `fc1e3b33…`，与 `vbmeta_b_flags3.img` 链一致。

### 冷启方案
`rootfs/init` 在 `switch_root` **前**调 `scripts/camera-modules-load.sh`（幂等、`timeout 20`、非致命，日志 `/run/camera-modules.log`）→ 持久与纯 RAM 两变体冷启均自动加载，无需手工 modprobe。新增 `rootfs/build-camera-overlay.sh` 以第二段 cpio 追加（不重建 Alpine）。闭包 17→20（补 `leds-qcom-flash` 链）。

### 用户验收（设备已在 fastboot，零写盘优先）
1. `fastboot boot ~/y700-elden/out/boot-elden-vk49.img`（持久根+相机；`-ram` 为纯 RAM 仅验 probe）。
2. 采证：`cat /run/camera-modules.log`、`dmesg | grep -iE 'camss|csiphy|cci|s5k|gc08|gt9764|wl2868|dependency cycle'`、`ls /dev/video* /dev/media*`、`ls /sys/bus/i2c/devices/`、`media-ctl -p`、`v4l2-ctl --list-devices`。
3. 成功：日志以 `[camera] done: N media` 收尾；i2c 出 `0-0056/1-0031/0-000c`；`/dev/media0` 且 graph 含 sensor↔csiphy/csid/vfe。
4. 失败：`invalid module format`→重建；sensor `-517` 循环→查 LDO1/4/7、MCLK、reset-gpio。
5. 可选刷 b：先验 vk49 再 `fastboot flash boot_b out/boot_b-vk49.img`。

### fwnode 依赖环判断
`camera@56 ↔ isp@ad27000` 的 `Fixe


## Automatic settled outcome - 2026-10-04

相机子代理复核完毕，**关键回归已排除**：

| 复核项 | 结果 |
|---|---|
| vk49 DTB vs vk48 DTB | **逐字节相同**（`461fe072…`）→ 音频/WCD939x/热区 DTS 改动**全部保留**，无回归 |
| 相机模块 vermagic | 20/20 模块 = `7.2.0-debug-g5a70ade46a88`，与内核 `kernelrelease` 一致 |
| vk49 ramdisk | 第二段含 20 `.ko` + `camera-modules-load.sh` + 当前 `init`；`init` 同时含**相机钩子**（switch_root 前）与**我的音频 R3 钩子** |
| 产物 | `out/boot-elden-vk49{,-ram}.img`（88.1 MiB）、`out/boot_b-vk49.img`（96 MiB，b 槽签名）、`camera-modules-…g5a70ade46a88.tar.gz` 均在，sha256 前缀与自报一致（`249ee683` / `ddeb5735` / `1c44343c`） |
| 相机 loader 脚本 | 幂等、`lsmod` 去重、优先用随包 `modules.dep`、按 clk→cci→pmic→camss→sensor 顺序 |

**发现一处小缺口（非回归）**：vk49 的 RAM 基座 `out/rootfs.cpio.gz` 是旧构建，**不含 `audio-alsa-init.sh`** → 纯 RAM 变体下 R3 不生效（持久根 `/init` 已有该脚本，桌面/PipeWire 路径不受影响）。等三个代理收完，我在汇总步骤里用一行 overlay 补上并重打包，不单独动 vk49 哈希。

`bt-link` 仍在跑。等它回来我一并汇总、分批提交，并给出串行上机验收清单。


## Automatic settled outcome - 2026-10-04

## 汇报

**结论先行：既有证据链排除了"主机 IBS 握手"这个方向。** 本轮读代码发现两个关键事实，二者合力把根因指向**控制器侧**：

| # | 新发现的代码事实 | 影响 |
|---|---|---|
| F2 | `IBS_HOST_TX_IDLE_TIMEOUT_MS = 2000`（`hci_qca.c:80`），**不是 100 ms** | archive 里"调大 tx_idle_delay 无效"这个实验接近空操作，没真正测到主机睡眠 |
| F3 | `qca_enqueue()` 每次发包都 `mod_timer(tx_idle_timer, +2000ms)` | `l2ping -i 0.2` 期间主机 TX **全程 AWAKE** ⇒ 主机→控制器 WAKE 握手不在每包路径 |
| F4 | vk25 后无 SLEEP_IND ⇒ 主机 `rx_ibs_state` 恒 AWAKE | 主机 RX 侧握手也不在每包路径 |
| F7/F8 | 运行波特率由 **PERI 协议硬编码 8 Mbps**；`qca_wcn7861_uses_current_baudrate()` 命中时**跳过** `qca_set_speed` | **DT `max-speed` 可能完全不生效**（取决于 helper 返回值） |
| F9 | `qca_port_reopen()` 注释点名"RTS/CTS 同步问题"，但 WCN7861/Peach 路径**从不调用它** | H2 有据 |

**假设排序（每条附判别手段）：**
1. **H4 控制器固件自身深睡**（vk25 只停了 SLEEP_IND 通报，没停睡眠）——首推；零内核改动判别：`KEEPALIVE=1`。
2. **H2 控制器 CTS 反拉致 geni TX 停顿**——判别：关硬件流控补丁。
3. **H1 8 Mbps 时钟余量/误码**——判别：降到 3 Mbps；但 PERI 固件下载在 8M 下成功，削弱此假设。
4. **H3 主机 IBS 握手**——逻辑上已排除（F2/F3/F4），补丁仅作量化收尾。
5. H6 geni RX DMA 水位——低概率。

**候选补丁**（均 `git apply --check` 通过；未改 `linux/`、未 commit）：

| 路径 | 区分 | 风险 |
|---|---|---|
| `patches/candidate-bt-maxspeed-3000k.patch` | H1（PERI 字面量 0x15→0x0e + 实参 + DTS 三处） | 控制器不支持 ⇒ PERI EIO，hci0 不出现，重启回退 |
| `patches/candidate-bt-no-flow-control.patch` | H2 | 突发冲垮控制器 RX |
| `patches/candidate-bt-host-ibs-awake.patch` | H3 残差 | 空闲功耗略增 |
| `patches/candidate-bt-ibs-wait-stats.patch` | H3 量化（`ibs/tx_wait_ms|_cnt`，纯诊断） | 无 |

**测试脚本** `scripts/bt-link-test.sh`（幂等、`timeout` + `trap` 自限、只读、不留后台进程）：
```sh
PEER=AA:BB:... scripts/bt-link-test.sh          # 基线：RTT/loss + ibs_* 差值
PEER=... KEEPALIVE=1 scripts/bt-link-test.sh    # 测 H4（每 50ms 发 Read_Local_Version）
```
判读：`ibs_sent_wakes_delta≈0 && tx_wait_cnt_delta≈0` ⇒ H3 结案；`KEEPALIVE=1` 使 RTT 塌回 <10ms ⇒ H4 成立。脚本同时 dump `dmesg` 的 Product/SoC/ROM ID（判定 F8 helper 是否命中，进而判定 DT 改动是否有效）。

*


## Automatic settled outcome - 2026-10-04

三路全部收口并提交（4 个 commit）。四个 key 全程并行、主会话未互相打爆限流。

```
6ad19ec docs: TASKS G1-5/6/7 记录三路并行子代理结论与上机验收判据
6f38865 bt: 根因重定位 + 4 候选补丁 + 测试脚本（G1-7）
fa7c3f2 tfcard: 换卡 A/B 定性资产 + 5 候选补丁（G1-6）
8c16ea4 camera: vk49 内核+模块匹配基线与冷启自动加载（G1-5 主机侧就绪）
```

## 串行上机验收清单（一次 vk49 会话可做完三项）

设备现在还在 fastboot。**推荐先零写盘 `fastboot boot`**：

**① 相机 probe（G1-5，零写盘）**
```
fastboot boot ~/y700-elden/out/boot-elden-vk49.img      # 持久根 + 相机
ssh root@192.168.7.1
cat /run/camera-modules.log                              # 应见 [camera] loaded ... / done: N media
dmesg | grep -iE 'camss|csiphy|cci|s5k|gc08|gt9764|wl2868'
ls /dev/video* /dev/media*; media-ctl -p; v4l2-ctl --list-devices
```
成功判据：日志以 `[camera] done: N media` 收尾；i2c 出现 `0-0056`/`1-0031`/`0-000c`；`/dev/media0` graph 含 sensor↔csiphy/csid/vfe。

**② BT 根因判别（G1-7，零写盘、零编译，需一个 BT 对端如你的 PC）**
```
PEER=<对端MAC> sh /tmp/bt-link-test.sh          # 基线 RTT/loss + ibs_* 差值
PEER=<对端MAC> KEEPALIVE=1 sh /tmp/bt-link-test.sh   # 测 H4 控制器深睡
```
判读：`KEEPALIVE=1` 使 RTT 从 30–190ms 塌到 <10ms ⇒ **H4 成立**（控制器固件深睡），再上 `patches/candidate-bt-*` 编译。

**③ TF 卡 A/B（G1-6，需一张已知良好 TF 卡 + 本卡读卡器对照）**
```
scp scripts/tf-stress.sh root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'sh /tmp/tf-stress.sh -r 3 --fsck /mnt/tf'   # 本卡基线
# 换已知良好卡，重跑同一条（决定性）
```
新卡连续 ≥3 轮 0 不一致 + `e2fsck -fn` 干净 ⇒ **卡不良，任务闭环=换卡**；新卡也坏 ⇒ 上 `candidate-tf-lower-hs-hz` 等补丁。

## 两处已知小缺口（不阻塞）

- vk49 的**纯 RAM 变体**基座是旧 ramdisk，不含 `audio-alsa-init.sh` → R3 在纯 RAM 下不生效（**持久根 `/dev/sda17` 已有，桌面不受影响**）；下次内核重建时补齐。
- `patches/candidate-*.patch` 均为**提案**（已标 DO NOT COMMIT ON HARDWARE），未入树；按验收结果再决定应用哪个。

你要我先做哪一步？我可以把 ①②③ 合成一个一键上机脚本，或直接陪你逐条执行。


## Automatic settled outcome - 2026-10-04

**根因已修 + 重打包完成**。设备现在跑在 vk47a（b 槽，之前重启回落的），要验新 vk49 需重新 boot。

## 复验步骤（零写盘）

```
# 设备 Linux 里：
reboot bootloader                      # G1-24 已打通；或主机 adb reboot bootloader
# 主机：
fastboot boot ~/y700-elden/out/boot-elden-vk49.img
```

起来后采证（**日志现在进 dmesg 了**）：
```
ssh root@192.168.7.1 'dmesg | grep "\[camera\]"; echo ---; lsmod | grep -E "qcom_camss|videodev|s5kjns"; echo ---; ls /dev/media* /dev/video*; media-ctl -p'
```

**成功判据**：dmesg 出现 `[camera] loaded qcom-camss` 直到 `[camera] done: N media, M video nodes`；`lsmod` 有 `qcom_camss`/`videodev`；出现 `/dev/media0`，`media-ctl -p` 的 graph 含 sensor↔csiphy/csid/vfe。

## 本轮修的到底是什么

| 项 | 内容 |
|---|---|
| 根因 | 设备用 **kmod 34.2**，`modules.dep` 依赖必须是**完整相对路径 + `modules.dep.bin`**；bundle 里由 `modinfo -F depends` 生成的**裸名**格式 → `modprobe qcom-camss` 解析依赖失败（无依赖的 4 个模块却正常，所以恰好卡在 `qcom-camss`） |
| 修复 | `camera-modules-load.sh` 改为**无条件 `depmod -a`**；`package-camera-modules.sh` 改用 `depmod` 生成索引 |
| 可诊断性 | loader 日志改写 `/dev/kmsg`（持久启动会重新 mount `/run` 盖掉文件） |
| 最终产物 | vk49=`53d22cee83`、vk49-ram=`ee432c4b00`、boot_b=`87a1f8f2ab`（内核未变 g5a70ade46a88） |

提交：`acf16c3` + `a2d7ebc`（连同之前的 `6ad19ec`/`6f38865`/`fa7c3f2`/`8c16ea4`）。

相机 probe 一旦过了，同一次会话就能接着跑 **BT 的 KEEPALIVE A/B**；TF 还差你一张已知良好的卡。你先 boot 试一下？


## Automatic settled outcome - 2026-10-04

审查完成。已落盘。

**数字结论**（只审未改）：本地 `geekidos-linux` 相对主线 v7.2 的完整增量 = **125 个改动文件 + 11 个新增驱动/DTS 文件**（≈12.4k 行）。机械检查全绿：

| 检查 | 结果 |
|---|---|
| 9 个新驱动 `checkpatch --strict` | **0 error / 0 warning** |
| elden 系列 9 补丁 | 唯一 ERROR = 全缺 `Signed-off-by`（其余 17 warning 多为转载描述超列） |
| bindings（改 19 + 新 6）`dt-doc-validate` | **全过**，仅缺 `giantec,gt9764` |
| 板 DTS `dtc` + `dt-validate` | 0 warning；**仅 1 红点** `usb@a600000`（vendor-only dwc3 属性） |

**可上游性分级**（A 直发 / B 需重构 / C 外部阻塞 / D 永不上游）：
- **约 60% 是主线本就缺的硬件支持**（板 DTS、camss 新代、ath12k PEACH/WCN7861、panel、新 codec/regulator）——方向对，可分批立项。
- **~25% 需先重构结构**：`psci.c` vendor 钩子→reboot-mode DT；音频 `audioreach.c` 全局 `apm_src_port` 变量（上游必 NAK）；DSI 散落的 `of_device_is_compatible`。
- **~15% 永远不进上游**：调试打印、`force_hz`/`btqca IBS`/`MHI 90s→3s`、config 片段、`dm-default-key`(Android vendor ABI)。

**流程性缺口**（比代码更要命）：① 9 个 commit 全中文、0 个 SoB；② 浅克隆历史只有 1 commit，GEEKiDoS 基底不可追溯；③ 是发行版内核，上游化须另起干净树重放，不在本树做。

**落盘**：
- `archive/topics/UPSTREAM-REVIEW-2026-10-04.md`（完整 A/B/C/D 分类表 + 复现命令 + sha256）
- `TASKS.md §7` M1–M5 任务 + `INDEX.md`/`AGENTS.md` 交叉引用
- 建议推进顺序：M1 干净树 → **M2 首发小系列 A1(GC块)+A2(battmgr)+A3(aw86927)**（各 1 补丁、独立可测、建立与 ML 联系）→ M3 板支持 → M4 camss/wifi/bt 大件 → M5 剥离 dm-default-key。

未做任何重构。下一步若你要动，最省力是先把 A1–A3 三个小补丁整编成英文带 SoB 的系列——要我现在起草 M2 吗？


## Automatic settled outcome - 2026-10-04

**G1-5 相机：probe 里程碑达成** ✅（`9eb77c8`）。设备现在正跑 vk49 持久系统，是同一会话把 BT / TF 也做掉的好窗口。

## 建议现在就做的两项（同一 vk49 会话）

**① BT 基线判别（零写盘，需一个已配对的对端）**
```
scp ~/y700-elden/scripts/bt-link-test.sh root@192.168.7.1:/tmp/
# 先配对（如你的 PC 8C:C6:81:EA:E1:69），拿到对端 MAC 后：
ssh root@192.168.7.1 'PEER=<对端MAC> sh /tmp/bt-link-test.sh'            # 基线
ssh root@192.168.7.1 'PEER=<对端MAC> KEEPALIVE=1 sh /tmp/bt-link-test.sh' # H4 判别
```
判读：`KEEPALIVE=1` 让 RTT 从 30–190ms 塌到 <10ms ⇒ H4（控制器固件深睡）成立。

**② TF 压测基线（当前卡，随后换卡 A/B）**
```
scp ~/y700-elden/scripts/tf-stress.sh root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'mount /dev/mmcblk0p1 /mnt/tf 2>/dev/null; sh /tmp/tf-stress.sh -r 3 --fsck /mnt/tf'
```

> ⚠️ 记得这个持久系统有「空闲熄屏→重启」未解 bug——测完别让它闲太久，或手动保持唤醒。

## 相机"实际出流"要不要现在就上？

`v4l2-ctl --stream-mmap` 的 `-EPIPE` 是 csiphy 默认格式（`UYVY8_1X16`）与 sensor 实际输出（`SRGGB10`）不匹配所致，需要手工 `media-ctl` 配全链路 mbus format/selection 再 STREAMON。这可以：
- 派一个**专注子代理**（挂 `ustc_ai_2`）在你上机期间迭代调 pipeline，或
- 留到下一轮。

你想先跑 ① 还是 ②？相机出流我可以同时起一个子代理。


## Automatic settled outcome - 2026-10-04

能，而且项目里已经验证过半条路线（相机 20 个 `.ko` 热加载）。先给结论，再分层说清哪些改动本来就**不需要**重编内核。

## 数字结论

| 改动类型 | 现在每次的代价 | 目标代价 | 手段 |
|---|---|---|---|
| 驱动代码（音频/相机/触摸/BT/WiFi/panel/马达…） | 全量内核 + 重签 + 刷机 ≈ 20–40 min | **scp + modprobe ≈ 30 s** | 编成 `=m`，`.ko` 运行时加载 |
| DTS | 同上（其实内核从未重编） | **≈ 2 min** | `make dtbs`(秒级) → `mkbootimg --dtb` → `fastboot boot`（零写盘） |
| DT 微扰（使能节点/改一个属性） | 同上 | **0 重启** | configfs overlay（本机 `CONFIG_OF_OVERLAY=y` 已开） |
| 换内核核心（psci/clk/dwc3/audioreach 头） | 全量 | 全量（不可省） | 但可用 **kexec** 省掉 fastboot 往返 |

关键事实（都已在本地核实）：
- `build-boot.sh` 里 **DTB 本来就是 boot.img 的独立分区**（`mkbootimg --dtb`）——改 DTS 时 `Image.gz` 逐字节不变，重编内核纯属浪费。
- `CONFIG_KEXEC_FILE=y` 且 `KEXEC_SIG` 未开 → **从运行中的系统直接 kexec 新内核+新 dtb**，完全绕过 fastboot/ABL/AVB，一条 SSH 命令完成换内核。
- 相机模块路线已跑通并踩过全部坑（kmod 34.2 要 `depmod` 生成 `modules.dep.bin`、loader 按 clk→cci→camss→sensor 顺序）。

## 建议的三层开发环（由快到慢）

**第 1 环 · 模块环（最常用）**——把当前 `=y` 的 payload 翻成 `=m`：
- 现在编译进内核的：`SND_SOC_SC8280XP`、`WCD939X`、`AW88461`、`BT_QCA`、`ATH12K`、`DRM_MSM`、`PANEL_NT36536`、`AW86927`、`NVT36XXX`（camss/wl2868c/cci 已是 `m`）。
- 必须保持 `=y` 的只有**启动路径**：`USB_DWC3`/`CONFIGFS`（rootfs 靠 USB 网络）、UFS、串口、clk/pinctrl/GCC、PSI 核心。
- 做法：加一个 `arch/arm64/configs/elden-dev.config` 片段（就是现有 fragment 机制），把上面列表 y→m；`scripts/package-camera-modules.sh` 泛化成通用 `package-modules.sh`（打包 + `depmod` + scp + 按序加载），音频/gpr 总线有依赖序，但 `modules.dep` + deferred probe 能兜住。
- **纪律**：模块环期间 boot 里的内核固定不动（如 vk49），否则 vermagic 失配——这正好也防住「改动越界到核心文件却不自知」。

**第 2 环 · DT 环**：`make dtbs`（秒级）→ `mkbootimg` → `sign` → `fastboot boot`。可以做成 `iterate.sh --dtb-only`：检测 `Image.gz` 哈希没变就跳过内核构建。另外 `CONFIG_OF_OVERLAY=y` 意味着小改动可以直接 `/sys/kernel/config/device-tree/overlays/` 打补丁试，满意了再回写 DTS。

**第 3 环 · 内核环（不可避免时）**：boot_b 放一个稳定基座，新内核编好后 `kexec --load --dtb=... && kexec` 起来验证，省掉 fastboot 往返与 ABL 校验；**验证通过才** 走正式签刷。注意 kexec 不重走 A


## Automatic settled outcome - 2026-10-04

**诊断闭环（记录在 `8d9f888`）**——iQOO TWS 2 的问题复现并收窄了：

## 实测数字（vk47a，零写盘）

| 实验 | RTT min/avg/max/mdev | loss | 主机唤醒 | 控制器唤醒 |
|---|---|---|---|---|
| 基线（-c15 -i0.2） | 7.8/**44.4**/110.8/26.8 ms | 0% | `ibs_sent_wakes`=**1** | `ibs_recv_wakes`=20 |
| `KEEPALIVE=1` | 3.9/**35.3**/62.4/15.6 ms | 0% | **1**（不变） | 293 |
| 突发 `-c100 -i0.05` | **20s 内跑不完**（应 ~5s） | — | — | — |
| `hciconfig` errors | RX/TX 均 **0** | — | — | — |

## 结论（推翻了原来的首选假设）

- **H4「控制器固件深睡」不成立**：KEEPALIVE 只把 avg 44→35ms，没塌到 <10ms。
- **H3「主机 IBS 握手」排除**：`ibs_sent_wakes_delta=1` 两种情形一样（主机 TX 全程 awake）。
- 突发直接停摆、且 `errors=0` → **丢在空口/控制器侧**。
- 剩 **H1（8 Mbps 误码）/ H2（控制器 CTS 反拉）**——两者都改不了运行期，**需单变量测试内核**：
  - `patches/candidate-bt-maxspeed-3000k.patch`（H1）
  - `patches/candidate-bt-no-flow-control.patch`（H2）

顺带修了测试脚本 4 个 bug（IBS 路径、RTT 自算、errors 解析、counter 名）。

## 下一步

建议构建 **vk50 = vk49 内核 + `candidate-bt-maxspeed-3000k`**（单变量先测 H1，风险=控制器不支持 3Mbps 则 hci0 不出现，重启回退），`fastboot boot` 后用同一脚本复测 RTT/突发。

要我**现在构建 vk50**（主机侧，~10min）并给你精确 boot 命令吗？还是先派子代理并行把 H1/H2 两个测试内核都备好？


## Automatic settled outcome - 2026-10-04

审计完成，写入 `archive/topics/ITERATION-AUDIT-2026-10-04.md`。核心数字与结论：

## 一句话
**最高杠杆 = 把 payload 驱动 `y→m`（一次性全量重编），此后驱动改动进入 scp+modprobe ≈30s 环；第二杠杆 = 接入 ccache（现在装了但缓存为 0）。**

## 版本控制（🔴 高）
- 顶层仓 **58 commit，无 remote**（无异地备份）；无 tag，vk↔sha 只存在 commit message 里。
- 内核仓 **浅克隆**（`.git/shallow`，grafted 于 `ba28ec16f`）→ 无法向上 bisect，GEEKiDoS 基底不可追溯。
- **vk34–v39、vk43、vk49 无 commit**；提交只覆盖 vk40–v48（分支名 `elden/vk42-audio-thermal` 却含 vk42–48，名实不符）。
- **构建不可复现**：`build-boot.sh` 默认 ramdisk 候选**不含** `rootfs-overlaid-camera.cpio.gz`，vk49 的打包命令已丢失 → 无法用默认命令重建。`mkbootimg` 未设 `SOURCE_DATE_EPOCH`。
- `patches/elden-working-tree-*.patch` 已过期，与 git 形成**双真源**。

## 迭代流程（🔴 高）
- 驱动几乎全 `=y`：SC8280XP/WCD939X/QDSP6、BT_QCA、ATH12K、DRM_MSM、panel、AW86927、NVT36XXX、QCOM_Q6V5_PAS。
- ccache 已装但 **0.0 GiB**，`build-kernel.sh` 的 `CROSS_COMPILE` 未包 ccache → 纯冷编译。
- 模块热加载**已半通**：`package-camera-modules.sh`(depmod 修好的) + `deploy-camera-modules.sh`(**不刷机不重启**) + `camera-modules-load.sh` —— 通用化即得快环。

## Linux→fastboot（🟢 基本就绪）
- `eldroid-bootctl reboot bootloader`（PSCI 钩子 vk41）已通；`flash-b.sh` 可在 Linux 内 dd 写 b 槽。
- **缺口**：文档多处引用 `scripts/cycle.sh`，该文件**不存在**（死引用）。

## kexec（🟡 只差脚本+首测）
前置条件**全部满足**：`KEXEC_FILE=y` + `KEXEC_SIG` 关；arm64 加载器只认**未压缩 `Image`**（已有 62MB）；kexec-tools **设备上已装**（持久根 + Alpine rootfs 都有）。
> 注意：`Image.gz` 不能用于 kexec；`CONFIG_KEXEC` 旧 syscall 未置 → 须走 `kexec_file_load`（`-s`）。

## 建议顺序
**V1–V3 + I1**（加 remote/tag/manifest + ccache，零风险立竿见影）→ **I2→I3**（模块快环）→ **K1/I4**（kexec/DTB-only 并行验证）→ **F1/C1**（to-fastboot + 设备锁）。

要不要我现在就开始落地 **V1（加 remote+tag+补 vk43/vk49 commit）** 和 **I1（ccache）**？这两项零风险。remote 需要你给一个（GitHub/GitLab/校内），或我先只做本地 tag + manifest。


## Automatic settled outcome - 2026-10-04

# vk14–vk34 逐版本时间线（2026-09-30 ~ 10-01）

只读研究结论。构建时间取自 `out/boot-elden-vk*.img` mtime；sha256 为**当前 out/ 原始镜像**哈希（session 里另存的 boot_b 签名镜像哈希不同）。构建/打包命令除注明外统一为：`./build.sh` → `./pack.sh out/rootfs-vk11.cpio.gz out/boot-elden-vkN.img` → `scripts/sign-boot-b.sh` → `scripts/flash-b.sh ... --reboot`。hk14–19 rootfs 固定 `rootfs-vk11.cpio.gz`（62,842,080 B）。全程 uname 恒为 `7.2.0-debug-gba28ec16f01f-dirty`（无 per-version localversion，见 RESOURCES §4.3）。

## 1. 版本表

| vk | 时间(09-30起) | 相对上一版的内核/DT/config 改动 | 编/打包/上机命令 | 真机结果 | 证据文件 |
|---|---|---|---|---|---|
| **vk14** | 09-30 19:08 | `sm8750_dspp_sblk` catalog 补 `.gc = {.base=0x17c0,.len=0x40,.version=0x10008}`（DSPP GAMMA_LUT）。**补丁 0002**。config 基线=去 suspend/hibernate/kexec 的 vk13 树 | `./build.sh`（5m20 全量）→ `./pack.sh`（77 MiB, sha 9c32c9a9…）→ flash-b | ✅ Night Light 面板出现、可调、按钮可用 → 内核 gamma 链路打通。踩坑：裸 `make` 覆坏 `linux/.config`，用设备 `zcat /proc/config.gz` 拉回修复（PITFALLS 9b） | ROADMAP-dep §3/§4；PITFALLS #9b；patches/0002；session 01a0f1ee |
| **vk15** | 19:16 | `aw86927.c` SRAM 上界修复（固件超 4KB 被写死窗口拒；按型号区分 SRAM 窗口）。补丁初版名 `0003-…-sram-window.patch` | build→pack（77 MiB, sha 741fa5a3…）→flash-b | ✅ probe 无报错，但 **不震**（回退 vk14） | session 01a0f1ee；STOCK-KERNEL §4 |
| **vk16** | 19:28 | `aw86927_haptics_play_work` 加临时 `dev_info` debug 打印 | build→pack（77 MiB, sha fae1568c…）→flash-b | 播放路径执行、寄存器可见，**仍不震** | session 01a0f1ee |
| **vk17** | 19:32 | 加深寄存器级 debug（play 路径逐寄存器） | build→pack（77 MiB, sha 11809365…）→flash-b | 播放命令确实执行，马达不动；保留 debug 版继续观察 | session 01a0f1ee |
| **vk18** | 19:47 | 移植厂商 `haptic.ko` 反汇编出的 **AW86937 CONT 连续模式**序列（PLAYCFG3[1:0]=2、VBATCTRL bit6、CONTCFG 等） | build→pack（77 MiB, sha 600b4c72…）→flash-b | ✅ 用户确认**马达震动**（FF path 执行） | STOCK-KERNEL §5；session 01a0f1ee |
| **vk19** | 19:54 | 去 debug 打印，出**干净基线**；补丁定稿 `0003-aw86927-aw86937-haptics


## Automatic settled outcome - 2026-10-04

# vk1–vk13 逐版本时间线（09-28 ~ 09-29）

> 重要前提：**vk1–vk13 全部共用内核字符串 `7.2.0-debug-gba28ec16f01f-dirty`**（localversion 未改），设备上无法自报区分；版本只能靠镜像文件名+打包时间追溯（`RESOURCES.md §3`）。下面时间＝`out/` 文件 mtime（主机 CST）。
> 证据缩写：`928/复盘`=`/tmp/hist928/复盘.md`；`928/SESSION`=`/tmp/hist928/SESSION-2026-09-28.md`；`928/HANDOFF`=`/tmp/hist928/HANDOFF.md`；`929/HANDOFF`=`/tmp/hist929/HANDOFF.md`；`929/INDEX`=`/tmp/hist929/INDEX.md`；`929夜`=`archive/topics/复盘-2026-09-29-夜.md`；`S1`=`.pi/agent/sessions/2026-09-28T11-23-20…jsonl`；`S2`=`.pi/agent/sessions/2026-09-28T14-40-54…jsonl`；`S3`=`.pi/agent/sessions/2026-09-29T05-38-12…jsonl`。

## A. 09-28 白天：从零到显示/USB（命名镜像）

| 版本 | 时间 | 内核/DT/init 改动（自上一版） | 编/打包 | 真机结果 | 证据 |
|---|---|---|---|---|---|
| base1 | 20:05 | 首次用作者 build-boot.sh：内核+最小 busybox initramfs；`--base 0x10000000` | `scripts/build-boot.sh` → `out/boot-elden-base1.img` | ABL/地址实验用，未进 userspace | 928/HANDOFF §4.3；S1 12:05–12:21 |
| diag–diag6 | 20:27–21:03 | 诊断 initramfs 加 `elden_diag_reboot=1`（跑完 40s 自 `reboot -f`）；diag 起 `-d DRM_MSM` | `scripts/build-boot.sh` 覆写 initramfs | **全部废配置**：改 config 后跑 `olddefconfig` 连带删掉 `CONFIG_ARCH_QCOM` → 无 QCOM 平台支持，显示/USB/UFS 全灭 | 928/复盘 §六–七；928/HANDOFF §5 坑1 |
| fixed | 21:09 | 恢复 `.config.panel`（ARCH_QCOM=y）；DTS 节点 `splash-region`→`splash_region`；`CONFIG_PHY_NXP_PTN3222=y`；`CONFIG_BACKLIGHT_AW99706=y` | 同上 | 待验 | 928/复盘 §七 |
| fixed2 | 21:19 | fixed 迭代（config/DT 微调） | 同上 | 同上 | 928/复盘 §八 |
| fixed3 | 21:35 | fixed2 收敛；`boot-elden.img` 为同刻 build-boot.sh 输出 | 同上 | ✅ **首次决定性成功**：Linux 7.2.0 进 userspace；`/dev/ttyACM0` 串口 shell（`[usb-gadget] bound to a600000.usb`）；UFS `sda1..sda15`；背光 probe 成功 | 928/复盘 §八；S1 13:xx |
| fixed4 | 21:46 | **`&mdss_dp0 { status="disabled" }`**（DP 是永远 defer 的 DRM component，卡死 `msm_drm_bind`→无 card0） | 同上 | ✅ **显示打通**：logo→闪→Linux 终端页 | 928/复盘 §八；9


## Automatic settled outcome - 2026-10-04

已完成。git 历史从 58 个提交补到 **107 个**，`vk1`–`vk40` 每个版本都有对应提交与标签。

## 结果

| 项 | 值 |
|---|---|
| 新分支 | `history/pre-vk34`（49 个提交，根 = `base1` 2026-09-28） |
| 新标签 | 49 个：`base1 diag fixed3 fixed4 alpine gpu3 vk1…vk40 vk36debug vk38 vk38debug vk40-ram` |
| 嫁接 | `git replace --graft e3ec468 <回填末提交>` → `git log HEAD` 连续显示 107 个提交 |
| 嫁接处一致性 | 回填末提交树与 `e3ec468` 树**逐字节相同**（`git diff e3ec468 history/pre-vk34` 为空） |
| 既有提交 | **未改动**，`e3ec468` 及之后所有 sha 保持原样（文档里的引用不失效） |

## 怎么做的

- 用 `out/boot-elden-*.img` 的 **mtime** 排出 49 个版本边界，逐个用纯 plumbing（临时索引 + `commit-tree`）生成提交，工作树/索引零改动。
- 文件集与内容取自 **`e3ec468` 的树**（git 纳管时的 293 文件快照）；每个文件归属最早的「epoch ≥ mtime」的版本。
- 对 11 个补丁 + 6 个 config 做了**显式归属**（如 `patches/0001-ath12k-*.patch` → `vk9`、`0009` → `vk34`），修正 mtime 相邻导致的 ±1 版本漂移。
- 10-02~10-03 纳管前的收尾并入一个桥接提交。

## 局限（已写进 README）

1. mtime 只记「最后一次修改」——同一文件被多版反复改，只能落在最后时刻那个提交，**早期中间态无法还原**；因此有若干**空提交**（只承载版本叙事/标签），这是诚实的「该版本无文件存留到此形态」。
2. 内核源码树与 `out/` 编译产物不在 git 内，回填只覆盖被跟踪的项目文件。

## 落盘

- refs：`refs/heads/history/pre-vk34`、49 个 tag、`refs/replace/e3ec468`（本地引用，clone 不携带，README 给了重挂命令）。
- `archive/2026-10-04-git-backfill/`：`README.md`（方法/局限/复现/撤销）、`plan.tsv`、`gen_plan.py`、`bf_build.sh`、`bf_manifest_all.txt`、`VERSION-MAP.txt`。

查看：`git log --oneline history/pre-vk34`、`git show vk9`。撤销嫁接：`git replace -d e3ec468`。

该目录目前是 untracked；要我把它作为一个提交纳入 main 吗？


## Memory - 2026-10-04

学校 GitLab = git.ustc.edu.cn（SSH Host 别名已配；账号 @xqh；key ~/.ssh/id_ed25519_gitlab_ustc）。个人命名空间支持 push-to-create：直接 `git push git@git.ustc.edu.cn:xqh/<repo>.git main` 即自动建私有项目（无需网页/API token），SSH 测试 `ssh -T git@git.ustc.edu.cn` 返回 Welcome, @xqh。限制：GitLab 服务器拒绝 shallow push（"shallow update not allowed"）——浅克隆仓需先 `git fetch --unshallow`，或改用「合成根」（`git commit-tree <base>^{tree}` 造无父提交 + cherry-pick 增量）推非 shallow 镜像，或改用 format-patch 补丁集留档。


## Automatic settled outcome - 2026-10-04

全部落地。总结如下：

## 已完成（无需设备，均已推送异地）

**V — 版本控制与异地备份** 🔴→🟢
- 顶层仓 `origin` → **https://git.ustc.edu.cn/xqh/y700-elden**（2 分支 + 全部标签，SSH push-to-create 自动建仓）
- 内核仓 `gitlab` → **https://git.ustc.edu.cn/xqh/y700-elden-kernel**（分支 `main`）
  - 浅克隆被 GitLab 拒绝直推 → 用**合成根**（根提交树=上游 `ba28ec16f` 树 + 9 个 elden 增量重放），非 shallow、可正常 clone
- 另有保险：`patches/kernel-history/` — 6 支 elden 分支的 `format-patch` 增量（脱离 git 也能 `git am` 复原）
- `archive/2026-10-04-git-backfill/VERSION-MAP.txt`：原 sha → 镜像 sha 映射 + 复原步骤
- `scripts/build-manifest.sh`：每个 vk 产出 {内核/DTB/config/ramdisk sha、cmdline、mkbootimg argv、镜像 sha256} → 构建可复现可审计

**I — 迭代快环** 🔴→🟢
- `scripts/env-build.sh`：ccache 接入 `CROSS_COMPILE`（此前装了但缓存 0）
- `patches/fragment-modular.config`：音频/ATH12K/触觉/触屏/背光 `y→m`（实测 merge_config+olddefconfig 可翻，模块数 1319→1355）；`fragment-modular-video.config` 可选（DRM/panel，牺牲启动早期显示）
- `scripts/mod-loop.sh` + `iterate.sh mod <dir>`：改驱动 → 编单模块 → scp → rmmod/modprobe，**~30s 不重启**
- `scripts/iterate.sh dtb`：改 DTS 只重编 DTB

**K / F — 去物理重启**
- `scripts/kexec-boot.sh`：用未压缩 `Image` + `--dtb` 走 `kexec_file_load` 热重载（`KEXEC_FILE=y`、kexec-tools 设备已装）
- `scripts/to-fastboot.sh`：`--boot` 零写盘 fastboot / `--flash` Linux 内 dd 进 boot_b 再重启；补上 PSCI vendor reset 进 fastboot

**C — 并发**
- `scripts/device-lock.sh` + 三个设备脚本自锁（flock，防嵌套死锁）：并行子代理串行化单台设备访问

`check-doctor`：FAIL=0。

> 更正一条审计原话：`cycle.sh` **确实存在**（在仓库根，非 `scripts/`），已同步修正。

## 需要你/设备的下一步（一次性）

1. **切换模块化**：跑一次全量构建应用 fragment
   ```
   scripts/apply-kernel-fragment.sh patches/fragment-modular.config   # 一次性
   scripts/iterate.sh kernel --boot VERSION=vk50        # fastboot 零写盘验证
   ```
   之后驱动改动就进 `iterate.sh mod ...` 的 30s 环。
2. **首次 kexec 实测**（用已知good的 vk49/vk50 镜像先验证不崩外设）：
   ```
   scripts/iterate.sh kernel --kexec VERSION=vk51
   ```
3. 若要我把内核仓也做成完整非浅历史（需 `git fetch --unshall


## Automatic settled outcome - 2026-10-04

## 复核结论（先数字）

| 维度 | 判定 | 关键数字 |
|---|---|---|
| 1 可记录可溯源 | 🟡 骨架好，**2 个闭环漏洞** | doctor FAIL=0/WARN=1；git 纳管 391 文件、双仓双远程、回填 107 提交+49 tag；**manifest 生成数=0 且被 .gitignore 吞** |
| 2 规划/并发/子代理 | 🔴 **子代理定义整体过期** | 6 角色+11 任务书 **100% 仍引用已退役 swarm**（`send SageYak`/`task done`/SWARM-PLAN 旧路径）；设备锁覆盖 **3/5**（flash-b.sh、cycle.sh 无锁） |
| 3 迭代/忙等 | 🟡 工具全在，**快环未接通** | ccache 缓存 **8 KB（从未命中）**；`WCD939X=y` 未模块化 ⇒ 音频进不了 30s 环；kexec 实测 **0 次**；轮询已全部有界 ✅ |

---

## 维度 1：可记录可溯源

**做得对**：6 文档分层 + SSOT 声明、archive 只增不改、git 回填+graft+VERSION-MAP、双异地备份、`check-doctor` 守门、.gitignore 边界有注释台账。

**漏洞**：
1. **manifest 闭环断裂**：`scripts/build-manifest.sh:9` 自己写着 "Commit the manifests"，但产物写到 `out/`，而 `.gitignore:18` 整目录忽略 `/out/`，且无 `!/out/*.manifest` 例外 → **每版可复现指纹永远进不了 git**。vk49 及之前的版本也还没有 manifest（生成数=0）。
2. **入口目录混散件**：根目录有 `sn.img`（BL 解锁证据，UNTRACKED）、`dtc-*.whl`、5 个 `y700-elden-docs-*.tar.gz`——与"根目录只有 6 文档+AGENTS"纪律冲突，且都不在 git 里。
3. 小项：RESOURCES §4 收录 54 ≠ 实际 68 会话（doctor 已 WARN）；`.pi/memory/HINDSIGHT.md` 有 +51 行未提交。

## 维度 2：规划任务 / 并发 / 冲突合并 / 子代理

**做得对**：TASKS 唯一台账+§2.1 主机侧并行清单、`device-lock.sh` flock 语义正确（自锁可嵌套、`DEVICE_LOCK_HELD` 透传）、AUDIT3 教训（副作用与轮询不同条命令）已写进任务书、retry 参数已按限流调好、默认模型已切 deepseek。

**漏洞（按危害排序）**：
1. **子代理不可用级过期**：`.pi/agents/*.md` 6 个角色与 `.pi/missions/*.md` 11 个任务书全部是 swarm 时代原文——`send SageYak`、`task done task-12`、"先读 `AUDIO-2026-10-01.md`"（实际在 `archive/topics/`）、`SWARM-PLAN-2026-10-02.md`（同）。`smoke.md` 还绑在已不存在的 task-12。**现在派生这些 Agent 类型，子代理会先浪费多轮去执行不存在的命令/读不存在的路径**，且任务书里"设备当前 vk34"等状态已落后 13 个版本。
2. **锁旁路**：`mod-loop/kexec-boot/to-fastboot` 自锁，但 `flash-b.sh`（写 boot_b+重启）与 `cycle.sh`（reboot/fastboot）无锁——而 **INDEX §4 快速命令恰恰推荐的就是这两条无锁路径**。并发子代理照 INDEX 行事即可撞车。
3. **规划项过期**：TASKS §4 第 1 步"⛔ 先救机器：U2 不可达"与 INDEX §3"U2=vk47 持久直启在跑"矛盾（§4 未随 10-03 深夜恢复刷新）；INDEX §3 快照 82% vs §0 的 85%（SSOT 已声


## Automatic settled outcome - 2026-10-04

P0+P1（无设备项）全部落地并推送。总结：

## 已完成（3 个提交 → origin/main）

| 项 | 内容 | 验证 |
|---|---|---|
| ① 子代理现代化 | 11 份任务书+5 份角色全部重写：**4 条活跃线**（audio 残余/bench/camera 出流/gplay+el2 收口动作）状态对齐 vk49 并指向 `archive/topics/` 真路径；**7 条已收官线**改为「墓碑+残余」，误派时先报告"已收官"不空转；删 `smoke.md` | `send SageYak`/`task done`/`SWARM-PLAN`/`task-N` **0 残留**；新引用路径**全部存在** |
| ② 锁旁路消除 | `flash-b.sh`/`cycle.sh` 补与 mod-loop 同款自锁；INDEX §4 快速命令从 sign+flash-b 改为 `scripts/iterate.sh` 四档环 + `device-lock.sh --status` | 实测三态：空闲拿锁 ✅、被占 1s 报 busy 退出 ✅、`device-lock.sh` 外层持锁时内层透传不死锁 ✅ |
| ③ manifest 闭环 | `.gitignore` 改 `/out/*` + `!/out/*.manifest` | `check-ignore`：img/子目录仍忽略、`.manifest` 放行 ✅ |
| ④ 双 iterate | 根 `iterate.sh` 改为 `exec scripts/iterate.sh`（带新用法注释） | `bash -n` ✅ |
| 顺手 | 修了一个**复核时新发现的 TASKS 原生死引用**：`build-camera-overlay.sh` 实际在 `rootfs/` 而非 `scripts/`（TASKS G1-5 + 任务书同改） | 存在性核实 ✅ |

`check-doctor` FAIL=0（WARN=1 仍是既知的会话索引 54≠68，属 P2）。

## 剩余（下次上机/收工时顺手）

- **P1⑤ 快环接通**（唯一需设备的一次性动作）：`scripts/apply-kernel-fragment.sh patches/fragment-modular.config` → 全量构建一次（带暖 ccache）→ `iterate.sh kernel --kexec` 首测 → 音频 30s mod 环首测。
- **P2**：RESOURCES §4 补 14 个会话；提交 HINDSIGHT 的 +51 行；TASKS §4 删过期的"⛔ 先救机器"；根目录散件归档（`sn.img`/`dtc-*.whl`/5 个 docs tar.gz）；doctor 加 G1% 口径检查。

上机那轮开始时说一声，我把 P1⑤ 和 G1-22/G1-5 的验证合并进同一次会话计划。
