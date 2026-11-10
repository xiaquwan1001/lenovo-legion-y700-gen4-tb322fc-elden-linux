# 进度总结 / Progress Log

> 面向公开读者的**诚实进度与问题记录**。内部权威台账是 [`TASKS/README.md`](TASKS/README.md) 与 [`INDEX.md`](INDEX.md)；
> 本文件按时间线给出「做了啥、验证到哪、错在哪」。全部数字都有仓库内证据文件。

---

## 1. 里程碑（时间线）

| 日期 | 里程碑 | 结果 |
|---|---|---|
| 2026-10-03 | BL 解锁（降级路：线刷 vendor → `fastboot oem unlock`） | `Device unlocked=true`；GPT 手术给 Linux 分区 `linux17`=193 GiB |
| 2026-10-03 | 持久磁盘根 + **Phosh 桌面自启** | `findmnt /`=`/dev/sda17`，Phosh 在跑 |
| 2026-10-04…08 | 驱动 bring-up 批次：音频(WCD939x)/CDSP/DisplayPort/相机出流/BT/WiFi/温控/串口 | 见 `TASKS/README.md` §1 |
| 2026-10-08 | 基线 `vk64`；发现 **Q28 显示间歇失败** | 冷起约 6 成失败，只有背光 |
| 2026-10-09 | Q28 根因收窄；#106「进 GUI 卡死」装自动取证 | 根因=bonded 双 DSI 首条 DCS 命令 DMA hang |
| 2026-10-10 | 立内核分界线 `clean/base`；模块化内核 `vk89` | 构建/身份管线收口 |
| 2026-10-10 夜 | Q28「按内核二进制确定性」结论 | **次日经溯源审计后被降级**（见 §4） |
| 2026-10-10 夜 | 发现 **clean-GOOD → 整机卡死**（`#106`）的强相关 | 见 §4 |
| 2026-10-11 | **容器传感器打通**（路线 C：宿主 gbinder 注入 + 真值 `ssccli`→UDP）；桌面深色/亮度闭环；`C1` 策略路由内核修复 | 见 `TASKS/README.md` C4/G1-28/C1 |
| 2026-10-11 | **M1 干净上游资产树**建成并通过干净构建 | `build/m1-upstream/clean-tree`，见 `reports/m1-clean-tree-20261011.md` |
| 2026-10-11 晚 | **容器音频打通**（C6：闹钟出声/录音/codec 53）、**C2 GMS 登录**（用户人工验证）、`/dev/fuse` emulated storage（Q30）、`C1` 网络治本（补 `IPV6_MULTIPLE_TABLES` 等） | 见 `TASKS/README.md` C6/C2/C1、`reports/container-audio-20261011.md`、`PITFALLS #194` |
| 2026-10-12 | ~~**Q28 STORM 定案**：与 NOCARD 同族 = **内核构建身份伪影**~~（**当日深夜已被推翻**，见下方 10-12 深夜各行与 `PITFALLS #217/#223`） | `PITFALLS #195`、`reports/q28-storm-bias-audit-20261011.md`、`reports/q28-identity-retest-20261012.md` |
| 2026-10-12 | **Q28 伪线索更正**：`to_primary_dsi` DSI0/DSI1 **不是** Q28 杠杆（两树属不同 MSM 实现，本硬件上是 no-op） | `PITFALLS #196` |
| 2026-10-12 | **Q24 重开**：更正「死前签名」（#197）；受控复现得 `{camcc}`+真熄屏=静默硬复位（末票 `mmcx↓/cx↓`）；S1/S2 存活、S3 因暖复位坏台架未执行（#198）；新增干净无相机台架 `lv64-nocam` | `reports/q24-ctl-20261012.md`、`reports/q24-stageA-20261012.md` |
| 2026-10-12 | **Q24 触发器干净定位（C 系列）**：三值仪表硬门下 C0(cam=0)/C1(`{camcc}`) 各自 `blank→hold 60 s→wake` 存活，C2(配对) 熄屏 3 s 内静默硬复位（GOOD 台架；`{camcc}` 单独不致死首次确证） | `reports/q24-cseries-20261012.md` |
| 2026-10-12 | **Q24 H1 DT 臂否证**：cambist 恢复上游 `MMCX+MX`（DTB-only repack，控制组逐字节复现、内核 UTS 不变）在同一 GOOD 台架同样死在熄屏，末票与基准逐字相同 | `reports/q24-h1-dtarm-20261012.md`、`reports/q24-h1-result-20261012.md`、`PITFALLS #205` |
| 2026-10-12 | **Q24 机制轮**：GPU `power/control=on` **不能**免除致死（GPU runtime-resume 被否定）；日常 boot_b 上「配对→熄屏存活→唤醒致死」**4/4 复现**；死亡末帧 = `phoc` 使能 `disp_cc_mdss_*`，共同信号 = NoC/BCM(`0x500xx`) 票爆发 | `reports/q24-mech-20261012.md`、`PITFALLS #207/#208` |
| 2026-10-12 | **Q24 受控差分 + NoC/BCM 否证**：同 boot A(cam=0) 熄屏 76 s + 唤醒存活 / B(配对) 唤醒 ≤10 s 死；BCM(`0x500xx`) 票死/活同址同型 ⇒ BCM 靶否证；cmd-db 资源映射首次落表 | `reports/q24-noc-20261012.md`、`PITFALLS #210` |
| 2026-10-12 | **Q24 致死 = SoC 级复位 + 约 30 s 自动重启（当日 5/5，无需物理 POR）**：USB 掉线 → 重枚举 → 回到已刷 OS；「需 POR」口径改判 | `reports/q24-noc-20261012.md`、`PITFALLS #209` |
| 2026-10-12 | **Q24 死法取证（PMIC/WDT 排除）+ 最小触发矩阵**：PON 块逐字节无差异、无硬件看门狗；cambist 单独 / camcc 单独在硬门口径下各存活 ⇒ 最小触发 = 配对 | `reports/q24-r9-20261012.md`、`PITFALLS #211/#212`、`scripts/q24-pmic-*.sh` |
| 2026-10-12 晚 | **Q28 收尾轮：日常镜像按 3 位构建身份重编（`vk113-dailyid`，可复现：全量重编逐字节相同）+ 上游 round 修复臂（`vk114-dailyid-round`）** | **两者均未修好 Q28**：当晚 7 发冷起 4 坏/7（4 臂同率），签名逐字同；⇒ 『构建身份治法』作废 |
| 2026-10-12 晚 | **Q28 判据修正：坏发按时间成簇（会话级），非镜像属性** | `PITFALLS #223`、`reports/q28-identity-retest-20261012.md` §6 |
| 2026-10-12 晚 | **Q28 负结果**：运行期重绑 panel/`msm_dsi` 不恢复（`card0` 消失 + GPU hangcheck） | `PITFALLS #224`、`logs/q28-rebind-20261012/` |
| 2026-10-12 晚 | **Q28 上游报告草稿就绪（待发送）** | `archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md`、`out/q28-bonded-dsi-2026-10-12.txt` |
| 2026-10-12 深夜 | **Q28 七臂收束：vk116–vk122（+vk123）全部否证**；`-5`=软件闩锁短路、DSI ctrl+PHY 复位救不回、自定义 bonded 序列/使能期 force-on 同签名坏发；判别量=**DYN pclk 域闩住**⇒故障态不在控制器内部 | `reports/q28-dsi-recover-20261012.md`、`PITFALLS #226` |
| 2026-10-12 深夜 | **Q28 主靶 dispcc/INTF 静态对照后削弱**：原厂源码本仓已有，`DSI_DISP_CC_*` 只用于 PHY reset clamp/MDP 调试，命令路径寄存器级等价 | `reports/q28-dispcc-static-20261012.md`、`PITFALLS #227` |
| 2026-10-12 深夜 | **Q28 运营兜底看门狗上机**：坏发 75 s 后自动**正常重启**（可用性 ~50%→~75%）；顺带修 `reboot2` 旧构建「无参=进 fastboot」地雷 | `reports/q28-watchdog-20261012.md`、`PITFALLS #228/#229` |
| 2026-10-13 | **Q28 复位终态对齐臂 vk125 上机否证**（= vk117 恢复路径 + `CLK_CTRL=0` 终态）：坏发 boot 上恢复路径确实触发（`resetting DSI link` + 两控制器 `Q28 resetterm: CTRL=0x0 CLK_CTRL=0x0 CLK_STATUS=0x1403`），但 `link_power_on` 后 `CLK_STATUS` 立刻回到 `0x1743`、重试命令逐字 `-110`（3 次尝试寄存器序列完全相同）⇒ **终态对齐不是解** | `reports/q28-dsi-recover-20261012.md` §20、`PITFALLS #230` |
| 2026-10-13 07:15–07:22 | **Q28 同窗配对采样（T2 第 1 窗，#60 ↔ 3 位身份）**：vk104-s1 **GOOD** / vk94-s4 **GOOD** / vk104 **GOOD** / vk94-s5 **UNKNOWN**（操作者提前中断，未捕判据）；同窗前段 07:04 vk125 **L1FAIL**、07:10 vk94 **L1FAIL** ⇒ **窗内两臂都出 GOOD、#60 自身也有坏发 ⇒ 无可辨身份效应**（坏发成簇主导；三条 record 由日志回填，存活门被人工中断已在 note 标注）。**同窗口尾 07:21 `vk94` 第 5 发 = 坏发第三形态「仅背光 + 无 SSH」**（`NOROUTE`；150 s 无 SSH、无 fastboot、30 min 仍不可达）⇒ 判据不得并入 NOCARD/STORM，且**设备侧看门狗救不了本形态**（`PITFALLS #231`） | `reports/trials/20261012T23{2103,2537,2538}Z-*.json`、`reports/q28-identity-retest-20261012.md` §8 |
| 2026-10-12 深夜 | **上游回移 lane 收尾**：清洗后 14 文件 fast-forward 合入 `clean/base`（`5b169d541`），出日常候选 `out/boot-elden-vk124-merged.img`（同 UTS 身份 `#121`）；**验收口径改为「取得 1 次 GOOD 冷起」**；上机 3 发全 L1FAIL | `reports/upstream-lane-merge-20261012.md` |
| 2026-10-13 | **C10 Waydroid 马达透传完成**：容器 HAL ↔ `aw86927` FF 全链路 → 自编 **AIDL V2** 拿到幅度控制与 `cancel` → **固化进 `vendor.img`**（运行期零 bind）→ **Settings 振动强度档位**（静态 RRO，档位 1→3） | `reports/waydroid-haptics-20261013.md`、`PITFALLS #232–#246` |
| 2026-10-14 | **Q31 显示回归定位并修复（E1b，1 行语义）**：上游 revert 了 bonded PLL init ⇒ `PLL_SYSTEM_MUXES=0xc0` 永不写入；修复后干净 POR 面板有内容 + 触屏可操作 | `reports/m1-73-e1b-pllfix-20261014.md` |
| 2026-10-18…22 | **Q28 机理改写**：定位 `dsi_bonded_cmd_failed` 单向闩锁 + `link_configured` 误清两处代码缺陷；A/B 修复后 **0154+0155 两臂合并 15/15 GOOD vs base 4/9（p=0.003）** | `reports/q28-disp-init-ab-20261022.md`、`PITFALLS #366` |
| 2026-10-23 | **Q28 v2：复位搬到 display 侧（`msm_mdss_reset()`）真 POR 5/5 GOOD**，证明起作用的是「复位动作 + 早于 PLL」而非 dispcc probe 位置；日常候选 `vk151/vk152` 已写 `boot_b`（含 kexec 诊断旋钮） | `reports/q28-v2-mdss-reset-20261023.md`、`reports/vk151-daily-candidate-20261023.md` |
| 2026-10-23 | **Q24 根因指名并停止采样**：7.2 血统缺上游 `pmdomain: qcom: rpmhpd: Skip retention by default`（7.3 线自带）⇒ 41 发 0 死亡 vs 7.2 的 6/8 死是**版本差不是随机**；日常线无需本地补丁 | `reports/q24-retention-rootcause-20261023.md` |
| 2026-10-23 | **收尾轮（免 POR）**：Q29 关闭（容器 Mesa bind 冗余，已删，图形正常）、**背光下限服务**（修「面板 GOOD 但看起来黑屏」）、容器相机恢复 1 设备（根因 = `/dev/video100` bind 从未持久化） | `reports/closeout-q29-backlight-camera-20261023.md`、`PITFALLS #372/#373` |
| 2026-10-23 夜 | **Q28 前 2 发真 POR（vk152）= 2/2 GOOD**，判据段逐字一致；累计 3 发，距 ≥8 发判据剩 5 发（**采样配额：agent 只取 2 发，其余交用户**）。**新增待办 Q32 = 暖起 vs 冷起差异**（静态预研指向「ABL 交接 framebuffer + 复位动作」，而非「暖/冷」本身） | `reports/q28-por-samples-r1r2-20261023.md`、`reports/q32-warm-vs-cold-preresearch-20261023.md` |
| 2026-10-23 深夜 | **Q32 开工（无复位、无 verdict）**：取证工具落地（`scripts/q32-boot-evidence.sh` / `scripts/q32-arm.sh`，clkdiag 加 6 个 Q32 判据、两个 POR 收集器自动附采）；**判据更正 = 复位深度只能从 pstore/ramoops 取**（本次 dmesg 永无该打印，`PITFALLS #374`）；**试点（vk152 `b6211ab4`）**：DT `splash_region` 43 MiB + msm `reserved boot framebuffer IOVA` + `silent_boot.mode=nonsilent` ⇒ **ABL 留了活显示**，而 `simpledrm=0`（`PITFALLS #375`）；UEFI 交叉评估：**维持搁置**，UEFI 会把「固件活显示」推向恒 yes 并抹掉 W1 臂 | `reports/q32-kickoff-20261023.md` |
| 2026-10-24 凌晨 | **Q32 判据表完成（5 发）**：W1(vendor 0x80010001)×2 GOOD、C1(真 POR)×2 GOOD、W2(arch SYSTEM_RESET)×1 GOOD ⇒ **三入口无差异，暖/冷不是主变量**；5/5 `FW_LIVE_FB=yes` / `SIMPLEDRM=0` ⇒ 「撕显示」机会与复位深度无关；局限 = 坏发未复现，结论限定本线。**复位深度改为从 pstore 指纹判读**（#374/#377）。Q32 → 并入 Q28 | `reports/q32-matrix-20261024.md` |
| 2026-10-24 | **Q28 收口 = 已规避（运营线 vk152）**：规避栈 = 0154/0155/闩锁清零/`link_configured` + 看门狗（ON、count=0）+ 三态探针；POR 5/5、暖复位 3/3 全 GOOD（8/8 无坏发）。用户决定**不补样本、不挖根因**（Q24 教训）；口径限定「运营判断、非已解决」，复启条件三条 → `reports/q28-workaround-closeout-20261024.md` |
| 2026-10-24 | **kexec「静默挂死」破案并修好**：目标其实 1.3 s 就到 `/init`（旧记录「没到 marker 段」错），真因是交接后 `GICR_CTLR.EnableLPIs` 在 SM8750 上是 **RES1**（清不掉）+ LPI 表跨 kexec 无保留 ⇒ `redist_disable_lpis()` -EBUSY ⇒ LPI 从不重配 ⇒ ITS 命令队列停摆（**99 次 ×1.25 s，`/init` 126.35 s**）。修法 = incoming 侧 `memblock_reserve()` **认领**继承的表、走 preallocated 路径 ⇒ **0 超时、`/init` 1.31 s（vk160/vk161 实测）** | `reports/kexec-target-boots-20261024.md`、`TASKS/sessions/2026-10-24-kexec-its-lpi-claim.md` |
| 2026-10-24 | **修法已上游投递并入归档**：`[PATCH] irqchip/gic-v3-its: Claim LPI tables inherited across kexec on DT`，Message-ID `<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>`，`/lkml/` 与 `/linux-arm-kernel/` 均命中；checkpatch `--strict` 0/0/0、干净 `git am` rc=0、编译 0 warning | `patches/upstream/m-gic-its-claim-20261024/README.md`、`TASKS/README.md` §7 M9 |
| 2026-10-25 | **日常线修复两项（都在机验证闭环）**：① **电源管理全废**的真因 = RAM 启动镜像用了 `initramfs-slim`（无 `/lib/firmware`）⇒ `q6v5_pas` 在 switch_root 前拿不到 ADSP/CDSP 固件 ⇒ 两 DSP 永久 `offline` ⇒ `qcom-battmgr` 所有属性 `-EAGAIN`（WiFi 正常是因为 ath12k 固件在磁盘）；换成日用 62 MB ramdisk 后 `adsp/cdsp=running`、电量可读。② **RTC 不可写**（`hwclock -w` → `-ENODEV`，每次开机被 1970 覆盖）根因 = DT 缺 nvmem offset cell（`rtc-pm8xxx` 无 cell 直接 `-ENODEV`）；按上游 `sc8280xp-crd` 范式把 offset 放进 `pmk8550_sdam_2@0xb0` ⇒ `hwclock -w` 成功、对时后重启 `date` 直接正确 | `PITFALLS #390/#392`、`patches/dt/0002-*`、`out/boot-elden-dtbo3.img` |
| 2026-10-25 | **Gunyah pVM 实测 + 一次结论更正**：RM 错误码是 `%d` 十进制打印，2026-10-24 的「`Error: 0x10` IRQ_INUSE」实为 **0xA `MEM_INVALID`** ⇒ 上轮 IRQ 泄漏/DTB 缺 doorbell 假设全废。pVM 路径（真 `pvmfw` + LEND + `SET_FW_CONFIG`）走到 `VM_INIT` 仍 `0xA`，7 个 DTB 变体错误码不变；`gunyah_rm_vm_init()` 请求体只有 vmid（DTB 侧改不动）⇒ DTB-only 路线穷尽；`SHARE+PVM` 更早被 `Error: 3 DENIED` | `reports/gunyah-pvm-attempt-20261025.md`、`PITFALLS #391/#393` |
| 2026-10-25 | **根文件系统切 f2fs（路线 A：并存，数据不出设备）**：先用实测否掉「原地换」——主机↔设备 USB NCM 只有 **14.3 MB/s**（300 MB/21.0 s），两趟 30 GB ≈ 1–1.5 h 且 ext4 一格式化就没本地回退。改为「缩 ext4 + 尾部新建 f2fs + 同盘本地复制」：`linux17` ext4 **193→96 GiB**、`linux18` f2fs **96 GiB**（GPT 双表写后 `cmp` 读回一致）；`tar -d`（含 xattr/ACL）**零差异**、216 882→216 876 文件（差 6 = socket）、硬链接 133 组保留。零写盘 `fastboot boot` 验 `f2fs` 起根后写槽 `boot_b`：真 POR `/`=`/dev/sda18 f2fs`、模块 **37**、`version magic` 错 **0**、`phoc=1`、DSI connected、`qbootctl succ=1`、读回 sha 一致、首启后 `fsck.f2fs` 全 `[Ok..]`；ext4 侧保留且 `fastboot boot` 实测可起（回退零成本）。过程修掉 5 个只在 RAM root 暴露的工具坑（busybox `tar/dd`、无 `python3`、dmesg 钩子 fd9 占超级块、tar 流 sha 非内容指纹） | `TASKS/sessions/2026-10-25-f2fs路线A落地.md`、`RUNBOOK-BRINGUP/f2fs-migration.md`、`PITFALLS #400–#405` |
| 2026-10-24 | **kexec 剩余边界写清**：修好的是「内核 + MSI」，**显示与 USB 仍是继承活态**（`mask=1` 跳过 `device_shutdown`）⇒ 目标里无 `card0`、`[usb-gadget] no UDC after 20s`，~157 s 被自家 Q28 看门狗重启回落；定位维持「不需显示/网络的调试快环」 | `reports/kexec-target-boots-20261024.md` §9、`PITFALLS #380` |
| 2026-10-26 | **驱动模块化迁到 7.3 日常线（`vk163`，零写盘上机）**：载荷驱动（ath12k / QDSP6 全套 / WCD939X / SC8280XP / 触屏 / 触觉 / 背光）在 `build/vk151`(@`24223e4`) 全部翻成 `=m`，并在**生产 f2fs 根**上启动验证：66 模块、WiFi/BT/音频/触屏/触觉/背光/相机/Phosh 全绿、模块错误 0；`mod-loop` 热换触屏驱动实测通过 ⇒ 改叶驱动从「重编内核 + 重做镜像 + 重启」降到秒级。**`boot_b` 未写**（是否转日常线待定）。顺带更正两条旧结论（BT 模块化不需要改 Kconfig；`PCI_PWRCTRL_PWRSEQ` 与 WiFi 无关）| `reports/vk163-modular-20261026.md`、`PITFALLS #406–#409` |
| 2026-10-26 | **Mobian 迁移物料（摆脱 Alpine 依赖的第一步）**：`rootfs/debian/pkgmap.tsv` 把设备 120 个 apk 全部定性（map 97 / drop 23 / add 7，门禁 **FAIL=0 WARN=0**）→ 107 个 Debian 包清单；`elden-firmware` 自建固件 deb（21 MB / 116 项，板 DTS 的 `firmware-name` 逐条门禁全绿，含自编 tplg）。新事实：BT 固件实际请求 `qca/` 前缀；Debian 的 `firmware-qcom-soc` 无 `sm8750` ⇒ 自建包必需 | `reports/mobian-rootfs-artifacts-20261026.md` |
| 2026-10-26 | **Mobian 路径打通到桌面**：`linux17` ext4 上的 Debian forky/sid 根全自动进 phosh（修掉六条静默失败：overlay tar 顶掉 usr-merge、`.pre` 无 shebang、`_greetd` 名差、greetd-phrog drop-in 排序、缺桌面用户、`wlan0`/`wlp1s0`），电量（缺 `upower` 包）与 usb0（busybox `udhcpd` 无链接）同日收口；`boot_b`/`linux18` 未动，回退 = 重启 | `reports/m6-switch-root-breakpoint-resolved-20261026.md`、`reports/debian-root-accounts-sensors-20261026.md` |
| 2026-10-26 | **模块化 v2（`vk172`/`boot_b`=`vk173`）**：42 符号重分类后 `=y 3364 / =m 1464`，1638 `.ko` vermagic 逐字一致；上机全绿（含 MMC 整链 `=m`），`mod-loop` 热换秒级；同批把 RTC offset 打进板 DTB（`hwclock` 可写且跨重启保持） | `reports/vk172-modular-v2-build-20261026.md`、`TASKS/README.md` T16/T21 |
| 2026-10-27 | **Debian 根上的 Waydroid 起完**：`sys.boot_completed=1`、6 个 h/w 传感器 running、加速计数值与 `ssccli` 逐位一致、马达桥 `amp=255/255` 实测、冷起 XDG autostart 10 s 内 Session RUNNING。根因三条全在用户态：`waydroid-sensord` 是 **musl 动态件**（glibc 根 exec ENOENT 但 `which` 命中 ⇒ 关了 stub 又没 HAL）、`elden-hapticd` 的 systemd `${VAR}` 不分词、`ssc-udp-relay` 缺 `ssccli`（在 `libssc-bin`） | `TASKS/sessions/2026-10-27-Debian根Waydroid打通-sensorsHAL与马达桥.md`、`PITFALLS #431–#437` |
| 2026-10-27 | **容器相机推进到 App 预览 `STREAMING`**：宿主 `gst(NV12) → v4l2-ctl --stream-out-mmap=8 → /dev/video100`（`REQBUFS` 只能在写端解决，模块保持 stock）；容器 `configureStreams` 通过、`Preview stream state STREAMING`。剩余 = 外部 HAL 无 JPEG(BLOB)（`v4l2loopback` 只能 NV12）故拍照型 App 打不开，绕法 = preview+analyze 类 App | `PITFALLS #438–#441`、`TASKS/README.md` C5/U7 |
| 2026-10-27 | **G1-34 按根分列**：SSC 服务 **400 已注册**（旧「未注册」结论作废）、`ssccli` 出真值；`HasAccelerometer=false` 的真因在 **libssc 0.4.4**（Alpine 工作态 0.4.3），顺带修掉 `qrtr-tools` 缺失导致的 60 s 白等 | `PITFALLS #442/#443`、`PITFALLS/sessions/107-*` |
| 2026-10-27 | **三条并行 lane 收口（编排者独立复跑判据）**：`b5-resoc` 把 bonded-DSI 的全局态/魔数/十直调收进 per-SoC `msm_dsi_bonded_cfg` + 两个 host ops（3 提交，逐提交 `make drivers/gpu/drm/msm/` rc=0 / 0 warning；`static bool dsi_bonded_cmd_failed`=0、`0x001f0200`=0、`0x44440400`=0、`dsi.h` 原型 10→2）；`aw86927-series` 从 pristine 起把固件波形能力做成 5 提交上游系列草案（`checkpatch --strict` 5/5 `0E/0W/0C` + `dt-doc-validate` rc=0 + 逐枚 `git apply` 全通）；`devcam-ab` 上机做 SKEW_CAL A/B（`0x54` vs 厂商 `0x00`，各 3 次 90 帧） | 三臂均 90/90、0 错误、30.26 fps（顶 sensor 上限）、帧 STDDEV 53.81 vs 53.78 ⇒ **无可测差异**；处置 = 不回退，上游化时以厂商值提交并注明「本机无差异」 | `reports/lanes-20261027-verified.md`、`TASKS/sessions/2026-10-27-三lane收口与mod-loop假成功修复.md` |
| 2026-10-27 | **`mod-loop.sh` 的「reloaded」曾是假的**：`qcom-camss`(连字符) vs `lsmod` 的 `qcom_camss`(下划线) 致 `rmmod` 从不执行、`modprobe` 必失败且错误被 `2>/dev/null` 吞；`modules_install` 目的地取自不刷新的 `include/config/kernel.release` ⇒ 装进错误 `<KV>`；`modules.order` 丢失时被误报成「driver is built-in」。修法 = 直收 `.ko` → `updates/` + 名字归一化 + 失败非零 + **build-id 硬校验** | 正路 build-id 匹配、负向测试 rc=1；同轮我自己用 `make -B` 验证生成文件把 `build/vk151/.config` 从 12047 行/`=m`1464 改成 9042/686，已按 manifest `config_sha256` 反查快照逐字还原 | `PITFALLS #447`、`PITFALLS/sessions/108-*` |

| 2026-10-27 夜 | **G1-34 真因换掉两个**：`HasAccelerometer=false` = 缺 udev 属性 `ssc-accel`（**不是 libssc 0.4.4**；`drv-ssc-accel.c` 首行就查该属性）；修完冷起又灭 = **ordering cycle**（服务挂 `multi-user.target` 而 `After=hexagonrpcd`，包单元自带 `After=multi-user.target`）⇒ 改挂 `graphical.target`。冷起 `running`/`failed=0`/传感器三真、无需手工 restart | `PITFALLS #451/#453`、`TASKS/sessions/2026-10-27-G1-34定案-udev属性缺ssc-accel.md` |
| 2026-10-27 夜 | **B5（M6）第 1–4 步**：1–3 步零写盘上机**行为中性**（60 次 DCS 亮度写 + 20 轮熄屏/唤醒，7 项错误计数全 0、`boot_id` 不变）；第 4 步（master 由 per-SoC 表决定）同值臂一致、**判别臂强改 DSI1 ⇒ 面板首条 DCS `ff 20` 三连 `-22`** ⇒ 主从角色**不可自由换**。陷阱：判别臂下截图/桌面都正常，只有 dmesg 露馅 | `reports/b5-step4-master-from-cfg-20261027.md` |
| 2026-10-28 | **Q34 定案 = 缺固件不是服务崩**：`hci0` DOWN/BD 全 0、`Direct firmware load for qca/tmel_peach_20.elf failed with error -2` ⇒ `Peripheral setup failed: -2`；补文件 + 重载模块 ⇒ `UP RUNNING`/`QCA setup on UART is completed`。根治 = `local-extras.tsv` + 新门禁 **A2「驱动 MODULE_FIRMWARE 必须进包」** | `PITFALLS #454`、`TASKS/sessions/2026-10-28-Q34蓝牙缺tmel固件定案.md` |
| 2026-10-28 | **U2（B5/M6 原子回调时序）上机取证并关闭**：`ftrace` 抓 bonded-DSI 熄屏/唤醒两轮，enable 序 = `pre_enable(只 power_on) → panel_prepare → 219–224 ms → bridge_enable(host_enable ×2) → panel_enable`，disable 序 = `panel_disable → host_disable ×2 → panel_unprepare → post_disable(power_off ×2 + phy_disable)`；8 项判据全 PASS 且两轮同序、错误计数 0→0 ⇒ 现有原子回调切分即推荐形状，**不需要补丁** | `reports/b5-u2-atomic-timeline-20261028.md`、`scripts/b5-u2-atomic-timeline.sh`、`PITFALLS #456` |
| 2026-10-28 | **M4-2…M4-4 定稿为可发状态**（未发）：9 提交 / 14 文件 / +1931 −61 —— R1 改成厂商 SKEW_CAL 值并写明 2ph 表 103/103 出处 + 本机 A/B 无差异；R3 把「帧起始改由 CSID 上报」拆成独立提交；R4 拆 DMA 连续性与失败回退；新增 SoC dtsi 节点 ⇒ `dtbs_check` 首次能跑且两板 0 warning（含负向测试）；剔除 NOT-FOR-UPSTREAM 提交。门禁：checkpatch 9/9 `0E/0C`、逐提交编译含 `LD [M]` 全绿、pristine 重放逐字节一致、`send-email --dry-run` 10 × OK | `reports/m4-camss-series-ready-20261028.md`、`patches/upstream/m4-camss-series-20261028/` |
| 2026-10-28 | **M4-2…M4-4 已投递（用户批准）并逐字节复核**：`[PATCH 0/9] media: camss: add SM8750 support`，10 封 `Result: 250`，Message-ID `20261028034105.326535-1..10`；lore `/all/` **10/10** 归档，抽验 linux-media / linux-arm-msm / linux-devicetree 均 200；**raw → mbox → pristine `git am` 9/9，与源分支 `git diff` 空**；Sent Items 10/10、INBOX 回环 10/10 | `patches/upstream/m4-camss-series-20261028/README.md` §6、`PITFALLS #457` |
| 2026-10-28 | **B5 第 5 步解阻**：原判「`0x001f0200/0x44440400` 魔数 bit30/29 上游无描述 ⇒ 永久隔离」被证否 —— `0x44440400` 的五个位在 `generated/dsi.xml.h` 里全有名字（OR 逐位相等），bit30/29 = `BROADCAST_MASTER`/`WC_SEL`；只有 `ERR_INT_MASK0` 字段布局无公开手册 ⇒ 写成 `GENMASK(20,16)|BIT(9)` 并注释。落地 0005 补丁，**`dsi_host.o` 的 `.text` 逐字节相同**（零机器码差异），编译 0 warning | `reports/b5-step5-doc-unblock-20261028.md`、`PITFALLS #458` |
| 2026-10-28 | **C5/U7 容器相机真卡点换人**：镜像内本就有 OpenCamera（无需装 APK）；`Number of camera devices: 0` 的真因是容器启动时主机无 `/dev/video100` ⇒ LXC `create=file` 造了 0 字节普通文件，重启容器即得 **1 台**；NV12/YUYV/MJPG 三格式下 App 都一样 `Opened→disconnect`，logcat `metadata is null` ⇒ 真卡点 = external HAL **static metadata 为空**；顺带修 `cam-mode.sh` 写死 uid 与 `sudo -u` 导致的 blank 守卫静默空操作 | `reports/c5-u7-container-camera-20261028.md`、`PITFALLS #459` |
| 2026-10-28 | **C5/U7 Binary Eye 实测：相机链路对 App 可用** —— 容器里早已装 `de.markusfisch.android.binaryeye`（启动 Activity 是 `.activity.SplashActivity`）；`Camera 200: Opened` → `configureStreams` → **`start V4L2 streaming 1280x720@30fps`** → **`ProcessCaptureRequest latency histogram (7) samples`（真 7 帧）**，随后 provider 进程 SIGSEGV：`formatConvert()` → `libyuv::I420Copy` → `CopyRow_NEON+8` `SEGV_ACCERR` ⇒ **HAL 输出侧 `lockYCbCr` 的 gralloc YCbCrLayout 与 I420 平面假设不符（容器 gralloc）**。连同 OpenCamera 的 `libhwui.so GrBackendTexture` 崩溃 ⇒ **两处阻塞都在「帧交给 Android 图形层」，不在相机线** | `reports/c5-u7-container-camera-20261028.md` §16–§20 |
| 2026-10-28 | **C5/U7 写端打通：容器相机预览流真的跑起来** —— `v4l2-ctl --stream-from-hdr` 不可用（头是 `fwht_cframe_hdr`，FWHT 专用，源码核对 `v4l2-ctl-streaming.cpp:read_fwht_frame()`）⇒ 自写 `patches-userland/mjpgfeed-loopback/`（SOI/EOI 切帧 + `bytesused`=真实帧长 + 8×mmap buffer）⇒ 设备实测 **`frames=390+ dropped=0`**、`Size Image=1843200`；容器侧 **`configureV4l2StreamLocked: start V4L2 streaming 1280x720@30fps` 成功**、**`Convert V4L2 frame to YU12 failed` 完全消失**。**卡点换人 = 容器 GPU**：OpenCamera 打开相机与 configureStreams 全通过后崩在 `libhwui.so` RenderThread（`GrBackendTexture::~GrBackendTexture` 野指针，HWUI+Adreno/ANGLE）——与相机无关，转 G2 图形线 | `reports/c5-u7-container-camera-20261028.md` §12–§15、`patches-userland/mjpgfeed-loopback/`、`PITFALLS #460` |
| 2026-10-28 | **C5/U7 容器相机第二轮：上版结论被推翻，真卡点两级并已修到最后一门** —— `metadata is null` 是关闭路径噪声（static metadata 实为满 55 项）；① HAL **只在 MJPEG 源**下广告 JPEG(BLOB)（NV12 源格式 33 缺席 ⇒ `no picture sizes returned by getOutputSizes`）；② v4l2loopback 压缩格式 `.depth=32` ⇒ MJPEG `sizeimage=w*h*4=3686400` 超 HAL `kMaxBytesPerPixel=2` 上限 `1843200` ⇒ `configureStreams` `-38`。修 `depth→16`，上机 `Size Image=1843200`、`configureStreams` 通过、`start V4L2 streaming` 成功；剩余 = 写端须按真实 `bytesused` 切变长 MJPEG 帧（`v4l2-ctl --stream-from` 按固定 sizeimage 切 ⇒ `Convert V4L2 frame to YU12 failed`） | `reports/c5-u7-container-camera-20261028.md` §7–§11、`PITFALLS #460`、`patches/extmod/0002-*` |
| 2026-10-28 | **M4 camss 系列 Sashiko 自动评审处置（v2 候选）**：8 条 finding 逐条取证（`reports/m4-sashiko-triage-20261028.md`）⇒ **4 条真 bug 已修**（`dt_id` 误取 vc 应为 port［High］、`INFO_RUP_DONE` 未解掩［High］、`frame_started` 不回置+下溢［Medium］、事件 ioctl 三态不一致［Medium］）；另 2 类（`aup/rup` 竞态、`csid_set_stream` 跳过 configure_stream）判定=既有上游同形/既有门，回帖不改。v2 分支 `build/m4-base@m4/v2-20261028`（+1938 −61）、产物 `patches/upstream/m4-camss-series-20261028-v2/`；逐提交编译 9/9、checkpatch 9/9 `0E/0C`、pristine `am` 9/9。**F3 等 4 处修复已零写盘上机复验（front/rear 各 90/90、0 错误、像素正常）；未发，待用户批准** | `reports/m4-sashiko-triage-20261028.md` |
| 2026-10-29 | **C5/U7 容器相机 gralloc 修法已上机 = 有效**：`dl-cam/gen-aidl.sh`（AOSP prebuilts aidl + cpp/ndk 两套头）补掉构建链缺口后重编 external HAL（rc=0，`camera.device@3.4-external-impl.so` sha256 `4291fa7a…`），`vendor.img` 用 `debugfs` 原地换 5 个 .so（回退件 `vendor.img.bak-l1d-20261029-103701`）。四判据：**12 个 capture 请求 / 0 崩溃 / 12 次布局修复（`y_str 2048 c_str 0` ⇒ `y_str 1280 c_str 640`，转换分支 `YU12`⇒`YV12`）/ `refuse=0`**，框架 `Preview stream state = STREAMING`。**剩余卡点换人 = 容器图形层**：`surfaceflinger` `SIGABRT: Unable to generate SkImage` 自杀 ⇒ 之后 `am start` 一律 `DEAD_OBJECT`。同日新坑：**宿主 `androidboot.mode=charger` 会毒化容器**（`ro.bootmode=charger` ⇒ 只 15 进程、无 `media.camera` 服务；零改镜像修法 = bind 覆盖容器 `/proc/cmdline`）| 
| 2026-10-29 | **M4 camss v3 上机复验 = 无回归**（镜像 `vk182-camssv3`，父会话执行）：前摄 90 帧 30.25 fps rc=0、后摄 90 帧 30.01 fps rc=0，dmesg `camss|csid` **0 条**、`BUG/WARNING/lockdep` **0 条**；但 sashiko #4 [High]「多 RDI 累积位」**未被判别**（两路走不同 CSID 实例）。同日出**上游 v6 对照**（v6 8/8、重叠 5/9、0004 与 v6 5/7 函数名 15/15 全同）⇒ 推荐 **C→B**：先 3 句回信定调，落地只发 0007/0003/0006。过程代价：自建 boot.img 前三刷「USB 整个消失」，真因三条硬条件（`elden_early_gadget=1` / ramdisk 必须是可用那份 / UTS 必须匹配 `/lib/modules`）⇒ `PITFALLS #468` | 
| 2026-10-29（晚） | **双口充电实测定案 + 上游两系列投递**：① 只留短边 PD 时电池 **0.199→12.21 A**（`capacity` 19%→27%，≈46 W），两口同插只吃长边 SDP 0.891 A；内核逐口建模但 `qcom-battmgr-usb` 只读跟随被 ADSP 选中的那口 ⇒ **归因固件选口策略**（事实正文 `DEVICE` §1.4、`TASKS` Q35）；② `[PATCH 0/3] media: camss: three fixes …` 与 `[PATCH v2 0/3] drm/msm/mdss: reset all MDSS block resets …` 各 4 封 250、lore `/all/` 各 4/4 归档；③ M8 撤回收尾信退信后**重投 Michael Turquette**；④ M8 v2 投前修掉 binding 的 `maxItems` 违反 dtschema meta 规则（改 `minItems: 1`，两态 `dt-validate` 实测）⇒ `PITFALLS #470` |
| 2026-10-29 | **camss 线程回信已发**（`<179325717815.489400.16602455641444097904@mail.ustc.edu.cn>`，lore `/linux-media/` 命中）：发送前发现上游最新是 **`[PATCH v23 00/15] media: qcom: camss: Add Kaanapali support`**（Hangxiang Ma，10-28），其 changelog 明写「Replace the CSID AUP/RUP union with separate reg_update/addr_update field pairs」= 与我方 0004 同处 ⇒ **主动放弃 0001/0002/0004/0005/0008/0009**，只保留 0007/0003/0006 三枚通用修复待 rebase 后单发。教训 `PITFALLS #469`（对照上游要取最新 revision，重合点常只写在 cover 的 changelog 里） | 
| 2026-10-30 | **传感器（G1-34）修好并上机**：根因不是库版本而是「修复从未进镜像」——`fastrpc` 里的 DT 改动只活在未提交工作区 ⇒ 抽成独立 DT commit 重编 | `HasAccelerometer/AmbientLight/Proximity` 三真、`ssccli` 出真值；`TASKS/README.md` §1 G1-34、`reports/code-style-and-duty-overlap-audit-20261030.md` C-01 |
| 2026-10-31 | **平板单 Linux 分区扩容落地**：删 `linux18`（Alpine 回退根）→ `linux17` 扩到 **192 GiB**（起始扇区 73277435 未变），在线 `partx -u` + `resize2fs`，重启复验 `/` = 188 G（可用 163 G）；GPT 双表 + `sgdisk --backup` 留档。踩坑：`sgdisk --new` 默认 2 扇区对齐把奇数起点挪 +1（ext4 会挂不上）⇒ `PITFALLS #473` | `DEVICE/README.md §3.3`、`backup/gpt-20261031/` |
| 2026-10-31 | **上游批次（用户按批放行）**：wl2868c **v3 0/3** 与 camss **v2 0/2** 各 3–4 封 250、lore 命中；两封回 Krzysztof（wl2868c 逐条答复 + 8 条 consumer 证据；camss 线程重锚定），开头均如实披露「AI 辅助起草、内容与决定由本人负责」；patchwork 9 枚旧件标 `superseded`；Shuai Liu 的 icc 表 finding 转成 fix 素材（binding+DTS 收敛到驱动实际投票的 2 条，**归属 Hangxiang，不投递**） | `reports/m4-camss-v2-20261031.md`、`reports/camss-icc-table-fix-20261031.md`、`patches/upstream/{m4-camss-v2-20261031,camss-icc-20261031}/` |
| 2026-10-31 | **平板夜间通道可用**：平板（Debian sid/arm64）装 git 2.55 / node 24.22 / pi 1.4.0 / ble.sh，模型走直连 USTC（主机 litellm 不可用时自动切换）；仓库 clone + PAT + 会话 617 M 同步；`pi-tablet-night.timer` 23:00 跑 6 个低 CPU 任务（文档审计/邮件分诊/补丁备料/日志分析/证伪复核/SSOT 并入草案），只推 `tablet/<task>` 分支；runner 冒烟 `done=1 rc=0` | `reports/tablet-{dev-env,offload-plan}-20261030.md`、`.pi/plans/tablet-*` |
| 2026-10-31 | **`vk183-fastrpc` 转正为日常件**：用户物理断电做真 POR | Q28 七项计数全 0、1639 个 `.ko`、失败单元 0、传感器出 `face-up`；`reports/trials/20261031T073414Z-vk183-daily-por-r1.json` |
| 2026-10-31 | **UEFI `E1-v0b` 上机 = 不交棒**（证伪「含 UFSDxe 就会交棒」，零写盘） | 60/60 s 采样恒为 `18d1:d00d`、同一 bus/device ⇒ 从未离开 ABL；`reports/uefi-e1-v0b-onboard-20261031.md` |
| 2026-11-01 | **「只能进 fastboot」事故闭环**：U2 一度无 Android/ssh/adb | 真根因 = **引导固件代次与 A/B 槽脱钩**（`*_a`+LUN1 = 259 原厂 UEFI、`*_b`+LUN2 = 上一版），ABL 按活动槽选 boot LUN ⇒ `fastboot --set-active` 另一槽，双向复现；`reports/uefi-slotboot-stuck-fastboot-20261101.md`、`PITFALLS #484/#485` |
| 2026-11-01 | **DDR 取证通道打通 + 硬结论：本机 DRAM 跨复位不保真** | 1 MiB 写 `0xA5`，热复位后 26–32% 字节 1–3 bit 翻转（几乎全 1→0）；判据必须改用单调编码；`reports/uefi-ddr-blackbox-20261101.md` §0/§2 |
| 2026-11-02 | **UEFI「载荷到底有没有被执行」四臂判别 = 四臂全 0**，并撤回一条错判 | A1/A2/A3 的 `stage1` 全 0；中途「A3 挂死=被执行」经现场证实为**回落 Android**；新事实：`a` 槽 `unbootable` 只挡一次，ABL 会自己换槽并清位；`reports/uefi-ddrcut-fallback-20261101.md` §6-A/§6-D、`PITFALLS #487` |
| 2026-11-03 | **UEFI 三线核查（邮件/GitHub/外部）后裁决下一步 + 载荷可执行性重定位（9 发零写盘）** | DDR 黑匣子正控打通（真内核标记读回 95–98%）；**推翻两条旧判据**：`usb_read failed` ≠ 交棒、**不存在 1–2 s 看门狗**；解冻条件②满足（同芯片 SM8750 的 SunUEFI/UniXNU 已有 UEFI 用 UFS 先例）；`reports/uefi-posctrl-20261103-summary.md`、`reports/uefi-next-step-decision-20261103.md` |
| 2026-11-04 | **UEFI 载荷首次被执行 → Mu PrePi 走完 → 卡点定位到 DxeCore 未启动** | 打包配方定案（v2 base 0 + `text_offset=0`/`image_size`=真实长/`flags=0xa`）；屏上可见性达成；`LoadDxeCoreFromFv()` 返回 `EFI_NOT_FOUND`，失败在 `FV_IMAGE` 的 GUIDED/LZMA 段 `Decode`；设备侧块表 0–1 MiB 正确、其后 48 块全错；`reports/uefi-payload-execution-20261104.md`、`PITFALLS #490–#496` |
| 2026-11-04（主机侧收口） | **UEFI 卡点真因定位并出修复件（未上机）** | 反汇编定到指令级：shim 把 `Image` 头 offset 16（repack 改写成的真实长度 `0x400308`）当拷贝长度，等值比较型分块循环首轮即落“完成”分支 ⇒ **只拷了 FD 的前 1 MiB**；修法 = 拷贝长度/目标改构建期常量 + 循环改硬上界 + repack 加 16B 对齐断言；产物 `out/uefi-20261104-fixcopylen.img`、补丁 `patches/uefi/20261104-fixcopylen/`；`PITFALLS #497` |
| 2026-11-04（上机 1 发） | **UEFI 修复件首发现场：HANDOFF 达成，屏上判据未取到** | `fastboot boot` 零写盘：`Sending 1.496 s` + `Booting OKAY 10.109 s`（与旧 11 发同签名 ⇒ ABL 真跳）；随后 300 s USB 无枚举、`192.168.7.1` 不通；用户报告「反复刷屏、疑似 kernel panic」⇒ **本轮不能判定 E0 是否生效**（`verdict=indeterminate`）。后续设备进入 fastboot（slot b/successful），`fastboot reboot` 后仍未回 Linux。`reports/artifacts/uefi-boot-20261104-fixcopylen/`、`reports/trials/20261104T024726Z-uefi-fixcopylen-r1.json` |
| 2026-11-04（上游） | **两批投递 10 封全 250：wl2868c v6 0/5 + dwc3 0/3 正确形态重发** | patchwork 8 枚全命中、0 退信。v6：修 apply 失败（`sm8650-valve-deckard.dtb` 插入点）、按 Conor 拆 `arm/qcom.yaml`、binding 补 `vsys`、CCI 让给 Hangxiang、driver 改整字节写；dwc3：base 回退公开 `v7.3-rc7`、三枚自足合并 v4+v5、cover 逐条答 Krishna/Krzysztof。顺带定案 `linux-regulator@vger` 不存在（上批 6 封 550 的源）。| 2026-11-05 | **UEFI 取证通道改走 fastboot 响应**（屏上三条通道全废后，断电收尾） | `diag st=%r last=[%a]` 让「到没到某阶段」完全在宿主侧判读，不用拍照；同日一条断电事故（UEFI 树 15 文件变 0 字节）已用 manifest 的 25 条补丁序列重建，与旧件只差构建时间串 ⇒ 代码等价、sha 不跨构建可复现。`reports/uefi-noavb-dtbo-bootchain-20261104R.md` §8/§9、`PITFALLS #509–#511` |
| 2026-11-06 | **UEFI 三处判据更正 + 真启动件首次走到跳内核之前** | ① **上一轮 10 发作废**：`SbStopStage` 只在 `BootLinux()` 内赋值，`LoadImageAndAuth()` 先跑 ⇒ 探针从未命中；② 单变量定案**崩溃元凶 = 屏显写穿帧缓冲**（`splash_region` 43 MiB 只有前 ~448 KiB 可写，`SCALE_FACTOR 3` 下一行文字 274 KiB ⇒ 是我们自己的调试输出越界），新通道 `sbprobe=3` 不再付断电代价；③ 门控那条写后 `VS_STOP` 尾段九档 + `BootLinux` 1..6 全回话，`stop=7/41/42` 无应答 = **`ExitBootServices` 拆掉 USB 设备栈**不是崩溃；④ 真启动件首次被放行 ⇒ 屏上 `[L] LoadImage=Success` 后**直接 Synchronous Exception（PC 落 DXE heap）**、`[K] JUMP-BANNER` 不出现 ⇒ 卡点搬到 `LoadImageAndAuth` 收尾 / `FastbootOkay` 段，且**诊断模式 ≠ 真启动路径**。`reports/uefi-vsstop-and-fbconsole-20261106.md`、`reports/uefi-onboard-walkthrough-20261106.md`、`PITFALLS #514–#516/#522–#524` |
| 2026-11-07 | **临时用户态基线补齐（G1-37）+ 内核配置补口** | 根因不是掉包而是「两张清单覆盖面差」：`apt-list.txt` 源自 Alpine `apk-world` + `--no-install-recommends`，不含 `sudo`/`locales`/ CJK 字体；处置 = 不引 `mobian-*/phosh-core` 元包，自建正交三件套（`daily-baseline.tsv`/`.sh` + `scripts/mobian-daily-baseline.sh`）。实测设备包数 **1355→1625**（全新增 0 删）、`sudo -n true` OK、`locale -a` 有 `zh_CN.utf8`、`fc-match …lang=zh-cn` = Noto Sans CJK SC（补前 zh 字体 = 0）；另补 `CONFIG_ZRAM=m`（原先 `zramswap` 每启 FAILED）。未收口 = 中文「组词上屏」需屏上点一次。`reports/mobian-daily-baseline-20261107.md` |
| 2026-11-07 | **内核重基到 stable `7.3.1` 并写入 `boot_b`（`vk185-adsp`）** | `v7.3.1` + payload replay + M1 DSI **零冲突**；上机全绿（DSI / WiFi / 声卡 / fastrpc + `qrtr svc 400` + SensorProxy 三项 true / `zram` 7.3 G）；新增一枚板 DT（ADSP fastrpc `qcom,non-secure-domain` = G1-34 在机真因）。用户放行后 `fastboot flash boot_b` + 设备侧 `dd` 读回逐字节一致（写前备份 `boot_b-before-vk185-20261107.img`），槽位 `retry=7 succ=1`；`reboot bootloader` 4 s 进 fastboot 复验通过。台账 `DEVICE/README.md` §1.1 |
| 2026-11-07 | **UEFI 间接引导首次交棒**（G1-29，全程零写盘；**当晚即撤回判定**，见同日后条） | p45 把崩点钉死 = **EB 之后复用缓存的 `BlkIo` 写盘**（`WriteBlocks` 读出 0 ⇒ `blr 0` ⇒ `pc=0`，与屏上 `x3=0x4000` 逐值吻合）；p46 删掉该转储 + `PreparePlatformHardware()` 双侧标记后**一发打通**：UEFI → `LinuxLoader` → `BootLinux` → 内核 `7.3.1` 真起来（`root=/dev/sda17`），启的是 ABL 启的同一份 `boot_b`、新增字节 0。决定性证据 = DDR 共享环 `0xE3F80000`（从 Linux 侧 `blackbox.ko` 读回）。性质纠正：`ExitBootServices()` 一直正常，p37 起的「EB 后立刻死」全是自家探针自杀。剩 BDS 菜单 / 绕开 `boot.img`。`reports/uefi-p46-kernel-boot-success-20261107.md`、`PITFALLS #546/#547` |
| 2026-11-07 | **上游：wl2868c binding v9 投出 + M10 ADSP DT 投出** | v9 = 落 Rob Herring 两点（YAML `>` 折叠块 / example 删固定 provider），3 封全 250（cover `<20261107015014.22374-1-…>`），patchwork devicetree 1/2 `needs-ack` + arm-msm 2/2 `new`；M10（`sm8750: ADSP fastrpc non-secure-domain`）1 封 250、patchwork 已摄取（`new`）。至此 **11-04 批的两条欠账（dwc3 2×High / wl2868c 2×changes-requested）全部还完**，我方无未答项 |
| 2026-11-07 | **⛔ 更正：「UEFI 间接引导打通」判定撤回；当晚 p58 以持久 logfs 重新打通** | 撤回理由 = 当时「内核起来」只有易失 DDR 环 + 主机 USB 事件，而后者连同型号机的 gadget 串都是常量 `HA2CB1KY` ⇒ 无法排除「跳转后复位、ABL 自己引导」（`PITFALLS #549`）。随后 p58 定死真因 = **`SdccDxe` 抢初始化 SD 主控**（内核接手后 `mmc0: ADMA error` ⇒ 硬复位），把 `APRIORI.inc`/`DXE.inc`/`DXE.dsc.inc` 三处同步摘掉后一发 `VERDICT=HANDOFF_TAGGED`（`/proc/cmdline` 带 `elden_bootpath=uefi`，桌面/WiFi/Waydroid/SD 卡全在）；`reports/uefi-p58-sdccdxe-handoff-success-20261107.md` |
| 2026-11-08（上午） | **ESP + GRUB 菜单起来了，但 EFI-stub 交接撞平台墙** | GPT 尾部**纯追加** 512 MiB ESP（`/dev/sda18 eldenesp`）+ GRUB standalone；屏照证明 `esp blk=120 / fs=8 / ld=Success` → GRUB 菜单可操作（音量上/下、电源键）→ 内核 PE 被装载（63.4 MB），随后 `DBI dump table info not found` + `App Log Flush` 即死；四条取证通道同时空（无 fbcon / gadget 未起 / ramoops 未注册 / `ConOut` no-op）⇒ 路线改 B。`reports/uefi-grub-esp-handoff-wall-20261108.md`、`PITFALLS #558` |
| 2026-11-08（下午/晚间） | **★ 路线 B 打通：ESP 上的 `boot.img` 由 Mu `LinuxLoader` 变体直接读起（零写盘）** | 判据三条全中（`verdict=ESPBOOT_TAGGED`）：`/proc/cmdline` 含 `elden_bootloader=esp`、`uname -r` = ESP 侧内核（`vk184-00002`，与 `boot_b` 的 `00003` 不同）、`boot_b` sha 未变。转折点 = 用 ESP 上的 `\loader.log` 定位到本树 `LinuxLoader.c` 把 `BootIntoFastboot` **写死 TRUE**（此前所有「ESP-first 失败」推断都建立在没执行的分支上）；`reports/uefi-espboot-r58b-success-20261108.md`、`PITFALLS #565–#567` |
| 2026-11-08（深夜） | **启动菜单闭环 + 落地第一发（写 `boot_a`）定位到新缺口** | 菜单（R60/r65）：屏显 + 音量上/下 + 电源确认，上机日志 `menu entry n 4 / key 2 / sel 1 / key 258 / boot \boot\boot2.img`；写 `boot_a` 一发证明 ABL 认这个件并跳过去，但 **flashed 形态 ESP 枚举不到（`fs=1` vs `fastboot boot` 形态 `8`）**，ABL 7 次后自动回 `boot_b`（无需救砖，`boot_a` 已回灌备份）；R62/p61 已构建待上机。`reports/uefi-persist-boot-a-20261108.md`、`reports/uefi-espboot-recursive-dump-rootcause-20261108.md` |
| 2026-11-09 | **zram 全链收口 + UEFI 世代/loader 可复现性收口（离线轮）** | 在机内核已有 `CONFIG_ZRAM=m`：`zramswap` active、`zram0` 7.3 G、`daily-baseline.sh --check` `MISS=0` ⇒ G1-37 该项无剩余动作（配置侧补开 LZ4 后端，`PITFALLS #573`）；`--gen p60/p61 --verify` 双 PASS（新增 `p6{0,1}-kept.sha256`）；loader 侧源码此前**只在 Mu 工作区**、不可再生 ⇒ 冻结为 `patches/uefi/20261109R65-loader-snapshot/`（`PITFALLS #574`） |
| 2026-11-09（晚） | **UEFI flashed 形态 4 发全败 + `p60` 对照同败；落盘信标 v1 废 / v2 可用但判不了「哪一发」** | 写 `boot_a` 四发（p63/p64/p65/p66）全部回退 `_b`；**`p60`（fastboot 形态已证明可用）同样失败** ⇒ 失败与补丁无关（`reports/uefi-p63-p66-beacon-20261109.md`）。信标 v1 按容量认分区撞到 8 MiB 的 `bluetooth_a/b` ⇒ 连已知可用的 fastboot 形态也 0 命中；v2 按内容指纹 `SBLOG0` 命中但**写入位置/内容固定** ⇒ `st=8` 不能区分是哪一发；`/dev/sde68` 跨启动不稳定（一次 logfs、一次 FAT12）⇒ 一律 `by-partlabel/logfs`。**口径撤回**：初版「fastboot 形态的内核是 FV `LinuxLoader` 的 espboot 起的（据信标 `st=8 fallback`）」**不成立** —— `st=8` 在 `if (!Found)` 之前是无条件检查点，且该发 logfs 记录区逐字节未变 ⇒ `LinuxLoader` 没参与、**R54 ESP-first 实为成功**（`reports/beacon-recheck-20261110.md` §命题 4、`PITFALLS #589`）。`PITFALLS #584/#585/#586/#587` |
| 2026-11-10（上机） | **p67 信标 v3：flashed 形态连 BdsDxe 都没跑到（旧口径被推翻）** | 同件两形态对照：`fastboot boot` 得 `s1…s5 + s9 esp-ld-ok`（R54 ESP-first 成功，顺带证伪「靠 LinuxLoader 兜住」）；写 `boot_a` 后**信标一字节未变**且读回内容无 `n=` ⇒ 该发没写任何信标 ⇒ 固件没执行到 BdsDxe，失败点在更早阶段（PrePi/dispatch/ABL）。下一步 = 信标搬进 BootShim/PrePi。`reports/uefi-p67-flash-trial-20261110.md`、坑 `#586/#587/#589/#590/#591`、设备已回滚 |
| 2026-11-10 | **11-09 晚那轮收口（原会话 23:29 被中断）：报告 + 坑 + 文档同步 + 世代入库** | 新增 `reports/uefi-p63-p66-beacon-20261109.md`（时间线/四条通道可用性/下发建议 `p67 = p62 + R66 + R67` 且信标带世代+计数）、`TASKS/sessions/2026-11-10-UEFI落盘信标收口p63-p66.md`；`patches/uefi/20261109R6{4,5,6,7}-*` 与 `p6{3,4,5,6}-recipe.txt` 入库；G1-29 单元格 4 939 B → 986 B（历史沿革下沉 `TASKS/sessions/2026-11-10-G1-29沿革.md`）；`scripts/lib-fastboot.sh` 入库。会话恢复用 `--gen p6x` |
---

## 2. 当前完成度（诚实版）

| 目标 | 状态（权威数字见 [`TASKS/README.md`](TASKS/README.md) §0） | 关键限定 |
|---|---|---|
| **G1** 功能健全的 Linux | 多数驱动已工作（暖起） | 按“驱动 bring-up 完整性”度量；**上游化 M 系列（以 `TASKS` §7 为准）进行中** |
| **G2** 安卓容器（Waydroid） | 主链路已通 | 图形/内核/GAPPS/代理可用，**容器传感器 HAL 已打通**、**容器音频已打通**（C6）、**C2 GMS 登录**、**C10 马达透传**（AIDL V2 + 固化 vendor.img）、**C11 触屏中文输入法**（squeekboard + fcitx5/Rime + OSK0）；Play Integrity/SafetyNet、Widevine 等级仍在收口 |
| **G3** x86 模拟（Steam） | **PoC ✅ / Steam 登录界面 ✅** | Box64 + Wine 成功；官方 ARM64 Steam 客户端 2026-10-28 起到登录界面（3/3 轮、证据 `reports/g3-steam-20261028.md`）、截图判据 10-29 闭环；Steam 游戏端到端（图形/音频/性能）未上机 |

---

## 3. 已验证可用的部分（有证据）

- **显示/图形**：暖起稳定出桌面（Phosh）；冷起有 `Q28` 竞态（见 §4）。
- **触屏**：Novatek NT36536（SPI）可用。
- **网络**：WiFi（WCN7861/ath12k）+ 蓝牙配对/TWS；USB-NCM 网卡（`192.168.7.1`）+ ACM 串口控制台。
- **音频**：WCD939x 播放 + 输入（**模拟麦接 WCD939x，非 DMIC**）走 QDSP6/ADSP。
- **相机**：后摄按需加载模块可出流并抓帧；容器侧已到 App 预览 `STREAMING`（`TASKS/README.md` C5/U7）。
- **安卓容器传感器**：加速/陀螺/光/磁/接近进容器；真值走 `ssccli`（Qualcomm SSC）→ UDP → 宿主 gbinder HAL（`TASKS/README.md` C4）。
- **安卓容器马达透传**：Waydroid HAL → 宿主桥 → `aw86927` 主线驱动；AIDL V2 幅度+cancel，固化进 `vendor.img`（`TASKS/README.md` C10、`reports/waydroid-haptics-20261013.md`）。
- **桌面用户态**：深色模式、亮度滑块、自动旋转磁贴、非整数缩放/刷新率（`TASKS/README.md` G1-26/27/28）。
- **温控**：分级 trips。
- **存储/启动**：持久磁盘根 + A/B 槽（`qbootctl`）+ 零写盘 `fastboot boot` 迭代。

证据位置：`reports/`（专题报告 + 会话台账）、`reports/trials/`（机器可读实验记录）、`logs/`（本机，未入库）。

---

## 4. 未解决的问题（含**被我们推翻的结论**）

> **本节的「当前口径」已上收：[`TASKS/README.md`](TASKS/README.md) §5（Q28/Q24）为准；此处只保留时间线与被推翻结论的诚实记录。**

### Q28 — 冷起显示间歇失败（**已规避·结项（2026-10-24）**：运营判断，非「已解决」）

- **当前口径（唯一入口）**：Q28 = **已规避·结项（2026-10-24，用户裁决不再补样本、不再挖根因）**；样本数、复启三条件与运营栈明细**只读** [`TASKS/README.md`](TASKS/README.md) §5 的 Q28 行，在机镜像只读 [`DEVICE/README.md`](DEVICE/README.md) §1.1；逐轮过程见本文 §1 时间线与 `reports/q28-*.md`。
- **现象与根因（长期事实，非进度）**：冷开机有概率只有背光、无画面，两种表现 = **NOCARD**（`card0` 没出现，更早的 probe 阶段失败）与 **STORM**；根因收窄 = bonded 双 DSI 的**首条 DCS 命令 `ff 20` 的命令 DMA 引擎 hang**（`STATUS0=0x20003`、`TRIG_DMA=0x1` 自不清），DPU 的 `ctl reset failure -22` / framebuffer 风暴是下游后果。
- **判据纪律（勿改）**：必须**三态**判定 + SSH 读全 dmesg + 查 `/sys/class/drm/card0`——只数风暴行数会把 NOCARD 误判成 GOOD，串口 logger 会漏 0–20 s 现场；**`reboot2` 暖复位会把状态"粘"成 NOCARD**，冷起结论不能用它取。

> **⚠️ 被推翻的结论（诚实记录）**：2026-10-10 夜我们曾得出「Q28 是**按内核二进制确定性**的、
> 不是冷/暖」这一逆转性结论，并一度写进 SSOT。次日**溯源审计否定了它**：
> 1. 那个「21 发」台账里**只有 7 发有原始日志**，其余是口头观测、`.img` 已删；
> 2. 所谓「内核二进制差 5,040,884 B(8%)」**主要是假象**——是 `LOCALVERSION` 版本串长度变化
>    导致的**整段 `.rodata` 平移 4 字节**（`.text` 仅 26 个 word 不同、全是地址立即数，无指令语义改变）；
> 3. 同一镜像在**同一路径**上就能跑出 GOOD→STORM→STORM→GOOD（**非确定性**），直接否掉“恒定复现”。
> 结论：原说法降级为「在 `reboot2` 暖路径上 vk64 亮、新编不亮，**真因未定**」。
> 过程稿见 `reports/q28-binary-determinism-provenance-20261010.md`。

### #106 — 亮屏进桌面后整机卡死（未解决）

- **现象**：显示正常起来后数秒，**整机冻结**：无 panic、SSH/ping/USB/fastboot 全失，只能物理断电。
- **边界**：APSS **硬看门狗被永久禁用** ⇒ 永不自复位；只有“冷断电”能恢复 ⇒ ramoops 也随之丢失，
  **至今一栈未获**。纯 RAM initramfs 不启桌面，故不受影响。
- **2026-10-10 新增观测**：本仓库的对照实验显示它与**“干净的 GOOD 显示”强相关**——
  相同的 `fastboot boot`，`storm=0` 的干净 GOOD **2/2 在数秒内打死**；`storm>0` 的 STORM **4/4 存活**；
  NOCARD 存活。也就是**“有 card0”不等于“能用”**，判定 GOOD 必须带**存活门**。
- **对历史结论的影响**：我们无法确认历史上所有被记为 `GOOD` 的样本都是真 GOOD——
  早期判据是二值的（有 `card0`=GOOD），会把「STORM 存活」和「亮一下就死」混在一起。
  但**也不能说它们全是 hang**：既有反例（`card0`+风暴的样本存活 >226 s），且当时循环能连续进行也说明多数不是 hang。

### Q24 — 熄屏 × 相机（已裁决规避；2026-10-12 重开调查）

单模块 `cambistmclkcc-sm8750` 与 DT 电源域冲突，相机常驻会在熄屏时掉电。**用户裁决**：
日常**零相机模块**，需要相机时显式加载。根治变体未完成。

**2026-10-12 重开轮（1–7 轮）的结论**（逐轮数据 = 本文 §1 时间线 2026-10-12 各行与 `reports/q24-*.md`，本节不再复述轮次）：旧「死前共同签名」被 `PITFALLS #197` 否定（不熄屏、设备存活时同样出现）；最小触发 = `{camcc, cambistmclkcc}` **配对** + 真实熄屏——第 4 轮 C 系列：**C0/C1 存活 +89 s、C2（配对）熄屏 3 s 内静默硬复位**，且三相位熄屏末票逐字相同 ⇒ **票不区分死/活**；H1 DT 臂（恢复上游 `MMCX+MX`）**否证**「DT 电源域绑定是死因/解」、第 7 轮**否证** GPU runtime-resume、NoC/BCM 靶亦已否证（`#210`），dispcc 靶当前无手段 ⇒ 靶点转电气/时序级。实验纪律（屏真关硬门、A/B 起点必须物理 POR、判活窗口 ≥60 s、串口持续读）见 `PITFALLS #197/#198/#208/#209/#210`。**当前口径（含 2026-10-23 指名根因并停止采样）只读 [`TASKS/README.md`](TASKS/README.md) §5 的 Q24 行**；**运营口径不变**：相机 ⇄ 熄屏互斥（日常零相机模块）。

### 构建/身份事故（已修复并入流程）

- `vk81/82/83` 因 `make olddefconfig` 抹掉 `ARCH_QCOM` → 编出**无 QCOM 驱动的死内核**且当时未察觉，
  其上的上机结果**全部作废**。已加编后符号守卫（`gcc_sm8750`/`msm_dsi_host_bonded_cmd_trigger`/`rpmh`）。
- `vk87/88` 名字与载荷对不上（`Image.gz` 陈旧未重编）→ 已删除、加打包前内核身份硬门。
- **版本号纪律**：`vkN` 是「构建/载具号」不是内核版本；内核身份唯一判据 = 镜像内核载荷的 sha256。

---

## 5. 方法 / 资产

- **版本号台账**：`versions/`（registry / 内核身份表 / manifest 指纹）。
- **实验记录**：`reports/trials/`（JSON + `index.tsv`），每发落盘、可事后复核。
- **取证脚本**：`scripts/q28-devprobe.sh`（三态）、`scripts/trial.sh`（闸门+记录）、
  `scripts/gui-freeze-watch.sh`（#106）、`scripts/check-doctor.sh`（仓库自检）。
- **分界线**：内核树以 `clean/base`（= `d02658e63`）为唯一功能基线，其上为实验层。

---

## 6. 下一步（按优先级）

> **2026-10-23 起的工作纪律（用户定）**：**需要物理 POR 的样本一律排最后**；**TF 卡（G1-6）暂时不做**；
> **Q28 补采样已完成（2026-10-24 收口）**：按「已规避」结项，原定 ≥8 发门槛**用户裁决不补**。权威口径 = [`TASKS/README.md`](TASKS/README.md) §4。

1. **★UEFI 与 Gunyah 考查**（2026-10-24 用户定的下一步；只读优先、不写盘）：基线 = `reports/uefi-restart-20261021.md`、
   `reports/gunyah-roadmap-20261021.md`。UEFI：~~逆向运行期注册表 + 回帖 issue #12~~（2026-11-10 起改为只读 `TASKS/README.md` §1 G1-29 行与 §5「2026-11-09（晚，p63→p66）」块）；
   Gunyah：阶段 0 零成本探测 + 上游现状复核。产出 = 各项「可不可重启 / 立不立项」定性 + 最小成本账。
   **2026-10-24 用户裁决：WoaA 走纯 Linux（Gunyah 自建栈），Android/AVF 只作材料参考，最终不保留 Android 分区**（详见 `TASKS` §4 N1/N2）。**首轮已出（`reports/uefi-gunyah-reassess-20261024.md`）**：
   UEFI（G1-29）：**路线 A 首轮（2026-10-05）失败后搁置 → 2026-11-01 用户放行恢复推进**；当前口径与四臂判别只读 `TASKS/README.md` §5。~~厂商 DXE 在 XBL 打包体里~~（**2026-10-24 已作废：厂商 UFSDxe 就在 `uefi.elf` 内嵌 FV 中**，见 `TASKS` §4 N1 纠正块）；**Gunyah 阶段 0/0b 阳性**
   （`gunyah-wdt` 在 + 自编 `gunyah_wdt.ko` probe 通 ⇒ 本机确实在 Gunyah 下且 SMCCC 通道可用，`reports/gunyah-stage0-positive-20261024.md`）。
   **★2026-10-25 终局：Gunyah 子 VM 结项 = 不可行（用户定 C）** —— RM 建 VM 恒 `VM_INIT 0xA MEM_INVALID`，
   对 DTB/内存模型（含整块急切 LEND）/驱动代次（6.6、6.12、厂商内核同 harness）全不敏感；厂商可用路径依赖主线没有的
   `MEM_DONATE(0x51000010)` + `gunyah_loader` hypercall 族。⇒ **G2 回 Waydroid**；`drivers/virt/gunyah` 6.12 分层只作 G1 补丁素材封存。
   权威 = `reports/gunyah-decision-20261025.md`；过程 = `reports/gunyah-612-samebuild-20261025.md`；新坑 `PITFALLS #395/#396`。
2. **Q28/Q32**：✅ **已结项（2026-10-24）=「已规避」** —— 运营线 vk152 线上 **8/8 无坏发**（真 POR 5/5 + 暖复位 3/3），
   看门狗与三态探针在役；**不补样本、不挖根因**，复启条件只读 `TASKS/README.md` §5 Q28。
3. **Q24**：⛔ **关闭（2026-10-24 用户裁决：不值得取证）** —— 根因已指名（7.2 缺上游 `skip retention by default`，7.3 自带），
   `vk149` 臂复现**取消**；日常仍执行 `cam-mode.sh on/off` 互斥（安全策略，非既成事实）。
4. **#106**：判据「GOOD 需 ≥60 s 存活/可交互」；ramoops 装弹已在位等它自己撞（见 `TASKS` §5 §2 表）。
5. **上游化 M 系列（以 `TASKS` §7 为准）**：M1 树与 `m1-73/baseline` 已收敛；M3-1 v4 / v5 系列、M4 camss（v2 0/2）、M4-1 bindings、M6 L1、M8 RFC、wl2868c v3 均已投并归档；
   **2026-10-27 新增可评审分片**：B5 第 1–3 步（bonded-DSI 收进 per-SoC cfg + 2 个 host ops，`patches/local/b5-resoc-20261027/`）与 aw86927 五提交系列（`patches/upstream/aw86927-20261027-v2/`）均已过门禁；aw86927 v2 **已投**（`[PATCH 0/5]`，`/linux-input/` 6/6 归档）、M1-U6 与 M2 A2 同批已投；
   **2026-10-27 夜**：B5 **第 1–3 步已零写盘上机 = 行为中性**（7 项计数全 0）、**第 4 步已实现并上机**（同值臂中性；判别臂 `master=DSI1` ⇒ 面板 DCS `ff 20` 三连 `-22` ⇒ **主从角色不可自由换**，字段降级为事实登记）⇒ 见 `reports/b5-step4-master-from-cfg-20261027.md`；
   投递前待办：① B5 的表挂在 `sm8650_dsi_cfg` 上（需拆独立 SM8750 表项）；② 第 4 步投递前把「调用者必须是 master」做成显式检查（当前只返回 `-22`）；
   **2026-10-26 新增热验证通道**：日常线载荷驱动已模块化（`vk163`），叶驱动（触屏/背光/触觉/音频/无线）改一次 = `mod-loop` 秒级上机验证，不用整机重启；
   **2026-10-27 该通道已可信**：`mod-loop.sh` 原先会在模块没换时假报成功（`PITFALLS #447`），现以 **build-id 校验**作唯一成功判据，失败非零退出；
   M3-2 台账 / M3-3 音频 / M3-4 显示 / M4 camss 均备料封存（投递冻结，收盘统一投）。
6. **G2**：容器相机 **HAL 侧缺陷已闭环（2026-10-29 修法上机，12 请求/0 崩溃/12 次布局修复）**，只剩 **容器图形层（surfaceflinger `Unable to generate SkImage` 自杀）+ App 端请求停止**；C3 身份/DRM 取证（PI 检测 App 需 APK 侧载）。
7. **G3**：Steam 端到端。
8. **★2026-10-28 收盘：三项已收掉**（不再列待办）：**G1-34 传感器两棵根全绿**（udev `ssc-accel` + ordering cycle，`PITFALLS #451/#453`）、**Q34 蓝牙 = 缺 `qca/tmel_peach_20.elf`**（`PITFALLS #454`，已加门禁 A2「驱动 `MODULE_FIRMWARE` 必须进包」）、**B5 第 1–4 步上机**（见上）。⇒ 当前真开放项只剩：M4-2…4 **已投递并复核**（`[PATCH 0/9]` 10 封 250，lore `/all/` 10/10，raw 重放 9/9 逐字节一致）、~~B5 第 5 步隔离层~~（**2026-10-28 解阻**：`0x44440400` 全位有上游符号、`ERR_INT_MASK0` 按厂商行为写明，patch 已落地且 `.text` 逐字节等价）、~~U2 原子回调时序~~（**2026-10-28 已证并关闭**：8 项原文判据全 PASS，现形状即上游形状）、UEFI issue #12 回帖（等你点头）、C5/U7 容器相机（**2026-10-28 推进**：无需装 APK，真卡点 = 容器 external HAL 静态元数据为空）、G3 Steam；**掉电率按用户指示最低优先、不排期**。

---

## 7. 协作方式说明

本项目由**人类研究者 + AI 编码代理**协作推进（代理行为规范见 [`.pi/AGENT-OPS.md`](.pi/AGENT-OPS.md)）。
**纪律**：worker（子代理）只报「命令 + 原始日志」，**编排者必须独立复跑**；
结论先过“证据是否可复现”，再进 SSOT。上面 §4 中那两条被推翻的结论，正是这条纪律起作用的结果。
