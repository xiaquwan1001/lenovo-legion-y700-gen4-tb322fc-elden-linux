# 用户态入口收敛（`/init` ↔ `local.d` ↔ 服务管理器）2026-10-25

> 前置：`reports/userland-service-inventory-20261025.md`（固化清单）、`reports/g0-fstype-zero-write-20261025.md`（新 `/init` 上机验证）。
> 本轮：**设备写操作 = ① 换 disk `/init`（旧件已备份）② 部署 9 个 initd ③ 两个 local.d 载荷改 no-op**，
> 全部可回退（`/root/bak/20261025-entry-consolidation/`）；**未改 GPT / 未写 boot 分区**。

## 0. 结论

原来「同一批后台脚本被两个入口各拉一次」的结构已收敛为**单一归属**，并顺带把在机 disk `/init`
从 350 行旧版换成仓库版（444 行，含模块加载与 openrc 模式判定）。

| 层 | 归属 | 内容 |
|---|---|---|
| 内核后、init 前 | `/init`（两种 init 共用） | `camera-modules-load.sh`（37 模块）、USB lifeline（usb0/udhcpd/sshd）、ttyGS0/1、`/var/log/elden-boot.log` |
| 运行期（依赖 dbus/NM/bluetoothd/会话） | **服务管理器** | `ath12k-retry`、`charge-watch`、`time-sync`、`net-up`、`net-selfheal`、`bt-alias`、`q28-boot-watchdog`、`elden-bootlog`、`pstore-catch`、`elden-powerlog`、`elden-hapticd`、`greetd`、`iio-sensor-proxy`、`wifi-scan-refresh`、`waydroid-ipv6`、`ssc-udp-relay`、`backlight-floor` |
| 已退役 | — | `/etc/local.d/elden-bringup.start`、`/etc/local.d/elden-bootlog.start`（改为 no-op，保留文件让 `local` 服务不报错） |

`local.d` 的两个载荷在仓库侧同步改为 no-op（`rootfs/persistent-overlay/etc-local.d.tar.gz` 已重建），
服务定义全部来自 `packaging/elden-userland/services.tsv`（21 行，20 个默认启用）。

## 1. 踩到的坑（**PITFALLS #399**，值得单独记）

### 1.1 顺序错了会静默断网

仓库 `/init` 在 openrc 模式**刻意不启动**那批脚本（注释写明交给 `/sbin/init` 与 local.d），
而在机 disk `/init` 是**旧版 350 行**、没有任何启动块 ⇒ 当时那批脚本的唯一启动者就是 local.d。
我先退役 local.d、再装服务 ⇒ 中间那一发 `ath12k-retry` 没人拉起 ⇒ PCI 保持 unbound ⇒
**`wlan0` 接口根本不存在、`/proc/modules` 0 个模块**，但桌面照常起来（DRM 编进内核）——
表现极像"无线驱动回归"。

判据（用于将来快速定位）：`grep -c . /proc/modules` = 0 ⇒ 模块没加载，不是驱动 bug。

### 1.2 OpenRC oneshot 的假 `crashed`

`command=` + 无 `command_background` 的 oneshot，脚本退出（哪怕 rc=0）会被记成 `crashed`。
已在 `render.py` 生成显式 `start(){ ebegin …; "$command" $command_args; eend $? }`，改后
`ath12k-retry / bt-alias / elden-bootlog / pstore-catch` 全部如实报 `started`。

### 1.3 `pgrep -c` 会数进 supervisor

`supervise-daemon <script>` 的命令行含脚本路径 ⇒ `pgrep -fc sbin/charge-watch` = **2**（supervisor + child），
不是双启。判双启看 `ps -eo pid,ppid,args` 里 `/bin/sh …/<script>` 的个数。

## 2. 冷起实测（新 `/init` + 服务单一归属）

| 项 | 结果 |
|---|---|
| 模块 | **37**（`camera-modules-load.sh` 由 `/init` 加载；旧 disk `/init` 是 0） |
| `/init` 日志 | `root fs type=ext2/ext3 on_initramfs=0` → `Alpine rootfs up` → `openrc mode: handing PID1 to /sbin/init` |
| 服务 | `ath12k-retry`/`charge-watch`/`bt-alias`/`elden-bootlog`/`pstore-catch`/`net-selfheal`/`elden-hapticd`/`greetd`/`iio-sensor-proxy` = **started**；`time-sync`/`q28-boot-watchdog` = stopped（一次性跑完即退出，正常） |
| 进程 | 每个脚本 `/bin/sh …/<script>` **各 1 个**（无重复启动） |
| 桌面 | `phoc`=1、`card0-DSI-1`=connected |
| 无线 | `phy0` up、`nmcli device wifi list` 扫到 ustcnet/eduroam ⇒ **驱动与固件通路正常**；未连上是因为环境里只有 `autoconnect=no` 的 ustcnet 与 eduroam（保存的热点不在范围内），**非本轮改动导致** |

## 3. 遗留（明确记账，不当成功）

1. **`wifi-scan-refresh` 冷起偶发 `stopped`**（pidfile 空、子进程成孤儿仍在写日志；`rc-service restart` 立即恢复成
   supervisor+child）。这是**既有** initd 的行为（本轮没换它的 initd），属 `PITFALLS #354` 家族的 supervisor 记账问题。
   下次处理建议：给该 initd 换成 `render.py` 产物并加 `respawn_max` 观测。
2. **`net-up` 在无可用 AP 时会把「等待 NM 自动连上」等满 200 s 再 `exit 1`**，届时 `rc-service net-up` 显示失败。
   语义上没错（它只是个等待器），但会让 `rc-status --failed` 有噪声；后续可改为「无 AP 时 exit 0 + 日志」。
3. **boot_b 仍是 vk152**（旧 ramdisk）。本轮只把 **disk `/init`** 换成新版；要让 RAM 阶段也用新版 `/init`，
   需要把 `out/boot-elden-vk162-fstype.img` 写进 boot_b（**需用户批准写槽**，写前读回校验、失败 `fastboot set_active b`）。
   当前状态是兼容的：旧 ramdisk 的 `/init` 只负责挂根 + `switch_root`，随后交给新版 disk `/init`。

## 4. 迁移视角（f2fs / Mobian）

- 换 init 时**不需要再动 `/init`**：openrc 与 systemd 都只依赖「服务管理器」，`/init` 的职责已收敛到
  「挂根 + 模块 + lifeline + 交棒」四件事。
- systemd 侧的等价物已在 `packaging/elden-userland/out/units/systemd/`（21 个服务，`systemd-analyze` unit 级错误 0），
  其中 `localmount→local-fs.target` 等 12 条依赖名映射是硬要求（`PITFALLS #397`）。
