# dwc3 v10（binding 真补丁）门禁账 — 2026-11-20 / 2026-11-21

本目录 = v10 系列。v9 已发原文证据在 `from-v9/`（只读）；门禁编号沿用
`../../reports/dwc3-v10-plan-20261120.md` 的 G1–G7。**本文件只记本轮（补「编译 + dtbs_check」）
实测结果，不重写 G1/G2/G4 的既有一轮结论。**

## 0. 数字结论（本轮）

| 门 | 命令形状 | 结果 |
|---|---|---|
| 补丁→树 blob | `patch -p1` 到 baseline 树 | preimage `6c0b8b65…` → postimage **`5dd032c76ac2139358616a182b482ace73896016`**（与已复核值逐字节一致） |
| G3 `W=1` 编译 | `make W=1 drivers/usb/dwc3/ drivers/usb/roles/` | **rc=0，0 warning**，23 个 `.o`（dwc3 21 + roles 2），`AR …/dwc3/built-in.a` |
| G5 `dtbs_check`（**修正后的正确形状**） | `make CHECK_DTBS=1 qcom/{sm8750-mtp,sm8750-qrd,sm8250-mtp}.dtb`（**不带** `DT_SCHEMA_FILES`） | **rc=0**，3/3 `DTC [C]`，**0 条诊断**；baseline 树同 3 份也是 0 ⇒ 无新增 |
| G6 binding 正/负样例 | `dt-validate -p processed-schema.json`（`-m` 全量匹配） | 正样例 **0 诊断**；负样例 3 类全部被拒（见 §3） |

**关键发现（会改变后续所有 dtbs_check 的写法）**：`make dtbs_check DT_SCHEMA_FILES=<本 binding>`
在本树上是 **空转/假绿**。原因：`scripts/Makefile.dtbs` 把 `DT_SCHEMA_FILES` 传给
`dt-validate -l`，而 `-l` 只保留「`$id` 命中 + 该 schema 自己 `select` 到节点」的检查；
`snps,dwc3-common.yaml` 是**公共片段、没有 `select:`**，于是没有任何节点被它选中 ⇒ 零诊断。
对照实验见 §4。**正确写法 = 不带 `DT_SCHEMA_FILES`**（走 `-m`，按各 vendor schema 的
`select` 匹配，`qcom,snps-dwc3` 等 glue schema 会 `$ref` 本文件，条件分支才真正生效）。

## 1. 用树与 blob 核对

盘上 4 份 1.9 GB 树里，`base-wt` 的 yaml 是 `6c0b8b6`（= 补丁 `index` 左端）；
其余三份（`gate-dwc3`/`dwc3-v10-verify`/`b6-apply` 后期被复核 worker 打过）文件名相同但
blob 为 `81e3561e…`/`57e3c1d9…`/`5dd032c7…`，**不同源**，故本轮以 `base-wt` 就地打补丁为准：

```sh
cd /tmp/base-wt && patch -p1 < .../v10-0001-*.patch    # patching file …/snps,dwc3-common.yaml
cd ~/y700-elden && git hash-object /tmp/base-wt/Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml
# 5dd032c76ac2139358616a182b482ace73896016
```

`base-wt`/`b6-apply` 的 `.git` 是**坏 worktree 元数据**（`build/m3v2-7.3rc7` 已不存在），
`git` 命令一律报 `不是 Git 仓库`；`make` 不受影响。**不要在仓库内建树。**

## 2. G3 `W=1` 编译门（本轮实跑）

配置（`defconfig` + 最小使能，`-j8`、`nice -n 15`、`flock /tmp/pi-heavy-build.lock`、`timeout -k 30 1500`）：

```sh
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
./scripts/config --enable USB --enable USB_DWC3 --enable USB_DWC3_DUAL_ROLE --enable USB_DWC3_QCOM \
                 --enable USB_DWC3_OF_SIMPLE --enable USB_XHCI_HCD --enable USB_GADGET --enable FTRACE \
                 --enable DEBUG_FS --enable MULTIPLEXER
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 -j8 drivers/usb/dwc3/ drivers/usb/roles/
```

```
CONFIG_USB=y CONFIG_USB_DWC3=y CONFIG_USB_DWC3_DUAL_ROLE=y CONFIG_USB_DWC3_QCOM=y
CONFIG_USB_DWC3_OF_SIMPLE=y CONFIG_USB_XHCI_HCD=y CONFIG_USB_GADGET=y
CONFIG_TRACING=y CONFIG_FTRACE=y CONFIG_DEBUG_FS=y CONFIG_MULTIPLEXER=y CONFIG_USB_ROLE_SWITCH=y
…
  CC      drivers/usb/dwc3/core.o  trace.o  host.o  gadget.o  ep0.o  drd.o  debugfs.o
  CC      drivers/usb/dwc3/dwc3-qcom.o  dwc3-qcom-legacy.o  dwc3-of-simple.o  …(19 个 glue 全编)
  AR      drivers/usb/dwc3/built-in.a
RC=0   warnings=0   objs=23
```

坑：`scripts/config --enable TRACING` 是 **no-op**（该符号无 prompt，只被 `FTRACE` `select`），
要覆盖 `trace.o` 必须 `--enable FTRACE`（本轮这么做的；独立复核那轮只写了 `TRACING`，故少了 `trace.o`）。

## 3. G5 + G6（本轮实跑，正确形状）

```sh
# 目标是相对 dtstree 的路径；写成 arch/arm64/boot/dts/... 会被 Makefile:1674 的
# %.dtb 规则再拼一次 $(dtstree)/$@ ⇒ "没有规则可制作目标 arch/arm64/boot/dts/arch/arm64/…"（rc=2）
rm -f arch/arm64/boot/dts/qcom/{sm8750-mtp,sm8750-qrd,sm8250-mtp}.dtb
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j8 \
     qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb qcom/sm8250-mtp.dtb
```
```
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8250-mtp.dtb
RC=0   诊断行数=0
```

`qcom,snps-dwc3.yaml:172` `$ref: snps,dwc3-common.yaml#`，且它有 `select: compatible contains
qcom,snps-dwc3` ⇒ 这三份 DTB 里 `usb@a600000` 真的会走到本补丁的条件分支（不是空跑）。

**G6 正/负样例**（`/tmp/dwc3-schema-selftest/`，`dtc` 生成，`dt-validate -p processed-schema.json`）：

| 样例 | 形状 | 结果 |
|---|---|---|
| `good.dtb` | `mux-controls` + `port@0`（`#address/-size-cells` + `endpoint@0 state=1` + `endpoint@1 state=0`） | **0 诊断** |
| `bad.dtb` | 同上但 `port@0` 里**没有 endpoint** | 拒：`'endpoint@0' is a required property` / `'endpoint@1' …` |
| `samestate.dtb` | 两个 endpoint 都是 `mux-state = <1>` | 拒：`'oneOf' conditional failed … 0 was expected` |
| `base.dtb` | 无 `mux-controls`，`port@0` 里一个裸 `endpoint` | **0 诊断**（单连接器形状不被误伤） |

真树 A/B（把 `mux-controls` 注入真实 `sm8750-mtp` 的 `usb@a600000`）：

| schema | 输出 |
|---|---|
| baseline `6c0b8b6` | 只有 `Unevaluated properties are not allowed ('mux-controls' was unexpected)` —— 属性根本不存在 |
| 补丁 `5dd032c` | `ports:port@0: '#address-cells' / '#size-cells' / 'endpoint@0' / 'endpoint@1' is a required property` + `'dr_mode' is a required property`（均 `from schema $id: …/qcom,snps-dwc3.yaml`，即 `$ref` 进来的本补丁分支） |

⇒ 本补丁在真 qcom 节点上**新增了可观测的约束**，且不误伤现存三份 DTB。

## 4. `DT_SCHEMA_FILES` 空转的对照实验（可复现）

拿上面故意违反的 `samestate.dtb`/`bad.dtb` 直接喂 `dt-validate`，两种形状对比：

```sh
# (a) kernel 在 DT_SCHEMA_FILES 下生成的形状
dt-validate -l Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml \
            -u ./Documentation/devicetree/bindings \
            -p ./Documentation/devicetree/bindings/processed-schema.json bad.dtb
#   → 0 行（连 samestate/bad 都"通过"）

# (b) 不带 DT_SCHEMA_FILES（-m，按 compatible 匹配）
dt-validate -u Documentation/devicetree/bindings \
            -p $PWD/Documentation/devicetree/bindings/processed-schema.json bad.dtb
#   → 'endpoint@0' is a required property / 'endpoint@1' is a required property / …
```

`dtschema` 侧依据：`-l/--limit` 的语义是「只保留 `$id` 命中 LIMIT 的 schema」，而 schema 要被
应用到某节点仍需它自己的 `select:`；公共片段文件没有 `select`，所以 limiter 之后**没有节点匹配**。
另注意 `scripts/Makefile.dtbs` 的 `cmd_dtb_check` 末尾带 `|| true` ⇒ **rc 永远是 0**，
判绿只能看输出里有没有诊断行，不能看 `rc`。

## 5. 独立复核（子代理 + 本人复跑）

- 子代理（`custom.ustc-pool/ustc-dsf2`，树 `/tmp/b6-apply`，独立打补丁）：W=1 rc=0/0 warning/21 个 `.o`；
  dtbs_check 3/3 `DTC [C]`；blob 双向一致。**但它的 dtbs_check 用的是 `DT_SCHEMA_FILES` 形状**
  （它只在 `.dtb.cmd` 里看到 `dt-validate -l …` 就认定「schema 真的跑了」）⇒ 该绿是 §4 的假绿。
- 本人复跑：`base-wt` 独立打补丁（blob 一致）、`W=1` rc=0/0 warning/23 `.o`（多了 `trace.o`+roles）、
  dtbs_check 用**不带 `DT_SCHEMA_FILES`** 的形状重跑 3/3 无诊断，并补做 §4 对照与 §3 正负样例。
  子代理的 W=1 结论成立，dtbs_check 结论**形状不合格、已由 §3 的正确形状取代**。

## 6. 未尽项

1. **G7 上机回归仍未做**（两连接器枚举/拔插/角色切换，需设备）。
2. **普通树里没有 `mux-controls` 用户**：真实 DTB 只验证「不误伤」，条件分支只由 §3 合成样例覆盖；
   elden 板 DTS 落地后应把该 DTS 加进这条门。
3. `dt_binding_schemas`（`processed-schema.json` 重建）在改了 yaml 后 **`make dtbs_prepare` 不会重建**
   （只有 `CHECK_DTBS=1` 才挂该依赖）；换 schema 复测必须先 `rm -f processed-schema.json` 再
   `make CHECK_DTBS=1 dt_binding_schemas`，否则读的是上一版（本轮踩过，A/B 作废重做）。
4. §4 的结论建议另立一条 `PITFALLS`（编号追加）；本轮按要求不新建文档，只记在此。
