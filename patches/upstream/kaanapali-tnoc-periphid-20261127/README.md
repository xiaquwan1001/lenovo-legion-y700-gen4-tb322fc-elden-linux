# ⛔ SUPERSEDED —— kaanapali TNOC periphid 草稿（2026-11-27）：**不要投递**

> 结论：缺口真实存在，但**上游已有一模一样的投递**（kaanapali + sm8750 都覆盖），
> 且另一条已被收进 `next` 的路线会把这行改掉。按任务第 5 条「停手 + 否证证据」处置：
> 本目录只作留档，**SEND.sh 已改为硬拒绝**。证据与判据全在
> `reports/kaanapali-tnoc-periphid-20261127.md`。

## 1. 缺口（真）

`arch/arm64/boot/dts/qcom/kaanapali.dtsi:5416` 的 `tn@111b8000` 与 sm8750 同型：
`compatible = "qcom,coresight-tnoc", "arm,primecell";` 但**没有** `arm,primecell-periphid`。
`build/elden-tree`（7.4-rc3）与 `build/daily`（4da9a8b69fc85）两棵树都是 0 命中
（`rg -n 'primecell-periphid' …/kaanapali.dtsi` → 空）。

## 2. 为什么停手（三条，任一即足以停）

| # | 事实 | 证据 |
|---|---|---|
| 1 | **同型补丁已于 2026-11-18 投过**：`[2/4] arm64: dts: qcom: kaanapali: add periphid for traceNoC`（id 14995781），改动 = `tn@111b8000` 加 `arm,primecell-periphid = <0x000f0c00>;` | `logs/patchwork-dupcheck.log` |
| 2 | 同系列 `[3/4]` 就是 **sm8750 同名补丁**（id 14995782）、`[1/4]` 就是 binding 放宽（id 14995780）⇒ 我们 2026-11-27 已投的 sm8750 v1 与之重复 | 同上 |
| 3 | 该系列 DT 两封已获 **Abel Vesa（2026-11-20）+ Konrad Dybcio（2026-11-25）Reviewed-by**；同时竞争的 v7 系列（改平台总线绑定）**已在 `next`**（`[v7,3/5] kaanapali`、`[v7,4/5] sm8750` 均 state=`in-next`） | 同上 |

即：我们的 kaanapali 补丁与 14995781 同实质（同一行、同一值），投出去只会被当重复件；
而 v7 一旦落主线，`arm,primecell` 会从该节点消失，这行 property 也随之无意义。

## 3. 目录内容（留档）

| 文件 | 说明 |
|---|---|
| `v1-0000-cover-letter.patch` | `[PATCH 0/1] arm64: dts: qcom: kaanapali: describe the TNOC AMBA periphid`（**未投递**） |
| `v1-0001-arm64-dts-qcom-kaanapali-describe-the-TNOC-AMBA-periphid.patch` | `git format-patch` 产出，`git am` 逐字可装（已实测，见 `GATES.md`） |
| `GATES.md` | 四道门原始输出（checkpatch / dtbs_check 正反对照 / dt_binding_check / dup-check） |
| `SEND.sh` | **硬拒绝**（默认即拒绝，无 `--yes` 通路） |
| `logs/` | 上述门的原始日志 |

## 4. 基线

`build/elden-tree` HEAD `aebb72744764`（Linux 7.4-rc3，干净）；发件树 = `git worktree /tmp/kn-wt`。
`build/daily` HEAD `4da9a8b69fc85` 同缺，`build/daily` 工作区里的 sm8750 本地版只是注释差异。

## 5. 若要重新捡起（父级决定后）

- 若上游最终选 periphid 路线（14995780-14995782 合入），**不需要**本目录任何东西 —— Jie Gan 的三封已覆盖。
- 若选平台总线路线（v7 已在 `next`），则 kaanapali 的活是 `[v7,3/5]` 已做完的事，同样不需要本目录。
- 唯一还空的缝隙：本机内核（7.3.1 树）上的**本地**规避 —— 见报告 §5。
