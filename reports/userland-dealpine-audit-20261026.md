# 用户态去 Alpine 化审计（T20 补欠账，2026-10-26）

> 性质：**纯主机侧静态审计 + 一次只读 ssh 取证**（无写盘、无重启、无 fastboot）。
> 范围：`packaging/elden-userland/` 的 `services.tsv`（21 行）、`deps.tsv`（27 条抽象）、
> `tools/coupling-waivers.tsv`（12 条豁免）；T14 剩余三步处理结果；四门禁原始输出。
> 证据等级标注：**实测**（本机/设备跑过命令）/**静态**（读文件+行号）/**推断**（标注为推断）。
> 上游接口裁决沿用 `reports/waydroid-droidloom-userland-interface-20261026.md`（下称〔接口报告〕）。

## 0. 结论（数字）

- services.tsv 21 行：ours 16 / override 3 / package 2；默认启用 20（gunyah-modprobe=0）。
- deps.tsv 27 条抽象：其中**三大抽象点**（container-backend / sensor-source / haptics-bridge）
  本轮新增 provider 列并已在 services.tsv 落依赖改名（§3）；其余 24 条不抽象（理由 §4）。
- coupling-waivers.tsv 12 条：skip 8 / message 4，全部通过 X 段可核查性验证。
- 四门禁基线（改动前）与终态（改动后）均 **FAIL=0**（§6 原始输出）。
- T14：a) ffrumble 重写已存在并补规格/ABI 检查（§5.1）；b) sensord 宿主 recipe 已存在（§5.2）；
  c) 双入口**实测已收敛**（设备 local.d sha 与 MANIFEST 一致，均为退役 stub）（§5.3）。

## 1. services.tsv 逐行审计

| 行 | name | init | class | exec | 归属 | 宿主接口 | 失败模式 |
|---|---|---|---|---|---|---|---|
| services.tsv:23 | backlight-floor | ours | longrun | `/usr/local/sbin/elden-backlight-floor.sh` | 我们自己 | AW99706 背光 sysfs（/sys/class/backlight） | 崩溃=低面板发黑；respawn 10 s 兜底 |
| services.tsv:24 | bt-alias | ours | oneshot | `/usr/local/sbin/elden-bt-alias.sh` | 我们自己 | BlueZ D-Bus（org.bluez Adapter1） | 别名不设=蓝牙名不可辨 |
| services.tsv:25 | charge-watch | ours | longrun | `/usr/local/sbin/charge-watch.sh` | 我们自己 | 充电策略 sysfs（charge-ctl → /sys/class/power_supply） | 无 pidfile ⇒ 双实例竞态窗口（清单报告 §3.2），已由双入口收敛消除第二个入口 |
| services.tsv:26 | elden-bootlog | ours | oneshot | `/usr/local/sbin/elden-bootlog.sh` | 我们自己 | /proc/sys/kernel/random/boot_id + dmesg | 缺失=post-mortem 无每启动快照 |
| services.tsv:27 | elden-hapticd | ours | longrun | `/usr/local/bin/elden-hapticd` | 我们自己 | sysfs leds（/run/elden-haptic/leds/vibrator）→ aw86927 FF_RUMBLE | droidloom 下无 /sys bind 面 ⇒ 抽象点③ |
| services.tsv:28 | elden-powerlog | ours | shutdown | `/usr/local/sbin/elden-powerlog-mark.sh` | 我们自己 | shutdown target 钩子 | 缺失=无干净关机标记 |
| services.tsv:29 | gunyah-modprobe | ours | oneshot | `/usr/local/sbin/gunyah-modprobe.sh` | 我们自己（默认禁用） | 内核模块加载 | BLOCKED: vendor MEM_DONATE（reports/gunyah-decision-20261025.md） |
| services.tsv:30 | greetd | override | longrun | `/usr/sbin/greetd` | 包+我们覆盖 | seatd/libseat + Wayland | respawn=5 语义红线（PITFALLS #318） |
| services.tsv:31 | iio-sensor-proxy | override | longrun | `/usr/libexec/iio-sensor-proxy` | 包+我们覆盖 | D-Bus net.hadess.SensorProxy；数据来自 SSC(QRTR 400) | 不等 QRTR svc 400 ⇒ 自动旋转永久 MODE_OFF（G1-34） |
| services.tsv:32 | net-selfheal | ours | oneshot | `/usr/local/sbin/net-selfheal.sh` | 我们自己 | NetworkManager + 路由/PMTU | 缺失=弱网下 TLS 链路偶发失败 |
| services.tsv:33 | pstore-catch | ours | oneshot | `/usr/local/sbin/pstore-catch.sh` | 我们自己 | /sys/fs/pstore | 缺失=panic 证据丢 |
| services.tsv:34 | q28-boot-watchdog | ours | oneshot | `/usr/local/sbin/q28-boot-watchdog.sh` | 我们自己 | DSI/panel 状态 | 现役线未触发；保留观测 |
| services.tsv:35 | qbootctl | override | oneshot | `/usr/bin/qbootctl` | 包 | AB slot标记（/boot A/B 分区） | 不标=约 7 次重启进 fastboot（PITFALLS #181），语义红线 enabled=1 |
| services.tsv:36 | ssc-udp-relay | ours | longrun | `/usr/bin/python3` | 我们自己 | ssccli(QRTR/SSC) → UDP:4446 | 现役传感器数据源 ⇒ 抽象点② |
| services.tsv:37 | time-sync | ours | longrun | `/usr/local/sbin/time-sync.sh` | 我们自己 | 网络时间 + RTC | 缺失=时钟漂移破坏 TLS |
| services.tsv:38 | waydroid-ipv6 | ours | longrun | `/usr/local/sbin/waydroid-ipv6` | 我们自己 | waydroid0 桥 + ip6tables NAT66 | 依赖方向已改抽象名 container-backend（A1/A6） |
| services.tsv:39 | net-up | ours | oneshot | `/usr/local/sbin/net-up.sh` | 我们自己 | NetworkManager | legacy /init 与服务管理器二选一，无双启（§5.3） |
| services.tsv:40 | wifi-scan-refresh | ours | longrun | `/usr/local/sbin/wifi-scan-refresh.sh` | 我们自己 | NetworkManager Scan | 间隔<180 s 语义红线（PITFALLS #354） |
| services.tsv:41 | ath12k-retry | ours | oneshot | `/usr/local/sbin/ath12k-retry.sh` | 我们自己 | PCI 重新 bind（/sys/bus/pci/drivers/ath12k） | 首探失败时的重试 |
| services.tsv:42 | hexagonrpcd-adsp-sensorspd | package | longrun | `/usr/bin/hexagonrpcd-adsp-sensorspd` | 发行版包 | QRTR svc 400（ADSP sensorspd） | Debian 由 hexagonrpcd.service -s drop-in 复刻+别名（J3） |
| services.tsv:43 | waydroid-container | package | longrun | `/usr/bin/waydroid` | 发行版包 | LXC（lxc.service）+ binderfs | 容器管理器 ⇒ 抽象点①现役 provider |

静态证据：两套渲染产物 `out/units/{openrc,systemd}/`（render.py 实测 21 服务/20 启用）；
语义红线 5 条由 verify.sh §E 逐条断言（§6）。


## 2. deps.tsv 逐条抽象审计

| 行 | abstract | openrc | systemd | 归属 | 宿主接口/失败模式 |
|---|---|---|---|---|---|
| deps.tsv:39 | abstract | openrc | systemd | 发行版/内核侧 | note |
| deps.tsv:40 | fs-local | localmount | local-fs.target | 发行版/内核侧 | 本地文件系统已挂载（/etc、/var 可写、/var/log 可写）。OpenRC 的 localmount 是伪服务 |
| deps.tsv:41 | fs-root | root | local-fs.target | 发行版/内核侧 | 根文件系统。OpenRC 的 root 伪服务与 localmount 在 systemd 侧收敛到同一个 target |
| deps.tsv:42 | dev-manager | udev | systemd-udevd.service | 发行版/内核侧 | 设备管理器（/dev 与冷插拔事件）。OpenRC 里 udev 是本地服务名，systemd 侧是 systemd-u |
| deps.tsv:43 | dev-manager-settle | udev-settle | systemd-udev-settle.service | 发行版/内核侧 | 等设备枚举收敛。Debian 侧默认不启用 udev-settle（Debian 认为它是 time sink）⇒ 依赖 |
| deps.tsv:44 | dev-manager-trigger | udev-trigger | systemd-udev-trigger.service | 发行版/内核侧 | 补发冷插拔 uevent |
| deps.tsv:45 | clock-hw | hwclock | systemd-hwclock.service | 发行版/内核侧 | 把 RTC 同步到系统时钟（无电池 RTC 的本机在上游化时会被拔掉，见 TASKS §7） |
| deps.tsv:46 | hostname | hostname | systemd-hostnamed.service | 发行版/内核侧 | 主机名设定 |
| deps.tsv:47 | sysctl | sysctl | systemd-sysctl.service | 发行版/内核侧 | 内核参数（/etc/sysctl.d）；注意 Debian 的 sysctl 由 systemd-sysctl 在 sy |
| deps.tsv:48 | kernel-modules | modules | systemd-modules-load.service | 发行版/内核侧 | 按 /etc/modules 加载模块。本机**不用**它加载相机/payload（有序加载在 /init，见 init |
| deps.tsv:49 | boot-local | local | elden-local.service | 我们 | 「sysinit 之后跑一次本地钩子」的抽象。OpenRC 侧 = /etc/local.d（Alpine 专属目录，本 |
| deps.tsv:50 | session-bus | dbus | dbus.service | 发行版/内核侧 | D-Bus **系统总线**（名字沿用 T14 词表）。这是全项目最容易错的一条：OpenRC 叫 dbus，syste |
| deps.tsv:51 | seat | seatd | seatd.service | 发行版/内核侧 | seat 管理（greetd 的 LIBSEAT_BACKEND=seatd；seatd 没起 greetd 就无桌面， |
| deps.tsv:52 | login-manager | elogind | elogind.service | 发行版/内核侧 | 会话/登录管理。Alpine 用 elogind（独立守护），Debian 用 systemd 自带 logind ⇒  |
| deps.tsv:53 | polkit | polkit | polkit.service | 发行版/内核侧 | 权限代理 |
| deps.tsv:54 | rtkit | rtkit | rtkit-daemon.service | 发行版/内核侧 | 实时调度代理（PipeWire 依赖） |
| deps.tsv:55 | udisks | udisks2 | udisks2.service | 发行版/内核侧 | UDisks2（Phosh 的存储/电源面板） |
| deps.tsv:56 | bluetooth-stack | bluetooth | bluetooth.service | 发行版/内核侧 | BlueZ 守护。OpenRC 服务名 bluetooth，systemd 单元 bluetooth.service |
| deps.tsv:57 | net-manager | networkmanager | NetworkManager.service | 发行版/内核侧 | 网络管理。**大小写是硬坑**：systemd 单元名是 NetworkManager.service（大写 N/M）， |
| deps.tsv:58 | time-daemon | chronyd | chronyd.service | 发行版/内核侧 | 时间同步守护（本机另有 time-sync.service 做一次性校正，见 services.tsv） |
| deps.tsv:59 | container-host | lxc | lxc.service | 发行版/内核侧 | LXC（Waydroid 宿主侧依赖） |
| deps.tsv:60 | ssh | sshd | sshd.service | 我们 | SSH 守护。**这是 /init 的恢复通道**，在 PID1 交接前就由 /init 自己拉起（initramfs/ |
| deps.tsv:61 | container-backend | waydroid-container | waydroid-container.service | 我们 | 【抽象点① 容器后端】「起/停/查一个 Android 容器」的语义。现役 provider=waydroid（wayd；provider=waydroid-container |
| deps.tsv:62 | sensor-source | ssc-udp-relay | ssc-udp-relay.service | 我们 | 【抽象点② 传感器数据源】「把宿主侧传感器值推给消费者」的进程。现役 provider=ssc-udp-relay（ss；provider=ssc-udp-relay |
| deps.tsv:63 | haptics-bridge | elden-hapticd | elden-hapticd.service | 我们 | 【抽象点③ 触觉桥】「容器振动请求 → aw86927 FF_RUMBLE」的桥。现役 provider=elden-h；provider=elden-hapticd |
| deps.tsv:64 | sensors-dsp | hexagonrpcd-adsp-sensorspd | hexagonrpcd-adsp-sensorspd.service | 发行版/内核侧 | ADSP sensorspd（QRTR svc 400 = SSC）。Alpine 是独立 initd；Debian 0 |

归属说明：抽象名本身是**我们的**语义层（deps.tsv 是唯一真源，render.py 派生 UNIT_MAP 缓存并
做逐字等价自检——`--check` 硬门）；两侧具体名字（openrc/systemd 列）归发行版。
失败模式共性：两侧名字不等价 ⇒ systemd 静默忽略（PITFALLS #397a），render.py 对未登记名直接 FAIL。


## 2.1 coupling-waivers.tsv 逐条豁免审计

| 正则（缩写） | kind | stage | 理由摘要 | 归属 | 失败模式 |
|---|---|---|---|---|---|
| waivers.tsv:23 `packaging/elden-userland/files/usr/local/sbin/openrc` | all | skip | BRINGUP=/etc/local.d/... 是该脚本写 boot 钩子的目标路径；脚本已被 debian-exclude.tsv 排除，不进 Debian | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:24 `packaging/elden-userland/files/usr/local/sbin/openrc` | locald | skip | 同上：mkdir /etc/local.d 只为写 Alpine 的 local 钩子；脚本不进 Debian 根 | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:25 `packaging/elden-userland/files/usr/local/sbin/openrc` | rc-update | skip | rc-update add sysinit：Alpine runlevel 概念，Debian 侧等价物是 systemctl --root enable（st | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:26 `packaging/elden-userland/files/usr/local/sbin/openrc` | rc-update | skip | 同上（boot runlevel） | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:27 `packaging/elden-userland/files/usr/local/sbin/openrc` | rc-update | skip | 同上（default runlevel） | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:28 `packaging/elden-userland/files/usr/local/sbin/openrc` | rc-update | skip | rc-update add elden-powerlog shutdown：systemd 侧由 services.tsv 的 elden-powerlog 行 | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:30 `packaging/elden-userland/files/usr/local/sbin/elden-` | rc-service | skip | rc-status 只在 OpenRC shutdown runlevel 有意义；本文件已被 debian-exclude.tsv 排除，Debian 侧等价 | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:32 `packaging/elden-userland/files/usr/local/bin/ssc-udp` | apk | message | 字符串 "FATAL: ssccli not found (apk add libssc)" 是异常分支的**日志文案**，不会被执行；X 段证明：剥掉引号后正 | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:33 `packaging/elden-userland/files/usr/local/sbin/bt-up\` | apk | message | 同上：`log "bluetoothd not installed (apk add bluez)"` 是日志文案（该分支直接 exit 1，不装包） | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:34 `packaging/elden-userland/files/usr/local/sbin/greetd` | apk | message | 同上：`echo "$GREETD missing (apk add greetd)"` 是错误提示，随后 exit 1 | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:35 `packaging/elden-userland/files/usr/local/sbin/setup-` | apk | message | `echo "[session] apk add greetd greetd-phrog"` 是下一步的提示文案；真正执行在 :41（该文件已被 debian- | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |
| waivers.tsv:36 `packaging/elden-userland/files/usr/local/sbin/setup-` | apk | skip | 真调用 `apk add -q greetd greetd-phrog`，但本文件已被 debian-exclude.tsv 排除（Debian 侧 greet | 设备逐字副本/Alpine 侧工件 | 剥引号/排除表/守卫由 check-coupling X 段当场核验 |

归属：12 条全部是「设备逐字副本」（MANIFEST sha 锁定，禁手改）或「本身属于 Alpine 侧」的工件；
无一条豁免我们**新写**的代码。可核查性（skip⇒进 debian-exclude.tsv / message⇒引号内 / guarded⇒command -v）
由 check-coupling.sh X 段逐条当场验证（§6 g2）。

## 3. 三大抽象点：为什么是这 3 个、为什么现在做

判据（〔接口报告〕§3）：① 已有 ≥2 个真实候选实现 ② 抽象成本 < 一次性重写 ③ 阻塞本次迁移。
三条全满足的只有 3 个，本轮以**声明式**落地（不引入框架/插件注册表）：

| 抽象点 | deps.tsv 行 | 现役 provider（services.tsv） | 候选 | 换实现的动作 |
|---|---|---|---|---|
| ① 容器后端 | deps.tsv:61 `container-backend` | `waydroid-container`（services.tsv:43，`waydroid container start`） | redroid、droidloom cell | 改 deps.tsv provider 列 + provider 行 exec/args；依赖图不动 |
| ② 传感器数据源 | deps.tsv:62 `sensor-source` | `ssc-udp-relay`（services.tsv:36，ssccli→UDP） | --fake 源、Termux 转发 | 同上；只抽源不抽传输（下游 HIDL HAL 只认 UDP，已定型） |
| ③ 触觉桥 | deps.tsv:63 `haptics-bridge` | `elden-hapticd`（services.tsv:27，sysfs 轮询→FF_RUMBLE） | socket 行协议承载（droidloom 无 /sys bind 面） | 桥语义 ABI（activate/duration/amplitude=255）不变，只换承载 |

**为什么其余不抽象**：见 §4。**为什么现在做**：services.tsv 的依赖方向必须先从 `waydroid-container`
（包名）改成 `container-backend`（语义名），否则切后端时要手改 2 处依赖（waydroid-ipv6:38、
elden-hapticd:27）——这是 A6 的依赖方向修正，成本 2 个单元格，收益是切换时零依赖改动。
render.py 新增校验：只有 3 个抽象点允许带 provider 列（防到处长出可插拔点）；provider 必须
是本包服务名或 UNIT_MAP 键（防幽灵）；3 个点缺 provider 列直接 FAIL。



## 4. 不抽象清单（防过度设计，逐条一句）

| 不做 | 一句理由（〔接口报告〕§3/§4.2） |
|---|---|
| 通用 backend plugin API | 2 个候选中 droidloom 现不可用（需 linux-drm-syncobj，Phosh 不支持；aarch64 无发布包） |
| camera provider（A4） | 接口形态两侧相同（V4L2）；我们的 4 层修补是真缺陷修复，抽象=重写已修好的东西 |
| 音频四层修补（A5） | 全是 Waydroid 镜像内部缺陷补丁，droidloom 下天然不存在 |
| 网络/waydroid0（A6 抽象） | 只需改依赖方向（已做，§3），不抽网络后端 |
| 显示/窗口（A7） | 桌面栈选型（Denial vs Phosh），与去 Alpine 化正交 |
| 属性投影/PI（A8） | 与 droidloom 无关的独立小改进；本轮塞入会给 linux17 首启加变量 |
| binderfs/输入挂载策略（A9） | 内核能力两路线共用；挂载细节属后端内部 |
| 通用挂载管理器（A10） | 真问题是"漏项不可观测"，用 verify.sh 断言解决，不造框架 |


## 5. T14 剩余三步

### 5.1 ffrumble（无源 → 已补规格 + ABI 检查）

- **静态**：最小 C 重写已存在 `scripts/ffrumble.c`（2026-10-25，按用法重写，接口逐字兼容，
  ms 十进制/magnitude 0x 前缀的怪癖刻意保留），构建 `scripts/build-ffrumble.sh`，
  产物 `out/ffrumble/ffrumble`（aarch64 静态）；`sources.tsv:5` 已 `status=ok`。
- **本轮新增**：`packaging/elden-userland/sources/ffrumble/README.md`（行为规格 + 反汇编要点 +
  上机 A/B 记录）+ `check-abi.sh`（arch/静态链接/用法字符串/strace 行为探针；对重写产物实测 FAIL=0）。

### 5.2 waydroid-sensord 宿主 glibc 构建 recipe（已存在，实测核对）

- **实测**：可复跑脚本 `scripts/host-arm64-chroot.sh --build-sensord`（chroot 内 make，
  产物拷回 `out/sensord-host/{waydroid-sensord,waydroid-sensord-udp}` + SHA256SUMS，2026-10-25 已产出，
  与 `sources.tsv:7,8` 两条的 build/产物路径一致）。源 `patches-userland/waydroid-sensord-udp/`
  （SensorFW/Sensors/service.cpp + Makefile）。本轮**未改动**，仅核对路径一致性（静态）。

### 5.3 /init 与 local.d 双入口收敛（实测已收敛，零改动）

- **实测（设备只读 ssh）**：设备 `/etc/local.d/elden-bringup.start` 与 `elden-bootlog.start`
  的 sha256（111b2e4c…、4b3f9cc4…）与 MANIFEST.tsv 副本一致，且首行均为
  "已退役 2026-10-25：改由服务管理器负责" ⇒ **local.d 入口已死**，`/init` 是唯一剩余入口。
- **静态**：`initramfs/init:541-546` 的 5 个后台脚本（ath12k-retry/net-up/time-sync/charge-watch/bt-up）
  全部包在 `init_mode = legacy` 分支内（initramfs/init:523）；native（openrc/systemd）模式由
  服务管理器唯一拉起，两种模式互斥 ⇒ 无双启窗口。
- **services.tsv 同步**：4/5 有服务行（net-up:39、time-sync:37、charge-watch:25、ath12k-retry:41）；
  `bt-up` 无行是**有意**：它只做 bluetoothd 拉起+别名，native 模式下 bluetoothd 归
  `bluetooth.service`（deps.tsv bluetooth-stack），别名由 `bt-alias`（services.tsv:23）承担。
- **dash -n initramfs/init**：实测通过（§6 门禁输出内附）。**本轮未改 initramfs/init** ⇒
  无 diff、无需备份/回滚（回滚命令为通用形态：`cp backup/<ts>/init initramfs/init`，本轮不适用）。



## 6. 四门禁原始输出

### 6.1 终态原始输出（改动后，2026-10-26）

四个门禁 **FAIL=0 / WARN=0**；基线（改动前）同为 FAIL=0（verify/coupling/render），改动零回归。

#### g1 verify.sh --offline

```text
$ bash packaging/elden-userland/tools/verify.sh --offline

[A. MANIFEST ↔ files/ 自洽]
  ok    73 行已核对

[B. ELF 可重建性（sources.tsv）]
  ok    /usr/local/bin/elden-hapticd ← scripts/elden-hapticd.c
  ok    /usr/local/bin/eldroid-sensord ← scripts/eldroid-sensord.c
  ok    /usr/local/bin/ffrumble ← scripts/ffrumble.c
  ok    /usr/local/bin/waydroid-sensord ← patches-userland/waydroid-sensord-udp/
  ok    /usr/local/bin/waydroid-sensord-udp ← patches-userland/waydroid-sensord-udp/Makefile
  ok    /usr/local/bin/elden-ime-focusd ← patches-userland/zh-ime/elden-ime-focusd.c
  ok    /usr/local/sbin/reboot2 ← rootfs/reboot2.c

[C. services.tsv ↔ 资产对齐]
  ok    backlight-floor → /usr/local/sbin/elden-backlight-floor.sh（设备副本）
  ok    bt-alias → /usr/local/sbin/elden-bt-alias.sh（extra）
  ok    charge-watch → /usr/local/sbin/charge-watch.sh（设备副本）
  ok    elden-bootlog → /usr/local/sbin/elden-bootlog.sh（extra）
  ok    elden-hapticd → /usr/local/bin/elden-hapticd（设备副本）
  ok    elden-powerlog → /usr/local/sbin/elden-powerlog-mark.sh（extra）
  ok    gunyah-modprobe → /usr/local/sbin/gunyah-modprobe.sh（extra）
  ok    greetd → /usr/sbin/greetd（包二进制，unit 被我们覆盖）
  ok    iio-sensor-proxy → /usr/libexec/iio-sensor-proxy（包二进制，unit 被我们覆盖）
  ok    net-selfheal → /usr/local/sbin/net-selfheal.sh（设备副本）
  ok    pstore-catch → /usr/local/sbin/pstore-catch.sh（extra）
  ok    q28-boot-watchdog → /usr/local/sbin/q28-boot-watchdog.sh（设备副本）
  ok    qbootctl → /usr/bin/qbootctl（包二进制，unit 被我们覆盖）
  ok    ssc-udp-relay → /usr/bin/python3 /usr/local/bin/ssc-udp-relay.py（解释器 + 仓库脚本）
  ok    time-sync → /usr/local/sbin/time-sync.sh（设备副本）
  ok    waydroid-ipv6 → /usr/local/sbin/waydroid-ipv6（设备副本）
  ok    net-up → /usr/local/sbin/net-up.sh（设备副本）
  ok    wifi-scan-refresh → /usr/local/sbin/wifi-scan-refresh.sh（设备副本）
  ok    ath12k-retry → /usr/local/sbin/ath12k-retry.sh（设备副本）
  ok    hexagonrpcd-adsp-sensorspd（package：unit 由发行版提供，不校验 exec）
  ok    waydroid-container（package：unit 由发行版提供，不校验 exec）

[D. 两套 unit 渲染]
  ok    render.py --check：render: 21 个服务，20 个默认启用
  ok    unit 结构检查完成（19 个 systemd + 19 个 openrc）

[E. 语义红线（README §服务迁移口径）]
  ok    qbootctl 默认启用（PITFALLS #181）
  ok    greetd 有 respawn（PITFALLS #318）
  ok    iio-sensor-proxy 等 QRTR svc 400（G1-34）
  ok    wifi-scan-refresh 间隔 150s < 180s（PITFALLS #354）
  ok    elden-hapticd amplitude 默认 255（TASKS C10）
  ok    shutdown 标记已剥离成独立脚本

[F. 设备逐字比对]
  ok    --offline：跳过

[G. rootfs/build-rootfs.sh 白名单 ⊆ MANIFEST（防第 4 处漂移）]
  ok    白名单 24 项全部在 MANIFEST 中

==== verify: FAIL=0 WARN=0 ====
```

#### g2 check-coupling.sh

```text
$ bash packaging/elden-userland/tools/check-coupling.sh

[W. 豁免表合法性（每条必须有理由且正则可编译）]
  ok     12 条豁免（理由均非空、正则均可编译）

[X. 豁免可核查性（skip⇒进排除表 / message⇒在引号内 / guarded⇒有 command -v）]
  ok     skip 类 8 条已对账 debian-exclude.tsv
  ok     message 类 4 条（明细在 A/B/C 段的 --list 里核对）

[0. 扫描范围]
  ok     扫了 101 个文件（scope=userland；CODE 判 FAIL，注释/文档/守卫/检测清单只计数）

[A. OpenRC 服务控制（rc-service / rc-update / rc-status）]
  waiver packaging/elden-userland/files/usr/local/sbin/openrc-enable.sh:71 [rc-update/skip] 	for s in $SYSINIT; do rc-update add "$s" sysinit >/dev/null 2>&1; done
  waiver packaging/elden-userland/files/usr/local/sbin/openrc-enable.sh:72 [rc-update/skip] 	for s in $BOOT;    do rc-update add "$s" boot    >/dev/null 2>&1; done
  waiver packaging/elden-userland/files/usr/local/sbin/openrc-enable.sh:73 [rc-update/skip] 	for s in $DEFAULT; do rc-update add "$s" default >/dev/null 2>&1; done
  waiver packaging/elden-userland/files/usr/local/sbin/openrc-enable.sh:93 [rc-update/skip] 		rc-update add elden-powerlog shutdown >/dev/null 2>&1 || true
  waiver packaging/elden-userland/files/usr/local/sbin/elden-powerlog.initd:23 [rc-service/skip] 	rc-status default >>/root/powerlog.txt 2>/dev/null

[B. /etc/local.d（Alpine 专属 boot 钩子目录）]
  waiver packaging/elden-userland/files/usr/local/sbin/openrc-enable.sh:25 [locald/skip] BRINGUP=/etc/local.d/elden-bringup.start
  waiver packaging/elden-userland/files/usr/local/sbin/openrc-enable.sh:39 [locald/skip] 	install -d -m755 /etc/local.d /etc/conf.d

[C. apk 包管理调用]
  waiver packaging/elden-userland/files/usr/local/bin/ssc-udp-relay.py:61 [apk/message]             log("FATAL: ssccli not found (apk add libssc)")
  waiver packaging/elden-userland/files/usr/local/sbin/bt-up.sh:19 [apk/message] [ -x "$BLUETOOTHD" ] || { log "bluetoothd not installed (apk add bluez)"; exit 1; }
  waiver packaging/elden-userland/files/usr/local/sbin/greetd-initial-session.sh:80 [apk/message] 		[ -x "$GREETD" ] || { echo "$GREETD missing (apk add greetd)" >&2; exit 1; }
  waiver packaging/elden-userland/files/usr/local/sbin/setup-session-greetd.sh:40 [apk/message] 		echo "[session] apk add greetd greetd-phrog"
  waiver packaging/elden-userland/files/usr/local/sbin/setup-session-greetd.sh:41 [apk/skip] 		apk add -q greetd greetd-phrog

[D. musl 动态解释器路径]

[E. Portage（emerge）]

[F. openrc-run shebang 位置]
  waiver packaging/elden-userland/files/etc/init.d/backlight-floor:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/elden-hapticd:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/elden-powerlog:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/greetd:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/iio-sensor-proxy:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/pstore-catch:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/qbootctl:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/ssc-udp-relay:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/waydroid-ipv6:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/etc/init.d/wifi-scan-refresh:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/files/usr/local/sbin/elden-powerlog.initd:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）
  waiver packaging/elden-userland/templates/openrc-initd.in:1 [openrc-shebang] 模板本体（渲染 OpenRC 投影用，不可直接安装）

[R. 结果]

==== check-coupling: FAIL=0 MENTION=33 GUARDED=2 豁免=24（scope=userland）====
```

#### g3 check-coupling.sh --self-test

```text
$ bash packaging/elden-userland/tools/check-coupling.sh --self-test

[W. 豁免表合法性（每条必须有理由且正则可编译）]
  ok     12 条豁免（理由均非空、正则均可编译）

[S. 负向自测（注入 → 必须 FAIL；移除 → 必须 PASS）]
  ok     S0 干净树 PASS（rc=0）
  ok     S1 注入 rc-service → FAIL（rc≠0，符合预期）
  ok     S2 移除注入 → PASS（门禁可逆、无残留）
  ok     S3 注入 'rc-service greetd restart' → FAIL（覆盖 rc-service）
  ok     S3 注入 'rc-update add greetd default' → FAIL（覆盖 rc-update）
  ok     S3 注入 'sh /etc/local.d/elden-bringup.start' → FAIL（覆盖 locald）
  ok     S3 注入 'apk add bluez' → FAIL（覆盖 apk）
  ok     S3 注入 'exec /lib/ld-musl-aarch64.so.1 ./x' → FAIL（覆盖 musl）
  ok     S3 注入 'emerge -av greetd' → FAIL（覆盖 emerge）
  ok     S4 command -v 守卫的写法 → PASS（可移植写法被放行）
  ok     S5 stage=skip 未进排除表 → FAIL（X 段有效）
  ok     S6 空理由豁免 → FAIL（W 段有效）

[S. 结果]

==== self-test: 全部通过（FAIL=0）====
```

#### g4 render.py --check

```text
$ python3 packaging/elden-userland/tools/render.py --check
render: 21 个服务，20 个默认启用
render: --check 通过（未写盘）
```

#### g6 check-pkgmap.sh

```text
$ bash rootfs/debian/tools/check-pkgmap.sh

统计: map=97 drop=23 add=14  解析失败=0  apt 包数=114
生成: rootfs/debian/apt-list.txt（114 个包）

[E. 服务运行时依赖 svc-deps.tsv]
  minbase 闭包 819 个包（空 status 模拟）
  条目 15 条已核（provider ∈ minbase 闭包 ∪ 自建 deb；命令型条目在 userland 有引用）
结果: FAIL=0 WARN=0
```

另：`dash -n initramfs/init` 实测通过（T14c 语法门）。
完整日志（含 ok 行）见本次会话产物；以下为各门禁末行判据：
verify `FAIL=0 WARN=0`；coupling `FAIL=0 MENTION=33 GUARDED=2 豁免=24`（含自检全过）；
render `21 个服务，20 个默认启用 / --check 通过`；pkgmap `FAIL=0 WARN=0（apt-list 114 包）`。



## 7. 边界与未做项

- 只写：本报告、`TASKS/sessions/2026-10-26-用户态解耦审计与三抽象.md`、
  `packaging/elden-userland/{deps.tsv,services.tsv,tools/render.py,sources/ffrumble/*}`。
  **未改** `initramfs/init`（双入口已收敛，无需改动 ⇒ 无备份/回滚需求）、
  INDEX/TASKS/DEVICE/RESOURCES/PITFALLS、`scripts/`、`rootfs/`。
- 设备只读：ssh 仅 head/sha256sum 取证；无装包/重启/写盘/fastboot。
- 未做/未证实（不编）：
  1. droidloom 侧真机验证（§3 的候选仍只是候选）；hapticd socket 承载**未实现**（〔接口报告〕§6.4 判定为可用后才需要）。
  2. ffrumble 行为探针（strace 段）在本机跳过——无 /dev/input/event2；上机 A/B 证据引用 2026-10-25 实测。
  3. sensord recipe 本轮未重跑构建（产物 2026-10-25 已在 `out/sensord-host/`，脚本可复跑）。
  4. 设备在 legacy /init 模式下的 5 脚本单实例性只做了静态确认 + 单点 pgrep（含 ssh 自匹配噪音），未做长时间竞态观测。
- 结论分级汇总：门禁数字=实测；services/deps/waivers 逐行=静态（file:line）；§4 不抽象清单=静态+推断（引用〔接口报告〕）。

