# D19 候选②：SM8750 APSS watchdog —— DT(+binding) 备料（2026-11-25，**不投递**）

> 线：D19 遗留「本机无硬件看门狗，测试核 hang 只能物理 POR」。上一候选 `gunyah_wdt` 已上机证否
> （`reports/d19-gunyah-wdt-20261125.md` 父代理附节：hyp 侧空实现、停喂 45 s 不复位）。
> 本 lane **纯主机侧、零设备动作**（未 ssh / 未 adb / 未 fastboot），产出 = **两枚可 `git am` 的补丁 + 门禁原始输出 + 上机判据**。
> 树：上游基线 `build/elden-tree` @ `aebb72744764`（7.4-rc3）；日常线 `build/daily` @ `4da9a8b69fc85`（7.3.1+payload v2）。
> 输出：`patches/local/apss-wdt-20261125/`（补丁 + `README.md` + `evidence/`）；本文件是唯一报告。
> **没有**改 `TASKS/DEVICE/INDEX/PITFALLS`、没有改任何既有 report、没有发信。

---

## 0. 结论（先数字）

| 项 | 值 |
|---|---|
| 补丁 | **2 枚**：`0001` binding 加 `qcom,apss-wdt-sm8750` 枚举（7 行）；`0002` `sm8750.dtsi` 加节点（+8 行，1 文件） |
| 节点 | `watchdog@16410000`，`"qcom,apss-wdt-sm8750", "qcom,kpss-wdt"`，`reg = <0x0 0x16410000 0x0 0x1000>`，`clocks = <&sleep_clk>`，`interrupts = <GIC_SPI 0 IRQ_TYPE_EDGE_RISING>`，`status = "okay"` |
| 基址来源 | **vendor DTB 无该节点**（只有 `/hypervisor/qcom,gh-watchdog`）⇒ 转向 **vendor 固件（XBL/CPuCP/Hyp）内的 APSS 保护区表** + 同族上游节点形状，采信 **`0x16410000`**（理由/冲突表见 §2，**不是**同族字面照抄 `0x17600000`） |
| `git am`（7.4-rc3 干净树） | **2/2 干净**（`evidence/gate-git-am-2of2.log`） |
| `checkpatch --strict --no-tree` | 两枚 **0E/0W/0C**（`evidence/checkpatch-*.log`） |
| `dtbs_check`（7.4-rc3，`sm8750-mtp.dtb`） | 基线 **0 诊断** → 打补丁 **0 诊断**，`DTC [C]`（`evidence/gate-{base,patched}-dtbscheck-sm8750-mtp.log`）；**只打 DT 不打 binding** 的负样例 = **2 条诊断**（`evidence/gate-dtsonly-no-binding-dtbscheck.log`） |
| `dtbs_check`（日常树，elden/mtp/qrd） | 基线 elden **0 诊断** → 打补丁 **3/3 `DTC [C]`，各 0 诊断**（`evidence/gate-daily-*.log`） |
| `dt_binding_check` | 定向（`DT_SCHEMA_FILES=qcom-wdt.yaml`）rc=0；**全量 rc=0，5420 个 example `DTC [C]`，0 error/warning 行**（`evidence/gate-patched-bindingcheck-*.log`） |
| 日常树 `scripts/build-kernel.sh dtbs` | **rc=0**，3 个 DTC，符号守卫 OK；`.config` 前后 sha256 一致；`git status` 干净（`evidence/gate-daily-build-kernel-dtbs.log`、`evidence/gate-tree-state-after.log`） |
| 上机 | **没跑**（本 lane 硬约束）。判据/安全顺序见 §5；**先读后试**是硬要求（见 §5.1） |

---

## 1. 三源取证（逐条标来源）

### 1.1 源① 仓内 vendor DTB / vendor 固件 —— 「APSS WDT 在 vendor DT 里根本没有节点」

| 事实 | 证据（可复现命令） |
|---|---|
| vendor overlay DTS 无任何 `watchdog@` / `,wdt` 节点，只有 `gh_watchdog` 引用（`pmic-pon-log:depends-on-supply`、`__symbols__.gh_watchdog`） | `grep -n -i 'watchdog@\|,wdt' reference/stock-elden.dts` → **0**；`grep -n 'gh_watchdog' reference/stock-elden.dts` → 2388、4284 |
| vendor 分包 DTB 13 个全部无 `watchdog@`；唯一的 watchdog 是 `/hypervisor/qcom,gh-watchdog`（无 `reg`） | `for f in backup/stock-elden/dtb/[0-9][0-9]_*.dtb; do dtc -I dtb -O dts $f \| grep -qi 'watchdog@' && echo HIT; done` → 无 HIT；`dtc -I dtb -O dts backup/stock-elden/dtb/06_*Sun_SoC.dtb \| grep -n -i 'watchdog'` → 24344 `qcom,gh-watchdog`、26098 符号行 |
| vendor DT **整个 0x16xx_xxxx/0x17xx_xxxx APSS 段**只有：`timer@16800000`(6418)、`mmio-sram@0x17b4e000`(12514)、`qcom,cpucp@0x17830000`(12535，`reg=<0x16430000 0x4c08 0x17830000 0x300>`)、`qcom,pdp0@0x18980000`(12544，`reg=<0x16420000 0x4c08 0x18980000 0x300>`)、`qcom,pdp1@…`(12554)；**没有任何 `0x16410000` 节点** | 见上，`/tmp/sun.dts`（= `dtc -I dtb -O dts backup/stock-elden/dtb/06_*Sun_SoC.dtb`，sha256 `95512cf8…`） |
| ⇒ 源①**给不出基址**（Android 用 hyp 的 `qcom,gh-watchdog`，vendor DT 不描述 APSS WDT） | 同上 |

**补证①b（vendor 固件内的 APSS 保护区表，本 lane 新增取证）**：`xbl_s.melf`（sha256 `8b09b3ae…`）在
文件偏移 `0xdb160–0xdb214` 有一张 **12 字节/条**的 APSS 保护（XPU/MPU）区域表，按地址排列；
`0x16410000` 是 **PDP/CPuCP 邻域里唯一没有被 vendor DT 其它节点占用的 4 KiB 级条目**
（`0x16330000` 同样未被 vendor DT 占用，但不在 `0x1642_0000` PDP / `0x1643_0000` CPuCP 这条 APSS glue 邻域上）：

```
0db1c4: 16330000  0000ff03  00000000
0db1d0: 16400000  0000ff80  00000000
0db1dc: 16410000  0000ffe0  00000000     <-- 候选 WDT 窗口（4 KiB 级、权限 mask 0xffe0）
0db1e8: 16420000  0000ff00  00000000     <-- vendor qcom,pdp（本地 rx 块）
0db1f4: 16430000  0000ff40  00000000     <-- vendor qcom,cpucp（rx 块）
0db200: 16500000  0000ff00  00000000     <-- apps_rsc
0db20c: 16510000  0000ff00  00000000
```

同文件还有 `WatchdogMgr.cpp`、`APPS_WDOG_BITE`（重置原因表）、`xbl_sc_wdog` 字符串；
`devcfg.mbn`（sha `072a4bfb…`）有 `OEM_wdog_flags`、`OEM_sec_wdog_bark_time`、`OEM_sec_wdog_bite_time`、
`OEM_wdog_ms_accept_hlos`、`OEM_wdog_ms_accept_uefitzt` ⇒ **XBL/TZ 管着一枚带 bark/bite 时间的 secure watchdog**。
`hypvm.mbn`（sha `c3dbff5e…`）有 `hyp/platform/soc_qcom_watchdog/src/watchdog.c`、
`/hypervisor/qcom,gh-watchdog`、`Failed creation of watchdog memextent` ⇒ **hyp 侧为 watchdog 建了 memextent**（与 hamoa 的 `status="reserved" /* Reserved by Gunyah */` 同型，见 1.2）。

> 口径：①b 是**旁证**（地址存在 + 是 APSS 受保护块），不是「WDT 在 0x16410000」的直接证明；
> 它的作用是排除「照抄同族 0x17600000」并把候选收敛到 SM8750 自己的 `0x1641_0000`。

### 1.2 源② 上游同族 SoC 的节点形状 —— 「形状可抄，基址不能抄」

| SoC（文件:行） | compatible | reg | clocks | interrupts | status |
|---|---|---|---|---|---|
| kaanapali（SM8850，`kaanapali.dtsi:6033`） | `qcom,apss-wdt-kaanapali`, `qcom,kpss-wdt` | `0x17600000`, 0x1000 | `<&sleep_clk>` | `<GIC_SPI 0 IRQ_TYPE_EDGE_RISING>` | 无（默认 okay） |
| glymur（`glymur.dtsi:8183`） | `qcom,apss-wdt-glymur`, `qcom,kpss-wdt` | `0x17600000`, 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| hawi（`hawi.dtsi:5115`） | `qcom,apss-wdt-hawi`, `qcom,kpss-wdt` | `0x17600000`, 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| hamoa / x1e80100（`hamoa.dtsi:8584`） | `qcom,apss-wdt-x1e80100`, `qcom,kpss-wdt` | `0x17410000`, 0x1000 | `<&sleep_clk>` | 同上 | **`status = "reserved"; /* Reserved by Gunyah */`** |

形状结论（补丁采用）：compatible = SoC 专用 + `qcom,kpss-wdt` 回退；`reg` 1 KiB；`clocks = <&sleep_clk>`（不写 `clock-names`）；
`interrupts = <GIC_SPI 0 IRQ_TYPE_EDGE_RISING>`；**无 `#reset-cells`**（同族四例都没有，故本补丁也不加）。
基址结论：**同族内部就不一致**（`0x17600000` vs `0x17410000`），且 SM8750 的 APSS 块整体挪到了 `0x1640_0000` 段
（vendor DT：`pdp`=0x16420000、`cpucp`=0x16430000、`apps_rsc`=0x16500000、`timer`=0x16800000）⇒ 不能字面照抄。

### 1.3 源③ 主线驱动 `drivers/watchdog/qcom-wdt.c`（7.4-rc3）

| 事实 | 位置 |
|---|---|
| `of_match_table` 只认 `qcom,apss-wdt-{ipq5332,ipq5424,ipq9574}`、`qcom,kpss-timer`、`qcom,scss-timer`、**`qcom,kpss-wdt`** | `drivers/watchdog/qcom-wdt.c:385-392` |
| `qcom,kpss-wdt` → `match_data_kpss`：KPSS 偏移表 `WDT_RST=0x4`、`WDT_EN=0x8`、`WDT_STS=0xC`、`WDT_BARK_TIME=0x10`、`WDT_BITE_TIME=0x14`；`pretimeout=true`；`max_tick_count=0xFFFFF` | `:34-39`、`:205-209` |
| probe 只做 `devm_clk_get_enabled(dev, NULL)`（按第一枚 clock，无 `clock-names` 要求）；`rate==0` 或 `rate>max_tick_count` 直接 `-EINVAL` | `:285`、`:299-305` |
| 无 `sram` phandle 时，bootstatus 走 **`readl(WDT_STS) & 1`（EXPIRED_STATUS）→ `WDIOF_CARDRESET`** | `:211-228` |
| BITE = 写 `WDT_EN` 的 `BIT(0)`（`qcom_wdt_restart`，驱动注释「Trigger watchdog bite」） | `:120-146` |
| `pretimeout` 仅在 `match_data->pretimeout` 且 `platform_get_irq_optional()` 得到有效 IRQ 时启用（BARK ISR） | `:307-325` |
| binding：`compatible` 枚举（`qcom-wdt.yaml:20-53`，本次插在 `-sm8250`→`-x1e80100` 之间）；`required: compatible, reg, clocks`；`interrupts` 可选但若给则 `minItems: 1`（kpss 分支：Bark/Bite） | `Documentation/devicetree/bindings/watchdog/qcom-wdt.yaml` |

结论：**不需要新驱动**；`qcom,kpss-wdt` 回退即可拿到全部寄存器语义（EN/STS/BARK/BITE）。
按 `sleep_clk = 32000 Hz`（`build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1246` fixed-clock；上游 `sm8750-mtp.dts:79` 同值）计算
`max_timeout = 0xFFFFF/32000 = 32 s`（驱动 `:299` 取 `clk_get_rate`、`:326` 算 `max_timeout`），**正好落在 D19 可用区间**（与 `gunyah_wdt` 的 32 s 上限同量级，但那颗是空实现）。

### 1.4 设备侧历史负证据（不是本轮跑的，引用既有报告）

- `reports/uefi-p54-p57-wdog-negative-20261107.md` §0.5/§1：UEFI 阶段 p56 读 `0x17410000` 在 `far=17410014` 同步外部中止、
  p57 **第一个字** `far=17410000` 即中止 ⇒ **`0x17410000` 在本机总线上无实现**（hamoa 的地址不能用）。
- 同一报告只在 `0x17410000` 上中止；**`0x17C10000` 实际未被读到**（p56/p57 都在第一处就中止）——
  既有文档把它写成「两地址均不可访问」是**过度外推**，本报告按原始数据更正为「`0x17C10000` 未验」。
- `PITFALLS #553/#210`：**别照抄同族平台基址**；盲探 MMIO 代价是人工长按断电。

---

## 2. 冲突表与采信理由

| # | 候选基址 | 谁说的 | 本机状态 | 采信？ |
|---|---|---|---|---|
| A | **`0x16410000`** | **vendor 固件**：XBL 保护区表 12 字节条目（`0x16410000` 独立 4 KiB 窗口、权限 mask `0xffe0`，紧邻 vendor `pdp`=0x16420000 / `cpucp`=0x16430000）；且同族「WDT 在 PDP 本地块 −0x10000」（kaanapali/glymur/hawi：WDT 0x17600000 vs pdp0_mbox 0x17610000）映射到 SM8750 的 `0x16420000−0x10000` | 未验 | **✅ 采用**（两条独立推导收敛；仍属「待上机读回确认」，见 §5） |
| B | `0x17600000` | 上游 glymur/kaanapali/hawi 节点字面 | 未验；但 SM8750 的 APSS 块在 `0x1642_0000–0x1680_0000`（vendor DT 实测），`0x17xx_xxxx` 段只有 sram（0x17b4e000）等零散件；同族 `timer` 在 0x17810000 而 SM8750 在 0x16800000 ⇒ **内存图整体不同** | ❌ 不采（照抄即踩 `#553/#210`） |
| C | `0x17410000` | 上游 hamoa/x1e80100 | **已证否**：UEFI p56/p57 外部中止 | ❌ 不采 |
| D | `0x17C10000` | sm8250…sc8280xp 老世代 | **未验**（p56/p57 未读到；属既有文档外推） | ❌ 不采（无依据） |
| E | `0x17826000` | nord（不同 die） | 未验；无对应关系 | ❌ 不采 |

采信 A 的理由（不猜的部分 / 猜的部分分开写）：

1. **不猜**：SM8750 自己的 APSS 寄存器块起止可由 vendor DT 逐条读出（`0x16420000` pdp、`0x16430000` cpucp、`0x16500000`
   apps_rsc、`0x16800000` timer）；`0x16410000` 独立出现在 XBL 的 APSS 保护区表里，是**本机固件承认存在**的窗口。
2. **不猜**：同族节点形状（compatible/回退、1 KiB、sleep_clk、SPI 0 edge、无 reset-cells）在 4 个 SoC 上一致。
3. **待验（明确标为假设）**：`0x16410000` **就是 APSS WDT**，且其 bark 中断是 `GIC_SPI 0`、时钟是板级 32 kHz `sleep_clk`。
   这三条只能上机读回/试喂来定，判据见 §5；**若第一条不成立，补丁作废（不要投），不是改地址继续猜**。

---

## 3. 补丁（`patches/local/apss-wdt-20261125/`）

| 文件 | 内容 | 行数 |
|---|---|---|
| `0001-dt-bindings-watchdog-qcom-add-sm8750-apss-wdt.patch` | `qcom-wdt.yaml` 的 SoC 枚举里加 `- qcom,apss-wdt-sm8750`（`-sm8250` 与 `-x1e80100` 之间，字典序） | +1 行（7 lines checked） |
| `0002-arm64-dts-qcom-sm8750-add-apss-watchdog.patch` | `sm8750.dtsi`：`soc@0` 下、`cpucp_mbox` 之前（地址序，同族也是 watchdog 紧邻 pdp/cpucp mailbox）插节点 | +8 行 |

节点正文（`status = "okay"` 是父代理明确要求，保留；上游同族默认省略 status，见 §6 的投递提醒）：

```dts
		watchdog@16410000 {
			compatible = "qcom,apss-wdt-sm8750", "qcom,kpss-wdt";
			reg = <0x0 0x16410000 0x0 0x1000>;
			clocks = <&sleep_clk>;
			interrupts = <GIC_SPI 0 IRQ_TYPE_EDGE_RISING>;
			status = "okay";
		};
```

**是否需要新 binding**：**需要**（但只是枚举 +1 行，不用新驱动）。原因：上游对每个 SoC 都要求 SoC 专用 compatible 进
`qcom-wdt.yaml` 枚举（glymur/kaanapali/hawi 都这么干，驱动靠 `qcom,kpss-wdt` 回退拿数据）；
若只写 `qcom,kpss-wdt` 单串，`dtbs_check` 虽过（该串在 binding 里标了 `deprecated`），但会被维护者要求改回专用串。

---

## 4. 门禁（本轮自己跑，原始输出）

### 4.1 树状态（开工前）

```
$ git -C build/elden-tree status --short
（空）
$ git -C build/elden-tree rev-parse HEAD
aebb7274476403040d582c61478df8f4a7bf9cd3
$ ls build/elden-tree/.config
ls: cannot access 'build/elden-tree/.config': No such file or directory
$ sha256sum build/daily/.config
34c7d658d4eee4aa073ecf2f2ed9ca5d58c5ad22caca794334c007e468aa34fe  build/daily/.config
```

### 4.2 `git apply --check` / `git am`

`evidence/gate-elden-tree-applycheck.log`：

```
# tree = build/elden-tree HEAD aebb7274476403040d582c61478df8f4a7bf9cd3
# git apply --check:
OK 0001-dt-bindings-watchdog-qcom-add-sm8750-apss-wdt.patch
OK 0002-arm64-dts-qcom-sm8750-add-apss-watchdog.patch
```

`evidence/gate-git-am-2of2.log`（临时 worktree `/tmp/apss-wdt-am2`，基点 `aebb72744764`）：

```
# base = aebb7274476403040d582c61478df8f4a7bf9cd3 (7.4-rc3)
应用：dt-bindings: watchdog: qcom: add SM8750 APSS watchdog
应用：arm64: dts: qcom: sm8750: add APSS watchdog
d941cdd25a8b arm64: dts: qcom: sm8750: add APSS watchdog
859518c754f3 dt-bindings: watchdog: qcom: add SM8750 APSS watchdog
aebb72744764 Linux 7.4-rc3
```

### 4.3 `checkpatch --strict --no-tree`

```
$ perl build/elden-tree/scripts/checkpatch.pl --strict --no-tree --no-signoff - < 0001-…patch
total: 0 errors, 0 warnings, 0 checks, 7 lines checked
"…has no obvious style problems and is ready for submission."

$ perl build/elden-tree/scripts/checkpatch.pl --strict --no-tree --no-signoff - < 0002-…patch
total: 0 errors, 0 warnings, 0 checks, 14 lines checked
"…has no obvious style problems and is ready for submission."
```

### 4.4 `dtbs` + `dtbs_check`（上游门树 = 7.4-rc3 临时 worktree，`O=/tmp`）

7.4-rc3 没有 board DTS（`sm8750-lenovo-elden.dts` 只在日常树），故上游侧用 **`qcom/sm8750-mtp.dtb`**（同一 `sm8750.dtsi`）：

```
# 基线（pristine worktree）
make O=/tmp/kb-apss-base defconfig                      # rc=0
make O=/tmp/kb-apss-base -j8 qcom/sm8750-mtp.dtb        # rc=0
make O=/tmp/kb-apss-base CHECK_DTBS=1 -j8 qcom/sm8750-mtp.dtb
  SCHEMA  Documentation/devicetree/bindings/processed-schema.json
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
↳ 诊断行（^arch/…/sm8750-mtp.dtb:）= 0

# 打补丁（2/2 的 worktree）
make O=/tmp/kb-apss-patched defconfig                   # rc=0
make O=/tmp/kb-apss-patched -j8 qcom/sm8750-mtp.dtb     # rc=0
make O=/tmp/kb-apss-patched CHECK_DTBS=1 -j8 qcom/sm8750-mtp.dtb
  SCHEMA  Documentation/devicetree/bindings/processed-schema.json
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
↳ 诊断行 = 0

# 负样例：只打 0002（DT）、不打 0001（binding）
make O=/tmp/kb-apss-dtsonly CHECK_DTBS=1 -j8 qcom/sm8750-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb           # rc=0，但 cmd_dtb_check 末尾有 || true，rc 不可信
arch/arm64/boot/dts/qcom/sm8750-mtp.dtb: watchdog@16410000 (qcom,apss-wdt-sm8750): compatible: 'oneOf' conditional failed, one must be fixed:
	['qcom,apss-wdt-sm8750', 'qcom,kpss-wdt'] is too long
	…
	'qcom,apss-wdt-sm8750' is not one of ['qcom,apss-wdt-glymur', …]
arch/arm64/boot/dts/qcom/sm8750-mtp.dtb: /soc@0/watchdog@16410000: failed to match any schema with compatible: ['qcom,apss-wdt-sm8750', 'qcom,kpss-wdt']
↳ 诊断行 = 2 ⇒ binding 必须与 DT 同系列（§6.2-1）
```

### 4.5 日常树（`build/daily`，临时打补丁后复原）

```
# 基线 elden 单件 dtbs_check
$ rm -f …/sm8750-lenovo-elden.dtb
$ make -C build/daily ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j8 qcom/sm8750-lenovo-elden.dtb
  SCHEMA  Documentation/devicetree/bindings/processed-schema.json
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
↳ 诊断行 = 0

# 打补丁（git apply 两枚，均 OK）+ 全量 dtbs 目标
$ build-slot take y700-elden:apss-wdt --jobs 8
$ scripts/build-kernel.sh dtbs
  DTC     arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  DTC     arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC     arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
  [build] symbol guard OK: gcc_sm8750 / DSI bonded / rpmh present
  rc=0；elden dtb = 153 253 B，md5 43782a23e65e72d1fe9d84710066e7eb
$ make -C build/daily … CHECK_DTBS=1 -j8 qcom/{sm8750-lenovo-elden,sm8750-mtp,sm8750-qrd}.dtb
  DTC [C] ×3
↳ 诊断行（三个 dtb）= 0 / 0 / 0
$ dtc -I dtb -O dts …/sm8750-lenovo-elden.dtb | grep -A6 watchdog@16410000
  watchdog@16410000 { compatible = "qcom,apss-wdt-sm8750", "qcom,kpss-wdt";
                      reg = <0x00 0x16410000 0x00 0x1000>; clocks = <0x26>;
                      interrupts = <0x00 0x00 0x01>; status = "okay"; };

# 复原（git checkout 两文件 + 重编 dtb）
$ git -C build/daily status --short          → （空）
$ sha256sum build/daily/.config               → 34c7d658…（与开工前同值）
$ 重编 dtb → md5 2caac5ce9a2824be58065cc6cc81e6c4；dtc | grep -c 'watchdog@' = 0
$ git -C build/daily rev-parse HEAD           → 4da9a8b69fc85fb1dd100c63f5a1b02eb730571a
```

收工树状态（`evidence/gate-tree-state-after.log`）：

```
## build/elden-tree
HEAD aebb7274476403040d582c61478df8f4a7bf9cd3
status: ''
config: ls: cannot access 'build/elden-tree/.config': No such file or directory
## build/daily
HEAD 4da9a8b69fc85fb1dd100c63f5a1b02eb730571a
status: ''
config-sha 34c7d658d4eee4aa073ecf2f2ed9ca5d58c5ad22caca794334c007e468aa34fe  build/daily/.config
```

### 4.6 `dt_binding_check`（binding 有改动，两跑）

```
# 定向（本补丁门）
$ make O=/tmp/kb-apss-patched DT_SCHEMA_FILES=Documentation/devicetree/bindings/watchdog/qcom-wdt.yaml -j8 dt_binding_check
  CHKDT / LINT / STYLE / DTEX
  DTC [C] Documentation/devicetree/bindings/watchdog/qcom-wdt.example.dtb
  rc=0；error/warning 行 = 0

# 全量
$ make O=/tmp/kb-apss-patched -j8 dt_binding_check
  rc=0；DTC [C] 计数 = 5420；error/warning 行 = 0
```

> 全量日志 880 KB，原件留在 `/tmp/kb-patched-bindingcheck-full.log`；`evidence/` 存首尾摘要（`gate-patched-bindingcheck-full-summary.log`）。

### 4.7 编译槽位

`build-slot take y700-elden:apss-wdt --jobs 8` → `DROP 205222-2445665-y700-elden_apss-wdt`（收工已 drop）。

---

## 5. 上机判据（**只写不执行**；先读后试）

### 5.1 ⚠ 安全顺序（必须遵守）

`qcom_wdt_probe()` 在 probe 里就会 `readl(WDT_STS)`（`qcom-wdt.c:223`）——**基址若属 hyp/TZ 保护区，这一读就是同步外部中止**。
而 `status = "okay"` 的 `qcom,kpss-wdt` 节点还会让 `qcom_scm` 跳过 `gunyah-wdt` 注册（`build/daily/drivers/firmware/qcom/qcom_scm.c:2506-2530`：
`of_wdt_compatible[]` 里任何一串在 DT 中 **available** 就 bail）⇒ 一旦 probe 崩，连兜底都没有。
所以：

1. **第 0 步（只读）**：同一补丁把 `status` 改成 `"disabled"`（或直接造一份 disabled 的 DTB），零写盘起机；
   用 `devmem`（busybox，单次 32 bit 读）读 `0x16410000`（**一次一个字**，`PITFALLS #553`）。
   - **读不出（外部中止/SIGBUS）⇒ 基址错或受 hyp 保护 ⇒ 停**，不要继续喂狗测试；改走 §6.3 的「不可用」结论。
   - **读出合理值**（如 `WDT_EN` bit0=0、`WDT_STS`=0）⇒ 进第 1 步。
2. **第 1 步（probe）**：换 `status = "okay"` 的核，零写盘 `fastboot boot`（D19 流程：`scripts/autotest-cycle.sh`/`to-bootloader.sh`），确认能看到 SSH 再判断。
3. **第 2 步（bite）**：只在「设备已在 BL、可零写盘回滚」的窗口做（喂狗测试会**复位整机**）。
4. **失败回滚**：换回不带节点的 DTB/`boot_b`，**不需要写盘**；本 lane 没有改动设备任何分区。

### 5.2 判据清单

| # | 检查 | 期望 |
|---|---|---|
| 1 | `dmesg \| grep -iE 'qcom-wdt|watchdog'` | 出现 `qcom-wdt` 绑定/注册日志；无 `invalid clock rate`、无 `failed to get input clock`（后者= `sleep_clk` 没拿到，`-EINVAL`/`-ENODEV`） |
| 2 | `ls -l /dev/watchdog*`；`ls /sys/class/watchdog/` | `/dev/watchdog0` 存在；`/sys/class/watchdog/watchdog0/` 存在 |
| 3 | **sysfs 注意**：日常线 `.config` 是 `# CONFIG_WATCHDOG_SYSFS is not set`（`build/daily/.config:5035`；`watchdog_dev.c:445` 的 `#ifdef CONFIG_WATCHDOG_SYSFS` 才挂属性） | watchdog0 下的 `state/timeout/timeleft` 等**属性不会出现** ⇒ 用 `wdctl`（ioctl）或自写 4 条 ioctl（`WDIOC_GETSUPPORT/GETTIMEOUT/GETTIMELEFT/SETTIMEOUT` + `KEEPALIVE`） |
| 4 | `wdctl /dev/watchdog0` | `Identity: qcom-wdt`（`KBUILD_MODNAME`）、`Timeout: 30`（默认 = min(32,30)）、`Pre-timeout: 0` 或 bark 秒数（有 IRQ 才启用 pretimeout） |
| 5 | `SETTIMEOUT` 10 s → 停喂 → 实测墙钟 | **≈10 s 复位** ⇒ 时钟/寄存器偏移正确；若 10 s 实际是 ~320 s 或 ~1 s ⇒ `sleep_clk` 频率假设错（32 kHz）|
| 6 | 复位后**先回 BL 看 ABL 日志**（`scripts/abl-log.sh`）+ 再起 Linux 读 bootstatus | ABL/XBL 记录 `APPS_WDOG_BITE`（`xbl_s.melf` 字符串表里有该 reason）；Linux 侧 `WDIOC_GETBOOTSTATUS` 置 `WDIOF_CARDRESET`（驱动读 `WDT_STS` bit0） |
| 7 | `ls /sys/bus/platform/devices \| grep gunyah-wdt` | **应为空**（`qcom_scm` bail-out；`GUNYAH_WATCHDOG` 在 `.config` 本来也是 not set）。这条是「两个候选不能共存」的实证 |
| 8 | `cat /proc/device-tree/soc@0/watchdog@16410000/status` | `okay`；`…/compatible` 两个串按序 |
| 9 | 挂起/恢复（`qcom_wdt` 有 `SET_LATE_SYSTEM_SLEEP_PM_OPS`：active 时 stop/resume 时 start） | `systemctl suspend` 后能醒；醒后 `wdctl` 仍 active（若挂起不自动停狗会咬，属回退条件） |
| 10 | XBL/TZ 是否禁用硬件狗 | vendor DTB **没有** `qcom,watchdog-*` 属性（本轮已查，§1.1）；`devcfg.mbn` 有 `OEM_wdog_flags`/`OEM_sec_wdog_bark_time`/`bite_time`/`OEM_wdog_ms_accept_hlos` ⇒ **XBL/TZ 侧确有一枚 secure WDT**。若 APSS WDT 因 TZ 归属不可访问，判据 1 会以 probe 失败/外部中止收场，按 §5.1 回滚 |

> 附加判据（可选）：`/sys/kernel/debug/watchdog` 不存在（无 debugfs 支持）；`CONFIG_WATCHDOG_NOWAYOUT` 是 `not set`（`.config:5032`），
> 所以 `wdctl`/ioctl 发 `V` 魔数关闭后应能 `rmmod`/退出而不咬——但**别在 bite 测试前做**。

---

## 6. 上游可投性（`arm-msm`）

### 6.1 能否单独投

**能，且是一个干净的 2 枚自成系列**（binding → dts），无外部依赖：

- `sm8750.dtsi`、`sm8750-mtp.dts`、`sm8750-qrd.dts` 都已在 7.4-rc3 树内；
  `sm8750-lenovo-elden.dts` 是本地板件（上一封 v7/v8 系列，patchwork `14991580`，state=new，0 回复，见
  `patches/upstream/elden-dts-v8-prep-20261121/README.md`）——**本系列不依赖它**，用 MTP/QRD 当载体即可。
- 收件人：`linux-arm-msm@vger.kernel.org` + `linux-watchdog@vger.kernel.org` + `devicetree@vger.kernel.org`；
  binding 走 Rob/Krzysztof 的 dt 流程（同系列内投，不拆开发）。
- 主题形状（已按上游习惯写）：`dt-bindings: watchdog: qcom: add SM8750 APSS watchdog` /
  `arm64: dts: qcom: sm8750: add APSS watchdog`。

### 6.2 需要连带什么

1. **binding 必须同系列**：只打 DT、不打 binding 时 `dtbs_check` 会报 **2 条诊断**（实测负样例，`evidence/gate-dtsonly-no-binding-dtbscheck.log`）：
   `watchdog@16410000 (qcom,apss-wdt-sm8750): compatible: 'oneOf' conditional failed … 'qcom,apss-wdt-sm8750' is not one of [...]`
   + `failed to match any schema`；本补丁把枚举加进 `qcom-wdt.yaml` 后，实测 mtp/elden/qrd 全 0 诊断（§4.4/§4.5）。
2. **不需要改驱动**：靠 `qcom,kpss-wdt` 回退；不需要动 `qcom_wdt_of_table`（同族也没加）。
3. **`dtbs_check` 覆盖**：`sm8750-mtp.dtb`（上游树内）+ 本地 `sm8750-lenovo-elden.dtb`（不入上游）都验过 0 诊断；
   上游 CI 用 `make dtbs_check` 时该节点会被 `qcom-wdt.yaml` + `watchdog.yaml` 双重覆盖。
4. **投递前要不要改 `status`**：上游同族 4 个节点都**不写** `status`（默认 okay），hamoa 例外写成 `"reserved"`。
   本补丁的 `status = "okay"` 是按本 lane 的父代理要求保留的（板级可用性/可覆盖性明确），
   **投递版建议删掉这一行**（否则 reviewer 大概率要求「drop redundant status」）；若上机证明 hyp 保留该窗口，
   则按 hamoa 先例改成 `status = "reserved"; /* Reserved by Gunyah */`——**这两个分支互斥，由上机结果定，不预选**。

### 6.3 「本机能否作为 Tested-by 证据」的分级

| 级别 | 现状 | 能写什么 |
|---|---|---|
| **build-tested**（主机） | ✅ 已做：`dtbs`/`dtbs_check`/`dt_binding_check`/`checkpatch` 全绿 | 补丁本身可写 `Tested-by` 只到「编译/校验」层级——上游不认，最多在 cover 里写 "build-tested only" |
| **功能实测**（设备） | ❌ 没做（本 lane 禁设备） | **不能**写 `Tested-by: Qianhui Xu` 的功能语义；要等 §5 全绿（含 bite 真复位） |
| **反例实测** | ❌ 没做 | 若 §5.1 第 0 步读不出 ⇒ 结论应是「SM8750 的 APSS WDT 对 Linux 不可用（hyp/TZ 保留）」，这时**不该投这个启用版**，应改投 `status = "reserved"` 的「document reserved window」或干脆不投 |
| **AI 辅助披露** | `AGENTS.md` §上游发信三件 | 投递文本开头如实写 AI 辅助（同 `out/mail-20261031/` 范式），本备料阶段不涉及 |

---

## 7. 未尽 / 风险（按阻塞度）

1. **基址是旁证推导，不是硬证**（§2 A）：只能上机读回定生死。**不要**在没有 §5.1 第 0 步结果前把 `okay` 核当日常件。
2. **中断号 `GIC_SPI 0` 未验**：同族 4 例都是它，SM8750 DT 里 SPI 0 目前无其他用户（`grep 'GIC_SPI 0 ' sm8750.dtsi` = 0），
   但硬件是否接线未知。即使接错也不会阻塞 probe（`platform_get_irq_optional`+`request_irq` 只在 IRQ 号非法时错），
   最坏是 bark 不来、只剩 bite。
3. **时钟 32 kHz 假设**：由板级 `sleep_clk`（`sm8750-lenovo-elden.dts:1246`、`sm8750-mtp.dts` 同值）给出；
   若 WDT 实际吃别的时钟，§5 判据 5 的墙钟测试会暴露（timeout 换算按 `rate`）。
4. **hyp 冲突**：`qcom_scm` 的 bail-out 意味着「APSS WDT 可用」与「gunyah-wdt 平台设备」**互斥**；
   `gunyah_wdt` 已证否，所以本改动不会丢功能，但要在投递/上机说明里写清（否则 reviewer 会问 `qcom_scm.c` 行为变化）。
5. **上游形状小分歧**：`status = "okay"` 与同族默认省略不一致（§6.2-4），投递前删/改。
6. **`dt_binding_check` 全量日志太大**：只存摘要进仓，原件在 `/tmp`（会随重启丢），摘要已足够复核。
7. **本 lane 没算上机成本**：§5 的 bite 测试要占「设备在 BL + 可零写盘回滚」窗口；`autotest-cycle.sh` 单轮 ≈90 s，
   bite 一发的复位等待 + 回 BL 看 ABL 日志 ≈ 2–3 min，估 **3 发以内**能定论（第 0 步只读 1 发、probe 1 发、bite 1 发）。
