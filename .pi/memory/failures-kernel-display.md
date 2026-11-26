# y700-elden — 内核/引导类失败与洞察：DSI / DRM / panel / DPU / mdss-dispcc / 背光

> 2026-11-26 从 `failures-kernel.md`（199 KB / 346 条）按主题机械拆分：**每条逐字搬移，未改一字**。
> 检索口径不变：`mem -t project <关键词>`（= `~/.pi/agent/projects-memory/<repo>/` 软链到本目录，`find -name '*.md'`），拆分不需改工具。
> 入口与本表 = `failures-kernel.md`（索引件）。

---

电源/桌面（主线 GEEKiDoS 7.2）：① 睡眠即挂死——/sys/power/mem_sleep 默认 [deep]，进 mem 就黑屏死机（PSCI SYSTEM_SUSPEND 未支持），缓解 `echo s2idle > /sys/power/mem_sleep` + 关空闲灭屏；② Phosh 熄屏后无法唤醒——phoc 打 "connector DSI-1: Turning off"，dpms=Off、bl_power=4，外部 echo 被拒（DRM master 在 phoc 手上），phoc 退出后 seatd 卡 "seat is VT-bound"，此时 reboot -f 最省事；③ 插充电器仍净掉电（PMIC charger 未驱动），长任务前先在 Android 充满，勿依赖边充边跑。
---
Phosh 会话在无 logind 时的已知坑（上游 Qualcomm DSI 案例，pmos-xiaomi-thunder PR#7 2026-09-22）：用 logind 后端会导致 session 被 deactivate → phoc 释放显示 → 禁用 CRTC 会挂住面板直到 watchdog 复位设备；必须 LIBSEAT_BACKEND=seatd。与本机「熄屏→重启=未解/间歇性」高度相关，暗示排查时应先分用户态（seatd vs logind / phoc DPMS-CRTC 路径）与内核态（DSI panel blank/unlp/ULPS + APSS watchdog），不要混在一起。同类案例：Marker284/samsung-gts7xllite-display-touch（SM-T735 msm DPU 修复，GNOME/Plasma 默认 dim/blank 触发）。
---
phoc/phosh 在 logind 后端下会话被 deactivate 后 phoc 会释放显示并关闭 CRTC，Qualcomm mainline 面板会在关闭 CRTC 时挂死直到看门狗复位；必须用 LIBSEAT_BACKEND=seatd 而非 logind 后端（上游 pmos-xiaomi-thunder PR#7 同结论）。
---
initramfs 载具号 ≠ 内核号（继 vk61 之后的普遍规律）：vk55/vk60/vk61 都无内核改动（用户态 / initramfs ∧ init），启动后 `uname -r` 仍显示基座内核（如 vk47clean）= 正确签名，不是刷入失败。判断「到底在跑哪个 vk」必须从镜像内抽 UTS（解 gzip 内核流取 Linux version），文件名不可信。 — Failed: 用户误把 vk61 当内核升级
---
`wlr-randr --output <conn> --off` 与 `modetest -w <conn>:DPMS:3` 在本机 msm/DSI 上是**无效操作**（读回 DPMS value 仍 =0/On、sysfs dpms 仍 On，只触发面板 unprepare→重下固件）。modetest 需 DRM master（不停合成器报 Permission denied）。测「真熄屏」必须走 `org.gnome.ScreenSaver.SetActive(true)`（sysfs dpms 确实变 Off）。此前用 wlr-randr/modetest 得到的「DPMS off 必复位 / 免疫」数据全是噪声（2026-10-07 实测）。
---
内核 uname（release 串）与设备 /lib/modules/<release>/ 目录名不匹配时，`=m` 模块全部无法加载（modprobe 报 not found 或 `Exec format error`——vermagic 不符）；表现为上游 DRM 组件 deferred → msm_drm_bind 不完成 → 连 card0 都没有（DP/显示全无）。软链目录不够（vermagic 仍不符），必须为当前内核构建并部署配套模块包（`scripts/build-kernel.sh modules`）到 /lib/modules/<release>/。本次 vk64 因此需要自己的 1610 个 .ko 模块目录。
---
在 device_shutdown() 循环体里加 msleep 时绝不能碰 devices_kset->list_lock：该函数在调用每个 dev->shutdown() 前已 spin_unlock(list_lock)，之后循环底部再 spin_lock。在 msleep 前后误加 spin_unlock+spin_lock 会对未持有的锁解锁再抢 → 双重加锁死锁，表现为 CPU soft-lockup（queued_spin_lock_slowpath ← device_shutdown+0x174 ← kernel_restart_prepare），~100s 后 watchdog 才打印回溯，背光因显示设备被跳过而未灭。 — Failed: kexec 诊断内核 vk68 加 settle_ms 后设备挂起、背光常亮；抓日志得 CPU5 soft-lockup 回溯定位
---
Q28 面板 init retry 补丁（vk64 d02658e63）实机确认**不足**：首条 DCS `ce 8c a9 00` 在 bonded 双 DSI 命令 DMA 上超时 master=-110，retry 路径确实触发（`panel init attempt 1 failed: -110, resetting and retrying`），但第二次 `sending dcs data ff 20 failed: -5`（EIO）⇒ DSI host 已被首次超时楔死，面板级 reset 救不回。真修需 msm_dsi 级复位（未立项）。面板驱动 builtin（非模块），无法 rmmod 重载。 — Failed: panel-novatek-nt36536 bonded-DSI init retry: -110 → reset → -5, DSI host wedged after first timeout
---
Q28 面板 init 失败的**永久闩锁机制**（drivers/gpu/drm/msm/dsi/dsi_manager.c）：`static bool dsi_bonded_cmd_failed`（:41）被首次 bonded 命令失败置 true（:21 WRITE_ONCE），**全树无任何代码清除它**（grep 确认 0 处写 false）。后果：后续所有 `msm_dsi_manager_cmd_xfer` 在 :674 被 `msm_dsi_manager_cmd_failed()` 短路返回 -EIO，面板 retry 必然拿 -5。只有全新 boot（静态变量随进程空间复位）才有机会。这解释了 vk64 的 panel-retry 补丁为何完全无效。另：热重启 5/5 连续失败 vs 物理冷启正常 ⇒ 失败态不被 warm reset 清除（DSI PHY 寄存器/固件状态残留）；失败态下 `reboot -f` 会挂住（DPU 卡死挡住关机路径），必须用 `echo b > /proc/sysrq-trigger`。 — Failed: panel-novatek-nt36536 首条 DCS 在 bonded 双 DSI 命令 DMA 超时(-110)，闩锁置位后所有后续传输被 -EIO 短路，retry 补丁无意义
---
Q28 诊断：`command DMA timeout: status=0x2200200` 的 0x2200200 实际是 DSI IRQ_MASK 寄存器值（bit21=DSI_IRQ_CMD_DMA_DONE 的 mask 位被错误打印为 status），不是 IRQ_STATUS。真正失败 = cmd DMA 的 completion 从未触发（both master+peer 同值超时 -110）。更早期的 `DSI PLL(0) lock failed, status=0x00000000`（t≈0.87s，远早于面板 init t≈8.8s）表明 DSI PHY 的 PLL 从未锁定——命令 DMA 不完成是 PLL 不锁的下游后果，不是命令路径 bug。方向应查 PHY bring-up/PLL 初始化而非 cmd_xfer 逻辑。
---
Q28 测试镜像构建教训：用 `git diff` 打了补丁后直接 make → kernel.release 带 `-dirty` 后缀 → 设备 `/lib/modules/` 无匹配目录 → 所有模块（含 CONFIG_TYPEC_MUX_FSA4480=m）加载失败 → `msm_dpr_bind` 因 fsa4480 defer 永不完成 → 连 card0 都没有（比 Q28 面板 init 失败更严重，完全无 DRM）。正确做法：(a) 关 LOCALVERSION_AUTO + 硬编码 CONFIG_LOCALVERSION="-vk64-gd02658e63cf6" + 构建时传 `LOCALVERSION=`（空字符串但已设置，阻止 setlocalversion 追加 `+`）使 UTS 精确匹配；或 (b) 确保所有必要驱动 =y（全 builtin 不依赖模块加载）。 — Failed: dirty kernel vermagic mismatch caused total DRM failure on test boot
---
Q28 good/bad 对照否掉的假差异（2026-10-09 vk75 冷启对照 vs vk74 坏发）：`dsi1vco_clk rate=0`（好发也是 0，不是未编程）、`dsi1_isr=0`（好发也低）、byte 时钟 108≠133 MHz、probe 期 `PLL lock failed ×8`（好发同样有）——全部在好发里一模一样，不是差异项。唯一真差异 = 中断计数（mdss irq 1733/dsi0_isr 41 vs 1-2/0），但这是「什么都没跑起来」的结果非原因。教训写进了 vk75 补丁 commit message：「调试差分必须有对照组，只有真差分能活下来」。 — Failed: 上一轮把 dsi1vco_clk=0 当头号线索，缺好发对照导致假阳性
---
GUI 死挂 #106 新约束（2026-10-09）：用户确认「进了桌面然后卡死」（非 Q28 坏显示态，桌面正常出现过）。但压力测试（foot/chromium/btop + dpms 循环）期间 `gfx` genpd 全程 `off-0`（从未上电），原因 = 脚本以 root 跑但 Wayland 会话属 user 1000（/run/user/1000/wayland-0），foot 报 `failed to change working directory to /root: Permission denied` ⇒ 实际没有任何 GUI 渲染发生。⇒ 下一步复现必须以 xuqianhui1001 身份、正确 XDG_RUNTIME_DIR/WAYLAND_DISPLAY 施压。vk76-freezetrace（cmdline softlockup_panic=1 panic=20）已就绪，可在下次死挂时自动留证到 ramoops 并暖复位。APSS 硬看门狗永久禁用（历史原因）⇒ 无 cmdline 装弹则永不自复位。 — Failed: stress script ran as root but Wayland session belongs to uid 1000, preventing actual GPU rendering and making the 600s+ survival meaningless for reproducing the GUI freeze
---
Q28 首次好/坏寄存器差分（vk75 探针，2026-10-09）：坏发与好发仅 4 个寄存器不同——STATUS0 0x0→0x20003（CMD_MODE_ENGINE_BUSY|DSI_BUSY|INTERLEAVE_OP_CONTENTION）、CLK_STATUS 0x2343→0x3743（多 DYN_PCLK_ACTIVE+DYN_CMD_PCLK_ACTIVE）、cmd_dma_busy/cmd_engine_busy 0→1。其余 16 项（DMA_BASE/DMA_LEN/TRIG_CTRL/INTR_CTRL=0x2200200/PHY_RESET/LANE_STATUS/TIMEOUT_STATUS/ACK_ERR 等）全等。断点=面板首条 bonded DCS 写走命令 DMA 超时（master=-110），不是 DPU modeset/genpd/PLL。INTR_CTRL 好/坏相同→中断掩码不是变量。 — Failed: 此前多轮只看坏发现场推差异项（4 个假差异），首次有对照组才拿到真差分
---
Q28 判据不完备（2026-10-10 实机）：q28-boot-cycle.sh 只 grep `command DMA timeout` + `panel init attempt failed`，但 Q28 实际有**三种可观测签名**：① 首 modeset 的 `command DMA timeout`(-110) + `Failed to initialize panel: -110`（典型冷起）；② 后续 re-init（如 DPMS 唤醒）只看到 `panel init attempt failed: -5`（EIO，来自 dsi_bonded_cmd_failed 闩锁短路，无 -110 行）；③ 纯 vblank WARN 风暴（`drm_crtc_wait_one_vblank` WARNING from `drm_fb_helper_damage_work`，每 ~2s 一次，**无 DSI 命令错误**）= DPU 楔死但 DSI 层无错。分类器应 OR 三条件：`command DMA timeout` | `panel init attempt.*failed` | `vblank wait timed out on crtc`。只 grep 第一个会把 ②③ 误判 GOOD。 — Failed: A/B 测试 8/8 判 GOOD 但设备实际面板坏（vblank WARN 风暴 + 后续 -5），因为分类器只看 command DMA timeout
---
Q28 坏发时 USB 网络 gadget 不出现（主机侧无任何 usb 网卡接口、adb 空）⇒ SSH 完全不可达，**只有串口 ttyACM0 可用**。后果：① 标准 q28-boot-cycle.sh 的 SSH 取证路径在坏发时失效（脚本等 SSH 超时→判 ENV=1 而非 BAD）；② 诊断必须走串口。固化工具：scripts/serial-logger.sh（跨重启自动重连 cat，pid 文件 /tmp/q28_serial_logger.pid，`--all` 关共享 Chrome 用法同 pi-browser-reap）。另：设备坏发后可能**自发重启**（DPU commit 卡死→看门狗/panic），串口 logger 必须跨重启存活才能接住 t=0。 — Failed: Q28 坏发显示子系统卡死导致 USB gadget 函数注册失败，SSH 通道不可用，标准脚本判据失效
---
q28-boot-cycle.sh 判据不完整（2026-10-10 实测定案）：只 grep `command DMA timeout`+`panel init failed` 会**漏判 L2 坏发**（vid 模式下 DPU 等 vblank/frame-done 超时，面板 init 本身过了、无 command DMA timeout 也无 panel init failed）。正确判据应加：`dpu_encoder_phys_vid.*ctl.*reset failure` 或 `frame done timeout`（出现=坏）；`vblank timeout` 单独用会误判（DPMS off 也产 vblank）。命令模式面板空闲不推帧 ⇒ dsi_isr 增量恒 0（好发也一样），只能看累计值（好>0/坏=0）。
---
scripts/q28-boot-cycle.sh 判据缺陷（2026-10-10 实锤）：该脚本只数六种风暴签名（command DMA timeout / panel init fail / ctl reset / frame done / vblank / dpms off），**不检查 /sys/class/drm/card0 是否存在**——NOCARD（无 card0、零风暴签名）被误报为 GOOD。正确判据必须用 scripts/q28-devprobe.sh 的三态（NOCARD/STORM/GOOD），或至少额外 `[ -e /sys/class/drm/card0 ]`。本轮 vk86-round 暖机被报 GOOD 实为 NOCARD 即此因。
---
scripts/q28-boot-cycle.sh 的 GOOD/BAD 判据**不看 card0 是否存在**——NOCARD 启动（无显示驱动绑定、面板从未点亮）被误报为 GOOD。正确判据必须用 scripts/q28-devprobe.sh 的三态（NOCARD=无card0 / STORM=有card0但风暴签名>0 / GOOD=有card0且无风暴）。本轮 vk86-round 暖机被 q28-boot-cycle.sh 连续 4 次报 GOOD，实际 q28-devprobe 全是 NOCARD。 — Failed: 脚本 GOOD 判据只看 dmesg 风暴签名>0，不查 /sys/class/drm/card0* 存在性；NOCARD 启动风暴签名=0（因为从未 modeset）→ 误判 GOOD
---
Q28 台架混淆变量（2026-10-10 坐实）：(1) vk86-base 与 vk64 的内核 commit/config(a383cdb9)/DTB(386cc9bd) **逐字节相同**，但 ramdisk /init 不同（354 行 vs 364 行，多 payload-modules-load.sh ≤20s 模块加载器挪动用户态时序）→ 同一冷路径下 vk64=STORM、vk86-base=NOCARD，A/B 前提不成立。(2) vk73–85 诊断链 ca81318f2（propagate DPU/DSI power-up failures）把失败点从 STORM（modeset 后 cmd-DMA hang）推早到 NOCARD（PLL lock fail → 组件没聚齐 → 从未 modeset）→ 带诊断补丁的内核**不能**测 Q28 修法，必须用干净 vk64 基线（d02658e63）无诊断改动。 — Failed: vk86-base 的 ramdisk 是从 vk61 重建（多 payload-modules-load.sh），与 vk64 原 ramdisk 不同，首次 modeset 时序偏移导致冷起落在不同失败模式
---
Q28 冷起三态分布（2026-10-10 多轮实机）：同一条 POR 冷路径，同一内核(vk64 d02658e63)，冷起可落 STORM（cmd-DMA 超时，有 card0）也可落 NOCARD（PLL lock fail，无 card0）——两者不是不同 bug，是同一根因（冷起 DSI PHY 状态未初始化）的不同表现深度。区分判据唯一可靠 = SSH 后 q28-devprobe 三态 + 查 card0 有无。串口 logger 重连会漏 0–20s 窗口（NOCARD 断点在 0.86s），不能靠串口时序判。
---
`loginctl poweroff`（走 OpenRC init）在本设备上**永远卡在停服务阶段**（powerlog 有 stopped 记录但无 CLEAN-STOP），不执行实际 poweroff syscall——设备 uptime 持续增长。唯一能触发真实断电的用户态命令 = `busybox poweroff -f`（直接 syscall，绕过 init/OpenRC 停服务链）。且坏发（DPU storm sig>100）态下连 `busybox poweroff -f` 也无效（内核关机路径被 DRM 占死），只能物理断电。 — Failed: loginctl poweroff triggers OpenRC service stop but never reaches reboot(POFF); on STORM-state device even busybox poweroff -f is blocked by DRM storm in kernel shutdown notifier
---
Q28 有第四种结局 HANG（2026-10-10 layout A/B 发现）：oct8 内核（原 GOOD 参照）在 uptime=14.6s 时 SSH probe 报 GOOD（card0 在、DSI-1 connected、风暴=0），但**进入桌面几秒后整机冻死**（SSH 超时→ping 全丢→USB 消失→reboot2 无响应→只能物理长按电源）。原三态判据（NOCARD/STORM/GOOD）漏判此态——probe 时点太早、只看 dmesg 签名不看后续存活。正确判 GOOD 必须 = 有 card0 + 无风暴 + **后续存活 ≥60s**（或在存活期内完成交互测试）。HANG 与 Q28 STORM 不同：STORM 有 dmesg 风暴但内核活；HANG = dmesg 安静但整机不再响应。待单独调查（可能是 DPU/DSI 卡死后 VBUS/PMIC 侧二次触发，或 Q24 cambist 路径在桌面活跃时才触发的子集）。 — Failed: probe 时点(14s)过早且只看瞬时 dmesg 签名，未验证后续存活——导致 oct8 被记为 GOOD 但实际几秒后 HANG
---
Q24 熄屏复现有效性前提（2026-10-11 实测教训）：若当前 boot 是 Q28 坏发（dmesg 有 `panel init attempt … failed: -5/-110`、card0-DSI-1 虽 connected 但 DPU 从未完成 modeset），则 `ScreenSaver.SetActive(true)` **不会复现 Q24 掉电**（设备存活）——因为显示管线本身已死、熄屏路径走不到 cambist×DSI-blank 交互。Q24 扫测/复现的前置判据 = `grep -c 'panel init.*failed' /dev/null` 为 0（从 dmesg grep）+ `cat /sys/class/drm/card0-DSI-1/status` = connected + phosh 进程在 + **dpms 确实从 On→Off**（用 `wlr-randr` 或 `gdbus call … org.gnome.ScreenSaver GetActive` 验证，不能只发 SetActive 就假设生效）。坏发 boot 上的负样本一律标 INVALID 不计入统计。 — Failed: 2026-10-11 Q24 复现：vk64 boot_b 上 boot 已有 panel init -5（Q28 坏发），加载 cambist + SetActive(true) 后设备存活 12s+，差点误判为 Q24 已修复。实际是 Q28 坏发导致显示管线从未正常 modeset，熄屏走不到触发路径。
---
RPMh tracepoint 局限性（2026-10-11 设备实测）：`/sys/kernel/debug/tracing/events/rpmh/` 下的 `rpmh_send_msg`/`rpmh_tx_done` 主要捕获 **BCM（Bus Communication Manager）周期心跳**（msgid=0x10008, 每 ~15ms 一条），**不是** genpd 电源域的 ARC（Active Resource Coordinator）corner level 投票。熄屏时 genpd `mx=on mmcx=on mxc=off-0` 全程不变（55 秒采样零变化），要么投票走不同路径（rpmh_regulator 而非 rpmh driver 直调），要么 collapse 发生在采样间隙内（原子掉电无中间态）。要抓真正的 corner 写需：(a) `/sys/kernel/debug/cmd_db` 读资源映射（已确认设备可读）；(b) 在 `drivers/power/domain/qcom-rpmh-power.c` 的 `rpmhpd_power_on/off` 里加 dev_dbg/printk；(c) 或 `rpmh_regulator_set_voltage` tracepoint（若内核有 CONFIG_TRACING）。genpd sysfs 采样不能证明「轨没塌」——只能证明「塌得比采样快」。 — Failed: 试图用 ftrace rpmh_send_msg 抓 Q24 掉电瞬间的 RPMh 轨投票，结果 24 行全是 BCM 心跳、0 行 genpd ARC 操作。genpd sysfs 采样（0.5s 间隔）显示熄屏全程 mx/mmcx=on、mxc=off-0 不变，与「MX/MXC 轨塌导致 NoC→PS_HOLD」假设矛盾，但采样分辨率不足以排除亚 500ms 原子塌。
---
G1-8 GPU 基准（vkmark/es2gears）在设备上的 caveat：用户观察到「待渲染物体挤在左上角」，疑与 phoc 显示缩放/视口有关（非 GPU 性能问题）。解读 vkmark/GLES 分数时注明此 caveat，不要因绝对值偏低误判 GPU 驱动异常。vkmark ~25400、GLES es2gears ~165fps（= 面板刷新率上限）均正常。
---
Q28 坏发时 USB-NCM 网络 gadget 可能起不来（面板 init 失败 → DPU 卡死 → 关机路径挂 → USB gadget 未初始化），此时主机侧无 usb 网卡、SSH 不通、adb 空——只有串口可用。用户 2026-10-11 明确：「注意到 q28 的 bug 可能会影响 ssh，为了防止误导，先停下来梳理现况」。做设备侧实验前必须先确认 boot 健康（ping 192.168.7.1 或 ssh uname），不要把 Q28 导致的 SSH 不通误判为设备断电或其他故障。 — Failed: Q28 bad boot can prevent USB-NCM gadget from coming up, making SSH appear dead when device is actually alive but display-failed
---
Waydroid 容器 state 可能显示 FROZEN（冻结）导致一切音频/媒体行为静默失效：`waydroid status` 显示 Container: FROZEN、cgroup freezer.state = frozen 1。排查容器内任何服务无响应时先 `cat /sys/fs/cgroup/.../freezer.state`（或 lxc-info）确认未冻结，用 `echo 0 > .../freezer.state` 解冻后再测；冻结态下 Android 侧线程全停、媒体无声但进程仍在。 — Failed: 容器被冻结时音频/媒体静默无输出，容易误判成 HAL 或内核问题
---
同 UTS 串 ≠ 保证 GOOD（2026-10-11 实机）：日常 boot_b 内核（UTS …-vk64-gd02658e63cf6）某次纯净冷起实测 **STORM**（card0 在、DSI-1 connected，但 storm=45、vblank wait timed out、phoc=1/phosh=0、greetd=2），而同一内核在测试台架上 GOOD 5/5。⇒ STORM 是独立随机事件，「UTS=GOOD 串」只是降低概率、不保证结果；启动后必须先实测判 GOOD/STORM 再谈后续实验。STORM 启动下 phoc/phosh 会消失、无 /run/user/1000/wayland-0、无会话总线 ⇒ 依赖桌面会话的实验（如容器网络）做不了。
---
「按内核二进制确定性」假说已被彻底否定，且 Q28 冷起 GOOD/NOCARD 由**内核 UTS 版本串内容**决定（2026-10-11 十二发冷起定案）：UTS 恰为 `7.2.0-debug-vk64-gd02658e63cf6` → 冷起 GOOD 5/5（base vk97 3/3 + 同源码重编 base2 vk100 2/2，二进制不同仍 GOOD）；任何其它版本串 → NOCARD 7/7（空提交 vk101 1/1、一行常量 pr_info vk99 2/2、clk_round_rate 查询 vk98 1/1、round 补丁 vk96 3/3）。⇒ 改代码/改 config 会经 setlocalversion 改变 UTS 串从而翻转结果；**冷起 A/B 测 DSI 补丁这条路作废**（观测行为自身改变结果），round/Method-B 的 NOCARD 不能当「修复无效」。可控手段 = 钉死 UTS 串（`CONFIG_LOCALVERSION_AUTO=n` + `LOCALVERSION=-vk64-gd02658e63cf6`，即 PINUTS）——vk102-c1pin/vk103 证明改内核+改 config 仍能冷起 GOOD。脚本 scripts/q28-build-arm-lv64.sh（含 PINUTS）/ q28-build-round-lv64.sh / q28-cold-run.sh；臂记录 reports/trials/index.tsv + logs/q28-cold-*。
---
Q28「STORM 是探针误判」已被证据审计证伪（2026-10-11，commit d3b1831，reports/q28-storm-bias-audit-20261011.md）：10 个落盘 STORM 样本拆 L1（DSI/panel 真失败：`command DMA timeout` / `Failed to initialize panel`）后 L1 全部 ≥6，离线回放无任何「L1=0 却 L2>0」样本 ⇒ 不是把良性 vblank 误当坏发。但「STORM = 独立随机」的证据只有 1 条无原始日志样本（wd-net-baseline §4 的 vk94 一次 storm=45），且同镜像当日又被记为 GOOD 一次，两条都 n=1 无 dmesg。★新线索：STORM 与镜像高度共线——所有 STORM 样本都在旧内核+旧 ramdisk 镜像（vk64 Oct-8 / oct8 / vk94），16 发新 PINUTS 冷起（vk97/vk100/vk102-vk105）无一 STORM。⇒ 下一步应做内核×ramdisk 2×2 因子实验（vk106=newK-oldR、vk107=oldK-newR），判 STORM 是否同样是构建产物而非随机。
---
Q28 STORM 非独立随机——与内核构建身份强相关（2026-10-12 2×2 因子实验 + E2 定案）：源码全为 d02658e63（旧K vk94/vk64 与新K vk97/vk100/vk104 **完全相同**，之前「差 1 个 ADSP fastrpc 提交」是 DTB 差异非内核源码差异，已更正）。唯一内核构建差异 = `CONFIG_LOCALVERSION_AUTO=y`（旧，嵌 build 时间戳→payload 布局偏移 ~5.1M 字节）vs `n`（新，PINUTS）。实测：`#60`（Oct-8 构建）4 发冷起 2/4 L1FAIL；`#111+`（Oct-11 构建）20+ 发冷起 0 L1FAIL。E2 决定性实验：vk110（旧K #60 + 新DTB）= L1FAIL，vk109（新K #118 + 旧DTB）= GOOD ⇒ DTB 不是轴，内核二进制构建身份才是。机制假说：build 时间戳导致 .rodata/.data 段偏移 ~4B × 字符串数量，把 DSI bonded cmd-DMA completion 的中断/轮询时序推过竞态刀刃。ramdisk 无关（B 臂旧 ramdisk 恒 GOOD）。n 仍小（Fisher p≈0.43），但趋势极强。下一步 = 用 vk108（旧源码 d02658e63 + PINUTS + 新 .config 无 AUTO）冷起，若 GOOD 则坐实 AUTO 是唯一变量。 — Failed: 之前多次记忆将 STORM 定性为「独立随机」（如 TASKS §p 收尾口径「剩余唯一未解=STORM（独立随机）」），被 2×2 因子实验 + E2 推翻
---
Q28 STORM 也是构建身份伪影（2026-10-12 E1'/E2 实验定案）：2×2 因子臂（内核×ramdisk）+ E2（内核×DTB）+ E1'（KBUILD_BUILD_VERSION=60+KBUILD_BUILD_TIMESTAMP 复刻 banner 重编，与 vk94 payload 仅差 0.14%/87605B）全部指向：源码(d02658e63)、DTB、ramdisk 都不是轴——**轴=内核 banner 构建号位数**（`#60` 2 位 → .rodata 平移 1 字节 → DSI cmd-DMA 竞态刀刃偏移 → ~67% STORM；3 位 = 0%）。机制假说 = banner 长度差使 Image 中字符串/常量表地址平移 1 字节，恰好落在 cmd-DMA trigger 路径的某个对齐敏感点。修法 = `KBUILD_BUILD_VERSION=100`（或任何≥100），`KBUILD_BUILD_TIMESTAMP` 任意，源码/DTB/ramdisk 不动。验证 = vk111 冷起 STORM（4 坏/2 好 vs 3 位 0/12+，Fisher p=0.005）。 — Failed: 此前多次将 STORM 判定为「独立随机」或「旧内核特定二进制」，经 E1'/E2 实验证明是构建号位数（banner 长度→rodata 平移）的系统性伪影
---
Q28 STORM 最终定案（2026-10-12 冷起 12 发）：STORM（bonded DSI 首条 DCS command DMA timeout -110）也是内核构建身份伪影，与 NOCARD 同一机制。E1'（vk111 = KBUILD_BUILD_VERSION=60 + KBUILD_BUILD_TIMESTAMP='Thu Oct 8 17:06:14 CST 2026' 复刻 #60 banner）冷起即复现 STORM；3 位构建号（#111–#120）冷起 0 STORM。Fisher p≈0.005。E2 排除 DTB 轴（vk109 好内核+旧DTB=GOOD；vk110 旧内核+新DTB=STORM）。2×2 排除 ramdisk 轴。源码完全相同（全 d02658e63）。治法 = 日常镜像用 3 位构建号重编即愈（日常 boot_b 恰好已是 #60→仍有间歇风险，需重编一次 3 位号）。判定脚本 scripts/q28-devprobe2.sh 分 L1（真失败）/L2（vblank 风暴可能良性）。
---
Q24 "熄屏类" 实验的三值硬门（2026-10-12 实测定型）：判「屏真的熄了」必须同时满足 ① `org.gnome.ScreenSaver.GetActive` = true（注意是**方法**不是属性，`busybox`/gdbus 下属性写法报 `No such property "Active"`）② `/sys/class/backlight/*/bl_power` = 0 或 dpms state = Off ③ RPMh trace 里看到 mmcx/cx 降档票。只有 GetActive 不够（phosh 0.55 下 SetActive 可被忽略、DPMS 仍 On），no-op 会被当成存活。三值不全过就不算有效样本。
---
Q24「死前共同签名」（加载第二个相机时钟控制器时 RPMh 一次性把 ebi/gfx/lcx/lmx/mss/nsp/nsp2/gmxc/mxc 投到 0）**不是死因**，是 cambist probe 注册 genpd 子域的常规行为——已更正定性（PITFALLS #197）。另：暖复位路径会损坏台架（phoc 卡 D 态 rpm_resume，D 态持有 DRM master ⇒ modetest DPMS:3 恒 Permission denied，kill -9 无效），Q24/Q28 冷起 A/B 必须走物理 POR（PITFALLS #198）。
---
Q24 C 系列（2026-10-12）GOOD 台架一次冷起内按序 C0(cam=0)/C1({camcc})/C2({camcc,cambist}) 各做「真熄屏→hold 60s→唤醒」+三值硬门：C0 存活 +89s、C1 存活 +89s、C2 ≤5s 静默硬复位（串口 0 panic/Oops/BUG）。⇒ 触发器 = 配对 {camcc,cambist} + 熄屏，{camcc} 单模块不致死，致死点随台架显示栈状态移动。commit a455295，PITFALLS #204。
---
Q24 台架准入判据 = 三值仪表硬门 3/3（GetActive=true + DPMS=Off + RPMh mmcx/cx 降档票 >0），**不是** Q28 GOOD —— Q28 L1FAIL 的台架照样能用于 Q24（PITFALLS #202）。台架损坏的一种形态 = phoc 卡 D 态 `wchan=rpm_resume`（GPU resume 路径，栈 adreno_get_param→__pm_runtime_resume），持有 DRM master ⇒ modetest DPMS 恒 Permission denied（PITFALLS #198/#203）。
---
Q24 台架准入纪律（2026-10-12）：不要用 Q28 的 GOOD 作为 Q24 台架准入判据——Q28 L1FAIL 的冷起台架照样可能有效。唯一准入 = 三值仪表硬门 3/3（ScreenSaver GetActive=true + card0-DSI-1 dpms=Off + RPMh mmcx/cx 降档票 >0）。且同镜像不同冷起的仪表就绪度也不同（vk112 第 1 跑门失败、第 2 跑同镜像 3/3 通过），每跑必须重新验门。
---
绑定/解绑 DSI host 做运行期恢复会拆掉整个 DRM 栈：运行期重绑 ae94000.dsi 后 /sys/class/drm 只剩 version（card0-DSI-1 消失）、随后 dpu_kms_wait_for_commit_done 报 -110 风暴 ⇒ 不能用重绑 DSI host 当 Q28 坏发的恢复手段。PITFALLS #224，commit dcb61a8，证据 logs/q28-rebind-20261012/dmesg-after-rebind.txt。
---
Q28 运行期重绑 DSI host 会把 DRM 拆掉，不能当恢复手段：`echo ae94000.dsi.0 > .../unbind` 再 bind 后 card0-DSI-1 消失、DPU 报 wait for commit done returned -110、GPU hangcheck recover（offending task: phoc）；且在 panal init 失败态下重绑无助于恢复显示。 — Failed: 被当作 Q28 恢复手段尝试，实测破坏 DRM 状态
---
Q28 差异化判别量 = DYN pclk 域（2026-10-12 vk118 首命令探针 + CLK_STATUS 位解码）：坏发首命令**前** CLK_STATUS=0x343（AHBM AON+DYN、AON_BYTECLK、AON_ESCCLK、AON_PCLK）；失败后 0x3743（多出 DYN_PCLK 0x400 + DYN_CMD_PCLK 0x1000 + CMD_PCLK 0x2000）；好发同点（10-09 数据）= 0x2343，**无 DYN 位**。STATUS0: 首命令前 0x0 → 失败后 0x20003（ENGINE_BUSY|DMA_BUSY）。⇒ 坏发卡在 DYN pclk 域而非 AON。另：`Q28 power_on: link_clk_set_rate -> 0`（两 host 均 0 = 成功）。探针臂 vk118（首命令前 dump + set_rate 返回值）/ vk119（加成功路径 after-first-cmd-ok 同点 dump，patch q28-dsi-probe2.patch）均为冷起 L1FAIL。
---
Q28 冷起实验「vk114 上游 round 修复不修我们的 STORM」定论（2026-10-12）：vk114-dailyid-round（=vk113 同配方 + 上游 2028280686f4 机制的等价自落 patches/q28-methodB-round-byteclk.patch，落点 dsi_link_clk_set_rate_6g）冷起 #1 L1FAIL（同签名 t≈9.05s）⇒ 上游 byte-clk 取整不修本树 STORM（本树 bonded 双 DSI 路径为 GEEKiDOS/linux 自带，可能非同根因）。镜像 sha 4fb6c145…，payload 0857f458…（补丁串在 payload 内 True / vk113 内 False）。PITFALLS #223。
---
Q28 冷起采样统计口径（2026-10-12 实测）：坏发**按时间成簇**（当日观测 3 连 GOOD → 5 连坏 → 又 GOOD），单发 GOOD 无判别力，候选修复至少要 3/3 或 5/5 全 GOOD 才能写「有效」；出现 1 发坏发就要立刻看它卡在哪一步（若仍 DYN_PCLK_ACTIVE 闩住 + STATUS0=0x20003，说明 force-on 不是根因）。判据脚本 scripts/q28-devprobe.sh 三态 NOCARD/STORM/GOOD，必须 SSH 读完整 dmesg（只数签名会把「显示缺失」误判成 GOOD）。
---
Q28「3 位构建身份 #N ⇒ 不坏」的治法假设**已作废**（2026-10-12 上机否证）：`vk113-dailyid`(#121) 冷起 3 次 1 GOOD/2 L1FAIL；`vk114-dailyid-round`（同配方 + 上游 2028280686f4 byte-clk 取整）仍 L1FAIL。≈7 发 4 坏/7（57%），与 2 位身份无统计差异。⇒ 坏发是**时间成簇的随机**（10-11 15:24–27、10-12 00:02–09、08:37–41、09:43–48 成串坏；10-11 11:51–14:51 10 GOOD 0 L1FAIL 成串好），**缓解不在镜像层**（PITFALLS #223）。历史「3 位身份 0/20 坏」落在一个好窗内，是采样偏差。严格 POR（断电 30 s）也无效。运行期重绑 panel/`msm_dsi` ⇒ card0 消失（副作用）。 — Failed: 以构建身份位数作为治法的假设被上机否证；后续不要再用「改构建号位数」当修复。
---
Q28 判别量与尚未证否的靶点（2026-10-12）：① 判别量 = **DYN pclk 域生命周期**（健康发 CLK_STATUS 0x343→0x743→0x343 随命令瞬开/放；坏发闩在 0x1743/0x3743 + STATUS0=0x20003 + DSI 中断计数 0）；② **DYN 位在控制器 sw_reset 后仍在 ⇒ 故障态不在 DSI 控制器内**（映向 dispcc/INTF 动态时钟请求）；③ 坏发首条命令前寄存器与好发逐字相同，且**首条命令其实成功**，卡死在第 2 条命令的 DYN pclk 域切换（master=-110 peer=0 从机已完成）；④ DYN 域一旦卡住永不释放（vk120 全 boot CLK_STATUS 只变 1 次）。已否证 6 条路线：面板 reset / 软件闩锁 / DSI ctrl+PHY 复位 / 自定义 bonded 序列（vk121 改走标准广播路径仍 L1FAIL）/ 使能期 force-on（vk122 首 2 发 GOOD 后仍 L1FAIL）/ VBIF 优先级。原厂 dyn-refresh 寄存器面（`DSI_DYNAMIC_REFRESH_CTRL=0x200`/`_STATUS=0x210`、LANE_CTRL bit28 请求、INT_CTRL bit28 done+ACK、PHY v7.2 dyn_refresh_*）本树一概没有，但 Lenovo 版与 OnePlus 版原厂 display 源码的 `dsi_ctrl_reg.h`/`dsi_clk_manager.c` 逐字节相同 ⇒ 「dispcc/INTF 是下一主靶」的前提也被削弱，需重新选靶。
---
Q28 已明确否证的路线清单（避免重复开发，2026-10-12/13）：面板 reset、软件闩锁清除、DSI ctrl+PHY 复位（vk117 寄存器转储证明复位执行但救不回）、自定义 bonded 序列（vk121 改走标准广播路径仍失败）、使能期 force-on（vk122）、VBIF 优先级、上游 2028280686f4 byte-clk 取整移植（vk114 L1FAIL，本树 bonded 路径是 GEEKiDOS 自带、非同根因）、vk125 resetterm（镜像原厂 ctrl_reset 终态仍 L1FAIL）。判别量 = DYN pclk 域生命周期（好发 CLK_STATUS 0x343→0x743→0x343 按命令瞬开/放；坏发闩在 0x1743/0x3743 + STATUS0=0x20003 + DSI 中断计数 0），且 DYN 位在控制器 sw_reset 后仍在 ⇒ 故障态不在 DSI 控制器内。
---
判断『上游是否有同族工作』要看 GIT PULL 邮件而非只搜关键词：本轮从 andersson 的「Qualcomm clock updates for v7.4」pull 请求里读出 sm8750-gcc 加 CX power domain、dispcc-sm8750 always-on 通用 probe、cambistmclkcc-sm8750 +7 行等，直接支撑 Q24 的 cx/mmcx 票面分析；而 [PATCH v21 14/14] kaanapali-mtp-camera 把 cambistmclkcc 当相机 MCLK 提供者（CAM_BIST_MCLK_CC_MCLK2_CLK），佐证『裸时钟控制器』质疑。
---
「屏幕没拉起」这类 Q28 坏发时，设备 SSH **仍然可连、但响应极慢**——真因不是网络：坏发下 dmesg 出现 `msm_dpu ... [drm:hangcheck_handler] *ERROR*` 回收循环（hangcheck recover ×78）、`a6xx_gmu_set_oob Timeout`、`offending task: phoc`，GPU worker 吃 CPU 致 load 5–6。同时 `card0-DSI-1/status` 仍是 `connected` = 假阳性（连接器在但管线 hang）。判坏发要看 hangcheck 计数与 phoc 是否被点名，不能只看 card0 status。
---
审计本机内核 payload 的上游合规性（2026-10-13）：相对主线 v7.2 为 125 文件 /≈7077 行改动 + 11 个新驱动或 DTS /≈5300 行；其中约 60% 属真实硬件缺口（方向正确）、25% 结构需重做、15%（D 类）永不上游。新驱动族已全部挂在强制框架下（panel-novatek-nt36536→drm_panel、wl2868c-regulator→regulator、aw86927→input FF、novatek-nvt36xxx-spi→spi/input、camss-*→V4L2/media+MC、pwrseq-qcom-wcn→pwrseq、hci_qca→bluetooth），binding 全过 dt-doc-validate，dt-validate 仅 usb@a600000 一处红点。策略定为「mainline + 薄下游层」（reports/upstream-policy-20261013.md + AGENT-OPS §3 + TASKS §7）。
---
M1-7.3 新内核「外设全废/无桌面」根因 = 模块集没带（不是代码回归）：73h 是纯 ramdisk（0 个 .ko）+ 磁盘无 7.3 的 /lib/modules ⇒ 所有 =m 驱动未加载。因果链（每环有实机日志）：fsa4480.ko 未加载（CONFIG_TYPEC_MUX_FSA4480=m）→ 无 typec mode-switch → pmic_glink.altmode defer（`failed to acquire mode-switch for port: 0`）→ af54000.displayport-controller 永久 defer → disp_cc-sm8750 sync_state() pending → msm_drm_bind 被卡 → 无 card0/无桌面。决定性证据：运行时 insmod 与内核同 vermagic 的 fsa4480.ko（13.7KB strip 后）→ 立刻出现 card0/card0-DP-1/card0-DSI-1/renderD128 + dmesg `msm_dpu: bound af54000.displayport-controller`。同类：fastrpc=m 缺失 → 无传感器。=y 的 USB/触摸/背光/部分音频照常——与观察一致。⚠不要误判成 Q28/DSI 问题。
---
M1-7.3 纯 ramdisk 上机「外设全废」真因 = 模块集没带（非代码回归，2026-10-13 单变量闭环）：fsa4480 未加载（CONFIG_TYPEC_MUX_FSA4480=m）→ 无 typec mode-switch → pmic_glink.altmode defer（failed to acquire mode-switch for port: 0）→ af54000.displayport-controller 永久 defer → disp_cc sync_state() pending → 阻塞 msm_drm_bind → 无 card0/无桌面；运行时 insmod fsa4480.ko 立刻出现 card0/card0-DP-1/card0-DSI-1/renderD128。insmod fastrpc.ko → /dev/fastrpc-adsp + QRTR svc400 上线、传感器恢复。最小必需模块 = fsa4480 + fastrpc；实测闭包 36–37 个（时钟族 + 相机 + fuse/stp/bridge/overlay）。
---
Q28 判据不能只看 card0 + phoc/phosh 就判「显示正常」——P2b 上游 DSI 臂 10-13 那次被记为 GOOD 的启动，10-14 同 sha（71016e08）复测翻转为 kickoff reset failure 196 + frame-done/vblank 195，且事后核对该次 GOOD 从未验屏。判「面板是否点亮」必须看三类风暴签名（kickoff reset failure / frame-done / vblank timeout），且两栈失败签名不同：vendor 栈 = command DMA timeout，上游栈 = ctl N reset failure -22 + vblank/frame-done。scripts/q28-devprobe2.sh 的 L2 正则原缺 vblank timeout（2026-10-14 已补）。
---
Q28 健康发窗口是逐会话成簇的（2026-10-14 实测）：同一台设备同一构建身份，一个窗口里 P2c/P4a/P4d/m1-73j 连出「结构健康发」（L1=L2=0），而 vk94 对照组同窗口却是 L2STORM 坏发 ⇒ 「窗口好坏」不能一律按 L1/L2 签名判，还要看是否真出图（用户目视）。寻找健康发的实用手法 = scripts 自动复位 + 轮换臂直到单臂 L1=L2=0，然后请用户目视。复位路径：显示坏态下 `reboot2` 会挂 DRM cleanup（PITFALLS #253），可用串口 SysRq-b（BREAK+'h'+'b'）或 `echo b > /proc/sysrq-trigger`，无需物理 POR。
---
M1 7.3-rc7 重基树显示回归（2026-10-14 同窗口 A/B 定案）：同硬件同启动路径下 vk94（7.2 血统）面板正常出桌面，而 M1 7.3-rc7 树的两条臂（m1-73j vendor 栈、P4a/P4d 上游 DSI 臂）都是「有声音+背光但屏幕无内容」⇒ 不是 Q28 粘态、不是面板坏，是 M1 树自身的显示回归。判据关键：vk94 与 m1-73j 都 dsi_isr=41（视频引擎在跑、grim 能出图），但只有 vk94 有画面；P4a/P4d 上游臂 dsi_isr=0（上游 DSI host 根本没起视频引擎）。回归在**内核侧**（两树源 DTS 几乎无差异，仅注释/无关节点）。
---
Q28 判据 `q28-devprobe2.sh` 的 L2 正则漏了 `vblank timeout`（原只有 ctl reset failure / frame done timeout / vblank wait timed out / drm_crtc_wait_one_vblank），对上游 DSI 栈会报 GOOD-NOSESSION 实为显示未工作，已补。教训：判「面板是否点亮」不能只看 card0+phoc/phosh——两栈失败签名不同（vendor = command DMA timeout；上游 = ctl N reset failure -22 + vblank/frame-done 风暴），必须三类风暴签名一起数。
---
Q28「vendor DSI 命令路径专有」假设已悬置（2026-10-14）：P2b 上游 DSI 臂 10-13 记为 GOOD 的那次完全没看屏幕、10-14 同 sha（71016e08）复测 4/4 全是 ctl reset failure + vblank 风暴 ⇒ 那次 GOOD 是判据伪阳性，不能当「Q28 被修复」；但 Q28 签名在上游路径恒 0 属预期（上游不用 bonded_cmd_*），所以也**不能**据此说 Q28 是 vendor 专有。
---
在 Q28 坏发 boot 上仍可做相机/无显示依赖的验收：本次在 Q28 BAD（`boot_id=26262eee…`、dsi_isr=0、Q28sig 逐发递增 4→9）的会话里，相机前/后摄照样出流并抓到真实场景图。反过来，Q28 坏发态下用户无法用屏幕手动拍照，因此人工目视验收要另设通路（agent 侧抓帧转 PNG 给用户看）。 — Failed: 曾默认「Q28 坏发 ⇒ 显示栈废 ⇒ 相关实验作废」，实际只有显示相关项作废
---
Q28 与 Q24 在当前实验条件（vk127 / 7.3 线）互不构成混杂：GOOD 态与 BAD 态各跑 6 次「完整 19 模块相机栈 + 真实灭屏 30s」全部存活（boot_id 全程不变），7.3 线累计 30 发存活，而 vk64 线仍是 1 死/2 发 ⇒ 显示态不是 Q24 的判别量，血统才是候选变量。以后不必为「Q28 坏发会污染相机/Q24 结果」而停实验。 — Failed: 此前长期担心 Q28 显示态会污染 Q24 判读
---
相机 RAW「全暗」判读分三级，别一看到暗就判链路坏：① 均匀 ~16 且 uniq=3 = 完全没光（AGC 未收敛或遮挡）；② 长采 N 百帧后 p50 升到 ~37、mean 38 = 正在收敛（有光但弱）；③ B/G/R mean=0.0 而 max 有值 = 该帧有极少数饱和像素、画面主体仍暗。真正判链路好坏看 STREAMON rc + 字节数（4080×3072 RAW10 = 15679488 B；libcamera 输出 4080×3072×8×3 帧 = 150994944 B）+ 目视 PNG，不要只看首帧均值。 — Failed: 用户反馈「已经是 Q28 坏态，无法手动拍照，不过我已经将前后摄像头移动到有光地方」，需要据此区分没光 vs 链路坏
---
用户拿「马达 1/2 good」反问是否该改用 vk127 测相机时，正确姿势是先纠正统计口径再回答：vk127 的 Q28 样本合规 5 发（s4/s5/s6 GOOD、s7 BAD，加打折 s3）4/6 = 67%，二项单侧 p=0.344 不显著，马达那次 1/2 是最低样本；且 Q28 不是 Q24 的靶——N2' 12/12 存活与 N5 致死都发生在 Q28 坏发 boot 上，显示态是协变量不是判别量。不要顺着用户的数字结论走。
---
写 Python 单行脚本处理 RAW 图时不要用 `import numpy as np if False else None` 这类条件 import 表达式——它是 SyntaxError（`cannot use conditional expression as import target`），整段不执行。设备侧 python3 无 numpy，拆 RAW 帧要用纯 PIL/bytes 遍历（本机主机侧有 PIL 可拆 PNG）。 — Failed: 2026-10-17 vk127 相机后摄 RAW 拆帧时踩到，报 SyntaxError 导致没有生成 PNG
---
用户在现场报「Q28 坏态、无法手动拍照，不过我已经把前后摄像头移到有光地方」时，不要因首帧全暗就判链路坏：sensor AGC/libcamera 软 ISP 需若干帧收敛，应延长采集（如 200–300 帧）看 p50 是否上升，并用 test_pattern 区分通路问题与曝光问题；判真出流只看 STREAMON rc 与字节数。 — Failed: 首帧均值均匀 ~16 是好发/坏发都常见的（无光/未收敛）现象，误读会导致把正常链路判成驱动坏。
---
libcamera `cam --capture=N` 打印的前两帧 fps（如 29.99/30.4）不能当作持续帧率：它只是首帧建立后的瞬时值。长采真值远低（本机 vk127：原生 4096×3072 ≈1.1 fps、1280×720 ≈2.0 fps，log 里 0.29/0.75 fps 才是真值）。判帧率必须看长采末尾的 fps 行或计时统计。
---
`/sys/class/drm/card0-DSI-1/dpms` 在设备上是 0644（-r--r--r-- root root）：非 root 写入 Permission denied；即使是 root 写入也要约 2.5s 才生效（t+0.5 仍 On、t+2.5 才 Off）。熄屏自动化脚本必须带生效延时 + 回读校验，否则会得到一排假 INVALID-NO-BLANK。另：Q28 坏发会话里 phoc/phosh 会崩、SBU 为空 ⇒ 走会话总线的 dpms（gdbus/loginctl）不可用，需备「不依赖会话总线」的内核 DPMS 路径。
---
用户 2026-10-18 当场纠正：「设备当前是 q28 坏态，屏幕无法确认是否拉起了容器。命令没有设置超时」——凡可能阻塞/交互的命令（`waydroid session start`、`lxc-start`、ssh 轮询、容器启动类）必须包 `timeout -k`；且设备处于 Q28 坏态（面板未点亮）时不要用「屏幕上看不到」当启动成功/失败的证据，改用设备侧客观读数（`waydroid status`、/dev/binder、ps、dmesg、card0）。 — Failed: 前台阻塞命令未设 timeout，导致工具调用被用户手动中止；且当时设备 Q28 坏态无显示，无法目视确认容器是否起来。
