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

## 追加（2026-11-21 第二轮）：门绿 ≠ 驱动语义对，DT 属性也可能整类不可校验

同一道门在 elden DTS 上的一轮实战，补四条**与本条同源**的判据（细节与日志
`patches/upstream/dwc3-v10-20261120/README.md` §8）：

- **`gpio-mux` 在 probe 就把 mux 线驱成 state 0**，且 **DT 侧无任何写法能改**：
   `devm_gpiod_get_array(dev, "mux", GPIOD_OUT_LOW)`（`drivers/mux/gpio.c:66`）是硬编码；
   `idle-state` 只影响 `mux_chip_register`（`core.c:180-183`，默认 `AS_IS == cached` ⇒ 跳过）与
   `mux_control_deselect`（`core.c:491-493`），**probe 路径一次都不用它**。要「request 时不改方向/电平」
   只能是 `GPIOD_ASIS`（`include/linux/gpio/consumer.h:44-52`、`drivers/gpio/gpiolib.c:5092-5095`），
   = 改驱动 + 改 `gpio-mux.yaml`（`additionalProperties: false`）。
- **pinctrl 不驱也不释放 ABL 的电平**（反直觉）：qcom pinctrl 在把 pin mux 到 gpio 功能时，若 OE 已置位
   （输出态）会先把当前引脚电平回写 out 位再切 mux（`drivers/pinctrl/qcom/pinctrl-msm.c:213-232`，注释防 glitch）
   ⇒ `function="gpio"` + 无 output level 的 pinctrl **不改变**引脚电平；真正的改写者是第一次 `GPIOD_OUT_*`
   请求（`pinctrl-msm.c:576-596`）。别用「pinctrl 没写 output 就等于把线放了」推断。
- **给 mux 加非 `MUX_IDLE_AS_IS` 的 `idle-state` 会引入「换口瞬态」**：消费者换口普遍是
   `deselect()` → `select(新)`（例 `dwc3` v10-0003 `:125-127`），中间那一刻真的会驱 idle 状态
   ⇒ 每次 A→B 都先选错一次口。「park 到某状态更干净」的直觉在 `deselect→select` 序列下是错的。
- **`dtbs_check` 对 `gpio-mux` 的 `idle-state` 完全瞎**：`gpio-mux.yaml:38-39` 只写 `default: -1`，
   **无 `$ref`/无 type/无 minimum**（`mux-controller.yaml:78-101` 才是 `int32, minimum: -2`）⇒
   `idle-state = <2>`（1-pin mux 越界）在门里 **0 条诊断**，只有运行时 `mux_gpio_probe` 的
   `invalid idle-state` 能拒。实测四份日志（改前 / `<0>` / 注释-only / `<2>`）**sha256 全等**
   `4cd4ace3…` ⇒ 该属性的任何取值都不会改变门输出。
   **判据推广**：门只覆盖「schema 写了的约束」；写 `default:` 而不给 `$ref`/type 的属性等于没约束，
   想在 DT 侧拦住越界值，先补 binding 的类型与 `minimum`。
