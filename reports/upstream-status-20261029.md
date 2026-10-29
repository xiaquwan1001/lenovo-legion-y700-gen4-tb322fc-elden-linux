# 上游系列状态页 — 2026-10-29

> **取代** `reports/upstream-status-20261027.md`（后者已过期：其「M4-2…M4-4 未投」与「M8 等回包」均被
> 10-28/10-29 动作推翻，仅作历史对照）。
> 权威口径 = `TASKS/README.md` §7 各 M 行；本页是「一眼看全 + 下一步动作」的压缩视图。
> 邮件侧原始证据 = `reports/mail-triage-20261029b.md`（42 封去重回包、12 线程归并、patchwork 24 个 series 只读查询）。

## 0. 一句话

**在途系列全部按「等 review」处理，唯一可立即推进的是回帖与返工；但 10-29 出现两项信誉/路线事件，
必须先修「提交形态」再发任何补丁。**

## 1. 逐系列状态

| 系列 | 状态 | 最近动作（10-27 → 10-29） | 我方欠什么 |
|---|---|---|---|
| **M3-1** dwc3 双连接器 | 🟡 等 review（v4 已投） | 10-26 投 v4 3 枚；sashiko 10-26 回 **8 条**（5 High：`dwc->lock` 内调 `dwc3_set_mode()` 自死锁、同角色换端口漏处理、注册早于 init 竞态、fwnode 引用泄漏、`IS_ERR_OR_NULL` 吞 `-EPROBE_DEFER`） | **v5**：先把角色切换挪出锁；binding 侧 3 条（`unevaluatedProperties`、顶层 `usb-role-switch`、`mux-state` 互斥）。草案 `out/mail-20261029b/01,02` |
| **M1-U6** `qcom_q6v5_pas` DTB 固件泄漏 | 🟡 等 review（10-27 投） | 无上游动作 | 无（此时催信只扣分） |
| **M2-A2** `qcom_battmgr` SM8750 | 🟡 等 review（10-27 投，v2 基线 linux-next） | 无上游动作；10-28 厂商 QBG 重新评估（旧「无厂商通道」结论被推翻，致命互斥 = `MSG_OWNER_BC` 与上游 `PMIC_GLINK_OWNER_BATTMGR` 同值） | 无；将来若做，落点推荐 **B（扩展上游 qcom_battmgr）** |
| **M4-1** bindings（gt9764 / s5kjns / wl2868c） | 🟡 等 review；**两枚被要求「给用户」** | Mark Brown + Krzysztof 回：wl2868c「只有 binding 别说 driver」、主题前缀不符；sashiko：gt9764 建议复用 `dongwoon,dw9768.yaml` | 回帖选路（gt9764 → `dw9768.yaml`）+ wl2868c 改 **binding + driver + DTS 同系列** |
| **M4-2…M4-4** camss 驱动 | 🔴 **v1 已投但被要求 hold；v2 未投** | 10-28 投 9 枚 + 10 封；10-28 晚 Hangxiang Ma：等 SoB/Author 补齐、**CSIPHY 必须改走 `phy-qcom-mipi-csi2-core`**；10-29 对照上游 **v6/v23** 后**公开放弃 6 枚**，只留 3 枚通用修复 | 3 枚已备（`patches/upstream/m4-camss-fixes-20261029/`，门禁 3/3 0E0W0C + 编译 0 warning，见该目录 `GATES.md`），**未投**；SoB 归属取证见 `reports/m4-camss-v3-plan-20261029.md` |
| **M6/B5** bonded DSI 核心 | ⛔ 用户 10-29 裁决**暂不启动**上游化 | preflight：6 枚对 pristine 7.3-rc7 `git am` **0/6**，缺整组不存在的 bonded 核心（4 文件 +822 −46） | 维持备料封存；第 5 步已解阻（魔数有上游符号） |
| **M7/Q24** rpmhpd retention | ✅ 无需我方补丁 | 上游 `skip retention by default` 已在 7.3 线 | 可选：把 retention 档位 dump 回给 Konrad/Taniya |
| **M8** dispcc 复位落点 | ⛔ **RFC 形状被否决** | Taniya Das：复位不得由 clk driver 驱动；10-28 回信接受 | 返工到 `msm_mdss_reset()`（`patches/upstream/q28-dispcc-v2-20261029/`，**未上机**） |
| **M9** GIC ITS 认领 LPI 表 | ⛔ 已撤回 | Marc Zyngier 否方案（正解 = 引导器预置 LPI 表 + DT memreserve）；10-26 回信已发 | 无（只保留「kexec 仅用于不需 LPI 的调试」） |
| **aw86927** 5 枚 | 🟡 等 review（10-27 投） | Krzysztof **Acked-by 2/5**；sashiko 4/5、5/5 各 1 条 Medium | v3 时保持 Ack 原样 + 接两条 Medium（草案 `out/mail-20261029b/07`） |
| **wl2868c driver** | ⬜ 备料，**未投** | — | 与 binding + DTS 同系列，用 `git format-patch -v2` 统一重生成 |

## 2. 两个必须先处理的非技术事件

1. **信誉**：Krzysztof 三封点名 `LLM-generated slop`，明说会降优先级；叠加我方 10-29 一封无称呼、无引用对象的裸编号汇总信（他回 "What are you referring to? I'll just drop this."），以及 wl2868c binding v1 **补丁正文整段重复**。
   ⇒ **门禁**：此后一律 `git format-patch` + `git send-email`/`b4` 生成，正文逐行写；发前跑
   `grep -c '^\+' `-级别的人工复核与 `checkpatch --strict`。草案 `out/mail-20261029b/05`（修补型回帖）。
2. **退信**：10-29 01:06 系统退信 = M8 撤回收尾信对 `mturquette@baylibre.com` 投递失败（5.0.0，MX 抽风；现 `dig MX baylibre.com` 正常）⇒ **Mike Turquette 从未收到撤回**。
   ⇒ 需**单独重投给他**（待用户批准）。

## 3. 工具事实（会影响所有「盯 review」判断）

- `read-mail-ustc.py --replies-only` **会漏检**：内部 `OUR_IDS` 硬编码 3 个旧 Message-ID，不覆盖 10-26 起的 v4 与 10-27/28 批次。10-29 实测它报「2 封」，补扫去重后 **42 封**。
  ⇒ 以后用 `out/mail-20261029b/mailscan.py --days N --mode ours|series` 交叉验证。
- patchwork：24 个 series 副本只读查询，**无 delegate、无 commit_ref**；10-29 已把 camss v1/v2 全部置 `superseded`（token 在 keyring，不入仓库）。

## 4. 备份/未证实

- SKEW_CAL `0x54` vs 厂商 `0x00`：上机 A/B **无可测差异**（3.144–3.156 s / 90 帧 ×3，30.26 fps），但只测前摄单模式、只热换未 POR。
- camss sashiko #4「多 RDI 累积位」修复效果**未被判别**（两路走不同 CSID 实例）。
- 10-29 07:35Z / 07:48Z 两次 patchwork 账号动作（确认信 / 密码重置）**来源未确认**；若非我方发起，按安全事件处理。
