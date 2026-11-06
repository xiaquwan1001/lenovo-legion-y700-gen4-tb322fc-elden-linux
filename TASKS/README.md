> 会话进度见本目录 `sessions/`；本文件为该角度策展 SSOT。
# 任务拆解与进度（TASKS）

> 本角度文件夹的策展 SSOT（`README.md`）；`sessions/` 存以会话为单位的进度。标准见 `INDEX.md` §2。
> **本文件是唯一任务台账**：所有 ID、状态、下一步只在这里维护；专题文档只放过程与证据。
> 纪律：worker 只报「命令 + 原始日志」，编排者**独立复跑**；每步留回退；设备锁串行、主机侧并行。

---

## 0. 进度总览（数字）

| 目标 | 已完成 | 进行中 | 未开始 | 完成度 |
|---|---|---|---|---|
| **G1** 完整 Linux + 上游化（驱动原厂固件 + 上游提交） | **33 项 / 在范围 35 项**（显示/图形/触屏/网络/**G1-36 WiFi 候选榜**/电源/相机出流+App 实测/音频播放+输入/温控/串口/CDSP/DP/BT 配对+TWS/**G1-8 基准**/**G1-23 vblank/PPM 残留复核（2026-10-26 三窗 47.5 min 全 0）**…）——**明细与证据只在 §1** | 0 项（WiFi Q26 已关闭，2026-10-10 用户确认）+ ✅ TF 卡 G1-6 **新卡已收口（3 轮 0 不一致 + fsck clean；旧卡废置，不再追）**——证据见 §1 G1-6 | 上游化 **M 系列**（状态/队列**只读 §7**）、G1-34 已收口（SSC 路线两棵根全绿；SLPI 原生 IIO 为后续可选线） | **33/35**（口径见下表注） |
| **G1 阻塞项速览**（**本行只列 ID**；状态/样本数/口径唯一权威 = §5 的 Q 行） | — | 🟢 **Q28/Q32 已结项（2026-10-24）=「已规避」**（运营线 vk152：0154/0155 + `dsi_bonded_cmd_failed` 闩锁清零 + `link_configured` 修复 + 开机看门狗 + 三态探针；线上真 POR 5/5、暖复位 3/3 = **8/8 无坏发**；**原定 ≥8 发 POR 门槛按用户裁决不再补 ⇒ 补采样项标记完成**；Q32 五发判据表已出：三个复位入口无差异、并入 Q28；复启条件与局限**只读 §5 Q28/Q32**）· ⛔ **Q24** 熄屏×相机（**2026-10-24 用户裁决：不值得取证 ⇒ 关闭**；根因已指名 = 7.2 血统缺上游 `skip retention by default`，7.3 线自带该修复 ⇒ 41 发 0 死亡 vs 7.2 的 6/8 死是**版本差不是随机**；日常线仅保留 `cam-mode.sh on/off` 互斥策略；**只读 §5 Q24**） | — | — |
| **G2** 安卓容器（可用性 + 风控/完整性等级） | **8**（注：Waydroid 图形/内核/GAPPS 镜像/代理通路/Win-x86 PoC 属 `C-历史` 聚合行，不计入 12 项分母；以下为分母内 12 项：**C4 传感器 HAL 路线 C**/**C7 切槽脚本**/**C6 容器音频**/**C2 GMS 登录（用户人工验证）**/**C10 马达透传（2026-10-13：桥 + 自编 AIDL V2 幅度/cancel + 固化进 vendor 镜像 + 强度档位 RRO）**/**C11 触屏中文输入法（2026-10-20：squeekboard + fcitx5/Rime + focusd 唤起/折叠）**） | 3（C3 待装 PI Checker 取三档回包；C5 剩 U7 App 实开预览；C8 书面结论已出、未立项） | 1（C9 打分表出数）；附 C5 的 ②b（容器识别到 1 个相机）2026-10-19 已达成、2026-10-23 修好 `/dev/video100` bind 持久化，只差 App 实开预览 | **8/12**（口径见下表注） |
| **G3** x86 模拟（Steam 载体） | 2（Box64 0.4.5 + Wine 9 PoC 成功；**官方 ARM64 Steam 客户端已起到登录界面**，2026-10-28 设备实测 3/3 轮 `SetLoginState: WaitingForCredentials - OK`、`steamwebhelper` 恒 7 进程存活 130–301 s、0 SIGSEGV、0 联网报错；**截图判据 2026-10-29 已可闭环**：当时失败真因是面板输出 `enabled=disabled`/`dpms=Off`（`grim` 报 `no supported format found`）；当前 `dpms=On` 下 **`grim` 一次成功出图**（`reports/artifacts/c5-u7-l1d-shot-20261029.png`），降级路径见 `reports/g3-steam-screenshot-paths-20261029.md`） | 1（x86 游戏端到端：FEX/box64 层待接，与「起客户端」已解耦） | Steam 游戏端到端（图形/音频/性能） | PoC ✅ / **Steam 登录界面 ✅（证据 `reports/g3-steam-20261028.md` §0b/§5–§8、`reports/artifacts/g3-steam-20261028/`）** |
| **拓展** UEFI 间接引导 · Gunyah VM | 1（**Gunyah 已终局裁决 2026-10-25 = 不做**，见 §4 N2 与 `reports/gunyah-decision-20261025.md`） | 1（**UEFI：路线 A 首轮 2026-10-05 失败后搁置 → 2026-11-01 用户放行恢复推进**；当前口径只读 §5 的 2026-11-06 块） | 0（UEFI 复启条件见 §4 N1；文本控制台考古计划 `reports/uefi-text-console-archaeology-plan-20261030.md`） | ⬜ 非主线（Gunyah 结项） |
| 运维/资产 |**2026-11-02 在机状态（★在机口径以 `DEVICE/README.md` §1.1 首条为准；本行只给指针，不再自己记快照）**：`boot_b` 分区 sha256 = **`fb55997c…`**（11-01 16:2x 能正常启动件， ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行19-运维资产.md`⟫ | wc -l`（实测 67，重建按 §5 Q24/Q28 配方） | — | — |✅ **2026-10-27 新增资产**：`scripts/host-net-proxy.sh`（Clash 只听 `127.0.0.1:7890` ⇒ 用 `systemd-socket-activate`+`socket-proxyd` 暴露 7897 给设备，幂等/`--check`； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行19-运维资产.md`⟫ |

> **注（口径 2026-11-03 机器化；手算推导已删，改为脚本现出）**：本表数字**一律由 §1 / §2 的行内状态标记导出**，不另设分母。
> **公式**：`完成 / 在范围`，其中 `在范围 = ID 总数 − ❌/⛔`，`完成 = ✅ + 🟢 + 🎯`；合并行（`| ✅ G1-12…21 |`）按区间展开计 10 项。
> **现查（唯一出口）**：`scripts/check-progress-counts.sh`（`--tsv` 机读 / `--selftest` 断言 33/35 与 8/12，漂了就 rc=1）。
> 现状：**G1 33/35**（37 ID − ❌2：`G1-10` 无 NFC 硬件、`G1-30` 与 G1-29 同路线；不含上游化 M 系列，以 §7 为准）、**G2 8/12**（`C-历史` 是 5 项聚合行、不进分母）。
> **词表（8 类）**：`✅` 完成 / `🟢` 已结项（已规避·已出分·已随根因结项）/ `🟡` 部分·进行中 / `🎯` 治本完成 / `🆕` 取证已做未收口 / `⛔` 搁置 / `❌` 取消 / `⬜` 未开始；`🟢`/`🎯` 计入完成，`🟡`/`🆕`/`⬜` 计入未完成。
> **改数字只改 §1/§2 的行内标记**：§0 上下表由脚本导出，勿手改（历史手算推导见 `sessions/2026-11-03-TASKS-§4-待办沿革.md` 前后版本）。

---

## 1. G1 任务分解（功能健全的 Linux + 原厂固件全部驱动）

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
| **G1-29** | **间接引导层（GRUB 类/UEFI）——摆脱 boot.img 96 MiB 限制** | 🟡 **进行中（2026-11-01 用户放行恢复推进；**当前口径只读 §5 的 2026-11-06 块**，四臂判别见 11-01/11-02 块）**。以下为首轮（2026-10-05）记录：⛔ 路线 A 上机失败 ⇒ 当时搁置。机制（lane `bootchain`）：四代 UEFI 被拆成 `uefi_a`/`imagefv_a`/`abl_a` 由 XBL 加载，ABL 不扫 FAT、无现成启动 FAT。**上机：本地编译链通、壳机制成立、能进 BDS，但 UFS 初始化过不去**（UFSDxe ASSERT / Sync Exception + SCM mailbox/QBSS/CPU_Vectors 缺失）⇒ Mu Pakala 移植层系统性缺口，非单点可解；已发上游 `mu_wide_platforms#12`，**上游已回复（2026-10-10）：固件版本相关，需 UFSDxe 专用补丁**（非缺 config；见 archive/topics/UEFI-UFS-UPSTREAM-ASK-2026-10-05.md §回复）。**96 MiB 限制已被 G1-30/vk61 实际解决 ⇒ UEFI 不构成主线依赖**｜**2026-11-04 状态更新：载荷已真被执行并跑到 DXE**（v2 base 0 + Image 头对齐；屏上串口打出 Mu 版本行 + PrePi `[P01]`–`[P11]`）⇒ 当前卡点从「能不能跑起来」变成「DXE dispatch/UFS」，再收敛到 **`BootLinux()` 内 `MarkPtnActive()` 附近**（2026-11-06：另定案崩溃元凶之一是**帧缓冲控制台写穿**，探针通道改为 `sbprobe=3`；**同日下午更正：34→27 窗口里那条 R15 诊断写也没纳入开关 ⇒ 「`MarkPtnActive` 崩」不是唯一解释**）；**当前口径与下一步只读 §5 的 2026-11-06（傍晚）块** | U2（只读） | 出现 GRUB/BDS 菜单 + `root=LABEL=linux17` | `archive/topics/BOOTCHAIN-2026-10-05.md`、`UEFI-UFS-BRINGUP-2026-10-05.md`、`UEFI-UFS-UPSTREAM-ASK-2026-10-05.md`、`TASKS §5 Q25` **★2026-10-28 复现件重制（纯主机，未上机）**：E0/E1 两件已构建并逐个记录 sha256（E0 `987bcde9…` 2 441 216 B / E1 `1ae201c2…` 2 445 312 B，E1 取件 sha 与派工单逐字节一致）；**BootShim 判定 = 不含 `dc civac`**（`d50b7e25` 0 命中，`_Start…_Dead` 12 条指令无 cache 维护）；**E2 tiny DXE 不需要**（dodge 二进制已覆盖 sleep→wakeup），自写最小 ~120 行但**写错 UFS UIC 寄存器可致链路不可恢复**；**对旧配方的更正**：`~/ext-repos/mu` **不能**构建 Y700g4（Mu-Silicium 主仓无 `Platforms/PakalaPkg/Device/`），实际用 `build/uefi-woa-prep/repos/7-mu-lenovo`（`mu_wide_platforms@6b6ac42a` + `build_cfg/sm8750.json`）。报告 `reports/uefi-visibility-rebuild-20261028.md`；同芯片平板亮屏回挖见 `reports/uefi-samechip-tablet-display-20261028.md`；引导方案横评 `reports/bootloader-alternatives-survey-20261030.md`、issue #12 回帖见 `reports/uefi-issue12-reply-draft-20261028.md`；E1-v0b 上板记录 `reports/uefi-n2-v0b-onboard-20261030.md` |
| **G1-30** | **boot.img 立即瘦身（=G1-29 路线 C）** | ❌ **口径更正（2026-10-06）**：slim 能打到 20.8 MiB，但 **vk60 实机=进桌面、外设全不可用**——**归因 = initramfs 打包（最小 initramfs 无 `/lib/firmware`），不是驱动/内核**（`PITFALLS` #113/#115、`archive/topics/ATTRIBUTION-AUDIT-2026-10-06.md`）⇒ **slim 不作日常启动**。boot_b 替换版改走 **vk61**=原完整 ramdisk 只换修好的 `/init`（内核/固件/模块零回归，83.3 MB < 96 MiB，已零写盘验收）。真机 busybox **有 findfs、无 blkid/mountpoint**（#112） | U2 | —（slim 不用于日常启动） | `archive/topics/BOOTSLIM-2026-10-05.md`、`INIT-HARDEN-2026-10-06.md` §9–§11、`out/boot-elden-vk61.img` |
| **G1-31** | **GNU 用户态工具补装**（AI 调试高频失效率） | ✅ **已完成（2026-10-06 U2）**：`coreutils findutils grep sed gawk procps-ng curl wget jq rsync socat tcpdump zstd xz tree less`（735→760 包，world 104→120 行）。设备无默认路由 ⇒ 借**主机代理** `http://192.168.7.2:7897`。**重启回归 ×2 通过**（GNU 会 shadow busybox，含 init 同 PATH）。 | 任一 mainline | `sed/grep/find/sort/awk/curl/jq --version`、`ps -p 1`、`date -d '1 hour ago'` 全 rc=0 | `.pi/plans/2026-10-06-用户态查漏补缺.md` P1、`PITFALLS` #120/#121/#122、`rootfs/build-rootfs.sh` |
| **G1-32** | **OpenRC 化（init 交接，替代自研服务编排）** | ✅ **已完成（2026-10-06 U2）**：Alpine OpenRC 已装但 `runlevels` 空 ⇒ `/init` 保生命线（usb0/sshd/ttyGS0）后按 `/etc/elden-init-mode` `exec /sbin/init` → inittab → openrc。**PID1=`/sbin/init`**；`rc-status default` 全 `started`；**G1-25 关机链结构性修复**（干净 `loginctl reboot` 实测通过，wrapper 按模式选 `-f`）。回退 `echo legacy >/etc/elden-init-mode; reboot`。 | 任一 mainline | `rc-status` default 全 started + `ps -p 1` = `/sbin/init` + `loginctl reboot` 干净重启 | `scripts/openrc-enable.sh`、`initramfs/init`、`scripts/fix-logind-poweroff.sh`、`rootfs/persistent-overlay/` |
| **G1-33** | **相机 × 熄屏共存（Q24 修复）** | 🟢 **已随根因指名而结项（2026-10-23）**：修复 = 上游 `skip retention by default`（7.3 线已含）；**7.3 日常线不需要本地补丁**，DT/驱动侧不再需要任何变体。**与 G1-22 同一条 bug（历史双 ID，非两个任务）**，状态/样本/口径**只在 G1-22 行与本文件 §5 Q24 维护**，本行只保留交付面：DT/驱动侧变体（H1 去 power-domains 7/9、H2 单挂 MX、D1 `use_rpm=false` 6/9、D2 去 `critical_cbcrs` 7/9）均未根治；E4a/FIX-3/FIX-2 的 2026-10-10 上机判定**已作废**（测的是 `olddefconfig` 删掉 `ARCH_QCOM` 的死内核，`PITFALLS` #162） | 任一 mainline | 相机常驻 + 装 cambist 后长时空闲不断电 | `patches/`、`out/boot-elden-vk63.img`（历史）、`PITFALLS` #162/#177 |
| **G1-34** | **加速度计/重力传感器（SSC/QRTR 路线上线；SLPI 原生 IIO 为后续可选线）** |✅ **已修好并上机验证（2026-10-30）**：根因是「**修复从未进镜像**」—— `fastrpc.c:2599` 用 `qcom,non-secure-domain` 决定建不建非安全域实例，而该属性只存在于 `build/vk151` 的未提交工作区 ⇒ 在机 vk172 的 DTB 早于它 ⇒ 只建 `fastrpc-adsp-secure`。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行55-G1-34.md`⟫ | Alpine 根 + Debian 根 | `net.hadess.SensorProxy` accel/light/prox 全 true（两棵根） | `PITFALLS` #442/#443（`PITFALLS/sessions/107-*`）、`reports/debian-root-accounts-sensors-20261026.md` |
| **G1-35** | **设备网络自愈（HTTPS 信任链 + PMTU）** | ✅ **信任链已修复并冷启动验证（2026-10-18）**：8 个 `/etc` 配置被清成 **0 字节**，`/etc/ca-certificates.conf` 空 ⇒ `update-ca-certificates` 每次写出 **0 字节** bundle（rc=0 静默成功）⇒ **所有 HTTPS 立即失败**（`curl: (77) error adding trust anchors` / git reset / apk 校验失败）。**`apk fix ca-certificates` 修不了**（把 0 字节活文件当"用户改动"，只再写 `.apk-new`，实测两次无效）⇒ 显式 `mv *.apk-new → 活文件`，无 `.apk-new` 时从 `mozilla/*.crt` 重建 conf。修后 bundle 181724 字节/121 证书，curl 全 200。 🟡 **PMTU 黑洞已缓解未根治**：手机热点广播 MTU 1500、上游实际 **1400** 且无 ICMP frag-needed；OpenSSL 3.5 默认后量子曲线 `X25519MLKEM768` 把 ClientHello 撑到 **1423 字节**必然拆段 ⇒ 抓包见「满 MSS 首段被丢 + 服务端 `ack 1` 回退 + SACK 只认尾段 ⇒ 无限重传死锁」；同 MTU 下 MLKEM 80% vs `X25519` 98%（各 40 次）⇒ 仅 `gitlab.freedesktop.org`/`gnome`（Fastly 段）受影响，国内站 0 失败。已落地 `wlan0 mtu 1400` + `power_save off`，git 失败 35%→~10%。自愈脚本 `scripts/net-selfheal.sh`（幂等，`--check` 只报告），触发 = OpenRC `local`（等 wlan0 UP）+ `NM dispatcher.d`，**冷启动注故障态验证通过**。证据 `reports/net-https-mtu-rootcause-20261018.md`、`PITFALLS §49 #340–#342` | 任一 mainline | `net-selfheal.sh --check` rc=0；冷重启后 mtu=1400、conf/bundle 非空、curl 200；git fd.o 失败率 <15% | `scripts/net-selfheal.sh`、`rootfs/persistent-overlay/{etc-local.d,etc-NM-dispatcher,usr-local-sbin}.tar.gz`、`PITFALLS/sessions/49-设备网络HTTPS全废与PMTU黑洞.md` |
| **G1-36** | **WiFi 可用候选榜不刷新（连通态只剩已连接项）** | ✅ **根因已定并修复（2026-10-19 U2 vk127）**：不是 ath12k/固件问题——NM 1.52.2 在 ACTIVATED 时 **禁止自己做周期扫描**（`_scan_notify_allowed()` → `periodic_allowed=FALSE`），把复扫交给 supplicant 的 `bgscan`，而 NM 把该串**写死**为 `simple:30:-70:86400`（`nm_supplicant_config_add_bgscan()`；连接级 `802-11-wireless.bgscan` 在 1.52 里**不被读取**）⇒ 信号好于 -70 dBm 时 = 24 h 才扫 ⇒ supplicant BSS 缓存按 age(180 s) 过期被清 ⇒ NM 删 AP 对象 ⇒ 候选榜只剩当前连接项。**实测**：NM 重启后仅 1 次连接期扫描，120 s 内 0 次扫描事件，AP **35 → 1**；`nmcli dev wifi rescan` 后 **1 → 24**（12 s）——与用户「关开一次即恢复」完全一致。**修复** = `wifi-scan-refresh` OpenRC 服务：连通态每 **150 s** 显式 RequestScan（间隔必须 < `bss_expiration_age` 180 s；全信道 110 信道 5.6–8.4 s ≈ 4–6% 占空比），未连接时跳过（NM 自扫 ≤120 s）。**上机验证**：服务存活 470 s、扫描按 +0/+150 s 节奏、aps 24→27→26→22→26→28 不再塌；断开后 `--once` 正确跳过 | 任一 mainline | 连通态每 ~150 s 有 `scan started`；`nmcli dev wifi list --rescan no` 的 BSSID 数不跌到 1；`wifi-scan-refresh.sh --check` rc=0 | `scripts/wifi-scan-refresh.sh`、`rootfs/persistent-overlay/etc-initd-wifi-scan-refresh`、`etc-conf.d-wifi-scan-refresh`、`reports/wifi-scan-stale-20261019.md`、`PITFALLS §52 #354–#356` |
| **G1-4** | **音频可听（播放+输入）** | ✅ **播放 2026-10-04 实测听声**：根因=tplg MI2S **SD 线错**（SD0→SD1，`PITFALLS` #90）；PipeWire+UCM2 桌面链路 ✅。**输入 ✅ 2026-10-04**：本机麦克风=**模拟麦接 WCD939x**（非 DMIC）；WCD939x bring-up（DTS codec+swr1/2+TX3、去 VA DMIC）+采集 DAPM 控件 → `arecord -D default` 出数据并持久化 UCM2 `Mic`。**R3 裸 ALSA**：`scripts/audio-alsa-init.sh` 幂等设路由，无桌面 `aplay/arecord -D default` 开箱可用（增益 400）。R1 有线耳麦：代码就绪、**硬件缺失（无 3.5mm/转接头）冻结**；FSA4480（非 `wcd_usbss`）需编 built-in。R2 双麦=AMIC1+AMIC4（未做，低价值） | 任一 mainline | 扬声器出声 ✅；`arecord`/`aplay -D default` rc=0 ✅ | `archive/topics/AUDIO-SDLINE-2026-10-04.md`、`WCD939X-2026-10-04.md`、`HEADSET-HW-2026-10-04.md`、`MIC-ARRAY-2026-10-04.md`、`patches/0011`、`scripts/audio-alsa-init.sh` |
| **G1-5** | **相机出流** | ✅ **出流 + AE + 相机 App 出图全部达成（2026-10-18 在机 vk127 / 7.3-rc7）**：后摄 `s5kjns` **30.06 fps / 4072×3072 满帧**、前摄 `gc08a8` **30.26 fps / 3264×2448 满帧**，dmesg 零 `camss/vfe/EPIPE/EINVAL`；AE 收敛后**后摄 115.2 / 前摄 133.5**（RGB mean 均正常）。三个 AE 独立 bug 已修：`exposureTarget` 有不可达下限、`gainMinStep` 被整数除法截断、helper 增益语义必须与驱动一致（identity）。**⚠ 已推翻两条旧结论**：「软 ISP 只写第 0 帧」、「libcrypto 构建致黑帧」——后者两臂同配方对照证明无因果。详见 `PITFALLS` #320–#330、`reports/camera-linux-vk127-20261018-agc-rootcause.md`、过程叙事 `reports/tasks-narrative-archive-20261019.md` | 任一 mainline | `cam`/`libcamerasrc` 出真实画面；Snapshot 预览+录像朝向正 | `patches/libcamera-ae-totalfix-20261018/`、`logs/cam-bright-20261018/`；**闪光灯（2026-10-19 核实）：PM8550 `rear_flash` 驱动/DT 已就位（`white:flash` + `/dev/v4l-subdev30`，torch/strobe 寄存器级实测），硬件只有一颗后摄 LED、无独立前摄闪光灯；剩余缺口 = libcamera 不认 `MEDIA_ENT_F_FLASH`（`cam` 无闪光灯控制）+ flash LED NTC 温度监控（`patches/0013-flash-led-ntc-thermal.patch` 提案未上机）→ `reports/front-camera-flash-20261019.md`** |
| **G1-6** | TF 卡写稳定性 | 🟡 **新卡有条件收口（2026-10-26 复测，判据一次跑完）**：新卡 `mmcblk0` **CBADS 58.6 GiB / 03\/2022 / CID `6f0303434241445310aa000e02016300`** ⇒ `mkfs.ext4 -L tftest` 后 `tf-stress.sh --fsck -r 3`（small=2000×4K、large=64×1M）= **不一致 0**、`err_stats` **15 项全 0**、`e2fsck -fn` **clean**；ios = **37.5 MHz / 4-bit / SD_HS / 3.3 V**（与「level-shifter 只封顶 SD_HS」旧结论逐字一致）。**判据「≥3 轮 0 不一致 + fsck clean」已满足 ⇒ 收口（新卡）**。**旧卡已废置（用户 2026-10-26 明确）**，不再做旧卡 A/B，也不再按候选补丁做方向选择；`-d`(O_DIRECT)/加倍样本列为**不追**（仅当再出现新坏卡时重开）。2026-10-09「用户裁决搁置」**解除**。证据 `reports/tf-g16-retest-20261026.md`、`reports/trials/20261026T070115Z-tf-g16-card2-3r.json`。历史：历史状态：根因倾向卡本身 70–80%（2026-10-04 子代理）**：尺寸相关性（64MB 大块全对 / 8MB 小写间歇丢）、`err_stats` 全 0、`e2fsck` 前后一致、已是最保守 3.3V/SD_HS 档仍坏。**关键更正**：厂商 `qcom,uses_level_shifter` 唯一作用=SD_HS 封顶 37.5MHz，主线 `max-sd-hs-hz=<37500000>` 已等价 ⇒ 无效移植。5 个候选补丁（`patches/candidate-tf-*.patch`，按代价排序）+ 压测脚本 `scripts/tf-stress.sh` 就绪。**新卡已装入并复测通过（2026-10-26，见本条首段）；旧卡废置** | 任一 | 新卡连续 ≥3 轮 0 不一致 + `e2fsck -fn` 干净 | `archive/topics/TF卡-2026-10-04-subagent.md`、`scripts/tf-stress.sh` |
| G1-7 | BT 配对收口 | ✅ **已完成（用户 2026-10-06 实测：配对成功、TWS 实听可用）**。历史排查（保留备查、不再阻塞）：表象是 BR/EDR 高延迟而非「配对后断」；IBS 握手（H3）与固件深睡（H4）已排除，剩 H1(8 Mbps)/H2(CTS) 需单变量内核；4 个候选补丁 + `scripts/bt-link-test.sh` 备查。逐轮假设与 A/B 数字见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行056-G1-7.md`⟫ | 任一 | ✅ 用户实测配对 + TWS 可用（RTT 优化项可选） | `archive/topics/BT-2026-10-04-subagent.md`、`scripts/bt-link-test.sh` |
| G1-8 | CPU/GPU 基准（脚本已备） | 🟢 **已出分（2026-10-11 U2 vk64）**：Vulkan `vkmark` ~25532（3 轮）、GLES `es2gears` ~164 FPS（=165 Hz vsync 上限）、`sysbench cpu` ~19637 ev/s、`mem` 4129 MiB/s、`fio` 读 4024 MiB/s、温控峰 **81.9 °C（<82）**。**GL vs Vulkan 公平对比未完成**（Alpine 无 `glmark2`，GLES 数=vsync 上限）；渲染观察到「物体挤左上角」（疑显示缩放，另查，非阻塞） | 任一 mainline | `bench-run.sh` 出分 ✅；温控不破 82 °C ✅ | `archive/topics/BENCH-2026-10-11.md`、`logs/bench-20261011/`⚠️MIGRATION-LOST(日志未随迁)、`scripts/bench-run.sh`、`scripts/bench-install.sh` |
| G1-9 | DP 输出（解锁 `mdss_dp0`） | ✅ **已打通（2026-10-07，dp5 载具零写盘 + 用户实机目视确认出画面）**。**根因链（三步定位，此前误判「ADSP UCSI 未起」）**：① `PPM init failed, stop trying` 实为 `ucsi_init` **EPROBE_DEFER 重试 20 次放弃**（`failed to reset PPM` 从未打印 ⇒ ADSP UCSI PPM 本身通）；② defer 源 = `fwnode_usb_role_switch_get` ⇒ role switch 未注册 ⇒ **`dwc3_drd_init` 仅在 `dr_mode=otg` 时跑**，本机 DTS 写死 `peripheral`；③ otg 又被 `/delete-property/ usb-role-switch` 强制回 peripheral（GHWPARAMS0=DRD，硬件支持双角色）。**修复 = `dr_mode=otg` + `usb-role-switch` + `mdss_dp0 okay` 三处 DTS 同批**（内核提交 `6c1376907`）。dp5 实机：`card0-DP-1` connected+enabled+dpms=On、EDID `F27G32Q Pro` 2560×1440@180 preferred、`typec/port0-partner` 出现、vblank=0、DSI 同亮、Phosh 正常、外接实测出画面。**残余（非阻塞）**：放缩/横竖屏显示尚有问题（桌面侧，非物理链路） | 任一 | `/sys/class/drm/card0-DP-1` connected + 外接出画面 ✅ | `archive/topics/DP-2026-10-06.md`、`PITFALLS` #128、`out/boot-elden-dp5.img`（sha `096470c3…`） |
| G1-10 | ~~NFC compatible 修正~~ **取消：本机无 NFC 硬件（2026-10-06 取证）** | ❌ **不成立**：TB322FC vendor **无 `android.hardware.nfc.xml`**（feature 未声明）、vintf manifest 无 NFC HAL、`/lib64(/hw)` 无 NFC HAL 库、`/firmware` 无 NFC 固件、原厂运行服务无 NFC；GSMArena `NFC: No`。`elden.dts` 的 `st21nfc` 是**总线 `disabled` 的共用模板**，`stm_nfc_i2c.ko`/`st54spi_gpio` 多 SKU 共用；`ro.nfc.port=I2C` 为通用属性。**vk53 的 `&i2c0` 使能反而致硬关机（#108），已从驱动批次移除** | — | — | `PITFALLS` #108 |
| G1-11 | CDSP 启用（可选加分） | ✅ **已启用（2026-10-07 实机）**：`remoteproc1(cdsp) state=running`、`fw=qcom/sm8750/cdsp.mdt`，dmesg `remote processor cdsp is now up`（1.40 s）。**根因=固件变体+载具，非 PAS id**：① 原 DTS 用非 stock 单文件 `cdsp.mbn`/`cdsp_dtb.mbn`，单文件 `cdsp_dtb.mbn` 被 TZ PAS init 拒（`-22`）；stock SunP DTS 用 **split** `cdsp.mdt`/`cdsp_dtb.mdt`（DTS 已改，内核提交 `c132a1bc7`）。② **固件由 initramfs 加载**（switch_root 前 ~1.16 s），磁盘 rootfs 副本不生效 ⇒ split 必须打进 ramdisk（`build-initramfs.sh full` 已加注入）。**「PAS id 不匹配」假设否证**：反汇编 stock `qcom_q6v5_pas.ko` 的 `sun_cdsp_resource` = pas_id **18** / dtb_pas_id **0x25**，与主线 `sm8650_cdsp_resource` 完全一致。**boot_b 已持久化**（2026-10-07 刷入 `out/boot-elden-cdsp-vk47clean.img`（vk47clean 内核 + 模块一致），读回 sha 校验通过；`findmnt /`=`/dev/sda17`、cdsp `running`） | 任一 | `/sys/class/remoteproc/remoteproc1` running ✅ | `archive/topics/CDSP-FIX-2026-10-07.md`、`CDSP-PROBE-2026-10-06.md`、`PITFALLS` #127 |
| ✅ G1-12…21 | 显示 165 Hz、图形 A830、触屏、WiFi、BT 基础、充电+旁路、温控分级、带外串口、启动 ~5 s、触觉 | **已完成** | — | 见 `../DEVICE/README.md` §1.3 | `PANEL-REFRESH`/`THERMAL`/`CHARGE`/`OOB-CONSOLE` |

---

## 2. G2 任务分解（**前提：不依赖 Android**，参考社区资源做 ARM Linux 侧安卓兼容）

> 路线定义见 `README.md §6`。ID 前缀 `C`（compat）。

| ID | 任务 | 状态 | 层 | 验收 | 备注 |
|---|---|---|---|---|---|
| **C0** | **真 Android 对照取证**（趁单元还是 stock，**覆盖 a 槽前必做，不可复得**） | 🟢 **已采（2026-10-11，U2 `HA2EXB0E` a 槽 stock）**：`backup/HA2EXB0E-16+512/c0-baseline/`（22 文件 + SHA256SUMS）。要点：**Android 16 / build `ZUXOS_1.5.10.259_260611` / Widevine `L1` / HDCP 2.3 / BL 解锁 `orange` / 未 root / Google 账号 0 / 42 传感器 / AVF apex 在**。采集器 `scripts/c0-android-evidence.sh`（本轮修了容量档解析 bug）。U1 a 槽（stock+root）**可另采**（脚本历史文字针对 U1）；**root 专属项已判定无产出、不补采**（2026-10-13） | 基线 | `getprop` 全量 ✅、Widevine 级别 ✅、传感器清单 ✅、分区/包清单 ✅；**30 s 传感器 CSV + 5 App 录屏仍需人工**（真机账号未登录、未 root）；**PI 不在此列**（判定对象 = 容器 → C3 行） | 报告 `reports/c0-android-baseline-20261011.md`；见 `README.md §5` Q5 |
| **C1** | Waydroid 在 vk40 端到端复跑（去掉旧的 bind-mount 路由 workaround） | 🎯 **治本完成（2026-10-11，vk103 实机）**：根因 = 内核缺 **`CONFIG_IPV6_MULTIPLE_TABLES`**（+ IPv4 多路由表）⇒ netd `RouteController` 起不来；补上后**无 workaround** 即 `curl baidu=200`。2026-10-13 `vk126-c1` 在日常镜像口径复现判据；2026-10-19 vk127 复核「容器重启后 ~20 s 自愈出网」。历史（bridge 模块、vk95 半修）见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行072-C1.md`⟫ | 容器 | ✅ 无 workaround 出网（`curl baidu=200`，netd 自建 table 1002） | `reports/wd-netd-route-20261011.md`、`reports/c1-iprule-vk95-20261011.md`、`reports/wd-net-baseline-20261011.md`、`PITFALLS #184/#194` |
| C2 | Play / GMS 登录收口（旧结论：卡在外部上行与代理） | ✅ **已完成（2026-10-11，用户人工验证 GMS 服务可用、Google 登录成功）**。通路：容器经**宿主 Clash 代理**出网——容器内 `curl -x http://192.168.7.9:7897 https://www.google.com`=**302**、`https://github.com`=**200**（`192.168.7.9`=x86 主机 USB 链路 IP，宿主 Clash 监听 `0.0.0.0:7897`）⇒ 已设容器 Android 全局代理 `settings put global http_proxy 192.168.7.9:7897`。**★2026-10-27 前提变化**：主机 Clash 现在只听 `127.0.0.1:7890`（不再 `0.0.0.0:7897`）⇒ 设备侧必须先在主机跑 `scripts/host-net-proxy.sh`（`systemd-socket-activate`+`socket-proxyd` 暴露 7897，幂等、`--check`），否则容器 `http_proxy` 是死的（本轮容器里原值甚至是 `null`）。⚠ 在**平板本地**跑同订阅代理走不通（校园 wlan 到境外节点 `nc` 直连 fail）；容器走宿主代理可行。 | 容器 | Play Store 登录成功 + GMS 服务可用 ✅（人工） | `reports/wd-net-baseline-20261011.md`、`reports/wd-netd-route-20261011.md`、`archive/topics/PROXY-WAYDROID-2026-10-02.md` |
| C3 | **身份兼容性取证**（GMS/Play Integrity/Widevine 能做到哪一级）——**不预设结论** | 🆕 **本机取证已做（2026-10-13，`reports/c3-identity-drm-20261013.md`）**：**GMS 已登录**（`xuqianhui176@gmail.com`，GMS 26.37.37 / Play 53.4.34）+ **Google 连通**（`gstatic/generate_204`=204，经容器代理 `192.168.7.9:7897`）；**Widevine 不存在**（`/vendor/lib64/mediadrm/` 仅 `libdrmclearkeyplugin.so`，全 `/vendor`+`/system` 无 `*wv*`/`*widevine*`，DRM HAL 仅 `drm-service-lazy.clearkey`）⇒ **L3 路径不可用**；build = `userdebug`+**`test-keys`**（Waydroid fingerprint，非 Google 认证）⇒ PI device integrity 前置不满足；**PI/SafetyNet 回包待装检测 App**。剩余：装 PI Checker 取三档回包（需取 APK，等用户确认）+ 按社区三做法各变一变量复现 | 容器 | 出「社区先例 × 本机实测」对照表 + 回填 `README.md §6` §1 的 C2 格 | 先例：redroid / waydroid_script `certified` / WayDroid-ATV（arm64 GAPPS 有、L3 仅 x86-64；arm64 仅 A11 有、A13 无） / PlayIntegrityFork；**实测需设备+上行** |
| **C4** | **传感器注入原型**（~~uinput + UDP~~ **作废**→ **UDP HAL 真实现**） |✅ **已打通（2026-10-11，路线 C）**：宿主 gbinder 注入 daemon（`patches-userland/waydroid-sensord-udp/` = 上游 `service.cpp`/`Sensors.cpp` 原样 + 自写 UDP 版 `SensorFW`）装到 `/usr/local/bin/waydroid-sensord`； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行80-C4.md`⟫ | HAL | ✅ `dumpsys sensorservice` 列 6 个传感器且 running；数据流实测；自动旋转监听已连接 |`archive/topics/C4-SENSORS-2026-10-11.md`、`PITFALLS #185`、`out/sensord/android.hardware.sensors@1.0-service.waydroid`、`reports/research-waydroid-sensors-hal-20261011.md`（上游路线实测： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行80-C4.md`⟫ |
| C5 | 相机共享（`v4l2loopback` + sampler → 容器） | 🟡 **②b 已达成（2026-10-19）**：容器 `dumpsys media.camera` → **`Number of camera devices: 1`**（`Device 0 maps to "200"`, Facing Front），`camera-provider-2-4-ext` 状态由 `restarting`（crash-loop）转为 **`running` 稳定**，端到端真帧 **10 帧 / Y mean 107**。根因 = **四层独立缺陷**：容器 `IBinder` 比 AOSP 多一虚函数致 Bn vtable 错位、自编 `.so` 模板实例抢占平台 WEAK 符号、自生成 `android.hidl.manager.*` 盖掉平台实现、64 位 `kDevicePrefixLen` 用 `sizeof(ptr)` 导致设备号恒 0。**剩余 = U7（App 预览 / 前后摄切换）+ C3 身份/DRM 实测**。**★2026-10-27（U7 推进）**：宿主链路改 `gst → fdsink |v4l2-ctl --stream-out-mmap=8`（写端控 buffer 数，stock v4l2loopback、零补丁；`gst v4l2sink` 默认只申请 3 个，会被设备级共享队列压到 3 ⇒ `REQBUFS expected 4, got 3`）；源格式必须 **NV12**、`exclusive_caps=1`。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行81-C5.md`⟫ | 容器 | 容器内相机出预览 | `scripts/waydroid-camera-bake.sh`、`patches/waydroid-camera-64bit-20261018/` **★2026-10-23 收尾复核：`Number of camera devices` 曾回落 0 —— 根因不是 provider，而是 `config_nodes` 里**从来没有 `/dev/video100` 的 bind**（2026-10-19 那次成功是会话内手工绑的，重启即丢）。已写入持久配置（`lxc.mount.entry = /dev/video100 ...`，`optional`）⇒ 重启后复现 **1 个设备**（`Device 0 maps to "200"`）。**前后摄语义已定**：external HAL 只有 1 个 external 设备，"切换" = 换 loopback 生产者（`cam-loopback.sh start front|rear`），两路均出帧（前 Y mean 51.6→54.3、后 19.6）。顺带修掉 `cam-loopback.sh start` 的**100% 假阳性拒启动**（旧判据命中内核线程 `[disp_snapshot]`）；坑见 `PITFALLS #373`。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行81-C5.md`⟫ |**★2026-10-28 第二轮（推翻上一版结论）**：`metadata is null` 是**关闭路径噪声**（static metadata 实为满 55 项）；真卡点两级 —— ① HAL **只在 MJPEG 源**下广告 JPEG(BLOB)（NV12 源只有 2 条 YUV 流，格式 33 缺席 ⇒ OpenCamera `no picture sizes` 即退出）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行81-C5.md`⟫ |
| C6 | 音频通路打通后的容器音频（PipeWire） | ✅ **闹钟已出声 + 开机持久（2026-10-11）**：输出链路本就通；无声 = **四层**容器/镜像缺陷叠加（vendor manifest 声明了无服务的 `media.omx` / internal 卷未扫描 + `alarm_alert=null` / `ccodec=0` 且只有 `OMX.google.*` / 容器无 `/dev/dma_heap`）。四层修完 codec=**53**、闹钟解码出声；构建侧已固化进 `m vendorimage`。逐层机制与命令见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行077-C6.md`⟫ | 容器 | 容器内播放有声 ✅；延迟与录音单独记 | `reports/container-audio-20261011.md`、`tools/wd-audio-test/`⚠️MIGRATION-LOST(工具未随迁) |
| C7 | `scripts/slot-switch.sh` 一键切槽 + 槽属性自检 | ✅ **已完成（2026-10-11）**：`status`/`a`/`b [--reboot]` 全路径；b 槽回 Linux 自动 `qbootctl -m b`（防 PITFALLS #181 扣 retry）；2026-10-11 复核 `status` 在 Linux 侧正常打印槽属性 | 双槽保险 | 两条命令完成往返切换 ✅ | 即便 a 槽可弃，也要保留回退手段 |
| C8 | **无 Android 的 VM 路线调研**（Gunyah guest on mainline / crosvm+`--parallel_vcpus`；KVM 已确认不可行） | 🟡 **书面结论已出（2026-10-02）**：维持低优先不立项——① 设备侧 KVM 不可达（XBL 锁 hyp，`-el2.dtb` overlay 只适用 dev kit）；② 独立 gunyah 驱动未进主线（本地 7.2 树无 `drivers/virt/gunyah`）；③ 唯一新路线=KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，配 `qemu-for-gunyah`，WIP） | VM | ✅ **探测已做（2026-10-10、boot_b/vk64）**：`dmesg` 仅见 reserved-memory `gunyah-hyp@80000000`（14 MiB 保留区），**无 `gh_rm`/gunyah 驱动**（本地 7.2 树无 `drivers/virt/gunyah`）⇒ 本树路线第一步不成立 ⇒ **按书面结论归档、维持低优先不立项**（若将来上带 gunyah 驱动的内核再探）**★2026-10-24 阶段 0/0b 实测阳性**（`reports/gunyah-stage0-positive-20261024.md`）：`ls /sys/bus/platform/devices` 有 **`gunyah-wdt`**（= `qcom_scm` 的 SMCCC UUID 询问命中 ⇒ 本机确实运行在 Gunyah guest 里），且自编 `gunyah_wdt.ko` probe 通过（`GUNYAH_WDT_STATUS` 返回 0）⇒ **SMCCC vendor-hyp 通道真实可用**；主线仍无 `drivers/virt/gunyah`（今日复核 `master`）。⇒ **由「维持不立项」改为「阶段 0 阳性，进入立项评估」**；**WoaA 已有本机型第三方先例**（`Droid-VM/edk2-gunyah` tested platforms 列出 `tb322fc`，crosvm+Gunyah+edk2-gunyah.fd，usbfs 仿真 xHCI 直通见 `Droid-VM/crosvm fb86c7b0`）；**2026-10-24 用户裁决：走纯 Linux 宿主（不借 Android/AVF），Android 侧项目只作材料参考，最终回收 Android 分区**（缺件全在 Linux 侧软件、可自建；源码已抓 `reference/gunyah-android15-6.6/`） | `archive/topics/EL2-VIRT-2026-10-02.md`、`../RESOURCES/README.md` §1.5 |
| C9 | 兼容层验收用例集 `README.md §5` §Q6 打分表 | ⬜ 新增 | 全部 | 5 维打分表出数 | — |
| **C10** | **马达透传（容器 vibrator HAL → aw86927 FF）** | ✅ **已打通（2026-10-13 `vk124-merged`；2026-10-17 vk127 补记 amplitude 默认 0 致静音，已改 255）**：镜像自带 vibrator HAL 只写主线不存在的 `leds`/`timed_output` 且不检查写失败 ⇒ Android 侧全绿、马达不动；桥 = `lxc.mount.entry` 覆盖 `/sys/class/leds` + 宿主 `elden-hapticd` 轮询 `FF_RUMBLE`。二期换自编 AIDL V2 HAL、三期固化进 `vendor.img`，Settings 强度档位靠静态 RRO。全过程与 kprobe 计数见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行081-C10.md`⟫ | HAL | 幅度/取消/每侧强度/RRO 有可查证据 + 人手体感确认 | `reports/waydroid-haptics-20261013.md` §7–§8、`PITFALLS #232–#246` |
| **C11** | **触屏中文输入法（唤起 / 折叠隐藏）** | ✅ **已上机验收（2026-10-20，vk127 / Phosh 0.55.0 / phoc 0.55.1）**：最终栈 = **squeekboard（OSK + `sm.puri.OSK0` 控制面 + seat 键盘）+ fcitx5 `--disable waylandim`（Rime 组词）+ `fcitx5-gtk3/gtk4`（候选窗由 IM 模块自绘）+ 自写 `elden-ime-focusd`（把 fcitx5 kimpanel 的 `SetRelativeSpotRect` 当聚焦信号 → `SetVisible(true)`）**。实测：点输入框自动弹键盘、敲 `nihao` 出候选、选 1 上屏**「你好」**；`SetVisible(false)` 收起（底部亮度 169→0）、`SetVisible(true)` 再唤起。**三处纠偏**：① 缺 `fcitx5-gtk` ⇒ 中文完全不工作（按键以字面字母进控件）；② fcitx5 若留 `waylandim` 会抢 IM 槽位 ⇒ squeekboard 哑；③ **上一轮的自编候选条 `candidate-bar` 完全不必要**（杀掉后候选照常）⇒ 已移入 `patches-userland/zh-ime/withdrawn/`。部署 `bash scripts/deploy-zh-ime.sh`（7/7 自检）。**剩余（不阻塞）**：整机重启后自启未验；自动收起无可靠信号（走触摸图标/Phosh 入口）；Qt 应用（`fcitx5-qt` 未装）与 Waydroid 容器内 IME 未验 | 桌面 | 点输入框→触屏键盘→拼音→候选→上屏中文；可唤起可折叠 | `reports/zh-ime-touch-chinese-20261020.md`、`reports/ime-osk0-dbus-spec-20261020.md`（OSK0/kimpanel/wvkbd 源码取证）、`PITFALLS` §59（+§48/§50）、`patches-userland/zh-ime/` |
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
> `sessions/2026-11-03-TASKS-§4-待办沿革.md`（2026-11-03 前的 §4 全文，零删改）。
> 功能状态只在 §1 任务行维护；未解/未收口只读 §0 与 §5；上游投递队列以 §7 为准。

**当前口径（2026-10-06 立，2026-11-03 复核）**

- **本轮主线** = 尽可能覆盖硬件驱动；判据 =「命令 + 原始输出」可复现。
- **本轮不投入**：Q24（2026-10-23 停止采样——根因已指名、日常线免疫，只读 §5 Q24）。UEFI/G1-29 已于 2026-11-01 恢复推进；G1-26/27/28 已出列。
- **迭代通道**：`fastboot boot`（零写盘）/ `--flash`；**kexec 定位 = 不需显示/网络的调试快环**（K3 裁决）——`mask=1` 全链零掉电、目标内核能起（写盘 marker + `nokaslr` 实证），但带磁盘根时死于 Q28 同源 bonded DSI 初始化，且 `0154` 对 kexec 机制性无效 ⇒ **本机 kexec 拿不到显示**；工程侧见 §7 M9，全过程见归档。
- **内核基线**：`clean/base`（= vk64 内核源 `d02658e63`，tag `baseline/clean-base`）为唯一功能基线；分界与旧树处置见归档。
- **boot_b 形态 / 上机纪律 / 归因分层**：只在 `DEVICE/README.md` §1.1、`PITFALLS` #3/#115 维护，本文件不复述。

### 开放待办（按顺序；需要物理 POR 的排最后）

- **T14 用户态驱动/服务独立固化** —— 🟡 门禁已收口（2026-10-28 真机 `verify.sh` **FAIL=0 WARN=0**，80 条含 19 unit 逐字一致）；剩余 = Mobian 换根后的重建 recipe（7 个 ELF 里 3 个无源、其中 2 个动态 musl）。权威 `reports/userland-service-inventory-20261025.md`、`reports/userland-dealpine-audit-20261026.md`、`packaging/elden-userland/tools/verify.sh`；历史与三步落地 → 归档。
- **T17 驱动模块化 × Alpine→Mobian 迁移** —— 🟡 交界面核对完成（2026-10-26，零写盘）；下一步 = 执行 S2–S7：装 `linux17` ext4、S7 = 一条 `fastboot boot` 换根（⚠ 2026-10-31 已把 `linux18` 删除并入 `linux17`，见 `PROGRESS.md` 2026-10-31 里程碑 ⇒ 本行原「留 linux18」的回退项已失效）、S2 补 7 个依赖闭包包、S3 补 `/usr/share/qcom/.../sensors`；回退 = 重启回 `boot_b`（秒级）。权威 `reports/modular-mobian-transition-20261026.md`。
- **C3 Play Integrity / DRM 取证**（G2）—— C1 已收官（vk95 起 `ip rule` 生效；去 workaround 出网 200，`reports/c1-noworkaround-20261013.md`）⇒ 下一步 = C3 身份/DRM 取证，其后 C2 GMS 登录（需上行 + 代理 + 凭据）。权威 = §2 C1/C2/C3 行。
- **N1 UEFI 间接引导** —— 🟡 2026-11-01 用户放行恢复推进；当前口径**只读 §5 的 2026-11-06 块**（该块推翻 11-05 夜 10 发并定案崩溃元凶 = 屏显写穿帧缓冲；11-04 晚块推翻更早的「已交 DXE Core」判读，逐块沿革在同一节），首轮定性 `reports/uefi-gunyah-reassess-20261024.md` §1。**解冻条件（任一）**：上游 issue #12 给出层级答案 / 出现 SM8750 上 UEFI 真正枚举 UFS 的第三方案例 / kexec 不可用而又需要启动菜单。
  - **2026-11-03 裁决（邮件+GitHub+外部三线核查后）**：解冻条件②**已满足** —— `7Night-kqx/UniXNU-dada`（小米 15 / SM8750）README 明写 UEFI「framebuffer/menu/**UFS**-works in Mu-Silicium」，并附 boot-image v3/v4 header + BootShim header-size 现成补丁。**下一步只做一件事**：用该打包链补「载荷被执行」（P1 主机侧搬 patch + 装对树内 `PatchedBinaries/UFSDxe.efi`(`00ae059f…`)，P2 单发零写盘 `fastboot boot`，判据 `stage1≠0`）。issue #12 无新回复（末条 `2026-10-29T04:19:30Z`）、邮件 UEFI 相关 0 封 ⇒ **不回帖、不升 Mu 基座**。权威 `reports/uefi-next-step-decision-20261103.md`（三份子报告同目录 `uefi-{mail-triage,github-scan,external-scan}-20261103.md`）。
  - **2026-11-03 下午（9 发零写盘）**：**DDR 黑匣子正控打通**（真内核 `primary_entry` 标记，断电重启读回 95%–98%）；并**推翻两条旧判据**——① `usb_read failed` ≠ 交棒（自旋探针同样触发但标记全 0；真内核是 `Booting OKAY 10.106 s` 后真执行，我们 UEFI 件是 `0.056 s` 早期拒绝）；② **不存在 1–2 s 看门狗**（自旋载荷躺数分钟无人复位）。`text_offset=0` 单独不够（`8ed4ffc1…` 仍被 0.056 s 否掉）⇒ 下一步 = 把载荷 Image 头（`code0` 必须 branch / `image_size`=解压真实长度 / `flags=0xa`）+ 打包头（v2 base0）逐字段对齐真内核。权威 `reports/uefi-posctrl-20261103-summary.md`。

  - **2026-11-04（主机侧定案 + 上机 1 发）**：**真因 = BootShim 只拷了 FD 的前 1 MiB** —— 载荷头 `image_size=0x400308` 被 repack 改写成真实长度，而 shim 又拿同一字段当拷贝长度、分块循环用 `cmp x6,#0x300000` 等值比较判剩余 ⇒ 首轮即落「完成」分支；设备侧「块 0–15 正确、其后 48 块全错」与「`LzmaDecode` 返回 `EFI_INVALID_PARAMETER`」都是这一条的下游症状（同源坑还解释了历史「`dc civac` 段死点」= 非 64 倍数长度使 `subs #64; b.ne` 永不归零）。修法 = 拷贝目标/长度改构建期常量 + 循环改「地址 < 上界」硬条件+ repack 加 16B 对齐（补丁 `patches/uefi/20261104-fixcopylen/`，坑 `PITFALLS #497`）。**上机 1 发（零写盘）**：`Sending 1.496 s` + `Booting OKAY 10.109 s` ⇒ ABL 真跳；随后 300 s USB 无枚举、`192.168.7.1` 不通，用户报「反复刷屏、疑似 panic、看不清」⇒ **屏上判据（`[P01]`/块表/`[D00]`）一帧未取到，本轮 verdict = indeterminate**；设备随后进入 fastboot（slot b/successful），`fastboot reboot` 后仍未回 Linux。**下一步先把设备弄回可读状态**（强制关机→fastboot→零写盘起已知可用镜像→读 `/sys/fs/pstore`），再重发本件取屏上判据。见 `reports/trials/20261104T024726Z-uefi-fixcopylen-r1.json`、`reports/artifacts/uefi-boot-20261104-fixcopylen/`。
  - **2026-11-03 晚 → 11-04（7 发零写盘）**：**载荷首次被真正执行，并一路跑到 DXE**。① 打包配方定案 = **v2 base 0 + Image 头对齐**（`text_offset=0` / `image_size`=解压真实长 / `flags=0xa`）⇒ ABL 从 `0.056 s usb_read failed` 变 `Sending 1.49 s` + `Booting OKAY 10.108 s`；② **屏上可见性达成（J1 首次）**：shim 直涂设备 DT 的 `splash_region`（`0xFC800000`），色带逐段推进可肉眼判读；③ **FD 4 MiB 全部拷到 `0xFF300000`**（进度 4/4），死点收窄到 `dc civac` 段，跳过该段后 shim 顺利 `br` 进 UEFI；④ **Mu PrePi 整段走完**：屏上出现 `UEFI firmware (version …)`（`AndromedaPkg/PrePi/PrePi.c:137`）+ 插桩 `[P01]`–`[P08]`/`[P10]`/`[P11]` 全部打印（含 `MemoryPeim`/`PlatformPeim`/`DecompressFirstFv`/`LoadDxeCoreFromFv`）⇒ **控制权已交给 DXE Core**；⑤ **DDR 标记通道在本类场景失效**：载荷跑过之后低 4 GiB 出现 ~1.9 GB `0xFF` 填充（两次对照确认来自自家载荷，定位在 PrePi `MemoryPeim` 段），会抹掉 shim 早写的 stage 页。**下一步 = 把同款屏上串口插桩打进 DXE Core**（`DxeMain.c` 9 个相位点 + `Dispatcher.c` 每 dispatch 一个 `>`），判据 `[D08]`（`gBds->Entry`）= 进 BDS 菜单。权威 `reports/uefi-payload-execution-20261104.md`；坑 `PITFALLS #490/#491/#492`。
- **M 系列（G1 上游化）投递** —— 队列与状态以 §7 为准；投递解冻由用户按批放行，agent 不等回复。
- **N2 Gunyah VM** —— 终局裁决 2026-10-25 = **本 firmware 下不做**（权威 `reports/gunyah-decision-20261025.md`）；6.12 驱动集只作 G1 上游补丁素材封存（§7 M9）。
- **T9 suspend 掉电率** —— 🔽 2026-10-28 用户裁决：优先级最低、暂不排期（恢复时按归档的历史口径；权威 `reports/qca-fw-download-suspend-20261021.md`、`reports/t9-vk130-pcie-l2-live-20261021.md`）。
- **H1 资产清理（2026-11-05 整理轮收尾）** —— `build/` 已清扫 190.7 G→17 G（执行账 `reports/asset-tidy-20261105.md` §7）；**`out/` 历史镜像已归档**（2026-11-05：129 件→`out/` 留 15 件，114 件移 `backup/out-history-20261105/`，逐件 sha + 回滚脚本；`vk-kernel-identity.tsv` 一行未改、`check-doctor` FAIL=0；执行账 `reports/out-archive-20261105.md`、工具 `scripts/out-archive.py`）；**剩两件已结案（用户 2026-11-06 裁决）**：`.pi/trash` **不清理（等用户自己清）**、`backup/` 与 `.pi/sessions` **不上云、留本地** ⇒ 不再每轮询问（账目口径见 `RESOURCES/README.md` §3 的 B2/B4）。详见 `.pi/plans/2026-11-05-交接-下一轮会话.md` §2 与 `RESOURCES/README.md` §3 的 B2–B4/H1。
- **H2 完整性巡检（每轮收尾，2026-11-05 起）** —— `bash scripts/check-doctor.sh` + 镜像基线复算（`versions/out-images-sha256-20261105.tsv`，命令在表头；**必须走 `O_DIRECT`**，普通读会命中被位翻转的页缓存副本，见 `PITFALLS #513`）+ 项目仓与 `geekidos-linux` 的 `git fsck --full`。判据与背景 = `PITFALLS #512`/`#513`、`reports/integrity-audit-20261105.md`（磁盘侧真损坏 0）。⚠ 禁用 `echo 3 > /proc/sys/vm/drop_caches`（本机实测卡死重启）。

### 收尾轮次纪律（2026-10-23 用户定，仍有效）

- **需要物理 POR 的样本一律排在最后**（用户在机旁断电/开机时一次做完），其间只做不重启的项。
- TF 卡（G1-6/Q10）已收口出列；**Q28 补采样与 Q32 已于 2026-10-24 收口**，其余「需要 POR」项全部关闭 ⇒ 现无待取 POR 样本；判据备查 → 归档。
---

## 5. 查漏补缺（GAPS）

### 2026-11-06（深夜）：**真启动崩溃真因 = 我们自己的探针写屏**（修好后真路径首次到 EB）— p13→p24 十一代件

- **一句话**：`LoadImageAndAuth()` 入口那行 `SbProbeMode = … : 0;` **无条件**把探针模式重置为 0，
  把 R4 设的默认 3（沉默）覆盖掉 ⇒ 真件（cmdline 无令牌）里十几次 `SbVProbe` 直写帧缓冲
  （scale 3 每行 ≈274 KiB × 十几行 ≫ splash 前 ~448 KiB）⇒ `PITFALLS #514/#515` 写穿机制。
  修法 `20261106R12-probemode-guard`（**只有带 `sbstop=` 令牌才改模式**）。
- **判据链**：真件 vs 令牌件唯一差别 = "写不写屏"；**只改 cmdline 文本（`console=tty0` 变体）照崩**
  ⇒ 与 cmdline 内容无关。修复后（p19）真件回 `ret-after-lia` 且设备存活；p20 全路径 → 宿主
  `Booting OKAY [0.001s]`（越过 LIA/ExitMenuKeys/FastbootOkay）后崩 `0xCFE98C4C`。
- **真载荷阶梯**（历史上从未在真内核载荷上做过）：`VS_STOP 16/20/24/26/27/28/34/35/36/37/38`
  与 `SB_STOP 1..6`、`40` **全部回话** ⇒ 装载/AVB/槽位/DTB/ramdisk/释放/pre-EB 全通。
- **排除**：`FastbootUsbDeviceStop()`（p21 跳过它仍崩同一 PC）；EB（p24 跳过 EB 仍崩）⇒ 崩点不在 EB 内部。
- **PC 不在自家模块内**：`[L] Found=1` 后那条 `[I]? base=0xCFEB2000 size=0x45000` 是 LinuxLoader，
  崩溃 PC `0xCFE98C84` 在它**下面 ~0x1C000** ⇒ 崩在第三方二进制 DXE 驱动（EB/尾段做 USB redriver 重初始化的那个）。
- **三条旧归因作废**：「跳进堆」（DXE Heap 是 `Conv`，DXE 映像本就分配在此，DxeCore 自身在 `0xD4CA6000`）、
  「`MarkPtnActive()` 崩」、「`FastbootUsbDeviceStop()` 崩」。
- **纪律/副作用**：82 MB 真件**一会话一发**（第二发必 `Load Error`）；**ABL 会写槽位 retry**
  （实测 `boot_b` 7→6，已 `set-retry 7 b` 补回）⇒「零写盘」只对 agent 动作成立（`PITFALLS #525`）；
  `eldroid-bootctl reboot bootloader` 偶发卡死关机路径。
- **正文/坑**：`TASKS/sessions/2026-11-06-UEFI真启动崩溃真因-探针写屏.md`、
  `patches/uefi/README-p19-p20-NOTE.md`；`PITFALLS #525/#526`；
  配方 `p14…p24-recipe.txt`（`p7` 仍是逐字节复现基点，未动）；阶梯账 `reports/artifacts/real-vs-ladder-20261106T21*.tsv`。

### 2026-11-06（傍晚）：**首次上机全场走通到跳内核** + 三条判据更正（EB 后宿主失联 / 会话污染 / 跳进堆）

- **一句话**：门控住 `out:` 那条诊断写后，`vs-18/19/26/27/28/35/36/37/38` **九档全回话**（p7 同一点崩）、
  BootLinux `SB_STOP 1..6` 全回话 ⇒ 装载/DTB/ramdisk/释放全通；`stop=7/41/42` 的「无应答」是
  **`ExitBootServices` 拆掉 USB 设备栈 ⇒ 宿主天然收不到**（屏上 `Usbfn is not enabled`），不是崩溃。
- **真启动件首次被放行**（p11/p12 = 默认 `SbProbeMode=3` + 去掉 R18 的 `CpuDeadLoop`）：
  现象 = **递归 dump**，用户报异常 PC **`0xcfe98c38` 落在 `DXE Heap`**（`0xB90C0000+0x1D500000`）
  而 `Kernel` 区是 `0xA8000000+0x10000000` ⇒ **「跳进堆」**；卡点从「AVB/分区/装载」整段搬到
  **「EB → `PreparePlatformHardware()` → `LinuxKernel()`」**。
- **纪律**（新账）：① **一个固件会话只能打一发电平 ≥40 的件**（连打必退化 `diag st=Load Error … ldt=Load Error`，
  换会话即恢复）；② EB 之后只能看屏，`--scale 1` 把一行压到 91 KiB（448 KiB 预算 ≈ 4 行）。
- **第二轮（同日 18:34，照片判读）**：p12（`scale 3`）真启动的屏上顺序是 `[L] LoadImage=Success` →
  USB redriver/I2C 刷屏 → **直接** `Synchronous Exception at 0xCFE98C38`，
  **`[K] JUMP-BANNER` 没出现** ⇒ **死在跳内核之前**；宿主连 `Booting OKAY` 都没收到。
  **最重要更正**：诊断模式与真启动是两条路径（`FastbootOkay`/`FastbootUsbDeviceStop`/`ResetBootDevImage` 只在真启动分支，
  且诊断件还前缀覆写 cmdline 丢 `root=`/`console=`）⇒ `PITFALLS #524`。
- **下一步**：**p14 = p12 + `SbForceDiagPath`**（cmdline 原样、只跳过那三个调用），判据 = `[K] JUMP-BANNER` 出不出现；
  出现 ⇒ 凶手在这三个调用里，仍不出现 ⇒ 回到 `LoadImageAndAuth` 返回后的收尾。再往后才是
  `--scale 1` 四行 banner（pre-EB / post-EB / post-PPH / JUMP）那套 EB 之后定位。
- **正文/坑**：`reports/uefi-onboard-walkthrough-20261106.md`；`PITFALLS #523`；
  会话记录 `sessions/2026-11-06-UEFI上机全场走通到跳内核.md`；判据 `reports/artifacts/uefi-p9-onboard-20261106/results.tsv`。

### 2026-11-06（下午）：34→27 窗口里还有一条**未门控**的屏显写 + 探针 35..38 / p8·p9 世代就绪（**未上机**）

- **一句话**：上午那份「窗口只剩 `MarkPtnActive()`」的读法**在静态上不唯一** —— `FindBootableSlot` 的 `out:` 收尾里
  躺着 2026-11-04R15 加的一条**无条件** `SerialPortWrite`（走帧缓冲），它没纳入 `sbprobe` 开关 ⇒
  `34` 档是 `return EFI_ABORTED`（**不经** `out:`）、`27` 档是正常返回（**必经** `out:`），
  「自己的诊断打印把帧缓冲写穿」与「`MarkPtnActive()` 崩」两种解释等价。
- **先验变化**：`MarkPtnActive()` 的 GPT 写回**本树是关掉的**（`IsUpdatePartitionAttributes()` 恒 `FALSE`，
  `PartitionTableUpdate.c:193-200`）⇒ 它只跑内存属性循环，不落盘。
- **本轮主机侧产出（零写盘）**：`patches/uefi/20261106-vsstop35/`（`VS_STOP(35..38)`）+ `20261106R2-gate-outwrite/`
  （那条写按 `SbProbeMode` 门控）；世代配方 `p8-recipe.txt` / `p9-recipe.txt`（**p7 不动**，在盘件仍逐字节可复现）；
  `scripts/uefi-r21-p7-ladder.sh` 新增 `PFX` / `BUILD_ARCHIVE`；构建 `reports/artifacts/uefi-20261106R{8,9}-*/`；
  镜像 `out/r21-sbstop-p{8,9}/`。**反汇编逐点核对**（`0x23`→`0x24`→`SerialPortWrite`→`0x25`→`0x26`→`0x1b`；p9 另有
  `ldr w8,[x27,#0x63c]; cmp w8,#1; b.hi` 门控）。
- **下一步（4 发、1 次断电）**：p9 `stop35` → `stop36` → **`stop27`（判决）** → `stop37`/mode 1（反证）；
  1/2/3 全回话 ⇒ 尾段通过、窗口搬到 28 之后（p9 已备 `stop18/19`，可用 mode 3 把 11-05 的 18/19 重测）。
  **当前阻塞 = 板子不在 USB 上**（在线的是主机上的 Android 模拟器 `sdk_gphone64_x86_64`），本块**无上机判据**。
- **正文/坑**：`reports/uefi-vsstop35-tail-static-20261106.md`（含排产与复现命令）；`PITFALLS #522`；
  会话记录 `sessions/2026-11-06-UEFI尾段二分与未门控屏显写.md`。

### 2026-11-06：**上一轮 10 发作废（探针从未命中）+ 崩溃真因 = 屏显写穿帧缓冲 + 新通道 `sbprobe=3`**

- **一句话**：`VS_STOP(n)` 判的全局 `SbStopStage` 只在 `BootLinux()` 内赋值，而 `LoadImageAndAuth()` 先被调用
  ⇒ 11-05 夜那 10 发（`vs-stop20…25`、`pre-stop16/18/19`）**一次都没命中探针**，行为等于对照组；
  修好探针后单变量判别定案：崩溃元凶是 **`SerialPortWrite`（帧缓冲控制台）**，不是 `gRT->SetVariable`。
- **机制**：`splash_region` 声明 43 MiB 但只有前 ~448 KiB 可安全写（`PITFALLS #492`），面板 1904×3040@32bpp，
  `SCALE_FACTOR 3` 下一行文字占 **274 176 B** ⇒ 只装 ~1.6 行 ⇒ 「17 回话、18 崩」是我们自己的调试输出越界，
  不是随机崩溃。
- **新通道**：`sbprobe=3` = 只更新 `SbLastMark`、不写帧缓冲/不写 NV 变量；标记仍随 fastboot 响应
  （`diag st=%r last=[%a]`）回宿主 ⇒ 二分不再付断电代价（不崩的档 1–2 s）。
- **重推后的窗口**：`26/30/31/32/33/34` 全回话、`27` 崩 ⇒ 窗口 = (`VS_STOP(34)`, `VS_STOP(27)`)，
  只剩 `MarkPtnActive()` + `out:` 收尾 + `IsSuffixEmpty`/`IsDynamicPartitionSupport`/`StrnCpyS`/`StrnCatS`。
  **首要嫌疑 = `MarkPtnActive()`**（槽位属性写回，与 `PITFALLS #484` 同片区域），是唯一未被探针覆盖的大调用。
  另：`sbstop=7`（跳内核前，mode 3）也崩，与上表自洽。
- **下一步**：① 加探针 35（`MarkPtnActive()` 之后）单发定案；再决定是否单独判别 `FbConFlush()` 的整块 cache 维护。
  ② ~~补可复现性欠账~~ **✅ 2026-11-06 已完成**：`scripts/uefi-r21-p7-ladder.sh`（配方 `patches/uefi/p7-recipe.txt`，
  35 个补丁按序）+ `uefi-sbstop-patch.py --probe N`（第二个令牌 `sbprobe=3`）⇒ `--verify` **rc=0**，
  `uefi-preamble7-r1` 与 `p7-m3-stop{27,34}`、`p7-s26-pb3` 四件与在盘件 **sha256 逐字节相同**；
  **构建段仍不逐字节可复现**（`PITFALLS #510`：`--rebuild` 只验关键字串，不比 sha）。
  连带已执行清仓：`out/r21-sbstop` **4.8 G → 257 M**（72 件删前 sha 全对），`out/` 7.9 G → 3.1 G。
  详见 `reports/patches-uefi-grading-20261106.md`、`patches/uefi/README.md`。
- **正文/坑**：`reports/uefi-vsstop-and-fbconsole-20261106.md`；`PITFALLS #514/#515/#516`；
  会话记录 `sessions/2026-11-06-UEFI探针失效与帧缓冲写穿.md`；补丁 `patches/uefi/20261105R{2,4,5,6,7}-*/`。

### 2026-11-05（上午）：R21 **取证通道改走 fastboot 响应**（断电收尾，重建完成、未上机）

- **一句话**：屏上三条通道全废（`ConOut` no-op / LinuxLoader 的 `SerialPortWrite` 不上屏 / NV 变量不跨上电）
  ⇒ 把最后一条 `[V]`/`[K]` 标记塞进 **fastboot 响应**（`diag st=%r last=[%a]`），取证完全在宿主侧、不用拍照。
- **判据**：`diag st=Aborted last=[K] …` ⇒ 到达第 N 阶段；命令无响应 / USB 掉线 ⇒ 崩在第 N 阶段之前。
  诊断模式（cmdline 带 `sbstop=`）**不调** `FastbootUsbDeviceStop()`，解析必须在调用 `BootLinux` 之前当场做。
- **断电事故**：11-05 09:32 前掉电 ⇒ UEFI 树 15 个文件变 0 字节、R21 产物 9 个文件全 0、报告尾部 2456 B 变 NUL。
  已 `git checkout` 恢复 + 用 manifest 的 25 条补丁序列重建（增量 15 s）；与 11-04 那发 payload 逐块比对
  **仅差构建时间字符串**（`Nov  4 2026 23:18:14` → `Nov  5 2026 09:39:49`）⇒ 代码等价、sha 不跨构建可复现。
- **产物**：`reports/artifacts/uefi-20261104R21-hostdiag/`（FD `cd100f81…`）、镜像 `out/uefi-20261104R21-hostdiag-r1.img`
  （`a9e0b059…`，67 198 976 B）；补丁 `patches/uefi/20261104R21-hostdiag/0001-fastboot-host-visible-diag.patch`。
- **下一步（未上机）**：`sbstop` 阶梯 5 → 3 → 4 → 2，每档重复 3 次（崩溃随机）；**设备仍在安全态**，`boot_b` 未写。
- **正文/坑**：`reports/uefi-noavb-dtbo-bootchain-20261104R.md` §8/§9；`PITFALLS` #509–#511；
  会话记录 `sessions/2026-11-05-断电收尾R21取证通道重建.md`。

### 2026-11-05（夜）：判据彻底改为**宿主可读**，崩溃点从「DXE 里某处」收敛到 `LoadImageAndAuth` 前导 3 步

- **一句话**：`sbstop=0` 入口探针证明「令牌解析 + `FastbootFail` 回传 + 探针后固件仍活」三件全成立
  （`diag st=Success last=[entry]`，随后 `getvar product` = **`sun`**，与 ABL 的 `elden_prc_wifi` 区分）；
  随后 10 发零写盘阶梯把崩溃点锁进 `LoadImageAndAuth()` 前导（`fb-stop13` 回话 / `pre-stop19` 崩）。
- **关键判据变更**：崩在 `ShutdownUefiBootServices` 附近时 USB 端点会死（`reap_urb … transport endpoint shutdown`），
  `FastbootFail` **结构性送不出去** ⇒ 改用「宿主是否收到 `diag`」+「崩不崩」双判据；**代价 = 每次崩一次物理断电**。
- **已排除**：`WaitForFlashFinished()`（`gEfiKernelProtocolGuid` 查找失败 `Status:0xE` ⇒ `KernIntf==NULL` ⇒ 多线程路径不启用）、
  `GetAVBVersion()`（编译期 `NO_AVB`）、`Images[1]` 越界（数组 32 项）、`GUARD()`、`CheckImageHeader()`、`VBAllocateCmdLine()`。
- **首要嫌疑**：`FindBootableSlot()`（`PartitionTableUpdate.c:1603`，槽位属性读/写 + `ValidateSlotGuids` + `MarkPtnActive`），
  与 `PITFALLS #484` 同一片区域；崩溃 ELR **固定 `0xCFE988F0`、落在 DXE Heap `[0xB90C0000,0xD6610000)` 内** ⇒ 跳进堆（坏函数指针/返回地址）。
- **下一步（件已就绪）**：`out/r21-sbstop/uefi-preamble-r1.img`（`7757114d…`）+ `pre-stop{18,17,16}.img`，
  打序 18 → 17 → 16，判据 `diag st=Aborted last=[vs-N]`；`pre-stop19` 已证崩在 `GetAVBVersion` 之前。
- **正文/工具**：`reports/uefi-screenlog-crash-20261105.md` §7–§12（含全部 10 发表格）；
  补丁 `patches/uefi/20261105-{diagentry,finebisect,vsbisect}/`；工具 `scripts/uefi-sbstop-patch.py`、
  `scripts/uefi-r21-sbstop-ladder.sh`；会话记录 `sessions/2026-11-05-UEFI宿主侧判据阶梯.md`。

### 2026-11-04（更深夜）：路线重排 —— **loader 早就在 FV 里（`LinuxLoader`），只是没人启动它** ⇒ 首选改成路线 D

- **下轮入口**：`.pi/plans/2026-11-04_late-uefi-routeD-linuxloader.md`（复核 + 7 条新增主机侧事实 + R13 实施单 + 风险表）。
- **更正上块**：`QcomModulePkg` **在树里也编了**（`build.log:4354`），`LinuxLoader` 的 FFS（GUID `F536D559-459F-48FA-8BBC-43B554ECAE8D`）就在 `FVMAIN.Fv.txt` 末行 `0xC126B0`；它没跑的唯一原因是 `MODULE_TYPE = UEFI_APPLICATION`，而 `Dispatcher.c:73 mDxeFileTypes[]` 不含 `APPLICATION`（`PITFALLS #503`）。
- **路线重排 D > A > B**：D = BdsDxe 里 `LoadImage`+`StartImage` 这个 FV 内应用 → 它写死 `BootIntoFastboot=TRUE` ⇒ 进 UEFI 侧 fastboot → 宿主 `fastboot continue` 启 `boot_b`（`FastbootCmds.c:2685/2854` → `LoadImageAndAuth` → `BootLinux`）；**新增字节 0、不动盘、启的就是今天 ABL 启的同一份 boot.img**。解锁态 AVB 走 `ALLOW_VERIFICATION_ERROR`（`VerifiedBoot.c:1105`）、`EnableMdtpSupport=FALSE` ⇒ 自签镜像不被拦。
- **A（GRUB 进 FD）降为退路且已验尺寸**：FD 尾部空 `1 727 675 B`；`grub-mkstandalone -O arm64-efi` 最小集 = `2 093 056 B`、`xz -9` = `1 174 968 B` ⇒ 压得进。arm64 模块可从 USTC 镜像 `grub-efi-arm64-bin_2.14-2ubuntu1_arm64.deb` 现取（本机已解包实测）。

### 2026-11-04（深夜）：UEFI **DXE 全走完、UFS 枚举成功（BlockIo=119）、整机无 ESP** ⇒ 只差一个 loader

- **下轮入口**：`.pi/plans/2026-11-04_handoff-uefi-dxe-to-linux.md`（现状/12 发清单/方案 A（零写盘 GRUB 进 FD）/判据/复现步骤/新坑）。
- **一句话**：`0xD2B9B224` 已定案 = `QRKSDxe`（剔除后零异常）；`BlockIo=119` 证明 UFS 枚举通了；唯一的 `SimpleFileSystem` 是 **LUN4 `modem_b`**（FAT，绝不能写）⇒ BDS 无交接目标 ⇒ 复位 ⇒ 原厂 recovery。
- **下一步**：方案 A = standalone GRUB arm64（或自写最小 loader）打进 FD，由 BdsDxe `LoadImage` 启动，GRUB 用 ext2 读 `linux17`(ext4) 的 `/boot`；退路 = GPT 手术建 ESP。
- **正文**：`reports/uefi-ramoops-channel-20261104R.md` §9–§11；会话记录 `sessions/2026-11-04-UEFI-DXE走完到BDS之后的handoff.md`。

### 2026-11-04（傍晚）：UEFI **DxeCore 真进场、QCOM DXE 驱动在跑**，卡点 = 某驱动同步异常 0xD2B9B224

- **推翻 11-04 早间的「DxeCore 从未被启动」**（那批 11 发只拷 1 MiB 的伪结论）：屏上实测 `[D00]`（附 `&DxeMain=0xD4CA7D90`，DxeCore 装载基址 `0xD4CA6000`/`0x210000`，来自 `[L04]`）与 `[D01]…[D07]` 全部出现。
- **64 块 FNV 表 64/64 与主机期望一致**（块 1–37 逐值相同、块 38–63 恒 `1DC99DC5`；仅块 0 有差异，待查是否为运行时改写的 FV 头）⇒ **`fixcopylen` 的 4 MiB 拷贝链已收口**。
- **QCOM DXE 驱动确实被 dispatch**：`HW Wdog Setting from PCD`、`mbox_os_init`（缺 SCM mailbox 14）、`pm8550b`、`IsArmVBSmc`、QDSS clock、`Overriding PIL cfg`、`usb_redriver`、`qup_open` 等日志；随后 `RmVmDxe`（Gunyah）报 `Merge Overlay: -3 / Gunyah Interface init error: Load Error / Skipping RmVmProtocol Install`。
- **卡点**：紧跟其后 `Synchronous Exception at 0x00000000D2B9B224`（三次独立实验逐字节相同 = 确定性），且异常处理器在 RELEASE 下只剩 ConOut 打印、该打印在 FB 滚屏路径二次异常 ⇒ `Recursive exception` 无限重印（「反复刷屏」真身）。
- **下一步判据**：`[I] base/size` 装载表 + ConOut no-op 使处理器走到 `CpuDeadLoop`，屏停在最后内容 ⇒ 用 `0xD2B9B224 ∈ [base, base+size)` 定位驱动；件 `out/uefi-20261104R7-r1.img`（sha `331fb365…`）。
- **正文/证据**：`reports/uefi-ramoops-channel-20261104R.md`、trial `reports/trials/20261104T0{6,7,8}…-uefi-*.json`、屏上原文见会话；补丁 `patches/uefi/20261104R2-slow-serial|R5-dxebase|R7-loadmap/`。

### 2026-11-04R（下午）：UEFI 判据换成 **ramoops 主机可读**（零写盘件已构建，未上机）

- **一句话**：上一发 `fixcopylen` 的 verdict=indeterminate 是因为唯一判据是「人眼看屏」而屏在刷；本轮把同一条轨迹（`[F01]/[P01]…[P11]`、64 块 FNV 表、`[D00]…`）**同时写进 Linux 的 pstore record 区**（`dprzs[0]=0xC2000000` PrePi、`dprzs[1]=0xC2200000` DxeCore，格式照 `persistent_ram_buffer` + `"====<sec>.<usec>-D\n"` 头），回到 Linux `cat /sys/fs/pstore/dmesg-ramoops-{0,1}` 即可判；**刻意去掉 Dispatcher 进度点**（那是无限滚屏的元凶）。
- **件**：`out/uefi-20261104R-r1.img`（sha `e7f8b544…`）；断言=shim 字面量池 `0xff300000/0x00400000/0xff700000` + header v2 + `text_offset=0` + `flags=0xa`；期望块表 `.pi/plans/next2/expected-blocktable-uefi-20261104R-r1.txt`。
- **机制化**：`scripts/uefi-repack-v2aligned.py` 末尾新增 `verify_built_image()` 硬断言（旧 shim 件一律拒，实测拒掉 `nocivac`）；`out/SUPERSEDED.md` 登记 7 类旧变体。
- **正文/证据**：`reports/uefi-ramoops-channel-20261104R.md`（§1 内核侧 pstore 事实与 ECC=0、§3 上机与三态判读、§4 DDR 冷清风险）；补丁 `patches/uefi/20261104R-pstore/000{1,2}`。

### 2026-11-04（晚）：UEFI **DxeCore 从未被启动** —— 真卡点 = 内层 FV 解压失败（11 发零写盘）

- **一句话**：给 DXE Core 打屏上串口插桩后，**推翻上一块「已交给 DXE Core」的结论** —— `[P11]` 打在 `LoadDxeCoreFromFv()` **返回之后**，实测返回 `0x800000000000000E`（EFI_NOT_FOUND）⇒ DxeCore 一次都没执行。卡点在更前一层：`DecompressFirstFv` 的 GUIDED/LZMA 段 `Decode` 返回 `EFI_INVALID_PARAMETER`（`GetInfo` 反而成功、解压后 `0xC45008`）⇒ 无内层 FV HOB ⇒ `FfsAnyFvFindFirstFile(DXE_CORE)` 失败。
- **主机侧反证**：同一份 `Sdk/C/LzmaDec.c` 在主机解压 `res=0`、Python `lzma` 亦成功 ⇒ 压缩数据与参数没问题；且 `LzmaDecode` 只分配 16 KB probs（`p.dic = dest`），**「scratch 64 KiB 不足 / 字典 16 MiB」两条假设均被否**。
- **设备侧硬事实**：64×64 KiB 块表显示 **FD 块 0–15（0–1 MiB）全部正确**（仅 2 个单比特翻转），**从块 16（`0x100000`）起 48 块全错**；坏内容 ≠ ramdisk / gz 载荷 / `0xFF` / `0x00`。**未定**：损坏在 PrePi 之前（shim 拷贝 / ABL 解 gz）还是 PrePi 之内（内存图把 `0xFF300000` 声明为 `BsData` = 可分配）；第 11 发两张块表屏纯黑无输出，判据未取到，用户裁决收尾。
- **下一步（若复起）**：① 把 `Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c` 里 `"UEFI FD"` 的 `BsData` 改 `Reserv` 单变量验证；② 若仍错，做「shim 与 FD 之间加 `.space` 偏移」变体，看 1 MiB 边界跟**源**走还是跟**目标**走。
- **正文**：`PITFALLS/sessions/2026-11-04-UEFI-DxeCore从未启动.md`；坑 `PITFALLS #493/#494/#495/#496`；镜像 `out/uefi-20261104-dxe{,2…11}.img`、补丁 `patches/uefi/20261104-dxe/0001…0014`、现场 `reports/artifacts/uefi-boot-20261103-dxe{,2…11}/`。
- **作废**：`reports/uefi-payload-execution-20261104.md` §7「`[P11]` ⇒ 已交 DXE Core」的判读。

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

**一句话**：在「a 槽 unbootable 切断回落 + `boot_b`←载荷 + `sysrq-b`」同一路径上做了 4 个变体，
**四臂 `stage1` 全部为 0**（载荷第一条指令从未执行）；中途一度判「A3 挂死 = 载荷被执行」，**用户现场证实设备其实正常进了 Android，结论已撤回**。
报告 `reports/uefi-ddrcut-fallback-20261101.md` §6-A/6-B/6-C/6-D；record 三条：`reports/trials/20261102T03*-ddr-marks-{cacheclean,sysram}-r1.json`、`…-ddr-marks-ramdisk-r1.json`。全程零写盘除 `boot_b` 三轮（A1/A2/A3 各一轮 + 各轮刷回，均读回核验并复原）。

- **四臂**（shim 变体均已入库 `patches/uefi/20261102-ddr-clean/`，构建选项 `--shim ddrmarksclean|ddrmarkssys`）：
  A1 = 标记页加 `dc civac`+`dsb sy` 回写（排除「只落 D-cache」）；A2 = 标记改写**普通 System RAM** `0xE3F00000`/`0xC2500000`（排除「carveout 被保护写不进」）；
  A3 = A2 + v0 image 补 `--ramdisk`(92 B) + `--cmdline`（排除「v0 无 ramdisk 被静默丢弃」）。**三臂 `stage1` 皆 0**。
- **正控（必做，已通过）**：`a` unbootable + `boot_b` = 日常 Linux ⇒ `sysrq-b` 后 **3 s 回 Linux** ⇒ 切断动作本身不阻塞槽位启动。
- **机制硬事实（`PITFALLS #487` 追加条）**：**「a 槽 unbootable」只能挡住一次** —— b 槽失败后 ABL **自己把活动槽切到 a 并清掉它的 unbootable 位**，
  然后正常起 Android（实测 `current-slot=a`、`slot-unbootable:a=no`）。要真切断必须让 a 槽**内容**不可用（`backup/stock-259/boot_a.img` 可回滚）。
  另：`17ef:7f3d` = **Android MTP**（class255/sub66/proto1），看到它 + `adb devices` 有设备 = 进了 Android，**别误判成挂死**。
- **下一步（已排好，未做）**：① **正控**——把日常 Linux 内核极早期入口打同样的三窗标记、走同一路径，验证「装载后可写 DRAM」这条链；
  ② 正控通过后换「真 Linux `Image` 头 + 内联 FD」的壳做单变量。
- **设备终态**：Linux 在机（`boot_id 109a2bce…`、UTS `…vk172`、根 `/dev/sda17` ext4、失败单元 0）、`boot_b` = `fb55997c…`（读回逐字节一致）、
  `current-slot=_b`、**a/b 均 Bootable**。

**以下为 2026-11-01 19:40 的当时记录（结论已被上条取代，仅留沿革）**

**现状（2026-11-01 19:40，只读实测）**：`current-slot:b`、`a/b` 均 `successful:yes`、`retry:7`、`unbootable:no`、
`verdict:fastboot`；**无 ssh、无 adb、无 Android**（`lsusb` 仅 `18d1:d00d`）。

**未解问题（按权重，均未证）**
1. `fastboot continue` 的 **`Failed to load image from partition: Device Error`** = ABL 自己的**加载层**错误（比 `Booting OKAY`/`usb_read failed` 更有指向性）
   ⇒ 优先核对 AVB 链（`vbmeta_a/b`、`vbmeta_system_a/b`、`pvmfw_a`）与 UFS 读。
2. **只改了 `boot_b` 却让原厂槽 `boot_a` 也不启动** ⇒ 指向某个**跨槽持久状态**：`misc`（上轮读取被打断）/ `devinfo` / `lenovoraw` /
   rpmb rollback index / ABL 的 prevent-flash-verify 类修改检测。
3. **GPT 一致性**：我只改 `boot_a/boot_b` 的 byte6，而 `recovery_b/init_boot_b/pvmfw_b` 等仍是 `0xfb`（succ=1/unbootable=1），
   与 `boot_b=0x7f` **形态不一致** ⇒ 「槽可用但子分区声明不可用」可能被 ABL 拒（未证）。

**待办（已暂停，等用户决定；全部只读优先）**
1. EDL 重抓 **GPT 修复之后**的 `logfs`（现在缺这一段）；2. 只读核对 `vbmeta_*`/`pvmfw_a` 是否仍为原厂件；
3. 重读 `misc`/`devinfo`/`lenovoraw` 看是否被写过；4. 仍无解则按官方包 GPT 全量比对，或 LTBox 全量刷回（最后手段）。
5. 「载荷是否被执行」仍无答案（DDR 标记需 Linux 才能读）——本次不能反证 `PITFALLS #481`。

报告 `reports/uefi-slotboot-stuck-fastboot-20261101.md`（事故全记录）、`reports/lanes-consolidated-20261101.md` §5、
现场件 `reports/artifacts/uefi-slotboot-20261101/`。

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

- **根因 + 修法**（`PITFALLS` #475）：`hooks/net-selfheal.pre` 判据写死 Alpine 的 `wlan0`，Debian 侧是 **`wlp1s0`**
  ⇒ 永不提前返回，**每轮启动白等满 120 s**（静默降级、无失败单元）。改判据为「任意 `wl*` + `UP` + 有 IPv4」、上限 **20 s**。
- **真机结果（warm reboot 实测，同一台机）**：`net-selfheal` 3.1 s→**10.2 s（7.1 s 完成）**（原 128 s）；
  `multi-user.target` **128 s → 33.2 s**、`graphical.target` **33.2 s** ⇒ **净省约 95 s**。
  同轮：`iio-sensor-proxy` active、`waydroid-container` active、失败单元 **0**、`dsi_bonded_cmd_failed` **0**、面板 `On`。
- **部署事故与教训**（`PITFALLS` #476）：手工 `cat >` 直推仓库 `hooks/*.pre` 丢了 `stage.sh` 补的 shebang ⇒
  `Exec format error / 203/EXEC`；又因「脚本与数据共用一个 stdin 管道」把目标截成 0 字节。已改为**只从 `out/stage-debian/` 部署**。
- **未验证**：修后的 hook 只在**暖复位**上验过启动耗时；下一次真 POR 应复核同一数字（预计不变，`wlan` 关联 ~9 s 与复位深度无关）。

### 2026-10-31 下午（续）：「全部继续」四项落地

- **① wl2868c v4 已投（15:0x CST，git send-email，5 封全 `Result: 250`）**：cover MID `<cover.1793427040.git.xiaqinghuan@mail.ustc.edu.cn>`，4 枚分别为 `7f2062a3…`/`bebaff7e…`/`74cccd47…`/`9ef48d26…`（同 `.1793427040/41.git.` 前缀）；To Mark Brown + Liam Girdwood，Cc Krzysztof/Rob/Conor/linux-arm-msm/devicetree/lkml；cover `In-Reply-To` v3 cover ⇒ 与 v3 线程相连。**未上机**。
- **② greetd 停止语义已进生成链，并在设备上实测生效**（`packaging/elden-userland/{stop.tsv,hooks/greetd.stop,tools/render.py}`，提交 `b7d8fcd`）：设备部署后 `systemctl stop greetd` 实测 **1035 ms / 6 ms**（原基线 **90.0 s × 6/6**，`DefaultTimeoutStopSec` 兜底），`timed out` 计数 **0**，桌面自动恢复（`greetd active` + `phoc=1` + `dpms On` + 失败单元 0）。`verify.sh` **FAIL=0 WARN=0**（F 段 80 条与设备逐字一致）、`stage.sh` FAIL=0。**局限**：测的是 `systemctl stop`，真关机路径仍缺一次实机样本（判据 = 关机时 Δ(Stopped−Stopping greetd) ≤ 5 s）；旧 P0 drop-in `zz-stop.conf` 已移除（改由生成物接管），原件备份在设备 `/root/greetd-backup-20261031/`。
- **③ `cam-mode.sh` 从设备采回仓库**（同提交）：设备版本含 Debian 修正（会话用户/uid **现查** + `runuser` 回退，避免守卫静默空转），仓库副本落后 ⇒ 按设备版覆盖并同步 `MANIFEST.tsv` sha（`1262641c…`）。`verify.sh` F 段由此从 FAIL=1 转 0。
- **④ UEFI `E1-v0b` 上机 = 不交棒（证伪「含 UFSDxe 就交棒」）**：`reports/uefi-e1-v0b-onboard-20261031.md`。`fastboot boot` **零写盘**，60/60 s 采样全为 `18d1:d00d`、同一 bus/device ⇒ 从未离开 ABL；`fastboot reboot` **9 s** 回 Linux，`boot_id` `d13951f3`、根 `/dev/sda17`、面板 connected、`boot_b` 仍 `aedae5f1`、失败单元 0。四点表：E0/N2/E1 全 ❌、仅 A2（**厂商** UFSDxe）✅ ⇒ 判别量不在「有没有 UFSDxe」，而在厂商件 vs dodge 件（E1 少 `0x1b080` IOMMU stub、基座代次不同）。**J1（屏上出字）仍 0**。
- **②'「vk183 转正为日常件」= ✅ 已完成（2026-10-31 15:29 真 POR）**：**⚠ 2026-11-04 更正**：该结论在 boot_b 层已被 2026-11-01 的 UEFI 四臂判别轮覆盖回退（每轮实验后刷回 vk172 备份件，见 `DEVICE/README.md` §1.1 首条）⇒ **当前在机件 = vk172 备份（`fb55997c…`），不是 vk183**；本条只作 vk183 当时的验收记录。原记录：用户物理断电冷起，判据全绿 —— 7 项 Q28 计数全 **0**、`DSI PLL lock failed=4`（与 vk181 基线同，无新副作用）、面板 `connected/enabled/On`、`/lib/modules` **1639 `.ko`**、失败单元 **0**、`monitor-sensor` 出 `tilt=face-up`（G1-34 未回退）、根 `/dev/sda17` ext4、`boot_b` 仍 `aedae5f1…`。`boot_id` `0f6195d0`；trial record `reports/trials/20261031T073414Z-vk183-daily-por-r1.json`（`--reset por` / `GOOD`），证据 `reports/artifacts/por-vk183-20261031/`；`DEVICE` §1.1 首条已改为「vk183 转正」。
  **顺带观察（非回归，记为启动代价）**：`net-selfheal.pre` 等 `wlan0` 最多 **120 s**（本轮等到超时才继续，`wlan 未在 120 s 内 UP，照常执行`）⇒ `hexagonrpcd`/`iio-sensor-proxy`/multi-user 在它之后才起，整机 ~2 min 才全就绪；另 `hexagonrpcd` 在该轮以 `status=0/SUCCESS` 796 ms 后退出（**按需退出**，`iio-sensor-proxy` 随后正常出值）。

### 2026-10-31 下午：三封回信已发 + wl2868c v4 出件（用户「全部允许」批）

> 授权口径：用户 2026-10-31 批「回信正文可由 agent 代写」，前提 = 披露 AI 辅助 + 可复现证据 + 逐条回应（`AGENTS.md`「上游发信」）。

- **三封回信已投（13:27–13:29 CST，Sent Items [216][217][218]）**，报告 `reports/mail-batch-20261031b-3replies-20261031.md`：
  ① **[216] 回 Konrad**（M8 v2 / mdss-common RSC）= 接受、v3 只留 CORE+CORE_INT2，并**主动声明**「三复位在本板是一起测的，撤 RSC 后需重测 CORE+INT2 是否够；不够则由 RSC 设备驱动、不回 mdss」；保留 PLL 先行的排序待定点。
  ② **[217] 回 sashiko**（wl2868c v3 3/3）：High（父节点没 enable）**确认**；Medium **部分接受**（s5kjns/gt9764 的 binding 已 10-27 单独投递、gc08a8 无 binding 故删、删 sensor 上的 `power-domains`）；Low 四条**全接受**；并如实写「除 DTS 内容外未实测」。
  ③ **[218] 回 Krzysztof**（wl2868c binding）：**先更正两处**（v3 父节点缺陷使「users」比早先所称更弱；把「我们证明了什么」写成精确口径：下游板 DTS 实测 probe，但那不是上游那份文件，不能证明上游 200 行能 bind），再给 v4 三联形状 + **主动给出退出选项**（可 park 等 sensor binding）。
  **lore 复核未做**：`lore.kernel.org` 对本机 13:2x 起**一律 403**（`/all/<mid>/raw` 与查询页同），当日早间尚为 200 ⇒ 判为限流/临封，待重核（三条 MID 已记录）。
- **wl2868c 一手实测证据（只读，在机 vk183）**：`/dev/i2c-10` 在、`10-002f` 设备节点在、`camera_ldo1..5,7` 全注册（LDO6 无消费者）、dmesg 有 `geni_i2c 888000.i2c` + `[camera] loaded wl2868c-regulator` ⇒ **器件与供电接线是真的**（但**不等于**上游那份板 DTS 能 bind）。已写进 [218] 正文。
- **wl2868c v4 出件（主机侧，未投、未上机）**：`patches/upstream/wl2868c-v4-20261031/`（cover + 4 枚）+ `reports/wl2868c-v4-20261031.md`。拆为 binding / driver / `sm8750.dtsi`（两 CCI 均开 bus1 + `cci0_1`/`cci1_1` pinctrl + 节点按 unit-address 重排 + 提交信息改「三个 CCI、描述两个」）/ 板 DTS（`qupv3_2`+`gpi_dma2`+`i2c10` 使能、删 gc08a8 与 sensor `power-domains`、保留 s5kjns/gt9764 及其 supply 与 CSI endpoint）。**父代理独立复跑**：checkpatch（stdin）cover 1E1W / 0001 0E1W86 行 / 0002 0E0W192 行 / 0003 0E0W170 行 / 0004 0E3W182 行；**pristine `24a19b953e` 上 `git am` 4/4 rc=0 且终态 == 母树 tip `9ef48d26aa`（diff 0 字节）**；`sm8750-lenovo-elden.dtb` **rc=0 / ERROR=0**（102 367 B）、mtp 对照 0，`make W=1` 0 warning。**未证实**：`qupv3_2` 使能后 i2c10 在上游 board DTS 下的 probe（需上机）；`dt-validate` 诊断 **7→6 行**，其中 2 行是 `giantec,aac-mode`/`aac-timing` 在 dt-core 回退 schema 下的**属性类型错**（不是单纯「compatible 未登记」）——待 gt9764 binding 落地才消。
- **设备侧下一动作未执行**：恢复 `vk181` **会回退 G1-34 传感器修复**（在机 `vk183-fastrpc` = vk181 + 一枚 `qcom,non-secure-domain` DT commit）⇒ 不改判、不改刷；建议改为**把 vk183 转正为日常件**（需一发真 POR 样本 + `DEVICE` §1.1 口径同步），待用户确认。

### 2026-10-31 四 lane 轮（设备在线，vk183）

> 派工：总管 → 4 个一级角色（`physical-exec` / `mail-io` / `doc-audit-lead` / `code-boundary`），设备动作串行加锁、本轮**零复位零刷写**。
> 门禁：`scripts/check-doctor.sh` **FAIL=0 / WARN=3**（前后同值）。

- **M8 收尾已可安全恢复**（`reports/m8ab-readback-bootb-20261031.md`）：`boot_b` 分段读回（6×16 MiB / 87 s）得到**完整 100 663 296 B**，sha `aedae5f1…` = **2026-10-31 当时的读回值**（当前在机值见 `DEVICE/README.md` §1.1 = vk172 `fb55997c…`）；`bootslot-b/boot_b-vk181-daily-signed-20261029.img` = `b72866ef…` 完整一致 ⇒ **可安全恢复**（`fastboot flash boot_b <vk181 件>` + 读回校验）。归档 `backup/HA2EXB0E-16+512/m8ab-restart-20261030/boot_b-readback-20261031.img`。**M8 v2 疗效仍未证实**（基线臂 3/3 无坏发，预注册规则触发停手）。
- **平板夜间通道 dry-run 通过（带 2 个差距）**（`reports/tablet-night-runner-dryrun-20261031.md`）：runner 原生 `DRY_RUN`（默认 RUN=0）、6 任务队列校验全过、截止盒 mock rc=0 无残留；`pi-tablet-night.timer` **enabled**（service static，工作目录 `/root/y700-elden`）；设备 8 核 / 可用 10.6 G / 根盘 12%。**差距**：① 设备 `/root/.config/pi-tablet-night.env` **已存在（96 B / 0600，2026-10-31 11:46）但 `USTC_API_KEY=` 与 `PI_MODEL=` 两个值均为空**（**凭据项，需用户填**，不由 agent 落盘）；② runner 收尾 `done=1` 计数显示 bug（不影响执行）。
- **greetd 关机卡死：修复已装且生效，但未验证**（`reports/greetd-stop-verify-20261031.md`）：设备实装 `TimeoutStopUSec=5s` + `ExecStop=/usr/local/libexec/elden/greetd.stop`（drop-in `zz-stop.conf`/`zz-elden.conf`，脚本 0755 且内容逐字等于方案）；**生成链仍缺 stop 语义**（`packaging/elden-userland/services.tsv` 无 stop 列、`tools/render.py` 0 命中）⇒ 根治三件套未落。判据 = 下次真关机 `Δ(Stopped−Stopping greetd) ≤ 5 s`（旧基线 **90.0 s × 6/6**）；**本轮不重启**，只算「P0 已生效」。
- **邮件分诊（窗口 10-30 03:17Z→10-31 04:50Z）**（`reports/mail-triage-20261031b.md`）：相关新来信 **2 封**、lore 核对 **11/11 命中**、「有新意见」**2/11**、取不到 0。**★状态更正（2026-10-31 12:5x 实测）**：wl2868c **v3 已于当日 11:42:57–11:43:00 CST 投出**（`[PATCH v3 0/3]`，Sent Items [208–211] + 本机 INBOX [15908–15911]），patchwork 侧 v3 三枚与 elden DTS 均在册（2 条 `new`/`needs-ack`、driver 一条 `handled-elsewhere`），**已收 sashiko 自动评审**；被 agent 误判为「待投」的部分（D4 / wl2868c v3 四枚）**以本更正为准**。① **M8 v2 ← Konrad**：「MDSS RSC is not part of MDSS itself」⇒ 草稿 `out/mail-20261031-b/re-konrad-mdss-rsc.txt`（**待批未发**，并含 v3 删 RSC）；② **wl2868c v3 ← sashiko 4 条**（High 是真 bug）⇒ 草稿 `out/mail-20261031-b/re-sashiko-wl2868c-v3-dts.txt`（待批）；③ Krzysztof 一项 = **按 2026-10-31 授权可由 agent 撰稿**（须披露 AI 辅助 + 证据 + 逐条回应），**投递仍待批**。补记 Marc Zyngier 10-26 13:53Z 纯确认信（M9 结论不变）。**★新发现（削弱 wl2868c「users」答复）**：v3 3/3 的 `&i2c10` 父节点 `qupv3_2`/`gpi_dma2` 在 `sm8750.dtsi` 里仍 `disabled` ⇒ wl2868c 运行时**根本不探测**，8 条 `*-supply` 指向的 regulator 注册不出来。
- **投递前静态门禁独立复跑**（`reports/code-boundary-preinject-20261031.md`）：**wl2868c-v2b 4 枚 = 可投**（checkpatch stdin 0E；elden.dtb rc=0/ERROR=0；`drivers/regulator/` W=1 rc=0；dt-doc-validate/dt-check-style 0 B；pristine 重放 3/3 终态一致）；**m3v5 2 枚 = 落盘形态不可直接投**（v5 对 pristine 不自足：直接 `git am` **FAIL rc=128**，须 v4×3 打底；且**目录无 cover** 说明依赖与 `usb_role_switch_at_endpoint()` 不在 7.3-rc7）。两批三问门通过、无占位身份/下游脏差异混入。**★方法论纠正已记 `PITFALLS #474`**：checkpatch 用文件参数会假报 ERROR，必须 stdin（既有 0E 可信）。文档漂移 3 处：tss 3/3 记「0E/2W」实测 **5W**、m3v5 0002 记「5 文件」实测 **4 文件**、wl 报告 tip/md5 已过期。
- **文档审计**（`reports/doc-audit-20261031-apply.md`）：2026-10-30 applylist 的 **18 条可机械条目已被 10-31 提交自然修好（仍在盘可机械应用 = 0 条）**；增量审计 **P0=0 / P1=1 / P2=2**。**P1 已由总管修**（`DEVICE/README.md` U2 表「`/`=f2fs @sda18」→ 改为指针到 §1.1 首条 + 分区列改为 `linux17` 192 GiB/§3.3）；P2 之 T19 行「回退 = 重启回 Alpine linux18」已补 `linux18` 已删注（PITFALLS 序号 59/69 重复属既有 DEFER，未动）。

### 2026-10-31 晚（续）：阻塞项调查 A 类三 lane + B 类窗口单

> 派工：总管 → 3×`code-boundary` + 1×`physical-exec`（`custom.ustc-pool/ustc-worker`，叶级不派 L2），**设备零动作**。
> 口径：阻塞按「缺什么」分 A（缺事实）/ B（缺一次人工动作）/ C（缺外部回包）/ D（已裁决不做）。本轮清 A 类 3 条，B 类合并成单窗口。

- **M8 = 「RSC/RSCC 不属于 MDSS 可复位域」成立**（`reports/m8-rsc-ownership-20261031.md` + §7 总管复核）：`RSCC` 在上游 qcom dtsi **0 命中**、mdss/dispcc `resets` 含 rscc **0 条**、`DISP_CC_MDSS_RSCC_BCR` 在 dispcc `0xc000`、vendor `sde_cesta` rscc reg `0xaf20000` **恰在 dispcc 窗口之外**。**Konrad 的 `apps_rsc@16500000` 例证是 `qcom,rpmh-rsc`（无关）⇒ 回信不沿用**。处置 = 0002 保留、0001/0003 各删 1 条 RSC 项；疗效 J5 仍需真机冷起 A/B。
- **M6 = ERR_INT_MASK0 可部分定名，但序列不可投**（`reports/m6-dsi-errmask0-20261031.md` §5）：bit16..19 = DLN0..3 HS FIFO overflow、bit20 随组无名、bit9 = cmd DMA FIFO underflow（**分组出处 = vendor `mask_error_intr()`**）；状态侧 `0x44440400` 与 mask 侧 `0x1f0200` 是两套编码。**新证否**：vendor `dsi_error_int_index` 是 ERROR_STATUS0 **状态位**编码（`BIT(14)`=underflow），不可当 mask 位表。**序列缺陷（新）** = `patches/local/b5-resoc-20261027/` 重放 `PASS=4 FAIL=1 WARN=2`：**0004 是裸 diff**（非 format-patch ⇒ 不能 `git am`/不能直接投）；**0005 与 0002 冲突**（0002 已改 `bonded->err_clear_bits`），且 `build/vk151` 终态 `err_clear_bits` **零命中**（被通用宏取代）⇒ **设计分叉待裁决**：建议保留 0002 表驱动，0005 只做命名。`0005` 注释已改为带出处、hunk 计数自洽。
- **M3v5 = 仍不能投（形态硬项）**（`reports/m3-v5-selfcontained-20261031.md` §6）：门禁对 pristine `24a19b953e` **FAIL**、对 v4 tip **`fd69bd54e3` PASS 2/2**（唯一 WARN = 缺 cover）；目录缺 `v5-0000-cover-letter.patch`、两枚缺 `base-commit:`；cover 草稿已出（`out/mail-20261031-c/0000-cover-letter.txt`，含 AI 披露，未发）。**更正**：`reports/code-boundary-preinject-20261031.md:63` 把 `34865c8915` 当 base 属**自指**（它是 v5 自身 tip）。
- **B 类 = 单窗口执行单**（`reports/device-window-checklist-20261031.md` + `scripts/device-window-collect.sh`）：7 条合并且**只需 1 次关机 + 1 次开机** —— T1 开机即采（11 门只读）→ T2 同一启动容器会话（C5-U7 相机预览 + C3 PI 三档）→ T3 唯一一次 `systemctl poweroff` 计时 → 次日 `--post-shutdown`。**W1 vk183 真 POR 已于 15:29 完成**（本窗口只复核签名）；**W5 上游 v4 上机 BLOCKED**（缺 v4 签名镜像 + 刷写放行）；W7（T11 BIOS）非本窗口。总管修 4 处：§0 计数矛盾、W2 回滚指向**已退役的 `zz-stop.conf`**（现停止语义由 `stop.tsv`→`render.py` 渲进 unit，回滚=恢复设备 `/root/greetd-backup-20261031/`）、采集脚本 Q28 签名 6→10 项、门禁 `git am` 误报。
- **两批上游投递已发（2026-10-31 23:01–23:03 CST，用户放行）**：
  - **M3v5** 3 封｜`<20261031150154.1106455-1..3@mail.ustc.edu.cn>`｜`/linux-usb/` 3/3、`/linux-arm-msm/` 3/3、patchwork linux-usb 2/2 `new`；raw 正文 sha256 与本地**逐字节相同**；**`/linux-devicetree/` 0/3 待复核**。
  - **M6/B5** 6 封｜`<20261031150305.1107572-1..6@mail.ustc.edu.cn>`｜`/linux-arm-msm/` 6/6、patchwork 5/5 `new`；raw 5/5 逐字节相同；**`/dri-devel/` 0/6（疑非订阅审核）**，与 M8 RFC 同症状。
  - 投递前形态修复：0004 裸 diff→format-patch、0001–0003 剥 `Lane/Agent/Baseline/Task` 记账 trailer、补 `[PATCH 0/5]` cover（明写不含 Q28 修复）；M3v5 补 cover + `base-commit`（正文零改动）。**cover 由我自己复核后改掉 3 处**：标题重复、shortlog 头重复、`Tested on the device itself` 的过强论断（改为 re-home 同一逻辑 + 三道门禁）。
  - 两处"发出了但归档不在"要盯：devicetree 若 24 h 后仍无，按 `upstream-mail-ustc` 技能查 vger 订阅/回执；dri-devel 需用户走 freedesktop 表单订阅（agent 不碰凭据/表单）。
- **新增可复用门禁**：`scripts/check-series-selfcontained.sh`（临时 worktree 序列重放 + `--self-test` 正负例）——M3v5 与 B5 两处形态缺陷都由它抓出；**此后任何系列投递前固定跑**（与 `PITFALLS #474`「checkpatch 必须 stdin」并列）。

### 2026-10-30 新增待办与并行安排


- **Waydroid 浏览器 `ERR_PROXY_CONNECTION_FAILED`（2026-10-30 已修并已固化）**：根因 = 容器全局代理指 `192.168.7.9:7897`，而宿主中继进程未运行（Bettbox `allow-lan:false` 只听 `127.0.0.1:7890`）。**固化已完成**：`scripts/systemd/host-net-proxy.service`（`Restart=always` + `ExecStartPre` 有界等 7890，脚本新增 `--foreground`/`--wait-upstream`/unit 接管时不再另起进程），已 `enable --now`；父代理独立复验 = 宿主 `curl -x` **204**、设备侧 `curl -x` **204**、`kill -9` 后 `NRestarts=1` 自愈；`Linger=yes` 已开（未登录也跑）。**未实测**：整机重启后自启（机制依据 = `is-enabled`+`default.target.wants`）。取证 `reports/waydroid-proxy-systemd-20261030.md`（原故障取证 `reports/waydroid-proxy-err-20261030.md`）。
- **droidloom 可行性规划（未证实，主机侧可并行；**已出规划** `reports/droidloom-feasibility-plan-20261030.md`）**：以 `RESOURCES/sessions/2026-10-26-denial-droidloom深度评估.md` 和 `reports/waydroid-droidloom-userland-interface-20261026.md` 为基线，核实上游当前版本、arm64 构建/发布、Phosh 的 linux-dmabuf v4 feedback 与 linux-drm-syncobj 要求、内核和图形接口、GMS/PI、相机/音频/传感器适配；给出不改现有桌面的隔离试验、资源成本与退出条件。用户要求规划，不预设替换 Waydroid。
- **设备优先收口**：M8 A/B 基线本轮用户现场判别 3/3 正常，首发有标准采样；原方案的坏发未复现，v2 疗效仍未证实。当前在基线臂，恢复日常镜像前读回备份超时且缺 32 KiB，已停止写入；先诊断链路并取得完整校验备份及 GPT 双表，再决定恢复，禁止把截断备份用于恢复。
- **双口反向接法**：见 `DEVICE/README.md` §1.4 与 `reports/artifacts/usb-reverse-20261030/snapshot.txt`；待低电量条件下复核充电功率和长时数据稳定性。
- **并行排产**：设备操作串行加锁；三条 2026-10-29 中断件（M3 / wl2868c / UEFI）已于 2026-10-30 **完成静态分诊并落盘**（不是任务收口——三者均有未证/待上机项，逐条见下文三行）。报告经父代理核对（数字与文件存在性）。后续按“设备一条 + 主机侧两条”排，新增 lane 均限定单文件报告与设备只读。任何上游发送另按批批准。
- **2026-10-29 中断产物的报告入口**（均为未完成/未验证件，不得当结论）：`reports/m8ab-build-20261029.md`（两臂构建，上机结果见下条）、`reports/uefi-closeout-20261029.md`（部分完成；主机侧续作 `reports/uefi-recovery-20261030.md`：M1/M3/M4 已完、M2 待上机、**E1 二进制身份与仓库 `PatchedBinaries` 不一致**未决）；`reports/m3-1-v5-20261029.md` 与 `reports/wl2868c-v2-20261029.md` 两份骨架已由对应 recovery 报告取代，见下两条。
- **M3-1 v5：零产出 → 上机 → 根因定位 → A–J/F1 落地 → binding 形状改定 → F2 上机（2026-10-30 全链）**（静态分析 `reports/m3-v5-recovery-20261030.md`；首次上机 `reports/m3v5-onboard-20261030.md`；A–J 修复 `reports/m3v5-fix-20261030.md`；binding 改定 `reports/m3v5-binding-reshape-20261030.md`；**F2 上机 `reports/m3v5-f2-onboard-20261030.md`**）。**★F2 上机结论**：`ucsi.c` 不再把 `-EPROBE_DEFER` 降级成 `NULL` 后继续注册（= 恢复上游语义；**上游本就上抛**，`置 NULL` 是下游 `usb_role_switch_at_endpoint()` 的副作用）⇒ 镜像 `m3v5-f2`（sha `072ddb9a…`）+ 部署 4 个 `.ko`（`typec_ucsi`/`ucsi_glink`/`dwc3`/`dwc3-qcom`；`dwc3`/`ucsi` 都是 `=m`，**只刷 Image 不算测过**）后：`/sys/class/typec/port0`+`port1`+`port0-partner` 注册完成、`dmesg` 中 `PPM init`/`failed to get usb role switch` **各 0 条** ⇒ switch 指针有效（F2 已把失败变成中止注册）；回归计数 0（`hexagonrpcd` 失败起于 11:26，早于本轮刷写，属既有）。**F3 不需要**：`ucsi_init_work()` 本就有 `-EPROBE_DEFER` 重试环（100 ms × 100 = ~10 s）。**★拔插实测（用户换边两次）= 绑定闭环**：`function_graph` 统计 `usb_role_switch_set_role` **12 次**，每次完整进入 `dwc3_mux_role_set [dwc3]` → `dwc3_qcom_set_role_notifier` / `dwc3_qcom_vbus_override_enable [dwc3_qcom]` → `dwc3_set_mode`，全程 **0** `WARNING/BUG/lockdep`、设备 SSH 不断（USB 数据未丢）、电池 `Charging`；12 次中无一次进 HOST（`dwc3_host_init`=0、无新 `xhci`）。**冷起（POR）复测同样成立**：`boot_id` 换新、`typec port0/port1/port1-partner` 在。**尚缺仅剩「仲裁明细」**（每口角色值）：函数图不带参数，已改布 arm64 带参 kprobe（`p:usbrole usb_role_switch_set_role sw=$arg1 role=$arg2` → 持久写 `/root/usbrole.log`，tracer=nop 已确认无噪声）⇒ **下次任何插拔自动落数据，不需专门安排一轮**。**投递件已就绪**：`patches/upstream/m3v5-20261030/`（pristine 重放，0001 仅 binding / 0002 仅 driver，两枚 `0E/0W/0C`，不含 `ucsi.c`），`reports/m3v5-pristine-replay-20261030.md`；**未投递**（按批批准）。
- **邮件分诊结论（2026-10-30，`reports/mail-triage-20261030.md`）**：近三日外部来信 **10 封**（Krzysztof 2 / Shuai Liu 4 / Bryan 2 / Loic 2）。要点：① **camss 2/3 被 Bryan NAK**（他实测 plane0 有 5 处物理断裂、0 处 IOVA 断裂 ⇒ 查 IOVA 却声称物理连续的判据被证伪）；② camss 3/3 获 Loic 形状建议（helper 化 + `v4l2_subdev_enable_streams`）；③ Bryan 明确 SM8750 camss enable 整块归 Hangxiang，我方只以 fix 形态存在；④ **M8 v2 与 sashiko 均 0 新回信**；⑤ **Krzysztof 对 wl2868c 三条硬要求**：逐条回应 v1 意见 / **“not with LLM”** / “still see no users”。**★口径更新（2026-10-31 用户授权）**：“not with LLM” 现处理为**必须如实披露 AI 辅助 + 逐条可复现证据 + 人工校对**（见 `out/mail-20261031/` 与 Sent[207]），**不再要求「人工撰稿」**；该要求的目标是「不产生 LLM 垃圾」，不是「禁用工具」。
- **wl2868c “no users” 已具备答复依据（2026-10-30）**：器件数 = 板 DTS 的 **8 条 `*-supply = <&camera_ldoN>`**（LDO7 扇出 3、LDO6 空置），且 v3 已把该 DTS 修到 **DTB 编译 rc=0**（原 rc=2）——即“消费者证据”现在成立。~~但回信必须人工撰稿，不由 agent 代写~~ **→ 2026-10-31 用户授权 agent 代为撰写并要求如实披露**：回信与 cover 均可由 agent 起草，**但必须（a）开头写明 AI 辅助（作者本人校对、内容/测量/决定归作者），（b）每条论断附可复现证据**（范例 = `out/mail-20261031/{re-krzysztof-wl2868c.txt,claims.tsv,self-review.md}`，已按此形态发出 Sent[207]）。旧「必须人工撰稿」口径**作废**。
- **UEFI 上机实测（2026-10-30，`reports/uefi-onboard-20261030.md`；总账 `reports/uefi-consolidated-20261030.md`、执行单 `reports/uefi-testplan-20261030.md`）**：两发对照定案：**E0-v0b（`ad450e28…`）不交棒**（`Booting OKAY [10.1s]` + fastboot 全程应答 + 槽位未变 + 卡联想 logo）；**A2-v0b（`a38bd563…`）真交棒**（`Booting FAILED usb_read failed`，USB 掉线）但 **UEFI 早期全静默**，~30 s 后回落 stock Android（`current-slot=a`、`slot-unbootable:b=yes`）。两枚 header 逐字段相同（`kernel_addr=0x10008000`/v0/4096）⇒ **「E0 不交棒」不是 header 问题，而是 ABL 对该载荷有额外拒绝条件**；壳头部差异 = `code0` `0x10000381` vs `0x10000501`（未证实因果）。**J1（屏上出字）未达成**；设备已恢复（`set_active b` → 15 s 回 Linux，`uname -v=#1 …11:22:59`、面板正常）。**下一发建议 N2-v0b（`90659a4d…`）**完成三点定位。
- **M3-1 v5 首次上机（2026-10-30，`reports/m3v5-onboard-20261030.md`）**：镜像 `boot_b` sha `55d06551…`、构建 0E/0W、两份 role switch 注册成功、双口数据+充电并存；**当轮连接器未绑定**（根因见下条）。
- **M3-1 v5 修复 A–J 已落地（2026-10-30，`reports/m3v5-fix-20261030.md`）**：独立树 `build/m3v5-fix`（与 `m3v5-daily` 19/19 逐字一致），**10/10 落地**（G-③ 按方案降级为“写明限制”）；两道门禁全绿（`dt-doc-validate` 输出 0 字节、`make -j6 W=1 drivers/usb/dwc3/ drivers/usb/roles/` 0 warning/0 error）；两枚补丁 `patches/upstream/m3v5-fix-20261030/`，在 `24223e44ad` 上 apply 后终态与 fix 树逐字节一致，`checkpatch --strict` 两枚均 0/0/0。关键落点：A `drd.c:556-585`（锁内只更新字段、解锁后 `pre_set_role`+`set_mode`）、**I `class.c:192` 改回 `if (sw)`**（即绑定根因报告的 F1）、H 删粘性 `error` 改 per-port 计数。
- **M3-1 两个新缺口（2026-10-30，未解）**：① **板级 DTS 与 v5 binding 形状不一致** —— DTS 用 `port@0/endpoint` + `port@2/endpoint`，binding `then` 要求 `port@0/endpoint@0+endpoint@1`，探针实测被拒。**父代理核准：`port@1` 已被 SoC dtsi 的 SuperSpeed 通路（`usb_dwc3_ss` → QMP PHY）占用，两个 HS 连接器只能分居 `port@0`/`port@2`** ⇒ **DTS 结构正确、binding 形状写错**，应改 binding 而非改 DTS（待拍板后落地）。② **补丁基线是 daily(`24223e44ad`) 而非 pristine**，0002 含「v2→v4 形状」重写内容，**投递前必须在 pristine 上重放 v4 三枚 + 本轮增量后重出**。另：复刻基点本身 `core.h` 是 `void pre_set_role` 而 `dwc3-imx/imx8mp/qcom.c` 仍是 `int` 版 ⇒ 基线 `make` rc=2/3 errors，已在 fix 树内最小对齐（不入补丁）。：上机后两个 mux role switch 已注册但连接器未绑定。静态定案：**不是端点不匹配**（DTB 双向 phandle 闭合，2/2 连接器都对）；断在「连接器→switch」的**一次性取用点** —— `ucsi.c:1860` 只取一次、无重试面，而本树把 `roles/class.c:187` 的 `if (sw)` 改成 `if (!IS_ERR_OR_NULL(sw))` ⇒ **把 `-EPROBE_DEFER` 降级成 NULL**，永久 no-op。修复优先级：**F1（必做，1 行）**改回 `if (sw)`；F2 让 `ucsi.c` 失败上抛而非置 NULL；F3 `ucsi_glink.c:323-325` 不无条件置 `usb_registered`、加有界重试。**不改 DTS**。同时**更正**上机报告 §1.2：`connector` 软链在 DT 平台永不创建（`typec/port-mapper.c:96-101`），不能当失败信号；另：`usb_role_switch_at_endpoint()` **不在 7.3-rc7**，上游化时须在 cover 说明。
- **M3-1 binding 形状已改定（2026-10-30，`reports/m3v5-binding-reshape-20261030.md`；绑定根因 `reports/m3v5-connector-bind-rootcause-20261030.md`）**：按用户裁定「DTS 结构正确、改 binding」落地——两个 HS 连接器 = **两个 port**（`port@0`+`port@2`）各挂一个 endpoint、`mux-state` 落在 endpoint；`port@1` 不能用作第二口（已被 SoC dtsi 的 SS 通路占用且上游 `snps,dwc3.yaml` 已定义）。探针矩阵：`boardshape` **PASS**、`n_dup0`（两口同 mux-state）/`n_extra`（非法属性）/`n_port1`/`nomuxprop` **全部 REJECT**（判据=诊断文本，见 `PITFALLS #471`）。补丁重出并分工正确：**0001 仅 binding（92+/40−）/ 0002 仅 driver（5 文件）**，两枚 `checkpatch --strict` **0E/0W/0C**、`make W=1 drivers/usb/{dwc3,roles}/` **0 warning**、pristine 重放 **rc=0 且终态逐字节一致**。**未上机、未投递**。**投递前构建/边界回归已过（2026-10-30 重派轮）**：`reports/m3v5-prefetch-regression-20261030.md` — pristine 基线（24a19b953e+v4×3+v5×2）上 G1 `W=1 dwc3/roles` rc=0 0W/0E、G2 全部 glue（18/18 `=m`，19 个 `.o`，`dwc3-hisi` 在 7.3-rc7 不存在=N/A）、G3 四符号使用点 10/7/5/13 且**漏改=0**、G4 checkpatch 0E/0W/0C×2+dt-doc-validate rc=0+DTS 形状 5/5、G5 独立复放 6/6 SAME（diff=0 B）⇒ **无需 `m3v5-20261030b/`**；仍差用户按批放行投递。工具链注意：`CROSS_COMPILE=aarch64-linux-gnu-` 必须显式传（缺省 rc=2 为工具链假故障）。 **★2026-10-30 23:38 上机 A1 = 未通过（启动期失联）**：候选（pristine+v5）经 `fastboot boot` 后 USB 全程不枚举、目视卡 OEM logo；用户强关后回 vk183，4 个 `.ko` 已复原（基线干净，`boot_b` 未动）。根因**未证实**：候选 `.config` 的 `dwc3/ucsi/phy` 均为 `=m` 而本次 initramfs 不含这些模块（cmdline 又带 `early_gadget=1`）是首要可疑点，叠加 pristine 缺下游 DSI；串口当轮未抓到（logger 主机重启后 23:43 才开，且 ACM0 自 10-24 起无内核输出）、pstore 空。复启条件见 `reports/m3v5-onboard-plan-20261030.md` §6.4（先验串口端口 + 内核/模块/initramfs 配套 + 独立 UTS）。 **★2026-10-31 10:26 第二发（m3v5-onboard-b）同样失败**：initramfs 已含 gadget 全套 14 个 `.ko` 且会主动 modprobe，仍 USB 零枚举、串口零候选输出 ⇒ **「initramfs 缺模块」假设被排除**；失败在更早环节（pristine 内核对 SM8750 平台基本启动即有问题的可能性最高）。判读：**pristine 血统内核不是本机的有效上机载体**（缺下游平台/显示补丁，且 ttyGS0 控制台与 SSH 同源，失联时无独立观测面）。**因此不再盲试 pristine boot**；v5 的行为证据以 daily 血统的 `m3v5-f2` 上机为准，pristine 系列只作投递形状/构建门。基线已整树回滚（1639 `.ko`、4 个关键模块 sha 回原件），`boot_b` 未动。
- **待拍板的投递动作**（邮件分诊 §3 D1–D6）：~~D1 camss v2（撕2/3、改 3/3 形状）~~ **✅ 已发（2026-10-31 12:11，`[PATCH v2 0/2]`，MID `<20261031041154.308030-1..3@mail.ustc.edu.cn>`，Sent [212–214]）**：2/3 整枚撕除（Bryan plane0 实测 5 处物理断裂/0 IOVA 断裂 + 判据错位 + hook 死代码）；3/3 按 Loic 形状重构（单 helper + `media_entity_remote_source_pad_unique` + `v4l2_subdev_*_streams`）；pristine 24a19b953e am 2/2 rc=0、camss 模块编译 rc=0、checkpatch 0E/0W/0C；报告 `reports/m4-camss-v2-20261031.md`。~~D2 回 Krzysztof 重锚定 camss~~ **✅ 已发（同日 12:11，Sent [215]，IRT `<fe9765cf-…@kernel.org>`）**，只澄清+fix-only 口径，不重发 enable、~~D3 回 wl2868c（人工）~~ **✅ 已发（2026-10-31 11:39，Message-ID `<179341794086.262379.12925109262126624772@mail.ustc.edu.cn>`，Sent Items [207] 回读；In-Reply-To 他的 `<20261029-amiable-loutish-wolf-60a76a@quoll>`；5 条意见逐条回应 + 8 条 consumer 证据 + 开头 AI 辅助披露（用户 2026-10-31 授权代发并要求如实说明）；稿与 claims/self-review 在 `out/mail-20261031/`）**、D4 wl2868c driver 系列（前置已解锁）、~~D5 patchwork 标 superseded~~ **✅ 已完成（2026-10-31）**：9 枚置 `superseded`（wl2868c v1 ×2、camss 0/3 ×3、dwc3 RFC v3 ×4），其余多数已由 patchwork 随新版本自动标；~~D6 吸收 Shuai Liu 的 icc 表 finding~~ **✅ 素材已出（2026-10-31）**：`reports/camss-icc-table-fix-20261031.md` + `patches/upstream/camss-icc-20261031/`（binding+DTS 收敛到驱动实际投票的 2 条；checkpatch 0E/0W/0C ×2、dt-doc-validate rc=0、mtp dtb rc=0、dt-validate 通过）。**归属 Hangxiang 系列，不由我方投递**。
- **wl2868c v3 四枚（**已于 2026-10-31 11:42 CST 投递**；投递前门禁见下行）**（诊断 `reports/wl2868c-recovery-20261030.md`、修复与门禁 `reports/wl2868c-v2b-20261030.md`）：原 15 条 phandle 错误已归零——从 `sm8750-mtp.dts` 复用 4 个 fixed-clock、补 `arm/qcom.yaml` 登记、**compatible 已改为 `lenovo,elden`**（与日常线树一致，用户 2026-10-30 批准）。**父代理独立复跑**：`sm8750-lenovo-elden.dtb` rc=0/ERROR 0（原 rc=2）、mtp 对照 rc=0、pristine 重放 3/3 且被改文件 md5 与分支 tip 逐个相同；checkpatch 1/3 与 2/3 **0E0W0C**、3/3 0E/5W（实测 5W，旧记 2W 已更正）、cover 0E/1W。**未上机**。细节 `reports/wl2868c-v2b-20261030.md`。**★投递事实与状态（2026-10-31 实测，Sent Items [208–211]）**：`[PATCH v3 0/3]` 四封 11:42:57–11:43:00 CST 已发出并回读到 Sent Items + 本机 INBOX；**`v3 3/3` 已被 `sashiko-bot` 自动评审命中**（INBOX [15912]，4 条，见 §5 2026-10-31 四 lane 轮）；**patchwork 侧仍 `new`**（sashiko 不改 patchwork state）。**v4 已出件（2026-10-31 下午，未投）**：`patches/upstream/wl2868c-v4-20261031/`（cover+4 枚，sashiko 4 条逐条落地：父节点 `qupv3_2`/`gpi_dma2` 使能、拆成 binding/driver/dtsi/板 DTS、删 gc08a8 与 sensor `power-domains`）；门禁见 §5「2026-10-31 下午」。**残留**：上游板 DTS 下 `i2c10` 探测未上机验证；`dt-validate` 余 2 行 `giantec,aac-*` 属性类型错待 gt9764 binding 落地。
- **wl2868c “上机”一项已作废（2026-10-30 核验，不需要单独上机）**：① 日常线**已含**驱动与消费者——`build/m1-73/drivers/regulator/wl2868c-regulator.c` 在位（⚠该树已于 2026-11-05 归档，源码路径改看 `patches/upstream/wl2868c-*` 或在 `build/daily` 同路径）、板 DTS 里 6 个 `camera_ldoN` + 4 个 `*-supply`（8 条引用）齐全；② 在机（m3v5-f2）实测：`dmesg` 有 `[camera] loaded wl2868c-regulator`，`/sys/kernel/debug/regulator/` 有 `camera_ldo1/2/3/4/5/7` 且 `regulator_summary` 电压正常（1128/1288/2816/2824/2808/1800 mV），相机出流早已可用 ⇒ **功能侧零缺口**。③ `patches/upstream/wl2868c-v2b-20261030/` 的 3/3 改的是一份 **202 行上游骨架 DTS**（新板提交用），与日常线 3178 行板 DTS 不是同一个文件 ⇒ **不能也不能靠它上机验证**。剩余只剩**投递动作**（已于 2026-10-31 11:42 投出，见上条）。
- **UEFI E1 二进制身份已澄清（2026-10-30）**：`reports/uefi-e1-identity-20261030.md`（session `TASKS/sessions/2026-10-30-UEFI-E1二进制身份.md`）。E1 内 UFSDxe = **dodge 件** `e76b555f…`（`E1-UFSDxe-in-FV-SEC2.pe32` 去掉 4 B `EFI_SECTION_PE32` 段头即逐字节相等，155 652 B），**不是** `PatchedBinaries` 的 `00ae059f…`；两者补丁集**不等价**（E1 件只改 2 点，缺第三点 `0x1b080` 的 IOMMU stub，且基座代次不同）⇒ **E1 成败不能解释「dodge 三补丁」**；且 E1-v0b 未交棒（usb 30/30 `18d1:d00d`）；**2026-10-31 独立复测 60/60 同结论**。顺带证伪「载荷含 UFSDxe ⇒ 会交棒」（A2 ✅ / E1 ❌）。
- **增量文档审计（2026-10-27→30）**：`reports/doc-audit-20261030-v2.md` + `TASKS/sessions/2026-10-30-增量文档审计.md`（当日 11:41 已有 `reports/doc-audit-20261030.md`，本件是续作，故 `-v2`）。计数 **P0 0 / P1 8 / P2 15**；本轮总管已修 P1-1（本行上一段的设备状态数字重复）；待处理：PITFALLS 索引悬空 `#418/#419/#471`、13 号段对 `## #NNN` 标题式条目空转、5 篇窗口内报告成孤儿、`RESOURCES` 备份死路径（`check-doc-assets` 不覆盖 `backup/`）。**应用清单 = `reports/doc-audit-20261030-v2-applylist.md`（25 处编辑已由总管应用，8 条 DEFER 见清单 §A-DEFER）**。
- **设备状态 = 指针（不在本节维护数字）**：唯一权威 = `DEVICE/README.md` §1.1（在机镜像/`boot_b` sha/`boot_id` 只在那里）。本节只保留两条不随镜像漂移的操作约束：**日常回退件 = `bootslot-b/boot_b-vk181-daily-signed-20261029.img`，但回退时必须同时拷回当时替换的 4 个 `.ko`**（M3-1 v5/F2 轮次；原件 `/root/m3modbak-20261030/`）；`bootslot-b/boot_b.img` 是随刷写变动的工作副本，**禁止当日常件**。
- **M8 续测结果（2026-10-30）**：基线臂 3/3 现场正常（1 发有标准采样）⇒ 坏发未复现、按预注册规则停手未刷 v2 ⇒ **v2 疗效仍未证实**；详见 `reports/m8ab-restart-20261030.md`。

### 1. 待调查（Open questions，按优先级）

> 编号以表内为准（Q27 从无此号；不在此写死连续区间）；**Q27 从无此号**（历史「G1-34 / §5 Q27」为幻影引用，已随 2026-10-10 清理移除）。

| ID | 未知 | 为什么要知道 | 怎么测（最小实验） | 关联任务 |
|---|---|---|---|---|
| ~~**Q22**~~ | ~~**vk34（2026-10-01）之后未逐版验证的内核增量**~~（5 文件：DTS 分级热 trip + `q6apm.c`/`q6prm.c`/`audioreach.c`/`q6apm-lpass-dais.c` + `config-vk40-bringup`） | 决定 G1 基线是否可信（曾是「AI 难以稳固推进」的核心） | ✅ **已无剩余动作（2026-10-26）**：「增量=熄屏复位源」已由 Q24 根因取代；最后一个子项 vblank/PPM 残留复核已闭合（三窗 47.5 min 全 0，见 §1 G1-23 行）。**三轮取证全过程只在 G1-23，此处不复述** | **G1-23**；`archive/topics/AUDIT-since-vk34-2026-10-03.md`、`AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md` |
| **Q21** | ~~桌面空闲熄屏（DPMS blank）→ 整机重启~~ **已归因（2026-10-07）→ 并入 Q24**（根因=单模块 `cambistmclkcc-sm8750`，**仍未根治**） | 与 DP/altmode（G1-9）不同源 | 已由 60+ 轮模块二分 + H1 实锤 | **G1-22 🟡 / Q24** |
| ~~**Q23**~~ | ~~Linux 侧 reboot→fastboot 的触发点~~ **已解决（2026-10-03 深夜）** | 已定 G1-24 路线 | **实测结论**：PMIC SDAM `reboot-reason@48`、`misc` BCB `bootonce-bootloader`/`boot-recovery` **均不被 ABL 采纳**；**PSCI SYSTEM_RESET2 vendor reset 被采纳**（`mode-bootloader=<0x80010001 0x2>`、`mode-edl=<0x80000000 0x1>`，无 recovery）。落地 = `elden/vk41-psci-reboot` 最小钩子（`psci.c`）；`reboot bootloader` → fastboot **实测成功**。EDL = TCSR DLOAD cookie（`qcom,dload-mode=<&tcsr 0x19000>`）。**2026-10-20：EDL 根因已定位并修好**——先前「本机不支持 EDL」的归因是错的：EDL 不走 reboot-mode magic，而走 `qcom_scm` 的 `download_mode`（TCSR `0x1fc0000+0x19000`）；我们 `sm8750.dtsi` 既无 `qcom,dload-mode` 也无该 TCSR 块 ⇒ 地址恒 0。已按原厂 DTB + 上游 kaanapali 三源对齐新增 `tcsr: syscon@1fc0000` 并挂 `qcom,dload-mode`（`patches/edl-dload-20261020/`，`dtbs` rc=0、`dtbs_check` 0 诊断），`eldroid-bootctl reboot edl` 改为真实实现；**真机 9008 触发未验**（需用户同意承担一次进 EDL）。另：槽位/计数已与 QTI `gpt-utils.h` 逐位核对等价，无需替换；TWRP 的 BCB 通道本机实测不被 ABL 采纳，不采用 | **G1-24**；`archive/topics/FLASHCTL-2026-10-03.md` §7–§9、`reports/twrp-parity-edl-dload-20261020.md` |
| **Q25** | **G1-29 路线 A 为何卡在 UFS 初始化**（**2026-10-21 口径升级**：不是单点，**至少两层**——① ~~`0x402` = 运行期注册表条目类型字段~~ **⚠ 已两次修正：10-24 §4 N1 先证伪「不存在运行期表」；10-29 反汇编定论 = 请求上下文偏移 0 的 opcode（`0x401..0x404` 分派表，链路 `0x401..0x404 → 0x12e90 → 0x13120`），崩溃点 = `ctx+4` 被当指针解引用（`0xD6ABB030`），全程 0 次查表；权威 = `reports/uefi-issue12-reply-final-draft-20261029.md`**（原「静态定位 config tag」待办作废）；② `UFS.c+2326` = `UFSSmmuConfig` 失败，修好 ① 仍撞） | 决定将来是否重启 UEFI 方向；当前**不阻断主线**（96 MiB 已由 G1-30 路线 C 解决） | 已发上游 issue `sunflower2333/mu_wide_platforms#12`；**剩余只有两件可做**：回帖上游给出「`0x402` 不是 config tag」的结论（10 min，零成本）/ 等上游 SM8750 UFS SMMU 修法。**裁决：维持搁置**（复起需先重下 2.3 G 资产 + 估计 1–2 周，收益已被 kexec 覆盖） | **G1-29（已搁置）**；`reports/uefi-restart-20261021.md`（§A 实测取证、§B–§D 裁决）、`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` |
| **Q24** | **桌面熄屏（DPMS off）→ 整机硬复位/断电** |**⛔ 关闭·不值得取证（2026-10-24 用户裁决）**：**不再做任何取证**（含原保留的 `vk149` 臂复现，**取消**）——根因已指名且日常线免疫，继续取证无判别力、只浪费时间。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行443-Q24.md`⟫ | 装相机模块后长时空闲不断电 | G1-22 / G1-33、`PITFALLS` #197–#212 / #282–#289 / #294–#295、`reports/q24-suspend-hypothesis-excluded-20261019.md`、`reports/q24-n5-vk64-death-reproduced-20261015.md`、`reports/q24-n7-vk127-20261017.md`、`scripts/n5b-vk64-death-rate.sh`、`scripts/cam-mode.sh`；上游同源工作与判据陷阱 → `reports/mail-triage-20261019.md` §2.2/§3.4（Abel genpd boot floor、Konrad clk-dvfs 16/16、Joonhoe Kim）；dispcc runtime 残留实测 + Joonhoe 联系 → `reports/joonhoe-kim-contact-20261019.md` |
| **Q26** | ~~WiFi 关联后 IPv4 约 140 s、每 16–18 s 周期掉线~~ | ✅ **已关闭（2026-10-10 用户实机确认 WiFi 正常，关联即可用）** | 已无需再测（关闭项不从「怎么测」再取样本） | 历史排查全文 → `archive/topics/history-chain-tasks5-20261014.md` §Q26 |
| **Q28** | **面板 init 间歇失败 → 只有背光无桌面**（在机 `boot_b` 口径**只在 `DEVICE/README.md` §1.1 维护**；此处不再写死镜像号——历史上写死过 vk163/vk173，均已过期） |**🟢 已规避·结项（2026-10-24 用户裁决，补采样门槛按裁决作废）**。当前口径（2026-10-12 深夜，权威仍在本行）：**坏发 ~50%、逐启动随机、按时间成簇（会话级）**，**与镜像/构建身份无关**（旧「构建身份伪影」定案**作废**）。七臂 vk116–vk123 全部否证；**故障态不在 DSI 控制器内部**；恢复只能整机复位；日常靠看门狗兜底（~50%→~75%）。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行445-Q28.md`⟫ |MDP_BUSY|DSI_BUSY` 自锁、`CTRL.ENABLE=0`）、`CLK_STATUS=0x23f`（**无 DYN 位、PLL 未失锁**、`dsi_isr` 恒 0）⇒ 「故障态不在 DSI 控制器内」「DYN pclk 域闩住」两条旧口径**削弱/本发不成立**；「恢复只能整机复位」**机理改写**为软件闩锁所致。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行445-Q28.md`⟫ | 冷起后 `card0` 在 + 面板实测有画面（非仅背光） |`reports/q28-DOSSIER.md`（SSOT）、`reports/q28-INDEX.md`（文档地图）、`reports/q28-dsi-recover-20261012.md`、`reports/p1-upstream-dsi-20261013.md`、`reports/p2b-retest-20261014.md`、`scripts/q28-watchdog.sh`、`scri ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行445-Q28.md`⟫ |grep -c 'psci: SYSTEM_RESET2'` = 0 可作「本发是真 POR」的硬判据。累计 vk151/vk152 线 **3 发真 POR 全 GOOD**，距判据 ≥8 发还差 **5 发**（`scripts/q28-por-rounds.sh 1 2400 <N>`，boot_b 已是 vk152 无需 fastboot）。 ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行445-Q28.md`⟫ |
| **Q31** | ~~M1 7.3-rc7 重基树「管道全绿但面板只有背光」~~ | ✅ **已解（2026-10-14，E1b）** | **E1b = 把 `writel(0xc0, PLL_SYSTEM_MUXES)` 放进 `dsi_7nm_phy_enable()` 预置块（refcount 语义原样不动）** ⇒ 干净 POR 发 L1=0/L2=0、`dsi_isr`=41、phoc/phosh/wayland 在、**面板有内容 + 触屏可操作**；净差异 vs 上游 7.3-rc7 = **1 行语义**（E1 的 refcount 变更废弃）。根因 = 上游 `44784327815b` revert 了 `93c97bc8d85d "dsi: fix PLL init in bonded mode"`（elden = bonded 双 DSI）⇒ `PLL_SYSTEM_MUXES=0xc0` 永不写入；上游提交走此 1 行版。 | 同窗口日常 `vk94` 对照仍是判据基线；`reports/m1-73-e1b-pllfix-20261014.md`、`reports/m1-73-e1-pllfix-20261014.md`、`reports/m1-display-rootcause-analysis-20261014.md`、`patches/m1-73-e1-pllfix.patch`；历史口径 → `archive/topics/history-chain-tasks5-20261014.md` §Q31；**M1 / §7**；**★机上验收（2026-10-14）：M1-7.3 功能基线 `out/boot-elden-m1-baseline.img`（sha `1254324a…`）零写盘一发通过** —— `Run /init` **7.67 s**、L1=0/L2=0、`card0-DSI-1` connected、phoc/phosh、`wlan0` 关联（−48 dBm）、**用户实机确认面板有内容+触屏可操作**（`reports/trials/20261014T115840Z-m1-baseline.json`、`sessions/2026-10-14-m1-73-baseline-onboard.md`） |
| **Q1** | **容器内的 GMS 身份/Play Integrity/Widevine 能做到哪一级**（不作废猜测，先取证） | 决定 G2 兼容上限与是否需要 VM/换路线 | 复现社区三条做法各一次（只变一个变量）：① Waydroid + GApps；② 未认证设备注册流程；③ Widevine L3 库注入。**社区侧**：arm64 GAPPS 有、**L3 仍仅 x86-64**（`waydroid_script` 源码核实：arm64 仅 A11 有 prebuilt）。**本机取证**：GMS 登录 ✅、Google 连通 ✅、**Widevine 不存在**（只有 ClearKey）、build=`test-keys`/userdebug ⇒ 不加对策 PI device 必失败；2026-10-26 lane F 复核确认 J2=FALSE 且 STRONG 结构性否证（无 TEE、keymaster 4.0 软实现）。清单与证据见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行411-Q1.md`⟫ | **C3** |
| Q2 | ~~Waydroid 在 **vk40** 上是否不再需要旧 workaround~~ **✅ 已答（2026-10-11，vk64）：仍必需。** 去 workaround 后容器只有链路路由、无 default；`ip rule` → `Operation not supported`（`CONFIG_IP_ADVANCED_ROUTER` 仍 not set）。要根除需开该 config（连带 `IP_MULTIPLE_TABLES`）重编内核。**🆕 2026-10-11 vk95 已开该 config：`ip rule` 上机生效（`local/main/default` 三表），内核侧根修完成；容器端到端（去 workaround 出网）待 Q28 GOOD 启动复测**（见 `reports/c1-iprule-vk95-20261011.md`）。附带发现：vk64 部署模块目录缺 `net/` 核心模块（bridge），已补（`PITFALLS #184`）；模块化 ramdisk 管线也已补齐 net/veth/fuse | 少一处 bind-mount 脆弱点 | 已实测（§C1 行） | **C1** |
| Q3 | **droidloom**（Linux 原生跑 Android 应用，Wayland 直出窗口）在 arm64 宿主是否可用 | 形态优于容器（无需 Android 镜像） | **已查（2026-10-02）**：声称支持 arm64+x86_64，但**发布包只发 x86_64 Arch**；INSTALL 的 "experimental ARM64" 指 **x86 宿主跑 ARM64 APK**（Digitalis/Berberis 翻译层），不是 arm64 宿主。**🆕 2026-10-26 深读（README/architecture/runtime-layout 契约/KNOWN_ISSUES/补丁清单）**：arm64 宿主确实是**一等产品配置**（`android/device/droidloom_arm64/`：`kgsl_dma_heap` 与 `drm_dma_heap` 两种图形后端、Panfrost v11/Turnip、audio APEX、cgroup 描述），上游在 **OnePlus Pad 4** 上跑 Android 17（Play 登录、装游戏、属性投影经 getprop+分区文件双读验证）⇒ **Q3 原两点未知已收窄**：① 自构建仍是唯一路径，但编的是已知可用的 aarch64 产品（pacman 包需转本 rootfs）；② **freedreno 路径不再未知**，但**新增硬门槛**：presenter 要求合成器支持 `xdg-shell`+`linux-dmabuf` **v4 feedback**+**`linux-drm-syncobj`** ⇒ **Phosh/Mutter 不满足**，只 Denial 或带 syncobj 的 wlroots 行。另：宿主无 Android SELinux LSM ⇒ binder SID 走 PID-context 回退（安全边界=宿主沙箱），**PI/Widevine 官方明确未验证**（Moto cell 上 Play 显示未认证）。**结论：仍只跟踪**（R1 未受阻，且比 Waydroid 多一个合成器前置）。可搬资产见 `../RESOURCES/sessions/2026-10-26-denial-droidloom深度评估.md` §4 | 观察（R1 受阻再试） |
| Q4 | **无 KVM 前提下 VM 路线值不值得投**（**书面评估已完成 2026-10-02**，结论见 TASKS C8） | 决定要不要开第二条腿 | 结论：**维持低优先**。① 设备侧 KVM 不可达（XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 只适用 Qualcomm dev kit，ABL 重签救不了——hyp 加载点在 ABL 上一级）；② 独立 gunyah 驱动（v17）未进主线（本地 7.2 树 `drivers/virt/` 无 gunyah 目录）；③ 唯一新路线 = KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`），WIP（pinned pages/无 guest_memfd/禁 swap）。**决定性上机实验**：vk40 起机后 `dmesg \| grep -i gunyah`（本地 qcom_scm 已带 gunyah UUID 探测）——通则路线第一步成立，败则归档 | **C8**（🟡 书面结论已出；**2026-10-25 终结 = 不可行，见 §4 N2 终局裁决与 `reports/gunyah-decision-20261025.md`**） |
| **Q5** | **真 Android 对照基线**（一旦覆盖 a 槽就不可复得）：GMS 属性 8 段、Widevine 级别、7 颗传感器读数曲线、目标 App 行为 | 兼容层的"标准答案"，也是判定容器是否等价的尺子 | ✅ **主体已采（2026-10-11，U2 a 槽 stock，报告 `reports/c0-android-baseline-20261011.md`）**：`getprop` 全量、Widevine **L1**（`dumpsys IDrmFactory/widevine`）、42 传感器清单、分区/包、AVF apex、账号（0）。**剩**：30 s 传感器 CSV、5 App 录屏（均为 App 行为项，与 root 无关）。**PI 判定不属本基线**（对象 = Waydroid 容器 → §2 C3）。U1 a 槽（stock+root）可另采；root 专属项已判定无产出、不补采（2026-10-13） | **G2/C0**；`backup/HA2EXB0E-16+512/c0-baseline/` |
| Q6 | 兼容层验收的**量化判据**——**已定稿（2026-10-02，A15）**：10 条用例+阈值见 `README.md §6` §5 | 避免"看起来能用"的自欺 | 上机后按用例表逐条实测打分（打分模板同处） | **C9**（模板就绪） |
| Q7 | ~~Linux 分区到底要多大~~ **已解决（2026-10-03 G1-2）** | GPT 手术一次给足，避免二次缩容 | 实测划定：`linux17`=193 GiB（CRC 校验过），估算表在 `../DEVICE/README.md` §3.1 | G1-2 ✅ |
| Q8 | ~~音频是否真的可听 + 有无录音通路~~ **已解决（2026-10-04 G1-4）** | G1 硬验收 #4 | 实测：`amixer cset numid=8 on` 后扬声器出声 ✅；`arecord -D hw:0,2`（AMIC1）采集 ✅，UCM2 Mic | G1-4 ✅ |
| Q9 | ~~相机能否真正出流（graph ENABLED ≠ 有帧）~~ **已解决（2026-10-05 G1-5）** | G1 硬验收 #5 | 实测：前后摄 `v4l2-ctl --stream-mmap` 连续出帧 rc=0，帧尺寸精确吻合 | G1-5 ✅ |
| **Q15** | **解锁 U2 的两个不可逆代价**：① Widevine **L1→L3**（现 `sys.lenovo.widevine_security_level=L1`，属 TEE 内密钥，社区主流案例为永久降级）——它正是 Q1/Q5 容器侧 DRM 上限的「标准答案」；② 保修 + FOTA。**两台单元现均已解锁**（U1 2026-08-16 / U2 2026-10-03；U2 实机现 `flash.locked=0`） | 先拍基线再解锁，否则事后无法对照；且影响 G2 的 U5 用例上限 | ✅ **已执行（2026-10-03）**：`scripts/bl-preunlock-evidence.sh HA2EXB0E` → `backup/HA2EXB0E-16+512/pre-unlock/`（getprop 全量/by-name/传感器清单/settings/Widevine=L1 + SHA256SUMS）；解锁后重测同一项做对照 | **G1-0**、Q1/Q5 |
| **Q32** | **暖起（warm reset）与冷起（真 POR）的差异到底在哪** —— 为什么同一内核/DTB 的显示结果会因复位深度不同而不同 |✅ **已结项（2026-10-24）**：五发判据表已成（W1×2 / C1×2 / W2×1 全 GOOD、无入口差异）⇒ 并入 Q28，不再单列。以下为 10-23 立项记录：现状证据是**零星且互相矛盾**的，尚未系统化：① `PITFALLS #166`（2026-10-10）： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行457-Q32.md`⟫ |**怎么测（最小实验，两阶段）**：**(A) 复位深度序列**（同一镜像 vk152，固定同一台、同一起点）：`warm(reboot2 bootloader → fastboot boot/或直接起 boot_b)` → `warm2` → **物理 POR** → `warm3` 交替，至少 3 组 × 2 深度； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行457-Q32.md`⟫ |**★2026-10-23 静态预研已落盘**（`reports/q32-warm-vs-cold-preresearch-20261023.md`）：① 现有证据**自相矛盾**（`#166` 暖复位→NOCARD vs vk150 暖复位 2/2 GOOD；POR→STORM vs POR 5/5 GOOD）⇒ 「暖必坏/冷必好」都不成立，判据只能是「**同一深度内是否一致**」； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行457-Q32.md`⟫ | | **判据**：能否给出一张「复位深度 × 显示结果 × 残留寄存器」的表，且**同一深度内结果一致**；若同一深度内仍随机 ⇒ 暖/冷不是主变量（回到 Q28 的时序竞态）。 |**关联**：Q28（本行上方）、`PITFALLS #166`、§4「迭代通道」条的 kexec（同属「继承态」问题）、`scripts/q28-clkdiag.sh`、`scripts/q28-devprobe.sh`、**`scripts/q32-boot-evidence.sh`**（Q32 判据取证）、**`scripts/q32-arm.sh`**（W1/W2/C1 单发执行器）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行457-Q32.md`⟫ |
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
| 面板 init 间歇失败（只有背光） | 收窄：**只有开机首次 modeset 触发**（80 轮 DPMS 上电循环 0 命中）；机制候选=首次上电被吞错 + ABL 遗留态（`research-q28-dpu-powerup-race` / `2026-10-09-Q28-密集复现与vk74`） | **温启跑 vk74**（`fastboot boot out/boot-elden-vk74-q28power.img`）看是否自报 `power-up failed -X`；无自报则去 `clk_ignore_unused` 单变量 | Q28 |
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
| **R3 原生** | droidloom（Wayland 直出窗口，shared-kernel；Denial 合成器同栈） | ✅ 形态最优雅 | 🟡 aarch64 产品已一等（OnePlus Pad 4 真机跑通）但**仍无发布包**；**新增硬门槛：宿主合成器需 `linux-dmabuf` v4 feedback + `linux-drm-syncobj`**（Phosh 不满足）；更早的阻碍是 R1 本身未受阻 | **只跟踪上游**（Q3，R1 受阻再试） |
| （相邻）| Win-x86 转译 Box64+Wine | ✅ | ✅ **PoC 已成功** | 已交付，与 R1 共用 chroot/防护范式 |

> **为什么容器优先**：它是唯一"不重启、不离开 Linux、能用我们自己的 GPU 驱动栈、可单独卸载"的形态；
> 且社区在**纯 Linux 宿主**上把 GMS/Widevine 做进容器的先例最多（`../RESOURCES/README.md` §1.3）。

---

### 1. 兼容度评估（5 维，**分数随实测更新**，当前为初始估计）

| 维度 | R1 Waydroid | R1' redroid | R2 VM | R3 原生 |
|---|---|---|---|---|
| C1 功能兼容（App 能装能跑，含厂商 App/游戏） | 4 | 4 | 4 | 3 |
| C2 身份兼容（GMS 登录、Play Integrity、Widevine） | **待调查**（社区有做法，本机未测） | **待调查** | 待调查 | 待调查 |
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
> **★当前一页 = `reports/upstream-status-20261105.md`（2026-11-05，取代 `-20261029`）**：逐系列状态 / 归档复核（patchwork，非 cover 计数）/ **我方欠什么** / 复启条件。
> **未答项（2026-11-05 现查）**：11-04 批次 sashiko-bot 回 **2 High + 8 Medium**（dwc3 3/3 两条 High 优先：mux init 竞争/teardown 顺序、port-role 状态撕裂）；Krzysztof 两条 changes-requested（**v6 5/5 并入 4/5**「one logical action, one commit」、3/5 commit message 改写）⇒ 下一次发信前先答。
> **归档复核口径（2026-11-04 起）**：lore `/<list>/<mid>/raw` 返 Anubis 挑战页（HTTP 200 但非原文）⇒ **不得**用 `/raw 200` 当作档证据；一律 **patchwork API** + 按 MID 取 lore `/T/` 线程页，且「N/N 命中」口径 = 「非 cover N/N」。

> 审查已完成（2026-10-04，只审不改）：payload=相对主线 v7.2 的 **125 改 + 11 新文件（≈12.4k 行）**，
> 分级 A/B/C/D 与推进顺序见 `archive/topics/UPSTREAM-REVIEW-2026-10-04.md`。机械检查全净
> (checkpatch/DTC/dt-validate 仅 1 红点=usb@a600000)。
> **上游化规则/违例清单/下游隔离清单 = `reports/upstream-policy-20261013.md`**；M3 分片与验收口径 = `reports/m3-series-plan-20261013.md`（三问门 + 强制框架表 + Q3 违例 + 薄下游层预算）；本节维护 M1–M9 状态（**各 M 行内文即权威**；当前一页 = `reports/upstream-status-20261105.md`（取代 `-20261029`），含逐系列状态 / 我方欠的动作 / 两项必须先处理的非技术事件 / 邮件与 patchwork 工具事实。`reports/upstream-status-20261027.md` 是 10-27 快照、**已过期**，其 M4「未投」与 M8「等回包」均已被 10-28/10-29 动作推翻）。**M6/M7 = 把 Q28/Q24 按上游标准重新定义后的立项（分层、判据、动作）见 `reports/upstream-q24-q28-standard-20261015.md`（2026-10-15）。**
> **投递口径（2026-10-27 更新）**：**按系列逐次由用户批准**——2026-10-13 的「全面投递冻结」自 2026-10-19 起逐案放开（M6 L1 → M8 RFC → M9 → M3-1 v4 → M4-1），未批准的系列仍只做备料。投递口径的历史页 = `reports/upstream-status-20261026.md`、`-20261027.md`（**当前一页 = `-20261105.md`**；`-20261026/-20261027/-20261029` 均降为历史快照；旧冻结文与「唯一例外 = M3-1」已作废）。

| ID | 任务 | 状态 | 依赖 | 判据 | 证据 |
|---|---|---|---|---|---|
| M1 | 干净上游资产树（upstream tip + payload 重放，剔除 D 类与 vk 历史） |⚠️MIGRATION-LOST(2026-10-17：`build/` 与 `m1/*` refs 未随迁，本行所有树路径已失效，需重放) 🟢 **树已建、干净构建通过（2026-10-11）**： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行691-M1.md`⟫ | — | 树能编出 vk 等价功能镜像 ✅（构建）；上机对照待做（**2026-10-13 晚起已上机 bringup + 上游显示栈对照 P1–P2c，见下方专节**） | `reports/m1-clean-tree-20261011.md`、`.pi/plans/2026-10-10-M1-资产树清单.md`、审查档案 §4 |
| M2 | 首发小系列 A1(GC 块)+A2(battmgr)（**A1 已撤稿=与上游重复；A3 重分类**） | 🟡 **A2 在评审**（battmgr → linux-pm/linux-arm-msm/lkml 已归档）；**A1（DPU GC 块）2026-10-13 已发撤稿回复**——与已在 msm 树的 `3389406e6a03`（Rob Clark，2026-09-30，v7.4）**重复**；**新增 P3 `drm/msm/dpu: reject undersized gamma LUT blobs`（修 sashiko 指出的 OOB 读，2026-10-13 10:04 已发）**：基线 upstream **v7.3-rc7**，`patches/upstream/m2-2026-10-13/`；checkpatch `--strict` 0/0、两目标文件编译干净、收件人 dry-run 通过 | M1 | 发至对应 ML 获 review（+lore 复核） |`patches/upstream/m2-2026-10-13/README.md`；**A3 更正 = 上游 `aw86927.c` 无 firmware 波形装载路径（882 行）⇒ 窗口放宽无对应代码可修，重分类 B/C 不进 M2** ； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行692-M2.md`⟫ |
| M3 | 板支持系列（DTS+binding 随行；拆片见 `reports/m3-series-plan-20261013.md`） |​**★2026-11-06 已投（用户放行「都开始」，`[PATCH v8]`）**：① **dwc3 `[PATCH v8 0/3]`** 4 封全 250，cover MID `<20261106114208.987284-1-xiaqinghuan@mail.ustc.edu.cn>`，patchwork linux-usb 3/3 + arm-msm 3/3 在档；② **wl2868c `[PATCH v8 0/2]`** 3 封全 250，cover MID `<20261106114252.988023-1-xiaqinghuan@mail.ustc.edu.cn>`，arm-msm 2/2 在档。**两系列发信前已重基到 torvalds master `f66469d9905b`（7.4-rc2 线）并重跑全部门禁**；首轮（11:28/11:30）因 `format-patch` 漏 `-v7` 致逐枚 Subject 无版本号 ⇒ **11:42 以 `-v8` 正确重投**（内容逐字节不变，cover 已写明）。**sashiko 已对首轮 `2/3 usb: roles` 与 `3/3 usb: dwc3` 回「found no issues」**（`<sashiko-outbox-201319@kernel.org>`/`<sashiko-outbox-201328@kernel.org>`）⇒ 11-04 两条 High 的修复被机器评审确认。投递记录 `out/mail-20261106/REPORT.md` |**★2026-11-06 v7 备料（已投，见左侧最新条）**：① **dwc3 `m3-dwc3-v7-20261106`** = 11-04 批的 `[PATCH v7 0/3]`，**只答 sashiko 两条 High**（端口/角色撕裂 → `dwc3_set_mode_port()` 原子发布；init 拆除顺序 → `mux->ready` 门控 + 反注册后 drain + 不再清 `role_mux`），1/3、2/3 零变化，3/3 +92/−11；② **wl2868c `wl2868c-v7-20261106`** = `[PATCH v7 0/2]`，**板 DTS（v6 4/5+5/5）整段拆出**（Krzysztof「one logical action」+ sashiko「骨架板 DT」+ VIN 父 supply 三处同向），只发 binding+driver，driver 修 sashiko 三条 Medium（`chip->enabled` 种子化 / `vsys` 使能 / `disable()` 写成功才提交）；板件存 `held-back/`。**顺带查实：v6 4/5 对声明的 base 不可 apply**（插入点写了 `sm8650-valve-deckard`，而 v7.3-rc7 无此行）⇒ 那一版 4/5 在干净树上必然失败 |**★2026-10-31 v5 已投递**（用户放行）：3 封 `Result: 250`，Message-ID `<20261031150154.1106455-1..3@mail.ustc.edu.cn>`（cover + 1/2 + 2/2，`In-Reply-To` 串到 cover）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行693-M3.md`⟫ | M1 | 每片过 `dtbs_check`（自带 binding）+ `dt-doc-validate` + `checkpatch --strict` |`reports/m3-series-plan-20261013.md`、`patches/upstream/m3-2026-10-13/`；**M3-1 v3（2026-10-19 C0）**： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行693-M3.md`⟫ |
| M4 | 大件立项：B8 camss（media）/ B6 ath12k PEACH（wifi）/ B3 hci_qca PERI（bt） |🟢 **M4-1（bindings）已投递并归档（2026-10-27，用户解冻投递）** —— 两线程：① **media 2 枚**（`gt9764` VCM + `s5kjns` 传感器，`[PATCH 0/2]`， ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行694-M4.md`⟫ |csid` 0 条、BUG/WARN 0），但 sashiko #4「多 RDI 累积位」**未被判别**；② 对照上游 **v6**（8/8 取到）与 **v23 Kaanapali**（10-28）： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行694-M4.md`⟫ | M1 | 各成多轮 review 工程 | `reports/m4-camss-project-20261013.md`、`reports/m3-6-wireless-slice-20261013.md` | **★2026-10-29 20:31 三枚通用修复已投递并归档**（用户批准）：`[PATCH 0/3] media: camss: three fixes for the CSID power and VFE streaming paths`，Message-ID `20261029123107.28705-1..4`，4 封 250、lore `/all/` 4/4 HTTP 200（封面 Subject/From 逐字核对）；门禁 = pristine `git am` 3/3 + checkpatch 3/3 0E0W0C + camss 目录 `W=1` 0 warning（`patches/upstream/m4-camss-fixes-20261029/GATES.md`、`SENT.md`）；**未上机**（2/3 改变缓冲校验行为）。 **★2026-10-31：v2 0/2 已投并归档**（用户批准）：`[PATCH v2 0/2] media: camss: CSID power-on unwind and VFE stream handling`，MID `20261031041154.308030-1..3`，3 封 250、lore 命中；**2/3 整枚撕除**（Bryan plane0 实测 5 处物理断裂/0 IOVA 断裂 + 判据错位 + `prepare_buffer` 死代码），**3/3 按 Loic 形状重构**（单 helper + `media_entity_remote_source_pad_unique` + `v4l2_subdev_*_streams`）；pristine `am` 2/2、camss 编译 rc=0、checkpatch 0E/0W/0C；报告 `reports/m4-camss-v2-20261031.md`。同日 patchwork 9 枚旧件标 `superseded`；Shuai Liu 的 icc 表 finding 已出 fix 素材 `patches/upstream/camss-icc-20261031/`（**归属 Hangxiang，不投递**，见 `reports/camss-icc-table-fix-20261031.md`）。
| M5 | C2 dm-default-key 从上游包剥离 → 持久根 out-of-tree patchset | 🟡 **立项完成（2026-10-13）**：静态取证推翻本行原前提——`dm-default-key`（457 行）+ `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED` 兼容层**一直在 vendor 血统树**，但三份在用 `.config` 对 `DM_DEFAULT_KEY` 零命中 ⇒ **现状是树内死代码，剥离零运行时风险**；上游 7.3-rc7 自带替代品 **`dm-inlinecrypt`**（620 行、支持 hw-wrapped）⇒ 推荐 *能力用上游、patchset 封存*。需求判定与候选比较见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行654-M5.md`⟫ | — | 上游包内无 Android vendor ABI | 同上 §1-C |
| **M6** |**Q28 上游化 = B5 DSI per-SoC cfg 重构（含 E1b 1 行）+ 协作**​**★2026-11-02 已回 Dmitry 四条（承诺 v2 在 torvalds master 重切），见 §7 头 11-02 批次**​**★2026-10-31 已投递**（用户放行）： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ |BIT(9)` 并注释来历 + 厂商 `mask_error_intr()` 同形）。落地 `patches/local/b5-resoc-20261027/0005-dsi-name-fifo-error-bits.patch`（+24 −9），**等价证明 = `dsi_host.o` 的 `.text` 逐字节相同**（23 048 B / 23 048 B）， ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ |（2026-10-15 立项；定义 = `reports/upstream-q24-q28-standard-20261015.md` §2） |🟡 **≈35%**：**L1** ✅ **已投递（2026-10-19，用户解冻）** `<20261019130041.305805-1-xiaqinghuan@mail.ustc.edu.cn>`，`/linux-arm-msm/` 已归档；原件 `patches/upstream/m1-2026-10-14/0001`（机上已验 L1=0/L2=0 + 目视确认）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ | M1（M1 树）、上游四问答复 | ① P1–P3 对 Q28 **行为中性**且可机械验证（P2/P3 与 P4 分离 + 同会话交替采样）；② P4 有明确归属且改动后重跑 Q28 冷起风暴；③ L1 补丁达上游门（checkpatch `--strict` + `git am`）；④ 包内无 Q3 魔数与诊断钩子 | `reports/b5-dsi-resoc-20261013.md`、`reports/upstream-q24-q28-standard-20261015.md`、`archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md` |**★2026-10-27 RFC 备料完成（只备不发）**：`patches/upstream/m6-b5-p4-rfc-20261027/RFC-SCOPE.md` —— 核实出三条可引用的上游事实（bonded 支持只在时钟/PHY 层；`CMD_DMA_CTRL.BROADCAST_EN` 位**已存在于** `dsi.xml` 但驱动从不置位； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行696-M6.md`⟫ |
| **M7** | **Q24 上游协作 + 外部测量**（2026-10-15 立项；定义 = 同上 §3） | 🟢 **2026-10-23 结论：不需要我方补丁** —— 根因 = 上游 `pmdomain: qcom: rpmhpd: Skip retention by default`（2026-06-29），**7.3 线已含、日常线自动免疫** ⇒ M7 从「缺陷」变成「结论」。剩余可选（非阻塞）：把 `debugfs/cmd-db` 的 retention dump + `vk149` 对照作为**数据**回 Konrad/Taniya；外部电流/电压测量已取消。旧进度存档见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行656-M7.md`⟫ | — | ① 根因可指名（哪条硬件/顺序约束被违反且有反证）或上游复现确认；② 驱动/DT 缺陷按正确层提交，硬件特性则上游文档化；③ `cam-mode.sh`/零相机 cmdline 等**策略件不进任何上游包** | `archive/topics/UPSTREAM-REPORT-cambist-q24-v3-2026-10-12.md`、`reports/upstream-q24-q28-standard-20261015.md`、`reports/q24-{mech,r9,noc}-20261012.md` |
| **M8** | **Q28 显示初始化（dispcc probe 复位 MDSS 块）—— ★2026-11-02 已投 `[PATCH v3 0/3]` 新线程（删长注释 + drop RSCC），见 §7 头 11-02 批次** |​**★2026-10-31 静态归属已定（总管复核）**：**「RSC/RSCC 不属于 MDSS 可复位域」成立**（上游 qcom dtsi `RSCC` 0 命中、mdss/dispcc `resets` 含 rscc 0 条、`sde_cesta` rscc reg `0xaf20000` 恰在 dispcc 窗口外）； ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行698-M8.md`⟫ |CORE_INT2|RSCC`（`lenovo,elden` 门控），RFC 里问了两件事（DT 属性 / 无条件在 dispcc 或 mdss / 交给 bootloader）并给出 DIGTOP 系列的独立佐证（PLL 锁修好但不改 command DMA 失败）。待办：盯 review（Konrad/Dmitry/Bjorn/clk 维护者）与是否需要非 RFC 版本（含 DT 属性）；草稿与说明 `patches/upstream/q28-dispcc-2026-10-22/` | — | 获 review 或明确落点后转为正式系列 |`patches/upstream/q28-dispcc-2026-10-22/README.md`、`reports/q28-disp-init-ab-20261022.md` **★2026-10-29 20:32： ⟪全文见 `TASKS/sessions/2026-11-03-TASKS行698-M8.md`⟫ |
| **M9** | **kexec：irqchip/gic-v3-its 认领继承的 LPI 表（DT）** — 2026-10-24 立项（Q11/K6 收口产物） | 🔴 **方案被否（2026-10-26，Marc Zyngier：nothing works at all）** ⇒ 撤回，或改「引导器预置 + DT memreserve」待用户裁决。旧记录：2026-10-24 曾投 `<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>`（`/lkml/` + `/linux-arm-kernel/` 已归档；投前 vk161 上机确认 0 超时），补丁把 `gic_check_reserved_range()` 拆成纯查询 + 认领助手，机械门 `checkpatch --strict` 0E/0W/0C。沿革与回信见全文。 ⟪全文见 `TASKS/sessions/2026-11-06-TASKS行658-M9.md`⟫ | —（不阻塞） | ① ~~投递~~ 已发；② 盯 review（Marc/Thomas），视反馈出 v2；③ 若进树则回填上游提交号 | `patches/upstream/m-gic-its-claim-20261024/README.md`、`reports/kexec-target-boots-20261024.md`、`TASKS/sessions/2026-10-24-kexec-its-lpi-claim.md` |
| **M9-收口** | ✅ **已撤回（2026-10-26，长期规划取舍）** —— Marc Zyngier 2026-10-24 12:39 +0100 `<87v76r8h0o.wl-maz@kernel.org>` 三点的原文要点（逐字核对自 INBOX，非二手转述）：①「***nothing* works at all** ... Everything is dead」，与 command queue 无关；②「What makes you think that EFI and DT are incompatible? 90% of my machines are DT based and yet boot with EFI」；③「**No.** This is way too late, and nothing guarantees that these are not already used for other purposes by the new kernel ... **Either it works always, or it doesn't at all.**」⇒ 正解 = 「configure the LPI tables from the bootloader, reserving them at boot time by sticking the reservation in the DT ... preserved along the whole of the kexec chain」。**我方决定 = 撤回整个系列**（不发 v2、不重做内核代领路径）；回信已投并复核（2026-10-26T11:41Z，Message-ID `<179301488974.13269.12823732532276833194@mail.ustc.edu.cn>`，`In-Reply-To` Marc 原件，正文 31 行纯 ASCII，Sent Items [151] 回读）。**长期归位**（不进内核）：kexec 链的「bootloader」= kexec loader 自己 ⇒ 以后若真需 kexec 后 LPI，修在 loader（把 memreserve 写进交接 FDT（不够就扩容 blob）+ 预置 LPI 表），内核侧不再动；当前 kexec 只当「不需显示/网络的调试快环」，需要 LPI 的场景直接全重启。 | ❌ | ✅ 回信已发 + Sent Items 回读；✅ `TASKS`/`reports/` 口径已改 | `out/mail-20261026/re-m9-withdraw.txt`、`reports/upstream-status-20261026.md` §4 |

### ★ 2026-10-11 → 2026-10-14 的历史叙事已下沉（本节只留 M 系列台账）

- M1-7.3 首次上机 bringup（`73`–`73j` 单变量表 + 设备侧修复三条 + 深夜更正）、本轮其它交付（M3-6/M3-3/B5 预研、邮件列表订阅台账）、上游显示栈对照 P1–P2c、M1 7.3-rc7 树显示回归与 E1/E1b/E1g 定案、用户态上游（phoc/phosh）——**原文逐字**在 `sessions/2026-11-02-M系列历史叙事归档.md`。
- **口径**：M 系列的当前状态只读上面的 M1–M9 表（含各行的投递/评审状态）与 `reports/upstream-status-20261105.md`；上面那份归档只作沿革，不回写。
