# M6 首次上机：Debian 目标根候选镜像 `fastboot boot` 后设备**全程无 USB**（未收口）

> 2026-10-26 11:05 · 设备 `HA2EXB0E`（U2）· 试验性质：零写盘（`fastboot boot`），**未写任何分区**
> 结论：**未验证成功 / 未证实失败原因**。设备在 `fastboot boot` 后从 USB 彻底消失，无串口、无网络、
> 无 fastboot ⇒ 按 `.pi/AGENT-OPS.md` §1「出现超出预期的错误 → 停止重试、保留现场、给用户可执行的恢复步骤」
> 处理：**需要用户物理长按电源（POR）**。`boot_b` 与 `linux18`（Alpine 现役根）未被触碰。

## 1. 时间线（主机内核日志 + lsusb 取证）

| 时刻 | 事件 | 证据 |
|---|---|---|
| 10:49 | Debian rootfs 归档传到设备（605 MB，sha256 `fcb6081c…` 双端一致） | `scp` / 设备侧 `sha256sum` |
| 10:50 | 写入 `linux17`：挂载 → 清空 → 解包（36 268 文件 / 1.9 G）→ 关键项核对 → `sync` → 卸载 | 见 §2 |
| 10:52:29 | Alpine（linux18）下线，进 fastboot | `usb 1-10: USB disconnect, device number 6` |
| 10:52:34 | fastboot 枚举 `18d1:d00d` serial `HA2EXB0E` | 同上 device number 11 |
| 10:57:50 | `fastboot boot out/boot-elden-vk164-debianroot.img` → `Sending OKAY [1.9s]` / `Booting OKAY [10.1s]`；**这一刻 USB 断开后再没出现** | `USB disconnect, device number 11`，其后 8 分钟无任何 usb 日志 |
| 10:58–11:05 | 轮询：无 `18d1:*`、无 `1d6b:0104`（composite gadget）、`/dev/ttyACM*` 不存在、`fastboot devices` 空 | `lsusb` 全量、`journalctl -k --since 10:57` |

判据口径：`PITFALLS #391` 说 `fastboot boot` 后 USB 会变 `1d6b:0104` 且要 **60–90 s** 才枚举；
本次等了 **>7 min** 且 `18d1/1d6b:0104` **一次都没出现** ⇒ 不是「慢枚举」，是**没起来**。

## 2. 已确认的落盘状态（设备侧只读核对过）

- `linux17`（ext4，LABEL 仍是 `linux17`）现在 = Debian forky/sid 目标根：`etc/debian_version=forky/sid`、
  `sbin/init -> ../lib/systemd/systemd`、模块树 `…-debug-vk163`、固件 `qcom/sm8750/adsp.mdt`、
  传感器树 140 文件、`etc/systemd/system/{multi-user.target.wants/qbootctl.service,display-manager.service,elogind.service,hexagonrpcd-adsp-sensorspd.service}` 四条符号链接、
  `lib -> usr/lib`（usr-merge 完好）、`etc/fstab` 活行只有 `LABEL=linux17`。
- `linux18`（f2fs，Alpine 现役根）= **未动**。
- 槽位基线（写前记录）：`boot_b retry=6 succ=1 unbootable=0 active=1`；`boot_a retry=6 succ=1`。
- 归档：`out/debian/elden-rootfs-20261026.tar.zst`（605 MB，sha256 `fcb6081c…`）；
  主机侧完整根 `/opt/elden/mobian-rootfs`（833 包 / 1.9 G）。
- 候选镜像：`out/boot-elden-vk164-debianroot.img`（85 811 200 B，sha256 `56644bc7…`）。

## 3. 为什么「载荷与 vk163 相同」却挂了（分析，非结论）

vk164 与 2026-10-26 上午**上机成功**的 vk163 镜像相比，**内核 `Image.gz`、DTB、ramdisk 三者逐字相同**
（同 `build/vk151`、同 `out/initramfs-full-elden.cpio.gz`），唯一差异 = cmdline
`elden_root=LABEL=linux18` → `LABEL=linux17`。⇒ 变量只有「切到哪个根」。

已排除/未排除的怀疑点：

| # | 怀疑 | 现状 |
|---|---|---|
| H1 | 磁盘根 `/init` 在 **dash**（Debian `/bin/sh`）下跑不起来 | `dash -n initramfs/init` **通过**；但运行期差异未验（`getty -n -l`、`rescue` 分支等） |
| H2 | `/init` 在磁盘根上 `mnt proc/sysfs/run` 失败 → 走 `rescue()`（exec `/bin/sh` 当 PID1，**不打 USB**） | 三个目标目录在目标根里都存在；`mnt()` 自带 `mkdir -p`。**未排除**（一旦落进 rescue，表现正是「全静默、无 USB」） |
| H3 | `usb-gadget` 起不来（configfs 未挂 / 无 UDC） | gadget 相关 Kconfig 全 `=y`（`CONFIG_USB_CONFIGFS_NCM/ACM`、`LIBCOMPOSITE`、`DWC3`），`usb-gadget` 脚本在目标根里（MANIFEST 已铺）。**未排除** |
| H4 | 内核在 userspace 之前就挂了 | 载荷与 vk163 逐字相同，理论上不可能；且 `panic=15` 应触发重启回 `boot_b`（未见 USB 复现） |
| H5 | SoC 级硬挂（本机 Q28 家族的既有现象） | 无串口无法判 |

**关键结构性观察**：现在整条恢复通道（usb0 + ttyGS0/GS1）都在 `switch_root` **之后**由磁盘 `/init` 拉起。
一旦磁盘根有任何问题，主机侧就**完全失明**。这与本项目「lifeline 必须在交接之前」的原则少了一层。

## 4. 下一步（按性价比，都不需要先知道 H1–H5 的答案）

1. **物理 POR**（用户操作）：长按电源 ~10 s 关机，再开机。预期回到 `boot_b` → Alpine（linux18）→
   `lsusb` 见 `1d6b:0104`、`ssh root@192.168.7.1` 可达、`uname -r` = `…-debug-vk127-…`（不带 vk163 后缀）。
2. **把 lifeline 提前一层**（改 `/init`，仍只读验证后再上机）：加 `elden_early_gadget=1`，
   在 **RAM 阶段**（`switch_root` 之前）就挂 configfs + 起 `usb-gadget`，使「磁盘根自己坏了」时
   主机仍能拿到 ttyACM0 的 dmesg 与 shell。这是本次事故最直接的工程结论。
   注意：`PITFALLS` 里有「ramdisk 资源不能跨 switch_root 持有」的教训（`/init` 里对应注释），
   早挂 gadget 是否会被 switch_root 破坏需先在 **RAM-only 镜像**上验（零写盘）。
3. **串口常驻**：设备回来后先把 `cat /dev/ttyACM0` 抓到文件（现在那口是 root 起的临时 `cat`，
   日志没落盘），再重试候选镜像 ⇒ 才有机会看到 `[init] …` 的实际停点。
4. 重试顺序建议：先 **RAM-only 变体**（`ROOTARGS=`，验证新 `/init` 与早发 gadget 不破坏启动）
   → 再 `elden_root=LABEL=linux17` 候选。

## 5. 复现命令（设备回归后逐条跑，**不要**接管道）

```bash
lsusb | grep -E '18d1|1d6b:0104'
fastboot devices
ssh -o BatchMode=yes root@192.168.7.1 'uname -r; findmnt -no SOURCE /'
# 串口抓取（设备回来后）
cat /dev/ttyACM0 | tee /tmp/serial-$(date +%H%M%S).log
# 重试候选（零写盘）
fastboot boot out/boot-elden-vk164-debianroot.img
# 退回 boot_b（PITFALLS #90/#406：fastboot boot 的镜像会活过暖复位）
ssh root@192.168.7.1 reboot2 bootloader && fastboot reboot
```

---

## 6. 调试全记录（同日续，8 发候选镜像）— **断点已定位到 `switch_root`**

### 6.1 取证基础设施（这轮最大的工程产出）

| 尝试 | 结果 |
|---|---|
| 串口 `cat /dev/ttyACM0` | **无用**：console 在 t≈11 s 才连上（gadget 后起），`/init` 的埋点都在 t≈2–6 s；连上时内核只把 ring buffer 重放一遍（到 t≈10.98），此后设备一个字节都没打 |
| 多读者并存 | **有害**：常驻 fanout + 临时 `cat` 会**分食同一条流**，日志出现空洞（第一次失败证据就这么丢的）。已改 `scripts/serial-probe.sh`（独占 + BREAK/换行）与 `scripts/serial-capture.sh`（`DETACH=1`） |
| **pstore / pmsg** | **不可用**：`echo x > /dev/pmsg0` 返回 0，但 `/sys/fs/pstore` **恒空**（`mount -t pstore` 也空）；ramoops 已注册（`pstore: Registered ramoops as persistent store backend`，`ramoops: using 0x400000@0xc2000000`）。⇒ 只能降级为「备份通道」，见 PITFALLS 新条目 |
| **`/init` trace → 常开 fd 9 直写目标根 ext4** | ✅ **有效**：`/var/tmp/elden-init-trace.log` 跨复位可读；每行立即落盘，不受「后续行还在 tmpfs」歧义影响 |
| 免物理断电复位（SysRq over USB ACM） | 已实现 `scripts/serial-sysrq.py`（BREAK + 字符；内核 `CONFIG_MAGIC_SYSRQ=y` + `MAGIC_SYSRQ_SERIAL=y`），**本轮未验证成功**（发 `b` 后设备重新枚举但未回 Alpine） |

### 6.2 决定性 trace（vk170-trace3 那发，逐字）

```
elden-init/ram t=0.80 start on_initramfs=1 mode= roottype=tmpfs
elden-init/ram t=0.81 disk root requested: LABEL=linux17
elden-init/ram t=0.84 early usb0 up
elden-init/ram t=0.97 resolved LABEL=linux17 -> /dev/sda17
elden-init/ram t=0.97 mount start dev=/dev/sda17 fstype=ext4
elden-init/ram t=0.98 mount ok entries=20
elden-init/ram t=0.98 newinit /init size=29055
elden-init/ram t=0.98 mkdir newroot dirs
elden-init/ram t=0.98 move /dev
elden-init/ram t=0.98 move /proc
elden-init/ram t=    move /sys        ← 时间戳变空：/proc 已被搬走（预期副作用）
elden-init/ram t=    move /run
elden-init/ram t=    all mounts moved
elden-init/ram t=    exec switch_root /newroot /init
```
**之后没有任何 `disk …` 行。**

### 6.3 由此确定的结论

1. `linux17` 的 ext4 **挂载完全正常**（t=0.97→0.98，20 个顶层项），4 个 `mount --move` 全部完成；
2. `exec switch_root /newroot /init` **已发出**，但磁盘根的 `/init` **一个 trace 都没写**（它在开头就会 `exec 9>>/var/tmp/…` 并写 `start`）⇒ **从未进入磁盘 `/init`**；
3. ⇒ 卡点在 **busybox `switch_root` 内部**（它要递归删除旧 initramfs 的整棵树后再 `mount --move` + `chroot` + `exec`），或 `exec` 后内核 exec 失败。
   **已排除**：Debian 根的用户态不可执行（设备上 `chroot /mnt/deb /bin/sh` → `chroot-exec-ok` + `forky/sid`；`dash -n /init` 通过；`sbin/init -> ../lib/systemd/systemd`）。
4. 「设备活着但无 SSH」还有一个**结构原因**：`mount --move` 之后 `/dev /proc /sys /run` 都离开了 RAM 根，一旦 `switch_root` **返回失败**而不是 exec，后面的 lifeline（usb-gadget/sshd/udhcpd）会**静默全废**。已在 `/init` 里补「switch_root 返回则把四个伪文件系统搬回来」。

### 6.4 下一步（已实现、待读结果）

`vk171-swrerr`（`out/boot-elden-vk171-swrerr.img`，sha `551ac3a848aedd35…`）把 **`switch_root` 的 stderr 直接重定向进 trace 文件**（`exec switch_root … 2>&9`），并加了「返回则恢复伪文件系统」。它的错误文案就是答案（`not a mount point` / `can't delete …` / `exec failed: …`）。**该发未读到结果**（设备卡住待物理 POR）。

另一条待验方向：`switch_root` 的删除阶段要递归 unlink **整个 initramfs**（本机 full ramdisk 解包约 200 MB、`/lib/firmware` 数千文件）。若嫌疑集中在此，可改用 `switch_root` 的替代实现（自己 `mount --move` + `chroot` + `exec`，跳过删除），或换成 slim ramdisk（无 `/lib/firmware`）先验一次。

### 6.5 本轮设备态

**需要物理 POR**：设备当前 USB 有 `1d6b:0104` gadget、无 SSH、无 fastboot。`boot_b` 槽位未变（`retry=6 succ=1 unbootable=0`），`linux18`（Alpine 现役根）未动，`linux17` 上是 Debian 根 + 最新 `/init`（sha `678cccb7…`）。**全程零写盘**（只 `fastboot boot`；唯一写入是 rootfs 归档到 `linux17` 与把 `/init` 铺进该根，均在非现役分区）。
