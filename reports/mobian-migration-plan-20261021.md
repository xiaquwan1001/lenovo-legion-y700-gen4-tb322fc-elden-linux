# Mobian（Debian + Phosh）迁移可行性评估与方案 — 只读研究，2026-10-21

> 只读 lane：未改 SSOT、未动设备（设备停在 fastboot `HA2EXB0E`，本 lane 全程未执行任何 fastboot/adb/EDL/reboot）。
> 证据口径：每条结论后给 `路径:行号` 或 `命令 → 输出摘要`；标注【已证实】【未证实】【推测】。
> 写作顺序：先落骨架 → 分节 append（§1→§2→§3/§4/§5/§6）→ 最后回填 §0。
> 结论优先级：§0 是摘要，冲突时以正文（§2 矩阵 / §5 风险）为准。

## 0. 结论

**技术上可做，但不该现在做；若做，只走「原地换 rootfs + forky/sid」这一条，且先用路线③探路。**

1. **Mobian 对本机不是「装一个镜像」**：Mobian 支持设备列表无 SM8750 类（`wiki.debian.org/Mobian/Devices`），且 `mobian-recipes/devices/qcom/configs/` 只有 `sc7280/sdm670/sdm845/sm6350/sm7150/wip`（**无 sm8750**，salsa API 实测），加上 Mobian 明确「不打包重设备特定内核」（`wiki.debian.org/Mobian/Porting`）⇒ 只能「自建 Debian rootfs + 保留自编内核」，Mobian 仅作包集合参考。（§4 S1）
2. **内核/模块树/AVB 全部不变**：Debian 任何 `linux-image` 都不能启动本机（`sm8750.dtsi` 在 v6.12=**404**、v6.14 才 200；`sm8750-lenovo-elden.dts` 上游 v6.15/v6.17 均 **404**；v6.17 Makefile 只有 `sm8750-mtp/qrd`）⇒ boot.img/vbmeta 不用碰，消除最大一类风险。（§2 #1、§3.1）
3. **必须选 forky/sid，不能选 trixie**：trixie 的 `iio-sensor-proxy 3.7-3` 源码**无 `drv-ssc-*.c`**，而本机 `/sys/bus/iio` 恒空（传感器在 SSC 上）⇒ 传感器必死；`libssc` 与 `iio-sensor-proxy 3.9-1`（`Build-Depends: libssc-dev (>= 0.4.0) [arm64]`）只在 forky/sid。（§2 #6）
4. **成本集中在用户态重写**：7 类 systemd unit（含 `PITFALLS #181` 的 qbootctl、`#318` 的 greetd 守护、G1-36 的 150 s 扫描 timer）、120 行 apk 清单翻译、自建 firmware 包（Debian `firmware-qcom-soc` 无 `sm8750`）、两枚 phoc/phosh 补丁 rebase。**发行版本身（debootstrap）反而是最便宜的一步**。（§4）
5. **三条路线**：① 原地换 rootfs 唯一合理（不动 GPT/AVB，回退靠纯 RAM 启动 + 3.44 GB 归档）；② 新分区并存要先缩 `userdata`（不可逆）或回收 Android 分区（前置 EDL 备份）⇒ 代价大于收益；③ 只换桌面栈不满足目标，但**应作为 ① 的前置探路**。（§3）
6. **最大 3 个风险**：R1 AB 槽 retry 归零卡 fastboot（`slot-attr.py` 基线 + `systemctl enable qbootctl`）；R2 唯一 rootfs 被覆盖后无 live 回退（移入 `old-root/` + 3.44 GB 归档 + 回退通道事前实测）；R3 仅当改 boot.img 时的 AVB 链/模块树错配（本方案不动 boot.img，从源头规避）。（§5）
7. **与既有裁决的关系**：`INDEX.md:134`「不切 glibc、不切 systemd」的核心理由（当前卡点全是内核/显示链，`reports/init-systemd-vs-openrc-20261011.md:24-33`）**未被推翻**；本轮新增的只是「若确实要 Debian，这是唯一的做法与代价」+ 一条对 Debian 有利的新事实（Waydroid 已进 Debian 官方归档：trixie-backports 1.6.3+ds-2~bpo13+1 / sid 1.6.3+ds-3）。

### 关键数字

- **0** 个上游/发行版内核能启动本机（`sm8750.dtsi` v6.12=404；`sm8750-lenovo-elden.dts` v6.15/v6.17=404）。
- **2 个**包版本门：必须 forky/sid（trixie 的 iio-sensor-proxy 3.7 无 SSC 后端）；phoc/phosh 从 0.55 → **0.58.0**（sid）或 **0.46.0**（trixie，降级）。
- **7 类** systemd unit 需重写 + **120 行** apk 清单需翻译 + **1 个** 自建 firmware 包；boot.img/AVB/GPT **全部不动**。

## 1. 现状：设备当前用户态到底装了什么

> 本节只做「换发行版需要搬什么」的清点，不重复 `DEVICE`/`TASKS` 的状态口径。

### 1.1 发行版与 init（【已证实】）

- **发行版 = Alpine（musl）+ OpenRC**，内核 = 自编 mainline **7.3.0-rc7-debug-vk127…**（在机 `boot_b`），rootfs = `/dev/sda17`（`linux17`，ext4）。
  证据：`DEVICE/README.md:35`（vk127 已刷入 boot_b、`uname -r`=`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`）、`TASKS/README.md:43`（G1-32：PID1=`/sbin/init`(busybox)→inittab→OpenRC）。
- **init 交接链**：initramfs 的 `/init` 挂 ext4 → `exec switch_root /newroot /init`（磁盘根副本）→ 磁盘 `/init` 起生命线（usb0 gadget + `udhcpd` + `sshd` + ttyGS0/1）→ 末尾 `exec /sbin/init`。
  证据：`initramfs/init:234`（`mount -t ext4 … /newroot`）、`:236-238`（挑 `/init`→`/sbin/init`→`/bin/sh`）、`:247`（`exec switch_root`）、`:266/272/285`（usb-gadget/udhcpd/sshd）、`:355-361`（openrc 模式 `exec /sbin/init`）。
  ⇒ **这条链对发行版无偏好**：只要新 rootfs 有 `/sbin/init`，现有 ramdisk 就能交棒（见 §3 路线①的前提）。
- **OpenRC runlevel 清单**（换 systemd 必须逐条映射）：
  `SYSINIT="devfs procfs sysfs cgroups dmesg modules sysctl hostname"`；
  `BOOT="hwclock seedrng udev udev-trigger udev-settle localmount bootmisc"`；
  `DEFAULT="dbus elogind seatd greetd networkmanager wifi-scan-refresh bluetooth polkit rtkit udisks2 local"`。
  证据：`scripts/openrc-enable.sh:38-40`。

### 1.2 持久根「非包管理」状态（`rootfs/persistent-overlay/`，30 个条目）

`ls rootfs/persistent-overlay/ | wc -l` → **30**。分三类（【已证实】，逐条见 `rootfs/persistent-overlay/README.md` 表格）：

| 类 | 条目 | 换 Debian 后的命运 |
|---|---|---|
| **包集合** | `apk-world.txt`（**120 行**，`wc -l`） | 需整体翻译成 apt 清单（§2 矩阵） |
| **OpenRC 专属** | `etc-initd-greetd`、`etc-initd-wifi-scan-refresh`、`etc-initd-powerlog.tar.gz`、`elden-hapticd.initd`、`iio-sensor-proxy.initd`、`pstore-catch.initd`、`openrc-runlevels.txt`、`elden-init-mode.txt` | **全部作废**，需重写 systemd unit（§2 逐项） |
| **可移植（脚本/配置）** | `init`、`sbin-{poweroff,reboot,halt}`、`etc-greetd.tar.gz`（config.toml）、`etc-NM-conf.d/99-unmanaged.conf`、`etc-conf.d-elden-hapticd`、`net-selfheal.sh`、`q28-boot-watchdog.sh`、`usr-local-sbin.tar.gz`（`tar tzf` 实测 **47 个文件**，含 `slot-attr.py`/`cam-mode.sh`/`wifi-scan-refresh.sh`/`reboot2`）、`user-autostart/`（**4 个 .desktop** + README）、`userland-display/`（phoc/phosh 补丁+构建脚本） | 可直接搬；但脚本内 `apk`/`rc-service` 调用需改（`net-selfheal.sh` 的 `apk fix` 段落） |

### 1.3 自维护用户态补丁（换发行版后怎么落地）

- `patches-userland/0001-phoc-honor-any-mode.patch` → **phoc 0.55.1**，1 行（`if (head->state.mode && head->state.mode->preferred)` → `if (head->state.mode)`）。证据：`patches-userland/README.md:11,19-23`、patch 正文 `@@ -1943,7 +1943,7 @@`。
- `patches-userland/0002-phosh-report-supported-scale.patch` → **phosh 0.55.0**，新增 `phosh_head_snap_to_supported_scale()` 并用于 `GetCurrentState`。证据：`patches-userland/README.md:12`、`reports/userland-display-scale-refresh-20261011.md:29-33`。
- 0003（自动旋转磁贴）**已撤销**，不构成迁移负担。证据：`patches-userland/README.md:13`。
- 构建脚本硬绑 Alpine：`patches-userland/build-phoc-phosh.sh:14-15`（固定 `PHOC_VER=0.55.1`/`PHOSH_VER=0.55.0`）、`patches-userland/install-on-device.sh:33`（`apk add` 装 `build-deps.txt`）、`patches-userland/install-on-device.sh:48`（`rc-service greetd stop`）。⇒ **换 Debian 后这两个脚本不能直接用**（见 §2「显示」行）。

### 1.4 与已定案裁决的关系（只写差量，不重推）

- 既有裁决：**宿主 rootfs 不切 glibc、不切 systemd**（`INDEX.md:134`，理由=零收益/高重建成本，证据 `reports/libc-musl-vs-glibc-20261011.md`、`reports/init-systemd-vs-openrc-20261011.md`）。
- **本轮差量（2026-10-21 新增事实，不是重复论证）**：
  1. 该裁决的核心理由是「当前卡点（Q28/Q24/#106）全是内核/显示链，换 init 不能改善」——这一点**仍然成立**（`reports/init-systemd-vs-openrc-20261011.md:24-33` 逐条），本报告不推翻；
  2. 但 2026-10-19/20 之后用户态已从「会话账」推进到**具体栈验收**（C11 中文输入法上机通过、C10 马达、G1-36 WiFi 扫描），这些栈在 Debian 侧**依赖版本完全不同**（phosh 0.46/0.58 vs 0.55、iio-sensor-proxy 3.7 无 SSC 后端）⇒ 迁移成本比 10-11 评估时**更高**，不是更低；
  3. 唯一新增的「对 Debian 有利」的事实：**Waydroid 已进 Debian 官方归档**（trixie-backports 1.6.3、forky/sid 1.6.3）——`packages.debian.org` 查询结果，详见 §2「Waydroid」行。

## 2. A. 依赖差异矩阵（Alpine/OpenRC 现状 → Debian/Mobian）

> 版本基线（【已证实】，`packages.debian.org` 2026-10-21 查询）：
> **trixie(stable)** = Linux **6.12.113-1**、phosh/phoc **0.46.0**、squeekboard **1.43.1-1**、greetd **0.10.3-4**、iio-sensor-proxy **3.7-3**、hexagonrpcd **0.3.2-2**、qbootctl **0.2.2-1**、waydroid **1.6.3+ds-2~bpo13+1**（backports）；
> **forky/sid** = Linux **7.2.11-1**、phosh/phoc **0.58.0**、iio-sensor-proxy **3.9-1**（带 `libssc` 后端）、libssc **0.4.4-2**、hexagonrpcd **0.4.0-2**、waydroid **1.6.3+ds-2/3**。

| # | 依赖项 | 现状（Alpine 3.24 + OpenRC，已上机） | Debian/Mobian 侧 | 差异与结论 |
|---|---|---|---|---|
| 1 | **内核** | 自编 `7.3.0-rc7-debug-vk127…`（GEEKiDoS `v7.2-elden` + `patches/0001–0013` + 本地板 DTS） | trixie **6.12.113**（无 `sm8750.dtsi`）；forky/sid **7.2.11**（有 `sm8750.dtsi`，但**无 `sm8750-lenovo-elden.dts`**） | 【已证实】**Debian 任何 kernel 都不能直接启动本机**：`git.kernel.org` 实测 `sm8750.dtsi` 在 `v6.12`=**404**、`v6.14`=200；`sm8750-lenovo-elden.dts` 在 `v6.15`/`v6.17`=**404**，`v6.17` Makefile 只有 `sm8750-mtp/qrd`。⇒ **必须继续用自编内核**（Mobian 的 Debian 内核路线对本机不成立） |
| 2 | **模块树** | `/lib/modules/7.3.0-rc7-debug-vk127-…`，**1497 个 .ko**，vermagic 与 `uname -r` 逐字相等；`CONFIG_MODVERSIONS` **未开**（错配静默加载后 panic） | Debian 无对应包；内核包会带自己的 `/lib/modules/<deb 版本>` | 【已证实】`DEVICE/README.md:32`、`reports/kernel-abi-variants-20261020.md:16-24`。⇒ 模块树**照搬现有 tarball**（`out/m1-73-modules-*.tar.gz`），与 Debian 无关；风险是「换发行版时误装 Debian 内核包」→ 见 §5 R3 |
| 3 | **init** | OpenRC（busybox init → inittab → openrc）；`/etc/elden-init-mode` 双路径回退 | Mobian = **systemd**（phosh 依赖 `libsystemd0`，`packages.debian.org/trixie/amd64/phosh` 依赖表） | 【已证实】差异 = **26 个 runlevel 服务**重写（`SYSINIT` 8 + `BOOT` 7 + `DEFAULT` 11，`scripts/openrc-enable.sh:38-40`）。**回退优势**：`/etc/elden-init-mode` 分支机制天然允许「同一 rootfs 双 init」，可先并存 |
| 4 | **显示（phoc/phosh 版本与补丁）** | phoc **0.55.1**（内嵌 wlroots **0.20.0**，static）+ phosh **0.55.0**；两枚自维护补丁已上机 | trixie：phoc/phosh **0.46.0**（`phoc` 动态链 **libwlroots-0.18**，`phoc46 debian/control:17`）；forky/sid：**0.58.0**（`-Dembed-wlroots=enabled --default-library=static`，`phoc58 debian/rules:5`，与现役 Alpine 构建方式相同） | 【已证实】`sources.debian.org` 源码核对：**0001 的 bug 在 0.46 不存在**（`phoc46 output.c:1806-1808` 直接 `if (config_head->state.mode != NULL) wlr_output_state_set_mode(...)`，无 `preferred` 门；0.46 无 `phoc_output_config_head_to_output_config` 函数）；**0.58 仍有该 bug**（`phoc58 output.c:1946` 逐字同构 `if (head->state.mode && head->state.mode->preferred)`）。**0002 的 bug 两版都在**（`phosh46 monitor-manager.c:520`、`phosh58 monitor-manager.c:522` 都是 `(double)head->scale` 直报，无吸附）。⇒ trixie 只需 rebase 0002；forky/sid 需 rebase 0001+0002。**另**：`patches-userland/build-phoc-phosh.sh` 的 `apk add`/`rc-service` 段落要改写（§1.3） |
| 5 | **音频（PipeWire + AudioReach tplg）** | tplg = 自编 `Lenovo-Y700-Gen4-tplg.bin`（10436 B，`scripts/audio-tplg/out/`），**boot 早期从 initramfs 加载**，持久根副本在 `/lib/firmware/qcom/sm8750/`；UCM2 自写（`scripts/audio-ucm/install.sh` → `/usr/share/alsa/ucm2/Qualcomm/sm8750/…`）；PipeWire+WirePlumber | `firmware-qcom-soc`（trixie）**无 sm8750 目录**（filelist 实测：只有 sdm845/sm8250/sm8550/sm8650/x1e80100/sc8280xp）；`alsa-ucm-conf` 是否含 Qualcomm 子目录**【未证实】** | 【已证实】tplg 与 UCM 都是**发行版无关的自研资产**，可直接搬；【已证实】不能依赖 Debian 固件包 → 需自建 `elden-firmware` 包（§4 阶段 2）。风险点：**tplg 必须在 initramfs 里**（`archive/topics/AUDIO-SDLINE-2026-10-04.md:51-53`），Debian 的 initramfs-tools 默认不会带它 ⇒ 必须写 hook |
| 6 | **传感器** | SSC 路线：`hexagonrpcd-adsp-sensorspd`（QRTR svc400）+ `libssc` + `iio-sensor-proxy`（Alpine 版带 SSC 后端）；`/sys/bus/iio` **恒空** | trixie：`iio-sensor-proxy 3.7-3` **源码无 `drv-ssc-*.c`**（`sources.debian.org` src 列表实测）⇒ **无 SSC 后端**；forky/sid：`3.9-1` 有 `drv-ssc-{accel,compass,light,proximity}.c` 且 `Build-Depends: libssc-dev (>= 0.4.0) [arm64]` | 【已证实】**trixie 上传感器栈不可用**（iio-sensor-proxy 看不到任何设备，因为本机无内核 IIO 节点）；**必须 forky/sid**（或自编 3.9+）。这是「选 trixie 还是 sid」的决定性一项 |
| 7 | **触觉 daemon** | `elden-hapticd`（**静态** aarch64，`out/hapticd/elden-hapticd`，`file` 实测 `statically linked`）+ OpenRC initd；bridge 目录 `/run/elden-haptic/leds/vibrator` | 无对应包；需自写 systemd unit | 【已证实】静态二进制**可直接跨发行版跑**（musl static）；只需把 `elden-hapticd.initd`（36 行）翻成 `.service`。依赖 `lxc.mount.entry` 一条（`scripts/waydroid-haptics-setup.sh`）不变 |
| 8 | **输入法（fcitx5 + squeekboard + elden-ime-focusd）** | squeekboard（OSK0 控制面）+ fcitx5+Rime（`--disable waylandim`）+ `fcitx5-gtk3/4` + 自写 `elden-ime-focusd`（kimpanel `SetRelativeSpotRect` → `SetVisible`） | squeekboard **1.43.1-1**；fcitx5 前端包名 = **`fcitx5-frontend-gtk3` 5.1.3-3**（不是 Alpine 的 `fcitx5-gtk3`）；`fcitx5-rime` 5.1.10-2 | 【已证实】包名/版本差异（`packages.debian.org` 查询：`fcitx5-gtk` 在 trixie **无结果**，`fcitx5-frontend-gtk3` 有）。**关键**：`elden-ime-focusd` 是 **XDG autostart + D-Bus**（`patches-userland/zh-ime/elden-ime-focusd.desktop`、`rootfs/persistent-overlay/user-autostart/`），**与 init 无关** ⇒ systemd 适配成本≈0；但**未在 Debian 上验过** phosh 0.46/0.58 的 squeekboard 交互【未证实】 |
| 9 | **WiFi / BT 服务** | NetworkManager + `wifi-scan-refresh`（OpenRC，`WIFI_SCAN_INTERVAL=150`，必须 <180 s）+ `net-selfheal.sh`（含 `apk fix` 逻辑）+ `ath12k-retry.sh`（12 s 后重绑未绑定 PCI 设备）+ bluez `bluetooth` 服务 | NM/bluez 包都在；`wifi-scan-refresh` 无对应包，需自写 **systemd timer**（150 s）；`net-selfheal.sh` 的 `apk`/`.apk-new` 段落**必须删**（Debian 无 apk） | 【已证实】`scripts/openrc-enable.sh:40`（`DEFAULT=… wifi-scan-refresh …`）、`scripts/net-selfheal.sh:29-33`（`*.apk-new` 逻辑）、`scripts/ath12k-retry.sh:28-29`（`sleep 12` 后循环）。⇒ 3 个服务改写 + 1 个脚本裁剪 |
| 10 | **AB 槽 qbootctl** | Alpine `qbootctl` + `scripts/fix-ab-mark-successful.sh`（把 initd 加进 default runlevel 并显式 start）；备用 `scripts/slot-attr.py`（直接改 GPT 属性，**权威**） | trixie `qbootctl 0.2.2-1`（arm64）**自带 `/usr/lib/systemd/system/qbootctl.service`**，`ExecStart=/usr/bin/qbootctl -m`、`WantedBy=multi-user.target` | 【已证实】`packages.debian.org/trixie/arm64/qbootctl/filelist`。**但**：`-m` 无 slot 参数，靠 cmdline `androidboot.slot_suffix`；本项目 `scripts/build-boot.sh:69` 确实带 `androidboot.slot_suffix=_b` ⇒ **可工作**；`PITFALLS #181`（不置位→~7 次重启卡 fastboot）的教训必须迁移为「装完 Debian 第一件事 `systemctl enable qbootctl` 并核对 `slot-attr.py show`」 |
| 11 | **Waydroid** | Alpine `waydroid`（+ 本项目大量自研 vendor 资产：AIDL vibrator HAL、camera provider、sensord UDP） | trixie **backports 1.6.3+ds-2~bpo13+1**；forky/sid **1.6.3+ds-2/3**；Debian 14+ 进官方 repo（`docs.waydro.id` 原文） | 【已证实】**Debian 可安装性成立**（不再是「无包」状态）。但容器内资产（`/var/lib/waydroid/images/vendor.img` 烘入的 HAL）是**镜像级**，与宿主发行版无关，可整块搬；宿主侧只剩 `elden-hapticd` + lxc 配置（§2 #7）。**未证实**：Debian 的 waydroid 1.6.3 与本机在 Alpine 上验证的版本行为差异（`container_manager.py`/`images.py` 的 `mount_overlays`、`stub_sensors_hal` 逻辑，`PITFALLS #185`） |

### 2.1 矩阵小结（3 条决定性结论）

1. **内核必须自编**：Debian 的任何 `linux-image` 都缺本机板级 DTS（`sm8750-lenovo-elden.dts` 不在上游，v6.15/v6.17 均 404）⇒「Mobian 用 Debian 内核」这条对本机**不成立**，Mobian 只能提供**用户态**。
2. **trixie 不够，必须 forky/sid（或自编包）**：传感器（iio-sensor-proxy SSC 后端）与 libssc 只在 forky/sid；trixie 只能拿到 3.7（无 SSC）。
3. **phosh/phoc 版本是「降级」**：trixie=0.46（比现役 0.55 **旧**）、forky/sid=0.58（新但需重做两枚补丁）。现役 C11 输入法栈在 0.55 上验收，换版本后需重验【未证实】。

## 3. B. 三条路线对比（原地换 rootfs / 新分区并存 / 只换桌面栈）

### 3.1 前提事实（三条路线共用，【已证实】）

- **boot.img（内核 + ramdisk）与 rootfs 完全解耦**：ramdisk 是自建 busybox，`/init` 只做「找盘 → 挂 ext4 → `switch_root` 到 `/newroot/init` 或 `/sbin/init`」⇒ 换 rootfs **不需要改内核、不需要改 boot.img、不需要重签 AVB**。证据：`initramfs/init:234`（`mount -t ext4 … /newroot`）、`:236-238`（`newinit` 依次试 `/init`→`/sbin/init`→`/bin/sh`）、`:247`（`exec switch_root`）。
- 唯一 Linux 分区 = `linux17`（`/dev/sda17`，**193.0 GiB**，ext4，末扇区占满 `last_usable`）。证据：`TASKS/README.md` G1-2 行（`linux17`=193.0 GiB）。⇒ **LUN0 无空闲空间**，路线②必须动 GPT。
- Alpine 根归档在手（回退资产）：`env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` = **3 443 799 223 B**（`ls -la` 实测）。
- 主机侧**当前缺 debootstrap/mmdebstrap**（`which debootstrap mmdebstrap` → 空；`apt-cache policy debootstrap` 显示候选 `1.0.142ubuntu2` 未装），但 **qemu-aarch64 binfmt 已启用**（`/proc/sys/fs/binfmt_misc/qemu-aarch64` → `enabled`，interpreter `/usr/bin/qemu-aarch64`）⇒ 主机侧交叉 debootstrap 可行。

### 3.2 对比表

| 维度 | ① 原地换 rootfs（保留分区） | ② 新分区并存双系统 | ③ 只换桌面栈不换发行版 |
|---|---|---|---|
| 做法 | 把 `linux17` 内容换成 Debian；boot.img 不动 | GPT 手术新增 ext4 分区（如 `debian`），cmdline 改 `elden_root=LABEL=debian` | 保留 Alpine+OpenRC，只把 phosh/phoc 换掉 |
| **回退手段** | **中**：`fastboot boot bootslot-b/boot_b-clean.img` + `ROOTARGS=`（纯 RAM Alpine）→ 挂 `linux17` 解回 3.44 GB 归档 | **最好**：`elden_root` 指回 `LABEL=linux17`（但需重签 boot.img，见 R3） | **最好**：`rc-service greetd restart`，分钟级 |
| 磁盘/GPT 风险 | **无**（不动 GPT） | **有**：需缩 `userdata`（f2fs 重建，Android `/data` 丢）或回收 Android 分区（前置 EDL 全量备份） | **无** |
| 主机侧工作量 | 中：debootstrap + 120 行包集翻译 + firmware 包 + 模块树 + 7 类 systemd unit | 中+：同①，再加 `gpt-surgery-tb322fc.py` 产物核对 + boot.img 重签 + 写回读校验 | 小：换 Alpine edge 或自编 0.58，**不涉发行版** |
| 设备侧需人在场 | 仅首次 `fastboot boot`（零写盘则不需人工按键，但需主机在场） | 同①，**加** GPT 写入（属「有写坏风险的写入」，须先备份） | 无 |
| 拿到什么 | Debian 用户态（systemd/apt/glibc） | 同上 + 三系统并存 | 拿不到 Debian；只是桌面栈版本变化 |
| 主要代价 | **失去 live 回退系统**（唯一 rootfs 被覆盖） | GPT 手术不可逆 | 不解决「要 Debian」这个目标 |
| 判定 | **推荐**（若确实要 Debian）：不动 GPT/AVB | 仅当必须保留 Android+Alpine+Debian 才值 | **不满足本 lane 目标**，但作为「先验证 phosh 0.58 行为」的探路有价值 |

### 3.3 路线选择结论

1. **路线②对当前目标是过度设计**：新增分区要先缩 `userdata`（f2fs 不可逆）或回收 Android 分区（前置条件 = EDL 全量备份 + G1 全绿，`DEVICE/README.md:119` 的 Phase B 口径）——代价远大于收益。
2. **路线①是唯一合理形态**：`linux17` 有 193 GiB（Debian+Phosh 安装后约 15–20 GB，量级依据 `DEVICE/README.md:143` 的 Alpine 实测 15–20 GB），boot.img/AVB 零风险，回退靠 RAM 启动 + 3.44 GB 归档。
3. **路线③建议先做一步（半天量级）作为探路**：在 Alpine 上把 phoc/phosh 换到 0.58.0 自编版，实测两枚补丁在 0.58 上的行为 + squeekboard/fcitx5 兼容性。**这一步的结论直接决定路线①要不要做**（若 0.58 上输入法/缩放坏掉，换 Debian 就是负收益）。

## 4. C. 分阶段执行清单（主机侧先做 / 设备侧最小人工步骤）

> S0–S6 全部可在主机侧完成，**设备保持 fastboot 不动**；只有 S7 触碰设备。

> **★2026-10-26 状态更新（权威状态只在此块，下文各节保留原始计划文本）**
> | 步骤 | 状态 | 产物/证据 |
> |---|---|---|
> | S0 版本选型门 | ✅ 已定 = **forky/sid** | sid 索引实测（`apt-cache` 直读 `/opt/elden/arm64-sid`） |
> | S1 主机 rootfs（debootstrap） | ✅ 完成（2026-10-25） | `/opt/elden/arm64-sid`（`debian_version` = `forky/sid`），同时用作 arm64 交叉构建 chroot |
> | S2 包集翻译 | ✅ 完成（2026-10-26） | `rootfs/debian/pkgmap.tsv`（map 97 / drop 23 / add 7）+ `tools/check-pkgmap.sh` **FAIL=0 WARN=0** → `apt-list.txt`（107 包）；`reports/mobian-rootfs-artifacts-20261026.md` §1 |
> | S3 自建 firmware 包 | ✅ 完成（2026-10-26） | `rootfs/debian/elden-firmware/` → `out/debian/elden-firmware_1.0~20261025_all.deb`（21 MB / 116 项，DTS `firmware-name` 门禁全绿）；同报告 §2 |
> | S4 模块树 | 🟡 物料已就绪，未落地 | `out/modstage-vk163/lib/modules/<UTS>`（1539 `.ko`，模块化产物） |
> | S5 initramfs | ⬜ 未做 | 需 Debian `initramfs-tools` hook（tplg/固件必须进 initramfs） |
> | S6 systemd unit | 🟡 已渲染、未部署 | `packaging/elden-userland/out/units/systemd`（18 个，语义真源 `services.tsv`） |
> | S7 设备侧落地 | ⬜ 未做 | 前置：回退通道实测 + `slot-attr` 基线 |
>
> **方向已由用户指令确认（2026-10-26）**：宿主 rootfs 切 glibc/systemd = 目标（不再受 2026-10-11「不切」裁定约束，
> 该裁定只针对「为换而换」）。仍未变的两条硬约束：① 内核必须自编；② 必须 sid 级 `iio-sensor-proxy` + `libssc2`。

### S0 版本选型门（0.5 h）— ✅ 已定 forky/sid

- 判据：**必须选 forky/sid**（或 trixie + 自编 `iio-sensor-proxy 3.9` + `libssc`）。依据 §2 #6：trixie 的 `iio-sensor-proxy 3.7-3` 源码无 `drv-ssc-*.c`，而本机 `/sys/bus/iio` 恒空（`TASKS/README.md` G1-34 行）⇒ 传感器必死。
- 附带判据：选 sid 即接受 phoc/phosh **0.58.0**，并承担 §6 U1（补丁 rebase）风险。

### S1 主机侧 rootfs 构建（2–3 h）— ✅ 已完成 2026-10-25

- 动作：`sudo apt install debootstrap`；`debootstrap --arch=arm64 --variant=minbase <suite> <dir> <mirror>`（靠已启用的 qemu-aarch64 binfmt 跑 arm64 maintainer scripts）。
- 判据：`chroot <dir> dpkg --print-architecture` = `arm64`；`chroot <dir> /bin/sh -c 'echo ok'` rc=0；目录 < 2 GB（minbase）。
- 备注（重要，**两条独立证据**）：**不要用 Mobian 官方镜像**。
  ① `wiki.debian.org/Mobian/Devices` 的完整设备列表只有 PinePhone/PinePhone Pro/PineTab/PineTab2/PineTab-V/Librem 5/Pixel 3a(3a XL)/OnePlus 6(6T)/Poco F1/Fairphone 4/5/SHIFT6mq，**无任何 SM8750 类设备**；
  ② 构建侧更硬：`mobian-recipes` 的 `devices/qcom/configs/` 只有 `sc7280.toml sdm670.toml sdm845.toml sm6350.toml sm7150.toml wip.toml`（salsa API 实测），**没有 sm8750**；且 `wip.toml` 是空模板（`chipset = ""`）。
  加上 Mobian 明确「使用 mainline 内核、**不打包重设备特定内核**」（`wiki.debian.org/Mobian/Porting`）⇒ 本机只能是「自建 Debian rootfs + 保留自编内核」，Mobian 仅作**包集合参考**（`devices/qcom/packages-phosh.yaml` 一类清单）。

### S2 包集翻译（`apk-world.txt` 120 行 → apt 清单，2 h）— ✅ 已完成 2026-10-26

- 动作：逐条映射 `rootfs/persistent-overlay/apk-world.txt`（`wc -l` = **120**）。已确定的必改项：
  `musl`→无（glibc）；`elogind`/`elogind-common`/`elogind-openrc`→`systemd`（删 -openrc）；`greetd-phrog`→`phrog`；`networkmanager-cli`→`network-manager`；`fcitx5-gtk3/4`→**`fcitx5-frontend-gtk3/4`**（`packages.debian.org` 实测：`fcitx5-gtk` 在 trixie 无结果）；`mesa-dri-gallium`→`libgl1-mesa-dri`+`mesa-utils`；`llvm22-libs`→按 sid 实际 `libllvm*`；`alpine-*`/`apk-tools`/`busybox*`/`openrc` 全删；`squeekboard`/`iio-sensor-proxy`/`hexagonrpcd`/`libssc` 保留（版本按 sid）。
- 判据：清单中**每个 apk 包都有 `map/drop/replace` 三选一的显式记录**（落 `rootfs/debian/pkgmap.tsv`），无「未知」项；且**显式排除 `linux-image-*`**（见 §6 U7）。

### S3 自建 firmware 包（3–4 h）— ✅ 已完成 2026-10-26

- 动作：从 `backup/fw/` 打本地 deb `elden-firmware`，安装到 `/lib/firmware/`：ADSP `adsp.mdt`+seg、CDSP **split** `cdsp.mdt`/`cdsp_dtb.mdt`、WiFi `peach/amss20.bin`+bdwlan+BDF、BT `brhbtfw20.tlv`/`brhbtnv20.bin`、GPU `gen80000_{zap,sqe,gmu,aqe}`、触屏 `novatek_ts_csot_3k_fw.bin`、功放/触觉 `awinic/y700-gen4-*.bin`、**tplg `qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`**。
- 判据（硬）：DTS 的每条 `firmware-name` 与包内路径逐条比对，已知 5 处：`qcom/sm8750/adsp.mdt`（`linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1868`）、`qcom/sm8750/LENOVO/elden/cdsp.mbn`（`:1923`）、`novatek_ts_csot_3k_fw.bin`（`:1948`）、`brhbtnv20.bin`+`brhbtfw20.tlv`（`:2261`）、`awinic/y700-gen4-{haptic,speakers}.bin`（`:1369/1383/1403/1413`）。
- 另判据：**不得依赖 `firmware-qcom-soc`**（trixie filelist 实测无 `sm8750` 目录；只有 sdm845/sm8250/sm8550/sm8650/x1e80100/sc8280xp 的 mbn/tplg）。

### S4 模块树（0.5 h）

- 动作：解 `out/m1-73-modules-<UTS>.tar.gz` 到 `<root>/lib/modules/<UTS>/`，chroot 内 `depmod -a`。
- 判据：`modinfo -F vermagic <root>/lib/modules/<UTS>/kernel/…` **逐字等于**内核 `uname -r`；`ls <root>/lib/modules/<UTS>/kernel | wc -l` 与主机 tarball 一致；`depmod` 无 `not found`。
- 备注：`CONFIG_MODVERSIONS` 未开（`reports/kernel-abi-variants-20261020.md:24`）⇒ **没有 CRC 门**，错配静默加载后 panic —— 这是 R3 的根因。

### S5 initramfs（0.5 h，通常零改动）

- 动作：**不改**。现役 ramdisk 是自建 busybox，已含 `/lib/firmware`（`scripts/build-initramfs.sh:100-107` 注入 `qcom/sm8750` split CDSP 固件）、tplg、模块。
- 判据：解开 ramdisk 后 `lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin` 与 `/init` 存在；`/init` 的 `newinit` 链能找到 Debian 的 `/sbin/init`。

### S6 systemd unit 重写（4–6 h，本方案最大工作量）

| # | 原 OpenRC / 脚本 | systemd 目标 | 判据 |
|---|---|---|---|
| 1 | `/init` 内联 usb0 gadget + `udhcpd` + `sshd`（`initramfs/init` 的 `:266`/`:272`/`:285`） | `elden-lifeline.service`（`Before=network-pre.target`） | `ssh root@192.168.7.1` 通；`ip -br addr show usb0` 有 192.168.7.1 |
| 2 | `greetd` + `LIBSEAT_BACKEND=seatd`（`rootfs/persistent-overlay/etc-conf.d.tar.gz`、`etc-greetd.tar.gz`） | Debian 自带 `greetd.service` + 原 `config.toml`；**`Restart=always`** | `loginctl list-sessions` 有会话；`systemctl is-active greetd`=active（`PITFALLS #318`：greetd 崩=无桌面） |
| 3 | `wifi-scan-refresh`（OpenRC，150 s） | `.timer`（`OnUnitActiveSec=150s`）+ `.service` | `systemctl list-timers` 见 150 s；连通态 `nmcli dev wifi list --rescan no` 的 BSSID 数不塌到 1（`TASKS` G1-36 判据） |
| 4 | `elden-hapticd.initd`（`start_pre` 建 bridge 目录 + chmod 777 + amplitude=255） | `elden-hapticd.service` + `ExecStartPre=`；二进制用**静态** `out/hapticd/elden-hapticd`（`file` 实测 `statically linked`） | `systemctl is-active elden-hapticd`；`/run/elden-haptic/leds/vibrator/` 5 文件、amplitude=255 |
| 5 | `ath12k-retry.sh`（`/init` 后台拉，`sleep 12` 后循环，`scripts/ath12k-retry.sh:28-29`） | `ath12k-retry.service`（`After=systemd-modules-load.service`） | `iw dev` 有 `wlan0`；`dmesg` 见 `ath12k … chip_id` |
| 6 | `net-selfheal.sh`（含 `*.apk-new`/`apk fix` 段落，`scripts/net-selfheal.sh:29-33`） | 裁掉 apk 分支，保留 MTU + ca-certificates 部分 | `net-selfheal.sh --check` rc=0 |
| 7 | Alpine `qbootctl` initd（需手动加 runlevel） | Debian 包**自带** `/usr/lib/systemd/system/qbootctl.service`，只需 `systemctl enable qbootctl` | `qbootctl` 输出 `SLOT _b is marked successful`；`slot-attr.py show` succ=1 且多次重启 retry 不递减 |

- 整组判据：`systemctl --failed` 为空；`systemd-analyze critical-chain` 无超 60 s 项。

### S7 设备侧落地（最小人工步骤，1–2 h）

1. **前置（只读，agent 可做）**：`slot-attr.py show` 记录 `boot_b retry/succ/unbootable`；`scripts/gpt-dump.sh` 存 GPT（**不动 GPT**，仅留档）。
2. **回退通道先实测**：`fastboot boot bootslot-b/boot_b-clean.img`（纯 RAM，零写盘）+ `ssh` 可达 —— **通道不通就不做 S7**。
3. **写 rootfs（不原地覆盖）**：RAM Alpine 里 `mount /dev/sda17 /mnt` → Alpine 根**移入 `/mnt/old-root/`**（同分区，秒级回切）→ 解 Debian 归档到 `/mnt` → `sync` → `reboot`。
   判据：`findmnt /` = `/dev/sda17` 且 `/etc/debian_version` 存在；`ps -p 1 -o comm=` = `systemd`。
4. **首启验收清单**：`systemctl is-system-running`=running；`card0-DSI-1` connected + **目视有桌面**（`PITFALLS #251` 判据）；`aplay -D default` 出声；`nmcli` 连上 ustc-guest；`HasAccelerometer=true`；`loginctl list-sessions` 有会话；`slot-attr.py show` succ=1。

## 5. D. 风险清单（最大 3 个不可用/变砖点 + 规避）

### R1（最高频，**不可用**而非变砖）：AB 槽 retry 归零 → 卡 fastboot

- 机制：ABL 每次启动把**当前槽** `boot_*` 的 `tries_remaining`（3 bit，默认 7）减 1，除非 `BOOT_SUCCESSFUL` 已置位；归零即 `UNBOOTABLE` → 停在 fastboot。证据：`scripts/slot-attr.py:7-22`（`AB_FLAG_OFFSET`=attribute byte 6；bit2=ACTIVE、bit6=BOOT_SUCCESSFUL、bits3-5=tries_remaining、bit7=UNBOOTABLE；`boot_a`/`boot_b` 在 **LUN4 `/dev/sde`**=sde12/sde45，不在 `/dev/sda`）、`DEVICE/README.md:30`（`PITFALLS #181`：Alpine 的 qbootctl initd 不在 runlevel ⇒ ~7 次重启卡 fastboot；基线 `boot_b retry=7 succ=1`）。
- **规避**：① 迁移前记录基线；② Debian 首启**第一件事** `systemctl enable --now qbootctl`（包自带 unit，`ExecStart=/usr/bin/qbootctl -m`、`WantedBy=multi-user.target`，`packages.debian.org/trixie/arm64/qbootctl/filelist` 实测）；③ `-m` 不带 slot 依赖 cmdline `androidboot.slot_suffix`，本项目 `scripts/build-boot.sh:69` 已带 `_b` ⇒ 可用，换 boot.img 必须保留；④ 判据 = 连续 3 次 `reboot` 后 `retry` 不变且 `succ=1`。

### R2（**不可用**）：唯一 rootfs 被覆盖后起不来，无 live 回退

- 机制：`linux17` 是唯一 Linux 分区；`/init` 的 `newinit` 选择链只判断「文件是否存在」，systemd 起来后崩不会自动回退（`initramfs/init:236-238` 只做 `-x` 存在性判断）。
- **规避**：① **不原地覆盖**，把 Alpine 根移入 `/mnt/old-root/`（S7 步骤 3）；② 更稳：把 Alpine 根打成 `/mnt/old-root.tar` 再清空（回退 = RAM 启动 + 解包）；③ 保留 3.44 GB 归档 `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` 作最后兜底；④ 回退通道**事前实测**（S7 步骤 2）。
- 定性：**不是变砖**（fastboot 与纯 RAM 启动都在），但会让设备「只有 fastboot 可用」，必须主机在场。

### R3（**变砖级**，仅当改 boot.img 时）：AVB 链 / 模块树错配

- 机制：① `boot` 是 **chained AVB** 分区，自签必须 AOSP testkey（sha1 `2597c218`）+ rollback `1738713600` + 3 条 prop，缺任一被 ABL 拒（`DEVICE/README.md:23`）；换机后 `bootslot-b/avb.key` 已重建，新公钥 sha1 `1e54e86ef19fad73…`（旧 `fc1e3b33…` 作废，`DEVICE/README.md:35`）。② `CONFIG_MODVERSIONS` 未开 ⇒ 内核与模块树**无 CRC 门**，错配静默加载后 `[0.55 s]` panic（`reports/kernel-abi-variants-20261020.md:16-24`）。
- **规避**：① **路线①根本不需要动 boot.img**（§3.1）⇒ 方案里不出现「改 cmdline/重签」；② 若必须重签：只用 `scripts/sign-boot-b.sh`（`add_hash_footer` + `--partition_size 100663296`），**先**设备侧 `dd if=/dev/disk/by-partlabel/boot_b` 备份（本机 ABL **无 `fastboot fetch`**，`PITFALLS #290`），写后读回比对 sha256；③ 内核与模块树同进同退（`reports/kernel-abi-variants-20261020.md:26-34` 的 symlink 挂载点做法）；④ fastboot 命令**拆单条**（`PITFALLS #3`），客户端**不得接 `head`/`grep -q`**（SIGPIPE 卡死 gadget，`PITFALLS #199`）。

### R4（附带，通道级）

- 设备当前在 fastboot（`HA2EXB0E`），本 lane 全程未发任何 fastboot 命令。写操作前查 `scripts/device-lock.sh --status`。
- Linux→fastboot 的可靠入口是 `reboot2 bootloader`（PSCI vendor reset，`scripts/to-fastboot.sh:1-11`），**不是** `cycle.sh --soft`（sysrq-b 在 b 槽直启后不进 fastboot，`cycle.sh:19` 为旧路径）。`reboot2` 是**静态 aarch64**（`file` 实测 `statically linked`）⇒ 在 Debian 上同样可用，回退通道不受发行版影响。

## 6. 未证实项与下一步取证

| # | 未证实项 | 为什么重要 | 取证方式 |
|---|---|---|---|
| U1 | 0001/0002 补丁 rebase 到 phoc/phosh **0.58.0** 后行为是否等价 | 决定 sid 路线可行性 | 源码已核（§2 #4）；**行为**需上机（`wlr-randr` 切档 + `gdbus GetCurrentState` 比对 supported_scales） |
| U2 | phosh **0.46/0.58** 与 squeekboard 1.43.1 / fcitx5 5.1.3 的输入法交互 | C11 栈在 0.55 上验收，换版本后未知 | 上机（主机侧只能读源码） |
| U3 | Debian `alsa-ucm-conf` 是否含 Qualcomm sm8750 子目录 | 决定 UCM 要否整包自带 | `apt-file`/filelist 查询（本 lane 未做） |
| U4 | Debian `waydroid 1.6.3` 的 `images.py`/`container_manager.py` 与本机 Alpine 版差异（`mount_overlays`、`stub_sensors_hal`、`config_nodes` bind） | 决定容器内自研 HAL 能否原样沿用 | 下载 Debian 源码包比对（主机侧可做，未做） |
| U5 | squeekboard **1.43.1** 是否仍提供 `sm.puri.OSK0` 控制面 | `elden-ime-focusd` 依赖该 D-Bus 接口 | 读 squeekboard 源码 + 上机 |
| U6 | `hexagonrpcd 0.4.0`（sid）是否含 `adsp-sensorspd` 等价入口 | 传感器链路前置 | trixie 0.3.2 的 filelist **只有** `hexagonrpcd`+`chrecd`，**无** `hexagonrpcd-adsp-sensorspd`（实测 filelist）⇒ 0.4.0 需再查 |
| U7 | Debian `initramfs-tools` 是否会抢管 ramdisk | 若装 `linux-image-*` 会覆盖自建 ramdisk | 规避：S2 清单**显式排除** `linux-image-*` |

### 6.1 建议的下一步（按性价比排序）

1. **先做路线③探路**（半天）：Alpine 上自编 phoc/phosh 0.58.0 + rebase 两枚补丁 → 上机验刷新率/缩放/输入法。**若失败，整个 Debian 迁移应停在此处**。
2. 主机侧补 `debootstrap` 并跑 S1/S2（离线可做，不占设备）。
3. 只有 1、2 都绿之后，才讨论设备侧 S7（需主机在场；优先用 `fastboot boot` 零写盘）。
