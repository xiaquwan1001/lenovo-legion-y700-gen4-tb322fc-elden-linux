# elden 板 DTS —— **v9 备料**（2026-11-26，**未投递**，等 §7 逐系列放行）

> 件：`v9-0000-cover-letter.patch` + `v9-0001`（binding 一行）+ `v9-0002`（板件）。
> **只备料**：没有发信、没有 `git commit`、没碰设备、没改 TASKS/README/INDEX。
> 上一代 = `../elden-dts-v8-20261125/`（v8，2026-11-25T09:13Z 已投，cover MID
> `<20261125091309.124354-1-xiaqinghuan@mail.ustc.edu.cn>`）。
>
> ⚠ **目录名歧义速查**：`../elden-dts-v9-prep-20261124/` **不是**本目录的前身 —— 那是**另一条系列**
> （板件的 USB 部分：`sm8750.dtsi` HS port label + 两 usb-c-connector，依赖 dwc3 两连接器 binding）。
> 本目录 = 「qcom.yaml + 板件」这条**主系列**的 v8→v9（只改 cover/changelog 文字）。

## 0. v9 到底改了什么（一句话）

**只改文字，不改补丁内容**：v8 收到 Krzysztof 一条实质写作要求（cover/changelog 必须明写
「waiting on bindings」，别铺墙纸文字）⇒ v9 把这句话提到 cover 的**第一节**并点名依赖，
2/2 的 changelog 也写明同一件事；1/2 与 2/2 的 `diff --git` 段与 v8 **逐字节相同**
（`cmp` 有日志，见 §3）。

| 项 | v8 | v9 |
|---|---|---|
| 1/2 diff | `qcom.yaml` +1 行 | **同**（cmp 相同） |
| 2/2 diff | 板件 129 行 + Makefile 1 行 | **同**（cmp 相同） |
| cover | 长文，"Known dependencies" 里一句带过 WL2868C | **第一节 = "Waiting on bindings"**（点名 binding / 文件 / commit / 树 / 合并顺序 / 提前合入的代价），其余压缩 |
| 2/2 changelog | "Changes in v8"（未提依赖） | 新增 **"Changes in v9"** 逐条写依赖与合并顺序 |
| 依赖表述 | 「WL2868C binding 不在 v7.4-rc3」 | **「本系列在等 willsemi,wl2868c binding；1/2 无依赖可先合，2/2 等它」** |

## 1. 为什么依赖只能写成「等」，不能靠改代码消掉

- 2/2 里 `pmic@2f { compatible = "willsemi,wl2868c"; ... }` 是**真实硬件**（作者本机 i2c10 上
  那颗相机 PMIC），删它 = 丢硬件描述 ⇒ 不能为消诊断而删。
- schema 侧**不是我们的欠账**：binding 已被 Mark Brown 接收，在 `regulator.git for-7.5`
  （`84e67d2ee13f` binding + `602f57223457` driver，merge `0216753490ff`），只是 v7.4-rc3
  基线里还没有 ⇒ 上游读者**确实需要被告知**「这条诊断是已知的、会自己消失的」。
  这正是 Krzysztof 要求的写法。

## 2. 收件人/线程（沿用 v8，未发）

`bash SEND.sh`（默认 dry-run）→ 放行时 `bash SEND.sh --send`。
To = `andersson@`(Bjorn) + `konradybcio@`(Konrad)；Cc = `abelvesa@`、`mitltlatltl@`(Pengyu)、
`robh@`、`krzk+dt@`、`conor+dt@`、`devicetree@`、`linux-arm-msm@`、`linux-kernel@`（= v8 现查结果）。
**新线程**（无 `In-Reply-To`/`References`），cover 里给出 v8 的 lore URL 作指引 —— 与 v8/v16 同口径。

## 3. 门禁（2026-11-26 现跑；基线 = `build/elden-tree` worktree `aebb727447` = v7.4-rc3）

| 门 | 命令要点 | 结果 | 日志 |
|---|---|---|---|
| G0 apply | `git apply --check -v` ×2 | rc=0，**无 offset 无 fuzz** | `logs/apply-check-verbose-20261126.txt` |
| G1 落树 | `git apply` ×2 + `git hash-object` | `qcom.yaml a32cfb30a1` / `Makefile e0b65a36c5` / 板件 `73f4452f46` = patch `index` 右值 | — |
| G2 与 v8 同内容 | `awk 'diff --git→' 后 `cmp`` | 1/2、2/2 **diff 段逐字节相同** | — |
| G3 checkpatch | `--no-tree --strict --no-signoff - < patch`（**stdin**） | 1/2 **0E/0W/0C**（7 行）；2/2 **0E/1W/0C**（136 行，唯一 warning = 新文件 MAINTAINERS 提示） | `logs/checkpatch-v9-000{1,2}.txt` |
| G4 dt_binding_check 全量 | `O=/tmp/v9build dt_binding_check`（不带 `DT_SCHEMA_FILES`） | **rc=0**，0 error/warning，`DTC [C]` **5420** | `logs/dt-binding-check-full-20261126.log`（摘要） |
| G5 dt_binding_check 定向 | `DT_SCHEMA_FILES=…/arm/qcom.yaml` | **rc=0**，静默 | `logs/dt-binding-check-qcomyaml-20261126.log` |
| G6 dt-doc-validate | `dt-doc-validate …/arm/qcom.yaml`（1.7.x 工具，直调） | **rc=0** | 同上（无输出） |
| G7 dtbs_check | `CHECK_DTBS=1 … sm8750-{lenovo-elden,mtp,qrd}.dtb` | 3/3 `DTC [C]`；诊断 **elden 1 / mtp 0 / qrd 0** | `logs/dtbs-check-3dtb-20261126.log` |
| G8 依赖消长（关键） | 落树后再 apply `wl2868c-v12` 1/2（binding），重跑 G7 | **elden 诊断 0**、mtp/qrd 0 ⇒ §0 的「等 binding」是**实测**而非说法 | `logs/dtbs-check-3dtb-with-wl2868c-binding-20261126.log` |
| G9 上机 | — | **未做**：板件未在真机跑过 v7.4-rc3，cover 不作启动声明 | — |
| G10 发信前断言 / dry-run | `bash SEND.sh`（local）→ `--dry-run` | local **rc=0**（六段断言全中，`Waiting on bindings` 在第 12 行）；dry-run **rc=0**，3 封 `Result: OK`，RCPT 11 地址 | `logs/local-checks-20261126.txt`、`logs/dry-run-20261126-065602.txt` |
| G11 `git am` 路线交叉验证 | `git am --keep-cr` ×2 + defconfig + 编单 dtb | **2/2 干净**；DTB md5 `4707d3de…` **与 G7 逐字节相同** | `logs/am-apply-and-build-20261126.txt` |

> 唯一那条诊断原文（= cover 里引用的同一条，逐字）：
> `sm8750-lenovo-elden.dtb: /soc@0/geniqup@8c0000/i2c@888000/pmic@2f: failed to match any schema with compatible: ['willsemi,wl2868c']`

## 4. 未做 / 边界

1. **未投递**，未 `git send-email`，未改订阅。
2. `dtb md5` 本目录记了值（`logs/dtb-md5-20261126.txt`），但**不与 `elden-dts-v9-prep-20261124`
   的 `2d2d…` 比对**：那轮的树额外带了 dwc3 binding + USB 补丁（改了 `sm8750.dtsi` 与板件），
   不是同一配置，比了会得出错误结论。
3. 未重跑 v8 的两条**负样例**（去掉 1/2 后根节点不合法）—— 它们测的是 binding 行是否必需，
   与 v9 文字改动无关；v8 记录继续有效（`../elden-dts-v8-20261125/logs/dtbs-check-no-binding-entry-20261125.log`）。
4. 临时 worktree `/tmp/v9wt`、`O=/tmp/v9build` 属一次性，**不入库**；重放命令见 `GATES.md`。

## 5. 文件清单

| 文件 | 内容 |
|---|---|
| `v9-0000-cover-letter.patch` | cover（**§"Waiting on bindings" 在第一节**；v8→v9 changelog 在 tearline 之下） |
| `v9-0001-…-Y700.patch` | `qcom.yaml` +1 行（= v8 1/2，仅代次/日期） |
| `v9-0002-…-Gen4.patch` | 板件（= v8 2/2；仅新增 "Changes in v9" 段与代次） |
| `CHANGES-v8-to-v9.md` | v8→v9 逐条改动说明（含「谁提的、落在哪一行」） |
| `RESPONSE-krzk-sashiko.md` | 对 Krzysztof + sashiko 两条 [Medium] 的逐条回应与落点 |
| `GATES.md` | 门禁账 + 复现命令 + 原始输出摘要 |
| `SEND.sh` | dry-run/真发脚本（含「cover 必含 waiting-on 段」断言） |
| `logs/` | 12 份门日志（含 dry-run、本地断言、`git am` 交叉验证） |
| `SHA256SUMS` | 本目录全部件 sha256 |
