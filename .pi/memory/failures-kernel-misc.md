# y700-elden — 内核/引导类失败与洞察：其余（构建脚本、工具链、取证方法等）

> 2026-11-26 从 `failures-kernel.md`（199 KB / 346 条）按主题机械拆分：**每条逐字搬移，未改一字**。
> 检索口径不变：`mem -t project <关键词>`（= `~/.pi/agent/projects-memory/<repo>/` 软链到本目录，`find -name '*.md'`），拆分不需改工具。
> 入口与本表 = `failures-kernel.md`（索引件）。

---

kexec_file_load 热重载硬挂的取证分析（archive/topics/KEXEC-2026-10-05.md）：装载成功（RC=0、/sys/kernel/kexec_loaded=1）但 kexec -e 硬挂整机（无 panic/无看门狗复位，需物理复位，复位后 pstore 空）。两个主机侧硬缺陷：① --dtb 对 kexec_file_load 是空操作；② 本树缺上游修复 1537e55728ec。旧证据链（ttyGS0 gadget console 在 kexec 时必断）无法定位失败分支点，需一次带跳转期间存活 console 的上机取证；首测还不同源（运行 vk46-dirty vs 装载 vk50 构建）。定位挂死分支点必须有跳转期间存活的 console。
---
合并多份并发调查结果时的优先级裁决模式（2026-10-05）：用户会给出明确优先级（本案：kexec 解决方案 > 装完整发行版解决用户态问题 > 补全驱动），并要求把冲突按该优先级裁定后合并落盘。做法 = 先定位各调查的会话 jsonl 与专题文档，读最终结论，提取冲突点（本案 C1–C4）逐一裁决胜者 + 落地约束，产出合并文档（archive/topics/MERGE-*.md）并把决议回写领域层（TASKS §4 / INDEX）。
---
vk54 上机（2026-10-05）：内核本身与补过 record-size/max-reason 的新 DTB 均正常（能亮屏到锁屏），但落在锁屏处**卡死无法操作**——属历史出现过的罕见用户态/会话层 hang，无法定性，与内核/kexec 无关；该卡死导致 SSH/网络不通，会挡住需要 SSH 的取证，改用最小 busybox initramfs（无桌面/无锁屏）做 kexec 取证。 — Failed: 罕见锁屏 hang 挡住 SSH 取证通道
---
kernel_kexec 路径会调 kmsg_dump(KMSG_DUMP_SHUTDOWN) 后跳转 ⇒ 要跨 kexec 保存最后日志必须让 ramoops 捕获 SHUTDOWN：DT 里 ramoops@c2000000 默认缺 record-size/max-reason（运行值 record_size=0、max_reason=2 不含 SHUTDOWN），需补 `max-reason`/`record-size` 属性才可能落盘。这是目前唯一可能跨 kexec 存活并保存日志的通路。
---
用户的 kexec 分析会话期望「以分析为主、上机需报备」；长实验（如 kexec 反复上机）出现设备不稳时应立即停手并汇报，而不是继续自动推进。 — Failed: 设备不稳时用户明确指示停手。
---
`scripts/build-boot.sh` 与 `scripts/build-manifest.sh` 里的 `KDIR` 原本是硬编码 `KDIR=$ROOT/linux`，env 覆盖无效——想打包树外/已提取的内核会静默用到树内内核（曾误打出带 vk58 内核的「vk59」镜像）。已改为 `KDIR=${KDIR:-$ROOT/linux}` 并透传给 manifest；构建后必须核 manifest 的 kernel_uts 与镜像内提取的 UTS 一致。 — Failed: 误信 VERSION 名即内核版本，实际打进了树内内核
---
项目文档中的「归因错误」典型例：min initramfs 缺 /lib/firmware 致功放/触屏/ath12k 报 firmware load failed -2，但 switch_root 后自愈；vk60「驱动全废」实际是 initramfs 打包问题而非内核/驱动问题。归因时先区分「本体问题」与「打包/部署层问题」。 — Failed: 差点把 initramfs 缺固件误写成内核/驱动缺陷
---
boot 镜像 manifest 里的 ramdisk/kernel/DTB sha 若在测试期间被重建过，会污染「单变量对照」的结论：vk58c/vk59/vk59a/vk59-nfcoff 四张镜像 manifest 引用同一路径 `out/initramfs.cpio.gz` 但 ramdisk sha 各异（1047383d / 69493ffd / 085b5345），实际解包后 init/busybox/文件链接数完全一致（同 3 文件 272 链接）⇒ 差异纯属 cpio mtime 噪声。**判两个镜像是否真的不同应先解包比对内容 sha，不能只看 manifest 哈希**。
---
主机侧 diff 脚本若用 `grep -v` 过滤 phandle/注释行，容易把整段 diff 内容也滤掉只剩行号（本次出现过「我的过滤器把 diff 行全删了」），对 DTB 反编译产物做语义 diff 时要显式保留以 `>`/`<` 开头的差异行，或改用 dtc 反编译后去掉 phandle 属性再比较。
---
manifest 里 ramdisk hash 不同 ≠ initramfs 内容不同：build-boot.sh 每跑一次都重打包，cpio mtime 噪声会让 sha 变化。判断两个镜像的 initramfs 是否等价，要解包后比 `/init` sha、busybox sha、文件/链接数（如 `3 files / 272 links`），不要只看 manifest 哈希。
---
主机上 `dtc` 不在 PATH 里（command not found）；可用树内构建出的 linux/scripts/dtc/dtc（由内核构建产出）。反编译 DTB 核对内容时用它，不要以为没装 dtc 就没法验。
---
二分实验镜像命名靠 D/B/X/Y/f 等后缀区分（D=DTB 二分、B=最小二分、X/Y=kernel/DTB 交叉、f=full 载具重打），这些 ad-hoc 号不走 scripts/lane.sh alloc，会与账本冲突；构建前先 `ls out/ | grep -o 'vk[0-9]*' | sort -V | tail` 取最大+1，并把 ad-hoc 号补录进 versions/vk-registry.tsv。
---
运维纪律：boot 镜像的 verNN 号若不是内核号而是载具号（如 vk61 = 只换 /init），就不能用 uname -r 验证刷入是否生效——必须比对 kernel/dtb 段 sha256（与 boot_b 逐字节相同）或 uname -v 的编译时间戳。
---
同 UTS 串下区分不同内核构建必须用 `uname -v`（`#N SMP PREEMPT <date>`），**不能只看 `uname -r`**——候选内核为了对齐 LOCALVERSION 会锁成同一 UTS（如 vk47clean），只有编译时间戳能证明「新内核确实跑起来了」。相关：debug_mask=2 的 ath12k 调试日志会冲 ring buffer，使基于 dmesg 计数的差分统计变负。
---
内核 .config 中 CONFIG_LOCALVERSION_AUTO 决定 vermagic 是否含 git sha：同一源码树在 AUTO=n 时构建得到 `7.2.0-debug-vk47clean-gbd114ca335e1` 之外的短名。比对 mirror 镜像与工作树 config 时，`diff` 只差这一行即说明是同一配置来源（config-vk40-bringup vs worktree/.config 仅 CONFIG_LOCALVERSION_AUTO 一行之差）。 — Failed: config 对比时误把 LOCALVERSION_AUTO 差异当成实质配置分歧
---
评估「换发行版/换 init 能否解决技术坑」时，用户期望按「每笔成本单独归因、判断能否用装包/换服务解决」逐项算账，而不是笼统答「哪个发行版更健壮」；会明确要求「评估切换 init 的收益」。已验证结论：Alpine→Ubuntu 只能顺带清 U1–U7 共 7 项（会话/PAM/logind/busybox 类），这些 postmarketOS 已在 Alpine(musl) 上用 greetd+phrog+elogind 解决 ⇒ 维持不换发行版；分诊数字 = 装包可解 8 项 / 启用 OpenRC 可解 8 项 / 只有换发行版才有增量 3 项（增量都小）/ 内核+上游+硬件谁都解不了 6 项。
---
内核构建坑（2026-10-06 实机遇到）：在已有 vmlinux.o 的大树上重跑 `make` 时 `LD vmlinux.unstripped` 段错误（make 错误 139，重试仍复现），而 vmlinux.o 本身完好（1.7GB）——属工具链链接阶段问题。绕法：不要在同一树上重编全量内核；改用已知良好的内核 Image.gz（如 /tmp/kdirD2 的 vkD2 产物）只重编 DTB，做「仅 DTB 变」的单变量镜像。
---
内核主树 `LD vmlinux.unstripped` 可连续两次段错误（exit 139，`vmlinux.o` 本身完好）。绕过：复用已知良好的 `/tmp/kdirD*/` 内核产物（Image.gz+dtb），只替换改动的 DTB 后重打包镜像，做单变量验证。
---
生态级核查否掉了两个曾以为可替代自研件的候选：① mkinitfs（Alpine 官方 initramfs 生成器）不适用本项目——本项目 initramfs 刻意不带模块，而 mkinitfs 依赖 nlplug-findfs/lddtree 且与自定义 /init 冲突；② pmbootstrap/pmaports 不推荐——与 lane/vk 工作流、kexec/mod-loop 快环冲突，除非把项目目标改成发行镜像/上游化。另：pil-squasher 方向相反（主线 qcom PIL 要的就是 .mdt+.bXX 拆分），msm-firmware-loader 不需要（固件已打包进 rootfs）。真正值得纳入的只有 qbootctl（已采纳）与 alpine-make-rootfs 启发的「apk --root --arch 免 chroot」手法。 — Failed: 避免后续会话再次误判这些标准轮子可直接替换本项目自研件
---
评估「是否用标准生态件替换自研轮子」时，先做本地命中数核查（grep 项目文档里该方案名出现次数）往往全为 0，说明该生态轮子从未被纳入候选；但命中数 0 不等于应当采纳——必须逐项核实兼容性（如 mkinitfs 与本项目刻意无模块的 initramfs 冲突）后才能裁决，裁决结论要写清「已采纳/不适用/不需要/方向相反」而不是笼统的「可选」。
---
qualcomm remoteproc（qcom_q6v5_pas/qcom_pas）的固件必须用 stock **split** 形式（<name>.mdt + <name>.b00/b01/…）——单文件合并版 .mbn 会被 TZ PAS init 拒为 -22 EINVAL。且固件搜索路径在 switch_root 前由 initramfs 生效：只把固件放磁盘 rootfs 无效，`Direct firmware load ... failed with error -2` 表示载具（initramfs）里没有。诊断顺序：dmesg 看是 -22（格式/变体错）还是 -2（没找到文件）。 — Failed: G1-11 CDSP 曾长期 offline，旧假设「PAS id 不匹配」被否证；真因是单文件 .mbn 变体 + 固件必须打进 initramfs
---
cat /dev/ttyACM0（设备内核日志串口）会刷 `drm_crtc_wait_one_vblank+0x1b0` 的 vblank 警告风暴（T116 worker_thread / drm_fb_helper_damage_work），导致设备侧 SSH 变得极慢乃至超时——遇到 SSH 卡顿时先查串口是否被该警告刷屏，不是网络问题。
---
本机 `~/wt-athm`（worktree，detached bd114ca33 = vk47clean 源）里已有**完整的 vk47clean 构建产物**（vmlinux 658MB、Module.symvers、System.map，构建时间 2026-10-06 23:13），其中 `drivers/dma-buf/heaps/{system_heap,cma_heap}.ko` 的 vermagic = `7.2.0-debug-vk47clean-gbd114ca335e1`，与设备运行内核完全一致 ⇒ 可直接 scp 到设备 `/lib/modules/$(uname -r)/` 下 insmod，无需重编内核。设备 `/lib/modules/7.2.0-debug-vk47clean-gbd114ca335e1/` 原有 29 个模块但不含 dma_heap 这批。判「.ko 能否直接 insmod」= 比对 vermagic 与 `uname -r`。
---
判断相机成像旋转差时：stock vendor DTB 的 `sensor-position-roll`（如后摄 90/前摄 270）与主线 DT 的 `rotation` 值可能完全一致却仍然整体颠倒——因为「应用方约定」与 DT 约定可能是反向的，此时 R=90/270 都表现成 180° 误差。旋转属性在驱动里是 read-only（`camera_sensor_rotation` v4l2 ctrl，flags=read-only），改朝向只能改 DT 重刷；libcamerasrc 无 video-direction 属性，消费端（Snapshot 等）是读 libcamera Orientation 自行旋转。 — Failed: 会话中相机颠倒排查的关键结论
---
DTS 多变量实验纪律（2026-10-07 两次踩坑教训）：每轮实验跑完 `git checkout` 回退会把**上一轮已验证的改动一起回退**（dp5 两次构建得到与 dp3/dp4 逐字节相同的镜像）。正确做法：一轮实验需要的所有 DTS 改动**一次改齐** → 构建前 grep 逐项核验 → 编译 DTB 后比对 sha256 与上一版不同再打包镜像。快速拦截 = 比对 image_sha256 / dtb_sha256；发现与旧载具相同即说明改动丢了。
---
本机（xuqianhui1001）内核树 `make syncconfig`/`olddefconfig` 会把 `.config` 的 QCOM 子树整体弄丢（实测 2026-10-07：`CONFIG_ARCH_QCOM` 消失，build-kernel.sh 报 `ERROR: CONFIG_ARCH_QCOM missing in .config (corrupted by olddefconfig?)`，.config 从 321948 B 掉到 244347 B）。恢复源 = `patches/config-vk50-modular`（Oct 4，模块化相机配置，321948 B）或 `patches/config-vk40-bringup`。另：想让 `uname -r` 里带上 `vk47clean` 中缀（对齐磁盘模块目录）需显式设 LOCALVERSION，仅 checkout bd114ca33 只会得到 `7.2.0-debug-gbd114ca335e1`。 — Failed: 重编 release 时 syncconfig 破坏关键 config，且 LOCALVERSION 中缀不会自动出现
---
熄屏掉电（Q24）二分协议教训：用「载具启动后 rmmod 全部相机模块，再只加载一个子集」做二分不可靠——rmmod 卸载不干净（本轮 CAM_LOADED_AFTER_UNLOAD=6，camss 栈仍在），致死的可能是残留模块而非被测子集，结论作废。更稳协议 = 做「不自动加载相机」的 camdp 变体（改 RAM initramfs 里的 /init 去掉 camera-modules-load 调用），再累积式加载、每次加载后真实熄屏，第一个致死的加载项即元凶——只有最后一次致掉电，前面安全，减少用户的物理恢复次数。
---
在内核树里用 `make M=... modules` 单编模块会缺 vmlinux 上下文（报错）；且在 dirty 树上构建会得到 vermagic 末尾带 `+` 的模块，设备 insmod 会失败。两个可用手法：(1) 把实验改动提交使树变 clean 再编译；(2) 直接改 .ko 里 vermagic 字符串的尾部 `+` 为 NUL（CONFIG_MODVERSIONS 关时只需字符串精确匹配）——本次用此法把 `7.2.0-debug-vk47clean-gbd114ca335e1+` 修正为不带 `+`，部署成功。
---
对内核树只改 DTS 后重编 DTB：若上一次 make 已生成过 dtb，直接 `make arch/arm64/boot/dts/qcom/xxx.dtb` 会报「无需做任何事」或「没有规则可制作目标」；需先 `touch` 源 dtsi/dts 或删掉旧 .dtb 再编，并用 `dtc -I dtb -O dts` 反编译回读确认节点属性（如 power-domains phandle）真的改到了。 — Failed: DTS 改动未触发重编，容易误以为构建成功
---
上游内核 patch 的 commit message 与 DTB 源码注释必须全英文后才能发给邮件列表：仅把 commit subject 改成英文不够，diff 的 `-`/上下文行若来自中文注释 commit（如 H1 的「H1 实验：…」）仍会把中文留在 patch 里。正确做法 = 连同前置实验 commit 一起在分支上重做/改写（本条经历 git rebase --onto + 手工解 sm8750.dtsi 冲突），保证 patch 纯 ASCII；另注意 `git format-patch` 的 Subject 若此前已带 `[PATCH]` 前缀会叠成 `Subject: [PATCH] [PATCH] ...`，需用 --subject-prefix 或手改。
---
「换设备/换 AP 就正常」类结论只能证明触发条件，不能排除本侧版本/DTB 变量；遇到这类现象若要归档成「已知限制」，必须先确认同一外设在早期版本是否工作过（用户会据此纠正）。
---
PyPI wheel `dtc`（dtc-0.1.1-py3-none-any.whl）是 dataclass 工具，不是 device-tree compiler；`import fdt` 会 ModuleNotFoundError。反编译 DTB 用内核树自带的 `geekidos-linux/scripts/dtc/dtc`。
---
手工改 linux/.config 后必须用交叉编译环境（`. scripts/env-build.sh`，CROSS_COMPILE=aarch64-linux-gnu-）跑 `olddefconfig`/`make`；用主机 gcc 跑会丢掉 43 项工具链相关项（CONFIG_ARM64_MTE/ARM64_AS_HAS_MTE/CC_HAVE_SHADOW_CALL_STACK/ARM64_ERRATUM_* 等），并引入 CONFIG_BROKEN_GAS_INST=y、CONFIG_CMDLINE=""。 — Failed: vk64 构建时用主机 gcc 跑 olddefconfig，config 被写坏
---
Q24 熄屏→硬复位未根治的最新增量证据（2026-10-08）：vk63（H2 DTB，cambist 单挂 MX）在**相机加载态**下 SSH 自动扫测真实熄屏（org.gnome.ScreenSaver.SetActive）3 轮 2 掉电 ⇒ 与 H1 同量级间歇，早前「用户实机 2/2 存活、H2 收盘」是低样本误判。无相机态仍稳定安全。掉电时死前几秒的用户态日志被 page cache 吞掉（脚本创建了 log 但 0 字节），符合既往「硬复位无痕」判据。
---
版本号对账的统计口径要小心：`out/` 里 80 个 *.img 有 4 个是 boot_b-*/dtbo-* 类无内核载荷的副本 ⇒ 「带内核载荷的镜像」是 76 个；而「硬错行数」要按 flag 前缀逐个统计（num_ne_tag 24 + uts_dup5 18 + tree_drift 18 + dirty_drift 2 = 45），漏掉 uts_dup5 会得出错误的 36。数字入账前必须脚本重算核对。
---
排查本机 kexec 时可参考的上游方向（2026-10 联网检索）：arm64 无 x86 的 machine_ops.shutdown 等价 teardown（Hyper-V 侧靠 syscore_ops.shutdown 修 VMBus kexec 失败，见 [PATCH v2] arm64: hyperv: run VMBus kexec handler via syscore_ops，2026-09）；reboot notifier 过早（在 kernel_restart_prepare 内、device_shutdown 之前）是已知机制限制；Qualcomm 侧关注 qcom-pon（drivers/power/reset/qcom-pon.c）在 kexec 路径的 pm_power_off / restart-mode 行为。引用时须复测，勿直接下结论。
---
kexec 调试落盘（跨 kexec -e 存活日志）必须用「设备本地、与 SSH 无关」的 dumper：`scripts/kmsgspy.sh` 即 `stdbuf -oL dmesg -w >> /root/kmsg-live.log &` + `while :; do sync; sleep 0.5; done`。R2 落盘失败（拿不到 `Starting new kernel`/`Bye!`）的根因 = 用 SSH 驱动的 python 读 `/dev/kmsg`，而 kexec 走 `kernel_restart_prepare()` → `blocking_notifier_call_chain(SYS_RESTART)` 会先拆网络/杀 SSH，dumper 随之死亡。修法：`setsid nohup` 完全脱离 SSH 会话，且 sync 足够密以抓到 device_shutdown 早期的 `[KD]` 标记。 — Failed: 第二轮 kexec 上机（KEXEC-ONDEVICE-R2-2026-10-05）落盘 kmsg 抓取未拿到跳转里程碑日志，误以为掉电点在里程碑之前，实为 dumper 依赖 SSH 被杀。
---
内核 diag sysfs 开关命名坑：用 kobject_create_and_add("kexec_diag", kernel_kobj) + sysfs_create_file 同名属性时，实际文件路径是 /sys/kernel/kexec_diag/kexec_diag（目录套同名文件），直接 cat/write /sys/kernel/kexec_diag 会报 Is a directory。另 sysfs_create_file 在新内核要 const struct attribute *，传 kobj_attribute 须取 &attr.attr。cmdline 解析（kstrtoint + __setup）在 kexec 时可能读到 0（解析失败静默 return 保默认），改用 sysfs 运行时开关更可靠、可当场读回核验。
---
kexec 诊断内核的开关不要只靠 cmdline（kexec_dbg= 解析在某些启动路径下会读到默认 0，出现 cmdline 明明 =1 而 stage 打印 skip_mask=0 的自相矛盾）；权威做法是 sysfs 运行时开关，且 kobject 与属性同名时实际文件是 /sys/kernel/kexec_diag/kexec_diag（目录套同名文件），写路径时别漏一层。 — Failed: vk65 的 kexec_dbg=1 实测被解析成 0，改用 sysfs 旋钮后读写正常
---
kexec 诊断内核必须用**它自己**作为运行内核：`kernel_restart_prepare`/`device_shutdown`/`syscore_shutdown` 都是运行内核在 `kexec -e` 时执行的，不是目标 Image。第二轮 kexec 取证（R2）把 fix 装在目标镜像里 = 测试设计错。诊断手段优先用运行时 sysfs 开关（如 /sys/kernel/kexec_diag/{kexec_diag,stop_after,settle_ms}）而非 cmdline `xxx=` 解析——cmdline 方案曾出现解析值在 kexec 时读到 0 的歧义，sysfs 写读可当场核验。
---
kobject 与属性同名时 sysfs 实际文件在 `/sys/kernel/<kobj名>/<attr名>`（目录套同名文件），`cat /sys/kernel/kexec_diag` 会报 "Is a directory"；须用 `/sys/kernel/kexec_diag/kexec_diag`。另 `sysfs_create_file` 在此内核版本要求 `const struct attribute *`，传 `&kobj_attr.attr`。
---
本机（xuqianhui1001）长跑/无人值守脚本里的远程 ssh 触发命令必须套 `timeout`：`kexec -e` 之类会掐断连接的命令会让 ssh 一直挂到外层脚本超时（曾拖死到 300–460s），看起来像测试失败但实际已执行（日志已落盘）。实时落盘（tee -a / dmesg -w >> file + 定时 sync）是唯一可靠的取证通道，因为 SSH 会在 kexec 的 reboot_notifier 阶段断掉、任何经 SSH 的子进程 dumper 都会被杀死；dumper 须 `setsid nohup` 完全脱离会话。
---
Q24 H2「用户实机确认健康」是过早收盘（2026-10-07 2/2 存活 → 2026-10-08 3 轮扫测 2/3 掉电）。间歇率 ~20-60% 的 bug，2 样本无统计意义；最低门槛 = 6 轮连续无失败才可判「健康」。此前写进 TASKS 的「用户确认」口径已于 2026-10-08 改回 🟡。 — Failed: 低样本误判为根治，后续扫测推翻
---
Q24 熄屏×相机硬复位修复假设被原厂证据削弱：stock SunP DTS 里 `cambistmclkcc` 只有 `vdd_mx-supply`（MX），camcc 才有 vdd_mm/vdd_mx/vdd_mxc ⇒ 主线「cambist 单挂 MX」（H2）就是原厂写法，「改 MXC」假设证据弱。变体 vk71-mxc（MXC）/ vk71-mxnom（MX+nom corner）待上机对照。
---
实验/诊断内核（E0/E4a 等）从 dirty worktree 构建时，CONFIG_LOCALVERSION_AUTO=y 会在 UTS 尾部追加 `-dirty`（如 7.2.0-debug-ge3c5e9fea66e-dirty）。若模块从同 commit 的 clean checkout 单独编译（或 depmod 时 git 状态已恢复 clean），模块 vermagic 就不含 `-dirty`。部署到设备后即使建了符号链接 /lib/modules/<with-dirty> -> <without-dirty>，modprobe/insmod 仍按 vermagic **字符串**逐字比对 → 全部 `Exec format error`（dmesg: version magic '...ge3c5e9fea66e ...' should be '...ge3c5e9fea66e-dirty ...'）。vk80-e4amxc 的相机模块加载 100% 失败即此因。修法：(a) 构建内核时 `make LOCALVERSION_AUTO=n`（或 `set localversion=''`）去掉 -dirty；(b) 模块必须从**同一个 dirty 树**编译。判据：`modinfo <ko> | grep vermagic` 与 `uname -r` 逐字节比较，不要只看目录名/symlink 是否存在。 — Failed: E4a 诊断内核 dirty UTS vs clean modules 导致所有 modprobe Exec format error，相机模块全链失败
---
agent_browser 在 Microsoft web 应用（Outlook Live 等）上做高频 DOM 操作（连续 5+ 次 eval/click/fill）会触发**反自动化风控**：表现 = compose 窗口关闭（看似发送成功）但邮件实际落入草稿夹，已发送夹无记录。判据 = 必须导航到「已发送邮件」文件夹确认有对应条目，不能只看 compose 消失。恢复 = 用户手动打开草稿点发送（绕过风控）。 — Failed: Q24 v2 邮件经 agent_browser 代填 Outlook 网页、点发送后 compose 消失，但邮件落入 Drafts；用户手动验证并发送成功
---
build-boot.sh 静默回退 slim ramdisk 破坏单变量（2026-10-10 vk85 实测）：打包脚本在 RAMDISK_KIND 未显式设 full 且 out/rootfs-overlaid*.cpio.gz 不存在时，**静默回退到 slim（1MB）或空 ramdisk**，产出 21MB 镜像（正常完整 ramdisk 应 ~85MB），但 manifest 只写 `ramdisk_sha256=(absent)` 不报错。后果：vk85 与 vk84 载荷不可比（slim=无固件=驱动全废，PITFALLS #113）。规矩：打包后**必须核对输出镜像体积**（完整 ramdisk ≈80–90MB，slim≈21MB），并显式 `RAMDISK_KIND=full bash scripts/build-boot.sh` 或 `RAMDISK=<path>` 锁定 ramdisk。
---
用户会当场纠正 agent 对设备状态的误判：「实际上没有测试成功。从你busybox重启进入锁屏以后，你执行的脚本没有重启，设备的gui卡住不动了，音量按钮无响应（内核卡死的征兆）」——期望 agent 据此立即停手、不继续循环、入账事故。用户还会主动报告物理观察（「屏幕无图案（仅背光点亮）」、「物理断电重启成功」），期望据此修正判读方向。
---
「按内核二进制确定性」claims (Q28 vk64=GOOD×7 / 新编=NOCARD×14) 溯源审计结论（2026-10-10 夜）：21 发台账**只有 7 发有原始日志**（vk64 GOOD×2、vk89×3、vk89-plain×2）；其余 14 发无 per-run 记录、vk64c*.img 已删。声称的 5,040,884 B 二进制差**主要是 LOCALVERSION 长度导致的 `.rodata` 4 字节平移**（`.text` 仅 26 word、全为地址立即数），不是真实代码变更。同一 vk64.img 在冷 POR 路径 3/3=STORM ⇒ 现口径 = 「reboot2 暖路径上 vk64 亮、vk89/vk64c 不亮，真因未定」，不是「确定性翻转」。教训：做确定性 claim 必须有 per-run 证据日志（scripts/trial.sh 正是为此而生），且声称的「二进制差异」必须先排除 UTS 字符串偏移、再看 .text。溯源文档 reports/q28-binary-determinism-provenance-20261010.md，commit 1c9a589。 — Failed: binary determinism claim made from device boots without per-run evidence; binary diff attributed to code change but was actually LOCALVERSION string offset
---
内核 Image 二进制对拍技巧（LOCALVERSION_AUTO=y 树）：同源码不同构建号的 Image（如 vk64 #60 vs vk64c #91）会因 UTS 串长度差（多一个字符如 'c'）导致 `.rodata` 整段后移，表现为 5M+ 字节差异，但 `.text` 段仅 26 个 word 不同且全为 adrp/add 立即数（= 符号地址平移产物）。判据：用 `b[i]==a[i-4]` 对齐率验证（>94% ⇒ 纯偏移）；真正代码改动看 `.text` 段逐 word XOR 排除偏移后剩余的 word 数。工具：`scripts/extract-ikconfig` 验 config 一致 + System.map 定位 kallsyms 符号确认偏移起点。 — Failed: naive binary diff of kernel Images misattributes LOCALVERSION string-length-driven .rodata shifts to real code differences
---
内核二进制「确定性」溯源的关键方法论教训（2026-10-10 Q28 调查）：LOCALVERSION 字符串长度差异（如 vk64→vk64c 多 1 字符）导致 .rodata 段整体 4 字节偏移，造成 ~5MB 假性字节差异（oct8_vk64 vs vk64c = 5,040,884 B diff），但 .text 段实际只差 1 个 word（q28a vs q28aa 实验证实：LOCALVERSION 长度差 1 字符 = 总 diff 仅 466 B / 1 text word）。结论：判断两个内核构建是否「功能不同」不能靠 Image 字节 diff，必须看 .text 段差异或反编译对比；字节 diff 的 94.7% 匹配 shift(+4) 只是 rodata 平移。这导致 Q28 的「按内核二进制确定性」结论被降级（commit 1c9a589 溯源审计）。 — Failed: 接受「21 发台账 vk64 GOOD×7 / 新编 NOCARD×14 + 5MB 二进制差异 → 确定性由内核二进制决定」的结论，未验证 per-run 日志（实际仅 7 发有记录）也未理解字节差异来源（LOCALVERSION 长度导致的 rodata 平移）
---
Q28「按内核二进制确定性」实验的 GOOD 判定存在系统性误判：SSH 探针在 uptime≈14 s 读到 card0+无风暴 就记 GOOD，但设备随后数秒即冻死（= PITFALLS #106「进 GUI 后整机卡死」，硬看门狗禁用→不自复位→需物理断电）。原报告「vk64 GOOD×7」很可能全部是 GOOD→HANG，被单次探针误判为真 GOOD。后果：(1) 逆转说法的实验设计根本缺陷——单次探针无法区分「真正常」与「即将冻死」；(2) 任何 Q28 判 GOOD 必须持续观测（至少 2–3 个时间点或 uptime>60 s 仍 SSH 活），单次 uptime=14 s 探针不算 GOOD；(3) layout A/B 中 oct8 跑出 GOOD 的样本实际是 HANG 前窗口，与 STORM 同属失败谱系。#106 与 Q28 不是独立问题，而是同一冷起/复位路径在时间轴上的不同表现。 — Failed: Binary determinism experiment used single-point SSH probe as GOOD criterion; system froze seconds later (#106) but was never re-checked, so HANG was silently misclassified as GOOD
---
Q28「按内核二进制确定性」溯源审计结论（2026-10-10，commit 1c9a589）：原报告 21 发台账仅 7 发有仓库原始日志；声称的 5,040,884 B 二进制差 94.72% 是 LOCALVERSION 字符串长度差导致的 .rodata 4 字节平移，.text 仅 26 word 且全为 kallsyms 地址立即数（无指令语义改变）；同源码仅改 LOCALVERSION（-q28a vs -q28aa）的 Image diff=466 B、.text diff=1 word。layout A/B（reboot2 暖路径）证实同一 oct8 镜像 4 次跑出 GOOD/STORM/STORM/GOOD（不自洽）⇒ 降级为「暖路径 vk64 亮/vk89 不亮，真因未定」。 — Failed: 原报告把 LOCALVERSION 字符串偏移误读为功能性二进制差异，且 21 发中 14 发无 per-run 证据，导致错误结论写入 SSOT
---
Q24 方法论缺口（2026-10-10 外部教程评估暴露）：核心机制「RPMh 轨塌 → NoC → PS_HOLD」至今是**推断**而非直接观测——60+ 轮二分只证了「cambistmclkcc 在位 + 熄屏 = 掉电」的共现，从未在掉电瞬间抓取 /sys/kernel/debug/regulator/regulator_summary 与 /sys/kernel/debug/clk/clk_summary 的前后对比来**直接观测**哪条轨先塌、塌的顺序、以及 cambist 的 MX 票是否真的阻止了轨关断。教程建议的「最小化 probe」= 我们的 FIX-3（vk82），但因死内核事故作废需在好档重做；而 regulator_summary 对比是**一条我们从未做的廉价新检查**（好发/坏发各采一次即可），应纳入下次 Q24 上机采集清单。 — Failed: 60+ 轮实验只做了共现二分，未做机制的直接观测（regulator 轨态 / RPMh 请求-响应对），导致所有修复实验都在「猜哪条轨」而非「看到哪条轨塌了」
---
内核树脏文件致 -dirty（2026-10-11 复发）：`tools/testing/selftests/bpf/progs/` 下有一个文件名被截断的跟踪文件 `btf__coreOreloc_type_based___fn_wrong_args.c`（O 代替 _，git checkout 产物 bug）被删 + 正确名 `btf__core_reloc_type_based___fn_wrong_args.c`（89 B，内容不同）未跟踪 → `git status` 报 ` D` + `??` → `git describe --dirty` 返回 `-dirty` → UTS/vermagic 含 `-dirty` → 模块 insmod 报 `Exec format error`。修法：`git checkout -- tools/testing/selftests/bpf/progs/` 恢复跟踪文件 + `rm` 或 `git add` 未跟踪文件使树 clean。每次从 clean/base 创建分支后、make 前必跑此检查。 — Failed: vk90/91/92 构建时 manifest 的 kernel_release 全部含 `-dirty` 后缀，虽镜像本身能启动但模块 vermagic 不匹配设备已有模块目录，无法 insmod 相机模块。
---
Q24 复现条件修正（2026-10-11 实测，用户裁定「以这次实验现象为主」）：**cambistmclkcc 单独加载 + 真实熄屏 = 9/9 存活**（vk64/H2 DTB，genpd 轨态在 blank 前后完全不动：mx=on mmcx=on mxc=off-0 cx=on）⇒ 旧口径「唯一触发模块 = cambistmclkcc / 单独加载它即 3/3 掉电」**不成立**。真正可复现的触发条件 = **完整相机栈**（camcc-sm8750 + cambistmclkcc-sm8750 + i2c-qcom-cci + wl2868c-regulator + qcom-camss + leds-qcom-flash + gt9764 + s5kjns + gc08a8 + system_heap）+ 真实熄屏 → 硬复位（uptime 归零、pstore 空、模块消失）。死前 1s 捕获 RPMh trace：`addr: 0x300a0 data: 0x2 → 0x0`（cmd-db 里需确认该 addr 对应哪个域）。历史 60+ 轮「单模块 cambist」二分样本的台架不干净（可能混入了完整相机栈或其他变量），新实验明确区分了 cambist-alone vs full-stack。 — Failed: 旧记忆中 20+ 条写「唯一触发=cambistmclkcc / 单独加载即掉电」，本次 vk64 干净台架 cambist-alone 9/9 存活直接否证
---
Q24 触发体修正（2026-10-11 干净复现）：cambistmclkcc-sm8750 **单独加载不触发熄屏掉电**（vk64 GOOD 启动 + cambist 单独 + 真实熄屏 ×9 全存活）；**cambist + camcc-sm8750 组合**才是触发体（加载 camcc 后首次熄屏即硬复位）。此前「单模块 cambist 即触发」的结论来自 -dirty 内核 + 非 GOOD 启动 + 可能含 camcc 的加载序列（camera.conf 顺序先 camcc 后 cambist），属台架不干净。用户明确「以这次实验现象为主，历史取证不干净」。RPMh 死前 trace：最后一笔 = tcs 1 cmd 0 addr 0x300a0 data 0x0（某轨掉到 0），紧接 reset。 — Failed: 旧记忆「cambist 单模块即触发」与干净复现矛盾；旧台架用 -dirty 内核 + 可能非 GOOD 启动 + camera.conf 含 camcc 在前
---
Q24/Q28 实验的构建版本串陷阱（2026-10-11 实锤）：同一源码树 + 同一 .config + 同一工具链，只有 LOCALVERSION（UTS 版本串）不同，会导致 (a) Q28 的 card0 有/无翻转（-vk64 GOOD，其他 NOCARD 11/11），(b) 模块 vermagic 与内核不匹配 → modprobe 静默跳过 / insmod 报 Exec format error。修复方式：用 LOCALVERSION=-vk64 统一重建内核+模块+镜像。另一种 vermagic -dirty 陷阱：树 dirty 时 UTS 含 `-dirty`，但模块目录可用 symlink 指向无 `-dirty` 的目录 → insmod 报 `version magic 'X' should be 'X-dirty'`（CONFIG_MODVERSIONS 关时无 force-load 余地），正确修法 = 全部在途改动 commit 使树变 clean 后重编内核+模块。绝不要试图用 symlink 或 --force-modversion 绕过。
---
模块级实验的 vermagic 匹配技法（2026-10-11 实测）：只改驱动 .ko（如 FIX-2/FIX-3）想装到已跑内核上时，模块 vermagic 必须与运行内核 kernelrelease 完全一致。若分支 HEAD 不同导致 vermagic 差（如 vk91-fix3mx vs vk64），正确做法 = 切到该分支后临时 `CONFIG_LOCALVERSION_AUTO=n` + `CONFIG_LOCALVERSION="-debug"`（或 export LOCALVERSION=-vk64）重编该模块 → vermagic 对齐目标内核。错误做法 = symlink / --force-modversion（MODVERSIONS 关时无余地）或 rmmod 已加载的模块（Used by≠0 时 rmmod rc=1）。
---
Q24「单模块 cambistmclkcc 触发」是**取证方法论错误**（非实验设计错误）：历史扫测用的 `/etc/modules-load.d/camera.conf` 全栈加载器会同时 modprobe camcc+cambist+cci+camss+传感器等 11 个模块，研究者只盯 cambist 的 insmod 日志就归因「单模块」，但 camcc 早已同时在场。干净单变量实验（2026-10-11）证明：cambist 单独 12/12 存活、camcc 单独 3/3 存活、配对 2/2 死（双向顺序均死）。教训：增量加载实验必须从**零模块**起逐个加，不能基于已有全栈加载器做「单模块」归因。 — Failed: camera.conf 全栈加载器同时带 camcc，研究者未隔离变量就得出「cambist 单模块触发」结论
---
内核 `make modules_prepare` **必须带 ARCH=arm64 CROSS_COMPILE=...**——不带时 make 按 x86 原生跑，会**静默覆盖 .config 为 x86 配置**（sha 从 a383cdb9 变 5dee2b27，CONFIG_CC_VERSION_TEXT 变 gcc 而非 aarch64-linux-gnu-gcc）。正确姿势：先 source scripts/env-build.sh（export ARCH=arm64 CROSS_COMPILE=... LOCALVERSION=-vk64），再 make modules_prepare。恢复被覆盖的 config：从设备 `zcat /proc/config.gz > .config`（sha 必须回到 a383cdb9）。 — Failed: modules_prepare 不带 ARCH 被当 x86 跑，覆盖权威 config
---
内核构建：`make modules_prepare` 不带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-` 会以 x86 原生跑，**覆盖 .config 为 x86 配置**（sha 从 a383cdb9 变 5dee2b27）。恢复法 = 从设备 `/proc/config.gz` 或 `extract-ikconfig` 取回权威 arm64 config。正确姿势 = 先 `. scripts/env-build.sh`（已设 ARCH/CROSS/LOCALVERSION/ccache），再 `make ARCH=arm64 CROSS_COMPILE=... modules_prepare`。历史教训：vk81/82/83 死内核（ARCH_QCOM 被 olddefconfig 静默丢弃）是同类根因，已加 apply-kernel-fragment.sh 回钉 + assert-kernel-sane.sh 硬门。 — Failed: make modules_prepare 不带 ARCH 参数被当 x86 原生编译，覆盖 arm64 .config，导致后续模块编译全部失败或产出 x86 .ko
---
hexagonrpcd-adsp-sensorspd 未持久化到 runlevel（2026-10-11 发现）：上一会话（2026-10-09）手动 `rc-service hexagonrpcd-adsp-sensorspd start` 后 svc400 注册成功，但该服务**未被 `rc-update add`** 到 default runlevel ⇒ 每次重启后 `status: stopped`、`/dev/fastrpc-adsp` 不存在、`HasAccelerometer=false`。与 qbootctl 同类问题（已修复）。修法 = `rc-update add hexagonrpcd-adsp-sensorspd default`。注意该服务依赖 ADSP fastrpc 节点有 `qcom,non-secure-domain`（DTB vk72 已加，但 boot_b 当前=vk64 未含此属性）⇒ 传感器栈只在 vk72 DTB 下工作。 — Failed: 手动启动的服务未 rc-update add 到 runlevel，重启后丢失
---
内核模块增量编译时 `make modules_prepare`（不带 ARCH=arm64 CROSS_COMPILE）会静默把 .config 重写成 x86 原生默认（CONFIG_CC_VERSION_TEXT 变 gcc、平台选项全丢），且无任何警告。判据 = 跑前后比对 .config sha256。正确做法 = 必须先 `. scripts/env-build.sh`（设 ARCH=arm64 + cross + ccache），再 `make modules_prepare`；或从设备侧 `zcat /proc/config.gz` 恢复权威 config（sha a383cdb9…）。2026-10-11 差点用污染后的 config 编 bridge.ko 部署到设备。 — Failed: modules_prepare 默认按 native arch 跑 kconfig，覆盖 aarch64 .config
---
Q28 冷起 A/B 的配对臂除源码/config/LOCALVERSION 一致外，ramdisk/init 配方也必须一致——否则「golden ramdisk vs modular-overlay（重建模块层）」会引入 /init 时序差异（§h 已知 /init 时序能翻转 NOCARD/STORM），污染单变量。做法：两臂用同一 build 脚本产出的同配方 ramdisk（本轮 base 臂 vk93-lv64 用 golden ramdisk、round 臂用 modular-overlay，遂重建同 modular 配方的 vk97-base-lv64）。
---
Q28 冷起 A/B 排除「构建身份伪影」的手段 = 构造 sham 臂（与对照臂同源码，只加一行无副作用的 pr_info 改变二进制但不改行为）。判定：sham 也 NOCARD ⇒ 是二进制身份效应（如 LOCALVERSION/链接顺序），该臂结论作废；sham GOOD ⇒ 差异来自被测补丁本身。这一方法用于区分「补丁逻辑」与「同源码不同二进制」造成的 card0 有/无翻转。
---
用户面对历史取证不干净时的裁决原则（2026-10-11 原话：「考虑到历史取证的不干净，我们以这次实验现象为主」）：新实验的干净单变量结果直接覆盖旧文档结论，不并列、不降级、不要求旧证据重做。案例：Q24 旧口径「单模块 cambistmclkcc-sm8750 触发」被本次 `{cambist}` 熄屏 12/12 存活 + `{camcc,cambist}` 配对首次熄屏即硬复位否证，改为「camcc + cambist 配对触发」。
---
Q28 冷起 A/B 测补丁这条路已作废：因为冷起 GOOD/NOCARD 由内核版本串（构建身份）决定，任何重编（含空提交、一行常量 pr_info）都会把 base 的 GOOD 推成 NOCARD —— 观测行为自身改变结果。教训：在被测系统存在「构建身份敏感性」时，A/B 实验的对照臂必须钉死 UTS 串（PINUTS）才能隔离待测变量。
---
Q28 冷起 A/B 测补丁的观察者效应（2026-10-11 实锤）：改内核代码本身会改变被观测对象——哪怕空提交（零代码，只换 git sha）或一行常量 pr_info 都会把 base 的冷起 GOOD 翻成 NOCARD；只有 UTS 逐字 = 7.2.0-debug-vk64-gd02658e63cf6 才 GOOD。⇒ 冷起 A/B 不能用来评估 Q28 补丁，round/Method-B 等的 NOCARD 不能当「修复无效」证据。绕过方法 = PINUTS 钉死 UTS 版本串（CONFIG_LOCALVERSION_AUTO=n + LOCALVERSION=<exact>），钉死后改内核/config 仍 GOOD。
---
Q28 2×2 因子实验（2026-10-12）设计教训：第一轮 A/B/C/D 全按固定顺序跑（A→B→C→D），导致 Round 1 的 C1/D1 连续坏发被误读为「首轮/时序状态效应」而非内核轴——因为 Round 2 全 GOOD 后「旧内核坏发率高」的结论被削弱。正确做法 = 同时间窗**交替采样**（C→A→C→A），消除 boot-to-boot 状态漂移。8 发样本 Fisher p≈0.43 远不够下判词，需 ≥20 发交替才能区分「内核坏发率」vs「会话内状态衰减」。
---
Q28 旧K/新K 源码差异**已被更正**（2026-10-12 manifest 逐项核对）：vk94/vk64 的内核源码 = `d02658e63`，vk97/vk100/vk104 的内核源码也 = `d02658e63`——**完全相同**。之前「新K 比旧K 多 1 个提交 = ADSP fastrpc qcom,non-secure-domain」的说法混淆了 DTB 差异与内核源码差异（该属性只存在于 DTB 编译产物中，不在内核 C 代码里）。两臂真正的差异 = config 中 CONFIG_LOCALVERSION_AUTO（y/n）→ 影响 UTS 构建号 #N 嵌入方式 → 影响 payload 二进制布局（~5.1M 字节差异，shift+0 匹配仅 18%，非简单平移）。教训：「源码差」必须逐项核对 manifest 的 kernel_git_head 字段，不能从镜像文件名或分支名推断。 — Failed: 之前多份报告（DOSSIER §e、audit 表）将 vk104 标注为源码 5d01d3324（含 ADSP 提交），实际核对 manifest 后 vk97/vk104 的 kernel_git_head 均为 d02658e63
---
Q28「旧K vs 新K 差 1 个 ADSP DT 提交」是错的——那是 DTB 的差（vk94 带 qcom,non-secure-domain），内核源码全部 = d02658e63（E2 vk109/vk110 交叉实验证实 DTB 轴不影响结果）。真正的轴 = 构建身份（#60 vs #1xx），与源码/DTB/ramdisk/cmdline 全部无关。之前报告写「源码差 1 commit」的口径已作废（reports/q28-storm-bias-audit-20261011.md §7.2 已更正）。
---
Q28 构建身份定量证据（2026-10-12，PITFALLS #195/#216）：`#60`（2 位构建号）内核臂 4 坏/2 好（~67% 冷起失败）vs 3 位构建号 0 坏/12+ 发（Fisher p≈0.005）。NOCARD 与 STORM 同族 = 内核构建身份（UTS/构建号位数）伪影，非独立随机。治法 = 用 3 位 KBUILD_BUILD_VERSION 重编日常镜像（vk113-dailyid 已构建未上机验证）。
---
Q28「构建身份伪影」口径在 2026-10-12 上机复测中被**推翻**：vk113-dailyid（3 位构建号 #121）冷起 1 GOOD / 1 L1FAIL；vk94（2 位 #60）冷起也 L1FAIL。即 3 位身份并不保证不坏，NOCARD/STORM 不是纯构建身份伪影。此前「#195：3 位身份 ⇒ 0 坏」的定量结论（Fisher p≈0.005）作废，冷起好坏仍是随机/未定因素。
---
generate_initramfs/内核 UTS 提取小坑：用 `zlib.decompressobj(16+MAX_WBITS).decompress(d[i:], 128<<20)` 解 gzip 取 UTS 时，`re.search(rb'Linux version ...')` 若正则过窄会返回 None（脚本里 `.group(0)` 直接 AttributeError）；应放宽正则并用 `m.group(0) if m else ''` 守卫。另 `python3 -c` 里别多写右括号（本轮 SyntaxError: unmatched ')'）。
---
Q28 冷起实验的「恢复路径未触发」陷阱：驱动内自恢复/重试补丁在 GOOD 发上完全走不到（失败签名计数为 0），4 发全 GOOD 不能当作「补丁有效」的证据，只能记为 no-op；必须等到坏发才能验证机制，且判据应是「日志出现补丁的恢复标记」而不是「本轮 GOOD」。vk116 前 3 GOOD + 1 坏的解释即此。
---
『上游报告已归档』只是投递成功，不等于有回信：Q28/Q24 报告发出后 In-Reply-To/References 命中回复 = 0 是常态。看『最新邮件有没有我们关心的』要走两条独立通道：① IMAP 巡自己的 INBOX/Junk（read-mail-ustc.py --replies-only；注意 USTC 会把自发邮件标 [SPAM]）；② lore 关键词查询（scripts/lore-query.py 自动过 Anubis PoW）。归档复核用 body sha256 逐字节比对（raw URL 带 `?x=A` 只拿到 Atom，要取 raw 正文直接用 /raw）。
---
用户会纠正关键实验事实的口径（2026-10-13 实例）：agent 报「vk124-merged 零写盘 RAM 直启后冷起 GOOD」，用户纠正「第一次冷起是 STORM，我手动第二次冷起后 GOOD」。⇒ 上机结论必须按**每发冷起逐次记录**（含坏发），不能用「最终 GOOD」概称；这与已有「新验收口径=1 次 GOOD 即可判候选可用」并存——判定可以宽，但事实陈述不能省掉坏发。 — Failed: agent 把 2 发（1 STORM + 1 GOOD）概括为「冷起 GOOD」，被用户当场纠正
---
用户口径修正（2026-10-13，vk124-merged 上机）：该镜像**第 1 次冷起是 STORM（只有背光无桌面），操作者手动 POR 后第 2 次冷起才 GOOD**——不要写成「冷起 GOOD」。这与 Q28 现状（~50% 随机坏发、与镜像无关、按时间成簇）一致，报告/台账须区分「第 N 次冷起」。 — Failed: 把操作者手动第二次冷起的结果记成单次冷起 GOOD，被用户当场纠正
---
Q28 探针臂 vs 门控臂判据（2026-10-13 定）：当臂的唯一目的为诊断（如 vk116/117/118/119/120/123——判据是日志里出现特定恢复/转储行，不是冷起成败），单变量可比是硬要求：UTS release 必须与要对照的基线臂==一致==（PINUTS 钉死 + 相同 #N 构建身份），刻意复用源提交/UTS 是预期例外，已登记 known-issues 降为 WARN。当臂为「候选功能修复」（如 vk125-resetterm、vk124-merged），判据是冷起三态（GOOD/L1FAIL/NOCARD），UTS 不同亦可比。
---
构建时 /tmp 是 tmpfs（31G，易满/有配额）⇒ 内核编译会报 `error closing /tmp/xxx.s: 超出磁盘配额`；修法 = 把 TMPDIR 指到大容量根文件系统（本次 TMPDIR=/var/tmp/p1build）再 make。清理 /tmp 前先看 df 与 du（本次 /tmp 有 /tmp/vk125wt 7.0G、/tmp/dailyid 7.0G 等残留）。
---
M1-7.3 树 boot 停滞 91 s 的真因 = 内核在 WCN/ath12k 首探的 MHI 等待上卡住（`[4.90] mhi mhi0: Wait for device to enter SBL or Mission mode` → `[96.08] ath12k: failed to set mhi state: POWER_ON(2)` -110），不是 `insmod fsa4480` 阻塞。决定性判据 = `[96.45] Freeing unused kernel memory` + `[96.50] Run /init as init process`（PID1 到 96.5 s 才被 exec）。对比日常 vk94：WCN 探针 23.09 s 起、0.4 s 内成功 ⇒ M1 树探针过早（4.4 s）。修法（E1g）= `CONFIG_ATH12K=m` 让用户态晚加载、不 gate init ⇒ `Run /init` 回到 4.49 s、GUI ~7 s。注意 `ps -o etimes -p 1` 会给误导值（≈uptime），不能用它判断 PID1 何时起。
---
geekidos-linux 是 shallow 克隆 ⇒ 任何 `git fetch` 新 ref 都被拒：`fatal: Not a valid object name <sha>^{commit}`、`warning: 拒绝 refs/tags/vkNN 因为浅克隆的根不允许被更新`。要从某个 vk tag 取树内容只能用**本地 worktree**（`git worktree add build/vk83-tree vk83`）做文件级差分，不能 fetch 远端补对象。 — Failed: 换机后重建 payload 时想 fetch vk83 等 tag 失败；eyeballing 浅克隆限制
---
本机 `~/.local/bin/dt-validate` / `dt-doc-validate` 的 shebang 指向 `~/.local/opt/dtschema-venv/bin/python`，但该 venv 里 `import dtschema` 报 `ModuleNotFoundError: No module named 'dtschema'`（换机后 venv 未重装）。`dtbs_check` 因此不可靠；判断 DTB 保真度改走「抽基线 DTB + dtc -I dtb -O dts 与重放 DTB 文本 diff」的路子。
---
geekidos-linux 是浅克隆 ⇒ 对已存在的 tag（vk81/vk82/vk83）`git fetch` 报 '拒绝 refs/tags/vkNN 因为浅克隆的根不允许被更新'、对新对象报 'Not a valid object name'（rc=128）。替代做法 = 用 `git worktree` 检出对应 tag 做文件级差分（本项目实测可行），不要试图 fetch 更新 ref。
---
geekidos-linux 是浅克隆（.git/shallow），fetch 已有 ref 会被拒（`warning: 拒绝 refs/tags/vk81 因为浅克隆的根不允许被更新`，rc=128），`git fetch <hash>` 报 `无法找到远程引用`/`Not a valid object name`。替代做法 = 建本地 worktree/克隆做**文件级差分**（`git worktree add build/vk83-tree vk83`），不要试图 fetch。 — Failed: 浅克隆仓库不能 fetch 新 ref；payload 取源必须靠本地 worktree 文件对比
---
内核树改 .config / LOCALVERSION 后 `make` 报 `"..." exceeds 64 characters`（utsrelease.h 生成失败）：根因是前一次构建残留在 include/config/auto.conf 里的 CONFIG_LOCALVERSION/LOCALVERSION_AUTO 与 .config 叠加重复拼接（如 `-debug-debug-vk127-...-00002-...-dirty` 双份）。修法 = 清 include/config 与 include/generated 后重编，或先 `make mrproper`/重新 olddefconfig。
