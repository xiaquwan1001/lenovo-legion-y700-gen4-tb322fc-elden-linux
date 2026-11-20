# #696 `make dtbs_check DT_SCHEMA_FILES=<yaml>` 对**没有 `select:` 的公共片段**恒空转（假绿）

<!-- created=2026-11-21 -->

## 判据（一句话）

`scripts/Makefile.dtbs` 把 `DT_SCHEMA_FILES` 翻成 `dt-validate -l <yaml>`；`-l/--limit` 只保留
「`$id` 命中 LIMIT」的 schema，而**一个 schema 要落到节点上仍然需要它自己的 `select:`**。
公共片段（如 `snps,dwc3-common.yaml`、`*-common.yaml`、`/schemas/graph.yaml`）**没有 `select`**
⇒ limiter 之后零节点匹配 ⇒ **零诊断**，看起来和「全绿」一模一样。
（对照：`qcom,snps-dwc3.yaml` 一类 glue schema 有 `select: compatible contains …`，改成它才真的会跑，
但那样又只覆盖这一个 vendor 的 glue，覆盖不到公共片段的条件分支。）

## 处置

- **判绿**一律用 **`make CHECK_DTBS=1 -j8 <相对 dtstree 的 dtb>`**，**不要**带 `DT_SCHEMA_FILES`（走 `-m`，
   由各 vendor glue schema 的 `$ref` 把公共片段拉进来，条件分支才生效）。
- **rc 不能作判据**：`scripts/Makefile.dtbs` 的 `cmd_dtb_check` 末尾带 `|| true` ⇒ rc 恒 0；
   只能数 `^arch/…\.dtb:` 开头的诊断起始行（后续缩进行不算）。
- **目标路径**必须相对 dtstree（写 `arch/arm64/boot/dts/...` 会被 `%.dtb` 规则再拼一次 `$(dtstree)`）。
- **改了 binding yaml 后** `processed-schema.json` **不会**被 `dtbs_prepare` 重建 ⇒ 换 schema 复测先
   `rm -f Documentation/devicetree/bindings/processed-schema.json` 再 `make CHECK_DTBS=1 dt_binding_schemas`。
- **自检门是否真跑**：造一个必然违反的样例（本例：两个 endpoint 都写 `mux-state = <0>`，或删 `mux-controls`
   而保留 endpoint 的 `mux-state`），确认出现诊断行；不出现就是空转。

## 证据与指针

- 对照实验（同一份坏样例，两种形状）：`patches/upstream/dwc3-v10-20261120/README.md` §4
  （`-l` 0 行 vs `-m` 多条）；真板 DTB A/B（加之前/之后/两个负样例）同文件 §7.3，
  日志 `patches/upstream/dwc3-v10-20261120/elden-dts/gate-*.log`。
- 2026-11-21 实测：上一轮子代理正是只看 `.dtb.cmd` 里出现 `dt-validate -l …` 就判「schema 跑了」，
  结论作废；换成不带 `DT_SCHEMA_FILES` 后，同一 DTB 才暴露出真实约束。
