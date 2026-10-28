# 邮箱分诊（M 系列新回复）+ UEFI issue #12 回帖 — 2026-10-28

lane L4。范围：只读邮箱/issue；写路径仅本报告、`out/mail-20261028/`、本 session 记录。
邮箱查询时刻：**2026-10-28 18:5x +0800**（IMAP `mail.ustc.edu.cn:993`，`SINCE 23-Sep-2026`，
INBOX 13895 封 / Junk 0 封 / Sent 161 封）。

工具说明：`read-mail-ustc.py --replies-only` 只认脚本里**硬编码的 3 个 OUR_IDS**（10-13 那批），
对 10-17 之后发出的系列（M3 v2/v4、M4、M9、aw86927、camss）**一律漏报**。
本轮改用 `out/mail-20261028/triage-20261028.py`（服务端 `HEADER In-Reply-To/References "mail.ustc.edu.cn"`
+ 关键词兜底，BODY.PEEK 不改 \Seen），命中写入 `out/mail-20261028/triage-20261028.json`。

---

## 1. 台账：需要我方动作的回复（按可操作性）

| # | 发件人 | 日期 (+0800) | Message-ID | 他要求什么 | 我方待做 | 映射 |
|---|---|---|---|---|---|---|
| 1 | **Hangxiang Ma**（QCOM，camss SM8750/Kaanapali 系列作者） | 10-28 18:42 | `<218d69dc-5761-4a8c-824f-7a15307f54a6@oss.qualcomm.com>` | ① 我方 v2 9 枚基于他的 SM8750 系列（`20260721-add-support-for-camss-on-sm8750-v6`），**原作者与 SoB 被丢**，要求按 `submitting-patches.rst` 保留原作者 + 自己 SoB 在下并注明改动；② 他们团队在 Kaanapali 系列合并后会 rebase 跟进 ⇒ **要求我方暂缓投递**，或把 CAMSS framework 部分拆成独立系列 | **必须回信**：确认「暂缓后续版本」；说明 v2 的来源与 SoB 处置（要么补 Author/SoB 链，要么明说以谁为基）；给出「framework 部分单拆」的取舍答复 | M4-2…M4-4（`patches/upstream/m4-camss-series-20261028-v2/`） |
| 2 | **Vladimir Zapolskiy**（camss reviewer） | 10-28 18:10 | `<8e05a28e-7881-4bf5-98c7-c5ccf4e22735@kernel.org>` | CSIPHY **必须**改用新的 MIPI CSI-2 PHY 驱动 `drivers/phy/qualcomm/phy-qcom-mipi-csi2-core.c`，参照刚发的 SM8450 CAMSS 系列 | 架构级返工评估：csiphy 从 `camss-csiphy-3ph-1-0.c` 迁到 PHY 框架（不是改表）；需先读 SM8450 系列定形状 | M4-2（CSIPHY 2.4.0） |
| 3 | **Krzysztof Kozlowski**（DT） | 10-27 19:06 | `<f76d56db-6ea8-45ef-a70e-e53cc70cf508@kernel.org>` | aw86927 binding（AW86937 变体）**Acked-by** | 记入补丁台账；v3 需带上 Acked-by | aw86927 系列（`patches/upstream/aw86927-20261027-v2/`） |
| 4 | **Mark Brown**（regulator） | 10-28 01:58 | `<179312390429.199157.12016700546762955000.b4-review@b4>` | wl2868c binding：① Subject 要符合子系统风格；② MAINTAINERS **要保持文件内排序**；③ 「这是 driver 段但只有 binding」⇒ 命名过早；④ 为何挂 `linux-media` 列表 | 改 Subject 前缀 + 调整 MAINTAINERS 段名/位置；回一句列表选择理由（相机 PMIC） | M4-1（wl2868c） |
| 5 | **Krzysztof Kozlowski** | 10-28 02:04 | `<c8e6c0e7-397c-4692-a478-d9778b312886@kernel.org>` | wl2868c：**「Looks like broken patch. Please use git or b4」**（补丁统计段重复/格式坏）+ 质问「谁用它，为什么需要这个 binding」 | 必须重生成补丁（`git format-patch`/`b4`）并解释消费者（本机 camss 供电），否则 binding 无消费者会被拒 | M4-1 |
| 6 | **Taniya Das**（dispcc/clk） | 10-22 22:52 | `<22a87c51-4f8c-49c0-a13a-c11767f10e85@oss.qualcomm.com>` | `dispcc-sm8750` RFC：**复位不该由 clock driver 驱动**，应由显示 SW 驱动；且整块 dispcc 复位会闪屏 | 方向性否决 ⇒ RFC 改落点（移到 `msm`/显示驱动侧或放弃该方案）；需回信确认接受并说明后续形状 | Q24/Q28 显示线（`patches/upstream/q28-dispcc-2026-10-22`） |
| 7 | **Konrad Dybcio** | 10-20 15:37 | `<101257b5-7e43-4cc1-ba17-1507dad27b52@oss.qualcomm.com>` | 回归 v3：给了一个**可直接试的 diff**（去掉 `rpmhpd` 的 `.sync_state`，把电源轨钉在最高档）作为判别实验 | 该实验与本地 U3 判定相关（`rpmhpd` `presync_floor` 已判死代码）；需上机跑一次并回结果，或说明为何不跑 | Q24 回归线 |
| 8 | **Konrad Dybcio** | 10-22 16:16 / 10-23 21:55 / 10-23 21:57 | `<52fc4222…>`, `<625f7af0…>`, `<84483ae1…>` | battmgr：① 追问 downstream 源码/属性重映射/power_now 是否也被禁；② 「厂商有 GPL 义务，别打客服」；③ **给出 `github.com/lenovo-basements/android_kernel_lenovo_sm8750`** 作为源码位置 | 核对该 repo 是否含 QBG/battery 路径（此前结论「drop 不含该子系统」需复核）；有则回信更正 | M2-A2 |
| 9 | **Fenglin Wu**（QCOM，battmgr） | 10-19 10:03 | `<c030eac4-1574-40d3-938d-ce11a505271a@oss.qualcomm.com>` | 「SM8750 固件默认支持 power_on，**不同 OEM 可能定制去掉**」⇒ 支持我方「OEM 特有」判断 | 可作为 A2 的第三方引证写进 commit/回信 | M2-A2 |
| 10 | **Marc Zyngier** | 10-26 21:53 | `<86y0bky3el.wl-maz@kernel.org>` | 我方撤回 M9 后的收尾确认（「Thanks.」+ 明确 kexec 链要由 loader 预置并保留） | 已按此改口径；**无需再回** | M9-收口（已完成） |
| 11 | **Greg KH** | 10-19 21:24 | `<2026101912-squealing-syndrome-8f6b@gregkh>` | RFC v3 线程内：说明 RFC 与 v2 的线程关系（我方 v4 已发，此项已消解） | 归档；v4 已投 | M3-1 |
| 12 | **Krzysztof Kozlowski** | 10-23 15:49 | `<20261023-conscious-newt-of-experience-2dddf2@quoll>` | RFC v3 binding：**因是 RFC 且挂在 v2 线程下，已从 DT patchwork 移除**（不视为待评审） | 已由 v4 正式投递覆盖 | M3-1 v4 |
| 13 | **Joonhoe Kim** | 10-20 21:24 | `<20261020132424.983-1-26rote@gmail.com>` | 回答我方 DSI AHB clock 问题：runtime-callback 变体下 dispcc 能 suspend、30 次 DPMS 循环面板正常；给出 DP 侧引用计数实测 | 可作 Q24 显示功耗线的引证；无强制动作 | Q24 |
| 14 | **Pengyu Luo** | 10-26 00:56 | `<CAH2e8h4wFH5Q_biepZzQuerydvmwbUOsEMRRzs4y-c-0WbjYrw@mail.gmail.com>` | ① **DT 归并放行**：「squash 后按你们的方式整份发」；② 无公开 downstream 源码（本地 6.19.6 树半年未更新） | DT 系列可按「整份 follow-up」推进；不再等他的 v3 | M3-2 / 板 DTS |
| 15 | **Kieran Bingham / Barnabás Pőcze** | 10-17 23:58 / 10-19 19:24 | `<179225268473…>`, `<75e177a5…>` | libcamera `libipa` 两枚（GC08A8/S5KJNS helper、AGC target）review 意见 | 属 libcamera 上游线，非内核；列入待办不阻塞 M 系列 | 相机用户态 |
| 16 | **Patchwork / Media CI** | 10-28 15:28 | `<6ae1a415.c3449938.c1faf.af00@mx.google.com>` | camss v1 9 枚：3 条 `checkpatch` WARNING（新文件未更新 MAINTAINERS）；要求修好发新版并把旧系列标 Superseded | v2 已发；**需在 patchwork 把 v1 标 Superseded** | M4-2…M4-4 |

### 1.1 sashiko-bot 自动评审（需逐条处置，非人）

| 对象 | 时间 | Message-ID | finding |
|---|---|---|---|
| camss v2 #2 csiphy | 10-28 17:37 | `<sashiko-outbox-187685@kernel.org>` | [Medium] `lane_regs_sm8750[]` 的 4 条 SKEW_CAL 仍是 `0x54`，与 commit message 说的「用厂商值 `0x00`」矛盾；且 `CSIPHY_SKEW_CAL` 目前 `continue` 不写硬件 ⇒ 现在改是 no-op；另指出 commit message 里「四个数据 lane 0x400 步进 + 时钟 lane 0xc00」与表的实际布局不符 |
| camss v2 #4 csid-980 | 10-28 17:52 | `<sashiko-outbox-187698@kernel.org>` | [High] `reg_update`/`aup_update` 里残留 AUP/RUP 位；[Medium] 三字段数据竞争 |
| camss v2 #8 vfe-gen4 | 10-28 17:53 | `<sashiko-outbox-187701@kernel.org>` | [Medium] `vfe_reg_update()` 与 `csid_isr()` 对 csid `reg_update` 竞争 |
| aw86927 #4 | 10-27 21:37 | `<sashiko-outbox-186657@kernel.org>` | [Medium] `aw86927_play_mode()` 里 `AW86938_PLAYCFG1_BST_MODE_MASK` 只有 1 bit（应两位域） |
| aw86927 #5 | 10-27 21:55 | `<sashiko-outbox-186676@kernel.org>` | [Medium] `aw86927_reset()` 缺 `devm_add_action_or_reset()` |
| GT9764 binding | 10-27 13:19 | `<sashiko-outbox-186108@kernel.org>` | [Medium] binding 里直接写裸寄存器值 + required delay；[Low] MAINTAINERS 段未按字母序；[Low] 属性顺序不符 coding style |

> 注：camss v2 的 SKEW_CAL finding 与本地 `reports/m4-skewcal-ab-20261027.md` 的 A/B 结论**方向一致**（应提交厂商值 0x00），
> 但 v2 补丁里 4 条 data 仍是 `0x54`、且由后续 `csid: add the 980 generation` 那枚改成 `0x00` —— 即**改动放错提交**，需前移。

---

## 2. 无需动作 / 已消解

- `Marc Zyngier` 10-26（#10）：撤回已闭环。
- `Krzysztof` 10-23（#12）：RFC v3 被移出 patchwork，v4 已正式投。
- `Greg KH` 10-19（#11）：线程关系问题，v4 已开新线程。
- `kernel test robot` 10-15 的 `mux_role` 告警：v4 已修（无新回复）。
- 与本项目无关的列表洪水（camss SM8250/SM8450/Waipio 系列、UFS NXP、Exynos8855、IPA 等）：只在与我们补丁同文件时读。

## 3. 待用户批准发送清单（本轮**不自动发送**）

1. 回 **Hangxiang Ma**（#1）：暂缓 + SoB/Author 处置 + framework 单拆取舍。
2. 回 **Vladimir Zapolskiy**（#2）：CSIPHY 迁 PHY 框架的接受与时间表。
3. 回 **Krzysztof/Mark Brown**（#4/#5）：wl2868c 重发计划（需先重生成补丁）。
4. 回 **Taniya Das**（#6）：接受「复位不由 clk driver 驱动」的落点调整。
5. 回 **Konrad**（#7）：`rpmhpd.sync_state` 判别实验的结果（需上机）。
6. 回 **Konrad**（#8）：`lenovo-basements/android_kernel_lenovo_sm8750` 是否含 QBG 路径的核对结果。
7. patchwork：把 camss v1 系列标 **Superseded**（非邮件，需 patchwork 账号）。
