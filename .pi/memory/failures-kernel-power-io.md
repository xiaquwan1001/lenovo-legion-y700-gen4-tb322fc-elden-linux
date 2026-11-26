# y700-elden — 内核/引导类失败与洞察：电源 / 休眠 / USB-typec 取电 / 文件系统 / 容器与内存

> 2026-11-26 从 `failures-kernel.md`（199 KB / 346 条）按主题机械拆分：**每条逐字搬移，未改一字**。
> 检索口径不变：`mem -t project <关键词>`（= `~/.pi/agent/projects-memory/<repo>/` 软链到本目录，`find -name '*.md'`），拆分不需改工具。
> 入口与本表 = `failures-kernel.md`（索引件）。

---

间歇性设备故障的观察者效应：为抓「静默硬复位」装 per-boot kmsg→UFS 落盘钩子后，被测坏内核从 ~1min 一次重启变成稳定 400s——取证装置本身改变了时序。① 用最小侵入读取（SSH 读 dmesg），改动前后各取样本；② 单次「没复现」无统计意义，需多轮长时窗；③ 主机 ModemManager 会独占 /dev/ttyACM*（EBUSY），USB-NCM SSH 更可靠。
---
arm64 kexec 在 VA_BITS_52 且运行于 !FEAT_LPA2 硬件时的上游修复：commit 1537e55728ec（Breno Leitao，2026-08 前后）——machine_kexec.c 的 trans_pgd_create_copy 原用编译期 PAGE_OFFSET(52-bit)，应改为 _PAGE_OFFSET(vabits_actual)；否则线性映射被按 52 位克隆约 16 倍（~RAM/32），KASAN 关闭时表现为慢/耗内存，是否致挂死待验证。排查 arm64 kexec 挂死时应先确认树里是否已含该修复。
---
定位 kexec/内核切换期间挂死的分支点必须有能在跳转期间存活的 console：ttyGS0（USB gadget 串口）在 kexec 时必然断开，输出「戛然而止/Bye!」之后什么都没有是设计使然，不能据此定位故障点。pstore/ramoops 在无 panic 的硬挂场景也为空。需要独立存活的 console（硬件串口等）才能取证。
---
kexec 上机取证时控制台选择陷阱：设备 cmdline console=ttyGS0,115200（USB gadget 串口 ttyGS0/ttyACM0），kexec -e 跳转期间 USB gadget 会断掉，所以「无输出」这一证据不能用来定位失败分支点；要定位硬挂分支点必须有能在跳转期间存活的 console（如 ramoops/pstore 通路或物理 UART）。
---
串口（ttyGS0 / USB gadget console）在 kexec/machine_shutdown 切换期间必断，其「戛然而止」不能用来定位失败分支点；定位需要能在跳转期间存活的 console（物理 UART、`console=tty0` 拍屏、或 ramoops 保留 KMSG_DUMP_SHUTDOWN）。
---
switch_root × 后台任务竞态：initramfs 的 init 里若用 `( ... ) &` 起后台子 shell 做挂载（如等 /dev/sde79 挂 /persist），主流程 exec switch_root 后 initramfs 被释放，孤儿子 shell 仍在旧根循环，刷屏报 `sleep: not found` / `can't create /dev/null: nonexistent directory`。修法：这类收尾必须同步执行，且仅在纯 RAM 启动分支运行。诊断手段：USB 串口抓不到早期输出（console 走 tty0）时可读屏幕缓冲 `/dev/vcs1`。
---
vk64 v1 烧 boot_b 后过 BL 但内核起不来（只剩充电标志）——真因不是构建错误而是配置源错误：vk63 manifest 记的 config_sha256=26e7cad3 指向 `.config.old`，与 vk63 真内核 config（从镜像 extract-ikconfig 提取，11948 行）差 3000+ 项（缺 DRM_MSM=y、触屏=y、CONFIG_CMDLINE 等），产物 Image.gz 仅 15.2MB（正确 20.5MB）、解压 42MB（正确 62.5MB）。教训：内核配置的真源应是镜像内 extract-ikconfig，而不是仓库里的 .config/.config.old；manifest 里的 config_sha256 可能指向坏文件。 — Failed: manifest 记录的 config 与真内核不符，重建内核残缺
---
设备侧『抓 kexec 掉电前最后日志』的正确做法：`setsid nohup` 起一个完全脱离 SSH 会话的本地落盘进程（`stdbuf -oL dmesg -w >> /root/kmsg-diag.log` + `while :; do sync; sleep 0.5; done`）。用 SSH 驱动的 python/进程读 /dev/kmsg 必失败——kexec 的 kernel_restart_prepare 会跑 SYS_RESTART notifier 链（网络 teardown 杀 SSH，读取进程随之被杀）。另注意观测硬墙：落盘写 UFS，device_shutdown 反向遍历到 UFS host controller 时会关闭落盘的存储自身，之后的 kernel 日志刷不出（本次捕获干净止于 `[KD] SD-done: sde51`，无孤立 start），只能收窄不能穷尽。 — Failed: R2 第一轮落盘 kmsg 未拿到 Starting new kernel/Bye! 里程碑，误以为掉电点在里程碑之前
---
本地落盘 dumper 抓 device_shutdown 早期标记的有效做法：setsid nohup 完全脱离 SSH 会话（不能用 SSH 驱动的 python 读 /dev/kmsg——reboot_notifier 跑 SYS_RESTART 时网络/SSH 断、子进程被杀，这正是 R2 落盘失败根因）；用 dmesg -w + 频繁 sync 循环落 UFS。但这是台车撞墙：device 反向遍历关到 UFS host controller 时把落盘用的存储自己关掉，之后的标记刷不出——「最后一条有 start 无 done」可能是观测截断而非真元凶。 — Failed: vk66 的 SD trace 止于 sde51 后无法继续，事后时间戳分析才知是观测截断/异步落电
---
RPMhPD Always-On (AO) 电源域语义纠正（2026-10-10 E4a worker 源码证据）：AO 域 = 「sleep 票清 0」即**更弱**（允许在 sleep 时掉电），不是更强。因此 Q24 修复方向「把 cambist 从 MMCX+MX 改为单挂 MXC」的正确逻辑 = MXC 是非 AO 域（保持 awake），而非「AO 保护更强」。此前 q24-deep 文档中「AO 保护」推断方向相反，以 worker 源码证据为准。
---
E4a MXC 变体上机判定（2026-10-10）：vk81（E0+E4a 补丁，cambist 挂 MXC + 干净 vermagic）上相机 10 模块加载成功 + 桌面起来，但熄屏（ScreenSaver.SetActive true）**即睡死关机**（ssh 连接即断）——MXC 单票未根治 Q24。加上此前 H2（MX 单票）3 轮 2 掉电：**「换轨」路线（MX/MXC/MX_AO）全部无效**，Q24 根因不在投票的轨名，而在 bare clock controller 的半成品态本身 → 唯一剩余路线 = FIX-2（probe 常持票）或 FIX-3（lazy-on + suspend quiesce），或确认该块本就不该从 Linux 实例化（原厂 vdd_mx-supply + 从不触碰）。
---
Q24 电源域换轨 + PM 生命周期两条线全部否证（2026-10-10 实机）：H1（去 PD）7/9 间歇、H2（MX 单票）3 轮 2 掉、E4a（MXC 单票 vk81）熄屏即睡死关机、D1（use_rpm=false）6/9、D2（去 critical cbcr）7/9、FIX-3（lazy-on PM lifecycle）boot 死锁。问题不在投票的轨名、不在 PM 是否可挂——在 cambistmclkcc 裸时钟控制器的**半成品态**（probe 编程 PLL + 恒活 AHB + 0 票/悬空窗口）本身，且受 GCC always-on AHB 约束无法走正常 PM 路径。
---
Q24 驱动侧修复上机判定（2026-10-10 深夜）：FIX-3（vk82，去 use_rpm + lazy-on + suspend quiesce）卡联想 logo 无法启动——删 use_rpm 让 probe 读写未 resume 的 MXC 域 MMIO → NoC hang；已 revert（67fcff7f0）。FIX-2（vk83，probe 后常持票）两次 boot 一次卡 logo、一次过 logo 但内核不响应 ssh（只剩充电标志）。结论：cambist 驱动侧 PM 改动都破启动链路，vk81（MXC DT + 原版 probe）能启动但熄屏即死。下一步：串口（ttyACM0）抓早期 dmesg 定位，或把「换轨+驱动侧均无效」写进上游 follow-up。教训：qcom_cc probe 流程的 use_rpm 不能随意删；boot 卡 logo 时设备不枚举 USB，只能物理重启恢复。
---
Waydroid 传感器 HAL（C4）部署链完整依赖：① `mount_overlays=True`（waydroid.cfg 默认 False）② 内核 `overlay.ko`+`fuse.ko` 必须部署到设备 /lib/modules/<KV>/（.config 里 =m 但从未 modules_install 到设备）③ `bridge.ko`+`stp.ko`+`llc.ko`+`8021q.ko` 同理（waydroid-net.sh 用 `ip link add type bridge`）④ 残留 `python3 /usr/bin/waydroid container start` 进程导致 lxc-info 假 RUNNING，需按 PID kill 后干净重启 ⑤ HAL 二进制（HIDL 1.0 UDP）能启动并监听 52012，但 Android framework `sensorservice` 在 VINTF manifest 找 `android.hardware.sensors.ISensors/default`（AIDL）而非 `@1.0-service.waydroid`（HIDL）⇒ `Service sensorservice didn't start`。下一步 = 对齐 VINTF manifest 或补 AIDL 包装。 — Failed: overlay/fuse/bridge 模块未部署到设备 + mount_overlays 默认关 + VINTF manifest 不匹配 HAL 版本
---
内核构建：`make modules_prepare`（或任何 `make` 目标）**不带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`** 会默认按 **x86 原生**运行，**静默覆盖 `.config`**（从 aarch64 变成 x86，sha 从 a383cdb9→5dee2b27），且 LOCALVERSION 丢失（因为它是命令行传的）。后果：后续模块编出的 vermagic 全是 x86，与设备不兼容。必须始终先 `. scripts/env-build.sh`（设置 ARCH/CROSS_COMPILE/ccache）再执行任何 make。 — Failed: 2026-10-11 C1 Waydroid bridge.ko 构建时，modules_prepare 未带 ARCH=arm64，把设备权威 config 覆盖为 x86，需从设备 scp 回 config 再带正确环境变量重做
---
Waydroid 容器启动所需的内核模块部署缺口（2026-10-11 实机确认）：内核 config 有 CONFIG_BRIDGE=m / CONFIG_OVERLAY_FS=m / CONFIG_FUSE_FS=m，但设备 /lib/modules/7.2.0-debug-vk64-gd02658e63cf6/ 里**完全没有** kernel/net/bridge/、fs/overlayfs/、fs/fuse/ 目录（1217 个已部署 .ko 中无这些）。后果：`ip link add type bridge` = Unknown device type → Waydroid waydroid-net.sh 失败；`mount -t overlay` = unknown filesystem type → overlay 挂载失败；OpenRC waydroid-container 报 Module fuse not found。修法 = 在构建树（.config sha=a383cdb9 与设备一致）跑 `make modules_prepare ARCH=arm64`（**必须带 ARCH+CROSS_COMPILE**，否则按 x86 跑把 .config 覆盖成 x86）后 `make M=net/bridge net/802 net/8021q fs/overlayfs fs/fuse` 编出 .ko 部署。vermagic 验证：7.2.0-debug-vk64-gd02658e63cf6。 — Failed: 模块目录部署不完整——构建树有 .ko 但未复制到设备
---
内核模块编译 `make modules_prepare` **必须带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`**（且 `LOCALVERSION=-vk64` 若靠命令行传入也需重复指定）；否则被当 x86 原生跑，**把 `.config` 从 arm64 覆盖成 x86**（sha 从 a383cdb9→5dee2b27，含 `CONFIG_CC_VERSION_TEXT="gcc"` 而非 `aarch64-linux-gnu-gcc`）。修法：先 `. scripts/env-build.sh`（source 不是执行）再 make，或从设备 `/proc/config.gz`（`zcat /proc/config.gz > .config`）恢复权威配置后重跑 `make ARCH=arm64 CROSS_COMPILE=... modules_prepare`。教训来源：2026-10-11 C1 Waydroid bridge.ko 编译时踩中，导致后续所有模块编译失败（`asm/compiler.h: 没有那个文件或目录`）+ 需要二次恢复。 — Failed: make modules_prepare 不带 ARCH=arm64 被当 x86 原生跑，覆盖 .config 为 x86 配置，后续所有 aarch64 模块编译失败
---
Waydroid 容器内音频（G2 C6）排查起点事实（2026-10-11 U2 vk64 实测）：容器内 /vendor/bin/hw/android.hardware.audio.service 与 /system/bin/audioserver 已起（分别在 host pid 25124/25152），但容器内 **没有 /dev/snd**、没有 /etc/asound.conf、音频资源在 /system/product/media/audio（不是 /system/media）。vendor HAL 二进制 ldd 链 libpulse.so + libasound.so + libsndfile.so（/vendor/lib64/）⇒ 上游 Waydroid audio HAL（hardware/waydroid/audio/audio_hw.c）是 pulse 后端，需要容器内能连到宿主 PulseAudio/PipeWire 的 pulse socket。容器内 /run/xdg/pulse 由 lxc 挂载提供（宿主 /run/pulse 或用户总线 socket），DBUS/PULSE 环境变量与 socket 路径是首要排查点。 — Failed: 容器音频无声的排查需要先确认 HAL 后端类型与 socket 通路，而不是先找 ALSA 设备
---
上游 Waydroid 容器音频的已知社区坑（2026-10-11 联网检索起点）：waydroid 主库 issue #1576「lxc pulse audio fails to mount，VM 未装 pulseaudio 时」= lxc 无法挂载宿主 pulse socket 导致容器内无声；排查关键词 = libasound_module_pcm_pulse / PULSE_RUNTIME_PATH / PULSE_SERVER / /run/xdg/pulse。搜索社区资源时应直接查 waydroid/waydroid 的 audio 相关 issue 与 hardware/waydroid/audio 上游实现，而不是从内核 ALSA 驱动方向找。 — Failed: 该路径已被社区踩过，先读上游 issue 可省去重复试错
---
Q28 收尾口径（2026-10-11，DOSSIER §p / PITFALLS #192）：① NOCARD 分支已闭环=内核构建身份（UTS 版本串）伪影——12 发物理 POR 冷起，UTS 逐字 `7.2.0-debug-vk64-gd02658e63cf6`⇒GOOD 5/5，其它任何身份（含空提交、一行 pr_info、round 补丁）⇒NOCARD 7/7；空提交也翻⇒非补丁逻辑。② 冷起 A/B 方法前提=PINUTS（CONFIG_LOCALVERSION_AUTO=n + LOCALVERSION=-vk64-gd02658e63cf6）；钉死后改内核源码+config 仍 GOOD（vk102/vk104/vk105）⇒A/B 恢复可用；决定性证据=同一 round 补丁未钉 UTS(vk96)=NOCARD 3/3 vs 钉死(vk105-round-pin)=GOOD。③ 作废旧结论：§k「按内核二进制确定性」、vk90/vk92 NOCARD、round NOCARD=「修复无效」、T1/T2/T3。④ 剩余唯一未解=STORM（独立随机，与构建身份无关）：日常 boot_b 纯净冷起实测 STORM；round/Method-B 对 STORM 是否有效=未测。⑤ Q28 不再阻塞日常/Waydroid（日常 boot_b 即 GOOD 身份；之前「Q28 挡 Waydroid」是在 RAM 起实验内核 NOCARD 上验证所致）。台架=vk97/vk100/vk104/vk105。详见 reports/q28-DOSSIER.md §o/§p、reports/q28-retro-audit-20261011.md。 — Failed: 旧结论多被构建身份混淆，需以 PINUTS 重测才有效
---
Q24「死亡」实为 SoC 级复位 + 约 30–42 s 自动重启（USB 掉线→重新枚举实测 32s/42s/32s），不是静默永久挂死。⇒ 判死可用「USB 是否重枚举 / trace 流是否终止」而不用物理 POR。历史「需要物理 POR」的口径已作废。
---
Waydroid 镜像自带 HIDL android.hardware.vibrator@1.0-service.waydroid 只写 AOSP leds/timed_output 节点（主线两处都没有），且 ofstream 不检查写失败 ⇒ 容器侧一切正常但马达不动——「HAL 无输出」的原因是内核缺对应 sysfs 节点而非 HAL 逻辑，定位此类问题要看节点是否存在，不要只看 lsof/lshal 是否注册。
---
trial.sh record 子命令强制要求 --label（报 '[trial] ❌ record 需要 --label'）；q28-devprobe2.sh 的 L2 正则原先漏了 'vblank wait timed out'（Q28 上游栈的典型失败签名），补充为 `ctl [0-9]+ reset failure|frame done timeout|vblank wait timed out|drm_crtc_wait_one_vblank`。
---
Q24 真机理（2026-10-15 复核，报告 reports/q24-causal-audit-20261015.md）：触发源不是「camcc+cambist 电学配对」，而是 rpmhpd 电源域 provider 的 sync_state 门控。rpmhpd.c：state_synced=false 时 aggregate 把全轨夹到最高档 (level_count-1)，仅 gfx/gmxc 有 presync_floor；driver core 在所有消费者绑定后调 rpmhpd_sync_state() 释放 clamp、按真实票重投 → 批量投 0（即 PITFALLS #197/F8 现象）。设备实测全天候只有两条 pending：`qcom-rpmhpd 16500000.rsc sync_state() pending due to ade0000.clock-controller (camcc)` 与 `… 1760000.clock-controller (cambist)` ⇒ 装其一仍 pending 存活、两个都装才触发。软件层验证（N1 配对加载前后 dmesg rpmhpd pending + pm_genpd current_state，不熄屏；N2 两 CC power/control=on 保票后真熄屏）。
---
用户纠正（2026-10-18）：「设备当前是 q28 坏态，屏幕无法确认是否拉起了容器。命令没有设置超时」——Q28 坏发（面板未点亮、屏幕全黑）下跑 `waydroid session start`、`lxc-start` 等前台阻塞命令必须包 `timeout -k`、丢后台写日志，并用 `waydroid status`/进程/日志判定是否起来，不能指望目视屏幕；否则命令挂死且无人能判断状态。 — Failed: 硬件坏态下前台阻塞命令会让会话卡死且无判据
