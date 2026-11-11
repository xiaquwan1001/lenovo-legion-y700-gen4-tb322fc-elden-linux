# 上游邮件投递状态查询（2026-11-11）

只读审计：范围 = `out/mail-*` 最近投递目录 + lore.kernel.org 归档核对。禁发信。

## 1. 方法与本地产出盘点

- 取仓库最近投递目录：`ls -td out/mail-2026*`（按 mtime 倒序）→ 最新四个：
  `out/mail-20261110`、`out/mail-20261108`、`out/mail-20261107`、`out/mail-20261106`（命令输出见本轮 bash 记录）。
- 关键区分：`out/mail-20261108/README.md:3` 明写「**本目录任何文件都没有发出去**」= 草稿目录（含 dwc3 v9 /
  wl2868c v10 / M10 v2 三份 cover 草稿），**不是投递**，不计入发送时间线。
- 实际最近「已发」= 三个系列（证据均为 `git send-email` 原样日志里的 `Subject:` + `Message-ID:` 头）：

| 目录 | 日志 | cover Subject | cover Message-ID |
|---|---|---|---|
| `out/mail-20261110/` | `send.log:22-24` | `[PATCH v2] arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain` | `<20261110023153.84262-1-xiaqinghuan@mail.ustc.edu.cn>` |
| `out/mail-20261107/` | `send-wl2868c-v9.log:24-26` | `[PATCH v9 0/2] regulator: add the Will Semiconductor WL2868C camera PMIC` | `<20261107015014.22374-1-xiaqinghuan@mail.ustc.edu.cn>` |
| `out/mail-20261107/` | `send-adsp-nonsecure.log:22-24` | `[PATCH] … ADSP fastrpc node as non-secure domain`（v1，后被 v2 取代） | `<20261107032646.32363-1-xiaqinghuan@mail.ustc.edu.cn>` |
| `out/mail-20261106/` | `send-dwc3-v8.log:27-29` | `[PATCH v8 0/3] usb: dwc3: two Type-C connectors sharing one HS data bus` | `<20261106114208.987284-1-xiaqinghuan@mail.ustc.edu.cn>` |
| `out/mail-20261106/` | `send-wl2868c-v8.log:24-26` | `[PATCH v8 0/2] regulator: add the Will Semiconductor WL2868C camera PMIC` | `<20261106114252.988023-1-xiaqinghuan@mail.ustc.edu.cn>` |
| （同日超集前的）`out/mail-20261106/` | `send-dwc3-v7.log:27-29` | `[PATCH v7 0/3] usb: dwc3: …` | `<20261106112811.963923-1-xiaqinghuan@mail.ustc.edu.cn>` |

- 抓取实验（lore）：本机普通 `web_fetch` 对 lore 无效——`scripts/lore-fetch-raw.py:5-7` 记录 lore 已上 Anubis PoW，
  `curl` 只回挑战页（`PITFALLS #444`）。故改用仓库自带脚本复现；字段口径一律以 lore 原文为准，抓不到就写抓取失败。


## 2. 最近 6 个 Message-ID 与 Subject

「最近 6 个」= 按 cover 主题的时间倒序（lore Atom 检索 `f:xiaqinghuan@mail.ustc.edu.cn` / `s:<关键词>`，
抓取器 = `scripts/lore-fetch-raw.py` 与 `~/.local/bin/lore-query.py` 的 `fetch()`，后者自动过 Anubis PoW）：

| # | 投递日(UTC) | 系列 | Subject | Message-ID（cover/主件） |
|---|---|---|---|---|
| 1 | 2026-11-10 02:31Z | M10 ADSP non-secure v2 | `[PATCH v2] arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain` | `<20261110023153.84262-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 2 | 2026-11-07 01:50Z | wl2868c v9 | `[PATCH v9 0/2] regulator: add the Will Semiconductor WL2868C camera PMIC` | `<20261107015014.22374-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 3 | 2026-11-07 03:26Z | M10 ADSP non-secure v1 | `[PATCH] arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain` | `<20261107032646.32363-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 4 | 2026-11-06 11:42Z | dwc3 v8 | `[PATCH v8 0/3] usb: dwc3: two Type-C connectors sharing one HS data bus` | `<20261106114208.987284-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 5 | 2026-11-06 11:42Z | wl2868c v8 | `[PATCH v8 0/2] regulator: add the Will Semiconductor WL2868C camera PMIC` | `<20261106114252.988023-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 6 | 2026-11-06 11:28Z | dwc3 v7（工具失误版） | `[PATCH v7 0/3] usb: dwc3: two Type-C connectors sharing one HS data bus` | `<20261106112811.963923-1-xiaqinghuan@mail.ustc.edu.cn>` |

- 复现命令（每条都是同一套）：`python3 ~/.local/bin/lore-query.py 'https://lore.kernel.org/all/?q=f%3Axiaqinghuan%40mail.ustc.edu.cn&x=A'`
  与 `scripts/lore-fetch-raw.py all <msgid>`（后者对 #1 已实测返回 7421 B 原文，含 `Fixes: be9d54c3`）。
- #6 是 #4 的前身：`out/mail-20261106/REPORT.md:13` 记录「首轮（11:28/11:30）因 `format-patch` 漏 `-v7`
  致逐枚 Subject 无版本号 ⇒ 11:42 以 `-v8` 正确重投」，两版 diff 逐字节相同。


## 3. lore 归档核对结果

抓取方式：`https://lore.kernel.org/all/<msgid>/raw`（Anubis 过挑战后返回原文；**正文块 `<pre>` 只有线程概览，
真实回复内容必须取 `/raw`** —— 这是一条本轮新踩到的坑，见本节末）。状态列 = 我按返回内容判定。

| Message-ID | lore 状态 | 回复人 | 回复日期(UTC) | 一句话要点 |
|---|---|---|---|---|
| `<20261110023153.84262-1-…>` (v2) | 已归档 + 2 封回信（本线程共 5 封） | sashiko-bot | 2026-11-10 02:41 | 两条 Low：v2 changelog 段应放到 `---` 线下（否则进 commit log）；`Fixes:` 用 12 位 SHA 前缀；`qcom,non-secure-domain` 应排在 `memory-region` 之后 |
| 同上（v2）的 Konrad 回信其实挂在 v1 | — | Konrad Dybcio `<a32b69d2-…@oss.qualcomm.com>` | 2026-11-09 15:16 | 「Please keep that under the `---` line so it doesn't end up in the commit log」= 同一条 changelog 位置问题，对象是 v1 |
| `<20261107032646.32363-1-…>` (v1) | 已归档 + 2 封回信 | Konrad Dybcio（11-09 15:16）、sashiko-bot（11-07 03:33） | 见左 | v1 先被 sashiko 要求补 `Fixes:`，再被 Konrad 指出 AI 披露段位置 |
| `<20261107015014.22374-1-…>` (wl2868c v9) | 已归档（3 封全在）+ 2 封回信 | **Rob Herring (Arm)** `<179423604384.3146607.887205491604475162.robh@kernel.org>` | 2026-11-09 14:54 | **`Reviewed-by: Rob Herring (Arm) <robh@kernel.org>`**（对 1/2 binding，整封只有这一行签名）⇒ binding 已过 DT 维护者 |
| 同上 v9 2/2 | 已归档 + 1 封回信 | sashiko-bot `<sashiko-outbox-205554@kernel.org>` | 2026-11-09 20:14 | 3 条 Medium：reset 释放/1 ms 延时早于 vsys 使能、只有 `vin7-supply` 无 `vsys-supply` 的板子、`chip->enabled` 未校验 bit7(sys_en) 就播种 |
| `<20261106114208.987284-1-…>` (dwc3 v8) | 已归档 + 1 封回信 | **Rob Herring** `<20261110163640.GA85824-robh@kernel.org>` | 2026-11-10 16:36 | **实质反对 binding 形状**：「port 用于独立数据流，endpoint 用于 mux 后的数据流，这看起来是后者 ⇒ `port@0` 应有 2 个 endpoint、删掉 `port@2`」；另对 `port-select-gpios` 回「Use the gpio mux binding」 |
| `<20261106114252.988023-1-…>` (wl2868c v8) | 已归档，已被 v9 取代 | Conor Dooley（11-06 17:12）、Rob Herring（11-06 14:10） | 见左 | 即 v9 已修的两点（`>` 块修饰符、example 去掉固定 provider） |
| `<20261106112811.963923-1-…>` (dwc3 v7) | 已归档，已被 v8 取代 | 无新增（仅 v8 覆盖） | — | 版本号缺 `v7` 的工具失误件 |

**抓取层的坑（可复现）**：`lore.kernel.org/all/<msgid>/` 的 HTML 里唯一 `<pre>` 是「Thread overview」；
直接解析正文会得到空或线程树。必须走 `/all/<msgid>/raw`（`scripts/lore-fetch-raw.py` 的路径），
并且 `web_fetch` 这类通用抓取器对 lore 会撞 Anubis PoW（`PITFALLS #444` 已记）。


## 4. 逐系列处置建议

| 系列 | 当前判定 | 依据（本轮 lore 原文） | 下一步 | 需用户批准? |
|---|---|---|---|---|
| **wl2868c v9 1/2 binding** | ✅ **已被接受**（DT 侧） | Rob Herring 2026-11-09 14:54Z 单行 `Reviewed-by: Rob Herring (Arm) <robh@kernel.org>`（`/all/179423604384.3146607.887205491604475162.robh@kernel.org/raw`） | 无需动作；**review tag 直接沿用**，v10 若改 1/2 则 tag 作废（C1/C2 恰是 1/2 的两条 Low） | 否 |
| **wl2868c v9 2/2 driver** | 🟡 **在等 = 需回应** | sashiko 2026-11-09 20:14Z 三条 Medium（reset 早于 vsys / 仅 vin7 无 vsys / `chip->enabled` 未校验 bit7）——与 `reports/mail-triage-20261109.md` §2 的 B1–B3 **逐条同源** | 出 **v10**（B1–B3 + C1–C2 一并）；注意 Rob 的 Reviewed-by 只对 1/2，改 1/2 要重新请 review | **是**（v10 = 新系列版本，§7 逐次批准） |
| **M10 ADSP non-secure v2** | 🔴 **需回应**（两条人工 Low 落在 v2 自身） | ① Konrad 2026-11-09 15:16Z（对 v1）：「Please keep that under the `---` line so it doesn't end up in the commit log」；② sashiko 2026-11-10 02:41Z（对 v2）：同一条 + `Fixes:` 用 12 位 SHA + `qcom,non-secure-domain` 应排在 `memory-region` **之后**（DT 编码风格：标准属性在前） | 出 **v3**：changelog 移到 `---` 下、`Fixes: be9d54c35312`、属性换行。**注意 v2 未修 Konrad 的这条**（v2 正文里 changelog 仍在 `---` 之上） | **是**（v3 = 新版本） |
| **dwc3 v8 0/3** | 🔴 **需回应（实质 changes-requested）** | Rob Herring 2026-11-10 16:36Z：① `port-select-gpios` → 「Use the gpio mux binding」；② 「ports are for separate data streams. Endpoints are for mux'ed data streams ⇒ `port@0` should have 2 endpoints and `port@2` dropped」 | **v9 要改 binding 结构**（与 `reports/mail-triage-20261109.md` §2-A 的 A1–A4 方向相同但更强：A3 原本建议「补 `port@2`」，Rob 直接否掉 `port@2` ⇒ **A3 作废、改走单 port 双 endpoint**） | **是**（v9 = 新版本） |

- 系列状态差异要点：`reports/mail-triage-20261109.md:24` 记「本窗口新增技术待办 0」，**已被本轮推翻**——
  11-09 15:16Z 之后又进来 3 封有人类署名的实质意见（Konrad 1、Rob 2），其中 dwc3 那封是**结构性反对**，
  不是措辞级 Low。该 triage 的窗口止于 11-09 但其 `mail-triage-20261109.md` 未覆盖 11-09 14:16Z 之后的信。


## 5. §7「按系列逐次批准」口径：哪些还缺用户批准

§7 原文口径（`TASKS/README.md:1292`）：「**按系列逐次由用户批准**——2026-10-13 的「全面投递冻结」自 2026-10-19 起
逐案放开（M6 L1 → M8 RFC → M9 → M3-1 v4 → M4-1），**未批准的系列仍只做备料**」；
`TASKS/README.md:149` 同语：「投递解冻由用户按批放行，agent 不等回复」。

据此逐条：

| 候选动作 | 是否需用户批准 | 说明 |
|---|---|---|
| 发 wl2868c **v10**（回应 sashiko 3 Medium + 2 Low） | **需要** | 新版本 = 新投递，不在任何已批批次内 |
| 发 wl2868c 1/2 的任何一个新版本 | **需要**（且会作废 Rob 的 Reviewed-by） | 现 tag 只覆盖 v9 1/2 |
| 发 M10 **v3**（changelog 位置 + `Fixes:` 12 位 + 属性顺序） | **需要** | v2 已于 11-10 单独批准发出；v3 是新版本 |
| 发 dwc3 **v9**（binding 改单 port 双 endpoint） | **需要** | 结构性返工，必须重新过 dt-validate 正/负样例 |
| 纯回信（不带新版本）解释立场 | 需用户批准（同属发信） | §7 只放行过「回信 + 备料」的历史批次 |
| 现有 v9/v8/v2 的 resend / ping | **不建议**（且 §7 口径是「agent 不等回复」） | 三系列都有人类或有内容的 bot 回复在 2 天内，无需催 |
| 零投递的本地备料（生成 v9/v10/v3 补丁、跑门禁） | **不需要批准** | §7「未批准的系列仍只做备料」 |


## 6. 结论

1. **已被接受**：只有 **wl2868c `[PATCH v9 1/2]` binding** —— Rob Herring 2026-11-09 14:54Z 给了
   `Reviewed-by`（证据 = `/all/179423604384.3146607.887205491604475162.robh@kernel.org/raw` 正文唯一一行 tag）。
   其余无任何 Acked/Reviewed/Tested 标签。
2. **在等（无人工动作就行）**：无。三个在册系列本轮都至少各有一封 11-09～11-10 的新回复。
3. **需回应 = 3 条线**：
   - dwc3 v8 → Rob 2026-11-10 16:36Z **结构性反对** binding（`port@2` 删掉、`port@0` 两个 endpoint）+
     `port-select-gpios` 改用 gpio mux binding ⇒ 优先级最高，v9 需返工 binding。
   - M10 v2 → Konrad(11-09) + sashiko(11-10) 同一件事：changelog 要放到 `---` 线下；外加 `Fixes:` 12 位 SHA
     与属性顺序。**v2 发出时并未修 Konrad 那条**（`out/mail-20261110/README.md:9` 记 v2 只加了 `Fixes:` 与
     v2 changelog 段）⇒ 这是当前最便宜的一发。
   - wl2868c v9 2/2 → sashiko 3 条 Medium，与 `reports/mail-triage-20261109.md` §2 B1–B3 完全同源，可直接照改。
4. **与既有 triage 的冲突（需注意）**：`reports/mail-triage-20261109.md:24` 的「新增技术待办 0」已过期；
   同文 §2-A 的 **A3（补 `port@2`）被 Rob 直接否决**，备料时不要照 A3 改。
5. **缺用户批准才能发**：wl2868c v10、M10 v3、dwc3 v9 三个新版本，以及任何纯回信，全部需要用户按 §7 逐系列
   放行；本地备料（生成补丁 + 跑门禁）不需要批准。**本轮零发信**（禁发信，未调用 `git send-email`）。


## 未完成项

- **patchwork 状态未现查**：本轮只用 lore 复核（`TASKS/README.md:1291` 规定归档复核口径 = patchwork API + lore `/T/`），
  未调 patchwork API，故「是否已进入 maintainer 树（applied）」无证据，只能给到「lore 线程 + review tag」层。
- **6 个 Message-ID 里 #5/#6（wl2868c v8、dwc3 v7）只按 superseded 关系判定**，未逐封打开 v8/v7 的每一枚回信正文
  （其内容已被 v9/v8 覆盖，`out/mail-20261106/REPORT.md:11-16` 已有记录）。
- **未验证 Rob dwc3 意见与我方 binding 现状的差异行号**（只读原文，未对照 `patches/upstream/m3-dwc3-v7-20261106/`
  的 yaml 逐行）；备料前需要补这一步。
- **`web_fetch` 对 lore 全程被 Anubis 拦**（`PITFALLS #444`），本轮一律改用仓库脚本 + `lore-query.py`；
  若后续要求「必须用 web_fetch」，需先给出过挑战方案（未做）。
- 本轮**未改**任何版本账、未动设备、未 git 操作；只新建 `reports/mail-status-20261111.{md,tsv}` 与本报告的自编辑。
