# UEFI ③ EUD 可行性（USB 口里的隐藏 JTAG/SWD）——真调试器方向

> 2026-11-01。性质：**只读调研 + 主机侧静态取证**（设备接触仅 ssh 只读：dmesg / sysfs / `/proc/device-tree` / 模块元数据；
> 零写盘、无 fastboot、无 reboot、未接调试器）。派工：UEFI lane D。
> 背景：`uefi-observability-pivot-20261101.md` §0 第 6 条。
> 证据分级：`已证` = 今日命令输出 / file:line；`外部` = 上游原文/仓库文档；`未证` = 推断。

---

## §0 结论（先看这里）

1. **硬件有、驱动有、DT 没有**：本机内核 `CONFIG_USB_QCOM_EUD=m`、`qcom_eud.ko` 就在
   `/lib/modules/$(uname -r)/kernel/drivers/usb/misc/qcom_eud.ko`（alias `of:N*T*Cqcom,eud`），
   但**运行中的 DT 里 "eud" 出现 0 次** ⇒ `probe` 永远不会发生。
   `dmesg | grep -i eud` 空、`lsmod | grep eud` 空、`/sys/bus/platform/devices/*eud*` 不存在：**三处同时为空**。`已证`
2. **固件里有 EUD 代码，而且每次启动都在跑**：XBL 二进制含 `boot_eud.c` / `EUD Init` / `EUD Post PMIC Init` /
   `EUD wait %ds` / `qusb_dci_eud_init` / `usb_eud_serial`；`logfs` 的 **10 段** SBL1 日志里
   `EUD Post PMIC Init` 10/10、`qusb_dci_eud_init` 10/10、`EUD Init` 10/10、`usb_eud_serial` 10/10。
   **但 10 段里 "EUD wait" 一次都没出现** ⇒ 「XBL 会等调试器挂上」这件事在本机**未被证实**。`已证`（字符串/日志）
3. **工具链齐了**：Qualcomm 2025-02 开源 `github.com/quic/eud`（GPL-2.0 OR BSD-3）；
   OpenOCD **上游**已内置 `eud` SWD adapter（openocd.org 手册已列，对应 gerrit 9773）；`linux-msm/openocd` 的
   `eud-rebased` 分支有 quickstart（`./configure --enable-eud`，`-f tcl/interface/eud.cfg -f tcl/target/qualcomm/qcs6490.cfg`，
   README 明说 "doesn't seem to be soc specific"）。`外部`
4. **但「早期执行」这条路默认不通**：Qualcomm 官方 OpenOCD 文档（80-70029-12）明确
   「**Kernel debug during bootup isn't supported until you manually enable EUD in the console shell or adb**」，
   且「**每次重启都要重新 enable**」；支持面只到 QCS6490 / IQ-9100 / IQ-9075。
   也就是说 EUD 默认是**Linux 起来之后**才开，正好错开我们"载荷死在 pre-Linux"的窗口。`外部`
5. **本机能不能用 = 三个缺口，不是三个开关**：
   ① DT 缺 `qcom,eud` 节点（必需）；
   ② SM8750 用的是 m31 eusb2 PHY，其 **EUD 路由寄存器**（vendor DT 的 `eud_enable_reg` = 0x88e2000 4 B、
      `eud_detect_reg` = 0xc278000）**主线 `phy-qcom-m31-eusb2.c` 没有实现**；
   ③ 使能要写 `eud_mode_mgr2`（0x88e2000）走 **SCM 安全调用**，本机是否放行**未证**。
   粗估：主机侧 0.5–1 人日 + 1–2 次上机（不接调试器的部分 0 物理风险）。`已证`+`未证`
6. **建议**：对「载荷死在哪」这个当前问题，EUD **不是** DDR 黑匣子的替代；先做 §4 L0（0 成本、一根线、
   只看 `lsusb`）判定 XBL 到底有没有 arm EUD，再决定是否投 L1。`未证`

---

## §1 本机 EUD 现状（实测）

### 1.1 驱动/内核侧

| 检查 | 结果 | 证据 |
|---|---|---|
| 内核配置 | `CONFIG_USB_QCOM_EUD=m`、`CONFIG_QCOM_SCM=y`、`CONFIG_USB_ROLE_SWITCH=y`、`CONFIG_TYPEC=y` | 设备 `zcat /proc/config.gz`，2026-11-01 22:38 CST 采集 |
| 模块文件 | `/lib/modules/7.3.0-rc7-debug-…/kernel/drivers/usb/misc/qcom_eud.ko` 存在 | 同上 |
| 模块元数据 | `alias: of:N*T*Cqcom,eud`、`description: QTI EUD driver`、`intree: Y` | 同上 |
| `dmesg \| grep -i eud` | **空**（rc=1） | 同上 |
| `lsmod \| grep eud` | **空**（rc=1） | 同上 |
| `/sys/bus/platform/devices/*eud*` | **No such file or directory** | 同上 |
| `/sys/bus/platform/drivers/` 里的 eud | **无** | 同上 |
| `/proc/device-tree` 里 `*eud*` | **0 个** | 同上 |
| USB role switch | `a600000.usb-port0-role-switch`、`a600000.usb-port1-role-switch` 已注册；`/sys/class/udc` 有 `a600000.usb` | 同上 |

结论：驱动侧**唯一缺的就是 DT 节点**（`qcom_eud.c:249` 只匹配 `"qcom,eud"`），probe 路径断在 `of_match`。`已证`

### 1.2 运行 DT（`/sys/firmware/fdt`，154 766 B，今日抓取）

产物：`reports/artifacts/uefi-eud-20261101/live-fdt.dtb`（+ 反编译 `live-fdt.dts`）。

```
$ grep -c -i eud live-fdt.dts      → 0
$ grep -c -i "msm-eud" live-fdt.dts → 0
```

同 DT 里相关件都在（`live-fdt.dts`）：

- `phy@88e3000`：`compatible = "qcom,sm8750-m31-eusb2-phy"`，`status = "okay"`（第 2268–2280 行）；
- `usb@a600000`：`compatible = "qcom,sm8750-dwc3","qcom,snps-dwc3"`，`usb-role-switch`、`port@0/1/2`（第 2332 行起）；
- Type-C：`/sys/class/typec/port0`、`port1` 两个口都在。

**缺的只有 `qcom,eud@88e0000` 这一块。** `已证`

### 1.3 静态对照：vendor DT（同 SoC `SunP`）里 EUD 节点是 **status="ok"**

反编译 `backup/stock-elden/dtb/10_dtbdump_Qualcomm_Technologies,_Inc._SunP_SoC.dtb`：

```dts
6476: qcom,msm-eud@88e0000 {
6477:     compatible = "qcom,msm-eud";
6478:     interrupt-names = "eud_irq";
6479:     interrupt-parent = <0x25>;
6480:     interrupts = <0x0b 0x04>;
6481:     reg = <0x88e0000 0x2000 0x88e2000 0x1000>;
6482:     reg-names = "eud_base", "eud_mode_mgr2";
6483:     qcom,secure-eud-en;
6484:     qcom,eud-utmi-delay = [00 ff];
6485:     status = "ok";
6486:     phandle = <0x348>;
6487: };
```

另有两处旁证（同一文件）：

- `18547: dummy-eud { compatible = "arm,coresight-dummy-sink"; coresight-name = "coresight-eud"; }`
  + `25774: replicator_swao_out_eud` ⇒ **QDSS trace 也能从 EUD 口出来**（TRACE 通道）。
- `20918–20920`: `qcom,usb-m31-eusb2-phy` 的 `reg-names = "eusb2_phy_base", "eud_enable_reg", "eud_detect_reg"`，
  地址 **`eud_enable_reg` = 0x88e2000（4 B）/ `eud_detect_reg` = 0xc278000**。

⇒ 硬件侧 EUD 在 SM8750 平板上是**完整实现**，vendor 固件默认开。`已证`

### 1.4 采集时序说明（设备状态在本次会话中变过）

- 22:37–22:40 CST：ssh `root@192.168.7.1` 正常，§1.1/§1.2 全部输出来自该窗口。
- 22:5x 复查：USB 网口重新枚举成 `192.168.42.97/24`，`192.168.7.1` 不可达、`192.168.42.129:22` **Connection refused**、
  adb 5555 也 refused ⇒ 设备已不在我们那套 Linux（疑似回落到 Android/其它状态）。
  **本 lane 未执行任何设备写操作**（仅 ssh 读），设备状态变化不是本 lane 造成的。`已证`

---

## §2 固件侧是否启用（静态 + 日志）

### 2.1 XBL 里有 EUD 初始化代码（`xbl_a.bin`，3 670 016 B，ELF）

```
$ strings -a -t x xbl_a.bin | grep -i eud
  c0e75 EUD Post PMIC Init
  c10ba EUD Init
  c4139 boot_eud.c
  c90b7 usb_eud_is_active, status
  c9179 usb_eud_serial
  c9600 vioclt_eud_set
  c960f qusb_dci_eud_init
  d1370 EUD wait %ds
  d137d EUD %d
```

- `boot_eud.c` 是源文件名 ⇒ 这是一整块 boot 固件模块，不是零散字符串。
- `EUD wait %ds` 的语义（`外部`+`未证`）：典型 bootloader 逻辑是「EUD 使能后等 N 秒让主机挂上」。**本机日志里没触发过**。
- `vioclt_eud_set` 暗示还有一层「VIOCTL（虚拟 IO 控制）设置」，与 vendor DT 的 `eud_detect_reg=0xc278000` 对应。`未证`

同样的 `strings` 在 `abl_a.bin`、`uefi_a.bin`、`xbl_config_a.bin` 里 **EUD 命中 0** ⇒
**ABL/Mu-UEFI 完全不碰 EUD**，所有 EUD 动作都在 SBL1/XBL 阶段或更晚的 Linux/Android。`已证`

### 2.2 启动日志：EUD 初始化每次启动都跑

`reports/artifacts/uefi-edl-read-20261101/logfs-now.bin`（8 MiB = 10 × 64 KiB 环形段）：

```
$ strings -a logfs-now.bin | grep -c "EUD Post PMIC Init"   → 10
$ strings -a logfs-now.bin | grep -c "EUD Init"             → 10
$ strings -a logfs-now.bin | grep -c "qusb_dci_eud_init"    → 10
$ strings -a logfs-now.bin | grep -c "usb_eud_serial"       → 10
$ strings -a logfs-now.bin | grep -c "EUD wait"             → 0
```

段 0 的实际上下文（`scripts/logfs-decode.py … --segment 0`）：

```
133- B - 184647 - SBL1, Start
135: B - 251686 - usb: usb_eud_serial  , 0x7fd29739
149: D -      0 - EUD Init
151: B - 305030 - Debug Policy: processed
152: B - 305030 - Debug Policy: debug policy applied
180: D -      0 - EUD Post PMIC Init
201: B - 611494 - usb: qusb_dci_eud_init
```

⇒ ① EUD 初始化位于 **SBL1**（XBL 的第一段）：PMIC init 之前跑 `EUD Init`、之后跑 `EUD Post PMIC Init`，各一次；
② 同段有 **`Debug Policy: debug policy applied`**（不是 "no debug policy applied"）⇒ 本机解锁机的 debug policy 是**放行型**；
③ `usb_eud_serial` 每次打印一个 32-bit 值（10 段里只有 `0xc096892b` / `0x7fd29739` 两个值）——
说明 EUD 块**可被读取**，但**不能据此断言已对主机放行**（serial 可能只是 TCSR 里的芯片序列/调试 ID）。`已证`+`未证`

### 2.3 devinfo：没有找到 EUD 相关位

`devinfo.bin` 4 096 B 的非零字节（今日逐字节枚举）：`ANDROID-BOOT!`（0x00–0x0c）+ **0x0d/0x0e/0x0f = 1/1/1**
（`is_unlocked` / `is_unlock_critical` / `is_charger_screen_enabled`，与既有口径一致）+ `0x90 = 1`
+ 0xca4–0xcca 一段 32 B 哈希 + 0xdac 起序列号 `HA2EXB0E…` + 0xe10 起 build 串
`…TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611` + 0xe7e/0xe9e 机型串
（`TB322FC` / `TB322FC_SM8750P_16+512`）。**没有发现第二个"EUD enable"位**。
⇒ EUD 放行更像走 **fuse + debug policy**，而不是 devinfo 位（`外部`：Linaro 博文明确说 fuses + OEM signed debug policy）。`已证`+`未证`

### 2.4 反向工程 vendor `eud.ko`（stock `vendor_dlkm/eud.ko`，35 496 B，`6.6.56-android15-8`）

这是**另一份下游驱动**（compatible `qcom,msm-eud`，注册 `ttyEUD` 串口 + extcon），与主线 `drivers/usb/misc/qcom_eud.c`
（`qcom,eud` + `usb_role_switch`）不是同一份代码。`已证`

反汇编 `param_eud_set`（使能路径）关键序列（偏移为函数内地址）：

```
a8–c4:  extcon_set_state_sync(..., 1,1)
d0–e8:  clk_prepare/clk_enable(eud_clkref_clk)
fc–120: 若 DT 有 utmi-delay：writew_relaxed(0x1034, hi); writew_relaxed(0x1030, lo)
124–148: writel_relaxed(0x1014, 1)          ← EUD_REG_CSR_EUD_EN
         writel_relaxed(0x24, 0x1c)         ← INT1_EN_MASK = VBUS|SAFE_MODE|…
150–178: 若 "secure-eud-en"：qcom_scm_io_readl(mode_mgr);
         若 bit0==0 → qcom_scm_io_writel(mode_mgr, 1)
184–1b0: usleep_range(50,100); extcon_set_state_sync(1,1); extcon(5,1)
```

`msm_eud_probe` 里还有一条：**只要 DT 有某属性（对应 `qcom,secure-eud-en` 一类；具体属性名未做 reloc 对照，`未证`），probe 阶段就直接
`qcom_scm_io_writel(eud_mode_mgr2, 1)`**（偏移 `694–6bc`）。

⇒ 两点结论：
① 使能 EUD 的**最后一步必须经 SCM 写 0x88e2000**（安全世界），不是裸 MMIO；本机 SCM 是否放行**未证**；
② SM8750 的 PHY 路由（`eud_enable_reg` 0x88e2000 / `eud_detect_reg` 0xc278000）由 **PHY 驱动**负责，
   主线 m31 驱动里 `grep eud` = **0 命中**（`build/base-7.2/drivers/phy/qualcomm/phy-qcom-m31-eusb2.c`）。`已证`

---

## §3 工具链现状

| 件 | 现状 | 证据 |
|---|---|---|
| EUD 用户态库 | `github.com/quic/eud`，GPL-2.0 OR BSD-3；CTRL/SWD/JTAG/TRACE/COM；构建 `autoreconf && ./configure && make` | `外部`：README（今日抓取） |
| OpenOCD EUD adapter | **已进上游**：openocd.org 用户手册「Debug Adapter Hardware」列 `eud` = "An SWD driver to communicate with the built-in EUD block"（对应 gerrit `+/9773`，Change-Id Ibe40b04…） | `外部`：openocd.org 文档 + syntacore PR #34 引用 |
| 快速上手分支 | `github.com/linux-msm/openocd` 默认分支 **`eud-rebased`**；`./configure --enable-eud --disable-linuxgpiod`；`-f tcl/interface/eud.cfg -f tcl/target/qualcomm/qcs6490.cfg`；README：**"Even though the config is named qcs6490, it doesn't seem to be soc specific."** | `外部`：README（今日抓取） |
| 官方支持面 | Qualcomm Linux Debug Guide（80-70029-12, Rev AA, 2026-03）：OpenOCD 0.12.0；**只支持 QCS6490 / IQ-9100 / IQ-9075**；使能命令 `echo 1 > /sys/bus/platform/devices/88e0000.eud/enable`（QCS6490，**与我们的 base 相同**）/ `88e1000.eud`（IQ-9100/9075） | `外部`：docs.qualcomm.com 今日抓取 |
| **早期 attach** | 官方原话：「**Kernel debug during bootup isn't supported until you manually enable EUD in the console shell or adb**」+「**每次系统重启都要重新 enable**」 | `外部`（同上） |
| 实战边界 | Linaro（2025-06）：845/855/865 只需 poke 使能寄存器 + 起 gadget；**新 SoC 需要额外改动（SM8450+）**；量产机可能被 fuse 关；**halt 到 EL2 后寄存器全 0**；建议 `maxcpus=1`；PRSR sticky reset 未解决 | `外部`：Linaro 博文 |
| 社区实证（新 SoC） | SM7635（2026-10）上 `eud.ko` 在 `88e0000.qcom,msm-eud` 能 bind，但与 dwc3 角色切换耦合（EUD 占走 role，UDC 不出现）；未见主机侧 SWD 成功报告 | `外部`：omnipha/linux-sm7635 issue #51 |
| SM8750 专项报告 | **未找到**任何「SM8750 + EUD + OpenOCD 成功」的公开记录 | `未证` |

**工具链结论**：软件侧 0 障碍（库、OpenOCD、config 都现成）；**障碍在「每 SoC 的使能与 PHY 路由」**，
而这正是官方只承诺 QCS6490 一档的原因。

---

## §4 最小验证清单与判据（不接调试器 / 物理动作归用户）

> 前置：备用通道先就位。**一旦 EUD 使能，USB host mode 与 adb/ssh 都会失效**（官方明写）——
> 我们的 ssh 正走这根线 ⇒ 先确认 WiFi（`wlan0`）或串口可用，否则会失去回退。

### L0（0 成本，先做）：看 XBL 到底有没有对主机放行 EUD

- **动作（用户）**：设备用 Type-C 线接一台 Linux PC；设备**冷启动**（PWR 长按断电再开）。
- **判据（PC 上）**：
  - `lsusb` / `lsusb -t` 在开机前 10 s 内出现 `05c6:9500` 或 `05c6:9501`（Qualcomm EUD），或一个 7 口 hub；
  - `dmesg -w` 同时段出现新 USB device / hub 枚举。
- **解释**：出现 ⇒ **XBL 自己 arm 了 EUD**（则「复位后早期 attach」有可能，值得投 L1/L2）；
  不出现（大概率）⇒ EUD 只能从 Linux/UEFI 侧开，**对 pre-Linux 载荷无效**，本条线降级为「调试我们自己的 UEFI/Linux」。
- **成本**：1 根线 + 1 次冷启动；**风险 0**（不写设备）。

### L1（低成本，主机侧）：把 DT 节点补上，在现有 Linux 里 probe + enable

1. 在运行 DT 的 `soc` 下加（照 upstream binding `Documentation/devicetree/bindings/soc/qcom/qcom,eud.yaml`）：

   ```dts
   eud: eud@88e0000 {
       compatible = "qcom,eud";           /* 或 "qcom,sm8750-eud","qcom,eud" */
       reg = <0x0 0x88e0000 0x0 0x2000>,
             <0x0 0x88e2000 0x0 0x1000>;
       interrupts-extended = <&intc GIC_SPI 11 IRQ_TYPE_LEVEL_HIGH>;  /* vendor: interrupts=<0x0b 4>；需 include arm-gic.h */
       ports { #address-cells=<1>; #size-cells=<0>;
           port@0 { reg=<0>; eud_ep: endpoint { remote-endpoint=<&usb_port0_role_ep>; }; };
       };
   };
   ```

   （vendor DT 里中断是 SPI 11、电平触发；主线 binding 要求 `ports`，需接到 dwc3 的 `usb-role-switch` endpoint。）
2. `insmod qcom_eud` → **判据 A**：`dmesg` 出现 probe 成功、`/sys/bus/platform/devices/88e0000.eud/enable` 存在。
   probe 失败会打印 `failed to get role switch`（`qcom_eud.c:206`）或 ioremap 失败信息。
3. `echo 1 > /sys/bus/platform/devices/88e0000.eud/enable` → **判据 B**：返回 0 且 `enable` 读回 1；
   若返回 `-EIO/-EPERM` ⇒ **SCM 拒绝**（EUD 被安全世界锁死），本条线到此为止（除非拿到调试策略）。
4. PC 上 `lsusb` → **判据 C**：出现 `05c6:9500` + `05c6:9501`（EUD 控制口 + SWD 口）。
   只出现 hub/控制口没有 SWD 口，或什么都没有 ⇒ **PHY 路由缺口**（见 L2）。
5. `openocd -f tcl/interface/eud.cfg -f tcl/target/qualcomm/qcs6490.cfg` → **判据 D**：
   `Info : Using EUD 2.1.7`、`SWD DPIDR 0x5ba02477`、`hardware has 6 breakpoints, 4 watchpoints`、
   `halted in AArch64 state`。

- **成本**：DT 改动 + 一次内核/DT 构建（~30 min）+ 1 次重启；不需要 flashing 任何分区（可用现有 `fastboot boot` 变体）。

### L2（中成本，仅当 L1 判据 C 失败）：补 SM8750 的 PHY EUD 路由

- 现状：`phy-qcom-m31-eusb2.c` 无 `eud_enable_reg`/`eud_detect_reg` 处理；vendor 版（`phy-msm-m31-eusb2.c`）
  有：probe 时映射 `eud_enable_reg`（0x88e2000，4 B）、`eud_detect_reg`（0xc278000），并在 `phy_init` 里
  `is_eud_debug_mode_active()` → 跳过 PHY reset、保持 LDO/clock（vendor commit：*"if the EUD is enabled in the bootloader,
  keep LDOs/clocks on … until the USB PHY driver initializes"*）。
- **判据**：补上后 L1 判据 C 变成"出现 05c6:9500/9501"。
- **成本**：主机侧半天（照 vendor 驱动裁剪成主线风格），1 次上机；**风险**：写错 PHY 寄存器可能 hang USB（可复位恢复）。

### L3（高成本/低优先级）：真正的「AP 早期执行控制」

- 需要 EUD 在 **XBL 阶段**就对主机放行并**停在 reset 向量**。L0 若为"不出现"，则只有两条：
  ① 改 XBL（重新签名/替换 `xbl_a`）——**不建议**，风险与合规都不划算，且未见 SM8750 可用配置项；
  ② 让自己的 UEFI 载荷在最早处使能 EUD（需要 USB device 栈 + SCM，工作量远大于 DDR 黑匣子）。
- **判据**：冷启动后 PC 上 OpenOCD 在 `BL1/XBL` 阶段就能 `halt`（`pc` 落在 XBL 地址窗），而不是等 Linux 起来。
- **结论**：**不建议作为当前主线**；DDR checkpoint 黑匣子（`uefi-observability-pivot-20261101.md` P0）仍是
  「载荷死在哪」的最低成本正解。

---

## §5 成本与风险

| 项 | 评估 |
|---|---|
| 主机侧工作量（L1） | ~0.5 人日（DT 节点 + 构建 + 验证脚本） |
| 主机侧工作量（L1+L2） | ~1 人日（补 PHY EUD 路由） |
| 设备操作 | L0：冷启动 1 次；L1：重启 1 次 + `insmod`/`echo`；**无需 flash** |
| 物理风险 | **零**（不接调试器、不开盖、不短接；L0 只是插线） |
| 系统风险 | 使能 EUD 会**关掉 USB host mode / adb / 我们的 ssh**；需 WiFi 或串口备用 |
| 不可回退点 | 无（`echo 0` 关闭；重启即恢复默认） |
| 主要不确定性 | ① SCM 是否放行（未证）② PHY 路由是否正确（未证）③ fuse/debug policy（`Debug Policy: applied` 是正向信号，但不等于 EUD 放行） |

---

## §6 未证 / 下一步

1. **未证**：XBL 是否在本机 arm EUD（只有 `EUD Init`/`qusb_dci_eud_init`，无 `EUD wait`）→ **L0 一根线即可定**。
2. **未证**：`devinfo` 是否有 EUD 位（4 KiB 里非零只有 0x0d/0x0e/0x0f=1、0x90=1、一段哈希 + 序列号/build 串，未见 EUD 开关）。
3. **未证**：本机 SCM 是否允许 `qcom_scm_io_writel(0x88e2000, 1)`（L1 判据 B）。
4. **未证**：主线 `qcom_eud` + `phy-qcom-m31-eusb2` 能否在 SM8750 上完成 PHY 路由（L1 判据 C / L2）。
5. **未证**：`tcl/target/qualcomm/qcs6490.cfg` 的 AP DAP/CTI 基址是否适用于 SM8750（README 称"不绑定 SoC"，但只在 845/855/865/6490 上验证过）。
6. **未证**：EUD 是否能 attach 到「自旋/异常后」的目标。OpenOCD 的 halt 依赖 CPU 仍在跑 debug 请求；
   若载荷已经 `b .` 或被 wdog 拉复位，**窗口可能不存在**——这条只能上机验证，不能靠读文档。
7. **下一步建议**（按性价比）：
   - 先做 §4 L0（0 成本）→ 若"不出现"，把 EUD 明确降级为「Linux/UEFI 期调试器」，不再当早期观测手段；
   - 早期观测仍走 DDR 黑匣子（P0）；
   - 若 L0 出现 EUD 枚举，再投 L1（DT + probe + enable），这是**唯一**有机会拿到 reset 后早期控制的路径。

---

## 附：产物与复现

- 产物目录：`reports/artifacts/uefi-eud-20261101/`
  - `live-fdt.dtb` / `live-fdt.dts` —— 2026-11-01 22:38 从设备 `/sys/firmware/fdt` 只读抓取（154 766 B）。
- 复现（只读）：

```bash
cd ~/y700-elden
ssh root@192.168.7.1 'dmesg | grep -i eud; lsmod | grep eud; ls -d /sys/bus/platform/devices/*eud*'
ssh root@192.168.7.1 'cat /sys/firmware/fdt' > /tmp/live.dtb
dtc -I dtb -O dts /tmp/live.dtb | grep -ci eud            # → 0
strings -a reports/artifacts/uefi-edl-read-20261101/xbl_a.bin | grep -i eud
strings -a reports/artifacts/uefi-edl-read-20261101/logfs-now.bin | grep -c "EUD wait"   # → 0
dtc -I dtb -O dts backup/stock-elden/dtb/10_dtbdump_*SunP_SoC.dtb | sed -n '6476,6487p'
```
