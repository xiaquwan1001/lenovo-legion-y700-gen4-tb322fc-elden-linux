# 上游补丁资产「投递状态」逐目录对账 — 2026-11-07

> 范围：`patches/upstream/*/` 全部 45 个目录。只核**投递状态声明**（README 状态行）与事实源
> （`out/mail-*/` 实发日志、`reports/mail-send-*` / `reports/upstream-status-*`、`TASKS/README.md` §7、
> 目录内 `SENT.md`/`sent/`）是否一致；**不动任何 .patch、不动 TASKS**。
> 权威事实源排序：实发日志/Sent 回读 > patchwork 复核记录 > TASKS §7 > 目录 README。

## §0 汇总（现数，与 §1 行数自洽）

- 目录总数：**45**
- 已投（含事实与 README 一致或无 README 者）：**29**（= §1a 10 + §1b 19）
  - 其中 README 状态声明与事实**矛盾、本轮修正**：**10 个目录**（§2 共 11 处编辑，m4-camss-series-20261028-v2 一个目录改 2 处）
- 未投（声明与事实一致，no-change）：**13**（§1c）
- 未证实：**3**（§1d：gunyah-v17 / wl2868c-v2-20261029 / m3v5-fix-20261030）
- 核对基数：45 = 29 + 13 + 3 ✓
- 未改任何 `.patch`/`.mdbox`/门禁文件；未改 `TASKS/README.md`

## §1 逐目录表

### 1a. 已投，README 状态行**过期** → 本轮修正（10 个）

| 目录 | README 现声明 | 事实 | 证据 | 处置 |
|---|---|---|---|---|
| `m1-2026-10-14/` | L15「0001 —— 唯一可上游补丁（**未发送**）」 | **已投** 2026-10-19 21:00 CST | MID `<20261019130041.305805-1-xiaqinghuan@mail.ustc.edu.cn>`；`reports/mail-triage-20261021.md:32`、lore `/linux-arm-msm/` 已归档 | 改标题行 |
| `m1-pas-dtbfw-20261027/` | L3「**未投递**（等用户批准）」 | **已投** 2026-10-27 13:29Z | MID `20261027132944.242550-1`；patchwork `linux-remoteproc 1/1 new`（`reports/mail-triage-20261030.md:155`） | 改 L3 |
| `aw86927-20261027-v2/` | L15「draft only —— **未投递、未上行**」 | **已投** 2026-10-27 13:29Z（0/5，5 枚） | MID `20261027132929.242158-1..6`；patchwork `linux-input 5/5 new`（`reports/mail-triage-20261030.md:129`）；本 README L59 自己就有「投递记录（2026-10-27 21:29 +0800）」 | 改 L15 |
| `m3-2026-10-13/` | L12「M3-1 USB 双连接器片 —— 3 枚就绪（**未发送**）」 | **v1 已投** 2026-10-13 | cover MID `20261013102927.1141696-1..4`，linux-usb/devicetree 各 4/4 归档（`TASKS/sessions/2026-11-03-TASKS行693-M3.md`） | 改 L12 |
| `m3-dwc3-20261104/` | L3「备料完成、门禁全绿、**未发信**」 | **已投** 2026-11-04 03:27Z（`[PATCH 0/3]`，4 封全 250） | cover MID `<20261104032706.210042-1-…>`；`reports/mail-send-20261104-wl2868c-v6-dwc3.md` §0、`reports/upstream-status-20261105.md` §1b | 改 L3 |
| `m4-camss-2026-10-13/` | L38「**投递前必须替换为真实维护者**」（M4-1 binding 草案） | **已投** 2026-10-27 05:10Z：gt9764+s5kjns `[PATCH 0/2]` MID `20261027051048.213177-1..3`；wl2868c binding v1 MID `20261027051055.213301-1` | `reports/upstream-status-20261105.md` §1（M4-1 行：`devicetree 2/2`、`linux-media 2/2` 在档）；`reports/mail-triage-20261030.md:133` | 改 L38「未决」条目 |
| `m4-camss-series-20261028/` | L7「状态：**可发（未发）**…发送需用户按系列批准」 | **v1 已投** 2026-10-28 03:41Z（`[PATCH 0/9]`，10 封全 250） | cover MID `<20261028034105.326535-1..10>`；实发转录 `out/mail-20261028/m4-camss-20261028-send.txt` | 改 L7–8 |
| `m4-camss-series-20261028-v2/` | L4「本目录 = **v2 候选，未发**」；L38「**未发。** 发送需用户按系列批准」（L1 标题又说「已投递并复核」＝自相矛盾） | **v2 已投** 2026-10-28 09:30Z（`[PATCH v2 0/9]`，10 封全 250） | cover MID `<20261028093003.722745-1..10>`；实发转录 `out/mail-20261028/m4-camss-v2-send.txt`；sashiko 对 v2 8/9 的回评 `reports/mail-triage-20261030.md:66` | 改 L4、L38 |
| `q28-dispcc-v2-20261029/` | L3「🟡 静态产物，**未上机，未发送**」 | **v2 已投** 2026-10-29 12:32Z（`[PATCH v2 1/3] mdss-common…`，3 枚） | MID `20261029123238.29877-1..4`；`reports/mail-triage-20261030.md:75`、Konrad 10-30 回评 `reports/mail-triage-20261031b.md:28`；「未上机」仍属实，保留 | 改 L3（只改「未发送」，不动「未上机」） |
| `wl2868c-20261104-v6/` | L3「**只备料，未发信**…（本目录 = 待投递产物）」 | **v6 已投** 2026-11-04 03:26Z（`[PATCH v6 0/5]`，6 封全 250） | cover MID `<20261104032648.209747-1-…>`；`reports/mail-send-20261104-wl2868c-v6-dwc3.md` §0、`reports/upstream-status-20261105.md` §1b | 改 L3 |

### 1b. 已投，README/SENT.md 状态**已正确**或无 README 可改（19 个，no-change）

| 目录 | README 现声明 | 事实 | 证据 |
|---|---|---|---|
| `m2-2026-10-13/` | 头部已记 P1 撤稿 + P3 已发（MID `20261013020425.408928`） | A2 原发 10-13（MID `20261013002124.332111`）+ 10-27 重发 | README 自身 + `patches/upstream/m2-a2-linuxnext-20261027/SENT.md` |
| `m2-a2-linuxnext-20261027/` | 无 README，有 `SENT.md`「投递记录（2026-10-27 21:29 +0800）」 | 已投，MID `20261027132949.242685-1`，linux-pm 1/1 归档 | `SENT.md`（含 Result: 250） |
| `m3-v2-2026-10-17/` | §6「投递记录（2026-10-17 08:13Z，已发送 + 已归档复核）」 | 已投 | README L53 |
| `m3-v3-2026-10-19/` | §4「投递与归档（2026-10-19）」 | RFC 已投（2 枚 + helper，3 封 250） | README L37；`TASKS/sessions/2026-11-03-TASKS行693-M3.md` |
| `m3-v4-20261026/` | §6「投递（2026-10-26 20:32 +0800，用户批准）」 | 已投，MID `20261026123211.243224-1..4` | README L2；`reports/upstream-status-20261029.md:17` |
| `m3v5-20261030/` | 无 README | v5 已投 2026-10-31 15:01Z（3 封 250） | cover MID `<20261031150154.1106455-1..3>`；`reports/upstream-status-20261105.md` §1b |
| `m3-1-v5-dt-resend-20261102/` | 无 README | 1/2 binding 单封已投 2026-11-02 05:40Z | MID `179359806935.413510…`；`reports/mail-send-20261102-b5-m3dt.md`（Sent[235] 回读） |
| `m4-camss-fixes-20261029/` | 无 README，有 `SENT.md` + `GATES.md` | 已投 2026-10-29 12:31Z（0/3，4 封 250） | `SENT.md`；MID `20261029123107.28705-1..4`；`TASKS` §7 M4 行 |
| `m4-camss-v2-20261031/` | 无 README | v2 0/2 已投 2026-10-31 04:11Z（3 封 250） | MID `20261031041154.308030-1..3`；`reports/upstream-status-20261105.md` §1b |
| `m8-mdss-v3-20261102/` | L3「🟢 已投递」+ `sent/` 回读 | 已投 2026-11-02 05:50Z | `sent/send-email.log`、`sent/msgids.txt`（MID `20261102055026.438521-1..4`） |
| `m-gic-its-claim-20261024/` | L3「已投递（2026-10-24）」 | 已投；10-26 已撤回 | MID `<20261024075856.835932-1…>`；README 自证 |
| `m3-dwc3-v7-20261106/` | L3「已投 `[PATCH v8]`（2026-11-06 11:42Z）」 | 已投 | `out/mail-20261106/REPORT.md`、`send-dwc3-v8.log` |
| `wl2868c-v7-20261106/` | L3「已投 `[PATCH v8]`（2026-11-06 11:42Z）」 | 已投 | 同上，`send-wl2868c-v8.log` |
| `wl2868c-v9-20261107/` | L1/L4「已投递（2026-11-07T01:50Z）」 | 已投（3 封 250） | `out/mail-20261107/send-wl2868c-v9.log` |
| `sm8750-adsp-nonsecure-20261107/` | L1「已投（2026-11-07）」 | 已投 03:26Z（1 封 250） | `out/mail-20261107/send-adsp-nonsecure.log`；MID `20261107032646.32363-1` |
| `wl2868c-20261028-v2/` | 无 README（仅 binding 单枚） | binding **v2 已投** 2026-10-28 12:04Z | MID `20261028120442.99375-1`；`reports/mail-triage-20261030.md:134`（patchwork devicetree `changes-requested`） |
| `wl2868c-v2b-20261030/` | 无 README（v3 文件名） | **v3 已投** 2026-10-31 03:43Z（4 封） | MID `20261031034300.272730-1..4`；`reports/upstream-status-20261105.md` §1b（Sent[208]–[211]） |
| `wl2868c-v4-20261031/` | 无 README | **v4 已投** 2026-10-31（5 封） | cover MID `cover.1793427040.git…`；`reports/upstream-status-20261105.md` §1b（Sent[219]–[223]，v3/v4 均 superseded） |
| `wl2868c-v5-20261102/` | 无 README | **v5 已投** 2026-11-02 06:04Z（cover+4，5 封） | MID `<20261102060458.461372-1..5>`；`reports/mail-send-20261102-wl2868c.md` §0 + `out/mail-20261102-wl2868c/sent/` 回读 .eml |

### 1c. 未投，README 声明与事实**一致**（13 个，no-change，不为整齐而改）

| 目录 | README 现声明 | 事实 | 证据 |
|---|---|---|---|
| `aw86927-20261027/` | 「draft only — not posted」+「⛔ 已被取代，不要再按这里投递」 | v1 确未投；由 v2 取代并投出 | `reports/aw86927-series-v2-20261027.md` |
| `camss-csiphy-24-20261102/` | 「备料，**不发**」 | 未投，无任何日志 | 无 `out/mail-*` 提及 |
| `camss-icc-20261031/` | 归属 Hangxiang，**不投递** | 未投（有意决策） | `TASKS` §7 M4 行；`reports/camss-icc-table-fix-20261031.md` |
| `m3-3-2026-10-13/` | 「2 枚就绪（未发送）」 | 备料封存 | `TASKS` §7（M3-3 备料封存不发） |
| `m3-4-2026-10-13/` | 无状态行 | 备料封存 | 同上（M3-4） |
| `m3-6-2026-10-13/` | L26「补丁未发送，仅备料」 | 备料封存 | README 自证 |
| `m4-camss-series-20261027/` | L9「**未投递**」 | 该版确实未投（被 20261028 版取代） | `../m4-camss-series-20261028/README.md` L9 |
| `m4-camss-series-20261029-v3/` | L1「v3 候选，**未发**」 | 未投；Bryan 10-29 表态后改走 3-fixes 形态 | `reports/mail-triage-20261030.md:66`（sashiko 最后一回评是对 v2） |
| `m6-b5-p4-20261026/` | 「备料草案（DRAFT），**冻结不发**」 | 未投 | 无日志 |
| `m6-b5-p4-rfc-20261027/` | 无 README（仅 RFC-SCOPE.md） | RFC 未投 | `reports/mail-triage-20261030.md:161`「RFC 未投」 |
| `m6-b5-v2-20261102/` | 「未发送」+ 用户 2026-11-02 裁决本轮不发 | 未投（有意封存） | `reports/upstream-status-20261105.md` §1 M6 行 |
| `phoc-im-keyboard-grab-2026-10-18/` | 「MR 待推送」（非内核 ML 补丁） | 不适用 ML 投递 | README 自证 |
| `wl2868c-driver-20261028/` | 无 README | driver 系列该版未投；被后续 v5/v6/v9 取代 | `reports/mail-triage-20261030.md:164`「未投」 |

### 1d. 未证实（3 个）

| 目录 | 疑点 | 缺什么证据 |
|---|---|---|
| `gunyah-v17/` | 只有 mbox 抓取件，无 README、无我方投递痕迹 | 无 `SENT.md`/日志；判定为参考资料（Gunyah 系列非我方维护线），如需归位请父级裁决 |
| `wl2868c-v2-20261029/` | 完整 v2 系列（cover+3），但 10-31 批直接从 binding-v2 跳到 v3/v4 | 无任何 send 日志或 Sent 回读指向这批 v2 全系列；按「未证实」处理（倾向未投、被 v2b 取代） |
| `m3v5-fix-20261030/` | 2 枚 fix 备料；11-02 只单投了 binding 1/2 | 0002（driver fix）是否曾随其它批次投出无日志佐证；按「未证实」处理 |

## §2 已应用的编辑清单

全部只改状态声明行；未动补丁内容、门禁命令段、`相对 vN 的改动`、TASKS。

| # | 文件 | 行 | 旧文案 → 新文案 |
|---|---|---|---|
| 1 | `patches/upstream/m1-2026-10-14/README.md` | 15 | `## 0001 —— 唯一可上游补丁（未发送）` → `## 0001 —— 唯一可上游补丁（已投 2026-10-19，MID <20261019130041.305805-1>，lore /linux-arm-msm/ 已归档）` |
| 2 | `patches/upstream/m1-pas-dtbfw-20261027/README.md` | 3 | 「**未投递**（等用户批准）」→「**已投递（2026-10-27 13:29Z，MID 20261027132944.242550-1，patchwork linux-remoteproc 1/1 在档，见 reports/mail-triage-20261030.md）**」 |
| 3 | `patches/upstream/aw86927-20261027-v2/README.md` | 15 | 「draft only —— **未投递、未上行**；投递需用户逐系列批准」→「**已投递（2026-10-27 13:29Z，0/5 共 6 封，MID 20261027132929.242158-1..6；patchwork linux-input 5/5 在档，见 §投递记录）**」 |
| 4 | `patches/upstream/m3-2026-10-13/README.md` | 12 | 「—— 3 枚就绪（未发送）」→「—— 3 枚已投（2026-10-13，cover MID 20261013102927.1141696-1；后被 v2 取代，见文首）」 |
| 5 | `patches/upstream/m3-dwc3-20261104/README.md` | 3 | 「备料完成、门禁全绿、未发信（发信由编排者按批执行）」→「已投（2026-11-04 03:27Z，[PATCH 0/3] 4 封全 250，cover <20261104032706.210042-1…>；日志 reports/mail-send-20261104-wl2868c-v6-dwc3.md）」 |
| 6 | `patches/upstream/m4-camss-2026-10-13/README.md` | 38 | 「投递前必须替换为真实维护者」→「已投（2026-10-27，M4-1 0/2 MID 20261027051048.213177-1..3 + wl2868c binding v1 20261027051055.213301-1）；MAINTAINERS 占位身份实际以真实 From 发出（发信记录见 reports/upstream-status-20261105.md §1 M4-1 行）」 |
| 7 | `patches/upstream/m4-camss-series-20261028/README.md` | 7–8 | 「状态：可发（未发）…发送需用户按系列批准」→「状态：v1 已投（2026-10-28 03:41Z，[PATCH 0/9] 10 封全 250，cover <20261028034105.326535-1…>；实发转录 out/mail-20261028/m4-camss-20261028-send.txt）；v2 见 ../m4-camss-series-20261028-v2/」 |
| 8 | `patches/upstream/m4-camss-series-20261028-v2/README.md` | 4 | 「本目录 = v2 候选，未发」→「v2 已投（2026-10-28 09:30Z，[PATCH v2 0/9] 10 封全 250，cover <20261028093003.722745-1…>，实发转录 out/mail-20261028/m4-camss-v2-send.txt）」 |
| 9 | `patches/upstream/m4-camss-series-20261028-v2/README.md` | 38 | 「**未发。** 发送需用户按系列批准。…若批准：…」→「**已投（2026-10-28 09:30Z，10 封全 250，转录 out/mail-20261028/m4-camss-v2-send.txt）。** §6 投递记录见下」 |
| 10 | `patches/upstream/q28-dispcc-v2-20261029/README.md` | 3 | 「静态产物，未上机，未发送」→「静态产物，未上机；**已发送（2026-10-29 12:32Z，MID 20261029123238.29877-1..4，见 reports/mail-triage-20261030.md §1）**」 |
| 11 | `patches/upstream/wl2868c-20261104-v6/README.md` | 3 | 「只备料，未发信…（本目录 = 待投递产物）」→「已投（2026-11-04 03:26Z，[PATCH v6 0/5] 6 封全 250，cover <20261104032648.209747-1…>；报告 reports/mail-send-20261104-wl2868c-v6-dwc3.md）」 |

## §3 未证实项与缺什么证据

见 §1d 三个目录。共性缺口：2026-10-31 之前的投递依赖 Sent Items 回读与 `reports/mail-triage-*`，
其中 10-28/10-29 批只有转录文件（`out/mail-20261028/*.txt`）与 patchwork 记录，无独立 `send-*.log`；
若需更强证据，可对 `out/mail-20261028/m4-camss-*-send.txt` 补一次 patchwork API 按 MID 复核
（本轮只读审计，未发网络请求）。gunyah-v17 建议父级裁决是否归档到 `archive/topics/`。

DONE-PATCH-DELIVERY-AUDIT-20261107
