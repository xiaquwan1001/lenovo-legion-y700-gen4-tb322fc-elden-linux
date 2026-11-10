# 项目整理核对报告（2026-11-10，只读盘点）

> 结论先行：`check-doctor.sh` **FAIL=0 / WARN=5**，仓库健康门通过。
> 唯一实质过期点 = **UEFI/G1-29 文档还停在「p61/p62 待上机」**，而事实是
> **2026-11-09 晚 p63/p64/p65/p66 已构建，flashed 形态（写 `boot_a`）全部失败回退 `_b`，p60 对照同样失败**；
> 且 p63–p66 **没有任何 `reports/*.md` 正文**（只有 `patches/uefi/p6{3..6}-recipe.txt`、
> `out/r21-sbstop-p6{3..6}/`、`reports/artifacts/uefi-20261109R6{4..7}-p6{3..6}/`、
> `reports/artifacts/uefi-p63-flash-20261109/` 含 logfs-beacon/logfs-p60-control 取证件）。

## 1. 文档过期：应改清单（只列不改）

| # | 文件:行号 | 现在写的 | 应改成 |
|---|---|---|---|
| 1 | `TASKS/README.md:18`（§1 UEFI 状态格） | 「R62/p61 已构建待上机 … 只读 §5『2026-11-08（深夜）』块」 | 「p62 已上机（2026-11-09，负结果，`fs2` 未现）；2026-11-09 晚 p63/p64/p65/p66 已构建，flashed 形态全部失败回退 `_b`，p60 对照同样失败 ⇒ 当前卡点不在 ESP 枚举补丁上；只读 §5 最新块」 |
| 2 | `TASKS/README.md:45`（G1-29 行） | 「R62/p61 已构建待上机（正式化清理 #562）」；尾部「剩余 = 写 boot_a 的落地一发（需批准）」 | 同上：p61/p62 flashed 形态已上机均负结果回退 `_b`；p63–p66（含 beacon/panel-hold 方向）已构建并 flashed 上机，全部失败回退 `_b`，p60 对照失败；「剩余动作」改为待定根因（logfs 普查件在 `reports/artifacts/uefi-p63-flash-20261109/`） |
| 3 | `TASKS/README.md:133`（§4 N1） | 「当前最新 = §5『2026-11-08（深夜）』块 … R62/p61 待上机；计划 `archive/plans-20261110/2026-11-09-p61-onboard.md`」 | 「当前最新 = §5 2026-11-09 晚 p63–p66 块（flashed 全败回退 `_b`，p60 对照失败）；计划文件 p61/p62-onboard 均已执行完毕（负结果）」 |
| 4 | `TASKS/README.md:156`（§5 现行最新块标题） | 最新块 = 「2026-11-09（傍晚，p62）」 | 其上需**新增**「2026-11-09（晚，p63–p66）」块：四代构建 + flashed 上机失败回退 `_b` + p60 对照失败 + 判据取证件指针（本轮最大的文档缺口：p63–p66 无任何正文报告） |
| 5 | `TASKS/README.md:246-251`（p60/p61 子块内嵌更正） | 「下一步 = 先加函数入口无条件标记出 p62，零写盘一发辨明，再谈 R62/根治路线」 | 已过时：p62 及后续 p63–p66 均已构建并上机，判据已取（负结果），下一步应指向新块 |
| 6 | `patches/uefi/README.md:7-13`（§0 表） | 「当前世代 = **p61**（最新，未上机）/ 上机验证过的最新 = p60」 | 「最新构建 = **p66**（2026-11-09 晚）；p62–p66 flashed 形态上机全部失败回退 `_b`（p60 对照同败）；上机**成功形态**仍只有 `fastboot boot` 零写盘（p59/p62）」；§0 表补 p63–p66 四行（配方 `p6{3..6}-recipe.txt`、归档 `uefi-20261109R6{4..7}-p6{3..6}/`） |
| 7 | `patches/uefi/README.md:20`（「新世代从 `p61-recipe.txt` 派生」） | 派生基点 = p61 | 派生基点 = **p66**（或注明 p62–p66 链） |
| 8 | `INDEX.md:192` | 「R62/p61 已构建待上机」 | 同 #1 口径 |
| 9 | `archive/plans-20261110/2026-11-09-p62-onboard.md`（抬头） | 「待用户批准写盘」 | 状态改为「已执行（负结果，回退 `_b`），被 p63–p66 序列与新一轮计划取代」 |

## 2. `.pi/plans/` 过期计划（建议归档/删除）

| # | 类别 | 路径 | 理由 | 建议动作 | 风险 |
|---|---|---|---|---|---|
| 1 | 归档 | `archive/plans-20261110/2026-11-09-p61-onboard.md` | 该发已执行（2026-11-09 flashed 上机，**负结果**，`fs2` 标记未现，已回滚），且文件头被 p62 计划声明「取代」 | 归档，动作与判据已进 `reports/uefi-p61-flash-trial-20261109.md` + `PITFALLS #575` | 无 |
| 2 | 归档 | `archive/plans-20261110/2026-11-09-p62-onboard.md` | 该发也已执行（负结果）；其派生的 p63–p66 又全部失败，计划整体被新结论取代 | 归档；若 p63–p66 无正文报告，归档前先把 §2/§3 判据摘要抄进 TASKS §5 新块 | 归档前漏抄判据 ⇒ 普查行读数解读失传 |
| 3 | 归档 | `archive/plans-20261110/2026-11-08-g1-29-menu-esp-p59.md`、`2026-11-08-g1-29-menu-r59.md`、`2026-11-08-g1-29-route-b-espboot.md` | 入口已被 `TASKS §5` 2026-11-08 深夜块与 `patches/uefi/README.md §0` 取代（菜单闭环、路线 B 打通均已定案） | 归档（整理候选清单 B 已列同类，未执行） | 无 |
| 4 | 归档 | `.pi/plans/2026-11-04_handoff-uefi-*`（3 篇）、`2026-11-04_late-uefi-routeD-linuxloader.md`、`2026-11-06_200000-uefi-p14-进度字符.md`、`2026-11-06_uefi-batch-next.md` | p14 世代判死；handoff 入口已被 p58 闭环及后续取代 | 归档（候选清单 B 原样未执行） | 无 |
| 5 | 归档 | `.pi/plans/next/` + `next2/`（含 12 篇） | `doc-audit-20261105 §3c` 建议归档至今未执行；**`next/non-uefi-open-items.md` 仍被 TASKS 引用 ⇒ 必须保留或改指针** | 归档其余、保留 non-uefi-open-items.md | 漏保 non-uefi-open-items.md 会产生幻影引用 |

## 3. 闲置资产与冗余（只列，不删）

| # | 类别 | 路径 | 体量 | 理由 | 建议动作 | 风险 |
|---|---|---|---|---|---|---|
| 1 | 删/归档 | `out/r21-sbstop-p54 … p61`（8 代，各 641–642 M） | ≈5.1 G | p54–p61 全部被 p62–p66 取代；**全部已绑 `--gen pNN --verify` 可逐字节复现**（`asset-cleanup-20261109.md §4` 自证） | 删，保留 p62（零写盘成功形态对照）、p66（最新）；p63–p65 若无特别用途同删（≈1.3 G） | 复现依赖 `build/uefi-woa-prep` 工作区完好；删前抽查一次 `--gen p61 --verify` rc=0 |
| 2 | 删/归档 | `out/r21-sbstop-p63`、`-p64`、`-p65`（各 641 M） | ≈1.9 G | flashed 形态全败的中间诊断代，配方+归档件齐全 | 同上 | 无（p66 留即可） |
| 3 | 合并/精简 | `reports/artifacts/uefi-20261104R*`（21 目录） | ≈458 M | R2–R22 历史二分诊断，结论已进 `PITFALLS`/`TASKS §5` | 归档或删（保留 `uefi-20261104R7-r1` —— 是 p7 配方 manifest 的导出源，`patches/uefi/README §1` 依赖） | **R7 目录勿删**，否则 p7 配方失去逐字来源 |
| 4 | 归档 | `reports/artifacts/uefi-boot-2026110{1,3}-*`（约 60 个 8.2 M 级串口/读回件） | ≈115 M | 2026-11-01/03 取证，结论已入账 | 归档 | 无 |
| 5 | 保留→登记 | `reports/artifacts/uefi-p63-flash-20261109/`（65 M） | 65 M | **唯一**的 p63–p66 flashed 失败取证（logfs-beacon、logfs-p60-control、pre/post/reboot txt） | 保留，并在 TASKS §5 新块挂指针 | 删了 p63–p66 就彻底无据可查 |
| 6 | 登记遗留 | `out/boot-elden-posctrl-20261103.img` | 小 | 候选清单 A 说删 `boot-elden-posctrl-markspin{,2,3,3gz}` —— markspin 系已删，但同名无 markspin 后缀的还剩 1 个 | 移除或入 `out/SUPERSEDED.md` 账 | 无 |
| 7 | 合并 | `reports/progress-review-2026110{6,7}.md`、`task-inventory-20261107.md`、`tasks-slim-20261107.md`、`script-tidy-20261106.md`、`doc-audit-20261106.md` | 小（文本） | 过程账，与 `TASKS/sessions/2026-11-0{6,7}-项目整理第{五,六}轮.md` 三方重叠（候选清单 B/C 原样未执行） | 归档 | 无 |
| 8 | 已裁决不动 | `.pi/trash` | 5.3 G | 用户 2026-11-06 裁决「不清」 | 维持登记 | — |
| 9 | 一次性脚本 | `scripts/` 下 b3b/b5/c0/c1/blackbox/blankspy/blackout-* 等一次性取证脚本 | KB 级 | 体量可忽略，暂不值得单独清 | 随下次脚本专项整理（`script-tidy` 线）处理 | 无 |

## 4. 与 `.pi/plans/2026-11-09-整理候选清单.md` 的差集

| 清单项 | 状态 | 核实证据 |
|---|---|---|
| A：删 `out/r21-sbstop-p8…p36`、`p38…p53`（≈8.8 G） | ✅ **已执行** | `ls out/` 只剩 `r21-sbstop` + p54–p66；commit `c0f1571`；账本 `reports/asset-cleanup-20261109.md` |
| A：删 `out/real-ladder`（1.9 G） | ✅ 已执行 | 同上，`ls` 无此目录 |
| A：删 `uefi-{ddr,ddrcut,posctrl}` 取证目录 | ✅ 已执行（GPT 双表已先备份） | 同上 + commit 信息「GPT 双表已先备份」 |
| A：删 `boot-elden-posctrl-markspin*` + `boot-elden.img` | ✅ 基本执行，**残留** `out/boot-elden-posctrl-20261103.img` | `ls out/boot-elden*` |
| A：保留 p54–p61 | ⚠ 当时正确，**现在应重估**（p62–p66 出来了，p54–p61 降级为可删，见 §3.1） | `patches/uefi/p6{3..6}-recipe.txt` |
| B：归档 `next/`+`next2/`、11-04/11-06 UEFI 计划、过程报告 | ❌ **全部未执行** | `ls .pi/plans/next next2`、`ls reports/progress-review-*` 均在 |
| C1：下沉 `TASKS §1 G1-29` 6 890 B 单元格 | ❌ 未执行（本轮反而更长） | `TASKS/README.md:45` |
| C2/C3：报告两两合并 | ❌ 未执行 | 文件均在 |
| C4：`PITFALLS #527–#533` 指向统一到 sessions | ❌ 未核实逐条，未见相关 commit | — |
| C5：修 `PROGRESS.md §6` 过期第 1 条 | ✅ 已部分执行（commit `c553068`「PROGRESS 补 11-08/11-09」） | git log |
| D：`.pi/trash` 不清 | ✅ 维持 | `du -sh .pi/trash` = 5.3 G |

## 5. `scripts/check-doctor.sh` 实测（只读运行）

**汇总：FAIL=0，WARN=5**（通过）。WARN 逐项：

1. `vk183-fastrpc`：registry 前历史镜像无 manifest（历史留白，已有审计档案背书）；
2. 大量 `uts_dup*`/`num_ne_tag(...)`：**已登记的例外**（理由在 `vk-ledger-known-issues.tsv`），非新增问题；
3. `boot-elden-posctrl-markspin-v2-20261103.img` 等 4 件「内核段不可读、勿据其做构建身份判断」——⚠ 与磁盘核对：**markspin 4 件已删但 doctor 缓存/清单仍提**（复跑若仍报，说明清单里有陈旧条目，对应 `out/` 现存仅 `boot-elden-posctrl-20261103.img`）；
4. `reports/mail-triage-20261109.md` 报告无人引用 ⇒ 建议在对应 README/TASKS 行补一处指针；
5. `HISTORY/days` 落后（未覆盖 HEAD `59f68a7` / HEAD~1 `ab5894`）⇒ 跑一次 `scripts/gen-history.sh`。

## 6. 本轮建议优先做的 5 件事

1. **补写 p63–p66 的事实正文**：在 `TASKS/README.md` §5 新增「2026-11-09（晚，p63–p66）」块（flashed 全败回退 `_b`、p60 对照失败、取证件 `reports/artifacts/uefi-p63-flash-20261109/`），并在 `reports/` 落一份正式 trial 报告——这是当前唯一「有产物无文档」的缺口。
2. **同步五处过期指针**（`TASKS:18/45/133/246-251`、`patches/uefi/README §0:7-20`、`INDEX:192`、p62 计划抬头），把「p61/p62 待上机」统一改为「p66 已构建、flashed 全败」口径。
3. **归档候选清单 B 的全部计划文件**（p61/p62-onboard + 11-08 三篇 + 11-04/11-06 UEFI 计划 + next/next2，保留 `non-uefi-open-items.md`）——清单已获批待执行两天，零风险。
4. **重估 `out/r21-sbstop-p54…p65`（≈6.4 G）**：p62/p66 之外全部 `--gen` 可复现，删前抽查 `--gen p61 --verify`；同时补删残留的 `out/boot-elden-posctrl-20261103.img`。
5. **消 doctor 的 2 个可动作 WARN**：给 `reports/mail-triage-20261109.md` 补一处引用；跑 `scripts/gen-history.sh` 刷新 HISTORY/days。

---
*生成：2026-11-10 项目整理子代理（只读；未修改任何其它文件）*
