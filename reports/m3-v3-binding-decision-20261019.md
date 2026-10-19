# M3-1 v3 · C0 一次正反判断：binding 形状是否改用标准 mux 子系统

> 角色：worker / researcher（**只做判断与证据，未改任何补丁/源码，未跑构建**）。
> 输入：`patches/upstream/m3-v2-2026-10-17/`（README + 0001 binding + 0002 driver）、
> `reports/mail-triage-20261019.md` §4.1 / §5 第 2 位、sashiko 原文 `/tmp/mailfocus3/001_*`（Message-ID `<sashiko-outbox-175391@kernel.org>`）。
> 证据树：**`build/m1-73`（v7.3-rc7 = `24a19b953`，HEAD `24223e44a`）** 为主；`linux/`（7.2.0）仅用于交叉复核，两者结论一致（逐条注明）。

---

## ① 结论：**选 A —— 维持自定义 `port-select-gpios`**（附两条强制修补，见 ④）

一句话：sashiko 的 5 条 binding 里**只有 1 条**点名标准 mux，而这一条是**净负收益**——
mux 子系统只能替掉 3 行 GPIO 写，替不掉仲裁（120 行），还会引入 `gpio-mux` 探测期
`GPIOD_OUT_LOW` 强驱 0 的行为变化和一条新的 Kconfig 依赖；其余 4 条换不换 mux 都要逐条回答。

**翻转条件（写下来，避免下次重复论证）**：若上游有人明确要求「HS 数据对必须在 OF graph 里
以中间 mux 节点建模」（即 sashiko 第 2 条的另一种表述），或 `drivers/usb/` 出现第一个
`mux_control` 消费者（先例建立），则重开本判断改选 B。在此之前**不改形状**。

---

## ② 三条判据逐条命中情况

| # | 判据 | 结果 | 一句话依据 |
|---|---|---|---|
| 1 | **上游先例**：USB 子系统是否已有 `mux_control`/`mux_get` 使用者（含 dwc3/typec 的 role switch 与 mux 关系） | **未命中** | 7.3-rc7 与 7.2 两棵树 `drivers/usb/` 内 `mux_control` / `linux/mux/consumer.h` 命中数 **0**；唯一声明 `mux-controls` 的 USB binding（chipidea）**无任何驱动实现** |
| 2 | **语义可承载**：标准 mux 能否表达我们现在需要的三件事（最早者胜仲裁 / 只在自己占有数据通道时报告角色 / debugfs 拒写 mode） | **未命中（净负）** | `mux_control_select()` 只是「取信号量 + 写状态」，无 owner 查询、无角色概念、无排序策略；三件事全部必须留在 dwc3。且 `gpio-mux` probe 用 `GPIOD_OUT_LOW` 强制驱动 0，破坏我们现在 `GPIOD_ASIS` 读回 bootloader 状态的语义 |
| 3 | **是否真能消解 sashiko 的实质异议**（换成 mux 后 5 条里有 ≥3 条自动消失） | **未命中（1/5）** | 5 条中仅第 1 条点名标准 mux；第 2/3/4/5 条（`port@2` 语义、`usb-role-switch` 位置、`ports` 未 required、两 port 同 `mux-state`）与 mux 无关。换成 mux 后仍需新增 `mux-controls` 消费者属性 + endpoint 的 role-switch 描述，等于把 1 条 Medium 换成**同形状的另一条 Medium** |

判据 1 的补充（正面反例，已查、已排除）：sashiko 建议的第三条路 `usb-switch.yaml` **不是 mux binding**
——它只定义 `mode-switch`/`orientation-switch`/`retimer-switch` 三个 boolean（`grep -n "" usb-switch.yaml`），
描述的是「谁是 altmode/orientation 处理者」，与「HS D+/D- 选哪一路」无关。**不可用。**

---

## ③ 若选 B（**本次不采纳，仅记录改动面**，供翻转时直接开工）

| 文件 | 改动 | 预计行数 |
|---|---|---|
| `Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml` | 顶层加 `$ref: /schemas/mux/mux-consumer.yaml#`；删 `port-select-gpios`、`$defs/hs-port` 的 `mux-state`；保留 `port@2`（仍需回答 sashiko 第 2 条） | −20 / +6 |
| `drivers/usb/dwc3/Kconfig` | `select MULTIPLEXER`（`MUX_CORE` 由用户态配；见风险 3） | +1 |
| `drivers/usb/dwc3/core.h` | `struct dwc3_role_mux.select`（`struct gpio_desc *`）→ `struct mux_control *` | −2 / +2 |
| `drivers/usb/dwc3/drd.c` `dwc3_role_mux_init()` | `devm_gpiod_get_optional(dev,"port-select",GPIOD_ASIS)` + `gpiod_get_value_cansleep` 读回 → `devm_mux_control_get_optional(dev, NULL)`；`mux->desired_port` 不再能从 line 读回（mux core 不暴露 `cached_state`） | ±15 |
| `drivers/usb/dwc3/core.c` `__dwc3_set_mode()` | `gpiod_direction_output(mux->select, mux_port)` → `mux_control_select(mux->mux, mux_port)`；**新增**上一次角色拆除后的 `mux_control_deselect()`（否则信号量永不释放） | ±10 |
| 板 DTS（M3-2 片） | 新增 `mux-controller { compatible="gpio-mux"; #mux-control-cells=<0>; mux-gpios=<&tlmm 29 …>; }`；`&usb` 换 `mux-controls`；删 `port-select-gpios` | +9 / −1 |

**风险（4 条，前两条已是实测证据）**：
1. **探测期强驱 0**：`drivers/mux/gpio.c:66` `devm_gpiod_get_array(dev,"mux",GPIOD_OUT_LOW)` —— mux-gpio 一 probe
   就把选择线拉到 0，而 dwc3 现在刻意用 `GPIOD_ASIS` 保留 bootloader 留下的电平。本机双连接器板上这会
   在 dwc3 probe 之前把数据通道强行指向 port 0。
2. **配置依赖新增**：`build/m1-73/.config` 实测 `CONFIG_MULTIPLEXER=y` 但 **`# CONFIG_MUX_CORE is not set`**
   （`:10785`）；`arm64/configs/defconfig` 只有 `CONFIG_MUX_GPIO=m` / `CONFIG_MUX_MMIO=y`（`:1861-1862`）、
   **无 `MUX_CORE`**。为一块板新增 `select MULTIPLEXER` + 用户必须开 `MUX_CORE`，比现在
   `devm_gpiod_get_optional` 自足。
3. **失去「bootloader 已选端口」信息**：`mux_control` 不公开 `cached_state`，`desired_port` 无法初始化
   （现在 `mux->desired_port = gpiod_get_value_cansleep(select)`，`active_port = -1`）。
4. **零收益**：12 条 sashiko finding（1 Critical / 3 High 全在 driver）一条都不会因换 mux 消失。

---

## ④ 若选 A：必须逐条回答的 binding 5 条（v3 交付清单）

| # | sashiko 原话要点（`<sashiko-outbox-175391@kernel.org>`） | 处置 | 证据/答复要点 |
|---|---|---|---|
| 1 | 「board-level HS GPIO mux modeled in controller」；点名 `mux/gpio-mux.yaml`、`mux/mux-consumer.yaml` | **拒绝，给理由** | 见 ② 判据 1/2/3：USB 子系统零 `mux_control` 先例（7.2 + 7.3-rc7 实测 0 处）；mux 只选通道不仲裁角色；`gpio-mux` probe 强驱 0 破坏 ASIS 语义。**改在 cover letter 里写，不改 binding** |
| 2 | 「`port@2` 把第二连接器建模成 controller bus」；建议「intermediate mux node in the graph 或 `port@0` 下 `endpoint@0/1`」 | **接受并改** | 采纳第二种：`port@0` 下用 `endpoint@0`（长边）/`endpoint@1`（短边）+ `reg`，删 `port@2`。`$defs/hs-port` 放开编号 endpoint |
| 3 | 「`usb-role-switch` 放在 graph endpoint」——`fwnode_graph_get_remote_port_parent()` 走到**控制器节点**才查该属性；且 `dependentRequired` 使其与 `mux-state` 冗余 | **必须改（最高优先）** | 已核实 `drivers/base/property.c:1362-1394` 确实查 parent。**且本机链路目前能通，靠的是下游树独有的 `usb_role_switch_at_endpoint()`**（`patches/replay-2026-10-17/0001-…patch`；`build/m1-73` 与 `linux/` 皆有，pristine `24a19b953` **无**）。即该形状**不可上游**：删 endpoint 上的 `usb-role-switch`，改为控制器级 `usb-role-switch` + endpoint 只带选择电平（或按 #2 的方向让 dwc3 自己从 `ports` 数 endpoint 建 switch） |
| 4 | 「`port-select-gpios` 的 `then:` 未把 `ports` 列入 required；也无 else 分支，缺 gpio 时 `port@2`/`mux-state` 仍被允许」 | **接受并改** | 已发 v2 的 `required` 只有 `[dr_mode, usb-role-switch]`（补丁原文）；本地 `build/m1-73` 已改成 `[usb-role-switch, ports, dr_mode]` —— 把该本地修正**收进 v3 补丁**，并补 else 分支禁止无 gpio 时的 `mux-state` |
| 5 | 「两个 port 可写同 `mux-state` 仍过校验」 | **接受并改** | 加 `dependentSchemas`/`oneOf` 把 `port@0`/`port@2`（或新 `endpoint@0/1`）的 `mux-state` 约束为 `0`/`1` 互补 |

**A 方案下 driver 侧仍要动的 12 条**（不在本判断范围，仅索引）：Critical `dwc3_role_mux_init()` 错误路径
`cancel_drd_work`；High ①`port->stamp` 只在 `NONE→非NONE` 更新 ②锁外 `dwc3_set_mode()` 竞争
③role switch 注册位置（与 binding #3 同一根因）——见 `reports/mail-triage-20261019.md` §5 第 2 位。

---

## 附录 A · 证据命令与命中摘录

> 全部在本机执行；「7.3」= `build/m1-73`（v7.3-rc7），「7.2」= `linux/`。两棵树的 grep 结论一致时只列 7.3 输出。

### A.1 `drivers/usb/` 里是否存在 mux 子系统使用者（判据 1）

```bash
cd build/m1-73 && grep -rn "mux_control\|mux/consumer\|#include <linux/mux/consumer.h>" \
    drivers/usb/ --include=*.c --include=*.h | wc -l
# → 0
grep -rln "include <linux/mux/consumer.h>" --include=*.c drivers/ | sed 's|/[^/]*$||' | sort -u
# → drivers/phy/ti, drivers/mtd/hyperbus, drivers/spi, drivers/pinctrl, drivers/phy/renesas,
#   drivers/net/mdio, drivers/mux, drivers/mmc/host, drivers/media/platform, drivers/iio/multiplexer,
#   drivers/i2c/muxes, drivers/i2c/busses, drivers/gpu/drm/bridge, drivers/gpio   ← 15 个目录，0 个 usb
```

`drivers/usb/typec/` 里的 `mux` 全是**另一个类**（`linux/usb/typec_mux.h` 的 AltMode/orientation mux），
不是 `linux/mux/consumer.h`：

```bash
# 用 mux 子系统的真实 API 名（typec 的 typec_mux_get 是另一套类，不能算）：
grep -rn "mux_control_get\|mux_control_select\|devm_mux\|mux/consumer.h" \
    drivers/usb/dwc3/ drivers/usb/typec/ drivers/usb/chipidea/ drivers/usb/roles/   # → 0 命中
grep -n "include" drivers/usb/typec/mux.c | grep -i mux
#   #include <linux/usb/typec_mux.h>        ← 无 linux/mux/consumer.h
```

dwc3 侧 role switch 与 mux 无交集（`dwc3_setup_role_switch()` 在**控制器节点**上注册唯一一个 switch）：

```bash
grep -n "dwc3_setup_role_switch\|usb_role_switch_register" build/m1-73/drivers/usb/dwc3/drd.c
# 675: static int dwc3_setup_role_switch(struct dwc3 *dwc)
# 694:     dwc3_role_switch.fwnode = dev_fwnode(dwc->dev);
# 699:     dwc->role_sw = usb_role_switch_register(dwc->dev, &dwc3_role_switch);
```

唯一「USB binding 声明了 `mux-controls`」的是 chipidea，但**驱动没实现**（只有 `phy-select` syscon）：

```bash
grep -n "mux-controls\|mux-control-names" Documentation/devicetree/bindings/usb/chipidea,usb2-common.yaml
# 131:  mux-controls:
# 195:  mux-controls: [ mux-control-names ]      ← 只有 schema，无 consumer 代码
grep -rn "mux_control\|mux/consumer" drivers/usb/chipidea/ --include=*.c --include=*.h   # → 0
sed -n '139,160p' drivers/usb/chipidea/ci_hdrc_msm.c   # ci_hdrc_msm_mux_phy() 用 of_parse_phandle("phy-select")
```

### A.2 binding 可用位与同类板级 DTS 先例（判据 1 的「可承载性」）

```bash
# 「muxes」这个属性名在整棵 schema 树里不存在（任务描述里的名字需更正）
grep -rn "muxes:" Documentation/devicetree/bindings/ | grep -v "pin muxes\|pinmuxes"   # → 0 命中
# 标准写法只有 mux-controls / mux-states
grep -n "mux-controls:\|mux-states:" Documentation/devicetree/bindings/mux/mux-consumer.yaml
#  46:  mux-controls:     49:  mux-states:
grep -n "mux-gpios:\|idle-state:\|#mux-control-cells" Documentation/devicetree/bindings/mux/gpio-mux.yaml
#  24:  mux-gpios:   32:  '#mux-control-cells':   38:  idle-state:  default -1
```

`snps,dwc3-common.yaml` 本身**是 `additionalProperties: true`**（`snps,dwc3.yaml` 那层才是
`unevaluatedProperties: false`），所以「加 `mux-controls` 在 schema 上很容易」——**这不是障碍**，
障碍是语义（②）：

```bash
grep -n "additionalProperties" Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml   # → 491: true
grep -n "unevaluatedProperties" Documentation/devicetree/bindings/usb/snps,dwc3.yaml          # → 78: false
```

**同类 SoC 板级 `gpio-mux` 先例（唯一的真命中，但不支持 B）**：同为 Lenovo、同一 TLMM、同一 SM8x50 家族，
但被控对象是**音频 codec 的 CTIA/OMTP 地/麦切换**，与 USB 角色无关，也不存在「谁先请求谁占有」的仲裁：

```bash
sed -n '188,196p' build/m1-73/arch/arm64/boot/dts/qcom/x1e78100-lenovo-thinkpad-t14s.dtsi
#   /* two muxes together support CTIA and OMTP switching */
#   us_euro_mux_ctrl: mux-controller {          ← :189
#           compatible = "gpio-mux";
#           mux-supply = <&vreg_l16b_2p5>;
#           #mux-control-cells = <0>;
#           mux-gpios = <&tlmm 68 GPIO_ACTIVE_HIGH>;   ← :195
#   };
sed -n '40p' .../x1e78100-lenovo-thinkpad-t14s.dtsi   # wcd938x: mux-controls = <&us_euro_mux_ctrl>;
```

「两个 Type-C 共用一个 HS 数据对」的 DTS 先例：**全树 0 例**。
`sun8i-t113s-netcube-nagami.dtsi` 的 `usb0_sec_mux`（`compatible="gpio-mux"`）**标签从未被引用**
（`grep -rn "usb0_sec_mux" arch/arm/boot/dts/allwinner/` → 只有定义行），是**死节点**：

```bash
grep -rn "mux-controls" arch/arm64/boot/dts/ arch/arm/boot/dts/ --include=*.dts --include=*.dtsi | \
  grep -ci "usb"     # → 0（无任何 USB 控制器 consumer）
```

### A.3 sashiko 5 条原文（`<sashiko-outbox-175391@kernel.org>`，2026-10-17 08:28Z）

文件：`/tmp/mailfocus3/001_INBOX_Re-PATCH-v2-1-2-dt-bindings-usb-snps-dwc3-de.txt`（若已清，
`python3 ~/.local/bin/read-mail-ustc.py --days 30 --grep sashiko` 重取）。

1. **[Medium] board-level HS GPIO mux modeled in controller**
   > "Should a board-level GPIO multiplexer on the High Speed D+/D- lines be modeled using the existing mux
   > bindings instead of adding controller-specific port-select-gpios and endpoint mux-state properties to
   > snps,dwc3-common.yaml? … Could this hardware topology be represented using
   > `Documentation/devicetree/bindings/mux/gpio-mux.yaml` (mux-gpios),
   > `Documentation/devicetree/bindings/mux/mux-consumer.yaml` (mux-controls / mux-states), or
   > `Documentation/devicetree/bindings/usb/usb-switch.yaml`?"
   > 并指出「the description also encodes driver switching policy」——**这条成立**：`port-select-gpios`
   > 的 description 里那句 "The controller switches the data path only after it has stopped the role of the
   > previous connector" 是**驱动策略**，按项目「红线」应留在 C 里。**v3 必须删这句。**

2. **[Medium] port@2 models second connector as controller bus**
   > "…children of ports represent buses on the controller itself (port@0 for the High Speed data bus and
   > port@1 for the Super Speed data bus). When a single High Speed bus is routed to two remote targets, OF
   > graph bindings normally model either an intermediate mux node in the graph or multiple numbered
   > endpoints (endpoint@0, endpoint@1) under port@0. … won't this reject numbered endpoint@N children under
   > port@0, while leaving port@1 (Super Speed) as a single port even though the commit message notes that
   > Super Speed lanes stay per connector?"

3. **[Medium] usb-role-switch placed on graph endpoint node**
   > "…the lookup walks from the remote endpoint up past port@N and ports to the parent controller device
   > node, and checks `if (!fwnode_property_present(node, "usb-role-switch")) continue;` on the parent device
   > node rather than the endpoint subnode. … isn't usb-role-switch on the endpoint completely redundant with
   > mux-state?"
   > **已独立复核**：`build/m1-73/drivers/base/property.c:1362-1394` `fwnode_graph_devcon_matches()` →
   > `node = fwnode_graph_get_remote_port_parent(ep); ret = match(node, con_id, data);` —— 查的确实是
   > parent。**这条是 5 条里唯一「不改就真的坏」的**（本机能通是因为下游 `class.c` 多了
   > `usb_role_switch_at_endpoint()`）；`pristine 24a19b953` 无该函数（`git show 24a19b953:drivers/usb/roles/class.c | grep -c at_endpoint` → 0）。

4. **[Medium] port-select-gpios conditional omits required ports**
   > "Since ports is optional at the top level … will a node with port-select-gpios, dr_mode = \"otg\", and
   > usb-role-switch that omits the ports node altogether silently pass dt_binding_check? … Should ports also
   > be listed in then:required: …? Conversely, without an else branch … won't port@2 and the endpoint
   > mux-state and usb-role-switch properties remain allowed even when port-select-gpios is absent?"

5. **[Medium] schema allows identical mux-state on both ports**
   > "Can a device tree specify the same mux-state value (for example, both <0> or both <1>) on
   > ports/port@0/endpoint and ports/port@2/endpoint and still pass schema validation? Both port@0 and port@2
   > reference #/$defs/hs-port, which independently checks enum: [0, 1] on each endpoint, without constraining
   > the two endpoints to use distinct GPIO levels."
   > `grep -n "enum: \[0, 1\]" …/snps,dwc3-common.yaml` → 命中 `$defs/hs-port` 内，**确认为真**。

### A.4 反方证据：「mux 只能选通道，不能仲裁角色」是否成立

**成立**，逐点：

```bash
# (a) mux 消费者 API 的唯一状态是「状态号 + 独占信号量」，没有角色/优先级/owner 查询
sed -n '355,395p' build/m1-73/drivers/mux/core.c
#   mux_control_select_delay(): ret = down_killable(&mux->lock); ret = __mux_control_select(mux, state);
#   ……"it will be locked until there is a call to mux_control_deselect()"
sed -n '428,445p' build/m1-73/drivers/mux/core.c   # mux_control_try_select_delay(): -EBUSY if contended
grep -n "cached_state\|states\|idle_state" build/m1-73/include/linux/mux/driver.h
#   struct mux_control { semaphore lock; mux_chip *chip; int cached_state; unsigned states; int idle_state; ktime_t last_change; }
#   ← 无 role，无 owner 暴露，无「最早者胜」
```

→ 本次要的三件语义**全都在 mux 的表达能力之外**，必须继续留在 dwc3：
`dwc3_role_mux_pick()`（最早者胜，`time_before(port->stamp)`）、
`dwc3_mux_role_get()`（`mux->active_port == port->state` 才报自己角色）、
`dwc3_mode_write()` 的 `-EBUSY`。即 mux 只能替 `gpiod_direction_output()` 这一处。

```bash
# (b) gpio-mux probe 会在 dwc3 之前把线强驱 0（行为变化，本板有风险）
sed -n '66p' build/m1-73/drivers/mux/gpio.c
#   mux_gpio->gpios = devm_gpiod_get_array(dev, "mux", GPIOD_OUT_LOW);
# 现方案刻意用 ASIS 保留 bootloader 电平：
grep -n "GPIOD_ASIS" patches/upstream/m3-v2-2026-10-17/0002-*.patch
#   select = devm_gpiod_get_optional(dwc->dev, "port-select", GPIOD_ASIS);
#   ret = gpiod_get_value_cansleep(select);  → mux->desired_port = ret; mux->active_port = -1;
```

```bash
# (c) 配置代价：本机现有 .config 里 MUX_CORE 是关的，arm64 defconfig 完全没开
grep -n "MULTIPLEXER\|MUX_CORE\|MUX_GPIO" build/m1-73/.config
#  10784: CONFIG_MULTIPLEXER=y
#  10785: # CONFIG_MUX_CORE is not set      ← dwc3 若消费 mux，必须新增 select
#  10792: CONFIG_MUX_GPIO=m
grep -n "CONFIG_MUX_" build/m1-73/arch/arm64/configs/defconfig
#  1861: CONFIG_MUX_GPIO=m      1862: CONFIG_MUX_MMIO=y      ← 无 MUX_CORE
```

---

## 附录 B · 未做 / 边界（诚实声明）

- **未改任何补丁或源码**；未跑 `make`/`checkpatch`/`dt-doc-validate`；未碰设备、未发邮件。
- `build/m1-73` 与 `linux/` 都是**浅克隆**（`git rev-list --count HEAD` → 1~3），因此
  `git log -S` 类**历史**检索无意义（如「chipidea 的 `mux-controls` 是否曾实现过」只能判「当前无实现」，
  不能判「从未实现」）。本轮所有 grep 结论都是**当前树的事实**，不涉及历史断言。
- 未核 7.4/net-next 是否已出现 USB mux 消费者（`TASKS/README.md` §7 M1–M5 之外，属翻转条件，非本轮阻塞）。
- 本报告需被引用以脱离孤儿：建议从 `TASKS/README.md` §7 M3-1 行或
  `patches/upstream/m3-v3-*/README.md`（待建）链入。
