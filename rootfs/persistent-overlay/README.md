# persistent-overlay — 持久根「非包管理」状态快照

来源：2026-10-06 从 U2 持久根（`/dev/sda17`，`linux17`）直接采集。
用途：持久 rootfs **无脚本化构建**；重建时用本目录还原「不随 apk 包走」的改动。
（遵守 AGENTS.md：迁移只搬 **数据/经验**，环境在目标机重建；包版本漂移可接受，目标是**包集合**与手写配置。）

**一键还原**（设备上 root）：
```sh
ssh root@192.168.7.1 'sh -s' < rootfs/persistent-overlay/restore.sh
```

| 文件 | 内容 | 还原方式 |
|---|---|---|
| `apk-world.txt` | `/etc/apk/world`（120 行） | `apk add $(cat …)`（restore.sh 已做） |
| `usr-local-sbin.tar.gz` | `/usr/local/sbin/`（自研脚本，**排除 `.bak*`**） | `tar xzf - -C /usr/local/sbin --owner=0 --group=0` |
| `etc-local.d.tar.gz` | `/etc/local.d/elden-bringup.start`（OpenRC `local` 载荷） | 解到 `/etc/local.d` |
| `etc-conf.d.tar.gz` | `/etc/conf.d/greetd`（`LIBSEAT_BACKEND=seatd`） | 解到 `/etc/conf.d` |
| `etc-greetd.tar.gz` | `/etc/greetd/config.toml` | 解到 `/etc/greetd` |
| `etc-NM-conf.d.tar.gz` | `99-unmanaged.conf`（usb0/lo unmanaged） | 解到 `/etc/NetworkManager/conf.d` |
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
