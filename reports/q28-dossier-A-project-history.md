# Q28 内部史料档案（A 卷 · 项目史）

> **性质**：只读史料梳理。本轮**未改任何代码/配置、未上机、未发信**；唯一写入 = 本文件。
> **覆盖范围**：`PITFALLS/`（条目 + 索引）、`reports/`（`*q28*`/`*panel*`/`*dsi*`/`*DYN*` 等）、
> `TASKS/README.md` §4/§5、`DEVICE/README.md` §1.1 与 `DEVICE/sessions/`、`packaging/elden-userland` 的三个 q28 脚本、
> `TASKS/sessions/` 的 q28 会话稿、`PROGRESS.md`、`INDEX.md` §0。
> **枚举命令（原文）**：
> `rg -ril 'q28' | wc -l` → **2677**；`rg -ril 'q28' | sort`（全文件表已检视，主要实体见文末 §7）；
> `ls reports/ | rg -i 'q28|panel|dsi|dyn|^il-|dsc|vblank|edp|mdss|backlight'` → 43 个 `q28-*`/相关报告。
> **口径纪律**：本文**只做归档**，不改写任何状态词。SSOT 仍是 `reports/q28-DOSSIER.md`（机理/过程）+ `TASKS/README.md` §5 Q28（状态）
> + `DEVICE/README.md` §1.1（在机镜像）；本文与它们冲突时以它们为准，且冲突本身在 §5 列出。

---

## ① 一句话结论

> **Q28 = 「冷起面板 init 间歇失败（只有背光/无桌面）」；它在 2026-10-24 被用户按「已规避」结项（运营判断，不是「已解决」），
> 机理至今未定**；而 **2026-11-16 一发真坏发又出现在 a 槽 UEFI/GRUB 路径（内核 vk192）上、且没有按结项文件写死的复启条件做现场取证**
> ⇒ 当前档案的准确状态是：**运营兜底在位、代码级缓解在位、根因未定、复启条件①事实上已被触碰但流程未走**。

依据：`reports/q28-workaround-closeout-20261024.md:9-10`（「判据不是根因已解释，而是三条同时成立」）、
同文件 `:25-26`（「0/5 坏发 ⇒ 95% 单侧上界仍约 45%…**不得在任何文档里写成『Q28 已解决』**」）、
`TASKS/README.md:390`（Q28 行状态「🟢 已规避·结项（2026-10-24 用户裁决）」）、
`DEVICE/README.md:56`（「该轮其中一发是真 Q28 坏发（屏白→仅背光、msm 未 bind），属 #228 存量问题」）、
`reports/q28-workaround-closeout-20261024.md:39-41`（复启条件三条）。

---

## ② 时间线（项目史）

| 日期 | 事件 / 结论 | 证据（文件:行 或 条目） |
|---|---|---|
| 2026-10-08 | 基线 `vk64`；**首次观测 Q28**：冷起约 6 成失败、只有背光 | `PROGRESS.md:16`；`versions/vk-registry.tsv` vk64 行；`PITFALLS/sessions/22-构建守卫&Q28变量纠正.md:13`（#164） |
| 2026-10-09 | 根因收窄 = bonded 双 DSI **首条 DCS `ff 20` 命令 DMA hang**；vk73 诊断内核/上机 | `PROGRESS.md:17`；`versions/vk-registry.tsv` vk73/vk74 行 |
| 2026-10-10 | 双模式定案：**NOCARD / STORM**；`#166` 暖复位粘 NOCARD；`#167` 脚本漏判；`#162` 死内核事故 | `PITFALLS/sessions/22-…md:20,27,31`；`reports/q28-DOSSIER.md:111`（§d 两模式表） |
| 2026-10-10 夜 | `#170` 真实 POR 2/2 STORM（复位深度阶）→ `#171`「按内核二进制确定性」→ §l 被**溯源审计降级** | `reports/q28-DOSSIER.md:213,226,276`；`PITFALLS/sessions/22-…md:41,51` |
| 2026-10-10 夜 | `#172` 判 GOOD 必须加**存活门**（`storm=0` 的干净 GOOD 数秒冻死） | `PITFALLS/sessions/22-…md:53`；`reports/q28-DOSSIER.md:276` |
| 2026-10-11 | `#175` NOCARD 与 **`LOCALVERSION` 版本串**强相关（n 小）→ `#192`「冷起 GOOD/NOCARD = 内核构建身份法则」+ PINUTS 解锁冷起 A/B | `PITFALLS/sessions/23-…md:15`、`PITFALLS/sessions/25-…md:3`；`reports/q28-DOSSIER.md:301,360,384` |
| 2026-10-12 | `#195` STORM 也是构建身份伪影（`#60` 4坏/2好 vs 3位 0/12+，p≈0.005）→ **当日深夜被 `#217` 推翻**（3 位身份 4 发中仍有 1 L1FAIL） | `PITFALLS/sessions/25-…md:19`、`PITFALLS/sessions/27-…md:123`；`reports/q28-identity-retest-20261012.md:11-18` |
| 2026-10-12 | `#196` `to_primary_dsi` DSI0/DSI1 = 伪线索（no-op）；`#223` 上游 byte-clk 取整 `2028280686f4` **不修** STORM + 坏发**按时间成簇** | `PITFALLS/sessions/26-…md:3`、`PITFALLS/sessions/28-上游邮件通道.md:32`；`PROGRESS.md:25,34` |
| 2026-10-12 | `#224` 运行期重绑 DSI host/panel 不恢复、反拆 DRM；`#225` 未就绪 `reboot2` 打进无 USB 态 | `PITFALLS/sessions/28-…md:39,45` |
| 2026-10-12 深夜 | **七臂 vk116–vk122（+vk123）全否证**；判别量 = **DYN pclk 域闩住**；`#226` | `PITFALLS/sessions/28-…md:51`；`reports/q28-dsi-recover-20261012.md:385-415`；`PROGRESS.md:37` |
| 2026-10-12 | `#227` 原厂 display 源码静态对照：「dispcc 映射进 DSI」靶点前提**不成立**；唯一新差异 = 复位终态 `CLK_CTRL=0` | `PITFALLS/sessions/28-…md:57`；`reports/q28-dispcc-static-20261012.md:11-18` |
| 2026-10-12 | **`#228` 运营兜底看门狗上机**（坏发 75 s 自动正常重启，~50%→~75%）；顺带 `#229` `reboot2` 旧构建地雷 | `PITFALLS/sessions/28-…md:66,74`；`reports/q28-watchdog-20261012.md:11-16` |
| 2026-10-12 深夜 | 上游 Q28 报告投递并归档（Message-ID `179184923104.248043…@mail.ustc.edu.cn`） | `reports/Q24-Q28-INDEX.md` §2；`archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md` |
| 2026-10-13 07:04 | `#230` T3 = 复位终态对齐臂 `vk125` **寄存器级否证**（`CLK_STATUS 0x3743→0x1403→0x1743`） | `PITFALLS/sessions/28-…md:80`；`reports/q28-dsi-recover-20261012.md:448-464` |
| 2026-10-13 07:21 | `#231` **第三形态：仅背光 + 无 SSH（hung）**；同时更正 `#228` 的乐观口径 | `PITFALLS/sessions/28-…md:87,90` |
| 2026-10-13 深夜 | 上游显示栈对照 P1–P2c：上游 DSI host/manager+vendor PHY **1 发 GOOD 无 Q28 签名**（疑 vendor 命令路径专有） | `reports/q28-INDEX.md:65-70`；`PITFALLS/sessions/32-…md:3`（#251） |
| 2026-10-14 | P2b 复测 **4/4 未复现**且面板未实测 ⇒ 悬置；Q31（面板只有背光）由 E1b `PLL_SYSTEM_MUXES=0xc0` 解 | `reports/Q24-Q28-INDEX.md:11`；`TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md:13`（§Q31） |
| 2026-10-15 | DOSSIER §r：M1-7.3 上游化基线 `m1-baseline-f3` 活体坏发**驻留 1 h 58 min**，签名逐字同型 ⇒「与镜像/血统无关」 | `reports/q28-DOSSIER.md:426-449`；`reports/q28-badboot-m1-baseline-20261015.md`（`q28-INDEX.md` 未列，属 §r 证据） |
| 2026-10-15 | 判据再修正：`#274`「不变量是面板黑，不是 `-110`」、`#275`「点亮只认用户目视」、`#276` 两亚型靠电源键控背光区分、`#277` PLL lockfail 是良性噪声 | `PITFALLS/sessions/37-Q28-armA：命令路径否证与「面板黑」是不变量.md:6,13,21,27` |
| 2026-10-17 | 重放镜像 `vk127` 真 POR 冷起 **7 发坏 / 第 8 发 GOOD** | `DEVICE/README.md:186` |
| 2026-10-22 | `#366` **运行期取证：两处代码级缺陷**（`dsi_bonded_cmd_failed` 单向闩锁 / `link_configured` 误清）；硬件侧首次被测到 `STATUS0=0x175`、`CLK_STATUS=0x23f` | `PITFALLS/sessions/61-Q28单向闩锁把硬件故障伪装成不可恢复.md:1`；`reports/q28-DOSSIER.md:451-505` |
| 2026-10-22 | **2×2 冷起 A/B 解离**：base 5/9 STORM、only0155 3/4、only0154 **5/5 GOOD**、exp 10/10；含 0154 两臂合并 **15/15 vs 4/9，Fisher 双侧 p=0.003** | `reports/q28-disp-init-ab-20261022.md:73-110` |
| 2026-10-22 | 日常候选 `vk145`（7.3 线 + 0154 + 0155 + 两修）冷起 **8/8 GOOD** vs 同日 daily **0/4**（p=0.002），并写 `boot_b` | 同上 `:200-230`；`DEVICE/sessions/2026-11-02-在机状态沿革-vk64..vk172.md:126` |
| 2026-10-23 | Q28 v2：三块 BCR 复位**搬到 display 侧 `msm_mdss_reset()`**，真 POR **5/5 GOOD**（第一版 `-EBUSY` 已修） | `reports/q28-v2-mdss-reset-20261023.md:9-20`；`TASKS/sessions/2026-11-03-TASKS行445-Q28.md:28` |
| 2026-10-23 夜 | `vk152` 真 POR r1/r2 = 2/2 GOOD，判据段 `diff` 空；「`psci: SYSTEM_RESET2` 计数 = 0」定为真 POR 硬判据 | `reports/q28-por-samples-r1r2-20261023.md:14-27`、`:49-54` |
| 2026-10-24 凌晨 | **Q32 五发表**：W1×2 / C1×2 / W2×1 全 GOOD、三入口无差异 ⇒ Q32 并入 Q28；`FW_LIVE_FB=yes` 5/5、`SIMPLEDRM=0` 5/5 | `reports/q32-matrix-20261024.md:9-23`；`PROGRESS.md:51` |
| 2026-10-24 | **Q28 收口 = 「已规避」（运营线 vk152）**：POR 5/5 + 暖复位 3/3 = 8/8 无坏发；用户裁决不补样本、不挖根因 | `reports/q28-workaround-closeout-20261024.md:1-26`；`PROGRESS.md:52` |
| 2026-10-26 | 外部确认 `dsiclk_sel=0` 是正确取值 ⇒ 该差异候选**正式关闭** | `reports/q28-workaround-closeout-20261024.md:45-47` |
| 2026-10-31 | `vk183-fastrpc` 真 POR：**7 项 Q28 计数全 0**（含 `dsi_bonded_cmd_failed`/`vblank timeout`/`command DMA timeout`），`DSI PLL lock failed=4` 与基线同 | `DEVICE/sessions/2026-11-02-在机状态沿革-vk64..vk172.md:40` |
| 2026-11-16 14:46 | a 槽 UEFI/GRUB 冷起：① 看门狗 **card0 误判**（`#667`）② **一发真 Q28 坏发**（屏白→仅背光、msm 未 bind），未留 dmesg/trial 现场 | `PITFALLS/sessions/303-q28看门狗只认card0-UEFI路径card1误判.md:3-14,31-33`；`DEVICE/README.md:56`；`reports/artifacts/uefi-daily-v8-20261116/README.md`（「异常 B」段） |

---

## ③ 症状族与判据

### 3.1 四个征状族（互相不可并入）

| 族 | 现象 | 判据（当时） | 出处 |
|---|---|---|---|
| **NOCARD** | 无 `/sys/class/drm/card0`；早期 `DSI PLL(0) lock failed, status=0x00000000`（~0.86 s）+ `Failed to create device link … panel@0`；管道没跑到 cmd-DMA | 无 card0 | `reports/q28-DOSSIER.md:111-125`（§d）；`PITFALLS/sessions/22-…md:20`（#165）；`scripts/q28-devprobe.sh:4` |
| **STORM** | 有 card0，但 `command DMA timeout status=0x2200200` + `bonded command DMA failed master=-110 peer=-110` + `ff 20` -110→-5 + `ctl 1 reset failure -22` + frame-done/vblank 风暴 | 有 card0 + 风暴签名 > 0 | `reports/q28-DOSSIER.md:52-60`（§b B2）、`:111`；`scripts/q28-devprobe.sh:10,21` |
| **假 GOOD / 面板黑** | connector `connected`、`dpms=On`、背光在、`phoc/phosh` 在、`grim` 能出图、`core_irq` 递增，**面板仍全黑** | **只认用户目视** | `PITFALLS/sessions/37-…md:13`（#275）、`:6`（#274）；`reports/q28-DOSSIER.md:443`（§r 假 GOOD 行） |
| **NOROUTE / hung** | `fastboot boot` 回 OKAY，但 150 s 无 SSH、无 fastboot、仅背光、30 min 仍不可达 | 无 SSH ⇒ `NOROUTE`，**不得**并入 NOCARD/STORM | `PITFALLS/sessions/28-…md:87-93`（#231）；`archive/2026-10-15-retired-scripts/q28-cold-run.sh:47` |

两个**亚型**：靠「电源键能否控背光」区分、dmesg 看不出来（`PITFALLS/sessions/37-…md:21`，`#276`）。

### 3.2 同域但**不同问题**（易被档案混读，逐一钉死）

| 现象 | 归属 | 证据 |
|---|---|---|
| 「背光被自动亮度压到 ~4% ⇒ 看着像黑屏」 | **不是 Q28**（判据陷阱） | `PITFALLS/README.md:98`（`#372`）；`DEVICE/sessions/2026-11-02-在机状态沿革-vk64..vk172.md:125` |
| 「背光亮一下即掉电」（`vk146`/`vk128`/`vk129`） | **模块树 ABI 失配**（`CONFIG_SUSPEND` 漂移），非 Q28 | `DEVICE/sessions/2026-11-02-在机状态沿革-vk64..vk172.md:127,128`；`PITFALLS/README.md:323`（`#625`） |
| 「UEFI `ExitBootServices()` 之后面板被驱动退出流程熄掉」 | 另一条链（`#531`），EDL/EB 取证语境 | `PITFALLS/README.md:238`（`#531`） |
| 「桌面空闲自发掉线：`dpms=Off`/`enabled=disabled`/`grim` 挂住」 | **明确「非 Q28 触发路径」** | `DEVICE/sessions/2026-11-02-在机状态沿革-vk64..vk172.md:78-81` |
| 「只有开机首次 modeset 触发」（80 轮 DPMS 上电循环 0 命中） | Q28 的范围收窄（§5 表行） | `TASKS/README.md:432` |
| kexec 目标「死于 Q28 同源 bonded DSI 初始化」 | Q28 下游影响（kexec 拿不到显示） | `TASKS/README.md:133` |

### 3.3 判据演进（每代都曾把上一代判错）

1. **card0 二元判据** → 被 `#165` 打破（只数风暴签名会把「管道没起来」误判 GOOD）——`PITFALLS/sessions/22-…md:20`。
2. **三态 NOCARD/STORM/GOOD**（`scripts/q28-devprobe.sh:3-6`）→ 仍漏「GOOD 但整机冻死」。
3. **+ 存活门 60/65/75 s**（`#172`、`q28-cold-run.sh` 65 s、看门狗 75 s）——`PITFALLS/sessions/22-…md:53`、`packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh:16`。
4. **+ `l1==0` + `dsi_isr` + `core_irq` 递增**（客观替代目视）——`reports/q28-DOSSIER.md:443`（§r 结论 3）；`#251/#255`。
5. **「点亮」只认用户目视**（DRM 判据集体失效）——`PITFALLS/sessions/37-…md:13`。
6. **真 POR 硬判据**：`fastboot getvar all | grep -c "psci: SYSTEM_RESET2"` = 0（`TASKS/README.md:390`；`reports/q28-por-samples-r1r2-20261023.md:49-54`）。
7. **复位深度改用 pstore 指纹判读**（W1 vendor `0x80010001` / W2 arch / 空 = POR）——`reports/q32-matrix-20261024.md:36-40`；`#374/#377`。
8. **有会话 + 有 cardN**（看门狗现状，含 2026-11-16 修订）——`packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh:8-13,41-50`。

### 3.4 判据冲突（同一标签两种含义，归档时必须写明）

- **`NOROUTE` 有两套语义**：
  - `NOROUTE = 150 s 无 SSH`（PITFALLS #231 口径）：`archive/2026-10-15-retired-scripts/q28-cold-run.sh:7,47`。
  - `NOROUTE = card0 在、无 connected 输出`：`scripts/q28-devprobe.sh:25`、`scripts/q28-devprobe2.sh:17,52`。
- **`#228` 有两个命名空间**：`PITFALLS/sessions/28-上游邮件通道.md:66` 的 `228.` 是**坑编号**；
  `PITFALLS/README.md:271` 的 `| 228 |` 是**会话序号**，对应坑 `#574`（Mu 树浅克隆）。检索时按 `#NNN` 前缀区分。

---

## ④ 已否证假设（带证伪证据）

| # | 曾提出的假设 | 证伪证据 | 结论出处 |
|---|---|---|---|
| 1 | 「面板级 reset 重试」能修（vk64 的 `d02658e63` retry on -110） | 重试的第 2/3 次根本没到硬件（`-5` = 闩锁短路）；清闩锁后回到 `-110` | `reports/q28-dsi-recover-20261012.md:12-24`（§2）、`:387-393`（§16.2 第 1 行） |
| 2 | 「软件闩锁是根因」 | `vk116` 清闩锁后故障照旧 | `reports/q28-dsi-recover-20261012.md:395-400`（§16.2） |
| 3 | 「DSI ctrl+PHY 复位」能救回 | `vk117` 寄存器证明确实复位（`CTRL 0x175→0x171`、`CLK_STATUS 0x3743→0x1743`），第 2/3 次逐字 `-110` | 同上 `:151-176`（§10.1）、`:392` |
| 4 | 「自定义 bonded 触发序列」是罪魁 | `vk121` 换标准广播路径：签名换成标准 `-110`，**DYN 卡死态照旧** | 同上 `:296-313`（§14）；`versions/vk-registry.tsv` vk121 行 |
| 5 | 「使能期 dynamic force-on 保护」是解 | `vk122` 第 4 发同签名坏发（`op=0xff`/`STATUS0=0x20003`/`CLK_STATUS=0x1743`/`-110`×3） | 同上 `:354-384`（§15.5） |
| 6 | 「静态 DYN force-on 保持」绕开握手 | `vk123` 首样本 force-on 掩码确实保持（`CLK_CTRL=0x200b3f`），DYN 位仍闩；累计 1 GOOD/1 L1FAIL = 与基线 ~50% 不可区分 | 同上 `:427-447`（§18/§19） |
| 7 | 「复位终态对齐（`CLK_CTRL=0`）」是解（T3 / vk125） | 终态**确实到达**（`CLK_STATUS 0x3743→0x1403`），`link_power_on` 后立刻回 `0x1743`，3 次序列逐字相同 | 同上 `:448-464`（§20）；`PITFALLS/sessions/28-…md:80`（#230） |
| 8 | 上游 byte-clk 取整 `2028280686f4` 能修 STORM | `vk96`（未钉 UTS）NOCARD 3/3 而 `vk105`（PINUTS）GOOD ⇒ 判决被身份混淆；当晚多臂同率坏发 | `PITFALLS/sessions/28-…md:32`（#223）；`reports/q28-DOSSIER.md:399-402`（§p 1） |
| 9 | 「构建身份（2 位 `#60` → 3 位 `#N`）是治法」 | `#195` 定案后**同日推翻**：`vk113-dailyid`（3 位）4 发中 1 L1FAIL，同会话 `vk94`（#60）也 L1FAIL；残余坏发点估 4.3%、95% 上界 21.9% | `PITFALLS/sessions/27-…md:123`（#217）；`reports/q28-identity-retest-20261012.md:11-18` |
| 10 | 「STORM 也是构建身份伪影」 | 见上 + `#223`（多臂同率、按时间成簇） | `reports/q28-DOSSIER.md:404-424`（§q 的「已作废」更正） |
| 11 | §k「Q28 按内核二进制确定性（同一二进制恒定复现）」 | ① 21 发台账只有 7 发有原始日志；② 5 MB 差异 = `.rodata` 平移 4 字节（94.72% `b[i]==a[i-4]`）；③ 同一 `boot-q28-oct8.img` 同晚同路径 5 发 = GOOD/STORM/STORM/GOOD/STORM | `reports/q28-DOSSIER.md:226-233,276-282`；`PITFALLS/sessions/22-…md:51`（#171） |
| 12 | 「冷/暖复位是主变量」 | Q32 五发表：W1×2/C1×2/W2×1 全 GOOD 无差异；`#166` 被 4/4 反例限定为「vk86 线现象」 | `reports/q32-matrix-20261024.md:9-30`；`reports/q28-DOSSIER.md:44-50`（§b B1 收窄） |
| 13 | 「`-5` = DSI host 硬件楔死 / 只能整机复位（硬件不可救）」 | 机理改写为软件闩锁；清闩锁后重试**首次到达硬件**并报新签名 `stale link configuration`/`-116` | `PITFALLS/sessions/61-…md:1`；`reports/q28-DOSSIER.md:451-476`（§s-1）、`:512`（§s-5） |
| 14 | 「故障态不在 DSI 控制器内部」 | **削弱**：`STATUS0=0x175`（ENGINE/MDP/DSI busy 自锁）就在控制器内；`CTRL.ENABLE=0` | `reports/q28-DOSSIER.md:488-505`（§s-3） |
| 15 | 「判别量 = DYN pclk 域闩住不释放」（普适） | **本发不成立**：`CLK_STATUS=0x23f` 无 DYN 位、PLL 未失锁 | 同上 `:495-505` |
| 16 | 「`DSI PLL lock failed` 导致 STORM」 | 2×2 解离：only0154 **5/5 GOOD 且 `lockfail=4`×5**；only0155 `lockfail=0` 但 **3/4 STORM** | `reports/q28-disp-init-ab-20261022.md:73-110`；`PITFALLS/sessions/37-…md:27`（#277） |
| 17 | 「`to_primary_dsi` DSI0/DSI1 是杠杆」 | 两树属不同 MSM 实现，本硬件上是 no-op | `PITFALLS/sessions/26-…md:3`（#196）；`PROGRESS.md:25` |
| 18 | 「运行期重绑 DSI host/panel 可救回」 | `card0` 消失、fb 切 dummy、GPU `hangcheck … offending task: phoc` ⇒ 显示未恢复 | `PITFALLS/sessions/28-…md:39`（#224） |
| 19 | 「`pm_genpd`/GDSC 状态可判 Q28」 | 只读判别已否证（`HW_CTRL_SKIP_DIS` 候选） | `PITFALLS/sessions/37-…md:31`（#278） |
| 20 | 「解开关闭守卫 ⇒ 会重试」 | 守卫后面本来没有重试循环；必须区分「解除守卫」与「提供重试者」 | `PITFALLS/sessions/37-…md:38`（#279） |
| 21 | 「上游 DSICLK_SEL / peer pclk 挂错」是缺口 | 我们 `dsi_phy_7nm.c:851-865` 与 OEM 一致（`DSICLK_SEL(0)`）；OEM `dsi_clk_update_parent()` 本就把第二路挂第一路 PLL，好启动实测一致 | `reports/q28-dpu-intf-next-20261023.md:16-22`（§0.2/§0.3） |
| 22 | 「kexec 能拿到显示 / 0154 对 kexec 有效」 | 带磁盘根时死于 Q28 同源 bonded DSI 初始化；`0154` 对 kexec 机制性无效 | `TASKS/README.md:133`；`reports/kexec-target-boots-20261024.md` §9（`PROGRESS.md:58` 引） |
| 23 | 「`reboot2` 无参 = 普通重启」（设备实况） | 部署件是 2026-09-28 旧构建，无参 = 进 fastboot；已加能力自检 + sysrq-b 兜底 | `PITFALLS/sessions/28-…md:74`（#229）；`packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh:101-107` |
| 24 | 「§p：剩余唯一未解 = STORM（独立随机）」 | 被 §q 更正为构建身份伪影；§q 又被 `#217/#223` 作废 ⇒ 现口径「~50%、逐启动随机、按时间成簇、与镜像无关」 | `reports/q28-DOSSIER.md:392-424`；`TASKS/README.md:390` |

---

## ⑤ 未解决缺口

1. **根因未定，且结项是运营判断**：结项判据 ≠ 根因解释；`0/5` 坏发 ⇒ 95% 单侧上界仍 ≈45%；原定「≥8 发 POR」门槛按用户裁决不再补
   —— `reports/q28-workaround-closeout-20261024.md:9-10,25-26`、`TASKS/README.md:390`。
2. **复启条件①事实上已被触碰，但流程没走**：`2026-11-16` a 槽 UEFI/GRUB 冷起出现一发真 Q28 坏发（屏白→仅背光、msm 未 bind），
   结项文件写死的复启条件是「日常线再出现坏发（任意一次，**需现场取证**）」——`reports/q28-workaround-closeout-20261024.md:39`；
   但：
   - 未见该发的 dmesg / trial record：`ls reports/trials/ | rg '2026111[56]'` = **空**（本轮实测）。
   - 现有证据只有屏照 + journal + 看门狗日志：`reports/artifacts/uefi-daily-v8-20261116/` 的 `40-loop-boot-journal.txt`、`42-q28-watchdog-log.txt`；
     README 自陈「本轮起晚了，loop 的现场只留在屏照 + journal 里」。
   - 状态词仍是「已规避·结项」，且 `INDEX.md:50` 仍写「Q28/Q32 =「已规避」（运营线 8/8 无坏发）」——**8/8 是 2026-10-24 的旧数字**。
   - 「日常线」是否涵盖 a 槽 UEFI/GRUB 路径：**未找到**书面定义（`TASKS/README.md:390` 只说「在机镜像口径只在 `DEVICE/README.md` §1.1」）。
3. **hung 型（仅背光 + 无 SSH）没有内核/引导级兜底**：设备侧看门狗是用户态脚本，本形态它根本不会运行；`#228` 的
   「~50%→~75%」只对 userspace 存活型成立 —— `PITFALLS/sessions/28-…md:90`（#231 更正）。
4. **看门狗的残余误判风险仍开**：现语义 `bad = (无会话 OR 无 cardN) AND (无 cardN OR 命中签名)`，即
   **「有会话但 75 s 内没 cardN 且 dmesg 无签名」⇒ 判定坏发并重启** —— `q28-boot-watchdog.sh:8,88-98`；
   2026-11-16 的两次误判就是这条（`sess=yes card=no sig=no`）：`reports/artifacts/uefi-daily-v8-20261116/42-q28-watchdog-log.txt`
   （`14:48:22`、`14:56:10`、`14:58:44` 三行）。card1 修法只覆盖「msm 拿到 card1」，不覆盖「card 迟迟不注册」。
5. **看门狗文档/件三处不一致**：
   - unit 描述仍写 `never fired on the operational line`（`packaging/elden-userland/out/units/systemd/q28-boot-watchdog.service:4`），
     但日志里 2026-11-10、2026-11-16 都有 `Q28 bad boot detected` 行（同上日志）。
   - `packaging/.../q28-watchdog.sh:10` 的 `status` **仍只查 `/sys/class/drm/card0`**，与已修的 `q28-boot-watchdog.sh` 口径不一致
     ⇒ 在 UEFI/GRUB 路径上 `status` 会报 `card0=no`。
   - 设备实况 vs 仓库源：`reports/artifacts/uefi-daily-v8-20261116/41-q28-wd-unit.txt` 里部署件仍是 `[ -e /sys/class/drm/card0 ]`，
     仓库源已是 `drm_cards()`（`q28-boot-watchdog.sh:41-50`）⇒ 归档时必须按「已部署 sha `d694c147…`」核对（`PITFALLS/sessions/303-…md:24`）。
6. **脚本缺陷（可修，未修）**：`packaging/elden-userland/files/usr/local/bin/q28-race-hunt.sh:178,182` ——
   `DMBASE_VB=$vb_now` 在计算 `NEW_SINCE_ARM=$((vb_now - DMBASE_VB))` **之前**被覆盖 ⇒ 该汇总值恒为 0；
   且 `vb_now` 在 `CYCLES=0` 时未定义。该脚本是「密集复现 + ftrace 取证」的唯一在库工具。
7. **样本独立性问题未解**：坏发按时间成簇（会话级）⇒ 单会话内样本不独立，A/B 必须同会话交替配对，不能跨会话比较比例
   —— `PITFALLS/sessions/28-…md:32`（#223）；`reports/Q24-Q28-INDEX.md` §4。
8. **判据标签冲突**（§3.4）：`NOROUTE` 两套语义并存于在库脚本（`scripts/q28-devprobe.sh:25` vs `#231`）。
9. **文档层缺口**：
   - `reports/q28-INDEX.md` 里 `TASKS.md`、`INDEX.md §3` 的引用已过期（`TASKS.md` 已不存在，实测 `ls TASKS.md` = No such file）。
   - 同文件章节编号跳过 §6（`## 5.` 之后直接 `## 7.`）。
   - `reports/q28-DOSSIER.md` 有两个 `## g)`（`:167` 与 `:178`）。
   - DOSSIER 内部保留已被自身顶部横幅降级的 §k/§l 原文（作为「零删改证据仓」可接受，但**不可当现行结论引用**）。
10. **7.3 线 fastrpc 刷屏**（曾混入 Q28 样本判读）根因已修（模块树 ABI 不匹配，`#367`），但该「脚本/配置漂移」类污染源
    仍可能再次伪造 Q28 结论 —— `TASKS/sessions/2026-11-03-TASKS行445-Q28.md:24`；`DEVICE/sessions/…:128`。
11. **未找到**：
    - `PITFALLS` 里 `#228` 的**索引行**（`PITFALLS/README.md` 中无 `**#228**` 条目，正文只在 `sessions/28-上游邮件通道.md:66`）。
    - `reports/` 下 Q28 的**独立 NOCARD 日志目录**（DOSSIER 自陈：`## g) 旧报告里…` §3「仓库 `logs/` 下 `grep VERDICT=NOCARD` 无命中」）。
    - 2026-11-16 那发真坏发的 dmesg/trial/串口现场（见缺口 2）。

---

## ⑥ 下一步实验（可执行命令 + 判据）

> 全部为**只读或零写盘**；涉及设备的项需用户在现场决定是否执行。纪律：任何可能留下坏发台架的实验前先
> `/usr/local/sbin/q28-watchdog.sh off`（`q28-boot-watchdog.sh:19-20`、`PITFALLS/sessions/28-…md:66` 末段）。

**E1（只读，最高优先）— 把 2026-11-16 那发真坏发补成「有现场」，判它是否触发复启条件①**
```sh
ssh elden-root 'cat /var/log/q28-watchdog.log'                       # 期望：能看到 14:48/14:56/14:58 三行（已在 reports/artifacts 留档）
ssh elden-root 'ls -la /var/log/q28-bootlog* /var/lib/systemd/pstore 2>/dev/null; journalctl -b -1 -o short-monotonic | grep -nE "command DMA timeout|Failed to initialize panel|vblank wait timed out|Unpacking initramfs|Freeing initrd"'
ls reports/trials/ | rg '2026111[56]'                                 # 判据：现在为空 ⇒ 该发无 trial record，需手工补档
```
判据：若 `journalctl -b -1` 能取到该发的 Q28 签名 ⇒ 按 `reports/q28-workaround-closeout-20261024.md:39` 的复启条件①**启动取证流程**；
若取不到（已轮转/未持久化）⇒ 结论只能是「触发条件成立但证据不可补」，并把「坏发必须留 dmesg」写进实验纪律。

**E2（只读，判归档口径）— 核对「日常线」定义是否覆盖 a 槽 UEFI 路径**
```sh
rg -n '日常线|在机镜像口径|boot_b 口径' TASKS/README.md DEVICE/README.md INDEX.md | head -30
```
判据：找到唯一权威句（当前 `TASKS/README.md:390` 只指向 `DEVICE/README.md` §1.1）⇒ 若定义为「b 槽 boot_b」，
则 2026-11-16 那发属「非日常线」，复启条件①**未**触发，但需在 closeout §4 显式写明「a 槽 UEFI 路径不计入」；
若定义含任意启动路径 ⇒ 复启条件已触发。

**E3（只读）— 复核看门狗残余误判面**
```sh
# 在设备上（不动系统，仅 DRYRUN；需要先确认当前 card 命名）
ls /sys/class/drm/ | grep -x 'card[0-9]*'
Q28_WD_SELFTEST=nocard Q28_WD_DRYRUN=1 Q28_WD_WAIT=1 /usr/local/sbin/q28-boot-watchdog.sh; echo rc=$?
grep -n 'selftest' /var/log/q28-watchdog.log | tail -3
```
判据：`Q28_WD_SELFTEST=nocard` + `sess=yes` 时是否仍判 bad（按 `:88-98` 逻辑应当判 bad）⇒ 若是，记为「已知残余误判面」，
并把「有会话但无 card 且无签名」改判为 NOT rebooting（或加第二道 30 s 复判）。

**E4（仓库内，纯静态）— 修/登记两处脚本不一致（改代码需另行批准，本轮未做）**
```sh
sed -n '8,13p;41,50p' packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh   # 已修版（cardN）
sed -n '5,12p'        packaging/elden-userland/files/usr/local/sbin/q28-watchdog.sh        # status 仍 card0-only
sed -n '170,185p'     packaging/elden-userland/files/usr/local/bin/q28-race-hunt.sh        # NEW_SINCE_ARM 恒 0
```
判据：`q28-watchdog.sh status` 输出含 `cards=[…]` 且与 `q28-boot-watchdog.sh` 同口径；`q28-race-hunt.sh` 汇总行
`NEW_SINCE_ARM` 与实际新增 `vblank timeout` 行数一致（当前恒 0，见 `:178,182`）。

**E5（复现台，需用户配合 POR）— 若复启成立，按现役判据重采样**
```sh
# 真 POR 硬判据：本发必须 psci: SYSTEM_RESET2 计数 = 0（reports/q28-por-samples-r1r2-20261023.md:49-54）
scripts/q28-por-rounds.sh 1 2400 1        # r1（每发自动落 clkdiag + devprobe + trial json）
ssh elden-root 'dmesg | grep -c "psci: SYSTEM_RESET2"; scripts/q28-devprobe2.sh; scripts/q28-clkdiag.sh'
```
判据（照 `reports/q28-por-samples-r1r2-20261023.md:11-20` 与 `reports/q28-dpu-intf-next-20261023.md` §2）：
`VERDICT=GOOD` + `storm_sig=0` + `pclk0=pclk1=172972734 @ dsi0_phy_pll_out_dsiclk` +
`byte0=byte1=108107958 @ dsi0_phy_pll_out_byteclk` + `failed to acquire/prime mdss resets = 0`；
坏发才是信息（结项文件 §3：`reports/q28-workaround-closeout-20261024.md:30-31`），GOOD 样本已无信息量。

**E6（可选，坏发线上才有收益）— DOSSIER §s-4 的两个最小实验**
判据原文：置 `link_configured=1` 后是否越过 `-ESTALE`；再打等价 `dsi_sw_reset_v2_9` 后 `STATUS0 & 0x19` 是否清零
—— `reports/q28-DOSSIER.md:506-511`。**前提**：必须先有坏发台架（当前无，`reports/q28-workaround-closeout-20261024.md:32-34` 明确不做）。

---

## ⑦ 引用清单

### 7.1 状态/结论 SSOT
- `reports/q28-DOSSIER.md`（机理卷；`:28` a、`:41` b B1–B6、`:111` d 两模式、`:196` h、`:213` j、`:226` k、`:276` l、`:301` m、`:331` n、`:360` o、`:392` p、`:404` q、`:426` r、`:451` s）
- `reports/q28-workaround-closeout-20261024.md`（结项；`:9-10` 判据、`:14-18` 规避栈、`:22-26` 样本与统计限定、`:28-35` 做/不做、`:37-41` 复启条件、`:43-50` 外部确认）
- `TASKS/README.md`（`:15` G1 阻塞项速览、`:133` kexec、`:189` T19、`:203` 收尾轮次纪律、`:380` §5 压缩说明、`:390` **Q28 行**、`:402` Q32 行、`:431-432` §5 表行）
- `TASKS/sessions/2026-11-03-TASKS行445-Q28.md`（Q28 行逐字下沉：`:20,24,28,32`）
- `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md:29`（第二轮压缩后的当前口径）
- `DEVICE/README.md`（`:56` 2026-11-16 真坏发 + card1、`:186` vk127 7坏/8好、`:189` 2026-10-10 离线快照、`:190` 串口 logger 局限、`:217` 「在树但需调：面板 init 竞态」）
- `INDEX.md:50`（「已结项勿重推」+ 8/8 旧数字）、`INDEX.md:67`（2026-11-16 两条异常）
- `PROGRESS.md:16,17,19,24,25,33,34,35,37,38,39,40,41,45,46,49,51,52,58`

### 7.2 PITFALLS 条目（正文在 `PITFALLS/sessions/`）
| 条目 | 位置 | 一句话 |
|---|---|---|
| #162 | `PITFALLS/sessions/22-构建守卫&Q28变量纠正.md:3` | `make olddefconfig` 删 `ARCH_QCOM` ⇒ 死内核（vk81/82/83 作废） |
| #163 | 同文件 `:11` | 真变量是冷/暖复位（后被收窄） |
| #164 | 同文件 `:13` | 根因 = 首条 DCS 命令 DMA hang，L2 是 L1 下游 |
| #165 | 同文件 `:20` | 两模式 NOCARD/STORM；无风暴 ≠ 显示好 |
| #166 | 同文件 `:27` | `reboot2` 暖复位粘 NOCARD ⇒ 每样本必须真 POR |
| #167 | 同文件 `:31` | `q28-boot-cycle.sh` 不查 card0，误报 GOOD |
| #168 | 同文件 `:34` | 仅 `/init` 差一个模块加载器 ⇒ 一次 STORM 一次 NOCARD |
| #169 | 同文件 `:36` | 验证链撒谎（流程体检） |
| #170 | 同文件 `:41` | 软件 POR 可行但不可无人值守 |
| #171 | 同文件 `:51` | 「按内核二进制确定性」（已被 §l 证伪） |
| #172 | 同文件 `:53` | 判 GOOD 必须加存活门 |
| #174/#175 | `PITFALLS/sessions/23-Q24复现定案+Q28「版本串」变量+测试协议陷阱.md:9,15` | RPMh 票反查；`LOCALVERSION` 翻转 GOOD/NOCARD |
| #192 | `PITFALLS/sessions/25-Q28冷起判定=内核构建身份法则+冷起AB测补丁作废.md:3` | 构建身份法则（12 发实证）+ PINUTS |
| #195 | 同文件 `:19` | STORM 也是身份伪影（后被 #217 推翻） |
| #196 | `PITFALLS/sessions/26-…md:3` | `to_primary_dsi` DSI0/DSI1 伪线索 |
| #215 | `PITFALLS/sessions/27-Q24台架工具链教训.md:110` | 主动 `reboot` 会把设备留在 STORM 态 |
| #216 | 同文件 `:115` | 一份载荷可能有两份 `UTS_VERSION` |
| #217 | 同文件 `:123` | 更正 #195：3 位身份是偏置不是解 |
| #223 | `PITFALLS/sessions/28-上游邮件通道.md:32` | byte-clk 取整不修 STORM；臂不是主导变量（成簇） |
| #224 | 同文件 `:39` | 重绑 DSI host/panel 拆 DRM |
| #225 | 同文件 `:45` | 未就绪 `reboot2` ⇒ 无 USB 通道 |
| #226 | 同文件 `:51` | 七臂全否证；判别量 = DYN pclk；故障态不在控制器内 |
| #227 | 同文件 `:57` | 原厂 display 静态对照；唯一新差异 = 复位终态 |
| **#228** | 同文件 **`:66`** | **运营兜底看门狗上机（75 s 自动正常重启，~50%→~75%，不改根因）** |
| #229 | 同文件 `:74` | `reboot2` 旧构建「无参 = 进 fastboot」 |
| #230 | 同文件 `:80` | T3 复位终态对齐无效（寄存器级） |
| #231 | 同文件 `:87`（更正 #228 见 `:90`） | 第三形态「仅背光 + 无 SSH」；看门狗救不了 |
| #251–#256 | `PITFALLS/sessions/32-上游显示栈bring-up：DRMGOOD≠面板有画面.md:3,8,13,19,26,33` | 目视判据、上游缺口、DRM cleanup 挂死、SSH 洪泛、M1 回归、bonded revert |
| #274–#279 | `PITFALLS/sessions/37-Q28-armA：命令路径否证与「面板黑」是不变量.md:6,13,21,27,31,38` | 面板黑是不变量、目视判据、两亚型、PLL fail 伪影、genpd 不可判、解守卫≠重试 |
| #366 | `PITFALLS/sessions/61-Q28单向闩锁把硬件故障伪装成不可恢复.md:1` | 单向闩锁 + 第二闩锁 `link_configured` |
| #372 | `PITFALLS/README.md:98`（正文 `sessions/67-背光4伪装黑屏与容器相机bind从未持久化.md`） | 背光 4% 伪装黑屏（非 Q28） |
| #531 | `PITFALLS/README.md:238` | EB 之后面板被退出流程熄掉 |
| #574 | `PITFALLS/README.md:271` | **会话序号 228** 对应的坑（勿与 `#228` 混） |
| #625 | `PITFALLS/README.md:323` | `.o` 静默损坏 + `CONFIG_SUSPEND` ABI 失配（「亮背光即掉电」） |
| #655 | `PITFALLS/README.md:335` | 空闲时 msm vblank IRQ 为 0（不可用 interrupts 判显示） |
| #667 | `PITFALLS/sessions/303-q28看门狗只认card0-UEFI路径card1误判.md:1`（索引 `README.md:346`） | 看门狗只认 card0 ⇒ UEFI 路径误判两次 |

### 7.3 Q28 相关报告（`reports/`）
- **已逐段精读并在上文引用**：`q28-DOSSIER.md`、`q28-INDEX.md`、`Q24-Q28-INDEX.md`、`q28-workaround-closeout-20261024.md`、
  `q28-disp-init-ab-20261022.md`、`q28-por-samples-r1r2-20261023.md`、`q28-v2-mdss-reset-20261023.md`（`§0`/`§2`）、
  `q28-dsi-recover-20261012.md`（`§1-5`、`§10-20`）、`q28-dispcc-static-20261012.md`（`§0-3`）、`q28-watchdog-20261012.md`（`§0-2`）、
  `q28-identity-retest-20261012.md`（`§0-1`）、`q28-dpu-intf-next-20261023.md`（`§0-2`）、
  `determinism-gap-and-q28-plan-20261023.md`（全文 89 行）、`q32-matrix-20261024.md`（`§0-3`）、
  `closeout-q29-backlight-camera-20261023.md`（`§0`，用于排除「背光下限」与 Q28 混读）。
- **仅按 `reports/q28-INDEX.md` 的定位入档（本轮未逐条读正文，引用只到该索引行）**：
  `q28-handoff-20261010.md`、`q28-two-layers-20261010.md`、`q28-upstream-diff-20261010.md`、`q28-upstream-research-20261010.md`、
  `q28-orchestration-20261010.md`、`q28-binary-determinism-20261010.md`、`q28-binary-determinism-provenance-20261010.md`、
  `q28-layout-ab-20261010.md`、`q28-nocard-research-20261010.md`、`q28-handoff-20261012.md`、`q28-storm-bias-audit-20261011.md`、
  `q28-retro-audit-20261011.md`、`q28-community-cases-20261012.md`、`q28-upstream-static-20261012.md`、`q28-INDEX.md:46-63`（§5）。
- **其它在库但本轮未定位其 Q28 关系的报告**（列名，避免遗漏）：`q28-armA-20261015.md`、`q28-b1-firstsample-20261015.md`、
  `q28-badboot-m1-baseline-20261015.md`、`q28-vk113-20261012.md`、`q28-watchdog-20261012.md` 以外的 `q28-dpu-intf-next` 邻件、
  `b5-dsi-resoc-20261013.md`、`p1-upstream-dsi-20261013.md`、`upstream-q24-q28-standard-20261015.md`、
  `q24-q28-narrative-archive-20261019.md`、`local-cleanup-q24-q28-20261015.md`、`device-rescue-and-q28-m1-badboot-20261017.md`、
  `m6-dsi-errmask0-20261031.md`、`mdss-int2-evidence-20261113.md`、`mail-send-20261102-mdss.md`、`mail-send-20261114-mdss-v5.md`、
  `e3-wcn-dyndbg-20261014.md`、`q32-warm-vs-cold-preresearch-20261023.md`。
  （检索命令：`ls reports/ | rg -i 'q28|panel|dsi|dyn|^il-|dsc|vblank|edp|mdss|backlight'`）

### 7.4 代码/工具（判据实现）
- `packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh`（`:2-20` 头部口径与实验纪律、`:41-50` `drm_cards()`、`:51-54` 签名、`:62-71` good-reset 先于 disable、`:73-98` 判定、`:101-107` reboot2 能力自检 + sysrq-b）
- `packaging/elden-userland/files/usr/local/sbin/q28-watchdog.sh`（`:6-7` on/off、`:10` **仍只查 card0**、`:12` usage）
- `packaging/elden-userland/files/usr/local/bin/q28-race-hunt.sh`（`:2-20` 近因假设与纪律、`:27-31` 连接/ftrace filter、`:47-73` `setpriv` 会话总线、`:106-126` 快照、`:130-142` 路径自检、`:178-186` **汇总缺陷**）
- `packaging/elden-userland/out/units/systemd/q28-boot-watchdog.service`、`out/units/openrc/q28-boot-watchdog`（`:4`/`description=` 仍写 never fired）
- `scripts/q28-devprobe.sh:3-6,10,17-25`、`scripts/q28-devprobe2.sh:17,52`、`scripts/q28-clkdiag.sh`、`scripts/q28-por-rounds.sh`、`scripts/q28-watchdog.sh`、`scripts/q28-coldboot-collect.sh`、`scripts/q28-reboot-until-good.sh`、`scripts/q32-arm.sh`、`scripts/q32-boot-evidence.sh`
- 已退役（归档留证）：`archive/2026-10-15-retired-scripts/q28-{cold-run,cold-sample-loop,boot-cycle,layout-one,layout-ab,layout-experiment,build-arm-lv64,build-oldrep-pin,verdict,race-hunt,warm-vk117-loop}.sh`、`README.md`（退役理由）

### 7.5 版本账（臂 → 结论）
- `versions/vk-registry.tsv`：`vk73`/`vk74`/`vk75`（诊断）、`vk93`（三变体）、`vk96`–`vk101`（身份法则臂）、`vk104`–`vk111`（PINUTS/STORM 判定臂）、`vk113`/`vk114`（3 位身份日常重建）、`vk116`–`vk123`（七臂+保持臂）、`vk124`（上游回移）、`vk125`（复位终态）、`vk137`–`vk145`（0154/0155 2×2 与日常候选）、`vk150`/`vk151`（v2 / 日常候选）。
- `versions/vk-kernel-identity.tsv`、`versions/vk-ledger-known-issues.tsv`（`uts_dup`/`num_ne_tag` 的刻意例外，与 Q28 单变量构建直接相关）。
- `reports/trials/`（逐发 trial record；`q28-*` 前缀）；`reports/artifacts/q28-clkdiag-*.txt`、`reports/artifacts/uefi-daily-v8-20261116/`（`40/41/42` + 屏照）。

---

**档案边界声明**：本卷只回答「项目内部史料说了什么、彼此怎么矛盾」。
Q28 的**寄存器级机理全文**在 `reports/q28-dsi-recover-20261012.md` 与 `reports/q28-DOSSIER.md` §s；
**上游化/投递面**（M6/M8 系列、评审往来）在 `TASKS/README.md` §7 与 `patches/upstream/q28-dispcc-2026-10-22/`，本卷不展开。
