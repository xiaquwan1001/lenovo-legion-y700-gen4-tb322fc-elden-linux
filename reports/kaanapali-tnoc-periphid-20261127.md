# kaanapali（SM8850）TNOC periphid —— 缺口真、上游已覆盖 ⇒ **停手，不发系列** — 2026-11-27

> lane：上游化（父任务：给 kaanapali 补与 sm8750 同型的 TNOC AMBA periphid 缺口）
> 结论先行：**缺口与上轮判断一致（真缺）**，但 **上游 2026-11-18 已投过一模一样的 kaanapali 补丁**
> （patchwork 14995781，两位维护者已 Reviewed-by），且 **已进 `next` 的 v7 系列把同一行改成平台总线绑定**
> （`[v7,3/5]`）。⇒ 本系列按任务第 5 条处置：**停手，产出否证证据**，草稿留档不投。
> 附带发现（需父级决策）：**我们 2026-11-27 已投的 sm8750 periphid v1 也是重复件**（14995782 / 14995780）。

## §1 缺口属实（源码证据）

树 1 = `build/elden-tree` @ `aebb72744764`（Linux 7.4-rc3，工作区干净）；树 2 = `build/daily` @ `4da9a8b69fc85`。

```
$ rg -n -A4 'tn@111b8000' build/elden-tree/arch/arm64/boot/dts/qcom/kaanapali.dtsi
5416:		tn@111b8000 {
5417-			compatible = "qcom,coresight-tnoc", "arm,primecell";
5418-			reg = <0x0 0x111b8000 0x0 0x4200>;
5419-
5420-			clocks = <&aoss_qmp>;

$ rg -c 'primecell-periphid' build/elden-tree/arch/arm64/boot/dts/qcom/kaanapali.dtsi   # 0
$ rg -c 'primecell-periphid' build/daily/arch/arm64/boot/dts/qcom/kaanapali.dtsi        # 0
$ rg -c 'primecell-periphid' build/elden-tree/arch/arm64/boot/dts/qcom/sm8750.dtsi      # 0（sm8750 在 7.4-rc3 也仍缺）
```

- 节点位于 `arch/arm64/boot/dts/qcom/kaanapali.dtsi:5416`（sm8750 是 `:5174` 的 `tn@109ab000`）。
- kaanapali.dtsi 里 STM/TPDM/TPDA/funnel 一律**没有** `primecell-periphid`（`rg -c` = 0），
  说明该 SoC 正常 AMBA 器件的 PID/CID 读得出来；**只有 Aggregator TNOC 是特例**（CID 读回 0，见 §3）。
- 驱动侧表项不变：`drivers/hwtracing/coresight/coresight-tnoc.c:258` `trace_noc_ids` =
  `0x000f0c00` / `0x001f0c00`，`mask 0x00ffff00`；`0x000f0c00` 命中该表（`0x0f0c00 & 0xffff00 == 0x0f0c00`）。
- binding 侧未覆盖：7.4-rc3 的 `Documentation/devicetree/bindings/arm/qcom,coresight-tnoc.yaml` 仍是
  `additionalProperties: false` 且无 `$ref: /schemas/arm/primecell.yaml#`（所以 DT 单改过不了门，见 §2 负对照）。

## §2 门禁（草稿本身全绿；原始输出 = `patches/upstream/kaanapali-tnoc-periphid-20261127/logs/`）

| 门 | 结果 |
|---|---|
| `checkpatch.pl --strict` DT 封 | `0 errors, 0 warnings, 0 checks, 7 lines checked`（rc=0） |
| `checkpatch.pl --strict` 封面 | `0 errors, 0 warnings, 0 checks`（rc=0） |
| `dtbs_check` **负对照**（不打 binding） | 两 DTB 各 1 条：`'arm,primecell-periphid' does not match any of the regexes: '^pinctrl-[0-9]+$'` |
| `dtbs_check` **正对照**（apply sm8750 v1-0001 binding） | rc=0，**无诊断**（`kaanapali-mtp.dtb` / `kaanapali-qrd.dtb`） |
| `dt_binding_check`（本 yaml） | rc=0（CHKDT / LINT / STYLE / DTEX / DTC 全过） |
| `git am`（干净 worktree @ `aebb72744764`） | rc=0，作者/Subject 保真（封面无 diff，`git am` 报「补丁为空」属正常） |
| dup-check（patchwork project=92） | **命中同型投递** → 见 §3 |

槽位：`build-slot take y700-elden:kaanapali-tnoc --jobs 4` → id `202752-3498977-y700-elden_kaanapali-tnoc`，收工已 drop。
基线选择说明：上一轮 sm8750 系列以 `build/daily`（7.3.1 + payload）为基线；本轮改用**纯上游 7.4-rc3**
（`build/elden-tree`），因为这是对外补丁的合法基线，且 `.config` 只需 `defconfig`。

## §3 否证证据：上游已有同型投递（为什么停手）

patchwork API（`https://patchwork.kernel.org/api/1.2/`，project=92 linux-arm-msm）原始记录 =
`patches/upstream/kaanapali-tnoc-periphid-20261127/logs/patchwork-dupcheck.log`。

**A. 与我们草稿同实质的已在投系列**：`[0/4] Fix the TraceNoC probe issue on QCOM platform`（2026-11-18，Jie Gan）

| patch | 内容 | state | 关键证据 |
|---|---|---|---|
| 14995780 `[1/4] dt-bindings: arm: coresight-tnoc: Allow arm,primecell-periphid` | 同我们 sm8750 v1-0001（+primecell `$ref`、改 `unevaluatedProperties`） | handled-elsewhere | 正文与我们的 1/2 逐句同义 |
| **14995781** `[2/4] arm64: dts: qcom: kaanapali: add periphid for traceNoC` | `tn@111b8000` 加 `arm,primecell-periphid = <0x000f0c00>;` | new | **Abel Vesa 2026-11-20 + Konrad Dybcio 2026-11-25 双 Reviewed-by** |
| 14995782 `[3/4] arm64: dts: qcom: sm8750: add periphid for traceNoC` | 同我们已投的 sm8750 2/2 | new | 同上双 R-b |
| 14995783 `[4/4] glymur: use Aggregator TNOC compatible` | glymur 换 compatible + periphid | new | — |

该系列 cover 自述：*"This is an alternative to the series that fixes the same problem by moving the traceNoC
onto the platform bus instead of AMBA."* ⇒ 上游明确把它当作**备选路线**，不是没人做过的缺口。
其 kaanapali 补丁 diff（14995781）与我们草稿的差异只有 property 落点（他们放在 `clock-names` 之后、
`in-ports` 之前；我们在 `reg` 之后），属性与值完全相同（`<0x000f0c00>`）。

**B. 已进 `next` 的另一条路线**：`[v7,0/5] Fix traceNoC probe issue on multiple QCOM platforms`（2026-11-10）

| patch | 内容 | state |
|---|---|---|
| 14966084 `[v7,1/5] dt-bindings: … Bind on platform bus instead of AMBA` | 去掉 `arm,primecell`，单 `qcom,coresight-tnoc` 平台 compatible（Krzk R-b） | **in-next** |
| 14966085 `[v7,2/5] coresight: tnoc: Bind Aggregator TNOC on the platform bus` | 驱动加平台 match + ATID 判定改按 compatible（Leo Yan R-b） | **in-next** |
| **14966086 `[v7,3/5] arm64: dts: qcom: kaanapali: bind traceNoC on the platform bus`** | kaanapali 节点去掉 `"arm,primecell"`（Konrad R-b） | **in-next** |
| 14966087 `[v7,4/5] arm64: dts: qcom: sm8750: …` | sm8750 同改 | **in-next** |
| 14966088 `[v7,5/5] glymur: use Aggregator TNOC compatible` | glymur 换 compatible | **in-next** |

**含义**：v7 若先落主线，`arm,primecell` 会从 kaanapali/sm8750 的 `tn` 节点消失，`arm,primecell-periphid`
随之失去作用——我们的（以及 14995781 的）periphid 补丁会变成死行并与 v7 同一行冲突。
**两条路线都在上游台面上、都由维护者 review 过；这个裁决不归本 lane。**

## §4 SM8850（kaanapali）↔ SM8750 对照表

| 项 | SM8750（`sm8750.dtsi`） | SM8850（`kaanapali.dtsi`） | 判 |
|---|---|---|---|
| TNOC 节点 | `tn@109ab000`（:5174，7.4-rc3） | `tn@111b8000`（:5416，7.4-rc3） | 同型 |
| `compatible` | `"qcom,coresight-tnoc", "arm,primecell"` | 同 | 同型 |
| `reg` 大小 | `0x4200` | `0x4200` | 同 IP |
| 时钟 | `<&aoss_qmp>` / `apb_pclk` | 同 | 同型 |
| `arm,primecell-periphid` | **缺**（`rg -c` = 0） | **缺**（`rg -c` = 0） | 同缺 |
| in/out-ports 结构 | `in-ports` port@0..；`out-ports` 单 port | 同结构，**端口清单不同**（端口更多：port@8/0xd/0x10/0x15/0x22…） | 形态同、内容异 |
| 驱动匹配值 | `0x000f0c00`（表项 `mask 0x00ffff00`） | 同一张表（按 IP，不按 SoC） | 同值可用 |
| 硬件实测（CID=0） | ✅ 实测（vk194/195/196）：`AMBA_ID=00000000`，加后绑定 `coresight-trace-noc`，未绑定 28→0 | ❌ **无 SM8850 单元可测** | 证据强度不同 |
| 上游补丁状态 | 14995782（periphid，R-b）/ `[v7,4/5]`（平台总线，in-next） | 14995781（periphid，R-b）/ `[v7,3/5]`（平台总线，in-next） | 都已覆盖 |

## §5 遗留（需上机 / 需父级决定）

1. **需 SM8850 硬件才能核的两项**：① `tn@111b8000` 的 `AMBA_ID` 是否也读回 `0x00000000`
   （判据：`cat /sys/bus/amba/devices/111b8000.tn/uevent` → `AMBA_ID=00000000`）；
   ② `arm,primecell-periphid = <0x000f0c00>` 后是否绑到 `coresight-trace-noc`
   （判据：`readlink /sys/bus/amba/devices/111b8000.tn/driver`）。**本仓无该型号单元，本轮无法提供。**
   若 v7 路线先落主线，则①的判据换成「`11b8000.tn` 是否出现在 `/sys/bus/platform/devices/` 并绑到
   `coresight-tnoc`」。
2. **父级决策（本 lane 不自行决定）**：我们 2026-11-27 已投的 sm8750 periphid v1（3 × 250，
   MID `<20261127113158.932414-1-…>`）与 14995780/14995782 重复、且与 `in-next` 的 `[v7,4/5]` 同行冲突。
   可选动作：等 v7 落主线后回帖自认 superseded；或直接在原 thread 说明选择哪条路线。
3. **本机不受影响**：我们的机器是 TB322FC/sm8750，线上内核是 vk196（已带 sm8750 periphid 本地版）；
   kaanapali 与本机运行无关，本任务纯上游贡献。若日后本机回到 `arm,primecell` 形态被 v7 改掉，
   本地 DTS 需同步换成平台总线 compatible（`build/daily` 工作区那行注释版届时作废）。
4. **draft 去留**：`patches/upstream/kaanapali-tnoc-periphid-20261127/` 保留为留档，`SEND.sh` 硬拒绝（rc=1）。
   若父级判定要投，必须换新 diff（路线二选一）并重跑门禁，本目录不可直接复用。

## §6 产物

- `patches/upstream/kaanapali-tnoc-periphid-20261127/{README.md,GATES.md,SEND.sh,v1-0000-cover-letter.patch,v1-0001-*.patch}`
- `patches/upstream/kaanapali-tnoc-periphid-20261127/logs/`：`checkpatch-v1-0000-cover.log`、
  `checkpatch-v1-0001.log`、`dtbs_check-1-without-binding-patch.log`、`dtbs_check-2-with-binding-patch.log`、
  `dt_binding_check.log`、`git-am.log`、`patchwork-dupcheck.log`
- 发件工作树 `/tmp/kn-wt`（`build/elden-tree` worktree @ `aebb72744764`，提交 `4e5193b9f63f`）、
  `git am` 验证树 `/tmp/kn-am`；两处均为临时 worktree，可随时 `git worktree remove`。
