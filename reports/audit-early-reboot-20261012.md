# 审计报告：历史脚本「过早复位 / 进 fastboot」模式（early-reboot）

- 日期：2026-10-12　·　审计人：静态代码审计（**未在设备上确认，仅静态判定**；按纪律未执行任何设备操作：未 fastboot/ssh 192.168.7.1、未取 device-lock）
- 范围：`scripts/*.sh`（含嵌套子目录）、`archive/` 下脚本（只读）、`.pi/skills/**/references/*.md` 命令片段
- 交付物：本报告 + `patches/draft-early-reboot-guard.patch`（新增 `scripts/lib-boot-ready.sh` 就绪门 + 给 3 个 q28 驱动接入；已 `git apply --check` 通过）

---

## 0. 结论先行

1. **模式成立（静态）。** 本仓「进 fastboot」的正规通路是 `reboot2 bootloader`（= `reboot(LINUX_REBOOT_CMD_RESTART2, "bootloader")`，`rootfs/reboot2.c`）/ `eldroid-bootctl reboot bootloader`（同为 PSCI SYSTEM_RESET2）。调用这些命令的脚本，**绝大多数只把「SSH 能 echo up」当作就绪门**，没有 uptime / 桌面（phoc/phosh）/ DRM bring-up 就绪 / 风暴检查。设备侧 SSH 在 **uptime≈6.7 s 即可用、比桌面早得多**（PITFALLS #67，`PITFALLS.md:697-701`），因此这些脚本**完全可能在上电 <60 s 内发出复位**。

2. **最危险的是「温复位循环」家族**——`scripts/q28-boot-cycle.sh:37`、`scripts/q28-layout-ab.sh:22`、`scripts/q28-layout-one.sh:23`。它们被外层循环（`q28-ab-delay.sh:18-20` 的 `for … timeout … q28-boot-cycle.sh` / `q28-layout-ab.sh` 的 `for tag in $SEQ`）反复调用：每轮 `fastboot boot` 后**一等到 SSH 通就进下一轮 `reboot2 bootloader`**，此刻设备 uptime 常在 ~20–45 s，正是本会话复现故障的窗口。静态上与本会话「uptime≈20 s 发 `reboot2 bootloader` → 全 USB 通道丢失」的时间线**吻合**。

3. **本会话观察未能在设备上独立复现/否证**（纪律禁止操作设备）；且**同一现象在仓库里有竞争机理**（#143 记录为「从 RAM 诊断内核发起」，#151 给出「VBUS 未把它叫醒 ⇒ 看似死机」的另一种解释），因此**不把任何历史挂机事件『归因』为过早复位**——只做「时间线/症状是否吻合」的分级判定，见 §3。

4. **拟议加固已给出可落地草案**：新增 `scripts/lib-boot-ready.sh`（就绪门：SSH 复核 + `uptime>=90` + `phoc|phosh` 已在跑，可选风暴拒绝；`fail-closed`，带 `ELDEN_FORCE_REBOOT=1` 逃生阀），先接入三个 q28 驱动的 `reboot2` 之前。其余单发命令（`to-fastboot.sh` / `sd-run-variant.sh` / `slot-switch.sh` 等）列为**待接入**（§4 表已标）。

---

## 1. 命中清单表（可执行触发点，已滤除纯注释 / echo / usage 行）

> 判据列 = 触发前对设备状态的**唯一**校验；`<60s` = 是否可能在上电 60 s 内触发（静态）。
> 就绪门 = 是否有 uptime / 桌面 / SSH 存活复核 / 风暴 任一有效校验。

| # | 脚本:行号 | 命令 | 触发条件 / 就绪门 | 等待 | `<60s` | 风险 |
|---|---|---|---|---|:--:|:--:|
| 1 | `scripts/q28-boot-cycle.sh:37` | `(sleep 2; reboot2 bootloader)&` | 前仅有 `trial.sh gate`（=SSH 可达 + boot_b 槽属性 succ/retry/unbootable，见 `scripts/trial.sh` `device_gate()`）；**无 uptime / 无桌面 / 无 SSH 现问现答** | fire 前 `sleep 2` | **是**（被 `q28-ab-delay.sh:18-20` 循环调，SSH 一通即下一轮）| **高** |
| 2 | `scripts/q28-layout-ab.sh:22` | `(sleep 2; reboot2 bootloader)&` | `for tag in $SEQ` 每轮开头 fire；上轮仅等 `S 'echo up'`（SSH 通）；**无就绪门** | `sleep 2` | **是**（循环，uptime≈20–45 s 即再发）| **高** |
| 3 | `scripts/q28-layout-one.sh:23` | `(sleep 2; reboot2 bootloader)&` | 仅当 `[ "$(S 'echo up')" = up ]`（SSH 通）才发；**无 uptime/桌面门** | `sleep 2` | **是**（单发，门弱）| 中高 |
| 4 | `scripts/sd-run-variant.sh:35` | `eldroid-bootctl reboot bootloader` | 仅 `if timeout 12 $SSH 'true'`（SSH 通）才发；**脚本内的 phosh 等待（:68-70）在复位之后**，不覆盖这次复位 | 无 | **是** | 中高 |
| 5 | `scripts/to-fastboot.sh:41` | `eldroid-bootctl reboot bootloader` | device-lock + `$SSH` connect 成功即发；**无就绪门** | 无 | 是（人工节奏通常>60 s，但无强制）| 中 |
| 6 | `scripts/slot-switch.sh:57` | `eldroid-bootctl reboot bootloader` | `have_linux()`（SSH `true`）成立才走；单发切槽；无 uptime/桌面门 | 无 | 是（单发）| 中 |
| 7 | `scripts/kexec-bs-cycle.sh:14` | `eldroid-bootctl reboot bootloader` 后 `echo b > /proc/sysrq-trigger`（:15） | 仅 SSH 可达即发；**SysRq-b 立即硬复位，无就绪门** | 无 / `sleep 2` | 是 | 中 |
| 8 | `cycle.sh:19`（`--soft`） | `(sleep 1; reboot -f)&` | SSH 通即发；**无就绪门**。注：#65 记录 b 槽直启后 `reboot -f` 已回 Linux 非 fastboot | `sleep 1` | 是（单发）| 中 |
| 9 | `cycle.sh:24-26`（`--fastboot`） | 写 misc BCB + `(sleep 1; reboot -f)&` | SSH 通即发；misc BCB 实测 ABL 不采纳（PITFALLS #65/FLASHCTL）| `sleep 1` | 是（单发）| 中 |
| 10 | `scripts/q24-pmic-cycle.sh:10` | `sync; (reboot -f \|\| busybox reboot -f \|\| reboot)` | SSH 通即发（取重启后 PMIC 对照）；**普通重启**非进 fastboot；无就绪门 | 无 | 是 | 中 |
| 11 | `scripts/flash-b.sh:51` | `(sleep 1; reboot -f)&`（`--reboot`） | 前置是 scp+dd+sha 回读（实际耗时通常已>60 s）；仍**无显式就绪门** | `sleep 1` | 边界（实践通常>60 s）| 低中 |
| 12 | `scripts/flash-recovery.sh:55` | `eldroid-bootctl reboot recovery`（`--reboot`） | 前置 dd+回读；无就绪门 | 无 | 边界 | 低中 |
| 13 | `scripts/kexec-boot.sh:98` | `kexec -e` | SSH 通即发；**非 fastboot 复位但历史记硬挂+USB全消需长按**（`archive/topics/KEXEC-2026-10-05.md:23`；kexec 通道已判死 `archive/topics/MERGE-2026-10-05.md:19`）| 无 | 是 | 中（已判死路）|
| 14 | `scripts/sleep-sweep.sh:52` | `(sleep 1; reboot)&` | **已有就绪门**：`boot_ok()`=`S true` 且 `pidof phoc` 非空；`wait_booted()`（:41-52）要求 phoc 起来才继续 | 30×5 s | **否**（桌面已起才发）| 低（正例）|
| 15 | `scripts/sleep-sweep.sh:32` | `fastboot reboot`（host 侧） | 设备已在 fastboot 才发（`FB()` 命中序列号） | — | N/A（已在 fastboot）| 低 |
| 16 | `scripts/q28-ab-delay.sh:42` | `fastboot reboot`（host 侧收尾） | 设备在 fastboot（命中 `HA2EXB0E`）才发 | — | N/A | 低 |
| 17 | `cycle.sh:29`（`--recover`） | `fastboot reboot bootloader`（host 侧） | 人工恢复；无 SSH 侧过早问题 | — | N/A | 低 |
| 18 | `scripts/q26-recheck.sh:45` | **仅打印**建议 `setsid /usr/local/sbin/reboot2 bootloader`，**不执行** | 无 | — | 否（提示）| 无（信息）|

### 1a. 外层循环放大（把单发弱门变成「上电即复位」）
- `scripts/q28-ab-delay.sh:18-20` `for` 内 `timeout -k 15 300 bash scripts/q28-boot-cycle.sh` 每轮：`fastboot boot` → 等 SSH（`q28-boot-cycle.sh:49-51`，SSH 一通即 break）→ 取证（数秒）→ **返回** → 下一轮 `q28-boot-cycle.sh:37` 再 `reboot2 bootloader`。设备此刻 uptime 常 ~20–45 s ⇒ 循环期持续在危险窗内。
- `scripts/q28-layout-ab.sh`（`for tag in $SEQ`，:22）同构。

### 1b. skills references 片段（只读，人工执行，非自动化循环）
均为 Android/fastbootd 侧人工命令，**不构成 Linux 上电过早自复位**：
- `.pi/skills/qualcomm-edl-flashing/references/tb322fc-y700-gen4.md:144-145`（`adb reboot fastboot` / `fastboot reboot fastboot`）、`:130`（`-w` + `reboot`）
- `.../abl-passes-kernel-crash.md:89,160`（`fastboot reboot` 烧 retry 的告诫）、`gsi-android-side.md:32`、`lenovo-lun4-safe-reset.md:59`、`cn-flash-ksu-execution-20260810.md:20,23`（`adb reboot edl`）
- `grub-direct-boot-android.md:133`（`panic=10` 自动重启）、`session-20260807-tail.md:31`（`panic=10` 制造可观测复位节奏）
- 结论：references 无「SSH 一通就 reboot2 进 fastboot」的自动片段；风险面在 §1 主脚本，尤其 #1-#4。

### 1c. initramfs / 设备侧固定秒自重启（历史镜像，非常规路径）
- `archive/topics/复盘.md:14,65,120`：diag 镜像 `elden_diag_reboot=1` → init 到用户态 **40 s 自动 `reboot -f`**（用作「进了用户态」的自动信号，~67 s 回 fastboot）。这是**镜像内固定延时**，与主机脚本无关，但属「固定秒数复位」同族，列出备查。
- `scripts/build-boot.sh:69` 等 cmdline 带 `panic=15`（panic 15 s 自动复位）——仅 panic 路径，正常不触发。

---

## 2. 与历史「挂起 / hang / 无桌面 / SSH 不可达」事件的吻合判定

**判定纪律：不强行归因。** 同一「reboot2 后设备失联、只能长按」在仓内至少有三种记录，机理各异；过早复位（uptime<60 s、桌面未起）只是其中一种候选，无法据现有记录坐实或排除。

### A. 症状吻合、机理存疑（不能归因，也不排除）
- **A1　PITFALLS #143（`PITFALLS.md:1123-1127`，2026-10-09）**：原文「`reboot2 bootloader` … 偶发把设备打进『USB 完全消失』态：90 s 内既无 fastboot 设备、SSH 不通、`lsusb` 也没有任何 18d1/05c6、ping 不通 ⇒ 只能长按电源 20 s」。
  - 吻合：现象与本会话观察**逐字同型**（全 USB 通道消失、ping 不通、只能长按）。
  - **不吻合点**：原文记的是「**从 RAM 诊断内核发起**」，RAM 诊断内核本就无桌面；未记 uptime。且 #151（`PITFALLS.md:1169-1172`）给出**竞争解释**「那次只是 VBUS 没把它叫醒 ⇒ 看起来像死机」。
  - 判定：**症状高度吻合，机理未定**（过早 vs VBUS 未唤醒 vs RAM 内核特异）。
- **A2　本会话 2026-10-12 实测（uptime 20 s 失败 / 138 s 成功）**：**未在设备上独立确认**（纪律禁碰设备）。静态上：`q28-boot-cycle.sh` 等仅以 `S 'echo up'` 为门，而 SSH 在 uptime≈6.7 s 即可用（#67），故脚本可在 20 s 发出 `reboot2` —— **时间线自洽**；但「20 s 失败、138 s 成功」这一因果对照**未被任何仓内记录复现**。

### B. 表面相似、实为不同机理（判为不吻合过早复位）
- **B1　PITFALLS #166（`PITFALLS.md:1276-1278`）/ `reports/q28-layout-ab-20261010.md:32` / `reports/q28-DOSSIER.md:275`**：「`reboot2 bootloader` 在 **STORM 态**下无效（无 fastboot），只能物理断电」。
  - 不吻合：前提是**设备处于坏发/STORM 态**（暖复位粘态 #166），非「上电过早、桌面未起」。同为「reboot2→无 fastboot→物理断电」，但触发态是**坏发内核**，不是**未就绪好发内核**。
- **B2　PITFALLS #215（`PITFALLS.md:1666`，2026-10-12，q24-noc §5）**：`reboot -f` 取 PMIC 对照 → 冷起落 STORM、SSH 无 banner、约 11 分钟不可达。
  - 不吻合：这是**普通重启后冷起撞 Q28 STORM**（面板 init 失败态），非复位命令打早了；与 `q24-pmic-cycle.sh:10` 同源，但根因是 Q28 STORM 而非过早。
- **B3　PITFALLS #170（`PITFALLS.md:1293-1300`）**：`busybox poweroff -f` 密循环 → GUI 卡死、SSH/fastboot 全无、只能长按。
  - 部分吻合「软复位在坏态不可靠、只能物理断电」，但命令是 **poweroff** 且现场是 GOOD 后/ STORM 态，属「坏态软复位不可靠」主题（#150），非「上电 <60 s」。
- **B4　Q24 受控致死（PITFALLS #209，`PITFALLS.md:1615-1623`）**：SoC 级复位 + ~30 s **自恢复**、不需 POR。
  - 不吻合：这些挂机**自己回来了**（28–42 s 重枚举、新 boot_id），与「无任何 USB 通道需长按」相反；且触发是熄屏/唤醒致死，非复位命令。

### C. 判为与过早复位无关（列此以划界）
- **C1　PITFALLS #199（`PITFALLS.md:1559-1561`；`reports/q24-s123-20261012.md:87`）**：`fastboot` 客户端接 `head`/`grep -q` 或 `timeout` 掐断传输 → 卡死设备 fastboot gadget → 只能物理 POR。机理=SIGPIPE 半途中断 bulk 传输，与复位时机无关。
- **C2　Q28 冷起 NOCARD/STORM「只有背光无桌面」（PITFALLS #16/#172/#158 等；`reports/Q24-Q28-INDEX.md:13`）**：这是**冷起显示 bring-up 竞态**（DSI PLL 未锁 / cmd-DMA hang），历史上确被**误记为「无桌面/挂起」**（`PITFALLS.md:100`、`reports/q28-layout-ab-20261010.md:38` 明确「hang 与桌面无关」）。**非脚本过早复位所致**——但正是本任务所指「误记为无桌面」的一大来源，列此划清界限。
- **C3　`archive/topics/REBOOT-5MIN-2026-10-05.md`**：进桌面后约 5 min 硬重启（熄屏/DPMS 路径，Q24）。与「上电过早」方向相反（是**桌面已起很久之后**），不吻合。

> 小结：仓内**没有任何一条历史记录明确把某次挂机归因于『上电 <60 s 就发复位』`。** A1 与本会话症状同型但机理存疑；其余相似记录要么前提为 STORM/坏发（B1/B2），要么为 poweroff（B3），要么自恢复（B4），要么完全无关（C1-C3）。

---

## 3. 根因静态画像（为什么「SSH 可达」是错门）
- **正规进 fastboot 通路**：`rootfs/reboot2.c`（`reboot2 bootloader` 走 `LINUX_REBOOT_CMD_RESTART2`）与 `eldroid-bootctl reboot bootloader`（PSCI SYSTEM_RESET2，vk41 起通，见 `archive/topics/ITERATION-AUDIT-2026-10-04.md:134`）。二者都不经关机链，直接触发 SoC 复位并交 XBL。
- **就绪门与真就绪脱节**：`trial.sh device_gate()` 只验 SSH + boot_b 槽属性；`S 'echo up'` 只验 sshd。#67 实测 sshd 在 uptime≈6.7 s 起，远早于 phoc/phosh、更早于 DSI/DRM bring-up 稳定（#158：坏发点在 boot 早期；#165/#167：0.86 s PLL 未锁）。⇒ 脚本眼中的「设备活着」=「内核刚起、显示栈可能仍在竞态」，此时 `reboot2` 落在「面板/DSI bring-up 未收敛」的窗口，与 #143「全通道消失」症状窗重叠。
- **`sysrq b` 与 `kexec -e` 更硬**：#150 记 `reboot`/`reboot -f` 在坏发态会挂住，`echo b>sysrq-trigger` 与 `reboot2` 是能用的活路——但对**未就绪**设备而言，硬复位同样是「无就绪门的立即复位」。

---

## 4. 拟议加固

### 4.1 就绪门 `scripts/lib-boot-ready.sh`（草案已随补丁给出）
`boot_ready_or_die`（host 侧，复用调用方 `$S` SSH 包装）在**发复位前**依次硬验，**fail-closed**：
1. **SSH 现问现答**（fire 前复核，拒绝「上一轮缓存的通」）；
2. **uptime ≥ `BOOT_READY_MIN_UPTIME`（默认 90 s）**——覆盖 #67 的 SSH 早期窗口与本会话 20 s 失败点；
3. **桌面已起**：`phoc` 或 `phosh` 在跑（用 `ps -eo comm|grep -cx`，绕开 busybox `pgrep -x` 坑 #68）——这是现场证据里真正区分好坏的信号；
4. 可选 **风暴拒绝**（`BOOT_READY_REJECT_STORM=1`：dmesg 有 `vblank wait timed out`/`power-up failed`/`command DMA timeout` 即拒，因坏发态软复位本身不可靠 #150/#170）。

逃生阀：`ELDEN_FORCE_REBOOT=1` 跳过并醒目告警；非图形/RAM 诊断确无桌面判据时 `BOOT_READY_ALLOW_NODESKTOP=1` 只跳过判据 3（1/2 仍生效）。

### 4.2 接入点
- **本补丁已接入**（reboot2 前一行 `boot_ready_or_die`）：`scripts/q28-boot-cycle.sh`（任务点名）、`scripts/q28-layout-ab.sh`、`scripts/q28-layout-one.sh`。
- **建议后续接入（同一函数，一次一行）**：`to-fastboot.sh:41`、`sd-run-variant.sh:35`、`slot-switch.sh:57`、`kexec-bs-cycle.sh:14`。这些是单发，但门同样太松。
- **`reboot -f` 类**（`cycle.sh`、`q24-pmic-cycle.sh`、`flash-b.sh`、`flash-recovery.sh`）：至少加 uptime 下限；`q24-pmic-cycle.sh` 尤应——#215 已实证其 `reboot -f` 触发过一次 11 分钟失联。
- **循环脚本**：`q28-ab-delay.sh` 每轮进入前应显式确认「上一轮真起来且稳」（`sleep-sweep.sh` 的 `wait_booted()`+`pidof phoc` 就是**正确范式**，见 `scripts/sleep-sweep.sh:41-52`）。
- **阈值待标定（需真机，本审计未做）**：90 s 为保守占位；应用 PITFALLS #67 的 boot 时序法测「桌面/DRM 稳定」真实秒数再收紧，别写死。

### 4.3 草案文件与验证状态
- `patches/draft-early-reboot-guard.patch`：新增 `scripts/lib-boot-ready.sh`（+68）并给三个 q28 驱动各插 `boot_ready_or_die`。
- 已做：四个脚本 `bash -n` 通过；`git apply --check` 通过；就绪门用**假 S() 离线单测**（早启→rc4 拒、138 s+桌面→rc0 放行、SSH 掉→rc3、风暴→rc4、force→rc0、nodesktop 允许/拒绝）。
- **未做（禁碰设备）**：真机 uptime/桌面实测、真机 `reboot2` 前后 USB 枚举对照。

---

## 5. 纪律符合性与边界
- 全程**未操作设备**：无 `fastboot`/`ssh 192.168.7.1`/未取 `device-lock`；设备就绪判定用假 `S()` 离线模拟。
- **未改领域层 SSOT**：`TASKS.md` / `INDEX.md` / `PITFALLS.md` 只读引用。
- **未提交到 main**：产物仅落 `reports/` 与 `patches/`；提交与否由后续在 `audit/early-reboot` 分支决定。
- **不强行归因**：§2 对每条历史事件给「吻合/不吻合 + 证据(文件:行号/原文)」，机理未定者标注存疑。
