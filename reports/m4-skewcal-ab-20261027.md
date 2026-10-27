# M4 R1 · SKEW_CAL A/B（设备侧热换模块，csiphy 3ph sm8750 lane 表）

- 日期：2026-10-27
- Lane：devcam-ab ｜ Baseline：`base/20261027-5d6400f`
- 设备：TB322FC / elden（SM8750P），`uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`
- 唯一变量：`build/vk151/drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c` → `lane_regs_sm8750[]` 里 4 条 `CSIPHY_SKEW_CAL` 记录的 data 字段
  - **A 臂（基线/现状）**：`0x005C/0x045C/0x085C/0x0C5C = 0x54`
  - **B 臂（厂商原值）**：同上 4 条 = `0x00`
- 手法：**只热换 `qcom-camss` 模块**（`mod-loop.sh --reload qcom-camss`），未整机重启、未写 boot 槽、未改 `.config`。

## 状态：进行中（分节追加）

<!-- SECTIONS BELOW ARE APPENDED AS EACH STEP COMPLETES -->
## 1. 只读准备（设备现状）

| 项 | 值 |
|---|---|
| `uname -r` | `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`（含 vk172 ✅） |
| 模块 | `/lib/modules/<uts>/kernel/drivers/media/platform/qcom/camss/qcom-camss.ko`，sha256 `02ef4401…b2aaa7`，vermagic 与 uname 一致 |
| `qcom_camss` refcnt（前） | 0 |
| 链路 | `gc08a8`(front, SRGGB10) + `s5kjns`(rear) + `v4l2_cci` + `gt9764` 已加载 |
| media 拓扑 | `msm_csiphy0..5` / `msm_csid0..4` / `msm_vfe0_rdi*` → `/dev/video0..16`，`msm_vfe0_video0 = /dev/video0` |
| dmesg 相机错误计数（前） | 0 |

测量口径（A/B 同一脚本 `scripts/skewcal-measure.sh`，全程在 `scripts/device-lock.sh` 锁内）：

- 链路配置：`/tmp/camera-stream-up.sh front`（主机 `scripts/camera-stream-up.sh` scp 上去）
- 采集：`v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=90`，目标 90 帧
- 计时：设备侧 `date +%s%N` 前后差（不含链路配置时间）
- 成功帧数：`v4l2-ctl` 输出的 `'<'` 帧标记个数（`got`），另记录它自报的 `V4L2FPS`
- 错误计数：`dmesg | grep -ciE "command DMA timeout|EPIPE|EINVAL|csiphy.*error|camss.*error"` 的全量计数前后差分
  （**注意**：本机 dmesg 环形缓冲已满、总行数恒定 7408 ⇒ 不能用 `tail -n +N` 取增量，改用计数差分）

## 2. A 臂（现状模块，源码未改，不重编）

| # | got/90 | 耗时 (s) | 实测 fps | v4l2 自报 fps | 错误计数 |
|---|---|---|---|---|---|
| A1 | 90 | 3.156 | 28.52 | 30.26 | 0 |
| A2 | 90 | 3.154 | 28.54 | 30.26 | 0 |
| A3 | 90 | 3.144 | 28.63 | 30.26 | 0 |

A 臂基线：3 次全部 90/90 帧、0 错误、耗时 3.144–3.156 s（σ≈0.006 s），v4l2 报 30.26 fps（= sensor 30 fps 上限，链路满速）。

## 3. B 臂（厂商值 0x00）——改源码 + 热换模块

源码改动（只 4 行，`lane_regs_2_4_0[]`，本树里该表函数体名就是 `lane_regs_2_4_0`，
派工单写的 `lane_regs_sm8750` 是同一张表的 sm8750 化别名；差异仅 0x54→0x00）：

```diff
-	{0x005C, 0x54, 0x00, CSIPHY_SKEW_CAL},
+	{0x005C, 0x00, 0x00, CSIPHY_SKEW_CAL},
-	{0x045C, 0x54, 0x00, CSIPHY_SKEW_CAL},
+	{0x045C, 0x00, 0x00, CSIPHY_SKEW_CAL},
-	{0x085C, 0x54, 0x00, CSIPHY_SKEW_CAL},
+	{0x085C, 0x00, 0x00, CSIPHY_SKEW_CAL},
-	{0x0C5C, 0x54, 0x00, CSIPHY_SKEW_CAL},
+	{0x0C5C, 0x00, 0x00, CSIPHY_SKEW_CAL},
```

完整 patch 存档：`reports/artifacts/m4-skewcal-ab-20261027/b-arm-skewcal-0x54-to-0x00.patch`（40 行，4 个 hunk）。

### 3.1 构建/热换过程中踩到的两个坑（已解，记录以免复现）

1. **`LOCALVERSION` 必须显式给**：本树 `CONFIG_LOCALVERSION="-debug-vk127-00002-g24223e44ad80-dirty"`，
   设备 UTS 是在其后追加 `-debug-vk172`。裸 `make` 会得到 `…-dirty+`（`setlocalversion` 给 dirty 树补 `+`），
   vermagic 不符 → modprobe 静默失败。必须 `LOCALVERSION=-debug-vk172`。
2. **`include/config/kernel.release` 缓存陈旧**：该文件（gitignore 内，2026-10-27 11:54 写入 `…-dirty+`）是
   `modules_install` 的目标路径来源，`M=… modules` 不会刷新它 ⇒ 模块被装到 `…-dirty+/updates/`，
   而设备要的是 `…-debug-vk172/updates/`。修法：先
   `LOCALVERSION=-debug-vk172 make include/config/kernel.release`（UPD 一次），再跑 mod-loop。
   **副作用**：`.config` 未改，但该生成文件现在是正确值，后续构建也一致。

### 3.2 热换证据（确认新模块真的在跑）

| 项 | 值 |
|---|---|
| `modinfo -n qcom_camss` | `/lib/modules/<uts>/updates/qcom-camss.ko`（新，19:57，12.0 MB 带 DEBUG_INFO） |
| 旧模块残留 | `/lib/modules/<uts>/kernel/…/qcom-camss.ko`（10-26 20:00，839 KB）仍在盘上，但优先级低于 `updates/` |
| **运行中模块 build-id** | `83c37dd1e8c728cac3e0df5096711d4e86d5af61` = `updates/qcom-camss.ko` 的 build-id ✅（旧 ko = `2dd23e54…`） |
| `rmmod` + `modprobe` 复验 | rc=0/0，reload 后 build-id 仍为 `83c37dd1…` |

> 注：`mod-loop.sh` 打印的 `[mod] reloaded qcom-camss` 本身不足以证明换了模块（它 suppress 了 modprobe 的错误），
> 所以用 build-id 对比 `/sys/module/qcom_camss/notes/.note.gnu.build-id` 做硬证据。

### 3.3 B 臂 3 次测量

| # | got/90 | 耗时 (s) | 实测 fps | v4l2 自报 fps | 错误计数 |
|---|---|---|---|---|---|
| B1 | 90 | 3.150 | 28.57 | 30.26 | 0 |
| B2 | 90 | 3.149 | 28.58 | 30.26 | 0 |
| B3 | 90 | 3.147 | 28.60 | 30.26 | 0 |

B 臂：3 次全部 90/90 帧、0 错误、耗时 3.147–3.150 s，v4l2 报 30.26 fps（与 A 臂同）。

### 3.4 帧内容抽查（防止「帧数够但像素坏」）

`scripts/skewcal-frame-stats.sh`（锁内抓 3 帧 raw 到设备 `/tmp`，python3 统计）：

| 臂 | BYTES | NONZERO_PCT | DISTINCT | MEAN | STDDEV |
|---|---|---|---|---|---|
| B（0x00） | 29 963 520 | 99.92 % | 256 | 42.77 | 53.78 |

（A 臂同位对照见 §4.2。）

## 4. 收尾：恢复 A 臂

### 4.1 源码恢复

```sh
git -C build/vk151 checkout -- drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c
git -C build/vk151 diff -- <file>      # → 输出为空 ✅
```

恢复后 829/852/875/898 行复读均为 `{0x00XX, 0x54, 0x00, CSIPHY_SKEW_CAL},`（0x54 回来）。

### 4.2 设备模块恢复（**恢复成原始基线 ko，不是重编的 A 臂**）

判据：运行中模块的 build-id。

| 阶段 | `/sys/module/qcom_camss/notes/.note.gnu.build-id` | 对应文件 |
|---|---|---|
| 起始基线 | `2dd23e5446174f7a382c1b8b65ba0c7d8f787ecc` | `kernel/…/camss/qcom-camss.ko`（10-26 20:00，出厂基线 ko） |
| B 臂 | `83c37dd1e8c728cac3e0df5096711d4e86d5af61` | `updates/qcom-camss.ko`（本次新编，0x00） |
| 收尾 | `2dd23e5446174f7a382c1b8b65ba0c7d8f787ecc` ✅ | 回到 `kernel/…/camss/qcom-camss.ko` |

收尾做法：`rmmod qcom_camss` → 删掉 `updates/qcom-camss.ko` → `depmod -a` → `modprobe qcom_camss`。
这样设备回的是**开机时那颗原物**，比"重编一个 A 臂"更严格地满足「回到基线」。
`refcnt` 收尾 = 0，`modinfo -n` = `kernel/…/camss/qcom-camss.ko`。

### 4.3 恢复后复测

| # | got/90 | 耗时 (s) | 实测 fps | v4l2 自报 fps | 错误计数 |
|---|---|---|---|---|---|
| A-restored | 90 | 3.151 | 28.56 | 30.26 | 0 |

帧内容对照（同 §3.4 口径）：

| 臂 | BYTES | NONZERO_PCT | DISTINCT | MEAN | STDDEV |
|---|---|---|---|---|---|
| A（0x54，恢复后） | 29 963 520 | 99.92 % | 256 | 42.80 | 53.81 |
| B（0x00） | 29 963 520 | 99.92 % | 256 | 42.77 | 53.78 |

## 5. 判定

| 指标 | A 臂 (0x54) | B 臂 (0x00) | 差异 |
|---|---|---|---|
| 成功帧 | 90/90 ×3 | 90/90 ×3 | 无 |
| 90 帧耗时 | 3.144 / 3.154 / 3.156 s（均值 3.1513，σ=0.0064） | 3.147 / 3.149 / 3.150 s（均值 3.1487，σ=0.0015） | Δ=−0.0026 s（−0.08 %），**远小于 A 臂自身 σ×0.5** |
| fps（v4l2 自报） | 30.26 ×3 | 30.26 ×3 | 无（已顶到 sensor 30 fps 上限） |
| 错误计数（dmesg 差分） | 0 ×3 | 0 ×3 | 无 |
| 帧内容 STDDEV | 53.81 | 53.78 | Δ=0.03（0.06 %） |

**结论：B 臂（厂商值 0x00）在"能出流、fps、错误计数、帧内容"四个维度上都不劣于 A 臂，且无可测改进。**

三个限定条件必须一起读：

1. **测量本身分辨不出差异**：30.26 fps 是 sensor 上限（gc08a8 SRGGB10 3264×2448），链路已满速跑，
   A/B 都封顶 ⇒ 这个指标对 SKEW_CAL 天然不敏感。要把差别逼出来需要更高数据率（更高分辨率/位深/多 lane）
   或直接看 CSI-2 误码/CRC，而不是看 fps。
2. **只热换了模块，未整机重启**：本轮是 `rmmod/modprobe` 热换 + 无 POR。SKEW_CAL 属于 PHY 上电初始化序列，
   **冷启（POR）路径下 PHY 复位时序不同**，本结论不外推到整机冷启动。
3. **单摄单模式**：只测了前摄 gc08a8（csiphy4 → csid0 → vfe0_rdi0 → /dev/video0），
   未覆盖后摄 s5kjns（csiphy3）与 csiphy 其它 lane 组合。

**是否建议回退成厂商值：暂不单独回退，建议与上游化一并处理。**
理由：(a) 本轮没有测出 A 臂有害（0x54 三次全绿、零错误），不构成"必须回退"的证据；
(b) 但厂商 82 张表里确实没有 0x54，A 臂值目前**无来源可追溯**，属于可疑魔数；
(c) 两种值在本机工作时长内均无错误，说明这 4 个字段对当前链路**不是关键路径**——
   最稳妥的处置是扔给上游/mailine 讨论时以厂商值为准（0x00）并注明"本机无差异"，而不是在本地偷偷改。

## 6. 口径声明

- 本实验**只热换 `qcom-camss` 模块**（`rmmod` + `modprobe`），**未整机重启、未写 boot 槽、未 fastboot、未改 `.config`**。
- 因此 `trial.sh` record 的 `reset_type=warm`；暖复位样本对复位敏感问题无效（PITFALLS #166），
  本实验的结论仅限"热换模块状态下的出流对比"。
- 全程设备操作经 `scripts/device-lock.sh`。
- 唯一未按原单的点：原单说 `mod-loop.sh --reload qcom-camss` 会完成热换，实测**不会**（见 §3.1/§7），
  改为手动 `rmmod/modprobe` + build-id 校验。

## 7. 工具侧发现（建议上游 agent 修）

1. **`mod-loop.sh` 的 `--reload` 对带下划线的模块名是静默失败的**：
   它用 `lsmod | grep -q '^$m '`，而传入的名字是 `qcom-camss`（连字符），lsmod 里是 `qcom_camss`（下划线）
   ⇒ 匹配不到就去 `modprobe qcom-camss`（同样不存在该名），`2>/dev/null` 吞掉错误，
   最后仍打印 `[mod] reloaded qcom-camss`。**"reloaded" 是假的**。
   建议：`m=$(echo "$m" | tr '-' '_')` 或直接 `grep -qE "^${m//-/_} "`，且 modprobe 失败时非零退出。
2. **`mod-loop.sh` 依赖陈旧的 `include/config/kernel.release`**：`M=… modules_install` 的目的路径来自该文件，
   它不会在 `M=` 构建里刷新 ⇒ 模块被装到 `…-dirty+/updates/`（错误 KV 目录），热载静默无效。
   建议 mod-loop 在 install 前显式 `make include/config/kernel.release`。
3. 本轮两个坑都表现为**静默成功**，因此报告的每条"已 reload"都用 build-id 独立复核过。

## 8. 产物

| 文件 | 行数 | 说明 |
|---|---|---|
| `reports/m4-skewcal-ab-20261027.md` | 见 `wc -l` | 本报告 |
| `reports/artifacts/m4-skewcal-ab-20261027/b-arm-skewcal-0x54-to-0x00.patch` | 40 | B 臂 4 行 diff（4 hunk） |
| `scripts/skewcal-measure.sh` | — | 单次出流测量（锁内）|
| `scripts/skewcal-frame-stats.sh` | — | 帧内容统计（锁内）|
| `reports/trials/20261027T120121Z-m4-skewcal-armA-0x54.json` | — | A 臂 record（reset=warm）|
| `reports/trials/20261027T120121Z-m4-skewcal-armB-0x00.json` | — | B 臂 record（reset=warm）|
