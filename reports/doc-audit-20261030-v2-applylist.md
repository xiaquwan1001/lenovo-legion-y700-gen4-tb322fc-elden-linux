# 应用清单（总管一次性机械应用）— 源自 `reports/doc-audit-20261030-v2.md`（P0 0 / P1 8 / P2 15）

> 触发：用户派工单（2026-10-30，清理项目）。角色 = 文档审计 Lead（L1）。**性质 = 纯主机、只读、只新建本文件**。
> 未 ssh / adb / fastboot / 刷机 / 全量构建 / 未改任何既有文件 / 未提交。**不刷机、不碰设备。**
> 基线 `scripts/check-doctor.sh`（开工）= **FAIL=0 WARN=3**（本清单不改文件，结束复跑同值，见文末门禁）。
> **锚点纪律**：每条 `OLD` 均为**当前盘上全仓唯一**子串（已 `grep -F -c = 1` 逐条验证；行号仅供人看，替换以字符串为准，行漂移无影响）。
> **二级复核**：一次 `fabric_exec`（timeoutMs 1500000）内 `Promise.allSettled` 起 2 个 `verify-worker`（`custom.ustc-pool/ustc-audit`，只读 tools `[bash,read,grep,find,ls]`，**未传 recursive**，未落文件）独立复跑本清单条目在盘态；其结论并入下表（标注 `[V1]/[V2]`）。

## 0. 数字结论（本轮）

| 桶 | 条数 | 说明 |
|---|---|---|
| **P1 已由总管修复（复核通过）** | **1** | A1 `TASKS §5`「设备状态 = 指针」→ 纯指针 + 保留 4 个 `.ko` 回退约束（**注**：约束在，但文中无字面量 `depmod -a`，系派工表述，非缺陷 `[V1]`）。附带复核 `reports/uefi-e1-identity-20261030.md` payload 等式（`:70` 已写 `img[0x1000:0x1000+ksize]==payload` + 尾部余量 `ksize=2 437 723`）→ **表述已正确** |
| **P1 可直接机械替换** | **8 条 / 10 处编辑** | A2(INDEX:129) + A5(RESOURCES 死路径) + B6(PITFALLS 悬空锚点 ×3) + D(5 篇孤儿补链 ×5) |
| **P1 → DEFER** | **3** | A3/A4（完成度可复算，须先定状态优先级规则 + 生成器，写死任一数字仍是 §2 规则 7 违例）、B7（check-doctor §8 见 §B2，本派工只给方案不落地） |
| **P2 可直接机械替换** | **10 条 / 15 处编辑** | 见 §A（DEVICE×2、TASKS×2+M1–M5×4、RESOURCES×2、PITFALLS×2） |
| **P2 → DEFER** | **7** | DEVICE「唯一差异」口径 / DEVICE 19:05 条目补 `.ko` 纪律 / DEVICE manifest 缺失 / RESOURCES 新资产登记 / vk-registry 补 m3v5（缺预签 sha）/ PITFALLS 序号 59·69 重复 / PITFALLS 序号乱序（均为高触碰或需外部值/判断） |
| **合计 P1 可机械 / P2 可机械 / DEFER** | **8 / 10 / 10** | DEFER = P1 3 + P2 7 |

> `[V1]`=worker-1（P1+B1）、`[V2]`=worker-2（P2+门禁）。两者在盘复核：V1 CONFIRM5/DRIFT2/ABSENT1（两处 DRIFT 即 A1 的 `depmod -a` 字面量、A5 死目录，均已吸收进本表）；V2 CONFIRM8/DRIFT1（DRIFT=out 67 img，与 TASKS:19「out/*.img 仍为空」矛盾 ⇒ 已并入本表 TASKS 条）。

---

# A. 可一次性机械应用（按文件分组）

> 用法：对每条按 `OLD → NEW` 做**精确字符串替换**（每文件建议用 `python -c` 或 `perl -0pi -e 's/\Q...\E/.../'`，避免 sed 正则元字符踩雷）。每替换一条立刻跑该行「验证」。

## A-file-1 `RESOURCES/README.md`

**R1（=B4）｜P1｜现役备份死路径**（`check-doc-assets` 不覆盖 `backup/` 前缀故漏检）
- anchor（唯一）：见 OLD 全行子串
- OLD：
  `现役可用备份 = `backup/kernel-git-repair-2026-10-08/elden-all-refs-1820.bundle`（**265 MB / 41 ref**，`bundle verify` 判为「完整历史」，含 vk40→vk64 + 5 个 `archive/*`；旧的 1743 那份 279 MB/38 ref 没有 vk43 留白 tag，保留作修复前留存）`
- NEW：
  `现役可用备份 = `backup/kernel-git-repair-2026-10-23/elden-all-refs-66.bundle`（**实测 303,660,780 B ≈ 290 MB / 67 head-ref，含 vk34→vk127**；体积/号段一律现查 `ls -l backup/kernel-git-repair-*/*.bundle` + `git bundle list-heads`。原 2026-10-08 / `elden-all-refs-1820.bundle` **目录已不在盘**）`
- 磁盘现状（证据见 §B4）：`backup/kernel-git-repair-2026-10-08` = **MISSING**；`…-10-23/elden-all-refs-66.bundle` = 303,660,780 B / 67 refs。
- 验证：`test -e backup/kernel-git-repair-2026-10-08 && echo STILL || echo GONE`（期望 GONE）；`grep -c 'kernel-git-repair-2026-10-23/elden-all-refs-66.bundle' RESOURCES/README.md`（期望 1）；`grep -c '2026-10-08/elden-all-refs-1820' RESOURCES/README.md`（期望 0）。

**R2｜P2｜`:394` 号段自相矛盾 + 写死计数**
- OLD：`现 22 个 img（vk64、vk127、vk130–vk147）`
- NEW：`现查 img 数 `ls out/*.img | wc -l`（实测 67；vk130/vk131 仅剩 `.manifest`，A4 已删其 `.img`）`
- 验证：`grep -c '现 22 个 img' RESOURCES/README.md`（期望 0）；`ls out/*.img|wc -l`（实测 67，与文一致）。

**R3｜P2｜`:320/321/324` 同类体积同节多值互斥（改「现查」）**（3 处编辑，各自唯一）
- OLD：`| **现查 5.4 G** |` → NEW：`| **现查 `du -sh out`** |`
- OLD：`| **现查 830 M**（vk127–vk173 若干件 + f2fs-root） |` → NEW：`| **现查 `du -sh bootslot-b`（实测 1.1 G / 13 img）** |`
- OLD：`| **现查 19 M** |` → NEW：`| **现查 `du -sh logs`（实测 35 M）** |`
- 验证：`grep -c '现查 5.4 G\|现查 830 M\|现查 19 M' RESOURCES/README.md`（期望 0）；`du -sh out bootslot-b logs` 与文一致。

## A-file-2 `TASKS/README.md`

**T1｜P2（附 §5 表头）｜`:19` 待办指针陈旧（T4 已收口）+「out/*.img 仍为空」过期**（`[V2]` 实测 67 img）
- OLD：`；`out/*.img` 仍为空（重建见 §4 待办 T4）`
- NEW：`；`out/*.img` 数量现查 `ls out/*.img | wc -l`（实测 67，重建按 §5 Q24/Q28 配方）`
- 依据：`T4` 行（`TASKS/README.md:138`）= `✅ 已完成（2026-10-17）` `[V2]`。
- 验证：`grep -c '重建见 §4 待办 T4' TASKS/README.md`（期望 0）；`grep -c 'out/\*.img. 仍为空' TASKS/README.md`（期望 0）。

**T2｜P2｜`:14` 「M1–M5」陈旧（§7 实维护 M1–M9）**
- OLD：`上游化 **M1–M5**（§7）` → NEW：`上游化 **M 系列（以 §7 为准）**`
- 验证：`grep -c 'M1–M5' TASKS/README.md`（应用 T2+T3 后期望 0）。

**T3｜P2｜`:25` 「M1–M5」陈旧**
- OLD：`**不含**上游化 M1–M5，M 系列单列于 §7` → NEW：`**不含**上游化 M 系列（以 §7 为准）`
- 验证：同 T2。

**T4｜P2｜`:328` §5 表头 Q 范围写死且含幻影号（漏 Q29/Q30、内含不存在的 Q11/Q16-19/22/23）**
- OLD：`编号 Q1–Q26、Q28、Q31–Q35；`
- NEW：`编号以表内为准（Q27 从无此号；不在此写死连续区间）；`
- 验证：`grep -c 'Q1–Q26、Q28、Q31–Q35' TASKS/README.md`（期望 0）；`grep -oE '^\| \*{0,2}Q[0-9]+' TASKS/README.md | grep -oE 'Q[0-9]+' | sort -u -V | tr '\n' ' '`（人工确认与文述一致）。

**T5–T8｜P1（孤儿补链，见 §B3）｜从 README 给 4 篇当日报告补入站链**
> 每条 = 在某表行尾部追加链接；OLD 均为该行尾部唯一子串。

- T5 `shutdown-greetd-hang-plan-20261030`（宿主 = T19 行，Debian 根→phosh/greetd）
  OLD：``95-*.md`/`96-*.md` |`` → NEW：``95-*.md`/`96-*.md`、`reports/shutdown-greetd-hang-plan-20261030.md`（关机/greetd 冷起卡死取证计划） |``
- T6 `droidloom-build-device-plan-20261030`（宿主 = T22 行，Debian 根 Waydroid 构建）
  OLD：`判据速查表见 `PITFALLS/sessions/107-…` |` → NEW：`判据速查表见 `PITFALLS/sessions/107-…`、`reports/droidloom-build-device-plan-20261030.md`（容器构建/设备侧计划） |``
- T7 `bootloader-alternatives-survey-20261030`（宿主 = G1-29 行，间接引导层）
  OLD：`同芯片平板亮屏回挖见 `reports/uefi-samechip-tablet-display-20261028.md`` → NEW：`同芯片平板亮屏回挖见 `reports/uefi-samechip-tablet-display-20261028.md`；引导方案横评 `reports/bootloader-alternatives-survey-20261030.md``
- T8 `uefi-n2-v0b-onboard-20261030`（宿主 = G1-29 行尾，UEFI 复现件）
  OLD：`issue #12 回帖见 `reports/uefi-issue12-reply-draft-20261028.md` |` → NEW：`issue #12 回帖见 `reports/uefi-issue12-reply-draft-20261028.md`；E1-v0b 上板记录 `reports/uefi-n2-v0b-onboard-20261030.md` |``

> 第 5 篇孤儿 `uefi-text-console-archaeology-plan-20261030`（宿主 = §0「拓展」汇总行，line 18）见 A-file-3 **X2**。

**验证（T5–T8 合并）**：`for r in shutdown-greetd-hang-plan droidloom-build-device-plan bootloader-alternatives-survey uefi-n2-v0b-onboard; do grep -rc "$r" TASKS/README.md; done`（每个 ≥1）。

## A-file-3 `INDEX.md`

**X1｜P1｜`:129` 写死「未解（1 项）」违 §2 规则 7 + 与本节 `:121`「任何数字不在此维护」自相矛盾**（`[V1]` 唯一命中）
- OLD：`- **未解（1 项）**：③ 进 GUI 后整机卡死（`PITFALLS #106`）。`
- NEW：`- **未解项（只读 `TASKS/README.md` §5 / `PITFALLS #106`，本文件不计数）**：③ 进 GUI 后整机卡死（`PITFALLS #106`）。`
- 验证：`grep -c '未解（1 项）' INDEX.md`（期望 0）。

**X2｜P1（孤儿补链，见 §B3）｜`§0 拓展`行补链**
- OLD：`复启条件见 §4 N1）` → NEW：`复启条件见 §4 N1；文本控制台考古计划 `reports/uefi-text-console-archaeology-plan-20261030.md`）`
- 验证：`grep -c 'uefi-text-console-archaeology-plan' INDEX.md`（期望 1）。

**X3｜P2｜`:15` 「M1–M5」陈旧**
- OLD：`§7 M1–M5）。` → NEW：`§7 M 系列，以 §7 为准）。`
- 验证：`grep -c 'M1–M5' INDEX.md`（应用 X3+X4 后期望 0）。

**X4｜P2｜`:91` 「M1–M5」陈旧**
- OLD：`**§7 上游化（M1–M5）**` → NEW：`**§7 上游化（M 系列，以 §7 为准）**`
- 验证：同 X3。

## A-file-4 `DEVICE/README.md`

**D1｜P2｜`:40` 可变路径上写死已变 sha（按该 sha 找文件会指错件）**
- OLD：`（**现为 m3v5-f2，sha `e6b1124c…`**）` → NEW：`（**历史值：2026-10-30 13:19 时点曾为 m3v5-f2 / sha `e6b1124c…`；该路径随 `scripts/flash-b.sh` 每次刷写变动，当前值只认本节首条 §1.1，实测现 = `aedae5f1`（vk183）**）`
- 依据：`sha256sum bootslot-b/boot_b.img`=aedae5f1、`…boot_b-pre-vk183-20261030.img`=e6b1124c `[V1]`。
- 验证：`grep -c '现为 m3v5-f2，sha' DEVICE/README.md`（期望 0）。

**D2｜P2｜`:45` 把可变副本当稳定签名件引用**
- OLD：`与签名件 `bootslot-b/boot_b.img` **逐字节一致**` → NEW：`与签名件 `bootslot-b/boot_b-vk181-daily-signed-20261029.img` **逐字节一致**（可变副本 `bootslot-b/boot_b.img` 现已刷 vk183，不再等于 `b72866ef`）`
- 验证：`grep -c '与签名件 `bootslot-b/boot_b.img`' DEVICE/README.md`（期望 0）；`sha256sum bootslot-b/boot_b-vk181-daily-signed-20261029.img | cut -c1-8`（期望 b72866ef）。

**D3｜P2｜`:191` 候选/已判定口径不同步（`:194` 已实测、Q35 已判物理可行）**
- OLD：`可尝试 **PD 插长边、数据线插短边**；数据热切换及 `port-select-gpios` 仲裁仍需独立验证` → NEW：`历史候选接法 **PD 插长边、数据线插短边**；「数据+充电并存」已于 2026-10-30 反向接法实测（见下条），**仅热切换/启动期仲裁**未验证`
- 验证：`grep -c '仲裁仍需独立验证' DEVICE/README.md`（期望 0）。

## A-file-5 `PITFALLS/sessions/98-*`、`99-*`、`135-*`（=B1 悬空锚点，3 处编辑，P1）

> 详见 §B1。正文按 `# #NNN · 标题` 补 `#NNN` 锚点（与同段 97=`# #417`、134=`# #470` 一致），使索引 #418/#419/#471 不再是悬空。

**P1-a `PITFALLS/sessions/98-UEFI-v0-repack必须base-0x10000000.md`**
- OLD：`# 98 · UEFI 异类载荷 repack v0` → NEW：`# #418 · UEFI 异类载荷 repack v0`
**P1-b `PITFALLS/sessions/99-OpenRC-after-elogind不等于就绪-greetd冷起抢跑.md`**
- OLD：`# 99 · OpenRC `after elogind` 不等于` → NEW：`# #419 · OpenRC `after elogind` 不等于`
**P1-c `PITFALLS/sessions/135-dt-validate退出码恒为0.md`**
- OLD：`# 135 · `dt-validate` 的**退出码恒为 0**` → NEW：`# #471 · `dt-validate` 的**退出码恒为 0**`
- 验证（三处合并）：`for p in 98 99 135; do head -1 PITFALLS/sessions/${p}-*.md; done` → 三行分别含 `#418`/`#419`/`#471`。

## A-file-6 `PITFALLS/README.md` + `PITFALLS/sessions/111-*`（P2）

**P2-a `README.md:6` 「最后更新：2026-10-25」写死日期必漂（索引已到 #471）**
- OLD：`> 最后更新：2026-10-25。` → NEW：`> 最后更新：现查 `git log -1 --format=%ad --date=short -- PITFALLS/`（勿写死日期）。`
- 验证：`grep -c '最后更新：2026-10-25' PITFALLS/README.md`（期望 0）。

**P2-b `PITFALLS/sessions/111-lane产物未合入主仓-文档路径说谎.md:48` 断言已过期（现 110=#446、111=#447 且都有链接）**
- OLD：``PITFALLS/README.md` 的索引行里 `#446` 与 `#447` **都编号 110**，且 `#446` 行没有链接（写成纯文本路径）。`
- NEW：`（历史断言，已修正）`PITFALLS/README.md` 索引行曾出现 `#446`/`#447` 同编号 110 且 `#446` 无链接——现索引已改为 110=#446、111=#447 且两行均有链接。`
- 验证：`grep -nE '^\| (110|111) \|' PITFALLS/README.md`（110→#446、111→#447）。

---

# A-DEFER. 需人判断 / 需外部值 / 高触碰（本轮不落 old/new）

| ID | 条目 | 为何 DEFER | 建议下一步 |
|---|---|---|---|
| **P1-D1** | `TASKS:24` G1 完成度「部分 4」不可由标记复算 | 需先定**状态标记优先级规则**（`✅>🟢>🟡`，🟢 是否计入完成）再**脚本生成**；现标记实测 ✅20/🟢3/🟡1/⛔1/❌2（27 行，含「G1-12…21」合并行）——写死任一固定数仍是 §2 规则 7 违例 | 定规则 → 加 `§0` 生成脚本；口径由总管拍板 |
| **P1-D2** | `TASKS:26` G2「完成 8/12」不可复算（列内出现 🎯/🟢/🆕，`:30` 分类集未含） | 同上，需先在 `:30` 补「🟢/🎯/🆕 一律计入完成」或删除这些标记 | 定标记集 → 复算 8/12 |
| **P1-D3** | `check-doctor.sh §8` 对悬空空转 | 属门禁代码改动，派工明确「只给方案不落地」——见 §B2 | 总管按 §B2 diff 落地 |
| **P2-D4** | `DEVICE:27` 「vk183 与 m3v5-f2 唯一差异 = 一枚 DT commit」口径 | 实为「相对 m3v5-f2 = 回退 M3-1 v5+F2 + 加一枚 DT」，两枚 Image 不同（`build/vk183-fastrpc` vs `build/m3v5-fix`）⇒ 措辞需拆两句、属口径判断 | 拆「与日常线 vk181 差一枚 DT」+「相对 m3v5-f2 已回退 M3-1 v5/F2」 |
| **P2-D5** | `DEVICE:27-32` 19:05 条目缺 4 个 `.ko` 回日常纪律 | 需先**在机/在树核实**当前 `/lib/modules` 仍是 m3v5 版 4 个 `.ko`（`typec_ucsi`/`ucsi_glink`/`dwc3`/`dwc3-qcom`，原件 `/root/m3modbak-20261030/`）——涉及设备态，本派工不碰设备 | 设备侧核实后补一行 |
| **P2-D6** | `out/boot-elden-vk183-fastrpc.manifest` 缺失 | 非文档改动：需重跑 `scripts/build-manifest.sh`（构建产物）| 主机侧重生成 manifest 并记预签 sha |
| **P2-D7** | `RESOURCES:315` + §3.2 新资产未登记（`tools/gunyah-modules/`、`backup/git-history-rewrite-20261026/`、`backup/f2fs-migrate-20261025-*/`）| 需**来源/可再生性/清理级别**判断后逐条登记 | 总管补台账 3 行 |
| **P2-D8** | `versions/vk-registry.tsv` 漏 `m3v5-daily`/`m3v5-f2` | 需各号**预签 sha**（外部值），仅凭文档无法安全补行 | 从 `vk-kernel-identity.tsv`/构建日志取 sha 后按 `:290` vk183 行格式补两行 |
| **P2-D9** | `PITFALLS/README.md` 索引「序号」列 59 重复、69 重复（实测 `uniq -d → 59 69` `[V2]`）| 序号列是展示列，真键是 `#NNN`；重编号/拆 59a·59b 属**高触碰**且可能被交叉引用「§59」引用 | 改「序号列直引文件名」或拆后缀 + 升序，一次改后跑门禁 |
| **P2-D10** | `PITFALLS/README.md:122-126` 序号乱序（88/87/86/89/85 = #399/#398/#397/#400/#396）| 纯展示排序，重排 5 表行风险>收益（P2 装饰性）| 按 #NNN 升序重排（可与 D9 合并处理）|

---

# B. 三处结构性问题专项裁决

## B1 — PITFALLS 索引悬空 #418 / #419 / #471

**结论：三号为「真悬空」，正文编号无错位、无被他号占用；应补正文锚点，不改索引。**

编号是**连续**的（同段旁证：`96`=`#414–#416`、`97`=`# #417`、`100`=`#420/#421`、`134`=`# #470`），故
索引 `98→#418`、`99→#419`、`135→#471` 的目标正文**确为** `98-*`/`99-*`/`135-*` 三文件本身，只是其 H1 用了
「文件序号式」标题（`# 98 · …`）而非「条号式」（`# #NNN · …`），导致 8d 的标题解析取不到 `#NNN`。
135 正文仅写「与第 470 条同类」（引用 #470，非自定 #471），故 #471 亦悬空。

- **方案**：见 §A-file-5（P1-a/b/c，三处 H1 改 `# #NNN · …`）。
- **索引行不动**（`README.md:139/140/176` 保持 `#418/#419/#471` 与链接）。
- 证据命令：
  - 悬空存在：`for n in 418 419 471; do echo "#$n body=$(grep -rl "#$n" PITFALLS/sessions/|wc -l)"; done`（→ 0 0 0）。
  - 连续性旁证：`grep -Hn '^# #4[0-9][0-9]' PITFALLS/sessions/97-*.md PITFALLS/sessions/134-*.md`；`grep -n '#41[4-6]' PITFALLS/sessions/96-*.md | head`。
  - 三文件当前无条号：`for p in 98 99 135; do echo "== $p =="; head -1 PITFALLS/sessions/${p}-*.md; done`。

> **易混淆（务必区分，别误改索引）**：`#420/#421`（`sessions/100-*`，bullet 定义）、`#444`（`109-*`，blockquote 定义）、`#446`（`110-*`，blockquote）、`#371`（`66-*`，`- 编号：**#371**`）——**这 5 个正文都真实存在**，只是定义形态不是标题（详见 B2）。它们**不是**悬空，**不要**改动。

## B2 — check-doctor §8 对 `## #NNN` 标题式条目「空转」

**根因（复核纠正派工表述）**：§8 的 **8d 块**（`scripts/check-doctor.sh:363–391`）**其实已解析** `^#{1,4}\s` 标题里的 `#NNN`（及老式 `NNN. **`），但它**只做「跨文件重复」检查**（`if len(files)>1`），**从不做「索引 ↔ 正文 悬空对账」** ⇒ #418/#419/#471（索引有、`pnum` 无）无人发现。派工「只匹配老式行」对**重复门**成立、对**悬空**不准确。

**最小 diff（仅方案，不落地）**——在 8d 之后、`emit` 之前，新增**一个只喂悬空门的宽松定义集**并核悬空；**关键：不要把这个宽松集并进 `pnum`（重复门）**，否则会把正文里 `**#143**` 这类**行内引用**误当定义，制造假的跨文件重复（实测把 `17`/`28` 撞成 #143 dup）。

```python
# ---- 8e. 索引 #NNN 必须在正文「定义」集里（悬空=硬错）----
# 宽松定义集 pdef_all 仅用于悬空门，绝不回喂 pnum（重复门保持标题/老式行解析，避免行内引用假阳）。
pdef_all = {k: set(v) for k, v in pnum.items()}
for f in glob.glob(os.path.join(root, 'PITFALLS', 'sessions', '*.md')):
    base = os.path.basename(f)
    for ln in open(f, encoding='utf-8', errors='replace'):
        line = re.sub(r'`[^`]*`', '`X`', ln)
        if re.match(r'^#{1,4}\s', line):
            continue                                   # 标题首编号已在 pnum
        m = re.search(r'\*\*\s*#(\d{1,3})\s*\*\*', line)  # bullet/blockquote/元数据里的粗体 #NNN 也算「定义」
        if m:
            pdef_all.setdefault(m.group(1), set()).add(base)
idxnums = set()
rd = os.path.join(root, 'PITFALLS', 'README.md')
for ln in open(rd, encoding='utf-8', errors='replace'):
    if ln.startswith('|') and 'sessions/' in ln:
        for m in re.findall(r'#(\d{1,3})\b', re.sub(r'`[^`]*`', 'X', ln)):
            idxnums.add(m)
DANGLING = ['PITFALLS 索引 #%s 无正文定义' % n for n in sorted(idxnums, key=int) if n not in pdef_all]
emit('DANGLING', DANGLING)
# 并让汇总把 DANGLING 计入 FAIL（非空即 FAIL），并在 case 分支补一行文案：
# DANGLING) [ "$_msg" = "-" ] && ok "索引 #NNN 均有正文定义" || failf "索引悬空（正文缺 #NNN 锚点）: $_msg" ;;
```

**「先跑证明」——该门会新命中哪些现有条目**（本轮已实跑，python 复刻 8d + 上述宽松集）：
- **未加宽松集**（只索引 vs `pnum`）会误报 **8 个**：`#371 #418 #419 #420 #421 #444 #446 #471`。
- **加上宽松集**（bullet/粗体也算定义）后**精确命中 3 个 = `{418,419,471}`**，且**不新增重复**（#143 因走 `pnum` 不受影响）。
- B1 落地（P1-a/b/c 补锚点）后，本门命中 **→ 空**，与 `check-doctor §8` 现有 PASS 一致、不新增 FAIL。

复现命令（先跑，证明命中集）：
```bash
cd /home/xuqianhui/y700-elden && python3 - <<'PY'
import glob,re,os
root='.';pnum={}
for f in glob.glob('PITFALLS/sessions/*.md'):
    for ln in open(f,encoding='utf-8',errors='replace'):
        l=re.sub(r'`[^`]*`','`X`',ln)
        if re.match(r'^#{1,4}\s',l):
            m=re.search(r'#(\d{1,3})\b',l)
            if m:pnum.setdefault(m.group(1),set()).add(os.path.basename(f))
        else:
            m=re.match(r'^(\d{1,3})\.\s+\*\*',l)
            if m:pnum.setdefault(m.group(1),set()).add(os.path.basename(f))
pdef={k:set(v) for k,v in pnum.items()}
for f in glob.glob('PITFALLS/sessions/*.md'):
    b=os.path.basename(f)
    for ln in open(f,encoding='utf-8',errors='replace'):
        l=re.sub(r'`[^`]*`','`X`',ln)
        if re.match(r'^#{1,4}\s',l):continue
        m=re.search(r'\*\*\s*#(\d{1,3})\s*\*\*',l)
        if m:pdef.setdefault(m.group(1),set()).add(b)
idx=set()
for ln in open('PITFALLS/README.md',encoding='utf-8'):
    if ln.startswith('|') and 'sessions/' in ln:
        idx|=set(re.findall(r'#(\d{1,3})\b',re.sub(r'`[^`]*`','X',ln)))
print('strict-dangling(no bullet)=',sorted({n for n in idx if n not in pnum},key=int))
print('final-dangling(bullet-incl)=',sorted({n for n in idx if n not in pdef},key=int))
print('new-crossfile-dup-if-mismerged=',[ (n,sorted(pnum[n])) for n in pnum if len(pnum[n])>1 ])
PY
```

## B3 — 5 篇孤儿报告：最合适入站指针（每篇 1 条）

> 入站须来自 `README.md`（AGENT-OPS §3 严格口径），非仅 session/报告互引。以下为**建议宿主**（机械插入见 §A T5–T8、X2）。

| 报告 | 最合适入站指针（文件 + anchor） | 建议一句话 |
|---|---|---|
| `reports/shutdown-greetd-hang-plan-20261030.md` | `TASKS/README.md` **T19 行**（Debian 根→全自动进 phosh/greetd；anchor ``95-*.md`/`96-*.md` |``） | 关机/冷起 greetd 抢跑致无桌面的取证计划，续 T19 greetd-phrog 线 |
| `reports/droidloom-build-device-plan-20261030.md` | `TASKS/README.md` **T22 行**（Debian 根 Waydroid 构建；anchor `判据速查表见 `PITFALLS/sessions/107-…` |``） | 容器（droidloom 线）构建与设备侧落点计划，续 T22 Waydroid 打通 |
| `reports/bootloader-alternatives-survey-20261030.md` | `TASKS/README.md` **G1-29 行**（间接引导层 GRUB/UEFI；anchor `同芯片平板亮屏回挖见 …uefi-samechip-tablet-display-20261028.md``） | 摆脱 boot.img 96 MiB 的引导替代方案横评，配 G1-29/§5 Q25 |
| `reports/uefi-text-console-archaeology-plan-20261030.md` | `TASKS/README.md` **§0「拓展 UEFI」汇总行**（anchor `复启条件见 §4 N1）`） | UEFI 文本控制台可行性考古计划，UEFI 路线复启条件配套调研 |
| `reports/uefi-n2-v0b-onboard-20261030.md` | `TASKS/README.md` **G1-29 行尾**（anchor `issue #12 回帖见 …uefi-issue12-reply-draft-20261028.md` |``） | E1-v0b 上板记录（`uefi-text-console-archaeology-plan` 的下游实测件，补 README 级入站即脱离「报告互引」孤儿） |

验证（全 5 篇均有 README 级入站）：
```bash
for r in shutdown-greetd-hang-plan droidloom-build-device-plan bootloader-alternatives-survey uefi-text-console-archaeology-plan uefi-n2-v0b-onboard; do
  echo -n "$r: "; grep -rl "$r" INDEX.md */README.md PITFALLS/README.md 2>/dev/null | tr '\n' ' '; echo; done
```

## B4 — RESOURCES 备份死路径

- **准确替换**：见 §A-file-1 **R1**。
- **磁盘现状（实测证据）**：
```bash
test -e backup/kernel-git-repair-2026-10-08 && echo EXISTS || echo MISSING   # → MISSING
ls -d backup/kernel-git-repair-*                                             # → 2026-10-10  2026-10-23
ls -l backup/kernel-git-repair-2026-10-23/*.bundle
#   elden-all-refs-66.bundle  303660780 B（≈290 MB / 289 MiB）
git bundle list-heads backup/kernel-git-repair-2026-10-23/elden-all-refs-66.bundle | wc -l   # 67
git bundle list-heads backup/kernel-git-repair-2026-10-23/elden-all-refs-66.bundle | grep -oE 'vk[0-9]+' | sed 's/vk//' | sort -n | sed -n '1p;$p'  # vk 头尾
```
> 注：文件名 `elden-all-refs-66` 与 `list-heads` 实测 67 差 1（多为 HEAD/别名），故 R1 措辞用「实测 67 head-ref」而非文件名号，避免再写死。

---

# 应用后应重跑的门禁（一次性序列）

```bash
cd /home/xuqianhui/y700-elden
# 1) 主门禁：FAIL 必须仍 = 0，WARN 不得因本次编辑上升（基线 FAIL=0 WARN=3）
bash scripts/check-doctor.sh; echo "doctor_exit=$?"
# 2) 若已按 §B2 落地 8e：悬空门应随 B1 补锚点转绿
bash scripts/check-doctor.sh 2>&1 | grep -iE 'DANGLING|悬空|索引.*定义'
# 3) 文档资产死链门（虽不覆盖 backup/，仍应 PASS）
bash scripts/check-doc-assets.sh 2>&1 | tail -2
# 4) 本次新增入站链确已落地（5 篇孤儿 + uefi-e1 已修）
for r in shutdown-greetd-hang-plan droidloom-build-device-plan bootloader-alternatives-survey \
         uefi-text-console-archaeology-plan uefi-n2-v0b-onboard; do
  c=$(grep -rl "$r" INDEX.md */README.md PITFALLS/README.md 2>/dev/null | wc -l); echo "$r inbound_README_refs=$c"; done
# 5) 悬空三锚点确已补
for p in 98 99 135; do head -1 PITFALLS/sessions/${p}-*.md; done
# 6) SSOT：设备数字唯一出口——TASKS §5 行不含 sha/boot_id/UTS
grep -nE 'boot_id|e6b1124c|3a3d187f|19:00:42' TASKS/README.md || echo "TASKS §5 clean (期望)"
# 7) 收工 git：仅应新增 1 个未跟踪文件（本清单），无其它改动
git status --porcelain
```

> 预期：`doctor_exit=0` 且 `FAIL=0`；WARN ≤ 3（不因本次上升）；5 篇孤儿 `inbound_README_refs ≥ 1`；98/99/135 首行分别含 `#418/#419/#471`；`git status --porcelain` 只多出 `reports/doc-audit-20261030-v2-applylist.md`（本派工纪律：只新建此 1 文件）。
