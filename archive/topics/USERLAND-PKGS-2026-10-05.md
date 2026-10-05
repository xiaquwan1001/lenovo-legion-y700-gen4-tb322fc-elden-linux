# USERLAND-PKGS-2026-10-05：用户/系统服务包补全（实机执行记录）

> 承接 `archive/topics/USERLAND-STACK-2026-10-05.md`（U1–U14 清单 + 会话 overhaul 决定）与 `MERGE-2026-10-05.md` §2。
> 本文件记录**在 U2 实机（b 槽持久直启）上补全系统/用户服务必要包**的过程与结果；设备锁串行、未改内核/DT。
> 证据层（只增不改）；结论以领域层为准。

---

## 0. 一句话结论

用户态会话缺的**服务包已补齐**：`xdg-desktop-portal(+gtk,+wlr,document)`、`gvfs`、`rtkit`、`xdg-user-dirs`、
`gnome-bluetooth`、`pipewire-spa-bluez`、`pam-rundir`；并修好 greetd 前置权限（`/var/lib/greetd` 归属）。
实测这些服务在本会话内可 **D-Bus 激活并运行**（portal/gvfs/rtkit 均 PID 在）。**套餐已具备会话 overhaul（greetd）条件**，
但"启用 greetd + 建登录用户"属账号/登录面变更，**待用户拍板**（见 §4）。

---

## 1. 设备基线（执行前）

- U2，b 槽持久直启；`uname -r = 7.2.0-debug-vk47clean-gbd114ca335e1`；`/` = `/dev/sda17` ext4（188.9 G，用 8.7 G）。
- Alpine **3.24.2**，`/etc/apk/repositories` = 阿里云 `latest-stable`（HTTP，故 1970/校时不影响装包）。
- 会话 = **legacy ad-hoc 路径**：`/etc/elden-session = phosh`；`start-desktop.sh` 手拉 udevd/seatd/dbus/elogind + `phosh-session` 循环。
- `apk world` = **94 行 / ~693 包**；PAM 底座在 `/usr/lib/pam.d/base-*`（vendor dir，`include base-*` 可解析，含 `pam_elogind.so`）。
- 已装（会话相关）：`phosh/phoc`、`gnome-session`、`elogind`、`seatd`、`pipewire(+pulse,alsa)`、`wireplumber`、
  `upower`、`polkit-elogind`、`networkmanager`、`bluez`、`chrony`、`gnome-keyring`、`accountsservice`、`feedbackd`、`greetd`、`greetd-phrog`。

## 2. 本次补装（`apk add`）

```sh
# 用户服务 / 会话后端
apk add xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
        xdg-document-portal xdg-user-dirs gvfs \
        rtkit gnome-bluetooth pipewire-spa-bluez
# PAM 运行目录助手（base-session 引用；elogind 之外的兜底）
apk add pam-rundir
```

连带 28+ 包（obexd-enhanced、fuse3、libblockdev 依赖链等）。`apk world` 94 → **103 行**；安装包 693 → **721**。
装包耗时：`apk update` 18 s；批次安装 <10 s（**无需主机侧离线 fetch**——设备直连阿里云 HTTP 镜像可用）。

| 包 | 作用 | 对应问题 |
|---|---|---|
| `xdg-desktop-portal` + `phosh-portalsconf` | 门户框架；`phosh-portals.conf` 选定后端（ScreenCast=wlr / Screenshot=gtk|wlr / Secret=gnome-keyring / Access=phosh-shell） | 应用文件选择/截图/共享 |
| `xdg-desktop-portal-gtk` | GTK 门户后端（默认） | — |
| `xdg-desktop-portal-wlr` | wlroots 截图/投屏后端（phoc） | — |
| `xdg-document-portal` (+fuse3) | 文档门户（Flatpak/文件授权） | — |
| `gvfs` (+fuse) | 用户态文件系统 daemon | 文件管理器/挂载 |
| `rtkit` | PipeWire 实时优先级 | 音频 XRUN/Jitter（#90 相关） |
| `gnome-bluetooth` (+obexd) | 蓝牙设置面板/OBEX | BT 用户态（G1-7） |
| `pipewire-spa-bluez` | PipeWire 蓝牙音频 profile | BT 音频 |
| `xdg-user-dirs` | `~/Pictures` 等标准目录 | — |
| `pam-rundir` | `base-session` 引用的 PAM 助手 | 会话 XDG_RUNTIME_DIR 兜底 |

## 3. 实测验证（执行后）

- `xdg-desktop-portal` 已在会话 bus 激活运行（PID 4146）；`gvfsd`（PID 4175）、`rtkit-daemon`（PID 4186）在跑。
- system bus：`org.freedesktop.login1`（elogind）在；rtkit 可经 system bus 激活（uid 109）。
- 会话 bus 上 `org.freedesktop.portal.Desktop`、`org.freedesktop.impl.portal.desktop.{gtk,wlr}` 均为 activatable。
- `phosh-portals.conf` 安装于 `/usr/share/xdg-desktop-portal/`。
- 桌面未受影响：`phoc/phosh/gnome-session-binary/pipewire/wireplumber` 全在；`df` 仍 5%，无异常 dmesg。
- **修复前置**：`chown greetd:greetd /var/lib/greetd`（原为 `root:root 750`）——这正是上一轮 greetd 报
  `unable to set working directory: Permission denied` 的直接原因。

> 未装（判定为"非当前必要"）：`udisks2`（可移动存储挂载，gvfs 后端；TF 卡未修好，暂缓）、`gnome-software`+`apk-polkit`（图形装包）、
> `modemmanager`/`ofono`（无 Modem，WiFi 版）、`iio-sensor-proxy`（SLPI 传感器已放弃）、polkit-gnome（**phosh 自带 agent**，避免双 agent）。

## 4. 待决策（账号/登录面，需用户拍板）

**目标**：启用 `greetd+phrog+elogind` 真会话（清 U1 亮度 / U2 PIN / U5 seatd / U7 dconf）。
现状：`greetd`/`greetd-phrog` 已装、`start-desktop.sh` 已有 `greetd` 分支（`/etc/elden-session` 切换）、`/etc/phrog/greetd-config.toml` 就绪；
**但系统当前无普通用户**（仅 root），而 phrog 是"登录 greeter"，需要一个可登录账号（PIN）。

两条路（**都涉及账号/登录，需授权**）：
- **A. greetd `initial_session` 自动登录 root**：最小改动、无 greeter、立刻拿到 elogind 会话；
  但 root 会话 + 无 PIN，属降级安全面。
- **B. 建普通用户（如 `elden`, uid 1000）+ phrog greeter PIN 登录**：更接近目标形态，
  但需迁移 `/root` 下的 dconf/配置、给用户补 `video/render/input/audio/seat` 组，改动面较大。

另：`LIBSEAT_BACKEND=seatd` 必须固定（有案例：logind 后端会 deactivate session → phoc 释放 DRM → 关 CRTC 挂面板，类 Q24）。

## 5. 复现（包补全部分）

```sh
# 设备侧（root，持久根）
apk update
apk add xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
        xdg-document-portal xdg-user-dirs gvfs rtkit gnome-bluetooth \
        pipewire-spa-bluez pam-rundir
chown greetd:greetd /var/lib/greetd && chmod 750 /var/lib/greetd
```

> ⚠️ 持久 rootfs 目前**没有脚本化构建**（`rootfs/` 是早期 RAM 根树）；上述命令应纳入将来的 rootfs 重建流程，
> 否则重建会丢失本批包。

## 6. 出处

设备实测（`scripts/device-lock.sh` 持锁执行）；包/版本见 `pkgs.alpinelinux.org`（Alpine 3.24 stable）；
`/usr/lib/pam.d/base-session`（`pam_elogind`）、`/etc/phrog/greetd-config.toml`、`/usr/libexec/phrog-greetd-session`（设备实物）。
关联：`USERLAND-STACK-2026-10-05.md`、`PITFALLS.md` #48–#53/#70–#77/#89/#100。

---

## 7. 会话 overhaul = 路径 A（greetd initial_session 自动登录 root）——已落地上机

> 用户 2026-10-05 选 A（先不建普通用户；日后遇到真实安全/认证需求再建）。

**改动**（`scripts/greetd-initial-session.sh` 新增；`scripts/start-desktop.sh` greetd 分支重写）
- `/etc/greetd/config.toml`：`[terminal] vt=7` + `[initial_session]`/`[default_session]` 均指向 `/usr/local/sbin/elden-session-root`、`user=root`。
  **坑**：greetd 没有 `[default_session]` 时**直接启动失败**（`no default_session specified`）——`initial_session` 不能单独存在。
- `/usr/local/sbin/elden-session-root`：导出 `LIBSEAT_BACKEND=seatd` + XDG/HOME，`exec /usr/bin/phosh-session`。
- `start-desktop.sh`：greetd 分支改为优先 `/etc/greetd/config.toml`，并用 `while true` 重启 greetd（裸 `exec` 一旦 greetd 退出即无会话）；顺带修 `pgrep -x elogind-daemon`→`elogind`（原判据永不匹配、会重复拉起）。

**验证（重启后自动生效，uptime ~39 s）**
| 判据 | 结果 |
|---|---|
| 自动启动 | dmesg `[10.1] [start-desktop] launching greetd (/etc/greetd/config.toml)` |
| 真 logind 会话 | `loginctl list-sessions` = **c1 / root / seat0 / tty7 / active**；`/run/user/0` 建立 |
| 会话服务 | phoc/phosh/gnome-session + 24 个会话服务（portal/gvfs/pipewire/wireplumber）挂在 cgroup `c1` |
| **U1 亮度** | `org.freedesktop.login1.Session.SetBrightness backlight aw99706-backlight 1800` → sysfs 511→**1800**（此前无 session 时恒 `EISDIR`） |
| PAM 底座 | `/usr/lib/pam.d/base-session` 含 `pam_elogind.so`（vendor dir，`include base-*` 可解析） |
| 无面板异常 | dmesg 无 drm/dsi/watchdog 复位；`idle-delay=0` 规避保留 |

**仍待**：U2（锁屏 PIN，root 自动登录下不触发）、U5/U7 属自动通过；U8（GTK3 深色/accent，与 session 无关）仍待单独落 dconf。**TF 卡**：`udisks2` 已装（gvfs 已能枚举 UFS 卷），但**卡未插入**（无 `/dev/mmcblk*`、`mmc_host/mmc0` 下无卡），待插入后测。

**回退**：`sh /usr/local/sbin/greetd-initial-session.sh phosh` + 重启（或直接 `echo phosh > /etc/elden-session`）。
