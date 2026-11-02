# M4 camss：我方 v2(9 发) 与上游在审系列的覆盖差集 + 裁决（2026-11-02）

- 性质：**只读比对**（材料在 `/tmp/camss-up/`，未入库）。未发信、未改 patchwork、未碰设备、未 commit。
- 材料：Qualcomm Hangxiang Ma `[v6 0/7]`（patchwork series **1131656**，mbox 114 279 B）、
  Bryan O'Donoghue `[PATCH 0/14] Add SOF/EOF sequence logic`（series **1196135**）、
  我方 `[v2 0/9]`（series **1195271**，2026-10-28 实发）、`camss` master 快照。
- 未取到：`80dd5911cb` / `2482c6f93a` 的对象（本地树 shallow + 未联网 fetch）；本次差集以**在审 mbox 的 diff 文本**为准。

---

## §0 结论

| 项 | 数字 |
|---|---|
| 我方 v2 补丁 | 9 枚（+1 cover） |
| 与 Qualcomm v6 **直接重复** | **3 枚**（1/9 binding、4/9 CSID 980、8/9 VFE gen4） |
| 与 Bryan SOF/EOF 系列 **重复** | **1 枚**（5/9 frame starts from CSID） |
| 我方**独有且可独立成立** | **4 枚**（2/9 csiphy 2.4.0 lanes、3/9 csid power-on 回滚、6/9 DMA 连续缓冲检查 + prepare、7/9 start 失败回滚） |
| 依赖上游在审件才成立 | **1 枚**（9/9 DTS，依赖 v6 的 `qcom,sm8750-camss.yaml`） |
| **裁决** | **B′**：把 v2 拆成「4 枚独立小修 + 1 枚依赖 v6 的 DTS」，另给 Bryan 系列补一枚 `sm8750` 的 `frame_sync_en`；**不再自成 9 发系列** |

一句理由：**9 发里只有 4 发是上游没有的**；继续整串重投，最可能的回包是「请基于 Hangxiang 的 v6 和 Bryan 的 SOF 系列重做」。

---

## §1 覆盖表（逐枚）

| 我方 v2 | 规模 | 上游对应 | 判定 | 依据 |
|---|---|---|---|---|
| 1/9 `dt-bindings: media: add SM8750 camera subsystem` | 435 + | v6 **2/7** `media: dt-bindings: Add CAMSS device for SM8750`（427 +） | **重复 ⇒ 丢弃我方** | 同一文件 `qcom,sm8750-camss.yaml`；两份都是新建 schema，规模差 8 行（属性裁剪差异，**待逐属性核**） |
| 2/9 `csiphy: add CSIPHY 2.4.0 lane settings for SM8750` | 125 + / 2 文件 | v6 **4/7** `csiphy: Add support for v2.3.0 two-phase CSIPHY`（**2 行**，只加 camss.c 匹配项） | **独有 ⇒ 保留** | v6 只登记 **v2.3.0（two-phase）**，与我方 **v2.4.0 的 lane/preemphasis 表**不是同一件事 |
| 3/9 `csid: unwind power-on through a single error label` | 20 + / 25 − | 无 | **独有 ⇒ 保留（独立小修）** | 纯错误路径重构，不依赖任何新 SoC |
| 4/9 `csid: add the 980 generation` | 464 + / 8 −，6 文件 | v6 **5/7** `csid: Add support for CSID 980`（520 +，4 文件） | **重复 ⇒ 丢弃我方** | 同一新驱动 `camss-csid-980.c`；v6 多 56 行（含 TPG 7/7 的部分） |
| 5/9 `csid: report frame starts from CSID` | 101 + / 1 − | Bryan **03/14 SOF tracking** + **07–10/14 RDI SOF enable（gen3/680/gen2）** | **重复 ⇒ 丢弃我方，改给 Bryan 系列加 sm8750** | 方向一致（SOF 由 CSID 上报）；Bryan 的 11–14/14 已把 `frame_sync_en` 开到 sm8650/x1e/x2e/sm8250/sdm845，**独缺 sm8750** |
| 6/9 `video: check DMA contiguous + prepare hook` | 18 + / 1 − | 无 | **独有 ⇒ 保留（独立小修）** | 与 SoC 无关的 defensiveness 修 |
| 7/9 `video: stop already-started subdevices when start fails` | 30 + / 30 − | 无 | **独有 ⇒ 保留（独立小修）** | 同上 |
| 8/9 `vfe: add the gen4 block and SM8750 camera subsystem` | 570 +，3 文件 | v6 **6/7** `vfe: Add support for VFE 980`（11 + / 3 −） | **重复 ⇒ 丢弃我方**，仅核 v6 是否缺我方独有的 gen4 注册项 | 我方体量大 50 倍，但上游选择「最小注册 + 复用 gen4」；**待逐符号核**（`camss-vfe-gen4.c` 的 1080/980 差异） |
| 9/9 `arm64: dts: qcom: sm8750: add the camera subsystem` | 179 + | 无（v6 无 DTS） | **保留，但必须 `Depends-on:` v6 的 binding** | 板级 DTS 只用 v6 定义的 `qcom,sm8750-camss` |

**未证项（不得当结论用）**：① 1/9 与 v6 2/7 的 binding 属性差异未逐条核对；② 8/9 与 v6 6/7 的符号级差异未逐条核对（仅比规模与文件名）；③ `80dd5911cb` / `2482c6f93a` 的原文未取到（本地 shallow）。

---

## §2 SKEW_CAL 表述（必须改，否则评审当场打回）

已证：上游 `camss-csiphy-3ph-1-0.c` 的 `case CSIPHY_SKEW_CAL:` 分支**直接 `continue`，不写寄存器**
（本地 master 快照 `up-csiphy-master.c:1099-1100`；我方树上同位置为 `:1216-1217`）。

⇒ 我方原句「0x54 vs 0x00 上机 A/B 无可测差异」**不是证据**（结构上就不可能测出差异）。可直接进 commit message 的改写：

```
The CSIPHY_SKEW_CAL entry is inert in the current driver (the switch arm
continues without programming the register), so the value carried in the
SM8750 table is documentation of the vendor setting, not a behavioural
change. It is kept so the table matches the downstream description.
```

---

## §3 下一步（按顺序）

1. **先把 4 枚独立小修投出去**（2/9 csiphy 2.4.0 + 6/9 + 7/9 + 3/9），新线程、无 `Depends-on`：
   这 4 枚与 Qualcomm/Bryan 的任何在审系列都不冲突，是唯一现在就能推进的部分。
2. **给 Bryan 系列补一枚 `sm8750` 的 `frame_sync_en` 增量**（在 14/14 之后追加），而不是自己再发 SOF 实现。
   前提：等他的系列落地或至少被接受方向；**本批不发**。
3. **9/9 DTS 挂 `Depends-on:` 等 v6**；binding 用 v6 那份，我方 1/9 撤回（patchwork 需人工标 superseded，agent 不操作）。
4. 8/9 的独有符号（若有）并入 v6 的后续增量，不单独成系列。
5. 我方 v2 剩余 5 枚（1/4/5/8/9）在 patchwork 上维持 `new`，等 v6 进展后一并重投或撤回。

---

## §3b ★2026-11-02 收尾更正：§3 第 1 条的「4 枚可先投」**只有 3 枚成立**

- **3 枚已于 2026-10-29 投出并归档**：`patches/upstream/m4-camss-fixes-20261029/`（`[PATCH 0/3] three fixes for the CSID power and VFE streaming paths`，
  MID `20261029123107.28705-1..4`，lore `/all/` 4/4）。逐枚对位 = csid power-on unwind / video DMA 连续性 + `prepare_buffer` 钩子 / video 起流失败回退。
  ⇒ §3 第 1 条写成「待投」是**与 10-29 已投事实脱节**，本轮更正。
- **第 4 枚（2/9 csiphy 2.4.0 lane 表）不是独立小修**：在公开 `6628e7d4c6`(v7.4-rc1) 上它**树内无使用者** ——
  `camss.c` 无任何 SM8750 `camss_resources` 表项（`grep -c 8750` = **0**），`CAMSS_8750` 因此永不被赋值，
  新表只死在 `csiphy_init()` 的 `switch` 里。⇒ 与 M6 B5 v2 是同一个「who uses it」问题，**不能自成线程**。
  正确落点 = 挂 Hangxiang `[v6 0/7]` 线程（其 SoC 使能被接受后作为增量/回帖），本批不发。
  已重切并过门禁备料：`patches/upstream/camss-csiphy-24-20261102/`（+125 −0，`checkpatch --strict` 0E/0W/0C，
  `W=1` camss 编译 rc=0 / 0 warning，见其 `GATES.md`）。

⇒ **camss 侧当前无「可立即投」的件**；M4 的推进完全取决于 Hangxiang v6 与 Bryan SOF 系列的走向。

---

## §4 复跑命令

```bash
cd /tmp/camss-up
python3 - <<'PY'
import json; d=json.load(open('coverage.json'))
for k,v in d.items():
    for p in v: print(k, p['subj'][:80], '|', p['total'])
PY
# Qualcomm v6 全文（7 枚）
curl -s --max-time 25 "https://patchwork.kernel.org/api/1.2/series/1131656/mbox/" -o hx-v6.mbox
# Bryan SOF/EOF 14 枚
curl -s --max-time 25 "https://patchwork.kernel.org/api/1.2/series/1196135/mbox/" -o bryan-sof.mbox
# 我方 v2 9 枚
curl -s --max-time 25 "https://patchwork.kernel.org/api/1.2/series/1195271/mbox/" -o our-v2.mbox
# 三方三态
curl -s --max-time 25 "https://patchwork.kernel.org/api/1.2/series/1195271/" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("patches"))'
```
