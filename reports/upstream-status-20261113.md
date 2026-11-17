# 上游化当前一页（2026-11-13）

> 取代 `archive/topics/upstream/upstream-status-20261105.md`（11-05 快照，留作沿革）。
> 只写「逐系列状态 / 我方欠什么 / 复启条件」；每条论断的证据指针在行内。
> 外部动向快照 = `reports/upstream-watch-20261113.md`（patchwork REST 取证 29 条）。

## 1. 本窗口已投（2026-11-11 → 11-14）

| 系列 | 版本 | 封数 | 结果 | 证据 |
|---|---|---|---|---|
| `regulator: willsemi,wl2868c` | **v11** | 3 | 3×250，lore 归档逐字节通过；**Rob Herring 2026-11-16 15:10 UTC 回帖**：v11 1/2 **漏带**他此前给的 `Reviewed-by`（「It's your responsibility to add tags when sending new versions」并重给 tag）⇒ 流程性指摘、非反对 | `patches/upstream/wl2868c-v11-20261113/`（1/2 trailer 实测只有 Signed-off-by）；回 Mark 的 LDOx_SEQ 问题（datasheet Rev1.4 p.35 + 板上读数 `0x0a..0x0d=00`）；回信取证 `reports/upstream-replies-20261117.md` §1.1 |
| `drm/msm/mdss` 块复位 | **v4 → v5** | 4 + 4 | v4 4×250（11-13）；**v5 4×250（2026-11-14）** | v4 = `patches/upstream/m8-mdss-v4-20261113/`（只重写 3/3 message，带 Abel+Dmitry R-b）；**v5 = `patches/upstream/m8-mdss-v5-20261114/`**（答 sashiko 的「0xa000 是未 attach 的独立域」Medium：1/3、2/3 未变，3/3 diff 逐字节相同、只收窄 message，三个 R-b 含 Konrad；全账 `reports/mail-send-20261114-mdss-v5.md`） |
| `drm/msm/dsi/phy` PLL_SYSTEM_MUXES | v1 → **v2 已投（2026-11-16 22:50 / 23:03，两发 `250`）** | 1 | v1 = **2026-10-19** 投出（MID `20261019130041.305805-1-…`）；Dmitry 2026-11-11 回一句「注释该进 commit message」⇒ v2 = `patches/upstream/dsi-phy-muxes-v2-20261116/`（对 **7.4-rc3 `aebb727447`** `git am` rc=0、`checkpatch --strict` **0 error**、代码与在机 vk192 第 1155 行逐字相同）；v2 另把 `Fixes:` 从 `44784327815b`（且 v1 把它标题写错）改指 `cb55f39bf7b1`。**投递实账**：22:50 那封前缀漏 `v2`（`[PATCH]`），23:03 重发 `[PATCH v2]` 并在正文自述；MID `20261116150334.78710-1-…` 在 `/linux-arm-msm/`、`/linux-kernel/`、`/dri-devel/` **三处均已归档**，`diff --git` 起正文与本地件逐字节相同（624 B = 624 B） |
| `arm64: dts: sm8750 ADSP fastrpc non-secure` | v3 | 1 | 11-11 已投 | 等 Konrad 拉的四位定性；`accel/qda` v4 与 `nsessions` 废弃在动 |
| `pstore/ram` 拒绝与 initrd 重叠的 zone | v1 | 2 | **2 枚 + cover 全部 250（2026-11-16 12:00:49）**；lore `/lkml/`、`/linux-arm-msm/` 命中 0/2（归档 04:01:14Z） | 备料与门禁 = `patches/upstream/pstore-ram-initrd-overlap-20261116/`（apply-check 对 `gh/master` 2/2、checkpatch 0 error、构建 0E/0W、QEMU A/B、**真机 UEFI/GRUB 守卫生效**）；账 `logs/40-sent.txt`；正文 `reports/pstore-ram-initrd-guard-20261116.md` |
| UEFI `mu_wide_platforms#12` | — | 1 评论 | 11-13 闭环已发（comment 6847932534） | UFS 枚举通、两形态都通、flashed 真阻塞 = `dtbo_a` |

## 2. 逐系列状态与「我方欠什么」

| 系列 | 状态 | 我方欠 |
|---|---|---|
| **wl2868c**（M4） | v11 等 Mark 复审；binding 侧 Rob 已 R-b，**但 v11 实投丢了该 tag**（Rob 11-16 回帖重给，见 §1） | ① **v12 备料动作**：在 1/2 trailer 补 `Reviewed-by: Rob Herring (Arm) <robh@kernel.org>`（只补 tag，diff 不变）——仍按系列等放行；② 若被要求「非零 SEQ 时隐藏 ops」的替代方案，需给出为何不选（cover 已答）；否则等 |
| **mdss**（M8） | **v5 已发（11-14）**：sashiko 的「0xa000 是 dispcc 单独描述的域、mdss 没 attach」质疑成立 ⇒ 保留 3/3、只收窄 message（不再称 interrupt controller / same block）+ 声明两条测量边界（15/15 是三枚形状、0xa000 未做单变量）；3 R-b 全保留 | 等回复；若被判不可接受则发 v6 删 3/3（并发回 1/3 应有的 Rob Acked-by）。**仍未证**：两枚形状的上机验证、0xa000 单变量（`reports/mdss-int2-evidence-20261113.md` §2.3） |
| **dsi/phy** | **v2 已投（11-16 22:50/23:03，两发 250；错前缀一封已由第二封自述）**，三列表归档已核 | 等 Dmitry 回 v2 |
| **haptics aw86937** | v1；bindings 有 Krzysztof Acked-by；同串其余只收 bot 意见 | **v2 顺手采纳** `GENMASK(6,5)` 与 `devm_add_action_or_reset` 两点 |
| **counter/dispcc reset RFC** | 两轮追问无维护者回信 | 按自己承诺：v2 挪到 display 侧、`reset_control_*`、补 simple-framebuffer 在场对照；否则撤 |
| **相机 camss** | **改接 Qualcomm v6**（7 补丁，2026-07-21）；自建 9 补丁串停止后续版本；**2026-11-15 我方 CSIPHY 2.4.0 RFC 已收到 Bryan 回信**（11-15 17:44 UTC）：先对齐 on-list 的 8750/Kaanapali 工作（Hangxiang **v25** 15 枚、Qualcomm **v7** 23 枚，均未合），并直言「I'm finding the LLM output pretty difficult to understand」 | 拿 7.4-rc2+ 树比对 `csiphy_res_kaanapali` 与本机 vendor 2.4.0 表（**2026-11-17 已对完**：delta 所涉 4 文件 blob 在 `9d66f26fef` 与 master tip `666539eecdf4` 逐字相同 ⇒ apply 结论沿用 rc=0，见 `reports/misc-20261117.md`）；SOF 等 Bryan 的 `V4L2_EVENT_FRAME_SYNC`；板级 dts 等 v6 合入后 rebase。**形状争点已消解**：per-SoC lane 表正是 v25 `[03/15]` 的做法 ⇒ delta 该基于 on-list 分支重排并补一次上机出流；**给 phy 侧的信只留最小事实、去 AI 味**。详见 `reports/camss-v6-rebase-plan-20261113.md`、`reports/upstream-replies-20261117.md` §3.1 |
| **dwc3 双 connector** | Rob 11-10 结构性反对（ports 留给独立数据流、endpoint 留给 mux 后数据流；删 `port@2`） | 方案先行：binding + DTS + driver 三件同时改，工作量最大，未排期 |
| **ath12k WCN7861 / hci_qca** | 上游 0 命中（只有 WCN7850） | 无敌对信息，维持自维护 |
| **gie-v3-its 认领继承 LPI 表**（M9） | 已投并归档 | 无 |
| **fastrpc** | 等 Konrad 线程定性；**`qcom,nsessions` 已于 2026-11-16 被上游合入废弃**（Srinivas「Applied」3 枚，`641dd7dd0f68` = dt-bindings deprecate）；`accel/qda` 仍 v4（11-11 之后无新活动、未合） | 准备「为什么不能简单写 non-secure」的寄存器/固件证据；**板级 DTS 若仍写 `qcom,nsessions`，现在属已废弃属性 ⇒ 按驱动侧策略删除/改写** |
| **Gunyah** | 主线仍 0 进展（停在 2023-03 v11） | 拓展项维持「无上游可依赖」 |

## 2b. 2026-11-16 复查与新增欠账

- IMAP `read-mail-ustc.py --days 4 --replies-only` = **INBOX / Junk / Sent Items 各 0 封**
  ⇒ `pstore/ram`（11-16 12:00）、**M8 mdss v5**（11-13）、**M6 bonded**（10-31）、**Q28 REPORT v2**（10-15）
  **全部零回复**；四条线程维持「等维护者」。取证 = `reports/q28-dossier-B-mail-external.md` §①②。
- **我方欠账（2026-11-17 早复核，两件 → 一件）**：
  1. ~~**dsi/phy v2**~~ **已投 2026-11-16 22:50/23:03**（两发均 250；错前缀一封由第二封自述；
     `/linux-arm-msm/`+`/linux-kernel/`+`/dri-devel/` 三处归档，正文逐字节相同）⇒ 现在只欠「等回复」；
  2. **Q28 证据回帖到 v5 线程（仍未发，只差放行）** = `patches/upstream/mdss-v5-q28-evidence-20261116/mail-body.txt`
     （症状族 A/B/C + 硬判据「DSI 中断计数亮 41 / 暗 0」+ 23 发真实 POR 四臂：`base 4/9` vs
     `含块复位两臂 15/15`，Fisher 双侧 **p=0.003**；`DIGTOP` 单独 p=1.0 ⇒ 无效；并写明边界
     **15/15 是三枚形状、两枚形状未采样**）。`send-mail-ustc.py` dry-run 已过（95 行、纯 ASCII、
     `In-Reply-To` = v5 cover MID `20261113155635.1677541-1-…`）。
     **★2026-11-17 修复一处真缺陷**：该草稿的 `Cc:` 原本写成 RFC 822 **折行**，而 `send-mail-ustc.py`
     的首部解析是逐行的 ⇒ dry-run 只报「收件人合计: 4 个」（真正该发 9 个），会**静默漏发**
     Konrad / Dmitry / Abel / Bjorn / Rob 五人（正好是这封信最该送到的人）。已把 `Cc:` 压成单行，
     修后 dry-run = 9 个；并新增门禁脚本 `scripts/mail-draft-check.py`（离线，A=RFC 解析 vs
     B=逐行解析，差集非空即 FAIL）。全载 = `reports/mail-draft-check-20261117.md`。
     投递前必跑：`scripts/mail-draft-check.py <draft>`。
- **邮件账缺口**（`q28-DOSSIER-B` §⑤-3）：`send-mail-ustc.py` 走 `smtplib`、发送后**不做 IMAP `APPEND`**
  ⇒ 该通道发出的件在 Sent Items 查不到（v5 那批就是典型）。**2026-11-17 已落地 `scripts/mail-append-sent.py`**
  （默认 dry-run，`--check` 只列缺，`--apply` 才 APPEND 且已存在的 MID 自动跳过；自测 `--self-test` 无需网络）；
  仍欠一步：把 `send-mail-ustc.py --send` 成功后接上它（该脚本在 `~/.local/bin/`，不属本仓，已登记「需要人做」）。

## 2c. 2026-11-17 复查（子代理联网核查，全账 `reports/upstream-replies-20261117.md`）

- **在飞 4 系列只有 1 个收到人回**：wl2868c v11（Rob，补 R-b）；**pstore v1 / dsi-phy v2 / mdss v5 零人回**（mdss v5 只有 sashiko 3 封 bot）。
- **另有 1 封真回帖不在 4 系列内**：Bryan 对我方 camss CSIPHY **RFC**（11-15 17:44 UTC）⇒ 要求先基于 on-list 的 v25/v7 工作，并直言我方邮件 AI 味难读。
- **我方相关主线合入 = 0**；但同家族上一代（Kaanapali PHY 3 枚）已于 11-13 被 Vinod 收进 phy-next（`846aacbf8322` / `478577f3db4a` / `00926bc50707`）——即「新增该代 lane 表」这个形状上游已采纳。
- **`qcom,nsessions` 已合入废弃**（`641dd7dd0f68`）⇒ 板级 DTS 侧待改。
- **邮件通道可用**：`~/.local/bin/read-mail-ustc.py --days 3` = INBOX 794 封、`rc=0`（keyring 未锁）——此前「无桌面会话 keyring 死锁」只影响**无会话**场景（`PITFALLS #670`），不要据此否定通道。
- **口径修正**：mainline 判定不可用本地 `linux/`（下游 `snap-20261110-v7.2-elden`）；lore/git.kernel.org/raw.githubusercontent 直连被 Anubis 或本机网络挡 ⇒ 走 `scripts/lore-fetch-raw.py` + **GitHub commits API / patchwork REST**。

## 3. 复启/纪律
- **投递按系列逐次批准**；本轮两批（wl2868c v11、mdss v4）由用户「按推荐顺序执行」放行。
- 代写回信/cover 的三件前提不变（披露 AI / 每条论断有可复现证据 / 逐条回应）——见 `AGENTS.md`「上游发信」。
- **无对照表不发提问**：11-13 相机 CSIPHY 版本分歧就属于「先对账再发信」的例子（`reports/camss-v6-rebase-plan-20261113.md` §2）。
- lore 抓取：`scripts/lore-fetch-raw.py`（过 Anubis）；patchwork REST 用于评论与状态。
