# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：**§0（现在一页）→ §2「入口阶梯」**（含时间序权重）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录 = 入口 `INDEX.md` + 项目身份 `AGENTS.md` + 公开 `README`/`PROGRESS`（**公开门面，agent 默认不读**），**7 个角度文件夹**（`DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/`），各自 `README.md`（策展 SSOT）+ `sessions/`（会话进度）；标准见 §2。
> 2026-10-03：git 纳管 + 文档收敛（12→6）；自检 `scripts/check-doctor.sh`；不再有 SQLite/生成物。

---

## 0. 现在一页（**唯一的状态入口**；核对日期：2026-11-20）

> 新会话**只读本节**就知道「做到哪、卡什么、下一步」。三行都有日期 + 证据指针；
> 与其它文档冲突时**以本节为准**，冲突处按 §2「时间序裁决」处理（旧说法标作废或直接删）。
> 数字口径：完成度以 `TASKS/README.md` §0（脚本 `scripts/check-progress-counts.sh --tsv` 现出）为准，本节只摘结论。

**做到哪**

0. **🆕 2026-11-20 11:xx（主机）—— 进度整理轮：4 条 lane 产出落盘、A 档回收 8.1 GB、新增 out/ 造件门禁；**设备现离线（需人项插线+上电）**
   - **全账** = `.pi/plans/2026-11-20-进度整理与待办规划.md`（现态实测 + 4 lane 产出 + 排好序的待办 + 4 条待拍板）。
   - **主机侧已落地**：① A 档回收 **8124 MB**（`out/` 87→75 G）；② `check-doctor` **§23 out/ 造件账本门**（`scripts/out-manifest-check.py` + `scripts/out-manifest-exempt.tsv`，含空理由豁免必 FAIL 的反作弊与 4 类 selftest）；③ 上游现查一页账 `reports/upstream-recheck-20261120.md`（**§7 台账落后 1–2 代**：wl2868c 已 v12、dwc3 已 v9 且 Rob Herring 11-18 回「??」、elden DTS v7、fastrpc v3、M8 现役 = mdss block-resets 3 枚），`TASKS §7` 头已加增量块；④ v3 上机执行包 `scripts/android-v3-bringup-walkthrough.sh`（`--dry-run` 默认，父代理复跑 `--verify` 7 件全过）+ `reports/android-v3-bringup-packet-20261120.md`；⑤ arch-audit P1#3 收尾：`scripts/README.md` 生成索引（334 入口）挂 `check-doctor` **§24 新鲜度门**（`gen-scripts-index.py --check` + 删行反作弊，只进全量档，设计/验证 = `reports/scripts-index-gate-20261120.md`）。
   - **四个新硬阻塞**：原厂 `boot.img` = **header v4** 而 `boot-img-cmdline.py` 只支持 v2（⇒ S5 的 `console=ttyGS0` 取证件造不出来）· `qbootctl -a` 是只读查询（设 active = `-s SLOT`）· `metadata` 起点 = **5857704** · **页缓存污染让 buffered sha256「稳定但错」**（v1 件 `637a9965…` vs O_DIRECT `e3d0d26f…`）⇒ 硬门必须 O_DIRECT。
   - **设备现态 = offline**（无 `05c6/18d1` 枚举、`fastboot devices` 空、无 `/dev/ttyACM*`）；**`ping 192.168.7.1` 是假阳性**（走手机热点网关）——判在线只看 `DEVICE/README.md` §1.6 五条。需人项：插线 + 上电 → `sudo scripts/ncm-host-up.sh`。
   - **主机稳定性（规则 12，不深挖）**：本机 10:17/10:27 两次 Pi 子进程 SIGSEGV（MCE=0）、页缓存 sha 漂移、盘上 super 位翻转；证据已交 `~/hw-stability/evidence/inbox/20261120-y700-elden-{pi-child-upstream-lane-segv,pagecache-sha-drift}/`。
0. **🆕 2026-11-19 22:5x（U2 HA2EXB0E）—— 掉电链定因 + 设备已回「最优 Linux 模式」；全仓 8 代理审计产出落 `reports/audit-20261119/`**
   - **掉电链（新坑 #694）**：22:0x–22:36 连续 3 次「进 Phosh 锁屏即整机掉电」。取证 = 每次 boot 的持久日志只到启动后第 1 秒（≈928 行）就断 ⇒ **硬挂不是优雅关机**（无 `final.target`/`System is powering off`）。定因分层：① **已证实** live 系统上 `systemctl disable --now droid-juicer` ⇒ ~40 s 掉电（#693 同族，**禁止再在 live 上停这两件**）；② **高置信未单变量** = droid-juicer 落盘 mask 后顶上来的 `hexagonrpcd`（#692 attach ADSP 硬崩）。
   - **新机制（可复用）**：`scripts/boot-img-cmdline.py --append "systemd.mask=…"` 造 **零写盘救援舱** → `fastboot boot` 进系统 → 只做 `systemctl mask` 落盘 → 正常 reboot。本次 45 s 到 SSH、`graphical.target` active、无 failed unit。全文 `PITFALLS/sessions/326-掉电链定因与systemd.mask救援舱.md`（索引行 #694）。
   - **现态（22:37 起实测）**：`boot_b` 持久启动 / `elden_root=LABEL=linux` / `/dev/sda17` 190 G 用 6.2 G / **greetd+phoc+phosh+phosh-osk-stub 四进程** / Mesa **26.1.6** / **wlan0 = ustcnet 114.214.230.246，默认路由经 wlan0**（`usb0` 192.168.7.1 保留 SSH）/ 时钟正确 / `scripts/deploy-desktop-shell.sh --check` = **MISS=0**。
   - **安卓分区零改动**：`super` 22 G、`userdata` 256.7 G、`metadata` 64 M、`boot_a` 原样（`lsblk PARTLABEL` 复核）；六件 mask = droid-juicer + plymouth×4 + hexagonrpcd（`/etc/systemd/system/*.service -> /dev/null`）。
   - **审计产出（8 代理只读）**：总入口 `reports/audit-20261119/README.md`；`A1-phase-timeline.md`（阶段突破/卡点）、`A2-best-state.md`（最优进度+复现）、`A3-*`（344 脚本分类）、`A4-*`（29 条文档问题+三批顺序）、`A5-forks.md`（14 分叉点）、`A6-*`（152 G 资产批次）、`A7-hygiene.md`、`A8-device-state.md`。**已执行** = 删 2.44 G 构建 scratch（`out/stage-*`）+ 重生成 `reports/README.md`（564 篇/147 组），其余为清单。
   - **遗留（需拍板）**：A6 批次 2/3（~34 G 归档 + ~20 G 中间物）、A4 批二/批三（文档合并/归档）、A3 的 9 项证据型脚本归档、PITFALLS 跳号 159 个人工判。
0. **🆕 2026-11-19 21:5x（U2 HA2EXB0E）—— 共存契约已冻结、安卓 v3 已造件并写入；**上机 3 发均未进桌面，其中 2 发被 BCB 污染；设备现居 Linux（可用）**
   - **共存契约（新，正文 `DEVICE/README.md` §1.7）**：Android = `super 90504..5857671` + `userdata 5972392..73277434`；Linux = `linux17 73277435..123871226` + `boot_b`。
     现场 EDL 读回主表 16 条目**两两不重叠**、无旧破坏设计的单 `linux` 分区 ⇒ `scripts/android-linux-coexist-check.py` rc=0。**实测共存：刷安卓 3 次，Linux 全程可登**（`/` = `/dev/sda17`）。
   - **v3 镜像**：`out/android-slim-v3-20261119/new/`（`system_a.img` **3920 MiB**、`super_min_v3.img` **7109 MiB**；v1 是 5296/8481.5）。
     删全部 41 个预装池目录 + `etc/AI` + `bgmusic` + 18 个无用 leaf 包；**空目录占位 + launcher.db 47→15 行 + 空目录 selinux 标签**三件同办。
   - **上机**：① v3 首启 → 卡 ZUXOS 动画（唯一有效 Android 失败样本）② wipe 后 + adb 免授权件 → 卡 logo 后掉电 ③ 回刷 v1（读回 `e3d0d26f…`）= 同样。
     **现场复核**：`logfs` 每条 a 槽启动都到 `Shutting Down UEFI Boot Services`（≈13.3 s）⇒ ABL 清白；`pstoredump` 无 panic；电池 82%/Charging；
     **`misc` BCB = `boot-recovery`**（EDL 后是 `bootonce-bootloader`）⇒ 后两发很可能是启 recovery，**不算 Android 失败**。
   - **下轮纪律**：清 BCB → 读回校验 → 再 reset；顺序 S1 清 BCB+`qbootctl -a` → S2 原厂 `metadata.img` → S3 原厂 `super` 对照 → S4 二分 v2b → S5 带 `console=ttyGS0` 的 boot 件拿日志。KSU 仍不并入。
   - 全账 = `reports/android-slim-v3-20261119.md` + `TASKS/sessions/2026-11-19-安卓共存契约与v3精简上机.md`；脚本 = `scripts/android-slim-v3-build.sh`。
0. **🆕 2026-11-19 13:20（U2 HA2EXB0E）—— 桌面起来了（Phosh 锁屏，GPU 渲染），全链固化成脚本 + 手册**
   - **链路（全部实测，逐环有判据）**：fastboot 起机 → `resize2fs` **6.25 GB → 190 GiB** → 设备上外网（主机 NAT + 自愈路由 + DNS 上游）→
     时钟冷起自愈（`chronyd -q` step 1.9e7 s）→ 日用基线 **49 包**（`MISS=21→1`）→ greetd+phoc+phosh **三进程**、锁屏截图有顶栏/中文 →
     **Mesa 26.1.6（trixie-backports）= `Adreno (TM) 830` / GLES 3.2**，`glmark2-es2` **Score 2594**。
   - **两个新铲子**：`scripts/deploy-desktop-shell.sh`（9 步幂等自检，`--check` → MISS=0；含包集/用户/greetd appliance/软合成开关/
     usb0 自愈路由/GPU devfreq 固化/会话三进程+截图字节门）、`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`（S1–S12 + 速查 + 回退 + 溯源表）。
   - **五个静默失败**（`PITFALLS` #681–#685）：根缺 `udev`（模块零加载）· phosh 必需 `sm.puri.OSK0` · 老 Mesa 不认 Adreno 830
     （pixman 能起但**帧率低**，需 backports Mesa）· RTC 只读且冷起给「镜像构建日 2026-04-13」（日期阈值判据失效）· usb0 无默认网关且主机地址随 gadget 重建消失。
   - **卡点（需人）**：内核未开 `CONFIG_INPUT_UINPUT`（无 `/dev/uinput`）⇒ 锁屏**必须人手滑开**，agent 无法注入触摸做桌面内验证。
   - 全账 = `TASKS/sessions/2026-11-19-EDL到桌面端到端重建.md`。
0. **🆕 2026-11-19 下午（U2 HA2EXB0E，压过下面深夜条）—— 显示修复 = minbase 缺 udev；屏幕出字；槽位 successful 收口**
   - **真因（单变量证据）**：minbase 根**没装 udev** ⇒ `systemd-udevd` 不存在 ⇒ 模块零自动加载 ⇒
     fastrpc/ath12k/音频链全缺 ⇒ DP 组件 defer 拖死 DPU 聚合（11-19 上午/深夜的「显示挂死」全是下游症状）。
   - **修复 + 判据**：主机 NAT（正确出口 = 手机热点 `enx027644563e50`，第一发误加 eno1 由 tcpdump 定位）+ 设备时钟修正
     （2026-04-13 → 现时，TLS 才通）+ `apt install udev` + `enable --now systemd-udevd` ⇒ `modprobe fastrpc` 后
     `/dev/fastrpc-adsp` 出现；ath12k 早启 `-110` = 时序问题，PCI rescan 即复活 ⇒ 固化 `ath12k-rescan.service`（已 enable）。
   - **控制实验（决定性）**：`fastboot reboot` 走持久 `boot_b`（= 上午控制件 `740d431b…`，内核/DTB 零改动）⇒
     **DPU aggregate + DSI×2 + DP + GPU 全 bound**、`/dev/dri/card0` + fb0 1904×3040 + fbcon、音频卡出、**屏幕有字（用户目视）**。
     ⇒ 上午的 nodp DTB 实验**不需要**（DP 不用摘），件留档勿用。
   - **槽位收口**：设备无 python3 ⇒ dd LUN4 主备 GPT → 主机 `slot-attr.py --image` 打补丁（`boot_b` 0x3f→0x7f）→ 写回读回一致
     ⇒ **`fastboot getvar slot-successful:b` = yes**（unbootable=no、retry=7）；件 = `reports/artifacts/slotattr-20261119/`。
   - ~~**遗留小项**：设备 RTC 不保持（重启回 4-13）；wlan0 DOWN 待连网；Phosh 桌面未起~~ **三项均已处置（2026-11-19 13:20，见上条）**：时钟 = `time-sync.sh` 修 + 路由就位补跑；网络 = 自愈路由 + DNS 上游；桌面 = greetd/phoc/phosh 起来（GPU 渲染）。
   - 全账 = `TASKS/sessions/2026-11-19-显示修复=minbase缺udev.md`（+ 上篇 `…-显示nodp实验与RAM路径复核.md`：
     11-18 两次 RAM 启动失败真因 = cmdline 根标签 `linux17` vs 实际 `linux`，RAM 路径本身是好的）。
0. **🆕 2026-11-19 深夜（U2 HA2EXB0E）—— 主线 Linux 已重建到「能登入」；~~显示仍缺~~（已于同日下午修复，见上条）；安卓面零改动**
   - **旧 `linux17` 数据确认丢失**：EDL 只读采样 6 点（起点 73277435 及 +10/+50/+134/+275/+359 GiB）非零字节 **全 0**；
     成因 = 11-17/18 恢复原厂时 stock `userdata`(449.7 GiB) 覆盖该区间（`fastboot -w` 再把它 discard 成零）。
   - **已重建（都过读回校验）**：LUN0 GPT 写回手术表（`linux17` 193 GiB + `userdata` 256.7 GiB，主备 `80ab46e5…`/`e5f79c0e…`；
     **`super`/`vbmeta_system`/`boot_a`/`dtbo_a` 未动 ⇒ 安卓装机测试面保留**）；LUN0 `73277435` 写 6 GiB 最小 Debian 根（设备端 sha `abf96ec4…`）；
     `boot_b` = 同 vk192 核/DTB/initrd、仅 cmdline 改 `elden_root=LABEL=linux` 的自签件（读回 `740d431b…`）。
   - **现态**：`ssh root@192.168.7.1`（需先 `sudo scripts/ncm-host-up.sh`）/ systemd PID1 / 内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` / **当时 165 包** / **当时 `/` 2.0 of 5.9 GiB**（数字均为当晚快照；今日现态 = 1253 包 / `/` 190 GiB 且桌面已起，见上条）。
   - **显示仍缺，根因已定界**：`device_component/ae01000.display-controller` = `aggregate not bound`，`ae94000/ae96000.dsi` not bound，
     `(unknown)×2` not registered；`af54000.displayport-controller` 在 `devices_deferred`（`aux_bridge: failed to acquire drm_bridge`）
     ⇒ **DP 组件拖死 DPU master**。同批失败：`ath12k` MHI `-110`、无 `/dev/fastrpc-adsp`、音频卡 deferred。
   - **明早接续**：① 上电 → `scripts/ncm-host-up.sh` → ssh 验活 + `slot-attr.py mark-successful b`；② 显示实验（`out/min-restore-20261119/dp-port2-experiment.patch`）；
     ③ 桌面 = `resize2fs` + `daily-baseline`。全账 / 待办 = `TASKS/README.md` §4 首条 + `TASKS/sessions/2026-11-19-主线恢复最小Linux与显示定位.md`。
   - **设备可用性（压过历史「等送修」口径）**：**不需要送修、无硬件故障证据** —— 「ABL 内存类硬件故障 / 全原厂态仍失败 ⇒ 等送修」已于 **2026-11-19 正式作废**
     （真因 = 非原厂 GPT，11-17 19:2x 单变量定因；20:0x 完整起 Android 16、11-18 最小安卓包、11-19 本最小根 = 三次真实上机）。
     2026-11-19 19:xx 实测设备**未连接**（`lsusb` 无 `05c6:*`/`18d1:*`、`fastboot devices` 空、`adb` 只有 P40pro `MDX5T20730009849` 与 `emulator-5554`）⇒ **离线 ≠ 坏机**。
     在线确认 5 条命令 / 判读规则 / 人项动作 = `DEVICE/README.md` **§1.6**；新旧口径对照表 = `reports/device-status-20261119.md`。
   - 历史（11-18）：`super_min` 上机成功（8.28 GiB、`/system` 5.0 GiB）但 wipe 后卡 ZUXOS 动画（未取证）。

0. **🆕 2026-11-18 小时级状态（U2 HA2EXB0E）—— 精简安卓包已上机成功；当前在 fastboot，未结「卡 ZUXOS 动画」**
   - **已做成（有判据）**：清 `boot_a` UNBOOTABLE（`fastboot --set-active=a`：`yes→no`、retry `6→7`，实测坐实 #677）→ 刷回原厂 `boot_a` 起 Android；
     刷自签 `vbmeta_a_flags1`（`419e01ac…`，Flags=1）→ `ro.boot.veritymode=**disabled**`；**EDL 写 `super_min.img` 8.28 GiB @42.2 MiB/s，
     设备端 `qdl sha256` = 主机 sha（`e3d0d26f…`）→ 连续两发 `boot_completed=1`**；`/system` 从 11.43 GiB → **5.0 GiB**，
     `/system/preinstall`、`/system/etc/AI` 已不存在。
   - **未结**：`fastboot -w` 后 adbd 报 `Could not set SELinux context` 崩溃 → 用户在 recovery 做 factory reset → 联想 logo **~72 s**（正常值，#679）
     → **卡在 ZUXOS 动画**（>10 min）。当前槽属性 `a: unbootable=no/successful=yes/retry=6`（未被再标）。候选原因 =
     「`/data` 与删掉预装池的精简 system 不一致 / factory reset 触发 ZUI 重新格式化」，**尚未取证**。
   - **已登记的 4 条待办**（本次只记不做）：① 干净瘦身镜像（连桌面「预装占位」来源一起处理）；② **KernelSU 修补版 boot**（GKI LKM：magiskboot + `kernelsu.ko` + avbtool 重签）；
     ③ 卡动画取证（recovery logcat / ttyGS0）；④ 设备恢复可用。全账 = `TASKS/sessions/2026-11-18-安卓最小包上机成功与卡动画.md`。
   - 历史（11-17～11-18 上午）：11-17 20:0x 曾恢复原厂 Android 完整启动；11-18 上午「试装最小包 3 发全败」的真因 = `boot_a` 被标 UNBOOTABLE
     （#672），不是镜像问题——当天 19:0x 清标志后**一次通过**，该结论已闭环。`super`/`vbmeta` 回滚件与 GPT 双表 dump 见
     `backup/HA2EXB0E-16+512/edl-20261118/`、`out/edl-supermin-20261118/`。
   - **Linux 侧现状（不变）**：`linux17`/`eldenesp` 条目与槽镜像/ESP 已被原厂件覆盖，但 `linux17` 的 ext4 数据物理保留在 LBA `73277435`（192 GiB）；
     重建路径 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md`。取证/时间线 = `reports/bl-stuck-20261118-forensics.md` §7；自检 = `bash scripts/linux-state-audit.sh --host`。

1. **G1 = 36/37**（2026-11-17 脚本现查；`❌` 仅 `G1-10` 无 NFC 硬件、`G1-30` 与 G1-29 同路线）。**在机 ≠ vk192（2026-11-17 20:0x 起跑原厂 Android，见本节 0 条）**；`vk192` 现为**回退件**（`bootslot-b/boot_b.img` 自签 `06c081ca…`、空载件 `out/boot-elden-vk192.img` `bdf47f5f…`，UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）。
   以下为该版（2026-11-16）**历史判据**：slot `_b` Active/Successful/Bootable 全 1、重启实测回 vk192；模块树 1510 `.ko` 已按新 UTS 部署。
   判据全绿 = DSI `bound ae94000.dsi`+fb0 / WiFi `wlp1s0` UP / `/dev/fastrpc-adsp`+qrtr 400 / SensorProxy 三项 true / Waydroid+zramswap / **s2idle 3/3（fail=0）**。
   本版内容 = **pstore/ram 守卫**（拒绝与 initrd 重叠的 ramoops zone，上游已投 3×250）。→ `DEVICE/README.md` §1.1 首条、`reports/device-session-20261116-vk192.md`；
   前代 vk191（RAM 启动，kernel/dtb 同 vk190）沿革 → `reports/device-session-20261113-vk191.md`。
2. **G2 = 10/13**（Waydroid 主链 + 传感器/音频/GMS/马达/输入法/相机 STREAMING 都通）；**C3 Play Integrity 已实测收口（2026-11-15，SPIC v1.4.0 一次回包）**：`deviceRecognitionVerdict = []` ⇒ **BASIC/DEVICE/STRONG 三档全部不满足**，与书面判读（无 TEE、keymaster 软实现 ⇒ STRONG 结构性不可能）一致、未被推翻；PIF 伪装未做。剩 **C5 App 实开预览 / C8 立项 / C9 打分表**。→ `reports/c3-spic-verdict-20261115.md`、`reports/c3-pi-tiers-closeout-20261110.md`。
3. **G3 = Steam 登录界面 ✅**（2026-10-28 设备实测 3/3，截图判据 10-29 闭环），游戏端到端未做。→ `reports/g3-steam-20261028.md`。
4. **拓展：UEFI 两种形态都通**（2026-11-10 深夜定案：flashed 失败真根因 = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我们的 DTB，清 `dtbo_a` 即通；2026-11-14 夜第 2 轮间接形态也通，判据 = cmdline `androidboot.serialno=51318dc0` 且无 ABL 追加 token，14 s 到 SSH、零写盘）；Gunyah = 有条件重启、非主线。11-14 首轮复测的三次崩溃**不是固件问题**，是主机侧 USB 被隔壁项目 13 个孤儿 `fastboot` 抢走（`PITFALLS #658`）。
   **GRUB 路径断点已在 2026-11-15 夜定案**：Mu UEFI 把 initrd buffer 分配进 DTB 的 `ramoops@c2000000`（8 MB `no-map`），内核 `t=0.0269 s` 就把它注册成 printk 控制台 ⇒ 每行 console 写进那 8 MB ⇒ initrd 被内核自己覆盖 ⇒ 解包 ~120 ms `broken padding`；A/B 单变量（只删 ramoops 节点）= 起进 SSH 32 s、`sum=0x5c53688e` = 主机期望值。修法优先级 = 内核 `pstore/ram` 拒绝重叠 zone（可上游）> GRUB 先占位 > 挪 ramoops。→ `reports/uefi-dtbo-a-rootcause-20261110.md`、`reports/uefi-grub-initrd-rootcause-20261115.md`（§5 另列两条修法）、复现件 `patches/local/uefi-initrd-probe-20261115/`、`PITFALLS #665/#666`、`TASKS` §5 沿革索引「2026-11-10 / 11-15」行。
5. **桌面层两回归已闭环（2026-11-14 晚）**：**T20 电源键短按不熄屏**根因 = `zwlr_output_power_v1` 每屏只许一个请求者，phosh 的第二个请求被 `send_failed` 且资源被销毁 ⇒ `power_mode` 停在 `OFF` ⇒ 屏保管理器 `active` 恒 TRUE、press/release 双短路；修 = phoc（wlroots 放行多请求者）+ phosh（failed 回退为 ON）两枚自编件，已上机验收（短按熄屏/再按亮屏、长按菜单正常）。**T19 撕裂**仍停在「根因层 = 带 modifier 的 dmabuf 导入已锁定、缺 mesa 26.2.5 A/B」。
   → `TASKS/sessions/2026-11-14-T20-电源键不熄屏.md` §7、`PITFALLS` #371、`scripts/{phoc,phosh}-install.sh`
6. **上游**（2026-11-17 更新）：**mdss v5 已发**（答 sashiko `0xa000` 独立域质疑，3/3 只收窄 message）、**wl2868c v11 已发**、**dsi/phy v2 已发**（11-16 22:50/23:03 两发 `250`；`/linux-arm-msm/`+`/linux-kernel/`+`/dri-devel/` 三处归档、正文字节一致；错前缀那封由第二封自述）；dwc3 v9 / gamma v2 / haptics v2 / board DTS 单提交 = **备料在档、等批准**；**唯一在档未发 = Q28 证据回帖**（已修「折行 Cc 会漏发 5 人」）。→ `reports/upstream-status-20261113.md`、`TASKS` §7。
   **★2026-11-17 联网核查（子代理，全账 `reports/upstream-replies-20261117.md`）**：在飞 4 系列**只有 1 个收到人回** = wl2868c v11（Rob 11-16 15:10 UTC：**v11 漏带他的 R-b** ⇒ 下一版补 tag）；pstore v1 / dsi-phy v2 / mdss v5 **零人回**。
   另有两封改变前提的信：① **Bryan 对我方 camss CSIPHY RFC 回信（11-15 17:44 UTC）** —— 先基于 on-list 的 Hangxiang **v25**/Qualcomm **v7** 工作，并直言我方邮件「LLM output…干难懂」；② **`qcom,nsessions` 已于 11-16 被上游合入废弃**（`641dd7dd0f68`）。我方相关主线合入 = 0；同家族上一代 Kaanapali PHY 3 枚已进 phy-next。
   **★2026-11-17 12:17 Q28 证据回帖已发（用户放行）**：`Message-ID <179488903160.260870.8168848839719897744@mail.ustc.edu.cn>`，`/linux-arm-msm/`+`/dri-devel/`+`/lkml/` 三处归档、正文逐字节相同（`sha256 4fe84148…`）⇒ **在档未发件已清零**；下一批 = 6 个待发系列（含新增 `wl2868c v12`）。

**卡什么**

- **⛔ 卡什么 = Linux 侧归零，不是设备坏（2026-11-17 20:0x 起设备已回原厂 Android 16；21:4x adb 在线复核见下）**：`linux17`/`eldenesp` GPT 条目与槽镜像都已被原厂件覆盖，**只有 `linux17` 的 ext4 数据物理保留在 LBA `73277435`（192 GiB，位于现 `userdata` 区间内，未被 mkfs 覆盖前可救）** ⇒ 下一步 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §3 S3a（先重建条目、**不格式化**）→ S4/S5/S6；**需 C1 放行（S3a 保数据 vs GPT-minimal 重装）**。
  **2026-11-17 21:4x 只读复核（`SN=HA2EXB0E bash scripts/linux-state-audit.sh --device`，未写盘；快照 `reports/artifacts/linux-state-20261118/audit.tsv`）**：`DRIFT = 设备上无 linux17/eldenesp`、`F.rootfs 缺失（库里无全量 rootfs 归档）`、`/lib/modules 目录数 = 0`；adb `HA2EXB0E` 在线、`sys.boot_completed=1`、slot `_a`、`uname -r 6.6.118-android15`、`/data` 450 G（用 6.3 G）。
  **★2026-11-17 22:0x 路线已定（用户放行：走重装最小化 + 可进 EDL）=「GPT-minimal 重装 + EDL 直写」**（不再走 S3a 保数据）：① **P0 已做**（EDL 只读 dump 六 LUN 主备表 → `backup/HA2EXB0E-16+512/edl-20261118/`，12 文件 + `SHA256SUMS.txt`；主备表条目逐字节相等、头/条目 CRC 全 OK）；② **两张最小表已生成且自检通过**（`out/gpt-minimal-20261118/lun0_{main0,backup0}.bin` = 10 项 / `linux` LBA 90504..123871226 = 472.19 GiB；`lun4_{main4,backup4}.bin` = 74 项，删 `init_boot_a/b`+`vendor_boot_a/b`）；③ ✅ **2026-11-18 11:29 最小 rootfs ext4 镜像已出**（`out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`：6 GiB 稀疏/实占 2.1 G、label=`linux`、160 包、1510 个 `.ko`、44 M 固件、15 项门禁全绿、sha256 `d22c6a00…`；构建器 = `scripts/rootfs-minbase-build.sh`（`podman`/`proot` 路线实测不行，必须真 root））+ boot 件 `out/p2-minbase-20261118/boot-minbase-labellinux.img`（cmdline `elden_root=LABEL=linux`，sha `7ea9370b…`）；**⇒ P2 前置件已齐，卡在 C2（写盘批准）**，然后 P1（写 LUN0 表）→ P2（`qdl write 0/90504 <ext4.img>` → 上台 `resize2fs` → 刷 `boot_b`/`dtbo_dummy`/`vbmeta_b` → 冷起验 `findmnt /` = `LABEL=linux` + ssh 通）→ P3（LUN4 表）→ P4（`mark-successful b`）。
  ⚠️ **回退口径已改（2026-11-18）**：不再写「删条目 ≠ 删数据」——`linux` 起点 LBA 90504 = 原 `super` 起点，P2 的头 6 GiB 会覆盖 `super` ⇒ **P2 之后 Android a 槽不再可起**，真回退 = 写回旧表 **+ 重刷官方 `super`**（`backup/official-rom-15.10.259`，~20 min，11-17 已实测走通）。→ `RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md` §4 P2 行。
  **★历史（18:5x 定性降级，已被 20:0x T1/T2 推翻，留档防回流）**：真因 = **非原厂 GPT**（LUN0 条目名 + LUN4 槽属性），只写 88 KiB GPT 即恢复；「硬件类唯一存活解释」与送修单均作废（佐证 `#482`/`#486` 的判读错误）。全账 = `reports/bl-stuck-20261118-forensics.md` §7；历史案例 10 例 / 决策树 = `reports/bl-history-and-playbook.md`；回退件清单 = `DEVICE/README.md` §1.1 首条。
  > **作废（2026-11-19）：上句的「送修单」已整体标作废，设备不需要送修也不需要换主板** —— `DEVICE/service-repair-note-20261117.md` 顶部已写 `⛔ 作废（2026-11-19）` 抬头；
  > 新旧口径对照 + 在线判定 + 上机计划 = `reports/device-status-20261119.md`；上机判据 = `DEVICE/README.md` §1.6。
- **camss：delta 已按 Bryan 要求重基完成（2026-11-17 下午），只差一次上机出流回归**：本机 vendor `camera.ko` CSIPHY = **2.4.0**（地址 103/103 同、13 个 data 字节不同）。**v2 = `patches/upstream/camss-csiphy-24-v2-20261117/`（2 枚，基线 = 7.4-rc3 + kaanapali v25 `[01..03]` 前缀），6 道门全绿**（apply / checkpatch **0E0W0C** / `W=1` / `dt_binding_check` / 表 **13-13** 且与 vendor **103-103** 全等 / `git am` 2-2）。关键新事实：v25 `[03/15]` 的 `mipi_csi2_dphy_3nm_kaanapali` **复用 `lane_regs_x1e80100[]`（4nm v2.1.2 表）**，而 Qualcomm 自己的 SM8750 CAMSS v6 `[4/7]` 指向 `csiphy_res_kaanapali`（subject 写 **v2.3.0**），v2.3.0 与 2.4.0 的 18 张 2ph 表逐字节同值 ⇒ 上游现用值与 Qualcomm 两处口径都不一致（只写 cover 提问段，不替 Kaanapali 下结论）。**剩 = ① 一次上机出流回归（或 cover 声明无实测，需用户裁决）；② 投前再看 `SM8750 CAMSS v6 1/7` 是否已进 tree（进则删本系列 binding 那枚）**。→ `reports/camss-v25-rebase-20261117.md`、`reports/camss-csiphy-v6-vs-240-20261113.md`、`reports/upstream-replies-20261117.md` §3.1、`PITFALLS #648`。
- **fastrpc**：`qcom,nsessions` **上游已废弃并合入**（`641dd7dd0f68`）⇒ 倒过来变成我们的欠账：板级 DTS 里若还写该属性就要按驱动侧策略删除/改写；`accel/qda` 仍 v4（未合、无 v5）。
- **T14/T17 用户态固化**：S3+S4+S6 离线复核已过，**唯一缺口 = `hapticd` 二进制不可重建**（自家 ELF，chroot 步骤已闭合）。→ `reports/t14-s3s4s6-offline-verify-20261114.md`。
- **T9 待机**：改成间接采样（设备 timer 30 min 追加 `/var/lib/elden/suspend-resource.tsv`），**要 1–2 天数据才能判**，取数是人的动作。→ `TASKS` §4 T9、`PITFALLS #651`。
- **已结项、勿重推**：Q28/Q32 =「已规避」（运营线 8/8 无坏发）、Q24 = 根因指名（7.2 缺 `skip retention by default`）、Gunyah = 非主线、`#106` = 历史记录（2026-10 之后无复现样本，未取证）。

**下一步（按顺序）**

1. **camss CSIPHY**：① 重基 **已完成（2026-11-17 下午，v2 = `patches/upstream/camss-csiphy-24-v2-20261117/`，基线 = v25 `[01..03]` 前缀，6 道门全绿）**；② **剩**一次上机出流回归（`s5kjns`/`gc08a8` 30 fps）——未做前不发信/不发补丁；③ **★2026-11-18 复核：暂不投** —— Qualcomm 11-14 发 `Add CAMSS support for SM8750 and Eliza` **v7（23 枚）**，把我方 `0001` binding 与 `0002` cfg 都做掉了（Krzysztof 已判「应 squash 依赖」）⇒ 等 v8 落地再定形状（预期：`0001` 删、`0002` 收敛为 `.data` 指向 2.4.0 表的一处改动）。→ `reports/camss-v25-rebase-20261117.md`、`reports/upstream-delta-20261118.md` §2.1。
2. **上游待批准批次**（**2026-11-16 已对 mainline **7.4-rc3 final `aebb727447` 全部重跑顺序 apply**，详见 `reports/artifacts/apply-check-7.4rc3-20261116/`）：
   `board DTS` 单枚 / `dwc3 v9` 4 枚 / ~~`m8-mdss v4` 3 枚~~（**v5 已于 11-14 投出** ⇒ 剩「等回复」，见上第 6 条与本文件 §0-6；v5 与 v4 diff 只差 3/3 message，apply 结论沿用） / `dpu-gamma v2` 1 枚 / `m6-dsi-pll v2` 1 枚 / `haptics v2` 6 枚（**本轮已 rebase 0006** —— 去掉只存在于 linux-next 的 `interrupt.h` 上下文行，6/6 rc=0）—— **均 rc=0，逐系列等用户放行**；
   **新增待放行（2026-11-17）**：`wl2868c v12` = v11 原样 + 在 1/2 trailer 补回 Rob 的 `Reviewed-by`（他已重给）；
   **★2026-11-17 13:20 整批已发（用户放行）**：板 DTS **v7**（单提交）/ dpu-gamma **v2** / dsi-phy muxes **v2（m6 件）** / haptics **v2**（6+cover）/ dwc3 **v9 3 枚**（`0004` 板 DTS 暂 hold，因改尚未上游的板文件）/ wl2868c **v12**（补回 Rob 的 R-b）= **17 封全 `Result: 250`**，
   逐 MID 在 `linux-arm-msm` / `linux-devicetree` / `dri-devel` / `linux-input` / `linux-usb` / `lkml` 全部命中（每系列 `SENT.md` 有 MID 清单）。
   **已投的不再在列**：`dsi-phy v2`（11-16 两发 250）、`wl2868c v11`、`mdss v5`、Q28 证据回帖（11-17 12:17）；
   **卡源**：`dispcc-reset-v2` 与 `m8-mdss v4` 内容重复（发 v4）；`camss 2.4.0 delta` **已重基为 v2（`patches/upstream/camss-csiphy-24-v2-20261117/`，6 门全绿）**，停在「缺一次上机出流回归」（见上条）。
3. **设备窗口才做**：A10 两发（`set_active a` 或物理 POR）、B6/B18 需先建树出镜像。
4. **中文输入法候选窗：配置层已全绿（2026-11-15 T1–T5 全做，`scripts/ime-candidates-check.sh` = 11 PASS / 0 FAIL）**；**行为层未验** —— 画候选的那一半（`elden-ime-candidates.py`）仍按 #646 撤下，重做要求见 `PITFALLS #646` + 前置条件 `LD_PRELOAD=libgtk4-layer-shell.so.0`。→ `TASKS/sessions/2026-11-15-IME候选回归台账.md` §3b/§3c
5. **UEFI GRUB 路径：取证已完成（2026-11-15 夜）；修法 ① 已成可上游 2 枚系列并全绿备料**（内核 `initrd_phys_range()` + `ramoops_probe()` 逐 zone 判重叠，重叠段 `dev_warn` 跳过、四段全跳 → `-ENODEV` 干净退出；门禁 = `gh/master` apply-check 2/2 + checkpatch 0 error + 构建 0 error/0 warning + QEMU 两发 A/B）。**2026-11-16 真机已验**：`set_active a` → Mu UEFI → 嵌入菜单 GRUB → 64 MB initrd `0xc1ab0000-0xc584a5e0` 整段盖住 ramoops ⇒ dmesg 三段 zone 逐条 `ignoring … overlaps the initrd`，60 s 进 SSH；同日无守卫内核对照 = 黑屏 → 20 s 关机 → 回落 b 槽 ⇒ 真机有/无对照成立。14:03 ESP 归位（日常嵌入菜单 `f5dcf599…`）+ a 槽暖启 44 s + POR 冷启菜单正常；该轮另修 `q28-boot-watchdog` 只认 `card0` 的误判（`PITFALLS #667`）。
   **已发 2026-11-16 12:00:49（USTC）**：To Kees/Tony/Guilherme，Cc lkml + linux-arm-msm，3 × 250，线程根 `20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn`，**等回复**；树 = `build/daily` `v7.3.1-5-g4bdf1711b5`（未打 vk 号、未进版本账）。→ `patches/upstream/pstore-ram-initrd-overlap-20261116/`（README + 0000 cover + 2 枚 + `logs/40-sent.txt`）、`reports/pstore-ram-initrd-guard-20261116.md` §5、评审 `reports/pstore-ram-initrd-review-20261116.md`、`scripts/qemu-ramoops-initrd-ab.sh`、真机件 `reports/artifacts/uefi-pstoreguard-20261116/`、`reports/artifacts/uefi-daily-v8-20261116/`、`PITFALLS #666`。
6. ~~**LastFile2 打印版（v2）缺屏上取证**~~ **→ 已撤销（2026-11-16，不需再拍）**：v2（`b9fb14cb…`）只是把同一测量改成「只打印不写盘」的通道变体，不产生新判据——「LoadFile2 fill 后 64 MB 内容正确」已由 v1 grubenv 侧证（`lf2_addr=0xc23e0000 / len=64595425 / sum=0x5c53688e`）与 11-16 真机守卫臂双重覆盖。件留 ESP（`.lf2v2.bak`）与 `out/`，不再列入待办。→ `reports/uefi-grub-initrd-rootcause-20261115.md`。
7. **T9 取数**：`scp elden-root:/var/lib/elden/suspend-resource.tsv .` 后按同一 boot ≥3 周期看趋势。
8. **磁盘 A 类清理已执行完（2026-11-16）**：两轮共释放 **15.25 GiB**（项目 91 G → 76 G；A1–A14 无失败项，第二轮 = `stock-src`、`dl-cam/ndk`、`out/r21-sbstop-{p69,pc2}`、`out/mu-memmap-20261115`、`out/{espboot-20261108,espboot-20261110,fbdiag-20261108,dbg-uefi-initrd-20261115}`、`y700四代工具`）。三项评估 = `backup/official-rom` super 15 G **可压不可删**（脚本零引用、净省 ~6 G，需同轮改引用行）、`backup/out-history` 8.13 G **无可删**（114 个 .img 全被 `versions/*.tsv` 引用）、`.pi/sessions`+`reports/artifacts` **建议保留**。→ `reports/disk-cleanup-20261115.md` §2（执行记录 + 复核命令）。
9. **主机侧待办已对账到 2026-11-17（子代理）**：`reports/todo-inventory-20261113.md` 的 72 条 → `reports/todo-reconcile-20261117.md`（17 已闭环 / 9 已作废 / **6 条主机侧可做** / 25 需设备窗口 / 15 需用户批准）。主机侧 6 条按价值 = B14 T14 重建 recipe、B15 Gunyah 两空、B13 脚本欠账、B18 libcamera 闪光灯、C-I12、B17 分诊盲区（合计 ~10–13 h）。文档/工件卫生 = `reports/doc-hygiene-20261117.md`。
10. **2026-11-18 主机侧 lane（只读，未改 SSOT 的 5 份报告已入库；本轮结论已并进本节）**：**单一可执行清单 = `reports/todo-next-20261118.md`**（A 主机 11 条 / B 设备 12 条 / C 待批准 11 条 / D 已作废 15 条；价值序首位 = dwc3 v10 + haptics v3 答 sashiko 的 2×High+1×High）。其余 = `reports/progress-audit-20261118.md`（数字三方一致 36/37·10/13；9 处文档滞后已同轮改完）、`reports/mail-inbox-20261118.md`（11-14 后人类回帖 2 封、bot 8 封；`read-mail-ustc.py --replies-only` 判据失效待修）、`reports/upstream-delta-20261118.md`（**camss v2 暂不投**：Qualcomm 11-14 v7 23 枚已做掉我方 0001/0002 形状，等 v8；dwc3/haptics 重基目标换 `refs/heads/master`）、`reports/doc-slim-plan-20261118.md`（可净减 ~44 KB，**第一刀 C1–C8 已于 2026-11-19 执行完**（C9 = PITFALLS 索引行合并，判「收益 < 风险」不做））。孤儿报告补指针：`reports/stale-cleanup-b-docs-20261119.md`（check-doctor §13 曾报无人引用）。

**怎么核实本节没漂**（开工前先跑，见 `.pi/AGENT-OPS.md` §0）

```sh
scripts/recent-sessions.sh 3          # 最近 3 轮会话的收尾结论（正文在 .pi/sessions/*.jsonl）
scripts/check-progress-counts.sh --tsv   # G1/G2 完成度现查
sed -n '/### 1.1/,/### 1.2/p' DEVICE/README.md | head -20   # 在机内核/槽位/判据
scripts/check-doctor.sh --only 15      # §15：本节「核对日期」是否落后于最新会话证据
```

---

## 1. 使命与范围（3 行；目标定义只在一处）

- **机型唯一**：只研究 **TB322FC / elden / SM8750(P)**，不做别的机型移植；研究面 = 让本机在主线 Linux 上功能完整（固件/驱动为主，刷写只是手段）。
- **G1 / G2 / G3 / 拓展 / 核心原则（设备等价 / 存储 / 构建并发 / 上游发信授权）= 唯一正文在 `AGENTS.md`**（每轮自动注入，此处不复述）。
- **术语**：设备称 **U1 / U2**；备份目录 `backup/<SN>-<容量档>/`；禁用 `new-tablet` 与「两轨分机」旧口径；容量裁定见 `DEVICE/README.md` §3。

---

## 2. ★ 文档结构（文件夹＝角度；会话进度进 sessions/）

> **文档 v2（2026-10-14 起）**：每个**角度** = 一个**文件夹**，内含 `README.md`（该角度**策展 SSOT 正文**，唯一维护面）+ `sessions/`（**以会话为单位**的进度文件）。
> **会话进度文件**：命名 `YYYY-MM-DD-<主题>.md`（同日多主题加 `-2`）；文件头记 日期 / pi 会话 id / 主题 / 结论 / 证据指针 / **★SSOT 待并入**。
> **记录时的区分度**（取代自检脚本的计数/索引）：写入时就靠 文件夹(角度) + 文件名(日期+主题) + pi 会话 id 区分。
> **会话检索** = pi 原生项目会话（`.pi/sessions/*.jsonl`，项目级 `sessionDir`）：`scripts/sess.sh` / `/resume`；不手抄索引表。
> **SSOT**：数字/结论只在该角度 `README.md` 维护，其余用链接；跨会话新增先落 `sessions/`，由宿主择机并入 `README.md`。
> **阅读顺序只在一处声明**：唯一路径 = 下面「入口阶梯」（按新鲜度加权；与 `.pi/AGENT-OPS.md` §0 开工三件事是同一阶梯）。

### ★ 会话结束时写什么（唯一规则，8 条）

> 目标：**增量记录**——每次会话只新增文件，不改旧文件；状态数字只有一处出口。

1. **只写 1 个新文件**：`<角度>/sessions/YYYY-MM-DD-<主题>.md`；同一会话多主题加 `-2`。**不新建目录、不改已存在的 sessions 文件、不建索引表**。
2. **可用角度 5 个**：`TASKS/`（任务/进度/未解）、`PITFALLS/`（踩坑）、`DEVICE/`（单元/镜像状态）、`RESOURCES/`（资产/资源）、`RUNBOOK-BRINGUP/`（bringup 流程与相变记录）。
   `SESSIONS/` **冻结不写**；`HISTORY/` 由脚本生成**不手写**；`RUNBOOK-BRINGUP/` 已有正文（Phase −1…9 + `sessions/`），属可写角度。跨角度时写**主角度**一个文件，其余角度补一行指针。
3. 文件头只写 6 个字段：`日期 / pi 会话 id / 主题 / 结论 / 证据指针 / ★SSOT 待并入`。`pi 会话 id` 取 `$PI_SESSION_ID`。
4. **状态数字只改一处**：`TASKS/README.md` §0（总览）/ §5（Q 行）。其它任何地方**不写状态数字**，只写指针。
5. **会话全文不复述、不复制**——它就在 `.pi/sessions/*.jsonl`；文件里只放「结论 + 指向证据的路径/命令」。
6. **索引只放一句话主题**：`PITFALLS/README.md` 的索引行 ≤800 B，结论/命令/数字一律在正文。超长会被 `check-doctor §8` 判 FAIL。
7. **不写死计数**：任何「共 N 条 / N 个文件 / N 个提交」都必须现查（`scripts/gen-history.sh --stats`、`ls`、`check-doctor §8`）。写死必漂，且漂了没人发现。
8. **收尾判据**（`.pi/AGENT-OPS.md` §5）：产物落盘 + SSOT 同步 + `check-doctor.sh` **FAIL=0** + `git commit` + 工作区干净。


### ★ 时间序裁决（同一事实出现多个说法时的**唯一**规则）

> 目的：文档里**不准并列两说**。历史上多次出现「旧结论 + 勘误 + 再勘误」同时躺在正文里，
> 新会话无法判断哪个算数 —— 实测代价 = 每轮开工先花几十分钟考古。

1. **同一事实只允许一个「当前口径」**，写在**离它职责最近的那一份 SSOT** 里（状态 → 本文件 §0 / `TASKS`；设备事实 → `DEVICE`；经验 → `PITFALLS`；行为 → `.pi/AGENT-OPS.md`）。
2. **胜负判定 = 证据强度优先，其次日期**：会话内**实测证据（命令 + 原始输出）** > 带日期的报告（`reports/*.md`）> 文档叙述；同类证据取**日期更新**者。无日期、无证据的叙述直接输。
3. **输了的那条只有两种待遇**：① 与现状无沿革价值 → **删**（commit 信息写明「删除旧口径 + 依据」）；② 有沿革价值（曾被当真、影响过判断）→ 就地改成一行 `~~旧说法~~ **作废（YYYY-MM-DD，真因 + 指针）**`，**不得**在别处再复述一遍旧的。
4. **改口径必须同轮改完所有引用点**（grep 旧结论的关键词），并在提交信息里写「口径更正（YYYY-MM-DD）：旧 X → 新 Y（证据）」。发现新的实测证据与本文件 §0 冲突时，**先改本文件 §0 的结论与核对日期**，再改下游文档。
5. **本节自身有门**：`scripts/check-doctor.sh` §15 做两项比对（落后就 WARN、矛盾就 FAIL）：
   §0「核对日期」vs **最新会话证据日期**；以及 **§0 写的「在机 `vkNN`」必须出现在 `DEVICE` §1.1 首条**
   （§1.1 只允许一个 `★★` 权威行 —— 2026-11-14 之前那里同时挂着 vk190/vk191 两套说法，就是本节的实测代价反例）。

### ★ 入口阶梯（**唯一**路径；数字越小越权威，冲突时上位胜 —— 这就是时间序权重）

| # | 读什么 | 为什么它在这个位置 |
|---|---|---|
| 0 | 本文件 **§0 现在一页**（做到哪 / 卡什么 / 下一步） | 最新会话证据的摘要，标题带核对日期 |
| 1 | **`scripts/recent-sessions.sh 3`** + `*/sessions/` 最新 2 篇的「结论 / ★SSOT 待并入」 | **比任何 README 新**：本轮及上两轮的实测结论 |
| 2 | **`.pi/AGENT-OPS.md` §0**（开工三件事）→ §1–§5 | 行为唯一入口；§0 直接要求先做第 1 行 |
| 3 | **`PITFALLS/README.md` §0**（零号纪律）+ 索引 | 动手前必查的既有结论 |
| 4 | **`TASKS/README.md`** §0 / §4 / §5 / §7 | 状态数字与台账的唯一出处 |
| 5 | `DEVICE` §1.1（在机）/ `RESOURCES` §3（资产）/ `RUNBOOK-BRINGUP`（步骤） | 按需展开 |
| 5b | **`RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md`**（＋`scripts/linux-state-audit.sh`） | **设备状态被改后重建 Linux 的唯一入口**：8 项清单 / S0–S9 步骤 / 卡 BL 误判防护 / 反向回 Android |
| 5b2 | **`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`**（＋`scripts/deploy-desktop-shell.sh`） | **EDL/fastboot → 可用桌面的端到端链路（2026-11-19 实测）**：S1–S12 每步命令/判据/失败形态/回退 + 一页速查 + 溯源表 |
| 5c | **`RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md`**（＋`scripts/gpt-minimal-build.py`） | **分区表如何简化 + 最小 Debian 刷机件清单**（LUN0 18→10 项、单 `linux` 472 GiB）；与 5b 是同一目标的两层 |
| 6 | `reports/*.md`（按日期）→ `archive/` · `SESSIONS/` · `PROGRESS.md` · `HISTORY/` | **只作沿革与证据，不得当「当前结论」引用** |

> `reports/` 内部查全用 **`reports/README.md`**（509 篇的机器生成目录，`scripts/reports-index.py` 产；`--check` 过期即 rc=1）。
> 它**不是入口**，不承载结论，只解决「reports 里到底有什么、哪篇没人引用」——2026-11-15 实测有 135 个报告/台账文件名全仓只出现 1 次（**快照，已过时；现数以本文件顶部报告总数与 `scripts/reports-index.py` 重跑为准**）。

> **权重规则（硬）**：第 1 行（最近会话）与第 4–6 行冲突时，**先按会话读**，并在**同一提交**内把下行文档改成一致；
> 不允许「两边都写着，读者自己判」。`README.md` / `PROGRESS.md` 是**公开门面**，agent 默认不读（不占入口位）。

### ★ 根目录四文件的职责边界（单一事实源；2026-10-15 收敛）

> 收敛前：机型规格出现 4 处、G1–G3 目标在 4 个文件各复述一遍 ⇒ 必然漂移（实测 `README.md`
> 的机型表与 `AGENTS.md` 重复、目标段与 `INDEX.md` §1 重复）。现按「一条事实只有一个正文位置」
> 收敛如下，**其余位置一律只给链接**：

| 文件 | 唯一职责（正文位置） | 不得复述 |
|---|---|---|
| **`AGENTS.md`** | **项目身份**：机型唯一性、G1–G3 目标定义与优先级、核心原则（设备等价/存储/SSOT） | 不写进度数字 |
| **`INDEX.md`**（本文件） | **路由**：入口阶梯（含时间序权重）、文件夹地图与 SSOT 口径、§0 现状摘要、快速命令 | 不写状态数字（指向 `TASKS` §0）、不复述目标（指向 `AGENTS`） |
| **`README.md`** | **公开门面**：面向 GitHub 读者的定位、免责/许可、快速开始 | 机型表/目标只留速查副本 + 指向 `DEVICE`/`AGENTS` |
| **`PROGRESS.md`** | **公开时间线**：诚实进度叙事（含被推翻的结论） | 不写权威台账（指向 `TASKS`） |

细节（机型规格、分区、单元台账）以 `DEVICE/README.md` 为准；状态数字以 `TASKS/README.md` §0 为准。

### 规范入口（agent 行为唯一入口）

| 入口 | 文件（权威） | 装什么 |
|---|---|---|
| **行为/规范** | **`.pi/AGENT-OPS.md`** | agent **自主优先**、物理干预边界、设备安全纪律、研发纪律、文档写入权限、汇报/时间盒；并发细则见 `.pi/CONCURRENCY.md`，三层编排见 `.pi/ORCHESTRATION.md` |

> 项目描述（机型/目标/设备等价）在 `AGENTS.md`；各角度 `README.md` 不再复述规范与经验。
> （原「1 分钟版」三步已于 2026-11-14 并入上方「入口阶梯」第 0/2/3 行，不再单列。）

### 角度文件夹（`README.md` = 权威正文；子目录 = 以会话/单元为单位的记录）

| 角度 | 文件夹 | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE/`** | 机型规格、固件清单与通路、驱动矩阵、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略** |
| **任务 / 进度 / 未解 / 方案** | **`TASKS/`** | **唯一任务台账 + 进度权威**（§0）；G1/C/A 任务（§1–4）；**§5 查漏补缺（GAPS，Q 编号以表内为准）**；**§6 G2 安卓兼容方案**；**§7 上游化（M 系列，以 §7 为准）** |
| **资源 / 资产 / 会话** | **`RESOURCES/`** | §1 外部参考 · §2 本地资源 · **§3 文件与资产台账（git 边界/可清理）** · §4 会话检索（pi 原生） |
| **上机手册** | **`RUNBOOK-BRINGUP/`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase −1…9 |
| **开发经验 / 踩坑** | **`PITFALLS/`** | **开发经验唯一入口**：`README.md` = §0 零号纪律 + 索引表（条数以该表实际行数为准，勿在此写死）；正文在 `sessions/NN-*.md`（含 **§15 过时/废弃登记**） |
| **会话档案（逐会话）** | **`SESSIONS/`** | ⚠ **已冻结的历史快照（2026-10-15 起不再增补）**：`README.md` = 索引表/统计/内核时间线 + `sessions/YYYY-MM-DD-<名称>.md`。**新会话一律不进本目录**；会话身份与全文检索 = pi 原生会话（`scripts/sess.sh` / `/resume`）。此处保留仅为档案 + `check-sessions.sh` 校验基准 |
| **git 提交史（逐提交）** | **`HISTORY/`** | 提交视角权威：`README.md` = 规范/查询入口（**不写死数字**）+ `days/YYYY-MM-DD.md`（机械生成）。统计现查 `scripts/gen-history.sh --stats` |

### 顶层布局（4 区 + AI 大脑；**逐项 = 机器表**）

> **机器真源 = `versions/layout.tsv`**（人读 `scripts/check-layout.sh --list`），门 = `check-layout.sh`（`check-doctor.sh` §14：
> **每条路径必须在本节出现且磁盘存在**）。规则：**根目录新增条目先登记 `versions/layout.tsv`**，未登记即 FAIL。
> 本节只回答「这个目录能不能删、要不要入库」的**分区级**口径；逐条职责/删除风险读 `RESOURCES/README.md` §3。

| 区 | 顶层条目（与 `layout.tsv` 同源） | 版本控制 |
|---|---|---|
| 入口 | `AGENTS.md` `INDEX.md` `README.md` `PROGRESS.md` `LICENSE` | track |
| 角度文档 | `DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/` `archive/` | track |
| 源码/补丁/工具 | `scripts/` `tools/` `patches/` `patches-userland/` `reference/` `versions/` `packaging/` `initramfs/` `rootfs/` `probes/` `net/` `waydroid-ota/` `restore-259/` `cycle.sh` `elden-net.sh` `.githooks/` `.gitignore` | track |
| 证据/备份 | `reports/`（md 入库，大件 ignore）· `backup/`（**不可再生**：删前必须云盘或 bundle 兜底）· `assets/`（原厂安卓资产提取树，2026-11-19 起；专有、仅本机用、不入库，脚本可重建） | track / ignore |
| 工作区（**可再生成**） | `build/` `out/` `logs/` `bootslot-b/` `env-pass/` `dl-cam/` `wt/` `external/` `geekidos-linux/` `Y700-elden-linux/` + 软链 `linux` | ignore（`build/` 删前先 bundle + 导 diff） |
| ↳ **2026-11-19 现状** | `build/` 的内核树与 `geekidos-linux/`＋软链 `linux` **已被磁盘清理删除**（`build/` 只剩 phoc/phosh 源码）；重建命令见 `versions/layout.tsv` 表头注释，影响与处置 = `reports/disk-cleanup-20261119-validation-impact.md` | — |
| AI 大脑 | `.pi/`（规范/并发/编排/技能/记忆/会话；分工见 `.pi/README.md`） | track |


### 证据层（`archive/`，追加为主）

> 专题档案＝**过程证据**；结论一律以领域层为准，archive 不得被引用为「当前结论」。
> **追加为主**；允许为更正错误 / 回填结果做带日期的最小修订（不改写既有结论口径，权威恒在领域层）。

### 机器可查（无 SQLite，无生成物）

> **项目资产归属（2026-11-02）**：记忆/技能/会话全在仓库内——`.pi/memory/`（记忆 SSOT，`~/.pi/agent/projects-memory/y700-elden` 只是软链，自检 `scripts/check-project-memory.sh`）、
> `.pi/skills/`（项目技能，Pi 按工作目录叠加加载）、`.pi/sessions/`（会话轨迹，ignore）。lane 工作树在 `../wt/`、外部工作区在 `../external/`（均 ignore，`scripts/lane.sh` 默认 `WT_ROOT=<repo>/wt`）。

- 文本搜索：`rg` / `grep`（`PITFALLS/README.md` 找踩坑、`RESOURCES/README.md` 找资源、`TASKS/README.md` 找任务）。
- 会话回忆：pi 原生会话选择器（`/resume`）/ `scripts/sess.sh`；**逐会话快照** `SESSIONS/`、**逐提交史** `HISTORY/`（`scripts/gen-sessions.py` / `gen-history.sh` 再生）。
- 机器账自检：`scripts/check-doctor.sh`（退场入口 / vk 版本账 §5+§5d / manifest §5e / **§5f ABI 敏感项一致性（`.config`↔模块树）** / 静态卫生 /
  **§7 入口文档完整性（围栏·截断·证据指针泄漏）** / **§8 索引↔磁盘对账（编号撞车·索引行超长）** /
  **§9 SESSIONS 快照** / **§10 HISTORY 对账** / **§11 提交钩子生效性** / **§14 顶层布局注册表** /
  **§15 时间序健康（§0 核对日期 vs 最新会话证据；见 §2「时间序裁决」）**）。
  顶层布局真源 = **`versions/layout.tsv`**（项数现查 `scripts/check-layout.sh --list | wc -l`；4 区：入口/文档 · 源码/补丁 · 证据/备份 · 工作区；人读面 = 本节「顶层布局」表，门 = `scripts/check-layout.sh`）。
  **入库前门已接线**（`core.hooksPath=.githooks`）：`pre-commit` 跑 `--staged-fast`（§7/§8/§9/§10/§11/§13/§14，实测亚秒级（量级见 `reports/script-audit-20261105.md`）；§12 内核 config 门不在这一档）。
  全量 `scripts/check-doctor.sh` 现为**并发子门**（`scripts/doctor/`），稳态 **~1.4 s**（旧版单体串行 12.5 s）；口径与实测见 `reports/script-audit-20261105.md`。
- **打包前门**：`scripts/assert-kernel-sane.sh`（config 锚点 / System.map 符号 / UTS 对齐 / 非陈旧 / **§1b ABI 敏感项**，后者调 `scripts/check-abi-config.sh` 比对 SSOT config 的 27 项）。
- 版本对账：**`versions/vk-kernel-identity.tsv`**（构建号 ↔ 内核二进制 ↔ 源提交，含每个镜像的失真标记）。
  它是本目录**唯一入 git 的派生表**（破例理由：兼作版本欠账账本）；由 `scripts/vk-identity.py` 重生成，
  `check-doctor` §5d 强新鲜度（过期即 FAIL）。“vkN 是什么”的口径见 `PITFALLS` #135。

---

## 3. 去哪读（**细节指针**；本节不写状态、不写结论）

> 本文件 §0 = 唯一状态入口；数字 = `TASKS/README.md` §0；设备/镜像 = `DEVICE/README.md` §1.1/§2.2。
> 本节只回答「某个细节去哪找」，不重复任何结论。

| 要查什么 | 去哪 |
|---|---|
| 任务台账 / 未解（Q 表）/ 待办 / 上游化（M 系列） | `TASKS/README.md` §1–§2 / §5 / §4 / §7 |
| 上游投递现状（当前一页） | `reports/upstream-status-20261113.md` |
| 在机内核 / 槽位 / 单元台账 / 存储策略 | `DEVICE/README.md` §1.1 / §2.2 / §3 |
| 动手前的坑 | `PITFALLS/README.md` §0 + 索引 |
| 从原厂到 b 槽直启的操作步骤 | `RUNBOOK-BRINGUP/README.md`（Phase −1…9） |
| 换机缺口 / 资产与 git 边界 | `RESOURCES/README.md` §3.5 / §3 |
| 文档去重执行账 / 审计依据 | `reports/docs-slim-20261114.md`（本轮：入口收敛二轮）、`reports/docs-slim-20261113.md`、`reports/doc-dedup-audit-20261112.md` |

**已定不做 / 搁置（勿重推）**：正文只在 `TASKS` §4「本轮不投入」+ §1 各 ID 行（`G1-26/27/28` 已出列、`G1-10` 无 NFC 硬件、
`G1-30` slim initramfs）与 `RUNBOOK` §0.5（BL 解锁已定稿关闭）；`kexec` 定位见 `TASKS` §4「迭代通道」条。
**两条不变的硬约束**（内核必须自编 / 传感器栈要 forky-sid 级 `iio-sensor-proxy`+`libssc2`）= 正文在 `DEVICE/README.md` §1.1 末条。


**保留但需知道的旧账**：换机缺口（`RESOURCES` §3.5 + `versions/migration-gaps-2026-10-17.tsv`）、
宿主 rootfs 方向（Alpine → Debian/Mobian，2026-10-26 用户定，`reports/mobian-migration-plan-20261021.md` + `TASKS` T14/T17）、
单元台账（`DEVICE` §1）。
---

## 4. 快速入口命令

```bash
cd ~/y700-elden          # ★ 启动入口即此（旧 cd 包装与根目录兼容包装 build.sh/iterate.sh/pack.sh 均已移除 → PITFALLS §15.1）
# 【收尾自检】退场入口 / vk 版本账与内核身份 / manifest 完整性 / 静态卫生（全绿再收工）
scripts/check-doctor.sh
# 【版本对账】“这个 boot.img 里到底是哪个内核” / 重生成对齐表
python3 scripts/vk-identity.py --gate                    # 只看命名/溯源规则结果
python3 scripts/vk-identity.py > versions/vk-kernel-identity.tsv   # 重生成（随后连表一起提交）
# 【脚本账】全量可执行入口清单（live / hist-only / unreferenced；整理轮用，勿手改表）
python3 scripts/static-scan.py --inventory | sed '1d' > versions/scripts-inventory.tsv
# 【动手前 30 秒】引导链类问题（解锁/AVB/降级/GPT/EDL）先查本地既有结论（PITFALLS #87）
grep -rn -iE "unlock|解锁|sn\.img|rollback|testkey|073" \
  .pi/skills/*/references/*.md *.md archive/topics/*.md | grep -v '^Binary'
```

```bash
# 目标形态：b 槽直启 Linux（~5–9 s 进 Phosh），日常不需 fastboot
sudo bash elden-net.sh && ssh -o StrictHostKeyChecking=no root@192.168.7.1
# 内核迭代＝统一入口 scripts/iterate.sh（四档环，细则 RUNBOOK §迭代）
scripts/iterate.sh mod <driver-dir>              # 环0：=m 模块热载 ~30s 不重启（需先应用 fragment-modular）
#   成功判据 = build-id 匹配（脚本会自己打印 ✅/❌ 并在未确认时 rc=1；见 PITFALLS #447）
LOCALVERSION=-debug-vkNN scripts/mod-loop.sh <driver-dir> --reload <mod-name>
#   设备 UTS 与本树 KV 不一致时脚本会 REFUSING；跨 KV 只能用 --bootstrap 或 --allow-mismatch
scripts/iterate.sh kernel VERSION=vkNN           # 全量重编（零写盘快环：kexec 可用，但目标无显示/USB，见 §4「迭代通道」条）
scripts/iterate.sh kernel --flash VERSION=vkNN   # 写回 boot_b（设备写：按 .pi/AGENT-OPS.md 先备份后执行）
scripts/device-lock.sh --status                  # 谁占着设备；并发子代理写操作前必查
# ★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM → 死内核，PITFALLS #162）
ssh elden-root 'sync; reboot bootloader'   # 唯一软路径进 fastboot（PITFALLS #650）
#   ⛔ 作废（2026-11-19）：`./cycle.sh --soft`（sysrq-b 暖复位，到不了 ABL）与 `eldroid-bootctl` 均不可用（PITFALLS #690）
fastboot boot bootslot-b/boot_b-minbase-labellinux-20261119.img  # 零写盘·持久变体（vk192 核/DTB/initrd + 磁盘根，cmdline LABEL=linux），功能测试用（PITFALLS #93）
#   历史：boot_b-f2fs-root.img 的 cmdline = LABEL=linux18，而 linux18 已于 2026-10-31 删除 ⇒ 该件永久起不来，勿用
fastboot boot <img>                        # 零写盘·纯RAM变体（无桌面/服务）仅内核/引导级验证；先 blank 活跃槽 dtbo 否则卡 logo（PITFALLS #1/#10）
# 新单元开工三件套（先写台账，再备份，再手术）
fastboot getvar serialno; adb shell getprop ro.boot.hwboardid   # → 写进 DEVICE/README.md §2.2
sh scripts/gpt-dump.sh                                          # 打印本单元 backup_lba（禁跨容量档复用）
# b 槽三件套备份：本 ABL **无 fastboot fetch**（实测与报错全文见 PITFALLS #290）
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/boot_b of=/tmp/boot_b.img'  # 再取回；或从官方线刷包解出
python3 scripts/slot-attr.py show                               # 槽位属性（在 GPT attribute，非 misc）
# 设备侧三态判据（显示问题）：NOCARD / STORM / GOOD
scripts/q28-devprobe2.sh          # 在设备上跑（SSH 读全 dmesg + 查 card0）
scripts/trial.sh                  # 一次设备实验 = 一条机器可读记录（reports/trials/，--reset 必填）
```
