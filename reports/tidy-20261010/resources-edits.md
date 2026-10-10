# T2 产出 1 — RESOURCES.md 同步提案（resources-edits.md）

> 生成：2026-10-10 资产整理子代理（worker）。
> **这是提案，不是改动。** 本文件与 `cleanup-candidates.md` 是本轮唯一允许写盘的两个文件；RESOURCES.md 本体由 integrator 落笔。
> 每个 OLD 块已用 `grep -F` 验证「全文件唯一」；OLD 逐字节从当前 RESOURCES.md 摘出。
> 实况基准：`git log`（至 `f037412` 12:35）、`ls scripts/ patches/ reports/ versions/`、`du -sh`、`ls -lt .pi/sessions/*.jsonl`、`versions/vk-identity-inflight.txt`。

## 覆盖清单（对应简报「必须覆盖」）

| 简报项 | 状态 | 落点 |
|---|---|---|
| §2 登记 q28-* 脚本 + serial-logger.sh | ✅ | §2.1 表新增一行 |
| §3 新增 `reports/` 目录定位 + q28 文件 | ✅ | §3.2 表 archive 行后插 `reports/` 行 |
| §3 `patches/q28-*` 系列（上机/草稿分类） | ✅ | §3.2 `patches/` 行 amend |
| §3 `build/`（4G 可再生）与 `out/` 现状 | ✅ | §3.2 `net/build/waydroid-ota` 行拆分 + `out/` 行 amend |
| §4 补 10-09/10-10 会话行 | ✅ | §4.2 末尾（`01a11667` 行后）追加 8 行 |
| §1 过时/疑似死链条目 | ➡️ 移交 | 不删、不改，全部登记到 `cleanup-candidates.md` §1（标『待核』） |

---

## 节 A — §2.1 新增 Q28 显示取证 / 串口抓取脚本行

**位置**：§2.1 构建链与工具表，`设备端操作` 行之后。
**理由**：`git status` 显示 `scripts/q28-{ab-delay,devprobe,verdict,serial-logger}.sh` 未入库、`scripts/q28-{boot-cycle,race-hunt}.sh` 已入库，均 §2 无登记。用途读脚本头注释确认（见每行括注）。

<<<OLD file=RESOURCES.md
| 设备端操作 | `scripts/{flash-b,thermal-watch,thermal-stress,bench-run,bench-install,serial-run,serial-log,oob-gs1-activate,win-x86-rootfs,win-x86-run,waydroid-proxy-setup,charge-ctl,charge-watch}.sh` |
===
| 设备端操作 | `scripts/{flash-b,thermal-watch,thermal-stress,bench-run,bench-install,serial-run,serial-log,oob-gs1-activate,win-x86-rootfs,win-x86-run,waydroid-proxy-setup,charge-ctl,charge-watch}.sh` |
| Q28 显示取证 + 跨重启串口抓取（2026-10-09/10 新增） | `scripts/q28-boot-cycle.sh`（温启→零写盘 `fastboot boot` 诊断内核→取证，单轮 GOOD/BAD，SSH over USB-NCM，本机无 adbd）、`scripts/q28-ab-delay.sh`（同时间窗 base/exp 各 N 轮统计坏发率，判 delay 能否压制 Q28）、`scripts/q28-verdict.sh`（串口日志三层判 GOOD/BAD：L1 cmd-DMA/panel-init、L2 ctl-reset/frame-done/vblank）、`scripts/q28-devprobe.sh`（设备端三态 NOCARD/STORM/GOOD，POSIX sh，只数风暴签名会把「无 card0」误判 GOOD）、`scripts/q28-race-hunt.sh`（设备端 rpm tracepoints 密集复现 power-on 竞态、零构建）、`scripts/serial-logger.sh`（ttyACM 跨重启自动重连抓取，pid `/tmp/q28_serial_logger.pid`） |
>>>

---

## 节 B — §3.2 `patches/` 行 amend（Q28 补丁系列上机/草稿分类）

**位置**：§3.2 顶层台账 `patches/` 行。
**理由**：`patches/` 现有 6 个 `q28-*.patch` + `q28-methodB-NOTES.md` 无登记。分类据 `patches/q28-methodB-NOTES.md`、`reports/q28-DOSSIER.md`（C13/C14、§B5）与 `reports/q28-handoff-20261010.md` §2/§6：
- **已上机取证（RAM `fastboot boot`，非日常 boot_b）**：`q28-dsi-regdump*.patch`（vk72/vk73/vk75 好/坏寄存器差分）、`q28-poweron-propagate.patch`（vk74 4/4 复现）、`q28-cmd-dma-delay.patch`（vk84 base/exp 单变量对，暖 8/8 GOOD 不判别、冷 A/B 仅 T1=NOCARD 未定案）。
- **候选未独立上机**：`q28-dsi-cmd-recover.patch`（vk64 源 d02658e63 的有界复位）。
- **草稿未编/未 apply/未上机**：`q28-methodB-round-byteclk.patch`+`q28-methodB-NOTES.md`（取整 byte-clk，`git apply --check` 通过，落点待按上游校准）。

<<<OLD file=RESOURCES.md
| `patches/` | 3.7 M | ✅ track | 内核补丁 + config 快照 + 工作树全量 patch + `kernel-history/`（各 elden 分支增量补丁，异地留档） |
===
| `patches/` | 3.7 M | ✅ track（q28 delay/methodB 草稿未入库） | 内核补丁 + config 快照 + 工作树全量 patch + `kernel-history/`（各 elden 分支增量补丁，异地留档）。**Q28 显示诊断补丁系列**（均设备无关诊断/实验件，非 G1 交付）：已 RAM 上机取证 = `q28-dsi-regdump.patch`/`q28-dsi-regdump-with-baseline.patch`（vk72/vk73/vk75 好坏寄存器差分）、`q28-poweron-propagate.patch`（vk74 4/4 复现）、`q28-cmd-dma-delay.patch`（vk84-{base,exp} 单变量对，暖 8/8 GOOD 不判别、冷 A/B 仅 T1=NOCARD 未定案）；候选未独立上机 = `q28-dsi-cmd-recover.patch`（vk64 源有界复位）；草稿未编未 apply = `q28-methodB-round-byteclk.patch`+`q28-methodB-NOTES.md`（取整 byte-clk，落点待按上游校准） |
>>>

---

## 节 C — §3.2 拆分 `net/ build/ waydroid-ota/` 行（build/ 现为 4G 内核构建树）

**位置**：§3.2 `net/ build/ waydroid-ota/` 行。
**理由**：该行把 `build/` 记成「<220 K ✅ track 小体积资产」——**已失真**。实测 `build/` = 4.0 G（几乎全在 `build/m1-upstream`，`scripts/build-kernel.sh` 工作区）。且 `.gitignore` 第 24 行**已含 `/build/`**（简报「父将补 .gitignore」实为**已完成**）。把 `build/` 单列成 ignore/可再生行，`net/` `waydroid-ota/` 保持 track。

<<<OLD file=RESOURCES.md
| `net/ build/ waydroid-ota/` | <220 K | ✅ track | 小体积资产 |
===
| `net/ waydroid-ota/` | <220 K | ✅ track | 小体积资产 |
| `build/` | 4.0 G | ignore（`.gitignore` 第 24 行 `/build/` 已在） | **2026-10-10 起内核构建目录**（`scripts/build-kernel.sh` 工作区；体量集中在 `build/m1-upstream`，`build/glibc-arm64` 近空）。**可再生**：`make clean`/整目录删后下次构建重建，无独有内容需留（简报称「父将补 .gitignore」——实测已补，无需再补） |
>>>

---

## 节 D — §3.2 `out/` 行 amend（10-10 清理后现状）

**位置**：§3.2 `out/` 行。
**理由**：原记 4.6 G 失真。`reports/local-cleanup-audit-20261010.md` 顶部「父代执行状态」记已回收 ≈6.28 G（out/ 9.4→3.6 G），实测现 `du -sh out` ≈3.5 G、`out/*.img` = 41 个。需反映：现役/在途留盘口径与 `versions/vk-identity-inflight.txt` 一致——vk71-mxc/mxnom 用户已判死（可删）、vk74-q28power 与 vk84-q28delay-{base,exp} 在途留、vk64=持久 boot_b 内核。**注**：简报与审计 B 表提到的通用输出 `out/boot-elden.img` 现已**不存在**（清理时已无，非待处置）。

<<<OLD file=RESOURCES.md
| `out/` | 4.6 G | ignore | boot 产物 / cpio / modules |
===
| `out/` | ~3.5 G（41 个 img） | ignore（`*.manifest` 入库） | boot 产物 / cpio / modules。**2026-10-10 清理审计已回收 ~6.28 G（9.4→3.6）**；留盘口径同 `versions/vk-identity-inflight.txt`：vk64=持久 boot_b 内核（+`Image-vk64.gz`）、**在途留**=vk84-q28delay-{base,exp}+vk74-q28power（Q28 冷 A/B 未定案）、vk77/vk78 modular 线；**用户已判死可删**=vk71-mxc/mxnom（Q24 变体）。逐项见 `reports/local-cleanup-audit-20261010.md` 与 `reports/tidy-20261010/cleanup-candidates.md` |
>>>

---

## 节 E — §3.2 新增 `reports/` 顶层目录行

**位置**：§3.2 顶层台账 `archive/` 行之后。
**理由**：`reports/` 是 2026-10-09/10 新增的顶层目录（Q28 过程稿 + 清理审计 + 本轮整理提案），`git status` 显示整体 `?? reports/`（未入库、未 ignore），§3.2 无登记。定位口径按简报定义写入。

<<<OLD file=RESOURCES.md
| `archive/` | ~5.5 M | ✅ track | 过程证据（87 篇专题 + 2 截图 + `2026-10-04-retired-entrypoints/` 退场入口归档），只增不改 |
===
| `archive/` | ~5.5 M | ✅ track | 过程证据（87 篇专题 + 2 截图 + `2026-10-04-retired-entrypoints/` 退场入口归档），只增不改 |
| `reports/` | 132 K | ⚠️ 未入库（`?? reports/`，working；主题收口时随迁 `archive/topics/` 再入库） | **活跃主题的工作区证据**（活跃期可读可改；主题定案后整体迁 `archive/topics/`，归档层只增不改）。现含 **Q28 显示线过程稿**（`q28-DOSSIER.md`=SSOT、`q28-INDEX.md`=文档地图、`q28-{handoff,two-layers,upstream-diff,orchestration,upstream-research,nocard-research}-20261010.md`）、本地清理审计 `local-cleanup-audit-20261010.md`、本轮整理提案 `tidy-20261010/`（`resources-edits.md`/`cleanup-candidates.md` + T1/T2/T3 简报） |
>>>

---

## 节 F — §4.2 追加 10-09 / 10-10 会话行（8 行）

**位置**：§4.2 全量索引表末尾（`01a11667` 2026-10-07 行之后，`### 3.` 小节之前）。
**理由**：`ls -lt .pi/sessions/*.jsonl | head -8` 全部为 10-09/10-10 会话，而现索引最后一行停在 10-07（`01a11667`），三者（`01a12302`/`01a1241b`/`01a12529`）与其余 head-8 均未登记。

**核定说明（重要）**：8 行的 **日期/ID 为磁盘 jsonl 实测**；`01a12302`/`01a1241b`/`01a12529` 的主题/结论按简报权威描述提炼，其余 5 行主题据「首条用户指令 + 对应 git log 提交 + reports/ 文件头」提炼。10-09 会话存在**多线并行、边界重叠**，`kv` 列为镜像/文件**提及**（非实机验证，遵 §5 口径），请 integrator 据会话正文核定后定稿。8 行均非冒烟/无产出（jsonl 数百～数千行），无一标 junk。

<<<OLD file=RESOURCES.md
| 2026-10-07 | `01a11667` | 审计：近两天会话一致性审计 | session-audit | ✗ | active | 修死链误报（check-doctor 正则把 adsp.mdt 截成 adsp.md）；INDEX 88%→90%；TASKS §0 DP/Q24 状态对齐；RESOURCES §4 补 9 行（另：§2 有重复行段，待后续去重） | - | 本会话 |
===
| 2026-10-07 | `01a11667` | 审计：近两天会话一致性审计 | session-audit | ✗ | active | 修死链误报（check-doctor 正则把 adsp.mdt 截成 adsp.md）；INDEX 88%→90%；TASKS §0 DP/Q24 状态对齐；RESOURCES §4 补 9 行（另：§2 有重复行段，待后续去重） | - | 本会话 |
| 2026-10-09 | `01a11fe1` | 会话：10-09 中断项目接续与多线编排 | session-meta | ◐ | active | 「继续之前中断的项目」→编排子代理推进文档口径/GPU·相机/旋转/kexec/UEFI/模块化多线；对齐 10-09 午后 Q28 密集复现（vk74/75/76）、GUI 死挂取证两件套、持久装弹常驻等提交（`d35088e`→`0915c4a`） | vk74,vk75,vk76 | 与 01a12093/01a120fe 多线并行、边界待厘清；主题待据正文核定 |
| 2026-10-09 | `01a12093` | 会话：子代理派发（文档/GPU·相机/旋转/kexec/UEFI/模块化） | session-meta | ◐ | active | 首条指令=分派 6 类子代理（文档进度口径审核、GPU 驱动与相机、重力旋转用户级开关、kexec 可行性、UEFI 启动、驱动模块化），高难任务用高上下文模型 | vk* | 编排会话，实机结论归各子线；主题据首条指令 |
| 2026-10-09 | `01a120fe` | 会话：接手上一轮并处理待办 | session-meta | ◐ | active | 首条=接手上次会话（设备在 linux）逐项处理待办 | - | 多线接续，主题待据正文核定 |
| 2026-10-09 | `01a12140` | 相机：模块驱动收尾 + "camera not found" 根因 | camera | ✅ | active | 收尾相机模块驱动 + 查「模块已装仍报 camera not found」→ 根因=现役 cmdline `elden_nocamera=1` 使模块根本没加载（配置态非驱动坏，`c377ac2`/`d8ba26d`；PITFALLS #299/#300 类误判） | vk64 | 相机⇄熄屏互斥（Q24）为已知约束；主题据首条指令+提交标题 |
| 2026-10-09 | `01a12157` | 审计：当前版本基线与可安全烧录集合 | version-audit | ◐ | active | 首条=「现在版本基线是多少？哪些是安全的」→盘点在机/在途 vk 基线与可安全烧录集 | vk64,vk71,vk74 | 口径与 §4.3 时间线 / `versions/` 账本一致；短会话（315 行） |
| 2026-10-09 | `01a12302` | Q28 密集取证：寄存器差分 + 好/坏基线（vk74–76） | display/q28 | ✅ | active | **Q28 密集取证 / vk74–76**：首个好/坏寄存器差分到手（否掉 dsi1vco/dsi1_isr/byte-clk 三个假差异）、模块化线在机验收通过、U2 A/B 槽位险情处置；判据更正（dsi_isr **增量**不可判屏幕死活→改累计值+dmesg，`b4616d5`/`372dda8`） | vk74,vk75,vk76 | 会话跨 10-09 深夜→10-10 12:37；Q28 根因终定在后续 01a1241b |
| 2026-10-10 | `01a1241b` | Q28 定案：死内核事故修复 + vk84 单变量 A/B | q28/build | ✅ | active | **死内核事故 + vk84 + Q28 定案**：`make olddefconfig` 误删 ARCH_QCOM 致 vk81/82/83 无 QCOM 驱动死内核（作废，PITFALLS #162），build/apply 脚本加符号守卫+回钉；vk84-q28delay-{base,exp} 单变量对（唯一差 cmdline）；Q28 根因=bonded 双 DSI 首条 DCS 命令 DMA hang（冷起 ~60%，L2 DPU ctl reset 为下游，#164）；上游正解 `2028280686f4` 逐字移植对本树无效 | vk84 | 冷 A/B 未跑完（T1 vk84-exp=NOCARD，n=1）；vk84 实验镜像在途未收口 |
| 2026-10-10 | `01a12529` | 会话：新一轮项目整理（文档/参考/规划/工作史） | session-meta | ✗ | active | **本轮整理**：发起项目整理（进度文档/参考资料/下一步规划/git 工作史），派 T1/T2/T3 子代理；本行即 T2 资产台账同步所在会话 | - | 本会话；T1/T2/T3 提案待 integrator 落领域层文档 |
>>>

---

## 未编辑但需 integrator 处置的一致性问题（不改，交父代）

1. **§4.1 统计数字全部过时**（补登 8 行后）：现「时间跨度 2026-09-29 → 2026-10-07」「磁盘 jsonl 103；本索引 110 行」「active 59 / reference 27 / junk 10 / superseded 4」。会话数字 SSOT = §4 本表，**计数由 integrator 复核后更新**（本子代理不擅改 SSOT 数字）。时间跨度终点应改至 2026-10-10。
2. **§4 索引缺 10-08 一整天**（10 个会话 `01a11919`…`01a11bfc`）：本轮简报 head-8 只覆盖 10-09/10-10，10-08（kexec-diag Q11 / vk65–69 二分 / 版本账二次对账，见 git log `41a41c3`→`f34814c`）**全部未索引**。建议 integrator 另立任务补登，否则 10-07→10-09 之间有三日断层。
3. **§3.2 `.pi/sessions/` 行失真**：现记「100 个 jsonl / ~108 M」，实测磁盘 jsonl 更多、`.pi` 合计 227 M。属同类计数漂移，随 §4 计数一并交 integrator。
4. **§3.2 `out/` 与 `archive/` 之外若干体积**（bootslot-b 905 M 实测 954M+112M、env-pass 3.8 G 实测 3.4 G、pkgs 三合一 639 M 实测 655 M 等）本轮只做 `du` 复核，未逐行 amend（超简报范围），逐目录处置建议见 `cleanup-candidates.md`。
