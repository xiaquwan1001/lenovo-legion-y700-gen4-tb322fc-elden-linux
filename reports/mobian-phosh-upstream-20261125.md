# Mobian/phosh 上游化进度 + 通信增量复扫（D10）— 2026-11-25

> **只读纪律**：本文件是本轮**唯一**写入（未发信 / 未推 MR / 未改 TASKS/DEVICE/INDEX/RESOURCES/PITFALLS/AGENTS 与任何既有 report）；
> 外部命令一律 `timeout -k`；IMAP 全 `BODY.PEEK`（不改已读态），凭据只在运行时从 keyring 取、未落盘。
> **增量基线** = `reports/comm-triage-20261125.md`（覆盖到 2026-11-25T01:45Z）。本轮复核窗口 = **01:45Z → 11:25Z**（访问日期 2026-11-25 UTC，最后一次现查 11:25Z）。
> **判据口径**：① 只认「维护者/评审人可读的回信」+「维护者树 / linux-next 内容级」；② patchwork `state` 只作**摄取旁证**；
> ③ 拿不到的直接写「未取到」，不推测。

---

## ① 一页结论

### A. 通信增量（01:45Z → 11:25Z）

| 对象 | 渠道 + 时间戳 | 是否归档 | patchwork（仅旁证） | 新回信 | 需我方动作 |
|---|---|---|---|---|---|
| **dwc3 v15**（cover `<20261125081219.3661014-1@…>`） | lore `linux-usb` 线程页，`2026-11-25T08:12:34Z` | ✅ 4 封全在（[线程](https://lore.kernel.org/linux-usb/20261125081219.3661014-1-xiaqinghuan@mail.ustc.edu.cn/)） | `linux-usb` 15020958 `new` 08:12:17Z；`devicetree` 15020990 `needs-ack` | **sashiko 2 封**：`08:29:30Z`（1/3，2×`[Low]`）、`08:31:24Z`（系列小结：2/3・3/3 无问题）。人类 0 | **出 v16** 回应 2 条 `[Low]`（见 §2.3 A1） |
| **M11 pstore ping**（实发 MID `<179559762994.96050.5409562801088468974@…>`） | lore `/all/` + `Thread overview` 4 封，`2026-11-25T09:07:26Z` | ✅ 已归档（线程第 4 封 = 我方 ping） | —（回复件无 patch 条目） | 0 | 无需（等 Kees）。**但 TASKS 记的 MID 是 dry-run id，需更正**（§2.3 A4） |
| **M10 fastrpc 补发**（`<20261125022328.680070-1@…>`） | lore `/all/`，`2026-11-25T02:23:38Z`；`X-Mailing-List: linux-arm-msm` | ✅ 线程 8 封 | —（回复件） | 0（最新人类仍是 Konrad `11-09T14:16:46Z`） | 无需 |
| **M8 mdss 补发**（`<20261125022333.680119-1@…>`） | lore `/all/`，`2026-11-25T02:23:45Z` | ✅ 线程 13 封 | —（回复件） | 0 | 下次发件把 `abel.vesa@linaro.org` 换现址（§2.3 A3） |
| **elden 板 DTS v8**（cover `<20261125091309.124354-1@…>`） | lore `/all/`，`2026-11-25T09:13:16Z`；`X-Mailing-List: linux-arm-msm`，Cc 含 `mitltlatltl@gmail.com`、`abelvesa@kernel.org` | ✅ 3 封全在 | `devicetree`：1/2 15021210 `needs-ack`、2/2 15021211 `handled-elsewhere`；`arm-msm`：2/2 15021176 `new` | **sashiko 1 封** `09:19:45Z`（2/2，2×`[Medium]`）。人类 0 | 回应口径确定（§2.3 A2），**不必改 DT** |
| **aw86927 v4**（cover `<20261124045040.559317-1@…>`） | lore 线程 7 封，顶 = 我方 `2026-11-24T04:50:54Z` | ✅ | `linux-input` 15015279–15015284 全 `new` | **0**（静默 **30.6 h**） | 无需（等 Dmitry） |
| **M12→Venkat 回信**（`<179559445400.3708856.10349476503948801160@…>`） | lore `/all/`，`2026-11-25T08:14:16Z` | ✅ | — | 0 | 无需 |
| **INBOX 增量** | IMAP `mail.ustc.edu.cn:993`，窗口内 104 封（我方 4、退信 1、他人在办外 99） | — | — | **对我们线程的外部来信 = 0** | 见 §2.3 A5（IMAP 存储层自 `03:44:39Z` 起无新件） |

**一句话**：增量里**没有任何人类评审意见**，但机器人给了 **3 条需要处理的新意见**（dwc3 v15 两条 `[Low]`、elden v8 两条 `[Medium]`）；
另有 **1 个新的退信事实**（`abel.vesa@linaro.org` 死地址，R2 独退）与 **1 处账错**（M11 的 MID 记成了 dry-run id）。

### B. Mobian

| 项 | 现查值（渠道：GitLab/Salsa API v4，2026-11-25T11:1x–11:2xZ） | 结论 |
|---|---|---|
| `mobian1/droid-juicer !46` | `opened` · `detailed_merge_status=mergeable` · **notes 1（全 system；人类 0，故「最后一次人类 note」= 无）** · `sha=ea9fe3d5` · pipeline **3102631920 success**（`11-23T11:15:16Z`） · `updated_at=11-23T11:10:29Z`（**≈48.2 h 零变化**） | 等维护者；仓库 master 最后一次提交 = `2026-10-12`（0.4.3），6 个 open MR（!45 自 10-11）⇒ 队列慢，**不必催** |
| 我方其它 MR/issue（gitlab.com `scope=created_by_me`） | MR **1 条**（仅 !46）；issue **0 条** | 无遗漏面 |
| `Mobian-team/mobian-recipes`（**salsa**） | default `master`（末次提交 `2026-10-21` `a4fff866`）；`last_activity 2026-11-22Z`；open MR **15 条（无我方）**；`devices/qcom/configs/wip.toml` = **仍是空模板**；`devices/qcom/packages/` = **只有 `.gitkeep`**；`devices/qcom/droid-juicer/` = **只有 `.gitkeep`** | 我们 MR-2 的三件上游**一件都没有**；**硬前置（内核 deb）未满足** ⇒ 差距见 §3.2 |
| 内核 LTS 口径 | wiki.debian.org/Mobian/Porting 原文（现查）：「Mobian ships LTS kernel versions (e.g. 6.1/6.6/6.12/6.18) to stable and testing branches, while some not-LTS kernel versions can be made available in the **staging** section … please use the last available LTS kernel version」 | stable/testing 要 LTS；**staging 收 7.x**（口径未变） |
| `qcom-linux` 7.x staging 可用性 | 51 分支；**7.x 18 条**，最新 = **`mobian-sdm670-7.3` @ `2026-11-24T14:42:59Z`（`3c1fc08f` "d/changelog: release version 7.3.6-1"）**；LTS 家族 17 条（`mobian-sdm670-6.18` 11-23T14:42:37 6.18.65-1 / `mobian-sm6350-6.12` 11-23T11:37:01 6.12.119-1）；default = `mobian-sdm845-6.12` | 7.x staging **可用**；**0 条 sm8750 分支** ⇒ 我们缺的只有 `mobian-sm8750-7.4` + `debian/` |

### C. phosh / phoc

| 项 | 现查值 | 结论 |
|---|---|---|
| phosh `!2005` | API（`--noproxy '*'`）：`opened` · **`detailed_merge_status=mergeable`** · notes 6（`user_notes_count=2`，即 2 条人类）· `sha=5300355a` · pipeline **1152598 manual/Blocked**（`11-24T07:01:50Z`）· `updated_at=11-24T06:53:31Z`（我方 push） | **最新人类 note = guidog `2026-11-14T13:12:08Z`**（「continue without AI … setting the mode to `enabled` … retry on the next press」）；增量内 **0 新 note** |
| phoc `#125`（back gesture） | `opened`（建于 `2020-04-09`）· `updated_at=2023-02-17T10:33:53Z` · 10 条 note（末条 guidog `2023-02-17`） | **无新 MR**：phoc 14 个 open MR 里无 edge-swipe/back 相关（最近相关件仅 !828 layer-shell-effects drag gesture，`11-19`） |
| 版本线 | 上游 `phosh v0.59.0`（`2026-11-15T11:12:57Z`）、`phoc v0.59.0`（`2026-11-15T08:11:06Z`）；Debian **sid** phosh `0.59.0-1` / phoc `0.59.0-1`，**forky** phosh `0.58.0-1`，**trixie** phosh `0.46.0-3+deb13u1` / phoc `0.46.0-1`；我们设备 phosh **0.58.0**、phoc **0.58 / 0.59rc1（测试核）** | 设备落后上游/ sid **1 个 minor（0.58 vs 0.59）**；`0.46` = Debian stable(trixie) 线，不是我们的落地目标 |
| `reports/phosh-mr-power-mode-20261114.md` 前置 | 「能推的仓库」障碍已被该报告 §4 解掉（fork + `target_project_id`、HTTP 必须 `--noproxy '*'`）；补丁在 0.58 基线 + main 源树双验 | **仍成立**；新增两条待核事实见 §4.3 |

---

## ② 通信增量详证

### 2.1 IMAP 增量 —— **存储层自 `03:44:39Z` 起无新件（必须先说）**

脚本 = `/tmp/mp_scan.py`（`SINCE 24-Nov-2026`，INBOX + `"Junk E-mail"` + `"Sent Items"`，全 `BODY.PEEK`，按 `INTERNALDATE` 过滤 ≥ `2026-11-25T01:45Z`）。

| 观测 | 值 |
|---|---|
| 窗口内封数 | **104**（INBOX 101 / Junk 1 / Sent 2） |
| 各文件夹**最后一封**的 `INTERNALDATE` | INBOX `25-Nov-2026 11:44:39 +0800` = **03:44:39Z**；Junk `10:23:49 +0800`；Sent `10:23:36 +0800`（三处同一天花板） |
| 我方邮件 | 4 封（R1/R2 的 Sent 副本 + 服务端回写 INBOX 副本） |
| 退信 | **1 封**：`<6b0646ad.4f307ea2.36666.a537.GMR@mx.google.com>`，`2026-11-25T02:23:49Z`，`In-Reply-To <20261125022333.680119-1@…>`（= R2）⇒ 退 `abel.vesa@linaro.org`（正文 `Address not found`） |
| 外部来信 IRT/References 命中我方 MID | **0**（命中者全是我方自己的 R1/R2 副本与该 DSN） |
| 「像我们线程」的外部来信 | 3 封，**均非我们**：Xu Yang `03:33:48Z`（`usb: dwc3: Allow glue drivers to override all dwc3_properties`，Thinh 的系列）、Stanislav `03:43:59Z/03:44:03Z`（Halliday v3 04/14 的 `qcom,snps-dwc3.yaml`） |

⇒ **`03:44:39Z` 之后（含我方 08:12Z dwc3 v15、09:07Z pstore ping、09:13Z elden v8 的送达/退信面）IMAP 侧什么都没有**，
故这三封的**退信扫描不可做**（原因未取到：非我方凭据/文件夹问题，`STATUS INBOX (MESSAGES 19435)` 与三处天花板一致）。
**本轮这 3 件的「有没有回信」改用 lore 线程 atom（`t.atom`）判定**，见 §2.2。
副作用：`Sent Items` 里也看不到 08:12Z 之后的三封（`git send-email` 提交不自动入 Sent 可解释，但 INBOX 自收副本也没有 ⇒ 仍是存储层问题）。
**不据此推断「信没发出」**：三封在 lore 均已归档（§2.2），SMTP 侧另有 `Result: 250` 日志（`patches/upstream/dwc3-v15-20261125/logs/sent-20261125-161219.txt`、`elden-dts-v8-20261125/logs/sent-20261125-171309.txt`）。

### 2.2 逐件现查（lore 线程 atom + `/raw` 头 + patchwork）

**工具**：`curl -A '<browser UA>' https://lore.kernel.org/all/<MID>/t.atom`（200，含全文）；`/raw` 走 Anubis 求解器（`/tmp/lget.py`）。

| 件 | 线程封数 / 末封 | 外部回信（作者 + 时间 + MID） | lore 归档归属（`X-Mailing-List`） |
|---|---|---|---|
| dwc3 v15 | 6（4 我方 + 2 sashiko） | sashiko `08:29:30Z` `<sashiko-outbox-232903@kernel.org>`、`08:31:24Z` `<sashiko-outbox-232906@kernel.org>` | `linux-usb@vger`（线程页直取命中）；`devicetree` 侧按 MID 也有条目（patchwork 429 15020990），`/linux-devicetree/<MID>/` 未单建（lore 按 MID 去重） |
| pstore ping | 4（3 原 v1 + ping） | **0** | `linux-arm-msm@vger`（`/raw` 头 `X-Mailing-List`） |
| M10 补发 | 8 | **0**（末人类 = Konrad `2026-11-09T14:16:46Z`） | `linux-arm-msm` |
| M8 补发 | 13 | **0** | `linux-arm-msm` |
| elden v8 | 4（3 我方 + 1 sashiko） | sashiko `09:19:45Z` `<sashiko-outbox-232999@kernel.org>` | `linux-arm-msm`（`/raw`：`X-Mailing-List: linux-arm-msm@vger.kernel.org`；Cc 里确有 `devicetree@`） |
| aw86927 v4 | 7（全我方） | **0** | `linux-input` |
| Venkat battmgr v2 | 7 | **0** | `linux-pm`/`lkml`（patchwork 侧未查，未取到） |

**新意见原文要点（逐条，供回信/ v16 用；不作我方判断扩张）**

- `sashiko-outbox-232903`（dwc3 v15 **1/3**，`2026-11-25T08:29:30Z`），两条 `[Low]`：
  1. 「the "Changes since v13:" block is placed **above the "---" tearline** separator, so git am records the revision changelog in the permanent commit message.」
  2. 「`$defs/port-base` … 因为 port@0 只对 `^endpoint@[01]$` 加 `unevaluatedProperties: false`，且 **else 分支没有引用** `/schemas/graph.yaml#/properties/port`，单口控制器的裸 `port@0/endpoint`（或 `endpoint@2+`）会接受任意未文档化属性；另外 then 分支 `'^endpoint@([2-9]|[1-9a-f][0-9a-f]+)$'` **漏了单字符 a–f**」→ 建议「Referencing `$ref: /schemas/graph.yaml#/properties/port` under port@0 in the **else branch** and changing `[2-9]` to **`[2-9a-f]`** in the then branch pattern would close both gaps.」
- `sashiko-outbox-232906`（`08:31:24Z`，系列小结）：「Patches 2 and 3: **no issues found**. Patch 1: 2 potential issues (2 Low)」。
- `sashiko-outbox-232999`（elden v8 **2/2**，`2026-11-25T09:19:45Z`），两条 `[Medium]`：
  1. 缺核心引导/电源节点（SPMI PMIC、`&apps_rsc` RPMh regulators、console、storage），「leaving `&i2c10` and an unused camera PMIC as the only enabled peripherals」。
  2. 「Is there a devicetree binding schema for `willsemi,wl2868c`? … make dtbs_check fails validation」。
  （两条都 = 我们 cover 里**已如实声明**的两项，见 v8 cover「Known dependencies and gaps」原文。）

**patchwork 摄取（旁证，不作判据）**：`linux-usb` 363 → `[v15,1/3]` 15020958 `new`；`devicetree` 429 → `[v15,1/3]` 15020990 `needs-ack`、`[v8,1/2]` 15021210 `needs-ack`、`[v8,2/2]` 15021211 `handled-elsewhere`；`arm-msm` 92 → `[v8,2/2]` 15021176 `new`、`[v7]` 14991580 仍 `new`；`linux-input` 17 → v4 六枚 `new`。
（回复件不产生新 patch 条目；M8/M10 补发是否挂到对应 series 的 comment 面，**未取到**。）

### 2.3 需我方动作（逐条；**谁能回、回什么，本 lane 不代发**）

| # | 事项 | 谁能回 / 载体 | 具体内容（最小动作） |
|---|---|---|---|
| **A1** | dwc3 v15 的 2×`[Low]` | **我方作者**；载体 = **v16 补丁**（不是回信；1/3 需改） | ① 把 1/3 的 `Changes since v13:` 段整体移到 `---` 之下；② else 分支给 `port@0` 补 `$ref: /schemas/graph.yaml#/properties/port`；then 分支 pattern 改 `[2-9a-f]`。2/3・3/3 无意见，可保持不变（仍 byte-identical） |
| **A2** | elden v8 的 2×`[Medium]` | **我方作者**；载体 = 维护者回信后随 **v9**，或**不单独回**（两条 = cover 已声明项） | 建议只在有维护者来信时引用 cover 原文一句 + `willsemi,wl2868c` 已进 `regulator.git for-7.5`（`84e67d2ee13f`/`602f57223457`）+ `dtbs_check` 的唯一诊断即为此；**不新增 DT 内容** |
| **A3** | `abel.vesa@linaro.org` 死地址（R2 独退，`02:23:49Z`） | **用户放行**才可补发；本 lane 只报 | 下次给 M8 线程发件用 `abel.vesa@oss.qualcomm.com`（11-24 已按 lore `f:abel.vesa@oss.qualcomm.com` 核）；**本次不补发**（正文已进 lore，列表读者看得到） |
| **A4** | M11 的 MID 记错 | 有 TASKS 写权的一方 | TASKS §7 M11 行写的是 **dry-run id** `179559762811.96036.…`；**实发/归档 = `<179559762994.96050.5409562801088468974@mail.ustc.edu.cn>`**（lore `/raw` 头逐字，`Date: Wed, 25 Nov 2026 17:07:09 +0800` = 09:07:09Z）。根因 = `send-mail-ustc.py` 每次运行重生 Message-ID（技能第 10 条） |
| **A5** | IMAP 存储层冻结 | 用户（账号面） | 自 `2026-11-25T03:44:39Z` 起 INBOX/Junk/Sent 三处均无新件；需用户侧确认（配额/反垃圾/服务端延迟）。在此之前**不要**把「INBOX 无退信」当结论 |

---

## ③ Mobian 上游化进度

### 3.1 `mobian1/droid-juicer !46`（GitLab API v4，gitlab.com，`2026-11-25T11:1xZ`）

| 字段 | 值 |
|---|---|
| 状态 | `state=opened`、`draft=false`、`detailed_merge_status=mergeable`、`has_conflicts=false` |
| notes | `user_notes_count=0`；`/notes` 实取 **1 条且为 system**（`2026-11-23T11:10:29Z`「added 1 commit ea9fe3d5」）⇒ **最后一次人类 note = 无（未取到，因为不存在）** |
| pipeline | `3102631920` **success**，sha `ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d`，`2026-11-23T11:15:16Z` |
| sha / 时间 | head `ea9fe3d5`；`created_at 2026-11-21T09:31:14Z`；`updated_at 2026-11-23T11:10:29Z`（到复核时刻 **≈48.2 h 零变化**） |
| 仓库侧 | master 末次提交 `2026-10-12T12:28:10Z a160267c`「Release version 0.4.3」；open MR 6 条（!45 `2026-10-11`、!36、!35、!22、!2 均 draft/久挂）⇒ **维护者节奏 = 月级**，我们 11-21 才开，属正常等待 |
| 我方其它件 | gitlab.com `scope=created_by_me`：**MR 1（本件）/ issue 0** |

### 3.2 `Mobian-team/mobian-recipes` 现状 vs `patches/distro/mobian-20261124/mobian-recipes-elden-mr2/`

| 维度 | 上游现查（salsa API，`master`） | 我方备料包 | 差距 |
|---|---|---|---|
| `devices/qcom/configs/wip.toml` | **仍是空模板**（118 行注释 + `chipset = ""` + 空 `[[device]]`）；与我们 11-24 快照 **`diff` 相同** | `wip.toml.append`（`[[device]]` + `chipset="sm8750"`、`vendor="lenovo"`、`model="elden"`，不写 version/dtb/append） | 只差提交（无上游变化，无 rebase 债） |
| `devices/qcom/droid-juicer/` | **只有 `.gitkeep`** | `droid-juicer/lenovo,elden.toml`（与 !46 `ea9fe3d5` 逐字节一致） | 需 `mkdir` + 新文件；`packages-base.yaml:35-37` 已覆盖该目录 ⇒ 无配方改动 |
| `devices/qcom/packages/` | **只有 `.gitkeep`** | 空 | **硬前置**：缺 `linux-image-<ver>-sm8750*.deb` ⇒ 提交即 CI 红（`qcom` job 建不出可启镜像） |
| 现役 SoC 配置 | `sc7280 / sdm670 / sdm845 / sm6350 / sm7150 / wip` | 我们目标 = 第 7 个 | 需上游先有可复用内核分支（见 3.3） |
| open MR / 活跃度 | 15 条 open（无我方）；`master` 末次 `2026-10-21T10:33:28Z a4fff866`；`last_activity 2026-11-22Z` | — | 不是「没人管」，是**排队** |

⇒ **结论**：MR-2 的三件里，两件（TOML）具备「内核 deb 一到即投」的完成度；**唯一未满足的硬前置仍是内核 deb**（连带上游 `qcom-linux` 需先有 sm8750 分支）。

### 3.3 内核 LTS 要求 vs 我们 7.x —— 冲突现状与 staging 可用性

- **上游口径原文**（wiki.debian.org/Mobian/Porting，本轮现查；页面 `last modified` **未取到**）：
  > "Mobian ships LTS kernel versions (e.g. 6.1/6.6/6.12/6.18) to stable and testing branches, while some not-LTS kernel versions can be made available in the **staging** section of the repository … please use the last available LTS kernel version"
  ⇒ **stable/testing 强制 LTS；staging 允许非 LTS**（与 11-21 报告读法一致，未见改口）。
- **`qcom-linux` 现查**（`salsa.debian.org/Mobian-team/devices/kernels/qcom-linux`，`last_activity 2026-11-24T21:10:54Z`，**51 分支**，default = `mobian-sdm845-6.12`）：
  - **LTS 家族 17 条**，活跃样例：`mobian-sdm670-6.18`（`2026-11-23T14:42:37Z`，`6.18.65-1`）、`mobian-sc7280-6.18`（`11-23T13:49:28Z`）、`mobian-sm6350-6.12`（`11-23T11:37:01Z`，`6.12.119-1`）。
  - **7.x 分支 18 条，仍在活跃提交**，最新 4 条：`mobian-sdm670-7.3`（**`2026-11-24T14:42:59Z` `3c1fc08f`** `d/changelog: release version 7.3.6-1`）、`wip/tiol/7.3-sdm845`（`11-23T22:28:21Z`）、`mobian-sc7280-7.3`（`11-23T19:03:22Z`）、`mobian-sdm845-7.3`（`11-23T08:44:24Z` `Linux 7.3.6`）。
  - **`sm8750` 分支：0 条**（`branches` 全量 `grep -i 8750` 空）。
  ⇒ **7.x staging 可用（有活的 7.3 线可抄形状）**，我们缺的是自己的 **`mobian-sm8750-7.4` + `debian/` 打包**（沿 11-21 结论：从 `6.18-sdm845` cherry-pick「Add Debian packaging」`28d219039c63`，再改 `debian/config`）。
- **我们 7.x 与 LTS 的冲突现状（一句话）**：设备侧全部在 **7.3/7.4 线**，进 **stable/testing 必须 6.12/6.18**；而 **6.18 不可落**（v6.18 的 `sm8750.dtsi` 4083 行 vs 在机线 7484 行，缺 USB v7.0 / mdss v7.1 / GPU+camss-PHY v7.4 三段使能 —— 沿 `reports/mobian-upstream-firstpr-20261121.md` §1，**本轮未重验**）⇒ **只能走 staging/分支形态**，LTS 重基是第二阶段独立决策。

---

## ④ phosh / phoc

### 4.1 `World/Phosh/phosh !2005`（GNOME GitLab API v4，**必须 `--noproxy '*'`**，否则 Fastly 406）

| 字段 | 值（`2026-11-25T11:1xZ`） |
|---|---|
| 状态 | `opened` · **`detailed_merge_status=mergeable`** · `has_conflicts=false` · `blocking_discussions_resolved=true` |
| notes | `user_notes_count=2`；`/notes` 实取 **6**（4 system + 2 human）；**最新人类 = guidog `2026-11-14T13:12:08.406Z`**；我方最近 3 条全 system/自述（`11-24T06:43:26Z` 人类、`06:46:10Z`/`06:53:31Z` system） |
| sha / 时间 | head `5300355a30f47df5443823a1c6c207adc30d9e39`；`updated_at=2026-11-24T06:53:31.635Z`（我方 push，不是回复） |
| pipeline | `1152598` · `status=manual` · `detailed_status=Blocked (waiting for manual action)` · sha 同 head · `2026-11-24T07:01:50.911Z` |
| URL | <https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005> |

**⚠ 一处口径冲突（据实记）**：Firecrawl 渲染的**网页**显示「Merge blocked: 1 check failed — Fast forward merge is not possible. Please rebase」「source branch is **20 commits behind**」且挂的是旧 pipeline `1146543`（`88a0e237`）；
而 **API 同时刻返回 `mergeable` / `has_conflicts=false`**。⇒ 本轮**以 API 为判据**，网页那句按「缓存/旧渲染」处理；**是否真需 rebase 未取到定论**（下次在网页强制刷新或用 `GET ...?include_diverged_commits_count=1` 复核）。

### 4.2 `World/Phosh/phoc #125`（`Have a back gesture to close dialogs`）

- `state=opened`，`created_at 2020-04-09T18:24:28Z`，`updated_at 2023-02-17T10:33:53Z`，`user_notes_count=10`（`/notes` 13 条，末条 guidog `2023-02-17T10:33:53Z`：「A e.g. two/three finger swipe close could benefit other toolkits though.」）。
- **无新 MR**：phoc open MR 14 条（最新 828/827/826 均 `2026-11-19`），`search=back` 20 条里无 edge-swipe/back-gesture 相关件。
- 结论：**该需求上游 3 年无动**；我们的「侧滑返回」是设备侧 lisgd 实现（`patches-userland` 线），不构成上游提交候选。

### 4.3 版本线结论 + 14 日报告前置是否仍成立

- **一句结论**：上游 `phosh/phoc v0.59.0`（`2026-11-15`）= Debian **sid** `0.59.0-1`；我们设备跑 **phosh 0.58.0 / phoc 0.58（0.59rc1 测试核）**，**落后 1 个 minor**；`0.46` 是 **trixie(stable)** 线（`phosh 0.46.0-3+deb13u1` / `phoc 0.46.0-1`），只在「迁移到 Debian stable」语境下才有意义。
- **`reports/phosh-mr-power-mode-20261114.md` 的前置仍成立**：① 该报告 §4 已解掉「不能对上游项目直接 `POST`（403）」「必须 `--noproxy '*'`」两条；② 补丁在 0.58 基线与 main 源树双验。
- **本轮新增两条待核（不推翻前置，只是补充）**：
  1. API/网页在「是否需 rebase」上不一致（§4.1 ⚠）；
  2. guidog 的「**continue without AI from here**」仍然有效 ⇒ 后续任何正文更新仍须走「披露 + 可复现证据 + 逐条回应」三件套，且**不得自行投递**（发信权限与代写权限分离）。

---

## ⑤ 未取到 / 工具事实（给下一轮省时间）

1. **IMAP 存储层冻结**：`2026-11-25T03:44:39Z` 之后三处文件夹均无新件（`STATUS INBOX (MESSAGES 19435)`）。⇒ 退信面 / Sent 副本本轮**不可核**；改用 lore `t.atom` 判回信。原因未取到。
2. **`lore /raw` 与 `patchwork /api` 都会撞 Anubis**（`/raw` 403→挑战页；patchwork 返回挑战 HTML）。可用：`curl -A '<browser UA>' .../t.atom`（直接 200 含全文）、`/tmp/lget.py`（PoW 求解器，此次 `n=67` 即过）、`web_fetch`（Firecrawl 渲染线程页）。
3. **patchwork 列表端点要 `project=` 或 `series=`**（本次首次查询被 400：`Searches must be limited with one of these parameters`）；project id 现查：`linux-input=17`、`dri-devel=21`、`linux-arm-msm=92`、`linux-usb=363`、`devicetree=429`。
4. **GNOME GitLab 必须 `--noproxy '*'`**（走代理/或环境 proxy 生效时 = Fastly 406）；gitlab.com 相反，proxy 与直连都可（本轮用直连）。**salsa.debian.org** 直连可用、无 Anubis。
5. **lore 按 MID 去重归档**：一封 Cc 多列表的信只在**一个** inbox 建条（`X-Mailing-List` 决定），所以「`/linux-devicetree/<MID>/` 404」≠ 未投递 —— 先看 `/all/<MID>/` 的 `X-Mailing-List`。
6. **`send-mail-ustc.py` 每次重生 Message-ID**（技能第 10 条）已再次实锤：M11 ping 的 dry-run id = `179559762811.96036.…`，实发/归档 = `179559762994.96050.…`。
7. 本轮未做（lane 边界）：设备侧/上机、任何发信/MR 推送、`TASKS|DEVICE|INDEX|RESOURCES|PITFALLS|AGENTS` 与既有 report 的修改。

---

## ⑥ 复现命令（全部只读，带 `timeout -k`）

```bash
# 0) IMAP 增量（BODY.PEEK；INTERNALDATE ≥ 2026-11-25T01:45Z）
timeout -k 5 300 python3 /tmp/mp_scan.py                      # → 104 封；三处天花板 = 03:44:39Z

# 1) lore 线程 atom（含全文；UA 用浏览器串即可 200）
python3 /tmp/mp_lore.py                                       # 8 条线程的封数/作者/时间一览
timeout -k 5 120 python3 /tmp/lget.py 'https://lore.kernel.org/all/<MID>/raw' /tmp/x.txt   # Anubis PoW

# 2) patchwork（仅摄取旁证）
timeout -k 5 120 python3 /tmp/lget.py \
  'https://patchwork.kernel.org/api/1.2/patches/?project=363&q=dwc3%20two%20connectors&order=-date&per_page=8' /tmp/pw.json
timeout -k 5 120 python3 /tmp/lget.py \
  'https://patchwork.kernel.org/api/1.2/patches/?project=429&q=lenovo&order=-date&per_page=6' /tmp/pw2.json

# 3) GNOME GitLab（务必 --noproxy '*'；token 取 keyring，未落盘）
TOK=$(secret-tool lookup protocol https user xuqianhui1001 host gitlab.gnome.org)
curl -sS --noproxy '*' -H "PRIVATE-TOKEN: $TOK" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005' | jq '{state,detailed_merge_status,user_notes_count,sha,updated_at}'
curl -sS --noproxy '*' -H "PRIVATE-TOKEN: $TOK" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005/notes?per_page=100&sort=desc'
curl -sS --noproxy '*' -H "PRIVATE-TOKEN: $TOK" \
  'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphoc/issues/125'
curl -sS --noproxy '*' -H "PRIVATE-TOKEN: $TOK" \
  'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/repository/tags?per_page=5'

# 4) gitlab.com / salsa（token 亦从 keyring 取）
TOK2=$(secret-tool lookup protocol https host gitlab.com username xiaquwan1001)
curl -sS -H "PRIVATE-TOKEN: $TOK2" 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS -H "PRIVATE-TOKEN: $TOK2" 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46/notes?per_page=100&sort=desc'
curl -sS -H "PRIVATE-TOKEN: $TOK2" 'https://gitlab.com/api/v4/merge_requests?scope=created_by_me&state=all'
curl -sS 'https://salsa.debian.org/api/v4/projects/Mobian-team%2Fdevices%2Fkernels%2Fqcom-linux/repository/branches?per_page=100'
curl -sS 'https://salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes/repository/files/devices%2Fqcom%2Fconfigs%2Fwip.toml/raw?ref=master'
curl -sS 'https://salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes/repository/tree?path=devices/qcom/packages&per_page=100&ref=master'

# 5) 版本线
for p in phosh phoc; do curl -sS "https://sources.debian.org/api/src/$p/"; done
```
