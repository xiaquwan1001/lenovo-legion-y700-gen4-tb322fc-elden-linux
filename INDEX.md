# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：本文件 §1（使命）→ §2（文档结构）→ §3（现状）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录 = 入口 `INDEX.md` + 项目身份 `AGENTS.md` + 公开 `README`/`PROGRESS`，**7 个角度文件夹**（`DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/`），各自 `README.md`（策展 SSOT）+ `sessions/`（会话进度）；标准见 §2。
> 2026-10-03：git 纳管 + 文档收敛（12→6）；自检 `scripts/check-doctor.sh`；不再有 SQLite/生成物。

---

## 1. 使命与范围（8 行）

1. **机型唯一**：只研究 **TB322FC / elden / SM8750(P)**；不做别的机型移植。研究面 = 让本机在主线 Linux 上功能完整。
2. **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = **容量**（内存/UFS → GPT 数值）。
   身份 = `(SN, hwboardid, 容量)`；**"新机/旧机"不是角色**，**任务按单元当前状态分派**。
3. **G1 完整 Linux + 上游化**：跑**功能健全的 Linux**，**正常驱动原厂全部固件**（ADSP/CDSP/WCN/GPU/触屏/触觉/功放/tplg/相机…）；
   达到上游规范后**按模块向上游提交**（checkpatch/DTC/`dtbs_check` 绿，见 `TASKS/README.md` §7 M 系列，以 §7 为准）。
4. **G2 安卓容器**：**无 Android 宿主**下运行安卓（主路线 Waydroid，备胎 redroid）；核心验收 = **可用性 + 风控/完整性等级**：
   GMS 登录、**Play Integrity / SafetyNet**、Widevine 能做到哪一级（**取证判定，不预设"不可能"也不承诺**；见 `RESOURCES/README.md` §1.3、`TASKS/README.md` §6）。
5. **G3 x86 模拟运行**：以 **Steam 游戏**为验收载体，跑通 x86 用户态/游戏（Box64 + Wine/Proton 线）。
6. **拓展（非主线）**：**UEFI 间接引导**、**Gunyah 高通虚拟化做 VM**——不阻塞 G1–G3，现状/裁决见 `TASKS/README.md` §4/§5。
7. **Linux 存储容量不固定**：按项目体量估算后一次给足（`DEVICE/README.md` §3），并可回收 Android 专属分区扩容。
8. 术语：设备称 **U1 / U2**；备份目录 `backup/<SN>-<容量档>/`；禁用 `new-tablet` 与"两轨分机"旧口径。

---

## 2. ★ 文档结构（文件夹＝角度；会话进度进 sessions/）

> **文档 v2（2026-10-14 起）**：每个**角度** = 一个**文件夹**，内含 `README.md`（该角度**策展 SSOT 正文**，唯一维护面）+ `sessions/`（**以会话为单位**的进度文件）。
> **会话进度文件**：命名 `YYYY-MM-DD-<主题>.md`（同日多主题加 `-2`）；文件头记 日期 / pi 会话 id / 主题 / 结论 / 证据指针 / **★SSOT 待并入**。
> **记录时的区分度**（取代自检脚本的计数/索引）：写入时就靠 文件夹(角度) + 文件名(日期+主题) + pi 会话 id 区分。
> **会话检索** = pi 原生项目会话（`.pi/sessions/*.jsonl`，项目级 `sessionDir`）：`scripts/sess.sh` / `/resume`；不手抄索引表。
> **SSOT**：数字/结论只在该角度 `README.md` 维护，其余用链接；跨会话新增先落 `sessions/`，由宿主择机并入 `README.md`。
> **推荐阅读顺序**：本文件 → `.pi/AGENT-OPS.md`（做事规范）→ `TASKS/README.md`（任务/进度/未解）→ `PITFALLS/README.md`（动手前扫）→ 需要时再进 `DEVICE/`/`RESOURCES/`/`RUNBOOK-BRINGUP/`。

### ★ 会话结束时写什么（唯一规则，8 条）

> 目标：**增量记录**——每次会话只新增文件，不改旧文件；状态数字只有一处出口。

1. **只写 1 个新文件**：`<角度>/sessions/YYYY-MM-DD-<主题>.md`；同一会话多主题加 `-2`。**不新建目录、不改已存在的 sessions 文件、不建索引表**。
2. **可用角度 4 个**：`TASKS/`（任务/进度/未解）、`PITFALLS/`（踩坑）、`DEVICE/`（单元/镜像状态）、`RESOURCES/`（资产/资源）。
   `SESSIONS/` **冻结不写**；`HISTORY/` 由脚本生成**不手写**；`RUNBOOK-BRINGUP/` 已有正文（Phase −1…9 + `sessions/`），属可写角度。跨角度时写**主角度**一个文件，其余角度补一行指针。
3. 文件头只写 6 个字段：`日期 / pi 会话 id / 主题 / 结论 / 证据指针 / ★SSOT 待并入`。`pi 会话 id` 取 `$PI_SESSION_ID`。
4. **状态数字只改一处**：`TASKS/README.md` §0（总览）/ §5（Q 行）。其它任何地方**不写状态数字**，只写指针。
5. **会话全文不复述、不复制**——它就在 `.pi/sessions/*.jsonl`；文件里只放「结论 + 指向证据的路径/命令」。
6. **索引只放一句话主题**：`PITFALLS/README.md` 的索引行 ≤800 B，结论/命令/数字一律在正文。超长会被 `check-doctor §8` 判 FAIL。
7. **不写死计数**：任何「共 N 条 / N 个文件 / N 个提交」都必须现查（`scripts/gen-history.sh --stats`、`ls`、`check-doctor §8`）。写死必漂，且漂了没人发现。
8. **收尾判据**（`.pi/AGENT-OPS.md` §5）：产物落盘 + SSOT 同步 + `check-doctor.sh` **FAIL=0** + `git commit` + 工作区干净。


### 入口（唯一，仍是文件）

| 文件 | 装什么 |
|---|---|
| **`INDEX.md`** | 使命与范围、文件夹地图、现状快照、快速命令、专题档案索引 |

### ★ 根目录四文件的职责边界（单一事实源；2026-10-15 收敛）

> 收敛前：机型规格出现 4 处、G1–G3 目标在 4 个文件各复述一遍 ⇒ 必然漂移（实测 `README.md`
> 的机型表与 `AGENTS.md` 重复、目标段与 `INDEX.md` §1 重复）。现按「一条事实只有一个正文位置」
> 收敛如下，**其余位置一律只给链接**：

| 文件 | 唯一职责（正文位置） | 不得复述 |
|---|---|---|
| **`AGENTS.md`** | **项目身份**：机型唯一性、G1–G3 目标定义与优先级、核心原则（设备等价/存储/SSOT） | 不写进度数字 |
| **`INDEX.md`**（本文件） | **路由**：使命 8 行、文件夹地图与 SSOT 口径、现状指针、快速命令 | 不写状态数字（指向 `TASKS` §0） |
| **`README.md`** | **公开门面**：面向 GitHub 读者的定位、免责/许可、快速开始 | 机型表/目标只留速查副本 + 指向 `DEVICE`/`AGENTS` |
| **`PROGRESS.md`** | **公开时间线**：诚实进度叙事（含被推翻的结论） | 不写权威台账（指向 `TASKS`） |

细节（机型规格、分区、单元台账）以 `DEVICE/README.md` 为准；状态数字以 `TASKS/README.md` §0 为准。

### 1 分钟版（新人 / 第一次会话）

1. **本文件 §1**（使命 8 行）→ 知道「在做什么、不做什么」。
2. **`TASKS/README.md` §0**（总览表）→ 知道「做到哪、什么卡着」。
3. **`PITFALLS/README.md` §0**（零号纪律 4 条）→ 知道「动手前必须先做什么」。

需要做事时再按下方文件夹按需展开；完整规范见 `.pi/AGENT-OPS.md`。

### 规范入口（agent 行为唯一入口）

| 入口 | 文件（权威） | 装什么 |
|---|---|---|
| **行为/规范** | **`.pi/AGENT-OPS.md`** | agent **自主优先**（写坏风险先备份，超出预期的错误才上报）、物理干预边界、设备安全纪律、研发纪律、文档写入权限、汇报/时间盒；并发细则见 `.pi/CONCURRENCY.md`，三层编排（总管/一级角色/二级叶级）见 `.pi/ORCHESTRATION.md` |

> 项目描述（机型/目标/设备等价）在 `AGENTS.md`；各角度 `README.md` 不再复述规范与经验。

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

### 顶层布局（4 区 + 注册表；新增顶层条目必须先登记）

> **机器真源 = `versions/layout.tsv`**，门 = `scripts/check-layout.sh`（`check-doctor.sh` §14）。
> 规则：**根目录新增任何条目，先登记 `versions/layout.tsv`，再在本表加一行**；未登记即自检 FAIL。
> 分区的意义是回答「这个目录能不能删、要不要入库」：`work/` 全是可再生成的构建/日志/外部工作区，
> `evidence/` 里的 `backup/` 是不可再生件（删前必须先云盘或 bundle 兜底），`src/` 才是随代码走的资产。

| 区 | 顶层条目 | 版本控制 | 职责（详情指向领域层） |
|---|---|---|---|
| 入口 | `AGENTS.md` | track | 项目身份：机型唯一性、G1–G3 目标与优先级、核心原则 |
| 入口 | `INDEX.md` | track | 唯一入口：使命/布局/路由/现状指针/快速命令 |
| 入口 | `README.md` | track | 公开门面（面向 GitHub 读者） |
| 入口 | `PROGRESS.md` | track | 公开时间线（诚实进度叙事，非权威数字） |
| 入口 | `LICENSE` | track | 许可 |
| 角度文档 | `DEVICE/` | track | 设备状态与描述（规格/固件/驱动矩阵/单元台账/存储策略） |
| 角度文档 | `TASKS/` | track | 唯一任务台账 + 进度权威（§0 总览 / §5 未解 / §7 上游化） |
| 角度文档 | `RESOURCES/` | track | 外部参考 + 本地资源 + 文件与资产台账（§3） |
| 角度文档 | `RUNBOOK-BRINGUP/` | track | 上机手册（Phase −1…9） |
| 角度文档 | `PITFALLS/` | track | 开发经验唯一入口（§0 纪律 + 分类正文） |
| 角度文档 | `SESSIONS/` | track | 逐会话档案（2026-10-15 起冻结，只读） |
| 角度文档 | `HISTORY/` | track | 逐提交史（scripts/gen-history.sh 机械生成，不手写） |
| 角度文档 | `archive/` | track | 过程证据（追加为主；不得作为当前结论引用） |
| 证据/备份 | `reports/` | track | 报告与活跃证据工作区（md 入库；大件按 .gitignore 排除） |
| 证据/备份 | `backup/` | ignore | 原厂固件/分区 dump/内核 bundle/官方线刷包（不可再生，见 RESOURCES §3） |
| 源码/补丁/工具 | `scripts/` | track | 脚本全集（构建/刷机/诊断/门禁） |
| 源码/补丁/工具 | `tools/` | track | 第三方或自研小工具（avbtool/mkbootimg/l2-extract…） |
| 源码/补丁/工具 | `patches/` | track | 内核补丁与 config 快照（内核进度的权威文本） |
| 源码/补丁/工具 | `patches-userland/` | track | 用户态（Phosh/phoc）补丁与构建/安装脚本 |
| 源码/补丁/工具 | `reference/` | track | 外部同机型/厂商资料快照与裁决 |
| 源码/补丁/工具 | `versions/` | track | 机器对账派生表（vk 身份/registry/布局注册表） |
| 源码/补丁/工具 | `packaging/` | track | 用户态解耦真源（manifest/services/deps） |
| 源码/补丁/工具 | `initramfs/` | track | initramfs 重建输入（init + busybox） |
| 源码/补丁/工具 | `rootfs/` | track | rootfs 覆盖物与设备侧还原副本 |
| 源码/补丁/工具 | `probes/` | track | 设备侧诊断探针源码 |
| 源码/补丁/工具 | `net/` | track | 网络小资产 |
| 源码/补丁/工具 | `waydroid-ota/` | track | Waydroid OTA 小资产 |
| 源码/补丁/工具 | `restore-259/` | track | 恢复说明（二进制不入库） |
| 源码/补丁/工具 | `.githooks/` | track | 提交钩子（core.hooksPath=.githooks） |
| 源码/补丁/工具 | `cycle.sh` | track | 软回 fastboot 快环脚本 |
| 源码/补丁/工具 | `elden-net.sh` | track | USB 网络（RNDIS/ssh 通道） |
| 源码/补丁/工具 | `.gitignore` | track | 版本控制边界 |
| 工作区（ignore） | `build/` | ignore | 内核构建树/独立仓/worktree（含未提交改动，删除前必须先 bundle + 导 diff，见 RESOURCES §3） |
| 工作区（ignore） | `out/` | ignore | 构建产物（*.manifest 入库） |
| 工作区（ignore） | `logs/` | ignore | 串口/构建/agent 日志 |
| 工作区（ignore） | `bootslot-b/` | ignore | 自签 b 槽包（含 avb 私钥，禁止入库） |
| 工作区（ignore） | `env-pass/` | ignore | 过环境里程碑件 |
| 工作区（ignore） | `dl-cam/` | ignore | 相机 provider 交叉编译工作区（部分纳管） |
| 工作区（ignore） | `wt/` | ignore | lane git worktree（scripts/lane.sh WT_ROOT） |
| 工作区（ignore） | `external/` | ignore | 外部构建工作区（$HOME 同名软链指回此处） |
| 工作区（ignore） | `geekidos-linux/` | ignore | 上游内核 clone（GEEKiDoS/linux v7.2-elden） |
| 工作区（ignore） | `Y700-elden-linux/` | ignore | 旧迭代上游 clone |
| 工作区（ignore） | `stock-src/` | ignore | 联想 GPL 源码 clone |
| 工作区（ignore） | `y700四代工具/` | ignore | 厂商工具与解锁工具包 |
| 工作区（ignore） | `linux` | track | 目录约定软链 -> geekidos-linux |
| AI 大脑 | `.pi/` | track | AI 大脑：行为规范/并发/编排/技能/记忆/会话（分工见 .pi/README.md） |

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
  **§9 SESSIONS 快照** / **§10 HISTORY 对账** / **§11 提交钩子生效性** / **§14 顶层布局注册表**）。
  顶层布局真源 = **`versions/layout.tsv`**（46 项，4 区：入口/文档 · 源码/补丁 · 证据/备份 · 工作区；人读面 = 本节「顶层布局」表，门 = `scripts/check-layout.sh`）。
  **入库前门已接线**（`core.hooksPath=.githooks`）：`pre-commit` 跑 `--staged-fast`（§7/§8/§9，~0.2 s）。
- **打包前门**：`scripts/assert-kernel-sane.sh`（config 锚点 / System.map 符号 / UTS 对齐 / 非陈旧 / **§1b ABI 敏感项**，后者调 `scripts/check-abi-config.sh` 比对 SSOT config 的 27 项）。
- 版本对账：**`versions/vk-kernel-identity.tsv`**（构建号 ↔ 内核二进制 ↔ 源提交，含每个镜像的失真标记）。
  它是本目录**唯一入 git 的派生表**（破例理由：兼作版本欠账账本）；由 `scripts/vk-identity.py` 重生成，
  `check-doctor` §5d 强新鲜度（过期即 FAIL）。“vkN 是什么”的口径见 `PITFALLS` #135。

---

## 3. 现状速览（指针，不复述状态）

> **SSOT**：任务状态、完成度、样本数一律以 `TASKS/README.md` §0/§1/§5 为准；单元与镜像形态以 `DEVICE/README.md` §1.1/§2.2 为准。
> **本节只回答「现在还没解决什么」，任何数字与当前口径都不在此维护**（见 §2 公开层豁免）。

- **⚠️MIGRATION-LOST（2026-10-17 换机）**：登记与重建路径只读 `RESOURCES/README.md` §3.5 与 `versions/migration-gaps-2026-10-17.tsv`（当时的重建账与 P0–P4 顺序是快照，已下沉 `TASKS/sessions/2026-11-02-INDEX现状速览下沉.md`）。
- **去哪读（本节唯一职能）**：未解/开放集 = `TASKS/README.md` §5（Q 表，含 Q28/Q24/Q32 的样本数与复启条件，另见 `PITFALLS #106`）；待办 = `TASKS/README.md` §4；进度与里程碑 = `PROGRESS.md` §1/§2；上游化与投递 = `TASKS/README.md` §7 的 M 行 + 当前一页 `reports/upstream-status-20261105.md`（取代 `-20261029`；投递解冻由用户按批放行，agent 不等回复）；设备在机态与单元台账 = `DEVICE/README.md` §1.1/§2.2；换机缺口 = `RESOURCES/README.md` §3.5；内核分界线 = `TASKS/README.md` §4。
- **kexec**：不在「不做」之列，定位 = 不需显示/网络的调试快环；**当前口径只读** `TASKS/README.md` §4「当前口径 → 迭代通道」条与 §7 的 M9 / M9-收口 行（全过程在 `TASKS/sessions/2026-11-03-TASKS-§4-待办沿革.md`）。
- **宿主 rootfs（Alpine → Debian/Mobian、systemd）**：用户 2026-10-26 定的方向，**不是「勿重推」项**；路径与成本只读 `reports/mobian-migration-plan-20261021.md`（S0–S7，完成项见其 §4 状态标记）与 `TASKS/README.md` T14/T17。
- **两条不变的硬约束**：① 内核必须自编（Debian 任何 `linux-image` 都缺本机板 DTS）；② 必须有 forky/sid 级 `iio-sensor-proxy`（trixie 3.7 无 SSC 后端）+ `libssc2`，否则传感器栈直接死。
- **已定不做 / 搁置 / 取消**（勿重推）：G1-26/27/28（已收口）、G1-10 NFC、G1-30 slim initramfs；
  **G1-29 UEFI 不在「勿重推」之列** —— 路线 A 首轮（2026-10-05）失败后曾搁置，**2026-11-01 用户放行恢复推进**，当前口径只读 `TASKS/README.md` §5（**11-03/11-04 块**；11-01/11-02 块已下沉到 `TASKS/sessions/2026-11-02-UEFI历史块归档.md`）：11-04 晚块 = 卡点定位到内层 FV 的 LZMA 段解码失败；`reports/uefi-payload-execution-20261104.md`、`reports/uefi-posctrl-20261103-summary.md` 为两条主报告。
- **单元**：U1 / U2 台账见 `DEVICE/README.md` §1；解锁议题已定稿关闭（`RUNBOOK` §0.5 + `archive/topics/复盘-2026-10-03-BL解锁.md`），不要重新论证。

---

## 4. 快速入口命令

```bash
cd ~/y700-elden          # ★ 启动入口即此（旧 cd 包装与根目录兼容包装 build.sh/iterate.sh/pack.sh 均已移除 → PITFALLS §15.1）
# 【收尾自检】退场入口 / vk 版本账与内核身份 / manifest 完整性 / 静态卫生（全绿再收工）
scripts/check-doctor.sh
# 【版本对账】“这个 boot.img 里到底是哪个内核” / 重生成对齐表
python3 scripts/vk-identity.py --gate                    # 只看命名/溯源规则结果
python3 scripts/vk-identity.py > versions/vk-kernel-identity.tsv   # 重生成（随后连表一起提交）
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
# b 槽三件套备份：本 ABL **无 fastboot fetch**（`Unable to get max-fetch-size`，PITFALLS #290）
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/boot_b of=/tmp/boot_b.img'  # 再取回；或从官方线刷包解出
python3 scripts/slot-attr.py show                               # 槽位属性（在 GPT attribute，非 misc）
# 设备侧三态判据（显示问题）：NOCARD / STORM / GOOD
scripts/q28-devprobe2.sh          # 在设备上跑（SSH 读全 dmesg + 查 card0）
scripts/trial.sh                  # 一次设备实验 = 一条机器可读记录（reports/trials/，--reset 必填）
```
