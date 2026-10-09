# 文档进度口径一致性审计 — elden（2026-10-09）

> 范围：`scripts/check-doctor.sh` 全量输出 + `INDEX.md` §3「现状速览」vs `TASKS.md` §0/§1/§4/§5 的进度口径。
> 纪律：**只审不改**；未修改任何领域层文件（INDEX/DEVICE/TASKS/RESOURCES/RUNBOOK/PITFALLS）。
> 结论口径：状态/完成度/样本数权威 = `TASKS.md` §0（数字）/§1（G1 明细）/§5（Q 项）；`DEVICE.md` §1.1（在机镜像）。

---

## 1. 结论（TL;DR）

- **headline 完成度百分比口径一致、无漂移**：`check-doctor` §3.5 实测 `[ok] G1/G2 百分比 INDEX ≡ TASKS`（G1≈90%、G2≈45%）。G3「PoC ✅」三处（AGENTS/INDEX/TASKS §0）一致。
- **「已定不做/搁置/取消」清单一致**：INDEX §3 五项（G1-26/27/28、G1-29、G1-10、G1-30、kexec）与 TASKS §1 状态（🟠/⛔/❌）及 §4「本轮不投入」完全对齐。**（PASS）**
- **发现 8 项不一致/过时**，均集中在 **`TASKS.md` §0 与 §4 落后于 §5（Q28）与 `DEVICE.md` §1.1 的实测进度**：
  - **中**：§0/§4/§5 把 **vk63** 当作「迭代进度 / 在机基线 / 现役」，但 ①构建线实际已到 **vk76**（`check-doctor` registry vk50–76、§4 kexec 用 vk65–70、§5 Q28 用 vk74/75/76），②在机镜像 = **vk64 v2**（`DEVICE.md` §1.1）。→ **当前"哪版是现役"两处口径打架**。
  - **中**：§0 阻塞项速览仍写 **Q28「vk74 已就绪待上机」**，而 §5 Q28 与 INDEX §3 均已记 **vk74 已上机 4/4 全坏 + vk75 好发基线在手 + vk76 已出**。INDEX 自称「数字权威=TASKS §0」，读者拿 §0 会读到**过时一轮**的进度。
  - **中/低**：INDEX §3「Linux 侧未解（**5**）」含 #106「进 GUI 整机卡死」；§0「阻塞项速览」只列 **4** 个 ID（无 ID 的 #106 未入行，虽在 §5.2 补救表）。跨文件计数 **5 vs 4** 口径不齐；INDEX 另有 **重复「⑤」**编号瑕疵。
  - **低**：INDEX「未开工」= {M1–M5, G1-8}；§0「未开始」列多一项 **G1-34 传感器**。二者「未开工」清单不同（SLPI 原生路线 vs 重力已通的拆分未在 §0 标注）。
  - **低**：§4 下一步**序号断裂** = 1…10 后**又出现「8.」**（失败/半成品登记，且它并非"下一步"）；§4.1 Q28 行动项与 §5.2「面板 init」补救路径仍指向**已执行且否掉**的旧动作。
- **`check-doctor` 覆盖面缺口（重要元结论）**：§3.5 只比对 INDEX↔TASKS 的 G1/G2 **百分比字符串**，**不校验** §0 的 vk 版本号/迭代进度、G1-34 状态、未开工/未解清单。因此上面 I-1/I-3/I-5/I-7 类过时**不会被 doctor 拦下**——doctor 绿 ≠ 进度口径新鲜。

---

## 2. 不一致项列表（按严重度）

| # | 位置 | 现有口径 | 冲突事实（权威来源） | 判定 | 严重度 |
|---|---|---|---|---|---|
| I-1 | `TASKS.md` §0 运维行「内核迭代至 **vk63**」 | 构建进度 = vk63 | `check-doctor` §5 registry **vk50–76 单调**；§4 kexec 用 **vk65–vk70**；§5 Q28 用 **vk74/vk75/vk76** | §0 迭代进度落后约 13 个版本 | 中 |
| I-2 | §0「在机镜像口径 DEVICE.md §1.1」（自身标题写 vk63）；§4 步 5「现役 **vk63** 基线」；§5 Q24/Q28/§5.2「基线改用现役 vk63」 | 现役/基线 = vk63 | `DEVICE.md` §1.1（L28/L73）：**U2 在机 boot_b = vk64 v2**（2026-10-08 烧录 + 启动健康 + qbootctl mark successful） | 「在机=vk64」与「现役/基线=vk63」两版并存，且 §0 标题 vk63 与它指向的 §1.1(vk64) 自相矛盾 | 中 |
| I-3 | §0 G1 阻塞项速览「🟡 Q28 …**vk74 已就绪待上机**」 | vk74 未上机 | §5 Q28 与 INDEX §3：**vk74 已上机 4/4 全坏**（当场否掉 pm_runtime 吞错 / 断电态两假说）、**vk75** 已拿好发基线 `logs/q28-BASELINE-good-vk75-dmesg.txt`、**vk76-freezetrace** 已出 | §0 落后 §5/INDEX 一整轮上机（SSOT 声明指向 §0，误导） | 中 |
| I-4 | INDEX §3「**Linux 侧未解（5）**」：Q28·Q24·Q26·G1-6·**#106 GUI 卡死** | 未解 = 5 | §0 阻塞项速览**只列 4 个 ID**（#106 无 Q/G1 ID，未入行，虽在 §5.2 补救表存在） | 跨文件「5 vs 4」；INDEX 另有**重复「⑤」**（#106 与划掉的 G1-34 都用 ⑤） | 中/低 |
| I-5 | INDEX §3「**未开工**：M1–M5、G1-8」 | 未开工 2 类 | §0「未开始」列 = {M1–M5, **G1-8 基准**, **G1-34 传感器**} | 两处「未开工」清单不同；§0 把 G1-34 计入未开始、INDEX 已移出（仅重力部分） | 低 |
| I-6 | §0 同一格「未开始: …G1-34 传感器」 | G1-34 未开始 | 相邻阻塞行「🟢 G1-34 重力/旋转**已通**」；§1 G1-34=🟢 | §0 内部自相矛盾（未标"仅 SLPI 原生路线"限定） | 低（并入 I-5 修） |
| I-7 | `TASKS.md` §4 下一步序号 = 1…10，随后**再出现「8.」**（L126 失败/半成品登记） | 两条「8.」 | 第二条「8.」实为**失败/半成品登记**，非"下一步"步骤 | 序号断裂/错标 | 低 |
| I-8 | §4 步 1（Q28）行动项「**vk62 基线对比 + 冷启对比（需用户断电），先定性**」；§5.2「面板 init」补救=「**温启跑 vk74 看是否自报 power-up failed**」 | 仍停留在"先定性/跑 vk74" | §5 Q28：冷启对比**已做并否掉线索**、vk74 **已上机无自报**（pm_runtime 假说否）、vk75 基线在手、**下一步=再抓一发坏发对拍** | §4/§5.2 落后 §5 Q28 SSOT，指向已执行且否定的旧动作 | 低/中 |

### 一致性通过项（明确记录，非问题）
- **完成度百分比**：G1≈90% / G2≈45% / G3 PoC —— INDEX §3 ≡ TASKS §0（doctor §3.5 `[ok]`）。
  - *判断性注记（非冲突）*：TASKS §0 对 G1 的定义 =「驱动原厂固件 **+ 上游提交**」，而"上游提交"半壁（M1–M5）**0/5**、G1-8 基准 0/1。故「G1≈90%」实际只度量**驱动 bringup 完整性**，未含上游化。建议 §0 加脚注标明百分比基准，使 INDEX 指针继承该限定（见建议 R-9）。
- **G2 45%**：§0 = 6 完成 / 4 进行 / 4 未开始 → ≈45%，与 §2 任务行拆分吻合。
- **G3 PoC ✅ / Steam 未上机**：与 §2「C-历史 Win-x86（Box64 0.4.5+Wine 9）PoC 已完成」+ Steam 端到端未上机一致；核心验收诚实标注。
- **「已定不做/搁置/取消」清单**：INDEX §3 五项 ↔ TASKS §1 状态（G1-26/27/28=🟠根因已定本轮不做、G1-29=⛔搁置、G1-10=❌取消无硬件、G1-30=❌不用 slim、kexec=§4.10 搁置）逐条对齐；**G1-26/27/28 与 kexec 属"本轮不做/搁置"（非永久取消），INDEX 括注已如实限定**。

---

## 3. `check-doctor.sh` 完整输出（原样保留）

命令：`bash scripts/check-doctor.sh` → `EXIT CODE: 0`；汇总 `FAIL=0  WARN=18`。

```
== elden check-doctor — /home/xuqianhui1001/y700-elden ==

== 1. 计数一致性 ==
  会话 jsonl=181  RESOURCES§4 收录=110  专题=96  根目录 md=7
  [ok]   根目录 7 份 md（6 维护文档 + AGENTS.md）
  [warn] 会话目录 181 ≠ 索引 110 → 补 RESOURCES §4

== 2. 死链检查（活跃文档）==
  [ok]   活跃文档无死链（30 份：6 维护 + .pi README/AGENT-OPS/CONCURRENCY/missions/agents/SKILL）

== 3. 过期字样扫描 ==
  [ok]   无过期文件引用
  [ok]   术语「领域层 4 份 + 经验层 1 份」一致

== 3.5 进度百分比口径 ==
  [ok]   G1/G2 百分比 INDEX ≡ TASKS

== 4. 已退场入口（2026-10-04 清理，见 archive/2026-10-04-retired-entrypoints/）==
  [ok]   无 .pi/pi-messenger.json
  [ok]   无 .pi/messenger
  [ok]   无 scripts/swarm.sh
  [ok]   无 scripts/swarm-monitor.sh
  [ok]   无 scripts/y700-swarm-reset.sh
  [ok]   无 scripts/y700-harness-restart.sh
  [ok]   无 scripts/start-y700-harness.sh
  [ok]   无 scripts/apply-swarm-patch.sh
  [ok]   无 patches/pi-messenger-swarm-detach-spawn.patch
  [ok]   无 patches/pi-messenger-swarm-spawn.js.patched
  [ok]   无 ~/.local/bin/flashing
  [ok]   无 ~/.local/bin/eacndev
  [ok]   无 ~/.local/bin/lob-remake

== 5. vk 版本账（registry / manifest / 镜像内 UTS）==
  [ok]   registry vk50-76 单调、无重复（26 行）
  [warn] 打包内核非本树内核（已知留档：包入 vk42 内核（geb432f18a0d1），当时树=vk48/vk50；slim 失败归因（缺 /bin/sh）不受影响）→ vk52-slim: 树/构建记录=7.2.0-debug-g5a70ade46a88 但镜像内=Linux version 7.2.0-debug-vk42-geb432f18a0d1 (elden@y700
  [warn] 打包内核非本树内核（已知留档：复用 vk54-dirty 内核镜像（b3b87ed1），非当时树（vk54 提交 g26cd13b1c4a2））→ vk54-slim: 树/构建记录=7.2.0-debug-g26cd13b1c4a2 但镜像内=Linux version 7.2.0-debug-vk54-g2b5badef00fb-dirty (elden@y700
  [warn] 打包内核非本树内核（已知留档：同 vk54-slim 内核（仅换 ramdisk））→ vk56-slim: 树/构建记录=7.2.0-debug-g26cd13b1c4a2-dirty 但镜像内=Linux version 7.2.0-debug-vk54-g2b5badef00fb-dirty (elden@y700
  [warn] 打包内核非本树内核（已知留档：同 vk54-slim 内核（仅换 ramdisk））→ vk57-slim: 树/构建记录=7.2.0-debug-g26cd13b1c4a2-dirty 但镜像内=Linux version 7.2.0-debug-vk54-g2b5badef00fb-dirty (elden@y700
  [warn] 打包内核非本树内核（已知留档：#131 manifest kernel 列=树 Image.gz；实际打包=vk47clean（sha 2321e3b9），boot_b 实跑 vk47clean）→ vk62: 树/构建记录=7.2.0-debug-g6c1376907dec-dirty 但镜像内=Linux version 7.2.0-debug-vk47clean-gbd114ca335e1 (elden@y700
  [warn] 打包内核非本树内核（已知留档：同 vk62（#131；同内核 vk47clean，仅换 H2 DTB））→ vk63: 树/构建记录=7.2.0-debug-g1389ed11b063-dirty 但镜像内=Linux version 7.2.0-debug-vk47clean-gbd114ca335e1 (elden@y700
  [warn] 打包内核非本树内核（已知留档：#131同类：打包内核=vk47clean（仅换 cambist DTB），构建时树 HEAD=0d4bedf55383；实验需固定内核）→ vk71-mxc: 树/构建记录=7.2.0-debug-g0d4bedf55383 但镜像内=Linux version 7.2.0-debug-vk47clean-gbd114ca335e1
  [warn] 打包内核非本树内核（已知留档：同 vk71-mxc（A/B 仅 DTB 的 power-domains/required-opps 不同））→ vk71-mxnom: 树/构建记录=7.2.0-debug-g0d4bedf55383 但镜像内=Linux version 7.2.0-debug-vk47clean-gbd114ca335e1
  [warn] 打包内核非本树内核（已知留档：Q28 测试内核（DSI cmd 闩锁恢复补丁）：UTS 刻意=vk64 以匹配在机模块，构建时树 HEAD=0d4bedf55383）→ vk72: 树/构建记录=7.2.0-debug-g0d4bedf55383 但镜像内=Linux version 7.2.0-debug-vk64-gd02658e63cf6
  [warn] dirty 位漂移（已知留档：同 commit g26cd13b1c4a2，镜像 -dirty；vk58c 已实机 fastboot boot 验收）→ vk58b-slim: 同 sha 但 dirty 位不同（7.2.0-debug-g26cd13b1c4a2 vs 镜像内 Linux version 7.2.0-debug-vk58-g26cd13b1c4a2-dirty (elden@y700）
  [warn] dirty 位漂移（已知留档：同 commit g26cd13b1c4a2，镜像 -dirty；已实机 fastboot boot 验收）→ vk58c-slim: 同 sha 但 dirty 位不同（7.2.0-debug-g26cd13b1c4a2 vs 镜像内 Linux version 7.2.0-debug-vk58-g26cd13b1c4a2-dirty (elden@y700）
  [warn] registry 前的历史镜像无 manifest（历史留白，见审计档案）：vk34recon-ram,vk34recon,vk46-ram,vk46,vk47-dtb42,vk47-ram,vk47,vk47a-ram,vk47clean

== 5d. 内核身份表（号 ↔ 内核二进制 ↔ 源提交）==
  [ok]   生效时刻之后的镜像无硬错（在途豁免 2 个）
  [warn] 在途豁免（收口后从 vk-identity-inflight.txt 删掉）：vk71-mxc(num_ne_tag(vk47),uts_dup5) vk71-mxnom(num_ne_tag(vk47),uts_dup5)
  [warn] 账本已登记的例外（理由见 vk-ledger-known-issues.tsv）：vk52-slim(tree_drift) vk54-slim(tree_drift) vk56-slim(tree_drift) vk57-slim(tree_drift) vk58b-slim(dirty_drift) vk58c-slim(dirty_drift) vk62(tree_drift) vk63(tree_drift) vk64(uts_dup5) vk71-mxc(tree_drift) vk71-mxnom(tree_drift) vk72-q28dsi(num_ne_tag(vk64)) vk72-q28dsi2(num_ne_tag(vk64),uts_dup5) vk72(tree_drift,num_ne_tag(vk64),uts_dup5) vk73-q28diag(num_ne_tag(vk64),uts_dup5) vk74-q28power(num_ne_tag(vk64),uts_dup5) vk75-q28ab(num_ne_tag(vk64),uts_dup5) vk76-freezetrace(num_ne_tag(vk64),uts_dup5)
  [warn] 存量欠账 46 个镜像有硬错（逐镜像见 vk-kernel-identity.tsv / vk-ledger-known-issues.tsv）
  [warn] 无版本号构建拷贝 1 个（build-boot.sh 默认产物，不拦构建；收口时改名或删）：boot-elden.img
  [ok]   versions/vk-kernel-identity.tsv 与当前镜像/registry/内核 ref 一致

== 6. 静态卫生（重复 / 死代码 / bashism）==
  [ok]   设备锁单一真源（lib-device-lock.sh）
  [ok]   #!/bin/sh 脚本无常见 bashism
  [warn] 疑似死脚本（无任何活跃引用，核实后删/标 legacy）: q28diag-forensic.sh

== 汇总: FAIL=0  WARN=18 ==
```

**输出解读（与进度口径相关）**：
- §1 `[warn]` 会话 181 ≠ 索引 110 → RESOURCES §4 会话索引欠 71 条（资产台账，不影响进度百分比）。
- §3.5 `[ok]` → 进度百分比字符串 INDEX≡TASKS 一致（**但它只比百分比数字，不比 vk 版本/清单**，见 §4 元结论）。
- §5/§5d 的 18 个 `[warn]` **全部是 vk 版本账本"已登记例外/留档"**（`vk-ledger-known-issues.tsv`）+ 历史留白 + 1 个疑似死脚本；属版本对账欠账，非文档进度冲突，但印证「registry 已到 vk76」，坐实 I-1/I-2 的 vk63 口径过时。

---

## 4. 建议修正（均为口径/文字级，建议由领域层维护会话落盘；本审计未改领域层）

1. **R-1（I-1）** `TASKS.md` §0 运维行「内核迭代至 vk63」→ 改为反映真实线：**在机 boot_b = vk64 v2**（`DEVICE.md` §1.1）、**构建/诊断线 = vk76**（Q28 系）。避免"迭代至 vk63"被读成当前进度。
2. **R-2（I-2）** 统一"现役基线"：要么 §4 步 5 / §5.2 / §5-Q24 的"现役 vk63"改 **vk64**，要么在 §1.1 说明 vk64 为在机、vk63 为某实验基线，二者择一。并在 §0「在机镜像口径 DEVICE.md §1.1」处去掉与 §1.1 冲突的 vk63 标题。
3. **R-3（I-3）** §0 G1 阻塞项速览 Q28 括注「vk74 已就绪待上机」→ 更新为「**vk74 已上机 4/4 坏（否 pm_runtime/断电态两假说）；vk75 好发基线在手，待一发坏发对拍**」，与 §5 Q28/INDEX §3 对齐。
4. **R-4（I-4）** 消除"5 vs 4"：§0 阻塞项速览补一行 **#106 进 GUI 卡死（无 ID，权威见 §5.2）**，或 INDEX §3 注明「5 = 4 个 ID + #106（无任务 ID）」；并修 INDEX §3 **重复「⑤」**（G1-34 划掉行改用独立标记或续号）。
5. **R-5（I-5/I-6）** §0「未开始」列的「G1-34 传感器」→ 限定为「**G1-34（仅 SLPI 原生 IIO 路线；重力/自动旋转已通）**」，与 INDEX §3「G1-34 重力已通移出未解」一致，消除 §0 内部自相矛盾。
6. **R-6（I-7）** §4 序号：两条「8.」→ 把第二条「失败/半成品登记」改为非序号小节（如「※ 失败/半成品登记」）或续到「11.」，使其不冒充下一步步骤。
7. **R-7（I-8）** §4 步 1（Q28）与 §5.2「面板 init」补救路径 → 从"先定性/跑 vk74"更新为「冷启已否掉差异项、vk74 已上机无自报；下一步 = **再抓一发坏发与 vk75 基线对拍 / 查 `clk_ignore_unused` 孤儿时钟 + ABL 遗留态**」。
8. **R-8（元结论，doctor 覆盖缺口）** 可选：给 `check-doctor.sh` §3.5 增补"§0 vk 版本 vs registry 最新 vk 单调上界"、"§0/§1 中『vk74 已就绪待上机』类旧态字样"扫描，使 vk 版本类过时能被自动拦下（当前需人工，正是本审计发现 I-1/I-3 的原因）。
9. **R-9（判断性注记）** `TASKS.md` §0 加一句脚注：G1 完成度百分比按 **驱动 bringup 完整性** 度量，**不含上游化 M1–M5（0/5）**；使 INDEX §3 指针继承该限定，避免"90% + 上游全未开工"被误读为矛盾。

### 无需处理（已核一致）
- 「已定不做/搁置/取消」清单、G1≈90%/G2≈45%/G3 PoC 百分比、G2 §2 拆分、G1「未开工」主体（M1–M5、G1-8）—— 与 §0/§1/§2/§4 一致。
- §4 下一步各开放项（Q28/Q26/Q24/G1-6/G1-23/C0/C1→C3→C2/顺路上机/M1–M5/kexec）**均仍开放**，无"已闭合却仍列为开放"的反向错误；仅部分**行动描述过时**（见 R-7）。
