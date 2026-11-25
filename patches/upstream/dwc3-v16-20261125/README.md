# dwc3 v16 备料（2026-11-25）——**备料完成，未投递，等放行**

- 触发：**sashiko 2026-11-25T08:29:30Z 对 v15 1/3 的两条 `[Low]`**
  （`dt-bindings: usb: snps,dwc3: incomplete endpoint schema under port@0`、
  `dt-bindings: usb: snps,dwc3: inter-version changelog above tearline`），
  以及同一波 `08:31:24Z` 的系列小结（判 **2/3・3/3 无问题**）。
  原文与判定 = `../../../reports/comm-triage-20261125.md` §2.6、`../../../reports/mobian-phosh-upstream-20261125.md` §2.3 A1；
  处置报告 = `../../../reports/dwc3-v16-20261125.md`。
- 范围：**只重出 1/3**（三处改动见 `GATES-v16.md` §2）；
  **2/3、3/3 与 v15 内容逐字节相同**（`cmp` diff 段静默 + `git patch-id` 相同；
  整文件只剩 `From`/`Date`/`Subject` 三行生成器头部，见 `logs/G5-identity.log`）。
- 收件人：`To: Thinh Nguyen`；`Cc:` **`gregkh` + `linux-usb@vger.kernel.org`**（v15 起已补齐，v16 保持）
  + `robh`/`krzk+dt`/`conor+dt`/`devicetree`/`linux-arm-msm`/`lkml`。**新线程**（无 `In-Reply-To`/`References`）。
- 文件：
  - `v16-0000-cover-letter.patch`（重写：只答这两条 + 明写 2/3・3/3 unchanged；历代 changelog 与 AI 披露段全在 tearline 之下）
  - `v16-0001-…patch`（改）、`v16-0002-…patch`、`v16-0003-…patch`（与 v15 同内容）
  - `SEND.sh`（**默认 dry-run**；真发需显式 `--yes`）、`GATES-v16.md`、`gates/`（正负样例）、`logs/`
- 投递：**未发**（本轮约束：禁止发信）。放行后 `bash SEND.sh`（dry-run）→ `bash SEND.sh --yes`（真发）。
- 回退：本目录整体删除即可（仓内其它文件未改动；验证用 worktree 与 `O=` 构建目录已删，
  `build/elden-tree` 收工时 `status --short` 为空）。

## 与 v15 的差异（一句话版）

| 件 | v15 → v16 |
|---|---|
| 1/3 | **动了三处**：else 分支 `port@0` 补 `$ref: /schemas/graph.yaml#/properties/port`；then 分支 pattern 改 `[2-9a-f]` 组合式；`Changes since v13` 段从 commit message 移到 tearline 之下 |
| 2/3 | **未动**（diff 段 `cmp` 相同，patch-id `5688adec43ea`） |
| 3/3 | **未动**（diff 段 `cmp` 相同，patch-id `60721b9fb7fb`） |
| cover | 重写：首段只讲 sashiko 两条 + 「2/3・3/3 unchanged」；`Testing on hardware`/`Not tested`/`Known gaps` 照抄 v15；新增 `Changes since v15` 节 |

## 一处必须知道的取舍（已按本轮任务单执行，但下一版要收口）

v15 的 cover 承诺「per-patch AI 披露段会在**下一次动这几个文件**时补回 1/3、2/3、3/3」。
v16 动了 1/3，但 2/3・3/3 必须保持逐字节不变 —— **只给 1/3 加披露会让系列内部不一致**，
所以本轮仍按任务单「只改三处」执行，披露**只在 cover**，并在 cover 的 `Changes since v15` 第 4 条如实写明现状。
⇒ 真要在 patch 里补回披露，需要一次**整套重出**（三枚一起加，届时 2/3・3/3 不再是 byte-identical）。

## 另一条：pattern 写法与 sashiko 建议的差异（有意为之，已在 cover 与 1/3 changelog 说明）

sashiko 建议把漏 `endpoint@a`–`@f` 的正则直接写成 `[2-9a-f]`。但 `[2-9a-f]` 只是**单字符**类，
会把 v15 原本能拒的**多字符**单元地址（`endpoint@10` 之类）重新放进来 —— 相对 v15 是能力回退。
本轮取「原正则 ∩ sashiko 建议」的**补集形式**：`'^endpoint@([2-9a-f]|[0-9a-f]{2,})$'`，
它恰好是 `endpoint@0`/`endpoint@1` 在 `graph.yaml` 允许的十六进制单元地址里的精确补集，
两个方向都覆盖。判别过程与证据（含新增 `neg-mux-endpoint-a` 反例）见 `GATES-v16.md` §1 G4。
**若维护者坚持字面 `[2-9a-f]`，v17 只需改 1/3 的那 1 行**（见处置报告「v17 判读」）。
