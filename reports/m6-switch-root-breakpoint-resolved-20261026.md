# M6 / T19 断点已解：不是 switch_root 内部，是 Debian 根缺 `switch_root` symlink

> 2026-10-26 深夜，**零写盘**（只 `mount -o ro` 读 `linux17`）。前置：设备在机跑 `vk173`/`linux18`。
> 关联：`TASKS` T19、`reports/m6-debian-candidate-boot-nousb-20261026.md` §6/§6.2（本报告推翻其主假设）。

## 0. 结论（先数字）

- **断点不在 busybox `switch_root` 内部**：`exec switch_root /newroot /init` **成功**，磁盘 `/init` **确实跑起来了**（PID 1）。
- 真正原因 = **Debian 根没有 `switch_root` 这个可执行文件/符号链接**（`/bin/busybox` 有该 applet，但 `busybox` 包不装 applet 链接）⇒ 磁盘 `/init` 的 **preflight 第一屏就 abort**，落进 rescue shell；
  而 PID 1 无 tty ⇒ 全静默，看起来像"卡在 switch_root"。
- 该证据本来就在磁盘上（`vk171-swrerr` 那发已写成），此前因设备卡死无法读取 ⇒ 本轮只需 `mount -o ro` 读回，**不需要再起一发**。

## 1. 决定性证据（`linux17:/var/tmp/elden-init-trace.log`，874 B，逐字末尾）

```
elden-init/ram t=0.94 mount start dev=/dev/sda17 fstype=ext4
elden-init/ram t=0.95 mount ok entries=20
elden-init/ram t=0.95 newinit /init size=30067
elden-init/ram t=0.96 move /dev
elden-init/ram t=0.96 move /proc
elden-init/ram t= all mounts moved
elden-init/ram t= exec switch_root /newroot /init
[init] FATAL: missing essential tool(s): switch_root
[init] FATAL: this initramfs/rootfs is incomplete - check the applet symlinks
[init] FATAL: dropping to rescue shell (PID 1): missing tools: switch_root
/bin/sh: 0: can't access tty; job control turned off
#
```

判读（三条互相独立地排除旧假设）：
1. `[init]` 前缀 = `initramfs/init` 自己的 `fatal()`；**它跑在磁盘阶段**（RAM 阶段 preflight 早已通过，否则不会有上面 10 行 trace）。
2. 磁盘阶段的 trace 一行都没有 ⇒ 不是"磁盘 `/init` 首行挂"，而是**preflight 在 `trace()` 之前**（`initramfs/init` 第 100–118 行 vs `trace()` 定义在第 57–82 行，fd 9 由 RAM 阶段 `exec 9>>…` 打开并被 exec 继承）。
3. `exec switch_root … 2>&9`（`initramfs/init:403–407`）把**磁盘 `/init` 的 stderr** 也写进同一文件 ⇒ 上面 3 条 FATAL 就是这么来的；`/bin/sh: can't access tty` = `rescue()` 的 `exec /bin/sh` 生效。

## 2. 直接核对目标根（`linux17`，`mount -o ro`）

| 工具 | 结果 |
|---|---|
| `sh mount umount mkdir cat sleep grep findfs blkid chroot` | **全部在位**（`/bin`、`/sbin`） |
| `switch_root` | **缺失**（`/bin`、`/sbin`、`/usr/bin`、`/usr/sbin` 均无） |
| `busybox --list` | **含 `switch_root` applet**（`/bin/busybox` 985 920 B，`busybox` 包只装二进制、不装 applet 链接） |

⇒ `initramfs/init` 的 preflight 用 `command -v` 查名字，PATH = `/usr/local/sbin:…:/sbin:/bin`，**名字不存在 ⇒ 判"根不完整"**。

## 3. 为什么此前 8 发全静默、且"Debian 根用户态不可执行"的排除项仍然成立

- 旧排除项（`chroot … chroot-exec-ok`、`dash -n /init` 通过、ext4 t=0.97 挂上）**全部有效**——问题不在用户态能否执行，而在**一个名字缺链接**。
- `T19` 曾把断点定在"busybox `switch_root` 内部（递归删旧树 / mount --move / chroot / exec）"。**该假设作废**：switch_root 的四步全过，甚至已把控制权交给新 `/init`。

## 4. 修法（两条都要，成本都很低）

1. **staging 侧（根因）**：`rootfs/debian/stage.sh` 造 `/sbin/switch_root -> ../bin/busybox`（或 `busybox --install` 的受控子集），并在门禁 A–F 里加一条"`/init` preflight 清单全部 `command -v` 命中"——否则同类缺链接会在别的名字上再犯。
2. **`initramfs/init` 侧（韧性）**：preflight 增加 applet 回退——`command -v` 失败但 `busybox --list` 命中时，定义同名 shell 函数转调 `busybox <applet>`，避免"能力在、名字不在"被当成根损坏（本次正是这种情形）。

## 5. 复验方式（待做，需一次 `fastboot boot`）

按 §4 改完后重建 Debian 根候选镜像 + `/init`，`fastboot boot` 后判据 = `linux17:/var/tmp/elden-init-trace.log` 出现
`elden-init/disk …` 行（磁盘阶段 trace 开始写）且**无** `missing essential tool(s)`；失败则看 switch_root/exec 的真实 stderr（同一条 fd 9 通道）。

## 6. 产物 / 取证指针

- 读回证据：本报告 §1（原文来自 `linux17:/var/tmp/elden-init-trace.log`，设备侧 `mount -o ro /dev/disk/by-label/linux17`）
- 诊断镜像：`out/boot-elden-vk171-swrerr.img`（sha `551ac3a848aedd35…`）
- 代码位置：`initramfs/init:57–118`（trace/preflight）、`initramfs/init:392–410`（switch_root 段）、`rootfs/debian/stage.sh`

---

## 7. ★ 上机验证（2026-10-26 21:25，vk174，零写盘）

**结论：§4 的修法在真机上**成立**——`switch_root` 与磁盘 `/init` preflight 全部通过；阻塞点已前移到 systemd 阶段。**

### 7.1 现场（主机侧 USB 时间线）

| 时刻 | 事件 |
|---|---|
| 21:24:53 | `fastboot boot out/boot-elden-vk174.img`（先 `slot-attr.py mark-successful b` 把 retry 顶回 7） |
| 21:25:05 | `Booting OKAY`（ABL 交棒） |
| 21:25:12 | 主机 `USB disconnect`（载荷接管） |
| 21:26:53 | `1d6b:0104` 复合 gadget 出现 —— 但这是**回落后的 Alpine（linux18）**，不是 Debian 根 |

即：Debian 根这次**没有**在本机复现「usb 全无 → 物理 POR」的老现象；设备约 95 s 后自行复位回 `boot_b`。

### 7.2 决定性证据（`linux17:/var/tmp/elden-init-trace.log`，715 B）

```
elden-init/ram  t=1.02 newinit /init size=33504        ← 新 /init 已生效
elden-init/ram  t= all mounts moved
elden-init/disk t=1.08 start on_initramfs=0 mode= roottype=ext2/ext3
elden-init/disk t=1.09 camera-modules-load start
elden-init/disk t=1.10 payload-modules-load start
elden-init/disk t=1.13 handoff to /sbin/init (systemd)
```

- **磁盘阶段 trace 开始写了**（旧事故里一行都没有）⇒ preflight 通过；
- **没有** `missing essential tool(s)` ⇒ 根因确实只是 `switch_root` 缺链接；
- `dmesg` 快照（`linux17:/var/log/elden-boot.log`）同步印证：`switching root to /dev/sda17 (/init)`、`newinit … sha=330ab62bec60`、`[init] Alpine rootfs up, kernel …vk172`。

### 7.3 新阻塞点（systemd 阶段），两条都可低风险验证

1. **模块树 UTS 不匹配**：`linux17:/lib/modules/` 只有 `…-debug-vk163`，而跑的是 `…-debug-vk172` ⇒ **DRM/显示模块完全加载不了**（无 `card0`），相机也是同样原因报了 `no modules`；
2. **恢复通道仍在交接之后**：`/init` 的 usb0 gadget 在后台子 shell 里拉起，而 PID1 在 **t=1.13 s** 就交给 systemd ⇒ systemd 一旦早期失败，主机侧依旧全静默（本次即如此：无 `1d6b:0104`、journal 未落盘、`/var/log/journal` 仍是 10-17 的旧文件）；
3. 复位时机 ~95 s ≈ `q28-boot-watchdog` 的 `Q28_WD_WAIT=75` + systemd 启动时间——**但该 watchdog 本次没有留下日志**（`/var/log/q28-watchdog.log` 仍是 10-17 那行），所以「watchdog 触发复位」只是候选，未坐实。

### 7.4 下一发（vk175）配方

- cmdline 追加 **`elden_early_gadget=1`**（RAM 阶段就起 gadget ⇒ 系统起不来时仍有 ttyACM0 + SSH）与 **`elden_q28_nowd`**（排除 watchdog 变量）；
- 先把 `out/modstage-vk172/lib/modules/<vk172 UTS>` 铺到 `linux17`（修 7.3-①）；
- 其余（内核/DTB/`/init`）保持不变，仍 `fastboot boot` 零写盘。

---

## 8. Debian 根到桌面（2026-10-26 22:2x，同一 vk175 镜像，零写盘）

修完下面 6 条后，`fastboot boot out/boot-elden-vk175.img` **全自动**起桌面（无任何人工步骤）：

| 判据 | 结果 |
|---|---|
| 根 | `ext4 /dev/sda17`（linux17） |
| PID 1 | `systemd`（`is-system-running=degraded`，另有 3 个已知失败单元） |
| greetd | `active`；`ExecStart=/usr/sbin/greetd --config /etc/greetd/config.toml` |
| 桌面 | `phoc -v -S -C /usr/share/phosh/phoc.ini -E gnome-session --session=phosh` + `/usr/libexec/phosh`（Phosh 0.58.0） |
| 会话 | `c1 1001 xuqianhui1001 seat0 1296 user tty7 yes`（**不是 greeter**） |
| 显示 | `card0-DSI-1 = connected/enabled`，背光 1024 |
| 槽位 | `qbootctl Result=success`（PITFALLS #181 风险消除） |
| WiFi | `wlp1s0 114.214.193.59/22`（`net-up` → `success`） |

### 8.1 六条根因（每条都是**静默失败**，全部已修，详见 PITFALLS #423–#428）

| # | 症状 | 根因 | 修法（已落地） |
|---|---|---|---|
| 1 | `chroot: /bin/sh: No such file or directory` | overlay 用普通 `tar` 解包，把 usr-merge 的 `/lib -> usr/lib` **换成真目录** | `install-overlay.sh`：`tar --keep-directory-symlink` + 解完断言 `/bin /sbin /lib` 仍是链接 |
| 2 | greetd 等 5 个服务 `203/EXEC` | 单元 `ExecStartPre=/usr/local/libexec/elden/*.pre` 而该文件**从不安装**；且 hook 本体是**无 shebang 的片段** | `stage.sh` 安装 hooks 并**补 `#!/bin/sh`**；新门禁 **D2**（`Exec*` 路径必须在 overlay∪PKGROOT 存在、hook 必须带 shebang） |
| 3 | 同上，`_greetd` vs `greetd` | Debian 用户名叫 `_greetd` | `hooks/greetd.pre` 两个名字都试，owner 用解析结果 |
| 4 | 只停在 phrog 登录界面（`phoc --session=phrog`） | Debian 包 `greetd-phrog` 的 `/usr/lib/.../greetd.service.d/phrog.conf` 覆盖 ExecStart | overlay 写 `zz-elden.conf`（**排序必须晚于 `phrog.conf`**，`10-` 会被盖掉）+ 空 `ExecStart=` 清列表 |
| 5 | greetd 每 5 s 自杀：`configured default session user 'xuqianhui1001' not found` | debootstrap 根里**根本没有桌面用户** | `ensure-desktop-user.sh`（uid 1001、组按发行版过滤）+ 接进 `build-rootfs.sh` |
| 6 | `net-up.service failed`、`wlan0 never appeared` | 接口名 Debian 是 `wlp1s0`，且**开头只探测一次**（ath12k 异步 ~9–21 s 才出 phy） | `net-up.sh`：循环内反复探测 + `WIFI_IF` 覆盖；`/etc/conf.d/greetd` 去 `export`（systemd EnvironmentFile 不认，整条变量丢失）→ 记 `overrides.tsv` |

### 8.2 仍然失败/未做的（Debian 根，非阻塞桌面）

- `hexagonrpcd.service`：`Could not open FastRPC node (/dev/fastrpc-adsp)` ⇒ 传感器链在 Debian 根上没通（Alpine 侧由 `/init` 建节点/加载 adsp 相关模块）。
- `accounts-daemon.service` failed（gdm/accountsservice 依赖项，待查）。
- `lxc-net.service` failed + Waydroid 未部署在 Debian 根（G2 在 Debian 上的后续工作）。
- `elden-hapticd` 缺：设备侧静态二进制未入库（MANIFEST `repo_src=-`，T14 债务）；门禁 D2 以 WARN 点名。
- `usb0` 网络：Debian 根**不跑 udhcpd**，主机侧要手工 `ip addr add 192.168.7.9/24 dev <usbnet>` 才能 SSH（Alpine 侧有 udhcpd）。建议把 udhcpd 加到 Debian 单元或改静态对端地址。

### 8.3 冷起验收（2026-10-26 22:31 `fastboot boot vk175`，第 2 次独立复现，全自动）

```
root: ext4 /dev/sda17   uptime=407s
phoc(phosh)=2  /usr/libexec/phosh=2
c1 1001 xuqianhui1001 seat0 1392 user tty7 yes
wifi: 114.214.227.153/21     (net-up=success)
qbootctl=success  greetd=active
failed(仅 3): accounts-daemon / hexagonrpcd / lxc-net
```

⇒ **Debian(Mobian 方向) 根已在主线上「自动登录 → phosh 桌面 + WiFi + 槽位自标成功」跑通**，
两次独立启动结果一致。仍缺的三项见 §8.2。

---

## 9. 电源/电量 + usb0 lifeline 收口（2026-10-26 22:54，vk176，冷起全自动）

| 判据 | 结果 |
|---|---|
| 根 / 桌面 | `ext4 /dev/sda17`；`phoc --session=phosh` ×2、`/usr/libexec/phosh` ×2、会话 `c1 1001 … seat0 tty7 user` |
| **电量** | `/sys/class/power_supply/qcom-battmgr-bat` = `86 / Charging`（驱动一直正常）；`upower` 现已 active：`present yes / state charging / energy 25.2 Wh / 86%` |
| **usb0 lifeline** | 主机 **10 s 自动 DHCP 拿到 192.168.7.9/24**（`udhcpd` 由 `/init` 的 `usb0_dhcp()` 用 busybox applet 起，2 个实例；`/etc/udhcpd.conf` 无默认网关） |
| WiFi | `wlp1s0 114.214.193.209/22` |
| greetd / 槽位 | `active` / `qbootctl Result=success` |
| 失败单元 | **仅 2 个**：`accounts-daemon`、`lxc-net`（`hexagonrpcd` 本轮已 OK） |
| 启动速度 | 桌面在 **uptime ≈ 13 s** 内就起来了（greetd 不再陷入 5 s × N 重启退避） |

### 9.1 两条根因（详见 PITFALLS #429/#430）

0. **用户目视确认（2026-10-26 23:0x）**：phosh 顶栏**已显示电池图标与百分比** ⇒ UPower→phosh 的
   整条链闭合，不只是"数据可读"。
1. **电量**：`qcom_battmgr` 正常、sysfs 正常，缺的是 **`upower` 包**（phosh 走 UPower over D-Bus）；
   且 Debian 的 `upower.service` 是 D-Bus 激活型、postinst 不 enable ⇒ 必须在 overlay 里挂进
   `graphical.target.wants`。已加进 `pkgmap.tsv`（apt-list 第 100 行）+ 门禁 G 断言。
2. **usb0 地址**：Debian 的 busybox 有 `udhcpd` applet 但无符号链接 ⇒ `/init` 直接调 `udhcpd` 静默失败，
   主机侧表现为「USB 网卡永远没有 IPv4」。已加 `usb0_dhcp()`（路径 → applet → /run 内联配置），
   并在 Debian 根落 `/etc/udhcpd.conf`；主机侧一条 NM 配置（`elden-usb-gadget`，DHCP）即可持久自动。

### 9.2 仍缺

- `accounts-daemon`（Debian 侧 accountsservice，供 GNOME/Phosh 用户信息；不影响桌面与电量）
- `lxc-net` + Waydroid 未部署在 Debian 根
- `elden-hapticd` 设备侧静态二进制未入库（T14 债务）
