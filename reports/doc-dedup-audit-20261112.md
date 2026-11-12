# 文档重复描述（SSOT 违例）审计 — 2026-11-12

> 只读审计：未改任何既有文件、未碰设备、未 commit。唯一产物 = 本文件。
> 工作目录：`git rev-parse --show-toplevel` = `/home/xuqianhui/y700-elden`（已核对）。
> 判定依据不重新发明，直接套用 **`INDEX.md` §2 根目录四文件职责边界表**（`INDEX.md:55-68`）＋
> 「状态数字只在 `TASKS` §0/§5」/「机型规格只在 `DEVICE`」/「踩坑只在 `PITFALLS`」/
> 「资源台账只在 `RESOURCES` §3」/「会话规则只在 `INDEX` §2 + `AGENT-OPS` §5」。
> 扫描范围：范围表内 19 个 md + `scripts/`（仅取判据）；**未**进 `linux/ geekidos-linux/ build/ wt/ external/ stock-src/`。
> 每条 = `file:line` + 可复现命令。严重度定义见 §0 末。

结构：§0 结论先行 → §1 根文件 → §2 `.pi/` 规范层 → §3 记忆层 → §4 任务与报告层 → §5 执行顺序与风险。

---

## §0 结论先行

1. **重复组 30 组**（§1 六组 / §2 九组 / §3 十组 / §4 五组），**逐行证据 103 条**：
   **P0（≥3 处正文且已互相矛盾，会误导 agent 行为）15 条**、**P1（2–3 处正文复述，暂无矛盾）72 条**、
   **P2（影响面小或属已豁免速查副本）16 条**。按组看：**P0 组 9**、P1 组 20、P2 组 1。
2. **最大单一违例源 = `AGENTS.md` §项目记忆（`AGENTS.md:36-53`，18 条）**：18 条里 **15 条**在
   `.pi/memory/`、`PITFALLS/`、`DEVICE/`、`RESOURCES/` 里已有正文，AGENTS.md 是第二份正文——
   而 AGENTS.md 是每轮注入的常驻层，任何一处修订不同步就直接与常驻认知冲突。
   按 `INDEX.md:55-68`，AGENTS.md 唯一职责 = 项目身份（机型/目标/核心原则），**不含经验与机制**。
3. **五处已互相矛盾（都属 P0，按危险度排序）**：
   ① **`drop_caches` 反向指令**（安全）：`PITFALLS/sessions/11-存储TF卡扩分区.md:6-7` 写「**必用** drop_caches」，
      而 `PITFALLS/sessions/166-…:46-49`（#513）写「**不要再发**，实测主机冻结自动重启」——同一仓库内一条叫必用、一条叫禁用。
   ② **进 fastboot 入口**：`RUNBOOK-BRINGUP/README.md:420-422` 与 `TASKS/README.md:136` 定「唯一入口 = `scripts/to-fastboot.sh`」，
      而 `.pi/AGENT-OPS.md:37` 写「**不要用封装脚本代跑 fastboot**」、`PITFALLS/sessions/01-引导fastboot重启交接.md:23` 写「`to-fastboot.sh` … 属禁忌」。
   ③ **收尾判据**：`AGENTS.md:50` 要 `FAIL=0/WARN=0` + 「文档不得要求 AI 写 summary」，
      权威 `.pi/AGENT-OPS.md:86` 只要 `FAIL=0`，且 `AGENT-OPS.md:83` 已于 2026-10-19 **作废** summary 禁令
      （`AGENTS.md:50`、`.pi/memory/MEMORY.md:147` 仍在沿用旧禁令）。
   ④ **Q28 样本数**：`TASKS/README.md:1077`（§5 自称唯一权威）同一段落内**并存**「已规避·结项（2026-10-24）」与
      「距判据 ≥8 发还差 5 发」；结项样本 `8/8（真 POR 5/5 + 暖复位 3/3）` 反而只存在于 §0 与公开面。
   ⑤ **U1/U2 台账存废**：`.pi/memory/USER.md:65` 说「U1/U2 已过时、属待清理」，
      `DEVICE/README.md:208` 却写「单元台账（**唯一登记处**）」，`AGENTS.md:21-22` / `INDEX.md:21` 仍在用。
4. **记忆层内部自抄最重**：`.pi/memory/failures-device.md` 内 `pkill -f` 自杀**同一条写 7 遍**
   （`:57,59,61,65,67,107,121`）；`failures-kernel.md` 内 kexec `--dtb` 空操作写 4 遍、
   RAM 启动不部署模块树写 3 遍（权威其实是 `PITFALLS #293`）；`MEMORY.md` 内 `mkbootimg.py` 写 4 遍。
5. **`.pi/` 三件套互相抄**：并发上限/树内配额 3 份、单写者 3 份、设备锁 3 份、ustc 池模型口径 **4 份**
   （`AGENT-OPS:102` / `ORCHESTRATION:55` / `AGENTS:51` / `USER.md:77`）。`AGENT-OPS.md:71` 已给
   「唯一 8 条在 INDEX §2，本节不复述」的正确范式，其余三处照此改即可。
6. **正面样本（不要动，改法照抄它们）**：`.pi/AGENT-OPS.md:71`（指向 INDEX §2 不复述）、
   `HISTORY/README.md:7-8`（「本文件不写死任何计数」）、`SESSIONS/README.md:39`（「会话数一律现查」）、
   `README.md:54-60`（目标段只留一行版 + 指回 AGENTS/TASKS）。
7. **动 `AGENTS.md` 的条目全部标 ★ 需用户确认**（常驻注入层，改一条等于改所有会话的第一性认知）；
   其余文件按 `AGENT-OPS.md:72` 属父 agent 专属，本审计只出替换文本，不代改。
8. 建议净收益：按 §5 顺序做完可删 **≈ 60 处重复正文**，常驻层 `AGENTS.md` 从 60 行降到 ~40 行，
   并把 4 条互相矛盾的规则收敛成单一口径；全部替换文本可直接复制。

**严重度定义**：P0 = 同一事实 ≥3 处正文**且已出现口径矛盾**；P1 = 2–3 处正文复述，暂无矛盾；
P2 = 复述但影响面小，或属 `INDEX.md:65` 明示豁免的「公开门面速查副本」但缺免责标注。

---

## §1 根文件层（AGENTS.md / INDEX.md / README.md / PROGRESS.md）

### 1.1 ★P0 组：「收尾判据」4 份正文，其中 2 份口径与权威矛盾

正文句（同一事实）：「收尾 = 产物/证据落盘 + SSOT 同步 + 设备安全态 + check-doctor + commit + 工作区干净」。

| 严重度 | 位置 file:line | 现状（正文句摘录） | 证据命令 | 建议精确改法（可直接替换的文本） |
|---|---|---|---|---|
| **P0** | `AGENTS.md:50` | 「…+ check-doctor **FAIL=0/WARN=0** + 工作区 clean；**文档不得要求 AI 写 summary**」——比权威多一条 WARN=0，且保留已作废禁令 | `rg -n '收尾.*WARN=0' AGENTS.md; rg -n '收尾的定义' .pi/AGENT-OPS.md; rg -n '该禁令已作废' .pi/AGENT-OPS.md` | `- 「收尾」判据的唯一正文 = \`.pi/AGENT-OPS.md\` §5「收尾的定义」（五项）；本文件不复述，也不在此写 FAIL/WARN 阈值。` |
| **P0** | `.pi/memory/MEMORY.md:147` | 「…check-doctor FAIL=0/WARN=0 + 提交且工作区 clean；…**一律不得要求 AI 或子代理写 summary/总结/摘要**」 | `rg -n '收尾」定义' .pi/memory/MEMORY.md` | `y700-elden「收尾」定义的沿革（2026-10-18 首次写入 AGENT-OPS §5；2026-10-19 用户裁定「禁写 summary」作废）：现行判据只读 \`.pi/AGENT-OPS.md\` §5，本条只作沿革记录。` |
| **P1** | `INDEX.md:46` | §2 会话 8 条的第 8 条把收尾五项又写一遍（虽然已带 `（.pi/AGENT-OPS.md §5）` 前缀） | `rg -n '收尾判据' INDEX.md` | `8. **收尾判据**：见 \`.pi/AGENT-OPS.md\` §5「收尾的定义」（五项，缺一不可）；本节不复述。` |
| — | `.pi/AGENT-OPS.md:86` | **保留 = 唯一正文**（五项 + 「只回一段总结 = 未收尾」实例） | — | 不改。建议在该行末追加一句：`（阈值只有 FAIL=0 一项；WARN 不作为收尾门槛）`，以消灭 1.1 的两个副本差异来源。 |

### 1.2 ★P0 组：`AGENTS.md` §项目记忆 = 记忆层/PITFALLS 的第二份正文（14 行）

`INDEX.md:55-68` 给 AGENTS.md 的唯一职责是「项目身份：机型唯一性、G1–G3 目标与优先级、核心原则」，
`AGENTS.md:53` 自己也写「细节**不放这里**」——但 `:36-52` 有 17 条细节，其中 **15 条在别处已有正文**
（`:36,37,38,39,41,42,43,44,45,46,48,49,50,51,52`；`:50` 见 1.1，其余见下表）。只有 `:40`（build-kernel.sh 唯一入口，
他处只列脚本名不列成因）与 `:47`（PITFALLS 编号纪律）勉强算 AGENTS 侧独有。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `AGENTS.md:38` ↔ `.pi/memory/MEMORY.md:53`、`.pi/memory/failures-kernel.md:669,675,681` | 「RAM 起自编内核必须先部署 `/lib/modules/<新UTS>`，否则无 card0、看门狗 84.9 s 重启」写 **5 遍**，而权威其实是 `PITFALLS #293` | `rg -n 'lib/modules/<新UTS>\|RAM 启动.*fastboot boot' AGENTS.md .pi/memory/MEMORY.md .pi/memory/failures-kernel.md; rg -n '^## #293' PITFALLS/sessions/*.md` | `AGENTS.md:38` → `- RAM 起自编内核前要部署配套模块树：正文 \`PITFALLS #293\`。`；`failures-kernel.md:675,681` 两条 → 删除并把独有信息（`devices_deferred` 判别、Q28 坏发一定在 card0）并入 `:669`；`MEMORY.md:53` → `RAM 起自编内核不部署模块树 ⇒ 无 card0（伪 Q28 坏发）：正文 PITFALLS #293 + failures-kernel.md 同族一条。` |
| **P0** | `AGENTS.md:44` ↔ `.pi/memory/failures-device.md:57,59,61,65,67,107,121` | 「`pkill -f`/`pgrep -f` 自匹配打死自己」同一条 **8 遍**（含 AGENTS.md） | `rg -c 'pkill -f\|pgrep -f' .pi/memory/failures-device.md; rg -n 'pkill -f' AGENTS.md` | `AGENTS.md:44` → `- 远程/脚本里 \`pkill -f\`、\`pgrep -f\` 会自杀：正文 \`.pi/memory/failures-device.md\`（字符组 + \`grep -vw $$\` + 先 \`-af\` 只列）。`；`failures-device.md` 保留 `:121`（最全：字符组 + `grep -vw $$` + 先列后杀 + 用户原话），`:57,59,61,65,67,107` 六条删正文、只留一行 `pkill/pgrep -f 自杀：见本文件「字符组」条（同一事实，勿再新增）。` |
| **P0** | `AGENTS.md:42` ↔ `.pi/memory/MEMORY.md:192`、`.pi/memory/failures-kernel.md:45,59,65,71` | 「`--dtb` 对 `kexec_file_load` 是空操作」写 **6 遍**，`ttyGS0 kexec 必断`写 3 遍 | `rg -n -- '--dtb\|kexec_file_load' AGENTS.md .pi/memory/MEMORY.md .pi/memory/failures-kernel.md \| cut -c1-60` | `AGENTS.md:42` → `- kexec 取证三条（\`--dtb\` 空操作 / ttyGS0 必断 / ramoops 缺 record-size）：正文 \`.pi/memory/failures-kernel.md\` 的 \`:65\` 与 \`:59\`。`；`failures-kernel.md:71` → 删除（与 `:65` 逐字同义）；`MEMORY.md:192` → `kexec --dtb 空操作 + ttyGS0 必断：正文 failures-kernel.md:65 / :59。` |
| **P1** | `AGENTS.md:36` ↔ `.pi/memory/MEMORY.md:3,11,170,180`、`RESOURCES/README.md:327` | 「禁重跑 `vk-identity.py`、清镜像走 `out-archive.py`」写 **6 遍**；`RESOURCES §3` 的 B3 行才是资产台账正文 | `rg -n 'vk-identity.py' AGENTS.md .pi/memory/MEMORY.md RESOURCES/README.md \| cut -c1-70` | `AGENTS.md:36` → `- 版本账/镜像清理耦合：正文 \`RESOURCES/README.md\` §3 的 **B3** 行（含「禁重跑 \`vk-identity.py\`」）。`；`MEMORY.md:3` 与 `:11` 各含「勿重跑 vk-identity」→ 只在 `:11` 保留并加 `（机制正文 = RESOURCES §3 B3）`，`:170,180` 各改为指针。 |
| **P1** | `AGENTS.md:37` ↔ `.pi/memory/MEMORY.md:119,123`、`.pi/memory/failures-kernel.md:705`、`DEVICE/README.md:105,119` | 「b 槽要走 `sign-boot-b.sh` + 读回 sha」写 **5 遍**；换机后 AVB 新公钥只在 `DEVICE:105,119` | `rg -n 'sign-boot-b.sh' AGENTS.md DEVICE/README.md .pi/memory/*.md \| cut -c1-70` | `AGENTS.md:37` → `- b 槽不是裸写（AVB 自签 + 读回逐字一致）：设备侧口径正文 \`DEVICE/README.md\` §1.1，操作正文 \`RUNBOOK-BRINGUP/README.md\`。`；`MEMORY.md:119,123` 二合一 → 保留 `:123`（含 sha 与报错形态），`:119` 改为指针。 |
| **P1** | `AGENTS.md:43` ↔ `.pi/memory/failures-device.md:29,109,117`、`failures-kernel.md:501`、`MEMORY.md:198` | 「设备侧脚本必须 POSIX sh」写 **6 遍**（含 busybox/zsh/bashism 变体） | `rg -n 'POSIX sh' AGENTS.md .pi/memory/ \| cut -c1-70` | `AGENTS.md:43` → `- 设备侧脚本一律 POSIX sh（部署前 \`sh -n\`）：正文 \`.pi/memory/failures-device.md\` 首条。`；`failures-device.md:109,117` → 各改一行指针指向 `:29`；`failures-kernel.md:501` 保留其独有的「`timeout … \| head/tail` 会掐断 fastboot」，把 POSIX sh 句删成指针；`MEMORY.md:198` → 指针。 |
| **P1** | `AGENTS.md:41` ↔ `.pi/memory/failures-kernel.md:81`、`PITFALLS/sessions/06-脚本工具.md:95-98`（第 111 条） | 双层压缩 + `1f8b 0800/0808` 判据写 **3 遍** | `rg -n '1f8b 0808\|双层压缩' AGENTS.md .pi/memory/failures-kernel.md PITFALLS/sessions/06-脚本工具.md \| cut -c1-70` | `AGENTS.md:41` → `- boot 载荷可能已是 gzip，别再压一次（判据 \`1f8b 0800\`/\`0808\`）：正文 \`PITFALLS\` §06 第 111 条。`；`failures-kernel.md:81` → 指针。 |
| **P1** | `AGENTS.md:46` ↔ `.pi/memory/MEMORY.md:174`、`RESOURCES/README.md:328` | 「`.pi/trash` 受 harness 保护、删不动」写 **3 遍**；用户裁决「不用清理」在 `RESOURCES §3 B4` | `rg -n 'pi/trash' AGENTS.md .pi/memory/MEMORY.md RESOURCES/README.md \| cut -c1-70` | `AGENTS.md:46` → `- \`.pi/trash/\` 由用户清理（用户 2026-11-06 裁决）：正文 \`RESOURCES/README.md\` §3 **B4**；删 `build/*` 前置闸见 \`MEMORY.md:174\`。` |
| **P1** | `AGENTS.md:48` ↔ `.pi/memory/MEMORY.md:51,59` | 「geekidos-linux 浅克隆 → fetch 被拒 → 从本地 worktree fetch」写 **3 遍** | `rg -n '浅克隆' AGENTS.md .pi/memory/MEMORY.md \| cut -c1-70` | `AGENTS.md:48` → `- 内核仓是浅克隆（fetch/bundle 被拒，改从本地 worktree fetch）：正文 \`.pi/memory/MEMORY.md:51\`。`；`MEMORY.md:59` → 指针（保留 vk127 的源提交号 `24223e44ad80` 事实）。 |
| **P1** | `AGENTS.md:49` ↔ `.pi/memory/MEMORY.md:164`、`INDEX.md:100,169`、`PITFALLS/README.md:222`（#519） | 「新增顶层条目先登记 `versions/layout.tsv`」写 **5 遍**（INDEX:100 与 INDEX:169 同文件两处） | `rg -n 'layout.tsv' AGENTS.md INDEX.md .pi/memory/MEMORY.md \| cut -c1-70` | `AGENTS.md:49` → `- 顶层布局登记与门禁：正文 \`INDEX.md\` §2「顶层布局」表注。`；`INDEX.md:169` 那句与 `INDEX.md:100` 同义 → 改成 `（口径见本节上方引言）`。 |
| **P1** | `AGENTS.md:52` ↔ `.pi/memory/MEMORY.md:163`、`PITFALLS/README.md:191`（#486） | 「EDL 工具链分工（qdl 刷写 / edl-ng GPT / bkerler peek 备胎）」写 **3 遍** | `rg -n 'printgpt -u 4' AGENTS.md .pi/memory/MEMORY.md PITFALLS/README.md \| cut -c1-70` | `AGENTS.md:52` → `- EDL 工具链单根 \`~/edl/\` 的能力分工：正文 \`.pi/memory/MEMORY.md:163\`（loader 不放行 peek = \`PITFALLS #486\`）。` |
| **P1** | `AGENTS.md:45` ↔ `.pi/memory/MEMORY.md:101`（+ 交叉编配方 `:105`） | 「不要在平板上编译（过热→BL）+ musl 工具链路径」写 **2–3 遍** | `rg -n '不要在.*平板上跑编译\|aarch64-linux-musl-cross' AGENTS.md .pi/memory/MEMORY.md \| cut -c1-70` | `AGENTS.md:45` → `- 不在设备上编译（过热会断电到 BL）：正文 \`.pi/memory/MEMORY.md:101\`；交叉编配方同文件 `:105`。` |
| **P2** | `AGENTS.md:39` ↔ `.pi/memory/MEMORY.md:73` | 「诊断前先 `q28-watchdog.sh off`」两处正文，且 AGENTS 版多带 Q24/相机结论 | `rg -n 'q28-watchdog.sh off' AGENTS.md .pi/memory/MEMORY.md \| cut -c1-70` | `AGENTS.md:39` → `- Q28 显示态是协变量不是判别量（7.3 线 30 发存活 / vk64 线 1 死 2 发）：结论正文 \`TASKS/README.md\` §5 Q28，诊断前置 \`scripts/q28-watchdog.sh off\` 见 \`.pi/memory/MEMORY.md:73\`。` |
| **P2** | `AGENTS.md:51` 尾句「（2026-11-08 定，**推翻下文「不走 ustc-pool」**）」 | 指向的下文**已不存在** = 悬空引用（指向已删条目的历史注记） | `rg -n '不走 ustc-pool' AGENTS.md; echo rc=$?` | 删除括号内「，推翻下文「不走 ustc-pool」」保留日期：`（2026-11-08 定）`。 |

### 1.3 P1 组：AGENTS.md 的「项目记忆」该整体降级为指针（结构性结论）

`AGENTS.md:36-53` 18 条中只有 **3 条**可留（`:40` build-kernel.sh 唯一入口、`:47` PITFALLS 编号纪律、
`:53` 自述「细节不放这里」）；`:50` 已在 1.1 处置，其余 14 条应降级为指针。
**建议**：把 §项目记忆 整节改为 12 行指针清单，正文一律留在 `.pi/memory/`、`PITFALLS/`、`DEVICE/`、`RESOURCES/`。

| 严重度 | 位置 | 现状 | 证据命令 | 建议改法 |
|---|---|---|---|---|
| **P1** | `AGENTS.md:34`（节标题 `## 项目记忆（2026-11-11 整理）`） | 节标题本身就声明 AGENTS.md 是记忆正文所在，与 `INDEX.md:55-68` 冲突 | `sed -n '34p' AGENTS.md; rg -n '项目描述\|不得复述' INDEX.md` | 节标题 → `## 项目记忆的指针（正文一律在 \`.pi/memory/\`、\`PITFALLS/\`、\`DEVICE/\`、\`RESOURCES/\`）`；节内逐条按 1.2 的替换文本降级。 |

### 1.4 P1 组：README 机型表把 **U2 单元容量**写成机型规格（与设备等价原则冲突）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `README.md:44` | 「存储/内存 \| **16 GB / 512 GB**（UFS），A/B 双槽」——`DEVICE/README.md` §2.2 显示 **U1=12G/234 GiB、U2=16G/476 GiB**；容量是**单元属性不是机型属性**（`AGENTS.md:21-22`、`INDEX.md:12` 设备等价） | `rg -n '16 GB / 512' README.md; rg -n '^\\| \\*\\*U1\\*\\*\\|^\\| \\*\\*U2\\*\\*' DEVICE/README.md \| cut -c1-160` | `README.md:44` → `\| 存储/内存 \| UFS 4.0（容量**按单元**不同：见 \`DEVICE/README.md\` §2.2 单元台账），A/B 双槽 \|` |
| **P2** | `README.md:42-43` ↔ `DEVICE/README.md:14-15` | SoC 描述漂移：README 写「Snapdragon 8 Gen 4 平台」，DEVICE 写「骁龙 8 至尊版 / 8 Elite」；面板行 README 缺 `CPHY`、屏型号少后缀 `-1` | `rg -n 'SM8750' README.md DEVICE/README.md \| cut -c1-140` | 机型表属 `INDEX.md:60` 豁免的速查副本，但数值须与 DEVICE 一致：`SoC` 行改 `\| SoC \| **Qualcomm SM8750(P)**（骁龙 8 至尊版 / 8 Elite），8 核 + Adreno 830 \|`；`面板` 行改 `\| 面板 \| 8.8" 3K（1904×3040）**bonded 双 DSI + CPHY + DSC**，Novatek NT36536（CSOT PP8807HB1-1）\|` |
| **P2** | `README.md:37-46`（表整体） | 表下已有 SSOT 免责（`:47-48`），但表内无「速查副本」标注在表头，读者易当权威 | `sed -n '47,48p' README.md` | 在表头行 `README.md:37` 改为 `\| 项 \| 值（速查副本，权威见 \`DEVICE/README.md\` §1） \|` |

### 1.5 P1 组：README §3/§4 与 PROGRESS §2/§3 互相抄 + 抄 TASKS §0 的状态数字

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `README.md:71` ↔ `PROGRESS.md:125` | G2 行逐字同一条 C 清单（传感器 HAL / C6 音频 / C2 GMS / C10 马达 / C11 输入法 / 容器相机 STREAMING），两处都自称「权威数字见 TASKS §0」却把明细各抄一份 | `rg -n 'C10 马达透传' README.md PROGRESS.md \| cut -c1-140` | `PROGRESS.md:126`（G2 行「关键限定」列）→ `主链路已通；分项目录与完成度只读 \`TASKS/README.md\` §0/§2（C4/C6/C2/C10/C11/C12 等）`。`README.md:71` 保留一句概述并把明细换成分母数字指针。 |
| **P1** | `README.md:75-78` ↔ `PROGRESS.md:130-143` | 「已工作（有实测证据）」清单两处各写一遍（显示/触屏/WiFi-BT/USB/音频/温控/CDSP/DP/相机/磁盘根/槽/容器传感器…） | `rg -n '已工作（有实测证据）' README.md; rg -n '^## 3\. 已验证可用' PROGRESS.md` | `PROGRESS.md:130-143`（§3 整节）→ 换成一行：`已验证可用面的**唯一清单** = \`README.md\` §3（公开面）+ \`TASKS/README.md\` §1 各行状态；本节不再另列，避免两处漂移。` |
| **P1** | `README.md:70,83,94` + `PROGRESS.md:51,227` ↔ `TASKS/README.md:1077` | Q28 结项样本数 `8/8（真 POR 5/5 + 暖复位 3/3）` 在公开面两处 + §0 出现，**§5 权威行内没有 8/8**，反而留着「距判据 ≥8 发还差 5 发」 | `sed -n '1077p' TASKS/README.md \| grep -o '已规避·结项（2026-10-24\|距判据 ≥8 发还差 \*\*5 发\*\*\|8/8'` | ① 先补权威：`TASKS/README.md:1077` 内把「距判据 ≥8 发还差 **5 发**」替换为「**结项样本 = 真 POR 5/5 + 暖复位 3/3 = 8/8 无坏发**（2026-10-24 用户裁决不补样本；判据 `DSI_PLL_lockfail=0`/`storm_sig=0`/mdss reset 失败 0/两路 pclk-byte parent 一致）」；② `README.md:83` → `（\`Q28\`/\`Q32\` 已于 2026-10-24 按「已规避」结项；样本数与复启条件只读 \`TASKS\` §5 Q28/Q32。）`；③ `PROGRESS.md:227` 保留「已结项」一句、样本数换成指针。 |
| **P1** | `README.md:98` ↔ `TASKS/README.md:15` ↔ `PROGRESS.md:46` | Q24 根因句（7.2 缺 `Skip retention by default`）+ 数字（41 发 0 死亡 vs 7.2 的 6/8 死）三处正文 | `rg -n '41 发 0 死亡\|Skip retention by default' README.md TASKS/README.md PROGRESS.md \| cut -c1-120` | `README.md:98` 状态列 → `**⛔ 已关闭（2026-10-24 用户裁决不再取证）**；根因与样本数只读 \`TASKS\` §5 Q24。运营上仍保留 \`cam-mode.sh on/off\` 互斥（安全策略）。`；`TASKS/README.md:15`（§0 阻塞项速览行，自称「只列 ID」）把括号内 Q24/Q28 明细换成 ID + 指针，与该行自己的口径一致。 |

### 1.6 P1 组：INDEX §3「不复述状态」却自己复述了 UEFI 收口结论

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `INDEX.md:189-194` | 引言写「任何数字与当前口径都不在此维护」，正文却写「清 `dtbo_a` 后 p69 **129.2 s** 起 Linux（n=3 复现）」+ 真根因整段 | `sed -n '186,196p' INDEX.md \| grep -n '129.2\|n=3\|dtbo_a'` | 该行整段 → `- **G1-29 UEFI 不在「勿重推」之列**；当前口径只读 \`TASKS/README.md\` §5「2026-11-10（深夜，\`dtbo_a\` 真根因）」块 + \`reports/uefi-dtbo-a-rootcause-20261110.md\`（本文件不复述数字）。` |
| **P2** | `INDEX.md:193` | 「剩余仅两项非阻塞：屏上 BDS/GRUB 菜单交互取证、`boot_a` 冷启动回归」——同一句也出现在 `TASKS/README.md:153` | `rg -n '剩余仅两项非阻塞' INDEX.md TASKS/README.md \| cut -c1-90` | `INDEX.md:193` → 并入上一条指针，删本行。 |

---

## §2 `.pi/` 规范层（AGENT-OPS / ORCHESTRATION / CONCURRENCY）

三份文件各自开头都声明了分工（`AGENT-OPS.md:1-5`「唯一入口」、`ORCHESTRATION.md:4`「本文件不重复其自主优先与备份口径」、`CONCURRENCY.md:6`「行为/授权标准统一见 AGENT-OPS」），
**声明是对的、正文却仍然互抄**。以下每组都给出「保留哪一份 + 其余换成哪一行」。

### 2.1 P1 组：并发上限 / 递归深度 / 树内配额 —— 3 份正文

正文句：「`agents.maxConcurrent: 16`、`agents.maxDepth: 2`、总管 ≤4 个 L1、每个 L1 ≤3 个 L2、合计 ≤16」。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/AGENT-OPS.md:98-99` | 把三个配置值 + 配额策略整段又写一遍（`ORCHESTRATION` §3 自称「生效参数」是它的家） | `rg -n 'maxConcurrent' .pi/AGENT-OPS.md .pi/ORCHESTRATION.md .pi/CONCURRENCY.md` | `.pi/AGENT-OPS.md:98-99` → `- 并发上限、递归深度与树内配额：只读 \`.pi/ORCHESTRATION.md\` §3（配置真源 = \`~/.pi/agent/fabric.json\` + \`.pi/fabric.json\`）。` |
| **P1** | `.pi/CONCURRENCY.md:30-32` | 同一组数值第三次正文，且额外带 `maxPerExecution: 16` | `rg -n 'maxPerExecution' .pi/CONCURRENCY.md .pi/ORCHESTRATION.md` | `.pi/CONCURRENCY.md:30-32` → `6. **并发上限/递归深度/树内配额**：见 \`.pi/ORCHESTRATION.md\` §3（含 \`maxPerExecution\`）；按 ustc 池限流自留余量。` |
| — | `.pi/ORCHESTRATION.md:38-43` | **保留 = 唯一正文**（含真源与 `/reload` 提示） | — | 不改。 |

### 2.2 P1 组：单写者规则 —— 3 份正文（且两份的「谁专属」清单不一致）

正文句：「任何时刻一个文件只有一个写者；领域层 README + `.githooks` + `versions/` = 父 agent 专属」。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/CONCURRENCY.md:25` | 「**领域层 4 份** + `PITFALLS` + `.githooks` + `versions/` = 父专属」 | `rg -n '单写者' .pi/AGENT-OPS.md .pi/ORCHESTRATION.md .pi/CONCURRENCY.md` | `.pi/CONCURRENCY.md:25` → `1. **单写者**：口径见 \`.pi/AGENT-OPS.md\` §4「单写者」；lane 侧的落地约束 = 本文件 §2.2「文件归属不重叠」。` |
| **P1** | `.pi/ORCHESTRATION.md:99` | 「总管唯一写 `main` 与领域层 SSOT；L1 只读 SSOT；L2 只写被指派的路径」——第三种切法（按层），与 `:13` 表格「写领域层 SSOT」重复 | `rg -n '只读 SSOT' .pi/ORCHESTRATION.md` | `.pi/ORCHESTRATION.md:99` → `- **单写者**：见 \`.pi/AGENT-OPS.md\` §4；三层职责的落点见本文件 §1 表。` |
| — | `.pi/AGENT-OPS.md:72-73` | **保留 = 唯一正文**（含「被显式指派重建某角度文件夹时该角度单写」例外） | — | 不改；建议追加半句 `（"领域层 4 份" = DEVICE/TASKS/RESOURCES/RUNBOOK；PITFALLS 同列）`，与 CONCURRENCY 的历史措辞对齐。 |

### 2.3 P1 组：设备是单一串行资源（设备锁）—— 4 份正文

正文句：「所有上机/刷写/复现前 `scripts/device-lock.sh`，同一时刻只有一个持有者」。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/ORCHESTRATION.md:101` | 第三处正文（§5 深派决策 `:91` 已写过「设备动作永远串行」） | `rg -n 'device-lock.sh' .pi/ORCHESTRATION.md .pi/CONCURRENCY.md DEVICE/README.md` | `.pi/ORCHESTRATION.md:101` → `- **设备是单一串行资源**：口径见 \`.pi/CONCURRENCY.md\` §2 第 5 条。` |
| **P1** | `.pi/ORCHESTRATION.md:91` | 「设备动作**永远串行**（全局单资源，\`scripts/device-lock.sh\`），不得并行派上机」——与 `:101` 同文件互抄 | `rg -n '永远串行' .pi/ORCHESTRATION.md` | 保留 `:91`（这是 L1 深派判据），把 `:101` 换成上一行的指针。 |
| **P2** | `DEVICE/README.md:293` 末句 | 「设备是单一串行资源，未完成前不得与其它上机 lane 并行」在设备台账里又写一遍 | `rg -n '单一串行资源' DEVICE/README.md .pi/CONCURRENCY.md` | `DEVICE/README.md:293` 末句 → `（设备串行口径见 \`.pi/CONCURRENCY.md\` §2 第 5 条）` |
| — | `.pi/CONCURRENCY.md:29` | **保留 = 唯一正文**（唯一给出「串行 = 用 `device-lock.sh`」的强约束原句） | — | 不改。 |

### 2.4 P0 组：子代理模型池（ustc-pool / 禁 DeepSeek 与 nexavlinks）—— 4 份正文，其中 1 份缺禁令

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `.pi/ORCHESTRATION.md:55-56` | 只写「一律用 ustc 池 + 四个别名」，**未写禁用清单** ⇒ 照本文件派工就可能选到被禁 provider | `rg -n 'nexavlinks\|deepseek' .pi/ORCHESTRATION.md; echo rc=$?` | `.pi/ORCHESTRATION.md:55-56` → `4. **本项目模型一律用 ustc 池**：别名表与禁用清单（禁 \`custom.nexavlinks-com/*\` 与 \`deepseek/*\`）唯一正文 = \`.pi/AGENT-OPS.md\` §6；派工时写显式 \`provider/model\`。` |
| **P1** | `AGENTS.md:51` | 常驻层第三次正文（含悬空引用，见 1.2） | `rg -n 'ustc-pool' AGENTS.md .pi/AGENT-OPS.md .pi/ORCHESTRATION.md .pi/memory/USER.md` | `AGENTS.md:51` → `- 子代理模型池与禁用清单：正文 \`.pi/AGENT-OPS.md\` §6（用户口径 \`.pi/memory/USER.md:77\`）。` |
| **P1** | `.pi/memory/USER.md:77` + `:85` | 用户口径两条：`:85` 是 `:77` 的补充句，同一决定写两遍 | `rg -n '一律走 ustc-pool\|一律 ustc-pool' .pi/memory/USER.md` | `.pi/memory/USER.md:85` → `派发子代理时若用户点名网关/模型，仍以本文件上一条（ustc-pool / 禁 DeepSeek 与 nexavlinks）为硬前提；冲突先向用户确认。（2026-11-08）` |
| — | `.pi/AGENT-OPS.md:102-104` | **保留 = 唯一正文**（别名 + `/reload` + `tools` 白名单提醒） | — | 建议追加：`禁用：custom.nexavlinks-com/*、deepseek/*（含 deepseek-v4-pro）——只留给用户交互式对话（2026-11-08）。` |

### 2.5 P1 组：「worker 自报成功不可信」—— 5 份正文

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/ORCHESTRATION.md:17`、`:121` | `:17` 用括注复述、`:121` 又写「硬规则：worker 自报成功不可信；不复跑不得写已修复」 | `rg -n '自报' .pi/AGENT-OPS.md .pi/ORCHESTRATION.md TASKS/README.md \| cut -c1-90` | `.pi/ORCHESTRATION.md:121` → `- L1 → 总管：总管按验收判据**独立复跑**（规则正文 \`.pi/AGENT-OPS.md\` §6）；不复跑不得写"已修复/已解决"。` |
| **P1** | `TASKS/README.md:6` | 台账抬头再写一遍纪律（「worker 只报命令+原始日志，编排者独立复跑」） | `sed -n '6p' TASKS/README.md` | `TASKS/README.md:6` → `> 纪律：见 \`.pi/AGENT-OPS.md\` §3（判据在设备侧）与 §6（自报不可信，独立复跑）；设备锁串行、主机侧并行。` |
| **P2** | `.pi/AGENT-OPS.md:97` 与 `:105` | 同文件两条讲同一件事（一条原则 + 一条 2026-10-19 实例） | `rg -n '自报' .pi/AGENT-OPS.md` | `:105` → `- 实例（2026-10-19）：lane-b 返回 \`status=completed\` 且自称已写 33 KB 报告，实际文件不存在，重派后才有 ⇒ 复核必 \`ls\`/\`read\`。`（去掉重复的规则句式） |
| — | `.pi/AGENT-OPS.md:97` | **保留 = 唯一正文** | — | 不改。 |

### 2.6 P1 组：`AGENT-OPS` §4 复述 `INDEX` §2 的文档结构与「记录区分度」

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/AGENT-OPS.md:68-69` ↔ `INDEX.md:29-30` | 「记录时的区分度 = 文件夹(角度) + 文件名(日期+主题) + pi 会话 id」逐字两遍（连「取代自检计数」的说明都同构） | `rg -n '记录时的区分度' INDEX.md .pi/AGENT-OPS.md` | `.pi/AGENT-OPS.md:68-69` → `- **记录时的区分度 / 会话检索**：唯一正文 \`INDEX.md\` §2 引言；注意项目 \`sessionDir=.pi/sessions\`，全局 \`sess\` 扫不到本项目，必须用 \`scripts/sess.sh\`。`（保留唯一不重复的那条「全局 sess 扫不到」事实） |
| **P1** | `.pi/AGENT-OPS.md:66-67` ↔ `INDEX.md:27-28` | 「7 个角度文件夹 + README.md 策展 SSOT + sessions/ 命名」两处正文 | `rg -n '7 个' INDEX.md .pi/AGENT-OPS.md \| cut -c1-110` | `.pi/AGENT-OPS.md:66-67` → `- **结构**：唯一入口与角度清单、sessions/ 命名规则的正文 = \`INDEX.md\` §2。` |
| **P2** | `.pi/AGENT-OPS.md:75` ↔ `INDEX.md:157` | 「`archive/` 追加为主，允许带日期最小修订」两遍 | `rg -n '追加为主' INDEX.md .pi/AGENT-OPS.md` | `.pi/AGENT-OPS.md:75` → `- \`archive/\`：**追加为主**，口径见 \`INDEX.md\` §2「证据层」；结论以角度 \`README.md\` 为准。` |
| — | `INDEX.md:34-46`（8 条） + `.pi/AGENT-OPS.md:71` | **正面样本**：`AGENT-OPS:71` 明确「唯一 8 条规则在 INDEX §2，本节不复述」 | `sed -n '71p' .pi/AGENT-OPS.md` | 不改（本节其余各条照这一行改写）。 |
| **P2** | `.pi/ORCHESTRATION.md:122` ↔ `.pi/AGENT-OPS.md:84` | 「状态词只允许未解/未证实/未上机」两遍 | `rg -n '状态词' .pi/AGENT-OPS.md .pi/ORCHESTRATION.md` | `.pi/ORCHESTRATION.md:122` → `- 失败/半成品同样落盘；状态词口径见 \`.pi/AGENT-OPS.md\` §5。` |

### 2.7 P0 组：备份三件套 + 「本机 ABL 无 `fastboot fetch`」—— 8 份正文（权威是 `PITFALLS #290`）

正文句：「本机 ABL 无 `fastboot fetch`（`Unable to get max-fetch-size`）⇒ 备份 = 设备侧 `dd`／线刷包解出／EDL 读回 + GPT 双表 dump；写后读回校验（不看"传输完成"）」。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `.pi/AGENT-OPS.md:18` 与 `.pi/AGENT-OPS.md:33` | **同文件两处**完整正文（授权表 + §2 纪律），加上 2.7 其余 6 处 = 一条设备事实撑起了 4 个文件的正文 | `rg -n 'fastboot fetch' .pi/AGENT-OPS.md PITFALLS/README.md RUNBOOK-BRINGUP/README.md DEVICE/README.md INDEX.md .pi/memory/*.md \| cut -c1-90` | `.pi/AGENT-OPS.md:18` 行为列 → `**先备份**（覆盖分区 + GPT 双表 + 回退路径；备份手段见 \`PITFALLS\` §0 第 2 条），**再执行**；写后读回校验`。`.pi/AGENT-OPS.md:33` → `- 动分区/刷写前：备份 + GPT 双表 dump + **写后读回校验**——三条的正文与实测证据 = \`PITFALLS\` §0 第 2 条（#290）。` |
| **P1** | `INDEX.md:233` | 快速命令注释里把 #290 的实测报错文本又抄一遍 | `rg -n '无 fastboot fetch' INDEX.md` | `INDEX.md:233` → `# b 槽三件套备份：本机无 fastboot fetch（PITFALLS #290），走设备侧 dd` |
| **P1** | `DEVICE/README.md:109` 与 `:281` | 同文件两处正文（§1.1 上机注意 + §3 决策规则第 4 条） | `rg -n 'fastboot fetch' DEVICE/README.md` | `DEVICE/README.md:281` → `4. 任何改动前先备份分区 + GPT 双表 dump，改后**读回校验**（手段与判据见 \`PITFALLS\` §0 第 2 条 / #290）。` |
| **P1** | `RUNBOOK-BRINGUP/README.md:217` | 全文最长的一份（含 fastboot 版本号与用户原话），实际是这条事实的"真正文"，但 PITFALLS 也有一份 | `sed -n '217p' RUNBOOK-BRINGUP/README.md \| cut -c1-120` | 二选一即可：建议**把 `:217` 的长证据并入 `PITFALLS/sessions/39-…:6`（#290 正文）**，`:217` 换成 `> ⚠️ 本机 ABL 不支持 \`fastboot fetch\`（实测与用户原话见 \`PITFALLS #290\`）⇒ 备份按 §2.1 三条通道走。` |
| **P2** | `.pi/memory/notes-display.md:11` + `.pi/memory/MEMORY.md:206` | 记忆层再两份 | `rg -n 'fastboot fetch' .pi/memory/` | `MEMORY.md:206` → `本机 ABL 无 fastboot fetch ⇒ 分区备份三通道：正文 PITFALLS #290。`；`notes-display.md:11` 同改（notes-display 只留一行）。 |
| — | `PITFALLS/README.md:14` + `PITFALLS/sessions/39-…:6`（#290） | **保留 = 唯一正文**（§0 一句 + 条目正文） | — | 不改。 |

### 2.8 P1 组：`PITFALLS` §0 零号纪律 ↔ `AGENT-OPS` §2/§3 互相复述

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/AGENT-OPS.md:43` ↔ `PITFALLS/README.md:13` ↔ `INDEX.md:210` | 「先查本地既有结论」三处正文（`AGENT-OPS` 版还多一条 `grep` 范围） | `rg -n '先查本地既有结论' .pi/AGENT-OPS.md PITFALLS/README.md INDEX.md` | `.pi/AGENT-OPS.md:43` → `- **先查本地既有结论**：动手前纪律与现成 grep = \`PITFALLS\` §0 第 1 条 + \`INDEX.md\` §4「动手前 30 秒」（#87）。` |
| **P1** | `.pi/AGENT-OPS.md:44` ↔ `PITFALLS/README.md:18` | 「无设备证据不得写已修复 + 间歇性故障单次样本无效」逐字两遍（`AGENT-OPS` 已括注 `PITFALLS §0 纪律 4`，但正文仍然完整） | `rg -n '单次样本无效' .pi/AGENT-OPS.md PITFALLS/README.md` | `.pi/AGENT-OPS.md:44` → `- **判据在设备侧**：正文 \`PITFALLS\` §0 第 4 条（未上机 ≠ 已修复；间歇性故障须同口径量化 + 单变量 + 长时窗）。本文件的追加要求：**无设备证据不得写入本文件所指的任何 SSOT**。` |
| **P1** | `.pi/AGENT-OPS.md:36` ↔ `PITFALLS/README.md:15-17` | 「零写盘优先 + `-ram` 纯 RAM 变体 vs 持久变体」两遍正文（AGENT-OPS 已带 #92/#93） | `rg -n '持久变体' .pi/AGENT-OPS.md PITFALLS/README.md INDEX.md` | `.pi/AGENT-OPS.md:36` → `- **零写盘优先** \`fastboot boot\`；两种 RAM 变体的区别与适用面 = \`PITFALLS\` §0 第 3 条（#92/#93）。` |
| **P2** | `.pi/AGENT-OPS.md:37` ↔ `PITFALLS/sessions/01-引导fastboot重启交接.md:20-23` | 「fastboot 拆单条 / 不要封装脚本代跑」两遍，且 `AGENT-OPS:37` 是**授权句**、PITFALLS 是**经验句** | `rg -n '拆单条\|拆成单条' .pi/AGENT-OPS.md PITFALLS/sessions/01-*.md` | `.pi/AGENT-OPS.md:37` → `- **封装脚本**：主机侧构建/打包脚本可跑；fastboot/EDL 命令拆单条（经验与例外见 2.9）。` |

### 2.9 ★P0 组：「进 fastboot 的唯一入口」—— 3 份正文 + 1 处直接冲突

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `PITFALLS/sessions/01-引导fastboot重启交接.md:23` | 「`to-fastboot.sh`/`cycle.sh` 类**封装脚本代跑 fastboot** 在本机故障率高，属禁忌」——与 2026-11-12 定案（唯一入口就是 `to-fastboot.sh`）**直接冲突** | `rg -n '属禁忌' PITFALLS/sessions/01-*.md; rg -n 'to-fastboot.sh' RUNBOOK-BRINGUP/README.md TASKS/README.md` | `PITFALLS/sessions/01-…:23` → `★ **经验事实（非授权规则）**：故障率高的是 **cycle.sh 的 misc BCB / 裸 sysrq-b 两条路径**（#65/#66，实测到不了 fastboot），不是"封装"本身；Linux→fastboot 的**唯一入口 = \`scripts/to-fastboot.sh\`**（内部 \`eldroid-bootctl reboot bootloader\` + 6 s sysrq-b 看门狗），正文 \`RUNBOOK-BRINGUP/README.md\`「Linux → fastboot」+ \`PITFALLS #627\`。` |
| **P0** | `.pi/AGENT-OPS.md:37`（同 2.8 末行） | 「不要用封装脚本代跑 fastboot/EDL」若不改，将把唯一推荐入口判成违规 | `sed -n '37p' .pi/AGENT-OPS.md` | 用 2.8 末行的替换文本（把「不要用封装脚本代跑」换成「fastboot/EDL 命令拆单条」），并在 2.8 文本后追加：`例外（唯一）：\`scripts/to-fastboot.sh\` 已带 6 s sysrq-b 兜底，是 Linux→fastboot 的推荐入口。` |
| **P1** | `TASKS/README.md:136-137` | §4「下一步」里把整份审计报告的 §0 五条结论（唯一入口 / 内核路径相同 / cycle 两路都不通 / uefi-oneshot 不通 / 停手判据 25 s）**逐条正文复述** | `rg -n '进 fastboot 的唯一入口（2026-11-12 立' TASKS/README.md; sed -n '1,40p' reports/script-redundancy-audit-20261112.md \| grep -n '唯一推荐入口\|停手判据'` | `TASKS/README.md:136` 整条 → `- **进 fastboot 的唯一入口**（2026-11-12 定案）：\`scripts/to-fastboot.sh\`；口径正文 \`RUNBOOK-BRINGUP/README.md\`「Linux → fastboot」+ \`PITFALLS #627\`，实测账 \`reports/script-redundancy-audit-20261112.md\` §0。`（§4 只留一句结论 + 三个指针） |
| **P2** | `TASKS/README.md:140`、`:91`、`:162` | 待办行仍把 `reboot2 bootloader` 当可用入口写进步骤（与 `:136` 的「停用」自相矛盾） | `rg -n 'reboot2 bootloader' TASKS/README.md \| cut -c1-80` | 三处步骤里的 `reboot2 bootloader` → `to-fastboot.sh`；并在 `:140` 括注 `（旧记法 reboot2 bootloader 已停用，见 :136）`。 |
| — | `RUNBOOK-BRINGUP/README.md:420-422` | **保留 = 唯一正文**（入口 + 为什么 cycle 两路不行 + `--flash` 语义） | — | 不改；建议在该小节标题旁标 `（本节为该事实唯一正文）`，与 `DEVICE §1.4` 的「唯一正文位置」写法一致。 |

---

## §3 记忆层（`.pi/memory/`）

记忆层的写法是「一条 `---` 一块、只追加」，所以**同一事实被后来的会话再写一遍**而旧条目不删。
本节先给**层内自抄**（同一文件内多遍），再给**跨文件互抄**（notes-display ↔ MEMORY ↔ failures-\* ↔ USER）。

### 3.1 P0 组：`pkill/pgrep -f` 同一条在 `failures-device.md` 写 7 遍（详见 1.2 的 AGENTS 侧处置）

| 严重度 | 位置 file:line | 现状（各写各的解法） | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `.pi/memory/failures-device.md:57,59,61,65,67,107,121` | 7 条正文：`:57` 说改用 `pkill -x`、`:61` 说 `kill $(pgrep -x)`、`:65` 说括号法、`:67/:107/:121` 说字符组 + `grep -vw $$` + 先 `-af` ⇒ **同一坑给出三种互不相同的解法** | `grep -c 'pkill -f\|pgrep -f' .pi/memory/failures-device.md` | 保留 `:121` 为唯一正文并补一句「`pkill -x` 在 busybox 匹配 argv[0] 全串，会假阴性（见本文件 busybox 条），故**首选字符组 + `grep -vw "$$"`**」；`:57,59,61,65` 四条 → 各替换为 `pkill/pgrep -f 自杀：见本文件 :121（同一事实，勿再新增条目）。`；`:67`、`:107` → 各替换为同上一行（它们独有的日期/exit 码信息并入 `:121`）。 |

### 3.2 P1 组：`failures-kernel.md` 内 kexec `--dtb` 空操作 —— 4 遍

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/memory/failures-kernel.md:65` | 「`--dtb` 空操作 + FDT 由 live DT 重建 + iterate.sh DTB 环不成立」 | `grep -n 'kexec_file_load' .pi/memory/failures-kernel.md \| cut -c1-60` | **保留 `:65` = 本层唯一正文**（信息最全：syscall 无 DTB 形参、`of_kexec_alloc_and_setup_fdt`、`dtb: (ignored)`）。 |
| **P1** | `.pi/memory/failures-kernel.md:71` | 与 `:65` 同义重写（只多一句「只能走 fastboot boot/--flash」） | `sed -n '71p' .pi/memory/failures-kernel.md \| cut -c1-120` | `:71` → `kexec --dtb 被忽略（同 :65）；DTB 变更只能走 fastboot boot / --flash。` |
| **P1** | `.pi/memory/failures-kernel.md:45`、`:59` | 两条都含「`--dtb` 空操作」，`:59` 的独有信息是 **ttyGS0 kexec 必断 + 硬看门狗被禁 ⇒ 必须物理复位** | `grep -n 'ttyGS0' .pi/memory/failures-kernel.md \| cut -c1-60` | `:45` → `kexec_file_load 装载成功但 -e 硬挂（2026-10-05 案）：取证缺陷 = 无跳转期存活 console（见 :59）+ 缺上游 1537e55728ec（见 :49 族）；机制口径见 :65。` |
| **P1** | `.pi/memory/MEMORY.md:192` | 第五次正文（同时抄了 `--dtb` 与 ttyGS0 两条） | `rg -n 'kexec_file_load' .pi/memory/MEMORY.md` | `MEMORY.md:192` → `kexec：--dtb 空操作 / ttyGS0 跳转必断 / 缺 1537e55728ec —— 正文 .pi/memory/failures-kernel.md:65、:59。` |

### 3.3 P1 组：`failures-kernel.md` 内「RAM 起内核不部署模块树」—— 3 遍（权威是 `PITFALLS #293`）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/memory/failures-kernel.md:669`、`:675`、`:681` | 三条同一事故（vk127 s1/s2），只有判别句不同 | `grep -n 'lib/modules/<新UTS>' .pi/memory/failures-kernel.md \| cut -c1-60` | 保留 `:675`（含 `devices_deferred` 判别 + 已指向 `PITFALLS #293`）为唯一正文；`:669` → `RAM 起内核不部署模块树 ⇒ 无 card0（伪 Q28 坏发）：见本文件 :675 / PITFALLS #293。`；`:681` → `同上；补一条判别：**Q28 真坏发一定有 card0** 且带首条 DCS/`command DMA timeout` 签名。` |

### 3.4 P1 组：`MEMORY.md` 内 `mkbootimg.py` —— 4 遍

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/memory/MEMORY.md:25,43,47,57` | 「`tools/mkbootimg/` 随换机丢失（`/tools/` 在 `.gitignore:15`）→ 已恢复为 `scripts/mkbootimg.py`」写 **4 遍** | `grep -n 'mkbootimg' .pi/memory/MEMORY.md \| cut -c1-60` | 保留 `:47` 为唯一正文（含受管路径与 selftest）；`:25` → `换机后 out/ 的 ramdisk cpio 与 tools/mkbootimg 丢失；ramdisk 可从基线 boot_b 原位抽出：正文本文件 :47。`；`:43`、`:57` → `mkbootimg 恢复与 .gitignore 成因：见本文件 :47。` |
| **P2** | `.pi/memory/notes-display.md:3` | 第五次正文（v2 头字段表：magic/name@48/cmdline@64/id@576/header_size=1660）——**这条其实比 MEMORY 更技术、更该留** | `sed -n '3p' .pi/memory/notes-display.md \| cut -c1-120` | 把 `notes-display.md:3` 的字段偏移并入 `MEMORY.md:47`，`notes-display.md:3` → `- boot.img 打包 = \`scripts/mkbootimg.py\`（v2 头，pack/unpack/--selftest）：字段偏移与成因见 \`MEMORY.md:47\`。` |

### 3.5 P1 组：`MEMORY.md` 内 vk127 相关三对（浅克隆 / 压力测试 / boot_b 签名）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/memory/MEMORY.md:45,51,59` | 「浅克隆 fetch 被拒 ⇒ 从本地 worktree fetch」两条 + 「vk127 身份登记」两条，互相包含 | `grep -n '浅克隆\|vk127 身份登记' .pi/memory/MEMORY.md \| cut -c1-60` | 保留 `:51`（浅克隆机制）+ `:59`（vk127 具体源提交 `24223e44ad80` + worktree fetch 命令）；`:45` → `vk127 身份登记注意（lane.sh alloc / 源提交须可达）：机制见本文件 :51，实例见 :59。` |
| **P1** | `.pi/memory/MEMORY.md:63,69` | 「vk127 压力测试 s7 = Q28 BAD 教科书签名」两条同事件（`:63` 讲 s7/s8，`:69` 讲 s7 + 首次活体样本） | `grep -n 'vk127 压力测试' .pi/memory/MEMORY.md \| cut -c1-60` | 合并为一条（保留 `:69`，把 `:63` 的 s8 结果一句并入），`:63` → `vk127 压力测试 s7/s8：见本文件 :69（同一事件）。` |
| **P1** | `.pi/memory/MEMORY.md:119,123,149` | 「vk127 走 `sign-boot-b.sh` → sha `83d4e08a…` → 读回一致」写 **3 遍**（`:149` 是 C5 状态，只作子句） | `grep -n '83d4e08a' .pi/memory/MEMORY.md \| cut -c1-60` | 保留 `:123`（全链路 + 报错形态）为唯一正文；`:119` → `刷 boot_b 要走 AVB 自签（不能裸写）：见本文件 :123。`；`:149` 的第 ① 句 → `① vk127 已刷入 boot_b 并核验（见 :123）；` |

### 3.6 P1 组：`MEMORY.md` 内 EDL / 清理 / EDK2 三对

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/memory/MEMORY.md:188`、`:190` | 「EDK2/Mu 本地构建：`CLANG_BIN` 必须带结尾斜杠」写两遍 | `grep -n 'CLANG_BIN' .pi/memory/MEMORY.md \| cut -c1-60` | 保留 `:190`（两处关键坑那一条）；`:188` → `EDK2/Mu 本地构建工具链（clang-21 + llvm-ar + lld-21）：见本文件 :190。` |
| **P1** | `.pi/memory/MEMORY.md:170`、`:180`、`:3`、`:11` | 「`out/*.img` 账目耦合 / 禁重跑 `vk-identity.py`」在 MEMORY 内 4 处（另见 1.2 的 `AGENTS.md:36`） | `grep -n 'vk-identity.py' .pi/memory/MEMORY.md \| cut -c1-60` | 保留 `:180`（机制 + `ARCHIVE_GLOB`/`out_images()` 正解）为唯一正文；`:170` 的第 ① 句、`:3` 与 `:11` 的第 ① 条 → 一律换成 `账目耦合与禁重跑：见本文件 :180（资产台账口径 = RESOURCES §3 B3）。` |
| **P2** | `.pi/memory/MEMORY.md:174` 与 `:163` 尾段 | `.pi/trash` 受保护这条在 `:174`，`:163`（EDL 条）尾段又写「已清理入 `~/.pi/trash`」——同一机制的两次说明 | `grep -n 'pi/trash' .pi/memory/MEMORY.md \| cut -c1-60` | `:163` 尾段 → `已清理入回收站（\`.pi/trash\` 机制见 :174）。` |

### 3.7 P0 组：`USER.md` 内部同一条决定写两遍（5 对）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `.pi/memory/USER.md:43` 与 `:45` | 「尽可能利用上游，减少下游补丁」：`:43` 限定传感器/HAL，`:45` 升格为全项目哲学 —— 保留范围大的那条 | `grep -n '尽可能利用上游' .pi/memory/USER.md` | `:43` → `传感器/驱动/HAL 类任务的同一条口径：见本文件 :45（项目级开发哲学）。` |
| **P1** | `.pi/memory/USER.md:67` 与 `:73` | 「尽可能符合上游规范的同时实现功能」与「屏幕方向的最高期望（尽可能符合上游规范的同时驱动屏幕）」= 同一原话两次 | `grep -n '尽可能符合上游' .pi/memory/USER.md` | `:73` → `屏幕方向同本文件 :67（先做 pristine 对照臂区分下游/上游）。` |
| **P0** | `.pi/memory/USER.md:61` 与 `:63` | 「后续不再发上游邮件，等项目收盘」写两遍，`:61` 是旧句、`:63` 带例外清单 ⇒ 两份正文会让人漏掉例外与已解冻事实（`AGENTS.md:29-31` 记 2026-10-31 已授权代写、`AGENT-OPS.md:85` 另定汇报渠道） | `grep -n '不再发上游邮件' .pi/memory/USER.md` | `:61` → `2026-10-13 口径（只出草案不投递）：见本文件 :63；⚠ 已被 2026-10-31 授权取代，现行投递口径只读 \`AGENTS.md\`「上游发信」+ \`TASKS\` §7。` |
| **P1** | `.pi/memory/USER.md:69` 与 `:71` | 「坏发和冷暖没有必然关系 + SSH 可直重启到 bootloader」两条；`:71` 已带 2026-11-12 审计更正 | `grep -n '没有必然关系' .pi/memory/USER.md` | `:69` → `用户纠正「冷/暖复位」因果（同本文件 :71，并见其 2026-11-12 更正与 :87 的 reboot 停用口径）。` |
| **P1** | `.pi/memory/USER.md:77` 与 `:85` | 子代理网关两条（见 2.4） | — | 见 2.4 的替换文本。 |

### 3.8 ★P0 组：`USER.md:65` 的「不再区分 U1/U2」与三份 SSOT 的 U1/U2 台账互相矛盾

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `.pi/memory/USER.md:65` ↔ `AGENTS.md:21-22`、`INDEX.md:12`、`INDEX.md:21`、`DEVICE/README.md:208-213` | 记忆条目说「上机单元不区分 U1/U2，那个已经过时；DEVICE/TASKS 里残留的 U1/U2 属待清理项」，而 DEVICE §2.2 标题写「**唯一登记处**」、AGENTS/INDEX 把 U1/U2 写成在用口径 ⇒ 到底删不删 U1/U2 三处各执一词 | `rg -n 'U1 / U2\|不区分 U1/U2\|唯一登记处' AGENTS.md INDEX.md DEVICE/README.md .pi/memory/USER.md \| cut -c1-100` | `USER.md:65` → `上机单元口径（2026-10-13 明确）：**派工/上机不靠"单元身份"，靠 DEVICE §2.2 的当前状态**；U1/U2 作为台账行 ID 保留（不是角色）。——与 \`DEVICE/README.md\` §2.1-2.2、\`AGENTS.md\`「设备等价」同义。`（**需用户确认**：这决定 DEVICE 台账是否改名） |

### 3.9 P1 组：`notes-display.md` 自称「从 AGENTS.md 下沉」，实际 18 条里 14 条与 MEMORY/failures 重复

该文件头部（`.pi/memory/notes-display.md:1`）说正文是从 AGENTS.md 下沉来的细节；但**同一批事实在 `.pi/memory/MEMORY.md` / `failures-device.md` 已有正文**，于是变成三处正文。逐条映射（保留列 = 建议的唯一正文）：

| 严重度 | notes-display.md 行 | 重复的已有正文 | 证据命令 | 建议 |
|---|---|---|---|---|
| **P1** | `:4`（Q28 判据 GOOD/BAD 签名） | `MEMORY.md:55` | `rg -n 'dsi_isr=41' .pi/memory/` | notes-display 留一行指针 → `Q28 三态判据：正文 \`MEMORY.md:55\`（+ 探针 \`scripts/q28-devprobe2.sh\`）` |
| **P1** | `:5`（`dpms` 0644 只读 + 2.5 s 生效） | `MEMORY.md:81` | `rg -n '0644' .pi/memory/` | 同上（指针化） |
| **P1** | `:6`（冷起无桌面 = greetd 崩溃） | `MEMORY.md:153`、`:159` | `rg -n 'greetd' .pi/memory/MEMORY.md \| cut -c1-50` | 指针化，并把 MEMORY 两条先合并 |
| **P1** | `:7`（M1-7.3 重放配方 + DTB 153101 B 指纹） | `MEMORY.md:37`、`:39` | `rg -n 'payload \*\*取 vk64 树\*\*' .pi/memory/` | 指针化（MEMORY `:37`/`:39` 也要二合一） |
| **P1** | `:8`（`dtbo_a` 真根因 + `truncate -s 33554432`） | `TASKS/README.md:246-268` | `rg -n 'dtbo_a' TASKS/README.md \| head -3` | 指针化 → `a 槽卡 logo 的真根因与配方：正文 \`TASKS\` §5「2026-11-10（深夜，dtbo_a 真根因）」块 + \`scripts/uefi-a-slot-prepare.sh\`` |
| **P1** | `:10`（时钟 1970 → HTTPS rc=60） | `MEMORY.md:115` | `rg -n '1970' .pi/memory/ \| cut -c1-60` | 指针化（#299） |
| **P1** | `:11`（无 `fastboot fetch`） | `PITFALLS #290`、`MEMORY.md:206` | 见 2.7 | 见 2.7 |
| **P1** | `:12`（Waydroid 走 OpenRC） | `MEMORY.md:85` | `rg -n 'rc-service waydroid-container' .pi/memory/ \| cut -c1-60` | 指针化 |
| **P1** | `:13`（`ccodec=0` 根因） | `failures-device.md:97`、`:105` | `rg -n 'ccodec' .pi/memory/ \| cut -c1-60` | 指针化，并合并 failures-device 两条（保留 `:97`） |
| **P1** | `:14`（`vendor.img` 496 inode 恒满） | `MEMORY.md:137` | `rg -n '496' .pi/memory/ \| cut -c1-60` | 指针化（技能 `waydroid-image-bake` 里也是这条的展开，正文归技能） |
| **P1** | `:15`（容器 HAL A/B 定性） | `MEMORY.md:161` | `rg -n 'A/B 定性\|A/B：' .pi/memory/MEMORY.md \| cut -c1-60` | 指针化 |
| **P1** | `:16`、`:17`（相机判真出流 / 故障分层） | `MEMORY.md:83`、`:77` | `rg -n 'STREAMON' .pi/memory/MEMORY.md \| cut -c1-60` | 指针化 |
| **P1** | `:19`（设备侧 tar 抢资产） | `MEMORY.md:7` | `rg -n 'tar -C / -cf' .pi/memory/ \| cut -c1-60` | 指针化 |
| **P1** | `:20`（用户口径：优先上游 + 停手归档 + `timeout -k` + 目视优先） | `USER.md:43/45`、`failures-*` 多条、`AGENT-OPS.md:82` | `rg -n '目视' .pi/memory/USER.md \| cut -c1-60` | 指针化 → `用户口径（优先上游 / 停手归档 / timeout 兜底 / 目视优先）：正文 \`.pi/memory/USER.md\`。` |

> 结论：**`notes-display.md` 应整体降级为「一页指针表」**（每行 → 一个 `file:line`），
> 否则它既是 AGENTS 的下沉层、又是 MEMORY 的复制层，形成三层正文。改完后该文件 ≈ 18 行指针、零正文。

### 3.10 ★P0 组：`drop_caches` —— PITFALLS 内部两个条目互为对立指令

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P0** | `PITFALLS/sessions/11-存储TF卡扩分区.md:6-7` | 「严格测试方法（**必用！**）：写 → `sync` → `echo 3 > /proc/sys/vm/drop_caches` → 回读比对」 | `sed -n '6,7p' PITFALLS/sessions/11-存储TF卡扩分区.md` | 该行 → `- 严格测试方法（**改用 O_DIRECT**）：写 → \`sync\` → \`dd iflag=direct\` 回读比对。**禁** \`echo 3 > /proc/sys/vm/drop_caches\`（#513 实测主机冻结自动重启）。` |
| **P0** | `PITFALLS/sessions/166-页缓存位翻转与O_DIRECT校验纪律.md:46-49` | 「`drop_caches` = 危险动作，不要再发；要清缓存就重启或用 `O_DIRECT`」= 现行结论 | `sed -n '46,49p' PITFALLS/sessions/166-*.md` | 保留 = 唯一正文；建议在该节首行加 `（本条推翻 #513 之前各处「必用 drop_caches」的写法，见 sessions/11 已修正）`。 |
| **P1** | `.pi/memory/notes-display.md:18`、`.pi/memory/MEMORY.md:182`、`TASKS/README.md:169` | 禁令与 `O_DIRECT` 要求另有 3 份正文 | `rg -n 'drop_caches' .pi/memory/ TASKS/README.md \| cut -c1-60` | 三处 → 各一行指针 `页缓存位翻转与 O_DIRECT 校验、drop_caches 禁用：正文 \`PITFALLS #513\``（`TASKS:169` 保留"必须走 O_DIRECT"这半句即可）。 |

---

## §4 任务与报告层（TASKS / RESOURCES / reports / SESSIONS / HISTORY）

### 4.1 P1 组：完成度「公式 + 8 类词表」在 `TASKS` §0 注与 `scripts/check-progress-counts.sh` 头各写一遍

正文句：「`完成 = ✅+🟢+🎯`、`在范围 = ID 总数 − ❌/⛔`、合并行按区间展开；8 类状态词表」。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `TASKS/README.md:22`、`:25` ↔ `scripts/check-progress-counts.sh:8-11`（口径注释）与 `:29-31`（实现） | 注里已写「唯一出口 = 脚本」，却把**公式与词表原文各抄一份** ⇒ 脚本改词表时文档必漂 | `sed -n '22,25p' TASKS/README.md; sed -n '7,11p' scripts/check-progress-counts.sh` | `TASKS/README.md:22` → `> **公式与 8 类状态词表的唯一正文 = \`scripts/check-progress-counts.sh\` 头注**（\`✅/🟢/🎯\` 计入完成；\`❌/⛔\` 不进分母；合并行按区间展开）。`；`:25`（词表整行）→ `> 词表与计数口径：见脚本头注；本文件只使用这些标记，不在此定义它们。` |
| **P1** | `TASKS/README.md:24`（现状行硬写 **G1 36/37 / G2 9/13** + 推导「39 ID − ❌2」） | §0 表与注**手写了脚本要算的同一批数字与推导过程**，与「§0 上下表由脚本导出，勿手改」自相矛盾 | `bash scripts/check-progress-counts.sh`（现算输出 `G1 36/37`、`G2 9/13`，与文档同值但两套来源） | `TASKS/README.md:24` → `> **现状（现查）**：\`bash scripts/check-progress-counts.sh\`（当前输出 G1 36/37、G2 9/13；数字与推导不在本文件维护，\`--selftest\` 是门）。` |
| **P1** | `README.md:16,28`、`README.md:70-74`、`PROGRESS.md:115-116,122-127` | 公开面各自维护一份状态叙述：`README.md:16` 写「构建号到 `vk188`」、`README.md:28` 与 `PROGRESS.md:115` 各写「G2 9/13」、`README.md:70-74` 与 `PROGRESS.md:122-127` 是两张同构的目标状态表 | `rg -n 'G2 9/13' README.md PROGRESS.md \| cut -c1-80` | 公开面统一改为「完成度现查 \`scripts/check-progress-counts.sh\`；台账口径 \`TASKS\` §0」，不粘具体分数（`README.md:16` 的 `vk188` 属镜像/版本身份，应归 `versions/vk-registry.tsv` + `DEVICE` §1.1）。 |

### 4.2 P1 组：资产账（`out/` 归档 129→15/114、`.pi/trash` 不清、`backup` 不上云）—— 4 份正文

按 `INDEX.md:92`，**文件与资产台账的唯一正文 = `RESOURCES/README.md` §3**。

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `TASKS/README.md:168` | H1 行把 `build/` 190.7 G→17 G、`out/` 129→15 件、114 件移档、`.pi/trash` 裁决、`backup` 不上云**全部重抄**（同 §3 的 B1–B4） | `rg -n '129 件' TASKS/README.md RESOURCES/README.md \| cut -c1-80` | `TASKS/README.md:168` → `- **H1 资产清理** —— 已收口；账目与用户裁决（B1–B4）唯一正文 \`RESOURCES/README.md\` §3，执行账 \`reports/asset-tidy-20261105.md\` §7、\`reports/out-archive-20261105.md\`。` |
| **P1** | `.pi/memory/MEMORY.md:170`、`:180` | 同一批数字与规则各写一遍（另见 3.6） | `rg -n '129 件' .pi/memory/MEMORY.md \| cut -c1-80` | 见 3.6：`:170` 第 ① 句 → 指针；`:180` 保留**机制**（basename 无路径列 → `C=1`），数字换成「结果见 `RESOURCES` §3 B3」。 |
| **P2** | `RESOURCES/README.md:327`（B3 行）与 `RESOURCES/README.md:374` | `RESOURCES` 内部两处讲同一个 tar/回收站与归档结果 | `rg -n 'cloud-backup-y700-elden-20261016' RESOURCES/README.md \| cut -c1-80` | `:374` → `> 5.07 G 云盘包 tar 的落点与随 A0 回收：见 §3 表 **A0** 行。` |

### 4.3 P1 组：`TASKS` §4 复述 `reports/script-redundancy-audit-20261112.md` §0（详见 2.9 的冲突处置）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P1** | `TASKS/README.md:136` ↔ `reports/script-redundancy-audit-20261112.md:14-21`（§0 第 1/2/3/7/8 条） | 报告的 §0 结论（唯一入口、内核路径相同、cycle 两路不通、uefi-oneshot 不通、25 s 停手判据）被 §4 逐条抄成待办正文 | `rg -n '停手判据' TASKS/README.md reports/script-redundancy-audit-20261112.md \| cut -c1-90` | `TASKS/README.md:136` 用 2.9 的替换文本（一句结论 + 三个指针）；「25 s 停手判据」这类**动手判据**若要在文档层常驻，落点应是 `PITFALLS` §0 或 RUNBOOK §2，而不是 §4 待办。 |

### 4.4 P1 组：`TASKS` §5 Q28 权威行内部并存两种口径（§1.5 已给替换文本，此处定"位置"）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议 |
|---|---|---|---|---|
| **P0** | `TASKS/README.md:1077` | 同一行内：开头「🟢 已规避·结项（2026-10-24，补采样门槛作废）」，行尾仍留「累计 vk151/vk152 线 **3 发真 POR 全 GOOD**，距判据 ≥8 发还差 **5 发**」 | `sed -n '1077p' TASKS/README.md \| grep -o '已规避·结项（2026-10-24\|距判据 ≥8 发还差 \*\*5 发\*\*'` | 行尾那段旧推导 → 换成 §1.5 第 3 行给出的「结项样本 = POR 5/5 + 暖 3/3 = 8/8」一句；旧推导下沉到 `TASKS/sessions/2026-11-03-TASKS行445-Q28.md`（文件已存在）。 |

### 4.5 P2 组：SESSIONS/HISTORY 的自相矛盾（写死计数 vs 自称现查）

| 严重度 | 位置 file:line | 现状 | 证据命令 | 建议精确改法 |
|---|---|---|---|---|
| **P2** | `SESSIONS/README.md:31` | 「**逐会话档案**：`sessions/YYYY-MM-DD-<名称>.md`（**共 171 个**）」——同文件 `:39` 又说「会话数一律现查，历史写过 162/168/198 三个矛盾值」 | `sed -n '31p;39p' SESSIONS/README.md` | `SESSIONS/README.md:31` → `- **逐会话档案**：\`sessions/YYYY-MM-DD-<名称>.md\`（**数量现查** \`ls SESSIONS/sessions/*.md \| wc -l\`），与 §3 表一行一文件；` |
| 正例 | `HISTORY/README.md:7-8`、`SESSIONS/README.md:39` | 「本文件不写死任何计数 / 一切数字现查」= 本次收敛的标准句式 | `sed -n '7,8p' HISTORY/README.md` | 不改；§1–§4 各条替换文本请照此措辞。 |

### 4.6 备注：`RESOURCES` §3 的小节编号与父级重号（非重复描述，仅记一笔供后续修）

`RESOURCES/README.md:235` 是 `## 3. 文件与资产台账`，其内 `:237/:276/:287/:333/:352` 又用 `### 1./### 2./### 3./### 4./### 5.` ⇒
出现 `§3 的 §3`（`可清理标记`）。引用时「RESOURCES §3」有歧义（资产台账 vs 可清理标记）。
证据：`grep -n '^## 3\.\|^### [0-9]\.' RESOURCES/README.md | head`。
建议：把内部三/四/五级小节改为 `### 3.1 版本控制边界 … 3.5 MIGRATION-LOST`，并把所有外部引用一次改齐（属重命名，需用户点头）。

---

## §5 执行顺序与风险

### 5.1 建议合并顺序（每批一个 commit，批间跑门）

| 批 | 内容（本报告的节） | 需谁授权 | 该批的验证命令 |
|---|---|---|---|
| **0** | **PITFALLS 内部矛盾**：`sessions/11:6-7` 的 drop_caches「必用」改为 O_DIRECT + 禁令（§3.10）；166 节首行加「本条推翻旧写法」 | agent 可做（`PITFALLS` 是经验正文层，且这是**安全类反向指令**，越晚改越危险） | `rg -n 'drop_caches' PITFALLS/ \| grep -v 166` 应只剩被修正的那条；`scripts/check-doctor.sh §8` 编号对账 |
| **1** | **记忆层去重**：§3.1–§3.6、§3.9（`notes-display` 整页指针化）、`SESSIONS/README.md:31` | agent 可做（`.pi/memory/` 是唯一可写记忆面，见 `RESOURCES/README.md:254`） | `scripts/check-project-memory.sh`；`bash scripts/check-doctor.sh`（记忆不参与 §8，但别撞 §7） |
| **2** | **`.pi/` 三件套互抄**：§2.1、§2.2、§2.3、§2.5、§2.6 | agent 可做（`.pi/` 规范层，非领域层 README） | 改后 `rg -n 'maxConcurrent\|单写者\|device-lock.sh' .pi/AGENT-OPS.md .pi/ORCHESTRATION.md .pi/CONCURRENCY.md` 每词应只剩 1 处正文 + N 处指针 |
| **3** | **P0 冲突：进 fastboot 唯一入口**：§2.9（`AGENT-OPS:37` + `PITFALLS/sessions/01:23` + `TASKS:136/140/91/162`） | **需用户点头**（改的是授权/禁止边界，属 `AGENT-OPS` §1/§2 语义） | `rg -n 'to-fastboot.sh\|reboot2 bootloader' .pi/AGENT-OPS.md PITFALLS/sessions/01-*.md TASKS/README.md RUNBOOK-BRINGUP/README.md` 口径唯一 |
| **4** | **Q28/Q24 权威回归**：§1.5 + §4.4（先补 `TASKS:1077` 的 8/8，再删公开面数字）；§4.1 公式/词表归脚本 | 父 agent（领域层 README，见 `.pi/AGENT-OPS.md:72`） | `bash scripts/check-progress-counts.sh --selftest`（rc=0）；`sed -n '1077p' TASKS/README.md \| grep -c '还差 \*\*5 发\*\*'` = 0 |
| **5** | **跨文件长尾**：§2.7（`fastboot fetch` 8 处 → #290）、§2.8、§1.6（INDEX §3）、§4.2、§4.3 | 父 agent | `rg -c 'fastboot fetch' AGENTS.md INDEX.md DEVICE/README.md .pi/AGENT-OPS.md` 每文件 ≤1 |
| **6** | **★`AGENTS.md` 常驻层**：§1.1 收尾行、§1.2 全部 13 条、§1.3 节标题、§3.8 口径澄清 | **必须用户确认**（理由见 5.2） | `wc -l AGENTS.md`（目标 ≤45 行）；`rg -n '禁重跑\|WARN=0\|不走 ustc-pool' AGENTS.md` 全 0 命中 |
| **7** | 收尾：`scripts/check-doctor.sh` 全量 + `git status` 干净 | — | `.pi/AGENT-OPS.md` §5 五项 |

### 5.2 ★ 需要用户确认的项（逐条点名）

1. **`AGENTS.md` §项目记忆整节降级（§1.2/§1.3）**——这是**每轮注入的常驻层**，agent 的第一性认知来自它。
   降级后 agent 必须先 `rg .pi/memory/` 才能拿到判据，检索失败即等于规则失效；
   收益是消灭 13 条与记忆层的口径漂移。**风险与收益都要用户拍板**，不建议 agent 单方面改。
2. **`AGENTS.md:50` 的 `WARN=0`**——权威 `AGENT-OPS.md:86` 只要求 `FAIL=0`。
   两种可能：AGENTS 是"更严"的意图，或 AGENTS 抄错。**取哪个口径需用户定**（本报告默认按权威 FAIL=0）。
3. **`AGENTS.md:50` 与 `MEMORY.md:147` 仍保留「文档不得要求 AI 写 summary」**，而 `AGENT-OPS.md:83` 已于 2026-10-19 作废该禁令。
   本报告按「已作废」处理，但这是**用户 2026-10-19 的裁定**，请确认是否连带把 `MEMORY.md:147` 降级为沿革条目。
4. **`.pi/memory/USER.md:65` 的 U1/U2 口径**（§3.8）——决定 `DEVICE` §2.2 台账 ID 是否保留。
5. **`PITFALLS #290` vs `RUNBOOK:217` 谁当正文**（§2.7）——两处证据不同（RUNBOOK 带 fastboot 版本号与用户原话）。
   本报告建议"把 RUNBOOK 的证据并入 #290"，但这会修改 PITFALLS 正文措辞，需用户认可"证据搬家"。
6. **`RESOURCES` §3 小节重编号**（§4.6）——属重命名，会牵动所有「`RESOURCES` §3.x」引用。

### 5.3 执行风险（改之前必读）

- **门禁会拦你**：`.githooks/pre-commit` 跑 `check-doctor --staged-fast`（§7 入口文档完整性 / §8 索引↔磁盘对账 / §9 / §10 / §11 / §13 / §14）。
  被拦先修，不要 `--no-verify`；大批搬迁才允许 `ELDEN_HOOK_SKIP=1`（`AGENT-OPS.md:50-55`）。
- **`TASKS` §0 数字有脚本门**：`check-progress-counts.sh --selftest` 断言 36/37、9/13。
  §4.1 只删"公式/词表/推导"的正文，**不要动 §1/§2 的行内状态标记**，否则 rc=1。
- **记忆文件有格式纪律**：条目用单独一行 `---` 分隔、**一条 ≤300 字**（全局 `~/.pi/agent/AGENTS.md`「记忆」节）。
  替换文本请保持单行；**合并条目时保留被合并条目的占位指针行**（不物理删除），
  以符合「PITFALLS 编号只补不重排」同款可追溯思路，也让 `git log -p` 仍能追到原文。
- **PITFALLS 索引行长度**：`PITFALLS/README.md` 的索引行 ≤800 B，超长 = §8 FAIL（`INDEX.md:44`）。
  §2.7/§2.8 只动 §0 与 sessions 正文，不动索引表。
- **单写者**：各角度 `README.md` + `.githooks` + `versions/` = 父 agent 专属（`AGENT-OPS.md:72`）；
  子代理执行本清单时必须被显式指派为该股单写者，否则改不动 README。
- **不要碰的三处**：`INDEX.md:55-68`（判定依据本身）、`HISTORY/README.md:7-8` 与 `SESSIONS/README.md:39`（标准句式）、
  `README.md:54-60`（目标段的"一行版 + 指回"已是合规形态，别把它扩回正文）。
- **本报告自身不进 SSOT**：按 `AGENT-OPS.md:46-48`「报告不得成为孤儿」，落地后请从
  `TASKS/README.md` §5/§4 或 `PITFALLS` 条目链向本文件路径，否则结论会随文件沉底。

### 5.4 预期收益（可核对）

- 逐行复述点 **103 → 约 38**（每组保留 1 处正文 + 其余改为指针行）。
- 常驻注入层 `AGENTS.md`：60 → ≤45 行；其中"经验/机制"类正文 13 条 → 13 条指针。
- 口径矛盾清零：`收尾（FAIL/WARN + summary 禁令）`、`进 fastboot 入口`、`Q28 样本数`、`drop_caches`、`U1/U2` 五处。
- 唯一正文位置全部可被一条命令验证：
  `rg -n '<该事实的关键串>' <范围内全部 md> | cut -d: -f1 | sort | uniq -c` ⇒ 正文文件计数应为 1。

---

## 附：本次审计用到的全部证据命令（可重放）

```bash
cd /home/xuqianhui/y700-elden && git rev-parse --show-toplevel     # 前置校验
# 收尾判据四副本
rg -n '收尾判据|收尾的定义|收尾」定义|「收尾」= 产物落盘' AGENTS.md INDEX.md .pi/AGENT-OPS.md .pi/memory/MEMORY.md
# 进 fastboot 入口冲突
rg -n 'to-fastboot.sh|属禁忌|不要用封装脚本代跑|reboot2 bootloader' .pi/AGENT-OPS.md PITFALLS/sessions/01-引导fastboot重启交接.md TASKS/README.md RUNBOOK-BRINGUP/README.md
# Q28 权威行内部矛盾
sed -n '1077p' TASKS/README.md | grep -o '已规避·结项（2026-10-24\|距判据 ≥8 发还差 \*\*5 发\*\*\|8/8'
# drop_caches 反向指令
rg -n 'drop_caches' PITFALLS/ | cut -c1-120
# pkill 自杀 7 遍 / POSIX sh 6 遍 / kexec --dtb 6 遍 / RAM 模块树 5 遍
rg -c 'pkill -f|pgrep -f' .pi/memory/failures-device.md
rg -n 'POSIX sh' AGENTS.md .pi/memory/ | cut -c1-80
rg -n -- '--dtb' AGENTS.md .pi/memory/ | cut -c1-80
rg -n 'lib/modules/<新UTS>' AGENTS.md .pi/memory/ | cut -c1-80
# fastboot fetch 八副本
rg -n 'fastboot fetch' AGENTS.md INDEX.md DEVICE/README.md RUNBOOK-BRINGUP/README.md PITFALLS/README.md .pi/AGENT-OPS.md .pi/memory/ | cut -c1-90
# 并发/单写者/设备锁/模型池 多副本
rg -n 'maxConcurrent|树内配额' .pi/AGENT-OPS.md .pi/ORCHESTRATION.md .pi/CONCURRENCY.md
rg -n '单写者|device-lock.sh|ustc-pool' .pi/AGENT-OPS.md .pi/ORCHESTRATION.md .pi/CONCURRENCY.md .pi/memory/USER.md AGENTS.md | cut -c1-90
# 完成度口径：文档 ↔ 脚本
sed -n '21,26p' TASKS/README.md; sed -n '7,16p' scripts/check-progress-counts.sh; bash scripts/check-progress-counts.sh
# U1/U2 口径冲突
rg -n '不区分 U1/U2|唯一登记处|设备称' AGENTS.md INDEX.md DEVICE/README.md .pi/memory/USER.md | cut -c1-100
```
