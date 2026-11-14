> 会话进度见本目录 `sessions/`；本文件为该角度策展 SSOT。
# 任务拆解与进度（TASKS）

> 本角度文件夹的策展 SSOT（`README.md`）；`sessions/` 存以会话为单位的进度。标准见 `INDEX.md` §2。
> **本文件是唯一任务台账**：所有 ID、状态、下一步只在这里维护；专题文档只放过程与证据。
> 纪律：worker 只报「命令 + 原始日志」，编排者**独立复跑**；每步留回退；设备锁串行、主机侧并行。

---

## 0. 进度总览（数字）

| 目标 | 已完成 | 进行中 | 未开始 | 完成度 |
|---|---|---|---|---|
| **G1** 完整 Linux + 上游化 | **36 项 / 在范围 37 项**（明细与证据**只在 §1**，本行不列举） | 0 项（WiFi Q26 已于 2026-10-10 关闭；TF 卡 G1-6 已收口，见 §1） | 上游化 **M 系列**（状态/队列**只读 §7**） | **36/37**（口径见下表注） |
| **G1 阻塞项速览**（**本行只列 ID**；状态/样本数/口径唯一权威 = §5 的 Q 行） | — | 🟢 **Q28/Q32 已结项 =「已规避」**（2026-10-24，用户裁决不补样本）；⛔ **Q24 已关闭**（2026-10-24，根因已指名） | — | — |
| **G2** 安卓容器（可用性 + 风控/完整性等级） | **9**（分母 13 项；`C-历史` 聚合行不进分母，2026-11-10 新增 C12） | 3（C3 待 SPIC 回包、C5 剩 App 实开预览、C8 书面结论未立项） | 1（C9 打分表出数） | **9/13**（口径见下表注） |
| **G3** x86 模拟（Steam 载体） | 2（Box64+Wine PoC；官方 ARM64 Steam 客户端起到登录界面，2026-10-28 设备实测 3/3，证据 `reports/g3-steam-20261028.md`） | 1（x86 游戏端到端：FEX/box64 层待接，与「起客户端」已解耦） | Steam 游戏端到端（图形/音频/性能） | PoC ✅ / **Steam 登录界面 ✅** |
| **拓展** UEFI 间接引导 · Gunyah VM | 1（UEFI **两种形态都通**（2026-11-10 深夜，真根因 = `dtbo_a`，`reports/uefi-dtbo-a-rootcause-20261110.md`）；Gunyah =「有条件重启」不等已结项，`reports/gunyah-restart-assessment-20261111.md`） | 0（UEFI 剩余仅菜单交互目视 + `boot_a` 冷起回归，非阻塞） | 0 | ⬜ 非主线 |
| 运维/资产 | **在机状态与资产快照一律只读 `DEVICE/README.md` §1.1 / `RESOURCES/README.md` §3（本行不再记快照与 sha）** | — | — | — |

> **注（口径 2026-11-03 机器化；手算推导已删，改为脚本现出）**：本表数字**一律由 §1 / §2 的行内状态标记导出**，不另设分母。
> **公式**：`完成 / 在范围`，其中 `在范围 = ID 总数 − ❌/⛔`，`完成 = ✅ + 🟢 + 🎯`；合并行（`| ✅ G1-12…21 |`）按区间展开计 10 项。
> **现查（唯一出口）**：`scripts/check-progress-counts.sh`（`--tsv` 机读 / `--selftest` 断言 36/37 与 9/13，漂了就 rc=1）。
> 现状：**G1 36/37**（39 ID − ❌2：`G1-10` 无 NFC 硬件、`G1-30` 与 G1-29 同路线；不含上游化 M 系列，以 §7 为准）、**G2 9/13**（`C-历史` 是 5 项聚合行、不进分母；2026-11-10 新增 **C12 droidloom 隔离试验** 入分母 ⇒ 12→13；**2026-11-11 C12 结项 ⇒ 8→9**）。
> **词表（8 类）**：`✅` 完成 / `🟢` 已结项（已规避·已出分·已随根因结项）/ `🟡` 部分·进行中 / `🎯` 治本完成 / `🆕` 取证已做未收口 / `⛔` 搁置 / `❌` 取消 / `⬜` 未开始；`🟢`/`🎯` 计入完成，`🟡`/`🆕`/`⬜` 计入未完成。
> **改数字只改 §1/§2 的行内标记**：§0 上下表由脚本导出，勿手改（历史手算推导见 `sessions/2026-11-03-TASKS-§4-待办沿革.md` 前后版本）。

---

## 1. G1 任务分解（功能健全的 Linux + 原厂固件全部驱动）

> **★证据件路径口径（2026-11-11 回填 `reports/project-audit-20261111.md` §1）**：本表各行的 `out/<件>.img`
> 若在本轮后已不被 `ls` 命中，按以下顺序找：① `out/<件>.manifest`（sha/内核串/dtbs）；
> ② `backup/out-history-20261105/<件>`（2026-11-05 归档 114 件，逐件 sha 与回滚脚本见 `reports/out-archive-20261105.md`）；
> ③ 已被 2026-11-10「发送清理」删除、**只留账**（`versions/vk-kernel-identity.tsv` + 对应会话记录）。
> 换言之：这些历史件**不得**被当作「现成可上机件」引用；当前可用件只看 `out/` 实存 + `versions/vk-registry.tsv`。

| ID | 任务 | 状态 | 单元状态要求 | 验收判据 | 关键文件 |
|---|---|---|---|---|---|
| G1-0 | **U2 BL 解锁** | ✅ **已完成（2026-10-03）**——走**降级路**：线刷 `TB322FU_ZUXOS_1.1.11.073`（出厂 1.1/Android15）后 `fastboot oem unlock` 一次成功。第三方 blob（A3）与官网 sn.img（B）未用上且**已判死**（四代 1.5.x 换 ABL key）；路 C（EDL+testkey 链）成**保留资产**（`build-locked-chain.sh` 验证全绿） | U2 | ✅ `unlocked:yes`、`oem device-info: Device unlocked=true / critical unlocked=true` | `PITFALLS` #86–#87、`RUNBOOK` §0.5、`archive/topics/复盘-2026-10-03-BL解锁.md` |
| G1-1 | vk40 基线上机（持久直启） | ✅ **已完成（2026-10-03 U2）**：b 槽刷 blank dtbo + vk40 RAM 直启，后切持久版；重启后 `findmnt /`=`/dev/sda17`（ext4），**Phosh 自启**（phoc/phosh/gnome-session 在跑）。踩坑：`fastboot boot` 不清 dtbo 会卡 logo（`PITFALLS`/`复盘.md`） | U2（**已解锁**） | `uname -r`=`7.2.0-debug-gba28ec16f01f-dirty`；`findmnt /` 持久根=linux17 | `../RUNBOOK-BRINGUP/README.md`、`bootslot-b/boot_b_vk40.img` |
| G1-2 | GPT 手术：按 §3.2 体量给 `linux17` | ✅ **已完成（2026-10-03 U2）**：`userdata` 449.7→**256.7 GiB**、新增 `linux17`=**193.0 GiB**（idx16，`/dev/sda17`）；写后重 dump 校验 CRC OK | U2 | `list` 读回：`linux17` 末扇区=`last_usable`、CRC OK | `backup/HA2EXB0E-16+512/gpt_{main0,backup0}.bin`、`gpt_post-surgery_*` |
| G1-3 | 恢复持久 rootfs（3.44 GB 归档） | ✅ **已完成**：`mkfs.ext4 -L linux17` + 解包 30852 项（8.3 GB）→ 持久根 | U2 | `df /` 与归档项数一致；Phosh 自启 | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` |
| **G1-23** | **vk34→vk40 未验证增量回归审核** | ✅ **已闭合（2026-10-26）**：三窗口合计 **47.5 min**、7 项计数全 0（`reports/g1-23-windows-20261026.md`）；**局限** = 三窗口均 `dpms=On`，未覆盖熄屏/唤醒转换（该路径样本由 Q24 在 7.3 线 41 发 0 死亡覆盖）。历史沿革（vk34 后逐 hunk 二分、vk64 单窗口复核、两次口径更正）见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行038-G1-23.md`⟫ |blank` 命中 0），**未覆盖熄屏/唤醒转换**；转换路径样本另有来源（7.3 线 Q24 41 发 0 死亡），故不补窗口。 | 任一 mainline | 同口径 dmesg 计数（vblank/PPM ≥3 轮长时窗） | `archive/topics/AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md`、`AUDIT-since-vk34-2026-10-03.md`、`TASKS §5 Q22`、`reports/g1-23-windows-20261026.md` |
| **G1-22** | **熄屏/睡眠稳定性（Q24）** | 🟢 **根因已指名、停止采样（2026-10-23）**：7.2 血统缺上游 `skip retention by default`（7.3 已带该修复 ⇒ 41 发 0 死亡，日常线不需要本地补丁）⇒ 不再投 Q24 采样；`vk149` 臂 5 发全废 ⇒ **0 有效样本、假设未被否证**。日常仍用 `cam-mode.sh on/off` 互斥（**安全策略，非既成事实**）。口径沿革与证据见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行039-G1-22.md`⟫ | 任一 mainline | 装相机模块后长时空闲不断电 | `scripts/cam-mode.sh`、`scripts/sleep-sweep.sh`、`scripts/n5b-vk64-death-rate.sh` |
| **G1-24** | **Linux 侧刷机控制**（reboot→fastboot、选槽、清启动次数） | ✅ **S1/S2 已交付（2026-10-03 深夜实测）**：`scripts/eldroid-bootctl` + `flash-recovery.sh`；内核分支 `elden/vk41-psci-reboot` 把 reason `bootloader`/`edl` 映射为 **PSCI SYSTEM_RESET2 vendor reset**，`reboot bootloader` 真进 fastboot（否定 SDAM/BCB 三路）。⚠️ 上游该机制为 13 补丁大系列（未合并），本树是最小设备侧钩子。**固化（2026-10-08）**：钩子已 cherry-pick 落入基线分支 `v7.2-elden`（44137cb4e，编译验证 `psci.o` 通过）；`elden/*` 开发分支（vk47/vk53/vk54/vk63 源）均已含；**实机复验（vk47clean bd114ca33，U2 在机）**：`reboot2 bootloader` → 22 s 进 fastboot（HA2EXB0E）→ `fastboot reboot` 正常回 Linux。**推送状态（2026-10-08 核实）**：gitlab 镜像线（自有 y700-elden-kernel，main=fe54fcfff）已含逐字节相同钩子（e7453f538）；origin（GEEKiDoS 上游）无写权限且本地 shallow，不推。剩：`reboot edl` 实测（**待办：推迟到下次需要修改分区表时再做**，2026-10-08 用户决定；EDL 兑底场景为 GPT 手术）、TWRP 路线、slot 写校验（合流 C7） | 任一 mainline | `reboot bootloader` 进 fastboot ✅；slot 写后读回校验 | `archive/topics/FLASHCTL-2026-10-03.md`、`scripts/eldroid-bootctl`、`PITFALLS` #88 |
| **G1-25** | **桌面电源/会话（无 systemd）** | ✅ **已真机验证（2026-10-03 深夜）**：真根因=elogind helper `/sbin/{poweroff,reboot,halt}` 是 busybox applet，**不带 `-f` 只 `kill(1,…)`**，而 PID1=`/init`(shell) 不处理 → 假成功并让 elogind 永久卡 `OperationInProgress`。修复=`scripts/fix-logind-poweroff.sh`（换 `busybox <applet> -f`，幂等）。⚠️ USB 连着时 `loginctl poweroff` 会立即重启（疑 VBUS/充电检测自动开机）→ 关机前先断 USB | U2 | 长按电源键→菜单「立即关机」真断电 | `archive/topics/LOGIND-POWEROFF-2026-10-03.md`、`PITFALLS` #89、`scripts/fix-logind-poweroff.sh` |
| **G1-26** | **用户态深色模式 / 主题配色切换无效**（Phosh 0.55，Alpine） | ✅ **已上机复核通过（2026-10-11）**。根因（2026-10-05，lane `dt-ui` 会话 `01a10736-a2dd`）：`gtk-theme='Adwaita-dark'` 在 GTK3 **解析失败→回退浅色 Adwaita**（深色变体应靠 `prefer-dark`+主题名 **`Adwaita`**）。**修复=`gtk-theme='Adwaita'`**，设备 dconf 已持久（`/home/xuqianhui1001/.config/dconf/user`）；`grim` 截屏三态取证：`color-scheme=default`→浅色、`prefer-light`→浅色、`prefer-dark`→深色（`gnome-control-center`，GTK4/libadwaita）⇒ **深/浅即时切换成立**；portal `org.freedesktop.appearance color-scheme` 映射 0/2/1 正确。accent 同源：phosh 源码对 `theme_name=='Adwaita-dark'` 提前 return ⇒ 改 `Adwaita` 后放行。证据 `reports/userland-dark-brightness-verify-20261011.md`、`logs/ui-20261011/`⚠️MIGRATION-LOST(日志未随迁)。⚠️ 操作坑：`gsettings` 写入须 `dbus-run-session`（裸写不生效，见 `PITFALLS` #103） | U2 | ✅ 切深色即时变化（截屏为准） | `archive/topics/DT-UI-2026-10-05.md`、`reports/userland-dark-brightness-verify-20261011.md` |
| **G1-27** | **长按电源键菜单图标反色**（关机/紧急联系/锁屏等图标非常黑、深色背景分不清） | ✅ **同源修复，2026-10-11 复核通过**（symbolic 图标取主题前景色；浅色主题→近黑前景画在深色弹窗上）。`gtk-theme='Adwaita'` 后前景转浅，顶栏 symbolic 图标清晰可辨 | U2 | 电源菜单四图标在深色背景下清晰可辨 | 同 G1-26 |
| **G1-28** | **状态栏亮度滑块无效**（亮度固定） | ✅ **已闭环（用户 2026-10-11 实机确认滑块拖动生效）**。根因（2026-10-05）：elogind `Session.SetBrightness` 无真会话时恒 `EISDIR`。**候选 A（greetd `initial_session` 建真 logind 会话）已上机**：`loginctl list-sessions` 有 `c1`（user 1000/seat0/tty7/active）；2026-10-11 复核 `Session.SetBrightness backlight aw99706-backlight 1200` **实测生效**（sysfs 160→1200）；读 phosh 0.55.1 源码 `src/backlight-sysfs.c`：**背光只有 logind 一条路径、无 sysfs 直写后备** ⇒ 滑块后台链路成立。**剩**：滑块拖拽目视未做——本机 `CONFIG_INPUT_UINPUT` 未开、无 `/dev/uinput`，不能注入触摸打开快速设置；UI 同步（udev `on_backlight_changed`→`g_object_notify`）为代码可推断。附带：`gsd-power` 未导出 `Power.Screen` 接口 ⇒ g-c-c Power 面板无亮度行（另一条路径，与 Phosh 滑块无关，见 `PITFALLS` #187）。证据 `reports/userland-dark-brightness-verify-20261011.md` | U2 | ✅ 滑块拖动即时生效（用户实机确认） | `archive/topics/DT-UI-2026-10-05.md` §4、`archive/topics/USERLAND-PKGS-2026-10-05.md` §U1、`reports/userland-dark-brightness-verify-20261011.md` |
| **G1-29** | **间接引导层（GRUB 类/UEFI）——摆脱 boot.img 96 MiB 限制** | ✅ **两种形态都通（2026-11-10 深夜）**：① **零写盘形态**（2026-11-08 起）：`fastboot boot` 的 UEFI 件交棒后内核从 ESP 的 `\boot\boot.img` 起，cmdline 带 `elden_bootloader=esp`；② **flashed 形态**（2026-11-10 打通）：`boot_a` = p69 UEFI + `active=a` → **129.2 s** 起 Linux（基线 54.5 s + R70 **74.3 s** 三级停留，证明我们的固件确实执行）+ logfs 信标 `R68LOG n=3 s1:bds-in s2:r54-in s3:blk-enum s4:blk-conn s5:fs-enum s9:esp-ld-ok` + `elden_bootloader=esp`。**flashed 三年（11-09/10）全败的真根因 = `dtbo_a`**：原厂 `dtbo_a` 是合法 Android DTBO（`D7B7AB1E`/23.3 MB），ABL 在 `BootLinux` 后把它的 overlay 合进**我们的** Linux DTB ⇒ 卡联想 logo、USB 不枚举、~10 s 回落；`dtbo_b` 早在 10-03 就写成全 0 ⇒「`_b` 一直好、`_a` 一直坏」。**这是项目第一天的坑**（`PITFALLS/sessions/01`「假 dtbo 必须两个槽都写」、`sessions/02` 第 10 条），p60–p69 全打在 `_a` 上 ⇒ 每发注定卡 logo。**两条旧结论否证**：`vbmeta_a` 不是墙（原厂 Flags 0、哈希必然不匹配也照样起，`#601`）；`logfs` 对最近启动根本不写（前后 sha 相同 ⇒ `#594/#597` 的「信标未变 ⇒ 没跑到」不成立，`#602`）。配方 = `truncate -s 33554432` 刷 `dtbo_a` 全 0 + `boot_a` 刷件（`vbmeta_a` 不用动）；工具 `scripts/uefi-flashed-trial.sh --part <分区>`。**剩余**：BDS/GRUB 菜单交互、冷启动回归、把「a 槽 dtbo 清零」写进设备分派脚本。**现状与判据只读** §5「2026-11-10（深夜，`dtbo_a` 真根因）」块 + `reports/uefi-dtbo-a-rootcause-20261110.md`；历史沿革（p45–p58 定案、看门狗三路证伪、路线 A 失败、p63–p69 各轮）见 §5 上方各块与 `sessions/2026-11-10-G1-29沿革.md`。 | U2（只读） | **已满足**：flashed 形态（写 `boot_a`）起到用户态 + 内核从 ESP 起（`elden_bootloader=esp`）；`root=LABEL=linux17`。**未做**：屏上 BDS/GRUB 菜单交互取证、`boot_a` 冷启动（POR）回归 | `archive/topics/BOOTCHAIN-2026-10-05.md`、`UEFI-UFS-BRINGUP-2026-10-05.md`、`UEFI-UFS-UPSTREAM-ASK-2026-10-05.md`、`TASKS §5 Q25`、`reports/uefi-dtbo-a-rootcause-20261110.md` |
| **G1-30** | **boot.img 立即瘦身（=G1-29 路线 C）** | ❌ **口径更正（2026-10-06）**：slim 能打到 20.8 MiB，但 **vk60 实机=进桌面、外设全不可用**——**归因 = initramfs 打包（最小 initramfs 无 `/lib/firmware`），不是驱动/内核**（`PITFALLS` #113/#115、`archive/topics/ATTRIBUTION-AUDIT-2026-10-06.md`）⇒ **slim 不作日常启动**。boot_b 替换版改走 **vk61**=原完整 ramdisk 只换修好的 `/init`（内核/固件/模块零回归，83.3 MB < 96 MiB，已零写盘验收）。真机 busybox **有 findfs、无 blkid/mountpoint**（#112） | U2 | —（slim 不用于日常启动） | `archive/topics/BOOTSLIM-2026-10-05.md`、`INIT-HARDEN-2026-10-06.md` §9–§11、`out/boot-elden-vk61.manifest` |
| **G1-31** | **GNU 用户态工具补装**（AI 调试高频失效率） | ✅ **已完成（2026-10-06 U2）**：`coreutils findutils grep sed gawk procps-ng curl wget jq rsync socat tcpdump zstd xz tree less`（735→760 包，world 104→120 行）。设备无默认路由 ⇒ 借**主机代理** `http://192.168.7.2:7897`。**重启回归 ×2 通过**（GNU 会 shadow busybox，含 init 同 PATH）。 | 任一 mainline | `sed/grep/find/sort/awk/curl/jq --version`、`ps -p 1`、`date -d '1 hour ago'` 全 rc=0 | `.pi/plans/2026-10-06-用户态查漏补缺.md` P1、`PITFALLS` #120/#121/#122、`rootfs/build-rootfs.sh` |
| **G1-32** | **OpenRC 化（init 交接，替代自研服务编排）** | ✅ **已完成（2026-10-06 U2）**：Alpine OpenRC 已装但 `runlevels` 空 ⇒ `/init` 保生命线（usb0/sshd/ttyGS0）后按 `/etc/elden-init-mode` `exec /sbin/init` → inittab → openrc。**PID1=`/sbin/init`**；`rc-status default` 全 `started`；**G1-25 关机链结构性修复**（干净 `loginctl reboot` 实测通过，wrapper 按模式选 `-f`）。回退 `echo legacy >/etc/elden-init-mode; reboot`。 | 任一 mainline | `rc-status` default 全 started + `ps -p 1` = `/sbin/init` + `loginctl reboot` 干净重启 | `scripts/openrc-enable.sh`、`initramfs/init`、`scripts/fix-logind-poweroff.sh`、`rootfs/persistent-overlay/` |
| **G1-33** | **相机 × 熄屏共存（Q24 修复）** | 🟢 **已随根因指名而结项（2026-10-23）**：修复 = 上游 `skip retention by default`（7.3 线已含）；**7.3 日常线不需要本地补丁**，DT/驱动侧不再需要任何变体。**与 G1-22 同一条 bug（历史双 ID，非两个任务）**，状态/样本/口径**只在 G1-22 行与本文件 §5 Q24 维护**，本行只保留交付面：DT/驱动侧变体（H1 去 power-domains 7/9、H2 单挂 MX、D1 `use_rpm=false` 6/9、D2 去 `critical_cbcrs` 7/9）均未根治；E4a/FIX-3/FIX-2 的 2026-10-10 上机判定**已作废**（测的是 `olddefconfig` 删掉 `ARCH_QCOM` 的死内核，`PITFALLS` #162） | 任一 mainline | 相机常驻 + 装 cambist 后长时空闲不断电 | `patches/`、`out/boot-elden-vk63.manifest`（历史）、`PITFALLS` #162/#177 |
| **G1-34** | **加速度计/重力传感器（SSC/QRTR 路线上线；SLPI 原生 IIO 为后续可选线）** |✅ **已修好并上机验证（2026-10-30）**：根因是「**修复从未进镜像**」—— `fastrpc.c:2599` 用 `qcom,non-secure-domain` 决定建不建非安全域实例，而该属性只存在于 `build/vk151` 的未提交工作区 ⇒ 在机 vk172 的 DTB 早于它 ⇒ 只建 `fastrpc-adsp-secure`。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行55-G1-34.md`⟫ | Alpine 根 + Debian 根 | `net.hadess.SensorProxy` accel/light/prox 全 true（两棵根） | `PITFALLS` #442/#443（`PITFALLS/sessions/107-*`）、`reports/debian-root-accounts-sensors-20261026.md` |
| **G1-35** | **设备网络自愈（HTTPS 信任链 + PMTU）** | ✅ **信任链已修复并冷启动验证（2026-10-18）**：8 个 `/etc` 配置被清成 **0 字节**，`/etc/ca-certificates.conf` 空 ⇒ `update-ca-certificates` 每次写出 **0 字节** bundle（rc=0 静默成功）⇒ **所有 HTTPS 立即失败**（`curl: (77) error adding trust anchors` / git reset / apk 校验失败）。**`apk fix ca-certificates` 修不了**（把 0 字节活文件当"用户改动"，只再写 `.apk-new`，实测两次无效）⇒ 显式 `mv *.apk-new → 活文件`，无 `.apk-new` 时从 `mozilla/*.crt` 重建 conf。修后 bundle 181724 字节/121 证书，curl 全 200。 🟡 **PMTU 黑洞已缓解未根治**：手机热点广播 MTU 1500、上游实际 **1400** 且无 ICMP frag-needed；OpenSSL 3.5 默认后量子曲线 `X25519MLKEM768` 把 ClientHello 撑到 **1423 字节**必然拆段 ⇒ 抓包见「满 MSS 首段被丢 + 服务端 `ack 1` 回退 + SACK 只认尾段 ⇒ 无限重传死锁」；同 MTU 下 MLKEM 80% vs `X25519` 98%（各 40 次）⇒ 仅 `gitlab.freedesktop.org`/`gnome`（Fastly 段）受影响，国内站 0 失败。已落地 `wlan0 mtu 1400` + `power_save off`，git 失败 35%→~10%。自愈脚本 `scripts/net-selfheal.sh`（幂等，`--check` 只报告），触发 = OpenRC `local`（等 wlan0 UP）+ `NM dispatcher.d`，**冷启动注故障态验证通过**。证据 `reports/net-https-mtu-rootcause-20261018.md`、`PITFALLS §49 #340–#342` | 任一 mainline | `net-selfheal.sh --check` rc=0；冷重启后 mtu=1400、conf/bundle 非空、curl 200；git fd.o 失败率 <15% | `scripts/net-selfheal.sh`、`rootfs/persistent-overlay/{etc-local.d,etc-NM-dispatcher,usr-local-sbin}.tar.gz`、`PITFALLS/sessions/49-设备网络HTTPS全废与PMTU黑洞.md` |
| **G1-36** | **WiFi 可用候选榜不刷新（连通态只剩已连接项）** | ✅ **根因已定并修复（2026-10-19 U2 vk127）**：不是 ath12k/固件问题——NM 1.52.2 在 ACTIVATED 时 **禁止自己做周期扫描**（`_scan_notify_allowed()` → `periodic_allowed=FALSE`），把复扫交给 supplicant 的 `bgscan`，而 NM 把该串**写死**为 `simple:30:-70:86400`（`nm_supplicant_config_add_bgscan()`；连接级 `802-11-wireless.bgscan` 在 1.52 里**不被读取**）⇒ 信号好于 -70 dBm 时 = 24 h 才扫 ⇒ supplicant BSS 缓存按 age(180 s) 过期被清 ⇒ NM 删 AP 对象 ⇒ 候选榜只剩当前连接项。**实测**：NM 重启后仅 1 次连接期扫描，120 s 内 0 次扫描事件，AP **35 → 1**；`nmcli dev wifi rescan` 后 **1 → 24**（12 s）——与用户「关开一次即恢复」完全一致。**修复** = `wifi-scan-refresh` OpenRC 服务：连通态每 **150 s** 显式 RequestScan（间隔必须 < `bss_expiration_age` 180 s；全信道 110 信道 5.6–8.4 s ≈ 4–6% 占空比），未连接时跳过（NM 自扫 ≤120 s）。**上机验证**：服务存活 470 s、扫描按 +0/+150 s 节奏、aps 24→27→26→22→26→28 不再塌；断开后 `--once` 正确跳过 | 任一 mainline | 连通态每 ~150 s 有 `scan started`；`nmcli dev wifi list --rescan no` 的 BSSID 数不跌到 1；`wifi-scan-refresh.sh --check` rc=0 | `scripts/wifi-scan-refresh.sh`、`rootfs/persistent-overlay/etc-initd-wifi-scan-refresh`、`etc-conf.d-wifi-scan-refresh`、`reports/wifi-scan-stale-20261019.md`、`PITFALLS §52 #354–#356` |
| **G1-37** | **日用用户态基线（sudo / locale / 中文字体 / 输入法 / portal / keyring）** | ✅ **已完成（2026-11-07 U2 vk172；2026-11-09 zram 项亦收口）**：根因 = 两张清单覆盖面差（`apt-list.txt` 源自 Alpine `apk-world` + `--no-install-recommends`），处置 = **不引入 `mobian-*`/`phosh-core` 元包**，自建正交三件套 `rootfs/debian/daily-baseline.tsv` + `daily-baseline.sh` + `scripts/mobian-daily-baseline.sh`（`--check` 幂等）。实测：设备包 1355→1625（0 升级/0 删除）、`sudo -n true` OK、`locale -a` 有 zh_CN.utf8、`fc-match` = Noto Sans CJK SC、`systemctl --failed` 空；zram 已由内核门收口（`CONFIG_ZRAM=m` + `zramswap` active + `zramctl` 7.3G SWAP，`PITFALLS #573`） | 任一 mainline + Debian/Mobian 根 | `bash scripts/mobian-daily-baseline.sh --check` rc=0；`sudo -n true` rc=0；`fc-match "sans-serif:lang=zh-cn"` 含 CJK；`check-pkgmap.sh` FAIL=0 | `rootfs/debian/daily-baseline.tsv`、`rootfs/debian/daily-baseline.sh`、`scripts/mobian-daily-baseline.sh`、`reports/mobian-daily-baseline-20261107.md`、`reports/artifacts/zram-closeout-20261109/verify.txt`、`PITFALLS/sessions/05-设备上装包环境.md` #538–#541；逐轮 → `TASKS/sessions/2026-11-14-TASKS-1-G1-37-38沿革.md` |
| **G1-38** | **OSK（虚拟键盘）自动弹出 / 自动收起** | 🟡 **主链已通、剩四类边角样本（2026-11-13 口径）**：桥已固化（`/etc/systemd/user/elden-ime-focusd.service` + `daily-baseline.sh` §3b2）+ 源码四改（零矩形 2 s 确认／`Enable(false)` 即收／`State==-1` 宽限 5 s／`PropertiesChanged` 本地可见性 + 兜底超时 `ELDEN_IME_IDLE_SEC=300`）已上机（`PITFALLS #624`）；收起延时 42 991→2 183 ms（`#644`）；「候选词又没了」根因 = `daily-baseline.sh` 把 `Items/0` 写成 `keyboard-us`（`#643`，已修，判据 `Items/0=rime`）。**未验**：GTK3/Qt 各一例、Alt+Tab 跨窗漏收、候选窗与 stevia 重叠。**未决策**：preedit/候选需 kimpanel 侧（focusd）自绘（`#645`） | 任一（需 Linux 侧会话与真 IC） | 上机判据（2026-11-12 已过）：`is-active`=active、`busctl --user status org.kde.impanel` PID 对得上、`kill -9` 后 5 s 自愈、`SetRelativeSpotRect(10,20,100,40)`⇒`Visible=true`、`State=0`⇒false、`daily-baseline.sh --check` `MISS=0`；Firefox URL 栏真 IC 自动弹/收（截图 `reports/artifacts/ime-osk-focusd-20261112/firefox-urlbar-osk.png`） | 五失效点原文与逐轮取证 → `TASKS/sessions/2026-11-14-TASKS-1-G1-37-38沿革.md`、`reports/ime-osk-lifecycle-20261112.md`；`PITFALLS #619/#624/#643/#644/#645` |

**★2026-11-13 候选窗方案 A 试行后撤下（`PITFALLS #646`）**：按 #645 的判断在 focusd 里加 `org.elden.ImePanel` 信号转发 + 新写 GTK4 layer-shell 浮条 `rootfs/debian/ime/elden-ime-candidates.{py,service}`（渲染自检通过：`nihao` + `1 你 2 那 …` 高亮）。**真机不可用**：用户实测「输 `n` 一瞬间候选窗把整个页面顶掉、再返回，组字缓冲被直接提交上屏」⇒ 比没有更糟。判断 = **layer surface 的 map/unmap 触发焦点重算、打断客户端输入上下文**（组字期间 fcitx 还会穿插空 lookup，叠加抖动）。已 `disable --now` + 从 `daily-baseline.sh` 撤下（代码留库作下次起点）。**重做硬约束**：surface 全程 mapped、只切透明度/内容；验收必须先证「打字过程中 `NotifyFocusOut` = 0」。**结论：候选窗在本栈上属于「有明确前置条件才做」的项，不再是随手补丁**。

**G1-38 剩余只差真机四类样本**（Firefox/GTK3/Qt 各一例弹起·失焦收·Alt+Tab 漏收·无抖动），需要人在解锁后的桌面会话上做。**★2026-11-13 夜（C-U7 上机，`PITFALLS #653`）**：① **phoc 换 0.59~rc1 件不退化**（A 臂发行版原件 56 全局/syncobj 0、B 臂我们的件 57 全局/syncobj 1，OSK 行为两臂一致）；② **发现并修掉一个真回归**——`focusd` 的 `State==0 ⇒ osk_hide` 无条件生效，而 GTK3 在本栈**不建 fcitx IC**（`DebugInfo` 只有 `program:phosh`）⇒ 键盘弹起后 1 s 内被自己收掉；修法 = `fcitx_seen_active` 闸门（已上机：`Visible` 连续 8 s 保持 true + 截图可见完整 stevia 键盘），产物 `out/ime-host/elden-ime-focusd` sha `5cf98e1d…`；③ **遗留**：GTK3 仍不建 fcitx IC ⇒ 中文组词链路未通，且 `#618` 的「`GTK_IM_MODULE=wayland` → Visible=true」旧判据在 0.59 栈上**不再成立**。

**处置（§4 有改动点/代价/判据）**：(a) focusd 固化成 systemd user unit（照 `fcitx5.service` 模式，`/etc/systemd/user` + `graphical-session.target.wants`）+ 源码三改（零矩形过滤／兜底超时／非阻塞查询）+ `daily-baseline.sh` 一块 ⇒ 本机可静态/构建验证，上机只需重登一次；(b) 换单栈（fcitx5 `waylandim` + `wvkbd`）需先有 phoc `bb1f7465`，且候选窗问题不因此消失 | Debian/Mobian 根 | 冷启动后点输入框自动弹（Firefox / GTK3 / Qt 各 ≥1 例），失焦或关窗自动收；无残留悬浮键盘、无「弹了又收」抖动；判据命令见报告 §5（P0–P4 共 23 条） | `reports/ime-osk-lifecycle-20261112.md`、`reports/ime-osk-firefox-rootcause-20261112.md`、`reports/ime-osk-pop-20261111.md`、`PITFALLS #615/#618/#619`、`packaging/elden-userland/build/elden-ime-focusd.*`、`rootfs/debian/ime/`、`probes/ime/` |
| **G1-4** | **音频可听（播放+输入）** | ✅ **播放 2026-10-04 实测听声**：根因=tplg MI2S **SD 线错**（SD0→SD1，`PITFALLS` #90）；PipeWire+UCM2 桌面链路 ✅。**输入 ✅ 2026-10-04**：本机麦克风=**模拟麦接 WCD939x**（非 DMIC）；WCD939x bring-up（DTS codec+swr1/2+TX3、去 VA DMIC）+采集 DAPM 控件 → `arecord -D default` 出数据并持久化 UCM2 `Mic`。**R3 裸 ALSA**：`scripts/audio-alsa-init.sh` 幂等设路由，无桌面 `aplay/arecord -D default` 开箱可用（增益 400）。R1 有线耳麦：代码就绪、**硬件缺失（无 3.5mm/转接头）冻结**；FSA4480（非 `wcd_usbss`）需编 built-in。R2 双麦=AMIC1+AMIC4（未做，低价值） | 任一 mainline | 扬声器出声 ✅；`arecord`/`aplay -D default` rc=0 ✅ | `archive/topics/AUDIO-SDLINE-2026-10-04.md`、`WCD939X-2026-10-04.md`、`HEADSET-HW-2026-10-04.md`、`MIC-ARRAY-2026-10-04.md`、`patches/0011`、`scripts/audio-alsa-init.sh` |
| **G1-5** | **相机出流** | ✅ **出流 + AE + 相机 App 出图全部达成（2026-10-18 在机 vk127 / 7.3-rc7）**：后摄 `s5kjns` **30.06 fps / 4072×3072 满帧**、前摄 `gc08a8` **30.26 fps / 3264×2448 满帧**，dmesg 零 `camss/vfe/EPIPE/EINVAL`；AE 收敛后**后摄 115.2 / 前摄 133.5**（RGB mean 均正常）。三个 AE 独立 bug 已修：`exposureTarget` 有不可达下限、`gainMinStep` 被整数除法截断、helper 增益语义必须与驱动一致（identity）。**⚠ 已推翻两条旧结论**：「软 ISP 只写第 0 帧」、「libcrypto 构建致黑帧」——后者两臂同配方对照证明无因果。详见 `PITFALLS` #320–#330、`reports/camera-linux-vk127-20261018-agc-rootcause.md`、过程叙事 `reports/tasks-narrative-archive-20261019.md` | 任一 mainline | `cam`/`libcamerasrc` 出真实画面；Snapshot 预览+录像朝向正 | `patches/libcamera-ae-totalfix-20261018/`、`logs/cam-bright-20261018/`；**闪光灯（2026-11-13 口径更正）：手电筒本身早已可用**（Alpine 时期起状态栏手电筒即可点亮；本机 `white:flash` 只有一颗**后摄** LED，没有「前置灯光」这回事，旧文「前置闪光灯」是误称）。本轮在机复测：`echo 255 > /sys/class/leds/white:flash/brightness` → 读回 255、`echo 0` → 读回 0、`flash_fault` 空 ⇒ **sysfs/状态栏路径正常**。**剩余缺口只两条可选增强** = libcamera 不认 `MEDIA_ENT_F_FLASH`（`cam` 里没有闪光灯控制项）+ flash LED NTC 温度监控（`patches/0013-flash-led-ntc-thermal.patch` 提案未上机）→ `reports/front-camera-flash-20261019.md`** |
| **G1-6** | TF 卡写稳定性 | ✅ **新卡收口（2026-10-26 复测，判据一次跑完；旧卡废置不追）**：新卡 `mmcblk0` **CBADS 58.6 GiB / 03\/2022 / CID `6f0303434241445310aa000e02016300`** ⇒ `mkfs.ext4 -L tftest` 后 `tf-stress.sh --fsck -r 3`（small=2000×4K、large=64×1M）= **不一致 0**、`err_stats` **15 项全 0**、`e2fsck -fn` **clean**；ios = **37.5 MHz / 4-bit / SD_HS / 3.3 V**（与「level-shifter 只封顶 SD_HS」旧结论逐字一致）。**判据「≥3 轮 0 不一致 + fsck clean」已满足 ⇒ 收口（新卡）**。**旧卡已废置（用户 2026-10-26 明确）**，不再做旧卡 A/B，也不再按候选补丁做方向选择；`-d`(O_DIRECT)/加倍样本列为**不追**（仅当再出现新坏卡时重开）。2026-10-09「用户裁决搁置」**解除**。证据 `reports/tf-g16-retest-20261026.md`、`reports/trials/20261026T070115Z-tf-g16-card2-3r.json`。历史：历史状态：根因倾向卡本身 70–80%（2026-10-04 子代理）**：尺寸相关性（64MB 大块全对 / 8MB 小写间歇丢）、`err_stats` 全 0、`e2fsck` 前后一致、已是最保守 3.3V/SD_HS 档仍坏。**关键更正**：厂商 `qcom,uses_level_shifter` 唯一作用=SD_HS 封顶 37.5MHz，主线 `max-sd-hs-hz=<37500000>` 已等价 ⇒ 无效移植。5 个候选补丁（`patches/candidate-tf-*.patch`，按代价排序）+ 压测脚本 `scripts/tf-stress.sh` 就绪。**新卡已装入并复测通过（2026-10-26，见本条首段）；旧卡废置** | 任一 | 新卡连续 ≥3 轮 0 不一致 + `e2fsck -fn` 干净 | `archive/topics/TF卡-2026-10-04-subagent.md`、`scripts/tf-stress.sh` |
| G1-7 | BT 配对收口 | ✅ **已完成（用户 2026-10-06 实测：配对成功、TWS 实听可用）**。历史排查（保留备查、不再阻塞）：表象是 BR/EDR 高延迟而非「配对后断」；IBS 握手（H3）与固件深睡（H4）已排除，剩 H1(8 Mbps)/H2(CTS) 需单变量内核；4 个候选补丁 + `scripts/bt-link-test.sh` 备查。逐轮假设与 A/B 数字见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行056-G1-7.md`⟫ | 任一 | ✅ 用户实测配对 + TWS 可用（RTT 优化项可选） | `archive/topics/BT-2026-10-04-subagent.md`、`scripts/bt-link-test.sh` |
| G1-8 | CPU/GPU 基准（脚本已备） | 🟢 **已出分（2026-10-11 U2 vk64）**：Vulkan `vkmark` ~25532（3 轮）、GLES `es2gears` ~164 FPS（=165 Hz vsync 上限）、`sysbench cpu` ~19637 ev/s、`mem` 4129 MiB/s、`fio` 读 4024 MiB/s、温控峰 **81.9 °C（<82）**。**GL vs Vulkan 公平对比未完成**（Alpine 无 `glmark2`，GLES 数=vsync 上限）；渲染观察到「物体挤左上角」（疑显示缩放，另查，非阻塞） | 任一 mainline | `bench-run.sh` 出分 ✅；温控不破 82 °C ✅ | `archive/topics/BENCH-2026-10-11.md`、`logs/bench-20261011/`⚠️MIGRATION-LOST(日志未随迁)、`scripts/bench-run.sh`、`scripts/bench-install.sh` |
| G1-9 | DP 输出（解锁 `mdss_dp0`） | ✅ **已打通（2026-10-07，dp5 载具零写盘 + 用户实机目视确认出画面）**。**根因链（三步定位，此前误判「ADSP UCSI 未起」）**：① `PPM init failed, stop trying` 实为 `ucsi_init` **EPROBE_DEFER 重试 20 次放弃**（`failed to reset PPM` 从未打印 ⇒ ADSP UCSI PPM 本身通）；② defer 源 = `fwnode_usb_role_switch_get` ⇒ role switch 未注册 ⇒ **`dwc3_drd_init` 仅在 `dr_mode=otg` 时跑**，本机 DTS 写死 `peripheral`；③ otg 又被 `/delete-property/ usb-role-switch` 强制回 peripheral（GHWPARAMS0=DRD，硬件支持双角色）。**修复 = `dr_mode=otg` + `usb-role-switch` + `mdss_dp0 okay` 三处 DTS 同批**（内核提交 `6c1376907`）。dp5 实机：`card0-DP-1` connected+enabled+dpms=On、EDID `F27G32Q Pro` 2560×1440@180 preferred、`typec/port0-partner` 出现、vblank=0、DSI 同亮、Phosh 正常、外接实测出画面。**残余（非阻塞）**：放缩/横竖屏显示尚有问题（桌面侧，非物理链路） | 任一 | `/sys/class/drm/card0-DP-1` connected + 外接出画面 ✅ | `archive/topics/DP-2026-10-06.md`、`PITFALLS` #128、`out/boot-elden-dp5.manifest`（sha `096470c3…`） |
| G1-10 | ~~NFC compatible 修正~~ **取消：本机无 NFC 硬件（2026-10-06 取证）** | ❌ **不成立**：TB322FC vendor **无 `android.hardware.nfc.xml`**（feature 未声明）、vintf manifest 无 NFC HAL、`/lib64(/hw)` 无 NFC HAL 库、`/firmware` 无 NFC 固件、原厂运行服务无 NFC；GSMArena `NFC: No`。`elden.dts` 的 `st21nfc` 是**总线 `disabled` 的共用模板**，`stm_nfc_i2c.ko`/`st54spi_gpio` 多 SKU 共用；`ro.nfc.port=I2C` 为通用属性。**vk53 的 `&i2c0` 使能反而致硬关机（#108），已从驱动批次移除** | — | — | `PITFALLS` #108 |
| G1-11 | CDSP 启用（可选加分） | ✅ **已启用（2026-10-07 实机）**：`remoteproc1(cdsp) state=running`、`fw=qcom/sm8750/cdsp.mdt`，dmesg `remote processor cdsp is now up`（1.40 s）。**根因=固件变体+载具，非 PAS id**：① 原 DTS 用非 stock 单文件 `cdsp.mbn`/`cdsp_dtb.mbn`，单文件 `cdsp_dtb.mbn` 被 TZ PAS init 拒（`-22`）；stock SunP DTS 用 **split** `cdsp.mdt`/`cdsp_dtb.mdt`（DTS 已改，内核提交 `c132a1bc7`）。② **固件由 initramfs 加载**（switch_root 前 ~1.16 s），磁盘 rootfs 副本不生效 ⇒ split 必须打进 ramdisk（`build-initramfs.sh full` 已加注入）。**「PAS id 不匹配」假设否证**：反汇编 stock `qcom_q6v5_pas.ko` 的 `sun_cdsp_resource` = pas_id **18** / dtb_pas_id **0x25**，与主线 `sm8650_cdsp_resource` 完全一致。**boot_b 已持久化**（2026-10-07 刷入 `out/boot-elden-cdsp-vk47clean.manifest`（vk47clean 内核 + 模块一致），读回 sha 校验通过；`findmnt /`=`/dev/sda17`、cdsp `running`） | 任一 | `/sys/class/remoteproc/remoteproc1` running ✅ | `archive/topics/CDSP-FIX-2026-10-07.md`、`CDSP-PROBE-2026-10-06.md`、`PITFALLS` #127 |
| ✅ G1-12…21 | 显示 165 Hz、图形 A830、触屏、WiFi、BT 基础、充电+旁路、温控分级、带外串口、启动 ~5 s、触觉 | **已完成** | — | 见 `../DEVICE/README.md` §1.3 | `PANEL-REFRESH`/`THERMAL`/`CHARGE`/`OOB-CONSOLE` |

---

## 2. G2 任务分解（**前提：不依赖 Android**，参考社区资源做 ARM Linux 侧安卓兼容）

> 路线定义见 `README.md §6`。ID 前缀 `C`（compat）。

| ID | 任务 | 状态 | 层 | 验收 | 备注 |
|---|---|---|---|---|---|
| **C0** | **真 Android 对照取证**（趁单元还是 stock，**覆盖 a 槽前必做，不可复得**） | 🟢 **已采（2026-10-11，U2 `HA2EXB0E` a 槽 stock）**：`backup/HA2EXB0E-16+512/c0-baseline/`（22 文件 + SHA256SUMS）。要点：**Android 16 / build `ZUXOS_1.5.10.259_260611` / Widevine `L1` / HDCP 2.3 / BL 解锁 `orange` / 未 root / Google 账号 0 / 42 传感器 / AVF apex 在**。采集器 `scripts/c0-android-evidence.sh`（本轮修了容量档解析 bug）。U1 a 槽（stock+root）**可另采**（脚本历史文字针对 U1）；**root 专属项已判定无产出、不补采**（2026-10-13） | 基线 | `getprop` 全量 ✅、Widevine 级别 ✅、传感器清单 ✅、分区/包清单 ✅；**30 s 传感器 CSV + 5 App 录屏仍需人工**（真机账号未登录、未 root）；**PI 不在此列**（判定对象 = 容器 → C3 行） | 报告 `reports/c0-android-baseline-20261011.md`；见 `README.md §5` Q5 |
| **C1** | Waydroid 在 vk40 端到端复跑（去掉旧的 bind-mount 路由 workaround） | 🎯 **治本完成（2026-10-11，vk103 实机）**：根因 = 内核缺 **`CONFIG_IPV6_MULTIPLE_TABLES`**（+ IPv4 多路由表）⇒ netd `RouteController` 起不来；补上后**无 workaround** 即 `curl baidu=200`。2026-10-13 `vk126-c1` 在日常镜像口径复现判据；2026-10-19 vk127 复核「容器重启后 ~20 s 自愈出网」。历史（bridge 模块、vk95 半修）见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行072-C1.md`⟫ | 容器 | ✅ 无 workaround 出网（`curl baidu=200`，netd 自建 table 1002） | `reports/wd-netd-route-20261011.md`、`reports/c1-iprule-vk95-20261011.md`、`reports/wd-net-baseline-20261011.md`、`PITFALLS #184/#194` |
| C2 | Play / GMS 登录收口（旧结论：卡在外部上行与代理） | ✅ **已完成（2026-10-11，用户人工验证 GMS 服务可用、Google 登录成功）**。通路：容器经**宿主 Clash 代理**出网——容器内 `curl -x http://192.168.7.9:7897 https://www.google.com`=**302**、`https://github.com`=**200**（`192.168.7.9`=x86 主机 USB 链路 IP，宿主 Clash 监听 `0.0.0.0:7897`）⇒ 已设容器 Android 全局代理 `settings put global http_proxy 192.168.7.9:7897`。**★2026-10-27 前提变化**：主机 Clash 现在只听 `127.0.0.1:7890`（不再 `0.0.0.0:7897`）⇒ 设备侧必须先在主机跑 `scripts/host-net-proxy.sh`（`systemd-socket-activate`+`socket-proxyd` 暴露 7897，幂等、`--check`），否则容器 `http_proxy` 是死的（本轮容器里原值甚至是 `null`）。⚠ 在**平板本地**跑同订阅代理走不通（校园 wlan 到境外节点 `nc` 直连 fail）；容器走宿主代理可行。 | 容器 | Play Store 登录成功 + GMS 服务可用 ✅（人工） | `reports/wd-net-baseline-20261011.md`、`reports/wd-netd-route-20261011.md`、`archive/topics/PROXY-WAYDROID-2026-10-02.md` |
| C3 | **身份兼容性取证**（GMS/Play Integrity/Widevine 能做到哪一级）——**不预设结论** | 🟡 **书面三档结论已出（2026-11-10，权威 `reports/c3-pi-tiers-closeout-20261110.md`）**：GMS 可用（登录 + `generate_204`=204）；**Widevine 不存在**（只有 ClearKey ⇒ 比「L3」更低）；**PI BASIC/DEVICE 不加对策必失败**（`userdebug`+`test-keys`+非认证 fingerprint），加 PIF 类伪装只是**窗口期产物、不可承诺**；**PI STRONG 结构性不可达** —— 容器内 keymaster 4.0 为软实现（无 TEE）+ 整机 EL2 归签名 Gunyah + 2026-10-03 解锁后本体 verified-boot 已非 green（**换路线净增益 0**：redroid / VM / droidloom 同一结论）。**剩唯一动作** = 装 SPIC 取一次三档回包，把「必失败」从推理升级为实测（需你批准装 APK；判据表含「全绿则推翻本判读」）。原取证 `reports/c3-identity-drm-20261013.md` | 容器 | 出「社区先例 × 本机实测」对照表 + 回填 `README.md §6` §1 的 C2 格 | 先例：redroid / waydroid_script `certified` / WayDroid-ATV（arm64 GAPPS 有、L3 仅 x86-64；arm64 仅 A11 有、A13 无） / PlayIntegrityFork；**实测需设备+上行** |
| **C4** | **传感器注入原型**（~~uinput + UDP~~ **作废**→ **UDP HAL 真实现**） |✅ **已打通（2026-10-11，路线 C）**：宿主 gbinder 注入 daemon（`patches-userland/waydroid-sensord-udp/` = 上游 `service.cpp`/`Sensors.cpp` 原样 + 自写 UDP 版 `SensorFW`）装到 `/usr/local/bin/waydroid-sensord`； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行80-C4.md`⟫ | HAL | ✅ `dumpsys sensorservice` 列 6 个传感器且 running；数据流实测；自动旋转监听已连接 |`archive/topics/C4-SENSORS-2026-10-11.md`、`PITFALLS #185`、`out/sensord/android.hardware.sensors@1.0-service.waydroid`、`reports/research-waydroid-sensors-hal-20261011.md`（上游路线实测： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行80-C4.md`⟫ |
| C5 | 相机共享（`v4l2loopback` + sampler → 容器） | 🟡 **②b 已达成（2026-10-19）**：容器 `dumpsys media.camera` → **`Number of camera devices: 1`**（`Device 0 maps to "200"`, Facing Front），`camera-provider-2-4-ext` 状态由 `restarting`（crash-loop）转为 **`running` 稳定**，端到端真帧 **10 帧 / Y mean 107**。根因 = **四层独立缺陷**：容器 `IBinder` 比 AOSP 多一虚函数致 Bn vtable 错位、自编 `.so` 模板实例抢占平台 WEAK 符号、自生成 `android.hidl.manager.*` 盖掉平台实现、64 位 `kDevicePrefixLen` 用 `sizeof(ptr)` 导致设备号恒 0。**剩余 = U7（App 预览 / 前后摄切换）+ C3 身份/DRM 实测**。**★2026-10-27（U7 推进）**：宿主链路改 `gst → fdsink |v4l2-ctl --stream-out-mmap=8`（写端控 buffer 数，stock v4l2loopback、零补丁；`gst v4l2sink` 默认只申请 3 个，会被设备级共享队列压到 3 ⇒ `REQBUFS expected 4, got 3`）；源格式必须 **NV12**、`exclusive_caps=1`。**★2026-11-12 v4l2loopback 升级到上游 v0.15.4**（`/dev/video100` 在 vk184 上重新可用；此前 insmod EFAULT 的真根因不是版本而是 `build/daily/.config` 被 vk189-suspend 改动致 `struct video_device` 布局漂移 56 字节）——见 `reports/v4l2loopback-73-upgrade-20261112.md`。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行81-C5.md`⟫ | 容器 | 容器内相机出预览 | `scripts/waydroid-camera-bake.sh`、`patches/waydroid-camera-64bit-20261018/` **★2026-10-23 收尾复核：`Number of camera devices` 曾回落 0 —— 根因不是 provider，而是 `config_nodes` 里**从来没有 `/dev/video100` 的 bind**（2026-10-19 那次成功是会话内手工绑的，重启即丢）。已写入持久配置（`lxc.mount.entry = /dev/video100 ...`，`optional`）⇒ 重启后复现 **1 个设备**（`Device 0 maps to "200"`）。**前后摄语义已定**：external HAL 只有 1 个 external 设备，"切换" = 换 loopback 生产者（`cam-loopback.sh start front|rear`），两路均出帧（前 Y mean 51.6→54.3、后 19.6）。顺带修掉 `cam-loopback.sh start` 的**100% 假阳性拒启动**（旧判据命中内核线程 `[disp_snapshot]`）；坑见 `PITFALLS #373`。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行81-C5.md`⟫ |**★2026-10-28 第二轮（推翻上一版结论）**：`metadata is null` 是**关闭路径噪声**（static metadata 实为满 55 项）；真卡点两级 —— ① HAL **只在 MJPEG 源**下广告 JPEG(BLOB)（NV12 源只有 2 条 YUV 流，格式 33 缺席 ⇒ OpenCamera `no picture sizes` 即退出）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行81-C5.md`⟫ |
| C6 | 音频通路打通后的容器音频（PipeWire） | ✅ **闹钟已出声 + 开机持久（2026-10-11）**：输出链路本就通；无声 = **四层**容器/镜像缺陷叠加（vendor manifest 声明了无服务的 `media.omx` / internal 卷未扫描 + `alarm_alert=null` / `ccodec=0` 且只有 `OMX.google.*` / 容器无 `/dev/dma_heap`）。四层修完 codec=**53**、闹钟解码出声；构建侧已固化进 `m vendorimage`。逐层机制与命令见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行077-C6.md`⟫ | 容器 | 容器内播放有声 ✅；延迟与录音单独记 | `reports/container-audio-20261011.md`、`tools/wd-audio-test/`⚠️MIGRATION-LOST(工具未随迁) |
| C7 | `scripts/slot-switch.sh` 一键切槽 + 槽属性自检 | ✅ **已完成（2026-10-11）**：`status`/`a`/`b [--reboot]` 全路径；b 槽回 Linux 自动 `qbootctl -m b`（防 PITFALLS #181 扣 retry）；2026-10-11 复核 `status` 在 Linux 侧正常打印槽属性 | 双槽保险 | 两条命令完成往返切换 ✅ | 即便 a 槽可弃，也要保留回退手段 |
| C8 | **无 Android 的 VM 路线调研**（Gunyah guest on mainline / crosvm+`--parallel_vcpus`；KVM 已确认不可行） | 🟡 **书面结论已出（2026-10-02）**：维持低优先不立项——① 设备侧 KVM 不可达（XBL 锁 hyp，`-el2.dtb` overlay 只适用 dev kit）；② 独立 gunyah 驱动未进主线（本地 7.2 树无 `drivers/virt/gunyah`）；③ 唯一新路线=KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，配 `qemu-for-gunyah`，WIP） | VM | ✅ **探测已做（2026-10-10、boot_b/vk64）**：`dmesg` 仅见 reserved-memory `gunyah-hyp@80000000`（14 MiB 保留区），**无 `gh_rm`/gunyah 驱动**（本地 7.2 树无 `drivers/virt/gunyah`）⇒ 本树路线第一步不成立 ⇒ **按书面结论归档、维持低优先不立项**（若将来上带 gunyah 驱动的内核再探）**★2026-10-24 阶段 0/0b 实测阳性**（`reports/gunyah-stage0-positive-20261024.md`）：`ls /sys/bus/platform/devices` 有 **`gunyah-wdt`**（= `qcom_scm` 的 SMCCC UUID 询问命中 ⇒ 本机确实运行在 Gunyah guest 里），且自编 `gunyah_wdt.ko` probe 通过（`GUNYAH_WDT_STATUS` 返回 0）⇒ **SMCCC vendor-hyp 通道真实可用**；主线仍无 `drivers/virt/gunyah`（今日复核 `master`）。⇒ **由「维持不立项」改为「阶段 0 阳性，进入立项评估」**；**WoaA 已有本机型第三方先例**（`Droid-VM/edk2-gunyah` tested platforms 列出 `tb322fc`，crosvm+Gunyah+edk2-gunyah.fd，usbfs 仿真 xHCI 直通见 `Droid-VM/crosvm fb86c7b0`）；**2026-10-24 用户裁决：走纯 Linux 宿主（不借 Android/AVF），Android 侧项目只作材料参考，最终回收 Android 分区**（缺件全在 Linux 侧软件、可自建；源码已抓 `reference/gunyah-android15-6.6/`） | `archive/topics/EL2-VIRT-2026-10-02.md`、`../RESOURCES/README.md` §1.5 |
| C9 | 兼容层验收用例集 `README.md §5` §Q6 打分表 | ⬜ 新增 | 全部 | 5 维打分表出数 | — |
| **C10** | **马达透传（容器 vibrator HAL → aw86927 FF）** | ✅ **已打通（2026-10-13 `vk124-merged`；2026-10-17 vk127 补记 amplitude 默认 0 致静音，已改 255）**：镜像自带 vibrator HAL 只写主线不存在的 `leds`/`timed_output` 且不检查写失败 ⇒ Android 侧全绿、马达不动；桥 = `lxc.mount.entry` 覆盖 `/sys/class/leds` + 宿主 `elden-hapticd` 轮询 `FF_RUMBLE`。二期换自编 AIDL V2 HAL、三期固化进 `vendor.img`，Settings 强度档位靠静态 RRO。全过程与 kprobe 计数见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行081-C10.md`⟫ | HAL | 幅度/取消/每侧强度/RRO 有可查证据 + 人手体感确认 | `reports/waydroid-haptics-20261013.md` §7–§8、`PITFALLS #232–#246` |
| **C11** | **触屏中文输入法（唤起 / 折叠隐藏）** | ✅ **已上机验收（2026-10-20，vk127 / Phosh 0.55.0 / phoc 0.55.1）**：最终栈 = **squeekboard（OSK + `sm.puri.OSK0` 控制面 + seat 键盘）+ fcitx5 `--disable waylandim`（Rime 组词）+ `fcitx5-gtk3/gtk4`（候选窗由 IM 模块自绘）+ 自写 `elden-ime-focusd`（把 fcitx5 kimpanel 的 `SetRelativeSpotRect` 当聚焦信号 → `SetVisible(true)`）**。实测：点输入框自动弹键盘、敲 `nihao` 出候选、选 1 上屏**「你好」**；`SetVisible(false)` 收起（底部亮度 169→0）、`SetVisible(true)` 再唤起。**三处纠偏**：① 缺 `fcitx5-gtk` ⇒ 中文完全不工作（按键以字面字母进控件）；② fcitx5 若留 `waylandim` 会抢 IM 槽位 ⇒ squeekboard 哑；③ **上一轮的自编候选条 `candidate-bar` 完全不必要**（杀掉后候选照常）⇒ 已移入 `patches-userland/zh-ime/withdrawn/`。部署 `bash scripts/deploy-zh-ime.sh`（7/7 自检）。**剩余（不阻塞）**：整机重启后自启未验；自动收起无可靠信号（走触摸图标/Phosh 入口）；Qt 应用（`fcitx5-qt` 未装）与 Waydroid 容器内 IME 未验。**★2026-11-11 晚：现役 Debian 栈的唤起通路已打通**（两层根因都修：phoc 版本门 + `GTK_IM_MODULE=fcitx` 遮蔽 → `PITFALLS #615`/`#618`），Firefox/GTK3 均实测弹键盘 + 自动收起；剩中文组词上屏需真人，详见 §4 G1-37 条与 `reports/ime-osk-firefox-rootcause-20261112.md`。**★现役栈口径（2026-11-11）：本行的 ✅ 只覆盖 2026-10-20 的 Alpine + squeekboard 世代**；现役 Debian/Mobian 栈上「点输入框 OSK 不弹」= phoc 的版本门（`PITFALLS #615`，设备实测客户端发 `enable`、phoc 不转 `activate`），当前状态/三条处置/未闭环项**只在 §4 的 G1-37 条**维护，权威 `reports/ime-osk-pop-20261111.md`。 | 桌面 | 点输入框→触屏键盘→拼音→候选→上屏中文；可唤起可折叠 | `reports/zh-ime-touch-chinese-20261020.md`、`reports/ime-osk0-dbus-spec-20261020.md`（OSK0/kimpanel/wvkbd 源码取证）、`PITFALLS` §59（+§48/§50）、`patches-userland/zh-ime/` |
| **C12** | **droidloom 隔离试验**（Linux 原生跑 Android 应用，Wayland 直出窗口；**不替换 Waydroid**） | ✅ **L1–L4 全绿（2026-11-11 上机，用户目视确认窗口可用）**：aarch64 runtime 包（`0.1.0-30`，6.6 MB）在设备上摊开即执行，`droidloom-doctor` **13 过 / 1 阻塞 / 1 警告**；**subuid 100000 契约已修**（`usermod --add-subuids 300000-399999`，可回退）；唯一内核阻塞 `CONFIG_NF_TABLES` **片段已备并验证**（`patches/fragment-droidloom-nftables.config`，纯 nftables 40 行 diff、`ARCH_QCOM` 未受影响，验证后 `.config` 已回滚）。**★2026-11-10 关键翻转：合成器缺口不是内核/驱动问题** —— `DRM_CAP_SYNCOBJ_TIMELINE`=1、wlroots `check_syncobj_eventfd` 判据通过、EGL `native_fence_sync`+`KHR_wait_sync` 齐 ⇒ 创建条件全满足，只是 **phoc 0.58/0.59.rc1 全树都不调用 `wlr_linux_drm_syncobj_manager_v1_create`（0.59.rc1 也 0 命中，升级解决不了）**。**★2026-11-10 打通判据（headless 实证）**：`sway 1.12`（Debian，libwlroots-0.20.2）在 `WLR_BACKENDS=headless` 下 **广告 `wp_linux_drm_syncobj_manager_v1` v1**，`droidloom-wayland` 在其下**通过全部 Wayland 全局绑定**（对照 phoc 下直接 `global bind failure`）⇒ 图形前置可用「装 sway + headless 合成器」验证，**不必先编 phoc**。**★2026-11-10 上机实做**：① **L1 内核门槛已解除** —— `out/boot-elden-vk187b.img`（vk184 + nftables，`LOCALVERSION` 钉 `-vk184` 复用模块树）零写盘 1 发全绿：`nft list ruleset` rc=0（Waydroid 的 `lxc` 表已迁 nft）、`nft add/del table` OK、**doctor `ready=True blockers=0`**、DSI connected、wlp1s0 UP、waydroid RUNNING、容器 baidu=200；② image 包已下（964 MB）并摊装到 `/opt/dl-test`（2.5 GiB，四分区齐全），`/etc/droidloom/*` 手工铺好；③ **L3 被 rootfs 属主契约挡住（结构性）**：`host_storage::check_parent()` 要求 `data_dir` 全部祖先 `uid==0 && mode&0o022==0`，而本机 `/` `/etc` `/usr` `/var` 是 `1000:1000` + `0775`（迁移遗留）⇒ `unsafe Android storage parent`；**不改这些目录属主**（波及全系统）⇒ **C12 停在 L1 收口**，L3 记为「待将来 rootfs 重做时顺手解决」。④ 仍未做：真后端合成器（phoc 补一行 / sway DRM 后端）、GApps 自建。**★2026-11-11 L2 全链收口（主机补丁 + 上机两条判据全绿）**：phoc 补 `wlr_linux_drm_syncobj_manager_v1_create()`（条件 = renderer/backend `features.timeline`，`drm_fd` 为负回落 `wlr_renderer_get_drm_fd()`）；主机 headless A/B = 54 全局无 syncobj ↔ **55 全局有该 v1**。**上机（设备在版 phoc 0.58.0 / phosh 0.59~alpha1）**：改用 Debian 同版源码 + `debian/patches/Apply-upstream-patches.patch` + 内嵌 wlroots **静态** 重编 → `out/phoc-syncobj-arm64-20261111/phoc-0.58.0-syncobj`（sha256 `863731b0…`），`install` 后 `systemctl restart greetd`：① `wayland-info` = **57 全局含 `wp_linux_drm_syncobj_manager_v1` v1**；② `droidloom-wayland` **0 次 bind failure**、进入 `session mode: desktop`；Phosh 桌面正常（回退 = `phoc.orig-0.58.0`）。**★2026-11-11 L3+L4 打通**（上机，用户目视确认）：① 前置 swap 到 **RAM 启动 `vk187b`**（`reboot2 bootloader` → `fastboot boot out/boot-elden-vk187b.img`，零写盘；在机 `boot_b` 的 vk185 `CONFIG_NF_TABLES` 关闭 ⇒ doctor 不 ready）；② 四个门禁逐个关掉 = **subuid 给 root**（`root:400000:100000` 入 `/etc/subuid`+`/etc/subgid`）、**祖先属主**（`#608`：`/` `/var` `/var/lib` `…/1001/data` 改 root:root 非组写）、**`data_dir/{data,metadata}` 两个直接子目录**（`validate()` 要求存在，`prepare()` 以桌面用户跑因父目录 root 0755 静默失败 ⇒ 手建 0755 root）、**runtime 硬编码 `/usr/bin/droidloom-*`**（实验装置在 `/opt/dl-test` ⇒ 9 个软链）；③ 判据全部命中：`droidloomctl start --cell` → `started cell u1001`；`wait` → `Android is ready`；**`applications` → `listed 2 Android applications`**（Files / Settings）；`launch com.android.settings` 后 **窗口上屏、用户确认可用**（L4）。**★2026-11-11 收尾（C12 结项）**：① **已持久化** —— vk187b 写进 `boot_b`（读回 sha `8ab357ed…` 与主机件逐字一致，回滚件 `bootslot-b/boot_b-device-20261111.img`）；② **开机自启已 enable**（`droidloom.service` 链进 `graphical-session.target`，重启后自行起 cell，实测 `cell u1001 is running …; Android is ready`、`applications` 列出 2 个应用）；③ **通知通道：2026-11-11 复核已自愈、且「不能热补丁降级」（口径更正）**——boot 内 `journalctl -b | grep -c 'invalid Android frame'` = **0**、`droidloom-doctor` = **13 PASS / 1 WARN（`Host LSM hardening`，源码 `droidloom-doctor/src/lib.rs:767-791` 第 4 参 false = 非必需）/ 0 BLOCK**、15:38/15:41 两次 cell 会话 0 次失败、adb 实发通知宿主落盘 ⇒ 端到端可用；紧循环只在 **12:40–13:53 那一次会话**（1919 次 / 2 s ≈ **0.5 次/秒**，「1 次/秒」旧口径更正）。**ABI 错配假设被否证**：Android logcat 宣告 `DROIDLOOM_NOTIFICATIONS_ABI=3;`，与宿主 `strings` 同值。**降级方案 = 重编时加 `DROIDLOOM_NOTIFICATIONS=0` 门**（用户 2026-11-11 裁决「可以降级，等以后重编」）；二进制热补丁**不可行**（`Bridge::start` 返回 `Result` 经 sret 落栈 + `drop_in_place` 析构 ⇒ NOP 调用 = 垃圾 tag + UB，`PITFALLS #616`）。用户可见旧口径：：本 boot `invalid Android frame` **1919** 次 ↔ `Android connected` **1924** 次（≈1 次/秒的紧循环）；取证 = 宿主二进制只声明 `DROIDLOOM_NOTIFICATIONS_ABI=3;`（其余三个通道 ABI 均 1）、`system.img` 里**没有** ABI 字符串（Android 侧是编译期常量）、Android logcat 里**没有** `NotificationBridge`/`IllegalArgumentException`（`reports/droidloom-notifications-abi-20261111.md` 预测的错配症状未出现）⇒ 失败点在宿主侧帧解析，最可能仍是 runtime/image 的 26–30 修订间 ABI 演进没有源代码可对；④ msm_dpu 显式同步长时稳定性未测（`PITFALLS` #609–#613）。| 容器 | L1 `nft list ruleset` 不报错 + doctor `kernel.network_isolation` PASS；L2 `wayland-info` 出现 syncobj 且 `droidloom-wayland` 起来；L3 `droidloomctl applications` 列出应用；L4 一个 App 真开独立窗口 | `reports/droidloom-feasibility-20261110.md`（权威）、`reports/droidloom-feasibility-20261108.md`（基线）、`patches/fragment-droidloom-nftables.config`、`PITFALLS #603/#604/#605` |
| ✅ C-历史 | Waydroid 容器打通、Mesa 26.1.8 解 A830 chip-id、GAPPS 镜像安装、容器代理通路、**Win-x86（Box64 0.4.5+Wine 9）PoC** | **已完成** | — | 见 `archive/topics/WIN-X86-POC-2026-10-02.md` | — |

### 2.1 主机侧并行任务（不占设备，随时可做）

| ID | 内容 | 状态 |
|---|---|---|
| A11 | Debian/Alpine arm64 guest rootfs（VM 路线用） | ⬜ |
| A12 | guest 内核（`CONFIG_DMA_RESTRICT_POOL`，microdroid_defconfig 思路） | ⬜ |
| A13 | `sudo apt install qemu-utils` | ✅ 已装（`qemu-img`/`qemu-nbd` 实测在位，2026-10-02 核验） |
| A14 | 传感器注入代码 | ✅ **已完成（2026-10-03，前提修正后重定义）**：HAL 真实现（waydroid-build 树 Sensors.cpp，编译成功）+ 宿主侧 `scripts/eldroid-sensord.c`（selftest 7/7 + UDP 环回冒烟）+ `scripts/deploy-sensors-hal.sh`（overlay 部署）+ `env-pass/scripts/sensor-send-termux.sh`（真值转发） |
| A15 | C9 用例表 + 打分模板 | ✅ 已定稿 → `README.md §6` §5（2026-10-02，10 条用例+阈值） |
| A16 | 把 `scripts/*.sh` 里残留 `new-tablet` 默认路径参数化 | ✅ **已核（2026-10-20）**：`grep -rn new-tablet scripts/ rootfs/` 仅剩 1 处，且是 `scripts/gpt-dump.sh` 注释里的**反面示例**（“勿用 new-tablet”），无可执行配方 ⇒ 无需参数化 |
| A17 | `env-pass/` 打包成"装到任一单元的幂等脚本"（去掉隐含绑机） | ✅ 已完成：`env-pass/scripts/envpass-provision.sh`（状态预检 TB322FC/root + 产物自动 repack + 读回校验 + 幂等）+ `envpass-ondevice.sh` 幂等化（已装模块跳过 + Shamiko -patched 优先） |
| A18 | `sudo bash scripts/fix-fstab-samsung.sh`（/mnt/Samsung 掉盘卡开机） | ✅ 已完成（2026-10-02） |

---

## 3. 已作废/合并的旧任务线

> 2026-10-06 归档：`设备等价` 原则确立后，2026-09-30…10-02 的旧任务线 / swarm 批次 / "两轨分机" 角色表全部作废，原文已移出本文件。
> 见 **`archive/topics/RETIRED-PLANS-2026-10-06.md` §1**（含 swarm task-1…13、task-14…17、PLAN-NODEV、两轨分机、新机/旧机角色表）。本文件不再展开。

---

## 4. 下一步（按顺序，含并行项）

> **本节只列开放项，一行一句结论 + 指针。** 历史裁决、已收口条目、N1/N2 全过程与旧编号 1–11 条**逐字**下沉 →
> `sessions/2026-11-03-TASKS-§4-待办沿革.md`（2026-11-03 前的 §4 全文，零删改）；
> **2026-11-14 的第二轮压缩**（19 个长块 → 结论+指针）沉到 `sessions/2026-11-14-TASKS-4-沿革下沉.md`（逐块 `§4-N`）。
> 功能状态只在 §1 任务行维护；未解/未收口只读 §0 与 §5；上游投递队列以 §7 为准。

**当前口径（2026-10-06 立，2026-11-03 复核）**

- **本轮主线** = 尽可能覆盖硬件驱动；判据 =「命令 + 原始输出」可复现。
- **本轮不投入**：Q24（2026-10-23 停止采样——根因已指名、日常线免疫，只读 §5 Q24）。UEFI/G1-29 已于 2026-11-01 恢复推进；G1-26/27/28 已出列。
- **迭代通道**：`fastboot boot`（零写盘）/ `--flash`；**kexec 定位 = 不需显示/网络的调试快环**（K3 裁决）——`mask=1` 全链零掉电、目标内核能起（写盘 marker + `nokaslr` 实证），但带磁盘根时死于 Q28 同源 bonded DSI 初始化，且 `0154` 对 kexec 机制性无效 ⇒ **本机 kexec 拿不到显示**；工程侧见 §7 M9，全过程见归档。
- **内核基线**：`clean/base`（= vk64 内核源 `d02658e63`，tag `baseline/clean-base`）为唯一功能基线；分界与旧树处置见归档。
- **boot_b 形态 / 上机纪律 / 归因分层**：只在 `DEVICE/README.md` §1.1、`PITFALLS` #3/#115 维护，本文件不复述。

### 开放待办（按顺序；需要物理 POR 的排最后）
- **2026-11-13 夜：上机一轮（零写盘）—— ramdisk 修复件 `vk191` 一次通过 + s2idle 3/3** —— 全账 `reports/device-session-20261113-vk191.md`，在机状态只读 `DEVICE/README.md` §1.1 首条。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-1；证据/件：`scripts/to-fastboot.sh`
- **2026-11-13 夜：主机侧 B 组 18 条全部收口（派 3 个 L1，产物全落盘，零发信/零写盘）** —— 逐条正文只读各自报告，这里只给结论与今晚可用性：
  **① 上游备料（发信仍等下轮统一批准）**：`B1` camss CSIPHY 对账 = 上游 7.4-rc3 **没有** `csiphy_kaanapali`（camss 目录 0 命中），lane 表已迁到 `phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c` 的 `lane_regs_x1e80100[]`（其值 = vendor **v2.1.2**）；
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-2；证据/件：`reports/camss-csiphy-v6-vs-240-20261113.md` · `reports/mdss-int2-evidence-20261113.md` · `patches/upstream/m6-dsi-pll-v2-20261113` · `patches/upstream/dpu-gamma-lut-v2-20261113` · `patches/upstream/dwc3-v9-20261113` · `reports/fastrpc-nonsecure-evidence-20261113.md` · `patches/upstream/board-dts-single-20261113` · `patches/upstream/haptics-v2-20261113` 等 18 项
- **2026-11-13 晚：三份盘点 + 一次可合性实验（本轮派发产物，结论只在各自 §0）** —— ① **上游 7.4 可合性**：`reports/upstream-74-replay-20261113.md`（现役 `build/daily` payload → 上游 `gh/master` = `9d66f26fef` 7.4-rc3：**107 文件自动干净 / 15 文件 19 个冲突 hunk**；
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-3；证据/件：`build/daily` · `reports/todo-inventory-20261113.md` · `reports/repo-slim-audit-20261113.md` · `reports/git-tree-audit-20261113.md` · `reports/artifacts`
- **G1-37 日用用户态基线（只剩一件）** —— ✅ 包+配置已落地（2026-11-07：设备 1355→1625 包，`daily-baseline.tsv/.sh` + `scripts/mobian-daily-baseline.sh`，`--check` rc=0）；**2026-11-09 输入法三连修（新）**：① 配置图标点不动 = 缺 `fcitx5-config-qt`（已进基线，实测可开窗）；
② Phosh 无 SNI ⇒ 顶栏不会有 fcitx5 图标，已自绘 **GTK4 layer-shell 胶囊**（右上角「中·rime / EN」，点击即切）；
③ 触屏入口 = 应用网格「输入法 中/英 切换」（**用户实机确认：胶囊可见、配置器可开**）。**★2026-11-11 口径更正（用户指出旧口径「只差组词」过时）——现役栈连「点输入框弹键盘」都没过，且不是缺一次触摸**：现役栈 = Debian/Mobian + phosh 0.59~alpha1 + **自编 phoc 0.58.0-syncobj** + `phosh-osk-stevia` + `fcitx5 5.1.23 --disable waylandim`。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-4；证据/件：`reports/ime-osk-pop-20261111.md` · `patches/phoc-osk-versiongate-20261111` · `out/phoc-syncobj-arm64-20261111/phoc-0.58.0-syncobj-osk` · `reports/ime-phosh-fcitx5-invest-20261110.md` · `reports/doc-ime-scope-audit-20261111.md` · `rootfs/debian/ime` · `reports/artifacts/ime-osk-firefox-20261111.png` · `reports/ime-osk-firefox-rootcause-20261112.md` 等 12 项
- **G1-38 OSK（虚拟键盘）自动弹出 / 收起** —— 🟡 **2026-11-12 静态定案、待上机**：五个失效点与两条处置**只读 §1 G1-38 行**。**下一步顺序**：① 先做「固化」（systemd user unit + 源码三改，本机可验证）→ ② 重登后按报告 §5 的 T-S1/S2/S3、T-A3–A8 上机取「弹/收/漏收/误弹」四类样本 → ③ 再决定是否走单栈 b（需 phoc `bb1f7465` 重编）。**本轮无 Linux 设备实测**（平板在 Android 12，`uname -r`=5.10.43），任何「已修复」判断都要等 Linux 侧样本。
- **上游主线合并候选（2026-11-12 已评估，`reports/upstream-merge-candidates-20261112.md`）** —— **值得合并 12 条 = 必修 3 + 可选 9**，总工作量 **≈10–14 人时**（必修仅 ~1.5）；
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-6；证据/件：`reports/script-redundancy-audit-20261112.md` · `scripts/to-fastboot.sh`
- **SN 锚定（2026-11-12 用户口径：以后全部显式锚定原厂 SN）** —— 背景：我们自己写的系统过去把 USB gadget 的 `iSerialNumber` 写死成模板常量 `HA2CB1KY`（`rootfs/usb-gadget` / `initramfs/usb-gadget`），而真实 SN 在 `androidboot.serialno=`（ABL 恒给）：⇒ 同型号多台机 + 同一个 `192.168.7.1` 时，主机侧按 `lsusb`/`journalctl` 的 SerialNumber 认设备**必然认错**（`PITFALLS #549`，2026-11-12 又一次踩到：把另一台华为手机当目标板）。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-7
- **⭐vk189/vk190 = 上游合并批 1 + 待机功耗线重启（CONFIG_SUSPEND）—— ✅ 2026-11-13 上机收口并持久化**（全账 `versions/vk-registry.tsv` 的 vk189/vk190 两行）：
  - **vk189 零写盘 1 发全绿**：`uname -r` = `7.3.1-debug-vk189-suspend-00002-g4da9a8b69fc8-dirty`、`/sys/power/state` = `freeze mem`、`mem_sleep` 默认 `[s2idle]`、`lsmod` 非空、`/dev/dri/card0` 在、DSI `bound ae94000.dsi`、WiFi `wlp1s0` UP、无 arm-smmu fault / xHCI 错误；**s2idle 回归 3/3 成功**（`rtcwake -m mem -s 45` 三发：`suspend_stats/success` 0→3、`fail=0`、`uptime` 连续、唤醒后面板重下发 novatek 固件、WiFi 重关联）。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-8；证据/件：`build/daily` · `patches/upstream/sm8750-adsp-nonsecure-20261107` · `out/boot-elden-vk190.img` · `scripts/check-abi-config.sh` · `patches/config-daily-c2-suspend-20261113` · `build/m3v2-7.3rc7` · `patches/config-m3v2-suspend-20261113` · `scripts/to-fastboot.sh` 等 11 项
- **外部动向（2026-11-12 两轮扫描：`reports/external-scan-20261112.md` + `-20261112b.md`）** —— 三条要落到待办，都不是主线阻塞：
  ① **suspend 线两个必修上游补丁（先记后用）**：`llcc-qcom` 的 `LLCC_ISLAND1` 我们仍写 `bonus_ways=0x7fffffff`（应 `res_ways`，修 s2idle 时 LPASS 无票 → PS_HOLD 复位）、`gcc-sm8750` 两个 USB GDSC 仍 `PWRSTS_OFF_ON`（应 `PWRSTS_RET_ON`，修 USB host 下 s2idle 回来 SMMU fault/xHCI 死）。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-9；证据/件：`build/daily` · `build/m3v2-7.3rc7`
- **T14 用户态驱动/服务独立固化** —— 🟢 **前提已过时（2026-11-11 复核）**：10-25 报告的「7 个 ELF 中 3 个无源 / 2 个动态 musl」已被 **0e60a55（2026-11-04）补齐**——本轮实跑 `verify.sh --rebuildable` = `ELF 7 个 ok=7 missing=0`、`FAIL=0 WARN=0`，3 个历史无源件（ffrumble / waydroid-sensord / waydroid-sensord-udp）均已有源+recipe、现役动态件已切 glibc 且 sensord 双件 sha 与设备件逐字一致。**剩余只 = Mobian 换根重建 recipe 的可执行化**（P0 chroot → R1 dry-run → R2 all.sh --apply → R3 门禁 → R4 render.py；部署验收 D1–D5 标「待上机」），处置与 recipe 草案见 `reports/t14-userland-recipe-20261111.md`（含 4 个需人决策项）。权威 `reports/userland-service-inventory-20261025.md`、`reports/userland-dealpine-audit-20261026.md`、`packaging/elden-userland/tools/verify.sh`。
- **T17 驱动模块化 × Alpine→Mobian 迁移** —— 🟢 **口径更正（2026-11-07 现场核实）：S2/S3/S7 事实上已完成，本行不再挂待办**。判据：设备 `findmnt /` = `/dev/sda17 ext4`、`/etc/os-release` = `Debian GNU/Linux forky/sid`、`/dev/disk/by-partlabel` 只剩 `linux17`（`linux18` 已于 2026-10-31 并入），且 `check-pkgmap.sh` 的 S2 三项缺口（`alsa-ucm-conf`/`ca-certificates`/`login`）早已钉进 `pkgmap.tsv` 并在机；换根后遗留的真缺口只剩 **T14（userland 重建 recipe）**。权威 `reports/modular-mobian-transition-20261026.md`、`DEVICE/README.md` §1.1。
- **C3 Play Integrity / DRM 取证**（G2）—— C1 已收官（vk95 起 `ip rule` 生效；去 workaround 出网 200，`reports/c1-noworkaround-20261013.md`）⇒ 下一步 = C3 身份/DRM 取证，其后 C2 GMS 登录（需上行 + 代理 + 凭据）。权威 = §2 C1/C2/C3 行。
- **N1 UEFI 间接引导** —— ⚠️ **2026-11-11 夜阶段收口：判读全线重估，权威 `reports/uefi-efistub-stage-summary-20261111.md`**（本文件下面各条保留沿革，但**当前口径以该总结为准**）。三条要点：① **「60–70 s 硬件掉电」判读作废**（`PITFALLS #620`）—— 三臂日志全是 `Kernel panic`，栈逐字相同（`ramoops_pstore_write` 路径），「掉电」是 panic 的下游症状；**新判据纪律 = 无 `Kernel panic`/`Oops`/`end trace` 不得写「硬件掉电」，pstore 空不能当没 panic**；② **真现象（用户 2026-11-11 深夜实测）= GRUB 菜单两版都能显，问题在「选了之后」：屏要么只有背光、要么先强光一下，最终黑屏关机**。~~旧判读「缺显示模块 ⇒ 菜单不显 + `timeout=20` 盲等」两条均作废~~。**「无屏显」的真机制 = 内核侧 `CONFIG_SYSFB_SIMPLEFB` 未开**（`drivers/firmware/sysfb.c:19` 原文：未选则永不注册 `simple-framebuffer`）⇒ fbcon 无后端 ⇒ 从选完到 panic 一字不出；
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-13；证据/件：`patches/dt/0001-arm64-dts-qcom-sm8750-elden-ramoops-record-size.patch` · `build/daily` · `build/exp-cmdline/boot-elden-vk187b-ramoopsfix.img` · `reports/uefi-vk188-fbcon-20261112.md` · `out/ramdisk-vk181-daily.cpio.gz` · `out/boot-elden-vk188b.img` · `scripts/serial-tap.py` · `reports/qemu-usage-survey-20261112.md`
- **N1 UEFI 间接引导（历史）** —— 🟢 **已收口（2026-11-10 深夜，G1-29 两种形态都通）**
  - **2026-11-11 晚（替代引导器评估，`reports/bootloader-alternatives-20261111.md`；我已独立复核两条关键论断）**：① **systemd-boot 判别增量≈0** —— `src/boot/` 全树 `ExitBootServices` 只有声明（`efi.h:350`）与注释，**无调用点**；arm64 一等支持（`meson.build:1933` `'aarch64':'aa64'`、Debian 有 `systemd-boot-efi-arm64-signed`），但**非 x86 的 initrd 直接 `AllocateAnyPages`、无 4 GiB 限制**（`src/boot/util.h:113-131`）⇒ 与 GRUB 同交接形态。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-14；证据/件：`scripts/uefi-a-slot-prepare.sh` · `reports/grub-project-scan-20261111.md` · `reports/uefi-dtbo-a-rootcause-20261110.md` · `reports/uefi-gunyah-reassess-20261024.md` · `reports/grub-direct-vs-secondstage-20261110.md` · `reports/uefi-next-step-decision-20261103.md` · `reports/uefi-posctrl-20261103-summary.md` · `patches/uefi/20261104-fixcopylen` 等 11 项
- **内核重基成本账（7.3-rc7 → 7.3.1）** —— ✅ **静态账已出（2026-11-07）**：`reports/kernel-rebase-cost-20261107.md`。要点：**242 文件 / +2421−981，我方 payload 目录（msm、clk/qcom、dwc3、media/qcom、qcom DTS、interconnect、soc/qcom、firmware/qcom）0 改动**；与我方 493 枚补丁的源文件交集只有 **2** 个（`pwrseq-qcom-wcn.c` 要手工并一处 hunk、`kernel/reboot.c` 日常线不含）。**风险不在冲突而在行为**：7.3.1 把 WCN 的 `wlan-enable` 改成 `GPIOD_OUT_LOW`（原 FIXME 正是「会拉低 WLAN 致 PCIe link down」）⇒ 重基后必须复测 WiFi 关联 + 二次 suspend/resume；`emergency_restart()` 新增 nbcon flush ⇒ 复验 `reboot bootloader`。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-15
- **M6 v2 重切备料** —— ✅ **静态备料已出（2026-11-07）**：`reports/m6-v2-recut-plan-20261107.md`（4 枚备料对 11-06 master `d48723711b` **可 apply 4/4**，建议维持 4 枚切分；仍受 §7 M6 的三条复启条件约束，**未投**）。
- **7.3.1 重基（已执行，2026-11-07）** —— ✅ **`vk185-adsp` 上机全绿、零写盘、`boot_b` 未动**：`v7.3.1` + payload replay + M1 DSI **零冲突**；
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-17；证据/件：`patches/upstream/sm8750-adsp-nonsecure-20261107` · `reports/trials/20261107T023200Z-reb731-vk185-adsp-functional.json` · `out/boot-elden-vk185-adsp.manifest`
- **M 系列（G1 上游化）投递** —— 队列与状态以 §7 为准；投递解冻由用户按批放行，agent 不等回复。补丁目录投递状态对账（10 目录 README 状态行过期已修、3 未证实）见 `reports/patch-delivery-audit-20261107.md`。**★2026-11-11 增量（`reports/mail-triage-20261111b.md`，窗口 11-10T00:00Z→11-11T08:08Z）**：外部回信 3 封（Rob Herring ×2 + sashiko-bot ×1）、**退信 0**、我方外发 2（M10 v2/v3）；**patchwork 现查补齐**（70 条全空 `tags` 字段是常态，tag 只在 comment 正文）⇒ **mdss v3 1/3 有 `Acked-by: Rob Herring (Arm)`（2026-11-10T19:27:44Z）、3/3 有 `Reviewed-by: Abel Vesa`（2026-11-02T13:17:55Z）**、wl2868c v9 1/2 有 `Reviewed-by: Rob Herring`（11-09T14:54:04Z）——**旧口径「只有 wl2868c 1/2 有 tag」不成立**；四系列 `commit_ref` 全 `None`（都未进任何 maintainer 树）。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-18；证据/件：`reports/wl2868c-v10-plan-20261111.md` · `reports/dwc3-v9-plan-20261111.md` · `patches/upstream/dwc3-v9-draft-20261111`
- **N2 Gunyah VM** —— **★2026-11-12 驱动移植已完成编译**（piano 代次 → 7.3.1，10 个 .ko 零 error/warning，`out/gunyah-73/`；唯一 API 适配 = `vma_interval_tree_foreach`→`mapping_rmap_tree_foreach`；上机前提 = 统一内核基线，见 `reports/gunyah-73-port-20261112.md`）。**★2026-11-11 晚 S1 静态对账已出**（`reports/gunyah-s1-static-diff-20261111.md`，总管亲自 `diff`，子代理在抓取阶段停滞被接管）：**piano（同 SoC SM8750P）vs g612（10-25 用的 6.12）差异集中在 parcel 生命周期** —— `vm_mgr_mem.c` +109 行/diff 465、`rsc_mgr_rpc.c` +44/90、`vm_mgr.c` +6/175、`gunyah.c` **零差异**。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-19
- **N2 Gunyah VM（历史）** —— 2026-10-25 终局裁决「本 firmware 下不做」**已被 2026-11-11 的联网复核改为「有条件重启」**（`reports/gunyah-restart-assessment-20261111.md`，我逐条复核过：主线 `drivers/virt/{Kconfig,Makefile}` 仍 **0 命中 gunyah**；两台**纯 Linux 宿主**先例真实存在——`yzddmr6/linux-sm8750-piano` 的 `drivers/virt/gunyah/` 我直接拉到 `Makefile`（含 `gunyah_qtvm.o`/`gunyah_irqfd.o`），README 特性表写 Gunyah/crosvm VM=✅；`mzakamin-hub/iceland-gvm` = SM8850P + Fedora 44；KVM 维护者对 KVM-in-EL1 的拒绝我抓到原文「But mixing the two is not happening, sorry.」）。**10-25 三条理由对账**：① KVM 不可达 = 仍成立 ② 驱动未进主线 = 事实成立但「因此走不通」被推翻（移植成本被量化成 ~102 行 API 适配）③ 「KVM-in-EL1 是唯一在演路线」= **双重错**（不是唯一、且是死路）。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-20；证据/件：`reports/gunyah-decision-20261025.md`
- **T18 USB 插入后充电图标抖动（忽「充电」忽无）/ 有时重不上电**（2026-11-11 用户报，明确交代「这个现象以前出现过」；本轮**只登记，未调查**）—— 现象 = 插着 USB 时状态栏充电图标在「充电 / 不充电」之间反复跳；并出现过「有时重不上电」（掉电后插 USB 没恢复充电、需重插/换口）。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-21；证据/件：`reports/driver-ab-charging-20261108.md` · `reports/t18-charging-timing-20261111.md` · `rootfs/debian/udev/90-elden-charge.rules` · `rootfs/debian/usr-local-sbin/charge-icl-fix.sh` · `reports/t18-usb-charging-triage-20261111.md` · `reports/artifacts/t18-sampling-20261111`
- **T9 suspend 掉电率** —— **★2026-11-13 口径更新（用户定）：不追精密电流数值**，改为「脚本统计后台进程 / 资源占用」的**间接测量**：已部署 `scripts/suspend-resource-sample.sh`（设备侧 POSIX sh）+ `elden-resource-sample.timer`（30 min，追加 `/var/lib/elden/suspend-resource.tsv`，列含 procs/threads/MemAvailable/swap、电池 V/I/charge_counter（只作同口径相对量）、`suspend_stats` success/fail、top5 RSS、关键服务 RSS、UTS）；**过一两天取数再判**（取数 `scp elden-root:/var/lib/elden/suspend-resource.tsv .`）。判据纪律 = 同一 boot 内 ≥3 周期看趋势、跨 boot 先对齐 UTS 与负载；单点无意义。坑见 `PITFALLS #651`（`wakeup_count` 读会阻塞、`suspend_stats` 是目录）。旧的精密口径（2026-10-28 裁决：优先级最低、暂不排期）作废（恢复时按归档的历史口径；权威 `reports/qca-fw-download-suspend-20261021.md`、`reports/t9-vk130-pcie-l2-live-20261021.md`）。
- **H1 资产清理** —— 已收口；清理账目与用户裁决（B1–B4）唯一正文 = `RESOURCES/README.md` §3，执行账 `reports/asset-tidy-20261105.md` §7、`reports/out-archive-20261105.md`、`reports/out-uefi-trim-20261106.md`。
- **H2 完整性巡检（每轮收尾，2026-11-05 起）** —— `bash scripts/check-doctor.sh` + 镜像基线复算（`versions/out-images-sha256-20261105.tsv`，命令在表头；**必须走 `O_DIRECT`**，普通读会命中被位翻转的页缓存副本，见 `PITFALLS #513`）+ 项目仓与 `geekidos-linux` 的 `git fsck --full`。
  > 沿革与逐轮明细（零删改）→ `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-24；证据/件：`reports/integrity-audit-20261105.md` · `reports/counts-gate-20261107.md` · `reports/doc-audit-20261108.md` · `reports/asset-inventory-20261108.md` · `reports/project-audit-20261111.md` · `reports/asset-tidy-exec-20261111.md` · `reports/asset-slim-20261112.md` · `reports/integrity-h2-20261111.md` 等 10 项
### 收尾轮次纪律（2026-10-23 用户定，仍有效）

- **需要物理 POR 的样本一律排在最后**（用户在机旁断电/开机时一次做完），其间只做不重启的项。
- TF 卡（G1-6/Q10）已收口出列；**Q28 补采样与 Q32 已于 2026-10-24 收口**，其余「需要 POR」项全部关闭 ⇒ 现无待取 POR 样本；判据备查 → 归档。
---

## 5. 查漏补缺（GAPS）

> **★镜像件口径（2026-11-11 回填，`reports/project-audit-20261111.md` §1）**：本节各历史块里提到的
> `out/r21-sbstop-p*/uefi-preamble*-r1.img` 等件**已于 2026-11-10「发送清理」会话删除**（释放 7.39 GiB），
> 同批 `out/boot-elden-*.img` 多数只剩同名 `.manifest`（2026-11-05 `out/` 归档 + 11-10 清理）
> ⇒ 这些路径一律以「`out/<件名>.manifest` + `versions/vk-kernel-identity.tsv` + 对应会话记录」为证据，
> 配方/补丁在 `patches/`（UEFI 系在 `patches/uefi/`）。别再按块内原路径找件。

### 2026-11-09（傍晚，p62）：**R63 分区普查 + 按 GPT 名定位 ESP** 已构建并零写盘过一发；同时把 `logfs` 的写入语义查清
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-01.md`⟫

### 2026-11-10（晚，p69/R70 + 金标准对照）：**计时判据被硬复位剪断；金标准件同样起不来 ⇒ 矛头指向 `vbmeta_a`**
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-02.md`⟫

### 2026-11-10（深夜，`dtbo_a` 真根因）：**flashed 形态打通 —— 卡 logo 是 `dtbo_a` 的 Android DTBO overlay，不是 `vbmeta_a`**
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-03.md`⟫

### 2026-11-10（p67/R68 信标 v3）：**flashed 形态连 BdsDxe 都没跑到** —— 旧口径「ESP 枚举 `fs=1`」被持久证据推翻
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-04.md`⟫

### 2026-11-09（晚，p63→p66）：**flashed 形态 4 发全败 + `p60` 对照同败**；落盘信标 v1 废、v2 可用但判不了「哪一发」
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-05.md`⟫

### 2026-11-07（深夜·三，p58）：**UEFI 间接引导打通** —— 真因 = `SdccDxe` 抢初始化 SD 主控
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-06.md`⟫

### 2026-11-08（晚间）：G1-29 路线 B **打通** —— ESP 上的 `boot.img` 被 Mu `LinuxLoader` 变体直接读起（零写盘）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-07.md`⟫

### 2026-11-08（深夜）：崩溃定因两处修 + **启动菜单闭环** + 落地第一发（写 `boot_a`）定位到缺口
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-08.md`⟫

### 2026-11-08（下午）：路线定案 B + **首试判 indeterminate**（RELEASE 剥 DEBUG + 菜单歧义 = 无法归因）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-09.md`⟫

### 2026-11-08（上午）：ESP + GRUB **菜单出来了**，但 EFI-stub 交接撞平台墙 —— 已按判据收窄
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-10.md`⟫

### 2026-11-08（清晨）：G1-29 后半**主机侧备料**—— arm64 GRUB 造得出来，且 QEMU 端到端跑通「FAT 起 loader → 读 ext4 起内核」
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-11.md`⟫

### 2026-11-07（深夜·二，p54→p57）：**「关硬件看门狗」三路全证伪** + 复位「不是独立定时器」的反证
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-12.md`⟫

### 2026-11-07（夜·二，p51→p53）：**UEFI 交棒成立**（内核侧实锤）；卡点 = 那个内核 4–10 s 后整机硬复位
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-13.md`⟫

### 2026-11-07（夜，p49→p50）：**令牌已进 UEFI 的 cmdline（`tag=1`），但内核拿不到 ⇒ 交棒仍未成立**
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-14.md`⟫

### 2026-11-07（深夜，p45→p46）：**UEFI 间接引导打通** —— 删掉「EB 后落盘」的自家探针后，内核真正起来
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-15.md`⟫

### 2026-11-07（夜，p45）：**备料完成、已构建、静态复核 PASS、未上机** —— `p43` + EB 段逐步屏显 + 异常 dump 不清屏
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-16.md`⟫

### 2026-11-07（p39–p43）：**漏了 `fastboot continue`** 白打 4 发；补发后第一次真进 `BootLinux`，崩点回到 EB 段
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-17.md`⟫

### 2026-11-07（p38）：p37 的「EB 后立刻死」= **自家探针调 boot service**（静态定案，已构建上机件，未上机）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-18.md`⟫

### 2026-11-06（夜·五）：取证通道从「屏」搬到 **`logfs` 持久化窗口**（p34–p36，上机 4 发零写盘）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-19.md`⟫

### 2026-11-06（夜·四）：**已调用到 `LinuxKernel()`**（DDR 读回）⇒ 卡点搬到交接参数；并暴露「满屏不刷新」取证 bug（p30–p33）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-20.md`⟫

### 2026-11-06（夜·三）：屏显 NULL 崩修好 → **EB 正常返回** → 面板被熄 ⇒ 转 DDR 黑匣子（p27–p30 四发）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-21.md`⟫

### 2026-11-06（夜·二）：崩溃 PC 归因成功 = **`LinuxLoader` 自己的 `SerialPortWrite`**（p25/p26 两发）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-22.md`⟫

### 2026-11-06（深夜）：**真启动崩溃真因 = 我们自己的探针写屏**（修好后真路径首次到 EB）— p13→p24 十一代件
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-23.md`⟫

### 2026-11-06（傍晚）：**首次上机全场走通到跳内核** + 三条判据更正（EB 后宿主失联 / 会话污染 / 跳进堆）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-24.md`⟫

### 2026-11-06（下午）：34→27 窗口里还有一条**未门控**的屏显写 + 探针 35..38 / p8·p9 世代就绪（**未上机**）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-25.md`⟫

### 2026-11-06：**上一轮 10 发作废（探针从未命中）+ 崩溃真因 = 屏显写穿帧缓冲 + 新通道 `sbprobe=3`**
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-26.md`⟫

### 2026-11-05（上午）：R21 **取证通道改走 fastboot 响应**（断电收尾，重建完成、未上机）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-27.md`⟫

### 2026-11-05（夜）：判据彻底改为**宿主可读**，崩溃点从「DXE 里某处」收敛到 `LoadImageAndAuth` 前导 3 步
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-28.md`⟫

### 2026-11-04（更深夜）：路线重排 —— **loader 早就在 FV 里（`LinuxLoader`），只是没人启动它** ⇒ 首选改成路线 D

- **下轮入口**：`archive/plans-20261110/2026-11-04_late-uefi-routeD-linuxloader.md`（复核 + 7 条新增主机侧事实 + R13 实施单 + 风险表）。
- **更正上块**：`QcomModulePkg` **在树里也编了**（`build.log:4354`），`LinuxLoader` 的 FFS（GUID `F536D559-459F-48FA-8BBC-43B554ECAE8D`）就在 `FVMAIN.Fv.txt` 末行 `0xC126B0`；它没跑的唯一原因是 `MODULE_TYPE = UEFI_APPLICATION`，而 `Dispatcher.c:73 mDxeFileTypes[]` 不含 `APPLICATION`（`PITFALLS #503`）。
- **路线重排 D > A > B**：D = BdsDxe 里 `LoadImage`+`StartImage` 这个 FV 内应用 → 它写死 `BootIntoFastboot=TRUE` ⇒ 进 UEFI 侧 fastboot → 宿主 `fastboot continue` 启 `boot_b`（`FastbootCmds.c:2685/2854` → `LoadImageAndAuth` → `BootLinux`）；**新增字节 0、不动盘、启的就是今天 ABL 启的同一份 boot.img**。解锁态 AVB 走 `ALLOW_VERIFICATION_ERROR`（`VerifiedBoot.c:1105`）、`EnableMdtpSupport=FALSE` ⇒ 自签镜像不被拦。
- **A（GRUB 进 FD）降为退路且已验尺寸**：FD 尾部空 `1 727 675 B`；`grub-mkstandalone -O arm64-efi` 最小集 = `2 093 056 B`、`xz -9` = `1 174 968 B` ⇒ 压得进。arm64 模块可从 USTC 镜像 `grub-efi-arm64-bin_2.14-2ubuntu1_arm64.deb` 现取（本机已解包实测）。

### 2026-11-04（深夜）：UEFI **DXE 全走完、UFS 枚举成功（BlockIo=119）、整机无 ESP** ⇒ 只差一个 loader

- **下轮入口**：`archive/plans-20261110/2026-11-04_handoff-uefi-dxe-to-linux.md`（现状/12 发清单/方案 A（零写盘 GRUB 进 FD）/判据/复现步骤/新坑）。
- **一句话**：`0xD2B9B224` 已定案 = `QRKSDxe`（剔除后零异常）；`BlockIo=119` 证明 UFS 枚举通了；唯一的 `SimpleFileSystem` 是 **LUN4 `modem_b`**（FAT，绝不能写）⇒ BDS 无交接目标 ⇒ 复位 ⇒ 原厂 recovery。
- **下一步**：方案 A = standalone GRUB arm64（或自写最小 loader）打进 FD，由 BdsDxe `LoadImage` 启动，GRUB 用 ext2 读 `linux17`(ext4) 的 `/boot`；退路 = GPT 手术建 ESP。
- **正文**：`reports/uefi-ramoops-channel-20261104R.md` §9–§11；会话记录 `sessions/2026-11-04-UEFI-DXE走完到BDS之后的handoff.md`。

### 2026-11-04（傍晚）：UEFI **DxeCore 真进场、QCOM DXE 驱动在跑**，卡点 = 某驱动同步异常 0xD2B9B224
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-29.md`⟫

### 2026-11-04R（下午）：UEFI 判据换成 **ramoops 主机可读**（零写盘件已构建，未上机）

- **一句话**：上一发 `fixcopylen` 的 verdict=indeterminate 是因为唯一判据是「人眼看屏」而屏在刷；本轮把同一条轨迹（`[F01]/[P01]…[P11]`、64 块 FNV 表、`[D00]…`）**同时写进 Linux 的 pstore record 区**（`dprzs[0]=0xC2000000` PrePi、`dprzs[1]=0xC2200000` DxeCore，格式照 `persistent_ram_buffer` + `"====<sec>.<usec>-D\n"` 头），回到 Linux `cat /sys/fs/pstore/dmesg-ramoops-{0,1}` 即可判；**刻意去掉 Dispatcher 进度点**（那是无限滚屏的元凶）。
- **件**：`out/uefi-20261104R-r1.img`（sha `e7f8b544…`）；断言=shim 字面量池 `0xff300000/0x00400000/0xff700000` + header v2 + `text_offset=0` + `flags=0xa`；期望块表 `.pi/plans/next2/expected-blocktable-uefi-20261104R-r1.txt`。
- **机制化**：`scripts/uefi-repack-v2aligned.py` 末尾新增 `verify_built_image()` 硬断言（旧 shim 件一律拒，实测拒掉 `nocivac`）；`out/SUPERSEDED.md` 登记 7 类旧变体。
- **正文/证据**：`reports/uefi-ramoops-channel-20261104R.md`（§1 内核侧 pstore 事实与 ECC=0、§3 上机与三态判读、§4 DDR 冷清风险）；补丁 `patches/uefi/20261104R-pstore/000{1,2}`。

### 2026-11-04（晚）：UEFI **DxeCore 从未被启动** —— 真卡点 = 内层 FV 解压失败（11 发零写盘）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-30.md`⟫

### 2026-11-04：UEFI **载荷被执行 → Mu PrePi 走完 → 交给 DXE**（7 发零写盘）

- **一句话**：打包头换成 **v2 base 0 + Image 头对齐**后载荷第一次真被执行；屏上色带证明 shim 跑完 4 MiB 拷贝并 `br` 进 UEFI，屏上串口打出 Mu 自己的版本行与 `[P01]`–`[P11]` ⇒ **PrePi 全流程走通、已交 DXE Core**。
- **推翻/收紧的判据**：`Booting OKAY ~10.1 s` 只到「ABL 接受并跳」这一层；**DDR 标记通道在本类场景失效**（自家载荷在 PrePi 侧写了 ~1.9 GB `0xFF`，两次对照定性：纯重启 / 同路径启动真内核 ⇒ 窗内仍 `0x00`）。
- **硬约束**：`splash_region` DT 声明 43 MiB 但**只有前 ~448 KiB 可写**（整块填充挂死 SoC）；ABL 下次启动清屏 ⇒ 屏上标记只能实时看。
- **正文**：`reports/uefi-payload-execution-20261104.md` §0/§2/§3/§7；session `TASKS/sessions/2026-11-04-UEFI载荷首次被执行.md`；坑 `PITFALLS #490/#491/#492`；镜像 `out/uefi-20261104-{fbfill,fbband,dual,m3block,prog,nocivac,prepi}.img`、补丁 `patches/uefi/20261104-*/`。

### 2026-11-01：UEFI 线**判据纠正 + 恢复推进**（10 发上机，零写盘）
- **一句话（当时）**：10-30/31 的「交棒条件」= boot image v0 **header** 的产物、那 7 发载荷**从未被执行**；header 逐字段差分路线整体放弃 ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §1 ｜ **报告**：`reports/uefi-cleanheader-reframe-20261101.md`；坑 `PITFALLS #479/#480/#481/#482`

### 2026-11-01 16:39：UEFI 走「槽位正常启动」路径（P2 最小形态）→ **载荷未被执行，且设备进入「只能进 fastboot」状态**
- **一句话（当时）**：`boot_b`←载荷 + `reboot` 后 14 s 进 fastboot、两槽皆不启；**闭环 = 引导固件代次与 A/B 槽脱钩（`PITFALLS #484`）**，`--set-active` 双向修复 ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §2 ｜ **报告**：`reports/uefi-slotboot-stuck-fastboot-20261101.md`、取证 `reports/artifacts/uefi-edl-read-20261101/`；坑 `PITFALLS #484/#485`

### 2026-11-01 23:0x：UEFI 线按推荐顺序开工（4 lane）——**① 通道定案：EDL `peek` 本机不可用**，改「切断回落 + 回读」
- **一句话（当时）**：**EDL `peek` 本机不可用**（loader Supported Functions 无 `peek`）⇒ 改「切断回落 + 回读」；「回落清 marker」假设被否证；EUD lane 收口（DT 无 `eud` 节点） ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §3 ｜ **报告**：`reports/uefi-ddr-fallback-plan-20261101.md`、`reports/uefi-ddrcut-fallback-20261101.md`、`reports/uefi-eud-feasibility-20261101.md`；坑 `PITFALLS #486/#487`

### 2026-11-02 上午：UEFI ①「载荷到底有没有被执行」四臂判别 —— **全部为 0**，并更正一条错判
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-31.md`⟫

### 2026-10-31 晚：UEFI 线**暂停深入**（用户裁决；2026-11-01 已按上方纠正块恢复推进）—— 两项主机侧待办挂起
- **一句话（当时）**：用户裁决「更新文档并提交，暂不深入」；两项主机侧待办挂起，其前提后被 11-01 否证（见上方纠正块） ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §4 ｜ **报告**：判定纪律 = `PITFALLS #477`；两项待办的后续见 `reports/uefi-cleanheader-reframe-20261101.md`

### 2026-10-31 晚：UEFI 控制组 + R2 —— **A2 原件今天仍交棒**，而三发重建全不交棒
- **一句话（当时）**：⚠ 已被 `PITFALLS #481/#482` 作废（那批发射因脏 header 从未被 ABL 执行）；当时记录「A2 原件仍交棒、三发重建全不交棒」 ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §5 ｜ **报告**：`reports/uefi-vis-control-20261031.md`，证据 `reports/artifacts/`

### 2026-10-31 晚：UEFI R1 上机 —— 里程碑 shim **不交棒**，色条方案作废
- **一句话（当时）**：⚠ 同上作废（载荷未被执行，「不交棒」不构成对 shim 的否证）；当时记录「里程碑 shim 不交棒、色条方案作废」 ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §6 ｜ **报告**：`reports/uefi-vis-r1-20261031.md`

### 2026-10-31 晚（并行 lane）：UEFI 早期可见性四通道调查 —— 结论「改 0 行代码就有观测面」
- **一句话（当时）**：四通道结论（屏上出字 0 行新代码 / 内存落盘 / USB ACM / 硬件 UART）**仍成立**；但「1–2 s 掉电属载荷」已被 `PITFALLS #480/#481` 重归因 ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §7 ｜ **报告**：`reports/uefi-visibility-channels-20261031.md`、备料 `patches/uefi/20261031-vis/`

### 2026-10-31 晚（并行 lane）：UEFI 2×2 补全 —— 交棒需「厂商 UFSDxe × cachefix shim 基座」
- **一句话（当时）**：⚠ 整块作废（「交棒需厂商 UFSDxe × cachefix shim 基座」是 header 产物，不是载荷属性） ｜ **正文**已原样下沉 `sessions/2026-11-02-UEFI历史块归档.md` §8 ｜ **报告**：`reports/uefi-swap-x1x2-20261031.md`

### 2026-10-31 晚：启动提速（net-selfheal 白等 120 s 修掉）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-32.md`⟫

### 2026-10-31 下午（续）：「全部继续」四项落地
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-33.md`⟫

### 2026-10-31 下午：三封回信已发 + wl2868c v4 出件（用户「全部允许」批）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-34.md`⟫

### 2026-10-31 四 lane 轮（设备在线，vk183）
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-35.md`⟫

### 2026-10-31 晚（续）：阻塞项调查 A 类三 lane + B 类窗口单
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-36.md`⟫

### 2026-10-30 新增待办与并行安排
> ⟪全文见 `sessions/2026-11-13-TASKS5沿革-37.md`⟫

### 1. 待调查（Open questions，按优先级）

> **编号以表内为准**（Q27 从无此号；不在此写死连续区间）；**Q27 从无此号**（历史「G1-34 / §5 Q27」为幻影引用，已随 2026-10-10 清理移除）。
> **2026-11-14**：已归档/已结项的四行（Q25/Q31/Q32/Q3）从「整段沿革」压成「当前口径 + 指针」，原文逐字沉到 `sessions/2026-11-14-TASKS-5-Q行沿革下沉.md`。

| ID | 未知 | 为什么要知道 | 怎么测（最小实验） | 关联任务 |
|---|---|---|---|---|
| ~~**Q22**~~ | ~~**vk34（2026-10-01）之后未逐版验证的内核增量**~~（5 文件：DTS 分级热 trip + `q6apm.c`/`q6prm.c`/`audioreach.c`/`q6apm-lpass-dais.c` + `config-vk40-bringup`） | 决定 G1 基线是否可信（曾是「AI 难以稳固推进」的核心） | ✅ **已无剩余动作（2026-10-26）**：「增量=熄屏复位源」已由 Q24 根因取代；最后一个子项 vblank/PPM 残留复核已闭合（三窗 47.5 min 全 0，见 §1 G1-23 行）。**三轮取证全过程只在 G1-23，此处不复述** | **G1-23**；`archive/topics/AUDIT-since-vk34-2026-10-03.md`、`AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md` |
| **Q21** | ~~桌面空闲熄屏（DPMS blank）→ 整机重启~~ **已归因（2026-10-07）→ 并入 Q24**（根因=单模块 `cambistmclkcc-sm8750`，**仍未根治**） | 与 DP/altmode（G1-9）不同源 | 已由 60+ 轮模块二分 + H1 实锤 | **G1-22 🟡 / Q24** |
| ~~**Q23**~~ | ~~Linux 侧 reboot→fastboot 的触发点~~ **已解决（2026-10-03 深夜）** | 已定 G1-24 路线 | **实测结论**：PMIC SDAM `reboot-reason@48`、`misc` BCB `bootonce-bootloader`/`boot-recovery` **均不被 ABL 采纳**；**PSCI SYSTEM_RESET2 vendor reset 被采纳**（`mode-bootloader=<0x80010001 0x2>`、`mode-edl=<0x80000000 0x1>`，无 recovery）。落地 = `elden/vk41-psci-reboot` 最小钩子（`psci.c`）；`reboot bootloader` → fastboot **实测成功**。EDL = TCSR DLOAD cookie（`qcom,dload-mode=<&tcsr 0x19000>`）。**2026-10-20：EDL 根因已定位并修好**——先前「本机不支持 EDL」的归因是错的：EDL 不走 reboot-mode magic，而走 `qcom_scm` 的 `download_mode`（TCSR `0x1fc0000+0x19000`）；我们 `sm8750.dtsi` 既无 `qcom,dload-mode` 也无该 TCSR 块 ⇒ 地址恒 0。已按原厂 DTB + 上游 kaanapali 三源对齐新增 `tcsr: syscon@1fc0000` 并挂 `qcom,dload-mode`（`patches/edl-dload-20261020/`，`dtbs` rc=0、`dtbs_check` 0 诊断），`eldroid-bootctl reboot edl` 改为真实实现；**真机 9008 触发未验**（需用户同意承担一次进 EDL）。另：槽位/计数已与 QTI `gpt-utils.h` 逐位核对等价，无需替换；TWRP 的 BCB 通道本机实测不被 ABL 采纳，不采用 | **G1-24**；`archive/topics/FLASHCTL-2026-10-03.md` §7–§9、`reports/twrp-parity-edl-dload-20261020.md` |
| **Q25** | 🔒 **已归档（2026-11-10 深夜随 G1-29 收口）**：UEFI 两种形态都通，flashed 真根因 = `dtbo_a`（与 UFS/UFSDxe 无关）⇒ 不需要 tiny DXE；上游 `#12` 两条回帖已闭环（含 2026-11-13 的 UFS 枚举 `BlockIo=119` 结论）⇒ **本 Q 无剩余动作** | 决定将来是否重启 UEFI 方向；**当前不阻断主线** | 无（已归档；重启判据见 §4 N1） | **G1-29**（状态见 §1 该行）；历史取证链（`0x402` 反汇编定论、`UFS.c+2326`）→ `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q25、`reports/uefi-restart-20261021.md`、`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` |
| **Q24** | **桌面熄屏（DPMS off）→ 整机硬复位/断电** | ⛔ **关闭·不值得取证（2026-10-24 用户裁决）**：不再做任何取证（含原保留的 `vk149` 臂，**取消**）—— 根因已指名且日常线免疫，继续取证无判别力 | 装相机模块后长时空闲不断电 | G1-22 / G1-33；逐轮证据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q24、`TASKS/sessions/2026-11-03-TASKS行443-Q24.md`、`reports/q24-suspend-hypothesis-excluded-20261019.md`、`reports/q24-n7-vk127-20261017.md`、`PITFALLS` #197–#212 / #282–#289 / #294–#295 |
| **Q26** | ~~WiFi 关联后 IPv4 约 140 s、每 16–18 s 周期掉线~~ | ✅ **已关闭（2026-10-10 用户实机确认 WiFi 正常，关联即可用）** | 已无需再测（关闭项不从「怎么测」再取样本） | 历史排查全文 → `archive/topics/history-chain-tasks5-20261014.md` §Q26 |
| **Q28** | **面板 init 间歇失败 → 只有背光无桌面**（在机镜像口径**只在 `DEVICE/README.md` §1.1 维护**，此处不写死镜像号） | 🟢 **已规避·结项（2026-10-24 用户裁决，补采样门槛作废）**：**坏发 ~50%、逐启动随机、按时间成簇（会话级）**、**与镜像/构建身份无关**（旧「构建身份伪影」作废）；七臂 vk116–vk123 全否证；**故障态不在 DSI 控制器内部**；日常靠看门狗兜底（~50%→~75%）。结项样本 = 真 POR 5/5 + 暖复位 3/3 = **8/8 无坏发** | 冷起后 `card0` 在 + 面板实测有画面（非仅背光）；`fastboot getvar all \| grep -c "psci: SYSTEM_RESET2"` = 0 可作「本发是真 POR」的硬判据 | `reports/q28-DOSSIER.md`（SSOT）、`reports/q28-INDEX.md`（文档地图）、`reports/q28-dsi-recover-20261012.md`；寄存器级与逐轮细节 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q28、`TASKS/sessions/2026-11-03-TASKS行445-Q28.md` |
| **Q31** | ~~M1 7.3-rc7 重基树「管道全绿但面板只有背光」~~ | ✅ **已解（2026-10-14，E1b）**：`writel(0xc0, PLL_SYSTEM_MUXES)` 放进 `dsi_7nm_phy_enable()` 预置块（refcount 不动）⇒ 干净 POR 面板有内容 + 触屏可用；根因 = 上游 `44784327815b` revert 了 bonded PLL init（`PLL_SYSTEM_MUXES=0xc0` 永不写入），我方净差异 = **1 行语义** | 同窗口 `vk94` 对照；机上验收 `reports/trials/20261014T115840Z-m1-baseline.json`（`Run /init` 7.67 s、`card0-DSI-1` connected、用户目视面板+触屏） | `reports/m1-73-e1b-pllfix-20261014.md`、`patches/m1-73-e1-pllfix.patch`；历史口径 → `archive/topics/history-chain-tasks5-20261014.md` §Q31；**M1 / §7** |
| **Q1** | **容器内的 GMS 身份 / Play Integrity / Widevine 能做到哪一级**（不作猜测，先取证） | 决定 G2 兼容上限与是否需要 VM/换路线 | 复现三条社区做法各一次（只变一个变量）：① Waydroid + GApps；② 未认证设备注册；③ Widevine L3 注入。**本机取证**：GMS 登录 ✅、Google 连通 ✅、**Widevine 不存在**（只有 ClearKey）、`build=test-keys/userdebug` ⇒ 不加对策 PI device 必失败；STRONG **结构性否证**（无 TEE、keymaster 4.0 软实现）。**★2026-11-10 书面收口 = `reports/c3-pi-tiers-closeout-20261110.md`**（三档结论 / 结构性否证三条 / 换路线净增益 0 / 唯一剩余动作 = 一次 SPIC 回包） | **C3**；社区侧与逐轮证据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q1、`TASKS/sessions/2026-11-06-TASKS行411-Q1.md` |
| Q2 | ~~Waydroid 在 **vk40** 上是否不再需要旧 workaround~~ **✅ 已答（2026-10-11，vk64）：仍必需。** 去 workaround 后容器只有链路路由、无 default；`ip rule` → `Operation not supported`（`CONFIG_IP_ADVANCED_ROUTER` 仍 not set）。要根除需开该 config（连带 `IP_MULTIPLE_TABLES`）重编内核。**🆕 2026-10-11 vk95 已开该 config：`ip rule` 上机生效（`local/main/default` 三表），内核侧根修完成；容器端到端（去 workaround 出网）待 Q28 GOOD 启动复测**（见 `reports/c1-iprule-vk95-20261011.md`）。附带发现：vk64 部署模块目录缺 `net/` 核心模块（bridge），已补（`PITFALLS #184`）；模块化 ramdisk 管线也已补齐 net/veth/fuse | 少一处 bind-mount 脆弱点 | 已实测（§C1 行） | **C1** |
| Q3 | **droidloom**（Linux 原生跑 Android 应用，Wayland 直出窗口）在 arm64 宿主是否可用 | 形态优于容器（无需 Android 镜像） | **结论：维持「只跟踪」**（2026-11-11 口径，三次复核逐版收窄）：① 上游自修订 27 起**有 aarch64 包**（最新 `0.1.0-30`）⇒ 自构建不再是唯一路径；② 合成器门槛只剩 `wp_linux_drm_syncobj_manager_v1`（phoc 补丁 + aarch64 二进制已在 `out/phoc-syncobj-arm64-20261111/phoc`）；③ 内核前置已通（`vk187b` 上机 nftables，`ready=True blockers=0`）；④ **L1–L4 全绿**（`vk187b` 上 applications 列出 2 个 Android 应用、Settings 上屏 = 用户目视）；⑤ 身份/完整性上游明确免责 ⇒ 对 G2 硬验收**无净增益**（五维：可用性 1/5、图形 2/5、输入 2/5、音频 3/5、身份 0/5）。复启判据 = R1 受阻或需要「无 Android 镜像」形态 | 逐轮证据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q3、`reports/droidloom-feasibility-20261108.md`、`reports/droidloom-l2-phoc-syncobj-20261111.md`、`TASKS/sessions/2026-11-11-droidloom-L3-上机打通.md`；**C12** |
| Q4 | **无 KVM 前提下 VM 路线值不值得投**（**书面评估已完成 2026-10-02**，结论见 TASKS C8） | 决定要不要开第二条腿 | 结论：**维持低优先**。① 设备侧 KVM 不可达（XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 只适用 Qualcomm dev kit，ABL 重签救不了——hyp 加载点在 ABL 上一级）；② 独立 gunyah 驱动（v17）未进主线（本地 7.2 树 `drivers/virt/` 无 gunyah 目录）；③ 唯一新路线 = KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`），WIP（pinned pages/无 guest_memfd/禁 swap）。**决定性上机实验**：vk40 起机后 `dmesg \| grep -i gunyah`（本地 qcom_scm 已带 gunyah UUID 探测）——通则路线第一步成立，败则归档 | **C8**（🟡 书面结论已出；**2026-10-25 终结 = 不可行，见 §4 N2 终局裁决与 `reports/gunyah-decision-20261025.md`**） |
| **Q5** | **真 Android 对照基线**（一旦覆盖 a 槽就不可复得）：GMS 属性 8 段、Widevine 级别、7 颗传感器读数曲线、目标 App 行为 | 兼容层的"标准答案"，也是判定容器是否等价的尺子 | ✅ **主体已采（2026-10-11，U2 a 槽 stock，报告 `reports/c0-android-baseline-20261011.md`）**：`getprop` 全量、Widevine **L1**（`dumpsys IDrmFactory/widevine`）、42 传感器清单、分区/包、AVF apex、账号（0）。**剩**：30 s 传感器 CSV、5 App 录屏（均为 App 行为项，与 root 无关）。**PI 判定不属本基线**（对象 = Waydroid 容器 → §2 C3）。U1 a 槽（stock+root）可另采；root 专属项已判定无产出、不补采（2026-10-13） | **G2/C0**；`backup/HA2EXB0E-16+512/c0-baseline/` |
| Q6 | 兼容层验收的**量化判据**——**已定稿（2026-10-02，A15）**：10 条用例+阈值见 `README.md §6` §5 | 避免"看起来能用"的自欺 | 上机后按用例表逐条实测打分（打分模板同处） | **C9**（模板就绪） |
| Q7 | ~~Linux 分区到底要多大~~ **已解决（2026-10-03 G1-2）** | GPT 手术一次给足，避免二次缩容 | 实测划定：`linux17`=193 GiB（CRC 校验过），估算表在 `../DEVICE/README.md` §3.1 | G1-2 ✅ |
| Q8 | ~~音频是否真的可听 + 有无录音通路~~ **已解决（2026-10-04 G1-4）** | G1 硬验收 #4 | 实测：`amixer cset numid=8 on` 后扬声器出声 ✅；`arecord -D hw:0,2`（AMIC1）采集 ✅，UCM2 Mic | G1-4 ✅ |
| Q9 | ~~相机能否真正出流（graph ENABLED ≠ 有帧）~~ **已解决（2026-10-05 G1-5）** | G1 硬验收 #5 | 实测：前后摄 `v4l2-ctl --stream-mmap` 连续出帧 rc=0，帧尺寸精确吻合 | G1-5 ✅ |
| **Q15** | **解锁 U2 的两个不可逆代价**：① Widevine **L1→L3**（现 `sys.lenovo.widevine_security_level=L1`，属 TEE 内密钥，社区主流案例为永久降级）——它正是 Q1/Q5 容器侧 DRM 上限的「标准答案」；② 保修 + FOTA。**两台单元现均已解锁**（U1 2026-08-16 / U2 2026-10-03；U2 实机现 `flash.locked=0`） | 先拍基线再解锁，否则事后无法对照；且影响 G2 的 U5 用例上限 | ✅ **已执行（2026-10-03）**：`scripts/bl-preunlock-evidence.sh HA2EXB0E` → `backup/HA2EXB0E-16+512/pre-unlock/`（getprop 全量/by-name/传感器清单/settings/Widevine=L1 + SHA256SUMS）；解锁后重测同一项做对照 | **G1-0**、Q1/Q5 |
| **Q32** | ~~暖起 vs 冷起的差异~~ **已结项（2026-10-24）：五发判据表已成（W1×2 / C1×2 / W2×1 全 GOOD、无入口差异）⇒ 并入 Q28，不再单列** | 已并入 Q28 | 无（已结项） | 立项记录/逐发数据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q32、`reports/q32-warm-vs-cold-preresearch-20261023.md`、`PITFALLS #166`；在机镜像只读 `DEVICE/README.md` §1.1 |
| ~~**Q16**~~ | ~~三代「模板改 SN 自造解锁 blob」在四代 259 上是否有效~~ **已结（2026-10-03）：无效。** 四代 1.5.x ABL 换内嵌 key，**任何** sn.img（官网/三代免签模板/第三方签名）都过不了；且 **1.1.11.120 / 1.5.x 本身就不开放解锁命令**（版本门）。正解 = 降级 1.1.11.073 后 `fastboot oem unlock`（U2 已实测一次成功，无需 sn.img） | 不影响 G1（EDL 路不受 lock 位限制） | 已验证；`PITFALLS` #86、`RUNBOOK` §0.5 ★权威顺序、复盘 `archive/topics/复盘-2026-10-03-BL解锁.md` | 已结 |
| ~~**Q18**~~ | ~~第三方签名四代 blob（356 B）能否过 259 的 ABL 验签~~ **已结（2026-10-03）：不通过**——`flash unlock` OKAY（伪分区，不算数）但 `oem unlock-go` 失败；离线 18 组合验签全败 ⇒ 四代 ABL 换 key。**结论：买/求签名文件对 1.5.x 无用**；blob 与取证保留作证据（`backup/HA2EXB0E-16+512/sn-neko-zuxos.img`、`sn-neko` 取证 §5） | 已关：G1-0 靠降级解决 | `PITFALLS` #84/#86 | 已结 |
| ~~**Q17**~~ | ~~locked 态下「EDL 直写 + testkey 自签链」能否把 b 槽引导起来~~ **不再阻塞（2026-10-03）**：U2 已解锁 → 本实验从「必需」降为「可选」；`scripts/build-locked-chain.sh` 离线验证全绿，**真机未验**（无 locked 单元） | 若将来拿到 locked 新单元且想保住 Widevine L1/保修，本实验仍可取代解锁 | 照旧：`qdl` 写 `boot_b`/`dtbo_b`/`vbmeta_b` 后从 b 槽引导；失败留屏幕状态/日志 | G1-1（可选） |
| Q10 | TF 卡间歇写丢失是卡、还是 `sdhci-msm` flush/cache | ✅ **倾向「卡本身」（2026-10-26：新卡 3 轮 0 不一致 + `err_stats` 全 0 + fsck clean；ios 37.5 MHz/4-bit/SD_HS）；旧卡废置 ⇒ 不做驱动侧补丁选择** | 无需继续（仅新坏卡出现时重开） | G1-6 |
| ~~Q11~~ | ~~DP 输出被 `disabled` 的 ADSP altmode/UCSI 能否修好~~ **已结（2026-10-07）：与 UCSI 无关**——真因 = `dwc3_drd_init` 仅在 `dr_mode=otg` 时跑（本机 DTS 写死 `peripheral`）⇒ role switch 未注册 ⇒ `ucsi_init` EPROBE_DEFER 放弃；ADSP UCSI PPM 本身可通 | 外接显示能力（已解） | —（定案见 G1-9 根因链三步） | G1-9 ✅ |
| Q12 | 温控缺 OEM 层（`lenovo,sys-temp`/BCL）会不会在长期负载下露短板 | 安全边界 | 长时压测（≥2 h）+ `thermal-watch` 采样，看壳温与限频层级 | G1-8 附带 |
| **Q13** | ~~AVF 资产（crosvm/vm/microdroid_kernel/u-boot.bin）主机上找不到~~ **已解决（2026-10-04，离线提取）** | C8/R2 VM 路线的地基资产 | 不需设备：从原厂 259 system 镜像 `/mnt/Samsung/l2/system_a.pristine.img` 的 `/system/apex/com.android.virt.apex`（87.8 MB）debugfs 提取 → `backup/avf/`（crosvm 含 **Gunyah** 后端、microdroid_kernel **6.6.77-android15-8**、u-boot.bin/rialto.bin/initrd 全；SHA256SUMS）；`scripts/extract-avf-assets.sh` 可重跑 | ✅ 资产部分已闭；**a 槽覆盖前真正不可复得的只剩 C0（真机 getprop/DRM/传感器/App 行为）** |
| **Q14** | ~~**C4 UDP HAL 上机三未知**~~ **✅ 已解（2026-10-11，路线 C）**：① 宿主↔容器 UDP 可达（宿主发 52012 即达，无防火墙阻挡）；② 路线 C 不涉 `/vendor`/overlay，无 SELinux context 问题；③ 传感器名/映射由 daemon `getSensorsList` 决定。实测 6 h/w sensors running + UDP 喂值出事件 + 自动旋转监听连接 | C4 验收前置 | 已实测（§C4 行、`reports/c4-route-c-20261011.md`） | **C4 ✅** |
| ~~**Q19**~~ | ~~locked b 槽实验三未知~~ **已结（2026-10-03）**：U2 走降级路解锁成功（`fastboot oem unlock`），locked 实验不再需要；三未知答案归档：① U2(259) vbmeta_b 顶层=8fcb864f；② 1.1 与 259 的 vbmeta 顶层/boot chain key 均为 **AOSP testkey 2597c218**（私钥在手），rollback 均 1738713600/0；③ dtbo 无 hash 校验需求由自造 vbmeta 控制。路 C 管线保留作资产 | — | — | 已结 |
| **Q29** | ~~容器 vendor 镜像 Mesa 与宿主 bind Mesa 重叠~~ **✅ 已核对并简化（2026-10-23）**：`debugfs` 从 `vendor.img` 抽出 `config_nodes` 涉及的 **11 个**文件与 `/root/wd/mesa/...` 逐一比对 ⇒ **9 个逐字节 SAME**；剩 2 个（`lib64/libgallium_dri.so`、`lib64/hw/vulkan.freedreno.so`）**同尺寸、不同 build-id**，但**段级 `.text`/`.rodata` 相同**，只有 `.eh_frame*`/`.plt`/`.got.plt` 与 build-id 不同（同源两次构建）。⇒ **删除 `config_nodes` 里 `waydroid-mesa-swap` 段全部 11 条 bind**（备份 `config_nodes.bak-q29-20261023-221233`），起真实桌面会话实测 **`GLES: freedreno, Adreno (TM) 830, OpenGL ES 3.2 Mesa 26.1.8`**，容器 `/vendor/lib64/libgallium_dri.so` = 镜像内那份（mtime 2026-10-13 12:03）⇒ 图形栈正常。**（附）容器内录音「app 级」已可用**：修 emulated storage（见 Q30）后，自带 `org.lineageos.recorder` 无头驱动出 m4a。| 容器图形一致性（已闭） | ✅ 已核对 + 已简化 | `reports/closeout-q29-backlight-camera-20261023.md` §1、`PITFALLS #190` |
| **Q30** | ~~容器内 emulated storage 不可挂~~ **已修（2026-10-11）**：`sm list-volumes`=`emulated;0 unmountable`，全部写外存的 app（含自带 Recorder）`getExternalFilesDir()` 返 null。根因=容器缺 `/dev/fuse`（宿主有，但 `config_nodes` 生成时它还不存在 ⇒ `lxc.py make_entry("/dev/fuse")` 跳过）。修=`config_nodes` 加 `/dev/fuse` bind + `/etc/modules` 加 `fuse`；修后 `emulated;0 mounted`、Recorder 可存 m4a。 | 容器存储完整性（G2/C4） | ✅ 已修 | `reports/container-audio-20261011.md` §5.6 |
| **Q20** | **流程病：引导链问题先外部取证/自研、后本地检索** ⇒ 把 7、8 月已定的结论（版本门、.120 trap、失败特征串、**U1 已于 2026-08-16 用降级路解成功一次**）在 10-03 重新发现一遍，多花一轮必败实验。根因：`references/*.md` 正文不入上下文，**不 grep 等于不存在**（`PITFALLS` #87） | 上不设防就会再犯（下次是新 ROM 版本 / 新单元 / AVB 参数） | 已落：① `AGENTS.md` 新增「本地优先」规则；② `RUNBOOK` §0.5 ★权威顺序置顶（含版本门与停手串）；③ 本文末一条 grep 命令作开场强制动作；④ 引用旧成功记录先查单元+固件态 | 流程（无单元依赖） |

| **Q33** | **WCD939X 冷起 5425 行 `ASoC error (-16)` 读重试（耗 20 s）** | 音频最终可用，但启动多等 20 s、并刷屏 | 抓调用栈/调用者（T139 音频卡初始化上下文），确认 `soc_component_read_no_lock()` 的 EBUSY 来源（regmap 在 runtime-suspend 时读）；复现命令见 `reports/vk163-por-boot-latency-20261026.md` §3 | T21 / G1-4 / `PITFALLS #421` |
| **Q34** | **`bluetoothd` 冷起偶发 crash**（`rc-service bluetooth stop/start` 后正常） | 冷起后蓝牙不可用，需手动重启服务 | ✅ **已定案（2026-10-28 现场复现）= 不是 crash，是 WCN7861 外设固件缺文件**（`PITFALLS #454`）：`bluetoothd` 一直 active，`hci0` DOWN / BD 全 0、`Direct firmware load for qca/tmel_peach_20.elf failed with error -2` ⇒ `Peripheral setup failed: -2`；设备 `/lib/firmware/qca/` 只有 4 个文件（少 tmel）。补文件 + `modprobe -r hci_uart; modprobe hci_uart` ⇒ `hci0 UP RUNNING` / BD `22:22:62:9C:97:58` / `QCA setup on UART is completed`；**重载服务或重载模块都不解决，必须补文件**（旧「restart 就好」与本次不同源）。根治 = `elden-firmware` 加 `local-extras.tsv` + 新门禁 A2「驱动 `MODULE_FIRMWARE` 声明的厂商固件必须进包」（负向测试已验证）。原判据存档：若为 D-Bus 名抢占则在 `bluetooth` 服务加 restart/调序 | T21 / G1-7 / `PITFALLS #420` 邻近 |
| **Q35** | **双口能否「长边跑数据 + 短边快充」** | ✅ **已判定（2026-10-29 实测）= 物理可行、被 ADSP 选口策略挡住**：只留短边 PD 时电池 **12.2 A**（capacity 19%→27%，≈46 W）；两口同插则只吃长边 SDP 0.891 A。内核逐口建模（两 `typec/port*` + 两 `ucsi-source-psy-*` + 两颗 SMB1501）⇒ 不是「内核只认一口」；`qcom-battmgr-usb` 只读跟随被选中的那口，AP 无控制面 ⇒ **归因固件（ADSP 策略）** | 不阻塞 G1/G2；反向接法「PD 长边、数据短边」已观察到数据与充电并存；快充和热切换待验证（见 `DEVICE/README.md` §1.4；M3-1 仲裁的必要性未证实） | **不再投入**（除非将来 ADSP 侧提供选口接口）；事实正文只在 `DEVICE/README.md` §1.4，采样与判据 = `reports/usb-dual-port-test-protocol-20261029.md` §8 | 不需要单独任务行 |

---

### 2. 已知缺口的补救路径（G1 侧，简表）

> **只列未闭合项**，且本表不维护状态数字（✅/❌ 一律看 §1 对应任务行）。
> 已闭合/取消（相机出流 G1-5、音频 G1-4、DP G1-9、CDSP G1-11、BT G1-7、NFC 取消 G1-10）不再在此复述。

| 缺口 | 类别 | 补救路径 | 关联 |
|---|---|---|---|
| ~~TF 卡间歇写丢失~~ | ✅ 已定性（新卡 3 轮零错误；旧卡废置） | 无（`patches/candidate-tf-*.patch` 保留备查，不实施） | G1-6 / Q10（已收口） |
| 熄屏 × 相机共存 | ~~DT 电源域耦合~~ **更正：RPMh rail retention 档**（2026-10-23，已指名） | **已由上游 `skip retention by default` 解决（7.3 含）；日常线无需本地补丁、无需规避** | G1-33 / Q24 |
| 进 GUI 后整机卡死（PITFALLS #106，10-05 两次 + 今日 1 次） | 未定性；**非 Q28 专属**（卡死那次桌面显示正常，用户 2026-10-09 确认）；APSS 硬看门狗被永久禁用 ⇒ 死挂不自复位，故一直抓不到栈 | **已常驻装弹**：`/etc/sysctl.d/99-freeze-trace.conf`（softlockup_panic+all_cpu_backtrace+panic=20+sysrq）+ `pstore-catch`（开机把 ramoops 归档到 `/var/log/pstore/`）⇒ 真实使用/压测中命中即自动 panic→暖复位→带回全 CPU 栈；压力器 `scripts/gui-stress.sh`（PATHCHECK=mdss vsync 增量，实测 6 s +319 才算有效样本）；首轮 60 轮合成负载压测**未复现**（峰值 66.1 ℃、load 1.8）⇒ 改靠常驻装弹在日常使用中等它自己撞 | — |
| 面板 init 间歇失败（只有背光） | 收窄：**只有开机首次 modeset 触发**（80 轮 DPMS 上电循环 0 命中）；机制候选=首次上电被吞错 + ABL 遗留态（`research-q28-dpu-powerup-race` / `2026-10-09-Q28-密集复现与vk74`） | ~~温启跑 vk74~~ **已作废（2026-11-13 对账：Q28 已结项、运营线 vk152 起 8/8 无坏发 ⇒ 本行不作待办）**；历史二分见 `archive/topics/` | Q28 |
| WiFi 到可用 | ✅ 已关闭（2026-10-10 用户确认正常） | —（历史假设：版本/DTB 增量，见 Q26） | Q26 ✅ |
| SLPI 7 传感器（Linux 侧原生） | AP 侧无总线，需 QRTR + `qcom_smgr` 栈 | 可选自研（路线见 G1-34，未开工）；**G2 侧不等它**——走容器虚拟传感器（§6 §2①） | G1-34 |
| 温控 OEM 层（`lenovo,sys-temp`/BCL/QMI cooling） | 厂商私有 | 通用 thermal 框架已给 4 级 trip；长负载（≥2 h）复核壳温/限频层级 | G1-8 / Q12 |
| TEE/SPU/hw-fence/Gunyah/PMIH010x/BCL/FM/ST54 | 私有或无源码 | 明确不投入 | ✗ 结案 |

---

### 3. 环境与流程类待办（不属功能，但会咬人）

| 项 | 现象 | 处理 |
|---|---|---|
| 代理 `127.0.0.1:7897` | ✅ **已恢复正常（2026-10-06 复核：`curl -x 7897 https://www.google.com` → 302）** | 现状 = **Clash Verge Rev / verge-mihomo**（root，mixed-port 7897，mode=rule，tun 关闭）；2026-10-05 已加 99 条校园/教育网 DIRECT 规则 + bashrc `no_proxy` 覆盖。排障/回滚见 `~/netfix/复盘-2026-10-05-教育网分流-clash规则.md`；凭据通道见 `~/netfix/凭据与下载通道-2026-10-05.md` |
| `/mnt/Samsung` 无 `nofail` | 掉盘卡开机 | ✅ 已修（A18，2026-10-02） |
| `qemu-utils` 缺失 | 不能造/转 guest 磁盘 | ✅ 已装（`/usr/bin/qemu-img`、`qemu-nbd` 在位，A13 勾销） |
| API 双重限流（20 req/窗口 + $30/3h） | worker"干净退出"像崩溃 | 用 provider `deepseek`；并发 ≤3；见 `archive/topics/复盘-2026-10-02-swarm.md` |
| vermagic 耦合 | 改 `CONFIG_LOCALVERSION` → 相机 `.ko` 全废 | 改内核版本必须整套重编 `.ko` |
| 备份目录命名 | 历史 `backup/new-tablet/` 语义已废 | 新操作一律 `backup/<SN>-<容量档>/`；脚本默认值参数化（A16） |

---

### 4. 风险登记（高影响，需你决策或知悉）

| 风险 | 概率/影响 | 缓解 |
|---|---|---|
| ~~解锁 U2 = 永久失去 Widevine L1 / 保修 / FOTA（全项目唯一 locked 单元）~~ **已解锁（2026-10-03），本条关闭**；残余 = 新单元若在 1.5.x 上试解锁会白跑一轮 | 低 / 中 | 解锁前 locked 基线已入库（`backup/HA2EXB0E-16+512/pre-unlock/`，Widevine=L1 已记）；G2 的 U5 用例按 L3 上限做预期 |
| 1.5.10.259 屏蔽解锁指令导致白跑一轮 | ~~低/低~~ **已发生（2026-10-03）** | 已由全量降级 1.1.11.073 解决（G1-0 已关闭）；**以后新单元直接判版本门→降级，不再在 1.5.x 上试解锁**（`RUNBOOK` §0.5）。注：U2 现态已回 **259 + unlocked**（2026-10-03 实机核验） |
| 覆盖 a 槽后强检测/银行类 App 完全不可用 | 中 / 中 | Q5 先取证；保留 stock + EDL 恢复；容器不行就换路线而不是硬扛 |
| GPT 手术/回收分区写坏 LUN0 | 低 / **高** | 手术前**分区镜像备份（三选一：设备侧 `dd` / 线刷包解出 / **EDL 读回**；本 ABL 无 `fastboot fetch`，#290；**EDL 工具链与 loader 见 `RESOURCES/README.md` §2.1（其能力限制：本机 loader 不放行 `peek`，`PITFALLS #486`）**）** + GPT 双表 dump + EDL 包在手；只写主/备表两处；写后读回校验 |
| 设备热失控（曾 103 °C） | 低 / 高 | 分级 trips 已在线；压测必带 `thermal-watch`，超 90 °C 自动降级 |
| ~~空闲熄屏→重启（U2 实测）~~ **已关闭（2026-10-24 用户裁决：不值得取证）**：日常线（7.3 血统）免疫，Q24 只读 §5 | 低 / 低 | 禁止空闲熄屏（`idle-delay=0` 或 phosh caffeine 常开）作为临时规避，并把它写进 `start-desktop.sh`/rootfs 归档；根治前 **不要**在不可回滚的持久系统上做熄屏实验（详见 `archive/topics/复盘-2026-10-03-持久化与睡眠.md`） |
| **未验证内核增量（vk34 之后）** | 已发生 / 中（风险已降级） | 2026-10-03 二分只能说明「vk34→vk40 叠加体内有回归」；**熄屏复位的真因后续定为单模块 `cambistmclkcc-sm8750` × DT 电源域（不在那 5 文件内）**，见 Q24。残留风险 = vblank/PPM 计数回归未复核（G1-23）|
| 边充边跑掉电（PMIC 默认 100 mA） | 中 / 中 | 上机前 `charge-ctl.sh` 拉满输入电流；长任务挂充电器并监控 |
| 单一路线依赖（只押 Waydroid） | 中 / 中 | 保留 redroid 作 R1' 备胎（本文 §6 §0） |
| **宿主内存位翻转**（曾致构建静默损坏；2026-10-20 已定性，原 T11） | 中 / 中 | **归硬件项目，不属于本项目待办**：判据 = 三读法 `scripts/detect-memory-corruption.py` + 构建前后门 `scripts/kbuild-sanity.sh`；硬件侧检测（BIOS memtest / 换条）由用户在其硬件项目处理 |

---

### 5. 勾销规则

- 勾销一条 Q ⇒ 必须给出：命令、原始输出片段、结论一句话、生效文档链接（`../DEVICE/README.md` / `README.md §6`）。
- 不允许"口头已确认"：控制面 OK ≠ 数据面 OK（`GRAPH_START status=0` ≠ 可听；graph ENABLED ≠ 出帧）。

---

## 6. G2 安卓兼容方案（ANDROID-COMPAT）

### 0. 结论先行

**主路线 = 容器（Android-in-Linux），备选 = 虚拟机，观察 = 原生合成器方案；三条都不依赖 a 槽常驻。**

| 路线 | 形态 | 与"无安卓"前提 | 本地现成度 | 定位 |
|---|---|---|---|---|
| **R1 容器** | **Waydroid**（LXC + AIDL/HAL + 我们的 freedreno） | ✅ 完全符合 | ✅ Mesa 26.1.8 解 A830 chip-id、GAPPS 镜像在手、内核 binder/XFRM/netfilter 已开、代理通路已通 | **主力，先做（C1–C6）** |
| **R1' 容器备胎** | **redroid**（Docker/podman/k8s，arm64 官方支持，GMS 经 OpenGApps/MicroG/MindTheGapps） | ✅ 符合 | ⬜ 未装；与我们内核的 binder 配置兼容 | **备胎**：R1 受阻（图形/HAL 层）时切换验证 |
| **R2 虚拟机** | Android/Debian guest；本机 **无 KVM**（消费者机：XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 模式只适用 Qualcomm dev kit）⇒ ① KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`，需数周 port，WIP）或 ② QEMU TCG（可用但慢，Android 不可接受） | ✅ 不需要 Android 宿主（方案①） | ⚠️ AVF/DroidVM 是 Android 侧用法（与新前提冲突）；Gunyah ABI 兼容性待上机探测（`dmesg \| grep gunyah`） | **调研，不承诺**（C8 书面结论已出，维持低优先） |
| **R3 原生** | droidloom（Wayland 直出窗口，shared-kernel；Denial 合成器同栈） | ✅ 形态最优雅 | 🟡 aarch64 产品已一等（OnePlus Pad 4 真机跑通）且**2026-11-08 起有 aarch64 发布包**（修订 27–30，`0.1.0-30`）；**新增硬门槛：宿主合成器需 `linux-dmabuf` v4 feedback + `linux-drm-syncobj`**（Phosh 不满足）；更早的阻碍是 R1 本身未受阻 | **只跟踪上游**（Q3，R1 受阻再试） |
| （相邻）| Win-x86 转译 Box64+Wine | ✅ | ✅ **PoC 已成功** | 已交付，与 R1 共用 chroot/防护范式 |

> **为什么容器优先**：它是唯一"不重启、不离开 Linux、能用我们自己的 GPU 驱动栈、可单独卸载"的形态；
> 且社区在**纯 Linux 宿主**上把 GMS/Widevine 做进容器的先例最多（`../RESOURCES/README.md` §1.3）。

---

### 1. 兼容度评估（5 维，**分数随实测更新**，当前为初始估计）

| 维度 | R1 Waydroid | R1' redroid | R2 VM | R3 原生 |
|---|---|---|---|---|
| C1 功能兼容（App 能装能跑，含厂商 App/游戏） | 4 | 4 | 4 | 3 |
| C2 身份兼容（GMS 登录、Play Integrity、Widevine） | **2**（GMS 登录+连通 ✅；PI ≤ BASIC/DEVICE 且**需伪装、不可承诺**；DRM **无**）→ `reports/c3-pi-tiers-closeout-20261110.md` | 同 R1（同栈，净增益 0） | 0（无 TEE 给 guest） | 0（上游明确免责） |
| C3 性能（GPU/帧率/内存） | 4（freedreno 直驱） | 3–4（GSI + binder GPU HAL） | 2–4（图形最不确定） | 4 |
| C4 系统集成（窗口/输入/**传感器**/音频/相机/文件） | 3（传感器、相机是短板） | 3 | 2 | 4 |
| C5 可逆与风险（可卸载、不触信任根） | 5（删容器即净） | 5 | 4 | 5 |

**分数口径**：1=不可用 3=可用有坑 4=日常够用 5=等同真机。**C2 一律先填"待调查"，实测后回填**（C3/C4 允许边测边改）。

---

### 2. 兼容层设计（`elden-droid`）：容器优先的四件事

```
   Phosh/Wayland ── eldroid-cli (统一入口: start/stop/status/reset)
        │
        ├── R1 waydroid session ──┐
        ├── R1' redroid container ┤（二选一，切换验证用）
        │                         ▼
        │        ┌────────────────────────────────────────┐
        │        │ eldroid-bridge（我们要写的适配层）      │
        │        │  ① 传感器注入  uinput + UDP sensord     │  ← C4，补 SLPI 7 颗缺失
        │        │  ② 相机共享    v4l2loopback + sampler   │  ← C5（待 G1-5 相机出流）
        │        │  ③ 音频通路    PipeWire → AudioReach    │  ← C6（待 G1-4 听声）
        │        │  ④ 身份/商店   GApps 注入 + 未认证注册  │  ← C3（先复现社区做法，不预设结果）
        │        │  ⑤ 网络/代理   已通（netd+默认路由+http_proxy）
        │        └────────────────────────────────────────┘
        └── 回退保险：stock Android 镜像包 + EDL 全量包（可整机复原，但非常驻）
```

| # | 缺口 | 我们的补法 | 不做什么 |
|---|---|---|---|
| ① | SLPI 7 颗传感器（IMU/磁力/气压/温湿度/SAR/霍尔/光感）主线不可用 | **UDP HAL 真实现**（原 uinput 方案作废——waydroid sensors HAL 是 stub，不读 evdev，见 `archive/topics/SENSORS-WAYDROID-STUB-2026-10-03.md`）：waydroid-build 树 `hardware/waydroid/sensors/Sensors.cpp` 实现为「UDP 收值 → 喂 framework」（已编译成功）；入口 prop = `waydroid.sensors.enabled`（**勿用** `waydroid.stub_sensors_hal`，会触发 framework 锁旋转）。真值来源：① `scripts/eldroid-sensord.c` 编译出的 `eldroid-sensord --send 容器IP --fake`（兜底纯软件轨迹；**二进制不入仓**，源码在 `scripts/`）；② 同型号另一单元 a 槽 Android 经 Termux:API 转发（`env-pass/scripts/sensor-send-termux.sh`，设备等价的直接红利）；③ 其他安卓设备 | 不移植 QMI-SNS/不救 SLPI 固件；不动 Qt5/sensorfw（droidian 路线，Alpine 不现实） |
| ② | 容器无相机（厂商 camera-provider 不可用） | mainline camss 出流后 `v4l2loopback` 转发进容器 | 不写厂商 camera HAL |
| ③ | 容器音频路径未接（AudioReach 刚通） | PipeWire 桥接；先打通播放，再测录音 | 不追求低延迟游戏音频（先量化） |
| ④ | GMS/商店/DRM 身份 | **按社区既有做法逐条复现并记录**：GApps 包（OpenGApps/MindTheGapps/MicroG 三选 + **WayDroid-ATV arm64 GAPPS 镜像** 2026-01 SourceForge）、未认证设备注册流程、Widevine L3 注入（**x86-64 有现成库；arm64 仅 Android 11 有、A13 无**——2026-10-07 `waydroid_script` 源码核实）；每次只变一个变量 | **不预设"不可能"**；不做密钥伪造/绕过安全启动 |
| ⑤ | 传感器之外的输入/窗口 | 触屏/键盘/鼠标由主线输入子系统透传；窗口用 phoc freeform；**马达已透传（✅ C10，2026-10-13：容器 `vibrator` HIDL HAL 写的 `leds` 节点由宿主桥目录 bind 覆盖 + `elden-hapticd` 转 `aw86927` FF_RUMBLE；`PITFALLS #232–#238`）** | — |

---

### 3. 「a 槽可弃」带来的风险与对冲（必须如实记账）

| 风险 | 影响 | 对冲 |
|---|---|---|
| 放弃 Android = 失去"100% 兼容兜底"，兼容度完全取决于 R1/R1' | 强检测 App / 银行类 / L1 DRM 场景可能整体不可用 | 保留 `backup/stock-259/` + EDL 全量包 + `restore-259/` 流程；**恢复只需一次 EDL**（不是不可逆） |
| 一旦 a 槽被覆盖，无法再"用真 Android 校准" | 无法对照真机行为 | **已对冲（2026-10-11 采自 U2 a 槽）**；产物与剩余项指针 = §5 Q5 |
| 手术回收 Android 分区（`super_a/b` 等）扩大 Linux 空间 | 更彻底不可逆 | 只在 G1 稳定后做，做前 EDL 备份 + 读回校验；分区表脚本化 |
| 无 Android ⇒ AVF 路线（需 Android 宿主）自动失效 | VM 路线只剩高成本方案 | 所以 VM 定为"调研不承诺"（C8）；若将来需要，任一台单元刷回 stock Android 即可（等价原则保证可换机） |

---

### 4. 待你拍板（1 条，都是取舍不是参数）

1. **是否 Phase B 回收 Android 专属分区**（`super_a/b`、`boot_a`、`recovery_a` 等，腾数十~上百 GiB 给 Linux）？
   —— 好处：一次解决容量；代价：回退只剩 EDL 全量刷。默认**暂不回收**，等 G1 全绿。

---

### 5. 验收用例集（C9/A15，2026-10-02 定稿）

> 用法：上机后逐条实测，结果填「实测」列；打分口径同 §1（1=不可用 3=可用有坑 4=日常够用 5=等同真机）。

| # | 用例 | 验收阈值 | 依赖 | 实测 |
|---|---|---|---|---|
| U1 | Play Store 登录 | 登录+同步完成 ≤ 5 min；失败模式记录 | C2 | |
| U2 | Play 安装 3 个目标 App | 成功率 3/3；≤ 3 min/App | C2 | |
| U3 | 地图旋转（传感器注入） | 方位角 <500 ms 反映到视图，无跳变 | C4 | |
| U4 | 视频通话（相机+音频） | 对端可见可闻；端到端延迟 ≤ 400 ms；5 min 不断流 | C5+C6 | |
| U5 | 流媒体（Widevine） | YouTube/Disney+ 可播；记录实际分辨率与 DRM 级别（L3 上限如实记） | C3 | |
| U6 | 游戏（GPU） | 目标游戏 30 fps @ 默认画质；帧时间抖动 <30% | — | |
| U7 | 相机出流进容器 | 预览出帧 ≤ 2 s；前后摄切换成功 | C5 | |
| U8 | 容器音频 | 播放可听；延迟 <100 ms；录音通路单独记 | C6 | ✅ **播放 2026-10-11**（闹钟出声，宿主 `pactl list sink-inputs` + 用户实听）＋ **录音通路同日语**（`TestRecord`：samples≈233k、rms≈457、peak≈1815；宿主 `source-output … s32le 2ch 16000Hz`）。延迟未量化；“app 级”录音受容器 emulated storage（`emulated;0 unmountable`）阻塞，另立 |
| U9 | 多窗口/freeform | 2 窗口并排不崩；焦点切换正常 | — | |
| U10 | 休眠唤醒 + 切槽回退 | 熄屏唤醒不丢容器会话；a/b 往返后容器数据完好 | C7 | |

### 6. 版本基线与「自编 / 预制」账（2026-10-06 裁决）

**A. 容器 Android 版本：维持 LineageOS 20（Android 13），不追新版本。**
换版本本身不是编译问题（社区有现成镜像），且**不解决 G2 的两个真瓶颈**（arm64 Widevine L3 无库、GMS/PI 认证）；
新版反而 **Play Integrity 更严、arm64 支持更差**。

| 版本 | 现成 arm64 镜像 | Widevine(arm64) | 备注 |
|---|---|---|---|
| **LOS 20 / A13（现用）** | ✅ 官方 Waydroid OTA | ❌ | Waydroid 官方主线；PI 绕过先例最多 |
| LOS 21 / 22.2（A14/15） | 社区，主要 x86_64 | ❌ | 集成有 bug（`waydroid app install` 坏，需 adb） |
| LOS 23.2（A16） | ❌ 最新 release 原文明写「ARM64 images are NOT available」 | ❌ | 越新越偏 x86_64/PC |

**触发换版本（须有证据，不预设）**：① 目标 App 出现 `minSdk > 33` 装不上；② 某个必须能力只在 ≥A14 有；
③ LOS 20 镜像停更、而新版镜像开始带 **arm64** Widevine L3。
**换法**：优先下现成镜像（~2 GB），Mesa 对新分支重编一次（~10 min）后 bind-mount，**不重编整个 Android**。
证据：`../RESOURCES/README.md` §1.3；WayDroid-ATV releases 页（20260717「LineageOS 23.2 / ARM64 not available」）。

**B. 后续各线的编译量账**

| 线 | 自编内容 | 结论 |
|---|---|---|
| **容器 R1（LOS 20）** | Mesa（已编，偶发重编）+ sensors HAL（已编）+ 可选一次 `vendorimage` | 已 2/3 完成；编译不是瓶颈 |
| **Win-on-ARM VM（DroidVM / crosvm+Gunyah）** | 主链全预制：DroidVM APK + `DroidVM-Prebuilts`（含自建 crosvm，带 SBSA UART/PmReset）+ 驱动 `gunyah-guest-drivers-windows` **dev release zip** + 微软 Win11 ARM64 ISO；**唯一可能要编 = guest UEFI 固件**（本地 `edk2-aarch64-gunyah` 1.5 G，含 Windows ramfb 分支；EDK2 构建 ~10–30 min）——若 prebuilts 已带则 **0** | **基本不用编**；真工作量在：① 映象构建需 **x64 Windows 或 Apple Silicon 主机**（本机 x86_64 Linux 缺此平台）；② `viogpu` **未移植** ⇒ 无 GPU 加速（仅 simplefb）；③ 需 a 槽 Android + root |
| **Win-x86 转译（G3）** | **0**：box64 deb / Wine（Ubuntu amd64）/ Hangover wowbox64 / DXVK / VKD3D-Proton 全为预制；PoC 已成功 | 剩配置+性能+打包；真要 FEX-Emu 也有预制 release |

> 配套：`../RESOURCES/README.md` §2.5 P3「AOSP 工作树整树删」一栏据此**裁决保留**（Mesa 偶发重编需要它，与换不换安卓版本无关）。

**C. GPU 栈的编译量（2026-10-06 核账）**

| 层 | 组件 | 编？ |
|---|---|---|
| **宿主内核**（msm DRM + adreno a8xx） | 我们的 mainline 树 | ✅ 自编，但本就属 G1 主线；`patches/` 里**无 GPU 专属补丁**（0002/0006/0007/0008 均属显示/面板） |
| **宿主固件** gen80000 `zap/sqe/gmu/aqe` | vendor 提取 | ❌ blob |
| **宿主用户态** GL/Vulkan | Alpine `mesa-dri-gallium`(freedreno) + `mesa-vulkan-freedreno`(Turnip) + `mesa-egl` + `vulkan-loader` | ❌ **apk 预制、零编译**（PITFALLS：chip-id 补丁**不要**打，原版才对；未打过） |
| **Android 用户态** | AOSP `external/mesa`（freedreno GL + Turnip）+ minigbm/gralloc + libdrm | ✅ **自编**：`scripts/mesa-build.sh` 定向 make 11 库（已交付，~5.5 min；ccache 热后 ~10 min）；**已完成** |
| **Android 原厂 GPU blob**（libgsl/Adreno utils/KGSL） | Waydroid MAINLINE vendor 用 Mesa 替代，不用 | — |
| **VM 内图形**（virglrenderer/gfxstream） | DroidVM/AVF 预制 | ❌（Windows guest 的 `viogpu` 才是未移植缺口） |

**重编触发**：① 内核 DRM/A830 特性变化或 hang 调优（`has_fs_tex_prefetch` / 26.3 turnip 分支）→ Mesa 重编 ~10 min；
② 换 Android 版本（若触发）→ 对新分支重编一次；③ 想把 bind-mount 改成持久 `vendor.img` → `make vendorimage`（1–3h，一次）。
**结论：宿主用户态 GPU 编译量 = 0；Android 用户态 GPU = 1 组 11 库（已完）；剩下只有偶发 mesa 重编与可选 vendorimage。**

## 7. 上游化任务（M 系列，用户 2026-10-04 定：日后可合并为主线）

> **★投递批次沿革（2026-10-31 / 11-02 / 11-04 三批）已下沉**：原文逐字在 `TASKS/sessions/2026-11-05-§7投递批次沿革-20261031至20261104.md`；逐封实发件在 `patches/upstream/*/sent/`，投递报告在 `reports/mail-send-*`。
> **★当前一页 = `reports/upstream-status-20261113.md`（2026-11-13，取代 `-20261105`/`-20261029`）**：逐系列状态 / 归档复核（patchwork，非 cover 计数）/ **我方欠什么** / 复启条件。
> **外部动向快照 = `reports/upstream-watch-20261113.md`**（2026-11-13：patchwork 线程 12 条 + 待观察 8 条 + 外部仓库 9 条，每条带 URL；lore 全站被 Anubis 反爬拦截，故改用 patchwork REST 取同源数据）。
> **★2026-11-08 增量（`reports/mail-triage-20261108.md`，窗口 11-05 02:40Z → 11-08 05:21Z）**：新信 2481 头、外部回信 10 封唯一 MID、退信 0、我方外发 18 封（v7/v8/v9 + M10）；**行动 = 4 组 10 条技术待办，全部来自 sashiko 机器评审，且逐条在本地源码上确认「仍在」**：A dwc3 binding 3 Medium + 1 Low、B wl2868c driver 3 Medium、C wl2868c binding 2 Low、D M10 1 Low（`Fixes: be9d54c35312`）；人类 2 封（Rob Herring / Conor Dooley）已被 v9 覆盖（Conor 的 `changes-requested` 属时序竞态，v9 cover 已单节说明）；patchwork 上 v8/v9/M10 **tags 全空**（无 Acked/Reviewed/Tested）⇒ **本轮只起草、零投递**；阻塞 1 条 = M10 的 `Fixes:` 提交在本机 4 棵树都 `cat-file -t` = none。
> **★2026-11-14 增量（mdss v5 + 回 sashiko）**：v4 投后收到 **Konrad Dybcio R-b** 与 **sashiko Medium**（0xa000 是 dispcc 单独描述的域、mdss 没 attach 它却 assert 它的 BCR）。质疑**成立**（`sm8750.dtsi:3335` power-domains 只有 `MDSS_GDSC`、`:3322` clocks 无 `mdp1` 族）⇒ 已回信（承认 + 给出可观测事实 + 标注两条测量边界 + 声明无 datasheet 直证 + 附收窄后的 message，`Result: 250`）并发 **v5**（`patches/upstream/m8-mdss-v5-20261114/`：1/3、2/3 未变，3/3 diff 逐字节相同只收窄 message，三个 R-b 含 Konrad，4×`Result: 250`）。全账 `reports/mail-send-20261114-mdss-v5.md`。**重要自证缺陷已写进信里**：15/15 实测是三枚形状（含 RSCC），v4/v5 的两枚形状**从未上机**、`0xa000` **无单变量**。**遗留**：1/3 丢了 v3 上 Rob Herring 的 `Acked-by`（v4/v5 均未带，发 v6 时补回）。
> **★2026-11-12 增量（`reports/mail-triage-20261112.md`，窗口 11-11T08:08Z → 11-12T13:3xZ）**：新 reviewer tag 3 个（Rob→wl2868c v10 1/2 RV；Dmitry→mdss v3 3/3 RV；Dmitry→dpu gamma LUT RV + 要求补 `Fixes: 39a750ff5fc9`）；**已合并 0 条**（238 patch `accepted`=0、`commit_ref` 全空）；**我方欠 5 项，全部需用户批准**（报告 §5 W1–W5）：W1 wl2868c v10 2/2 答 Mark Brown 的 `LDOx_SEQ`（先量设备侧 SEQ 寄存器再定 v11）、W2 mdss v3 2/3 答 Dmitry 的 INT2 措辞/副作用/测试方法（⇒ v4）、W3 dpu gamma LUT 出 v2 补 `Fixes:`、W4 dsi/phy 出 v2 把 9 行注释搬进 commit message、W5 dwc3 v9（Rob changes-requested 的驱动/DTS 改造**尚未做**，当前不具备投递条件）。本轮**零发信**。
> **★2026-11-11 v10 已投（用户放行「三个按推荐决定发/不发」⇒ 只发这一版）**：`[PATCH v10 0/2]` cover MID `<20261111111132.1296892-xiaqinghuan@mail.ustc.edu.cn>`（1/2 `-2-`、2/2 `-3-`），3 封 SMTP 250、lore 3 封 raw 可取；**patchwork 已摄取**（`14972055/14972059` = 1/2，`14972056/14972060` = 2/2，state 全 `new`，`commit_ref=None`）。改法 = 答 sashiko 三条 Medium（SYS_EN 未置位不播种 / reset 与供电顺序 + devres 逆序 / vin7-only 板回退仅认 `-ENODEV`）+ 两条 Low（binding example 加 `vin12-supply`、MAINTAINERS `F:` 移到 2/2）；binding 本体未改。**门禁由我独立复跑**：pristine `25f7927e6ccb` 上 `git am` 2/2 干净、`checkpatch --strict` 两枚 **0E/0W/0C**、`W=1` 单目标编译 **rc=0 无 warning**。产物 `patches/upstream/wl2868c-v10-20261111/`（+`GATES.md`）、报告 `reports/wl2868c-v10-landed-20261111.md`、投递记录 `out/mail-20261111/`。
> **未答项（2026-11-07 现查，patchwork API 实拉）**：**11-04 批的两条欠账已全部还完** —— dwc3 两条 High 由 v8 修掉（sashiko 对 `2/3`/`3/3` 各回「found no issues」）、Krzysztof 两条由「板 DTS 整段拆出」+ v8 commit message 覆盖；wl2868c binding 的 Rob Herring 两点已由 **v9（2026-11-07T01:50Z 已投）** 落地。**当前我方无未答项**，只等 review：dwc3 v8 = `linux-usb 3/3 new`（devicetree 1/3 needs-ack）、wl2868c v9 = `arm-msm 2/2 new`（devicetree 1/2 needs-ack）、M10 `new`。
> **归档复核口径（2026-11-04 起）**：lore `/<list>/<mid>/raw` 返 Anubis 挑战页（HTTP 200 但非原文）⇒ **不得**用 `/raw 200` 当作档证据；一律 **patchwork API** + 按 MID 取 lore `/T/` 线程页，且「N/N 命中」口径 = 「非 cover N/N」。

> 审查已完成（2026-10-04，只审不改）：payload=相对主线 v7.2 的 **125 改 + 11 新文件（≈12.4k 行）**，
> 分级 A/B/C/D 与推进顺序见 `archive/topics/UPSTREAM-REVIEW-2026-10-04.md`。机械检查全净
> (checkpatch/DTC/dt-validate 仅 1 红点=usb@a600000)。
> **上游化规则/违例清单/下游隔离清单 = `reports/upstream-policy-20261013.md`**；M3 分片与验收口径 = `reports/m3-series-plan-20261013.md`（三问门 + 强制框架表 + Q3 违例 + 薄下游层预算）；本节维护 M1–M9 状态（**各 M 行内文即权威**；当前一页 = `reports/upstream-status-20261113.md`（取代 `-20261105`/`-20261029`），含逐系列状态 / 我方欠的动作 / 工具事实。`archive/topics/upstream/upstream-status-20261027.md` 是 10-27 快照、**已过期**，其 M4「未投」与 M8「等回包」均已被 10-28/10-29 动作推翻）。**M6/M7 = 把 Q28/Q24 按上游标准重新定义后的立项（分层、判据、动作）见 `reports/upstream-q24-q28-standard-20261015.md`（2026-10-15）。**
> **投递口径（2026-10-27 更新）**：**按系列逐次由用户批准**——2026-10-13 的「全面投递冻结」自 2026-10-19 起逐案放开（M6 L1 → M8 RFC → M9 → M3-1 v4 → M4-1），未批准的系列仍只做备料。投递口径的历史页 = `archive/topics/upstream/upstream-status-20261026.md`、`-20261027.md`（**当前一页 = `-20261105.md`**；`-20261026/-20261027/-20261029` 均降为历史快照；旧冻结文与「唯一例外 = M3-1」已作废）。

| ID | 任务 | 状态 | 依赖 | 判据 | 证据 |
|---|---|---|---|---|---|
| M1 | 干净上游资产树（upstream tip + payload 重放，剔除 D 类与 vk 历史） |⚠️MIGRATION-LOST(2026-10-17：`build/` 与 `m1/*` refs 未随迁，本行所有树路径已失效，需重放) 🟢 **树已建、干净构建通过（2026-10-11）**： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行691-M1.md`⟫ | — | 树能编出 vk 等价功能镜像 ✅（构建）；上机对照待做（**2026-10-13 晚起已上机 bringup + 上游显示栈对照 P1–P2c，见下方专节**） | `reports/m1-clean-tree-20261011.md`、`.pi/plans/2026-10-10-M1-资产树清单.md`、审查档案 §4 |
| M2 | 首发小系列 A1(GC 块)+A2(battmgr)（**A1 已撤稿=与上游重复；A3 重分类**） | 🟡 **A2 在评审**（battmgr → linux-pm/linux-arm-msm/lkml 已归档）；**A1（DPU GC 块）2026-10-13 已发撤稿回复**——与已在 msm 树的 `3389406e6a03`（Rob Clark，2026-09-30，v7.4）**重复**；**新增 P3 `drm/msm/dpu: reject undersized gamma LUT blobs`（修 sashiko 指出的 OOB 读，2026-10-13 10:04 已发）**：基线 upstream **v7.3-rc7**，`patches/upstream/m2-2026-10-13/`；checkpatch `--strict` 0/0、两目标文件编译干净、收件人 dry-run 通过 | M1 | 发至对应 ML 获 review（+lore 复核） |`patches/upstream/m2-2026-10-13/README.md`；**A3 更正 = 上游 `aw86927.c` 无 firmware 波形装载路径（882 行）⇒ 窗口放宽无对应代码可修，重分类 B/C 不进 M2** ； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行692-M2.md`⟫ |
| M3 | 板支持系列（DTS+binding 随行；拆片见 `reports/m3-series-plan-20261013.md`） |​**★2026-11-06 已投（用户放行「都开始」，`[PATCH v8]`）**：① **dwc3 `[PATCH v8 0/3]`** 4 封全 250，cover MID `<20261106114208.987284-1-xiaqinghuan@mail.ustc.edu.cn>`，patchwork linux-usb 3/3 + arm-msm 3/3 在档；② **wl2868c `[PATCH v8 0/2]`** 3 封全 250，cover MID `<20261106114252.988023-1-xiaqinghuan@mail.ustc.edu.cn>`，arm-msm 2/2 在档。**两系列发信前已重基到 torvalds master `f66469d9905b`（7.4-rc2 线）并重跑全部门禁**；首轮（11:28/11:30）因 `format-patch` 漏 `-v7` 致逐枚 Subject 无版本号 ⇒ **11:42 以 `-v8` 正确重投**（内容逐字节不变，cover 已写明）。**sashiko 已对首轮 `2/3 usb: roles` 与 `3/3 usb: dwc3` 回「found no issues」**（`<sashiko-outbox-201319@kernel.org>`/`<sashiko-outbox-201328@kernel.org>`）⇒ 11-04 两条 High 的修复被机器评审确认。投递记录 `out/mail-20261106/REPORT.md` |**★2026-11-06 v7 备料（已投，见左侧最新条）**：① **dwc3 `m3-dwc3-v7-20261106`** = 11-04 批的 `[PATCH v7 0/3]`，**只答 sashiko 两条 High**（端口/角色撕裂 → `dwc3_set_mode_port()` 原子发布；init 拆除顺序 → `mux->ready` 门控 + 反注册后 drain + 不再清 `role_mux`），1/3、2/3 零变化，3/3 +92/−11；② **wl2868c `wl2868c-v7-20261106`** = `[PATCH v7 0/2]`，**板 DTS（v6 4/5+5/5）整段拆出**（Krzysztof「one logical action」+ sashiko「骨架板 DT」+ VIN 父 supply 三处同向），只发 binding+driver，driver 修 sashiko 三条 Medium（`chip->enabled` 种子化 / `vsys` 使能 / `disable()` 写成功才提交）；板件存 `held-back/`。**顺带查实：v6 4/5 对声明的 base 不可 apply**（插入点写了 `sm8650-valve-deckard`，而 v7.3-rc7 无此行）⇒ 那一版 4/5 在干净树上必然失败；**★2026-11-07 增量复核 = `reports/upstream-delta-20261107.md`**：dwc3 v8 的两条 High（锁序撕裂 / err-path 与 unregister 同步）已被 sashiko 机器评审确认修复（`<sashiko-outbox-201358/201364@kernel.org>` "found no issues"）⇒ 无欠账；**wl2868c binding 欠 v9 两个技术点**（Rob Herring 11-06 14:10Z `<20261106141036.GA2921668-robh@kernel.org>`：多段 description 加 `>` 块修饰符；example 删固定 regulator provider），Conor 的 pw-bot `changes-requested` 是同两条的升级器（v8 投出早于 Rob 回信 28 min，时序竞态，v9 cover 说明即可）。**✅ v9 备料已完成（2026-11-07）**：`patches/upstream/wl2868c-v9-20261107/`（cover+1/2+2/2，2/2 与 v8 逐字节同）+ `README.md` 门禁账；判据 = `git am` 2/2 OK、`dt_binding_check` rc=0 无输出、`W=1` driver 编译 0 warning（54 288 B .o）、`checkpatch --strict` 0 error；**✅ 已投（2026-11-07T01:50Z，3 封全 250，cover `<20261107015014.22374-1-xiaqinghuan@mail.ustc.edu.cn>`，日志 `out/mail-20261107/send-wl2868c-v9.log`）**；patchwork（2026-11-07 现查）= `devicetree 1/2 needs-ack` + `arm-msm 2/2 new`，v8 两枚已随 v9 自动 `superseded` |**★2026-10-31 v5 已投递**（用户放行）：3 封 `Result: 250`，Message-ID `<20261031150154.1106455-1..3@mail.ustc.edu.cn>`（cover + 1/2 + 2/2，`In-Reply-To` 串到 cover）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行693-M3.md`⟫ | M1 | 每片过 `dtbs_check`（自带 binding）+ `dt-doc-validate` + `checkpatch --strict` |`reports/m3-series-plan-20261013.md`、`patches/upstream/m3-2026-10-13/`；**M3-1 v3（2026-10-19 C0）**： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行693-M3.md`⟫ |
| M4 | 大件立项：B8 camss（media）/ B6 ath12k PEACH（wifi）/ B3 hci_qca PERI（bt） |🟢 **M4-1（bindings）已投递并归档（2026-10-27，用户解冻投递）** —— 两线程：① **media 2 枚**（`gt9764` VCM + `s5kjns` 传感器，`[PATCH 0/2]`， ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行694-M4.md`⟫ |csid` 0 条、BUG/WARN 0），但 sashiko #4「多 RDI 累积位」**未被判别**；② 对照上游 **v6**（8/8 取到）与 **v23 Kaanapali**（10-28）： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行694-M4.md`⟫ | M1 | 各成多轮 review 工程 | `reports/m4-camss-project-20261013.md`、`reports/m3-6-wireless-slice-20261013.md` | **★2026-10-29 20:31 三枚通用修复已投递并归档**（用户批准）：`[PATCH 0/3] media: camss: three fixes for the CSID power and VFE streaming paths`，Message-ID `20261029123107.28705-1..4`，4 封 250、lore `/all/` 4/4 HTTP 200（封面 Subject/From 逐字核对）；门禁 = pristine `git am` 3/3 + checkpatch 3/3 0E0W0C + camss 目录 `W=1` 0 warning（`patches/upstream/m4-camss-fixes-20261029/GATES.md`、`SENT.md`）；**未上机**（2/3 改变缓冲校验行为）。 **★2026-10-31：v2 0/2 已投并归档**（用户批准）：`[PATCH v2 0/2] media: camss: CSID power-on unwind and VFE stream handling`，MID `20261031041154.308030-1..3`，3 封 250、lore 命中；**2/3 整枚撕除**（Bryan plane0 实测 5 处物理断裂/0 IOVA 断裂 + 判据错位 + `prepare_buffer` 死代码），**3/3 按 Loic 形状重构**（单 helper + `media_entity_remote_source_pad_unique` + `v4l2_subdev_*_streams`）；pristine `am` 2/2、camss 编译 rc=0、checkpatch 0E/0W/0C；报告 `reports/m4-camss-v2-20261031.md`。同日 patchwork 9 枚旧件标 `superseded`；Shuai Liu 的 icc 表 finding 已出 fix 素材 `patches/upstream/camss-icc-20261031/`（**归属 Hangxiang，不投递**，见 `reports/camss-icc-table-fix-20261031.md`）。 **★2026-11-13 相机路线改接上游 v6**：自建 9 补丁串停止后续版本（5 项被 Qualcomm v6 覆盖、 SOF/物理连续被 reviewer 否、0003 已作独立修复投递、0009 等 v6 合入后 rebase）；已从功能树撤掉「必须物理连续」（前摄出流 5 帧 rc=0 回归通过）；唯一硬分歧 = CSIPHY 2.3.0（v6 复用 kaanapali）vs 2.4.0（本机 vendor 表 103 条证据）。对账与下一步 = `reports/camss-v6-rebase-plan-20261113.md`。 **★2026-11-13 wl2868c v11 已发**（3 封 250，lore 逐字节通过）：按 datasheet Rev1.4 p.35 回答 Mark 的 LDOx_SEQ 问题——probe 清零 `0x0a..0x0d` 再播种 enable 集（板上实测全 0，清零为 no-op）；备料 `patches/upstream/wl2868c-v11-20261113/`。
| M5 | C2 dm-default-key 从上游包剥离 → 持久根 out-of-tree patchset | 🟡 **立项完成（2026-10-13）**：静态取证推翻本行原前提——`dm-default-key`（457 行）+ `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED` 兼容层**一直在 vendor 血统树**，但三份在用 `.config` 对 `DM_DEFAULT_KEY` 零命中 ⇒ **现状是树内死代码，剥离零运行时风险**；上游 7.3-rc7 自带替代品 **`dm-inlinecrypt`**（620 行、支持 hw-wrapped）⇒ 推荐 *能力用上游、patchset 封存*。需求判定与候选比较见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行654-M5.md`⟫ | — | 上游包内无 Android vendor ABI | 同上 §1-C |
| **M6** |**Q28 上游化 = B5 DSI per-SoC cfg 重构（含 E1b 1 行）+ 协作**​**★2026-11-02 已回 Dmitry 四条（承诺 v2 在 torvalds master 重切），见 §7 头 11-02 批次**​**★2026-10-31 已投递**（用户放行）： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ |BIT(9)` 并注释来历 + 厂商 `mask_error_intr()` 同形）。落地 `patches/local/b5-resoc-20261027/0005-dsi-name-fifo-error-bits.patch`（+24 −9），**等价证明 = `dsi_host.o` 的 `.text` 逐字节相同**（23 048 B / 23 048 B）， ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ |（2026-10-15 立项；定义 = `reports/upstream-q24-q28-standard-20261015.md` §2） |🟡 **≈35%**：**L1** ✅ **已投递（2026-10-19，用户解冻）** `<20261019130041.305805-1-xiaqinghuan@mail.ustc.edu.cn>`，`/linux-arm-msm/` 已归档；原件 `patches/upstream/m1-2026-10-14/0001`（机上已验 L1=0/L2=0 + 目视确认）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ | M1（M1 树）、上游四问答复 | ① P1–P3 对 Q28 **行为中性**且可机械验证（P2/P3 与 P4 分离 + 同会话交替采样）；② P4 有明确归属且改动后重跑 Q28 冷起风暴；③ L1 补丁达上游门（checkpatch `--strict` + `git am`）；④ 包内无 Q3 魔数与诊断钩子 | `reports/b5-dsi-resoc-20261013.md`、`reports/upstream-q24-q28-standard-20261015.md`、`archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md` |**★2026-10-27 RFC 备料完成（只备不发）**：`patches/upstream/m6-b5-p4-rfc-20261027/RFC-SCOPE.md` —— 核实出三条可引用的上游事实（bonded 支持只在时钟/PHY 层；`CMD_DMA_CTRL.BROADCAST_EN` 位**已存在于** `dsi.xml` 但驱动从不置位； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ |
| **M7** | **Q24 上游协作 + 外部测量**（2026-10-15 立项；定义 = 同上 §3） | 🟢 **2026-10-23 结论：不需要我方补丁** —— 根因 = 上游 `pmdomain: qcom: rpmhpd: Skip retention by default`（2026-06-29），**7.3 线已含、日常线自动免疫** ⇒ M7 从「缺陷」变成「结论」。剩余可选（非阻塞）：把 `debugfs/cmd-db` 的 retention dump + `vk149` 对照作为**数据**回 Konrad/Taniya；外部电流/电压测量已取消。旧进度存档见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行656-M7.md`⟫ | — | ① 根因可指名（哪条硬件/顺序约束被违反且有反证）或上游复现确认；② 驱动/DT 缺陷按正确层提交，硬件特性则上游文档化；③ `cam-mode.sh`/零相机 cmdline 等**策略件不进任何上游包** | `archive/topics/UPSTREAM-REPORT-cambist-q24-v3-2026-10-12.md`、`reports/upstream-q24-q28-standard-20261015.md`、`reports/q24-{mech,r9,noc}-20261012.md` |
| **M8** | **Q28 显示初始化（dispcc probe 复位 MDSS 块）—— ★2026-11-14 **v5 已投**（答 sashiko 的 0xa000 质疑，3/3 只收窄 message，4×250；见 §7 头 11-14 增量）—— ★2026-11-02 已投 `[PATCH v3 0/3]` 新线程（删长注释 + drop RSCC），见 §7 头 11-02 批次** |​**★2026-10-31 静态归属已定（总管复核）**：**「RSC/RSCC 不属于 MDSS 可复位域」成立**（上游 qcom dtsi `RSCC` 0 命中、mdss/dispcc `resets` 含 rscc 0 条、`sde_cesta` rscc reg `0xaf20000` 恰在 dispcc 窗口外）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行698-M8.md`⟫ |CORE_INT2|RSCC`（`lenovo,elden` 门控），RFC 里问了两件事（DT 属性 / 无条件在 dispcc 或 mdss / 交给 bootloader）并给出 DIGTOP 系列的独立佐证（PLL 锁修好但不改 command DMA 失败）。待办：盯 review（Konrad/Dmitry/Bjorn/clk 维护者）与是否需要非 RFC 版本（含 DT 属性）；草稿与说明 `patches/upstream/q28-dispcc-2026-10-22/` | — | 获 review 或明确落点后转为正式系列 |`patches/upstream/q28-dispcc-2026-10-22/README.md`、`reports/q28-disp-init-ab-20261022.md` **★2026-10-29 20:32： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行698-M8.md`⟫ |
| **M9** | **kexec：irqchip/gic-v3-its 认领继承的 LPI 表（DT）** — 2026-10-24 立项（Q11/K6 收口产物） | 🔴 **方案被否（2026-10-26，Marc Zyngier：nothing works at all）** ⇒ 撤回，或改「引导器预置 + DT memreserve」待用户裁决。旧记录：2026-10-24 曾投 `<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>`（`/lkml/` + `/linux-arm-kernel/` 已归档；投前 vk161 上机确认 0 超时），补丁把 `gic_check_reserved_range()` 拆成纯查询 + 认领助手，机械门 `checkpatch --strict` 0E/0W/0C。沿革与回信见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行658-M9.md`⟫ | —（不阻塞） | ① ~~投递~~ 已发；② 盯 review（Marc/Thomas），视反馈出 v2；③ 若进树则回填上游提交号 | `patches/upstream/m-gic-its-claim-20261024/README.md`、`reports/kexec-target-boots-20261024.md`、`TASKS/sessions/2026-10-24-kexec-its-lpi-claim.md` |
| **M10** | **SM8750 ADSP fastrpc `qcom,non-secure-domain`**（G1-34 在机真因，2026-11-07 立项并当日投出） | 🟡 **已投（2026-11-07T03:26Z，1 封 `Result: 250`，Message-ID `<20261107032646.32363-1-xiaqinghuan@mail.ustc.edu.cn>`）**：提交树里只有 `cdsp` 的 fastrpc 节点带该属性，`adsp` 没有 ⇒ 只生成 `/dev/fastrpc-adsp-secure`，`libssc`/`hexagonrpcd` 连不上 sensor PD（qrtr svc 400）、`iio-sensor-proxy` 三项全 false；加一行后 `vk185-adsp` 实测 `/dev/fastrpc-adsp` 在、SensorProxy accel/light/prox 全 true。发前按 §7 重基到 master `d48723711b`（`git am` 干净），门禁 = `CHECK_DTBS=y qcom/sm8750-mtp.dtb`（唯一 warning 在基线同样存在）+ `checkpatch --strict` 0E/0W/0C。**patchwork 已摄取（`2026-11-07T03:26 new`，投后约 1 h）**；自家 INBOX 已收到副本、无退信 | M10 | ① 维护者接受并进树；② 若要求与板件/消费者一起发，按 M 系列口径等复启条件，不单独 ping | `patches/upstream/sm8750-adsp-nonsecure-20261107/`（patch + README + SHA256SUMS）、`out/mail-20261107/send-adsp-nonsecure.log`、`DEVICE/README.md` §1.1 |
| **M9-收口** | ✅ **已撤回（2026-10-26，长期规划取舍）** —— Marc Zyngier 2026-10-24 12:39 +0100 `<87v76r8h0o.wl-maz@kernel.org>` 三点的原文要点（逐字核对自 INBOX，非二手转述）：①「***nothing* works at all** ... Everything is dead」，与 command queue 无关；②「What makes you think that EFI and DT are incompatible? 90% of my machines are DT based and yet boot with EFI」；③「**No.** This is way too late, and nothing guarantees that these are not already used for other purposes by the new kernel ... **Either it works always, or it doesn't at all.**」⇒ 正解 = 「configure the LPI tables from the bootloader, reserving them at boot time by sticking the reservation in the DT ... preserved along the whole of the kexec chain」。**我方决定 = 撤回整个系列**（不发 v2、不重做内核代领路径）；回信已投并复核（2026-10-26T11:41Z，Message-ID `<179301488974.13269.12823732532276833194@mail.ustc.edu.cn>`，`In-Reply-To` Marc 原件，正文 31 行纯 ASCII，Sent Items [151] 回读）。**长期归位**（不进内核）：kexec 链的「bootloader」= kexec loader 自己 ⇒ 以后若真需 kexec 后 LPI，修在 loader（把 memreserve 写进交接 FDT（不够就扩容 blob）+ 预置 LPI 表），内核侧不再动；当前 kexec 只当「不需显示/网络的调试快环」，需要 LPI 的场景直接全重启。 | ❌ | ✅ 回信已发 + Sent Items 回读；✅ `TASKS`/`reports/` 口径已改 | `out/mail-20261026/re-m9-withdraw.txt`、`archive/topics/upstream/upstream-status-20261026.md` §4 |

### ★ 2026-10-11 → 2026-10-14 的历史叙事已下沉（本节只留 M 系列台账）

- M1-7.3 首次上机 bringup（`73`–`73j` 单变量表 + 设备侧修复三条 + 深夜更正）、本轮其它交付（M3-6/M3-3/B5 预研、邮件列表订阅台账）、上游显示栈对照 P1–P2c、M1 7.3-rc7 树显示回归与 E1/E1b/E1g 定案、用户态上游（phoc/phosh）——**原文逐字**在 `sessions/2026-11-02-M系列历史叙事归档.md`。
- **口径**：M 系列的当前状态只读上面的 M1–M9 表（含各行的投递/评审状态）与 `reports/upstream-status-20261113.md`；上面那份归档只作沿革，不回写。
