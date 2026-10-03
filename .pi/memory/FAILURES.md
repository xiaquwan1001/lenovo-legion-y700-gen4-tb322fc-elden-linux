# Failures — flashing

- 用 qfil/默认全量刷而漏写关键分区（vbmeta/super/init_boot）→ 看似成功但 boot 链不配套。
  必须 EDL 逐分区补并读回哈希。
- 把 fastboot 的"传输完成"当作镜像完整：大镜像可能静默损坏，必须读回比对 hash。
- 坏线/老 USB 口导致的断联被误判为设备砖：先换线换口。
- 缩小 userdata 后不格式化 → 旧文件系统超界，bootloop。
- 把某槽早期死亡误判为内核 bug：先验证两槽镜像哈希是否一致、另一槽是否干净。
- 依赖 TWRP 做恢复：该机 ramdisk 体积受限，TWRP 可能起不来，需备 root 替代路径。


## Memory - 2026-09-28

TB322FC (Y700 Gen4) 的 fastboot 对批量脚本/连续命令响应差、易卡住。应拆成单条简单 fastboot 命令（flash dtbo_a / dtbo_b / boot 各自单独执行）。报 "Write to device failed (No such file or directory)" 时，先单条 `fastboot reboot bootloader`，等待后再单条 `fastboot boot <img>`。


## Memory - 2026-09-29

Y700(TB322FC) 主线 Linux 充电策略不可用：插着充电器仍净掉电（PMIC charger/SMB 未驱动），长任务（如经 USB NCM 走代理 apk 装大包）会把电池耗尽。进主线前应先在 Android 充满，并控制任务时长；机内长任务勿依赖边充边跑。


## Memory - 2026-09-29

sysfs 驱动 bind 属性必须写**设备名**而非设备路径：`echo 0000:01:00.0 > /sys/bus/pci/drivers/ath12k_wifi7_pci/bind` ✅；写完整路径 `/sys/bus/pci/devices/0000:01:00.0` ❌（内核按名字查找设备，路径匹配失败 → 立即返回错误、不触发 probe）。此坑让开机 ath12k 重试脚本静默失效很久。


## Memory - 2026-09-29

远程 ssh 里用 `pkill -f <模式>` 会匹配到**自己这条 sh -c 命令行**（命令文本含该模式），从而杀死自身 shell，严重时连带结束整个图形会话（phoc/phosh 一起退出）。必须用 `pkill -x <精确进程名>`，或把清理脚本写成文件再执行。


## Memory - 2026-09-29

TB322FC(Y700 Gen4) ZUXOS: 在 TWRP 里用 resize.f2fs 缩小 userdata（数据在块层确实保住了，Android 也能挂载），但 **ZUXOS 会检测到 userdata 容量不对 → 反复重启卡 logo**。所以要改 GPT 给 Linux 分区，必须按之前成功的方法：**GPT 手术后把 userdata 擦掉让 Android 重建**，不能靠在线 resize 保数据。


## Memory - 2026-09-29

GPT 缩小 userdata 后若不在 Android 侧擦除重建 /data（f2fs 仍自认旧容量），fs_mgr 挂载失败 → bootloop 卡 logo；TWRP resize.f2fs 在线缩容也救不了（ZUXOS 检测容量不符反复重启）。必须 fastboot erase userdata + erase metadata 后让 Android 重建。


## Memory - 2026-09-29

TB322FC(Y700 Gen4) fastboot：`fastboot boot <img>` 失败（Status read failed / No such device）会把 current-slot 翻到 b，而 b 槽引导链是另一套固件（vbmeta_b 密钥 8fcb864f…，a 槽是 2597c218…）永远起不来。所以每次进 fastboot 后任何操作前先 `fastboot --set-active=a`；boot 失败后先单条 `fastboot reboot bootloader`，等 6–8 秒再重试单条 `fastboot boot`。


## Memory - 2026-09-29

TB322FC 主线（GEEKiDoS 7.2 内核）睡眠即挂死：/sys/power/mem_sleep 默认 [deep]，一旦进 mem 就死机黑屏、只能长按电源重启（PSCI SYSTEM_SUSPEND/电源域未支持）。缓解：echo s2idle > /sys/power/mem_sleep + 关桌面空闲灭屏（idle-delay=0）。本机无 logind/elogind，能触发挂起的只有显式 echo mem > /sys/power/state 或 phosh 电源菜单。


## Memory - 2026-09-29

TB322FC 自编 Linux 从 b 槽直启时，Android 的 A/B 槽「启动失败重试计数」（misc 里 bootloader_control 的 tries_remaining/successful_boot）不会被 Linux 更新 → 反复重启几次后 ABL 判定该槽不可信，直接停在 fastboot。恢复：fastboot --set-active=b（会重置槽位元数据）+ fastboot reboot；不行就 fastboot boot <img>（RAM）。持久修复需在 Linux /init 里写 misc 偏移 2048 的 bootloader_control 标记启动成功。


## Memory - 2026-09-29

TB322FC 主线 Phosh：熄屏（按电源键或空闲自动）后无法再唤醒——phoc 在 /run/phosh.log 打 "connector DSI-1: Turning off"，dpms=Off、背光 511/4095、bl_power=4，内核仍活着；从外面 echo On > /sys/class/drm/card0/card0-DSI-1/dpms 会 Permission denied（DRM master 在 phoc 手上）。phoc 退出后 seatd 会卡 "seat is VT-bound and has an active client" 导致桌面起不来，此时直接 reboot -f 最省事。


## Memory - 2026-09-30

Linux /init 若不 export HOME，PID1 继承内核的 HOME=/；phosh/phoc/gsd-*/dconf-service 全带上 HOME=/，dconf 用户库被写到 /.config/dconf/user 而不是 /root/.config，表现是 gsettings/dconf 改了不持久（读回 default）。修法：会话启动脚本里 export HOME=/root，并把 /.config/dconf/user 迁移到 /root/.config。


## Memory - 2026-09-30

QCA WCN7861 蓝牙（TB322FC/elden）：不要靠改 NVM 固件文件（brhperinv20.bin/brhbtnv20.bin 的 tag 27）来关 IBS 深度睡眠——peripheral setup 会 EIO(5) 并卡死控制器，需 reboot -f。只能在驱动 hci_qca.c/btqca.c 里改。


## Memory - 2026-10-01

SourceForge large-file downloads: when the network requires a proxy (Clash 127.0.0.1:7897 via http_proxy env), curl works but Motrix/aria2 gets HTTP 403 (they ignore proxy env). Fix: download with curl (-L -C -) or configure the downloader's proxy. The file/URL is usually fine — verify against the official OTA JSON (filename+size+sha256) before blaming the resource.


## Memory - 2026-10-01

Waydroid on TB322FC (elden, SM8750/Adreno 830, Alpine musl): container boots fully but SurfaceFlinger crash-loops. Root cause chain: RenderEngine aborts 'output buffer not gpu writeable' because gralloc (minigbm_gbm_mesa) -> Mesa GBM -> freedreno fails. Verbose log (setenv MINIGBM_DEBUG 1 in the allocator rc, bind-mounted) shows 'GBM-MESA-WRAPPER: Unable to create gbm device' then Mesa 'fd_pipe_new2:51: unsupported GPU id 0x0 / chip id 0xe844050000'. The container's Android-bionic Mesa 26.0.8 does not accept the Adreno 830 chip id; host Alpine Mesa 26.1.6 does (host GLES/Vulkan work). CANNOT swap host Mesa in: container libs need libc.so (bionic), host needs libc.musl-aarch64.so.1. Fix requires a newer bionic/Android Mesa (build or newer Waydroid vendor image), not a config tweak. Also need /dev/dri/card0 bound + chmod 666 and IPv6 netfilter modules for netd.


## Memory - 2026-10-01

`pkill -f <模式>` 在本机 bash -c 命令行里会匹配并杀死自己这条命令（命令文本含该模式），导致命令中途 SIGTERM、后续步骤全不执行。要用 `pkill -x <精确名>`、或用 `pgrep` 取 PID 后 `kill -TERM -<pgid>`；写成脚本文件执行更稳。


## Memory - 2026-10-01

本机（y700-elden 主机）github 的「直连 vs 代理」可用性会随时间反转，且反转是无提示的静默卡死：写死单一路径的同步脚本会在拓扑变了之后 0 B/s 卡住（git fetch 进程存活、index-pack 挂着、日志不再新增）。判断方法：`.repo` 2 分钟内零增长 + `curl -x http://127.0.0.1:7897 https://github.com/` 与清 env 直连各测一次。修法：脚本里同时配置两条路——github/gitlab 走代理、AOSP 走清华镜像直连（no_proxy=mirrors.tuna.tsinghua.edu.cn），并先做 precheck。见 ~/waydroid-build/sync-resume2.sh。


## Memory - 2026-10-01

y700-elden 打 boot.img 的两个坑：①`scripts/build-boot.sh` 曾只是精简版（只打 busybox initramfs → 21MB），设备真实启动镜像必须用 **Alpine rootfs 作 ramdisk**（`out/rootfs-vk11.cpio.gz`，60MB）+ cmdline 末尾 `elden_root=LABEL=linux17`，产物体积应 ≈83MB。②内核树 `.config` 可能被换成精简版（曾缺 `DRM_MSM` 等 1400+ 内置项），构建前必须与设备 `/proc/config.gz` 对比；正确基座 `patches/config-vk27-container-netfilter`。验证方法：用旧内核 + 旧 ramdisk 重跑构建脚本，与旧 boot.img 逐字节 sha256 相同才算配方正确。


## Memory - 2026-10-01

本机网络测速/可达性测试的致命陷阱：shell 全局设了 http_proxy/https_proxy/all_proxy=http://127.0.0.1:7897，且 no_proxy 只放行 ustc.edu.cn。于是 curl/git 默认全走代理（代理时好时坏 → 大量假 000/假慢）；更坑的是 `curl --interface enp6s0` 会把「连本地代理」的 socket 绑到网卡上必然失败，导致误判「有线口到不了某站」。正确测法：`curl --noproxy '*'`（或 env 清掉 http_proxy/https_proxy/all_proxy/ALL_PROXY），且 git 要同时清 env 与 http.proxy 配置。


## Memory - 2026-10-01

内核树里直接跑 `make`（不带 ARCH/CROSS_COMPILE）会触发 syncconfig 并按**宿主架构(x86)**重写 `.config`，把 arm64 配置整体冲掉（体积从 ~322KB 降到 ~244KB，头变 "# Linux/x86"）。y700-elden 必须用 `scripts/build-kernel.sh`（内部 export PATH=$HOME/bin + ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-），或显式带上这些变量。误伤后从 `patches/config-vk28-netd-ipv6-xfrm` 恢复。


## Memory - 2026-10-01

y700-elden 设备 SSH 操作：不要在一条 ssh 里 `sleep` 长等（如 sleep 70 等 waydroid 起来），会被工具/连接超时中断为 "Command aborted" 且看不到结果。正确做法：ssh 只发启动命令后立即返回（nohup ... &），随后用独立的短命令轮询状态（waydroid status / dmesg），每次 ssh 都要 ConnectTimeout=6 且命令本身短小。


## Memory - 2026-10-01

本机反复踩的坑：在 bash 里用 `pgrep -f`/`pkill -f "模式"` 时，若模式字符串（如 server.js、PI_AGENT_NAME=X）也出现在当前命令行里，会匹配到执行中的 shell 自身并把它杀掉（命令中途 exit 143，后续步骤不执行）。改用变量拼接破坏字面量（如 'ser''ver.js'）、`pgrep -x`、或先写脚本文件再执行。


## Memory - 2026-10-02

pi-messenger-swarm 子代理"秒退/agent crashed"（2026-10-02）两个真因：①ustc_ai 每 key 限 20 请求/滚动窗口，pi 默认 retry.maxRetries=3（2/4/8s）在窗口复位前放弃→exitCode 0。修：settings.json 加 retry{maxRetries:8,baseDelayMs:3000,maxAgentDelayMs:60000}，并降 maxConcurrentSpawns。②本机多项目共用 node_modules 与 /tmp/pi-messenger-swarm.log；别的项目 SIGTERM 其 harness 时本项目的也被重启，worker stdout 是管道→SIGPIPE 死。修：给 dist/swarm/spawn.js 打 spawn detached+stdout 落文件的 LOCAL PATCH（scripts/apply-swarm-patch.sh 重新应用），重启 harness 用 kill -TERM（preserve）而非 --stop。另：swarm.sh 须每次钉回 .pi/messenger/session-id 原桶，且 PI_AGENT_NAME 用 ${..:-SageYak} 不硬编码。


## Memory - 2026-10-02

ustc_ai 端点（api.llm.ustc.edu.cn）限流是双重的：①每 api_key 20 请求/滚动窗口；②每 key 另有 3 小时金额预算 $30（超限回 429 ExceededBudget: Key over 3h budget. Spend=$X, Limit=$30.00, type=budget_exceeded）。两者表现相同：pi agent 重试耗尽后 exitCode 0 干净退出，看起来像崩溃。budget 类调 retry 无效，只能停跑或换 key，等 3h 窗口滚出预算。排查：grep 事件流 'budget_exceeded'/'Spend='。


## Memory - 2026-10-02

Win-x86 转译(Box64+Wine, 2026-10-02)：Ubuntu noble 自带的 box64 0.2.6(2024-01) 与 Wine 9.0 不兼容——初始化 prefix 时 explorer.exe 无限重生，262 进程/load 74/OOM，拖垮设备。改用 Pi-Apps-Coders box64 0.4.5(2026-10)+ 后正常。防护：在设备上用 cgroup v2（/sys/fs/cgroup/guard 设 pids.max）+ timeout -k + trap 退出按 comm 名 pkill -9（explorer.exe/services.exe/wineserver64 等），避免 fork 风暴。Ubuntu wine64 包无 /usr/bin/wine64，须用 /usr/lib/wine/wine64 且把 /usr/lib/wine/wineserver 末尾 exec 改成经 box64 调用。外部 exe 必须放进 chroot 内（host /root 对 chroot 不可见，否则 wine 报 c0000135）。


## Memory - 2026-10-02

安卓"过环境"(2026-10-02, Y700 TB322FC/Android16/KSU 3.2.5 LKM)：① Shamiko/ZygiskNext/TrickyStore 的官方模块 zip 用 xz(method 95) 压缩，标准 unzip 和 KSU Rust zip 装不了 → 需重打成 deflate（脚本 env-pass/tools/repack_module_zip.py）。② Shamiko 1.2.5 的 customize.sh 校验 `KSU_KERNEL_VER_CODE >= 20000` 就 abort "KernelSU version abnormal"；官方 KSU 3.x 版本号是 32525 → 误判，需改脚本去掉该分支。③ 官方 KernelSU 内核按 APK size+hash 识别管理器（不是包名），改名无效；要"隐藏管理器"须换 KernelSU-Next/SukiSU-Ultra。④ 软件栈(ZN+Shamiko+PIF+TrickyStore+resetprop 属性伪装)能让 Native Detector 判 normal；但 KSU 管理器包名 me.weishu.kernelsu 会被扫出，临时卸载即清，root 仍可用(ksud+allowlist)。


## Memory - 2026-10-02

y700-elden 上 `adb shell su -c '<复杂命令>'` 不可靠：复合/带引号的命令会被吞/中断（"Command aborted"），导致后续步骤静默失败。可靠做法：在设备端自己的 root 终端（MT管理器→终端 / Termux）里先 `su`，再逐条执行；或用 `adb shell` 跑不需要 root 的单条短命令。排查时不要只信 adb 返回，要在设备端确认。


## Memory - 2026-10-02

TB322FC 刷自编 boot 被 ABL 拒（卡 fastboot、slot 标 unbootable）的根因与修法(2026-10-02)：boot_a 是 vbmeta_a 的 chained AVB 分区，受信 AOSP testkey（公钥 sha1 2597c218，私钥=external/avb/test/data/testkey_rsa4096.pem），rollback index location 3（原厂值 1738713600）。CI/第三方产出的 boot 常用别的 key+rollback=0 签 → ABL 拒绝（且 fastboot boot 会借道 AVB 所以看起来能起，容易误判）。修法：avbtool add_hash_footer --partition_size 100663296 --partition_name boot --key testkey_rsa4096.pem --algorithm SHA256_RSA4096 --rollback_index 1738713600 --prop com.android.build.boot.os_version:15 --prop com.android.build.boot.fingerprint:<原厂> --prop com.android.build.boot.security_patch:2025-02-05。缺 props 也会失败（对照社区可用镜像才定位）。回退：flash stock boot_a（backup/stock-259/boot_a.img）。


## Memory - 2026-10-02

CN 网络抓取 GitHub 技术文档：raw.githubusercontent.com 常被 DNS 污染/连不上，但 github.com 与 api.github.com 可直连。取 README/单文件优先用 GitHub API：curl -H 'Accept: application/vnd.github.raw' https://api.github.com/repos/<owner>/<repo>/readme（或 /contents/<path>?ref=<branch>）。Wiki 用 github.com/<o>/<r>/wiki/<Page> HTML 提取。googlesource/cs.android.com 常不可达，AOSP 源码走 msft-mirror-aosp/<带点路径> 的 GitHub 镜像。本机代理 127.0.0.1:7897 可能整体故障（curl 35 TLS unexpected eof），此时临时 --noproxy '*' 直连反而成功；web_fetch/web_search 走代理会全灭，改用 bash+curl 直连。


## Memory - 2026-10-03

在只能靠单一远程通道（SSH/网络）进入的持久系统上，不要做可能导致自身失联的实验性参数改动（如电源/熄屏/网络）。先在可回滚的临时环境（RAM 启动、备用槽、离线镜像）验证，确认无害或准备好带外恢复手段后再落到持久系统。案例：把 Linux 平板桌面 idle-delay 改小以复现「熄屏→重启」bug，结果每次熄屏即重启、SSH 窗口短于复现周期，设备陷入重启环无法改回。


## Memory - 2026-10-03

间歇性设备故障排查的观察者效应（y700-elden 2026-10-03）：为抓"静默硬复位"给持久根装了 per-boot kmsg→UFS 落盘钩子，之后被测的坏内核从「~1 min 一次重启」变成「稳定 400 s」——钩子（持续写盘 + /dev/kmsg 读者）很可能改变了时序，使被测行为消失。教训：①不稳设备上，取证装置本身是变量，尽量用最小侵入读取（如 SSH 读 dmesg），改动前后各取样本；②间歇性故障单次"没复现"无统计意义，须多轮/长时窗；③主机 ModemManager 会独占 /dev/ttyACM*（EBUSY）并污染采集，USB-NCM SSH 更可靠。


## Memory - 2026-10-03

设备实验脚本禁忌（y700-elden 2026-10-03 审计）：①不要把 reboot/fastboot boot 等副作用与长轮询写进同一条 bash 命令——harness 会按超时杀死整条命令（"Command aborted"），副作用是否发出、fastboot boot 是否传输中途被打断都无法判定。一条命令只做一件事，轮询内部自加 timeout 自限。②设备持久槽/回退内核要用 kernel payload 指纹确认（解 boot 镜像 gzip 内核流算 sha256），不能信文件名：vk30–vk40 镜像共用同一 uname（dirty 构建），实测 boot_b 烧的其实是 vk40 内核，导致复位后回退到被测版本，使"复位次数/复位后行为"的跨版本归因失效。per-uname 的 kmsg 日志才能可靠做版本归属。
