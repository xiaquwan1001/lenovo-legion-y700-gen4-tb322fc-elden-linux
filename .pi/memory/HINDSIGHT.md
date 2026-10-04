# Hindsight — elden（y700-elden）

Techniques and root causes proven on Qualcomm/Lenovo tablet flashing. Host-machine

<!-- Older entries compacted -->
topics/FLASHCTL-2026-10-03.md` + `TASKS.md G1-24` + `GAPS.md Q23`。数字先行。

## 三条能力，现状完全不同

| 能力 | 现状 | 机制 | 缺口 |
|---|---|---|---|
| **reboot→fastboot** | 🟢 机制**已在设备上** | DT `reboot-mode`(nvmem-reboot-mode) → PMIC SDAM `reboot-reason@48`；`mode-bootloader=0x02`；驱动**已绑定** | 只缺 userspace：以 reason 调 `reboot(2)` RESTART2 |
| **reboot→EDL** | 🔴 主线 7.2 树**无通路** | 需 PSCI `SYSTEM_RESET2` vendor reset（`mode-edl=<0x80000000 0x1>`）或 TCSR dload cookie | 移植驱动+DT，`psci.c` 现在只发 architectural reset |
| **选槽/成功位/清次数** | 🟢 已有 `scripts/slot-attr.py` | GPT 分区项 byte6（`boot_*` 在 **LUN4 `/dev/sde`**） | 包成 CLI；与 **C7** 合并 |

关键证据：`/sys/bus/platform/drivers/nvmem-reboot-mode/reboot-mode` 已绑定；`reboot-mode.c` 靠 **reason 字符串**匹配 DT 的 `mode-*`（所以 busybox `reboot` 无参不行，必须 RESTART2）。`/sys/kernel/reboot/mode` 是 cold/warm 那个，**无关**，别用。

## 关于你指的 TWRP

`twrp/twrp.img` 是 Android bootimg（header v4，ramdisk 52 MB **LZ4**）；TWRP 的「重启到 EDL」走的是**厂商内核**的 reboot handler，属私有实现，**不能直接移植到 mainline**——但它印证了用户侧行为。主机暂无 `lz4`（python lz4 被 PEP668 拦），ramdisk 内脚本待解，只作行为对照用。

## 设计：一个 `eldroid-bootctl`

```
eldroid-bootctl reboot <bootloader|recovery|edl|system>
eldroid-bootctl slot {info|active|set-active <a|b>|mark-successful [a|b]|set-retry <n> [a|b]}
```
- reboot = `libc.reboot(...RESTART2, reason)`（ctypes，免编译）；slot 复用 `slot-attr.py`。
- 写操作要 root，写前自动备份 GPT 前后 34 扇区、写后读回校验。

## 分阶段

- **S1（免内核，可立刻测）**：先只验 `reboot bootloader` —— 机制已在，最坏结果只是进 fastboot，`fastboot reboot bootloader`/`fastboot reboot` 或物理键即回。
- **S2（需内核构建）**：EDL 要么移植上游 `psci-reboot-mode`（2026-05 系列 + `psci.c` vendor 出口 + DT），要么加 `qcom,dload-mode=<&tcsr 0x19000>` + 自加触发。建议以内核基座 **`elden/vk34-recon`** 出 `vk41-flashctl`（本特性与音频/热区增量正交）。
- **S3**：slot 子命令上机验证。

## 需要你拍板

1. **现在就走 S1**？我把 `eldroid-bootctl`（先带 reboot+slot）备好，你在设备上跑 `eld


## Automatic settled outcome - 2026-10-03

审查完成。先给数字，再说结构问题，最后给目标架构与可执行清单。

## 一、现状盘点（数字）

| 维度 | 数量 |
|---|---|
| 根目录 `.md` | **12 份**（INDEX/DEVICE/TASKS/RESOURCES/GAPS/ANDROID-COMPAT/RUNBOOK-BRINGUP/PITFALLS/LESSONS/SESSION-INDEX/FILES/AGENTS） |
| 全仓 `.md` | 300（archive/topics 51、archive 层 57、.pi/missions 11、.pi/agents 6、skills 3） |
| 会话 jsonl | **51**（SESSION-INDEX/db 仍写 45） |
| git 纳管 | 306 文件（scripts 78、.pi 61、archive 61、patches 31） |
| 顶层条目 | **40+**（源码树/产物/缓存/备份/文档 tar 全部平铺） |

结论：**内容已经很丰富，缺的不是文档，是"分层"。** 现在 12 份根文档属于两个不同平面，却平级摆放、互相登记计数，已经开始漂移。

## 二、审查发现（按严重度）

1. **维护面定义过时且自相矛盾。** INDEX §2 仍写"六视角=唯一维护面"，但 §5 又列出 LESSONS/SESSION-INDEX/FILES/db。TASKS/GAPS 的表头还写"六视角文档集之一"，INDEX 已改口径。**三处对同一定义各说各话。**

2. **同一事实多处维护，漂移已发生。**
   - 会话数：`.pi/sessions` 实有 **51**，SESSION-INDEX/db 写 **45**。
   - 主题数：INDEX 写 49，实为 51。
   - db docs 表 127，全仓 `.md` 实为 300（口径未定义）。
   - "G1 ≈80%" 同时存在于 INDEX §3、TASKS §0、DEVICE、GAPS——四处，无指定权威。

3. **元层知识散落根目录。** `PITFALLS.md`（正文，591 行）+ `LESSONS.md`（生成索引）+ `db/pitfalls` 表 = **同一知识的第三份拷贝**，且 db 最后重建 20:03、PITFALLS 改到 22:11 → **已不同步**。

4. **根目录资产/源码/产物/文档混放。** 5 个 `y700-elden-docs-*.tar.gz`、flashing-bundle tar、`sn.img`、40+ 顶层目录；**脚本两处**：根 `build.sh/cycle.sh/iterate.sh/pack.sh/elden-net.sh` vs `scripts/` 78 个。

5. **过程证据 vs 活文档边界被打破。** INDEX §6 声明 archive/topics"**不再更新**"，但 AUDIT3 昨天还在加、GAPS 持续引用它当活文档。

6. **`.pi/` 内部无说明。** missions/agents 存在同名文件（audio-graphopen.md 两处）、messenger 运行时状态、sessions 轨迹，彼此关系与是否纳管均未记录。

7. **记忆单体化。** `HINDSIGHT.md` **80 KB**、`FAILURES.md` 17 KB，按 `## Memory - <date>` 追加大块，检索靠 grep，已接近上下文成本上限。

## 三、建议目标架构：三个平面，边界显式

```
y700-elden/
├── INDEX.md              ← 唯一入口；只做路由 + 分层定义
├── docs/                 ← 【平面1】领域活文档（唯一维护面，状态只此一处）
│   DEVICE  TASKS  RESOURCES  GAPS  ANDROID-COMPAT  RUNBOOK-BRINGUP
├── meta/                 ← 【平面2】知识管理/元数据
│   FILES(资产台账)  PITFALLS(经


## Automatic settled outcome - 2026-10-03

收到，方案按这个改。已交付并 commit（`0f90f1c`）。

## S1 交付物（已上设备只读验证）

| 文件 | 作用 |
|---|---|
| `scripts/eldroid-bootctl` | `reboot <bootloader\|recovery\|system\|edl>`（ctypes `reboot(2)` RESTART2；EDL 占位、默认拒绝）+ `slot info/active/set-active/mark-successful/set-retry`（转发 `slot-attr.py`，**写前自动备份 GPT 前 34 扇区**） |
| `scripts/flash-recovery.sh` | Linux 内 `dd` 写 `recovery_b` + sha 回读 + 可选 `--reboot` |

设备上已放 `/usr/local/bin/`，`slot info`/`active` 实跑通过。

## 实读暴露的两个关键事实

1. **⚠️ `boot_b` 正在倒计时**：`byte6=0x2f → retry=5, succ=0`。mainline 从不调 `markBootSuccessful`，再启动 5 次 ABL 就置 unbootable 停 fastboot。这也正是你要的"重置启动次数"功能——**建议立刻**：
   ```bash
   ssh root@192.168.7.1 eldroid-bootctl slot mark-successful b
   ```
2. **TWRP 其实还没装**：设备 `recovery_a`/`recovery_b` 都是原厂（ramdisk ~16 MB）；`twrp/twrp.img` 才是 TWRP（ramdisk 52 MB）。另外 `backup/stock-259/recovery_{a,b}.img` 与 `twrp.img **同 sha**` —— 命名误导，它们不是原厂，恢复时别用。

## 为什么 recovery 目标选 `recovery_b`（免签）

`current-slot=b`（GPT 实测）；`vbmeta_b` 已被我们的 key 重签且 **Flags=3**、描述符**不含 recovery** ⇒ 写 `recovery_b` 不用签名。`vbmeta_a` 是原厂含 recovery 描述符，动它还要切槽，不值。

## 请你执行的验证（可逆，最坏进 fastboot/recovery）

```bash
# 0) 先止血
ssh root@192.168.7.1 eldroid-bootctl slot mark-successful b
# 1) 验 ABL 是否采纳 PMIC SDAM reason（这决定后面走 S2 还是移植 PSCI）
ssh root@192.168.7.1 eldroid-bootctl reboot bootloader
#    → 进 fastboot 即成功；fastboot reboot 回来
# 2) 装 TWRP 到 recovery_b
scripts/flash-recovery.sh twrp/twrp.img
# 3) 验 reboot recovery → TWRP
ssh root@192.168.7.1 eldroid-bootctl reboot recovery
```

## 待你拍板

1. 先跑 1) 验 `reboot bootloader`，还是直接连 TWRP（2→3）一起做？
2. TWRP 装好后是否要顺手做一次"从 TWRP 里重启到 EDL"的对照（记录 TWRP 如何触发 EDL，为将来 EDL 立项留证）？

（细节与证据在 `archive/topics/FLASHCTL-2026-10-03.md`；TASKS G1-24 / GAPS Q23 已更新。）


## Automatic settled outcome - 2026-10-03

A 已全部落地并提交（`e5e20df`）。自检全绿（仅剩 1 条真实待办）。数字先行：

## 已交付

| 项 | 产出 | 说明 |
|---|---|---|
| **分层定义** | `INDEX.md` §2 重写 | 「六视角」→ **三平面**：领域层(唯一维护面) / 元层 / 证据层；明确 **SSOT** 与生成物禁手改 |
| **表头统一** | 6 份领域文档 + `AGENTS.md` | 「六视角文档集之一」→「领域层活文档之一；分层见 INDEX §2」 |
| **自检脚本** | `scripts/check-doctor.sh` | 4 类检查：计数漂移 / 死链 / db 新鲜度 / 口径冲突；退出码可入 CI |
| **生成物纪律** | `db/build.py --check` + `db/README.md` + `LESSONS.md` 横幅 | 标注 `LESSONS.md`/`elden.db` 为生成物，禁手改 |
| **`.pi` 说明** | `.pi/README.md` | 分清 skills/memory/missions/agents/sessions/messenger，含 track 状态 |

`check-doctor.sh` 当前输出：**FAIL=0，WARN=1**——唯一 WARN 是 `.pi/sessions` 实有 **51** 个、而 `SESSION-INDEX`/catalog 只收录 **45**（6 个新会话未入索引）。这是真实待办，不是假警报。

## 两处我**没动**，需要你知悉

1. **`HINDSIGHT.md` 未拆分。** 我核实了：项目 `.pi/memory/` 就是本项目会话的**活跃 profile 记忆**（由 pi 按固定文件名加载，不是普通文档）。按主题拆成 `memory/decisions/` 有**加载不到而丢记忆**的风险，违背"先确认不破坏可用系统"。所以只做了 `.pi/README.md` 说明，**拆分留作 B 项另行验证加载机制后再做**。
2. **`HINDSIGHT.md` 的工作区改动未纳入本次提交。** 它在会话开始前就已是 dirty（疑似上一轮 harness 的压缩/追加），与本轮整理无关，故未替它背书。

## 下一步（等你选）

- **补 6 个会话进索引**（消掉最后的 WARN）：读 6 个新 jsonl，补进 `SESSION-INDEX.md` + catalog → 重建 db。
- **B 项**（低风险、改路径）：建 `meta/` 移入 FILES/PITFALLS/LESSONS/SESSION-INDEX/db；5 个根脚本并入 `scripts/`。
- **C 项**（需决策）：领域文档是否也进 `docs/`；`archive/topics` 是否真冻结；旧会话归档。

要我接着做"补 6 个会话索引"吗？这能把 doctor 打到全绿。


## Automatic settled outcome - 2026-10-03

明白，目标改成**入口最小化**。现状是「1 个入口 + 11 个根文档」，其中不少是**索引/台账/说明**类冗余入口。下面给一个收敛方案，确认后执行。

## 现状：根目录 12 个 `.md`，真正的「内容」与「索引/说明」混在一起

| 类 | 文件 | 问题 |
|---|---|---|
| 入口 | `INDEX.md` | 唯一入口 ✓ |
| 内容(领域) | DEVICE / TASKS / RESOURCES / GAPS / ANDROID-COMPAT / RUNBOOK-BRINGUP | 六份，各有独立价值 |
| 索引/台账 | `PITFALLS.md`(正文) · **`LESSONS.md`(生成索引)** · **`FILES.md`(台账)** · **`SESSION-INDEX.md`(索引)** | 后三者＝同一批知识的第二入口 |
| 说明 | `AGENTS.md`(pi 必需) · `.pi/README.md` · `db/README.md` | 可下沉 |

**可收敛的正是「索引/台账」层**——它们不是内容，只是内容的另一个入口。

## 建议：根文档 12 → 6（+AGENTS.md）

| 保留 | 从哪来 | 合并动作 |
|---|---|---|
| **`INDEX.md`** | 入口 | 保持唯一入口；`.pi/README.md` 的要点并入 §5 后删除该文件 |
| **`DEVICE.md`** | 设备 | 不变 |
| **`TASKS.md`** | 任务 | **并入 `GAPS.md`**（未解问题/风险）**+ `ANDROID-COMPAT.md`**（G2 方案） |
| **`RUNBOOK-BRINGUP.md`** | 操作 | 不变 |
| **`PITFALLS.md`** | 经验 | **并入 `LESSONS.md` 的零号纪律**，删除 `LESSONS.md`（它本就是 PITFALLS 的生成索引） |
| **`RESOURCES.md`** | 资源 | **并入 `FILES.md`（资产/版本控制边界）+ `SESSION-INDEX.md`（会话索引）** |

结果：根目录只剩 `INDEX / DEVICE / TASKS / RUNBOOK-BRINGUP / PITFALLS / RESOURCES`（+必需 `AGENTS.md`），**入口仍只有 INDEX 一个**；`db/` 继续做机器可查索引，不再需要有同义的人读第二份。

## 取舍（需要你知道）

- 合并后 `TASKS.md` ≈ 280 行、`RESOURCES.md` ≈ 410 行、`PITFALLS.md` ≈ 600 行——**文件变长**，但"入口"变少。这两者是此消彼长，我按你的偏好取"入口少"。
- `LESSONS.md` 由 `db/build.py --lessons` 生成。删除后我会把生成逻辑改为「不写根文件」或输出到 `db/`，并更新 `check-doctor`（不再检查 LESSONS 新鲜度）。
- `SESSION-INDEX.md` 是逐会话摘要（156 行），并入 `RESOURCES.md` 末尾作为"会话轨迹"节；`db/elden.db` 的 `sessions` 表保留。
- 所有跨文件引用（含 `INDEX`/`check-doctor`/`db/build.py`）会一并改写，`check-doctor.sh` 做死链兜底。

## 更激进（可选，若你要求再少）

再砍到 **4 份**：`INDEX`（使命+状态+路由）+ `TASKS`（任务+未解+G2+上机手册）+ `PITFALLS` + `RESOURCES`。代价：`TASKS.md` 会到 ~700 行（把 RUNBOOK 也吞进去），定位信息会变难。**我不建议**，但你要就做。

---

**按推荐方案（6 份）执行吗？** 还是你要更激进的 4 份？定了我就一次性重写 + 修引用 + 跑 `check-doctor` 验证。


## Automatic settled outcome - 2026-10-03

已更新会话笔记，等你选 A / B。


## Automatic settled outcome - 2026-10-03

查了 pi 的文档与本地扩展，结论先给：**pi 没有等价的结构化知识库服务**；`db/` 属于它自己 `extensions.md` 里定义的「External storage」。但 db **可以整体删掉**，因为它的功能都能被更少的东西覆盖。顺带发现一个关于记忆的重要事实。

## pi 原生能提供什么

| 原生设施 | 实际能力 | 能否替代 db |
|---|---|---|
| **profile memory**（`pi-profile-memory.ts`） | 只认 3 个固定文件 `USER/HINDSIGHT/FAILURES.md`，**追加式**，加载时**只取每文件尾部**（USER/FAILURES 各 4 KB、HINDSIGHT 8 KB），超 64 KB 自动压缩 | ❌ 不能查询，只适合少量durable偏好 |
| **`context_history`** | 搜/读 transcript 里的消息，**scope 仅当前会话**（branch/session） | ❌ 跨会话索引它不做 |
| **session manager**（`/resume`、`/name`、会话选择器） | 存会话、搜索/改名/删除 | ◐ 替代 db 的 `sessions` 表 |
| **`pi.appendEntry()`** | 会话内durable、不进模型上下文 | ❌ 单会话，非项目库 |
| **`grep` 工具 / `rg`** | 文件内容搜索 | ✅ 替代 db 的 `pitfalls`/`references_`/`tasks`/`docs` 查询 |

**关键点**：没有 SQLite/向量/索引类原生服务；要"原生查询"只能写**扩展**（反而增加基建，与"入口最少"相反）。

## db 的五张表 → 替代方案

| db 表 | 原用途 | 替代 |
|---|---|---|
| `sessions` | 跨会话轨迹、是否实机 | pi 会话选择器 + `rg '关键词' .pi/sessions/*.jsonl`（原生数据，零基建） |
| `pitfalls` | 关键词找踩坑 | `rg #关键词 PITFALLS.md` |
| `tasks` | 任务状态查询 | `rg` / `TASKS.md` 表格 |
| `references_` | 参考资源索引 | `rg 'url\|关键词' RESOURCES.md` |
| `docs` | 文档清单 | `git ls-files '*.md'` |

也就是说，db 提供的"机器可查"在**文档收敛到 6 份后，`rg` 已经够用**；唯一独有的是预计算的交叉统计，而那正是 `check-doctor.sh` 已经在做的轻量一致性检查。

## 建议：把 db 也一起删掉

- 删除 `db/`（4 个文件）与生成物 `LESSONS.md`；`db/build.py --lessons` 改为**不写根文件**或整体退役。
- `SESSION-INDEX` 内容并入 `RESOURCES.md` 会话轨迹节；会话回忆走 pi 原生选择器 + `rg .pi/sessions`。
- `check-doctor.sh` 保留，但去掉"db 新鲜度"检查（改为纯文本一致性检查）。
- 结果：根文档 12 → **6**（INDEX/DEVICE/TASKS/RUNBOOK/PITFALLS/RESOURCES + AGENTS），且**不再有生成物与第二索引**。

## 顺带一个纠正（关于 HINDSIGHT）

`pi-profile-memory.ts` 的 `readMemory()` 只把每个文件**最后 4–8 KB** 注入系统提示。所以：
- 之前担心的"拆分丢记忆"其实不成立——**只有尾部会加载**，拆成子目录反而更读不到。
- 正确做法是让 `HINDSIGHT.md` **保持小**（主动修剪旧条目），而不是拆分。现在 85 KB 里 90% 永远不进上下文。

---

要不要我把「删 db + 删 LESSONS + 6 份文档合并 + check-doctor 改造」作为


## Automatic settled outcome - 2026-10-03

SDAM 路线确认死亡，但我在 ABL 固件里找到了真正的机制线索。

## 已查明

1. **PMIC SDAM reason 不被采纳**：`reboot recovery` 后 SDAM cell 复位为 `0x00`，设备正常起 Linux（vk34recon）。→ `nvmem-reboot-mode` 这条链对 ABL 无效。
2. **ABL 认的是 DLOAD cookie（TCSR 寄存器）**：`uefi_a` 里有 `DloadCookieAddr / DloadCookieValue / EDLCookieAddr / "ERROR: Failed to set DLOAD cookie"` → 正好对应主线 `qcom,dload-mode = <&tcsr 0x19000>`。这是 **EDL** 的触发点（留档）。
3. **`misc` 在 LUN0 `/dev/sda7`**（boot/recovery 在 LUN4 `/dev/sde`），ABL 按分区名跨 LUN 读，所以 BCB 位置没错。

## 正在做零成本测试：BCB `boot-recovery`

`bootonce-bootloader` 不生效 ≠ `boot-recovery` 不生效（前者是 fastboot 的一次性命令，后者是 recovery 的经典命令）。我已：
- 备份 `misc` → `/root/misc-bak/`
- 写入 `misc` 首字段 = `boot-recovery`（已读回确认）

**请跑一条重启**（普通重启即可，不需要 reason——BCB 会留着）：

```bash
ssh root@192.168.7.1 'sync; reboot -f'
```

预期二选一：
- **进 TWRP** → 这条路通了：Linux 侧只需"写 BCB + 重启"，**零内核改动**，我把它包进 `eldroid-bootctl`。
- **仍进 Linux** → BCB 也被 ABL 忽略。下一步走 **DT-only 修**：给 `pmk8550_pon` 节点加 `mode-recovery = <0x01>`（上游标准写法，`qcom-pon` 驱动本树已编译 `=y`），即改用 **PMIC PON spare** 写 reason；只需重编 DTB 重打包。再不行才移植 PSCI vendor reset。

跑完告诉我进了哪个。


## Automatic settled outcome - 2026-10-03

三连否定后找到正解。汇总与下一步。

## 触发机制结论（全部实测）

| 机制 | 结果 |
|---|---|
| PMIC SDAM `reboot-reason@48`（DT 已绑的 `nvmem-reboot-mode`） | ❌ 不采纳 |
| `misc` BCB `bootonce-bootloader` | ❌ |
| `misc` BCB **`boot-recovery`**（本次新测） | ❌ |
| **TCSR DLOAD cookie** | ✅ 是 **EDL** 的触发点（`uefi_a` 里 `DloadCookieAddr/Value`、`EDLCookieAddr`；↔ 主线 `qcom,dload-mode=<&tcsr 0x19000>`） |
| **PSCI `SYSTEM_RESET2` vendor reset** | ✅ **SM8750 的上游正解**（`mode-bootloader=<0x80010001 0x2>`、`mode-edl=<0x80000000 0x1>`） |

上游正解是个 **13 补丁 / 559 行**的大系列（`psci-reboot-mode`+64bit reboot-mode+PSCI-MFD），**7.2 未合并**；而且它**没有 `mode-recovery`**，只有 bootloader/edl。

## 已交付：`elden/vk41-psci-reboot`（最小钩子）

只改 `drivers/firmware/psci/psci.c` **~35 行**：把 `reboot(2)` 的 reason 字符串映射成 SM8750 的 `SYSTEM_RESET2` vendor reset；**SMC 若返回（固件不支持）就回退普通重启**，不会卡死。正常重启路径不变。

- commit `4b643f169`（基于 `elden/vk34-recon`）
- 镜像 `out/boot-elden-vk41-psci.img`：image sha `f2038fb20f666263`，Image sha `e79dd77f0303b01c`，uname `7.2.0-debug-ge72a036ed4be-dirty`
- 已确认钩子字符串在镜像内核里

## 请你执行

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk41-psci.img --reboot
# ~30s 后确认在跑新内核：
ssh root@192.168.7.1 uname -r        # 期望 7.2.0-debug-ge72a036ed4be-dirty
# 测试：
ssh root@192.168.7.1 eldroid-bootctl reboot bootloader
```

预期：**真进 fastboot**（主机 `fastboot devices` 可见）。回退主机侧 `fastboot reboot`。
失败（仍进 Linux）：说明 TZ 不接受该 vendor reset，届时再议。
（`reboot edl` 也可测，但退出 EDL 需长按电源或 qdl；你说过 EDL 暂缓，先不动。）

## 注意

- **没有 recovery 的 vendor reset** → `reboot recovery` 不会进 TWRP。以后进 TWRP 的路线 = `reboot bootloader` → fastboot → `fastboot reboot recovery` / 直接刷写。
- 回退基线：`dd` 回 `bootslot-b/boot_b-vk34recon.img`（sha `53e5857a…`）。
- `misc` 里还留着我写的 `boot-recovery`（ABL 忽略、无害），需要的话我帮你还原备份。

跑完告诉我进的是 fastboot 还是 Linux。


## Automatic settled outcome - 2026-10-03

✅ **成功** —— Linux 侧 `reboot bootloader` 真进 fastboot（`HA2EXB0E`，current-slot=b）。PSCI `SYSTEM_RESET2` vendor reset 被 TZ/ABL 采纳，机制坐实。

## 现状与回退

- 设备当前在 **fastboot**。回 Linux：`fastboot reboot`
- b 槽现有内核 = **vk41-psci**（`uname` `7.2.0-debug-ge72a036ed4be-dirty`）；回退基线 `bootslot-b/boot_b-vk34recon.img`
- 已登记：`archive/topics/FLASHCTL-2026-10-03.md` §7–§9、TASKS G1-24、GAPS Q23、DEVICE U2

## 现在可用的 Linux 侧能力

| 命令（设备内） | 结果 |
|---|---|
| `eldroid-bootctl reboot bootloader` | ✅ 实测进 fastboot |
| `eldroid-bootctl reboot edl` | 同机制（`0x80000000/0x1`），**未测**（退出 EDL 需长按电源/qdl） |
| `eldroid-bootctl slot info/active/set-active/mark-successful/set-retry` | ✅ 已验证（GPT attribute） |
| `eldroid-bootctl reboot recovery` | ⚠️ **不行**：上游 sm8750 无 recovery 的 vendor reset |

## 建议下一步（你在 fastboot，正合适）

1. **回 Linux**：`fastboot reboot`
2. **测 TWRP**（recovery_b 已刷 TWRP）：
   ```bash
   fastboot reboot recovery
   ```
   - 进 TWRP → 你的原目标（TWRP 接管）达成；
   - 若起不来 → 说明 TWRP 那 52 MB ramdisk 借的是 `boot` 内核、而 boot_b 现在是 mainline；那就 `fastboot reboot` 回来再议。
3. **可选**：我写个主机侧 `scripts/to-recovery.sh`（`reboot bootloader` → 等 fastboot → `fastboot reboot recovery`），把"进 recovery"包成一条命令。

另外两个未决项仍在：桌面**关机/锁屏**（缺 elogind 守护进程）、熄屏→重启。

先试 `fastboot reboot recovery`？还是先回 Linux？


## Automatic settled outcome - 2026-10-03

## 电源关机：根因已定位并修复，需重启一次生效

**根因（两个叠加）**
1. **只装了 `libelogind`，没装 `elogind` 守护进程** → phosh 关机菜单调 logind 超时（日志 `phosh-session-manager: Failed to shutdown: Timeout was reached`）；且 gnome-session 在**会话启动时**就探测 logind，当时没有 → 缓存 `CanShutdown=false`。
2. `idle-delay=10` + `lock-enabled=true`（上一轮复现熄屏时设的）→ 10 秒熄屏即锁；root 空密码 + phosh 解锁断言失败 → **一直卡锁屏**。

**已做**
| 项 | 结果 |
|---|---|
| `apk add elogind elogind-openrc` | ✅ 已装，`elogind-daemon` 在跑 |
| `org.freedesktop.login1` | ✅ `CanPowerOff`/`CanReboot` = **yes** |
| `start-desktop.sh` 在 phosh-session **之前**启动 elogind | ✅ 已落（持久） |
| `gsettings`：`idle-delay=0`、`lock-enabled=false`、`idle-activation-enabled=false` | ✅ 已设（dconf 持久） |
| 即时解锁 | ✅ `ScreenSaver.GetActive=false`，桌面现在应该可以用了 |
| 内核 `pm_power_off=psci_sys_poweroff` | ✅ 已确认（SYSTEM_OFF 可用） |

**当前 `CanShutdown` 仍是 false** —— 因为 gnome-session 是在 elogind 起来**之前**启动的，缓存了失败。所以要**重启一次**，让 elogind 先于会话启动。

## 请你执行一次重启

```bash
ssh root@192.168.7.1 eldroid-bootctl reboot
```

回来后我验证 `CanShutdown=true`；然后你测**长按电源键 → 关机**（或电源菜单"立刻关机"）。

> 兜底（现在就能用）：`ssh root@192.168.7.1 eldroid-bootctl reboot --poweroff`

若重启后菜单仍不工作，我再把关机直接接到 logind（绕过 gnome-session 的 CanShutdown 门）。另外 TWRP 那次失败已记录在案、不深究。

提交：`20cc135`（elogind+关锁屏）、`79a4327`（TASKS G1-25）。


## Automatic settled outcome - 2026-10-03

第二轮根因找到并处理了。

## 真正卡住关机的原因

重启后 `CanShutdown` 已变 `true`，但**elogind 进程内部卡在「一个 shutdown 操作已在进行中」**：
- 任何 `Inhibit("shutdown", …)` 都返回 `OperationInProgress`（`sleep` 的却正常）；
- 于是 gnome-session / `gsd-power` 的关机路径（先取 shutdown delay inhibitor，再 `PowerOff`）全被拒，表现就是"点了立刻关机没反应"。

**诱因**：elogind 默认 `HandlePowerKey=poweroff`，电源键事件被它抢先�“占位”，与 phosh（持 `handle-power-key` block inhibitor）冲突，留下 in-progress 状态。

**处理**：
| 步骤 | 结果 |
|---|---|
| `kill -9` + 重启 elogind | ✅ `Inhibit("shutdown")` 立即恢复正常（返回 fd） |
| `/etc/elogind/logind.conf` 加 `HandlePowerKey=ignore` / `HandlePowerKeyLongPress=ignore` | ✅ 已落，elogind 不再接管电源键（交回 phosh） |
| elogind 以新配置重启 | ✅ `pid=5343`，`CanPowerOff=yes`，shutdown inhibitor 可获取 |

## 请你现在测一下

**长按电源键 → 「立刻关机」**（应该是真断电了）。
若菜单仍不行，直接测后端：`ssh root@192.168.7.1 loginctl poweroff`。

- 成功 → 我再确认**重启后是否仍有效**（配置已落盘，但 elogind 的启动顺序要复核）。
- 仍失败 → 我绕过 gnome-session：把 gsd-power/电源菜单直接接到 `eldroid-bootctl reboot --poweroff`。

兜底一直可用：`ssh root@192.168.7.1 eldroid-bootctl reboot --poweroff`。

（`logind.conf` 两行 + rootfs 重建须知已记入 `archive/topics/复盘-2026-10-03-持久化与睡眠.md` §6.1，commit `e9d03f9`。）


## Automatic settled outcome - 2026-10-03

整套重构完成并提交（`183477b`）。自检 **FAIL=0 / WARN=0**。

## 结果

| 指标 | 前 | 后 |
|---|---|---|
| 根目录 `.md` | 12 | **6 维护文档 + `AGENTS.md` = 7** |
| 入口 | INDEX + 11 份 | **唯一入口 `INDEX.md`** |
| SQLite/生成物 | `db/` 4 文件 + `LESSONS.md` | **0（全删）** |
| 第二索引 | FILES / SESSION-INDEX / LESSONS / catalog | **0** |
| 会话索引覆盖 | 45/51 | **51/51** |

## 具体动作

**合并（内容零丢失，只降级标题后追加）**
- `GAPS.md` + `ANDROID-COMPAT.md` → **`TASKS.md §5 / §6`**
- `FILES.md` + `SESSION-INDEX.md` → **`RESOURCES.md §3 / §4`**
- `LESSONS.md` 的零号纪律 → **`PITFALLS.md §0`**

**删除**：`GAPS.md`、`ANDROID-COMPAT.md`、`FILES.md`、`SESSION-INDEX.md`、`LESSONS.md`、`db/`（schema/build/README/elden.db）、`archive/sessions-catalog-2026-10-03.jsonl`

**新会话补录**（6 个，全部进 `RESOURCES.md §4`）
- `01a101b5` 问候（junk）
- `01a101bf` AUDIT2：vk34 后增量第二遍 + v1/v2 二分
- `01a101ee` AUDIT3：工具调用审计 + boot_b=vk40 混淆
- `01a101f3` Linux→fastboot 能力核实（后被推翻）
- `01a1021c` **PSCI vendor reset 实测进 fastboot + elogind 关机修复**
- `01a10224` 本次架构整理

**重写** `scripts/check-doctor.sh`：去掉 db 检查，改为「会话覆盖 / 死链 / 过期字样」三项，当前全绿。

## 现在的终态

```
y700-elden/
├── INDEX.md              ← 唯一入口（使命/分层/现状/命令/专题地图）
├── DEVICE.md             设备描述+状态
├── TASKS.md              任务/进度/未解(§5)/G2方案(§6)
├── RESOURCES.md          参考/本地资源/资产台账(§3)/会话索引(§4)
├── RUNBOOK-BRINGUP.md    上机手册
├── PITFALLS.md           零号纪律(§0) + 踩坑 #1–#88
├── AGENTS.md             pi 项目指令
├── scripts/check-doctor.sh
└── archive/              证据层（只增不改）
```

查询方式变为：`rg` 搜文本、pi 原生 `/resume` 找会话、`rg .pi/sessions` 搜轨迹——**无自建索引**。

> 说明：`.pi/memory/HINDSIGHT.md` 仍保持未提交（它是 harness 自动追加的活跃记忆，与本轮整理无关）；你刚定的「入口越少」偏好已存入项目记忆。


## Automatic settled outcome - 2026-10-03

完成并提交（`bea4c1b`），自检 FAIL=0 / WARN=0。

## 一、git 追踪审计

**结论：所有 durable 文本本来就在 git；漏网的是 `backup/` 下的"证据文本"，已补进。**

| 类别 | 状态 |
|---|---|
| 文档、脚本、内核补丁/config、`.pi/memory`、`.pi/skills`、`.pi/missions`、`archive/`、`AGENTS.md` | ✅ 早已 track |
| **`backup/` 证据文本**（本次新纳入） | `elden-dump.txt`、`HA2EXB0E-16+512/{getvar-locked,getvar-unlocked-1.1,gpt-list-pre-surgery,vk40-ram-acceptance-dmesg}.txt`、`pre-unlock/` 全部基线（getprop/by-name/sensorservice/packages/settings…）+ `SHA256SUMS` |
| 仍 ignore | 二进制分区/GPT dump、`sn-neko-zuxos.img`（含签名 blob，敏感）、`sn.img` |

git 追踪文件数 **306 → 316**。

**仍被 ignore 的"文本但运行时/大"**（需你拍板是否要）：
- `.pi/sessions/` **54 M**（51 个会话 jsonl，即 `RESOURCES.md §4` 的原始素材）
- `logs/` **90 M**（串口/构建/agent 日志）
- `.pi/messenger/`（swarm 运行时任务卡）
- `backup/pi-assets-*`、`flashing-bundle/`（迁移快照，内容已在 `.pi/`）

> 我倾向**不**把 sessions/logs 入 git：体量大且可能含工具输出里的敏感信息；会话已有 `RESOURCES.md §4` 索引 + pi 原生会话文件。要不要纳入，你说一句。

## 二、过时/废弃/功能缺陷列表

放在 **`PITFALLS.md §15（DEPRECATED）`**（不新增根文件，维持"入口最少"），git 管理。五个子表：

| 子节 | 内容 |
|---|---|
| **15.1 废弃/合并/删除的文档** | GAPS/ANDROID-COMPAT/FILES/SESSION-INDEX/LESSONS/db/catalog 各自的"现在看哪" |
| **15.2 迁移/退役的外部资产** | `~/y700类原生安卓/` 退役、profile/技能/会话内聚迁移、迁移前备份与 flashing-bundle |
| **15.3 被取代/无效的会话** | 3 个 superseded（`01a0ed5b`/`01a100d9`/`01a101f3`）+ 5 个 junk（空/测试会话） |
| **15.4 技能参考中过时结论** | `grub-uefi-dual-boot.md`（sn.img 解锁已失效）、`tb321fu-*`（Gen3 勿套 Gen4）、两份 `community-tool-status-2026-08`、`gsi-device-adaptation/*`（a 槽路线已弃） |
| **15.5 已知功能缺陷** | 12 项（熄屏重启、vk34 回归、音频/相机/TF/BT/DP/NFC/CDSP、reboot recovery 无解、reboot edl 未测、60 Hz 黑屏）各带权威指针 |

已同步：`INDEX.md §2` 标注 PITFALLS 含 §15；`check-doctor.sh` 的过期字样扫描**排除 PITFALLS**（§15 故意登记旧文件名），其余活跃文档仍严格查。

---

两个待你决定：**①`.pi/sessions`/`logs` 是否入 git？②§15 是否要单独拆成 `DEPRECATED.md`？**（我建议都保持现状：不入 git / 不拆，以符合"入口最少"。）


## Automatic settled outcome - 2026-10-03

复查完成，找到真根因并已修复（**与 vk41 内核无关**）。

## 结论（数字先行）

| 项 | 结果 |
|---|---|
| 真根因 | elogind 的 helper `/sbin/{poweroff,reboot,halt}` 是 **busybox applet**，**不带 `-f` 时根本不调 `reboot(2)`** |
| 实证 | `strace`：`poweroff` → `kill(1, SIGUSR2)` 后 **exit 0**（`reboot`/`halt` 同理 SIGTERM/SIGUSR1）；dmesg 有 `System is powering down.` 却**从无 `reboot: Power down`** |
| 为什么无效 | 本机 **PID 1 = `/bin/sh /init`**（不是 busybox-init），不处理这些信号 → 关机假成功 |
| 连带假死 | elogind 对 poweroff/reboot/halt 这类**非 sleep** 动作不清 `delayed_action` → 之后所有关机都回 `OperationInProgress`（phosh 菜单"无反应"就是这个） |
| 修复 | `/sbin/{poweroff,reboot,halt}` 换成 `busybox <applet> -f` 包装 → 直调 `reboot(2)`，`strace -e inject` 已验证 |

> 前一轮把根因归给"电源键被 elogind 占位"，只 `kill -9` 治了症状；这次是**真根因**。v41 只改 `psci_sys_reset`，不碰 POWER_OFF。

## 已落地

- 设备已装：`/sbin/{poweroff,reboot,halt}` 包装脚本 + `/usr/local/sbin/fix-logind-poweroff.sh`；`start-desktop.sh` 启动 elogind 前调用（幂等，**在 `/dev/sda17` 上持久**）。
- 仓库提交 `47c14aa`：脚本 + `PITFALLS #89` + `archive/topics/LOGIND-POWEROFF-2026-10-03.md` + TASKS/DEVICE/RESOURCES。`check-doctor` **FAIL=0/WARN=0**。
- elogind 当前是排查用的 debug 实例（状态干净，`PreparingForShutdown=false`）；重启后由 start-desktop.sh 正常拉起。

## 请你做真机验证（关键最后一步）

**测试 1（后端，最直接）**：
```bash
ssh root@192.168.7.1 loginctl poweroff
```
预期：设备**真断电**（屏幕灭、SSH 断）。再按电源键开机。

**测试 2（你的原目标，电源键）**：
长按电源键 → phosh 电源菜单 → 点「立刻关机」→ 真断电。

> 回退：若真断电失败而设备卡住（PSCI `SYSTEM_OFF` 极少数固件不支持会转 `machine_halt` 自旋），长按电源键硬复位即可。

跑完告诉我结果。成功的话我把 G1-25 标 ✅ 收口。


## Automatic settled outcome - 2026-10-03

收口完成 ✅

## 结论

**电源键关机已跑通**：长按电源键 → phosh 菜单 →「立刻关机」= **真断电**。重启后包装脚本仍在（`start-desktop.sh` 开机幂等重装，落在 `/dev/sda17`，已实测）。

## 真根因（与 vk41 内核无关）

| | |
|---|---|
| 机制 | elogind 执行 `/sbin/{poweroff,reboot,halt}`（编译期绝对路径） |
| 缺陷 | 这些是 busybox applet，**不带 `-f` 只给 PID 1 发信号**（`SIGUSR2/TERM/USR1`）后 exit 0 |
| 后果 | 本机 PID 1 是 `/init`（shell，不处理）→ 关机假成功，且 elogind 永久卡 `OperationInProgress` |
| 修复 | 换成 `busybox <applet> -f` 包装 → 直调 `reboot(2)`（`strace -e inject` 已证） |

## 一个边角（已记录）

`loginctl poweroff` 在 **USB 连着时**会让设备立即重启——你判断为平板探测到数据线插入（VBUS/充电检测自动开机），这是独立行为，不是 elogind 的问题。**正式关机先拔 USB** 即可。

## 提交

- `47c14aa` 真根因定位+修复（脚本/`PITFALLS #89`/专题/TASKS）
- `1be1acf` G1-25 真机验证通过 + USB 边角
- `check-doctor` **FAIL=0 / WARN=0**

G1-25 已标 ✅ 收口。下一个待办回到未解项：**「熄屏→整机重启」**（G1-22/Q21）和 **vk34 后增量回归二分**（G1-23/Q22）。


## Automatic settled outcome - 2026-10-03

日志采集方法已就位（`scripts/devlogs.sh`，已提交 `18bbf08`）：

| 子命令 | 用途 |
|---|---|
| `pull [tag]` | 单次 SSH 抓设备快照（`dmesg`、`/run/*.log`、`/var/log/kmsg`、`pstore`、uname/boot_id/uptime/power）→ `logs/devlogs-<tag>-<ts>/` |
| `watch [秒] [间隔]` | 周期 pull，并靠 `boot_id` 变化**自动标记复位**（抓"熄屏→重启"这类瞬时事件） |
| `pstore` | 读 ramoops 崩溃日志（survives 复位，无需设备侧写入器 → 无观察者效应） |
| `tail` / `serial` | 实时 dmesg / 主机串口 `/dev/ttyACM0` |

冒烟已通过。顺带一个日志发现：**vk41 的 `CONFIG_SUSPEND` 未开** → `/sys/power/mem_sleep` 不存在、`/sys/power/state` 为空（suspend 被整个拿掉了），这本身就是个待确认的改动。

不过——**"这两个改动"具体指哪两项？** 我不敢猜错，列几个候选请你点一下：

1. **logind 电源**：`HandlePowerKey=ignore` + `/sbin/{poweroff,reboot,halt}` 包装（本轮已验关机；短按熄屏/唤醒还未单独验）
2. **vk41 PSCI**：`reboot bootloader` / `reboot edl` 两个 vendor reset（只验了 bootloader，edl 未测）
3. **G1-23 二分**：`vk34-recon` ↔ `vk40` 两个内核版本/增量是否正常
4. **G1-22**：熄屏→重启 的修复改动

你指哪两个？（如果是别的，直接说改动内容即可。）确定后我就用 `devlogs.sh` 建基线、跑对照、出功能验证结论。


## Automatic settled outcome - 2026-10-03

已就绪。**vk42 = 当前 vk41（含 PSCI）＋ 干净重落这两项改动，不带 vk40 调试插桩**，已编译并校验内容：

| 项 | 证据 |
|---|---|
| 产物 | `out/boot-elden-vk42.img`（sha256 `40c87976…`，83 MB） |
| 内核 | `7.2.0-debug-geb432f18a0d1`（唯一 uname，便于版本归属）；含 `q6i2s_prepare` 符号、**0 处 DBG** |
| 音频修复 | `q6apm.c` 3 处改用 `audioreach_alloc_apm_cmd_pkt`；`q6apm-lpass-dais.c` 加了 `q6i2s_prepare`（BE graph 在 prepare 起） |
| 温控 | DTB 四级 trip `0x11170/0x14050/0x15f90/0x19a28` = **70/82/90/105 ℃**（当前 vk41 是单级 105） |
| tplg | ramdisk + 持久 root 都是自定义 10436 B 版（音频前提具备） |

## 请你刷入（设备侧断联操作，你来执行）

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk42.img --reboot
```
约 1–3 分钟回 SSH。**回退**：`scripts/flash-b.sh out/boot-elden-vk41-psci.img --reboot`

> 我也可以只跑"写入+回读校验"（不重启），你再单独重启——你选。
> 注意：这两项正是"熄屏→重启"的**嫌疑增量**，刷回后可能重现；我会用 `devlogs.sh watch` 盯 `boot_id`。

## 刷好后我来跑验证

- **温控**：`/sys/class/thermal/*/trip_point_*` 应现 70/82/90/105；跑 `thermal-stress.sh` + `thermal-watch.sh`，出稳态温度/频点与 cdev state。
- **音频**：`amixer -c0 cset numid=8 on` + `speaker-test`；抓 `dmesg` 的 q6apm 图状态（`GRAPH_OPEN/START status`），**由你确认是否出声**。
- **回归监控**：全程 `devlogs.sh watch`，捕捉熄屏/复位。

要我现在就把 vk42 写入 boot_b（不重启）吗？还是你直接跑上面那条？


## Automatic settled outcome - 2026-10-03

温控侧已确认生效；音频侧技术上链路是通的（MI2S bclk 在走），且发现两个功放音量 `numid=1/2` **默认是 0**（可能原来就没声）。我刚把它拉到 1023 并播了 8 秒 1 kHz 正弦。

**关键问题：你刚才听到扬声器出声了吗？**（1 kHz 蜂鸣/正弦音）

同时把目前证据汇总如下：

## 温控 ✅（功能正常）

| 检查 | 结果 |
|---|---|
| CPU/GPU 热区 trip | 全部 `120000 125000 70000 82000 90000 105000`（hot/critical + 四级 passive）|
| cooling device | `cpufreq-cpu0` 0/15、`cpufreq-cpu6` 0/15、`devfreq-3d00000.gpu` 0/13 |
| 空闲温度 | CPU 38–44 ℃ |

下一步我会跑 `thermal-stress.sh` + `thermal-watch.sh`（约 6 min），看四级 trip 是否按预期逐级降频。

## 音频 ◐（链路通、待听声）

| 检查 | 结果 |
|---|---|
| 声卡/控件 | `Lenovo-Y700-Gen4`；`numid=8` MM1→SECONDARY_MI2S_RX 路由 ✅ |
| **`SEC_MI2S_IBIT` 时钟** | **enable=1 / 1.536 MHz，consumer `dai@12` bclk** ← 0011 修复的直接证据 |
| PCM | state=RUNNING，指针推进 |
| dmesg | 无 q6apm graph 报错；仅有 `wsa_macro … flat cache` 无害告警 |
| 音量 | `Left/Right Playback Volume` 默认 **0**，已拉到 1023 |

## 一个已确认的"非回归"

`dmesg` 里 boot 6.8 s 的 `qcom-apm … CMD timeout for [1001021] opcode` 在 **vk41 也有**（vk41 快照里有 5 处），不是 vk42 引入的。

> 另外这两项正是"熄屏→重启"的嫌疑增量。要不要我同时开 `devlogs.sh watch` 盯 `boot_id`，边测边抓？


## Automatic settled outcome - 2026-10-03

修复已提交（`31cde62`）。新 boot 镜像已就绪：

| 项 | 值 |
|---|---|
| 产物 | `out/boot-elden-vk43.img`（sha256 `f3e53fe4…`，83 MB） |
| 内容 | vk42 + **tplg SD 线修正**（SD0→SD1，`db7e16e7…`，已同时写入 ramdisk 和持久 root） |
| 内核 | 同 vk42（`geb432f18a0d1`，音频 0009/0011 + 温控 0010 都在） |

## 请你刷入

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk43.img --reboot
```
回退：`scripts/flash-b.sh out/boot-elden-vk42.img --reboot`

> 理论上这一步**必须冷启**（运行期重载 tplg 会 ADSP 图残留，文档已记）。刷好回 SSH 后我来开 mixer、音量拉满、放测试音，**由你听声**。

## 这次修复的根据

- 功放 I2S 数据脚 = `gpio124 = i2s1_data1`（**SD1**），主 DTS 与原厂 DT dump（`probe/result/devicetree.dts`）**完全一致**。
- 但 tplg 是从 Google SC7180 SEC-I2S 模板抄来的 `SD_LINE_IDX_I2S_SD0`（=值 1），ADSP 便往 SD0/gpio122 发数据 → 功放挂在 SD1 收不到。
- 证据链：整条 DAPM 图全 On、`SEC_MI2S_IBIT` 时钟 1.536 MHz 在走、功放未静音/音量最大且 PLL+ready 就绪，**但 SYSST 的 SWITCHING 位不置位**（无输入信号）= 数据没到功放。

刷好后我来跑验证；若仍无声，下一步查 WORDSELECT/数据格式或功放 I2SCTRL。

> 另：设置界面输入输出设备为空是**独立问题**（系统里没装 PipeWire/PulseAudio 守护进程，只有库）。ALSA 出声确认后再装音频服务补上 UI。


## Automatic settled outcome - 2026-10-03

收口完成 ✅

## 结果

| 改动 | 状态 | 关键证据 |
|---|---|---|
| **温控**（0010，四级 trip） | ✅ 功能正常 | 所有 CPU/GPU 热区 `70/82/90/105 ℃`；cdev `cpufreq-cpu0/6`、`devfreq-gpu` 就位 |
| **音频**（0009/0011 + tplg SD 线） | ✅ **出声** | `SEC_MI2S_IBIT` 1.536 MHz；功放 SYSST `0x0215`→**`0x2315`（SWITCHING 置位）** |

**过程要点**：
1. 这两项在原 vk41 里被 `vk34-recon`（隔离熄屏重启）整批回退 → 新分支 **vk42** 干净重落（`geb432f18a0d1`），保留 PSCI。
2. 音频图全通但无声，真根因不在内核改动，而在 **tplg 的 MI2S SD 线抄错**：功放接 `gpio124=i2s1_data1`（SD1），tplg 却用 SD0 → ADSP 往 gpio122 发。改 `SD_LINE_IDX_I2S_SD1` 后出声（**vk43**）。
3. tplg 在 boot 早期从 initramfs 加载，故用**字节级替换**改了 ramdisk + 持久 root。

**提交**：`31cde62`（tplg 修复）、`cddb1ca`（收口：`PITFALLS #90`、`archive/topics/AUDIO-SDLINE-2026-10-04.md`、TASKS/DEVICE/RESOURCES）。`check-doctor` **FAIL=0/WARN=0**。当前设备 = vk43。

## 剩余待办（音频侧）

- **UI/应用音频**：系统只装了 `pipewire-libs`/`libpulse`（库），没有音频服务守护进程 → 设置界面"输入输出设备"为空。需装并启用 **PipeWire + WirePlumber**（或 PulseAudio）。
- 左/右两片 AW88461 分别验证、录音通路。
- 「熄屏→重启」仍未解（本轮 vk42/vk43 暂未复现）。

下一个做哪个？我建议先把 **PipeWire/WirePlumber** 装上（让设置界面和浏览器等应用有声音），这是"功能健全"的必要一块。


## Automatic settled outcome - 2026-10-03

音频这块收口完成 ✅

## 结果（冷启持久已验证）

| 项 | 状态 |
|---|---|
| ALSA 出声 | ✅（tplg SD1 修正） |
| **桌面音频服务** | ✅ **PipeWire + WirePlumber + pipewire-pulse**，由 `/etc/xdg/autostart` 自启 |
| **输出设备** | ✅ `Active Profile=HiFi`，sink = `HiFi__Speaker__sink`（GNOME 显示 **"Built-in Audio Speaker playback"**） |
| UCM2 | ✅ `scripts/audio-ucm/`（自动开 `numid8` 路由 + 抬功放音量；`start-desktop.sh` 幂等安装） |
| 输入设备 | ❌ **仍缺**：本卡只有 Secondary MI2S 播放 DAI，`arecord -l` 为空 |

提交：`9934f7b`（PipeWire+UCM）、`34394bc`（文档收口）。`check-doctor` FAIL=0/WARN=0。

## 建议先确认一步

请打开 **设置 → 声音**，应能看到输出设备「Built-in Audio Speaker playback」，并可播放测试音。看一眼对不对。

## 下一步（二选一）

1. **补麦克风/录音（输入设备）**：需要在机器驱动加 capture DAI（VA/TX macro → DMIC）、tplg 加采集子图、内核配置补齐——是新一轮 bring-up（中等工作量），做完"输入输出设备"就齐了。
2. **回到「熄屏→重启」**（G1-22，稳定性阻塞）：用 `devlogs.sh watch` 抓 `boot_id` 做长时窗复现与定位。

你说哪个，我就开工。（也可以先只做个小验证：用 `arecord` 确认确实无 capture PCM。）


## Automatic settled outcome - 2026-10-03

vk44 就绪（含 DMIC capture）。**请你刷入**：

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk44.img --reboot
```
回退：`scripts/flash-b.sh out/boot-elden-vk43.img --reboot`

| 项 | 值 |
|---|---|
| 镜像 | `out/boot-elden-vk44.img`（sha256 `001516a0…`） |
| 内核 | vk43 + **VA capture dai-link**（cpu=`VA_CODEC_DMA_TX_0`/110，codec=`lpass_vamacro`）+ VA macro **DMIC pinmux**（dmic01+dmic23，4 麦） |
| tplg | 加采集子图：FE **MultiMedia3** → **VA codec-DMA TX0** → DMIC（10436→15380B，ramdisk 已重打包） |

## 依据（与上游 SM8750-MTP 完全同构）

- 原厂 DT 已有 `dmic01-default-state`/`dmic23-default-state`（gpio6-9）+ VA macro 节点 → 硬件是 **4×DMIC 接 VA macro**。
- 主线 `sm8750-mtp.dts`：`&lpass_vamacro { pinctrl-0 = <&dmic01_default>, <&dmic23_default>; }` + `va-dai-link`（`VA_CODEC_DMA_TX_0`）。
- DMIC 的 mux/DEC 选择由 UCM `cset` 完成（`codecs/qcom-lpass/va-macro/DMIC0/1EnableSeq.conf` 模板已有）。
- macro 驱动（`VA/TX/RX/WSA_MACRO=y`）本就编进内核。

刷好回 SSH 后我查 `arecord -l` 与卡 link，再补 UCM 的 `Mic` 设备并现场录一段验证。


## Automatic settled outcome - 2026-10-03

## 两个问题的诊断结果

### ① 音频输入端：ALSA 已通，差最后两步

| 检查 | 结果 |
|---|---|
| **采集 PCM** | ✅ `arecord -l` 出现 `device 2: MultiMedia3 Capture`（vk44 的 DTS+tplg 生效）|
| 设置界面看不到 | 缺 **UCM Mic 段**（已补 `scripts/audio-ucm/HiFi.conf` 并部署到设备）|
| 录音全 0 | ❌ 根因：**`vdd-micb` 偏置 = Off**（DAPM 实测）→ 缺 `vdd-micb-supply` + `"VA DMIC0..3","vdd-micb"` 路由 |
| 修法 | 已补进 DTS（对齐上游 MTP：`vreg_l1b_1p8` + `qcom,dmic-sample-rate=4800000`）→ **vk45** |

另外 debug 时发现：**`numid=15 MultiMedia3 Mixer VA_CODEC_DMA_TX_0` 默认 off** 会让 `arecord` open 直接 EINVAL——UCM 的 Mic 段已含这条 `cset`。

**vk45 已就绪**：`out/boot-elden-vk45.img`（sha256 `f46de05d…`）。回退 vk43/vk44。

### ② 马达反馈：硬件正常，是 feedback profile 的问题

- **硬件好**：直接调 `org.sigxcpu.Feedback.Haptic.Vibrate` 返回 `true`（应已震）。
- 原因：feedbackd 的 **profile = "full"**（默认），而默认主题里 `full` 只映射 **Sound**，Vibra\*（震动）只在 **"quiet"** profile 里。
- 已修：`gsettings set org.sigxcpu.feedbackd profile quiet` + 重启 feedbackd → 现在 `Profile=quiet`。**按键应当有震动了**（quiet = 震动代替声音；两者不能同时对同一事件）。

> 所以不是包缺失（`feedbackd`/`feedbackd-device-themes` 都在）。若你想要"震动+声音"同时，需要给本机写一个自定义 device theme（feedbackd 每个事件只能一种类型，得权衡）。

## 请你刷入（修麦克风）

```bash
cd ~/y700-elden
scripts/flash-b.sh out/boot-elden-vk45.img --reboot
```

刷好回 SSH 后我验证：`arecord` 录一段（应非静音）+ 设置界面出现麦克风输入设备。同时你可试试按键震动是否回来了。


## Automatic settled outcome - 2026-10-03

**找到"没有 input"的真正原因了**——麦克风根本不是 DMIC。

## 关键发现（原厂设备树 `backup/stock-elden/elden.dts`）

原厂 `sound` 节点的 `qcom,audio-routing`（line 16249）里**全是模拟麦，没有一条 "VA DMIC"**：

```
"AMIC1","Analog Mic1","AMIC1","MIC BIAS1",  ... "AMIC5","MIC BIAS4",
"VA AMIC1","Analog Mic1","VA AMIC1","VA MIC BIAS1", ...
"VA SWR_INPUT","WCD_TX_OUTPUT", "VA_AIF1 CAP","VA_SWR_CLK", ...
```

- 本机音频栈 = **Awinic smart PA（I2S 功放，我们已打通）+ WCD939x 编解码器**（SoundWire TX/RX）。
- 麦克风是**模拟麦（Analog Mic）**，偏置由 **WCD939x 的 MIC BIAS1–4** 提供，ADC 在 WCD 里，经 **SoundWire** 送给 ADSP。
- **主线 DTS 里没有启用 WCD939x**（只有 I2S 的 aw88461 功放）。

### 这解释了我们所有现象

| 观察 | 解释 |
|---|---|
| ALSA `MultiMedia3 Capture` 出现、整条 APM/DAPM 图 On | 图/软件链路没问题 |
| `vdd-micb` 加了我们 DTS 的 `vreg_l1b_1p8`，regulator 也 enabled | 但硬件上根本没接 DMIC，偏置来源也应是 WCD |
| 4 个 DMIC 通道全 0 | **硬件没有 DMIC 麦**（原厂 routing 里也没有） |

> 所以 vk45 的 DMIC 方向是错的（软件对、硬件不对）。要出声必须走 **WCD939x**。

## 可选路线

**A. 上 WCD939x（正确路线，中等偏大工作量）**
镜像主线 `sm8750-mtp.dts` 的 WCD939x 配置移植：
1. DTS：`wcd939x` 节点（SWR slave + `cdc-vdd-rx/tx/buck/px/mic-bias` 稳压 + reset GPIO + pinctrl）+ 启用 rx-macro / va-macro 的 SWR master。
2. 加 `wcd-capture-dai-link`（cpu `TX_CODEC_DMA_TX_3`，codec `wcd939x`+`txmacro`）。
3. tplg 加 WCD 采集子图；UCM 加 Mic。
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
