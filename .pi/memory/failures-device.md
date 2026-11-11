# y700-elden — 设备/运行时/容器类失败与洞察（94 条）。2026-11-09 从全局 failures.md 下沉，原文未改；与 failures-kernel.md 互补，检索用 `mem -t project <关键词>`。
---
用官方 OTA 灌 Waydroid 镜像的四个连环坑：① waydroid 自带下载器不支持断点续传，SourceForge 一停摆就把半截文件送校验（Downloaded system image hash doesn't match）；② SourceForge WAF 对 aria2 默认 UA 和浏览器 UA 都回 403，只有 --user-agent="Python-urllib/3.13" 放行；③ OTA JSON 的 id 是 zip 的 sha256，不是解包后 img 的，照 img 校验必然「损坏」；④ 正确离线灌法：img 放 /etc/waydroid-extra/images/ 再 `waydroid init -f`，会彻底跳过 OTA。解法=aria2c(-c -x16 + 外层重试 + 清代理变量 + Python UA) 自校 zip 后解包再离线灌。
---
Alpine apk 坑：设备 /etc/apk/world 若残留「未安装」的包（如掉电中断的 epiphany），任何 apk add 都会去补它整条依赖树（实测 151 包）→ 先从 world 摘掉。设备侧 apk 走 USB+代理很慢（单次上百 MB 易超时）→ 大包一律走主机侧 qemu-aarch64 免 sudo 构建流程。
---
Alpine 的 PAM 配置在 /usr/lib/pam.d/（base-auth/base-account/base-password/base-session），/etc/pam.d/ 下只有少数条目；greetd 的 /etc/pam.d/greetd 用 include base-*，但这些 base-* 其实来自 linux-pam 包把文件装到 /usr/lib/pam.d/——设备上缺的是 /etc/pam.d 侧的条目，不是 pam_elogind.so（/lib/security/pam_elogind.so 不存在，elogind 提供的是 /usr/lib/security/pam_elogind.so）。
---
USB ACM 串口（ttyGS0，宿主 /dev/ttyACM0）抓不到进桌面之前的早期 userspace 输出——它到 ~8.8s（usb-gadget 起来）才注册，且非 tty0 console。正确取证姿势 = 读 VT 屏幕缓冲 `cat /dev/vcsN`（本轮 vcs1 保留了进桌面前最后 47 行），据此才定位到开机刷屏真因。
---
busybox applet 名单不能靠抄设备上的 /bin 符号链接生成——设备上 mount/mountpoint/ip 等实际来自 util-linux/iproute2 而非 busybox，抄表既漏 busybox 真项也混入假项（如 blkid、mountpoint 在 busybox 里根本没有）。权威做法：用 `qemu-aarch64 busybox --list`（本机有 /usr/bin/qemu-aarch64）生成名单（本机 busybox 1.38 = 282 项），并让自检脚本校验名单与实际二进制一致。另注意建链接时要防御：若 `busybox` 自身在名单里，会把 2MB 真二进制替换成自指链接、ramdisk 缩到 12K。
---
向受控平板（Alpine rootfs，shell 解析能力弱）投递脚本的正确姿势：先 `scp` 到设备 `/tmp`，再 `sh /tmp/x.sh`；不要把长 inline 单引号命令塞进 ssh 一行——单引号地狱会静默失败（本次曾出现 `can't open '/tmp/x.sh': No such file or directory` 与命令被 aborted）。 — Failed: inline 长命令在设备侧解析失败
---
单变量试验纪律（用户反复重申）：多变量连续失败时不要继续盲试，应停手归档、把口径更正写进文档、列出「已排除的假设」与「已确证的事实」，再让用户决定下一步；旧记忆里被推翻的结论要标注 superseded 与日期，而不是在新文档里并列矛盾说法。用户会主动在设备侧纠正助手的错误归因，期望据此撤回旧结论。 — Failed: 多次多变量盲试踩坑
---
busybox `pgrep -x NAME` 恒假阴性（argv[0] 带路径，-x 不匹配）——仓库里 dpms-watch.sh、net-up-manual.sh、waydroid-proxy-setup.sh 里的 `pgrep -x`/`pkill -x` 守卫实际全是空操作。改判据用 `ps -eo comm | grep -cx NAME`（dpms-watch.sh 注释里已记此坑）。 — Failed: AI 脚本在 Alpine/busybox 上的高频隐性 bug
---
busybox 的 `pgrep -x NAME` 在设备上是恒假阴性（argv[0] 是 `/sbin/udevd` 等带路径全串，`-x` 精确匹配不成立）⇒ 所有靠 `pgrep -x` 做的进程守卫都是空操作（仓库里 net-up-manual.sh、waydroid-proxy-setup.sh、dpms-watch.sh 都中）。正确做法：`ps -eo comm | grep -cx NAME` 或直接读 /proc/<pid>/comm；装 procps-ng（GNU pgrep）后 `-x` 语义自愈。busybox 的 pgrep/pkill 位于 /usr/bin/pgrep -> /bin/busybox。 — Failed: 空操作守卫会让「服务已在跑」检测失效，导致重复拉起或漏杀
---
Alpine 上 AI 写的远程脚本常因 busybox ash 报 `syntax error: unexpected "("`，根因是 `[[ ]]`、`$'...'`、数组、`set -o pipefail`、`date -d`、`stat -c` 等 bashism。部署到设备的脚本（start-desktop.sh / net-up.sh / bt-up.sh / time-sync.sh / ath12k-retry.sh / charge-watch.sh）shebang 全是 `#!/bin/sh` 却各含 1–3 处 bashism。解法不是换发行版——bash 已在 rootfs world 里，修脚本或补装包（coreutils/findutils/grep/gawk/curl/jq/xz）即可，装后 GNU 工具会 shadow busybox（init 同 PATH），必须实测重启能起来。 — Failed: 多变量盲试成本高；根因是脚本语言选择而非发行版
---
Alpine 的 openrc 包**不含 `/sbin/openrc-shutdown`**（只带 openrc/openrc-run/rc-service/rc-update/rc-sstat/service/start-stop-daemon/supervise-daemon/rc-sstat）；Alpine 关机链靠 /etc/inittab + busybox init 收信号，所以 G1-25 假关机只有换 PID1 到 busybox init（→ OpenRC）才能根治。
---
busybox `pgrep -x NAME` 在设备上恒假阴性（按 argv[0] 全串匹配，实际 argv[0] 是 `/sbin/udevd` 等带路径）；我们脚本里的 `pgrep -x` 守卫全是空操作。修法：装 procps-ng 让 `-x` 语义自愈，或改用 `ps -eo comm | grep -cx NAME` / 扫 /proc/<pid>/comm。设备当初 /usr/bin/pgrep -> /bin/busybox。
---
装 GNU 工具（coreutils/findutils/grep/sed/gawk）到 Alpine 设备会 **shadow busybox**（init 与 ssh 上下文同 PATH `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`）⇒ 每次装完必须实测重启能否起来（本次 ×2 通过，SSH ~30s 恢复、桌面/会话/服务全绿），不能只验证命令跑通。
---
ede 设备（Alpine rootfs）上部署/执行的脚本必须 POSIX sh 兼容：`[[ ]]`、`$'...'`、数组、`set -o pipefail`、`date -d`、`stat -c` 等 bashism 在 busybox ash 下会直接报 `syntax error: unexpected "("`。设备上 bash 已存在（rootfs world），修法 = 修脚本或补装包，而非换发行版。部署脚本前先 `sh -n`。
---
装 GNU coreutils/findutils/grep/sed 后会 shadow busybox（init 的 PATH 也把 /usr/bin 排在 /bin 前）⇒ 必须实测重启回归验证，不能只验证命令本身。
---
Alpine 侧 openrc 0.63.2 + 82 个 /etc/init.d 服务 + 全部 *-openrc 包已装齐，但 /etc/runlevels/* 全空、rc-update show 无输出、PID1 = 自研 /bin/sh /init ⇒ 三套服务管理并存、一套在跑。启用 OpenRC 后可解 8 类用户态 bug，无需换发行版。唯一结构性收益：/sbin/openrc-shutdown 不在 alpine 的 openrc 包里（openrc 包只带 openrc/rc-service/rc-update/openrc-run/start-stop-daemon/supervise-daemon），关机链需换 PID1 才能根治。
---
Alpine 设备上 busybox `pgrep -x NAME` / `pkill -x NAME` 恒假阴性：busybox 匹配的是 argv[0] 全串（进程以 `/sbin/udevd` 启动时 `-x udevd` 不成立），而 GNU procps 的 -x 匹配 comm（语义相反）。后果：设备脚本里所有 `pgrep -x` 守卫都是空操作。修法：apk 装 procps-ng（装后 -x 语义自愈），或改用 `ps -eo comm | grep -qx NAME`；kill 用 `ps -eo pid,comm | awk '$2=="NAME"{print $1}' | xargs kill`。涉及脚本：scripts/net-up-manual.sh、scripts/waydroid-proxy-setup.sh、scripts/dpms-watch.sh 等。
---
设备侧（Alpine/busybox）`depmod` 在 /lib/modules/<UTS>/ 缺 modules.order / modules.builtin 时会刷 WARNING（could not open modules.order / modules.builtin），属无害噪音；只要 modules.dep 生成成功，modprobe 仍可用（实测 rc=0 正常加载）。 — Failed: depmod 的一串 WARNING 容易被当成模块部署失败。
---
评估「安卓容器方案要自编多少」时的分账结论（2026-10-06）：主路线 Waydroid(R1) 需自编比例约 15%，Android 侧必需自编模块仅 3 个（约 15 个 .so），已完成 2 个（bionic Mesa、sensors HAL），剩余只有「偶发重编 Mesa」+「可选的一次 vendorimage」。真正的 G2 上限因素（GMS/Play Integrity/Widevine arm64 L3、上行/代理）基本都不是编译问题。
---
「要不要自编更新的 Android 版本」结论：没必要——换版本不是编译问题，社区已有现成镜像 WayDroid-ATV 的 lineage-21/22.2/23.2（Android 14/15/16）release，换版本只需换镜像（~2GB 下载）而非重编 AOSP；自编只在「arm64 + 本机定制」时才需要，且不解决 G2 两个真瓶颈（Widevine arm64 L3 缺库、GMS/PI 认证），还可能加大风控难度。Waydroid 官方主线仍是 LOS20/A13，PI 绕过先例最多。
---
C0「真 Android 对照取证」= 在 a 槽仍为 stock+root 的单元（U1 HA2ABH62）上采集原厂系统基线（getprop 全量 / dmsys media.drm Widevine 级别 / 7 颗传感器 30s 采样 CSV / 5 个目标 App 流程录屏），作为将来 Waydroid 容器等价性判定的「标准答案」；采集器 scripts/c0-android-evidence.sh 就绪，输出 backup/<SN>-<容量档>/c0-baseline/（git 不纳管）。一旦 a 槽被覆盖即不可复得（GAPS Q5）。
---
取数/抓图类主机侧工作用 magick/convert/ffmpeg 可用（本机实测三工具都在）；设备侧抓帧产物可 scp 回主机再用这些工具缩略查看，比反复 ssh 传大文件省事。 — Failed: 会话中抓帧回传主机的常用路径
---
SSH 远程后台启动 GUI 程序（如 `nohup ... snapshot &`）会挂住 SSH 通道，必须用 `setsid`/显式重定向 + disown，或干脆避免在 ssh 里拉 GUI——设备侧启动桌面 app 的正确姿势是走已有会话的 DBus/Wayland 环境变量并在一条独立命令里 `setsid nohup ... </dev/null >log 2>&1 &`。 — Failed: 会话中 ssh 后台启动 snapshot 卡住通道
---
Alpine 相机前端 app 可从仓库装（community）：megapixels 2.1.0、snapshot 50.0（GNOME）、plasma-camera 2.1.1；`libcamera-gstreamer` 提供 libcamerasrc（需另装 gstreamer-tools 才有 gst-inspect-1.0）。`cam` 输出 ABGR8888 即软件 ISP 已完成去马赛克。
---
本机（xuqianhui1001）设备侧 SSH 通路：**优先用有线 USB-NCM**（用户 2026-10-07 明确「ssh 用有线，无线每次 IP 会变动」）。但 USB-NCM 主机侧 IP 可能不是固定的 192.168.7.2——实测出现过 enx021e5eede102 = 192.168.7.9/24，此时 ssh root@192.168.7.1 会 No route to host，需先 `ip -br a` 确认当前 enx 名与主机地址。
---
Alpine 3.24 无 /etc/bash.bashrc——bash 系统级启动文件只有 /etc/profile.d/*.sh（由 /etc/profile 的 for 循环 source）。关键行为差异：交互式 SSH（ssh user@host）触发 login shell → source /etc/profile → 执行 profile.d；非交互式命令执行（ssh user@host 'cmd' 或 ssh -T）不触发 login shell → profile.d 不执行。要让非 login SSH 也拿到环境，需写入 ~/.bashrc（交互式非 login）或 ~/.bash_profile（login），Alpine 默认两者都不存在需自建。
---
本 Alpine (v3.24) 的 OpenSSH sshd 不支持 sshd_config.d/*.conf 中的 `UsePAM` 选项（报 Unsupported option UsePAM），且 restart 会因「already running」失败——需 HUP 信号（`kill -HUP $(pgrep sshd)`）而非 OpenRC restart。PermitUserEnvironment 单独可用。
---
设备侧 `pkill -f <模式>` 会匹配到执行该命令的远程 shell 自身（命令行含模式串）→ 自杀、无输出。改用 `pkill -x` 或精确 PID。
---
远程 SSH 会话里 `pkill -f PATTERN` 会**自匹配杀死执行 shell 本身**（因为命令行字符串包含 PATTERN）→ 无输出、连接断。正确做法：用 `pkill -x NAME`（精确匹配进程名）或 `kill $(pidof NAME)`；若必须用 -f，加 `--older 1` 或 grep -v 排除自身。本机实测：`pkill -f monitor-sensor` 通过 SSH 执行时杀死了 zsh 自身（命令行含该串），导致远程命令无输出。 — Failed: Agent 在设备侧远程 shell 里用 pkill -f 杀 monitor-sensor，结果杀死了执行命令的 zsh 进程本身，导致连续两次远程命令返回空输出。
---
远程 SSH 里 `pkill -f PATTERN`（如 `pkill -f monitor-sensor`）会匹配到**执行该命令的远程 shell 自身**（其 argv 含该模式串）→ 把 shell 自己杀掉 → 后续命令无输出、看似「无响应」。正确做法：用 `pkill -x NAME`（精确匹配进程名，不含路径），或直接 `kill $(pgrep -x NAME)`。 — Failed: 在设备侧用 pkill -f 清理后台采样脚本时，远程 shell 自匹配自杀，连续两轮无任何输出，误判为命令未执行
---
多行脚本经 SSH 传输的可靠做法（反复踩坑 2026-10-09）：设备侧 shell = zsh/ash，`ssh root@... '多行带引号脚本'` 会被远端压平（grep 吞后续参数、sed 的 `s/` 被截、set -e + grep 非零退出码中断）。可靠做法 = ① 本地写好脚本文件 → `scp` 到设备 → `ssh root@... 'sh /tmp/script.sh'`；或 ② 本地 heredoc 喂给远端 cat：`cat <<'EOF' | ssh root@... 'cat > /tmp/x.sh && sh /tmp/x.sh'`。禁止把含引号/管道/多行逻辑的命令塞进单行 ssh 参数。
---
pkill -f 匹配到发起命令自身（bash -c 的 cmdline 含搜索串）→ 自杀。设备侧或本地脚本中 pkill -f 一律用 `[g]ui-freeze` 括号法，或改用 `pkill -x <精确进程名>`。本项目内 agent-browser 的 bash 守卫已用同样技巧绕开。 — Failed: pkill -f "gui-freeze-watch" killed the bash process running the pkill command itself because the cmdline contained the search string
---
pkill -f / pgrep -f 自杀（本会话 3+ 次 exit 137/143）：模式字符串出现在自身命令行（如 `pkill -f "device-lock"` 匹配到执行它的 ssh/脚本本身），所有分支必须用字符组 `[d]evice-lock` + `grep -vw $$` 排除自身；更安全的做法是先 `pgrep -f '[d]evice-lock' | grep -vw $$` 列 PID 确认再逐条 kill。 — Failed: agent 用 pkill -f "gui-stress" / pkill -f "device-lock" 三次打死自己的 ssh 会话（exit 143/137），导致设备侧清理不完整（屏幕反复亮暗 + foot 刷 tick 留给用户）
---
Alpine aarch64 设备侧无 `glmark2` 包（apk 报 no such package）。GPU 快测可用 `mesa-demos`（已装，9.0.0-r6）里的 `kmscube`（DRM 直驱，无需 Wayland/X11，SSH 下可跑）和 `es2gears`。`es2_info` 需要 display 环境（WAYLAND_DISPLAY 或 X11 $DISPLAY），纯 SSH 下报 `couldn't open display`。
---
设备侧 shell = zsh（非 ash/bash）：脚本里用 `[[ ]]`/`==`/`$'...'` 等 bashism 会直接报 `zsh:2: == not found` 并 rc=1。后果：agent 的 inline ssh 命令如果含 bashism，在设备上静默失败（rc=1 但 stderr 被吞）。修法：部署脚本首行加 `#!/bin/bash`（bash 在 world 里已装），或 inline 命令用 `sh -c '...'` 包裹。另：ssh 命令里用 `echo === xxx ===` 也会触发 zsh 的 `== not found`（因为 `===` 被当测试运算符）——用 `echo "--- xxx ---"` 代替。
---
Waydroid 容器启动假状态（2026-10-11 实测）：`waydroid container start` 的 python 进程（PID 12846 等）残留时，`lxc-info` 报 RUNNING 但 `waydroid status` 报 STOPPED、后续 `waydroid container start` 报「Container service is already running」却实际无容器。解法 = `kill <残留PID>` + `waydroid session stop` + 再 `nohup waydroid container start &`。不要用 `pkill -f waydroid`（匹配到自己的 ssh 命令行）。
---
设备侧图形基准 `es2gears_wayland` 用 `| head` 截断输出会触发 **SIGPIPE**（rc=124 或 1），看起来像程序失败，实际上程序完全正常（EGL_VERSION=1.5 + 正常渲帧）。判据：看 stdout 是否已含 `EGL_VERSION` / frames 行；去掉 `| head` 单独跑则 rc=0。同类：`es2_info` 报 `couldn't open display (null)` 是因为没设 WAYLAND_DISPLAY，与 es2gears 无关。
---
C4 Waydroid 传感器 HAL 上机结论（2026-10-11）：自编 UDP HIDL 1.0 `android.hardware.sensors@1.0-service.waydroid`（经 overlay 覆盖到容器 /vendor）导致 Android framework 的 `sensorservice` 永远不注册（logcat `Service sensorservice didn't start` → bootanim 卡死、`sys.boot_completed` 空）。`lshal` 显示 HAL TIMED_OUT（binder interfaceChain 无响应），`configureRpcThreadpool(1→4)` 后 lshal 变 alive 但 sensorservice 仍起不来。对照：镜像原版 stub HAL → sensorservice 正常、boot_completed=1。根因 = framework SensorService 对 HIDL 1.0 ISensors 的 `getSensorsList`/`activate`/`batch`/`poll` 契约有严格期望，UDP 实现不满足。已回退到可用态（mount_overlays=False）. — Failed: 自定义 HIDL HAL 不满足 framework SensorService 的 binder RPC 契约，导致框架卡 boot
---
Waydroid 自编 UDP HAL 的 `configureRpcThreadpool(1→4)` 修复：使 HAL 对 `lshal` 查询响应（不再 TIMED_OUT），但框架 `SensorService` 仍然卡住（`Service sensorservice didn't start`）——根因不是线程池而是 **HIDL 1.0 注册架构本身与容器 framework 不兼容**（VINTF 声明了 `@1.0::ISensors` 但 `sensor_privacy` 依赖的 `ISensorPrivacyManager` 在 VINTF 中找不到）。原版 stub + `stub_sensors_hal=1` 则 sensorservice 正常、boot_completed=1。结论：overlay 方式替换 HAL 不可行（framework×HAL 版本/接口链不匹配），必须走 `waydroid-sensord`（libgbinder 从宿主侧注册）或对齐上游完整注册路径。 — Failed: 自编 HAL overlay 方式替换 /vendor HAL → 框架卡 bootanim 永久不完成
---
容器内应用播音频但宿主无声时的定位手段（2026-10-11 实测有效）：① 宿主侧 `pactl list sink-inputs` / `pactl list clients` 看是否有来自容器的 client 出现（Waydroid 走宿主 PulseWire，容器播放应产生 sink-input）；② Android 侧 `dumpsys media.audio_flinger` 看输出线程 Standby/设备/格式（Standby: yes = 从未真正推流）；③ `dumpsys audio` 看 stream volume 与 devices；④ `logcat` grep ActivityTaskManager 确认播放 intent 到没到 app、app 是否真的 start 播放（如 Eleven 的 AudioPreviewActivity 起来了不代表有输出）；⑤ 不要指望 strace HAL——Android HAL 是 binder 驱动的多进程，strace attach 会被立刻 detach（实测输出仅 39 行）。 — Failed: 跨容器音频排查需要分层证据（宿主 sink-input / AF / logcat），单看 Android 进程存活会误判
---
`/var/lib/waydroid/data/` 与 `/var/lib/waydroid/data/media/0` 在宿主侧可能不存在——Waydroid 通过 lxc.mount.entry rbind 把 `~/.local/share/waydroid/data` 挂进容器 `/data`（config_session 里可见）。宿主侧要放测试文件进 Android /sdcard 应写 `~/.local/share/waydroid/data/media/0/`（宿主 uid 1023/permissions 1023:1023），不是 /var/lib/waydroid/data。 — Failed: 宿主/容器数据目录映射与直觉路径不同，往错路径放测试文件会查无结果
---
Waydroid 容器内 `cmd content query/insert --uri content://media/...` 报 `Could not find provider: media`（MediaProvider 未起/超时 `timeout publishing content providers`）；读设置可走 `content query --uri content://settings/system`（如 volume_alarm=6、volume_music=5）。容器内 /system/media 不存在，铃声/闹钟素材在 `/system/product/media/audio/{alarms,notifications,ringtones}`（Alarm_Beep_01.ogg / Timer.ogg / Neon.ogg 等）。
---
Waydroid 容器音频「HAL 通路通≠闹钟/铃声有声」分层事实（2026-10-11 实测）：① AudioTrack→HAL→snd_pcm_open("pulse")→PULSE_RUNTIME_PATH→host PipeWire 这条**输出通路本身正常**（app_process TestAudio 出 frames=211200、pactl 看到 sink-input s16le 2ch 48kHz）。② 但闹钟/铃声走的是 **MediaPlayer/NuPlayer→AudioTrack**，NuPlayer 在解码音频文件（ogg/mp3/aac）时需要 MediaCodec；如果 codec 列表为空或 OMX 被移除，NuPlayer 报 `OMX service is not available` → Ringtone 创建成功但不出声。③ 去掉 vendor VINTF 里的 OMX 声明（via LXC bind-mount manifest-nomx.xml）能解 MediaProvider 卡 boot，但**会打断 MediaPlayer 的音频解码路径**——不是解法，是把 A 阻塞换成了 B 阻塞。④ 正确修法 = 要么提供 `android.hardware.media.omx@1.0-service` 二进制（本镜像未编译、manifest 声明了但 binary 不在），要么确保 `debug.stagefright.ccodec` 让 NuPlayer 纯走 C2（需 C2 覆盖全部音频格式 + MediaPlayer 不回退 OMX）。 — Failed: 移除 OMX 解锁了 MediaProvider boot，但 alarm/ringtone 仍无声——MediaPlayer 的音频解码依赖 OMX 或 C2，不是 HAL 输出通路问题
---
Waydroid Codec2 冷启动枚举时序坑（2026-10-11 实测）：容器刚启动时 `MediaCodecList` 返回 **0 个 codec**（`total codecs=0`），即使 `media.swcodec` 进程已 running、`lshal` 已注册 `IComponentStore/software`。原因 = `Codec2InfoBuilder::build()` 调 `Codec2Client::ListComponents()` 时 swcodec 尚未完成全部组件注册。解法 = 任何进程触发一次 codec 查询后（如 `ListCodecs.java` via app_process），后续进程能看到 **53 个 codec**（含 c2.android.aac/mp3/amrnb/amrwb/opus/flac/vorbis + 视频）。判据：`logcat -s Codec2InfoBuilder` 出现 `adding type 'audio/mp4a-latm'` 行即枚举完成。这是 cold-start 竞态，不是缺组件。 — Failed: Codec2Client::ListComponents() 在 swcodec 完成注册前返回空列表，导致 MediaPlayer 无法解析音频 MIME
---
Waydroid 容器 vendor.img 直接 mount 改写 → ENOSPC（2026-10-11）：`mount -o loop vendor.img /mnt/vendorimg` 后 `df` 显示 98MB used / 0 avail（ext4 镜像按原始大小分配，无空闲块）。`cp` 进去立即报 `[Errno 28] No space left on device`，且 Python 的 `open('w')` 先 truncate 原文件为 0 再写失败 → manifest.xml 被清空。教训：**任何想覆盖容器内 vendor 文件的场景，一律走 LXC bind-mount 从主机路径覆盖，不要试图写 vendor.img**（除非有 root 重打包流程）。若误 truncate 了镜像内文件，立即 umount + 从备份 `cp` 恢复 + `e2fsck` 校验。 — Failed: vendor.img 是只读预分配 ext4 镜像（235MB 已满），不可在线扩写
---
Waydroid Codec2 `start failed`（ENOMEM）排查路径（2026-10-11）：codec list 53 个（configure OK）但全部 `start failed` → 最初怀疑 binder/权限/ashmem → 实际 = 容器内 `/dev/dma_heap` 不存在（LXC 未 bind-mount）→ swcodec 分配 C2 buffer 时 ENOMEM。判据：`ls /dev/dma_heap/` 在容器内为空或不存在；主机侧 `system_heap` 模块未加载时 `/dev/dma_heap/` 整体不存在（不是空目录）。修复 = 主机 `modprobe system_heap`（**绝不 modprobe cma_heap**）+ 确认 `/dev/dma_heap/system` 字符设备存在 + LXC config 加 bind-mount 条目。 — Failed: 容器 LXC 配置未透传 /dev/dma_heap/system 给 swcodec 进程
---
Waydroid 容器内 app_process 测试进程被 cgroup OOM killer 杀掉（2026-10-11）：容器 cgroup 内存上限有限，`app_process` 加载 framework + MediaCodec + HAL 后超限额 → 直接 Killed（rc=137），日志里表现为 `dmesg` 无 panic、进程直接消失、`Killed` 输出。判据：TestRing/TestRing2 跑一次即死但 TestAudio（纯 AudioTrack 不碰 MediaCodec）不死。解法 = 精简测试用例或调大容器 cgroup 内存限制（waydroid 的 cgroup 配置在 /sys/fs/cgroup/.../memory.max）。 — Failed: app_process 在 Waydroid 容器内跑完整 MediaPlayer 路径时内存超过容器 cgroup 限制被 OOM kill
---
Waydroid 容器 codec 列表为空的**真正根因**（2026-10-11 会话最终定位，修正之前「时序竞态」误判）：waydroid Python 代码 `/usr/lib/waydroid/tools/helpers/lxc.py:272` 硬编码 `debug.stagefright.ccodec=0`（完全禁用 Codec2）→ `Codec2InfoBuilder` 根本不调 `ListComponents()` → codec 列表恒 0。正确修法 = `waydroid prop set debug.stagefright.ccodec 4`（写 waydroid.cfg [properties]，**不是** waydroid.prop 那个运行时再生文件）。改后 codecs=53 立即生效。之前试过的「restart media 重新枚举」hack 在 ccodec=4 后完全不需要（已 revert blank_screen.rc 里的 exec restart 行）。诊断顺序应为：先 `getprop debug.stagefright.ccodec` 看是否被禁，再查 timing。 — Failed: 项目 memory 中既有条目「Waydroid 容器 codec 列表重启后为空的竞态」把根因归为 swcodec 注册时序、建议 restart media hack，但实测 restart 无效、真正的单行修复是 waydroid 源码默认 ccodec=0。该旧条目需读时注意已被本条取代。
---
Waydroid vendor.img（235MB ext4）`mount -o loop` 后 `df` 显示 0 可用 → 任何写操作 ENOSPC → 不能直接改分区镜像。覆盖 vendor 内文件的唯一可行方法 = LXC bind-mount（在 config_nodes 加 `lxc.mount.entry = /root/wd/<src> vendor/<target> none bind,create=file 0 0`）。本项目已用此法覆盖：VINTF manifest（去 OMX hal）、media_codecs XML（OMX→C2 格式）、init rc 文件。overlay 文件存设备 /root/wd/（持久盘），重启自动挂载。
---
Waydroid 容器内 app_process 跑长时测试被 OOM Kill（rc=137）：容器有 cgroup 内存限制，DeskClock 等后台服务已占大头，app_process 起的 Java 进程（尤其 MediaCodec 分配 buffer 时）容易被 OOM killer 杀掉。表现 = 输出 'Killed'、无 logcat 异常。解法 = 测试前先 force-stop 非必需后台 app（org.lineageos.eleven、Firebase 相关）释放内存，或调大容器内存限制。TestRing 连续 3 次被杀后改用 TestCodec（只 configure+start 不实际播放）才成功。 — Failed: container cgroup OOM killing app_process during MediaCodec buffer allocation
---
Waydroid 容器内 `app_process` 测试里 `Uri.fromFile(path)` 触发 `FileUtils.getMediaProviderAppId` NPE（2026-10-11）：app_process 无 Context（`context == null`），MediaPlayer.setDataSource 走 `convertToModernFd → getMediaProviderAppId → context.getPackageManager()` 崩。解法 = 测试代码用 `Uri.parse("file://...")` + try-catch 或改用 `FileInputStream` + `setDataSource(FileDescriptor)` 绕过 MediaProvider 路径。 — Failed: app_process has no Application Context, triggering NPE in Android 13's MediaProvider-aware Uri path
---
Waydroid 容器 `debug.stagefright.ccodec=0` 根因已定位并修复持久化：waydroid Python 代码 `/usr/lib/waydroid/tools/helpers/lxc.py:272` 硬编码 `props.append("debug.stagefright.ccodec=0")`，而 Android 13 的 `Codec2InfoBuilder.cpp` 里 `GetIntProperty("debug.stagefright.ccodec", 4)` case 0 = 跳过全部 Codec2 软件组件（仅 OMX，而本镜像无 OMX）→ codec list=0。修复 = `waydroid prop set debug.stagefright.ccodec 4`（写 waydroid.cfg [properties]，重启 session 生效）；源头修复 = 改 lxc.py 或 waydroid_base.prop。验证判据 = codec list 53 个 + TestCodec 各 audio MIME start OK + 闹钟出声（宿主 pactl 出现 sink-input s16le 2ch 48000Hz）。 — Failed: waydroid 上游硬编码 ccodec=0 导致 Codec2 全禁，且无 OMX 服务时无任何解码器可用；该 prop 值不写入 waydroid.cfg 默认段、只靠运行时注入，极难追踪
---
`pgrep -f`/`pkill -f` 会匹配到自己所在的 shell 命令行（整条命令文本含目标模式），导致把自身的 bash -c 打死、命令半截没跑（2026-10-11 本会话再次踩到：`pgrep -f "waydroid session start"` 自杀）。规则：模式每个分支都写成字符组形式（`[w]aydroid`、`ttyACM[0]`），同一行不再出现未加括号的字面量，先 `pgrep -af` 只列不杀。
---
设备侧 `scripts/q24-s123-run.sh` 曾在设备（dash/busybox sh）上跑出 `Syntax error: "(" unexpected`（行 90 的 `case ... in *active=(true*)` 与 `$((...))`）——部署到设备的脚本必须 POSIX sh 兼容，`case` 模式里别带 `(`、别用 bash 专属展开；改写完先用 `sh -n` / 在设备上 `sh script 2>&1` 冒烟。
---
设备侧会话总线：以 root SSH 直连进用户会话总线会 `Error connecting: The connection is closed`；必须 `setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=$DB` 才能调 org.gnome.ScreenSaver / gsd 等用户会话 D-Bus 服务。
---
`org.gnome.ScreenSaver` 的 `Active` 是方法 `GetActive`（返回 `(true,)`/`(false,)`），不是属性——`busybox`/gdbus 里按属性读会报 `Error: GDBus.Error:org.freedesktop.DBus.Error.InvalidArgs: No such property "Active" (According to introspection data, you need to pass 'ss')`。
---
设备侧 `qcom_camss`/`wl2868c`/`gc08a8`/`s5kjns`/`camcc_sm8750` 常被 wireplumber 持有 /dev/media0 与 /dev/video0 的 fd，rmmod 报 in use——`killall wireplumber` 后即可全部卸载（可达 v4l2_cci/camcc 均 0 的干净态）。设备无 systemctl（Alpine/OpenRC）。
---
设备侧脚本部署注意 shell 差异：设备 root shell 曾是 zsh（`==` 报 `zsh:2: == not found`），脚本内 `LIB=...; case ... in *active=(true*)` 这类 bash/ash 语法在 sh（dash/busybox ash）下报 `Syntax error: "(" unexpected`。写设备脚本要么严格 POSIX sh，要么显式 bash 调用。fabric 的 pi.edit 报 "Could not find edits[1] ... oldText must match exactly" 时是 old_text 与实际文件不匹配（含空白），需重新读文件再改。
---
设备侧滚动执行器（把 host 脚本按行喂给设备 shell）会让 `case`/`if`/函数定义跨多行/跨语句落在**两个独立 shell**中 ⇒ 报 `Syntax error: "(" unexpected` / `未预期的记号 "("`。规则：写到设备的脚本必须整文件 scp 后 `sh file` 执行，禁止把含 shell 语法的多行块逐行通过 ssh 拼接（本项目 s123/instr 脚本连续踩过）。 — Failed: q24-s123-run.sh 与临时仪表脚本多次因跨行 case 语句被设备 shell 解析失败
---
`pkill -f <pattern>` / `pgrep -f` 会匹配到自己这条 `bash -c "..."` 命令行（命令里含 pattern 文本）从而自杀、命令半截未跑——用户 2026-10-12 明确指出「怀疑 pkill 匹配自己了」。规则：模式每个分支写成字符组（如 driver[-]log、ttyACM[0]、dev[-]stress），同一行不要再出现未加括号的字面量，再 `| grep -vw "$$"` 兜底；顺序 = 先 `pgrep -af` 只列不杀，看清目标再杀。
---
serial-logger.sh（bash while 循环 cat /dev/ttyACM0）被 kill 后会遗留孤儿 `cat` 进程占住 /dev/ttyACM0 ⇒ 后续多读者/停读读者、控制台背压、读数不完整（`Device or resource busy`）。修法 = 脚本内 trap EXIT/INT/TERM 回收子进程；排查命令 `lsof /dev/ttyACM0`。
---
设备侧 apk 装包后报 `N errors; … in N packages` 但只列出已装条目、看不到具体失败——apk-tools 3.0.8 已无 `apk fix --dry-run`（报 unrecognized option 'dry-run'）；查错应看 /var/log/apk.log 尾部 + `apk audit` 或 `apk fix`（不带 dry-run），并确认具体是哪两个包的 trigger 失败（Alpine 上常见是 busybox/desktop-file 类 trigger）。
---
Waydroid 构建树（/mnt/Samsung/waydroid-build）里执行 `mmm` / `lunch` 前必须先 `source build/envsetup.sh` + `source vendor/extra/vendorsetup.sh`（否则报 `lunch: 未找到命令`），且 shebang 里的 `python` 不存在（只有 python3）会报 `env: 'python': No such file or directory`。构建树目录属 root，普通用户往里 mkdir/cp 会 Permission denied，需借 sudo 或改由设备侧/root 操作用户执行。另 `rm` 跨设备重命名会报 EXDEV（树在 /mnt/Samsung 与家目录不同挂载）。 — Failed: 在 /mnt/Samsung/waydroid-build 里直接跑 mmm/lunch 与写文件反复失败：envsetup/vendorsetup 未 source、python 名不存在、目录属 root、跨挂载 EXDEV。
---
Waydroid 容器文件覆盖统一走 LXC bind-mount（`lxc.mount.entry = <宿主文件> vendor/etc/... none bind,create=file 0 0`）——vendor.img 是满盘 ext4，mount -o loop 后 df 显示 0 可用，直接改会 ENOSPC 截零。覆盖文件统一放设备持久盘（如 /root/wd/），脚本要幂等（去重后再写 config_nodes）。
---
Waydroid 构建树 lxc/config 层编辑注意：替换 /vendor/bin/hw 里正在运行的服务二进制前必须先停容器（否则 ETXTBSY / scp Failure）；servicemanager 对未在 /vendor/etc/vintf/manifest 声明的 HAL addService 会返回 -3，需同步 bind-mount vintf fragment 目录。
---
Alpine apk 的「N errors」输出不是本次操作造成的——它累积自历史损坏包状态。本次 `apk add musl-locales musl-locales-lang` 报 '2 errors' 实为 10-11 就损坏的 `fastfetch-bash-completion` / `fastfetch-zsh-completion`。别被 surface 错误误导，用 `apk fix --simulate` 或逐包 reinstall 定位真源。
---
Waydroid build 树（/mnt/Samsung/waydroid-build，530G；~/waydroid-build 是空目录/旧路径）实跑构建流程：`source build/envsetup.sh` → `lunch lineage_waydroid_arm64_only-userdebug` → **必须调 `apply-waydroid-patches`**（vendor/extra/waydroid-patches/vendorsetup.sh 里的 shell 函数，给 wayland-protocols 打 fractional-scale patch、system/vold 打 fuse-disable patch）→ `bash build/soong/soong_ui.bash --make-mode -j$(nproc)`。不调 apply-waydroid-patches 时 hwcomposer 报 `fatal error: 'fractional-scale-v1-client-protocol.h' file not found`。小改（换 vendor 二进制）重编约 4–5 秒（ninja 增量）；全量约 5 分钟（16 核含 swiftshader LLVM 缓存时 ~3 分钟）。
---
主机侧（xuqianhui1001）用 `ssh root@192.168.7.1 "<多行 shell>"` 传多行脚本时，嵌套引号会被外层 bash 解析破坏：报 `未预期的记号 "(" 附近有语法错误` 或远端 `uname: invalid option -- 'e'` / `cat: /proc/versionnecho: No such file or directory`（换行被吞成字面 n）。正确做法 = 把脚本写到本地文件再 `ssh ... 'sh -s' < file`，或 scp 到设备 /tmp 后 `sh /tmp/x.sh`，不要塞 inline 长单引号命令。设备侧 root shell 现为 /bin/bash（曾被误设 zsh）。
---
pi（Play Integrity）的判定位置是 **Waydroid 容器内**，不是在原 Android 槽内——与 a 槽 Android 无关。涉及 G2 身份/DRM 相关结论时必须区分「容器内判定」与「真 Android 判定」，别把两者混为一谈。C3 取证已确认容器内 Widevine 不存在（/vendor/lib/mediadrm 无 libwvhidl.so，仅有 clearkey plugin），Play Integrity 依赖 Widevine L1 故上限前置受限。
---
C0 真机基线里的「Play Integrity 判定」归错了地方（用户 2026-10-13 更正）：PI 的判定对象是 Waydroid 容器，属 G2 的 C3 任务，与真 Android 槽无关；真机槽只提供 Widevine L1/HDCP/getprop 等参考态。
---
C0 真机基线口径收敛（2026-10-13，commit fe08bee）：① Play Integrity 的判定对象 = **Waydroid 容器**（TASKS §2 C3 / reports/c3-identity-drm-20261013.md），C0 真机基线不测 PI——此前 TASKS §2 C0 行、§5 Q5 行、reports/c0-android-baseline-20261011.md §3/§5 曾误写为「C0 内做 PI 判定」；② root 专属项已裁决**不补采**（无不可替代产出：块设备映射已由非 root 的 by-name.txt 120 条覆盖、`dumpsys drm` 实测无服务对象、原厂固件可离线取自 backup/stock-259/、设备独有分区含 /persist 已由 EDL 提取）；③ **/persist 等 21 个设备独有分区早已由 EDL 采集**（backup/HA2EXB0E-16+512/unique/，133MB，EDL 刷机包对这些 filename="" 留空不刷 ⇒ 本机 dump 是唯一副本），adb root 采集与其相比更弱；④ C0 剩余项仅 2 条：30s 传感器 CSV、5 个目标 App 录屏。EDL 提取的证据来源极强（不受 root 限制），不要把 /persist 再列为「root 才能采」。 — Failed: 同一份 TASKS.md 内部自相矛盾（§2 已勾、§4/§6 还挂着），外加 3 份别处文档未同步；check-doctor 只查 vk 版本账，扫不到这类跨节口径漂移
---
设备侧资源提取与上机实验后，用户会主动逐字更正目视结论（如「第二次测试的马达是有工作的」「那版有背光但没有声音和马达」）——期望 agent 立即按操作者实际观察修正台账/报告里的版本对照表，不要沿用 agent 侧脚本读数或自己的乐观措辞。
---
P2b 上 modetest 强制设模式（crtc enable=1 active=1 mode 1904x3040@120）会导致整机硬挂（有背光、CPU/SSH 死、USB gadget 仍在枚举）。此时串口 SysRq-b 生效：通过 /dev/ttyACM0 发 BREAK+'h'+'b' 可让设备自行重启回 boot_b，无需用户物理 POR（PITFALLS 经验）。
---
设备侧 tar 流式抢救资产时，ssh 非登录 shell 的 cwd 通常是 /root 而非 /，`tar -cf - usr/local/sbin ...`（相对路径）会得到 22 字节空包。必须用绝对路径 `tar -P -cf - /usr/local/sbin ...`。抢救验证看解压后 sha 与设备侧一致。
---
设备侧资产流式抢救配方：`ssh root@<ll> 'tar -C / -cf - <abs paths> | zstd'` → 主机解压并 sha 对账。坑：ssh 非登录 shell 的 cwd 通常是 /root 而非 /，tar 必须用绝对路径并 `-C /`（相对路径会产出 22 字节空包）。比对设备侧原始 tar 的 sha 与主机解压后内容 sha 确认无损。
---
TASKS/README.md 与 INDEX.md 里引用的 q24/q28 脚本指针已失效（MIGRATION-LOST）：scripts/q24-rebuild-arms.sh、scripts/q28-devprobe2.sh、scripts/q28-devprobe.sh 均 MISSING；现存的只有 q28-devprobe.sh / q28-devprobe2.sh / q28-watchdog.sh 三个（部分在 reports 里被引用的名字对不上磁盘）。另有 scripts/eldroid-sensord、envpass-provision.sh、extract-ikconfig、sensor-send-termux.sh MISSING。审计脚本指针悬空时应按 MIGRATION-LOST 标记并登记 versions/migration-gaps-2026-10-17.tsv，别当成真死链去修。
---
设备侧 python3 无 numpy（`ModuleNotFoundError: No module named 'numpy'`），主机侧分析相机 RAW/帧 bin 时不要用 numpy；本机 python3 有 PIL 可用。字节流解析用纯 python（struct/statistics）即可，本次 3840 万字节的帧解析用纯 python 也只要几秒。
---
设备侧相机 RAW「首帧全暗」不能判链路坏：sensor AGC 需若干帧收敛，后摄长采到 ~300 帧后 p50 从 16 升到 ~37 才说明在收敛；判真实出流只看 STREAMON rc 与 bytesused 字节数。用 `test_pattern=2`（Color bars，mean≈123）能立刻区分「传感器→CSID 通路坏」与「没光/曝光问题」。
---
Alpine 设备（平板）在校园网下抓 APKINDEX 会拿到 HTML 重定向页（`<html><head><title>redirecting to http://202.141.180.1</title>`，414 字节，file 识别为 HTML document），apk 报 'file format is invalid or inconsistent' + 大量 no such package——是上游劫持/门户重定向，不是镜像损坏。判据 = `head -c 200 /tmp/APKINDEX` 或 `file`。绕法：用 https 而非 http（curl https 镜像 200），或给 apk 显式加 https 源；不要凭报错就去换镜像。
---
Alpine 设备时钟停在 1970 会让所有 HTTPS 报 curl rc=60（证书未生效），表现为「网络全挂/镜像不可用」，而 HTTP 劫持页仍 200。排查设备取网失败先看 `date`，再责怪代理/镜像；同时校园网会劫持 HTTP（把 APKINDEX 换成重定向 HTML，apk 报 'file format is invalid or inconsistent'）⇒ 设备侧 apk 必须走 HTTPS 或主机中继。
---
Alpine 包名与 Debian 不同：libcamera/meson 的 `yaml-0.1` 依赖在 Alpine 是 `yaml-dev`（不是 libyaml-dev），Python 的 `py3-ply`/`py3-jinja2` 需单独装，否则 meson 配置阶段报 `ModuleNotFoundError: No module named 'ply'`。装包前先 `apk search`。
---
`ssh -R 7890:...` 到设备会报 'remote port forwarding failed for listen port 7890'（设备侧已有监听/权限限制）；改用主机侧 python 小 TCP 中继绑 0.0.0.0:17890 → 127.0.0.1:7890，设备再把这个地址当 HTTP 代理即可通（实测 clash_http=200 / relay_local=200，但设备 curl 走它时若时钟/CA 不对仍会 000/60）。
---
Alpine 设备上编译 libcamera 时，meson 的 Python 模块缺失（ModuleNotFoundError: No module named 'ply'）需装 py3-ply/py3-jinja2/py3-yaml；但 Alpine latest-stable 的 APKINDEX 可能是 JS 重定向的 HTML（`file format is invalid or inconsistent` / 文件头 `<html><head><title>redirecting to http://...`）⇒ apk update 失败、包名查不到。判据：`head -c 200 /tmp/idxtest` 看是否 HTML；先修设备系统时间（1970 → 真实时间）再重试，HTTPS 证书校验 rc=60 的最常见根因就是时钟错。 — Failed: 设备 1970 年时钟导致 HTTPS 全部 rc=60；校园网劫持 HTTP 且封 443
---
libcamera 主机侧叉编（aarch64/Ubuntu → 设备 Alpine musl）走通的最小集：① 交叉工具链 = aarch64-linux-musl-cross（108MB tgz，GCC 11.2.1）；② sysroot = Alpine rootfs 拷贝（`/usr/include` 94M + `/usr/lib` 1.8G），pkg-config 指向它；③ meson cross file 里 `wayland-scanner` / `glslangValidator` 必须用**宿主版**（`/usr/bin/...`）否则会拿 aarch64 二进制执行失败；④ 依赖 threads/dl/yaml-0.1 必须都在 sysroot；⑤ 编译只需 9.5s（14700KF 上 `real 0m9.458s`），比在平板上快一个数量级。产物 = `src/libcamera/libcamera.so.0.7.1` + `src/ipa/simple/ipa_soft_simple.so` + `.sign`。 — Failed: 平板上先试 meson 构建被用户指出应主机编译
---
Alpine（musl）的包名与 glibc 发行版不同：`libyaml-dev` 不存在，要用 `yaml-dev`（提供 /usr/include/yaml.h 与 pkgconfig/yaml-0.1.pc），运行时是 `libyaml`/`py3-yaml`；`apk search -x libyaml` 才会列出 libfyaml 等相近名。交叉编 libcamera 只需从设备 sysroot 取 yaml-0.1。 — Failed: 按 Debian/Ubuntu 名 apk add libyaml-dev 会 no such package
---
ssh -R 远程端口转发重建同名端口会失败（`remote port forwarding failed for listen port 7890`）：上一轮断连后 ServerAlive 未超时、远端残留监听。改在主机侧写一个本地 TCP 中继（python3 监听 0.0.0.0:17890 → 127.0.0.1:7890）让设备当 HTTP 代理用，比反复 -R 稳；设备侧验证 = `curl -x 192.168.7.9:17890 -sI https://github.com` 应见 `HTTP/1.1 200 Connection established`。
---
meson 交叉编 libcamera 时 host python 必须有 ply/yaml/jinja2（`ModuleNotFoundError: No module named 'ply'` 会让 meson setup 直接退出）；Ubuntu 上 pip3 不一定存在，系统级包名 = python3-ply/python3-jinja2/python3-yaml。设备侧 Alpine 对应 py3-ply / py3-jinja2 / py3-yaml 与 yaml-dev（不是 libyaml-dev，后者在 Alpine 不存在）。
---
Alpine 设备上 apk 报 `APKINDEX ... file format is invalid or inconsistent` 往往不是镜像坏，而是设备时钟停在 1970 ⇒ HTTPS/TLS 全失败（curl rc=60），校园网还会把 HTTP 劫持到 202.141.180.1 跳转页。修复=`date -s` 或 time-sync.sh；判据=`date` 与远端 Date 头对比；临时绕过=--insecure 或走宿主中继。 — Failed: 把时钟错误误判为镜像/网络问题
---
Waydroid 的 `container start` 不接受 `-p <pidfile>`：手敲 `waydroid container start -p /run/waydroid-container.pid` 会报 `argument action: invalid choice: '/run/waydroid-container.pid'`（`-p` 是 OpenRC start-stop-daemon 的参数，写在 /etc/init.d/waydroid-container 的 command_args_background 里）。要后台起容器就直接 `rc-service waydroid-container start`，别把 initd 的参数抄进 waydroid 命令行。 — Failed: 把 OpenRC 服务的参数当成 waydroid CLI 参数
---
ext4 镜像 `resize2fs` 只扩块不扩 inode：Waydroid `vendor.img` 原本 20962 块只剩 64 空闲块、inode 总 496 只剩 14 个，扩到 128 MiB 后 debugfs `write` 仍报 `Could not allocate inode in ext2 filesystem`（`rm` 报 `File not found by ext2_lookup`）。正确做法 = ① debugfs `rdump /` 把整个 vendor 树导到主机 staging（本次 251 文件）；② 用 `mke2fs -N 8192` 重建 128 MiB ext4（充足 inode）；③ debugfs write 写回并 `sif ... uid 0 mode 0100644/0100755` 修正属主 0:2000（相机 HAL 在 /vendor 里必须是 root:2000，否则 linker 拒载）；④ 校验 inode/free inode 与目标文件存在。原位 `install` 会把目标先截断成 0 字节，`debugfs write` 在满盘镜像上同样不可用。 — Failed: 2026-10-18 C5 相机 HAL 固化进 Waydroid vendor.img 时反复踩；扩镜像后仍写不进去，根因是 inode 而非块
---
ext4 的 `resize2fs` **只扩块、不扩 inode**：Waydroid MAINLINE vendor.img 扩到 128 MiB 后 inode 仍 496（0 空闲），`debugfs write` 一律 `Could not allocate inode in ext2 filesystem`。需要更多文件时必须重建（mke2fs -N / 新建镜像）而不是 resize2fs。同理 debugfs `rdump` 非 root 会报 `Operation not permitted while changing ownership`（内容仍能搬出）。 — Failed: Waydroid vendor.img 扩容后写文件失败，误以为是空间不足
---
Waydroid 容器状态机坑（2026-10-18 设备侧实测）：① `waydroid container start` 不接受 `-p <pidfile>`（argparse 报 invalid choice，OpenRC initd 里传 `-p` 会失败），起容器用 `rc-service waydroid-container start`；② 残留 session 时 `waydroid session start` 报 `RuntimeError: Already tracking a session` / `Container service is already running`，必须先 `waydroid container stop` + 清 `/run/waydroid-container.pid` + 杀 session/container 进程再起；③ 以 root 跑 `dbus-run-session` 必须把 `XDG_RUNTIME_DIR` 指到 `/run/user/0`，否则报 `XDG_RUNTIME_DIR "/run/user/1000" is owned by uid 1000, not our uid 0`。 — Failed: 反复 start/stop 期间状态机与 pidfile 残留，加上 uid 不匹配，浪费数轮
---
Waydroid 容器 external camera HAL 的 A/B 归因（2026-10-18，commit 4cbbab9）：自编 64-bit `android.hardware.camera.provider@2.4-external-service` 注册成功（logcat `Registration complete`）但首笔 binder 事务即 SIGSEGV —— tombstone 顶层 `BHwBinder::transact+156`（blr x8，x8=0xffffffff…ffe0，即对 -32 调虚函数），init.svc 反复 restarting；同一 vendor.img 换成 donor 平台自产 64-bit `android.hardware.camera.provider@2.5-service_64`（另需补 `-legacy.so` 与 `camera.device@*.0-impl.so`、VINTF manifest 补 `legacy/0` 实例）后 `init.svc.vendor.camera-provider-2-5 = running`。⇒ 锅在自编二进制的 ABI（libc++ ABI / _LIBCPP_ABI 设置），不在容器环境或相机代码。教训：跨平台复用的 HAL 二进制必须用「平台自产件」先验证链路，再排查自编件。
---
Waydroid vendor.img 重建的两个硬细节（2026-10-18 实测）：① `debugfs -w -R "write <src> <dst>"` 要求**目标父目录已在镜像里存在**，缺 `/vendor/bin/hw`、`/vendor/lib64` 会报 `File not found by ext2_lookup while looking up …`（写入静默失败）；② `mke2fs -d <staged>` 填充时报 `__populate_fs: Could not allocate block in ext2 filesystem while writing file "libpulse.so"` 就是镜像尺寸不够——本机 128 MiB 放不下（加了 3 个 ≈4.6 MB 的 `camera.device@3.x-external-impl.so`），要用 256 MiB（最终 vendor-cam.img 268 435 456 B）。另 `hidl-gen` 只允许一个 `-L`（`-L c++-headers -o gen -L c++-sources -o gen-src` 报 `only one -L option allowed`）⇒ 头与源必须分两次跑，且包级生成会漏掉被后续版本重声明的接口，要枚举每个 .hal 循环到不再新增。
---
**a 槽跑自研件必卡联想 logo = 原厂 `dtbo_a` 的 Android DTBO overlay 被 ABL 合进我们的 DTB**（2026-11-10 定案）。ABL 在 `BootLinux` 后 `Apply Overlay`：`dtbo_b` 从 2026-10-03 起就是全 0（「假 dtbo」→ `magic mismatch` 容忍继续），`dtbo_a` 一直是原厂合法 DTBO（`D7B7AB1E`/23.3 MB，`Apply Overlay … 175 ms` 真的合并）⇒ 内核拿被污染的设备树起不来：卡 logo、USB 不枚举、无 pstore、~10 s 后 ABL 回落。**判据/处置**：`truncate -s 33554432` 全 0 刷 `dtbo_a` 后同件当场起（RAM 34 s / flashed 27 s）；脚本 `scripts/uefi-a-slot-prepare.sh`（幂等、带备份 `backup/dtbo_a.img` 与读回校验）。**连带的判据坑**：① `androidboot.slot_suffix` 不能判槽（我们的 boot.img 头里烤死 `_b`，ABL 对 Linux 件不追加）→ 在镜像头 cmdline 埋唯一标记再 grep；② `vbmeta_a` Flags 不是墙（解锁态 orange 下原厂 Flags 0 照样起）；③ `logfs` 对最近启动根本不写（前后 sha 相同），只有我们自己的 UEFI 写它有效。正文 `reports/uefi-dtbo-a-rootcause-20261110.md`、`PITFALLS #600–#602`。
