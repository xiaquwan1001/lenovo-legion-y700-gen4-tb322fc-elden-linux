# persistent-overlay — 持久根「非包管理」状态快照

来源：2026-10-06 从 U2 持久根（`/dev/sda17`，`linux17`）直接采集。
用途：持久 rootfs **无脚本化构建**；重建时用本目录还原「不随 apk 包走」的改动。
（遵守 AGENTS.md：迁移只搬 **数据/经验**，环境在目标机重建；包版本漂移可接受，目标是**包集合**与手写配置。）

**一键还原**（设备上 root）：

先把这个目录（含 `userland-display/` 子目录）拷到设备，再在设备上跑：
```sh
scp -r rootfs/persistent-overlay root@192.168.7.1:/root/
ssh root@192.168.7.1 'cd /root/persistent-overlay && sh restore.sh'
# 跳过耗时的用户态重编：SKIP_USERLAND_DISPLAY=1 sh restore.sh
```
（旧的一行式 `ssh 'sh -s' < restore.sh` 只在设备上已有这些 tarball 时才成立；新的 `userland-display/` 要求整目录存在。）

| 文件 | 内容 | 还原方式 |
|---|---|---|
| `apk-world.txt` | `/etc/apk/world`（120 行） | `apk add $(cat …)`（restore.sh 已做） |
| `usr-local-sbin.tar.gz` | `/usr/local/sbin/`（自研脚本，**排除 `.bak*`**；2026-10-19 重采，含 `wifi-scan-refresh.sh`、`cam-mode.sh`、`q28-*watchdog.sh`、`sleep-*.sh`、`kmsgspy.sh`、`elden-session-user`） | `tar xzf - -C /usr/local/sbin --owner=0 --group=0` |
| `etc-local.d.tar.gz` | `/etc/local.d/elden-bringup.start`（OpenRC `local` 载荷） | 解到 `/etc/local.d` |
| `etc-conf.d.tar.gz` | `/etc/conf.d/greetd`（`LIBSEAT_BACKEND=seatd`） | 解到 `/etc/conf.d` |
| `etc-greetd.tar.gz` | `/etc/greetd/config.toml` | 解到 `/etc/greetd` |
| `etc-NM-conf.d.tar.gz` | `99-unmanaged.conf`（usb0/lo unmanaged） | 解到 `/etc/NetworkManager/conf.d` |
| `etc-initd-backlight-floor` / `etc-conf.d-backlight-floor` | 背光下限服务（`supervise-daemon`，20 s 轮询，`BACKLIGHT_FLOOR=1024`≈25%）；防「面板 GOOD 但看起来像黑屏」（`PITFALLS #372`） | `install -m755/-m644` + `rc-update add backlight-floor default`（restore.sh 已做） |
| `etc-initd-wifi-scan-refresh` | `/etc/init.d/wifi-scan-refresh`（连通态周期扫描服务，`supervise-daemon`） | `install -m755` + `rc-update add wifi-scan-refresh default` |
| `etc-conf.d-wifi-scan-refresh` | `/etc/conf.d/wifi-scan-refresh`（`WIFI_SCAN_INTERVAL=150`，**必须 <180 s**） | `install -m644` |
| `init` | 磁盘根 `/init` 快照（**真源 = 仓库 `initramfs/init`**） | `install -m755 init /init` |
| `sbin-poweroff`/`-reboot`/`-halt` | `elden-powerwrap` 包装器 | `install -m755` |
| `elden-init-mode.txt` | `openrc`（init 模式开关） | — |
| `openrc-runlevels.txt` | `rc-update show -v` 快照 | 参照 `openrc-enable.sh` |
| `STATE.txt` | NM conf、chrony conf.d、pam.d、runlevels、`/sbin` 原始内容 | 人工比对 |

## 关键还原点（重建后必须补）

1. **GNU 工具**：`apk world` 已含 `coreutils findutils grep sed gawk procps-ng curl wget jq rsync socat tcpdump zstd xz tree less`
   （`rootfs/build-rootfs.sh` 已同步加进包清单）。
2. **greetd**：`[terminal] vt=7` + `[initial_session]`/`[default_session]` 均指向 `/usr/local/sbin/elden-session-root`、`user=root`
   —— **缺 `[default_session]` 会直接启动失败**；`/etc/conf.d/greetd` 必须 `export LIBSEAT_BACKEND=seatd`
   （logind 后端会 deactivate session → phoc 释放 DRM → 面板黑，见 Q24）。
3. **OpenRC 模式**：`/etc/elden-init-mode=openrc` ⇒ `/init` 末段 `exec /sbin/init`（busybox init）→ `/etc/inittab` → `openrc sysinit/boot/default`。
   服务清单见 `scripts/openrc-enable.sh`；**故意不 enable** `networking/dhcpcd/wpa_supplicant`（Q26 双管理器）、`chronyd`（由
   `time-sync.sh` 先步进 1970 时钟）、`sshd`/`usb-gadget`/getty（由 `/init` 保生命线）。
   回退：`echo legacy >/etc/elden-init-mode && reboot`。
4. **`/sbin/{poweroff,reboot,halt}`** = `elden-powerwrap`：`elden-init-mode=openrc` 时走**干净关机**（busybox init 收信号、跑 shutdown 链），
   legacy 时回退 `-f`。生成脚本 = `scripts/fix-logind-poweroff.sh`（幂等）。**G1-25 至此结构性解决。**
5. **`99-unmanaged.conf`**：`usb0`/`lo` 必须 unmanaged，否则 NM 会掐断 SSH 生命线。
6. **`chown greetd:greetd /var/lib/greetd`**（原 Alpine 打包 `root:root 750` → greetd 报 `Permission denied`）。
7. **`/init` 真源 = `initramfs/init`**（磁盘根 `/init` 由 `build-rootfs.sh` 安装；**禁止在设备上改 `/init`**）。
9. **背光下限**（`PITFALLS #372`）：`backlight-floor` 服务 + **用户态** `ambient-enabled=false`。
   gsettings 必须在**真会话**里写（`PITFALLS #103`：裸写不生效），restore.sh **不**替你改 dconf：
   ```sh
   sudo -u <sess_user> HOME=/home/<sess_user> XDG_RUNTIME_DIR=/run/user/<uid> \
        DBUS_SESSION_BUS_ADDRESS="$(从该用户任一进程的 environ 取)" \
        gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false
   ```
8. **dbus launch helper**：`chown root:messagebus /usr/libexec/dbus-daemon-launch-helper; chmod 4750`（Alpine 打包为 root:root）。

## 已知缺口（重建时注意）
- `chronyd` 依赖 `time-sync.sh` 等到网络才起；设备**无默认路由**时时钟停在 **1970**（硬件 RTC 只读，PITFALLS #73）。`rtkit` 同理由会话链决定。
- 本快照**不含** `waydroid` 镜像/容器状态（G2 另行处理）。

## 追加（2026-10-06 晚）：G1-22/Q24 取证套件
| 文件 | 内容 | 还原方式 |
|---|---|---|
| `etc-initd-powerlog.tar.gz` | `/etc/init.d/elden-powerlog`（shutdown runlevel 写 `CLEAN-STOP`） | `tar xzf - -C /etc/init.d` + `rc-update add elden-powerlog shutdown` |
| `blankspy.sh`、`elden-powerlog.initd` | 已在 `usr-local-sbin.tar.gz` 内 | `openrc-enable.sh enable` 会自动安装 forensics |
| `openrc-runlevels.txt` | `rc-update show -v` 快照 | 参照 `openrc-enable.sh` |

判别法：事件后 `/root/powerlog.txt` 有 `USERLAND-*`/`CLEAN-STOP` = 用户态干净关机；无 + `blankspy.log` 截断 = 内核硬复位。

## 追加（2026-10-09）：自动旋转时序修复
| 文件 | 内容 | 还原方式 |
|---|---|---|
| `iio-sensor-proxy.initd` | 覆盖 `/etc/init.d/iio-sensor-proxy`：加 `start_pre()` 等 QRTR svc 400（SSC）就绪再拉起（封顶 60s）、`after hexagonrpcd-adsp-sensorspd` | restore.sh 已在装包后 `install -m755` 覆盖 |

根因：本 build 的 iio-sensor-proxy 经 SSC/QRTR 后端（`/sys/bus/iio` 恒空但 `HasAccelerometer=true`）；SSC 加速度计要 ADSP 起来出 svc400（冷启数十秒）。iio 3.9「只扫一次即放弃」（G1-34），若开机时 proxy 抢在 svc400 之前起，`net.hadess.SensorProxy` 整轮无加速度计 → phosh `rotation-manager` 停 `MODE_OFF` → 自动旋转 tile 置灰、方向锁死。修复=proxy 等 svc400 再起。设备侧运行时已改（备份 `/etc/init.d/iio-sensor-proxy.bak-timing-*`）；**待下次冷启最终验证**。UI 说明：phosh 无独立“自动旋转”开关，只有“方向锁定”tile（自动旋转开着时不显示方向选择栏），属 phosh 正常模型。

## 追加（2026-10-11）：用户态显示修正 + 自动旋转磁贴（phoc/phosh）

| 文件 | 内容 | 还原方式 |
|---|---|---|
| `userland-display/install-on-device.sh` | 装构建依赖 + 下载官方 release 源码 + 打补丁（0001/0002；0003 已撤销）+ 重编 + 备份/替换 `/usr/bin/phoc`、`/usr/libexec/phosh` + 清除已撤销的 auto-rotation 插件 + 写 marker（`display3-norot`） | restore.sh 已自动调用；跳过＝`SKIP_USERLAND_DISPLAY=1` |
| `userland-display/build-phoc-phosh.sh`、`000{1,2}-*.patch`、`alpine-phosh-*.patch`、`build-deps.txt` | 构建脚本 / 补丁 / 依赖清单（**真源 = 仓库 `patches-userland/`，此处为设备侧副本**） | 由 install 脚本使用 |

- 三个改动：①phoc 只认 preferred mode ⇒ 非 preferred 刷新率档被忽略（屏恒 165 Hz）；②phosh `GetCurrentState` 上报的 scale 不在 `supported_scales` 里 ⇒ g-c-c 比例行显 100%；③~~新增「自动旋转」快速设置磁贴~~ **已撤销（2026-10-19，内置磁贴已覆盖，重复）**。
  根因/证据：`reports/userland-display-scale-refresh-20261011.md`、`reports/userland-auto-rotation-toggle-20261011.md`、`PITFALLS` #182/#77。
- ⚠️ **`userland-display/` 与 `patches-userland/` 是两份拷贝**（设备侧无法访问仓库）。改了 `patches-userland/` 里的任一文件，要**同步**到 `userland-display/`（反之亦然）。
- ⚠️ 这些二进制/插件是**非包管理**的；后续 `apk upgrade` 会把 `phoc`/`phosh` 换回原版（upstream 未合并前），需重跑 install-on-device.sh。

## freeze-trace（2026-10-09 新增，PITFALLS #106 死挂取证）

- `freeze-trace.conf` → `/etc/sysctl.d/99-freeze-trace.conf`：`softlockup_panic=1`、`softlockup_all_cpu_backtrace=1`、`panic=20`、`sysrq=1`。本机 APSS 硬看门狗被永久禁用，死挂永不自复位；这四项把它变成「panic → 20 s **暖**复位 → ramoops 留全 CPU 栈」（断电会丢 ramoops）。
- `pstore-catch.initd` → `/etc/init.d/pstore-catch`（boot runlevel）：挂载 pstore 并把记录带时间戳归档到 `/var/log/pstore/`（只留最近 10 份），这样后续任何断电都不会丢掉已抓到的现场。
- 判读：`ls /var/log/pstore/`；关掉：删 sysctl 文件 + `sysctl -w kernel.softlockup_panic=0 kernel.panic=0`。
- 已在 U2 生效并回读核实（1/1/20/1；服务 `pstore-catch | boot`；`/etc/sysctl.conf` 改前备份在 `/root/`）。
