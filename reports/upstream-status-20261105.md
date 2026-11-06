# 上游系列状态页 — 2026-11-05

> **取代** `reports/upstream-status-20261029.md`（后者停在 10-29；其「M4-2 九枚在评审」「M8 返工」「M3-1 v5 待 v5 修正」等结论已分别被 10-31 / 11-02 / 11-04 三批投递与回信推翻）。
> **权威口径仍在 `TASKS/README.md` §7 各 M 行**；本页是压缩视图 + 本窗口（11-04 02:12Z → 11-05 02:40Z）的独立复核结果。
> 原始分诊 = `reports/mail-triage-20261105.md`（本轮增量窗逐封表）。
> **本轮为只读 lane**：只新增本文件与 `mail-triage-20261105.md`；未发信、未改 patchwork、未碰设备、未改任何既有文件、未 commit。

---

## 0. 一句话

**三批 10 封（10-31 / 11-02 / 11-04）全部在档（patchwork 非 cover 全命中）、窗口内 0 封退信；但 11-04 投出后 8 条外部回信无人处理** —— 6 封 sashiko（**2 High + 8 Medium**）+ **Krzysztof 2 条 changes-requested（v6 拆补丁 / commit message）**，其中 dwc3 两条 High 是真实并发缺陷。

---

## 1. 逐系列状态（窗口 11-04 02:12Z → 11-05 02:40Z 复核）

口径：归档列 = **patchwork API 非 cover 计数**（`patches/?submitter=xiaqinghuan@mail.ustc.edu.cn&since=2026-10-25&per_page=200`，168 条，按 `series` 分组；cover 不入 patchwork，故分母不用「N+1」）。不使用 lore `/raw`（Anubis，见 §3）。

| 系列 | 状态 | 最近动作与 MID | 归档复核（非 cover） | **我方欠什么** | 复启/返工条件 |
|---|---|---|---|---|---|
| **M3-1 dwc3 双连接器**（11-04 `0/3` 自足重发） | 🟡 在评审，**两条 High 未答** | 11-04 03:27Z 投 4 封：cover `<20261104032706.210042-1-…>`、1/3 `-2`、2/3 `-3`、3/3 `-4`（Sent[254]–[257]） | **在档**：`linux-usb 3/3 new`、`linux-arm-msm 3/3 new`、`devicetree 1/1 needs-ack`（只有 1/3 binding 进 DT） | ① **3/3 两条 [High]**：`dwc3_mux_role_set()` 在 `dwc3->lock` 释放期间让 `__dwc3_set_mode()` 读到「新 `mux->desired_port` + 旧 `dwc->desired_dr_role`」的撕裂；`dwc3_role_mux_init()` 部分注册失败时 `cancel_work_sync()` 早于 `usb_role_switch_unregister()` ⇒ work 可在 `dwc->role_mux=NULL` 后运行（`<sashiko-outbox-196628@kernel.org>`）。② **1/3 三条 [Medium]**：`oneOf` 缺 endpoint/mux-state required、顶层 `ports` 缺 `port@2`、Linux 专有 mux 绑定与 port@2 拆分（`<sashiko-outbox-196629@kernel.org>`）。③ 2/3（roles）**sashiko 零问题**（`<sashiko-outbox-196610@kernel.org>`），无需动作 | v6 条件：先修两条 High（锁序 + err 路径与 unregister 同步），再把 1/3 三条 binding 意见落进去；**未收到 Krzysztof/Krishna/Thinh 对本轮新回信**（窗口内 0 条），不要主动 ping |
| **wl2868c（11-04 `v6 0/5`）** | 🟡 在评审，**2 条维护者 changes-requested + 5 条 sashiko 未答** | 11-04 03:26Z 投 6 封：cover `<20261104032648.209747-1-…>` … 5/5 `-6`（Sent[248]–[253]） | **在档**：`linux-arm-msm 5/5 new`、`devicetree 5/5`（3 handled-elsewhere + 1 changes-requested + 1 needs-ack） | ① **Krzysztof 10:30Z（对 5/5）**：*"I do not understand why this is a separate patch… One logical action, one commit"* ⇒ 5/5 应并入 4/5（`<20261104-elfish-booby-of-awe-27d2b6@quoll>`）。② **Krzysztof 10:31Z（对 3/5）**：*"Board cannot be shipped with such compatible - it's first time usage here. 'Add Lenovo Legion Y700 Gen4, an Qualcomm SM8750-based tablet'"*（`<20261104-offbeat-cerulean-degu-cfec1b@quoll>`）。③ sashiko 2/5 三条 Medium：`chip->enabled` 未初始化 → boot 已开的 LDO 位被后续写清、`vsys-supply` 从未 request/enable（probe 读 ID 时可能无供电）、`disable()` 先清位再写寄存器（写失败后与 core 失步）。④ sashiko 4/5 一条 Medium：板 DT 是「未验证骨架」（缺 SPMI/RPMh/console/存储，父 supply 全 dummy）。⑤ sashiko 5/5 一条 Medium：同上（pmic@2f 的 vin12/34/5/7 父 supply 缺失，六路 LDO 落到 dummy） | v7 条件：并入 5/5→4/5、改 3/5 commit message、driver 三处状态一致性、板 DT 是否与 PMIC/使用者一起发（Krzysztof/sashiko/Konrad 三处同向，等价于「别单发骨架板 DT」） |
| **M8 mdss 块复位（`v3 0/3`）** | 🟢 有 **Reviewed-by**，等 1/3、2/3 | 11-02 05:50Z 投 4 封 `<20261102055026.438521-1..4>`；Abel Vesa 11-02 13:17Z **Reviewed-by 3/3** `<buaeo5m3ozihgl5t6767jvu72umwbzqx2debegmzvkuigwwqki@zbtoarlnnihe>` | **在档**：`dri-devel 3/3 new`、`linux-arm-msm 3/3 new`、`devicetree 1/1 needs-ack`（1/3 binding） | 无（窗口内 0 条新意见）；若出 v4 **只累积 tag**，不要改动内容 | 等 Dmitry/Konrad/维护者看 1/3、2/3；不改内容 |
| **M6 / B5 bonded DSI** | ⛔ **继续封存（不投）** | v1 `0/5` 10-31 15:03Z 投 `<20261031150305.1107572-1..6>`；v2 4 枚 11-02 备料**未投**（`patches/upstream/m6-b5-v2-20261102/`） | v1 **在档**：`dri-devel 5/5 new`、`linux-arm-msm 5/5 handled-elsewhere`；v2 **不在档（预期，未发）** | 无（窗口内 Dmitry 0 条新回信，最后仍是 10-31 20:31Z） | 复启三条（见 `TASKS` §7 11-04 裁决）：(a) elden 板级 DTS 进树/进同线程；(b) 上游出现第二个 SM8750 command-mode bonded 需求；(c) Dmitry/Taniya 索要 |
| **M4-2 camss 通用修复（`v2 0/2`）** | 🟡 Loic 正面，等 Bryan | 10-31 04:11Z 投 `<20261031041154.308030-1..3>`；Loic 11-02 09:22Z 正面并把决定权交 Bryan | **在档**：`v2 → linux-media 2/2 new`、`linux-arm-msm 2/2 handled-elsewhere`；**three-fixes 0/3 在 linux-media 已全部 `superseded`**（`linux-arm-msm 3/3 handled-elsewhere`） | 无（窗口内 camss 侧 0 条针对我方 msgid 的新回信；11-04 的 camss 讨论全是别人的线程） | 等 Bryan；不 ping |
| **M4-1 bindings（gt9764 / s5kjns `0/2`）** | 🟡 等 review（v2 未出） | 10-27 05:10Z 投 `<20261027051048.213177-1..3>` | **在档**：`devicetree 2/2 changes-requested`、`linux-media 2/2 new` | Krzysztof 10-28 两封意见仍待落（v2 未发）；窗口内 0 条新意见 | 出 v2 时并入 10-28 意见 |
| **aw86927（`0/5`）** | 🟡 等 review（Krzysztof Acked-by 2/5） | 10-27 13:29Z 投 `<20261027132929.242158-1..6>` | **在档**：`linux-input 5/5 new`、`devicetree 5/5`（4 handled-elsewhere + 1 not-applicable） | 无新意见；v3 只需并 10-27 那轮（sashiko 4/5、5/5 两条 Medium + 2/5 binding 要求） | 出 v3 时保留 Ack 原样 |
| **M2-A2 `qcom_battmgr` power_now** | 🟡 等 review | 10-27 13:29Z 投 `<20261027132929.242158-…>`（同批） | **在档**：`linux-pm 1/1 handled-elsewhere`（另 `linux-arm-msm` 有副本） | 无（窗口内 0 条） | 若做 v2，落点 = 扩展上游 qcom_battmgr |
| **M1-U6 `q6v5_pas` DTB 固件释放** | 🟡 等 review | 10-27 13:29Z 投 | **在档**：`linux-remoteproc 1/1 new` | 无（0 条回信） | 无 |
| **M9 GIC ITS 认领 LPI 表** | ⛔ 已撤回（Marc Zyngier 否方案） | 10-24 07:58Z 投 `<20261024075856.835932-1-…>`；10-26 撤回信已发 | **部分在档**：`linux-arm-kernel 1/1 new`；**LKML 副本未证**（本窗口 submitter 查询只返回 arm-kernel 一份，未单独取 lkml 项目） | 无（口径已改为「kexec 不覆盖需 LPI 场景」） | 不重启；若重启改「引导器预置 + DT memreserve」 |

> 序号说明：`M3-1` = dwc3 双连接器；`M4-2` = camss；`M6/B5` = bonded DSI 核心；`M8` = dispcc/mdss 复位落点。

### 1b. 本轮前后三批投递事实（Sent Items 回读，108 封全表）

| 批次 | 系列 | 邮件数 | Message-ID 前缀 | Sent seq | patchwork 索引 |
|---|---|---|---|---|---|
| **10-31**（03:42–06:55Z） | wl2868c v3 `0/3` → v4 `0/4`（同日两版，v3 已被 v4 取代） | 4 + 5 | `20261031034300.272730-1..4`、`cover.1793427040.git…` | [208]–[211]、[219]–[223] | 在档（v3/v4 均 `superseded`） |
| 10-31（04:11Z） | M4 camss `v2 0/2` | 3 | `20261031041154.308030-1..3` | [212]–[214] | 在档 `linux-media 2/2 new` |
| 10-31（15:01–15:03Z） | M3-1 dwc3 `v5 0/2` + M6 B5 `0/5` | 3 + 6 | `20261031150154.1106455-1..3`、`20261031150305.1107572-1..6` | [224]–[226]、[227]–[232] | 在档（后均被取代或封存） |
| **11-02**（05:40–06:06Z） | dwc3 `v5 1/2` 单封重投 + M8 `v3 0/3` + wl2868c `v5 0/4` + 3 封回信 | 1 + 4 + 5 + 3 | `179359806935.413510…`、`20261102055026.438521-1..4`、`20261102060458.461372-1..5` | [234]–[247] | 在档；**该批 6 封 DSN 550 全指不存在的 `linux-regulator@`**（见 §2） |
| **11-04**（03:26–03:27Z） | wl2868c `v6 0/5` + dwc3 `0/3` | 6 + 4 = **10** | `20261104032648.209747-1..6`、`20261104032706.210042-1..4` | [248]–[257] | **8 枚非 cover 全命中**（5/5 + 3/3），0 退信 |

复核命令（只读）：

```bash
python3 /tmp/laneA/sent.py    # Sent Items SINCE 25-Oct-2026，按日计数 26/15/10
curl -s --noproxy '*' "https://patchwork.kernel.org/api/1.2/patches/?submitter=xiaqinghuan%40mail.ustc.edu.cn&since=2026-10-25&per_page=200" -o /tmp/laneA/pw.json
```

---

## 2. 必须先处理的非技术 / 流程事件

1. **sashiko 已是事实上的第一响应者**：11-04 那批 6 封 sashiko 全在投递后 **7–17 分钟**到达（03:34:41–03:44:30Z vs 投递 03:26:43–03:27:06Z），而人类维护者第一封是 Krzysztof **7 小时后**（10:30Z）。评审队列里「先到的不答、后到的被答」会被读成放弃维护，**处理顺序应先 sashiko 再人类**。
2. **Krzysztof 仍在对「拆补丁」扣分**（11-04 10:30Z：5/5 单发 = *"One logical action, one commit"*；10-31 起他已在 wl2868c 线上连续三轮提同一点）。这是**表述/打包纪律**问题，不是技术问题；11-04 的 `3/5`（`arm/qcom.yaml` 拆分）恰恰是他 11-02 要求的，说明**同一位维护者前后要求不同，落地时以最新一封为准**。
3. **地址纪律已修好、需保持**：11-02 批 6 封 550 全指 `linux-regulator@vger.kernel.org`（本地 `linux/MAINTAINERS` 该子系统只有 `L: linux-kernel@vger.kernel.org`，全树 0 命中，见 §3）；11-04 批改用「To = Liam/Mark，Cc LKML」后 **0 封 DSN**。历史同类坑 `linux-devicetree@`（正确 `devicetree@`）。11-04 dwc3 那批亦未再抄 `linux-devicetree@`，0 退信。
4. **patchwork 状态已自动跟随 Krzysztof 意见**：`devicetree` 项目 v6 3/5 = `changes-requested`、1/5 = `needs-ack`；dwc3 `1/3` = `needs-ack`。⇒ 维护者看板已能看到「有异议」，我方不处理会持续累积。
5. **`\Seen` 不可用**（沿用 11-04 结论）：本邮箱 `UNSEEN 12149 / MESSAGES 12289`，本轮 8 条外部回信仍全部无 `\Seen`。判「是否已处理」只以报告为准。
6. **GitHub OAuth 第三方应用告警**（11-02 15:14Z，Junk 294）仍**需用户本人核实**，本轮只上报。

---

## 3. 工具事实与坑（本轮实测，均已复现）

| # | 事实 | 证据 |
|---|---|---|
| T1 | `read-mail-ustc.py --replies-only` 会漏检：`OUR_IDS` 只硬编码 3 个旧 Message-ID | `grep -n OUR_IDS ~/.local/bin/read-mail-ustc.py` → 第 13 行 3 条；第 66 行 `if not any(o in irt for o in OUR_IDS): continue` |
| T2 | `--folders` 的 Junk 名**必须带引号**（`"Junk E-mail"`），否则 `select` 失败 | `imaplib` 假名；本 lane 用 `M.select(box, readonly=True)` 传 `'"Junk E-mail"'` 成功（`/tmp/laneA/scan.py`） |
| T3 | 只读必须显式 `readonly=True`（= EXAMINE）；仓库内 `out/mail-20261029b/mailscan.py` 用 `M.select(box)`（可写模式），**复用时须改** | `sed -n '55,60p' out/mail-20261029b/mailscan.py`；本 lane 全程 `BODY.PEEK`，无 STORE/COPY/EXPUNGE/MOVE |
| T4 | patchwork `?msgid=<mid>` **恒返回空数组**（不能按 Message-ID 查） | `curl "…/patches/?msgid=20261104032706.210042-1-xiaqinghuan@mail.ustc.edu.cn"` → `[]`（HTTP 200, 2 B） |
| T5 | **cover 不入 patchwork**：series 的 `n` = 非 cover 数（v6 `0/5` 在档 5 条，dwc3 `0/3` 在档 3 条） | §1 表；`pw.json` 里无 `-1-`（cover）msgid |
| T6 | 同一系列在多个 project 各有一份副本，**归档要按 project 分别计数** | 例：`1201267 linux-arm-msm 5/5 new` vs `1201276 devicetree 5/5`(3 handled-elsewhere/1 changes-requested/1 needs-ack) |
| T7 | lore 仍被 Anubis 拦截：`/<list>/<mid>/raw` = HTTP 200 但 7712 B 挑战页 | `curl … /linux-usb/20261104032706.210042-1-…/raw` → `HTTP 200 bytes=7712`，`grep -c "not a bot"` = 2 |
| T8 | `linux-regulator@vger.kernel.org` **不存在** | `sed -n '/VOLTAGE AND CURRENT REGULATOR FRAMEWORK/,+14p' linux/MAINTAINERS \| grep -E '^L:\|^M:'` → 只有 `L: linux-kernel@vger.kernel.org`；`grep -rn linux-regulator linux/MAINTAINERS linux/Documentation` → 0 命中 |
| T9 | `get_maintainer.pl` 按**文件**取收件人 ⇒ 多补丁系列每枚的 To/Cc 天然不同（这是 csv-graph/roles 类补丁只进部分列表的原因） | `linux/scripts/get_maintainer.pl` 存在；实际落点见 §1 归档列 project 分布 |
| T10 | `?since=` 参数按**补丁提交日期**过滤，粒度到天；跨月核对要放宽 1–2 天 | M9（10-24）在 `since=2026-10-25` 查询里**消失**，需另拉 `since=2026-10-20&until=2026-10-26` |

---

## 4. 未证 / 备份

1. **未证**：M9 的 **LKML 副本**是否在档（只核了 `linux-arm-kernel` 1/1）；`?project=lkml` 未单拉。
2. **未证**：dwc3 两条 High 是否真能触发（只读评审结论，未跑 qemu/真机；我方无 SM8750 双口取证的并发窗口）。
3. **未证**：wl2868c `vsys-supply` 是否真为必需（Conor 原话是「怀疑」；无芯片手册）。
4. **未证**：Krzysztof 11-04 两条是否已在 `patches/upstream/wl2868c-20261104-v6/` 之外的草稿里被处理（本 lane 只读，未查 `out/mail-*` 之后的草稿目录）。
5. **未核**：`linux-next`/`usb-next` 上 11-04 两批的 apply 状态（未联网 fetch 树）。
6. 本轮脚本全部在 `/tmp/laneA/`（`scan.py`、`body.py`、`sent.py`、`hdr.json`（2635 头条目）、`pw.json`、`pw9.json`、`matrix.txt`、`b1..b3.txt`）——**临时，可能被清**；仓库内只新增本文件与 `mail-triage-20261105.md`。
7. 时区一律 UTC；原信 `+0200`/`+0800`/`+0530` 已换算。

## 5. 2026-11-06 复核（增量窗：11-05 02:40Z → 11-06 10:54Z）

> 本轮只做两件事：重查**有没有新回信**、重查**patchwork 状态有没有动**。结论 = **两者都没有** ⇒ §1 的「我方欠什么」整表仍然有效，不需要新报告。

| 项 | 方法 | 结果 |
|---|---|---|
| 新回信 | IMAP `readonly=True`（EXAMINE）+ `BODY.PEEK`，`SINCE 05-Nov-2026` 扫 `INBOX`(2211 封) 与 `"Junk E-mail"`(29 封)，命中判据 = 头里出现我方 9 个系列 MID 前缀（`20261104032648/20261104032706/20261102055026/20261102060458/20261031150154/20261031150305/20261031041154/20261027051048/20261027132929`） | **0 命中** ⇒ 无新回信、无退信 |
| patchwork | `patches/?submitter=…&since=2026-10-25&per_page=200` 重拉 | **168 条不变**；最后状态变化仍停在 11-04 批（dwc3 3/3 两 High、wl2868c 5/5+3/5 changes-requested） |
| 上游基线 | `https://www.kernel.org/releases.json` | **`7.3.1`（10-30）= 当前 stable、`7.4-rc1`（11-01）= mainline**；我方日常线 `build/daily` 仍是 **`7.3.0-rc7`**（`24223e44ad`）⇒ **多了一个「rc7 → 7.3 定版 / 7.4-rc1」重基决策点**（见 `reports/progress-review-20261106.md` §4） |

⇒ **欠的动作没变**：① dwc3 两条 High（锁序 + err 路径 teardown 同步）→ v6；② wl2868c 5/5 并入 4/5、3/5 commit message 改写、driver 三处状态一致性、板 DT 是否单发。
两条都**只需主机侧**，不占设备。

DONE-UPSTREAM-STATUS-20261105
