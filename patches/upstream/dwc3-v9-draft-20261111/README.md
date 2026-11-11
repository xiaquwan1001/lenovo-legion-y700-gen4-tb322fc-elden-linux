# dwc3 v9 binding 返工草案（DRAFT，未发送）

> 依据：Rob Herring 2026-11-10 16:36:40Z 对 `[PATCH v8 0/3]` 的回信
> `<20261110163640.GA85824-robh@kernel.org>`（原文见 `out/mail-20261111/robh-20261110T1636Z-raw.txt`）。
> **本轮零投递**：本目录只有草案 + 门禁日志，未跑 `git send-email`，也未经用户批准。

## 1. Rob 的两条意见（原文字节）

```
> 		port-select-gpios = <&tlmm 29 GPIO_ACTIVE_HIGH>;

Use the gpio mux binding.

...
ports are for separate data streams. Endpoints are for mux'ed data 
streams. This looks like the latter, so port@0 should have 2 endpoints 
and port@2 dropped.
```

## 2. 「Rob 意见 ↔ v8 yaml 行号」差异表

行号口径：**v8 yaml** = 上游 pristine（`build/m3v2-7.3rc7` 的
`Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml`，432 行）**打上已发出的
`v8-0001-…patch` 之后**的 544 行版本（= 评审者看到的正文）；**v9 草案** = 本目录
`snps,dwc3-common.v9.yaml`（同基线的 544 行重写版）。

| # | Rob 意见 | v8 yaml 位置（原文） | v9 草案处置 | v9 草案行号 |
|---|---|---|---|---|
| R1 | `port@2` 删掉，`port@0` 放 **2 个 endpoint** | `:77-80` 注释「so two connectors are two ports, not two endpoints of one port … the second High Speed connector lands on port@2」（**被 Rob 直接否掉的那句**）；`:81` `required: [port@0, port@2]`；`:83-86` `port@0/port@2: $ref hs-port`；`:92,101,108,117` 两个 `oneOf` 分支里的 `port@2` | `hs-port` 改为「一个 port 两个 endpoint」：`required: ['#address-cells','#size-cells', endpoint@0, endpoint@1]`，`endpoint@0/endpoint@1` 各带 `reg`；`ports` 只保留 `port@0`（HS，两个 endpoint）+ `port@1`（SS），`port@2` 全线删除 | `:42-92`（`hs-port`）、`:108-125`（mux 分支只 `required: [port@0]`）、`:530-537`（`ports` 下 `port@0/port@1`） |
| R2 | `port-select-gpios` → 用 **gpio mux binding** | `:136-142` `port-select-gpios: maxItems 1` + 描述；`:64` `if: required: [port-select-gpios]`；`:29-36` `mux-state` 描述写成「port-select GPIO 的电平」 | 删除私有 GPIO 属性，改 `mux-controls: maxItems 1`（phandle 指向 `compatible = "gpio-mux"` 的 mux controller，`#mux-control-cells = <0>`）；`if: required: [mux-controls]`；`mux-state` 语义改为「mux controller 的 state」 | `:139-146`（`mux-controls`）、`:108`（`if` 条件）、`:29-40`（`mux-state` 描述） |
| R3（连带） | — | `:46-48` `patternProperties: '^endpoint(@[0-9a-f]+)?$'`（sashiko M2 曾批过编号 pattern） | 编号 endpoint 现在是**硬要求**（`endpoint@0/endpoint@1` 显式声明 `required: [reg]`），不再用 pattern 放开任意编号 ⇒ 顺带消化 sashiko M2 | `:57-68` |
| R4（连带） | — | `:29-36` 只说「两个 connector 必须不同电平」，无 schema 强制 | 仍保留 `oneOf` 互斥（两个 endpoint 的 `mux-state` 必须一 0 一 1），但作用对象从两个 port 变成同一 port 的两个 endpoint | `:70-92` |

**driver 侧连带（未做）**：3/3（`drivers/usb/dwc3/drd.c`）现在用 `gpiod_get` + `gpiod_set_value`
驱动 `port-select-gpios`，`usb_role_switch_at_endpoint()` 按 endpoint 找 role-switch。换 mux 后需要：
`devm_mux_control_get(dev, NULL)` + `mux_control_select(mux, endpoint->mux_state)`，
并把 `dwc3_role_mux_init()` 的 GPIO 描述符成员替换成 `struct mux_control *`。**本轮未改 driver / DTS。**

## 3. 门禁（本轮实跑，日志在 `gates/`）

树 = `build/m3v2-7.3rc7`（基线 `24a19b953e2a`），做法 = 把草案 yaml 临时放到树的
`Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml`，跑完 `git checkout --` 还原
（还原后 `git status --porcelain` 为空，已核实）。

| 门 | 命令 | 结果 | 日志 |
|---|---|---|---|
| G1 | `dt-doc-validate --verbose <fd>` | **rc=0**，无输出 | `gates/dt-doc-validate.log` |
| G2 | `make dt_binding_check DT_SCHEMA_FILES=<fd>` | **rc=0**，`SCHEMA/CHKDT/LINT/STYLE` 四段无诊断 | `gates/dt-binding-check.log` |
| G3 | `dt-validate -s processed-schema.json` on **正样例**（`port@0` 双 endpoint + `mux-controls` + gpio-mux 节点） | **PASS**：只报 root-node 缺 `compatible`/`model`（测试 harness 的无关噪声），`usb@a600000` 无任何诊断 | `gates/dt-validate-pos.log`、`gates/pos.dts` |
| G4 | 同上，**负样例①** 两个 endpoint `mux-state` 都 = 0 | **被拒**：`ports:port@0: 'oneOf' conditional failed` | `gates/dt-validate-neg-same-state.log` |
| G5 | 同上，**负样例②** 只留 `endpoint@0` | **被拒**：`ports:port@0: 'endpoint@1' is a required property` | `gates/dt-validate-neg-one-endpoint.log` |
| G6 | 同上，**负样例③** legacy v8 形状（`port@0` 单 endpoint + `port@2` + `port-select-gpios`） | **被拒**：`'#address-cells' is a required property` / `'#size-cells'` / `oneOf` 均报 | `gates/dt-validate-neg-legacy-v8.log` |

- 未跑：checkpatch（草案没有代码 hunk，只有 yaml）、`make W=1` 编译（未改 driver）、
  pristine `git am` 重放（需要 driver/DTS 一起成型才有意义）。
- 已知遗留：`snps,dwc3-common.yaml` 是 common schema（无 `select`/无 `examples`），
  所以正/负样例只能走「真 dts + dtc + `dt-validate -s processed-schema.json`」这条链，不能靠
  binding 自带 example；上面 G3–G6 就是这条路。

## 4. 文件清单

| 文件 | 说明 |
|---|---|
| `snps,dwc3-common.v9.yaml` | v9 草案全文（544 行） |
| `v9-0001-dt-bindings-usb-snps-dwc3-two-connectors-one-hs-bus.patch` | 相对**上游 pristine** 的草案补丁（`git diff --no-index` 生成，+118/−2） |
| `gates/` | 上面 6 个门的原始日志 + 4 个测试 dts/dtb |

## 5. 未做 / 下一步

1. driver（3/3）与 DTS（2/3）未改 —— v9 要三件一起改才能过 `make W=1` 与实机。
2. 未做 `mux_control` 在 dwc3 里的路径确认（`drivers/usb/dwc3/drd.c` 现状 vs `mux_control_select`
   的锁语义：`mux_control_select` 会持锁到 `mux_control_deselect`，role-switch 路径要考虑中断上下文）。
3. 投递需用户按 `TASKS/README.md` §7 逐系列批准；本目录**不构成投递**。
