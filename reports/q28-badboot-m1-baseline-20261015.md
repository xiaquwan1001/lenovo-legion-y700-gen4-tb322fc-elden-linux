# Q28 活体坏发取证：`boot_b` = `m1-baseline-f3`（2026-10-15）

> 状态/样本数 SSOT 仍是 `TASKS/README.md` §5 Q28；本文只记录**一次实测坏发**的原始证据与判读。
> 纪律：本报告所有数字均来自 `logs/q28-badboot-20261015/` 内的原始捕获文件，可独立复核。

---

## 0. 一句话

**上游化标准重建后的 M1-7.3 基线（`m1-baseline-f3`，已是 `boot_b`）在 E1b 修好显示回归之后，
依然会发生 Q28 坏发** —— 取证时该机正停在这个坏发态，`dsi_isr=0`、面板只有背光，
而 `card0-DSI-1` / phoc / phosh / wayland **全部正常**（典型「假 GOOD」）。

---

## 1. 取证环境

| 项 | 值 |
|---|---|
| 时间 | 2026-10-15 16:22–16:31 CST（设备**被发现**于坏发态） |
| 通道 | SSH over USB-NCM（`root@192.168.7.1`；主机侧 `enx021e5eede102` = `192.168.7.2`） |
| 设备身份 | SN `HA2EXB0E`（U2）、16+512 |
| 镜像 | `boot_b` = `out/boot-elden-m1-baseline-f3.img`，sha `40e13f8ad43b…` |
| 内核载荷 | `32e93db7a0c2…`；config `fe1a40b8…`；DTB `c801884334…` |
| UTS | `7.3.0-rc7-debug-ged6f232d10e3 #11 SMP PREEMPT Thu Oct 15 10:02:06 CST 2026` |
| 源码 | `m1-73/baseline` tip `ad5f03c43c`（= 7.3-rc7 + DSI 1 行 E1b + ath12k F3） |
| uptime @取证 | 7103 s（≈1 h 58 min）——**自 10-15 刷机冷起后从未复位** |
| cmdline | `… elden_nocamera=1 … msm_drm.dsi_display0=qcom,mdss_dsi_elden_nt36523_csot_3k_dsc_vid:` |
| 槽位 | `boot_b succ=1 retry=7 unbootable=0`（`trial.sh gate` = OK） |

---

## 2. 原始证据（逐项可复核）

### 2.1 L1 签名（真判别量）

```
[   11.913379] [ T1802] msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200
[   11.919154] [ T1802] msm_dsi ae96000.dsi: peer command DMA timeout: status=0x2200200
[   11.919167] [ T1802] msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
[   11.919182] [ T1802] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -110
```

`status=0x2200200` 与 `master=-110 peer=-110` 与历史坏发**逐字同**（10-09 起的既有签名）。

### 2.2 三态探针（`scripts/q28-devprobe2.sh`）

```
uname=7.3.0-rc7-debug-ged6f232d10e3 uptime=7165.27s
DSI_PLL_lockfail=4 device_link_fail=8 card0=1 l1=5 l2=2041 storm_sig=2046 \
  session=1 phoc=1 phosh=1 wayland=1 backlight=160 connected=1
connectors: card0-DP-1=disconnected card0-DSI-1=connected card0-Writeback-1=unknown
VERDICT=L1FAIL
```

> `l1=5` vs dmesg 里 4 行签名：差 1 是 probe 的正则多收了 `sending dcs data … failed` 一类行，属预期。

### 2.3 中断计数（★ 最干净的判别量）

```
187: 10 0 … msm_mdss  0 Edge  msm
188:  0 0 … msm_mdss  4 Edge  dsi_isr      <-- 0
189:  0 0 … msm_mdss  5 Edge  dsi_isr      <-- 0
222:  0 0 … msm_mdss 12 Edge  dp_display_isr
```

**`dsi_isr` 两条都为 0**：DSI 中断一次都没来过（好发历史值 = **41**，见 10-14 E1b 记录）。
这与「命令引擎 DMA hang、引擎/中断从未真正跑起来」的既有机制一致。

### 2.4 L2 风暴（L1 的**后果**，非独立问题）

| 计数 | 值 |
|---|---|
| `ctl [01] reset failure` | **834** |
| `vblank timeout` / `frame done timeout` | **1202** |

### 2.5 其它

| 项 | 值 |
|---|---|
| `DSI PLL(0) lock failed` | 4 |
| `Failed to create device link` | 8 |
| 背光 | `brightness=160`、`actual_brightness=160`（**开**）——但面板无内容 |
| `card0-DSI-1/status` | `connected` |
| phoc / phosh / wayland-0 | 1 / 1 / 存在 |

### 2.6 ★ 显示流水线**未在扫描**（客观证据，补 §6 的目视缺口）

```
$ cat /sys/kernel/debug/dri/0/debug/core_irq     # 采样 1
IRQ=[0, 26] count:0  cb:dpu_encoder_phys_vid_underrun_irq
IRQ=[0, 27] count:10 cb:0x0
IRQ=[0, 28] count:0  cb:dpu_encoder_phys_vid_underrun_irq
$ sleep 3; cat …                                  # 采样 2（3 s 后）
IRQ=[0, 26] count:0  cb:dpu_encoder_phys_vid_underrun_irq
IRQ=[0, 27] count:10 cb:0x0                       <-- 冻结在 10
IRQ=[0, 28] count:0  cb:dpu_encoder_phys_vid_underrun_irq
```

DPU core IRQ 计数在 3 s 窗口内**完全冻结**（正常扫描出图会持续递增）⇒
**显示流水线根本没在跑**，与 `dsi_isr=0` 相互印证。

⇒ 这**把 §6 的目视缺口补上了**：不需要目视也能客观认定「面板无内容」。
（`crtc-0/state` 仍报 `intf_mode: 2`、`core_clk_rate` 非 0，`card0-DSI-1` 仍 `connected`
——**这些静态属性在坏发上全部照常**，只有 IRQ/计数器是活的判别量。这再次强化 §3.3。）

### 2.7 看门狗**未**生效

```
/var/log/q28-watchdog.log 尾部（每行 = 一次开机）：
1970-01-04T04:45:14 disabled by /etc/q28-watchdog.disable [uptime=10.13s]
…
```

marker `/etc/q28-watchdog.disable`（2026-10-13 创建）**持续存在** ⇒ 看门狗关闭中，兜底没触发。
这与本次坏发**已持续 1 h 58 min 不自恢复**一致。

> 注意口径：本发属「坏发长期驻留」形态，**不是**看门狗可救的形态。
> 历史 `#231` 另记过第三形态「仅背光 + 无 SSH」（NOROUTE），本发**不属于**那一类（SSH 完全可用）。

---

## 3. 判读：三个结论

### 3.1 ★ Q28 与「构建身份 / vk 号 / 7.2 血统」全都无关（又一次独立验证）

本发跑在**全新的上游化基线树**上：7.3-rc7 基座 + 16 文件 payload、UTS `7.3.0-rc7-…`、
`m1-73/baseline` —— 与历史上做 Q28 实验的 `vk94`/`vk113`（7.2 血统）**血缘完全不同**，
却给出**逐字相同的坏发签名**。

⇒ 「坏发 ~50%、按时间成簇、与镜像/身份无关」的当前口径（`PITFALLS #217/#223`）**再次被独立证据支持**。

### 3.2 ★ E1b 修的是**另一个**层：Q28 不是「M1 树显示回归」

必须把两件事分开（这正是上游化重建带来的清晰度）：

| | E1b（上游缺口） | Q28（本报告） |
|---|---|---|
| 现象 | 面板只有背光，**确定性**点不亮 | 面板只有背光，**概率性**（~50%） |
| 根因层 | bonded 模式 `PLL_SYSTEM_MUXES=0xc0` 永不写入（`44784327815b` 撤了 `93c97bc8d85d`） | 首条 DCS `ff 20` 的 **bonded 命令 DMA 超时**（故障态在 DSI 控制器**之外**） |
| 状态 | ✅ 已修（1 行，在 baseline 内：`54dc4dd8fe`） | ❌ 未解 |

**本发就是「E1b 已在树内、却仍然坏」的实证** ⇒ 10-13/14 那批「上游 DSI 点不亮」的结论
**确实被显示回归污染**，不能在 E1b 之后继续引用（这正是 arm A 要复测的理由）。

### 3.3 ★ 「点亮」判据必须是面板实测（本发是教科书级反例）

坏发态下**以下全为真**：`card0-DSI-1=connected`、phoc=1、phosh=1、wayland 在、DPMS 正常、
`grim` 可出图（历史已验）、背光 160。

⇒ **只有 `l1==0` + `dsi_isr` 增长 + 用户目视**三者齐备才能判 GOOD（`PITFALLS #251/#255`）。
单看 connector/session ⇒ **必然误判**。

---

## 4. 与 arm A 实验的关系（本发现的价值）

1. **提供同基线的坏发锚点**：arm A 的对照臂 = `m1-baseline-f3`（就是本发这个镜像）。
   既然父臂**确证会坏**，「arm A 变好」才有可判别的意义（否则无从排除「父臂本来就全好」）。
2. **坐实「P2b/P2c 否证已过期」**：arm A 的立论前提（上游命令路径值得复测）得到支持。
3. **采样协议必须同会话交替**：本发与 10-15 上午那次 GOOD 相隔数小时、结论相反 ⇒
   再次证明**跨会话比较无效**（见 `.pi/plans/2026-10-15-armA-采样协议.md` §4）。

---

## 5. 产物与指针

| 项 | 路径 |
|---|---|
| trial record | `reports/trials/20261015T083353Z-m1-baseline-f3-badboot-20261015.json` |
| 全量 dmesg（4643 行） | `logs/q28-badboot-20261015/dmesg-full.txt` |
| **core_irq 冻结原始记录** | `logs/q28-badboot-20261015/core-irq-freeze.txt` |
| 状态快照 | `logs/q28-badboot-20261015/state.txt` |
| 三态探针输出 | `logs/q28-badboot-20261015/devprobe2.txt` |
| 启动日志摘录 | `logs/q28-badboot-20261015/bootlog.txt` |
| 采样协议 | `.pi/plans/2026-10-15-armA-采样协议.md` |

## 6. 本次未能取到的（诚实记录）

- **未做面板目视**：本报告在**无用户在场**时取得。但 §2.6 已用 **DPU core IRQ 冻结（3 s 内 0 增量）**
  + **`dsi_isr=0`** 两条客观计数给出「面板无内容」的硬证据（显示流水线未在扫描），
  故「面板只有背光」不再是纯推断。**仍建议**用户侧事后目视确认一次（低成本、可加倍坐实）。
- **未取串口日志**：`/dev/ttyACM0` logger 当时未跑（本机无串口会话）；dmesg 已全量留存，串口非必需。
- **未做因果实验**：本报告只做**取证与判读**，不含单变量改动。
