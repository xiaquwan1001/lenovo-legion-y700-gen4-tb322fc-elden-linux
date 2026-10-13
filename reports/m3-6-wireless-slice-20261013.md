# M3-6 无线片：就绪化 + M4 无线立项建议（2026-10-13）

- 日期：2026-10-13
- 任务：F（M3-6 无线片就绪化 + M4 无线立项建议）
- 工作树：`/home/xuqianhui1001/y700-elden/build/m3-6-worktree`（detach @ `24a19b953e` = Linux 7.3-rc7 pristine）
- payload 树：`build/m1-upstream/clean-tree`（**Linux 7.2.0 血统**，base `v7.2-elden` `44137cb4e`）
- 补丁目录：`patches/upstream/m3-6-2026-10-13/`
- 依赖面：`reports/m3-missing-support-matrix-20261013.md`、`reports/m3-series-plan-20261013.md` §2 M3-6
- 规则：`reports/upstream-policy-20261013.md` §1 三问 / §3 违例
- 设备侧：**纯主机侧，未上机**；本片只做静态分类 + 机械门

## 0. 摘要

- **§1 pwrseq-qcom-wcn 591 行可拆**：净 +589/-2、9 hunk。**最小可上游子集 ≈70 行**（`qcom,wcn7861-pmu` compatible + of_data 复用 wcn7850 轨道 + BT 时序三字段）；**必须拆出 ≈520 行** = AOSS QMP PDC 初始化 + OL-CPR 动态电压投票 + 导出 API（含新头 `include/linux/pwrseq/qcom_wcn.h`）。`vreg_cfgs` 逐轨投票属 **Q3 违例**（电压应在 DT regulator 约束）。
- **§2 binding 46 行（+46/-0，2 hunk）**：仅 `compatible.enum` 加 `qcom,wcn7861-pmu` 可上游；`qcom,qmp`/`qcom,pdc-init-table`/`qcom,vreg-pdc-map`/`qcom,pmu-vreg-map` 是 vendor 私货（固件命令串进 DT），应剔除。**不需要新 yaml**。上游 `sm8750-mtp.dts` 已注释“rev 2.0 MTP 可有 WCN786x”，有处境支撑。
- **§3 hci_qca 393 行 PERI（属 B3/M4）**：payload 自身 ≈350 行新协议（H4 packet type 0x31/0x34、EDL opcode、8 Mbaud、PERI 状态机、3 个新固件文件），另 `btqca.c` +58/-10。给出 **9 条与 linux-bluetooth 的接口问题**；可先发**纯数据小补丁（P-A）**打开局面（不夹带 PERI）。
- **§4 ath12k PEACH**：**纯数据表 ≈127 行可先出 RFC**（`pci17cb,110e` + hw_params + hal 条目，全部复用**上游已有**的 QCC2072 datapath）；`board_api1_only` ≈26 行独立小补丁；**TME-L 固件下载 + OL-CPR 跨模块 API（≈350 行 ath12k 侧 + 520 行 pwrseq 侧）须 RFC，OL-CPR 预期 NAK ⇒ 隔离下游**。
- **§5 实际交付 2 枚补丁**（0001 binding / 0002 pwrseq 驱动）：`checkpatch --strict --no-tree` **0E/0W/0C**，`drivers/power/sequencing/` 编译 **rc=0**，`dt-doc-validate` **rc=0**，在 pristine 上 `git apply --check` OK。
- **未上机**：功能结论一律「未上机/未证实」；补丁未发送，仅备料。

## 1. `pwrseq-qcom-wcn.c` 591 行逐 hunk 分类（核心）

### 1.1 基线事实（可复跑）

```sh
cd /home/xuqianhui1001/y700-elden
wc -l build/m3-6-worktree/drivers/power/sequencing/pwrseq-qcom-wcn.c          # 598 (pristine 7.3-rc7)
wc -l build/m1-upstream/clean-tree/drivers/power/sequencing/pwrseq-qcom-wcn.c # 1292 (payload 7.2.0)
diff -u <pristine> <payload> > /tmp/pwrseq.diff
grep -c '^@@' /tmp/pwrseq.diff        # 9 个 hunk
grep -c '^+[^+]' /tmp/pwrseq.diff     # 589 insertions
grep -c '^-[^-]'  /tmp/pwrseq.diff    # 2  deletions
```
⇒ 净 diff **+589 / -2 = 591 行**（与缺口矩阵的「591 行」一致）。该文件在 7.2→7.3-rc7 之间**无上游改动**，故此处直接的 pristine↔payload diff **就是 payload 自身的新增**，无版本漂移污染（与 ath12k/hci_qca 不同，见 §3/§4）。

新增头文件（payload）：`linux/mutex.h`、`linux/overflow.h`、`linux/pwrseq/consumer.h`、`linux/pwrseq/qcom_wcn.h`（**新文件**）、`linux/slab.h`、`linux/soc/qcom/qcom_aoss.h`。
其中 `include/linux/pwrseq/qcom_wcn.h` 是新造的跨模块 API 头（导出 `pwrseq_qcom_wcn_set_ol_cpr()`，被 `ath12k/qmi.c:3204` 调用）。

### 1.2 逐 hunk 分类

行号为 **payload 版**行号（diff 头 `+a,b`）。分类：**A**=WCN7861 时序数据(可上游) / **B**=框架扩展(需论证) / **C**=私有 hack(不上游) / **D**=纯重写。

| hunk | payload 行段 | 内容摘要 | 分类 | 去留 |
|---|---|---|---|---|
| **H1** | `+9,48`（9–56） | 6 个头文件；新 `struct pwrseq_qcom_wcn_vreg_cfg`；pdata 增 `vreg_cfgs`、`bt_reset_delay_ms`、`bt_wlan_off_delay_ms`、`bt_power_off_delay_ms`；新 `struct pwrseq_qcom_wcn_map`；ctx 增 `dev`、`qmp`、`pdc_lock`、`vreg_pdc_map`、`pmu_vreg_map` | **混合 A/B/C** | 拆分（见 1.3） |
| **H2** | `+59,206`（59–264） | 新增 `parse_map()` / `map_find()` / `validate_maps()` / `qmp_send()` / `qmp_put()` / `pdc_init()`（AOSS PDC 初始化，发送裸 firmware 命令串） | **C 私有 hack** | **不上游**（约 206 行） |
| **H3** | `+294,123`（294–416） | `vregs_unvote()` / `vregs_configure()` + 改写 `vregs_enable/disable`（逐轨 set_voltage/set_load，唯一目的是服务 `vreg_cfgs`） | **B 框架扩展** | 最小子集剔除（`-2/+121`） |
| **H4** | `+490,50`（490–539） | `bt_enable()`：regulator 使能后把 BT_EN 拉低持稳 `bt_reset_delay_ms`；观测 WLAN_EN=0 时等 `bt_wlan_off_delay_ms` 再释放 BT_EN | **A 时序数据** | **可上游**（~40 行新逻辑） |
| **H5** | `+544,12`（544–555） | `bt_disable()`：拉低 BT_EN 后等 `bt_power_off_delay_ms` 再关 regulator | **A 时序数据** | **可上游**（~10 行） |
| **H6** | `+772,45`（772–816） | `pwrseq_wcn7861_vreg_cfgs[]` 数据表（7 条电压/负载）+ `pwrseq_wcn7861_of_data` + `static_assert` | **混合 A/B** | `of_data` 可上游；`vreg_cfgs` 剔除（见 1.3） |
| **H7** | `+864,256`（864–1119） | OL-CPR 动态 PDC 电压投票：`pwrseq_qcom_wcn_pdc_vote`、`adjust_voltage()`、`vote_index()`、`send_voltage()`、`apply_ol_cpr()`；**导出** `pwrseq_qcom_wcn_set_ol_cpr()` | **C 私有 hack** | **不上游**（约 256 行） |
| **H8** | `+1125,43`（1125–1167） | `probe`：`ctx->dev`、`mutex_init`、两次 `parse_map`、`validate_maps`、`pdc_init` 调用 | **C 私有 hack** | 最小子集仅保留 `ctx->dev`（1 行） |
| **H9** | `+1267,10`（1267–1276） | `of_device_id` 增 `qcom,wcn7861-pmu` → `&pwrseq_wcn7861_of_data` | **A 芯片数据** | **可上游** |

### 1.3 最小可上游子集 vs 必须拆出的部分

**可上游子集（建议出 1–2 枚补丁，净增约 70 行）**
1. `of_device_id` 增 `qcom,wcn7861-pmu`（H9）。
2. `pwrseq_wcn7861_of_data`：沿用 `pwrseq_wcn7850_vregs`（payload 即如此），`.pwup_delay_ms = 50`、`.targets = pwrseq_qcom_wcn_targets`（与 wcn7850 完全一致）——**不含 `vreg_cfgs`**。
3. BT 时序三字段（H1 子集）+ H4/H5 逻辑：把 `bt_reset_delay_ms`/`bt_wlan_off_delay_ms`/`bt_power_off_delay_ms` 作为 **WCN7861 时序数据** 放入 pdata，`bt_enable/bt_disable` 按需 msleep。

**必须拆出去（不上游，建议留 M4 下游层）**
- `vreg_cfgs` 逐轨 set_voltage/set_load（H1/H3/H6）——**Q3 违例**：payload 注释自承“仅 enable 变量 RPMh regulator 会停在最低约束 500/500/1224 mV”。电压范围是**硬件事实**，上游姿势 = 写进 **DT 里 regulator 节点的 `regulator-min/max-microvolt`**，而不是驱动里强制投票。⇒ 删除机制、改 DT。
- AOSS QMP PDC 初始化与 OL-CPR 动态投票（H2/H7/H8 + H1 的 map/qmp 字段 + 新头 `qcom_wcn.h`）：QMI 固件下发的 OL-CPR 电压经 `pwrseq_qcom_wcn_set_ol_cpr()` 导出符号回灌到 pwrseq，再转成裸 AOSS 命令串 `{class: wlan_pdc, ss: ..., res: ....v, upval/dwnval: N}`。这是**高通下游私有固件接口**，不在 pwrseq 框架语义内，且把 firmware 命令串塞进 DT（`qcom,pdc-init-table`）。⇒ 不上游。

### 1.4 结论

**591 行可以拆出可上游子集**（不是“无法拆”）：≈70 行（新 compatible + of_data + BT 时序）可上游；其余 ≈520 行（PDC/QMP/OL-CPR/逐轨电压投票）属下游私有层，其中逐轨电压投票另可在 **DT regulator 约束**里正解。证据命令见 §6。


## 2. `qcom,qca6390-pmu.yaml` 46 行改动分类

### 2.1 基线事实（可复跑）

```sh
cd /home/xuqianhui1001/y700-elden
diff -u build/m3-6-worktree/Documentation/devicetree/bindings/regulator/qcom,qca6390-pmu.yaml \
        build/m1-upstream/clean-tree/Documentation/devicetree/bindings/regulator/qcom,qca6390-pmu.yaml > /tmp/bind.diff
grep -c '^@@' /tmp/bind.diff      # 2 个 hunk
grep -c '^+[^+]' /tmp/bind.diff   # 46 insertions
grep -c '^-[^-]'  /tmp/bind.diff  # 0  deletions
```
⇒ 纯新增 **+46 / -0**（与缺口矩阵「qca6390-pmu.yaml 46 行」一致），无删除。

### 2.2 逐项分类

| 项 | 位置 | 内容 | 分类 | 去留 |
|---|---|---|---|---|
| **E1** | `compatible.enum` | 增 `qcom,wcn7861-pmu` | **可上游** | 保留（须与驱动同片） |
| **E2** | 属性 `qcom,qmp` | phandle → AOSS 消息 RAM | **vendor 私货** | 剔除 |
| **E3** | 属性 `qcom,pdc-init-table` | string-array，**裸 AOSS/QMP 命令串**（如 `{class: wlan_pdc, ss: rf, res: s5f.v, upval: 876}`） | **vendor 私货（Q3 违例）** | 剔除：固件命令串不属于 DT |
| **E4** | 属性 `qcom,vreg-pdc-map` | `rail:subsystem` 映射串 | **vendor 私货** | 剔除 |
| **E5** | 属性 `qcom,pmu-vreg-map` | `FIRMWARE_PIN:rail` 映射串 | **vendor 私货** | 剔除 |
| **E6** | `allOf[].then` | wcn7861 的 required 集合含 E2–E5 + 7 个 supply + `wlan-enable-gpios` | **混合** | 保留 supply 与 gpios，删除 E2–E5 四个 required |

**可上游子集（binding 侧最小改动）** = E1 + E6（去掉 E2–E5）：
- `compatible.enum` 增 `qcom,wcn7861-pmu`；
- `then.required` = `vdd-supply`, `vddio-supply`, `vddio1p2-supply`, `vddaon-supply`, `vdddig-supply`, `vddrfa1p2-supply`, `vddrfa1p8-supply`, `wlan-enable-gpios`。

### 2.3 是否需新 yaml？

**不需要。** 理由：
- WCN7861 的 PMU 就是 qca6390-pmu.yaml 覆盖的同一“QCA6390 封装/PMU LDO 输出”族（已含 wcn6750/6855/7850）。加一个 enum + `then` 供应集合即自洽。
- E2–E5 描述的是 **pwrseq/AOSS 行为**，不是 regulator PMU 的硬件属性；即使哪天要上游，也不该进 `regulator/` 下这份 yaml，而应落到 pwrseq 类 binding（或根本不进 DT）。**把它们留在本 yaml 会污染 regulator subschema**，是 review 必拦点。

### 2.4 与上游 DTS 的呼应（加分点）

`build/m3-6-worktree/arch/arm64/boot/dts/qcom/sm8750-mtp.dts:262`（**pristine 7.3-rc7**）已有注释：
> “MTPs rev 2.0 (power grid v8) come with two different WiFi chips: **WCN7850 and WCN786x**.”
即上游已知 sm8750 MTP 存在 WCN786x 变体，只是当前只写了 WCN7850 节点。⇒ 提交 `qcom,wcn7861-pmu` 有现成的处境支撑（可引 sm8750-mtp.dts 注释作 rationale）。

### 2.5 依赖提醒

若按 §5 提交“最小 binding 补丁”（删 E2–E5），**elden 板 DTS 必须同步删除** `qcom,qmp`/`qcom,pdc-init-table`/`qcom,vreg-pdc-map`/`qcom,pmu-vreg-map` 四个属性（`additionalProperties: false` 会拒），否则 `dtbs_check` 红。这两件事必须同一系列内交付。


## 3. `hci_qca` PERI 固件下载（393 行，属 B3/M4）

### 3.1 基线事实与规模（可复跑）

```sh
cd /home/xuqianhui1001/y700-elden
P=build/m3-6-worktree/drivers/bluetooth; C=build/m1-upstream/clean-tree/drivers/bluetooth
diff -u $P/hci_qca.c $C/hci_qca.c > /tmp/hci.diff
echo "hunks=$(grep -c '^@@' /tmp/hci.diff) ins=$(grep -c '^+[^+]' /tmp/hci.diff) del=$(grep -c '^-[^-]' /tmp/hci.diff)"
# hunks=31 ins=368 del=25   （与缺口矩阵「hci_qca 393 行」一致）
diff -u $P/btqca.c $C/btqca.c > /tmp/btqca.diff
echo "btqca hunks=$(grep -c '^@@' /tmp/btqca.diff) ins=$(grep -c '^+[^+]' /tmp/btqca.diff) del=$(grep -c '^-[^-]' /tmp/btqca.diff)"
# btqca hunks=13 ins=58 del=10
grep -n "QCA_WCN7861" $C/btqca.h   # 164: enum qca_btsoc_type 末端新增
```

**重要：`hci_qca.c` 的 393 行 diff 里含版本漂移。** payload 树是 Linux 7.2.0，pristine 是 7.3-rc7，以下 `-`/`+` 是**上游更新**而非 payload 意图，打补丁时以 pristine 为准：
- `pwrseq_power_on/off`（payload，7.2 旧名） vs `pwrseq_enable/disable`（pristine，7.3 名）；
- `HCI_VENDOR_PKT`（payload） vs `HCI_EV_VENDOR`（pristine）；
- ACPI 表位置化初始化（payload） vs 指定初始化 `.id = ...`（pristine）；
- `qca_power_off()` 的 `HCI_UART_PROTO_READY` 守卫与注释措辞。

⇒ **payload 自身新增 ≈350 行**（PERI 协议） + `btqca.c` **+58/-10**（`case QCA_WCN7861:` 折叠 + IBS 第二字节 + baud quirk 键）。

### 3.2 新增的接口 / 回调 / 机制清单（payload 自身）

| # | 机制 | 位置（payload hci_qca.c） | 说明 |
|---|---|---|---|
| I1 | 新 packet type `0x31`（command）/ `0x34`（event） | 宏 `QCA_PERI_COMMAND_PKT`/`QCA_PERI_EVENT_PKT` | 非 HCI、非 H4 标准的 UART 字节协议 |
| I2 | 新 opcode `0xfff0`(EDL)/`0xfff1`(general) | 宏 `QCA_PERI_EDL_OPCODE`/… | PERI 阶段自己的命令集 |
| I3 | H4 接收表扩展 | `qca_recv_pkts[]` 增 `.type = 0x34, .recv = qca_recv_peripheral` | 往共享 H4 demux 表塞新类型 |
| I4 | 新接收回调 | `qca_recv_peripheral()`（~50 行） | 解析 PERI event、匹配 opcode/subopcode、complete |
| I5 | `qca_data` 新字段 | `peri_state`/`peri_opcode`/`peri_subopcode`/`peri_status`/`peri_ssid`/`peri_supported`/`peri_notify`/`peri_done`/`peri_ready` | 内嵌 pre-BT 状态机 |
| I6 | 请求/下载/唤醒/初始化 | `qca_peripheral_request/wake/download/setup()`（~230 行） | 分段（243 B）下载 + 8 Mbaud 切换 + TLV/NVM/ELF 校验 |
| I7 | IBS 唤醒复用 | `qca_peripheral_wake()` 调 `send_hci_ibs_cmd(HCI_IBS_WAKE_IND)`；`qca_ibs_wake_ack()` 在 `QCA_PERI_WAKE` 态提前返回 | 复用 IBS 握手 |
| I8 | 波特率上限 | `QCA_BAUDRATE_8000000` + `baudrate > QCA_BAUDRATE_8000000` | 7.3-rc7 无该常量 |
| I9 | baud quirk | `qca_wcn7861_uses_current_baudrate()`：按 `(soc_id,rom_ver,product_id)` 元组跳过 SetBaudRate | 硬编码元组 |
| I10 | 新固件文件 | `qca/brhperifw20.tlv`、`qca/brhperinv20.bin`、`qca/tmel_peach_20.elf` | `MODULE_FIRMWARE` 3 条 |
| I11 | 新 soc 数据 | `qca_soc_data_wcn7861`（6 vregs + caps）、`qcom,wcn7861-bt` | 芯片数据 |

### 3.3 为何不能复用 WCN7850 路径（技术事实）

- WCN7850 路径 = 标准 `hci_qca` 流程：HCI vendor cmd 下发 `qca_uart_setup()` → `qca_download_firmware()`（TLV rampatch/NVM）。
- WCN7861 在 **BT 固件下载之前**多出一个 **PERI（peripheral controller / TME-L）阶段**：raw UART 上按 `0x31/0x34` 收发、用 EDL/general opcode 做分段下载，并在此阶段内把 UART 切到 **8 Mbaud**；之后才回到标准 HCI/TLV 流程。
- 该阶段**不是 HCI 命令**，无法用 `qca_send_vendor_cmd` 表达；packet type `0x34` 也不在 H4 标准类型里。⇒ 必须新增接收路径与状态机，不能简单参数化 WCN7850。

### 3.4 「先与 linux-bluetooth 谈接口」的问题清单

1. **归属**：pre-BT 的 PERI/EDL 阶段应留在 `hci_qca` 作「pre-setup 阶段」，还是独立成 serdev/standalone driver（或纳入 `btqca` 的 firmware-loader 层）？上游偏好哪种？
2. **H4 表扩展**：向 `qca_recv_pkts[]` 增一个非标准 `.type`（0x34）是否可接受？还是希望 `hci_uart` 的 recv 表提供通用「额外 type 注册」能力？
3. **IBS 复用**：PERI wake 复用 `HCI_IBS_WAKE_IND` 与 wake-ack 路径是否合规，还是应有独立握手以免污染 IBS 语义？
4. **状态机形态**：`qca_data` 内嵌 `peri_*` 状态 + 两个 `completion`（`peri_done`/`peri_ready`，超时 3000 ms）。是否应抽为独立 struct/文件？同步与超时值是否可接受？
5. **固件与格式**：`brhperifw20.tlv`/`brhperinv20.bin`/`tmel_peach_20.elf` 可否进 linux-firmware？TLV tag 17/27 语义（8 Mbaud、`|=1`）、ELF 校验有无公开文档？
6. **8 Mbaud**：把上限从 `QCA_BAUDRATE_3200000` 提到 `QCA_BAUDRATE_8000000`（常量在 7.3-rc7 不存在）是否可接受？serdev/串口层 8M 是否满足？
7. **quirk 键**：`qca_wcn7861_uses_current_baudrate()` 用 `(soc_id,rom_ver,product_id)` 元组硬编码，上游更接受元组 quirk，还是 DT/版本属性？
8. **复用边界**：PERI 之后 WCN7861 能否完全复用 WCN7850 的 `qca_uart_setup`/TLV 下载？哪些是 WCN7861 特有、必须独立？
9. **D3 排除**：`btqca.c` 中 IBS/深睡位的实验性改法（policy §3 D3）根因未定，**任何 PERI 系列都不得夹带**——请确认这块按未定案处理。

### 3.5 能否先用小补丁打开局面

**能。** 建议先发一枚「纯数据、零协议」的探路补丁（P-A），把「新芯片识别」与「PERI 协议」解耦：
- `btqca.h`：`enum qca_btsoc_type` 末端增 `QCA_WCN7861`；
- `hci_qca.c`：`qcom,wcn7861-bt` of_device_id + `qca_soc_data_wcn7861`（vregs/caps）+ 所有 `case QCA_WCN7861:` 与 `QCA_WCN7850` **并列复用**（fwname `hmt*btfw`、nvm `hmtnv`、soc-logging）；
- `btqca.c`：WCN7861 复用 WCN7850 的命名分支；
- **不含 I1–I11 中任何 PERI 项**（即 `qca_peripheral_*`、PACKET 0x31/0x34、8Mbaud、quirk 全部留到后续 RFC）。

这样 reviewer 先确认「WCN7861 就是 WCN7850 的命名/供应变体」，再单独评审真正需要新接口的 PERI 阶段。


## 4. `ath12k` PEACH ~800 行拆解方案 + M4 立项建议

### 4.1 基线与规模（可复跑 + 方法说明）

**关键前提**：payload 树是 Linux 7.2.0、pristine 是 7.3-rc7，`ath12k/` 在两者间有**大量上游重构**（`git diff` 净差含 `-206` 等删除，多为版本漂移）。因此**不能**用 pristine↔payload 的整目录 diff 当 payload 改动量，改用 **token 定位**（`peach|110e|board_api1|tmel|ol_cpr|pdc`）逐块测量：

```sh
cd /home/xuqianhui1001/y700-elden/build/m1-upstream/clean-tree/drivers/net/wireless/ath/ath12k
grep -rin "peach\|110e\|board_api1\|tmel" --include=*.c --include=*.h . | head
# 定位：core.h / hw.h / core.c / qmi.c / pci.c / wifi7/{hw,hal,pci}.c
```

```sh
# 复跑块计数（行段来自 grep）
sed -n '806,901p' wifi7/hw.c | wc -l     # 96   peach hw_params 条目
sed -n '53,59p'   wifi7/hal.c | wc -l    # 7    peach HAL 条目
sed -n '22,22p;38,38p;171,190p' wifi7/pci.c | wc -l   # ~22 device id + probe case
grep -c 'board_api1_only' core.c         # 4 个 gating 点
```

**注**：缺口矩阵的「~800 行」是 ath12k 目录级粗估（含部分版本漂移）。按 token 逐块测量，PEACH 相关 payload 自身改动 ≈ **ath12k 侧 ~470 行 + pwrseq 侧 ~520 行（见 §1）**。

### 4.2 拆解：三堆

#### (a) 纯数据表 / 板级（可先出 RFC（~127 行））

| 文件 | 行段 | 行数 | 内容 |
|---|---|---|---|
| `wifi7/hw.c` | 806–901 | **96** | `"peach hw2.0"` hw_params：`.hw_ops = &qcc2072_ops`、WCN7850 CE/ring/mhi/wmi、`dir = "PEACH/hw2.0"` |
| `wifi7/hal.c` | 53–59 | 7 | `[ATH12K_HW_PEACH_HW20]` = qcc2072 hal_ops + qcc2072_regs |
| `core.h` | 161 | 1 | `ATH12K_HW_PEACH_HW20` 枚举 |
| `wifi7/pci.c` | 22,38,171–190 | ~22 | `PEACH_DEVICE_ID 0x110e`、id 表行、probe case（bdf_search/msi/window 0x3278/soc v2→PEACH_HW20） |
| `pci.c` | 1856 | 1 | `MODULE_FIRMWARE("ath12k/PEACH/hw2.0/*")` |

**要点（对 M4 有利）**：`ATH12K_HW_QCC2072_HW10` / `qcc2072_ops` / `hal_qcc2072_ops` / `qcc2072_regs` **都已在 pristine 7.3-rc7 上游**（见 `wifi7/pci.c:22/37/158`、`wifi7/hw.c:718`）。⇒ PEACH 数据表是**「复用已有 QCC2072 datapath + WCN7850 CE 布局」的新芯片条目**，不是新框架，争议最小。

#### (b) `board_api1_only`（框架扩展，小、可独立）

| 文件 | 内容 | 行数 |
|---|---|---|
| `core.c` | `fetch_bdf`/`fetch_regdb` 中 4 处 `if (ab->hw_params->fw.board_api1_only) goto api1;` + API1/API2 分支与调试打印 | ~25 |
| `hw.h` | `.board_api1_only:1` 位域 | 1 |

board API1（`board.bin`/单文件）vs API2（`board-2.bin`）是**通用概念**，非 PEACH 私有；可作为独立小补丁提交，但需 ath12k 维护者确认语义与命名。

#### (c) TME-L 固件下载 + OL-CPR（框架扩展，须 RFC）

| 文件 | 内容 | 行数 |
|---|---|---|
| `qmi.h` | `qmi_wlanfw_pmu_param_v01`/`pmu_cfg_v01`（~15）、`ol_cpr_cfg` 字段（2）、TME-L enum/req/resp（~24）、`tme_lite_mem`（1） | ~42 |
| `qmi.c` | `qmi_wlanfw_pmu_param_v01_ei`/`pmu_cfg_v01_ei`（~80）、`ath12k_qmi_apply_ol_cpr()`（~40）、`ath12k_qmi_tme_lite_{free,load}()`+`wlanfw_tme_lite_info_send()`（~135）、两处调用点（~18） | ~273 |
| `core.c`/`hw.h` | `.download_tme_lite:1` + `ATH12K_TME_LITE_FILE "tmel.bin"` + gating | ~5 |
| **pwrseq 侧** | §1 的 PDC/QMP/OL-CPR 导出 API（`set_ol_cpr` + `qcom_wcn.h` + H2/H7/H8） | **~520** |

**性质**：TME-L 是**新的 WLFW/QMI 消息**（`QMI_WLANFW_TME_LITE_INFO_REQ_V01 = 0x005B`）与**新固件阶段**（`tmel.bin`）；OL-CPR 是**跨模块私有接口**（fw 通过 QMI 下发电压 → ath12k 调 pwrseq 导出符号 → 转 AOSS 命令串）。两者都属「新接口」，须先与 ath12k/网络维护者谈。

### 4.3 M4 立项建议

| 序 | 内容 | 形态 | 判据 |
|---|---|---|---|
| **M4-1** | **PEACH 纯数据表**（(a) ~127 行）：device id + hw_params + hal 条目 + firmware 名 | **可先出正式 RFC/补丁** | 复用上游 QCC2072；`pci17cb,110e` 是干净的新芯片录入；先按 `board_api1_only=false`、`download_tme_lite=false` |
| **M4-2** | **board_api1_only**（(b) ~26 行） | **独立小补丁** | 通用 API1/API2 选择；需维护者确认命名 |
| **M4-3** | **TME-L 固件下载**（(c) 的 qmi.h/qmi.c/core.c） | **RFC**（先谈接口：新 QMI 消息、固件命名、阶段归属） | 需解释为何 TME 必须在 M3 之后、AUX 之前；`hardware-restricted 继续` 行为要单独说明 |
| **M4-4** | **OL-CPR → pwrseq 跨模块 API**（(c) 的 pwrseq 侧 + apply_ol_cpr） | **RFC，预期被 NAK ⇒ 隔离下游层** | vendor 私有固件电压接口，不属 pwrseq 框架语义；不阻塞 M4-1/M4-2 |

**给维护者的拆法**：把「PEACH 这样一块能跑的新芯片（复用 QCC2072）」与「Peach 私有 TME-L/OL-CPR 流程」**分成两个话题**——前者按普通 ath12k 新硬件支持评审，后者单独立 RFC。这样即使 OL-CPR 被 NAK，M4-1/M4-2 仍能落地。


## 5. 本次可实际交付的补丁草案

补丁目录：`patches/upstream/m3-6-2026-10-13/`；基底 = pristine `24a19b953e`（Linux 7.3-rc7）。均英文 commit + `Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`。

| # | 文件 | 逻辑 | 改动 | 上游判定 |
|---|---|---|---|---|
| **0001** | `regulator: qcom,qca6390-pmu: document the WCN7861 PMU` | `qca6390-pmu.yaml` 增 `qcom,wcn7861-pmu` enum + `then.required` 供应集合（含 `vddio1p2-supply`、`wlan-enable-gpios`） | 1 file, +16 | **可上游**（纯 binding，优先） |
| **0002** | `power: sequencing: pwrseq-qcom-wcn: add WCN7861 PMU support` | pdata 增 3 个 BT 时序字段；`ctx->dev`；`bt_enable/bt_disable` 按需 msleep；`pwrseq_wcn7861_of_data`（复用 wcn7850 轨道）；of_device_id 增 compatible | 1 file, +48 | **可上游**（新芯片 + 时序数据） |

**明确不包含**（§1/§2 判定为私有或 Q3 违例）：`vreg_cfgs` 逐轨电压投票、AOSS QMP PDC（`qcom,pdc-init-table`/`vreg-pdc-map`/`pmu-vreg-map`/`qcom,qmp`）、OL-CPR 导出 API（`pwrseq_qcom_wcn_set_ol_cpr` + `include/linux/pwrseq/qcom_wcn.h`）、ath12k TME-L/OL-CPR、hci_qca PERI。

### 5.1 机械验收（原始输出）

```sh
# 前置：worktree 基于 pristine 24a19b953e；补丁由 git format-patch 从 pristine 上的提交导出
cd build/m3-6-worktree
for p in patches/upstream/m3-6-2026-10-13/*.patch; do
  build/m1-upstream/clean-tree/scripts/checkpatch.pl --strict --no-tree "$p"
done
```
```
0001-...WCN7861-PMU.patch           total: 0 errors, 0 warnings, 0 checks, 28 lines checked
  ... has no obvious style problems and is ready for submission.
0002-...WCN7861-PMU-sup.patch       total: 0 errors, 0 warnings, 0 checks, 90 lines checked
  ... has no obvious style problems and is ready for submission.
```

```sh
# 编译（copy clean-tree .config → olddefconfig → 编 sequencing 目录）
cp build/m1-upstream/clean-tree/.config .config
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig      # rc=0
grep CONFIG_POWER_SEQUENCING_QCOM_WCN= .config                          # =y
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/power/sequencing/   # rc=0
```
```
  CC      drivers/power/sequencing/pwrseq-qcom-wcn.o
  AR      drivers/power/sequencing/built-in.a
MAKE_RC=0   （日志中 error:/warning: 计数 = 0）
```

```sh
# binding 自检
dt-doc-validate Documentation/devicetree/bindings/regulator/qcom,qca6390-pmu.yaml   # rc=0
```

```sh
# 两枚补丁在普通 pristine 上可应用
git switch --detach 24a19b953e
git apply --check 0001-*.patch && git apply --check 0002-*.patch
# APPLY_OK 0001 / APPLY_OK 0002
```

### 5.2 依赖与注意

- 0001 未把 `qcom,qmp` 等 vendor 属性写进 binding；因此**elden 板 DTS 必须同系列删掉**这四个属性（`additionalProperties: false`），否则 `dtbs_check` 红（见 §2.5）。
- 0002 只让芯片被识别并提供 BT 时序；**WCN7861 WLAN 所需的较高供电约束应在 DT regulator 节点给足**（即 `vreg_cfgs` 的 DT 替代），否则仅 enable 会停在最低约束（payload 注释自承 500/500/1224 mV）。
- **下一枚可交付物（本轮未生成，§3.5 P-A）**：`btqca.h` 加 `QCA_WCN7861` + `hci_qca.c` `qcom,wcn7861-bt` + `qca_soc_data_wcn7861` + WCN7861 复用 WCN7850 命名分支，**不含 PERI**。


## 6. 验收原始输出 + 产物清单 + 未决问题 + 未上机声明

### 6.1 关键数字（一页）

| 项 | 值 | 证据 |
|---|---|---|
| `pwrseq-qcom-wcn.c` 净 diff | **+589 / -2 = 591**（9 hunk） | `/tmp/pwrseq.diff` |
| 其中可上游子集 | **≈70 行**（新 compatible + of_data + BT 时序） | §1.3 |
| 其中须拆出（PDC/QMP/OL-CPR/电压投票） | **≈520 行** | §1.3 |
| `qca6390-pmu.yaml` diff | **+46 / -0**（2 hunk） | `/tmp/bind.diff` |
| 其中 vendor 私货 | 4 个属性 + 其 required = 大部分 | §2.2 |
| `hci_qca.c` diff | **+368 / -25**（31 hunk），含 7.2→7.3 漂移 | `/tmp/hci.diff` |
| `btqca.c` diff | **+58 / -10**（13 hunk） | `/tmp/btqca.diff` |
| ath12k PEACH 相关块 | ath12k 侧 **≈470 行** + pwrseq 侧 ≈520 行 | §4.1/§4.2 |
| 实际交付补丁 | **2 枚**（checkpatch 0E/0W/0C，编译 rc=0，dt-doc-validate rc=0，apply --check OK） | §5.1 |

### 6.2 产物清单

| 路径 | 内容 |
|---|---|
| `reports/m3-6-wireless-slice-20261013.md` | 本报告 |
| `patches/upstream/m3-6-2026-10-13/0001-regulator-qcom-qca6390-pmu-document-the-WCN7861-PMU.patch` | binding 补丁（可上游） |
| `patches/upstream/m3-6-2026-10-13/0002-power-sequencing-pwrseq-qcom-wcn-add-WCN7861-PMU-sup.patch` | pwrseq 驱动补丁（可上游） |
| `patches/upstream/m3-6-2026-10-13/README.md` | 补丁说明与验收摘要 |
| `build/m3-6-worktree` | worktree，分支 `m3-6/draft` @ `eda49f0adf`（基底 `24a19b953e`） |
| `/tmp/{pwrseq,bind,hci,btqca}.diff` | 临时 diff（可复现，非必需归档） |

### 6.3 未决问题

1. **WCN7861 WLAN 供电约束的具体 DT 值**：payload 用 `vreg_cfgs` 强制 S4D/S5F/S7I 到特定区间；正确姿势是 DT regulator `regulator-min/max-microvolt`，但**具体值需上机确认**。本轮只给方法与子集，未给数值补丁。
2. **BT 时序三值（50/100/100 ms）的来源与上游接受度**：来自下游 Peach `btpower`；作为 pdata 数据是否被 pwrseq 维护者接受，待评审（也可能希望进 DT）。
3. **`qcom,wcn7861-pmu` 命名**：上游 `sm8750-mtp.dts` 注释写 “WCN786x”，需确认供应商偏好 `wcn7861` 还是族名。
4. **PERI 协议接口归属**：§3.4 的 9 个问题待 linux-bluetooth 答复。
5. **ath12k TME-L / OL-CPR 接口**：§4.3 的 RFC 问题待 ath12k/网络维护者；OL-CPR 预期被 NAK ⇒ 隔离下游。
6. **版本漂移测量**：无法取得上游 v7.2 精确基座（`torvalds` tag fetch 失败，`cat-file` 触发 partial-clone 懒加载网络卡死 600 s），故 ath12k/hci_qca 的“payload 自身改动量”用 **token 定位近似**，非精确 diff；pwrseq/binding 因 7.2→7.3 无漂移，数字精确。

### 6.4 未上机声明

**本片为纯主机侧任务，未接触任何设备。** 所有结论为静态分类 + 源级 diff + 编译/binding 自检；**功能结论只能写「未上机/未证实」**：
- WCN7861 WLAN/BT **能否在主线 Linux 上工作**、门控时序是否正确、DT 供电值是否足够 —— **未上机，未证实**。
- 本片交付的 2 枚补丁**未发送**（`git send-email` 未执行），仅备料。

