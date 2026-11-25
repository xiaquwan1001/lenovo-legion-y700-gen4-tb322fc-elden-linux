# B5 APSS Watchdog 备料静态复核（2026-11-26）

> 工单：对 `patches/local/apss-wdt-20261125/` 双推基址 `0x16410000` 进行独立静态复核。
> 本轮零设备、零写盘、零 git commit。产出 = 本文件（唯一写入路径）。

---

## §1 结论

| 项 | 判定 | 依据强度 |
|---|---|---|
| 基址 `0x16410000` | **可信（中等偏强），待上机读回定生死** | 两条独立推导收敛（XBL XPU 表 + 同族空间模式）；无反证；同族字面地址 `0x17600000`/`0x17410000` 均已排除 |
| 节点形状 | **与同族一致** | 4 例同代 SoC 逐字段一致（见 §2 对表） |
| Vendor DT 保护区冲突 | **无冲突** | reserved-memory 全部在 DRAM（≥0x8000_0000）；0x1641_0000 无 vendor 节点声明（见 §3） |
| 中断号 / 时钟 | **未证实**（按同族惯例推定） | GIC_SPI 0 在 sm8750.dtsi 无其他占用；sleep_clk=32000 由板级 DTS 定义 |
| 投递就绪度 | **门禁全绿但未投递** | 前序 lane 已跑 checkpatch/dtbs_check/dt_binding_check 0 诊断 |

### 采信 0x16410000 的推导链

1. **XBL XPU 表**：`backup/fw/tb322fc-edl/xbl_s.melf`（sha256 `8b09b3ae…`）偏移 `0x0db1dc` 处有 12 字节条目 `[addr=0x16410000, perm_mask=0xffe0, rsv=0]`，紧邻 `0x16420000`(PDP) / `0x16430000`(CPuCP)，是 SM8750 APSS 段唯一未被 vendor DT 其它节点占用的独立 4 KiB 窗口。
2. **同族空间模式**：kaanapali/glymur/hawi → `WDT(0x17600000) = PDP_mbox(0x17610000) − 0x10000`；hamoa/x1e80100 → `WDT(0x17410000) = CPuCP_mbox(0x17430000) − 0x20000 = PDP(0x17420000?) − 0x10000`。映射到 SM8750 vendor DT：PDP = `0x16420000` ⇒ WDT = `0x16420000 − 0x10000 = 0x16410000` ✓。
3. **XBL 字符串**：同文件含 `APPS_WDOG_BITE`、`WatchdogMgr.cpp`；`devcfg.mbn` 含 `OEM_sec_wdog_bark_time`/`OEM_sec_wdog_bite_time`/`OEM_wdog_ms_accept_hlos` ⇒ 该 SoC 确有 APSS 级 WDT，XBL/TZ 有管理痕迹。

### 关键存疑点

- XPU 表条目仅证明「XBL 认为此地址有设备并设了权限」，不 100% 等于「Linux 侧可读写且功能为 WDT」。
- 若 hyp/TZ 独占，`qcom_wdt_probe()` 第一句 `readl(WDT_STS)` (偏移 0xC) 即触发同步外部中止。

---

## §2 同族 SoC dtsi 对表

### 2.1 节点逐字段对比

| SoC | 文件:行 | compatible | reg 基址 | 长度 | clocks | interrupts | status |
|---|---|---|---|---|---|---|---|
| **kaanapali** (SM8850) | `kaanapali.dtsi:6033` | `qcom,apss-wdt-kaanapali`,`qcom,kpss-wdt` | `0x17600000` | 0x1000 | `<&sleep_clk>` | `GIC_SPI 0 EDGE_RISING` | 无（默认 okay） |
| **glymur** | `glymur.dtsi:8183` | `qcom,apss-wdt-glymur`,`qcom,kpss-wdt` | `0x17600000` | 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| **hawi** | `hawi.dtsi:5115` | `qcom,apss-wdt-hawi`,`qcom,kpss-wdt` | `0x17600000` | 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| **hamoa** (x1e80100) | `hamoa.dtsi:8584` | `qcom,apss-wdt-x1e80100`,`qcom,kpss-wdt` | `0x17410000` | 0x1000 | `<&sleep_clk>` | 同上 | `"reserved"` |
| **kodiak** (sc7280) | `kodiak.dtsi:6966` | `qcom,apss-wdt-sc7280`,`qcom,kpss-wdt` | `0x17c10000` | 0x1000 | `<&sleep_clk>` | 同上 | `"reserved"` |
| **sm8250** | `sm8250.dtsi:6136` | `qcom,apss-wdt-sm8250`,`qcom,kpss-wdt` | `0x17c10000` | 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| **sm8150** | `sm8150.dtsi:4410` | `qcom,apss-wdt-sm8150`,`qcom,kpss-wdt` | `0x17c10000` | 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| **sc8280xp** | `sc8280xp.dtsi:6010` | `qcom,apss-wdt-sc8280xp`,`qcom,kpss-wdt` | `0x17c10000` | 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| **sdm845** | `sdm845.dtsi:5370` | `qcom,apss-wdt-sdm845`,`qcom,kpss-wdt` | `0x17980000` | 0x1000 | `<&sleep_clk>` | 同上 | 无 |
| **nord** | `nord.dtsi:2072` | `qcom,apss-wdt-nord`,`qcom,kpss-wdt` | `0x17826000` | 0x1000 | `<&sleep_clk>` | `GIC_ESPI 848` | 无 |
| **补丁新增 (sm8750)** | `patches/…/0002:sm8750.dtsi` | `qcom,apss-wdt-sm8750`,`qcom,kpss-wdt` | **`0x16410000`** | **0x1000** | `<&sleep_clk>` | `GIC_SPI 0 EDGE_RISING` | `"okay"` |

> 以上所有文件路径相对于 `build/elden-tree/arch/arm64/boot/dts/qcom/`。

### 2.2 形状结论

- compatible 格式：`qcom,apss-wdt-<soc>` + 回退 `qcom,kpss-wdt`——**全部一致**。
- reg 长度：`0x1000`——**全部一致**。
- clocks：`<&sleep_clk>`，无 `clock-names`——**全部一致**。
- interrupts：`GIC_SPI 0 IRQ_TYPE_EDGE_RISING`（nord 除外，用了 GIC_ESPI）——**同代一致**。
- 无 `#reset-cells`——**全部一致**。

### 2.3 基址分代与 SM8750 的偏移

| 世代 | 基址 | 代表 | SM8750 映射 |
|---|---|---|---|
| 845 | `0x17980000` | sdm845 | ❌ 不适用 |
| 855/865 | `0x17c10000` | sm8150/sm8250/sc8280xp/kodiak | ❌ 不适用 |
| x1e/8 Elite 前代 | `0x17410000` | hamoa/x1e80100 | ❌ **已证否**（UEFI p57 外部中止 `far=17410000`） |
| 8 Gen 4/同代 | `0x17600000` | kaanapali/glymur/hawi | ❌ SM8750 APSS 段已整体移至 `0x164x_xxxx`（vendor DT 实测） |
| 不同 die | `0x17826000` | nord | ❌ 无对应 |
| **SM8750** | **`0x16410000`** | 本补丁 | 推导：XBL XPU 表 + PDP(0x16420000) − 0x10000 |

### 2.4 GIC_SPI 0 可用性验证

```
$ grep -n 'GIC_SPI 0 ' build/elden-tree/arch/arm64/boot/dts/qcom/sm8750.dtsi
（无结果）
$ grep -n 'GIC_SPI 0 ' build/daily/arch/arm64/boot/dts/qcom/sm8750.dtsi
（无结果）
```

GIC_SPI 0 在 SM8750 上游/日常树均无其他用户，与同族「WDT 用 SPI 0」惯例一致。

---

## §3 Vendor DTB 核对

### 3.1 watchdog 节点

```
$ dtc -I dtb -O dts backup/stock-elden/dtb/06_*Sun_SoC.dtb | grep -n -i 'watchdog\|wdt'
24344:    qcom,gh-watchdog {      ← /hypervisor/ 下，无 reg，仅 phandle
26098:    gh_watchdog = "/hypervisor/qcom,gh-watchdog";   ← __symbols__
```

**结论**：vendor DT **无任何 `watchdog@` MMIO 节点**。唯一的 watchdog 是 `/hypervisor/qcom,gh-watchdog`（Gunyah VM 级看门狗，无 reg 属性，Linux 侧用 SMCCC 接口——已在上轮证否为 hyp 空实现）。

对 13 个分包 DTB 全量扫一遍：

```
$ for f in backup/stock-elden/dtb/[0-9][0-9]_*.dtb; do
    dtc -I dtb -O dts "$f" 2>/dev/null | grep -qi 'watchdog@' && echo "HIT: $f"
  done
（无输出 = 无 watchdog@ 节点）
```

### 3.2 0x16410000 地址占用检查

```
$ dtc -I dtb -O dts backup/stock-elden/dtb/06_*Sun_SoC.dtb | grep -n '16410000'
（无结果）
```

在 APSS 段，vendor DT 仅有：
| 行 | 节点 | 地址 |
|---|---|---|
| 6418 | `timer@16800000` | 0x16800000 |
| 6741 | `rsc@16500000` (apps_rsc) | 0x16500000–0x1652FFFF |
| 8738 | `syscon@16450000` | 0x16450000–0x16456FFF |
| 12537 | `qcom,cpucp@0x17830000` | rx=0x16430000(0x4c08) tx=0x17830000(0x300) |
| 12546 | `qcom,pdp0@0x18980000` | rx=0x16420000(0x4c08) tx=0x18980000(0x300) |
| 12556 | `qcom,pdp1@0x19980000` | rx=0x16420000(0x4c08) tx=0x19980000(0x300) |

**0x16410000–0x16410FFF 不被任何 vendor 节点覆盖**。

### 3.3 Reserved-memory 冲突检查

所有 `reserved-memory` 子节点的 `reg` 基址 ≥ `0x80000000`（DRAM 物理地址空间），
无一覆盖 MMIO 空间（`0x16410000` 在 `0x0000_0000–0x1FFF_FFFF` MMIO 段）。

**结论：补丁的 `reg = <0x0 0x16410000 0x0 0x1000>` 与 vendor DT 的任何节点或保留区不冲突。**

### 3.4 XBL XPU 表原始 hex（二次独立复核）

```
$ xxd -s 0x0db1c0 -l 100 backup/fw/tb322fc-edl/xbl_s.melf
000db1c0: 0000 0000 0000 3316 03ff 0000 0000 0000  ......3.........
000db1d0: 0000 4016 80ff 0000 0000 0000 0000 4116  ..@...........A.
000db1e0: e0ff 0000 0000 0000 0000 4216 00ff 0000  ..........B.....
000db1f0: 0000 0000 0000 4316 40ff 0000 0000 0000  ......C.@.......
000db200: 0000 5016 00ff 0000 0000 0000 0000 5116  ..P...........Q.
000db210: 00ff 0000 0000 0000 2000 062f 0116 0000  ........ ../....
```

解析为小端 32-bit 三字段（addr / perm_mask / reserved）：

| 偏移 | 地址 | 权限 mask | 备注 |
|---|---|---|---|
| 0xdb1c4 | `0x16330000` | `0xff03` | 未知（非 WDT 候选） |
| 0xdb1d0 | `0x16400000` | `0xff80` | APSS glue/基座 |
| **0xdb1dc** | **`0x16410000`** | **`0xffe0`** | **WDT 候选** |
| 0xdb1e8 | `0x16420000` | `0xff00` | PDP（vendor cpucp-v2 rx） |
| 0xdb1f4 | `0x16430000` | `0xff40` | CPuCP（vendor cpucp-v2 rx） |
| 0xdb200 | `0x16500000` | `0xff00` | apps_rsc |
| 0xdb20c | `0x16510000` | `0xff00` | apps_rsc 续 |

`0xffe0` 是独立且更宽松的 mask，暗示此窗口有特定的主从访问控制（WDT 通常只允许 Apps CPU 访问，不允许 ADSP/SLPI 等）。

---

## §4 上机判据清单

> **前提**：零写盘 `fastboot boot`（不碰 boot_a/boot_b），设备已在 BL，可 `to-bootloader.sh` 随时回退。
> **安全硬约束**：第 0 步是前置守门；读不出则整条路径终止。

### 第 0 步：只读探基址（disabled 核）

**准备**：构造一份 `status = "disabled"` 的 DTB 变体，打入候选核。

```bash
# 主机侧：改 status 重编 dtb
sed -i 's/status = "okay"/status = "disabled"/' \
  build/daily/arch/arm64/boot/dts/qcom/sm8750.dtsi   # 或补丁插入后手动改
scripts/build-kernel.sh dtbs
# 重打包候选件（沿用 build-manifest 流程）
```

**设备上**（RAM 起，SSH 可达后）：

| # | 命令 | 期望输出 | 失败判据 |
|---|---|---|---|
| 0a | `busybox devmem 0x16410000 32` | 返回 32-bit 值（如 `0x00000000`） | **SIGBUS / 无返回 / kernel panic** ⇒ 基址错或被 hyp/TZ 独占，**终止全部后续** |
| 0b | `busybox devmem 0x1641000C 32` | 返回 WDT_STS 值（bit0=EXPIRED；首启应为 0 或 1 但不崩溃） | 同上 |
| 0c | `busybox devmem 0x16410008 32` | WDT_EN：bit0=0（未启用，因为 XBL 可能已经关掉或从没开） | — |

> ⚠️ `devmem` 一次只读一个字（`PITFALLS #553`）。若第一条就触发外部中止，USB 会掉，系统死机需物理 POR。

### 第 1 步：Probe 验证（okay 核）

换 `status = "okay"` 的候选核零写盘起机。

| # | 命令 | 期望输出 | 失败判据 |
|---|---|---|---|
| 1a | `dmesg \| grep -iE 'qcom-wdt\|watchdog'` | `qcom-wdt 16410000.watchdog: …` 注册成功 | `invalid clock rate` ⇒ sleep_clk 未绑定；`failed to get input clock` ⇒ clocks 缺失；外部中止 ⇒ 基址错 |
| 1b | `ls -l /dev/watchdog*` | `/dev/watchdog` + `/dev/watchdog0` 存在 | 不存在 ⇒ probe 失败 |
| 1c | `ls /sys/bus/platform/devices \| grep -i gunyah` | **空**（`qcom_scm` bail-out 不注册 gunyah-wdt） | 非空 ⇒ 两狗冲突（不应发生） |
| 1d | `cat /proc/device-tree/soc@0/watchdog@16410000/status` | `okay` | — |

### 第 2 步：功能验证（喂狗/超时）

| # | 命令 | 期望输出 | 说明 |
|---|---|---|---|
| 2a | `ioctl WDIOC_GETSUPPORT` (wdctl 或自写) | `identity = "qcom-wdt"`, `options` 含 `WDIOF_CARDRESET` | — |
| 2b | `ioctl WDIOC_GETTIMEOUT` | `30`（驱动 default = min(max_timeout=32, 30)） | `max_timeout = 0xFFFFF/32000 = 32 s` |
| 2c | `ioctl WDIOC_SETTIMEOUT, arg=10` → 返回新超时 | `10` | — |
| 2d | 连续 `WDIOC_KEEPALIVE` 每 5 s 一次 × 3 次 | 不复位 | 证明喂狗通道有效 |
| 2e | 最后一次 KEEPALIVE 后停止喂狗，计时 | **≈10 s 后整机复位** | 若 ~320 s ⇒ 时钟非 32 kHz；若 ~1 s ⇒ 时钟过高；若永不复位 ⇒ 寄存器写无效 |

### 第 3 步：复位原因确认（破坏性测试后）

| # | 命令 | 期望输出 |
|---|---|---|
| 3a | 复位后回 BL，`scripts/abl-log.sh \| grep -i 'APPS_WDOG_BITE\|WDOG'` | 包含 `APPS_WDOG_BITE`（XBL reset reason 表有该字符串） |
| 3b | 重新起 Linux 后 `ioctl WDIOC_GETBOOTSTATUS` | `WDIOF_CARDRESET` 置位（驱动读 WDT_STS bit0） |

### 第 4 步：挂起/恢复（可选，低风险）

```bash
systemctl suspend
# 等 5 s 后唤醒（USB 插拔/电源键）
wdctl /dev/watchdog0   # 或 ioctl GETSTATUS
```

期望：唤醒成功；watchdog 在 resume 后自动重启（驱动有 `SET_LATE_SYSTEM_SLEEP_PM_OPS`）。

### 回退策略

| 阶段 | 回退方法 |
|---|---|
| 任何阶段 | `fastboot reboot` 或拔 USB 回 BL 起日常件（零写盘件不影响 boot_a/b） |
| 第 0 步外部中止 | 物理长按电源 15 s POR（PITFALLS #553 代价） |
| 第 2e 步复位 | 等待 ~30 s 自动回 BL/OS，无需人工干预 |

---

## §5 剩余风险与需用户放行项

### 风险

| # | 风险 | 等级 | 影响 |
|---|---|---|---|
| R1 | **基址错/被 hyp 独占**：probe 第一句即同步外部中止 | **高** | 需物理 POR；补丁作废 |
| R2 | **中断号错误**（GIC_SPI 0 未接线到 WDT bark）：不影响 bite，只影响 pretimeout（提前告警） | 低 | 最坏无 bark 中断、只有 bite |
| R3 | **时钟非 sleep_clk**（如吃 CX XO 19.2 MHz）：timeout 换算会偏 | 中 | 第 2e 步墙钟会暴露 |
| R4 | **XBL 已关闭 APSS WDT**（`boot_wdog_disable_check` 字符串暗示 XBL 会在移交时禁用）：Linux 侧拿到后需重新 enable，但寄存器可能锁定 | 中 | 需确认写入 WDT_EN 是否生效 |
| R5 | **hyp memextent**：`hypvm.mbn` 内有 `Failed creation of watchdog memextent` 字符串 ⇒ hyp 可能已为该地址建了 memextent，Linux 侧访问会被 stage-2 拦截 | 中 | 与 R1 同表现（外部中止） |
| R6 | **status="okay" 触发的 qcom_scm bail-out**：一旦本节点存在且 available，gunyah-wdt 不注册——已确认 gunyah_wdt 本身为空实现故无功能损失，但若未来 hyp 侧修复则两狗冲突 | 低（当前） | 投上游时 reviewer 会问 |

### 需用户放行项

1. **第 0 步上机窗口**：需设备在 BL + 可物理 POR 的窗口（若基址错则需长按断电）。建议安排在有人工值守时段。
2. **构造 disabled DTB 变体**：需修改 sm8750.dtsi 的 status 字段重编 dtb 并重打包 boot.img。本轮静态复核不执行此步（仅写判据）。
3. **投递前决定 status 字段**：上游同族均省略 status（默认 okay），hamoa/kodiak 写 `"reserved"`。本补丁当前为 `"okay"`。若上机证明 hyp 保留 ⇒ 改 `"reserved"`（此时不可投上游作为可用驱动，只能作为文档）。

---

## 复现命令汇总

```bash
# XBL XPU 表 hex 复核
xxd -s 0x0db1c0 -l 100 backup/fw/tb322fc-edl/xbl_s.melf

# Vendor DT 解包 + watchdog 搜索
dtc -I dtb -O dts backup/stock-elden/dtb/06_dtbdump_Qualcomm_Technologies,_Inc._Sun_SoC.dtb \
  | grep -n -i 'watchdog\|wdt\|16410000'

# 同族对表（以 kaanapali 为例）
grep -n -A5 'watchdog@17600000' build/elden-tree/arch/arm64/boot/dts/qcom/kaanapali.dtsi

# GIC_SPI 0 占用检查
grep 'GIC_SPI 0 ' build/elden-tree/arch/arm64/boot/dts/qcom/sm8750.dtsi

# sleep_clk 定义
grep -n -A4 'sleep-clk' build/elden-tree/arch/arm64/boot/dts/qcom/sm8750-mtp.dts

# 驱动 probe 关键路径（会读 WDT_STS）
sed -n '223,225p' build/elden-tree/drivers/watchdog/qcom-wdt.c

# qcom_scm bail-out（确认互斥逻辑）
sed -n '2506,2530p' build/daily/drivers/firmware/qcom/qcom_scm.c
```
