# PITFALLS 已作废/被取代条目存档（2026-10-14 整理）

> **性质**：证据层，**非 SSOT**；教训的**当前口径**以 `PITFALLS.md` 同号条目的首行为准。
> **来源**：`PITFALLS.md` 中下列 8 条条目的**逐字原文**（原位保留条目号 `#N` 与结论首行 + 指针）。
> **还原**：`git log -p -- PITFALLS.md` 取本次整理提交的前一版。

## #163

> 状态：已被取代（后期口径：坏发按时间成簇，见 #217/#223）

163. **★Q28 的真实变量是**冷/暖复位**，不是时间/温度（推翻 10-09「强时间相关」推断，用户实机纠正）。**
    - 当时定案（现已再被收窄）：冷起基本失败 / 暖起基本成功、与时间无关；A/B 必须固定复位类型（真实 POR 判据见 #166/#192）。后续 #192/#195/#217 证明真正变量是内核构建身份（UTS 版本串），冷/暖不是独立根因。
    - 证据：`reports/q28-binary-determinism-20261010.md` 等（见 #192 台账）。

## #167

> 状态：已修复（`q28-boot-cycle.sh` 判据已同步 card0 硬门）

167. **`scripts/q28-boot-cycle.sh` 判据缺陷：不查 card0，把 NOCARD 误报 GOOD（与 #165 同坑，但脚本未同步修）。**
    - 实锤：vk86-round 暖机被 q28-boot-cycle.sh 报 `VERDICT=GOOD`，实为 NOCARD（`/sys/class/drm` 只有 `version`）。该脚本只数六种风暴签名 + dpms，**不检查 `[ -e /sys/class/drm/card0 ]`**。
    - ⇒ **Q28 判显示一律用 `scripts/q28-devprobe.sh`（三态）**；已给 q28-boot-cycle.sh 补 card0 硬门（无 card0 直接 rc=10 BAD/NOCARD）。教训：修判据要**跨脚本同步**，一份改了另一份会悄悄漂移。

## #168

> 状态：已被取代（#171/#192 那条「构建身份」线已作废）

168. **★Q28 冷起复现的敏感点尚未定性：同一内核+DTB 逐字节相同、仅 initramfs `/init` 差一个模块加载器，冷 fastboot 路径一次 STORM(C2) 一次 NOCARD(A2)。**
    - → [已由 #192/#195 定性：冷起落 NOCARD/STORM 由内核构建身份（UTS）决定；ramdisk/DTB 已 2×2 交叉排除。证据 `reports/q28-retro-audit-20261011.md`、`reports/q28-storm-bias-audit-20261011.md`]

## #171

> 状态：已被取代（溯源审计降级 + #217/#223）

171. **★Q28 在本机当前状态是「按内核二进制确定性」的，不是「冷/暖」也不是 ~60% 随机（2026-10-10 夜，同一路径连测 21 发）。**
    - **已自审降级并作废（`reports/q28-binary-determinism-provenance-20261010.md`）**：原 21 发仅 7 发有仓库原始日志；声称的 8% 二进制差实为 `.rodata` 整段平移 4 字节假象（源头 `LOCALVERSION` 多 1 字符，无指令语义变化）；同一 vk64.img 冷 POR/冷 fastboot 3/3 = STORM，反证「不是冷/暖」。结论由 #192（构建身份/UTS 版本串）取代。
    - 附工具修复留存：`assert-kernel-sane.sh` mtime 陈旧检测仅对本树默认 `Image.gz` 生效（外部 `KERNEL_IMG=` 靠 UTS 对齐保身份）。

## #175

> 状态：已作废（「版本串决定 GOOD/NOCARD」整条线被 #192 推翻、#217/#223 收口）

175. **★Q28 的 `NOCARD`（无 card0）在**新编镜像**上高度疑似由构建版本串（`LOCALVERSION`）决定 —— 同一源码、同一 `.config`，只改版本串就翻转 GOOD/NOCARD。**
    - 本日实测（全部走 `reboot2 bootloader` → `fastboot boot` 同一路径，同一 vk89 ramdisk 基座）：`vk93-cleanctl`（`LOCALVERSION=-vk93-cleanctl`，内核=clean/base）**NOCARD 3/3**；`vk93-lv64`（**同源码同 config**，只把 `LOCALVERSION=-vk64`）→ **GOOD 1/1**（UTS 与旧 `boot-elden-vk64.img` 逐字相同）。另 `vk90/vk92/vk93-nocam` 各 NOCARD 3–4 发。
    - 与 `#171/#172` 的「`UTS_VERSION` 长度导致整段 `.rodata` 平移」一致：**布局漂移的触发点已收窄到版本串**；`boot-elden-vk64.img` 落在 GOOD 侧。**n 小（GOOD 仅 1 发），需复核**，但与 `#166`（暖复位粘 NOCARD）不矛盾——本对照两侧**同为暖路径**，唯一变量是 `LOCALVERSION`。
    - ⇒ **可复用的 Q28 GOOD 台架**：`LOCALVERSION=-vk64` 构建（UTS = `7.2.0-debug-vk64-gd02658e63cf6`）。**推论：`vk90/vk92` 上轮「NOCARD」判定全部作废（构建伪影），臂本身未被证伪。**

## #192

> 状态：已作废（「构建身份决定 GOOD/NOCARD」被 #217/#223 推翻）

192. **★Q28「冷起只有背光」的 GOOD/NOCARD 由内核构建身份（UTS 版本串）决定，与补丁逻辑无关；12 发冷起实证。**
    - 方法/判据（全部**物理 POR → Vol-+电源 进 fastboot → `fastboot boot`**，零写盘；判定=`scripts/q28-devprobe.sh` 三态 + `card0` 硬门 + 65 s 存活门；一键取样=`scripts/q28-cold-run.sh <img> <label>`；原始证据 `logs/q28-cold-*`、`reports/trials/*q28cold*`）：
      | 臂(vk) | 相对 base 的改动 | UTS | 冷起 |
      |---|---|---|---|
      | base `vk97` | —（d02658e63 未改源码） | `7.2.0-debug-vk64-gd02658e63cf6` | **GOOD 3/3** |
      | base2 `vk100` | 同源码重编（仅 build counter） | 同上 | **GOOD 2/2** |
      | empty `vk101` | **空提交（零代码）** | `7.2.0-debug-vk64-g8d5bdc16705f` | NOCARD 1/1 |
      | sham2 `vk99` | **+一行常量 `pr_info`** | `…-vk64-g94e9232e1eb4` | NOCARD 2/2 |
      | sham1 `vk98` | +`clk_round_rate` 查询（不赋值） | `…-vk64-g31e652c57d2d` | NOCARD 1/1 |
      | round `vk96` | +round(byte-clk 取整) 补丁 | `…-vk64-g66b5604d1898` | NOCARD 3/3 |
    - 规律：**UTS 逐字=`…-vk64-gd02658e63cf6` → GOOD（5/5）；其它任何构建身份 → NOCARD（7/7）**。base 与 base2 **版本串逐字相同、内核二进制不同**（build counter/时间戳）却都 GOOD ⇒ 决定因素是**版本串内容**，不是「重编随机性」；**空提交（零代码改动）也翻** ⇒ **不是补丁逻辑**。
    - 机理猜测：版本串内容不同 → 内核 `Image.gz` 压缩后尺寸/启动镜像布局微异 → 落在 **DSI probe 竞态**的刀刃两侧（与 `#171/#172/#175` 同源；`#175` 只测到「长度」，本轮证明「内容」同样足够）。
    - **推论（方法学，重要）**：**冷起 A/B 不能用来评估 Q28 补丁**——改代码本身就改变被观测对象（observer effect）。`round`/Method-B 的 NOCARD **不能**当「修复无效」证据（同理 `vk90/vk92` 的 NOCARD 判定作废）。若确要做冷起对照，须先有「改代码但不改构建身份」的手段——当前无。
    - **可复用台架**：`d02658e63`+`-vk64`（UTS 逐字 `7.2.0-debug-vk64-gd02658e63cf6`），冷起 GOOD 5/5，产物 `out/boot-elden-vk97-base-lv64.img`（`vk97`）/ `vk100-base2-lv64.img`（`vk100`）；臂可经 `scripts/q28-build-arm-lv64.sh` 重建。
    - **★可控性已验证（vk102-c1pin，同日）**：把版本串**钉死**回 `…-vk64-gd02658e63cf6`（`CONFIG_LOCALVERSION_AUTO=n` + `LOCALVERSION=-vk64-gd02658e63cf6`）后，**改内核源码 + 改 config（加 IP_ADVANCED_ROUTER 等）仍冷起 GOOD 1/1**（`ip rule` 亦生效）⇒ **法则只认版本串内容；钉死后冷起 A/B 恢复可用**（此前『冷起 A/B 作废』只对『版本串随源码漂移』的默认构建成立）。镜像 `out/boot-elden-vk102-c1pin.img`。
    - **旧结论重判（2026-10-11 `reports/q28-retro-audit-20261011.md`）**：`§k`「按内核二进制确定性」、`vk90/vk92` 的 NOCARD、round 的 NOCARD=「修复无效」、T1/T2/T3 冷 A/B 样本**均作废**；决定性证据=**同一 round 补丁未钉 UTS(`vk96`)=NOCARD 3/3 而钉死(`vk105-round-pin`)=GOOD**。冷起 A/B 的方法前提 = PINUTS。Q28 收尾口径见 `reports/q28-DOSSIER.md` §p。
    - **★法则范围限定（同日补）**：该法则只解释 **NOCARD 分支**（构建身份→有无 card0）；**STORM 是独立随机**——同日一次**日常 boot_b 纯净冷起**（UTS 同串）落在 **STORM**（`card0` 在、`storm=45`、`vblank wait timed out`、无 `phoc/phosh`/无会话）。⇒ 日常 Q28 痛点（STORM）仍在，与 boot 镜像身份无关。证据 `reports/wd-net-baseline-20261011.md` §4。
    - **设备日常 boot_b 即该身份**（会话初已稳定跑 3h；本次「纯净冷起」亦 GOOD：`card0`+`DSI-1 connected`+`phoc/phosh=1`+`storm=0`）⇒ **Q28 不构成日常 / Waydroid 的现实阻塞**；此前「Q28 挡 Waydroid」实为在 **RAM 起实验内核（NOCARD 倾向）** 上做验证所致。

## #195

> 状态：已作废（同上，STORM 亦非构建身份伪影）

195. **★Q28-STORM「冷起首条 DCS 命令-DMA 超时」同样是内核构建身份伪影（2026-10-12 定案；与 #192 同机理）**。
    - 现象（冷起）：`msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200` → `bonded command DMA failed: master=-110 peer=-110` → `sending dcs data ff 20 failed: -110` → `Failed to initialize panel: -5`，随后 `ctl reset/frame done/vblank` 风暴 ⇒ 只有背光/无桌面。坏发点 = `msm_dsi … timing …` 之后 **~0.22 s**；GOOD 启动在同一偏移做 `panel prepared`。DSI 时序参数、`DSI_PLL_lockfail=4`、`device_link_fail=8` 在好坏启动**完全一样**（良性）。
    - 判据：L1/L2 拆分探针 `scripts/q28-devprobe2.sh`（L1=DSI/panel 真失败：`command DMA timeout`/`Failed to initialize panel`/`sending dcs data … failed`；L2=DPU 下游：`ctl reset`/`frame done`/`vblank`）⇒ `NOCARD/L1FAIL/L2STORM/GOOD(-NOSESSION)`；`scripts/q28-cold-run.sh` 已优先调用 v2。
    - **证据（全部物理 POR → `fastboot boot`，零写盘）**：
      - **2×2 因子（内核构建 × ramdisk）**：新内核+新/旧 ramdisk = GOOD；旧内核+旧/新 ramdisk = L1FAIL ⇒ **ramdisk 无关**（vk104/vk106 vs vk94/vk107）。
      - **E2  DTB 交叉**：`vk109` 新内核+旧DTB = GOOD；`vk110` 旧内核+新DTB = L1FAIL ⇒ **DTB 无关**。
      - **E1'（决定性）**：同源码 `d02658e63` + PINUTS + **强制 `KBUILD_BUILD_VERSION=60` + `KBUILD_BUILD_TIMESTAMP='Thu Oct  8 17:06:14 CST 2026'`**（banner 逐字复刻 vk94）+ 旧 ramdisk ⇒ `vk111` 冷起 **L1FAIL**；与 vk94 内核 payload 仅差 0.14% ⇒ **重现旧构建身份即重现 STORM**。
      - 计数：**`#60`（2 位构建号）内核臂 4 坏/2 好（~67%）**；**3 位构建号（`#111`–`#120`）0 坏 / 12+ 发**（Fisher 精确 p≈0.005）。
    - 结论：**源码、DTB、ramdisk 全部排除；唯一变量 = 内核构建身份（`UTS_VERSION` 的 `#N`/日期长度 → `.rodata` 布局）**。`#60`（2 位）落竞态坏侧、3 位构建落好侧 ⇒ **STORM 不是「独立随机」，而是逐启动随机、坏发率由构建身份决定**（§p 的「STORM 独立随机」更正）。日常 boot_b = `vk94` = `#60` 内核 ⇒ 真痛点来源。
    - 治法：**日常镜像用新构建身份（3 位 `#N`）重编**（同源码 + ADSP DTB；cold GOOD 20+ 发）。**⚠️ 已作废（#217/#223）：3 位身份是偏置不是解**——`vk113-dailyid`（`#121`）真机冷起仍 L1FAIL；10-12 深夜 7 发 4 坏/7、坏发按时间成簇 ⇒ 缓解不在镜像层。
    - 方法学：**冷起 A/B 必须 PINUTS，且记录 `#N` 位数**；否则构建身份混淆结果（同 #192 observer effect）。
    - 证据：`reports/q28-storm-bias-audit-20261011.md`、`reports/trials/index.tsv`（`*q28storm*`）、`logs/q28-cold-*`。

---

## #250

> 状态：已解决（`CONFIG_ATH12K=m` + ramdisk 带 `wifi7/ath12k_wifi7.ko`，见 #259–#261）

250. **⏳ M1-7.3 内核从内核 init 到用户态 `Run /init` 约 95 s（daily `clean/base` 约 5 s）——待查，疑 ath12k 探测阻塞（异步/同步 initcall 差异）。**
    - 证据：黑匣子 dmesg 里 `Run /init as init process` 时间戳 ~95 s；同 boot 内 `ath12k ... failed to set mhi state: POWER_ON(2) -110` 也落在 95 s。
    - 影响：任何依赖“早启动”的测试（显示/桌面）都会晚 ~90 s 才出；非阻塞但影响可用性与验收节拍。
    - 状态：**未定位**；下一步对比 M1(7.3) 与 clean/base 的 ath12k 绑定（`=y` vs `=m`）与 initcall 顺序。
