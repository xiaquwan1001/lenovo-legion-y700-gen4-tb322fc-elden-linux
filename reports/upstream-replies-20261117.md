# 上游邮件 + 主线代码状态核查（2026-11-17）

> 只读核查：未发任何邮件、未 push、未动设备。查询方式见各节证据行。
> 上游状态账前身 = `reports/upstream-status-20261113.md`、`TASKS/README.md` §7。

## 结论数字表

| 项 | 数字 / 结论 |
|---|---|
| 已发 4 个系列里收到人回 | **1 / 4**（wl2868c v11 收到 Rob Herring） |
| 收到的实质回帖总数 | **2 封**：Rob Herring 对 wl2868c v11（要补 R-b，并重给 R-b）；Bryan O'Donoghue 对我方 camss CSIPHY **RFC**（不在 4 系列清单内） |
| 纯 bot（sashiko）回帖 | mdss v5 上 **3 封**（11-13 16:05/16:08/16:12），无人回 |
| 我方可发未发（阻塞在"放行"而非"回信"） | **5**：haptics v2、dpu-gamma v2、dwc3 v9、board DTS 单提交、Q28 证据回帖（+ camss-csiphy-24 两枚 = 6） |
| 主线已合入（我们相关） | **0 枚**；但同一 binding 家族上一代 **Kaanapali PHY 3 枚已合 phy-next**（2026-11-13） |
| 上游已废弃/变更影响我方 DTS | **1**：`qcom,nsessions`（fastrpc v7 三枚 2026-11-16 被 Srinivas 收下） |
| IMAP 通道 | **可用**（rc=0、INBOX 3 天 794 封），`--replies-only` 口径 0 封是过滤口径问题，非通道问题 |
| 主线 SM8750 CAMSS/PHY | **未合**（torvalds 里 `sm8750-csi2-phy` 0 命中）；Qualcomm 系列在 **v7**（2026-11-14，活跃评审） |

### 需要人决策的三件事（本轮只核查，未动手）

1. **wl2868c**：v11 的 1/2 缺 Rob 的 `Reviewed-by` —— 要么等 Mark 收 v11（并在后续说明），
   要么直接发 **v12 只补 tag**（3 枚，成本低、最省事）。依据见 §1.1。
2. **camss CSIPHY 2.4.0 两枚暂缓单发**：Bryan 明确要求基于 on-list 8750/Kaanapali 工作；
   先与 Hangxiang v25（PHY 已合 3 枚）+ Wenmeng v7（23 封）对账，找出真空缺再发。依据 §3.1。
   **★2026-11-17 下午已重基完成 = v2**（`patches/upstream/camss-csiphy-24-v2-20261117/`，基线 = 7.4-rc3 + v25 `[01..03]` 前缀，6 道门全绿）
   ⇒ 真空缺已定位：**v25 `[03/15]` 的 3nm cfg 复用 4nm v2.1.2 表**；剩一次上机出流回归 → `reports/camss-v25-rebase-20261117.md`。
3. **板级 DTS 去掉 `qcom,nsessions`**（上游已废弃该属性）：与 fastrpc driver 侧策略一起改。依据 §4.2。

## 0. 查询工具与可用性（可复现）

| 用途 | 入口 | 备注 |
|---|---|---|
| 取单封 / 整串 raw | `scripts/lore-fetch-raw.py <list|all> <mid> [-o DIR]` | 过 Anubis PoW；`curl` 直连 lore = **403** |
| 查线程有无回帖 | `/tmp/lore-thread.py <mid>`（本次临时件，逻辑 = 取 `https://lore.kernel.org/all/<mid>/t/`，打印 `Thread overview` 块） | 判据：overview 里出现非我方作者 = 有回帖 |
| 按主题搜（找最新 revision） | `/tmp/lore-search.py 's:"..."' N` → `https://lore.kernel.org/all/?q=...&x=A` | lore 偶发 "过挑战后仍被拦"，重试 1–2 次即可（本次 3 次失败均重试成功） |
| 判定是否进 mainline | GitHub commits API `https://api.github.com/search/commits?q=repo:torvalds/linux+<kw>` | **git.kernel.org 与 lore 也上 Anubis**，`raw.githubusercontent.com` 在本机不走代理不可达；API 可直连 |
| 系列状态（合没合） | patchwork REST：`https://patchwork.linuxtv.org/api/1.2/series/<id>/` | 例：Kaanapali `series/33877` → `version 25` |
| 收件箱 | `~/.local/bin/read-mail-ustc.py --days N [--grep X] [--replies-only]` | **不在 `scripts/` 下**（任务描述里的路径是错的），在 `~/.local/bin/` |

**本地树不适用于判主线**：`linux/` = 下游 `snap-20261110-v7.2-elden`（origin = GEEKiDoS/linux），
`build/daily` = 我方工作树，二者 `git log --grep` 查不到 mainline 合入（`sm8750-csi2-phy` 0 命中属正常，非证据）。

DONE: §0

## 1. 我们已发件的回复（lore 线程核查，2026-11-17）

**一行结论**：4 个在飞系列里 **只有 wl2868c v11 收到人回**（Rob Herring 2026-11-16 15:10 UTC，指 v11 丢了 R-b 并**重给** `Reviewed-by`）；pstore v1、dsi/phy v2、mdss v5 **零人回复**（mdss v5 只有 sashiko-bot 当天自动意见）。

| 系列 | 最新一封 | 线程内他人回帖 | 结论 |
|---|---|---|---|
| pstore/ram initrd 重叠 v1 | 2026-11-16 04:00 UTC（3 封，全是我方） | **无** | 等 Kees/Tony；暂未进任何分支 |
| dsi/phy PLL_SYSTEM_MUXES **v2** | 2026-11-16 15:03 UTC | 仅 Dmitry **2026-11-11 17:09**（针对 v1，要求注释进 commit msg） | v2 之后 **0 回** |
| drm/msm/mdss 块复位 **v5** | 2026-11-13 15:56 UTC | 仅 `sashiko-bot` 2026-11-13 16:05/16:08/16:12 | 维护者 0 回 |
| regulator wl2868c **v11** | 2026-11-13 08:19 UTC | **Rob Herring 2026-11-16 15:10 UTC** | 要补 R-b 到下一版；Mark/Konrad 仍未回 driver 侧 |

### 1.1 wl2868c v11 —— Rob Herring 回帖（唯一实质回复）

- URL：`https://lore.kernel.org/all/20261116151052.GA1449968-robh@kernel.org/`
  （`In-Reply-To: <9ab5e5937264bb…>` = v11 **1/2 binding**，MID 与 `patches/upstream/wl2868c-v11-20261113/README.md` 记的一致）
- 日期：`Date: Mon, 16 Nov 2026 09:10:52 -0600`（= 15:10 UTC）
- 原文关键片段（抓取：`scripts/lore-fetch-raw.py all 20261116151052.GA1449968-robh@kernel.org -o /tmp/lore-robh`）：

```
Missing my Reviewed-by tag. It's your responsibility to add tags when 
sending new versions.

Reviewed-by: Rob Herring (Arm) <robh@kernel.org>
```

- 判定：**不是反对**，是流程性指摘 —— v11 的 1/2 丢了 v10 时已拿到的 `Reviewed-by`（我方
  `reports/upstream-status-20261113.md` §2 记「binding 侧 Rob 已 R-b」，v11 复投时漏带）。
  处置：下一版（或若 Mark 直接收 v11）**必须**把该 tag 补进 1/2 的 commit trailer；
  若由 Mark 收 v11 原样，则需在回帖里说明 tag 缺失并给 v12。
- 同期线程内 **无** Mark Brown / Konrad / Krzysztof 的回复（线程 overview 3 封 + Rob 1 封）。

### 1.2 dsi/phy v2 —— 无新回复

- URL：`https://lore.kernel.org/all/20261116150334.78710-1-xiaqinghuan@mail.ustc.edu.cn/t/`
- 线程 overview（原文摘录）：

```
2026-10-19 13:00 [PATCH] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable Qianhui Xu
2026-11-11 17:09 ` Dmitry Baryshkov
2026-11-16 14:50   ` Qianhui Xu
2026-11-16 15:03   ` [PATCH v2] " Qianhui Xu
```
- 判定：v2 投出（15:03 UTC）后**无人回**；`end of thread, other threads:[~2026-11-16 15:03 UTC | newest]`
  ⇒ 该归档列表此后无更新到本线程。

### 1.3 mdss v5 —— 仅 sashiko-bot，维护者 0 回

- URL：`https://lore.kernel.org/all/20261113155635.1677541-1-xiaqinghuan@mail.ustc.edu.cn/t/`
- 线程 overview：

```
2026-11-13 15:56 [PATCH v5 0/3] drm/msm/mdss: reset all block resets described in DT Qianhui Xu
2026-11-13 16:12   sashiko-bot      (1/3 dt-bindings)
2026-11-13 16:08   sashiko-bot      (2/3 driver)
2026-11-13 16:05   sashiko-bot      (3/3 dts)
```
- 判定：Rob / Dmitry / Konrad / Abel **均未回 v5**；sashiko 的 3 条与 v5 cover 中已答的 Medium 同源。
  **Q28 证据回帖仍未发**（`patches/upstream/mdss-v5-q28-evidence-20261116/`），线程里因此仍缺该证据。
- 附：v5 之前的 **v4 3/3 拿到 Konrad 的 R-b**（非回帖于 v5，属 v4 遗产）——
  `<9d0a3aec-052f-4209-b2db-0c2112de33aa@oss.qualcomm.com>`（2026-11-13 08:42 UTC）正文仅一行
  `Reviewed-by: Konrad Dybcio <konrad.dybcio@oss.qualcomm.com>`；v5 的 3/3 已保留该 tag（与
  `reports/upstream-status-20261113.md` §1「三个 R-b 含 Konrad」一致）。

### 1.4 pstore/ram initrd 重叠 v1 —— 零回复

- URL：`https://lore.kernel.org/all/20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn/t/`
- 线程 overview：

```
Thread overview: 3+ messages
2026-11-16  4:00 [PATCH 0/2] pstore/ram: refuse zones overlapping the initrd Qianhui Xu
2026-11-16  4:00 ` [PATCH 1/2] init: initrd: add initrd_phys_range() Qianhui Xu
2026-11-16  4:00 ` [PATCH 2/2] pstore/ram: skip zones overlapping the initrd Qianhui Xu
```
- 判定：投出 20 h 内**无人回**（Kees Cook / Tony Luck / Guilherme G. Piccoli 均沉默）。

DONE: §1

## 2. 收件箱回复核查（IMAP，2026-11-17）

**一行结论**：**通道可用**（keyring 未锁，`rc=0`，非超时）；但 `--replies-only` 口径下 INBOX/Junk/Sent 各 **0 封**（该过滤口径对本批不计 Rob 的回帖，见下），改用 `--grep` 精确检索后**确认收到 1 封真回复 = Rob Herring 对 wl2868c v11 的 R-b 指摘**。

| 检查 | 命令 | 结果 |
|---|---|---|
| `--replies-only` 全量 | `timeout 130 python3 ~/.local/bin/read-mail-ustc.py --days 3 --replies-only` | INBOX 0 / Junk 0 / Sent 0，**rc=0**（无超时） |
| INBOX 总量（对照） | `... --days 3` | INBOX **794 封**（SINCE 14-Nov-2026）⇒ 通道确实通 |
| wl2868c 定向 | `... --days 5 --grep wl2868c` | 命中 **Rob Herring 2026-11-16 09:10:52 -0600** `Re: [PATCH v11 1/2] …`（= §1.1）；另有 Mark Brown **11-11 17:42 UTC** 对 **v10 2/2** 的旧回信 |
| dsi/phy 定向 | `... --grep PLL_SYSTEM_MUXES` | 6 封，全部是我方 11-16 两发 + Dmitry **11-11 19:09 +0200** 旧回帖；**v2 后 0 封** |
| pstore 定向 | `... --grep pstore` | 仅我方 2 封（0/2 与 2/2 各一），**0 封回信** |
| sm8750 定向 | `... --grep sm8750` | 12 封，**无**对我方 mdss 系列的回复；含 Qualcomm camss v7 系列回帖（§3）与 Konrad 对 mdss **v4** 3/3 的 11-13 回帖（§1.3 注） |
| mdss 定向 | `... --grep mdss` | 13 封；对我方系列只有 sashiko-bot(v4) 与 Konrad 11-13 09:42 +0100 **对 v4** 的回帖，**v5 无回** |
| aw86937 / haptics | `... --grep aw86937` / `--grep haptics` | **各 0 封**（5 天窗口内无任何回音） |
| fastrpc | `... --grep fastrpc` | 12 封，均为 Qualcomm 内部其它 fastrpc 线程（`Srinivas Kandagatla` 审 `Vinayak Katoch` 的 probe-race 系列），**无**对 `accel/qda` / `nsessions` 的动静 |

**已知工具缺陷（不影响本次结论）**：`--folders INBOX,"Junk E-mail"` 组合会在第二个文件夹处
`imaplib.select()` 抛栈（脚本仅支持单文件夹或默认集）；本次用默认文件夹集 + `--grep` 绕过。
`Sent Items` 仍是 0 是因为 `send-mail-ustc.py` 走 smtplib 不 APPEND（`reports/upstream-status-20261113.md` §2b 已登记）。

DONE: §2

## 3. 主线状态：SM8750 CSIPHY / CAMSS

**一行结论**：**SM8750 相机 PHY 与 CAMSS 均未进主线**；但**同一 binding 家族的上一代（Kaanapali）PHY 三件已于 2026-11-13 被 Vinod Koul 收进 phy 树**，且 Qualcomm 的 SM8750 系列已在 lore 走到 **v7（23 封，2026-11-14）**并在活跃评审中；我方 2026-11-15 的 RFC **已收到 Bryan O'Donoghue 回信**（指向"用 on-list 那条工作"）。

| 核查项 | 结论 | 证据 |
|---|---|---|
| `sm8750-csi2-phy` 是否在 mainline | **否**（0 命中） | GitHub commits API：`search/commits?q=repo:torvalds/linux+sm8750-csi2-phy` → `total_count: 0` |
| `qcom,sm8750-camss` 是否在 mainline | **否**（2 命中均为无关旧件：`i2c: qcom-cci: Document SM8750` 2025-12、`qcom-arm64-for-6.17` merge） | 同上 `+qcom,sm8750-camss` → total 2 |
| 上游 PHY 驱动现状 | 已有 `drivers/phy/qualcomm/phy-qcom-mipi-csi2-{core,3ph-dphy}.c`（2026-09-16 合入，7.4），**只支持 `qcom,x1e80100-csi2-phy`，仅 DPHY** | commit `2bc7bb2b8e` 正文：「The following devices are supported in this drop: "qcom,x1e80100-csi2-phy"」「For now only DPHY is supported」 |
| Kaanapali（同 family 上一代）PHY | **已合 phy-next**：3 枚 `846aacbf8322` / `478577f3db4a` / `00926bc50707` | Vinod Koul `Re: (subset) [PATCH v25 00/15]`（2026-11-13 19:15 +0530）：「Applied, thanks!」+ 三个 commit 号；URL `https://lore.kernel.org/all/179457754639.652128.11064545317839632813.b4-ty@kernel.org/` |
| SM8750 系列最新 revision | **v7**，`[PATCH v7 00/23] Add CAMSS support for SM8750 and Eliza`（Wenmeng Liu，2026-11-14 11:29 UTC），82 封、仍在讨论 | `https://lore.kernel.org/all/20261114-add-support-for-camss-on-sm8750-v7-0-8ff2a11835f6@oss.qualcomm.com/t/`：Krzysztof 11-14 18:11 与 11-16 10:14、Bryan 11-15 12:05 均在其 1/23、2/23、3/23 上回帖 |
| 另一条 in-flight（更大的）| `[PATCH v25 00/15] media: qcom: camss: Add Kaanapali support`（Hangxiang Ma，2026-11-13）——PHY 3 枚已合，CAMSS 8 枚仍待 Bryan/Mauro | patchwork API `https://patchwork.linuxtv.org/api/1.2/series/33877/` → `version: 25, 15 patches, submitter Hangxiang Ma` |

### 3.1 我方 RFC 收到回信（此前账上无此条）

- 我方件：`[RFC] phy: qcom: mipi-csi2-3ph: SM8750 ships CSIPHY 2.4.0 lane table - preferred shape?`
  （2026-11-15 05:29 UTC，`<179472053649.14538.1565870277822789081@mail.ustc.edu.cn>`，见 IMAP INBOX #290）
- 回信：**Bryan O'Donoghue `<bod@kernel.org>`，2026-11-15 17:44 UTC**，
  `<57ea8341-4685-4b50-9072-cceab6fc1623@kernel.org>`
  （取证：`scripts/lore-fetch-raw.py all 57ea8341-4685-4b50-9072-cceab6fc1623@kernel.org -o /tmp/lore-rfc`）
- 原文关键片段：

```
OK I's not clear to me if what is meant is stuff that Hangxiang is 
working on
There's a v25 on list for sm8750
https://patchwork.linuxtv.org/user/todo/linux-media/?series=33877

New work/additional-work/bug-fixes on top of that branch or absorption 
of downstream work ?
...
I think I already indicated the stuff on-list is good to go so if you 
have more fixes/changes/enhancements please ensure to base off of those.
...
I'm finding the LLM output pretty difficult to understand to be honest.
But if I've understood you here I think you've missed 
Hangxiang/Qualcomm's work for 8750 so please pick up on that and see if 
there are still gaps for you.
```

- **判读（要点，供下轮决策）**：① 上游明确要求**先对齐 on-list 的 Kaanapali/8750 工作再谈补丁**，
  我方 `patches/upstream/camss-csiphy-24-20261115/` 若直接单发会被当作重复工作；
  ② **"per-SoC lane 表"这一形状已被上游采纳**（v25 `[03/15] phy: qcom-mipi-csi2: Add Kaanapali support`
  = 新增该代 lane 设置），我方 RFC 问题 1 的答案基本给出；
  ③ Bryan 对我方邮件的 AI 披露措辞有明确负面反应（"LLM output pretty difficult to understand"）
  ⇒ 后续给 phy 侧的信**去掉冗长 AI 风格铺陈、只留最小必要事实**。

## 4. fastrpc：`accel/qda` v4 与 `qcom,nsessions` 废弃

**一行结论**：`accel/qda` 仍是 **v4（25 封，2026-11-01 发，最后活动 2026-11-11，未合、无 v5）**；`qcom,nsessions` 废弃系列 **v7 已于 2026-11-16 被 Srinivas Kandagatla 收下（Applied，3 个 commit）**，即**上游已正式废弃 `qcom,nsessions`**。

### 4.1 `accel/qda` v4

- 线程：`https://lore.kernel.org/all/20261106091121.3958523-1-tomeuvizoso.net/t/`
  （`[PATCH v4 00/25] accel/qda: Qualcomm DSP Accelerator driver`，Ekansh Gupta，2026-11-01 22:21 UTC）
- 线程 overview（68 封）末三条：`2026-11-11 8:33/8:35/8:36 Ekansh Gupta`（作者逐条答 Krzysztof 11-02 的 review）；
  `end of thread, other threads:[~2026-11-11 8:38 UTC | newest]` ⇒ **11-11 之后无新活动、无 v5**
- mainline：`repo:torvalds/linux` 搜 `qda+accelerator` → **total 0**（未合）
- 判读：v4 处于"作者答完 review、等下一版或维护者表态"，**与本次核查窗口（11-12~11-17）无交集**。

### 4.2 `qcom,nsessions` 废弃 —— 已合

- 系列：`[PATCH v7 0/3] misc: fastrpc: fix ADSP duplicate session creation`（Vinayak Katoch，2026-11-02 08:31 UTC）
  `https://lore.kernel.org/all/20261102-dup-sessions-v7-0-03f06c014e78@oss.qualcomm.com/t/`
- 关键回信：**Srinivas Kandagatla，2026-11-16 10:04 UTC**（`<179482349066.14925.18435181444934097603.b4-ty@kernel.org>`）：

```
Applied, thanks!

[1/3] misc: fastrpc: iterate CB nodes manually instead of of_platform_populate
      commit: 81b3908cf7b9b19a8a47521a18281399c55db889
[2/3] misc: fastrpc: move ADSP duplicate session creation to the driver
      commit: 112dc91edd51e964351513d876c2e5a63cbe980a
[3/3] dt-bindings: misc: qcom,fastrpc: deprecate qcom,nsessions
      commit: 641dd7dd0f68dacb8e972aded126887c17d6cf37
```
- 同线程另有 `Tested-by: Tyler Baker # Eliza EVK, EL2`（2026-11-07）。
- 版本账：v4(08-26) → v5(09-23) → v6(10-21) → **v7(11-02) 合入**（lore 搜索 `s:"qcom,nsessions"`，12 条）
- **对我方的影响**：板级 DTS 里若还写 `qcom,nsessions`，现在在主线属于**已废弃属性**；
  我方 fastrpc `non-secure` v3 与 DT 侧的 session 数策略需按"驱动侧策略"重述（不再靠 DT 属性）。

DONE: §3
DONE: §4

## 5. 其它在飞系列（各一句话）

| 系列 | 我方状态 | lore 上他人同名系列 / 是否合入 | 结论一句话 |
|---|---|---|---|
| haptics **aw86937 v2** | **未投**（`patches/upstream/haptics-v2-20261113/`，6 枚，v2 草案） | 仅我方 v1（2026-10-27）+ Krzysztof `Acked-by`（2026-10-27 18:06 UTC，属 2/5 binding）；mainline `aw86937` **0 命中** | 无人提同名系列、未合；v2 现在只需发，不需要对齐别人的系列 |
| dpu-gamma **v2**（reject undersized gamma LUT blobs） | **未投**（v2 草案） | 仅我方 v1（2026-10-13）+ Dmitry 唯一回帖（**2026-11-11 16:58 UTC**，`h346otf…@wcanozcwnysb`）→ 正是 v2 要答的那条；mainline **无**该主题提交 | 未合、无他人抢做；注意 mainline 另有一枚**不同主题**的 `drm/msm/dpu: Fix GAMMA LUT for sm8750 related DPUs`（Rob Clark，2026-09-30 合，commit `3389406e6a`，加 GC 块），别混为一谈 |
| dwc3 **v9**（两 connector 共享一条 HS bus） | **未投**（v9 草案；最后实发 = **v8**，2026-11-06） | 仅我方系列（v8 及以前）；阻塞点 = Rob Herring **2026-11-10 16:36 UTC** 的结构性反对（ports 留独立数据流） | 未合、无他人系列；v9 改动方向已按 Rob 意见重排，等放行 |
| board DTS **单提交**（`sm8750-lenovo-elden`） | **未投**（`patches/upstream/board-dts-single-20261113/`） | 上游最后件 = 我方 **v6 4/5 + 5/5**（2026-11-04）；Krzysztof **2026-11-04 11:30 +0100** 回帖原文：`I do not understand why this is a separate patch. You add new hardware, so the commit is "add new hardware". One logical action, one commit.`；mainline `lenovo-elden` **0 命中** | 未合；单提交正是这条意见的落地，属"待发"而非"待回复" |
| **Q28** 线程 | 我方线程 = mdss v5（Q28 = 内部代号）；**Q28 证据回帖仍未发** | lore `s:"Q28"` → 唯一命中是 2018 一条无关邮件；**无**他人提同名系列；主线无相关合入 | 无人对 Q28 有独立线程；欠的是我方把证据回进 mdss v5 线程 |

补充（同为"在飞"但不在原清单）：**camss CSIPHY 2.4.0 两枚**（`patches/upstream/camss-csiphy-24-20261115/`）也未投，
但 §3.1 的 Bryan 回信已把"先对齐 on-list 8750/Kaanapali 工作"设为前置条件。

DONE: §5

## 6. 复核边界（未做/查不到的都写明）

- **未做**：未发任何邮件、未 `git push`、未碰设备（设备断电）；未改工作区任何源码/DTS。
- **未查**：patchwork 上 4 个我方系列的逐 patch `state`（本轮用 lore 线程 + IMAP 判"有无回帖"，
  未拉 patchwork REST 的 `new/under-review/action-required` 字段）——若需要逐 patch 状态，命令为
  `curl -s "https://patchwork.kernel.org/api/1.2/patches/?q=<subject 片段>"`。
- **时效**：lore/IMAP 快照时刻 **2026-11-17 约 09:00 +0800**；此后新到邮件不在本报告内。
- **lore 未命中 ≠ 未投**：判"投递"以 `scripts/lore-fetch-raw.py` 取到 raw 为准（本报告所有引用条目均已取到原文）。

DONE: §6
