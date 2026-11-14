# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：**§0（现在一页）→ §2「入口阶梯」**（含时间序权重）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录 = 入口 `INDEX.md` + 项目身份 `AGENTS.md` + 公开 `README`/`PROGRESS`（**公开门面，agent 默认不读**），**7 个角度文件夹**（`DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/`），各自 `README.md`（策展 SSOT）+ `sessions/`（会话进度）；标准见 §2。
> 2026-10-03：git 纳管 + 文档收敛（12→6）；自检 `scripts/check-doctor.sh`；不再有 SQLite/生成物。

---

## 0. 现在一页（**唯一的状态入口**；核对日期：2026-11-14）

> 新会话**只读本节**就知道「做到哪、卡什么、下一步」。三行都有日期 + 证据指针；
> 与其它文档冲突时**以本节为准**，冲突处按 §2「时间序裁决」处理（旧说法标作废或直接删）。
> 数字口径：完成度以 `TASKS/README.md` §0（脚本 `scripts/check-progress-counts.sh --tsv` 现出）为准，本节只摘结论。

**做到哪**

1. **G1 = 36/37**（2026-11-14 现查；`❌` 仅 `G1-10` 无 NFC 硬件、`G1-30` 与 G1-29 同路线）。在机 = **RAM 启动的 `vk191`**（= `vk190` 的 kernel/dtb 逐字节原样 + 新 ramdisk），`boot_b` = vk190（**重启即回 vk190**）；判据全绿 = DSI/WiFi/`/dev/fastrpc-adsp`/传感器/Waydroid/zram + **s2idle 3/3**。→ `DEVICE/README.md` §1.1 首条、`reports/device-session-20261113-vk191.md`。
2. **G2 = 9/13**（Waydroid 主链 + 传感器/音频/GMS/马达/输入法/相机 STREAMING 都通）；**C3 Play Integrity 已书面收口三档**（无 TEE、keymaster 软实现 ⇒ STRONG 结构性不可能），剩唯一动作 = 一次 SPIC 回包。→ `reports/c3-pi-tiers-closeout-20261110.md`。
3. **G3 = Steam 登录界面 ✅**（2026-10-28 设备实测 3/3，截图判据 10-29 闭环），游戏端到端未做。→ `reports/g3-steam-20261028.md`。
4. **拓展：UEFI 两种形态都通**（2026-11-10 深夜定案：flashed 失败真根因 = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我们的 DTB，清 `dtbo_a` 即通）；Gunyah = 有条件重启、非主线。→ `reports/uefi-dtbo-a-rootcause-20261110.md`、`TASKS` §5「2026-11-10（深夜…）」块。
5. **上游**（2026-11-14）：**mdss v5 已发**（答 sashiko `0xa000` 独立域质疑，3/3 只收窄 message）、**wl2868c v11 已发**；dwc3 v9 / dsi-phy v2 / gamma v2 / haptics v2 / board DTS 单提交 = **备料在档、等批准**。→ `reports/upstream-status-20261113.md`、`TASKS` §7。

**卡什么**

- **camss 唯一硬分歧 = CSIPHY 2.3.0 vs 2.4.0**：上游 7.4-rc3 已把表迁到 `phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c` 的 `lane_regs_x1e80100[]`（= vendor **v2.1.2**），本机 vendor `camera.ko` 是 **2.4.0**（地址 103/103 相同、13 个 data 字节不同，逐版本扫证明是版本特征）⇒ 要 2.4.0 delta，形状须改成 phy 驱动里新增 `lane_regs_sm8750[]`。**没拿到对照表就不发信提问**。→ `reports/camss-csiphy-v6-vs-240-20261113.md`、`PITFALLS #648`。
- **fastrpc**：等上游 `accel/qda` v4 与 `nsessions` 废弃定调（不等我们动作）。→ `reports/fastrpc-nonsecure-evidence-20261113.md`。
- **T14/T17 用户态固化**：S3+S4+S6 离线复核已过，**唯一缺口 = `hapticd` 二进制不可重建**（自家 ELF，chroot 步骤已闭合）。→ `reports/t14-s3s4s6-offline-verify-20261114.md`。
- **T9 待机**：改成间接采样（设备 timer 30 min 追加 `/var/lib/elden/suspend-resource.tsv`），**要 1–2 天数据才能判**，取数是人的动作。→ `TASKS` §4 T9、`PITFALLS #651`。
- **已结项、勿重推**：Q28/Q32 =「已规避」（运营线 8/8 无坏发）、Q24 = 根因指名（7.2 缺 `skip retention by default`）、Gunyah = 非主线、`#106` = 历史记录（2026-10 之后无复现样本，未取证）。

**下一步（按顺序）**

1. **camss CSIPHY 对账**（主机侧，无需设备）：拉 7.4-rc3+ 的 phy 表与 vendor 2.4.0 逐字节比 → 决定是否给上游 2.4.0 delta。
2. **上游待批准批次**：dwc3 v9 四枚（`git apply --check` 4/4 OK）、dsi-phy v2 九行、gamma v2、haptics v2、board DTS 单提交 —— 逐系列等用户放行。
3. **设备窗口才做**：A10 两发（`set_active a` 或物理 POR）、B6/B18 需先建树出镜像。
4. **T9 取数**：`scp elden-root:/var/lib/elden/suspend-resource.tsv .` 后按同一 boot ≥3 周期看趋势。

**怎么核实本节没漂**（开工前先跑，见 `.pi/AGENT-OPS.md` §0）

```sh
scripts/recent-sessions.sh 3          # 最近 3 轮会话的收尾结论（正文在 .pi/sessions/*.jsonl）
scripts/check-progress-counts.sh --tsv   # G1/G2 完成度现查
sed -n '/### 1.1/,/### 1.2/p' DEVICE/README.md | head -20   # 在机内核/槽位/判据
scripts/check-doctor.sh --only 15      # §15：本节「核对日期」是否落后于最新会话证据
```

---

## 1. 使命与范围（3 行；目标定义只在一处）

- **机型唯一**：只研究 **TB322FC / elden / SM8750(P)**，不做别的机型移植；研究面 = 让本机在主线 Linux 上功能完整（固件/驱动为主，刷写只是手段）。
- **G1 / G2 / G3 / 拓展 / 核心原则（设备等价 / 存储 / 构建并发 / 上游发信授权）= 唯一正文在 `AGENTS.md`**（每轮自动注入，此处不复述）。
- **术语**：设备称 **U1 / U2**；备份目录 `backup/<SN>-<容量档>/`；禁用 `new-tablet` 与「两轨分机」旧口径；容量裁定见 `DEVICE/README.md` §3。

---

## 2. ★ 文档结构（文件夹＝角度；会话进度进 sessions/）

> **文档 v2（2026-10-14 起）**：每个**角度** = 一个**文件夹**，内含 `README.md`（该角度**策展 SSOT 正文**，唯一维护面）+ `sessions/`（**以会话为单位**的进度文件）。
> **会话进度文件**：命名 `YYYY-MM-DD-<主题>.md`（同日多主题加 `-2`）；文件头记 日期 / pi 会话 id / 主题 / 结论 / 证据指针 / **★SSOT 待并入**。
> **记录时的区分度**（取代自检脚本的计数/索引）：写入时就靠 文件夹(角度) + 文件名(日期+主题) + pi 会话 id 区分。
> **会话检索** = pi 原生项目会话（`.pi/sessions/*.jsonl`，项目级 `sessionDir`）：`scripts/sess.sh` / `/resume`；不手抄索引表。
> **SSOT**：数字/结论只在该角度 `README.md` 维护，其余用链接；跨会话新增先落 `sessions/`，由宿主择机并入 `README.md`。
> **阅读顺序只在一处声明**：唯一路径 = 下面「入口阶梯」（按新鲜度加权；与 `.pi/AGENT-OPS.md` §0 开工三件事是同一阶梯）。

### ★ 会话结束时写什么（唯一规则，8 条）

> 目标：**增量记录**——每次会话只新增文件，不改旧文件；状态数字只有一处出口。

1. **只写 1 个新文件**：`<角度>/sessions/YYYY-MM-DD-<主题>.md`；同一会话多主题加 `-2`。**不新建目录、不改已存在的 sessions 文件、不建索引表**。
2. **可用角度 5 个**：`TASKS/`（任务/进度/未解）、`PITFALLS/`（踩坑）、`DEVICE/`（单元/镜像状态）、`RESOURCES/`（资产/资源）、`RUNBOOK-BRINGUP/`（bringup 流程与相变记录）。
   `SESSIONS/` **冻结不写**；`HISTORY/` 由脚本生成**不手写**；`RUNBOOK-BRINGUP/` 已有正文（Phase −1…9 + `sessions/`），属可写角度。跨角度时写**主角度**一个文件，其余角度补一行指针。
3. 文件头只写 6 个字段：`日期 / pi 会话 id / 主题 / 结论 / 证据指针 / ★SSOT 待并入`。`pi 会话 id` 取 `$PI_SESSION_ID`。
4. **状态数字只改一处**：`TASKS/README.md` §0（总览）/ §5（Q 行）。其它任何地方**不写状态数字**，只写指针。
5. **会话全文不复述、不复制**——它就在 `.pi/sessions/*.jsonl`；文件里只放「结论 + 指向证据的路径/命令」。
6. **索引只放一句话主题**：`PITFALLS/README.md` 的索引行 ≤800 B，结论/命令/数字一律在正文。超长会被 `check-doctor §8` 判 FAIL。
7. **不写死计数**：任何「共 N 条 / N 个文件 / N 个提交」都必须现查（`scripts/gen-history.sh --stats`、`ls`、`check-doctor §8`）。写死必漂，且漂了没人发现。
8. **收尾判据**（`.pi/AGENT-OPS.md` §5）：产物落盘 + SSOT 同步 + `check-doctor.sh` **FAIL=0** + `git commit` + 工作区干净。


### ★ 时间序裁决（同一事实出现多个说法时的**唯一**规则）

> 目的：文档里**不准并列两说**。历史上多次出现「旧结论 + 勘误 + 再勘误」同时躺在正文里，
> 新会话无法判断哪个算数 —— 实测代价 = 每轮开工先花几十分钟考古。

1. **同一事实只允许一个「当前口径」**，写在**离它职责最近的那一份 SSOT** 里（状态 → 本文件 §0 / `TASKS`；设备事实 → `DEVICE`；经验 → `PITFALLS`；行为 → `.pi/AGENT-OPS.md`）。
2. **胜负判定 = 证据强度优先，其次日期**：会话内**实测证据（命令 + 原始输出）** > 带日期的报告（`reports/*.md`）> 文档叙述；同类证据取**日期更新**者。无日期、无证据的叙述直接输。
3. **输了的那条只有两种待遇**：① 与现状无沿革价值 → **删**（commit 信息写明「删除旧口径 + 依据」）；② 有沿革价值（曾被当真、影响过判断）→ 就地改成一行 `~~旧说法~~ **作废（YYYY-MM-DD，真因 + 指针）**`，**不得**在别处再复述一遍旧的。
4. **改口径必须同轮改完所有引用点**（grep 旧结论的关键词），并在提交信息里写「口径更正（YYYY-MM-DD）：旧 X → 新 Y（证据）」。发现新的实测证据与本文件 §0 冲突时，**先改本文件 §0 的结论与核对日期**，再改下游文档。
5. **本节自身有门**：`scripts/check-doctor.sh` §15 做两项比对（落后就 WARN、矛盾就 FAIL）：
   §0「核对日期」vs **最新会话证据日期**；以及 **§0 写的「在机 `vkNN`」必须出现在 `DEVICE` §1.1 首条**
   （§1.1 只允许一个 `★★` 权威行 —— 2026-11-14 之前那里同时挂着 vk190/vk191 两套说法，就是本节的实测代价反例）。

### ★ 入口阶梯（**唯一**路径；数字越小越权威，冲突时上位胜 —— 这就是时间序权重）

| # | 读什么 | 为什么它在这个位置 |
|---|---|---|
| 0 | 本文件 **§0 现在一页**（做到哪 / 卡什么 / 下一步） | 最新会话证据的摘要，标题带核对日期 |
| 1 | **`scripts/recent-sessions.sh 3`** + `*/sessions/` 最新 2 篇的「结论 / ★SSOT 待并入」 | **比任何 README 新**：本轮及上两轮的实测结论 |
| 2 | **`.pi/AGENT-OPS.md` §0**（开工三件事）→ §1–§5 | 行为唯一入口；§0 直接要求先做第 1 行 |
| 3 | **`PITFALLS/README.md` §0**（零号纪律）+ 索引 | 动手前必查的既有结论 |
| 4 | **`TASKS/README.md`** §0 / §4 / §5 / §7 | 状态数字与台账的唯一出处 |
| 5 | `DEVICE` §1.1（在机）/ `RESOURCES` §3（资产）/ `RUNBOOK-BRINGUP`（步骤） | 按需展开 |
| 6 | `reports/*.md`（按日期）→ `archive/` · `SESSIONS/` · `PROGRESS.md` · `HISTORY/` | **只作沿革与证据，不得当「当前结论」引用** |

> **权重规则（硬）**：第 1 行（最近会话）与第 4–6 行冲突时，**先按会话读**，并在**同一提交**内把下行文档改成一致；
> 不允许「两边都写着，读者自己判」。`README.md` / `PROGRESS.md` 是**公开门面**，agent 默认不读（不占入口位）。

### ★ 根目录四文件的职责边界（单一事实源；2026-10-15 收敛）

> 收敛前：机型规格出现 4 处、G1–G3 目标在 4 个文件各复述一遍 ⇒ 必然漂移（实测 `README.md`
> 的机型表与 `AGENTS.md` 重复、目标段与 `INDEX.md` §1 重复）。现按「一条事实只有一个正文位置」
> 收敛如下，**其余位置一律只给链接**：

| 文件 | 唯一职责（正文位置） | 不得复述 |
|---|---|---|
| **`AGENTS.md`** | **项目身份**：机型唯一性、G1–G3 目标定义与优先级、核心原则（设备等价/存储/SSOT） | 不写进度数字 |
| **`INDEX.md`**（本文件） | **路由**：入口阶梯（含时间序权重）、文件夹地图与 SSOT 口径、§0 现状摘要、快速命令 | 不写状态数字（指向 `TASKS` §0）、不复述目标（指向 `AGENTS`） |
| **`README.md`** | **公开门面**：面向 GitHub 读者的定位、免责/许可、快速开始 | 机型表/目标只留速查副本 + 指向 `DEVICE`/`AGENTS` |
| **`PROGRESS.md`** | **公开时间线**：诚实进度叙事（含被推翻的结论） | 不写权威台账（指向 `TASKS`） |

细节（机型规格、分区、单元台账）以 `DEVICE/README.md` 为准；状态数字以 `TASKS/README.md` §0 为准。

### 规范入口（agent 行为唯一入口）

| 入口 | 文件（权威） | 装什么 |
|---|---|---|
| **行为/规范** | **`.pi/AGENT-OPS.md`** | agent **自主优先**、物理干预边界、设备安全纪律、研发纪律、文档写入权限、汇报/时间盒；并发细则见 `.pi/CONCURRENCY.md`，三层编排见 `.pi/ORCHESTRATION.md` |

> 项目描述（机型/目标/设备等价）在 `AGENTS.md`；各角度 `README.md` 不再复述规范与经验。
> （原「1 分钟版」三步已于 2026-11-14 并入上方「入口阶梯」第 0/2/3 行，不再单列。）

### 角度文件夹（`README.md` = 权威正文；子目录 = 以会话/单元为单位的记录）

| 角度 | 文件夹 | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE/`** | 机型规格、固件清单与通路、驱动矩阵、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略** |
| **任务 / 进度 / 未解 / 方案** | **`TASKS/`** | **唯一任务台账 + 进度权威**（§0）；G1/C/A 任务（§1–4）；**§5 查漏补缺（GAPS，Q 编号以表内为准）**；**§6 G2 安卓兼容方案**；**§7 上游化（M 系列，以 §7 为准）** |
| **资源 / 资产 / 会话** | **`RESOURCES/`** | §1 外部参考 · §2 本地资源 · **§3 文件与资产台账（git 边界/可清理）** · §4 会话检索（pi 原生） |
| **上机手册** | **`RUNBOOK-BRINGUP/`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase −1…9 |
| **开发经验 / 踩坑** | **`PITFALLS/`** | **开发经验唯一入口**：`README.md` = §0 零号纪律 + 索引表（条数以该表实际行数为准，勿在此写死）；正文在 `sessions/NN-*.md`（含 **§15 过时/废弃登记**） |
| **会话档案（逐会话）** | **`SESSIONS/`** | ⚠ **已冻结的历史快照（2026-10-15 起不再增补）**：`README.md` = 索引表/统计/内核时间线 + `sessions/YYYY-MM-DD-<名称>.md`。**新会话一律不进本目录**；会话身份与全文检索 = pi 原生会话（`scripts/sess.sh` / `/resume`）。此处保留仅为档案 + `check-sessions.sh` 校验基准 |
| **git 提交史（逐提交）** | **`HISTORY/`** | 提交视角权威：`README.md` = 规范/查询入口（**不写死数字**）+ `days/YYYY-MM-DD.md`（机械生成）。统计现查 `scripts/gen-history.sh --stats` |

### 顶层布局（4 区 + AI 大脑；**逐项 = 机器表**）

> **机器真源 = `versions/layout.tsv`**（人读 `scripts/check-layout.sh --list`），门 = `check-layout.sh`（`check-doctor.sh` §14：
> **每条路径必须在本节出现且磁盘存在**）。规则：**根目录新增条目先登记 `versions/layout.tsv`**，未登记即 FAIL。
> 本节只回答「这个目录能不能删、要不要入库」的**分区级**口径；逐条职责/删除风险读 `RESOURCES/README.md` §3。

| 区 | 顶层条目（与 `layout.tsv` 同源） | 版本控制 |
|---|---|---|
| 入口 | `AGENTS.md` `INDEX.md` `README.md` `PROGRESS.md` `LICENSE` | track |
| 角度文档 | `DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/` `archive/` | track |
| 源码/补丁/工具 | `scripts/` `tools/` `patches/` `patches-userland/` `reference/` `versions/` `packaging/` `initramfs/` `rootfs/` `probes/` `net/` `waydroid-ota/` `restore-259/` `cycle.sh` `elden-net.sh` `.githooks/` `.gitignore` | track |
| 证据/备份 | `reports/`（md 入库，大件 ignore）· `backup/`（**不可再生**：删前必须云盘或 bundle 兜底） | track / ignore |
| 工作区（**可再生成**） | `build/` `out/` `logs/` `bootslot-b/` `env-pass/` `dl-cam/` `wt/` `external/` `geekidos-linux/` `Y700-elden-linux/` `stock-src/` `y700四代工具/` + 软链 `linux` | ignore（`build/` 删前先 bundle + 导 diff） |
| AI 大脑 | `.pi/`（规范/并发/编排/技能/记忆/会话；分工见 `.pi/README.md`） | track |


### 证据层（`archive/`，追加为主）

> 专题档案＝**过程证据**；结论一律以领域层为准，archive 不得被引用为「当前结论」。
> **追加为主**；允许为更正错误 / 回填结果做带日期的最小修订（不改写既有结论口径，权威恒在领域层）。

### 机器可查（无 SQLite，无生成物）

> **项目资产归属（2026-11-02）**：记忆/技能/会话全在仓库内——`.pi/memory/`（记忆 SSOT，`~/.pi/agent/projects-memory/y700-elden` 只是软链，自检 `scripts/check-project-memory.sh`）、
> `.pi/skills/`（项目技能，Pi 按工作目录叠加加载）、`.pi/sessions/`（会话轨迹，ignore）。lane 工作树在 `../wt/`、外部工作区在 `../external/`（均 ignore，`scripts/lane.sh` 默认 `WT_ROOT=<repo>/wt`）。

- 文本搜索：`rg` / `grep`（`PITFALLS/README.md` 找踩坑、`RESOURCES/README.md` 找资源、`TASKS/README.md` 找任务）。
- 会话回忆：pi 原生会话选择器（`/resume`）/ `scripts/sess.sh`；**逐会话快照** `SESSIONS/`、**逐提交史** `HISTORY/`（`scripts/gen-sessions.py` / `gen-history.sh` 再生）。
- 机器账自检：`scripts/check-doctor.sh`（退场入口 / vk 版本账 §5+§5d / manifest §5e / **§5f ABI 敏感项一致性（`.config`↔模块树）** / 静态卫生 /
  **§7 入口文档完整性（围栏·截断·证据指针泄漏）** / **§8 索引↔磁盘对账（编号撞车·索引行超长）** /
  **§9 SESSIONS 快照** / **§10 HISTORY 对账** / **§11 提交钩子生效性** / **§14 顶层布局注册表** /
  **§15 时间序健康（§0 核对日期 vs 最新会话证据；见 §2「时间序裁决」）**）。
  顶层布局真源 = **`versions/layout.tsv`**（项数现查 `scripts/check-layout.sh --list | wc -l`；4 区：入口/文档 · 源码/补丁 · 证据/备份 · 工作区；人读面 = 本节「顶层布局」表，门 = `scripts/check-layout.sh`）。
  **入库前门已接线**（`core.hooksPath=.githooks`）：`pre-commit` 跑 `--staged-fast`（§7/§8/§9/§10/§11/§13/§14，实测亚秒级（量级见 `reports/script-audit-20261105.md`）；§12 内核 config 门不在这一档）。
  全量 `scripts/check-doctor.sh` 现为**并发子门**（`scripts/doctor/`），稳态 **~1.4 s**（旧版单体串行 12.5 s）；口径与实测见 `reports/script-audit-20261105.md`。
- **打包前门**：`scripts/assert-kernel-sane.sh`（config 锚点 / System.map 符号 / UTS 对齐 / 非陈旧 / **§1b ABI 敏感项**，后者调 `scripts/check-abi-config.sh` 比对 SSOT config 的 27 项）。
- 版本对账：**`versions/vk-kernel-identity.tsv`**（构建号 ↔ 内核二进制 ↔ 源提交，含每个镜像的失真标记）。
  它是本目录**唯一入 git 的派生表**（破例理由：兼作版本欠账账本）；由 `scripts/vk-identity.py` 重生成，
  `check-doctor` §5d 强新鲜度（过期即 FAIL）。“vkN 是什么”的口径见 `PITFALLS` #135。

---

## 3. 去哪读（**细节指针**；本节不写状态、不写结论）

> 本文件 §0 = 唯一状态入口；数字 = `TASKS/README.md` §0；设备/镜像 = `DEVICE/README.md` §1.1/§2.2。
> 本节只回答「某个细节去哪找」，不重复任何结论。

| 要查什么 | 去哪 |
|---|---|
| 任务台账 / 未解（Q 表）/ 待办 / 上游化（M 系列） | `TASKS/README.md` §1–§2 / §5 / §4 / §7 |
| 上游投递现状（当前一页） | `reports/upstream-status-20261113.md` |
| 在机内核 / 槽位 / 单元台账 / 存储策略 | `DEVICE/README.md` §1.1 / §2.2 / §3 |
| 动手前的坑 | `PITFALLS/README.md` §0 + 索引 |
| 从原厂到 b 槽直启的操作步骤 | `RUNBOOK-BRINGUP/README.md`（Phase −1…9） |
| 换机缺口 / 资产与 git 边界 | `RESOURCES/README.md` §3.5 / §3 |
| 文档去重执行账 / 审计依据 | `reports/docs-slim-20261114.md`（本轮：入口收敛二轮）、`reports/docs-slim-20261113.md`、`reports/doc-dedup-audit-20261112.md` |

**已定不做 / 搁置（勿重推）**：正文只在 `TASKS` §4「本轮不投入」+ §1 各 ID 行（`G1-26/27/28` 已出列、`G1-10` 无 NFC 硬件、
`G1-30` slim initramfs）与 `RUNBOOK` §0.5（BL 解锁已定稿关闭）；`kexec` 定位见 `TASKS` §4「迭代通道」条。
**两条不变的硬约束**（内核必须自编 / 传感器栈要 forky-sid 级 `iio-sensor-proxy`+`libssc2`）= 正文在 `DEVICE/README.md` §1.1 末条。


**保留但需知道的旧账**：换机缺口（`RESOURCES` §3.5 + `versions/migration-gaps-2026-10-17.tsv`）、
宿主 rootfs 方向（Alpine → Debian/Mobian，2026-10-26 用户定，`reports/mobian-migration-plan-20261021.md` + `TASKS` T14/T17）、
单元台账（`DEVICE` §1）。
---

## 4. 快速入口命令

```bash
cd ~/y700-elden          # ★ 启动入口即此（旧 cd 包装与根目录兼容包装 build.sh/iterate.sh/pack.sh 均已移除 → PITFALLS §15.1）
# 【收尾自检】退场入口 / vk 版本账与内核身份 / manifest 完整性 / 静态卫生（全绿再收工）
scripts/check-doctor.sh
# 【版本对账】“这个 boot.img 里到底是哪个内核” / 重生成对齐表
python3 scripts/vk-identity.py --gate                    # 只看命名/溯源规则结果
python3 scripts/vk-identity.py > versions/vk-kernel-identity.tsv   # 重生成（随后连表一起提交）
# 【脚本账】全量可执行入口清单（live / hist-only / unreferenced；整理轮用，勿手改表）
python3 scripts/static-scan.py --inventory | sed '1d' > versions/scripts-inventory.tsv
# 【动手前 30 秒】引导链类问题（解锁/AVB/降级/GPT/EDL）先查本地既有结论（PITFALLS #87）
grep -rn -iE "unlock|解锁|sn\.img|rollback|testkey|073" \
  .pi/skills/*/references/*.md *.md archive/topics/*.md | grep -v '^Binary'
```

```bash
# 目标形态：b 槽直启 Linux（~5–9 s 进 Phosh），日常不需 fastboot
sudo bash elden-net.sh && ssh -o StrictHostKeyChecking=no root@192.168.7.1
# 内核迭代＝统一入口 scripts/iterate.sh（四档环，细则 RUNBOOK §迭代）
scripts/iterate.sh mod <driver-dir>              # 环0：=m 模块热载 ~30s 不重启（需先应用 fragment-modular）
#   成功判据 = build-id 匹配（脚本会自己打印 ✅/❌ 并在未确认时 rc=1；见 PITFALLS #447）
LOCALVERSION=-debug-vkNN scripts/mod-loop.sh <driver-dir> --reload <mod-name>
#   设备 UTS 与本树 KV 不一致时脚本会 REFUSING；跨 KV 只能用 --bootstrap 或 --allow-mismatch
scripts/iterate.sh kernel VERSION=vkNN           # 全量重编（零写盘快环：kexec 可用，但目标无显示/USB，见 §4「迭代通道」条）
scripts/iterate.sh kernel --flash VERSION=vkNN   # 写回 boot_b（设备写：按 .pi/AGENT-OPS.md 先备份后执行）
scripts/device-lock.sh --status                  # 谁占着设备；并发子代理写操作前必查
# ★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM → 死内核，PITFALLS #162）
./cycle.sh --soft                          # 软回 fastboot（免按电源键）
fastboot boot bootslot-b/boot_b-f2fs-root.img  # 零写盘·持久变体（RAM 内核+磁盘根，有桌面/服务），功能测试用（PITFALLS #93；原 boot_b-clean.img ⚠️MIGRATION-LOST(2026-10-17)，见 RESOURCES §3.5）
fastboot boot <img>                        # 零写盘·纯RAM变体（无桌面/服务）仅内核/引导级验证；先 blank 活跃槽 dtbo 否则卡 logo（PITFALLS #1/#10）
# 新单元开工三件套（先写台账，再备份，再手术）
fastboot getvar serialno; adb shell getprop ro.boot.hwboardid   # → 写进 DEVICE/README.md §2.2
sh scripts/gpt-dump.sh                                          # 打印本单元 backup_lba（禁跨容量档复用）
# b 槽三件套备份：本 ABL **无 fastboot fetch**（实测与报错全文见 PITFALLS #290）
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/boot_b of=/tmp/boot_b.img'  # 再取回；或从官方线刷包解出
python3 scripts/slot-attr.py show                               # 槽位属性（在 GPT attribute，非 misc）
# 设备侧三态判据（显示问题）：NOCARD / STORM / GOOD
scripts/q28-devprobe2.sh          # 在设备上跑（SSH 读全 dmesg + 查 card0）
scripts/trial.sh                  # 一次设备实验 = 一条机器可读记录（reports/trials/，--reset 必填）
```
