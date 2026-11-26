# y700-elden — 内核/引导类失败与洞察：刷机 / fastboot / EDL / GPT / 分区与打包

> 2026-11-26 从 `failures-kernel.md`（199 KB / 346 条）按主题机械拆分：**每条逐字搬移，未改一字**。
> 检索口径不变：`mem -t project <关键词>`（= `~/.pi/agent/projects-memory/<repo>/` 软链到本目录，`find -name '*.md'`），拆分不需改工具。
> 入口与本表 = `failures-kernel.md`（索引件）。

---

改 GPT/缩 userdata：TWRP 在线 resize.f2fs 保不住——ZUXOS 检测到容量不符会反复重启卡 logo，fs_mgr 也因 f2fs 自认旧容量挂载失败 bootloop。必须 GPT 手术后 `fastboot erase userdata` + `erase metadata` 让 Android 重建。
---
设备实验脚本禁忌：不要把 reboot/fastboot boot 等副作用与长轮询写进同一条 bash 命令——harness 按超时杀整条命令（"Command aborted"），副作用是否发出无法判定；一条命令只做一件事，轮询自带 timeout。ssh 里也不要长 sleep 等设备（会被中断），应 nohup 起后台后立即返回，再用独立短命令轮询，每次 ConnectTimeout=6。`adb shell su -c '<复杂命令>'` 不可靠（复合/带引号命令被吞），可靠做法是在设备端 root 终端里逐条执行。
---
给用户执行 fastboot 命令时必须是「单条、可直接手敲」的形式，禁止用封装脚本（to-fastboot.sh / cycle.sh 等）跑 fastboot——命令有限、深层嵌套难预测、故障率高；脚本只用于主机侧构建/打包。每次进 fastboot 后、任何操作前先 `fastboot --set-active=a`。
---
`kexec_file_load` 的 `--dtb` 是**空操作**：该 syscall 无 DTB 形参，新内核 FDT 由内核用 live DT 重建（drivers/of/kexec.c `of_kexec_alloc_and_setup_fdt`，只改 bootargs/kaslr-seed/linux,booted-from-kexec）。kexec-tools 自己就打印 `arch_process_options: dtb: (ignored)`。⇒ iterate.sh 的 DTB 环（依赖 kexec 传 DTB）从设计上不可能生效，DTB 变更只能走 `fastboot boot`/`--flash`。 — Failed: RUNBOOK §8 与 kexec-boot.sh 曾把 --dtb 当有效参数。
---
kexec_file_load 无 DTB 参数：命令行 `--dtb` 被忽略（内核用 live DT 重建 FDT，drivers/of/kexec.c of_kexec_alloc_and_setup_fdt）；`kexec -v` 输出会直接打 `dtb: (ignored)`。⇒ 任何依赖 kexec 传 DTB 的迭代环（改 DTS → kexec 热加载）不成立，DTB 变更只能走 fastboot boot/--flash。
---
fastboot boot「报 OKAY 但 uname 仍是旧内核」时的单变量判定法：(1) 先用已知可启动镜像（如 vk58c-slim）确认 fastboot boot 机制本身正常；(2) 再交叉组合「新内核 + 旧 DTB」——vk59 内核 + vk47 DTB 能正常启动 ⇒ 挂启动的是 DTS 改动而不是内核 config。随后可用内核自带 dtc 反编译 DTB + fdtput 做逐项单变量（关 NFC / 关 CDSP / 回退 ramoops），免重编内核。 — Failed: 连续两次 fastboot boot 后 uname 仍是 vk47clean，易误判为 fastboot 失效
---
initramfs/busybox 的 applet 名单必须用真二进制校验，不能靠猜：本机那份 aarch64 busybox v1.38.0 静态二进制实际只有 282 个 applet，而手写的 busybox-applets.txt 有 272 项且是错的——含假项（blkid / mountpoint 实际不存在，会导致根分区解析失败回退纯 RAM），并漏 30+ 真项。权威判定：主机有 qemu-aarch64，直接 `qemu-aarch64 ./busybox --list` 拿真名单；scripts/check-init.sh 已加「名单 vs 实际 --list 一致」检查。另：新名单若含 `busybox` 自身，`ln -sf busybox bin/busybox` 会把真二进制替换成自指符号链接（ramdisk 缩到 12K）——build-boot.sh 已加防御。
---
G1-30 slim 最小 initramfs 的根分区解析器：busybox 里**没有 blkid 也没有 mountpoint 小程序**，只有 findfs。init 的 LABEL=/UUID=/PARTLABEL= 解析必须用 findfs 为主（blkid 仅作 fallback），不能依赖 blkid；check-init.sh 的判据是「findfs 或 blkid 至少有一个」。
---
项目规则修正（2026-10-06，用户明确要求）：旧规则「每次进 fastboot 后、任何操作前先 `fastboot --set-active=a`」是错的，已从 AGENTS.md 删除——本意只是不影响可用的 b 槽。fastboot 类命令仍由用户亲自执行，助手只做分析并给可直接手敲的单条命令，不用封装脚本跑 fastboot。
---
文档纪律：无设备证据不得写「已修复」——PITFALLS §0 零号纪律第 4 条（2026-10-06 新增）；被推翻的中间态（如 #5 kexec 六段过程）收窄为结论+指针并标 ⛔superseded，保留沿革但移入 archive。
---
GNU cpio `--reproducible` 只归零 inode、**不归零 mtime**——同一输入连打两次 boot.img sha 仍不同（差异字节正好落在 cpio 头的 mtime 字段，差 1 秒）。这是版本台账里 ramdisk hash 乱跳的根因。让 initramfs/boot.img 可复现需三处一起做：全树 `touch @SOURCE_DATE_EPOCH` + `LC_ALL=C sort -z` 排序文件列表 + `gzip -n`（去掉 gzip 时间戳）。 — Failed: 曾据此把 manifest 里 ramdisk sha 不同误判成「ramdisk 内容变了」，污染 DTB/initramfs 归因结论
---
本机给 kexec/fastboot 取证抓串口日志的可靠姿势：`while true; do [ -e /dev/ttyACM0 ] && cat /dev/ttyACM0; sleep 0.5; done >> logs/serial-<date>-<topic>.log`（配合 scripts/serial-run.sh 经 /dev/ttyACM0 执行命令，依赖设备侧 ttyGS0 挂 shell）。但 console 主要走 tty0，早期内容串口常抓不到；/dev/ttyACM0=ttyGS0（cmdline console=ttyGS0,115200）、/dev/ttyACM1=adb 口；pstore 为空。 — Failed: 串口抓不到早期内核日志，需知正确通道与局限
---
板级 DT 改动（如新使能一个 QUP/I2C 控制器）在本机可能直接导致整机无法进内核（亮屏即灭/掉电，无输出、复位回 b 槽）。此类改动一律做成独立 DTB 变体镜像走 fastboot boot 零写盘验证，绝不直接刷 boot_b。
---
「用户亲自执行 fastboot/EDL」是断联场景下的一次性偏好，被升格成项目硬规则后已按用户口径放宽：agent 应首先自主执行（有写坏风险的先备份再执行），只有超出预期的错误再请用户检查/物理干预。项目级行为规范已统一入口到 .pi/AGENT-OPS.md（AGENTS.md 只留项目描述，不再夹带规则）。 — Failed: 偏好→硬规则升格 + 范围扩张（D1 语义漂移），用户随即要求放宽
---
项目文档会出现语义漂移：同一动作前后口径翻转（fastboot --set-active 从「进 fastboot 后先执行」变成「未授权写操作」）、禁令被压缩成理由（「不要用封装脚本跑 fastboot」只剩括号解释）、术语份数不一致（领域层 4 份 vs 5 份）。对策=定期做语义漂移审计（archive/topics/SEMANTIC-DRIFT-AUDIT-*.md），把规则按「行为规范 / 开发经验 / 项目描述」三分归口并互不复述。 — Failed: 2026-10-06 语义漂移排查发现 7 处矛盾
---
CDSP bring-up（G1-11）取证结论（2026-10-06，vkD2-cdsponly 实机）：remoteproc1 存在但 state=offline；`cdsp.mbn` 装载成功，`cdsp_dtb` 报 -22（EINVAL，来自 qcom_scm_pas_init_image —— SCM 拒绝 DTB metadata）。已排除「固件文件命名/格式」假设：换成 vendor 的 split 格式（cdsp_dtb.mdt + .b00/b01/b02，与 adsp 成功的方式一致）仍 -22 ⇒ 指向 PAS id 不匹配（驱动 sm8650_cdsp_resource 用 dtb_pas_id=0x25，需与 vendor SCM 期望的 id 对齐），下一步查 vendor DT/stock 源码里 cdsp 的加载 id。注意：remoteproc unbind/rebind 会因 reserved-mem 未释放而失败（`assign memory 0 failed`），验证固件改动必须冷启动（fastboot boot）。
---
只改 DTB 的 `fastboot boot` 镜像若静默回退 boot_b，特征 = 设备起来的 `uname -r` 是 boot_b 的 UTS（如 vk47clean）且 dmesg cmdline 带 `androidboot.*`。判「镜像到底起没起」必须比对镜像 manifest 的 kernel_uts 与设备实际 uname，别只看 fastboot 返回 OKAY。本案 dp1（带 `&i2c0 status=okay` 的 DTB）就是这样被误判为「role-switch 改动导致黑屏」。
---
本用户在设备已进 fastboot 时会主动告知「设备已经进入fastboot，可以继续」/「就绪」——不要因为 SSH/`fastboot devices` 一度为空就断言设备死掉或反复重试；按 AGENT-OPS 停下报告现场、等用户物理恢复即可。另：用户明确「ssh 走有线（USB-NCM，主机 192.168.7.2 / 设备 192.168.7.1），无线每次 IP 会变动」，排查连通性优先走有线。
---
本机 `to-fastboot.sh` 在设备侧执行时会卡住（timeout 300s 被杀，设备仍在 Linux）——需要 reboot 到 fastboot 时，detached 地跑单条 reboot 命令，或直接请用户手动重启到 fastboot。
---
从 boot.img 抽内核 UTS 的正确做法：找首个 b'\x1f\x8b\x08' 后 zlib.decompress(wbits=16+MAX_WBITS) 再 re.search(rb'Linux version (\S+)', k)。注意 \(S+ 贪婪会截错 manifest 字段，且脚本里正则须用 raw string（否则 SyntaxWarning invalid escape sequence）。105 个镜像中 99 个能抽到 UTS（dtbo-dummy.img 只有 4096 B 抽不到）。
---
kexec 诊断旋转开关必须跑在「运行内核」上：kernel_restart_prepare/syscore_shutdown/device_shutdown 都是发起 kexec 的运行内核在执行（不是被装载的目标 Image），所以必须 `fastboot boot` 起带开关的 diag boot.img 再发起 kexec——这是 R2 测试设计错的教训，vk65+ 已按此做。 — Failed: R1/R2 kexec 取证 design error，把 fix 装在目标镜像而非运行内核
---
用户 2026-10-09 明确修正：`scripts/to-fastboot.sh --boot`（脚本自动进 fastboot + 执行 `fastboot boot`）**对该设备不响应**。正确分工 = agent 准备好镜像路径，**`fastboot boot` 由用户手动执行**；agent 侧只做「等待 SSH 回来」的轮询。这与旧口径「单条 fastboot 命令优先由 agent 自己做」不矛盾——问题不是单条命令，而是脚本内嵌的 fastboot 交互链（进 fastboot + 发 boot 命令 + 等结果）在该设备上不可靠。 — Failed: Agent 调用 scripts/to-fastboot.sh --boot 试图自动完成 fastboot boot，被用户打断并告知 fastboot 对该脚本不响应，要求手动 boot。
---
设备图形界面冻死行为（2026-10-09 vk72 实测）：进入 phosh/phoc 图形界面后整机卡死（phoc compositor hang）⇒ 所有 USB 接口从主机 lsusb 消失（无 18d1:d00d fastboot、无 NCM enx、无 EDL 05c6）——这不是硬件断电，是内核/compositor 挂死导致 USB gadget 不响应枚举。远程通道全断，唯一出路 = 用户物理按 power+vol_down 进 fastboot（或长按 power 强制关机再开机）。诊断脚本里遇到 ping 不通 + lsusb 无设备时，应直接请用户物理操作，不要反复重试 SSH/fastboot。 — Failed: agent 把「USB 消失」误判为需要冷启断电，实际用户用按键切到了 fastboot
---
「USB 消失」≠ reboot2 回归（2026-10-09 更正）：连续温复位循环里设备从 lsusb 完全消失，我第一反应归因 reboot2 有 bug，**实为 PITFALLS #106（进 GUI 后整机静默冻死）复发**——内核已挂死，reboot2 根本没机会执行。用户目视确认「进了桌面然后不懂」即定案。教训：设备离线先按「冻死 vs 关机 vs 掉 USB」三分，不要凭上一条命令的失败点推断。 — Failed: 连续 fastboot boot 温复位循环中设备从 USB 总线消失，误判为 reboot2 工具 bug，实际是 #106 GUI 冻死
---
静默冻死取证破法（2026-10-09 落地）：本机 ramoops 后端**本来就活着**（4 MiB @ 0xc2000000，ramoops-1 console 已注册，所有 printk 进 RAM），pstore 目录空只说明从未有 crash 落盘。APSS 硬看门狗被永久禁用 ⇒ 死挂永不自复位。破法 = cmdline 加 `softlockup_panic=1 softlockup_all_cpu_backtrace=1 panic=20`：软锁 → panic → 20s 暖复位 → 重启后 /sys/fs/pstore 带回完整栈。已做进 vk76-freezetrace（sha d696f08e…），持久化到 /etc/sysctl.d/ 或 boot.img cmdline 即可长期生效。
---
设备从 USB 完全消失（fastboot/NCM/EDL 全无）≠ reboot2 二进制的锅——真因 = **PITFALLS #106「进 GUI 整机卡死」复发**（内核已冻死，reboot2 根本没执行）。判据：用户目视确认「进桌面后卡死」→ 物理按键进 fastboot。不要凭 USB 消失归因给 reboot2 / 硬件。已改 PITFALLS #143 口径。 — Failed: agent 最初把设备 USB 消失归因为 reboot2 安全默认改动引入回归，用户纠正为 #106 图形冻死；agent 据此撤回旧结论并改 #143
---
Q28 坏发 vs 好发寄存器对拍（vk75 实测）：`dsi1vco_clk rate=0`、`dsi1_isr=0`、byte 时钟 108≠133 MHz 在好发里**一模一样**——全被否。唯一真差异 = 中断总数（mdss irq / dsi0_isr），但属「什么都没跑起来」的症状非原因。连续温复位（reboot2→fastboot→fastboot boot）会把面板**粘在失败态**（5/5 坏），冷启（长按电源 20s）恢复。诊断结论写进 vk75 补丁 commit message。 — Failed: agent 首轮上机仅采坏发、把 dsi1vco=0 当头号线索，冷启好发对照出来后被否——教训：差分必须有健康基线
---
vk64 在机内核（7.2.0-debug-vk64-gd02658e63cf6）的 CONFIG_ATH12K=y / 触屏/音频/背光全 =y（**fragment-modular 之前**的构建），而构建树 .config 已全量应用 fragment-modular（1523 .ko 已编好）。模块化收益（mod-loop 30s 迭代）只在**下一次刷入基于新 .config 的镜像**后才兑现；当前 vk64/vk72 上 modprobe 找不到这些驱动（它们是 built-in）。验证模块化需 fastboot boot 新构建的 boot.img。
---
Q28 取证通道硬约束：设备从 fastboot→Linux 时 ttyACM 先消失再重新枚举（gadget 重建），`cat /dev/ttyACM0` 循环会在 ttyACM 消失时报错退出、重连后已**错过 0–20s 内核早期输出**（含 ~9s 的 DSI init/modeset/Q28 触发窗口）。⇒ **串口时序不可靠**，不能用于判 GOOD/BAD。正确做法 = 启动后 SSH 进设备读完整 `dmesg`（环形缓冲含全部 boot 行，与串口何时接上无关）。scripts/q28-devprobe.sh 已按此实现。 — Failed: cold A/B trial1 串口只抓到 uptime=23s 之后的输出，0–20s（含 DSI init 与可能的 PLL lockfail）完全丢失，误判 NOBOOT
---
RUNBOOK §8 四档迭代环实际状态（2026-10-10 盘点确认）：mod 热载 ~30s 要求 tree KV==device KV（默认 boot_b=vk64 vs 树 HEAD 必拒，需先刷 boot_b 或 --force）；kexec 已定论不可用；dtb 环 kexec 不传 DT 是空操作；唯一实际可用环=全量编+`fastboot boot`（~5min），但冷起 Q28 面板间歇失败（~60%）阻塞日常迭代。结论：迭代链瓶颈不在编译速度，在「上机验证的可靠性」（Q28 冷起 + 无 kexec + mod-loop KV 锁）。 — Failed: vk81/82/83 三个死内核镜像（olddefconfig 静默删 ARCH_QCOM）流入上机浪费 3 轮设备时间；mod-loop 默认拒绝导致开发者绕过闸门手写 manifest
---
mod-loop.sh 的 KV 对齐守卫（device KV == tree kernelrelease 才放行）在 boot_b 固定为 vk64 时，任何内核树前移（新 commit/tag）都会使 mod-loop 立即失效，直到刷 boot_b 或手动 --force。实际效果：开发者要么每次刷 boot_b（失去零写盘优势），要么绕过闸门（风险）。正确做法=保持一个与树 HEAD 同步的「开发 boot」或用 `fastboot boot` 替代。 — Failed: 本次会话发现树 HEAD=7.2.0-debug-ga8c09a723254 而 boot_b=vk64（7.2.0-debug-vk64-gd02658e63cf6），mod-loop 必拒
---
软件 POR（`busybox poweroff -f`）实测结论（2026-10-10 vk64）：确实产生真断电（USB 重枚举 + 新 boot_id + uptime 归零 + VBUS 自动开机），**但不可用于无人值守自动循环**——3 轮连续跑中第 3 轮 boot 后内核卡死（GUI 冻住、音量键无响应、SSH 超时、不在 fastboot），需用户物理冷启恢复。判据：run1=GOOD、run2=STORM（正常概率）、run3=HANG（非 Q28 两种已知签名，是新故障模式）。另：`loginctl poweroff`（OpenRC 停服务路径）在 STORM 态下挂住——OpenRC 试图 stop 与死 DPU 交互的服务后永不返回；只有 `busybox poweroff -f`（直调 reboot(2) 绕过 init/notifier）或 `echo b > /proc/sysrq-trigger` 能脱离 STORM 态。结论：迭代流程第 3 项（软件 POR 替代人工断电）**否决**，仍须用户物理断电做冷起对照。 — Failed: 自动化 POR 循环第 3 轮内核卡死，证明软件 POR 后的一次 boot 可能触发未知内核死锁（与 Q28 STORM/NOCARD 均不同），不可无人值守
---
Agent 仅凭 SSH 恢复 + 新 boot_id + USB 重枚举就宣布「软件 POR 成立」（busybox poweroff -f），但第二轮自动循环时设备 GUI 卡死（音量键无响应、USB/SSH/fastboot 全消失），用户纠正「实际上没有测试成功」。教训：对显示相关验证，SSH 活着 ≠ 系统正常；必须同时验屏幕输出 + 用户目视确认。自动密循环（poweroff→wait→probe→poweroff）在本设备上有内核挂死风险（第二轮触发），绝不能无人值守跑。 — Failed: Premature success claim based on partial signals (SSH+boot_id) while display was actually broken; unattended soft-POR loop caused kernel hang on iteration 2
---
自动设备循环（POR→boot→probe→POR→...）在 Q28 STORM 态下必死：坏发内核关机路径被 DRM storm 占死（reboot/reboot -f/busybox poweroff -f 全无效），USB gadget 可能不枚举，SSH 不通，fastboot 不在——设备变成只能物理断电的砖。本轮实测：run1 成功（暖态 GOOD）→ run2 自动发第二拍 poweroff -f → 内核卡死 → 设备失联 → 用户手动长按电源 20s 恢复。规则：任何涉及设备的循环脚本必须 (a) 每轮间等用户目视确认屏幕/物理按键响应（用户在场时 ≤3 轮），(b) 上轮 probe 返回非 GOOD 时立即 abort 不自动发下一拍，(c) 绝不无人值守密循环。 — Failed: Q28 软件 POR 自动循环 run2 在内核卡死态下继续发 poweroff -f，设备变砖需用户物理恢复
---
Q28 STORM 态下 SSH 饥饿机制（2026-10-11 实机确认）：面板 init 失败（bonded DSI cmd-DMA timeout）→ DPU vblank/frame-done 风暴 → drm_fb_helper_damage_work 占满 workqueue → SSH sshd 虽 LISTEN 且 TCP SYN 可达（ping 通）但 banner exchange 永远超时（sshd 的 worker 排不上 workqueue）。串口 /dev/ttyACM0 只有内核 log 输出、**无 shell**（cmdline console=ttyGS0 是 log-only gadget，不挂 getty）。唯一恢复 = 物理长按电源 20s + 音量下+电源进 fastboot。不能靠 SSH 重试或等待（风暴无限循环，非瞬态）。 — Failed: Q28 面板 init 失败后设备 ping 通但 SSH 永久挂起，误判为网络问题导致浪费时间；实际是 workqueue 被 DPU 风暴占满、sshd 饿死
---
@internal: 长命令/长测试被用户取消时 pi agent 看不到中断前的工具输出 ⇒ 任何长跑/扫掠脚本必须实时写文件（tee -a / 后台 nohup > log），agent 从文件读结果并在汇报里给 log 路径。本会话用户曾中断 `fastboot boot` 循环与 SSH 轮询，恢复靠持久日志而非 stdout。
---
build-modular-overlay.sh 的 payload 闭包计算会包含 qcom-camss.ko（单 12MB）+ 全部音频模块（snd-usb-audio 7MB 等）共 25 模块 ≈ 35MB，导致镜像涨到 98MB 逼近 fastboot boot 96MiB 上限而被拒收（表现为 fastboot boot OKAY 但设备回落到 boot_b，串口确认跑的是旧内核）。修法 = 加 ROOTS 环境变量覆盖（默认含全部相机+音频根，设为 `ROOTS='camcc-sm8750 cambistmclkcc-sm8750'` 时只算 2 模块闭包 ≈ 2MB，镜像回到 86.7MB）。已落地到 scripts/build-modular-overlay.sh。 — Failed: vk91-fix3mx 首次上机时镜像 98.3MB 被 fastboot boot 静默拒收，串口显示跑的是 boot_b 旧内核（vk64），误判为 FIX-3 内核挂死。
---
arm 镜像模块闭包膨胀超 fastboot boot 上限（~96MiB）：build-modular-overlay.sh 默认 ROOTS 含全部相机+音频模块（qcom-camss.ko 单 12MB、snd-usb-audio 7MB…），闭包算到 25 模块 11.8MB→镜像 98.3MB→fastboot boot 静默拒收→回落到 boot_b（表现为「vk91 启动后跑 vk64」）。修法=给 ROOTS 设环境变量覆盖，Q24 三臂只需 camcc+cambist 两个 .ko（86.7MB 通过）。判据：镜像 >96MiB 就大概率被 fastboot boot 拒收。 — Failed: 默认 ROOTS 含 qcom-camss 等 25 模块使闭包膨胀到 98MB 超 fastboot boot 的 ~96MiB 传输/加载上限
---
对 `fastboot getvar` 等 fastboot 命令套 `timeout ... | head/tail` 会因 SIGPIPE 中途掐断 fastboot 客户端，把设备 fastboot bulk 通道打断 → gadget 从此不应答（`fastboot devices` 仍列出、`getvar` 超时 rc=124、USB 设备号不重枚举），恢复只能物理 POR。fastboot 命令不要接管道截断。 — Failed: 2026-10-12 本轮我操作失误导致设备卡 fastboot，用户被迫做物理 POR
---
设备侧脚本必须 POSIX sh 兼容或显式用 bash 调用：设备 shell 曾被误设 zsh（报 `zsh: no matches found`/`== not found` 会静默中断整条远端命令，不是设备/驱动问题）。已切回 bash（mainline root 登录 shell = /bin/bash）。另：给 /dev/ttyACM* 串口抓取脚本写 `timeout … | head/tail` 管道会因 SIGPIPE 掐断 fastboot/串口客户端（快排查询 `timeout … | head/tail` 曾打断设备 fastboot bulk 通道 → gadget 从此不应答，84MB 传输全部白等）——探测 fastboot getvar 也要用完整输出、不要管道截断。
---
scripts/serial-logger.sh 无执行位（nohup 直接跑报 Permission denied），须用 `bash scripts/serial-logger.sh <log>` 启动。串口 logger 依赖 /dev/ttyACM0 存在——设备在 fastboot 时 ttyACM 不出现，logger 会空转等待；用户手动拔/插串口会中断日志（本轮即因此漏掉一段冷起日志）。
---
二阶循环脚本要「只等不推」：`scripts/q28-cold-sample-loop.sh`（2026-10-12）只负责等 fastboot（最多 900s）→ fastboot boot → SSH 起 → 三态判据（q28-devprobe.sh）→ 存活门 65s → 记 TSV；**不做自动重启进 fastboot**（自动路径因未就绪 reboot2 挂机不可用）。用户明确「这个脚本有问题，没法做重启到fastboot。我手动por两次，总共测试了三次，都成功」——冷起采样由用户手动 POR 驱动，脚本只等。每轮须过 device-lock，结束 qbootctl -m b。
---
脚本未经解释就不要拿来跑：`scripts/q28-cold-run.sh` / `q28-cold-sample-loop.sh` 设计上只**等** fastboot（无物理按键能力），冷起采样必须由用户手动 POR（长按电源 → Vol- + 电源进 fastboot），脚本再接手 fastboot boot + 判据 + 记录 TSV。用户当场指出「这个脚本有问题，没法做重启到 fastboot」是预期行为（不是 bug），派脚本前必须对用户讲清这一点。
---
**`reboot2` 未就绪挂机**（2026-10-12 实测，PITFALLS #225）：设备 uptime < 25 s 时直接调 `reboot2` 会把设备挂到无 USB 通道（2/2 挂），uptime > 100 s 时正常（3/3）。⇒ 所有自动化复位脚本必须先过就绪门 `scripts/lib-boot-ready.sh`；`scripts/q28-cold-sample-loop.sh` 明确**不做自动重启到 fastboot**（自动路径不可用），只等用户手动 POR。 — Failed: 自动化循环里过早 reboot2 会挂死设备，需就绪门。
---
本机构建产物核对：`fdtget` 未安装（读 DTB 节点/status 用不了）；boot.img 头部参数要用 `tools/mkbootimg/unpack_bootimg.py`（仓库内有 vendored 副本）。打包 M1 镜像时 mkbootimg 调用路径必须是仓根 `tools/mkbootimg/mkbootimg.py`，用绝对/临时路径（如 /tmp/73j-ovl/tools/...）会 `No such file or directory` 但外层不报失败。
---
构建 P1/P2b/P2c/P4a 这类上游对照臂时必须保持构建身份可比：kernel `CONFIG_LOCALVERSION_AUTO=y` 时 UTS 会出 `-g<sha>` 后缀（新提交变新身份），要得到与基准（P2c 的 7.3.0-rc7-debug-g2851bcaff64f）一致 UTS 需改 `CONFIG_LOCALVERSION="-debug-g2851bcaff64f"` + `LOCALVERSION_AUTO=n`。提交时漏 `git add` 某 tracked 文件会让 setlocalversion 产出 `+`/`-dirty` 后缀，需 amend 重编保可复现身份。overlay 的镜像内拷贝路径须用相对前缀（绝对路径会在 lib/modules/<KV>/ 下建出 home/xuqianhui1001/... 整条树）；fastboot boot 上限 100663296 B。
---
单变量显示/内核臂打包纪律（2026-10-14 实践）：ramdisk/DTB 必须**逐字节复用参考成品镜像内的组件**（从现成 boot.img unpack 取，而不是用 out/rootfs-*.cpio.gz，两者不同），保证唯一变量在内核；UTS 必须精确钉死（`CONFIG_LOCALVERSION="-debug-<sha>"` + `CONFIG_LOCALVERSION_AUTO=n`），否则 `-dirty`/`-g<sha>` 后缀会破坏构建身份可比性（提交时漏 add tracked 文件也会带 dirty）。设备/主机上 `rm` 跨设备会报 EXDEV（/tmp vs 家目录不同挂载），属无害噪声。
---
scripts/arm-console-run.sh（零写盘启动显示臂 + 串口内核控制台取证，不依赖 SSH）的 verdict 行解析 bug：`[: 0\n0: 需要整数` —— L1/L2 计数被 multi-line 输出打断导致打印成两行，判据 VERDICT 仍可读但计数不准。用法 `scripts/arm-console-run.sh <boot.img> <label> [wait_s]`（前提设备已在 fastboot），输出 logs/arm-<label>-<ts>/{console.log,verdict.txt}。设备侧 console=ttyGS0,115200 经 USB gadget 暴露为 /dev/ttyACM0（控制台**无 shell**，只有内核日志）。
---
`fastboot` 对复杂脚本/封装的支持有限，可能根本不响应——`fastboot boot` 等指令必须作为**单条纯命令**直接执行（用户 2026-10-14 明确要求记为高优先级）。实测：`scripts/arm-console-run.sh` 这类复合脚本里的 `fastboot boot` 被静默取消（无输出、不进 fastboot），而手敲单条 `fastboot boot <img>` 立即成功（Sending OKAY 1.9s / Booting OKAY 10.1s）。同理 `to-fastboot.sh` 可用但其中封装的 fastboot 步骤不可靠。 — Failed: 复杂脚本内嵌 fastboot 调用静默失效，被误判为设备/脚本问题
---
fastboot 对复杂脚本/封装命令支持有限：把 `fastboot boot <img>` 放在复杂的 bash -c / wrapper / 多步脚本里（尤其带变量插值、nohup、串口 reader 同批）时可能根本不响应或静默不执行（表现为容积里无输出、日志目录未创建、设备仍停在 fastboot）。可靠做法 = 用**单条纯命令**执行 `fastboot boot out/xxx.img`（发送+启动两次 OKAY 约 12s），串口/SSH 读日志单独另开一条命令或后台进程。同理，需要看 fastboot 输出时不要把它塞进复合脚本。 — Failed: 用户 2026-10-14 观察并确认「脚本似乎没有启动fastboot 的boot指令，可能是复杂脚本对fastboot支持不好」，随后拆成单条命令即成功
---
fastboot 对复杂脚本/批量封装的调用支持有限，可能根本不响应：把 `fastboot boot` 塞进带引号、变量插值或多步逻辑的复合脚本（含 nohup/bash -c 包装）时，常表现为「脚本跑了但 fastboot 没启动镜像」或整段静默不执行（输出为空、日志目录未创建）。可靠做法 = 每条 fastboot 命令单独提为一条纯命令直接执行（PITFALLS #3 的口径），进 fastboot 用 scripts/to-fastboot.sh（PSCI vendor reset）单独一步，再单独一条 `fastboot boot <img>`，串口取证另起 reader。用户 2026-10-14 明确要求记住此条。
---
本机（xuqianhui 新机，换机后）fastboot = ~/.local/opt/platform-tools/fastboot（v37.0.1，从 dl.google.com 直接下载 zip 解压，无需 sudo）；系统 PATH 里原本没有 fastboot。设备不支持 fetch（判据与替代手段见本文「fastboot 不存在 fetch 功能」条）。
---
文档/脚本里的命令能力必须在本机实测验证过才可写入口径——`fastboot --help`/工具帮助文本列出的子命令不等于本机设备支持（fastboot fetch 即典型幻觉）。用户要求「类似检查所有可能记错的地方」= 对全库做能力幻觉审计（grep 所有文档/脚本里的工具/命令用法，逐条核对是否本机可行），并对确认错误的处做替换修正 + 新增 PITFALLS 条目记录。
---
写文档/脚本前应先在本机实测命令能力，不要照抄 `--help` 或历史文档；本仓曾有多处把 fastboot fetch 写进备份配方（INDEX/RUNBOOK/PITFALLS/AGENT-OPS/TASKS/build-locked-chain.sh/DEVICE 共 6+ 处）——属「能力幻觉」类错误，排查时要全库 grep 同类可能记错的命令。
---
主机/文档排查「记错的能力」时的两类区分：① 命令能力幻觉（如 fastboot fetch、fastboot reboot fastboot 未验证）→ 改写成正确做法；② 文档指向已归档/不存在的脚本（本仓 26 处，如 scripts/q24-*.sh、q28-*.sh 已在 commit 6265d32「归档 32 个一次性 Q24/Q28 脚本」中被归档）→ 属文档指针陈旧，不是能力误判，登记为 debt 而不混入幻觉清理。
---
从内核 Image（Android boot.img 或 Image.gz 尾部）反查基线用的 DTB：Drive 用 Python fdt scan（fdt first 在 Image 文件里的偏移 + magic 检查 FDT_MAGIC=0xd00dfeed、total size 字段），2026-10-17 实测从 `boot_b-m1-baseline-f3-20261017.img` 里提出 153101B 板级 DTB，反编译后可与我们重放版 DTB（140537B）做节点名/diff 对账。内核 Image 内的裸 DTB 往往多块，要找 total size 匹配的那块，别拿第一个 fdt 头（常常是 `device-tree$header` 之类 730B 小段）。
---
boot.img v2 头打包/解包正解 = scripts/mkbootimg.py（pack/unpack/--selftest）；丢失根因 = /tools/ 在 .gitignore:15（换机后 out/ 的 ramdisk cpio 与 tools/mkbootimg MIGRATION-LOST，可从抢救的基线 boot_b 镜像原位抽出 ramdisk：kernel 偏移 4096、ramdisk 紧随其后）。头字段坑：id 槽 20B sha1 必须补零到 32B、name@48/cmdline@64、header_size=1660。权威账 = MEMORY.md 的 mkbootimg 条 + PITFALLS 的 boot.img 打包条目。
---
自研 boot.img v2 头打包器的两个必踩字节级坑（2026-10-17 实测）：① AOSP 把 20 字节 sha1 digest 补零填进 32 字节 id 槽——直接 `hdr[576:608] = digest` 会让整个 header 缩 12 字节，所有后续字段错位（header_size/dtbsz/dtba 全落到错误偏移）；必须 `digest + b'\0'*12`。② 用 `bytearray` 分段 seek/write 容易出隐性 bug，改为「内存拼装完整镜像再一次写出」。自校验方法 = 用两个真实镜像（boot_b-m1-baseline-f3 / boot_b-before-vk94）逐字节复刻比对。
---
RAM 起自编内核（fastboot boot）前必须先部署 /lib/modules/<新UTS>（1497 个 .ko ≈85M），否则 lsmod 空、modprobe 静默失败、DP PHY/altmode 缺、DP 控制器永久 -EPROBE_DEFER、DPU 组件集不齐 ⇒ 无 card0（症状伪装成 Q28 坏发，2026-10-17 vk127 s1/s2 两次踩坑）。判据顺序 = ① lsmod 条数（空=模块树没上）② dmesg | grep 'bound ae94000.dsi' ③ 才看 L1 签名。权威 = PITFALLS 四十节（#293）；AGENTS.md 项目记忆第 3 条为常驻口径。
---
依赖设备在线长跑的任务（叉编、apt/apk 装包）中途掉 USB 很常见：设备 enx 网卡消失 + ping/SSH 全断 = 设备断电或 USB 链路掉，不是网络问题。恢复 = `fastboot devices` 看到 `HA2EXB0E fastboot` 后 `fastboot reboot`，约 24s 后 SSH 自动回来（2026-10-17 实测）。不要反复远程重试、也不要以为设备砖了。
---
设备失联判读：主机侧 USB 网卡 enx021e5eede102 消失、lsusb 出现 18d1:d00d（Google fastboot VID/PID）⇒ 设备在 fastboot，无写盘处置 = `fastboot reboot`（约 24s 回系统）。不要误判为系统挂死或 Q24/Q28。另注意：用户在平板上原生编译（ninja/make 8 核满载）会过热，用户会手动断电重启到 BL——遇到『编译中途失联』先怀疑过热而非驱动 bug。
