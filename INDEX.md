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
   达到上游规范后**按模块向上游提交**（checkpatch/DTC/`dtbs_check` 绿，见 `TASKS/README.md` §7 M1–M5）。
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
   `SESSIONS/` **冻结不写**；`HISTORY/` 由脚本生成**不手写**；`RUNBOOK-BRINGUP/` 目前空壳，需要时再启用。跨角度时写**主角度**一个文件，其余角度补一行指针。
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
| **行为/规范** | **`.pi/AGENT-OPS.md`** | agent **自主优先**（写坏风险先备份，超出预期的错误才上报）、物理干预边界、设备安全纪律、研发纪律、文档写入权限、汇报/时间盒；并发细则见 `.pi/CONCURRENCY.md` |

> 项目描述（机型/目标/设备等价）在 `AGENTS.md`；各角度 `README.md` 不再复述规范与经验。

### 角度文件夹（`README.md` = 权威正文；子目录 = 以会话/单元为单位的记录）

| 角度 | 文件夹 | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE/`** | 机型规格、固件清单与通路、驱动矩阵、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略** |
| **任务 / 进度 / 未解 / 方案** | **`TASKS/`** | **唯一任务台账 + 进度权威**（§0）；G1/C/A 任务（§1–4）；**§5 查漏补缺（GAPS/Q1–Q31）**；**§6 G2 安卓兼容方案**；**§7 上游化（M1–M5）** |
| **资源 / 资产 / 会话** | **`RESOURCES/`** | §1 外部参考 · §2 本地资源 · **§3 文件与资产台账（git 边界/可清理）** · §4 会话检索（pi 原生） |
| **上机手册** | **`RUNBOOK-BRINGUP/`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase −1…9 |
| **开发经验 / 踩坑** | **`PITFALLS/`** | **开发经验唯一入口**：`README.md` = §0 零号纪律 + 索引表（条数以该表实际行数为准，勿在此写死）；正文在 `sessions/NN-*.md`（含 **§15 过时/废弃登记**） |
| **会话档案（逐会话）** | **`SESSIONS/`** | ⚠ **已冻结的历史快照（2026-10-15 起不再增补）**：`README.md` = 索引表/统计/内核时间线 + `sessions/YYYY-MM-DD-<名称>.md`。**新会话一律不进本目录**；会话身份与全文检索 = pi 原生会话（`scripts/sess.sh` / `/resume`）。此处保留仅为档案 + `check-sessions.sh` 校验基准 |
| **git 提交史（逐提交）** | **`HISTORY/`** | 提交视角权威：`README.md` = 规范/查询入口（**不写死数字**）+ `days/YYYY-MM-DD.md`（机械生成）。统计现查 `scripts/gen-history.sh --stats` |

### 证据层（`archive/`，追加为主）

> 专题档案＝**过程证据**；结论一律以领域层为准，archive 不得被引用为「当前结论」。
> **追加为主**；允许为更正错误 / 回填结果做带日期的最小修订（不改写既有结论口径，权威恒在领域层）。

### 机器可查（无 SQLite，无生成物）

- 文本搜索：`rg` / `grep`（`PITFALLS/README.md` 找踩坑、`RESOURCES/README.md` 找资源、`TASKS/README.md` 找任务）。
- 会话回忆：pi 原生会话选择器（`/resume`）/ `scripts/sess.sh`；**逐会话快照** `SESSIONS/`、**逐提交史** `HISTORY/`（`scripts/gen-sessions.py` / `gen-history.sh` 再生）。
- 机器账自检：`scripts/check-doctor.sh`（退场入口 / vk 版本账 §5+§5d / manifest §5e / **§5f ABI 敏感项一致性（`.config`↔模块树）** / 静态卫生 /
  **§7 入口文档完整性（围栏·截断·证据指针泄漏）** / **§8 索引↔磁盘对账（编号撞车·索引行超长）** /
  **§9 SESSIONS 快照** / **§10 HISTORY 对账** / **§11 提交钩子生效性**）。
  **入库前门已接线**（`core.hooksPath=.githooks`）：`pre-commit` 跑 `--staged-fast`（§7/§8/§9，~0.2 s）。
- **打包前门**：`scripts/assert-kernel-sane.sh`（config 锚点 / System.map 符号 / UTS 对齐 / 非陈旧 / **§1b ABI 敏感项**，后者调 `scripts/check-abi-config.sh` 比对 SSOT config 的 27 项）。
- 版本对账：**`versions/vk-kernel-identity.tsv`**（构建号 ↔ 内核二进制 ↔ 源提交，含每个镜像的失真标记）。
  它是本目录**唯一入 git 的派生表**（破例理由：兼作版本欠账账本）；由 `scripts/vk-identity.py` 重生成，
  `check-doctor` §5d 强新鲜度（过期即 FAIL）。“vkN 是什么”的口径见 `PITFALLS` #135。

---

## 3. 现状速览（指针，不复述状态）

> **SSOT**：任务状态、完成度、样本数一律以 `TASKS/README.md` §0/§1/§5 为准；单元与镜像形态以 `DEVICE/README.md` §1.1/§2.2 为准。
> **本节只回答「现在还没解决什么」，任何数字与当前口径都不在此维护**（见 §2 公开层豁免）。

- **⚠️MIGRATION-LOST（2026-10-17 换机）**：内核 git 线 `vk87–vk126`、`build/` 资产树、`out/*.img`、`logs/`、`tools/` 未随迁（判定不可再生/代价高）；登记与重建路径见 `RESOURCES/README.md` §3.5 + `versions/migration-gaps-2026-10-17.tsv`。
  **重建账（2026-10-17 审计）**：文档/补丁/配置/证据近乎无损，真损失 = 提交史 + 镜像产物；**在机镜像已于当日晚 P0 抢救到主机**（`boot_b` sha `78a2beb1…` + 1497 `.ko` + 207 项配置 → `backup/HA2EXB0E-16+512/device-rescue-20261017/`，见 `reports/device-rescue-and-q28-m1-badboot-20261017.md`）；
  分级与顺序（P0 抢救设备资产 → P1 修身份表 → P2 装 clang/dtc → P3 重放 M1-7.3 → P4 重编日常镜像）见 `reports/migration-rebuild-audit-20261017.md`；
  会话记录 `TASKS/sessions/2026-10-17-换机后重建审计-邮箱分诊.md`。**邮箱通道可用**，未处理的上游往来 5 条见 `reports/mail-triage-20261017.md`。
  **★ 当前待办入口 = `TASKS/README.md` §4**：T1–T8/T10/T12/T13 已结项（2026-10-23）；**仍开放 = T9（suspend 掉电率，等 `HS-PHY not in L2` 与 hwmon 两条非阻塞告警收尾）、T11（宿主内存，等你在 BIOS/硬件侧动作）、T14（用户态固化→Mobian 迁移，第一步已落）**；**T15（f2fs 根迁移，路线 A）已于 2026-10-25 真机完成**；**T16（驱动模块化迁到 7.3 日常线 + Mobian 首批物料）2026-10-26 第一步完成（零写盘上机）**。现行口径在该节顶部「收尾轮次纪律（2026-10-23 用户定）」——**需要物理 POR 的样本一律排最后**、**TF 卡暂时不做**、**Q28 只由 agent 取 2 发、其余交用户在机旁完成**。

- **未解（3 项，按影响排序）**：① Q28 显示间歇失败（日常线 vk152，真 POR 已 3 发 GOOD、还差 5 发）；② Q24 熄屏×相机（根因已指名 = 7.2 缺上游 `skip retention`，已停止采样）；③ 进 GUI 后整机卡死（`PITFALLS #106`）。
  **新增待办 Q32 = 暖起 vs 冷起差异**（静态预研已落盘，指向「ABL 交接 framebuffer + 复位动作」而非「暖/冷」本身）。 **2026-10-23 深夜：Q32 取证工具已落地 + 试点取证 + 判据更正**（复位深度只能从 pstore/ramoops 取；在机「ABL 留了活显示」已实测确认）→ `reports/q32-kickoff-20261023.md`；三臂仍未执行。**2026-10-24：三臂已跑完 5 发（W1×2 / C1×2 / W2×1）全 GOOD ⇒ 暖/冷不是主变量，Q32 并入 Q28** → `reports/q32-matrix-20261024.md`。
  **★2026-10-24：Q28 按「已规避（运营线 vk152）」结项** —— 代码级修复（0154/0155/两修）+ 看门狗（ON、从未触发）+ 三态探针；POR 5/5、暖复位 3/3 全 GOOD（8/8 无坏发），但用户决定**不再补样本、不再挖根因**；复启条件三条写死在报告里 → `reports/q28-workaround-closeout-20261024.md`。**口径 / 样本 / 触发 / 下一步只读** `TASKS/README.md` §5 Q28/Q24/Q32 与 `PITFALLS #106`；在机镜像 `boot_b` 见 `DEVICE/README.md` §1.1。
- ✅ **已解（近期）**：Q31 M1-7.3 显示回归（2026-10-14 E1b）——见 `TASKS/README.md` §5 Q31 / §7。
- **已关闭 / 搁置**（不再占未解）：Q26 WiFi、G1-6 TF 卡、G1-34 重力/自动旋转、C10 Waydroid 马达透传（PITFALLS §29/§30）。状态与证据见 `TASKS/README.md` §0/§5。
- **未开工 / 进行中**：上游化 M1–M5（`TASKS/README.md` §7）、G1-8 CPU/GPU 基准（`TASKS/README.md` §1）。细节只读对应节，本文件不复述。
- **已定不做 / 搁置 / 取消**（勿重推）：G1-26/27/28（已收口）、G1-29 UEFI、G1-10 NFC、G1-30 slim initramfs；
  **kexec 已不再是「不做」**（2026-10-24：交接/掉电/ITS 三个阻塞全关，修法已上游投递 M9）——但**显示与 USB 继承态未复位**
  （目标里无 `card0`、`no UDC`，~157 s 被 Q28 看门狗重启），所以定位仍是**「不需显示/网络的调试快环」**，见 `TASKS/README.md` §4 第 10 条；
  **宿主 rootfs 切 glibc / systemd = 用户 2026-10-26 定的方向（过渡到 Mobian），不再是「勿重推」项**：
  2026-10-11 的「不切」裁定针对的是「为换而换」（当时卡点全在内核/显示链，换 init 无收益，证据
  `reports/libc-musl-vs-glibc-20261011.md`、`reports/init-systemd-vs-openrc-20261011.md`）；2026-10-26 用户明确要求
  「摆脱 Alpine 依赖、逐渐过渡到 Mobian」⇒ 该裁定被用户指令覆盖，路径与成本以
  `reports/mobian-migration-plan-20261021.md`（S0–S7）为准，已完成项见其 §4 的状态标记。
  **仍未变的两条硬约束**：① 内核必须自编（Debian 任何 `linux-image` 都缺本机板 DTS）；② 必须有 forky/sid 级
  `iio-sensor-proxy`（trixie 3.7 无 SSC 后端）+ `libssc2`，否则传感器栈直接死。
- **内核分界线**：口径在 `TASKS/README.md` §4。
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
scripts/iterate.sh kernel VERSION=vkNN           # 全量重编（零写盘快环：kexec 可用，但目标无显示/USB，见 §4 第 10 条）
scripts/iterate.sh kernel --flash VERSION=vkNN   # 写回 boot_b（设备写：按 .pi/AGENT-OPS.md 先备份后执行）
scripts/device-lock.sh --status                  # 谁占着设备；并发子代理写操作前必查
# ★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM → 死内核，PITFALLS #162）
./cycle.sh --soft                          # 软回 fastboot（免按电源键）
fastboot boot bootslot-b/boot_b-clean.img  # 零写盘·持久变体（RAM 内核+磁盘根，有桌面/服务），功能测试用（PITFALLS #93）
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
