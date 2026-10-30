# M3-1 v5：connector@0/@1 为什么没绑上两个 mux role switch（2026-10-30，纯主机静态定位）

> 角色：父会话（`.pi/AGENT-OPS.md` §1/§3）。输入 = `reports/m3v5-onboard-20261030.md`（本轮上机实测，**不重测**）
> + `reports/m3-v5-recovery-20261030.md`（静态分析）。**本轮不接触设备**（无 ssh/adb/fastboot），
> **未改** `build/m3v5-daily` 任何源码/配置，**未改** TASKS/DEVICE/INDEX/PITFALLS/versions/README，未提交 git 之外任何仓库，未发邮件。
> 全部命令带 `timeout -k`。唯一产物 = 本文件。

**证据基线**：`build/m3v5-daily` HEAD `24223e44ad` + 20 文件脏差异（M3-1 v4 在其内）。
源码 mtime 11:19:03（`drd.c`/`class.c`/DTS）**早于** 构建产物（`class.o` 11:22:19、`elden.dtb` 11:19:29、`vmlinux` 11:23:14、镜像 11:23:34）
⇒ **本报告的静态结论与在机运行的内核是同一次构建**（不存在「树被改过、镜像不是它」的偏差）。
DTB 真值一律从 `build/m3v5-daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb` 反编译取得
（`dtc -I dtb -O dts` → `/tmp/m3v5rc/elden.dts`），**不引用 DTS 源码**。

---

## §0 一页结论（数字先行）

| 项 | 判定 | 证据 |
|---|---|---|
| 绑定链**断在哪一环** | **不是端点不匹配**，而是「连接器→switch」这条**一次性、不可延后**的取用点：`ucsi.c:1860` 只在 `ucsi_register_port()` 里查一次 `fwnode_usb_role_switch_get()`，失败/未就绪都没有重试面 | `drivers/usb/typec/ucsi/ucsi.c:1860,1861-1866,1984,1386` |
| 假设 A「端点图不匹配」 | **否定**：DTB 双向 phandle 完全对得上（2/2 连接器），且 remote 端点带 `usb-role-switch` | §2 表 + `dtc` 反编译 |
| 假设 B「switch 注册晚于 connector」 | **机制成立且是唯一可复现的失败形态**；本树还把它从「可延后」降级成「静默永久失败」 | `roles/class.c:187` vs 基线 `24a19b953` 的 `if (sw)` |
| 假设 C「connector 驱动根本没请求」 | **部分成立**：请求点确实只有 UCSI 一处，且它在失败分支里把 switch 指针永久置 NULL/永久放弃注册；**是否真的走到这一步需要一条运行期证据**（§5.3） | `ucsi.c:1864`、`ucsi_glink.c:323-325` |
| `connector` 软链缺失 | **不是失败信号**：该软链只有 ACPI 平台才会创建（`typec_link_ports()` 对 DT 直接 `return 0`）。上机报告 §1.2 的判读需更正 | `typec/port-mapper.c:96-101,118`、`roles/class.c:42-56,444-448` |
| `waiting_for_supplier` | 静态可算出它与 `desc.fwnode` 取值相关，但**单独不足以定案**（§5.2）；给出 3 条 1 行运行期取数 | §5.2/§5.3 |
| 最小修复 | **不改 DTS**；改 `roles/class.c:187`（一行）+ UCSI 侧让失败**可见且可重试**（`ucsi.c:1860-1866`、`ucsi_glink.c:323-325`） | §6 |
| 本轮未证 | 未上机、无 dmesg/tracepoint 样本；「C 是否真的发生」= 未证实 | §7 |

---

## §1 绑定链全图（本机实际走的那一条）

```
connector@0 (usb-c-connector, /pmic-glink 子节点)
   │  qcom,pmic-glink  →  drivers/soc/qcom/pmic_glink.c:406-409 匹配 "qcom,pmic-glink"
   │  aux: device_set_of_node_from_dev(&aux->dev, parent)          pmic_glink.c:192
   ↓  pmic_glink.ucsi  aux 驱动 probe                            ucsi_glink.c:393-468
   ↓  PDR UP → schedule_work(register_work)                     ucsi_glink.c:350-359
   ↓  pmic_glink_ucsi_register() → ucsi_register()               ucsi_glink.c:313-330
   ↓  ucsi_register(): for each con → ucsi_register_port()        ucsi.c:2149-2154
   ↓  cap->fwnode = ucsi_find_fwnode(con)  （= /pmic-glink/connector@N）  ucsi.c:1810-1830,1859
   ↓  con->usb_role_sw = fwnode_usb_role_switch_get(cap->fwnode)  ucsi.c:1860   ← ★ 取用点（一次性）
   │      roles/class.c:228-243
   │        ├─ usb_role_switch_is_parent()  需要 "usb-b-connector"  → connector 是 "usb-c-connector" ⇒ NULL   class.c:139-157
   │        ├─ usb_role_switch_at_endpoint()  ← 本机唯一能命中的分支                                          class.c:166-194
   │        │     remote = fwnode_graph_get_remote_endpoint(本地端点)
   │        │     usb_role_switch_match(remote, "usb-role-switch") → class_find_device_by_fwnode(remote)      class.c:126-136
   │        └─ fwnode_connection_find_match() 兜底：匹配的是 **remote port parent（控制器节点）**            property.c:1362-1390
   ↓  typec_register_port(ucsi->dev, cap)  → port->dev.fwnode = connector@N                                  ucsi.c:1924, class.c:2837
```

DWC3 侧的注册面（两个 switch 就是在这里登记的）：

```
usb@a600000 (qcom,sm8750-dwc3 + snps-dwc3 → dwc3-qcom.c:597-685 直接用 dwc3_core_probe() 编同一 pdev)
   ↓ dwc3_drd_init(): device_property_read_bool(dev, "usb-role-switch")                     drd.c:766-768
   ↓ dwc3_setup_role_switch(): ret = dwc3_role_mux_init(dwc, mode); if (ret) return ...     drd.c:713-729
   ↓   fwnode_graph_for_each_endpoint(dev_fwnode(dwc->dev), ep)                             drd.c:650-674
   │     只取带 "usb-role-switch" 的端点，按 mux-state 落到 ports[0]/ports[1]
   ↓   ports[i].sw = usb_role_switch_register(dwc->dev, &desc)   desc.fwnode = 端点 fwnode  drd.c:681-694
   ↓ dwc3_set_mode(dwc, mode)                                                                drd.c:698
```

**关键不对称**：`desc.fwnode` 现在是**端点**（`drd.c:681`），而 `fwnode_connection_find_match()` 兜底路径匹配的是
**端点所属端口的上层节点（= `usb@a600000`）**（`drivers/base/property.c:1379,1385`）。
两条路径的目标集合**不相交**：只有 `usb_role_switch_at_endpoint()` 能命中 mux 形状。
而 `usb_role_switch_at_endpoint()` **不在 Linux 7.3-rc7 里**
（`git show 24a19b953e:drivers/usb/roles/class.c` 只有 `usb_role_switch_is_parent`，无 `at_endpoint`；
`git log -S usb_role_switch_at_endpoint` 只命中 `0f1fb1c9c1` = 下游 vk64 payload 导入）
⇒ 这是**下游独有的取用机制**，本机绑定 100% 依赖它，且它只有「现在查到 / 永远查不到」两态。

---

## §2 假设 A「端点不匹配」——**否定**（DTB 真值）

反编译所得（phandle 已解析，`/tmp/m3v5rc/elden.dts`）：

| 位置 | phandle | 关键属性 | remote-endpoint |
|---|---|---|---|
| `/soc@0/usb@a600000/ports/port@0/endpoint` | `0x1ef` | `usb-role-switch; mux-state = <0>` | `0xb7` → connector@0/ports/port@0/endpoint |
| `/soc@0/usb@a600000/ports/port@1/endpoint` | `0xb2` | 无 `usb-role-switch`（drd 跳过） | `0xb8` |
| `/soc@0/usb@a600000/ports/port@2/endpoint` | `0x1f2` | `usb-role-switch; mux-state = <1>` | `0xb9` → connector@1/ports/port@0/endpoint |
| `/pmic-glink/connector@0/ports/port@0/endpoint` | `0xb7` | — | `0x1ef`（回指 usb@a600000 的 mux-state=0 端点） |
| `/pmic-glink/connector@1/ports/port@0/endpoint` | `0xb9` | — | `0x1f2`（回指 mux-state=1 端点） |

推导（逐条对齐 `class.c:166-194`）：

1. `drd.c:685` 实际注册的两个 switch，`desc.fwnode` 分别是 `0x1ef`（`a600000.usb-port0`）与 `0x1f2`（`a600000.usb-port1`）。
2. `at_endpoint(connector@0)`：遍历到 port@0 端点 → `fwnode_graph_get_remote_endpoint()` = `0x1ef`
   → `fwnode_property_present(0x1ef, "usb-role-switch")` = **true**（`class.c:131`）
   → `class_find_device_by_fwnode(&role_class, 0x1ef)` = port0 switch ⇒ **命中**。
3. `at_endpoint(connector@1)`：port@0 端点 → remote = `0x1f2` → 有 `usb-role-switch` ⇒ **命中 port1 switch**。
4. 端点图是双向闭合的（remote-endpoint 成对），`usb@a600000` 的 `status = "okay"`，`fwnode_device_is_available(parent)` 通过
   （`class.c:174-180` 的前置门槛满足）。

⇒ **端点不匹配不成立**；DTS 的 `ports`/`mux-state`/`usb-role-switch` 写法与 `class.c` 的匹配条件是**自洽**的。
**因此「改 DTS」不是本断点的解**（唯一可选的加固已在 DTB 里：控制器节点本身也带 `usb-role-switch`）。

另：`usb@a600000/ports/port@1/endpoint`（`0xb2`，无 `usb-role-switch`）与 connector@0 的 port@1/port@2 端点
（`0x1f0`/`0x1f1`）与本链路无关——`drd.c:650` 显式跳过前者，`class.c` 遍历遇首个命中即返回，不受后者影响。

---

## §3 `connector` 软链缺失 ≠ 绑定失败（更正上机报告 §1.2）

`connector` 软链由 **component 框架 bind 回调**创建，不是 role-switch 注册时创建：

- `roles/class.c:42-56` `connector_bind()` 建 `connector` / `usb-role-switch` 两条软链；
- `roles/class.c:444-448` `usb_role_switch_register()` 只做 `component_add(&sw->dev, &connector_ops)`（**加组件**，不是加 master）；
- 全树唯一的 **master** 是 `drivers/usb/typec/port-mapper.c:118` `component_master_add_with_match()`，
  而它被 `port-mapper.c:96-101` 的 `if (!has_acpi_companion(&con->dev)) return 0;` 挡在 ACPI 之前：
  `typec_link_ports()` 从 `typec/class.c:2886` 无条件调用，但**纯 DT 平台在这里直接返回 0，master 永不出现**。

⇒ **在 DT（非 ACPI）机器上，`connector` 软链本来就不会出现**，与本机 PMIC-GLINK 是否绑定无关。
上机报告 §1.2「`connector` 软链缺失才是真信号」这一句应作废；`role` 属性缺失（设计如此）同理。
**可观测的绑定面只有**：`con->usb_role_sw` 是否非 NULL（间接体现为 UCSI 是否真的去改角色）。

---

## §4 假设 B「switch 注册早于 connector 的取用」——**机制成立**，且本树把它做成了静默永久失败

时序竞争面完全在代码里可见：

| 侧面 | 事实 | 位置 |
|---|---|---|
| 取用只有一次 | `con->usb_role_sw = fwnode_usb_role_switch_get(cap->fwnode)`，之后全程用这份缓存指针，**无二次 lookup** | `ucsi.c:1860`，使用点 `1386`、`1984`、`2034` |
| 注册在 dwc3 probe 内 | `usb_role_switch_register()` 在 `dwc3_role_mux_init()` 里，属 `dwc3_drd_init()`（probe 中段） | `drd.c:685`、`766-768` |
| 两者无 fw_devlink 次序保障 | switch 设备只在 `dwc3` 设备出现后才存在；connector 侧是由 PDR(ADSP UP) 触发的异步 work | `ucsi_glink.c:350-359` |
| 失败没有重试面 | `pmic_glink_ucsi_register()` **丢弃 `ucsi_register()` 的返回值**，并**无条件**置 `ucsi_registered = true` ⇒ 下次只在 PDR 再次 UP 时才重跑 | `ucsi_glink.c:323-325` |

失败后果分两支，两支都是死路：

- **支路 B1（基线 7.3-rc7 行为）**：`usb_role_switch_match()` 在没找到设备时返回 `ERR_PTR(-EPROBE_DEFER)`（`class.c:126-136`），
  `at_endpoint()` 的基线写法是 `if (sw)` ⇒ 原样上抛（`git diff` 可见：本树把该行改成了 `if (!IS_ERR_OR_NULL(sw))`）。
  上抛后 `ucsi.c:1861` 走 `IS_ERR` 分支 → `ucsi_unregister_port()` → `ucsi_register()` 整体失败
  → `ucsi_glink.c:324` 吞掉返回值 → **两个连接器一个都没注册，永不重试**。
- **支路 B2（本树实际行为）**：`class.c:187` 的 `if (!IS_ERR_OR_NULL(sw))` 把 `-EPROBE_DEFER` 当成「没找到」继续扫描，
  最终 `return NULL`（`class.c:193`）→ 兜底路径 `fwnode_connection_find_match()` 匹配控制器节点，
  而控制器节点上没有以它为 fwnode 注册的 switch（mux 形状注册的是端点）⇒ 也返回 NULL
  → `ucsi.c:1864` `con->usb_role_sw = NULL` 并**继续**注册 typec port。
  之后所有 `usb_role_switch_set_role(NULL, …)` 都是 `IS_ERR_OR_NULL` 直接 `return 0`（`class.c:75-80`）
  ⇒ **不报错、不重试、角色永远不动**。

⇒ 这就是「bind 断点」的机制本体：**取用点不可延后 + 失败被降级成 NULL + 上层没有重试**。
注意 `§2.9/I`（`reports/m3-v5-recovery-20261030.md`）已把 `class.c:187` 列为待修 finding；
本报告给它补上了**后果链**：它不是「一条中庸 finding」，而是**本机绑不上的直接使能条件**。

---

## §5 假设 C「connector 驱动根本没请求 role switch」——分成两层看

### 5.1 请求点唯一，且是「请求一次就不再问」

- 全树里连接器侧取 role switch 的调用只有两类：
  UCSI（`ucsi.c:1860`，本机走这条）与 TCPM/TCPC 类（`tcpm.c:8924-8926`、`tipd/core.c:1877` 等，本机未参与）。
- `pmic-glink` 侧不自己找 role switch：`drivers/soc/qcom/pmic_glink.c` 无 `usb_role_switch_*` 调用；
  `ucsi_glink.c` 只搬 UCSI 报文。⇒ 「谁请求」= **UCSI**，没有第二条路径，也没有 retry/notifier。

### 5.2 `waiting_for_supplier` 的来源（静态可算的部分 + 限度）

按 fw_devlink 语义，该文件的内容 = `fwnode_links_check_suppliers(dev->fwnode)`（`drivers/base/core.c:1314-1326,1097-1111`）：

1. `remote-endpoint` **是**被 fw_devlink 跟踪的 supplier 属性（`drivers/of/property.c:1530-1537,1558-1560`），
   2. 但它的 **consumer 被重定向到端口父节点**：`of_graph_get_port_parent(con_np)`（`of/property.c:1559,1619`）。
   ⇒ 对本 DTB 生成的是两条 link：`/pmic-glink/connector@0 → usb@a600000` 与 `usb@a600000 → /pmic-glink/connector@0`
   （`port@0/endpoint` 的父父节点是 `usb@a600000`；`connector@0/ports/port@0/endpoint` 的父父节点是 `connector@0`）。
3. **端点点本身没有其它带 phandle 的属性**（DTB 只有 `remote-endpoint` / `usb-role-switch` / `mux-state` / `phandle`），
   所以按本树源码（`desc.fwnode` = 端点）推算，端点节点的 `suppliers` 链表应为**空** ⇒ `waiting_for_supplier` 应为 **0**。
4. 上机看到的是 **1**。两种互斥解释，静态无法再区分：
   - (a) `usb@a600000 → connector@N` 这条 link 未化解（**即 connector@N 没有 struct device**），
     而这只有在 `dev->fwnode` 是 **`usb@a600000`** 时才会算到 switch 设备头上；
   - (b) 观测到的 1 对应的是上表里另一条 link（`connector@N` 侧）/ `dev->fwnode` 的取值与源码推断不一致，
     需要一条运行期读数来定位。

**结论：不要用 `waiting_for_supplier` 单独定案。** 但方向性提示明确：若 3 成立而实测为 1，
最可能是「`connector@N` 根本没成为 struct device」——这与支路 B1（整个 UCSI 注册被放弃）自洽，
与支路 B2（port 会正常注册）**不自洽**。这条正好是区分 B1/B2 的判据。

### 5.3 需要的运行期证据（本轮**不执行**，只登记）

按判据强度排序，各一条命令即可：

1. `ls -l /sys/class/typec/` — 有 `port0/port1` ⇒ 支路 B2（UCSI 注册成功、只是 switch 没拿到）；
   **空/不存在** ⇒ 支路 B1 或「UCSI 从未 register」（C 的最强形态）。
2. `cat /sys/class/usb_role/a600000.usb-port*/waiting_for_supplier` + `dmesg | grep -i "wait for supplier"`
   — 前者给值（0/1），后者会直接点名**未被满足的 supplier fwnode 路径**，可一次性消解 §5.2 的 (a)/(b)。
3. `dmesg | grep -iE "ucsi|pmic_glink|usb role|con[0-9]"` — 看 `ucsi_register_port` 是否报
   `con%d: failed to get usb role switch`（`ucsi.c:1862`）；**没有这一行**是支路 B2 的判据（B2 是静默的）。
   同时确认 `qcom_pmic_glink` 的 usbc 客户端是否起来了（PDR 是否 UP）。

---

## §6 最小修复建议（**方案，未落地**）

优先级 1（本断点的必要条件，1 行）：

| # | 落点 | 改动 | 理由 |
|---|---|---|---|
| **F1** | `drivers/usb/roles/class.c:187` | `if (!IS_ERR_OR_NULL(sw))` → **`if (sw)`** | 恢复 `-EPROBE_DEFER` 上抛。这就是 `reports/m3-v5-recovery-20261030.md` §2.9 的 finding I，本报告证明它是**本机绑不上的直接使能条件**，应从「可选修」提到「必做」 |

优先级 2（让 F1 的 defer 真正生效，否则只是把静默失败换成可见失败）：

| # | 落点 | 改动 |
|---|---|---|
| **F2** | `drivers/usb/typec/ucsi/ucsi.c:1860-1866` | `IS_ERR` 分支不能 `con->usb_role_sw = NULL; goto out_put;` 后继续注册；应 `return PTR_ERR(con->usb_role_sw)`（`dev_err_probe` 保留），让 `ucsi_register_port()` 失败并向上传 |
| **F3** | `drivers/usb/typec/ucsi/ucsi_glink.c:323-325` | 检查 `ucsi_register()` 返回值：失败时**不要**置 `ucsi_registered = true`，改成 `schedule_delayed_work(&ucsi->register_work, …)` 有界重试（或保持未注册、等下一次 PDR UP） |

优先级 3（可选，减小对下游私有 helper 的依赖）：

| # | 落点 | 改动（择一，不叠加） |
|---|---|---|
| **F4a** | `drd.c:681`（mux 路径 `desc.fwnode`） | **不建议**改成控制器节点：两个 switch 会共用一个 fwnode，`class_find_device_by_fwnode()` 只能返回其中一个 ⇒ 丢失 per-connector 语义 |
| **F4b** | DTS | **不需要改**。若将来要让绑定不依赖 `usb_role_switch_at_endpoint()`（下游独有，非上游 API），正确方向是把这个 endpoint 语义推上游，而不是把 `usb-role-switch` 从端点挪走 |
| **F5** | 文档/上游化备注 | `usb_role_switch_at_endpoint()` 不在 7.3-rc7（`git show 24a19b953e:drivers/usb/roles/class.c`），本机绑定链依赖它 ⇒ 上游化时必须在 cover letter 说明，否则「过 `dtbs_check` 的 DT」在纯净上游内核上**不会绑定** |

**为什么不动 DTS**：§2 已证端点图双向闭合且属性齐备；DTS 任何改动都不改变「取用点一次性、失败不可延后」这一断点，
反而会掩盖 F1–F3 的真问题。

---

## §7 未证实 / 未做（明确缺口）

1. **未上机**：B1 vs B2 vs C 的最终归属需要 §5.3 的三条读数；本报告只在静态层面把三者收敛为
   「同一个断点（一次性取用 + 失败降级）的三种后果形态」。
2. **§5.2 的 fwlink 推断与实测值不一致**：已如实标注为未解项（(a)/(b) 二择），并给了 1 行可判定的取数命令；
   未据此下「已定位」结论。
3. **无 lockdep/KASAN/时序样本**：`drd.c:685` 与 `ucsi.c:1860` 谁先谁后属运行期（模块并行 probe + PDR 异步），
   本轮没有 boot 级时序证据；只证明「先 connector 后 switch 时的失败路径是确定性的死路」。
4. **`reports/m3-v5-recovery-20261030.md` 的 A–J 修复仍未落地**，本轮只把它里面 I 的优先级上调，并新增 F2/F3。
5. 本文件目前是新孤儿：按 `.pi/AGENT-OPS.md` §3「报告必须被引用」，需父会话在 `TASKS/README.md` 的 M3 行补指针
   （本 lane 不改 SSOT）。

---

## §8 复跑命令（只读，全部带时间盒）

```sh
cd /home/xuqianhui/y700-elden/build/m3v5-daily
# 1) DTB 真值（本报告 §2 的表）
timeout -k 5 120 dtc -I dtb -O dts -o /tmp/m3v5rc/elden.dts \
  arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
grep -n "pmic-glink\|connector@" /tmp/m3v5rc/elden.dts
# 2) 取用点与匹配条件
grep -n "at_endpoint\|usb_role_switch_match\|component_add\|connector_bind" drivers/usb/roles/class.c
grep -n "usb_role_sw\|ucsi_find_fwnode" drivers/usb/typec/ucsi/ucsi.c
# 3) 注册面
grep -n "desc.fwnode\|usb_role_switch_register\|dwc3_role_mux_init" drivers/usb/dwc3/drd.c
# 4) 「connector 软链只有 ACPI 才有」
sed -n '96,119p' drivers/usb/typec/port-mapper.c
# 5) 本树对基线的唯一行为性改动（EPROBE_DEFER 被吞）
timeout -k 10 120 git diff -- drivers/usb/roles/class.c
# 6) at_endpoint 是下游引入（不在 7.3-rc7）
timeout -k 10 60 git show 24a19b953e:drivers/usb/roles/class.c | grep -c at_endpoint   # → 0
```

**产物**：仅本文件（`reports/m3v5-connector-bind-rootcause-20261030.md`）。
临时物：`/tmp/m3v5rc/elden.dts`（可删）。
