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
   elden 板 DTS 落地后应把该 DTS 加进这条门 —— **2026-11-21 已落地，见 §7**。
3. `dt_binding_schemas`（`processed-schema.json` 重建）在改了 yaml 后 **`make dtbs_prepare` 不会重建**
   （只有 `CHECK_DTBS=1` 才挂该依赖）；换 schema 复测必须先 `rm -f processed-schema.json` 再
   `make CHECK_DTBS=1 dt_binding_schemas`，否则读的是上一版（本轮踩过，A/B 作废重做）。
4. §4 的结论建议另立一条 `PITFALLS`（编号追加）；本轮按要求不新建文档，只记在此。
   → **已立 `PITFALLS #696`**（正文 `PITFALLS/sessions/328-…dtbs_check空转.md`）。

## 7. elden 板真 DTB 进这道门（2026-11-21）

树 `/tmp/elden-gate`（= `/tmp/base-wt` 全量拷贝，含本系列 1–3/3；`.git` 仍是坏 worktree 元数据，用 `patch -p1`）。
取板 DTS 骨架 = `../board-dts-single-20261113-sent-20261117/0001-*.patch`，再加本轮改动
（件与全文见 `elden-dts/`：`sm8750-lenovo-elden.dts`、`sm8750-lenovo-elden-before-mux.dts`、
`elden-two-connector.diff`、`before-vs-after.diff`、四份门日志、`SHA256SUMS`）。

### 7.1 硬件证据（只据真机/第三方 DT，不用 QRD 参考板；`reference/stock-elden.dts` 是 Sun QRD，**不是** elden）

| 事实 | 证据（file:line） |
|---|---|
| 两个 Type-C 座 | `reports/artifacts/uefi-eud-20261101/live-fdt.dts` `connector@0`/`connector@1`（两个 `usb-c-connector`，各 dual/dual）；同文件 `typec-mux@42`/`@43`（**每口一颗 fsa4480**）；`reference/upstream-pengyuluo/sm8750-lenovo-elden.dts:700-722` 同样两颗 fsa4480 |
| HS 数据线共用一只 mux，选择脚 = TLMM **GPIO 29** | 同上 live-fdt `usb@a600000`：`port-select-gpios = <&tlmm 29 GPIO_ACTIVE_HIGH>`、`pinctrl-0 = <&eusb-mux-state>`；`eusb-mux-state { pins = "gpio29"; … }`（**无** output-high/low）；`port@0` mux-state 0 / `port@2` mux-state 1。**vendor 自己的用法**：`backup/stock-elden/elden_overlay.dtb` 反编译 `fragment@33 { target = <&ucsi>; __overlay__ { gpios = <&tlmm 29 GPIO_ACTIVE_HIGH>; } }`（`__symbols__: ucsi = "/fragment@26:target:0", "/fragment@33:target:0"`）⇒ 厂商是把这条线挂在 **UCSI 端口管理器**上，不是 dwc3、也不叫 mux/enable |
| 两口真实存在且能各自跑 | 双口充电实测（`TASKS/sessions/2026-10-29-双口定案与上游三封投递-2.md`§结论1、`DEVICE/README.md` §1.4）：两口同插、单口 PD 46 W、两 `typec/port*` + 两 `ucsi-source-psy-*` |

**未证的细节（不写进 DTS 注释以外的论断）**：GPIO 29 的**语义与极性**。
- 语义：**电平选择（select），不是 enable**（置信 ~70%）：`nxp,ptn3222` repeater 只有 reset 脚、无 select/enable 引脚，厂商又把这条线挂在 `&ucsi` 而不是 repeater/phy 节点上。
- 极性：**矛盾**——`archive/topics/CHARGE-2026-09-30.md` 说「gpio29 拉低 = 长边」（实测数据）；Pengyu 那份 `reference/upstream-pengyuluo/sm8750-lenovo-elden.dts:980-986` 写 `output-high; /* Unconditionally enable */`，而同文件 `:1045-1049` 注释又说 "select the repeter"（他自己 enable/select 混用）。**两位作者各执一端 ⇒ 至少一方错**。
- 因此本轮只按 vendor 的 `mux-state = 0/1` 写，**不断言**哪个电平/状态对哪个口（DTS 里两个 endpoint 注释写 `Receptacle A/B` 而不写长/短边）。
- **`gpio-mux` 不支持“保留 bootloader 电平”**：`drivers/mux/gpio.c:66` 是 `devm_gpiod_get_array(dev, "mux", GPIOD_OUT_LOW)` ⇒ **probe 时就把线驱低（state 0）**；`idle-state` 默认 `MUX_IDLE_AS_IS` 只影响 deselect 后的行为（`drivers/mux/core.c:140/336/491`），不影响 probe。DTS 注释已按此写（上一版注释「保留 bootloader 电平」是错的，已改）。
- 要把语义/极性/0↔口对应全部定死，缺三条之一：厂商内核里 `ucsi` 那段 `gpios` 的使用代码；原理图 GPIO 29 网络名；**上机 A/B**（debugfs 抓状态后 `gpioset` 翻转，看 HS 连接事件落在哪个口 —— 不刷机、最便宜）。

### 7.2 关键修正：**不要**在 `sm8750.dtsi` 里无条件把 `port@0` 拆成两个 endpoint

`../dwc3-v9-20261117/hold-0004-board-dts/v9-0004-*.patch` 的做法（dtsi 里就长出 `endpoint@0/@1`）
在 v10 binding 下**会让所有不接 mux 的板报错**：实测 mtp/qrd 各多 2 条诊断
（`ports:port@0: {...} is valid under each of …mux-state oneOf` 的歧义 + 随后
`Unevaluated properties are not allowed ('phys','ports','usb-role-switch',…)`）。
根因 = binding 的 `oneOf` 要判「两 endpoint 的 mux-state 相反」，而 mtp/qrd 的两个 endpoint 都没有 mux-state ⇒ 两支同时匹配。

**本轮采用的写法**：dtsi 只加**一个 label**（零行为变化）

```dts
usb_dwc3_hs_port: port@0 { reg = <0>; usb_dwc3_hs: endpoint { }; };
```

需要两连接器的板自己在 DTS 里 `/delete-node/ endpoint;` 再补 `endpoint@0/@1`（见 `elden-dts/elden-two-connector.diff`）。

### 7.3 门（**不带** `DT_SCHEMA_FILES`；`cmd_dtb_check` 带 `|| true` ⇒ rc 只作参考）

```sh
rm -f arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb \
      arch/arm64/boot/dts/qcom/sm8750-{mtp,qrd}.dtb
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j8 \
     qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
```

| 轮 | `DTC [C]` | 诊断起始行（`^arch/…dtb:`） | 其中 USB/mux/connector 相关 | 说明 |
|---|---|---|---|---|
| **加之前**（`sm8750-lenovo-elden-before-mux.dts`：单 endpoint、单 connector、`dr_mode=otg`） | 1（只 rebuilt elden；mtp/qrd 上一轮已 `DTC [C]`） | **3** | **0** | 3 条全是板级既有噪声：`lenovo,elden` 未进 `qcom.yaml`（×2）+ `willsemi,wl2868c` 未文档化 |
| **加之后**（mux + `port@0` 两 endpoint + 两 connector） | **3**（含强制重编的 mtp/qrd） | **3** | **0** | 与「加之前」逐条相同 ⇒ 本改动**零新增诊断**；mtp/qrd 强制重编后 0 诊断（label 改动无副作用） |
| 负样例 A（删 `mux-controls`、保留 endpoint 的 `mux-state`） | — | 8 | **5** | 首行 `ports:port@0:endpoint@0: False schema does not allow 0` |
| 负样例 B（两 endpoint 都是 `mux-state = <0>`） | — | 5 | **2** | 首行 `ports:port@0: 'oneOf' conditional failed, one must be fixed:` |

完整日志：`elden-dts/gate-after-3dtb.log`（after，3/3 `DTC [C]`、3 诊断、0 相关）、`elden-dts/gate-before.log`、`elden-dts/gate-neg{A,B}.log`。

⇒ 这道门在**真 elden DTB** 上既**不误伤**、也确实**咬得住**（负样例被拒），条件分支不再只靠合成样例覆盖。
DTS 编译产物 `sm8750-lenovo-elden.dtb` md5 `2d2d92662785a7aa07edb6aba78a9341`（重排空白后不变，证明只改了语义无关的版式）。

### 7.4 仍未做（下一轮入口）

1. **上面机**：mux 实际切换、两口枚举、同角色换口（G7）。
2. **`usb_hsphy`/`usb_dp_qmpphy` 在本门里仍 `status = "disabled"`**：打开后 phy binding 会要 4 条 supply
   （`vdd`/`vdda12`/`vdda-phy`/`vdda-pll`），而骨架板还没描述 PMIC 稳压器（实测 4 条 required-supply 诊断）⇒ 等 PMIC/regulator 那一批。
3. 真机两口用的是 `pmic-glink` + `ucsi`（vendor live FDT `connector@0/@1` 挂在 `pmic-glink` 下、`port@1` 是 SS + `fsa4480` SBU）；
   本轮骨架 DTS 用两个**根级** `usb-c-connector` 只表达「HS 两口各一个座」，不是最终拓扑。
4. `mux-state 0/1 ↔ 长边/短边` 的对应关系仍无硬件证据（见 §7.1 未证项）。
5. **`gpio-mux` 无法「保留厂商开机态」**：它在 probe 就把线驱低（§7.5 第 1 条）。→ **已在 §8 裁决**：
   (a) 采用 + 故意省略 `idle-state`（`idle-state=<X>` 会在 deselect→select 之间打出错误口瞬态）；
   (b) 改驱动登记为提案（§8.5，未落地）；(c) typec SBU mux 路线语义不匹配。**3/3 的设计前提不变**。

### 7.5 独立复核（子代理 `custom.ustc-pool/ustc-dsf`，42 turns，全程自跑）

子代理在自己的口径下复跑：**after = 3 个 `DTC [C]` / 3 条诊断起始行 / 0 条 USB 相关**；
**before = 3 / 3 / 0** ⇒ 新增 0；三组自造负样例（删 `mux-gpios` → 4 条，含
`mux-controller (gpio-mux): 'mux-gpios' is a required property`；两 endpoint 同 `mux-state` → 5 条；
两 `mux-state` 全删 → 9 条）全部被拒；最终 dtb md5 与我一致 `2d2d9266…`；改动范围核对 = dtsi 只差一行 label、
板 DTS 差异全在 USB 范围（无夹带）。**它与本轮实质分歧两条，两条都成立、已改**：

1. **`gpio-mux` 在 probe 就把线驱低**（`drivers/mux/gpio.c:66` `GPIOD_OUT_LOW`）⇒ 原注释「不写
   `idle-state` 就保留 bootloader 电平」**与驱动事实相反**，已改写；结论：这条线在本驱动下**无法**用
   `idle-state` 之外的写法保电平，要「保留厂商开机态」必须改驱动或换表达（记入 §7.4）。
2. **GPIO 29 的厂商用法挂在 `&ucsi`**（见 §7.1 vendor overlay `fragment@33`），且**两位作者对极性各执一端**
   ⇒ 语义/极性/0↔口对应全部降级为「未证」，DTS 注释不再写长/短边。
   副产品：本项还查实 `DEVICE/README.md` §1.4 的 SMB1501 地址（`@0x42/@0x43`）其实是 `fsa4480`，
   已在该节就地更正（vendor DT 是 `@0x68/@0x69`，live FDT 里 `smb1501` 0 命中）。

## 8. 「gpio-mux probe 即驱低」与「保留厂商开机态」的裁决（2026-11-21 第二轮）

### 8.1 数字结论

| 项 | 结果 |
|---|---|
| 能让 `gpio-mux` **probe 时不驱线**的 DT 写法 | **0 种**（驱动硬编码 `GPIOD_OUT_LOW`，`idle-state` 与 probe 无关） |
| 落地改动 | **注释-only**（`elden-dts/note-asis.diff`，+10/−2 行，全在注释里）⇒ 编译出的 DTB **md5 与改前逐字节相同** `2d2d92662785a7aa07edb6aba78a9341` |
| `dtbs_check` 诊断 | 改前 **3** / `idle-state=<0>` 变体 **3** / 最终 **3**，四份日志 **sha256 全等** `4cd4ace3…`；USB/mux 相关 **0** |
| 负样例 | 两 endpoint 同 `mux-state` ⇒ **5**（USB 相关 2）仍被拒；`idle-state = <2>`（1-pin mux 越界）⇒ **3**，**schema 抓不到** |
| 结论 | 选 (a) 继续 `gpio-mux` + **故意省略 `idle-state`（= `MUX_IDLE_AS_IS`）**；不改驱动 |

### 8.2 判据式选型

| 方案 | 能否不改上游驱动就表达真实行为 | 上游可接受度 | 与 v10 binding 一致 | 裁决 |
|---|---|---|---|---|
| **(a) `gpio-mux` + 省略 `idle-state`** | **只能表达「已知的部分」**：probe=state 0 是确定的，首选即搬数据路；**不能**表达「保留 boot 电平」（pinctrl 确实保得住，但 `gpio-mux` probe 唯一改写者，见 8.3） | 高（零驱动改动、零新属性、用的就是 `mux-controls` 设计） | 完全一致（binding 的 then 分支只要求 `mux-controls`+`mux-state`） | **采用** |
| (a′) `gpio-mux` + `idle-state = <X>` | 同上，但**引入新缺陷**：0003 的换口序列是 `deselect()` → `select(新口)`（`v10-0003:125-127`），非 AS_IS 的 idle 会在两次调用之间真的把线驱到 X（`core.c:491-493`）⇒ **每次 A→B 换口都先瞬态选错口** | 高 | 一致 | **否决**（本轮实测变体，诊断 3 但行为更差） |
| (b) 改 `drivers/mux/gpio.c` 支持「初始不驱动」 | 唯一能真正「保留 boot 电平」的路：`GPIOD_ASIS` 只 request 不改方向/电平（`consumer.h:44-52`、`gpiolib.c:5092-5095`） | **中偏低**：全树 46 文件/≈70 节点用 `gpio-mux`，其中 21 节点带 `idle-state`；把默认 `OUT_LOW`→`ASIS` 会改 ≈49 节点在「首次 select 前」的窗口（逐板依赖**未证**）；新增属性要同时改 `gpio-mux.yaml`（`additionalProperties: false`，:50） | 一致但属**系列前置**（要排在 3/3 之前/一起） | **只写提案**（8.5），本轮不动树 |
| (c) 改走 typec `mode-switch`/`orientation-switch`（`gpio-sbu-mux` 一类） | **不能**：`typec_switch` 只吃 `enum typec_orientation`、`typec_mux` 只吃 `TYPEC_STATE_*`（SBU/altmode 语义）；`gpio-sbu-mux` 的 compatible 必须命中真实型号且 probe 同样 `GPIOD_OUT_LOW`；`usb-switch.yaml`/`usb-switch-ports.yaml` 只是 fragment 无 `select` | 低（要新造 binding，比 (b) 更大的上游动作） | 与 v10 binding 目标相反 | **否决** |

### 8.3 开机态到底被谁改写（本轮新增的硬事实：pinctrl 保、gpio-mux 改）

1. **pinctrl 既不驱也不释放**：厂商自己的 pad 配置（live FDT `eusb-mux-state`，
   `reports/artifacts/uefi-eud-20261101/live-fdt.dts:4441-4447`）= `pins="gpio29"; function="gpio";
   drive-strength=<2>; bias-pull-down;`，**无 `output-high/low`**；本轮 DTS 与之逐字一致。而 qcom pinctrl 在把 pin
   mux 到 gpio 功能时，若 OE 已被置位（ABL 留下的输出态）会**先把当前引脚电平回写 out 位再切 mux**
   （`drivers/pinctrl/qcom/pinctrl-msm.c:213-232`，注释原文 “…not going to be glitching the pin”）；OE=0 时
   pad 就是输入+下拉。⇒ **pinctrl 阶段电平原样保留**，ABL 的驱动不被 pinctrl 释放。
2. **唯一改写者 = `gpio-mux` probe**：`devm_gpiod_get_array(dev, "mux", GPIOD_OUT_LOW)`（`drivers/mux/gpio.c:66`）
   → `msm_gpio_direction_output(value=0)`（`pinctrl-msm.c:576-596`，先写 out 位再置 OE）⇒ 强低 = state 0。
   ⇒ 在 (a) 下开机态确实丢失；且**当前树只有 binding、无 3/3 消费者**时没人再搬回去，于是这条线被强行
   定到 A 口 —— 这是 (b) 唯一的**真实**收益窗口（见 8.5）。
3. **`mux_chip_register` 默认不写线**：`if (mux->idle_state == mux->cached_state) continue;`
   （`core.c:180-183`），而 `cached_state` 初值 `MUX_CACHE_UNKNOWN == MUX_IDLE_AS_IS == -1`（`core.c:29/140`）
   ⇒ 省略 `idle-state` 时登记阶段零写；`select` 必写（`core.c:321-332`，首选自 -1 ⇒ 必写一次 0）；
   `deselect` 只在非 AS_IS 时写（`core.c:487-493`）。
4. **mux 不可读回** ⇒ 开机时哪一口在用软件不可知；3/3 的 commit message 与代码已把「首次 mode request
   抢 state 0」写成设计前提（`v10-0003:14-17`、`:550-555`）。
5. `MUX_IDLE_AS_IS` 在 probe 路径**一次都没被用到**（只出现在 `core.c:140/180/336-337/491-492`）。

### 8.4 门（命令同 §7.3；`nice -n 15` + `flock /tmp/pi-heavy-build.lock` + `timeout -k 30 900`）

| 轮 | 日志 | 诊断起始行 | USB/mux 相关 | dtb md5 |
|---|---|---|---|---|
| 改前（HEAD 版 DTS） | `elden-dts/gate-before-asis.log` | 3 | 0 | `2d2d9266…` |
| 变体：`idle-state = <0>` | `elden-dts/gate-variant-idle-state.log` | 3 | 0 | `53b393fd…` |
| **最终：注释-only（省略 idle-state）** | `elden-dts/gate-final-asis.log` | 3 | 0 | **`2d2d9266…`（= 改前）** |
| 负样例 C：`idle-state = <2>`（1-pin mux 越界） | `elden-dts/gate-neg-idle-range.log` | 3 | 0（**未抓到**） | — |
| 负样例 B 复跑：两 endpoint 同 `mux-state` | `elden-dts/gate-neg-samestate.log` | 5 | 2 | — |

前四份日志 **sha256 完全相同**（`4cd4ace3…`）= 输出与 DTS 内容无关 ⇒ 对 `idle-state`，`dtbs_check` **完全看不见**：
`gpio-mux.yaml:38-39` 的 `idle-state` 只有 `default: -1`，**无 `$ref`/无 type/无 minimum**（对照
`mux-controller.yaml:78-101` 才是 `int32, minimum: -2`）⇒ 越界值只能靠运行时 `mux_gpio_probe` 的
`invalid idle-state` 拒绝。负样例 B 复跑与上一轮逐行一致 ⇒ 门仍咬得住。

### 8.5 (b) 提案草案（未落地，只备档）

动机：让「controller 在用户插口之前不碰数据线」成立，并且不必在 probe 就把未知状态的 mux 定型。

```diff
--- a/drivers/mux/gpio.c
+++ b/drivers/mux/gpio.c
@@ static int mux_gpio_probe(struct platform_device *pdev)
-	mux_gpio->gpios = devm_gpiod_get_array(dev, "mux", GPIOD_OUT_LOW);
+	/* A mux state is unknowable until it is first set, so do not overwrite
+	 * the level the firmware left behind unless the idle state is given. */
+	mux_gpio->gpios = devm_gpiod_get_array(dev, "mux", GPIOD_ASIS);
```
（`idle-state` 已有登记期写入路径 `core.c:180-183`，因此显式写了 `idle-state` 的 21 个节点行为不变。）

上游可接受性评估（要说服的三个人/三条线）：
- **Peter Rosin（mux maintainer）**：必须说明「≈70 个节点里没有一个依赖 probe 即 0」——本轮只证到
  「无 DTS/注释依赖证据」，**未逐个 consumer 证实**（缺的证据：i2c-mux/spi-mux/iio-mux/can 在首次
  `select` 前是否要求确定电平）。这条不补，提案不该发。
- **Rob Herring / DT**：若走「新属性」路线（如 `mux-gpios-init-as-is`）要同时改 `gpio-mux.yaml`
  （`additionalProperties: false`），且必须回答「为什么不复用 `idle-state`」——答：`idle-state` 管的是
  deselect/park，不是 probe，语义不同（本节 8.3 第 3 条）。
- **与系列的关系**：属**系列前置**，要么塞进 3/3，要么先单独发 1 枚。当前 3/3 的行为（首选抢 state 0）
  不依赖它，故**不阻塞 v10 投递**；收益集中在「消费者不存在/未就绪」的过渡窗口（8.3 第 2 条），
  3/3 落地后首个 mode request 仍会选 0 ⇒ 长期收益≈ 0。
- 另一条被否决的中间态：给 mux 节点 `status = "disabled"` 以保电平 —— `mux-controls` 会指到 disabled 节点，
  3/3 落地后必须记得改回，属自埋雷。
- 反向论点（本轮采信）：mux 不可读回时，「确定已知的 state 0」比「未知的继承电平」更可推理；
  收益仅一个短暂的 boot 窗口 ⇒ 优先级低。

### 8.6 上机清单（本轮不上机）

1. `cat /sys/kernel/debug/gpio` 与 `gpiodetect/gpioinfo` 确认 GPIO29 被 `gpio-mux` 持有、方向 out、值 0。
2. 两口各插一次 U 盘/键盘：确认 `mux_state` 切换与 `lsusb` 枚举落在对应口（binding 的 `mux-state` 0/1
   ↔ 物理口对应关系仍**无硬件证据**，见 §7.1）。
3. A→B 换口时用示波器/逻辑分析仪（或 `gpioinfo` 轮询）确认**没有**中间态电平翻转（本轮的 (a) 判据；
   若出现翻转 ⇒ 说明有人给 mux 加了非 AS_IS 的 `idle-state`）。
4. `gpioset` 手动翻转 GPIO29，看 HS 连接事件落在哪个口 ⇒ 定死「极性/0↔口」。

### 8.7 子代理复核（`custom.ustc-pool/ustc-dsf`，20 turns/30 calls，全程只读）

它独立给出五条与本节一致的判定，其中**两条直接改变本轮结论**：
`mux_chip_register` 默认不写线（`core.c:180-183`）与 **`idle-state=<0>` 会在 deselect→select 之间造成
错误口瞬态**（`v10-0003:125-127` + `core.c:491-493`）⇒ 我据此把已落地的 `idle-state = <0>` 撤掉、改成
「故意省略 + 注释写清」。另两条我复跑确认：`GPIOD_ASIS` 语义（`gpiplib.c:5092-5095`）、
`gpio-mux.yaml` 的 `idle-state` 无类型约束（负样例 C 实测不报）。

**它还纠了两处既有记录**（以本轮为准）：① `/tmp/elden-gate` 实际只有 **1/3（binding）**，
`drivers/usb/dwc3/drd.c` 无 mux、`drivers/usb/roles/class.c` 无 `usb_role_switch_at_endpoint`
⇒ §7 开头「含 1–3/3」不成立；② §0/§1 记的 blob `5dd032c7…` 在本地树上**复现不出**：本地 pristine
`snps,dwc3-common.yaml` 是 `6892703…`，打补丁后 `18e3424…`（补丁 `index` 左端 `6c0b8b6` 属另一基线
`aebb7274` 的文件版本，语义差异与本轮无关，但「逐字节一致」这句话只对那个基线成立）。
