# 项目进度整理 — 2026-11-07（第六轮：漂移 / 过时 / 上游对账）

> 派单：「整理一下项目进度与文档，检查漂移和过时。」
> 本轮**只读 + 只改文档与 `.gitignore`**：不碰设备、不构建、不发信、不改内核/补丁内容。
> 复核时刻 = 2026-11-07 18:30 CST（10:30Z）。证据全部为**本轮现查**（doctor / 计数脚本 / patchwork API / `git status`），不引旧报告数字。

---

## §0 一页结论（先数字）

| 项 | 本轮实测 | 与 SSOT 关系 |
|---|---|---|
| `scripts/check-doctor.sh` | **FAIL=0 / WARN=4**（改前改后一致；资产引用 checked 367 → **369**） | ✅ |
| `scripts/check-progress-counts.sh` | **G1 34/36**（38 ID，❌2）、**G2 8/12** | ✅ 与 `TASKS` §0 一致**未漂** |
| `git status` | 改前 **16 个未跟踪二进制**（51 MB，`reports/artifacts/uefi-20261107R39R40-p45|R41-p46`）⇒ 改后**干净** | ⚠ 已修（D1） |
| 设备 | 11-07 深夜终态 = **`boot_b` 已写 `vk185-adsp`**（持久，重启即回它）；`DEVICE` §1.1 首条即此 | ✅ 无漂 |
| patchwork（现拉 API） | dwc3 v8：`linux-usb 3/3 new` + devicetree `1/3 needs-ack`；wl2868c **v9**：`arm-msm 2/2 new` + devicetree `1/2 needs-ack`；M10 = `new` | 🆕 v9 状态从未入账 ⇒ 已补 |
| 我方未答项 | **0**（11-04 批 dwc3 2×High、wl2868c 2×changes-requested 已由 v8/v9 还完） | ✅ 与 `TASKS` §7 头一致（但 §7 头原写 11-05 口径 ⇒ 已刷新） |

**一句话**：进度数字与门禁都没漂；漂的是**「最新一轮成果没回写入口」**（UEFI 间接引导已打通，但 `TASKS` §0/§1 与 `INDEX` §3 的「当前口径」仍指着 11-06 崩溃块）、
**「已投递仍写未投」**（wl2868c v9 的 patch README + `TASKS` M3 行）、**「已解的问题仍挂未解」**（Q25 按「UFS 过不去 ⇒ 搁置」）与**「构建产物没被 gitignore 覆盖」**（工作区不干净，违反收尾判据 ⑤）。

---

## §1 漂移清单（P1 = 会误导决策）

| # | 位置 | 漂移 | 证据 | 处置 |
|---|---|---|---|---|
| D1 | `.gitignore`（UEFI 世代归档段） | 2026-11-07 p45/p46 两个 artifacts 目录**无规则覆盖** ⇒ `git status` 16 个未跟踪二进制（51 MB：`SM8750_EFI.fd`/`kernel.bin`/`payload-*`/`build.log`/`*.img`），工作区不干净 | `git status --porcelain` 16 行；`git check-ignore` 对 `.fd`/`build.log`/`.img` 均 NOT IGNORED | ✅ **已改**：按既有口径（只入库 `BootShim.bin` + `manifest.txt` + `SHA256SUMS` + recipe）加 12 条 glob；现 `git status` 仅剩本轮文档改动 |
| D2 | `TASKS/README.md` §0 line 18（拓展行） | 「UEFI…当前口径只读 §5 的 **2026-11-06 块**」 | §5 最新块 = `### 2026-11-07（深夜，p45→p46）`（UEFI 间接引导打通） | ✅ **已改** → `2026-11-07「p45→p46」块（间接引导已打通，剩 BDS 菜单与绕开 boot.img）` |
| D3 | `TASKS/README.md` §1 **G1-29** 状态格 | 开头仍写「🟡 进行中（…当前口径只读 §5 的 2026-11-06 块…）」、结尾仍写「当前口径与下一步只读 §5 的 2026-11-06「夜·二」块（PC 归因成功：崩在 `SerialPortWrite`）」——把**已打通**的大进度描述成「还在查崩点」 | `reports/uefi-p46-kernel-boot-success-20261107.md`；`TASKS` §5 11-07 块；`reports/trials/20261107T101141Z-uefi-p46-kernel-boot.json` | ✅ **已改**：开头 = 「2026-11-07 ✅ 间接引导已打通…剩 BDS/GRUB 菜单与绕开 boot.img」；结尾补 p45→p46 机理（EB 后 `BlkIo->WriteBlocks=0` ⇒ `blr 0`）+ 剩余验收口径（仍经 `boot_b`） |
| D4 | `INDEX.md` §3「已定不做 / 搁置 / 取消」条 | 同 D2 的旧指针，且主报告列表停在 11-06 两块 | 同上 | ✅ **已改**：指向 11-07 块 + 主报告 `reports/uefi-p46-kernel-boot-success-20261107.md`，旧两块降为「沿革」 |
| D5 | `TASKS/README.md` §5 **Q25** 行 | 标题与结论仍是「路线 A 为何卡在 UFS 初始化 ⇒ 裁决维持搁置 ⇒ 关联 **G1-29（已搁置）**」；实际 11-04 已 `BlockIo=119`（UFS 枚举通）、11-07 打通到起内核 | `TASKS` §5 `### 2026-11-04（深夜）…UFS 枚举成功（BlockIo=119）`；`reports/uefi-p46-kernel-boot-success-20261107.md` | ✅ **已改**：标 ✅ 已解（2026-11-04/11-07），旧「维持搁置」划掉并注明作废（11-01 放行 → 11-04 → 11-07）；`0x402` 反汇编定论降为 `#12` 回帖素材 |
| D6 | `TASKS/README.md` §7 头「**未答项（2026-11-05 现查）**」 | 写「11-04 批 2 High + 8 Medium、Krzysztof 两条 changes-requested ⇒ **下一次发信前先答**」——这四条**已全部还完**（v8/v9） | patchwork 现拉（§0 表）；`TASKS` §7 M3 行「sashiko 已回 found no issues」 | ✅ **已改**：换成 11-07 现查口径（我方无未答项 + 三系列当前 patchwork 状态） |
| D7 | `TASKS/README.md` §7 **M3** 行 | wl2868c v9 仍写「**未投，等用户放行**」；实际 2026-11-07T01:50Z 已投 3 封全 250 | `out/mail-20261107/send-wl2868c-v9.log`（`Result: 250` ×3）；`TASKS/sessions/2026-11-07-7.3.1重基与UEFI-p37.md` §结论 1 | ✅ **已改**：写「✅ 已投（3 封 250、cover `<20261107015014.22374-1-…>`）+ patchwork 现查状态」 |
| D8 | `patches/upstream/wl2868c-v9-20261107/README.md` | 标题「**未投递**」、状态「等用户批准投递」、待办「是否发 v9」、边界「没有发任何邮件」——四处都与事实相反 | 同上（send log） | ✅ **已改**：标题/状态/待办/边界四处改为已投 + 投后 patchwork 复核；保留备料门禁账不动 |
| D9 | `PROGRESS.md` §1 时间线 | 末行停在 **2026-11-06**；11-07 四件大事（日用基线 G1-37 + `CONFIG_ZRAM`、7.3.1 重基并写 `boot_b`、UEFI 打通、上游 v9+M10）全缺 | `TASKS` §1 G1-37 / §5 11-07 块；`DEVICE` §1.1；patchwork | ✅ **已补**：+4 行（每行一句结论 + 证据指针）；§2 G2 行补 **C11 触屏中文输入法** |
| D10 | `reports/upstream-status-20261105.md` | INDEX/`TASKS` §7 都称其为「当前一页」，但它只到 11-06 块；11-07 的两封新投与「欠账清零」无记录 | 同上 | ✅ **已补 §6**「2026-11-07 增量」（v9 / M10 / 欠账清零 / 未做边界），文件名不变以免三处指针连带改 |
| D11 | `README.md` §3 G1 行（公开门面） | 写「B5 bonded-DSI 重构与 aw86927 系列已过门禁、**待批投递**」——aw86927 v2 已于 2026-10-27 投出（`[PATCH 0/5]`，`/linux-input/` 6/6 归档）；B5/M6 v2 是**按维护者条件封存**、不是「待批」 | `PROGRESS.md` §6 第 5 条（10-27 投递事实）；`TASKS` §7 M6 行（三条复启条件） | ✅ **已改**：改为「dwc3 / wl2868c 已到 v8 → v9、aw86927 v2、M10 已投；B5（M6）v2 按复启条件封存」 |

| D12 | 本轮自己踩的坑：改 `TASKS` §1 G1-29 状态格时用 `✅` 加重语气 | `check-progress-counts.sh` 按 **emoji 优先级**取标记（不看位置）⇒ G1 立刻从 **34/36 变 35/36**，与 §0 手写的 34/36 打架；`check-doctor` 的 `STALECOUNT` 门不管这条 | `scripts/check-progress-counts.sh` 的 `scan()`（`EMOJI` 列表即优先级） | ✅ **已修**：状态格改回纯文字（「间接引导已打通（未收口…）」），计数复归 34/36；**并登记为 `PITFALLS #548`**（含同族第二条：正文里 `N. **粗体**` 会被 doctor §8d 当成 `#N` 定义 ⇒ 用 `-` 列表） |

---

## §2 登记但不改（附理由）

| 项 | 位置 | 为什么不改 |
|---|---|---|
| `reports/doc-audit-20261030-v2.md`、`reports/doc-audit-20261106.md` 里的旧行号/旧措辞 | `reports/` 历史审计 | **报告是快照**，按 `AGENT-OPS` §4 的「带日期最小修订」只在其自身记录当时的行号；改它等于改写历史判读 |
| `PROGRESS.md` §6 第 8 条「UEFI issue #12 回帖（等你点头）」 | 公开时间线 | 同 11-06 轮 D3 判例：该块**自带 2026-10-28 日期**，属历史叙述；改它破坏「时间线不改写」。现状指针在 `TASKS` §7 / `INDEX` §3 |
| 其余 ~38 个 `patches/upstream/*/README.md` 的「未投递」字样 | 补丁资产目录 | 逐目录核投递状态是**独立的一轮对账活**（需逐系列比对 `out/mail-*` 日志），本轮不铺开；当前**唯一权威**是 `TASKS` §7 M 行 + `reports/upstream-status-*`。只修了被 `TASKS` 明确引用、且与 M3 行直接矛盾的 v9 一处 |
| `SESSIONS/` 冻结快照、`HISTORY/days` | — | 前者已冻结（只读），后者由 `scripts/gen-history.sh` 生成 |

---

## §3 复核过、确认无漂的项

| 项 | 判据 |
|---|---|
| `TASKS` §0 计数 `G1 34/36` / `G2 8/12` | `scripts/check-progress-counts.sh` 现跑逐字一致 |
| `DEVICE/README.md` §1.1 首条 = 11-07 深夜 `boot_b = vk185-adsp` | 与 11-07 提交链 + `backup/.../boot_b-before-vk185-20261107.img` 备份账一致 |
| `versions/layout.tsv` ↔ 顶层目录 | doctor §14（entries=46） |
| `versions/vk-kernel-identity.tsv` 新鲜度 | doctor §5d（含已登记例外） |
| `PITFALLS` 索引 ↔ 正文（#546/#547 = 索引 203/204） | doctor §8 全绿；两坑正文在 `sessions/177-*` |
| `HISTORY/days` 覆盖 | doctor §10（覆盖 `HEAD~1`） |
| 新报告引用完整性 | doctor §13（checked=369，无死路径）、§8（无孤儿报告） |
| `TASKS` §0 数字 ↔ `check-progress-counts.sh` | 现跑逐字一致（**改前 34/36、改后仍 34/36**；中间被 D12 顶到 35/36 一次，已修） |

---

## §4 下轮入口

1. **UEFI 剩余两项**（G1-29 验收另一半）：BDS/GRUB 启动菜单、直接从 FAT/EXT4 读 kernel+initrd（现仍经 `boot_b`）。设备侧每发需**物理断电 + 拍照**，先主机侧出件。
2. **补丁资产「投递状态」逐目录对账**（约 38 个 `patches/upstream/*/README.md` 的「未投递」字样 vs 实发日志）——本轮登记未做，属可机械化的下一轮。
3. **G1-37 收口**：中文「组词上屏」还差屏上一次点击（`CONFIG_ZRAM=m` 已进配置，尚差编进镜像上机）。
4. **上游**：只等 review（dwc3 v8 / wl2868c v9 / M10），按「不主动 ping」口径；下次增量窗复核新回信。
5. **内核**：`7.3.1` 已上机并写 `boot_b`；`7.4-rc1` 按 `reports/kernel-rebase-cost-20261107.md` 暂不跳。
6. **门禁补强（可选）**：`check-progress-counts.sh` 与 `TASKS` §0 的 `完成 N / 在范围 M` 目前靠人比；可加一条 doctor 子门自动比对（否则 `PITFALLS #548` 这类漂移仍只能靠运气发现）。

---

## §5 子代理并行 lane 的产物（2026-11-07 晚，ustc-pool 网关）

| lane | 产物 | 复核结论（编排者独立复跑） |
|---|---|---|
| **B 账目加固** | `scripts/doctor/s16-tasks-counts.py`（新增）、`scripts/check-doctor.sh` 接线（ALL + FAST 两档）、`reports/counts-gate-20261107.md` | ✅ 独立复跑：`check-doctor` **FAIL=0 WARN=4**（基线不变）、`--staged-fast` **FAIL=0 WARN=0**；负向验证用 `/tmp` 副本改 `34/36→35/36`，`ELF_TASKS_FILE=/tmp/T.md scripts/check-doctor.sh` **FAIL=1**（§16 精确报「§0 说 35/36，脚本算 34/36」）⇒ 这条漂移从此机器可查（对应本报告 D12 / `PITFALLS #548`） |
| **C 文档精简** | `reports/tasks-slim-20261107.md` | ✅ 复核：`doc-audit-20261106` §2 列的 10 处**已在 11-03/11-06 轮完成下沉**，本轮 0 处需改；现量状态格 217–365 B（C8 行另有一个 838 B 的证据格，非状态格），计数仍 34/36 与 8/12 |
| **A 投递账对账** | 见 `reports/patch-delivery-audit-20261107.md`（提交时以该报告为准） | 待复核 |
