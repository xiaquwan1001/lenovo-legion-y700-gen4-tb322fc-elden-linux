# 调查：elden GPU 驱动与相机模块后续方向（2026-10-09）

> 范围 = 纯调研，不改领域层文件。四个子项各按 **状态 → 推荐行动 → 参考链接** 组织。
> 领域事实的唯一权威仍是 `TASKS.md` / `PITFALLS.md`；本文件只做「现状归集 + 方向研判」。
> **网络核验受限**：本机 `curl` 访问 `lore.kernel.org`、`gitlab.freedesktop.org` 命中 **Anubis 反爬（JS proof-of-work）**，`marc.info` 连接超时、`patchew.org/search`/`spinics` 返回空壳页。因此「2026-10-08 之后是否有新回复/新 fix」**无法在此无头核验**；下文对上游动态的判断基于仓库内已固化的引用（`research-q24-cambist-2026-10-09.md`）+ 待人工核验清单。

## 摘要（TL;DR）

| # | 子项 | 现状 | 推荐首要行动 | 是否占设备 |
|---|------|------|--------------|-----------|
| 1 | freedreno/Turnip × Adreno 830 (gen8/a8xx) | GPU 工作正常（Mesa 26.1.8）；chip-id 已解；gen8 上游仍在快速演进 | **锁定当前 26.1.x 不动**；开一个低优先跟踪条目盯 Mesa 26.3 turnip gen8（`has_fs_tex_prefetch`/robustness），到点再评估重编 | 否（不占） |
| 2 | libcamera s5kjns IPA 校准 yaml | 出流+App 实测过；后摄过曝/高光压制慢 = **simple IPA 无 s5kjns 校准 yaml** | **先确认当前 IPA 模块**；首选迁到 **`ipa_soft` + 自标定最小 yaml**（黑电平/CCM/AWB/LSC/gain 上限），vendor IQ 转换列为高成本备胎 | 标定占设备，编写不占 |
| 3 | cambistmclkcc-sm8750 上游回复/fix | 上游 DT v4 已 applied（`4a1779f42e21`）无 fix；**我方报告已发（`be79b256d`，2026-10-08）**；规避中（`elden_nocamera=1`） | **人工核验 lore 线程回复**（见 §3 清单）；未得回复前规避保留、不再上机续修 H2 间歇 | 否（核验不占） |
| 4 | GPU 基准 G1-8 前置条件（`scripts/bench-run.sh`） | 脚本就绪、自适应、**确认未执行** | 补齐前置：**设备 apk 网络** + **Phosh Wayland socket 对运行用户可读** + **device-lock/温控纪律**；再 `apk add glmark2 vkmark sysbench` 跑标准一轮 | 是（占设备+发热） |

---

## 1. freedreno / Turnip 对 Adreno 830（gen8 / a8xx）的上游进展

### 状态（本地证据）

- **SoC/GPU 身份**：SM8750(P)，GPU = **Adreno 830**，freedreno 代号 **gen80000（gen8 / a8xx 家族）**（`DEVICE.md:13`）。
- **内核侧已在主线**：`geekidos-linux/drivers/gpu/drm/msm/` 含 `adreno/a8xx_gpu.c`、`a8xx_preempt.o`（gen8 = Adreno 830）——见 `research-s3-driver-gap-2026-10-09.md:20-21`；`patches/` 内**无 GPU 专属补丁**（`TASKS.md:351`），GPU 走纯主线 `msm`。GPU 固件 `gen80000 zap/sqe/gmu/aqe` 用**设备签名 vendor 版**（`DEVICE.md:40`、`PITFALLS` #27「linux-firmware 版被 TZ 拒 -EINVAL」）。
- **用户态 GL/Vulkan 双栈**：Alpine `mesa-dri-gallium`(freedreno GL) + `mesa-vulkan-freedreno`(**Turnip**) + `mesa-egl` + `vulkan-loader`，`Mesa 26.1.8`（`TASKS.md:353`、`.pi/missions/bench.md:5`）。
- **chip-id 机制（这是 A830 在 Mesa 能否被认领的关键，务必记牢，勿再打补丁）**：
  - 主线 DRM 对本机 Adreno 830 报 chip-id **`0x0000ffff44050001`**（`rootfs/patch-mesa-a830.sh`、`rootfs/scan-a830.py`、`rootfs/configure-ubuntu.sh:114`）。
  - Mesa 设备表历史三种形态：Mesa 26.0 = KGSL id `0x0000000044050000`；Mesa 26.1 = wildcard（不带 patchid）`0x0000ffff44050000`；上游 commit **`2061a5ee` "A830v1 mainline DRM chip-id support"** 才加入带 patchid 的 `...01`（`rootfs/patch-mesa-a830.sh:2`、`scan-a830.py`）。
  - **PITFALLS #15**：本机内核报 `0xE844050000`（**patchid = 00**），正好命中 Mesa 26.1 **原版 wildcard** ⇒ **Alpine 26.1.8 不打补丁即可用，打了反而 unsupported**（`TASKS.md:353`「chip-id 补丁不要打，原版才对」）。
  - **Ubuntu 侧另议**：Ubuntu 自带 Mesa **26.0.8 只有 KGSL 形态**，且 A830 支持不完整、gnome-shell 会把 GPU 打挂（`hangcheck detected gpu lockup`）⇒ 真修复 = 交叉自编 **26.1.6** 装到 `/opt/mesa-a830`（`rootfs/build-mesa-a830.sh`、`configure-ubuntu.sh:112-119`）；原地 `patch-mesa-a830.sh` 仅作 fallback。

### 上游进展研判

- **kernel（a8xx）与 userspace（26.1.x）都已把 A830「跑到能用的程度」**：桌面 165 Hz、GLES+Vulkan 通、Waydroid 容器也用同一 freedreno 直驱（`TASKS.md:229`）。当前不存在「GPU 未上游」的缺口——缺口在**性能/稳定性打磨**而非「认不认领」。
- **Mesa 侧仍会持续演进 gen8/turnip**：`TASKS.md:358` 明确列了未来**重编触发条件** = 内核 DRM/A830 特性或 hang 调优（`has_fs_tex_prefetch`）/ **`26.3 turnip 分支`**。⇒ 说明 26.3 系列带 A830/gen8 turnip 的进一步改动（纹理预取、CSQ/robustness 一类），值得发布后评估。
- **无法无头核验 Mesa `main` 最新 gen8 MR/commit**（gitlab Anubis）。需人工看：`gitlab.freedesktop.org/mesa/mesa` 的 `src/gallium/drivers/freedreno`（GL）与 `src/freedreno/vulkan`（Turnip）里 `gen8`/`A8xx`/`A830` 相关近期提交，以及 chip-id commit `2061a5ee` 之后是否有 A830v2/patchid 变体扩展。

### 推荐行动

1. **现在**：不动 GPU 栈（26.1.8 已验证）。把「GPU 上游跟踪」登记为**低优先观察项**（不占设备）。
2. **人工核验（一次性）**：浏览器 `git clone` 或 Web 打开 Mesa，检索 `gen8`/`A8xx`/`A830` 近 3 个月提交 + 确认 `2061a5ee` 是否已进 26.1.y stable、`...01` patchid 变体是否被 wild 化（若 wild 化则连我们的原地 patch 都可废）。
3. **到点评估**：Mesa **26.3**（含 `26.3 turnip` gen8）发布后，按 `TASKS.md:358` 走一次 `build-mesa-a830.sh` 交叉重编 + 回归（`vk-probe`/桌面/gnome-shell 不打挂），对比分数与稳定性再决定是否上 26.3。
4. **不要**再对 Alpine 26.1.8 打 chip-id 补丁（PITFALLS #15）。

### 参考链接

- Mesa 上游 commit（chip-id）：`https://gitlab.freedesktop.org/mesa/mesa/-/commit/2061a5ee`（**Anubis 拦，需人工/git clone**）
- Mesa gen8/Turnip 源码目录：`src/gallium/drivers/freedreno/`、`src/freedreno/vulkan/`
- Turnip / Freedreno 文档：`https://docs.mesa3d.org/drivers/freedreno.html`
- 本地：`rootfs/{patch-mesa-a830.sh,build-mesa-a830.sh,scan-a830.py,configure-ubuntu.sh}`、`DEVICE.md:13,40`、`TASKS.md:353,358`、`PITFALLS #15 #27`、`research-s3-driver-gap-2026-10-09.md:20`

---

## 2. libcamera s5kjns IPA 校准 yaml 获取路径

### 状态（本地证据）

- 相机**出流 + libcamera 软件 ISP + Snapshot App 已实测通过**（orchestrate context；`TASKS.md:50` G1-5 已通）。
- **唯一剩余质量问题**：**后摄（Samsung S5KJNS 50MP）过曝、高光压制速度偏慢**（`TASKS.md:50`）；登记为**非阻塞**（`TASKS.md:124`）。
- 根因（仓库口径）：libcamera **`simple` IPA 无 s5kjns 校准 yaml** ⇒ AWB/曝光/CCM/LSC 无标定数据（`TASKS.md:50`、`.pi/plans/2026-10-07-dp5基线-相机补全-加速度.md:63-64`、`research-s3-driver-gap-2026-10-09.md:11,20`）。
- libcamera 版本 = **0.7.1**（`PITFALLS` #130）；软件 ISP 依赖 `/dev/dma_heap/system`（仅 `system_heap`，勿装 `cma_heap`，`PITFALLS` #130）。
- 前摄 GC08A8 同理会缺标定，但过曝症状集中在**后摄**。

### 为什么会过曝（IPA 模块差异，域内常识 + 与仓库口径一致）

- **`simple` IPA（`ipa_simple`）**：只做**极简** AG/曝光 + 有限白平衡，**没有** 黑电平标定、逐光源 CCM（色彩校正矩阵）、镜头阴影（LSC）、gamma 曲线等；缺标定 ⇒ 增益/曝光上限不设防 ⇒ **过曝 + 高光滚降慢**。
- **`soft` IPA（`ipa_soft`，即「软件 ISP」）**：libcamera 推荐的通用软件处理链，**逐传感器 YAML 调优**，算法含 **Awb / BlackLevel / ColorCorrectMatrix(CCM, 分光源) / Gamma / LensShading / Denoise**，正是治这个症状的目标模块。

### 三条获取路径对比（代价 × 把握）

| 路径 | 做法 | 代价 | 把握 | 说明 |
|------|------|------|------|------|
| **A. 换 `soft` IPA + 自标定最小 yaml（首选）** | 确认/切到 `ipa_soft`；为 `s5kjns` 写一份最小 yaml：黑电平（盖镜头拍暗帧）、AWB 中性点 + 分光源 CCM（Macbeth/灰卡，D65/A/TL84/CWF 各拍一组拟合）、LSC（均匀白墙/平场）、AG/曝光**上限**先兜住过曝 | 中（yaml 编写不占设备，标定占设备一次） | **中高** | 能直接压住过曝与高光慢；色彩做到「大致正确」，非厂商级 |
| **B. vendor IQ 文件转换（备胎）** | 从原厂 `/vendor` 提取 Qualcomm/IPE-IQ 或 Samsung 模组 IQA（`.bin`/`.xml`），**手工映射**到 `soft` yaml 的 CCM/LSC/black/gain 字段 | **高** | 低中 | **无现成自动转换器**；IQ blob 结构私有，字段对齐靠逆向，逐传感器逐模组 |
| **C. 就近借用他传感器 yaml** | 用 libcamera 已支持的同族三星大底（如 S5KHM/S5KGN 类）yaml 起步 | 低 | 低 | 只能当**起点**；CFA/增益/色彩响应不同 ⇒ 颜色偏差明显，仍需回到 A 自标定 |

> 说明：仓库此前还提过「评估换 `rpi/pisp` 类 IPA」（`2026-10-07-...:64`）。`pisp` 是给树莓派 PiSP 硬件的，本机无该硬件，**不适用**；正解是把「更可调优的软件 IPA」= **`soft` IPA** 作为迁移目标，而非 `pisp`。

### 推荐行动（分阶段，非阻塞、不占主线）

1. **先取证确认模块（不占设备）**：设备上确认当前到底跑 `ipa_simple` 还是 `ipa_soft`：`ls /usr/share/libcamera/ipa/*`、`cam --list` + 看 `libcameracfg`/pipeline，并记录是否已存在任何 `*.yaml`。
2. **短期止血（可先做）**：若确为 `simple`，优先切 `ipa_soft`；即便还没有 s5kjns 标定，先用 `soft` 的**默认/中性**参数 + **手动设置 AG/曝光上限**（`cam -t`/`qcam` 里的 exposure/analogue-gain limit，或 yaml 的 `rtp.maxAgain`/max shutter）**先把过曝和增益失控兜住**。
3. **正式标定（占设备一次）**：搭标定场景（灰卡 + Macbeth 色卡 + 均匀白场 + 暗帧），跑 libcamera 标定流程，产出 `s5kjns` 的 `soft` yaml（黑电平 + 多光源 CCM + AWB + LSC + gamma），落到 `/usr/share/libcamera/ipa/soft/`，并让 IPA 用探测到的 sensor 名加载它。
4. **验收**：后摄在标准光源下不再过曝、高光有滚降、白平衡不偏；用 `cam --capture`/Snapshot 出图对比。
5. **vendor IQ 转换**：仅在 A 无法满足画质诉求时才立项（预期为「多周工程」，先做 1 个模组验证可行性再谈规模化）。

### 参考链接

- libcamera Soft IPA 与调优文件编写：`https://libcamera.org/` → docs「**Writing a tuning file**」/ `ipa_soft`；`Documentation/api/ipa-*.rst`（**需人工核验具体版本 0.7.1 的 schema**）
- 调优工具：`qcam`、`cam`；`libcamera-tuning`（辅助生成 sensor 标定）
- 上游 s5kjns 标定**大概率不存在**（三星 S5KJN/S5KJNS 多用于 Pixel 等，公版 libcamera 无该 sensor yaml）⇒ 以自标定为准
- 本地：`TASKS.md:50,124`、`PITFALLS #130`、`.pi/plans/2026-10-07-dp5基线-相机补全-加速度.md:63-64`、`research-s3-driver-gap-2026-10-09.md:11,20`、`archive/topics/CAMERA-2026-10-05.md:75`

---

## 3. linux-arm-msm 关于 cambistmclkcc-sm8750 的回复 / fix 进展

### 状态（本地证据）

- **根因已锁死**（60+ 轮二分，`PITFALLS` #132 / `TASKS.md` §5 Q24）：单模块 **`cambistmclkcc-sm8750`** × DT 电源域（MMCX/MX 耦合）在**熄屏（DPMS off）时触发整机硬复位**；`qcom-camss`/`camcc-sm8750`/`i2c-qcom-cci`/`wl2868c-regulator` 各 3/3 存活，零相机对照 3/3 存活。
- **上游 DT 系列状态**：`[PATCH v4] arm64: dts: qcom: sm8750: Add camera clock controller`（Message-ID `20260511-sm8750_camcc_dt-v4-1-eab4b6c3eaea@oss.qualcomm.com`），**Bjorn 已 applied（commit `4a1779f42e21`）**；`research-q24-cambist-2026-10-09.md` 判定「**尚未发现后续修正补丁**」；v3→v4 changelog 已点明 camcc 用 `RPMHPD_MXC`（always-on），但 **cambistmclkcc 仍留 `RPMHPD_MX`**（E1/E2）。驱动系列 `20251202-sm8750_camcc-v1-...`；Bjorn 提过需 rebase 到 `v7.1-rc1+`。
- **我方已上报上游**（`archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md`）：**2026-10-08 09:16 已发送**至 `linux-arm-msm@vger.kernel.org`，Cc Taniya Das / Bjorn Andersson / Konrad Dybcio / Abel Vesa / linux-clk / devicetree；正文附对照表 + H1/H2 实验 + 两个问题（MMCX vs MX、`vdd_mx-supply` 表征）。**我方 patch：`be79b256d`（纯 ASCII）/ 实验版 `86ea33c25`**。
- **本地修复实验汇总**（同 q24 文档 + `PITFALLS` #132）：H1（去 power-domains）7/9、**H2（单挂 MX）用户实机 2/2 存活但 2026-10-08 自动扫测 3 轮 2 掉电 ⇒ 未根治**；驱动侧 `use_rpm=false` 6/9、去 `critical_cbcrs` 7/9 无效 ⇒ 电源域/DT 层耦合为主因、残留 ~20% 间歇。
- **现行规避（不得轻改）**：`elden_nocamera=1` + 空 `camera.conf` + `idle-delay=0`（`DEVICE.md:75`、`RUNBOOK-BRINGUP.md:260`、`TASKS.md` G1-22/G1-33）。

### 回复/fix 进展研判

- **截至仓库最后记录（2026-10-08）：无 maintainer 回复、无 fix**。我方报告发出仅 1 天，短周期内通常仍无回复属正常。
- **无法无头核验 lore 现态**（lore.kernel.org Anubis JS PoW；marc.info 超时；patchew/spinics 空壳）。⇒ **「发出后是否有回复」必须人工核验**（下节清单）。

### 推荐行动

1. **人工核验上游回复（不占设备，一次性）**——按下列任一入口查 2026-10-08 之后回复：
   - lore 线程：`https://lore.kernel.org/linux-arm-msm/`，搜索串 `cambistmclkcc sm8750`、`from:xuqianhui1001`、以及我方 Message-ID（若我方发送端可查到 in-reply-to 链）；
   - 上游系列根贴：Message-ID `20260511-sm8750_camcc_dt-v4-1-eab4b6c3eaea@oss.qualcomm.com`（看是否已有 v5/v6 或针对 power-domain 的后续）；
   - commit `4a1779f42e21`（`git log`/`https://git.kernel.org` 或 `korg` 镜像）之后是否有 `clk: qcom` / `dts: sm8750` 修正。
2. **未得回复前**：规避保留，**不再占用设备续修 H2 的 ~20% 间歇**（低样本、收益不确定；G1-33 维持 🟡 观察）。
3. **若上游回信要求 rebase/改法**：按 `vdd_mx-supply`（regulator 表征）或 `v7.1-rc1+` rebase 出 v2；本地复现协议已固化 `scripts/sleep-sweep.sh`（≥3 轮带对照组）。
4. **候选本地修复仍备查**（若要提前自救，二选一各测 ≥9 轮）：DT 第二域 `RPMHPD_MX → RPMHPD_MXC`（对齐 camcc，`research-q24` 方案 1）；或驱动 `cam_bist_mclk_cc_sm8750_desc` 加 `.use_rpm=true`（方案 2）——但**优先级排在「等上游回复」之后**，避免与上游方向分叉。

### 参考链接

- 上游系列（DT v4）：`https://lore.kernel.org/all/20260511-sm8750_camcc_dt-v4-1-eab4b6c3eaea@oss.qualcomm.com/`
- 上游系列（clk 驱动 v1）：`https://lore.kernel.org/all/20251202-sm8750_camcc-v1-0-b3f7ef6723f1@oss.qualcomm.com/`
- v3→v4 changelog（MX vs MXC）：`https://lkml.iu.edu/hypermail/linux/kernel/2605.1/04406.html`
- multi-PD voting 先例（SM8450/8550/8650 camcc 加 MXC）：`https://patchew.org/linux/20250530-videocc-pll-multi-pd-voting-v5-0-02303b3a582d@quicinc.com/`
- Konrad 评审（MXA 线索）：`https://lore-kernel.gnuweeb.org/linux-devicetree/d1f9ae01-a81a-4287-9f98-f2318ec6dd01@oss.qualcomm.com/T/`
- 本地：`archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md`、`.pi/plans/research-q24-cambist-2026-10-09.md`、`PITFALLS #132`、`TASKS.md` G1-22/G1-33/§5 Q24、`scripts/sleep-sweep.sh`

---

## 4. GPU 基准（G1-8）前置条件检查 —— `scripts/bench-run.sh`

### 脚本设计回顾（已通读全文）

- 位置 `scripts/bench-run.sh`（配套 `scripts/bench-install.sh`）；设计 = **只用设备已有工具，缺项自动跳过**，全程后台采样温度/CPU/GPU 频点，末尾打印 SUMMARY，原始日志留 `OUTDIR`（默认 `/var/log/bench-<ts>`）。
- 环境：`DUR`（每项秒，默认 15）/`ONLY`（cpu|mem|disk|gles|vk|all）/`OUTDIR`。
- 覆盖：CPU（sysbench/7z/stress-ng，退化到 sha256）、内存（sysbench/stress-ng）、磁盘（fio，退化到 dd）、GLES（glmark2-es2-wayland / es2gears_wayland）、Vulkan（`vulkaninfo --summary` + vkmark `-b vertex -b clear`）。
- Wayland 探测：扫 `/run/user/0/wayland-0`、`/run/phosh/wayland-0`、`/run/user/1000/wayland-0`，命中即设 `XDG_RUNTIME_DIR`/`WAYLAND_DISPLAY` 并置 `HAVE_WL=1`；**GLES/vkmark 仅在 `HAVE_WL=1` 才跑**。

### 前置条件清单 × 满足状态

| 前置 | 要求 | 状态 | 依据 |
|------|------|------|------|
| 内核/图形栈 | 任一 mainline；`msm`+freedreno/Turnip，Mesa 26.1.8 | ✅ | `.pi/agents/bench.md:15`、`TASKS.md:353` |
| Phosh/Wayland 会话 | 有可读 wayland socket 且 GPU 已被 turnip 认领 | 🟡 需**运行时确认**（socket 属会话用户；root 跑时需 uid 对得上 / 能读） | 脚本 Wayland 探测段 |
| 基础工具 | mesa-demos（es2gears）+ vulkan-tools（vulkaninfo）在 rootfs | ✅ 已在 rootfs（脚本头注 + `bench.md`） | `.pi/missions/bench.md` |
| 有意义的 GL-vs-VK 分数 | 需 `apk add glmark2 vkmark sysbench stress-ng fio` | ❌ **未装**（缺项只跑退化路径，出不了可比分数） | 脚本 `have()` 跳过逻辑 |
| 设备网络 | 装上述包需 apk 可达镜像 | ⚠️ 待确认（Q26 WiFi 不稳；走 USB-NCM 宿主链路更稳） | `TASKS.md` §5 Q26、`DEVICE.md` |
| 温控纪律 | 稳态贴近 90 °C 未降频须主动停测；验收不破 **82 °C** | ⚠️ 脚本**只记录峰值温度**，不主动熔断；需人工+`scripts/thermal-watch.sh` 同步盯 | `.pi/missions/bench.md`、`TASKS.md:53`、trips 70/82/90/105 |
| 设备独占 | 开始前 `scripts/device-lock.sh --status` 空闲，全程持锁，不刷 boot/不重启内核 | ⚠️ 属执行纪律，未自动化 | `.pi/missions/bench.md` |

### 已识别风险 / 待确认（执行前）

1. **`vkmark` 时长单位存疑**：脚本 `vkmark ... -d "$((DUR*1000))"`——vkmark 的时长参数/单位需按设备上 vkmark 版本核对（`--duration` 语义），否则会跑错时长。建议首跑先 `ONLY=vk DUR=5` 冒烟。
2. **root + Wayland socket 归属**：Phosh 会话用户的 `wayland-0` 在 `/run/user/<uid>/`；以 root 直接跑可能命中 `/run/user/0/wayland-0`（若 Phosh 以 root 起）或需切到会话说 `XDG_RUNTIME_DIR`。首跑用 `ONLY=gles DUR=5` 验证 `HAVE_WL` 与出帧。
3. **apk 网络是真正闸门**：装 glmark2/vkmark/sysbench 需镜像可达；WiFi（Q26）慢/不稳时，优先走 USB-NCM 宿主代理链路。装不齐就只得 sha256/dd 的 CPU/磁盘退化指标，**GPU 分数拿不到**。
4. 温控：脚本不熔断，须人盯 82 °C 红线；`thermal.log`/`thermal-watch.sh` 佐证。

### 推荐行动（执行 runbook，占设备）

1. `scripts/device-lock.sh --status` 确认空闲并持锁；接 USB-NCM 供电联网。
2. `apk add glmark2 vkmark sysbench stress-ng fio`（缺哪个补哪个；装不动先记录）。
3. 冒烟：`ONLY=gles DUR=5 sh bench-run.sh` 验 Wayland/出帧；`ONLY=vk DUR=5` 验 vkmark 单位与认领。
4. 标准轮：`DUR=15 sh bench-run.sh`（预热 1 + 正式 ≥3 遍，见 `bench.md` 方法），**同步 `scripts/thermal-watch.sh`**，破 82 °C 即停。
5. 出证据文档 `archive/topics/BENCH-<date>-subagent.md`；**不改 `TASKS.md`**（编排者独立复跑后更新 G1-8）。

### 参考链接

- 本地：`scripts/bench-run.sh`、`scripts/bench-install.sh`、`scripts/thermal-watch.sh`、`scripts/device-lock.sh`、`.pi/missions/bench.md`、`.pi/agents/bench.md`、`TASKS.md:53`（G1-8）、`RUNBOOK-BRINGUP.md:355-356`、`.pi/plans/2026-10-08-本地待测清单.md:37`

---

## 附：本次调查方法与局限

- **本地证据**：通读 `scripts/bench-run.sh` 全文、Mesa 相关脚本（`patch-mesa-a830.sh`/`build-mesa-a830.sh`/`scan-a830.py`/`configure-ubuntu.sh`）、`TASKS.md`（G1-5/G1-8/G1-22/G1-33/§5/§7）、`PITFALLS` #15/#27/#130/#132、`.pi/missions/{bench,camera}.md`、`.pi/plans/research-q24-cambist-2026-10-09.md`、`archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md`。
- **网络核验受限（关键）**：`curl --noproxy` 试 `lore.kernel.org`（Anubis JS PoW 403→挑战页）、`gitlab.freedesktop.org`（Anubis）、`marc.info`（连接超时）、`patchew.org/search`/`spinics`（空壳/JS 页）⇒ **2026-10-08 之后的上游新回复/新 fix、Mesa `main` 最新 gen8 提交，均无法无头核验**。§1/§3 已给出人工核验入口与 Message-ID/commit。
- **未改任何领域层文件**；本调查只产出本文件。
