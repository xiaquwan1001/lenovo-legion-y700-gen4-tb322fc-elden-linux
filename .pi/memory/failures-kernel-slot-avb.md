# y700-elden — 内核/引导类失败与洞察：槽位 / vbmeta / AVB 自签 / ABL-XBL / 密钥

> 2026-11-26 从 `failures-kernel.md`（199 KB / 346 条）按主题机械拆分：**每条逐字搬移，未改一字**。
> 检索口径不变：`mem -t project <关键词>`（= `~/.pi/agent/projects-memory/<repo>/` 软链到本目录，`find -name '*.md'`），拆分不需改工具。
> 入口与本表 = `failures-kernel.md`（索引件）。

---

刷机核心：① 用 qfil/默认全量刷会漏写关键分区（vbmeta/super/init_boot）→ 看似成功但 boot 链不配套，必须 EDL 逐分区补并读回哈希；② 把 fastboot「传输完成」当镜像完整是错的，大镜像会静默损坏，必须读回比对 hash；③ 坏线/老 USB 口导致的断联常被误判为设备砖——先换线换口；④ boot_a 是 vbmeta_a 的 chained AVB 分区，受信 AOSP testkey（公钥 sha1 2597c218，rollback index 3 = 1738713600）；第三方用别的 key+rollback=0 签会被 ABL 拒（fastboot boot 借道 AVB 看着能起，易误判），需 avbtool add_hash_footer 带原厂 props 与 rollback_index；⑤ 不要依赖 TWRP 恢复（ramdisk 体积受限，可能起不来），备 root 替代路径。
---
槽位陷阱：`fastboot boot <img>` 失败（Status read failed / No such device）会把 current-slot 翻到 b，而 b 槽引导链是另一套固件（vbmeta_b 密钥 8fcb864f…）永远起不来。失败后先单条 `fastboot reboot bootloader`，等 6–8 秒再重试单条 `fastboot boot`。另：自编 Linux 从 b 槽直启时 Linux 不更新 misc 里 bootloader_control 的 tries_remaining，重启几次后 ABL 判定该槽不可信直接停在 fastboot；恢复 `fastboot --set-active=b` + reboot，持久修复要在 Linux /init 写 misc 偏移 2048。
---
设备 fastboot 回退产物位置：out/boot_b-vk49.img（100663296 B，vk49 时期的 b 槽备份，2026-10-04）；bootslot-b/ 目录是原厂槽位镜像集（dtbo_b/boot_b_vk40-ram.img/vbmeta_b_flags3.img 等）。
---
fastboot boot 失败会让 current-slot 翻到 b，而 b 槽引导链是另一套固件/另一把密钥，永远起不来。fb 报 `Status read failed` 时接 `fastboot reboot bootloader`，等 6~8 秒再单条重试。回 Android：先 `fastboot --set-active=<另一槽>`（非破坏）再 reboot。
---
kexec 取证上机发现（2026-10-05，U2）：① `kexec -e` 行为已不是「死挂」，而是设备自行复位落到 fastboot（ABL 记为该槽启动失败）；② `Hard watchdog permanently disabled` 是旁证——硬挂不会自复位，必须物理长按电源 ≥15s；③ `fastboot boot` 报 OKAY 但起来的是槽内内核（vk47clean），vk54 持久变体 RAM 镜像未真正接管 ⇒ 判断 RAM boot 是否真的生效要看 uname 与 DT 参数（如 ramoops record_size/max_reason），不能只看 fastboot 的 OKAY；④ 纯 RAM 变体 rootfs 里没有 eldroid-bootctl 也没有 python3（有 /usr/sbin/kexec），要进 fastboot 得先回 b 槽持久系统；⑤ `reboot bootloader` 在 vk47clean 持久系统里不生效（会走普通重启），须用 eldroid-bootctl 或 scripts/to-fastboot.sh（PSCI vendor reset + nvmem-reboot-mode）。 — Failed: fastboot OKAY 不等于 RAM 镜像接管；槽重试计数耗尽会被标 unbootable 停 fastboot
---
`fastboot boot` 在某些失败/异常路径下会让 `current-slot` 翻到 b（旧记录已两次实测：报 `Status read failed (No such device)` 后 getvar current-slot=b）。但 2026-10-05 的项目现状是 Linux 跑在 b 槽（/dev/sda17），因此「进 fastboot 后先 --set-active=a」这条旧规则已不适用——照做会切回 Android。正确顺序是先只读确认 current-slot 与 Linux 期望槽位再操作。 — Failed: 旧规则与当前 Linux 常驻 b 槽的实际部署冲突
---
kexec -e 触发的复位会被 ABL 记为一次当前槽（b）启动失败：`slot-retry-count:b` 递减，耗尽后 b 被标 `slot-unbootable:b=yes` → 设备停在 fastboot（boot_b 内容未动，可恢复）。所以每次 kexec 取证实验前必须先 `slot-attr.py mark-successful b` 重置成功位，否则会反复砖；本轮用户手动重置过一次。注意 `fastboot boot` 失败也可能让 current-slot 翻到 b。 — Failed: kexec 副作用的项目化坑
---
kexec 取证的控制台限制：设备控制台是 ttyGS0 USB gadget 串口，kexec 跳转时必断，其「戛然而止」不能用来定位挂死分支点；/dev/ttyACM0（主机侧）才是设备实时内核日志口。主机侧 `Hard watchdog permanently disabled` ⇒ 死挂不会自复位，必须物理复位（长按电源 ≥15s）。另 kexec_file_load 无 DTB 形参（--dtb 空操作），DTB 只能走 --boot/--flash。 — Failed: 取证手段本身受限
---
kexec -e 触发的复位会被 ABL 记为一次 b 槽启动失败，retry 耗尽后 b 槽被标 UNBOOTABLE（slot-unbootable:b=yes / slot-retry-count:b=0）导致设备停在 fastboot；boot_b 内容其实未损，可恢复。根治 = 项目脚本 `slot-attr.py mark-successful b`（改 GPT 分区属性第 6 字节 bit2 ACTIVE / bit6 BOOT_SUCCESSFUL / bit7 UNBOOTABLE / bit5..3 tries，主备 GPT 都要修 CRC）。⚠️ 槽位 GPT 在 /dev/sde，`blockdev --getsz` 返回 512B 扇区数而 UFS 逻辑扇区是 4096B——按 4096 备份/换算必须 /8，否则 skip 位置偏 8 倍、tail 备份为 0 字节。 — Failed: 反复 kexec 实验后设备卡在 fastboot，与 dd 扇区换算错误同批出现。
---
kexec -e 触发的复位会被 ABL 记为一次槽启动失败，retry 耗尽后把该槽标 UNBOOTABLE 并停在 fastboot（boot 分区内容未动）。恢复：`slot-attr.py mark-successful <slot>`（改 GPT 分区属性 byte6：bit2=ACTIVE / bit6=BOOT_SUCCESSFUL / bit7=UNBOOTABLE / bits5..3=tries，主备 GPT 都要修 CRC）。
---
打包 boot.img 双层压缩陷阱（G1-30 slim 线）：boot_b 解包出来的「kernel」本身就是 gzip（gzip compressed, original size 62.5MB → Image），再用 Image.gz 打包会变成双层 gzip，ABL 解一层后拿到 gzip 流而非内核 ⇒ 卡联想 logo、屏幕无输出。判据：`unpack_bootimg.py` 后看 kernel payload magic，boot_b/vk58c 是 1f8b 0800，坏包是 1f8b 0808。build-boot-slim.sh 必须对 boot_b 的真 Image 打包，不要传 Image.gz。
---
内核镜像重复压缩陷阱：若 boot 分区里的 kernel 载荷本身已是 gzip，再用 gzip 打包会形成双层压缩，ABL 解一层得到的是 gzip 流而非内核 → 卡 logo。打包自定义 initramfs 镜像时必须原样嵌入 boot_b 内的 Image，不要重新压缩。
---
QCOM fastboot 上 `fastboot boot <img>` 偶发 `Booting FAILED (remote: 'Failed to load/authenticate boot image: Load Error')`（Sending 已 OKAY）：重试一次（必要时先 `fastboot reboot bootloader` 回 fastboot）即成功，不需要改镜像或怀疑镜像损坏。 — Failed: 首次 flash/boot 报 Load Error 容易误判成镜像或签名问题。
---
fastboot boot 首次报 `Failed to load/authenticate boot image: Load Error` 时不要改镜像——2026-10-06 实测：同一 83MB 镜像 `fastboot reboot bootloader` 后再 `fastboot boot` 即 OKAY（10.1s 启动）。ABL 首次注入/校验偶发失败，重试即可。
---
qbootctl（Alpine community 包，AOSP bootctrl HAL 的 musl/glibc 移植）可完全取代本项目自研 scripts/slot-attr.py 的 mark-successful：① 扇区大小走 ioctl(BLKSSZGET)，4K 自动识别，无 sgdisk 那类 512B/4096B 误判；② 多盘/LUN 支持（按盘分别提交，源码注释直接举 /dev/sde 为例）；③ `-m`（mark successful）纯 GPT 写，primary+backup+CRC 同改、不碰 UFS BSG，与 slot-attr.py 完全等价；④ `-s`（set active）会额外走 /dev/sgY 的 UFS boot-LUN 切换（xbl），本项目不适用 ⇒ 慎用或加 `-i`；⑤ 缺口 = 无离线 dump 编辑、无 retry-count 顶配。源码常量：AB_FLAG_OFFSET=attribute byte 6，bit2=SLOT_ACTIVE(0x04)/bit6=BOOT_SUCCESSFUL(0x40)/bit7=UNBOOTABLE(0x80)；gpt-utils 用 BOOT_DEV_DIR by-partlabel 定位 LUN；运行时必须 root。2026-10-07 设备实测通过（boot_a->/dev/sde12、boot_b->/dev/sde45，LUN4，4096 字节扇区）：只读逐项一致，`qbootctl -m b` 把 boot_b byte6 0x0f(retry=1) 改为 0x4f(succ=1)，primary+backup 双表都写，内核重扫 78 分区无 CRC 错误。坑：写入触发分区重扫时有瞬时竞态，紧随其后的 `qbootctl -n b` 会报 “No slots found”，重读即正常，不代表 GPT 损坏。注意内核 cmdline 无 slot_suffix 时 qbootctl 无参会默认按 slot a 处理（读当前槽用 -x）。 — Failed: 自研 slot-attr.py 有可用的标准替代物，且后者在扇区大小/C-LUN 处理上更稳
---
PITFALLS #124 熄屏掉电（G1-22/Q24）单变量控制失败案例：头号假设「相机等 =m 模块的加载改变面板 disable 供电」无法验证——相机模块在用中无法 rmmod（绑定传感器），改用黑名单禁用后模块**仍被加载 12 个**，`modprobe --showconfig` 确认 `blacklist qcom_camss` 已生效但加载路径不是可被 blacklist 拦住的 udev autoload（或来自 RAM initramfs），单变量始终没隔离成功。 — Failed: 黑名单拦不住加载 ⇒ 无法做干净的单变量对照，熄屏掉电至今无法判定根因
---
本机 `dd` 备份磁盘时注意：`blockdev --getsz` 返回的是 512B 扇区数，而 UFS 设备逻辑扇区为 4096B ⇒ 直接拿该值做 bs=4096 的 skip 会得到偏差 8 倍的错误位置。正确换算 = 512B 扇区数 / 8。槽位 GPT 在 /dev/sde（LUN4，boot_a=/dev/sde12、boot_b=/dev/sde45）。 — Failed: 多次 dd 备份因扇区换算错误得到 0 字节 tail
---
`fastboot fetch <partition>` 在本机 U2 上不支持（`Unable to get max-fetch-size. Device does not support fetch command.`）⇒ 无法从设备回读 boot_b 等分区做「刷写前备份」。替代：设备在 Linux 时从设备侧读块设备（`/dev/disk/by-partlabel/boot_b` → /dev/sde45）再 scp 回主机（/tmp 是 tmpfs，7.3G）。
---
dp5 基线（内核 26cd13b1c）上执行 `ssh … 'sync; reboot bootloader'` 后设备从 USB 完全消失（fastboot devices 空、lsusb 无 18d1、无 enx*、无 /dev/ttyACM*）——当时归因为「内核不含 vk41 的 PSCI SYSTEM_RESET2 vendor-reset 钩子」，**该归因已作废（PITFALLS #712，2026-11-23 同启动内对照：无钩子核上 `reboot bootloader` 一样进 fastboot ~21 s）**；教训保留 = 发出后等 ~20–30 s 再判 `fastboot devices`，别用「没立刻出现」当失败。
---
本机 USB-NCM 调试链路重载：设备侧 `reboot bootloader` 后若内核缺 vk41 的 PSCI SYSTEM_RESET2 钩子（如 dp5 内核 26cd13b1c），设备会从 USB 完全消失（非 fastboot 未枚举，而是无任何 USB 设备：lsusb 无 Google/18d1、无 enx*、无 /dev/ttyACM*、SSH 超时）⇒ 必须用户物理进 fastboot。另外主机侧 USB-NCM 网卡名会变（本轮见 enx021e5eede102 配到 192.168.7.9/24 等），ping/ssh 前先 `ip -br a` 找当前 enx 名；`sync; reboot bootloader` 本身可用（PITFALLS #712，无需钩子）；本条现象若复现按「未见 fastboot」记账，不要据此回改「只能物理键」。
---
掉电/硬复位后设备可能停在 ABL fastboot 而非失联——此状态下 slot b 若缺 mark-successful（retry 耗尽被标 unbootable）会卡在 fastboot 不自动启动，须先 `qbootctl -m`（或 slot-attr.py mark-successful）再 reboot。判据：SSH 等待时间差异不是「启动慢」，而是槽位标志问题。
---
本机脚本调用 `scripts/to-fastboot.sh` / `cycle.sh` 走 `reboot bootloader` 时，若被外层 timeout 杀掉，设备会停在 Linux 不重启；且该步骤在 agent 侧常整体超时（本次 300s）。可靠做法 = 自身不被 timeout 包裹地跑 reboot 命令（detached），或直接请用户手动重启到 fastboot（用户 2026-10-07 就是手动做的）。 — Failed: 本轮 vk63 上机时 to-fastboot.sh 被 300s timeout 杀掉，设备仍在 Linux，用户手动重启进 fastboot
---
该 ABL 的 fastboot 不支持 `fastboot fetch`（报 `Unable to get max-fetch-size. Device does not support fetch command.`）⇒ 取分区内容改用 Linux 侧只读读分区（如 `dd if=/dev/disk/by-partlabel/dtbo_b ...` 后再按镜像大小截断比较 sha）。另注意：只用 python 扫前 4K 判「全零」会误判——dtbo_b 是全零 payload + 在 4096 偏移处开始的 AVB footer（1686 个非零字节）。 — Failed: fastboot fetch 不可用 + 前缀扫描误判全零
---
给 aarch64 内核模块 strip 必须用 `aarch64-linux-gnu-strip`，用主机 `strip` 会报 "Unable to recognise the architecture of the input file"（对象留在包里，未 strip 的全模块包 ~496MB → strip 后 ~16MB / 1610 项）。模块包须含 modules.order / modules.builtin*。 — Failed: vk64 模块打包时 strip 用错架构
---
本机 `fastboot fetch` 不被该设备支持（`fastboot fetch` → "Unable to get max-fetch-size"；`fastboot getvar max-fetch-size` → "GetVar Variable Not found"）⇒ 无法在 fastboot 下把分区读回主机做刷前备份。替代：以已知的 GPT 双表 dump（gpt_main0/gpt_backup0）+ 待刷分区已知内容（如已被写坏、无保留价值的镜像）替代，或走设备侧 `dd if=/dev/disk/by-partlabel/<part>` 再 scp。
---
vk64 的 Q28 retry 补丁（面板 prepare 失败后 redo reset 再试）**生效但不够**：attempt 1 报 `-110`（DSI DCS 首写超时），attempt 2 仅 30ms 后即报 `-5`——说明 DSI host 在首次 -110 后已楔死，面板级 reset 救不回。真修法需在 msm_dsi 级复位整个 DSI 控制器/host（更深的内核工作）。Q28 还有第二种失败面：`DSI PLL(0) lock failed, status=0x00000000` ×4 → dsi host enable 失败 → dpu 长时间不绑定（vk63 日志里同样有 PLL fail ×4 但 8.5s 后 dpu 仍绑定成功，说明该面有运气成分）。
---
kexec 流程代码链（本树 kernel/kexec_core.c:1138 kernel_kexec）：kernel_restart_prepare("kexec reboot") [reboot.c:100] → blocking_notifier_call_chain(SYS_RESTART)【网络 teardown 在此杀掉 SSH/读取进程】→ usermodehelper_disable() → device_shutdown()（UFS host .shutdown 走这里；device list 反向遍历 ⇒ UFS 作为早期 probe 设备最后被关）→ migrate_to_reboot_cpu() → syscore_shutdown() → 重新 cpu_hotplug_enable() → pr_notice("Starting new kernel")。因此「落盘 kmsg 在 wlan deauth 之后停止」是 SSH 先死、不是 kexec 失败。调试 kexec 时不要把 SSH 断连当成失败里程碑。
---
kexec 失败分支的代码层定位：`kernel_kexec()`（kernel/kexec_core.c:1138）非 preserve_context 路径依次执行 `kexec_in_progress=true` → `kernel_restart_prepare("kexec reboot")`（reboot.c:100，里面 `blocking_notifier_call_chain(SYS_RESTART)` 拆网络杀 SSH → `usermodehelper_disable()` → `device_shutdown()`）→ `migrate_to_reboot_cpu()` → `syscore_shutdown()` → cpu_hotplug_enable() → `pr_notice("Starting new kernel")`，再 machine_kexec。三段（notifier/device_shutdown/syscore_shutdown）任一挂死都会表现为「静默掉电且日志戛然而止」，故用 cmdline 掩码逐段跳过是可行的二分手段；另注意 UFS host 的 `.shutdown`（ufshcd_wl_shutdown）在 device_shutdown 的逆序遍历里通常最后被关，UFS 早期设备在 list 前部。 — Failed: kexec -e 硬挂/直接掉电，无跨切换存活的 console，无法定位失败分支点。
---
本机（xuqianhui1001）设备重启通路分层：`eldroid-bootctl reboot bootloader`（PSCI SYSTEM_RESET2 带 reason 写 SDAM magic）会被反复 kexec 测试写坏——命令干净返回但设备 uptime 连续增长=根本没重启（SDAM/reboot-mode 写通路 wedged）。恢复法 = SysRq 'b' 硬重启（`echo b > /proc/sysrq-trigger`，绕过 reboot-mode/ABL）。稳定进 fastboot 的组合拳 = 先 `eldroid-bootctl reboot bootloader`（写 magic，即使 RESTART2 不重启也无妨）→ 再 SysRq b（硬重启时 ABL 读到残留 magic 0x02 → fastboot）；若只 SysRq b 无先写 magic，设备正常启动（magic 已被消费）。 — Failed: kexec 测试把 reboot bootloader 通路写坏，表现为 reboot 命令空操作、uptime 连续增长
---
fastboot 变体镜像（101,425,152 B）**不能刷进 boot_b**（分区 100,663,296 B），avbtool 加 AVB footer 会报 `Image size ... exceeds maximum image size ... in order to fit in a partition size of 100663296`。要从 Linux 内免 fastboot 常驻换内核，镜像必须 ≤96MiB（或走 vk61 式 slim/full 载具瘦身）。flash-b.sh（Linux 内签 AVB + dd boot_b）因此只适用于 slim 尺寸镜像。
---
本机（xuqianhui1001）进 fastboot 的可靠组合拳（2026-10-08 起）：先 `eldroid-bootctl reboot bootloader`（只写 ABL bootloader magic 0x02，RESTART2 那步可能不重启也无妨）→ 再 `echo b > /proc/sysrq-trigger`（SysRq 硬重启，绕过被 kexec 测试写坏的 RESTART2 通路，ABL 读到残留 magic 即进 fastboot）。症状：多次 kexec（截断 device_shutdown / 跳 PON regulator 关机）后 `eldroid-bootctl reboot bootloader|system` 会变成空操作（uptime 持续增长、不重启）；SysRq b 是分水岭（能重启=硬件复位通路正常，只是 RESTART2 写通路 wedged）。脚本 scripts/kexec-bs-cycle.sh 已固化该组合。 — Failed: kexec 实验写坏 restart-mode/SDAM 写通路导致 reboot 命令静默失效，一度误判为硬件问题
---
boot.img（fastboot 变体）镜像 ≈101MB，超过 boot_b 分区 96MiB ⇒ `scripts/flash-b.sh`（Linux 内签 AVB + dd 到 boot_b）会失败：`avbtool: Image size 101425152 exceeds maximum image size 100593664 in order to fit in a partition size of 100663296`。诊断用的大 boot.img 只能 `fastboot boot` 零写盘，不能刷进 boot_b；只有 slim（~20.8MB）或完整但 <96MiB 的镜像才能 --flash。 — Failed: 误以为可从 Linux 内直接刷诊断镜像到 boot_b 以绕开失效的 fastboot 通路
---
设备侧 `reboot2`（rootfs/reboot2.c → /usr/local/sbin/reboot2）**无参数时默认 mode="bootloader"**。这是 Alpine bring-up rootfs 的设计（busybox reboot 不能传 reason 字符串），但若脚本/用户误调 `reboot2` 而不带参数，会直接进 fastboot 而非正常重启。正常关机/重启应用 `reboot`（busybox）或 `loginctl reboot`，不要用 `reboot2`。 — Failed: 用户报「之前的版本修复引入了直接重启到fastboot」，调查内核 PSCI 钩子只对显式 `reboot bootloader`/`reboot edl` 生效，但 reboot2 的默认值是一个潜在陷阱
---
用 `fastboot boot` 起一个 LOCALVERSION_AUTO=y 且树 dirty 的内核时，UTS 会带 `-dirty` 后缀（如 `7.2.0-debug-vk64-gd02658e63cf6-dirty`），与设备上 `/lib/modules/7.2.0-debug-vk64-gd02658e63cf6/` 不匹配 → 所有 =m 模块（fsa4480/fastrpc/ath12k 等）加载被拒 → 连锁故障（例：fsa4480 不加载 → DP 控制器 defer → msm_drm_bind 永不完成 → 连 card0 都没有，显示全黑）。修复：测试构建时 `scripts/config --disable LOCALVERSION_AUTO` 并硬设 `CONFIG_LOCALVERSION="-debug-vk64-gd02658e63cf6"`（精确匹配磁盘模块目录），或接受 builtin-only 无模块的退化态。 — Failed: Q28 补丁测试镜像 vk72-q28dsi 因 tree dirty → UTS 带 -dirty → fsa4480.ko 装不上 → DRM 完全不绑定 → /sys/class/drm 只有 version 文件、无 card0，补丁效果无法验证
---
to-fastboot.sh 在设备已处于 fastboot 模式时无响应（脚本先尝试 ssh reboot bootloader，但设备已是 fastboot 无 SSH）。正确流程：若 fastboot devices 已见设备，直接 fastboot boot，不要走 to-fastboot.sh。用户明确说「fastboot对这个脚本不响应。我手动boot」。
---
设备侧 `reboot2` 二进制在 `/usr/local/sbin/reboot2`（**不是** /usr/local/bin/）。`/usr/local/bin/` 下有 `eldroid-bootctl`。混淆路径导致 ssh 命令 rc=127 + 30s timeout。进 fastboot 正确命令 = `ssh root@192.168.7.1 '/usr/local/sbin/reboot2 bootloader'`。 — Failed: assistant 假设 reboot2 在 /usr/local/bin/ 导致命令失败和超时
---
ABL 槽位管理（2026-10-09 实机二次确认，补强旧条）：succ=1 后 retry 恒 7 不再递减，**无论 boot 多少次**。旧条「每次开机真的在扣次数」是基于 retry=6 的误判（那次 succ=0）。真正止血 = `qbootctl -m b`（或 `slot-attr.py mark-successful b`）一次置 succ=1，之后温启/循环测试不再累积风险。预检脚本应查 succ=1 而非「补 retry 到 7」。 — Failed: Agent 看到 retry=6 误判为「每次开机扣次数、RAM 实验在偷次数」，设 succ=1 后连掷 7 次 retry 一直是 7，当场打脸。已写入 PITFALLS #152 就地更正 + commit 372dda8。
---
设备「启动次数耗尽」的误判根因（2026-10-09）：`reboot2`（无参数=普通重启 RESTART2）被 ABL 当成「进 fastboot」——不是 retry 归零。真实判据 = `fastboot getvar slot-successful:b` 为 no（succ=0）；只要 succ=1，retry 恒 7 不递减。循环/温启脚本的预检 = **确认 succ=1**（`slot-attr.py show` 或 `qbootctl --get`），不是「补 retry」。`qbootctl -m b` 一次置 succ=1 永久止血。 — Failed: 误以为 retry 归零→进 fastboot，实际是 succ=0 + RESTART2 语义被 ABL 误解
---
Q24 电源域名称不是变量（2026-10-10 实机定案）：H2（MX 单票）间歇失败、E4a（MXC 单票 vk81）相机加载态熄屏**即睡死关机**（1/1 掉电）⇒ H1（去 PD）/H2（MX）/E4a（MXC）三种 DT 域切换全部未根治。根因不在「投哪条轨」，在 cambistmclkcc bare clock controller 的**半成品态本身**（probe 编程 PLL + 恒活 AHB 时钟 + 0 张 genpd 票 ⇒ 熄屏 DSI/面板 disable 路径触发电源域 collapse 时该块处于悬空不一致状态 → PMIC 硬复位）。剩余有效路线 = FIX-2（probe 后不 pm_runtime_put、常持票消除悬空窗口）/ FIX-3（lazy-on：probe 不编程 + runtime_suspend 彻底 quiesce 关 PLL+CBCR，最正/可上游）/ 不从 Linux 实例化该块（probe 黑名单）。不要再尝试换电源域。 — Failed: E4a (MXC) 实机熄屏即关机，与 H2 (MX) 同病，证明域名称不是变量
---
Q24 FIX-3（cambist PM lifecycle lazy-on + suspend quiesce，commit e1d2c658a）上机实测 = 卡联想 logo 无法启动（boot 死锁）。根因 = `gcc_sm8750_probe()`（gcc-sm8750.c）显式注释保持 `gcc_cam_bist_mclk_ahb_clk` always-on（同组还有 camera_ahb/camera_xo/disp_ahb/eva_ahb/gpu_cfg_ahb 等）；FIX-3 让 cambist 变为 PM-suspendable 后其 AHB 时钟可被 runtime_suspend 关掉，而 GCC 假设该 AHB 恒活 → 启动早期 AHB 被关、GCC 侧寄存器访问死锁。已 revert（commit 67fcff7f0）。结论：**「让 cambist 可挂起」方向被 GCC 硬约束否证**，剩余可行路线只剩 FIX-2（probe 后常持票不 put，消除悬空窗口但 AHB 仍活）或「不从 Linux 实例化该块」。 — Failed: FIX-3 上机 boot hang at Lenovo logo; GCC keeps cam_bist_mclk_ahb_clk always-on, PM-suspendable cambist violates that assumption
---
Q28 根因框架彻底更正（2026-10-10 用户明确）：**Q28 与时间无关，变量是复位类型（冷/暖）**。用户日常观察「全天候发作」= 冷起（物理电源/ABL 从零启动）几乎必失败；本会话 8/8 GOOD 全是 `reboot2 bootloader → fastboot boot` = **暖复位**（ABL 已初始化过、PHY/PLL 状态残留不同），根本不代表冷起结果。之前记忆里「强时间相关：晚间坏下午好」是伪归因——下午实验都是暖起。含义：(1) 任何 Q28 A/B 实验**必须用冷起路径**（物理断电后长按电源、或 `fastboot reboot` 经 ABL 完整初始化），`reboot2 bootloader → fastboot boot` 循环测不出冷起行为；(2) 上游调研的「PLL re-lock / byte-clk 取整」方向仍然有效（PLL 状态不被 warm reset 清除 = 暖起时 PHY 已锁 = 跳过脆弱路径）；(3) vk84 delay 实验结论「不可判别」的真正原因不是「下午不坏」而是「暖起本身不触发」。旧口径（时间相关、下午窗不可复现、暖起 8/8 GOOD = 当前不发作）全部 superseded。 — Failed: 把暖复位循环的 8/8 GOOD 误读为「Q28 当前时间窗不复现」，实际是测试方法学错（暖复位绕过了触发条件），导致 A/B 结论框架完全错误
---
Q28 实验方法学禁忌（2026-10-10 定案）：用 `reboot2 bootloader → fastboot boot` 循环做 Q28 A/B = **测试暖复位**，与日常冷起（物理断电/长按电源→ABL 全初始化）是完全不同的复位类型。暖起时 DSI PHY/PLL 可能残留锁定态，跳过首次 modeset 的脆弱 PLL re-lock 路径 → 几乎必 GOOD。正确做法：(a) 物理冷起（需用户拔电/长按）；(b) `fastboot reboot`（经 ABL 完整初始化，接近冷起但不完全等价）；(c) 若只能暖起，则不能用它判别修复是否有效——只能用于「确认不 crash / 能 SSH 回来」的基本冒烟。脚本 scripts/q28-boot-cycle.sh 当前用暖起路径，**不能**用于 Q28 修复验证。 — Failed: 连续 2026-10-09~10-10 两天用暖起循环做 Q28 复现/修复实验，得出「时间相关」「当前不发作」的错误结论，浪费大量实验轮次
---
Q28 vk84 delay A/B 冷 A/B trial1 结果（2026-10-10）：vk84-exp（dsi_cmd_delay_us=1000）冷 fastboot→fastboot boot = **NOCARD**（非 STORM、非 GOOD）。原因：delay 只作用于 `msm_dsi_host_bonded_cmd_init_trigger()`（首次 DCS 写，t≈9s），而 NOCARD 的 DSI PLL lock failed 发生在 t≈0.86s 的 **DSI host probe** 阶段——两者相差 8 秒、不同代码路径、不同电源状态。⇒ delay 补丁在结构上**不可能影响** NOCARD 失效。⇒ 若后续要修 NOCARD 需在 `dsi_host_probe()` / `dsi_pll_init()` 加延时或 retry，而非 cmd_trigger。另：冷 fastboot→fastboot boot 是否真正触发 POR 态存疑（ABL 仍保留部分寄存器态），真正冷可能需拔电或 `fastboot oem reboot-edl`。
---
Q28 暖复位粘态（2026-10-10 实测）：连续 `reboot2 bootloader → fastboot boot`（暖复位，不清 PMIC/PHY 状态）会把显示驱动**粘在 NOCARD**（PLL lock fail、无 card0、modeset 从未到达），与内核补丁内容无关——vk86-base（干净 vk64 基线+无诊断补丁）暖机 4/4 也是 NOCARD。⇒ **Q28 A/B 只能用物理 POR（断电→等→上电→按键进 fastboot→fastboot boot）取冷样本，暖复位循环不可判别**。C2 证实同内核 vk64 冷 fastboot=STORM（到 modeset、cmd-DMA hang），冷 fastboot ≡ 真实 POR（C1+C2 配对坐实）。
---
Q28 第四态 HANG（2026-10-10 实机定案）：STORM=0 的干净 GOOD 启动（有 card0、无风暴签名）在数秒内必定整机冻死（SSH/USB/ping 全消，APSS 硬看门狗禁用不自复位，需物理断电）。原 binary-determinism 测试的「GOOD×7」实际全是「t=14s 探针时看着 GOOD → 之后 HANG」，因为探针只拍一次、不验存活。正确判据=四态（NOCARD/STORM/GOOD-STABLE/HANG），GOOD 必须 uptime≥60s + SSH 仍活。RAM-only（无磁盘根、不起桌面）也 HANG ⇒ #106「进GUI卡死」不是 GUI 专属，任何显示 modeset 触发都可能冻死整机。STORM>0 反而存活（4/4），说明 DPU 报错风暴路径与冻结路径是两条独立失败模式。 — Failed: 原测试设计只拍 t=14s 单次快照判 GOOD/BAD，未设存活门，把 HANG 误录为 GOOD，导致「vk64 GOOD×7」的参照系本身不可靠
---
Q28 STORM 态 SSH 行为（2026-10-11 实测定案）：STORM（vblank timeout 风暴）时设备**网络层活着**（ping 通、TCP 3-way 握手成功、`ip neigh` 显示 REACHABLE），但 **ssh banner exchange 超时**——因 `drm_fb_helper_damage_work → drm_crtc_wait_one_vblank` 死循环占满 workqueue，sshd 子进程无法获得 CPU 完成 key exchange。串口 /dev/ttyACM0 可读（内核 printk 正常）但**无 shell**（不是 login shell 而是纯 console）。恢复 = 物理长按电源 ~20s → 音量下+电源进 fastboot → 反复 `fastboot boot vk64` 直到 GOOD（attempt 1~5，~40% 成功率）。**不要用 reboot2 暖路径做台架**（产生 NOCARD，非代表）。 — Failed: STORM 时 ping 通 + TCP connect 成功造成「SSH 应该能用」的错觉；实际 sshd 被 workqueue 饿死
---
Q24 死前 RPMh 取证标准流程（2026-10-11 实测成功）：台架 = fastboot boot vk64(LOCALVERSION=-vk64) → 确认 GOOD（card0 存在 + vblank=0 + resetfail=0 + dsi_isr>0）→ `echo 1 > /sys/kernel/debug/tracing/events/rpmh/rpmh_send_msg/enable; echo 1 > /sys/kernel/debug/tracing/tracing_on; cat /sys/kernel/debug/tracing/trace_pipe > 主机文件` 流式抓 → modprobe 模块 + ScreenSaver.SetActive(true) → 掉电判据 = uptime 归零 + ping 不通 + /sys/fs/pstore 空 → 每轮结束 qbootctl -m b。绝不用 `pkill -f trace_pipe`（杀自己 shell），用记录 pid + `kill <pid>` 或 `timeout` 控制 streamer。 — Failed: 首次尝试用 pkill -f trace_pipe 清理 trace 进程，把当前 SSH 会话的 bash 进程一起杀掉（命令半截没跑），重新做时改用 pid 记录。
---
phoc/phosh 上游提交路径：真实上游 = gitlab.gnome.org/World/Phosh/{phoc,phosh}，GitHub 上的 PhoshMobi/phoc 和 PhoshMobi/phosh 是 read-only mirror（hasIssuesEnabled=false, viewerPermission=READ），gh CLI 无法开 PR。GNOME GitLab 支持 GitHub OAuth 登录（用户账号 xiaquwan1001 可直接 OAuth 授权进 GitLab），无需单独注册。提交方式 = GitLab 网页 Fork → 推分支 → 开 MR，或邮件给 phosh-devel。 — Failed: gh repo view GNOME/phosh 报 Could not resolve to a Repository；gh api 对 PhoshMobi/phoc 确认是 mirror 无写权限
---
Waydroid 容器内 `waydroid session start` 需要正确的 `DBUS_SESSION_BUS_ADDRESS`——**不是** `/run/user/1000/bus`（该路径在此设备上不存在），而是 phosh/phoc 进程 environ 里的 `unix:path=/tmp/dbus-<random>`（如 `/tmp/dbus-zDSZhDcj9t`）。取法：`cat /proc/<phosh_pid>/environ | tr '\0' '\n' | grep DBUS_SESSION_BUS_ADDRESS`。错误表现：`Unable to autolaunch a dbus-daemon without a $DISPLAY for X11` 或 `Failed to connect to socket /run/user/1000/bus: No such file or directory`。 — Failed: waydroid session start 找不到 session bus 因为设备上 phosh 的 bus 在 /tmp/dbus-<random> 而非标准路径
---
Q24 与 Q28 根因独立（共享成分估 10–20%），仅工装/可测性强耦合，不是同一条电源链问题：Q28 触发 = 冷起（零相机模块照样坏，dmesg 可见）；Q24 触发 = {camcc-sm8750 + cambistmclkcc-sm8750} 配对 + 真实熄屏。三处耦合：① Q28 坏发时面板从未 enabled，熄屏只打 `Skipping disable of already disabled panel` ⇒ Q24 触发条件根本不存在（旧「cambist+熄屏 9/9 存活」是仪表坏、非无毛病）；② Q24 死亡把设备打回 Q28-bad，每次要物理 POR；③ Q24 可测性继承 Q28 的构建版本串（LOCALVERSION）敏感性。无 card0 ⇒ 无 phoc/Wayland ⇒ Waydroid session 起不来（headless weston/phoc 都试过，drmGetDevices2 failed）。解耦切入点 = 给内核加 vkms/vgem 虚拟显示。
---
「钉死 UTS 版本串」破解 Q28 构建身份法则（2026-10-11 实测）：Q28 冷起 GOOD/NOCARD 由内核 UTS 版本串内容决定；用 `CONFIG_LOCALVERSION_AUTO=n` + `LOCALVERSION=-vk64-gd02658e63cf6` 把版本串钉回日常 GOOD 串后，**改内核+改 config 的镜像（vk102-c1pin，含 IP_ADVANCED_ROUTER/IP_MULTIPLE_TABLES）仍冷起 GOOD 且 `ip rule` 可用**。⇒ 有了「改代码也能冷起 GOOD」的可控台架，冷起 A/B 测 DSI 补丁才重新可行。脚本 scripts/q28-build-arm-lv64.sh 已加 PINUTS 支持。
---
对 fastboot 客户端用 `timeout ... | head/tail` 会在传输中途 SIGPIPE 掐断 fastboot 客户端，把设备的 fastboot bulk 通道打断——此后 bootloader 不再应答（`fastboot devices` 仍有 USB 描述符，但 `getvar` / 任何传输 rc=124 超时且永不再重枚举），必须物理 POR。规则：fastboot 包装命令不要管道给 head/tail，也不要中途 timeout 掐断；先 `fastboot getvar product` 探测应答、再发长传输。
---
对 `fastboot getvar` 之类交互式 fastboot 命令套 `timeout … | head/tail` 会 SIGPIPE 中途掐断客户端，**把设备的 fastboot bulk 通道打断**，此后 bootloader 从不应答（USB 描述符还在、getvar 恒 rc=124、84MB 传输全部白等），只能物理 POR 恢复。规则：fastboot 命令不要管道给 head/tail，也不要轻易加 timeout。 — Failed: 10:40 探测时对 fastboot getvar 用了 timeout+head，gadget 卡死，需用户物理 POR
---
Q28 排查的「脚本自动 reboot 到 fastboot」不可靠：q28-cold-sample-loop.sh / q28-cold-run.sh 这类脚本假设能从 Linux 自动 reboot2 bootloader 进 fastboot 做冷起 A/B，但实际不可用（用户原话「这个脚本有问题，没法做重启到fastboot」）。真正有效的冷起 = 用户手动物理 POR（长按电源彻底关机 → 音量下+电源进 fastboot），然后 agent 只用 `fastboot boot <img>` + 取证部分。凡涉及 Q28 冷起采样的脚本，应只负责「等 fastboot → boot → 取证」，把 POR 交给用户手动做。
---
Q28 vk116-dsirec（DSI 链路失败自恢复臂）冷起采样结果（2026-10-12 晚）：前 3 发（用户手动 POR）全 GOOD、第 4 发 L1FAIL；且 q28 三类失败签名计数全 0 ⇒ 恢复路径一次都没被触发，补丁是 no-op，机制有效性**仍未验证**。判据 = 日志须出现 `command DMA failed before video enable, resetting DSI link`；未触发说明坏发没走到首条 DCS 超时那条路径（或坏发概率 ~50% 下 3 发不够）。 — Failed: 在 3/3 GOOD 时过早宣布方向成功；实际补丁未被触发，不能作为机制验证证据
---
Q28 恢复路线否证（2026-10-12 实测）：驱动内自恢复臂（清 `dsi_bonded_cmd_failed` 闩锁 + 复位 DSI ctrl/PHY 再重试）**不救场**。vk117 坏发寄存器转储（patch q28-dsi-recover2 新增能力）证明控制器真被复位（CTRL 0x175→0x171，CLK_STATUS 0x3743→0x1743，DYN_PCLK_ACTIVE 被清、CMD_PCLK 清），且 `unbalanced disables` 警告 0 次（vk116 同场景 6 次）；但第 2/3 次 DCS 仍逐字相同失败 `command DMA timeout status=0x2200200`（200ms 软超时）→ master=-110 peer=-110。⇒ 故障不在「软件闩锁/控制器状态」，复位-重试路线否证。同时更正旧口径：重试拿到 `-5` 并非硬件楔死，而是 `dsi_bonded_cmd_failed` 在 `dsi_mgr_bonded_cmd_xfer()` 开头短路（根本没碰 DMA）；清除闩锁后 `-5` 变 `-110`，证明闩锁机制如判。
---
Q28 vk116 冷起 3/3 GOOD（18:36/18:42/18:52，用户手动 POR）但坏发签名计数全 0 ⇒ 恢复路径一次都没被触发、补丁实为 no-op，机制有效性未验证。当晚会话第 4 发冷起出现 L1FAIL（19:10），并观测到 `Turning OFF PHY while PLL is on` + `unbalanced disables for vreg_l3i_0p88`（regulator/core.c:3261 WARNING）——坏发还有 `disp_cc_mdss_pclk0/1_clk_src`/`byte0/1_clk_src: orphan reparent failed: -110`（t≈0.87s）与 `DSI PLL(0) lock failed status=0x00000000` ×4。
---
Q28 驱动内自恢复路线已被两次不同臂否证：vk116（清 dsi_bonded_cmd_failed 闩锁 + 复位 DSI ctrl+PHY 后重试）机制从未被触发（4 发全 GOOD，三类签名计数全 0 ⇒ no-op）；vk117（恢复序列对齐 post_disable、去重复 phy_disable + 复位前后寄存器转储）在坏发上证明复位**确实生效**（CLK_STATUS 0x3743→0x1743，DYN_PCLK/DYN_CMD_PCLK 被清）但第 2/3 次 DCS 仍逐字相同地失败（status=0x2200200, master=-110 peer=-110）。⇒ 故障不在 DSI 控制器状态，驱动内 reset 救不回。
---
Q28 坏发卡点精确定位（vk118/vk119/vk120 首命令探针）：**首条 DCS 命令是成功的**（after-first-cmd-ok CLK_STATUS=0x2343，与 2026-10-09 好发同点逐字相同），卡死在**后续命令**的 DYN pclk 域切换——失败后 CLK_STATUS=0x3743（置起 DYN_PCLK 0x400 + DYN_CMD_PCLK 0x1000 + CMD_PCLK 0x2000）、STATUS0=0x20003（CMD_MODE_ENGINE_BUSY|DSI_BUSY）。死前伴随 `Turning OFF PHY while PLL is on` + `unbalanced disables for vreg_l3i_0p88`（regulator/core.c:3261 WARNING）+ `disp_cc_mdss_pclk0/1_clk_src: rcg didn't update its configuration`（clk-rcg2.c:136 update_config/0xdc，调用链 clk_pixel_set_rate）⇒ 嫌疑指向 DYN pclk 时钟域切换 / RCG 配置未更新，而非 DSI 命令 DMA 硬件本身。
---
Q28 旧结论「首条 DCS 超时后 DSI host 楔死、面板级 reset 救不回、重试必然 -5」被代码级纠正（2026-10-12）：重试那条 `-5` (EIO) 来自 `dsi_manager.c` 静态闩锁 `dsi_bonded_cmd_failed` 在 `dsi_mgr_bonded_cmd_xfer()` 开头的 `return -EIO` 短路——第 2/3 次 DCS 根本没触碰 DMA 硬件。该 bool 全树只写 true、从不清零，且短路 5 处 bridge 上下电路径（pre_enable/power_off/enable/post_disable）⇒ 故障自锁。清闩锁后重试确实打到硬件（vk116 首个坏发日志第 2/3 次变成 -110 而非 -5）。但这不改变「驱动内 reset 不救场」的结论（见 vk117）。
---
设备侧复位路径陷阱（2026-10-12 实锤，待用户确认型号行为后落 PITFALLS）：桌面未起完（uptime≈20s）时执行 `reboot2 bootloader` 会把设备挂到**无任何 USB 通道**（既非 fastboot 也非 SSH，需物理 POR）。推测此前某些「hang 桌面挂起」现象是脚本里过早 reboot2 造成。对策已落地：`scripts/lib-boot-ready.sh`（复位前就绪门 = uptime>=90s + 桌面已起，fail-closed）已接线到 q28-boot-cycle.sh/q28-layout-ab.sh/q28-layout-one.sh（分支 audit/early-reboot，合并 commit bd97123，审计报告 reports/audit-early-reboot-20261012.md）。
---
Q28 坏发首条 DCS 超时后**驱动内复位 DSI ctrl/PHY 路线否证**（vk117 寄存器转储）：控制器确实被复位（CTRL 0x175→0x171、CLK_STATUS 0x3743→0x1743、CMD_DMA_CTRL 0xd4000000→0x14000000），`unbalanced disables` 6→0，但第 2/3 次 DCS 仍逐字相同失败（command DMA timeout status=0x2200200 → master=-110 peer=-110）。vk116 的清闩锁 + 重试使失败从 -5 变回 -110（证明软件闩锁真被清、重试真打到 DMA 硬件），但救不回场。 — Failed: 驱动内 DSI ctrl/PHY 复位不是 Q28 的修复路径。
---
M1 资产树（build/m1-upstream/clean-tree 与 clean-tree-73）血统落后于 clean/base 的设备侧修复，带的是 PITFALLS #108 之前的板 DTS（&i2c0 status="okay"）⇒ 一上机必硬关机（fastboot boot 报 OKAY 后黑屏、无 USB gadget、~39s 回旧系统）。M1 系列上机前必须逐条对照 clean/base 的板 DTS 修复（i2c0 disabled、splash_region 命名、去 simple-framebuffer、sdhc no-1-8-v）。已在 M1-73 树提交 1e4077e13f / b3815fb150。
---
M1-7.3 另一个显示失败模式：`&mdss_dp0 { status="okay" }` + ADSP 起了但 fsa4480/typec mode-switch 缺失时，DP 控制器永久 defer 会**阻塞 msm_drm_bind** ⇒ 整机无 card0（但背光/部分外设正常）。单变量验证：只把 &mdss_dp0 改成 disabled 重建 DTB → card0 + card0-DSI-1 connected + greetd/phoc/phosh 全起。修法 = 确保 fsa4480.ko 加载（或 DP 实验期临时 disabled）。与 historic DP 修复（dr_mode=otg + usb-role-switch + mdss_dp0 okay 三处齐）一致。
---
M1 重基树（build/m1-upstream/clean-tree-73）上机验证经验：① 73h 内置「磁盘黑匣子」= ramdisk 第二段 cpio 覆盖 /init（后台子进程等 LABEL=linux17 → 挂 /mnt/dbg → fd9 每 3s 追加 dmesg + sync，跑 400 轮 ~20min，独立于正常启动）⇒ 零写盘取全量 dmesg（0.0s 起）的通道，但不带 sync 的旧版会留 0 字节文件。② 设备无 7.3 的 /lib/modules ⇒ 需要 =m 驱动时从 build/m1-upstream/clean-tree-73/ 下取 .ko（aarch64-linux-gnu-strip 后 vermagic 仍匹配）。③ M1 树已含 psci reboot 钩子（6776a30860），可 `reboot2 bootloader` 进 fastboot。
---
`scripts/trial.sh record` 必须带 `--label`（缺参会报 `[trial] ❌ record 需要 --label`）；且 `--reset` 类型必须显式声明 por|cold|warm——用 warm（reboot2 bootloader→fastboot boot）记录会污染冷起样本，A/B 对照前必须区分复位类型。
---
设备侧 dsi_isr 中断计数恒为 0 是判断「上游 DSI host 是否真在发视频流」的硬指标：P4a 健康发（l1=l2=0、phoc/phosh/wayland 全起、card0-DSI-1 connected enabled dpms=On、backlight 511）下 `dsi_isr` 两个 host 都恒为 0，且 `grim` 报 no supported format found ⇒ 该「健康发」实际合成器未 modeset、DSI host 未启动视频引擎。注意命令模式面板空闲不推帧所以只能看累计值（好发>0/坏发=0）。
---
设备探测 SSH 纪律（2026-10-14 补充）：轮询式 ssh 重试（本次 ~60 次）后设备 sshd 立刻回 `Not allowed at this time`（OpenSSH 9.8+ PerSourcePenalties 源惩罚，由 /usr/sbin/sshd 在 MaxStartups 触发时发出），随后连 banner 都不再给（Connection timed out during banner exchange）——TCP 能连上（内核 backlog）但用户态不回，极易误判成「系统挂死」。惩罚按源 IP 记账，安静等待也不可靠（新连接可能续期），最稳恢复 = 重启设备。纪律：单次连接 + ≥15s 退避，用 `-o ConnectionAttempts=1 -o ConnectTimeout=8`，禁止 for 循环里高频 ssh。scripts/trial.sh record 必须带 --label（缺参会报 `[trial] ❌ record 需要 --label`），实验中用 warm（reboot2 bootloader→fastboot boot）记录的 trial 会污染冷起样本，必须显式区分 reset 类型。
---
Q28 上游臂实验方法学（2026-10-14 验证）：设备显示处于坏态时 `reboot`/`reboot2`/`eldroid-bootctl reboot system` 都会挂在 DRM cleanup（进程不退、uptime 继续涨），可靠软件恢复 = `echo b > /proc/sysrq-trigger` 或串口 BREAK+'h'+'b'（SysRq-b）。因此「窗口搜索脚本」应先单次 SSH `reboot2 bootloader`，失败（SSH 不可用）则改用 SysRq-b 两级复位（SysRq-b → 回日常 boot_b → 再进 fastboot）。`scripts/arm-console-run.sh` 已封装 arm 实验 + 常驻串口日志（logs/arm-<label>-<ts>/console.log）。健康发判据 = 串口从 t=0 全程捕获 + L1=L2=0 + 单次 SSH 状态全绿。
---
上游 DSI 栈「结构健康但面板不亮」的决定性证据（2026-10-14 P2c/P4a/P4d 臂）：即使 modetest 强制 modeset（CRTC 106 fb=111 1904x3040，绕过合成器），`dsi_isr` 计数**恒为 0**（两个 DSI host 都不响）+ 用户目视「纯黑仅背光」⇒ 上游 DSI host **根本没启动视频引擎**；同窗口 vendor 栈（m1-73j）`dsi_isr=41`（不再增长）、grim 能出图，但用户目视同样「有声音和背光、屏幕无内容」⇒ 面板不亮不是上游臂独有。诊断探针结论（P4d DIAG）：`mgr bridge_enable id=0 powered=1 bonded=1`、`host_enable id=0/1 mode_flags=0x2e03 power_on=1 ctrl_before=0x171 → ctrl_after=0x173` ⇒ **video 使能路径确实被调用**（DSI_CTRL bit1 VID_MODE_EN 已置位），缺的是让 video 真跑起来的东西（时钟/PLL）。时钟侧：`dsi0vco=756.8MHz`、`disp_cc_mdss_pclk1_clk_src=172.992MHz` 正常；slave `dsi1vco=0` 待查。
---
显示类实验的复位纪律（2026-10-14 实锤修正）：「连续温复位（reboot2 bootloader→fastboot boot）会粘 DSI 坏态、必须物理 POR」这条旧口径**不能滥用**——本轮做了约 10 次温复位后一度以为全部现象都是粘态，但用户纠正 vk94 该窗口正常出桌面。正确做法 = 每轮实验都带上**已知健康的对照臂**（如 vk94 日常镜像）跑一次，用对照臂结果判定「是窗口坏还是被测臂坏」，不要先归因到粘态。
---
上游 DSI 栈缺 video 使能（2026-10-14 探针臂定案）：P4d 诊断探针显示 `DSI_CTRL` bit1 VID_MODE_EN 已置位（ctrl 0x171→0x173）、bridge_enable/host_enable 都被调用、时钟侧 dsi0vco=756.8MHz 与 disp_cc_mdss_pclk1_clk_src=172.992MHz 都对，但 dsi_isr 恒 0、modetest 强制 modeset（CRTC fb=111/1904x3040）后面板仍纯黑 ⇒ 上游 DSI host 根本没让 video 跑起来，缺的是 trigger/engine start 那块（与 vendor 栈 dsi_isr=41 的关键差异）。
---
暖复位路径（reboot2 bootloader→fastboot boot）会污染显示臂实验台架，与补丁无关：E1b 暖链得 L2STORM（dsi_isr=0 + 127 条 reset/vblank 风暴），但**已知 GOOD 的 E1 镜像走同一暖路径也 L2STORM + dsi_isr=0** ⇒ 控制组证明台架坏、不能据此判补丁。用法：判显示臂必须真实 POR；若只能暖链，先跑已知 GOOD 镜像做控制组，并检查 dsi_isr 累计值（暖链恒 0）。
---
内核 DSI PHY 探针写寄存器时注意成员路径：`struct dsi_pll_7nm` **没有 `pll_base`** 成员，正确写法 `pll->phy->pll_base`；`dsi_7nm_phy_enable()` 里只有 `phy`/`base`。写错会 3.9s 即编译失败（`error: 'struct dsi_pll_7nm' has no member named 'pll_base'`），只影响 dsi_phy_7nm.o。
---
M1-7.3 树上 Q28 与日常内核的耦合：Q28 坏发（~50%）同样出现在 M1 臂上（E1b POR 第一发即 command DMA timeout status=0x2200200 → bonded command DMA failed master=-110 peer=0 @95.58s，L1=2；日常 vk94 的 SysRq-b 重启也命中 9.07s 经典签名 + phoc=0）。区分办法：坏发看 `command DMA timeout` / `dsi_isr=0` / `hw recovery is not complete for ctl:1`；好发看 dsi_isr=41、L1/L2=0。设备侧 `q28-watchdog.sh` 是 **disabled** 状态（/etc/q28-watchdog.disable），不会自愈，需手动 SysRq-b 重试等好发。
---
fastboot 不存在 fetch 功能（本 ABL 支持不了）：`fastboot fetch` 报 `Unable to get max-fetch-size. Device does not support fetch command.`（2026-10-17 复核，此前 2026-10-06/10-08 已两次证实）⇒ 「刷写前先用 fastboot fetch 备份分区」的配方一律错。备份分区可行手段只有：① 设备侧 `dd if=/dev/disk/by-label/<part>` 后 ssh/tar 取回；② EDL(9008) 读回；③ 事先已有的镜像副本。写文档/脚本前先查设备侧能力，别照抄 `fastboot --help`。补充判据：失败时输出文件 0 字节（sha256 e3b0c442… 空文件），`fastboot fetch boot_b` 同样报此错。
---
fastboot 不存在 fetch 功能（2026-10-17 第 3 次实测证伪，用户原话「带有 fetch 的一律是幻觉」）：fastboot 客户端有 fetch 子命令但设备 ABL 未实现，实测 `Unable to get max-fetch-size. Device does not support fetch command.`。备份分区只能：① 设备侧 `dd if=/dev/disk/by-partlabel/<part>` 后 ssh/tar 取回；② EDL(9008) 读回；③ 已有镜像副本。写文档/脚本前先查设备侧能力，别照抄 fastboot --help。
---
avbtool 的可靠获取路径（2026-10-18 实测）：`https://android.googlesource.com/platform/external/avb/+/refs/heads/main/tools/avbtool.py?format=TEXT` 用 base64 -d 解出（文件在 tools/ 子目录，名字是 avbtool.py 而非 `avbtool`；codelinaro/avb 的 raw 路径 404）。本仓 scripts/sign-boot-b.sh 依赖 tools/avbtool.py + bootslot-b/avb.key 自签 b 槽，而 tools/ 因 .gitignore 的 `/tools/` 随换机丢失；签名后镜像 pad 到 96 MiB，fastboot 写回 readback sha 一致。
---
在设备上跑可能挂住的命令（如 `waydroid session start`）必须包 `timeout`，否则会话被卡、只能用户中断——2026-10-18 Q28 坏态时屏幕无法确认容器是否拉起，用户原话「命令没有设置超时」。另：waydroid session 需要 DISPLAY/WAYLAND_DISPLAY（否则报 'Unable to autolaunch a dbus-daemon without a $DISPLAY'），且 Q28 坏态下 phoc 可能尚未起。
