# 上游邮件分诊（2026-10-26）—— 差量轮

> 角色：worker（**只读**）。**未发任何邮件、未改 `.gitconfig`/凭据/keyring、未碰设备、未 commit**。
> 通道：`~/.local/bin/read-mail-ustc.py`（IMAP `mail.ustc.edu.cn:993`，口令由 `get_pw()` 从 keyring 取，全程未打印）。
> 窗口：**2026-10-23 00:00Z → 2026-10-26 05:36Z（= 3.23 天）**。
> 前序口径（本轮只做差量 + 确认/推翻）：`reports/mail-triage-20261023.md`（窗口到 10-23 05:2xZ）、
> `reports/upstream-mail-sm8750-refs-20261023.md`（窗口到 10-23 ~21:00 CST）。方法/坑见 `.pi/skills/upstream-mail-ustc/SKILL.md`。

---

## 0. 结论先行（数字）

- 窗口流量（按窗口切、`mid` 去重）：**INBOX 原始 1 075 / 去重 972；Junk 原始 18 / 去重 18；Sent 原始 8 / 去重 8**
  ⇒ 原始合计 **1 101**，同夹去重合计 **998**，跨夹去重（我方发出的副本也回灌 INBOX）**991**。
- **新增项目相关外部来信 = 8 封（去重 mid）**：Konrad Dybcio ×4（同一线程 4 个不同 mid）、Krzysztof Kozlowski ×1、
  Marc Zyngier ×1、Pengyu Luo ×1、Ulf Hansson **离职自动回复** ×1。另有 1 封 GitHub 安全通知 + 1 封教务通知（与项目无关）。
- **需我方行动 = 5 条，其中「阻塞本轮迁移」= 0 条**（全部属上游线程，不影响 `linux17` 落点/S6/S7）。
- **一个必须写清的更正**：上一份 `upstream-mail-sm8750-refs-20261023.md` 断言「**M3-1 USB v3 无新回复**」——
  **已被推翻**：Krzysztof Kozlowski 于 **2026-10-23T07:49:43Z** 回过该线程（我们的 refs 报告在 21:00 CST 截稿，漏了它）。
- **最大增量不是邮件本身**：Pengyu Luo 10-26 直接给了 DT 归口与 DPU 变量的**决定性答案**（§2.4）。

---

## 1. 流量与方法（可复现）

```bash
# 官方工具（只读；--replies-only 不可信，见 §5 坑）
timeout 180 python3 ~/.local/bin/read-mail-ustc.py --days 4 --limit 200

# 本轮实际用的窗口扫描（复用官方工具的 HOST/USER/get_pw，脚本在 /tmp，不入库）
timeout 600 python3 /tmp/scan4.py     # IMAP SEARCH SINCE 22-Oct-2026 → 三夹全量头 → /tmp/scan4.jsonl
                                      # 用 email.utils.parsedate_to_datetime() 按 >= 2026-10-23T00:00Z 切窗 + mid 去重
```

| 项 | 值 | 证据 |
|---|---|---|
| `SINCE 22-Oct-2026` 全量（含窗外） | INBOX **1 969** / Junk **68** / Sent **9** = 2 046 | `/tmp/scan4.py` 输出 `raw/window: {...}` |
| 窗口内原始 | INBOX **1 075** / Junk **18** / Sent **8** = **1 101** | 同上 |
| 窗口内去重（同夹） | INBOX **972** / Junk **18** / Sent **8** = **998** | 同上 |
| 跨夹去重 | **991** | 我方信件副本经 vger 多路投递回灌 INBOX |
| 窗口天数 | **3.23 天**（10-23T00:00Z → 10-26T05:36Z） | `date -u` |
| 日均 | ≈ **341 封/天**（1 101/3.23） | 比 10-23 轮的 ~1 160/天低，因 devicetree 已退订（10-21 生效）后本窗无残留 |

**List-Id 分布（窗口内，去重前）**：`linux-arm-msm` **488**、`linux-usb` **192**、`linux-pm` **120**、`linux-clk` **120**、
`linux-input` **89**、`libcamera-devel` **46**（全在 Junk 之外或 Junk 内）、`linux-remoteproc` **27**、无 List-Id **19**。

**我方窗口内发出 = 8 封**（Sent Items 逐条）：

| Sent uid | 时间 (UTC) | 主题 | Message-ID |
|---|---|---|---|
| 143 | 2026-10-23T07:52:50Z | Re: `[RFC PATCH] clk: qcom: dispcc-sm8750: reset the MDSS blocks…`（回 Taniya） | `<179274197058.1374475.15035361812241082707@mail.ustc.edu.cn>` |
| 144 | 2026-10-23T07:52:51Z | Re: `[PATCH] power: supply: qcom_battmgr: do not report power_now on SM8750` | `<179274197125.1374502.18211548118625978753@…>` |
| 145 | 2026-10-23T11:05:48Z | 同 battmgr（sync_state/Retention corner 解释） | `<179275354818.2172689.9851715727007912571@…>` |
| 146 | 2026-10-23T13:49:20Z | 同 battmgr（无厂商通道逐条理由） | `<179276336012.97124.9436748752781883311@…>` |
| 147 | 2026-10-23T13:49:39Z | Re: `[REPORT] SM8750 bonded dual-DSI + NT36536…`（回 Pengyu） | `<179276337975.97444.18043862696501391672@…>` |
| 148 | 2026-10-23T13:50:23Z | 同 battmgr（更正：有 GPL drop，但不含 power_supply） | `<179276342356.98176.10645303509497652146@…>` |
| 149 | 2026-10-24T07:58:56Z | `[PATCH] irqchip/gic-v3-its: Claim LPI tables inherited across kexec on DT`（新投） | `<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 150 | 2026-10-26T02:13:05Z | 夏卿桓PB24111701图形学作业4（**与项目无关**） | `<1df62120.1710a.1a175fb9ab1.Coremail.…>` |

> 注（全部折算 UTC）：我方 146 = 13:49:20Z、148 = 13:50:23Z；Konrad 四封 = **08:13:33Z / 11:07:21Z / 13:55:55Z / 13:57:29Z**
> ⇒ **battmgr 线程当前最后一条 = Konrad 13:57:29Z（GitHub 链接）⇒ 现在轮到我们**（§3 A1/A2）。

---

## 2. 在途线程状态表

### 2.1 Q28 v2（dispcc BCR 复位归属 / Taniya Das / sashiko / Pengyu / Dmitry）

| 对象 | 最后一条 | 日期 (UTC) | Message-ID | 本轮是否有新回复 | 需我方动作 |
|---|---|---|---|---|---|
| 我方 → Taniya（接受搬迁到 `msm_mdss_reset()`） | 我方 | 2026-10-23T07:52:50Z | `<179274197058.1374475.15035361812241082707@mail.ustc.edu.cn>` | — | — |
| **Taniya Das** | 10-22 17:23Z 反对 | 2026-10-22T17:23:01Z（**窗外**） | `<22a87c51-4f8c-49c0-a13a-c11767f10e85@oss.qualcomm.com>` | **0（窗口内 `from:taniya` 命中 0 封）** | 等；不催（一次正反判断） |
| **sashiko**（Q28 4 条） | 10-22 14:26Z | 2026-10-22T14:26:23Z（**窗外**） | `<sashiko-outbox-181631@kernel.org>` | **0**（窗口内 86 封 sashiko 全部是别人线程） | 无（随 A1 搬迁自然消解） |
| **Pengyu Luo** | **新回复** | **2026-10-25T16:56:37Z**（原文 `+0800` = 10-26 00:56 本地） | `<CAH2e8h4wFH5Q_biepZzQuerydvmwbUOsEMRRzs4y-c-0WbjYrw@mail.gmail.com>` | **+1（新）** | **是**（§3 A4/A5：DT 归口 + `dsiclk_sel=0` 确认） |
| **Dmitry Baryshkov** | 窗口内 74 个不同 mid 全是别人线程（IRQ_HPD v7、UFS、glymur…） | — | — | **对我们的 Q28/DT 线程 0** | 无 |

**Pengyu 三个实质点（原文要点）**：
1. `sm8750-lenovo-elden.dts`：**「You can squash them and send the whole thing your way, since I have no plans to update it for next months.」**
   ⇒ DT 归口**正式交给我们**（他 v2 = 1 170 行，我们 3 178 行）。
2. 下游源码：**「No public repo, my local tree with all features hasn't updated for about half a year (…6.19.6 tree…)」**
   ⇒ Konrad 问的「有下游源码吗」在本机型上**再次得到第三方确认：公开层面没有**。
3. **DPU 变量定案**：他当时的 hack 是 **`dsiclk_sel = 0`**（引 `0f5c8f03d990`），并说「0 is the right value」；
   我们已回报本机 `DSI_7nm_PHY_CMN_CLK_CFG1` 就是 `SEL=0` 且 pclk 算术自洽 ⇒ **该变量在本机已满足，无需再试**。
   另：他**撤回**了当年给 Konrad 的 SMMU 说法（「UEFI 在 SMMU 起来后还在写 splash region」），称后来自己解决了。
   ⚠ 这正是 sashiko/Taniya 那条「复位会抽掉扫描」的同源现象 ⇒ **与 B2 的 simpledrm 冲突直接相关**。

### 2.2 battmgr / Q24（Konrad Dybcio）

| # | 日期 (UTC) | Message-ID | 内容要点 | 是否新 | 需我方动作 |
|---|---|---|---|---|---|
| 1 | 2026-10-23T08:13:33Z | `<63cf18bc-5c89-4a55-aa15-2550dc47c155@oss.qualcomm.com>` | 「**Did you try reaching out to the vendor?**」 | 新（已回过） | 已回（144） |
| 2 | 2026-10-23T11:07:21Z | `<2cef48a1-7efe-4e02-9f8e-7da97cf8eaa8@oss.qualcomm.com>` | 「**Please ONLY do development on linux-next/master going forward.**」 | 新 | ✅ **需行动（A1）** |
| 3 | 2026-10-23T13:55:55Z | `<625f7af0-5977-41e3-a76d-fde8f998ed97@oss.qualcomm.com>` | 厂商**有 GPL2 义务**，customer support 不是正确渠道 | 新 | 已回（146 说明理由） |
| 4 | 2026-10-23T13:57:29Z | `<84483ae1-1fbb-4219-a829-5867feb8bb17@oss.qualcomm.com>` | 「see the drivers are here? `https://github.com/lenovo-basements/android_kernel_lenovo_sm8750`」 | 新 | ✅ **需行动（A2）** |

### 2.3 M3-1 v3 / USB 双连接器（linux-usb / linux-devicetree）

| 对象 | 日期 (UTC) | Message-ID | 内容 | 是否新 | 需我方动作 |
|---|---|---|---|---|---|
| 我方 v3 0/2、1/2 | 2026-10-19T13:18:47/54Z | `<20261019131848.344689-1/-2-xiaqinghuan@…>` | — | — | — |
| **Krzysztof Kozlowski** | **2026-10-23T07:49:43Z** | `<20261023-conscious-newt-of-experience-2dddf2@quoll>` | 「v2 had several Sashiko comments, this is called RFC and threaded there… **I assume RFC, so I drop this patch from DT patchwork**」 | **是（新，之前漏记）** | ✅ **需行动（A3）** |
| Greg KH / lkp / sashiko | — | — | 窗口内对 M3-1 **0 封** | — | — |

### 2.4 sm8750-lenovo-elden DT（上游同名 DTS 进展）

- **无新的上游提交**：窗口内 `TEXT "sm8750-lenovo-elden"` 只命中 **3 个 uid**（我方 10-23 的 REPORT 回复 2 份副本 + Pengyu 10-26 回复 1 份），
  **没有任何 v3 补丁串**（`Introduce Lenovo Legion Y700 Gen4` 在窗口内 0 命中）。
- **状态因此改变为「归口已定、无上游动作」**：Pengyu 明确「squash 成一整份发给我们这条路」，且他**下个月不打算更新** ⇒
  责任与节奏**完全转到我们**（与 `TASKS/README.md` §5 Q28 里「必须以其 v2 为基做 delta」的口径一致，但**升级为「由我们发布」**）。
- 旁证（同显示块的上游动向）：`[PATCH v4 0/3] drm/msm/dpu: Add INT2 GDSC power domain support for Kaanapali`（2026-10-23T08:13:10Z，Yongxing Mou，
  **Konrad 当场 `Reviewed-by`**，`<70d5ef70-00c7-4265-b2aa-3a784d4f0d1a@oss.qualcomm.com>`）——**同一显示块**上「CORE + INT2 两个 GDSC 都要挂到 DPU」
  已成上游共识；这条与我们把 `CORE_INT2` BCR 一起复位的做法**同向**，可作 Q28 回复的第三方支撑材料（不是新变量）。

---

## 3. 需我方行动清单（按「本轮迁移是否阻塞」分档）

### 阻塞本轮迁移（`linux17` 落点 / S6 unit / S7 上机）：**0 条**

无。8 封外部来信全部落在内核上游线程，与 Debian 落点、boot 镜像、systemd 单元、传感器物料无关。

### 不阻塞（但会漂的）——5 条

| # | 事项 | 对方在等什么 | 我方最小动作 | 成本 |
|---|---|---|---|---|
| **A1** | **Konrad：只许在 `linux-next/master` 上开发** | 无（是政策要求） | 后续投递的基线从 `build/m1-73`（7.3-rc7 血统）**改为 linux-next/master 重放**；先确认「Q28 三处改动 + 0155 能否在 next 上 apply」。这条影响 M9/后续所有补丁，**不影响本机日常内核** | 主机侧 1–2 h |
| **A2** | **Konrad 给的仓库 `github.com/lenovo-basements/android_kernel_lenovo_sm8750`** | 隐含「你自己去看」 | 主机侧 `gh api`/`git ls-remote` 只读核对：① 是否 == 我们 `stock-src/` 的 GPL drop（同 commit？）；② **是否含 `drivers/power/supply`**（我们声称「不含」，若含则该论据作废，需当场更正） | 0.5 h，零设备 |
| **A3** | **Krzysztof：RFC v3 被从 DT patchwork 摘掉** | 他要一个「这到底是 RFC 还是正式投稿」的明确态度 | 二选一后重投 v4：① 走正式（`[PATCH v4]`，正文写清 v2→v3 对 sashiko 的逐条处置，不再"threaded 在 v2"）；② 明确保留 RFC 并**不期待 DT maintainer 评审**。**建议 ①**（M3-1 是实质功能，不是 RFC 阶段） | 主机侧 1 h（改头 + 变更说明） |
| **A4** | **Marc Zyngier 否掉 M9（ITS/LPI kexec 补丁）方案** | 无（已明确拒绝） | 原文三点：①「**nothing works at all**，与 command queue 无关」；②**「EFI 和 DT 不互斥」**（他 90% 机器 DT 且 EFI 启动）；③**「Either it works always, or it doesn't work at all」**，正解 = **用 EFI、或由 bootloader 配好 LPI 表并在 DT 里 memreserve**。⇒ 我们的 memblock-claim 路线**不可挽救**：要么撤回 M9，要么改成「引导器预置 + DT memreserve」并等 UEFI（**与 B2 的 UEFI 复启条件直接耦合**） | 回信 0.5 h；方案重做 = 周级，**先不做** |
| **A5** | **Pengyu：DT squash 后由我们发布 + `dsiclk_sel=0` 已被证实** | 他已交接，不等回信 | ① 在 Q28 报告里把 `dsiclk_sel` 变量**关闭**（写「已确认 == 本机现状」）；② DT 发布计划立项（squash 3178 行 → 按 maintainer 拆成 display/remoteproc/misc 三串，Cc Pengyu） | ① 10 min；② 需单独立项 |

### 观察项（不需行动）
- **Ulf Hansson 自动回复**（2026-10-23T11:05:54Z，`<CAPDyKFrJspp4RNMgnV5mN6fhP8b1afVkJBm02f7c6KSjbYUTZw@mail.gmail.com>`）：
  「no longer works for Linaro」⇒ battmgr 的 To/Cc 里**有一个已失效维护者地址**，重投时顺手核对（不发信）。
- GitHub OAuth 通知（10-25）与教务停课通知（10-25）：与项目无关。

---

## 4. 关键词交叉检索（命中 / 未命中都记，含实际命令）

服务端全文检索（`TEXT` 走整封，比自建头表扫描更全）：

```bash
# 实际执行（/tmp/kw4.py）
python3 - <<'PY'   # 逐关键词: M.search(None, '(SINCE "22-Oct-2026" TEXT "<kw>")')
# 夹 = INBOX, "Junk E-mail"
PY
```

| 关键词 | INBOX 命中 | Junk 命中 | 判定 |
|---|---|---|---|
| `hexagonrpcd` | **0** | 0 | **未命中** |
| `droid-juicer` | **0** | 0 | **未命中**（`droid_juicer` 亦 0） |
| `Mobian` | **0** | 0 | **未命中** |
| `Debian` | 22 | 2 | **0 条与本项目相关**：全部是 RK3572/Forlinx 补丁正文、ath12k patch 正文、syzbot 报告里的 incidental 词（逐条核过 uid：10565/10567/10625/10810/10816–10818/10845/10858/11055/11150/11230/11238/11426/11454/11457/11662/11837/12268/12339/12409/12493） |
| `waydroid` | **0** | 0 | **未命中** |
| `droidloom` | **0** | 0 | **未命中** |
| `kexec` | 6 | 0 | 3 条是我方 M9 补丁 + Marc 回复（uid 12144/12195），另 3 条（10610/10850/10852/10853 中的 kexec 提及）为他人补丁正文提及，**无第三方对我们 kexec 工作的新意见**（Marc 那条已计入 A4） |
| `UFSDxe` | **0** | 0 | **未命中**（含 `mu_wide_platforms` 亦 **0**）⇒ 上游 issue #12 **窗口内无任何新动态**（与 `reports/uefi-gunyah-reassess-20261024.md` §1.1 一致） |
| `mu_wide_platforms` | **0** | 0 | 同上 |
| `sm8750-lenovo-elden` | 3 | 0 | 3 条全是我方/Pengyu 的本线程（见 §2.4），**无第三方上游动作** |

**替代检索命令（本轮未执行，只给命令；邮件工具不可用时应走这条）**：

```bash
# 1) 按发件人查我们全部投递
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=f:xiaqinghuan%40mail.ustc.edu.cn"
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-pm/?q=f:xiaqinghuan%40mail.ustc.edu.cn"
# 2) 按主题（注意 inbox 名：devicetree → /linux-devicetree/）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-devicetree/?q=s%3A%22describe+two+connectors%22"
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-clk/?q=s%3A%22reset+the+MDSS+blocks%22"
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/lkml/?q=s%3A%22Claim+LPI+tables+inherited%22"
# 3) 按 Message-ID 直取 raw（最可靠，不依赖搜索索引）
curl -s --noproxy '*' "https://lore.kernel.org/all/20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn/raw"
```

---

## 5. 本轮踩到的工具坑（写入，避免下次重踩）

1. **`--replies-only` 仍不可用**：`read-mail-ustc.py:21-23` 的 `OUR_IDS` 只有 3 个 10-13 前后的旧 mid
   ⇒ 本窗口 0 命中（实际有 6 封回复）。判据永远是「**Sent Items 动态取 mid 再求交**」（本轮 `/tmp/scan4.py` 做法）。
2. **`--grep` 只匹配 Subject+From**，会漏正文；关键词交叉检索必须用 IMAP `SEARCH TEXT`（本轮 `/tmp/kw4.py`）。
3. **同一个 mid 会进 INBOX 2–3 份**（vger 多路投递 + 我方 Sent 副本回灌）⇒ 报数必须先按 mid 去重，并注明
   「同夹去重」与「跨夹去重」两个口径（本轮 998 vs 991）。
4. **`email.header.decode_header()` 对列表信偶尔返回 `unknown-8bit`** ⇒ 上一轮记录的 `LookupError` 崩溃仍在；
   扫描脚本里必须 try/except 回退 `utf-8`（本轮的 `dec()` 已包）。
5. **时间戳时区混用会误判先后**：Konrad 的 `+0200`、Pengyu 的 `+0800`、lore 的 `Z` 必须统一折算 UTC 再排序
   （本轮 §2.2 的「谁最后说话」就是靠折算出来的）。

---

## 6. 边界声明

- 未发送任何邮件（含回复/转发/订阅/退订/DSN 重发）；`send-mail-ustc.py` **未调用**。
- 未改 `.gitconfig`、未触碰 keyring/凭据（口令仅由 `get_pw()` 内部使用，未打印、未落盘）。
- **未碰设备**（`fastboot`/`adb`/`ssh` 全部未执行；设备按任务前置为不可达）。
- 未 commit、未 `git add`；临时脚本与中间数据全在 `/tmp/`（`scan4.py`/`scan4.jsonl`/`kw4.py`/`kw5.py`/`body4.py`）。
- 未执行任何 lore 请求（§4 的替代命令只写不跑）。
