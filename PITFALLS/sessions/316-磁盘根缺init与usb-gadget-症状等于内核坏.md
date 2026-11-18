## #680 磁盘根少 `/init` 或 `/usr/local/sbin/usb-gadget` 时，`systemd` 照样起 ⇒ 设备症状是「只有背光 + USB 完全不枚举」，与「内核坏了/卡死」**无法区分**

**现象（2026-11-18 夜 ~ 2026-11-19 00:xx，U2 `HA2EXB0E` 重建最小 Debian 根）**：
EDL 写入 6 GiB minbase 根 + 自签 `boot_b`（`elden_root=LABEL=linux`），上电后**只有背光**：
不闪（⇒ 无 panic）、`lsusb` 无 gadget、`adb`/`fastboot` 全空、串口无输出。看起来和「内核/initramfs 坏」一模一样。

**真因**：该镜像**没有 `/init`**，`/usr/local/sbin` 是空目录。设备上 `systemd` 仍能从 `/sbin/init` 起来，
但 `/init` 负责的 `respawn ttyGS0/ttyGS1`、`usb-gadget`（USB-NCM）、`usb0_dhcp`、`elden-init-trace.log`
**全都不存在** ⇒ 既没有远程入口也没有 trace 落盘。

**为什么会漏**：`rootfs/debian/build-rootfs.sh` 第 4 步是 `rsync -aHAX stage/ → ROOTDIR/`，
stage 少一件就静默少一件（**rsync 退出码照样 0**）；`GATE_MIN` 只查 `/sbin/init`，
于是「能起 + 能 ssh」这个门在**缺 `/init` 时仍全绿**。

### 判据（三条，全部主机侧、只读、不需 root/loop mount）

| # | 命令 | 期望 |
|---|---|---|
| 1 | `debugfs -R "stat /init" <img>` | 有 `Inode:` 且 `Mode: 0755`（不是 `File not found by ext2_lookup`） |
| 2 | `debugfs -R "stat /usr/local/sbin/usb-gadget" <img>` | `regular` + 可执行位（无串口的机器上这是唯一远程入口） |
| 3 | `scripts/rootfs-image-check.py <img> --profile net --expect-init initramfs/init --strict-init` | `FAIL=0`；`/init` 与真源**同字节**（不同 = 磁盘 init 分叉） |

### 已落地的门（两道，2026-11-19）

- **构建侧**：`rootfs/debian/build-rootfs.sh` §8 门禁新增（两档共用）`/init` 存在 + 可执行 + 与 `initramfs/init` 同字节；
  最小档再加 `usb-gadget` + `/etc/udhcpd.conf`。缺任一件 ⇒ `FAIL`（构建失败，而不是"产出一个起不来的镜像"）。
- **镜像侧**：`scripts/rootfs-image-check.py`（debugfs 直读，`--selftest` 内置好/坏/无执行位/分叉四个合成件）
  + `check-doctor` §20（自检 + **已知坏件必须被拒** 反作弊 + 已知好件必须过）。
  已知对照：`out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img` = FAIL（/init、usb-gadget 各缺失），
  `out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img` = PASS（`/init` 34584 B 与真源同字节）。

**纪律**：以后所有 minbase/桌面档都必须在 build 里带 `/init`；**修镜像不要手工往 ext4 里塞件**（`debugfs -w` 只能应急），
正路是修 stage 再重跑构建，否则下一发又少。

证据：`TASKS/sessions/2026-11-19-主线恢复最小Linux与显示定位.md` §「本轮顺带修好的两个坑」；
`scripts/doctor/20-rootfs-image.sh` 的实现注释。
