# 上游化当前一页（2026-11-25）

> 取代 `reports/upstream-status-20261113.md`（11-13 版留作沿革；11-17/11-21/11-24 的投递批次见 `TASKS/README.md` §7 头与各 `patches/upstream/*/SENT.md`）。
> 只写「逐系列状态 / 我方欠什么 / 复启条件」；证据指针在行内。**patchwork `state` 一律不作证据**（`PITFALLS #724`）。
> 同日完成的**重复性核查**（7 系列逐条查维护者树）= `reports/dup-check-20261125.md`，本页与它口径一致。

## 0. 一句话

**1 个系列已进树**（wl2868c → `regulator.git for-7.5`，项目首件）、**7 个在飞等回信**、
**2 个已作废**（M12 被上游覆盖；M4 csiphy 2.4.0 降级为 delta 素材）、**1 个待放行**（elden 板 DTS v8 备料齐、门禁全绿）。

## 1. 已进树（唯一一件）

| 系列 | 合入 | 复核 |
|---|---|---|
| `regulator: willsemi,wl2868c`（binding + driver） | `84e67d2ee13f`（binding）、`602f57223457`（driver），合并提交 `0216753490ff`，均在 **`broonie/regulator.git for-7.5`** | 主会话 `web_fetch` 逐行命中；`Author: Qianhui Xu`。**patchwork 至今 `state=new`/`commit_ref=None`** ⇒ 反例已入 `PITFALLS #724` |

后续（非阻塞）：7.5 合并窗口后把 `TASKS` 的 M4/wl2868c 行改成「已进 mainline」并记账；板 DTS 里 `willsemi,wl2868c`
的 `dtbs_check` 诊断届时自然消失（见 §4 v8）。

## 2. 在飞（按「上次动作」排序）

| 系列 | 最新代次 | 上次动作 | 现在等谁 | 我方欠 |
|---|---|---|---|---|
| **dwc3 双 connector**（M3） | **v15**（3 枚 + cover） | 2026-11-25T08:12Z 投出，**`linux-usb` 已进 Cc**（Greg 11-24 的第二条要求），1/3–3/3 与 v14 diff 段逐字节相同，cover 新增「Testing on hardware」段 | Greg KH / Thinh Nguyen | 只等回信；被要求「先有板 DTS 再谈」时口径 = 见 §4 |
| **elden 板 DTS**（M3-DTS） | v7 在档（`14991580`，0 回复）；**v8 备料就绪** | 2026-11-25 晚建 v8 包（补 `qcom.yaml` + 板件=v7 原文，门禁全绿，`SEND.sh` dry-run `Result: OK`） | **用户放行**（§7 逐系列批准） | 放行后 `bash SEND.sh --send`；另需 Pengyu 指定 trailer 形式（`Co-developed-by` 不代签） |
| **M8 mdss 块复位** | v5（3 枚，3 R-b） | 11-24T15:15Z ping **退信**（`dmitry.baryshkov@linaro.org` 死地址）⇒ 11-25T02:23Z **换现址补发**（`dmitry.baryshkov@oss.qualcomm.com`，lore 已归档） | Dmitry / Konrad / Bjorn | 等回信；上机两枚形状与 `0xa000` 单变量仍**未证**（`reports/mdss-int2-evidence-20261113.md` §2.3） |
| **M10 fastrpc non-secure** | v3 | 同上换址补发（`srini@kernel.org` 在 Cc） | Konrad + Ekansh/Dmitry/Srini | 技术欠账 0，等回信 |
| **M11 pstore initrd 重叠** | v1（2 枚） | 2026-11-16T04:00Z 投出后**静默 ≈9 天、零回复** | Kees Cook / linux-pstore | **到点礼貌 ping**（下一个对外动作候选） |
| **aw86927 AW86937**（M4 收窄） | v4（7 封） | 2026-11-24T04:50Z 投出（答 sashiko 4 条 + 收 Joonhoe `Tested-by`） | Dmitry Torokhov | 等回信；v4 之后 0 封回复（11-25 现查 lore） |
| **dsi phy PLL_SYSTEM_MUXES**（M6-L1） | v2 | 2026-11-16 两发（首封漏前缀已在正文自述） | Dmitry / linux-arm-msm | 等回信 |

## 3. 已作废 / 停投（不要再当在飞件）

| 系列 | 判决 | 依据 |
|---|---|---|
| **M12 USB 充电限流**（我方 0001+v2） | ⛔ **被上游覆盖，不投**；本机只留 backport 参考 | Joonhoe Kim 的实现已收录 `be5e7367bceb`（`sre` for-next），语义逐条相同；**本机实测上游件 + Venkat v2 都通过**（写 900000↔500000 回读一致、`unknown message`=0）⇒ `reports/m12-upstream-test-20261125.md` |
| **M4 camss csiphy 2.4.0 v2** | ⛔ **不再作独立系列** | 上游 Wenmeng v7 `[06/23]` 已把 `qcom,sm8750-csi2-phy` 定到 kaanapali（2.3.0 表）并带 Bryan R-b；我方只剩「13 条值差 / 净行为 4 条 `0x0000` 写」⇒ 等 v7 进树后作 **1 枚 delta** 投给 Bryan |
| **M9 kexec LPI claim** | ❌ 已撤回（Marc Zyngier 明确否定） | 同前页 §3 |

## 4. 板 DTS 与 Pengyu Luo 的关系（投前必读）

- 同一个 `sm8750-lenovo-elden.dts` 由 **Pengyu Luo** 先投（`[PATCH v2 0/2]`，2026-07-26，1170 行，based on `sm8750-qrd`），
  状态 `changes-requested`（Abel/Konrad 评审过）、**无 v3、未合入**。
- **2026-10-25 双方确认移交**（他原话「squash them and send the whole thing your way」）⇒ 我方 v7/v8 **supersedes** 其 v2。
- **v8 相对 v7 只多一件事**：`qcom.yaml` 补 `lenovo,elden`（v7 漏了这行，`dtbs_check` 直接判根节点不合法，负样例在包内）。
- 板件唯一残留诊断 = `willsemi,wl2868c` schema 缺失 ⇒ 依赖 §1 那两枚提交进 mainline，**不隐藏**。

## 5. 工具事实（本窗口新增，省下一次踩坑）

- `web_fetch`（Firecrawl）能直接渲染 `lore.kernel.org/<list>/<MID>/`，绕过 Anubis ⇒ 归档复核不必只靠 patchwork。
- `checkpatch.pl` **必须喂 stdin**（`- < patch`），传文件路径会把补丁当源码、报假 `trailing whitespace`（`PITFALLS #725`）。
- 「上游是否已做」要查**维护者树**（`git.kernel.org/…/<maint>/<tree>.git/log/?qt=grep&q=`），patchwork/lore 都查不到已收录件（`PITFALLS #724`）。
- `power_supply` 的 `usb_type` sysfs：**方括号里才是当前值**（`PITFALLS #726`）。
